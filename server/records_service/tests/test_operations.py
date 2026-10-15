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
        env = {"REMOTE_ADDR": "10.0.0.2", "HTTP_X_FORWARDED_FOR": "198.51.100.7, 10.0.0.2"}
        self.assertEqual(svc._client_address(env, True), "198.51.100.7")
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


if __name__ == "__main__":
    unittest.main()
