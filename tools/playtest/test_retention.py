"""Tests for tools/playtest/retention.py on made-up usage logs.

    python3 -m unittest discover -s tools/playtest
"""

import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(__file__))
import retention  # noqa: E402

DAY = 86400
T0 = 1792000000 - 1792000000 % DAY + 10 * 3600   # 10:00 UTC on a day


def ev(name, t, **p):
    return json.dumps({"e": name, "t": t, "s": "x", "p": p})


def write(d, name, lines):
    with open(os.path.join(d, name), "w") as f:
        f.write("\n".join(lines) + "\n")


class Retention(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp()
        # Ann: tutorial, a graded send and a replay, back on day 2 and day 7.
        write(self.d, "ann.jsonl", [
            ev("game_launched", T0), ev("tutorial_started", T0 + 10), ev("tutorial_completed", T0 + 130),
            ev("route_started", T0 + 140, route="warm-up"), ev("route_failed", T0 + 170, route="warm-up"),
            ev("route_started", T0 + 180, route="warm-up"), ev("route_completed", T0 + 220, route="warm-up"),
            ev("route_replayed", T0 + 230, route="warm-up", sent_before=True),
            ev("session_ended", T0 + 400, seconds=400),
            ev("game_launched", T0 + DAY), ev("daily_started", T0 + DAY + 5), ev("session_ended", T0 + DAY + 200, seconds=200),
            ev("game_launched", T0 + 6 * DAY), ev("expedition_started", T0 + 6 * DAY + 5),
            ev("expedition_completed", T0 + 6 * DAY + 900, returned=True, summit=False),
        ])
        # Bea: one day, starts the tutorial and leaves.
        write(self.d, "bea.jsonl", [ev("game_launched", T0 + 3600), ev("tutorial_started", T0 + 3700),
                                    "{torn line", ev("session_ended", T0 + 3800, seconds=100)])
        # Cyd, at UTC-8: 15:30 and 21:30 the same day for them, but either
        # side of midnight in UTC.
        late = T0 + 13 * 3600 + 1800   # 23:30 UTC = 15:30 at UTC-8
        write(self.d, "cyd.jsonl", [ev("game_launched", late), ev("game_launched", late + 6 * 3600)])
        # An empty paste.
        write(self.d, "dan.jsonl", [""])

    def test_the_plans_measures(self):
        out = retention.report(self.d)
        m = out["all"]
        self.assertEqual(m["testers"], 3)
        self.assertEqual(out["skipped"], ["dan.jsonl"], "a log with no launch is not a tester")
        self.assertEqual((m["tutorial_completion"]["n"], m["tutorial_completion"]["of"]), (1, 2))
        self.assertEqual(m["tutorial_median_seconds"], 130)
        self.assertEqual((m["day1_retention"]["n"], m["day7_retention"]["n"]), (2, 1))
        self.assertEqual(m["voluntary_replay"]["pct"], 100.0)
        self.assertEqual(m["routes"]["warm-up"]["completion"]["n"], 1)
        self.assertEqual(m["routes"]["warm-up"]["median_attempts_to_send"], 2)
        self.assertEqual((m["retreat_rate"]["n"], m["expedition_safe_return"]["n"]), (1, 1))
        self.assertEqual(m["median_session_seconds"], 200)

    def test_days_are_the_testers_own(self):
        csv = os.path.join(self.d, "..", "testers-%d.csv" % os.getpid())
        with open(csv, "w") as f:
            f.write("file,utc_offset,group\nann.jsonl,0,A\nbea.jsonl,0,A\ncyd.jsonl,-8,B\n")
        utc = retention.report(self.d)
        local = retention.report(self.d, csv)
        cyd_utc = retention.tester_facts(retention.read_log(os.path.join(self.d, "cyd.jsonl")), 0)
        cyd_local = retention.tester_facts(retention.read_log(os.path.join(self.d, "cyd.jsonl")), -8)
        self.assertTrue(cyd_utc["d1"], "in UTC the second launch is the next day")
        self.assertFalse(cyd_local["d1"], "at UTC-8 both launches are the same afternoon and evening")
        self.assertEqual(utc["all"]["day1_retention"]["n"] - 1, local["all"]["day1_retention"]["n"])
        self.assertIn("fewer than", local["groups"]["A"]["note"], "groups under 8 are not reported alone")
        os.remove(csv)

    def test_the_printed_report_gives_counts(self):
        buf = io.StringIO()
        retention.print_report(retention.report(self.d), file=buf)
        text = buf.getvalue()
        self.assertIn("Day 1 retention", text)
        self.assertIn("2 of 3", text)
        self.assertIn("benchmark 35-40%", text)


if __name__ == "__main__":
    unittest.main()
