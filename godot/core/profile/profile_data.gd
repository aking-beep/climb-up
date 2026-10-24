class_name ProfileData
extends RefCounted
## What the profile shows, worked out from the records the game already
## keeps (Crag progress and achievements, the expedition runs in Records,
## the knowledge checks in Profile). Read-only: nothing here is stored.

## Grades in order, easiest first, for "best grade sent".
const GRADE_ORDER := ["Lesson", "4", "5a", "5b", "5c", "6a", "6a+", "6b", "6b+", "6c", "6c+", "7a"]


static func summary() -> Dictionary:
	var sends := 0
	var clean := 0
	var top := ""
	for r in Crag.ROUTES:
		var rec := Crag.record(r["id"])
		if int(rec["sends"]) > 0:
			sends += 1
			if String(rec["best"]) in Logbook.CLEAN:
				clean += 1
			if r["grade"] != "Lesson" and GRADE_ORDER.find(r["grade"]) > GRADE_ORDER.find(top):
				top = r["grade"]
	var runs: Array = Records.data.get("expedition", {}).get("runs", [])
	var best_points := -1
	var artifacts := 0
	var home := 0
	for run in runs:
		best_points = maxi(best_points, int(run.get("points", run.get("score", 0))))
		artifacts = maxi(artifacts, int(run.get("artifacts", 0)))
		if bool(run.get("returned", false)):
			home += 1
	var dailies := 0
	for d in Crag.daily.get("days", {}):
		if int(Crag.daily["days"][d].get("sends", 0)) > 0:
			dailies += 1
	var s := {
		"stars": Crag.total_stars(), "starsOf": Crag.ROUTES.size() * 3,
		"sends": sends, "clean": clean, "routes": Crag.ROUTES.size(), "topGrade": top,
		"achievements": Crag.achievements.size(), "achievementsOf": Logbook.ACHIEVEMENTS.size(),
		"expeditions": runs.size(), "summits": Unlocks.summits(), "home": home,
		"bestPoints": best_points, "artifacts": artifacts, "dailies": dailies,
		"knowledge": Profile.knowledge_right(), "knowledgeOf": KnowledgeChecks.CARDS.size(),
		"looks": CosmeticCatalog.open_count(),
	}
	s["title"] = title_for(s)
	return s


## A title that says what you have done, never more.
static func title_for(s: Dictionary) -> String:
	if int(s["summits"]) > 0 and GRADE_ORDER.find(String(s["topGrade"])) >= GRADE_ORDER.find("6c"):
		return "Mountaineer"
	if int(s["summits"]) > 0:
		return "Summiteer"
	if GRADE_ORDER.find(String(s["topGrade"])) >= GRADE_ORDER.find("6a"):
		return "Sport climber"
	if int(s["sends"]) > 1:
		return "Crag climber"
	if int(s["sends"]) > 0 or int(s["expeditions"]) > 0:
		return "Beginner"
	return "New climber"


## One line for the hub's profile chip.
static func chip_line(s: Dictionary) -> String:
	var bits: Array[String] = []
	if String(s["topGrade"]) != "":
		bits.append(String(s["topGrade"]))
	if int(s["summits"]) > 0:
		bits.append("%d summit%s" % [int(s["summits"]), "" if int(s["summits"]) == 1 else "s"])
	if bits.size() < 2:
		bits.append("%d of %d stars" % [int(s["stars"]), int(s["starsOf"])])
	return " · ".join(bits)
