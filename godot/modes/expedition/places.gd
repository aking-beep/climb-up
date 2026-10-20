class_name Places
extends RefCounted
## Where each route goes. The three routes up are three different journeys,
## so each has its own camps and its own three played climbs (and its own
## way down): nine places in all, each with its own ground, weather,
## people's words, gear and artifacts (the levels' specs, by route).
##
##   the long way (Lemosho, easy):     the Shira Cathedral, the Karanga
##                                     Valley, Stella Point at night
##   the faster way (Machame, medium): the Lava Tower, the Barranco Wall,
##                                     the Southern Icefields
##   the fastest way (Umbwe, hard):    the Umbwe Ridge, the Arrow Glacier,
##                                     the Western Breach
##
## The expedition's engine and its cards are the Expo game's, kept exactly
## as they are (the parity test): they name the long way's camps and
## climbs. The camp screen shows them through say(), which puts each
## route's own names in their place.
##
## Inspired by the real routes; heights and order are the game's. Game
## fiction, not a guidebook.

## The climbs' names, by route: [name, title (in a sentence), metres].
const CLIMBS := {
	"lemosho": {
		"lava-tower": ["Shira Cathedral", "the Shira Cathedral", 3870],
		"barranco-wall": ["Karanga Valley", "the Karanga Valley", 4035],
		"summit-night": ["Stella Point", "the night to Stella Point", 5756],
		"descent": ["The Mweka path", "the way down", 4640],
	},
	"machame": {
		"lava-tower": ["Lava Tower", "the Lava Tower", 4630],
		"barranco-wall": ["Barranco Wall", "the Barranco Wall", 4200],
		"summit-night": ["The Southern Icefields", "the Southern Icefields", 5895],
		"descent": ["Down through the cloud", "the way down", 4640],
	},
	"umbwe": {
		"lava-tower": ["Umbwe Ridge", "the Umbwe Ridge", 3850],
		"barranco-wall": ["Arrow Glacier", "the Arrow Glacier", 4870],
		"summit-night": ["The Western Breach", "the Western Breach", 5895],
		"descent": ["Down in the storm", "the way down", 4640],
	},
}

## The camps' names, by route (the engine's stop ids).
const STOPS := {
	"lemosho": {},
	"machame": {"briefing": "Machame Gate", "approach": "Machame Camp", "ebc": "Shira Cave Camp"},
	"umbwe": {"briefing": "Umbwe Gate", "approach": "Umbwe Cave Camp", "ebc": "Umbwe Ridge Camp",
		"camp1": "Upper Umbwe Camp", "camp3": "Lava Tower Camp", "camp4": "Arrow Glacier Camp"},
}

## The engine's words for the long way's places, and what each route
## calls them instead. Longest first, so "the Lava Tower" goes before
## "Lava Tower".
const SAY := {
	"lemosho": [
		["the Lava Tower", "the Shira Cathedral"], ["Lava Tower", "the Shira Cathedral"],
		["the Barranco Wall", "the Karanga Valley"], ["Barranco Wall", "Karanga Valley"],
	],
	"machame": [
		["Londorossi Gate", "Machame Gate"], ["Mti Mkubwa Camp", "Machame Camp"], ["Mti Mkubwa", "Machame Camp"],
		["Big Tree", "Machame Camp"], ["Shira 1 Camp", "Shira Cave Camp"], ["Shira 1", "Shira Cave"],
		["the summit night", "the Southern Icefields"],
	],
	"umbwe": [
		["Londorossi Gate", "Umbwe Gate"], ["Mti Mkubwa Camp", "Umbwe Cave Camp"], ["Mti Mkubwa", "Umbwe Cave"],
		["Big Tree", "Umbwe Cave"], ["Shira 1 Camp", "Umbwe Ridge Camp"], ["Shira 1", "the Umbwe Ridge camp"],
		["Shira 2 Camp", "Upper Umbwe Camp"], ["Shira 2", "Upper Umbwe"], ["the Shira Plateau", "the Umbwe Ridge"],
		["the Lava Tower", "the Umbwe Ridge"], ["Lava Tower", "the Umbwe Ridge"],
		["the Barranco Wall", "the Arrow Glacier"], ["Barranco Wall", "Arrow Glacier"],
		["Karanga Camp", "Lava Tower Camp"], ["Karanga", "Lava Tower Camp"],
		["Barafu Camp", "Arrow Glacier Camp"], ["Barafu", "Arrow Glacier Camp"],
		["the summit night", "the Western Breach"], ["Stella Point", "the crater rim"],
	],
}


static func route_of(session: Dictionary) -> String:
	var r := String(Trek.ensure(session).get("route", ""))
	return r if CLIMBS.has(r) else "lemosho"


## The played climb's name on this route ("Umbwe Ridge").
static func climb_name(climb: String, route: String) -> String:
	return String(CLIMBS.get(route, CLIMBS["lemosho"]).get(climb, [climb])[0])


static func climb_title(climb: String, route: String) -> String:
	return String(CLIMBS.get(route, CLIMBS["lemosho"]).get(climb, ["", climb])[1])


## A camp's name on this route.
static func stop_name(id: String, route: String) -> String:
	return String(STOPS.get(route, {}).get(id, Kili.checkpoint_name(id)))


## The engine's text with this route's names in it.
static func say(text: String, route: String) -> String:
	var out := text
	for pair in SAY.get(route, []):
		out = out.replace(pair[0], pair[1])
	return out


## The camp's text with the chosen route's names (none before a route is
## chosen: the engine's own words).
static func say_now(text: String) -> String:
	return say(text, String(Trek.ensure(Expedition.session).get("route", "")))


## How each route's camp looks on the diorama: a tint over the plate (the
## long way's warm gold, the faster way's plain light, the fastest way's
## wet, green forest grey) and extra weather.
const LOOK := {
	"lemosho": {"tint": "#fff0d4", "weather": 0.0},
	"machame": {"tint": "#ffffff", "weather": 0.1},
	"umbwe": {"tint": "#cfe0d4", "weather": 0.3},
}


static func look(route: String) -> Dictionary:
	return LOOK.get(route, {"tint": "#ffffff", "weather": 0.0})
