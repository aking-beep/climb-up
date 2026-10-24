class_name Briefing
extends RefCounted
## The weather briefing (CLIMB UP 2.0): what each played climb on a route
## will be like, read from the level's own spec (its temperatures, its
## weather, its dangers) so the briefing can never say something the climb
## does not do. Lena gives it at camp; the prep screen shows it too.

const CLIMBS := ["lava-tower", "barranco-wall", "summit-night"]

static var _cache: Dictionary = {}


## {place, meters, low, high, weather ("", "rain", "sleet"), dangers, wind}
static func for_climb(climb: String, route: String) -> Dictionary:
	var key := "%s:%s" % [climb, route]
	if _cache.has(key):
		return _cache[key]
	var path: String = Expedition.LEVELS.get(climb, "")
	if path == "":
		return {}
	var script: Script = load(path.replace(".tscn", ".gd"))
	var level: Node = script.new()
	level.apply_route(route)
	var spec: Dictionary = level.spec
	var temps: Array = spec.get("climate", {}).get("temps", [[0.0, 10.0]])
	var low := 999.0
	var high := -999.0
	for t in temps:
		low = minf(low, float(t[1]))
		high = maxf(high, float(t[1]))
	var out := {
		"climb": climb, "place": Places.climb_name(climb, route), "meters": int(spec.get("meters", 0)),
		"low": low, "high": high, "weather": String(spec.get("theme", {}).get("weather", "")),
		"dangers": spec.get("dangers", []).duplicate(), "wind": float(spec.get("difficulty", {}).get("wind", 0.0)) != 0.0,
	}
	level.free()
	_cache[key] = out
	return out


## One line a guide would say about it.
static func line(b: Dictionary) -> String:
	var bits: Array[String] = []
	bits.append("%d to %d °C" % [int(b["low"]), int(b["high"])])
	match String(b["weather"]):
		"rain":
			bits.append("showers: downpours make wet rock cost more. Wait them out under rock")
		"sleet":
			bits.append("sleet and cold hands")
	if float(b["low"]) <= 0.0:
		bits.append("below freezing: rests give back less")
	elif float(b["high"]) >= Climate.WARM:
		bits.append("hot: every move costs a little more")
	if bool(b["wind"]):
		bits.append("gusts on the exposed bits: rest until they pass")
	var sentences: Array[String] = []
	for b2 in bits:
		sentences.append(b2.left(1).to_upper() + b2.substr(1))
	return ". ".join(sentences) + "."


## The gear that answers this climb's weather best (for the prep screen's
## hint): [slot, item id] pairs, from what is open to you.
static func gear_hints(b: Dictionary) -> Array:
	var out: Array = []
	if String(b["weather"]) == "rain":
		out.append(["clothing", "hardshell"])
		out.append(["rope", "dry"])
	if float(b["low"]) <= 0.0:
		out.append(["clothing", "down"])
		out.append(["supplies", "thermos"])
	if not (b["dangers"] as Array).filter(func(d: String) -> bool: return "stone" in d or "rock" in d).is_empty():
		out.append(["helmet", "alpine-helmet"])
	return out.filter(func(h: Array) -> bool: return EquipmentCatalog.open(EquipmentCatalog.item(h[0], h[1])))


## The camp's sky now, a pure function of the expedition's state: how
## much cloud and rain to draw (0..1) and whether it is night.
static func sky(state: Dictionary) -> Dictionary:
	var risk := clampf(float(state.get("weatherRisk", 0)) / 100.0, 0.0, 1.0)
	var hour := fposmod(float(state.get("elapsedHours", 0.0)) + 8.0, 24.0)
	return {"cloud": clampf(risk * 1.4, 0.0, 1.0), "rain": clampf((risk - 0.45) * 2.0, 0.0, 1.0),
		"night": hour < 6.0 or hour >= 19.0, "hour": hour}


static func risk_words(state: Dictionary) -> String:
	var r := int(state.get("weatherRisk", 0))
	if r >= 60:
		return "Bad weather coming: high wind and storms on the upper mountain."
	if r >= 35:
		return "Unsettled: cloud building in the afternoons, showers likely."
	return "Settled: clear mornings, light wind."
