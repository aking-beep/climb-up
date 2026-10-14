"""Tests for the reference records service: real client submissions (from
the Godot game, tests/fixtures/client_queue.json), duplicates and retries,
ties, cheating attempts, firsts by server time, late offline dailies,
account deletion, ages, names, friends, and the HTTP layer.

    python3 -m unittest discover -s server/records_service/tests -t .
"""

import copy
import io
import json
import threading
import unittest
import urllib.request
from pathlib import Path
from wsgiref.simple_server import make_server, WSGIRequestHandler

from server.records_service import service as svc

FIXTURE = json.loads((Path(__file__).parent / "fixtures" / "client_queue.json").read_text())
NOON = 1791892800  # 2026-10-13 12:00 UTC


def entry(kind, route=None):
    for e in FIXTURE:
        if e["kind"] == kind and (route is None or e["payload"].get("route") == route) and (kind != "crag" or e["payload"]["go"]["sent"] or route == "fail"):
            return copy.deepcopy(e)
    raise KeyError(kind)


def crag_send(route="warm-up"):
    return next(copy.deepcopy(e) for e in FIXTURE if e["kind"] == "crag" and e["payload"]["route"] == route and e["payload"]["go"]["sent"])


def crag_fail():
    return next(copy.deepcopy(e) for e in FIXTURE if e["kind"] == "crag" and not e["payload"]["go"]["sent"])


def expedition():
    return next(copy.deepcopy(e) for e in FIXTURE if e["kind"] == "expedition")


class Base(unittest.TestCase):
    def setUp(self):
        self.now = NOON
        self.s = svc.Service(":memory:", clock=lambda: self.now)
        self.app = svc.make_app(self.s)
        self.n = 0

    def call(self, method, path, body=None, token=None, query=""):
        raw = json.dumps(body).encode() if body is not None else b""
        env = {"REQUEST_METHOD": method, "PATH_INFO": path, "QUERY_STRING": query, "CONTENT_LENGTH": str(len(raw)),
               "wsgi.input": io.BytesIO(raw)}
        if token:
            env["HTTP_AUTHORIZATION"] = "Bearer " + token
        status = {}

        def start(s, headers):
            status["code"] = int(s.split()[0])
        out = b"".join(self.app(env, start))
        return status["code"], (json.loads(out) if out else {})

    def player(self, age=30, name=None):
        body = {"age": age}
        if name:
            body["displayName"] = name
        code, out = self.call("POST", "/v1/players", body)
        self.assertEqual(code, 201, out)
        return out

    def submit(self, token, e, new_id=True):
        if new_id:
            self.n += 1
            e["id"] = "sub%08d" % self.n
        e["clientTime"] = self.now
        return self.call("POST", "/v1/submissions", {"id": e["id"], "kind": e["kind"], "clientTime": e["clientTime"], "payload": e["payload"]}, token)


class RealSubmissions(Base):
    def test_the_games_own_submissions_are_accepted_and_styled_by_the_server(self):
        p = self.player(name="Kibo Fan")
        for e in FIXTURE:
            code, out = self.submit(p["token"], copy.deepcopy(e))
            self.assertEqual(code, 200)
            self.assertTrue(out["ok"], out)
            self.assertTrue(out["verified"])
        code, out = self.call("GET", "/v1/leaderboards/crag/warm-up")
        self.assertEqual(out["entries"][0]["player"], "Kibo Fan")
        # The server named the style from its own count: the fail came after
        # the send in the fixture, so the send was the first go: an onsight.
        styles = [r["style"] for r in self.s.db.execute("SELECT style FROM crag_attempts WHERE board='warm-up' AND sent=1")]
        self.assertEqual(styles, ["onsight"])

    def test_a_claimed_style_is_ignored(self):
        p = self.player(name="Second Go")
        self.submit(p["token"], crag_fail())
        e = crag_send()
        e["payload"]["go"]["style"] = "onsight"
        code, out = self.submit(p["token"], e)
        self.assertEqual(out["style"], "redpoint", "not the first go on the route: a redpoint, whatever the client says")


