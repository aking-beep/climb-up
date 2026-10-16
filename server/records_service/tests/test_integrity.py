"""Tests for the stronger integrity checks: a log is accepted once, a real
log keeps a steady clock, and outliers wait for a moderator.

    python3 -m unittest discover -s server/records_service/tests -t .
"""

import os
import sqlite3
import tempfile

from server.records_service import admin, validate
from server.records_service import service as svc
from server.records_service.tests.test_service import Base, crag_send, expedition


def faster(e, scale):
    """The same climb at `scale` of its time: still a possible climb, with
    the height sampled as often as the game samples it."""
    for ev in e["payload"]["events"][1:]:
        ev[0] = round(ev[0] * scale, 2)
    e["payload"]["go"]["seconds"] = int(e["payload"]["events"][-1][0])
    return e


class Replays(Base):
    def test_another_players_log_is_refused(self):
        a = self.player(name="Real Climber")
        b = self.player(name="Copycat")
        e = crag_send()
        code, out = self.submit(a["token"], e)
        self.assertTrue(out["ok"], out)
        code, out = self.submit(b["token"], e)
        self.assertFalse(out["ok"])
        self.assertIn("already submitted", out["reason"])
        board = self.call("GET", "/v1/leaderboards/crag/warm-up")[1]["entries"]
        self.assertEqual([x["player"] for x in board], ["Real Climber"])

    def test_the_same_log_under_a_new_id_is_refused(self):
        a = self.player(name="Twice")
        e = crag_send()
        self.assertTrue(self.submit(a["token"], e)[1]["ok"])
        code, out = self.submit(a["token"], e)
        self.assertFalse(out["ok"])
        self.assertEqual(self.s.db.execute("SELECT COUNT(*) FROM crag_attempts").fetchone()[0], 1)

    def test_a_retry_of_the_same_submission_is_still_the_same_answer(self):
        a = self.player(name="Patient")
        e = crag_send()
        first = self.submit(a["token"], e)[1]
        again = self.submit(a["token"], e, new_id=False)[1]
        self.assertTrue(first["ok"] and again["ok"] and again["duplicate"])


class SteadyClock(Base):
    def rejected(self, e, words):
        p = self.player(name="Forger %d" % self.n)
        code, out = self.submit(p["token"], e)
        self.assertFalse(out["ok"], out)
        self.assertIn(words, out["reason"])

    def test_the_games_logs_keep_a_steady_clock(self):
        from server.records_service.tests.test_service import FIXTURE
        for e in FIXTURE:
            if e["kind"] == "crag":
                validate.check_crag(e["payload"])

    def test_a_log_that_goes_quiet(self):
        e = crag_send()
        ev = e["payload"]["events"]
        # Four seconds with nothing logged but the clips either side.
        e["payload"]["events"] = [x for x in ev if not (x[1] != "clip" and 12 <= x[0] < 15.9)]
        self.rejected(e, "gap")

    def test_a_log_with_too_few_height_samples(self):
        e = crag_send()
        hs = [i for i, x in enumerate(e["payload"]["events"]) if x[1] == "h"]
        drop = set(hs[1::2])   # every other sample: no long gap, half the samples
        e["payload"]["events"] = [x for i, x in enumerate(e["payload"]["events"]) if i not in drop]
        self.rejected(e, "height samples")

    def test_a_time_longer_than_the_log(self):
        e = crag_send()
        e["payload"]["go"]["seconds"] += 4
        self.rejected(e, "clock does not match")


class Review(Base):
    def board(self):
        return [(x["player"], x["seconds"]) for x in self.call("GET", "/v1/leaderboards/crag/warm-up")[1]["entries"]]

    def three_climbers(self):
        for name in ("Ann", "Bea", "Cyd"):
            self.assertTrue(self.submit(self.player(name=name)["token"], crag_send())[1]["ok"])

    def test_a_send_far_ahead_of_the_board_waits_for_a_moderator(self):
        self.three_climbers()
        quick = self.player(name="Quick")
        code, out = self.submit(quick["token"], faster(crag_send(), 0.7))
        self.assertTrue(out["ok"], "accepted, so the game stops sending it")
        self.assertTrue(out["held"])
        self.assertFalse(out["verified"])
        self.assertNotIn("Quick", [p for p, _ in self.board()])
        held = admin.review(self.s)
        self.assertEqual(len(held), 1)
        self.assertEqual(held[0]["player"], "Quick")
        self.assertEqual(admin.stats(self.s)["heldForReview"], 1)

        self.assertTrue(admin.decide(self.s, held[0]["ref"], True)["ok"])
        self.assertEqual(self.board()[0][0], "Quick", "approved: on the board, first")
        self.assertEqual(admin.review(self.s), [])

    def test_a_refused_outlier_stays_off_the_boards(self):
        self.three_climbers()
        quick = self.player(name="Quick")
        self.submit(quick["token"], faster(crag_send(), 0.7))
        ref = admin.review(self.s)[0]["ref"]
        self.assertTrue(admin.decide(self.s, ref, False)["ok"])
        self.assertNotIn("Quick", [p for p, _ in self.board()])
        self.assertIn("error", admin.decide(self.s, ref, True), "a refused record is decided")

    def test_an_approved_first_ascent_keeps_its_own_time(self):
        quick = self.player(name="Quick")
        # Nobody else on the board yet: nothing to be an outlier against.
        code, out = self.submit(quick["token"], faster(crag_send(), 0.7))
        self.assertTrue(out["verified"] and out["firstVerifiedAscent"])

    def test_a_close_time_is_not_held(self):
        self.three_climbers()
        p = self.player(name="Good Day")
        code, out = self.submit(p["token"], faster(crag_send(), 0.9))
        self.assertTrue(out["verified"], out)
        self.assertFalse(out.get("held", False))

    def test_an_expedition_far_above_the_board_is_held(self):
        def with_team(home):
            e = expedition()
            pl = e["payload"]
            pl["run"]["teamHome"] = home
            pl["run"]["points"] = validate.leader_points(pl["state"], pl["route"], home)
            return e
        for name in ("Ann", "Bea", "Cyd"):
            self.assertTrue(self.submit(self.player(name=name)["token"], with_team(2))[1]["ok"])
        top = self.player(name="Top")
        code, out = self.submit(top["token"], with_team(4))
        self.assertTrue(out["ok"] and out["held"], out)
        board = self.call("GET", "/v1/leaderboards/expedition/standard")[1]["entries"]
        self.assertNotIn("Top", [x["player"] for x in board])
        ref = admin.review(self.s)[0]["ref"]
        self.assertTrue(ref.startswith("expedition:"))
        admin.decide(self.s, ref, True)
        board = self.call("GET", "/v1/leaderboards/expedition/standard")[1]["entries"]
        self.assertEqual(board[0]["player"], "Top")


class OldDatabases(Base):
    def test_a_database_from_before_the_checks_opens_and_keeps_its_records(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "old.sqlite")
            db = sqlite3.connect(path)
            db.executescript(svc.SCHEMA)
            db.execute("INSERT INTO players VALUES ('p1','h',1,'adult','Old Timer','oldtimer','public','FRIEND01')")
            db.execute("INSERT INTO crag_attempts VALUES ('p1','s1','warm-up',1,40,0,31,'onsight',1)")
            db.commit()
            db.close()
            s = svc.Service(path)
            self.assertEqual([e["player"] for e in s.crag_board("warm-up")], ["Old Timer"])
            s.db.close()
