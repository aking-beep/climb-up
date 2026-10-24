extends Node2D
## Every pose of the climber in a grid, for reviewing the look (not a test).


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#cfe0e8"))
	var poses: Array = HeroRig.POSES
	for i in poses.size():
		var h := Hero.new()
		h.height = 56.0
		h.pose = poses[i]
		h.still = 0.4
		h.position = Vector2(30 + (i % 9) * 52, 70 + (i / 9) * 88)
		if i % 4 == 1:
			h.set_look({"body": "f", "jacket": "#2d5a4b", "jacketTrim": "#1f3d34", "headwear": "beanie", "headwearColor": "#d9572b", "pack": "daypack"})
		add_child(h)
		var l := Label.new()
		l.text = poses[i]
		l.add_theme_font_size_override("font_size", 7)
		l.add_theme_color_override("font_color", Color.BLACK)
		l.position = h.position + Vector2(-20, 4)
		add_child(l)