class Duplicates(Base):
    def test_a_retried_submission_counts_once(self):
        p = self.player(name="Retry Rita")
        e = crag_send()
        code1, first = self.submit(p["token"], e)
        code2, again = self.submit(p["token"], e, new_id=False)
        self.assertTrue(first["ok"] and again["ok"])
        self.assertTrue(again.get("duplicate"))
        self.assertEqual(again["serverTime"], first["serverTime"], "the same answer as the first time")
        count = self.s.db.execute("SELECT COUNT(*) FROM crag_attempts").fetchone()[0]
        self.assertEqual(count, 1)

    def test_too_many_at_once_says_retry_later(self):
        p = self.player(name="Speedy")
        for _ in range(svc.RATE_LIMIT):
            self.submit(p["token"], crag_fail())
        code, out = self.submit(p["token"], crag_fail())
        self.assertEqual(code, 429)
        self.assertTrue(out["retry"])
        self.now += svc.RATE_WINDOW + 1
        code, out = self.submit(p["token"], crag_fail())
        self.assertEqual(code, 200)


class Ties(Base):
    def test_equal_times_share_a_rank_and_the_earlier_is_listed_first(self):
        a = self.player(name="Ann")
        b = self.player(name="Bea")
        c = self.player(name="Cyd")
        self.submit(a["token"], crag_send())
        self.now += 10
        self.submit(b["token"], crag_send())
        slow = crag_send()
        slow["payload"]["go"]["seconds"] += 5
        self.now += 10
        self.submit(c["token"], slow)
        code, out = self.call("GET", "/v1/leaderboards/crag/warm-up")
        ranks = [(e["player"], e["rank"]) for e in out["entries"]]
        self.assertEqual(ranks, [("Ann", 1), ("Bea", 1), ("Cyd", 3)])

    def test_a_players_best_counts_once(self):
        a = self.player(name="Ann")
        self.submit(a["token"], crag_send())
        faster = crag_send()
        self.submit(a["token"], faster)
        code, out = self.call("GET", "/v1/leaderboards/crag/warm-up")
        self.assertEqual(len(out["entries"]), 1)


class Cheating(Base):
    def rejected(self, e, words):
        p = self.player(name="Cheater %d" % self.n)
        code, out = self.submit(p["token"], e)
        self.assertFalse(out["ok"], out)
        self.assertIn(words, out["reason"])
        self.assertEqual(self.s.db.execute("SELECT COUNT(*) FROM crag_attempts").fetchone()[0], 0)

    def test_a_faster_time_than_the_log(self):
        e = crag_send()
        e["payload"]["go"]["seconds"] = 3
        self.rejected(e, "after the end")

    def test_an_impossibly_fast_send(self):
        e = crag_send()
        scale = 0.2
        e["payload"]["go"]["seconds"] = max(1, int(e["payload"]["go"]["seconds"] * scale))
        for ev in e["payload"]["events"]:
            ev[0] = round(ev[0] * scale, 2)
        self.rejected(e, "faster than")

    def test_a_missing_bolt(self):
        e = crag_send()
        e["payload"]["events"] = [ev for ev in e["payload"]["events"] if not (ev[1] == "clip" and ev[2][0] == 3)]
        self.rejected(e, "out of order")

    def test_a_send_without_every_bolt(self):
        e = crag_send()
        last = max(i for i, ev in enumerate(e["payload"]["events"]) if ev[1] == "clip")
        del e["payload"]["events"][last]
        self.rejected(e, "every bolt")

    def test_events_out_of_order(self):
        e = crag_send()
        ev = e["payload"]["events"]
        ev[2], ev[5] = ev[5], ev[2]
        self.rejected(e, "out of order")

    def test_hidden_falls(self):
        e = crag_send()
        e["payload"]["events"].insert(3, [e["payload"]["events"][3][0], "fall", ["pump", 4]])
        self.rejected(e, "falls do not match")

    def test_another_map(self):
        e = crag_send()
        e["payload"]["mapHash"] += 1
        self.rejected(e, "map does not match")

    def test_an_unknown_route(self):
        e = crag_send()
        e["payload"]["route"] = "the-moon"
        self.rejected(e, "unknown route")

    def test_a_forged_expedition_score(self):
        e = expedition()
        e["payload"]["run"]["score"] -= 1
        p = self.player(name="Forger")
        code, out = self.submit(p["token"], e)
        self.assertFalse(out["ok"])
        self.assertIn("score does not match", out["reason"])

    def test_a_padded_ledger(self):
        e = expedition()
        e["payload"]["state"]["ledger"]["judgment"].append({"label": "x", "delta": 50, "mark": "fake"})
        p = self.player(name="Padder")
        code, out = self.submit(p["token"], e)
        self.assertFalse(out["ok"])

    def test_a_clock_from_the_future(self):
        p = self.player(name="Time Traveller")
        e = crag_send()
        code, out = self.call("POST", "/v1/submissions", {"id": "future0001", "kind": "crag", "clientTime": self.now + 99999, "payload": e["payload"]}, p["token"])
        self.assertFalse(out["ok"])
        self.assertIn("clock", out["reason"])


