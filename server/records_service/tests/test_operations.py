"""Tests for running the service in production: the health check, restoring
an account from its recovery code, moderation (reports, hidden names, bans),
the account throttle, errors that never leak, the request log (no tokens,
no addresses), the file database across restarts, and backups.

    python3 -m unittest discover -s server/records_service/tests -t .
"""

import io
import json
import os
import sqlite3
import tempfile
import time
import unittest

from server.records_service import admin, backup
from server.records_service import service as svc
from server.records_service.tests.test_service import Base, NOON, crag_send


class Health(Base):
    def test_the_health_check_answers_without_signing_in(self):
        code, out = self.call("GET", "/healthz")
        self.assertEqual(code, 200)
        self.assertTrue(out["ok"])
        self.assertEqual(out["version"], svc.VERSION)


class PrivacyPage(Base):
    def test_the_privacy_policy_is_served_when_configured(self):
        self.assertEqual(self.call("GET", "/privacy")[0], 404, "none configured: not found")
        self.s.privacy_page = b"<h1>policy</h1>"
        status = {}
        out = b"".join(self.app({"REQUEST_METHOD": "GET", "PATH_INFO": "/privacy", "wsgi.input": io.BytesIO()},
                                lambda s, h: status.update(s=s, h=dict(h))))
        self.assertTrue(status["s"].startswith("200"))
        self.assertIn("text/html", status["h"]["Content-Type"])
        self.assertEqual(out, b"<h1>policy</h1>")


class Recovery(Base):
    def test_the_recovery_code_restores_the_account_on_another_device(self):
        a = self.player(name="Restorer")
        self.submit(a["token"], crag_send())
        # A new device with only the code (the token) sees the same player.
        code, me = self.call("GET", "/v1/me", token=a["token"])
        self.assertEqual(code, 200)
        self.assertEqual(me["playerId"], a["playerId"])
        self.assertEqual(me["displayName"], "Restorer")
        self.assertEqual(me["friendCode"], a["friendCode"])
        code, _ = self.call("GET", "/v1/me", token="not-a-real-code")
        self.assertEqual(code, 401)


class Rotation(Base):
    def test_a_new_recovery_code_retires_the_old_one(self):
        a = self.player(name="Rotator")
        self.submit(a["token"], crag_send())
        code, out = self.call("POST", "/v1/me/rotate", token=a["token"])
        self.assertEqual(code, 200)
        self.assertNotEqual(out["token"], a["token"])
        self.assertEqual(self.call("GET", "/v1/me", token=a["token"])[0], 401, "the old code no longer works")
        code, me = self.call("GET", "/v1/me", token=out["token"])
        self.assertEqual((code, me["playerId"]), (200, a["playerId"]), "the new one is the same account")
        code, export = self.call("GET", "/v1/me/export", token=out["token"])
        self.assertEqual(len(export["crag_attempts"]), 1, "with its records")
        self.assertEqual(self.call("POST", "/v1/me/rotate")[0], 401, "rotating needs the current code")


class Moderation(Base):
    def setUp(self):
        super().setUp()
        self.a = self.player(name="Reporter")
        self.b = self.player(name="Rude Name")
        self.submit(self.b["token"], crag_send())

    def test_a_report_reaches_the_moderators(self):
        code, _ = self.call("POST", "/v1/reports", {"player": "Rude Name", "reason": "offensive"}, self.a["token"])
        self.assertEqual(code, 200)
        open_reports = admin.reports(self.s)
        self.assertEqual([(r["target"], r["reason"]) for r in open_reports], [("Rude Name", "offensive")])
        code, _ = self.call("POST", "/v1/reports", {"player": "Nobody Here"}, self.a["token"])
        self.assertEqual(code, 404)
        code, _ = self.call("POST", "/v1/reports", {"player": "Rude Name"})
        self.assertEqual(code, 401, "reports need an account")

    def test_reports_are_limited_per_day(self):
        for _ in range(svc.REPORTS_PER_DAY):
            self.assertEqual(self.call("POST", "/v1/reports", {"player": "Rude Name"}, self.a["token"])[0], 200)
        self.assertEqual(self.call("POST", "/v1/reports", {"player": "Rude Name"}, self.a["token"])[0], 429)

    def test_a_hidden_name_leaves_the_boards_and_firsts_and_is_free_again(self):
        self.call("POST", "/v1/reports", {"player": "Rude Name"}, self.a["token"])
        self.assertTrue(admin.hide_name(self.s, "Rude Name")["ok"])
        code, board = self.call("GET", "/v1/leaderboards/crag/warm-up")
        self.assertEqual(board["entries"][0]["player"], "a climber")
        code, firsts = self.call("GET", "/v1/firsts")
        self.assertEqual(firsts["firsts"][0]["display"], "a climber")
        self.assertEqual(admin.reports(self.s), [], "its reports are resolved")
        code, _ = self.call("POST", "/v1/players", {"age": 30, "displayName": "Rude Name"})
        self.assertEqual(code, 201, "the name can be taken again (and re-reported)")

    def test_a_banned_player_cannot_submit_and_leaves_the_boards(self):
        admin.set_ban(self.s, self.b["playerId"], True)
        code, out = self.submit(self.b["token"], crag_send())
        self.assertEqual(code, 403)
        code, board = self.call("GET", "/v1/leaderboards/crag/warm-up")
        self.assertEqual(board["entries"], [])
        admin.set_ban(self.s, "Rude Name", False)
        code, board = self.call("GET", "/v1/leaderboards/crag/warm-up")
        self.assertEqual(len(board["entries"]), 1, "nothing was deleted: a ban can be undone")

    def test_stats(self):
        self.assertEqual(admin.stats(self.s)["players"], 2)

    def test_extra_blocked_words_come_from_a_file(self):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as f:
            f.write("# comment\nbadword\n")
        try:
            svc.load_blocked_words(f.name)
            self.assertNotEqual(svc.name_problem("My Badword"), "")
            self.assertEqual(svc.name_problem("Kibo Fan"), "")
        finally:
            svc._extra_blocked = ()
            os.remove(f.name)


