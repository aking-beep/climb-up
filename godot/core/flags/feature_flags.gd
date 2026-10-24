class_name FeatureFlags
extends RefCounted
## Switches for CLIMB UP 2.0 (docs/climb-up-2.md). The new screens are on.
## Anything that would change how a climb scores or which style it earns
## stays off by default, so records stay comparable and the records
## service's checks stay true. Tests flip them through `set_flag`.

## The hub is the front door (off: the classic title).
static var hub := true
## The drawn climber (Hero) plays you in climbs, in place of the sprite.
static var hero_in_climbs := true
## The walkable camp (off: the camp board only).
static var camp_world := true
## Gear you equip changes a climb a little (expedition climbs only).
static var gear_effects := true
## Knowledge checks (knots, belay, anchors, reading a route).
static var knowledge := true
## Expedition achievements (a new record; proposed, not yet on).
static var expedition_achievements := false


static func set_flag(name: String, value: bool) -> void:
	match name:
		"hub":
			hub = value
		"hero_in_climbs":
			hero_in_climbs = value
		"camp_world":
			camp_world = value
		"gear_effects":
			gear_effects = value
		"knowledge":
			knowledge = value
		"expedition_achievements":
			expedition_achievements = value
		_:
			push_error("FeatureFlags: no flag %s" % name)


static func all() -> Dictionary:
	return {"hub": hub, "hero_in_climbs": hero_in_climbs, "camp_world": camp_world, "gear_effects": gear_effects,
		"knowledge": knowledge, "expedition_achievements": expedition_achievements}