class Firsts(Base):
    def test_first_by_the_servers_clock_not_the_device(self):
        a = self.player(name="Early Clock")
        b = self.player(name="On Time")
        self.submit(b["token"], crag_send())
        self.now += 60
        e = crag_send()
        code, out = self.call("POST", "/v1/submissions", {"id": "early0001", "kind": "crag", "clientTime": NOON - 86400, "payload": e["payload"]}, a["token"])
        self.assertTrue(out["ok"])
        self.assertFalse(out["firstVerifiedAscent"], "an earlier device clock does not make it first")
        code, firsts = self.call("GET", "/v1/firsts")
        self.assertEqual(firsts["firsts"][0]["display"], "On Time")

    def test_first_completion_of_the_expedition(self):
        a = self.player(name="Summiteer")
        code, out = self.submit(a["token"], expedition())
        self.assertTrue(out["firstVerifiedCompletion"])
        b = self.player(name="Next")
        code, out = self.submit(b["token"], expedition())
        self.assertFalse(out["firstVerifiedCompletion"])


class LeaderPoints(Base):
    """Expedition boards rank by leader points (validate.leader_points), the
    same numbers the game shows."""

    def with_team(self, home):
        from server.records_service import validate
        e = expedition()
        pl = e["payload"]
        pl["run"]["teamHome"] = home
        pl["run"]["points"] = validate.leader_points(pl["state"], pl["route"], home)
        e["id"] = "%s-%d" % (e["id"][:40], home)
        return e

    def test_the_game_and_the_server_agree(self):
        p = self.player(name="Agree")
        e = expedition()
        code, out = self.submit(p["token"], e)
        self.assertTrue(out["ok"], out)
        self.assertEqual(out["points"], e["payload"]["run"]["points"])
        self.assertGreater(out["points"], out["score"], "a whole team, quick and thrifty, earns more than the score")

    def test_forged_points_are_refused(self):
        p = self.player(name="Inflater")
        e = expedition()
        e["payload"]["run"]["points"] += 5
        code, out = self.submit(p["token"], e)
        self.assertFalse(out["ok"])
        self.assertIn("leader points", out["reason"])

    def test_nobody_is_home_from_a_run_that_did_not_come_down(self):
        p = self.player(name="Stranded")
        e = expedition()
        e["payload"]["state"]["returnedSafely"] = False
        e["payload"]["run"].pop("points")
        code, out = self.submit(p["token"], e)
        self.assertFalse(out["ok"])

    def test_the_whole_team_outranks_a_fast_summit_without_it(self):
        a = self.player(name="Together")
        b = self.player(name="Alone")
        code, out_b = self.submit(b["token"], self.with_team(2))
        code, out_a = self.submit(a["token"], self.with_team(4))
        self.assertTrue(out_a["ok"] and out_b["ok"])
        self.assertEqual(out_a["points"] - out_b["points"], 10 + 16 + 10 + 3, "team +10 vs -16, and speed and stores only with everyone")
        code, board = self.call("GET", "/v1/leaderboards/expedition/standard")
        self.assertEqual([e["player"] for e in board["entries"]], ["Together", "Alone"])
        self.assertEqual(board["entries"][0]["points"], out_a["points"])


class Offline(Base):
    def test_a_late_daily_go_from_offline_is_accepted_for_a_while(self):
        p = self.player(name="Offline Olly")
        e = crag_send("daily")
        self.now = NOON + 2 * 86400
        code, out = self.submit(p["token"], e)
        self.assertTrue(out["ok"], "two days late: still that day's board")
        self.now = NOON + 3 * 86400
        code, out = self.submit(p["token"], crag_send("daily"))
        self.assertFalse(out["ok"])
        self.assertIn("closed", out["reason"])
        code, board = self.call("GET", "/v1/leaderboards/daily/2026-10-13")
        self.assertEqual(len(board["entries"]), 1)


