class_name Artifacts
extends RefCounted
## Artifacts: pieces of Kilimanjaro's history and culture hidden on the
## played climbs. Each climb has two for each route (the long, faster and
## fastest way: easy, medium, hard), so a different expedition finds
## different ones. They are placed on the climb's most dangerous ground,
## and they are hard to keep:
##
## - a slip that counts drops every artifact you carry back where you
##   found it, and a raven can snatch one;
## - they are yours only when the climb ends without failing (the top, or
##   a retreat you walk down from); a failed climb leaves them behind;
## - they count only when the expedition comes home safely: each is worth
##   POINTS leader points at the end (Records.leader_points, and the
##   records service's validate.leader_points).
##
## The words are short histories for the game, checked against common
## sources; they are not a guidebook.

const POINTS := 6
const PER_CLIMB := 2
const CLIMBS := ["lava-tower", "barranco-wall", "summit-night", "descent"]
## The most one expedition can bring home: two on each of the four climbs.
const MAX := 8

## {climb: {route: [[name, story, [x, y]], ...]}}. Cells are standable
## ground on the climb's own line (tools: the level tests' bot walks over
## every one), on its most dangerous stretches; the fastest way gets the
## worst of them.
const DATA := {
	"lava-tower": {
		"lemosho": [
			["a Chagga honey barrel", "Chagga families kept bees in hollowed logs hung high in the forest trees on the mountain's slopes. Honey was both food and medicine.", [58, 13]],
			["a porter's head strap", "Most of what reaches a high camp is carried by porters. The park limits a porter's load to 20 kg, and porters' groups work for fair pay and proper gear.", [43, 51]],
		],
		"machame": [
			["a stone from a mfongo", "The Chagga dug mifongo, furrows that lead water from the mountain's streams for kilometres along the slopes to their banana gardens. Some are very old and still run.", [131, 23]],
			["a shard of Shira rock", "Kilimanjaro is three volcanoes. Shira, to the west, is the oldest and has fallen in; Mawenzi is jagged and worn; Kibo, the youngest, holds the summit.", [120, 22]],
		],
		"umbwe": [
			["Rebmann's sketch", "In 1848 the missionary Johannes Rebmann reported snow on a mountain almost on the equator. Geographers in London doubted him. He was right.", [103, 13]],
			["a Maasai cowbell", "Maasai herders graze cattle on the dry plains below the mountain's north and west sides, across into Kenya, as they have for generations.", [93, 13]],
		],
	},
	"barranco-wall": {
		"lemosho": [
			["a kihamba banana leaf", "A Chagga kihamba is a home garden of bananas, coffee, beans and tall shade trees, layered like a forest. The UN food agency lists the system among the world's agricultural heritage.", [83, 73]],
			["a coffee bean pouch", "Missionaries planted coffee on the slopes in the 1890s. In the early 1930s Chagga growers formed the Kilimanjaro Native Cooperative Union, one of Africa's oldest cooperatives.", [142, 11]],
		],
		"machame": [
			["a mangi's staff", "The Chagga lived in many small chiefdoms, each led by a mangi. In the 1800s rulers such as Rindi of Moshi and Sina of Kibosho made alliances and fought for trade.", [176, 8]],
			["a caravan trade bead", "In the 1800s caravans from the Swahili coast passed the mountain trading cloth and glass beads for ivory. Beads served as money along the way.", [81, 59]],
		],
		"umbwe": [
			["Yohani Lauwo's walking stick", "Yohani Kinyala Lauwo, a young Chagga man from Marangu, guided Hans Meyer and Ludwig Purtscheller on the first recorded climb to the summit in October 1889.", [85, 25]],
			["Purtscheller's ice axe", "Ludwig Purtscheller, an Austrian alpinist, reached the top with Hans Meyer on 6 October 1889. They called it Kaiser-Wilhelm-Spitze; in 1961 it was renamed Uhuru Peak.", [197, 15]],
		],
	},
	"summit-night": {
		"lemosho": [
			["a summit certificate", "The park gives climbers a certificate: one for reaching the crater rim at Gilman's or Stella Point, and a gold one for Uhuru Peak, the summit.", [17, 58]],
			["a word for the mountain", "Nobody is sure where the name Kilimanjaro comes from. One guess joins the Swahili kilima, a hill, with njaro, a word that may mean whiteness or greatness.", [101, 85]],
		],
		"machame": [
			["a note from Leopard Point", "In 1926 the pastor Richard Reusch found a frozen leopard high on the crater rim. Nobody knows why it climbed so high. Hemingway's story The Snows of Kilimanjaro opens with it.", [72, 49]],
			["a flame of the Uhuru Torch", "At Tanganyika's independence in December 1961 a torch was lit on the summit, and the highest point became Uhuru Peak: uhuru means freedom.", [18, 40]],
		],
		"umbwe": [
			["an ice core marker", "In 2000 scientists drilled through the summit glaciers. The oldest ice was about 11,700 years old. Most of the ice mapped in 1912 has since melted.", [57, 76]],
			["Nyerere's candle", "In 1959 Julius Nyerere said Tanganyika would light a candle on top of Kilimanjaro to shine beyond its borders: hope where there was despair, dignity where there was humiliation.", [88, 58]],
		],
	},
	"descent": {
		"lemosho": [
			["a stretcher wheel", "Rangers bring sick climbers down on one-wheeled stretchers, run fast down the trail. Going down is the cure for altitude sickness.", [101, 45]],
			["a porters' song", "Guides and porters sing to climbers: Jambo, jambo bwana, and Kilimanjaro, mlima mrefu sana, a very tall mountain.", [137, 57]],
		],
		"machame": [
			["a park ranger's badge", "Kilimanjaro National Park was set up in 1973, and in 1987 the mountain became a UNESCO World Heritage Site.", [41, 13]],
			["a Mawenzi ember", "A Chagga story tells how Mawenzi kept letting his fire go out and asking Kibo for embers, until Kibo lost patience and beat him. That is why Mawenzi is jagged.", [112, 56]],
		],
		"umbwe": [
			["a lamp from the Chagga caves", "In the 1800s Chagga families dug tunnels under their homesteads to hide from raids. Some, near Marangu, can still be walked.", [81, 37]],
			["an mbege gourd", "Mbege is the Chagga beer of fermented bananas and millet, brewed for weddings, births and the settling of disputes.", [69, 31]],
		],
	},
}