class Throttle(Base):
    def test_new_accounts_from_one_address_are_limited(self):
        for i in range(svc.ACCOUNTS_PER_HOUR):
            self.assertEqual(self.s.create_player({"age": 30}, "203.0.113.5")[0], 201)
        self.assertEqual(self.s.create_player({"age": 30}, "203.0.113.5")[0], 429)
        self.assertEqual(self.s.create_player({"age": 30}, "203.0.113.6")[0], 201, "another address is not affected")
        self.now += 3601
        self.assertEqual(self.s.create_player({"age": 30}, "203.0.113.5")[0], 201, "an hour later it is fine")

    def test_the_proxy_address_is_used_only_when_trusted(self):
        # The client sent a made-up address first; the proxy appended the real one.
        env = {"REMOTE_ADDR": "10.0.0.2", "HTTP_X_FORWARDED_FOR": "203.0.113.66, 198.51.100.7"}
        self.assertEqual(svc._client_address(env, True), "198.51.100.7", "the proxy's entry, not the client's")
        self.assertEqual(svc._client_address(env, False), "10.0.0.2")


class Errors(Base):
    def test_a_crash_is_a_500_with_no_details_and_is_logged(self):
        lines = []
        app = svc.make_app(self.s, log=lines.append)
        self.s.health = lambda: 1 / 0
        status = {}
        out = b"".join(app({"REQUEST_METHOD": "GET", "PATH_INFO": "/healthz", "wsgi.input": io.BytesIO()},
                           lambda s, h: status.setdefault("s", s)))
        self.assertTrue(status["s"].startswith("500"))
        self.assertEqual(json.loads(out), {"error": "server error"})
        self.assertTrue(any(l.get("event") == "error" for l in lines))
        self.assertEqual(lines[-1]["status"], 500)

    def test_the_request_log_has_no_tokens_or_addresses(self):
        lines = []
        app = svc.make_app(self.s, log=lines.append)
        a = self.player()
        app({"REQUEST_METHOD": "GET", "PATH_INFO": "/v1/me", "HTTP_AUTHORIZATION": "Bearer " + a["token"],
             "REMOTE_ADDR": "203.0.113.9", "wsgi.input": io.BytesIO()}, lambda s, h: None)
        text = json.dumps(lines)
        self.assertEqual(lines[-1]["status"], 200)
        self.assertNotIn(a["token"], text)
        self.assertNotIn("203.0.113.9", text)


class BackgroundBackups(unittest.TestCase):
    def test_the_service_backs_itself_up(self):
        d = tempfile.mkdtemp()
        db = os.path.join(d, "records.sqlite")
        svc.Service(db).db.close()
        lines = []
        svc.start_backups(db, os.path.join(d, "b"), keep=3, every=3600, log=lines.append)
        for _ in range(50):
            if lines:
                break
            time.sleep(0.05)
        self.assertEqual(lines[0]["event"], "backup")
        self.assertEqual(len(os.listdir(os.path.join(d, "b"))), 1)


class Storage(unittest.TestCase):
    def test_the_database_survives_a_restart_and_backs_up(self):
        d = tempfile.mkdtemp()
        db = os.path.join(d, "records.sqlite")
        s = svc.Service(db, clock=lambda: NOON)
        code, a = s.create_player({"age": 30, "displayName": "Keeper"})
        s.db.close()
        s = svc.Service(db, clock=lambda: NOON)
        self.assertIsNotNone(s.player_for(a["token"]), "the account is still there after a restart")
        out = os.path.join(d, "backups")
        paths = [backup.backup(db, out, keep=2, now=NOON + i) for i in range(3)]
        kept = sorted(os.listdir(out))
        self.assertEqual(len(kept), 2, "only the newest are kept")
        self.assertEqual(os.path.basename(paths[-1]), kept[-1])
        copy = sqlite3.connect(paths[-1])
        self.assertEqual(copy.execute("SELECT display_name FROM players").fetchone()[0], "Keeper")
        with self.assertRaises(FileNotFoundError):
            backup.backup(os.path.join(d, "missing.sqlite"), out)