class Privacy(Base):
    def test_deleting_an_account_removes_it_and_anonymises_its_firsts(self):
        a = self.player(name="Leaver")
        self.submit(a["token"], crag_send())
        code, export = self.call("GET", "/v1/me/export", token=a["token"])
        self.assertEqual(len(export["crag_attempts"]), 1, "the player can see everything held")
        code, _ = self.call("DELETE", "/v1/me", token=a["token"])
        self.assertEqual(code, 204)
        code, board = self.call("GET", "/v1/leaderboards/crag/warm-up")
        self.assertEqual(board["entries"], [])
        code, firsts = self.call("GET", "/v1/firsts")
        self.assertEqual(firsts["firsts"][0]["display"], "a deleted account", "the first stays a first, with no name")
        code, _ = self.call("GET", "/v1/me/export", token=a["token"])
        self.assertEqual(code, 401, "the token no longer works")

    def test_under_13_stays_private(self):
        code, out = self.call("POST", "/v1/players", {"age": 11, "displayName": "Kid"})
        self.assertEqual(code, 403)
        kid = self.player(age=11)
        self.assertFalse(kid["publicName"])
        self.assertEqual(kid["visibility"], "private")
        code, out = self.submit(kid["token"], crag_send())
        self.assertTrue(out["ok"], "their climbs still count for them")
        code, board = self.call("GET", "/v1/leaderboards/crag/warm-up")
        self.assertEqual(board["entries"], [], "but not on a public board")
        code, out = self.call("PATCH", "/v1/me", {"visibility": "public"}, kid["token"])
        self.assertEqual(code, 403)
        code, out = self.call("POST", "/v1/friends", {"friendCode": "ABC"}, kid["token"])
        self.assertEqual(code, 403)

    def test_names_are_unique_without_case_or_spacing(self):
        self.player(name="Kibo Fan")
        code, out = self.call("POST", "/v1/players", {"age": 30, "displayName": "kibo_fan"})
        self.assertEqual(code, 409)
        code, out = self.call("POST", "/v1/players", {"age": 30, "displayName": "Official Climber"})
        self.assertEqual(code, 400)

    def test_an_age_is_needed(self):
        code, out = self.call("POST", "/v1/players", {})
        self.assertEqual(code, 400)


class Friends(Base):
    def test_a_friends_board_shows_only_friends(self):
        a = self.player(name="Ann")
        b = self.player(name="Bea")
        c = self.player(name="Cyd")
        for p in (a, b, c):
            self.submit(p["token"], crag_send())
        self.call("POST", "/v1/friends", {"friendCode": b["friendCode"]}, a["token"])
        code, out = self.call("GET", "/v1/leaderboards/crag/warm-up", token=a["token"], query="scope=friends")
        self.assertEqual(sorted(e["player"] for e in out["entries"]), ["Ann", "Bea"])
        code, out = self.call("GET", "/v1/leaderboards/crag/warm-up", query="scope=friends")
        self.assertEqual(code, 401)


class Http(Base):
    def test_over_real_http(self):
        class Quiet(WSGIRequestHandler):
            def log_message(self, *a):
                pass
        server = make_server("127.0.0.1", 0, self.app, handler_class=Quiet)
        port = server.server_address[1]
        t = threading.Thread(target=server.serve_forever, daemon=True)
        t.start()
        try:
            req = urllib.request.Request(f"http://127.0.0.1:{port}/v1/players", data=json.dumps({"age": 30, "displayName": "Net Ned"}).encode(),
                                         headers={"Content-Type": "application/json"}, method="POST")
            with urllib.request.urlopen(req) as r:
                me = json.loads(r.read())
            e = crag_send()
            req = urllib.request.Request(f"http://127.0.0.1:{port}/v1/submissions", method="POST",
                                         data=json.dumps({"id": "http00001", "kind": "crag", "clientTime": NOON, "payload": e["payload"]}).encode(),
                                         headers={"Authorization": "Bearer " + me["token"]})
            with urllib.request.urlopen(req) as r:
                out = json.loads(r.read())
            self.assertTrue(out["ok"])
            with urllib.request.urlopen(f"http://127.0.0.1:{port}/v1/leaderboards/crag/warm-up") as r:
                board = json.loads(r.read())
            self.assertEqual(board["entries"][0]["player"], "Net Ned")
        finally:
            server.shutdown()


if __name__ == "__main__":
    unittest.main()