## The route's two for a climb: [[name, story, [x, y]], ...]. A session with
## no route chosen (the level tests) counts as the long way.
static func for_climb(climb: String, route: String) -> Array:
	var by_route: Dictionary = DATA.get(climb, {})
	return by_route.get(route if by_route.has(route) else "lemosho", [])


static func _kept(session: Dictionary) -> Dictionary:
	var t := Trek.ensure(session)
	if typeof(t.get("artifacts")) != TYPE_DICTIONARY:
		t["artifacts"] = {}
	return t["artifacts"]


## Indices (into for_climb) kept from this climb on this expedition.
static func kept_on(session: Dictionary, climb: String) -> Array:
	var list: Variant = _kept(session).get(climb, [])
	if typeof(list) != TYPE_ARRAY:
		return []
	return list.map(func(i: Variant) -> int: return int(i))


## Keeps what the climb ended with (it did not fail).
static func keep(session: Dictionary, climb: String, indices: Array) -> void:
	var list: Array = kept_on(session, climb).duplicate()
	for i in indices:
		if not list.has(int(i)) and int(i) >= 0 and int(i) < PER_CLIMB:
			list.append(int(i))
	_kept(session)[climb] = list


## Every artifact kept on this expedition: [{climb, name, story}], in the
## order of the climbs.
static func kept(session: Dictionary) -> Array:
	var route := String(Trek.ensure(session).get("route", ""))
	var out: Array = []
	for climb in CLIMBS:
		var words := for_climb(climb, route)
		for i in kept_on(session, climb):
			if int(i) < words.size():
				out.append({"climb": climb, "name": words[int(i)][0], "story": words[int(i)][1]})
	return out


static func count(session: Dictionary) -> int:
	return mini(kept(session).size(), MAX)
