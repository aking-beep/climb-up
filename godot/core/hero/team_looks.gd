class_name TeamLooks
extends RefCounted
## How the people on the mountain look, drawn with the same rig as you
## (design/magic-patterns/team.ts): Lena the guide, Marco and Jun, and the
## camp crew. Fixed looks; only yours changes.

const LOOKS := {
	"lena": {"jacket": "#3f6f8a", "jacketTrim": "#2c5068", "headwear": "beanie", "headwearColor": "#e9c46a", "pack": "daypack",
		"packColor": "#1f3d34", "harness": "#1f3d34", "skin": "#7a4a2e", "hair": "#1c1410", "body": "f", "bagPattern": "plain", "rope": "#d9572b"},
	"marco": {"jacket": "#a8432a", "jacketTrim": "#7e3520", "headwear": "sunhat", "headwearColor": "#d8c7a4", "pack": "crag",
		"packColor": "#3a342c", "harness": "#4c5866", "skin": "#e0b48e", "hair": "#5a3a22", "body": "m", "bagPattern": "plain", "rope": "#4fa3d9"},
	"jun": {"jacket": "#c98a2e", "jacketTrim": "#94621c", "headwear": "beanie", "headwearColor": "#2d5a4b", "pack": "daypack",
		"packColor": "#a8432a", "harness": "#4c5866", "skin": "#d9a77c", "hair": "#1c1915", "body": "m", "bagPattern": "plain", "rope": "#9cc23a"},
	"cook": {"jacket": "#e8e1d2", "jacketTrim": "#bdb29c", "headwear": "cap", "headwearColor": "#a8432a", "pack": "none",
		"packColor": "#3a342c", "harness": "#3a342c", "skin": "#5e3a24", "hair": "#120c08", "body": "m", "bagPattern": "plain", "rope": "#d9572b"},
	"porter": {"jacket": "#2d5a4b", "jacketTrim": "#1f3d34", "headwear": "cap", "headwearColor": "#e9c46a", "pack": "expedition",
		"packColor": "#c98a2e", "harness": "#3a342c", "skin": "#7a4a2e", "hair": "#120c08", "body": "m", "bagPattern": "plain", "rope": "#d9572b"},
	"ranger": {"jacket": "#6f7a3f", "jacketTrim": "#4f5a2c", "headwear": "sunhat", "headwearColor": "#8a7a52", "pack": "none",
		"packColor": "#3a342c", "harness": "#3a342c", "skin": "#a8714f", "hair": "#1c1410", "body": "f", "bagPattern": "plain", "rope": "#d9572b"},
}

const NAMES := {"lena": "Lena", "marco": "Marco", "jun": "Jun", "cook": "Baraka (cook)", "porter": "Juma (porter)", "ranger": "Neema (ranger)"}


static func look(person: String) -> Dictionary:
	return LOOKS.get(person, {})
