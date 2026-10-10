extends Node
## Plays the Barranco Wall with the test bot's route, rendered, for a
## recording (Godot's Movie Maker), then shows the camp with the outcome:
##   godot --path godot --write-movie out.avi --fixed-fps 30 res://tests/demo.tscn

func _ready() -> void:
	Expedition.navigate = false
	var bot: TestCase = load("res://tests/test_barranco.gd").new()
	bot.tree = get_tree()
	bot.root = self
	Expedition.session = TestSessions.at("barranco-wall")
	await bot._load()
	Expedition.session = TestSessions.at("barranco-wall")
	Expedition.resume_climb()
	bot.level.attempt_id = Expedition.climb["attemptId"]
	var level: Node = bot.level
	# A word with Lena before setting off.
	await bot.drive(["move_left"], func() -> bool: return bot.tx() <= 17.6, 4.0, "to Lena")
	level._find_interaction()
	level._interact()
	await get_tree().create_timer(2.5).timeout
	level.panel.choose("talk")
	await bot.climb_the_wall("help")
	await get_tree().create_timer(2.5).timeout
	level.queue_free()
	add_child(load(Expedition.CAMP).instantiate())
	await get_tree().create_timer(4.0).timeout
	print("DEMO DONE ", JSON.stringify(bot.outcome.to_expo()), " failures=", bot.failures)
	get_tree().quit(0)