class Restore(Base):
    """A backup taken from a live service puts every record back."""

    def live(self, d):
        db = os.path.join(d, "records.sqlite")
        self.s = svc.Service(db, clock=lambda: self.now)
        self.app = svc.make_app(self.s)
        a = self.player(name="Keeper")
        b = self.player(name="Second")
        self.assertTrue(self.submit(a["token"], crag_send())[1]["ok"])
        self.call("POST", "/v1/friends", {"friendCode": b["friendCode"]}, a["token"])
        self.call("POST", "/v1/reports", {"player": "Second", "reason": "test"}, a["token"])
        return db, a

    def test_a_restore_puts_back_every_record_and_keeps_what_it_replaced(self):
        with tempfile.TemporaryDirectory() as d:
            db, a = self.live(d)
            path = backup.backup(db, os.path.join(d, "backups"), now=NOON)
            want = backup.verify(path)["counts"]
            self.assertEqual((want["players"], want["crag_attempts"], want["firsts"], want["follows"], want["reports"]), (2, 1, 1, 1, 1))
            # Disaster: the account is gone from the live database.
            self.call("DELETE", "/v1/me", token=a["token"])
            self.s.db.close()
            out = backup.restore(path, db, now=NOON + 60)
            self.assertEqual(out["counts"], want)
            self.assertTrue(os.path.exists(out["replaced"]), "the replaced database is kept")
            s = svc.Service(db, clock=lambda: self.now)
            self.assertIsNotNone(s.player_for(a["token"]), "the account signs in again with its recovery code")
            self.assertEqual([e["player"] for e in s.crag_board("warm-up")], ["Keeper"])
            self.assertEqual(s.firsts()[0]["display"], "Keeper")
            s.db.close()

    def test_the_drill_restores_a_copy_and_the_service_answers(self):
        with tempfile.TemporaryDirectory() as d:
            db, _ = self.live(d)
            path = backup.backup(db, os.path.join(d, "backups"), now=NOON)
            before = os.path.getmtime(db)
            out = backup.drill(path)
            self.assertTrue(out["ok"] and out["health"]["ok"])
            self.assertEqual(out["counts"]["crag_attempts"], 1)
            self.assertEqual(os.path.getmtime(db), before, "the live database is not touched")
            self.assertEqual(backup.main(["--drill", path]), 0)
            self.assertEqual(backup.main(["--verify", path]), 0)

    def test_a_broken_backup_is_never_restored(self):
        with tempfile.TemporaryDirectory() as d:
            db, _ = self.live(d)
            junk = os.path.join(d, "junk.sqlite")
            with open(junk, "wb") as f:
                f.write(b"not a database" * 100)
            empty = os.path.join(d, "empty.sqlite")
            sqlite3.connect(empty).close()
            for bad in (junk, empty):
                with self.assertRaises(ValueError):
                    backup.restore(bad, db)
                self.assertEqual(backup.main(["--db", db, "--restore", bad]), 1)
            self.assertEqual(backup.verify(db)["counts"]["players"], 2, "the live database is unchanged")
            with self.assertRaises(FileNotFoundError):
                backup.verify(os.path.join(d, "missing.sqlite"))


class RestoreOnBoot(Base):
    """Hosts with no stopped state (Fly) restore by leaving a backup at
    /data/restore.sqlite and restarting: server/restore_on_boot.sh."""

    live = Restore.live

    def boot(self, d, db):
        import subprocess
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
        env = dict(os.environ, RECORDS_DB=db, RECORDS_RESTORE_FILE=os.path.join(d, "restore.sqlite"))
        return subprocess.run(["sh", os.path.join(root, "server", "restore_on_boot.sh")], cwd=root, env=env,
                              capture_output=True, text=True, timeout=60)

    def test_a_backup_left_for_the_boot_is_restored_once(self):
        with tempfile.TemporaryDirectory() as d:
            db, a = self.live(d)
            path = backup.backup(db, os.path.join(d, "backups"), now=NOON)
            self.call("DELETE", "/v1/me", token=a["token"])
            self.s.db.close()
            os.replace(path, os.path.join(d, "restore.sqlite"))
            out = self.boot(d, db)
            self.assertEqual(out.returncode, 0, out.stderr)
            self.assertIn('"restored"', out.stdout)
            self.assertTrue(os.path.exists(os.path.join(d, "restore.sqlite.done")), "not restored again on the next boot")
            self.assertEqual(backup.verify(db)["counts"]["players"], 2)
            self.assertEqual(self.boot(d, db).returncode, 0, "nothing waiting: the boot goes on")

    def test_a_bad_backup_left_for_the_boot_keeps_the_database(self):
        with tempfile.TemporaryDirectory() as d:
            db, _ = self.live(d)
            self.s.db.close()
            with open(os.path.join(d, "restore.sqlite"), "wb") as f:
                f.write(b"garbage" * 50)
            out = self.boot(d, db)
            self.assertEqual(out.returncode, 0, "the service still starts")
            self.assertIn('"restore_failed"', out.stdout)
            self.assertTrue(os.path.exists(os.path.join(d, "restore.sqlite.failed")))
            self.assertEqual(backup.verify(db)["counts"]["players"], 2)


if __name__ == "__main__":
    unittest.main()
