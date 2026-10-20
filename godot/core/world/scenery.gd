class_name Scenery
extends RefCounted
## Everything that makes the level a place rather than a collision map:
## sky, parallax mountains and valley, drifting fog, morning light with sun
## shafts, the camp fire's glow, dust in the air, wind streaks on the
## exposed ledge, a foreground that passes close to the lens, and a
## vignette. Quality settings trim fog, particles and lights; the
## simulation never depends on any of it.

const SKY_TOP := Color("#7f98a6")
const SKY_LOW := Color("#efe6d6")


## `theme`: {night, far, mid, foreground, snow, haze} (see ClimbLevel).
const GRADE := preload("res://core/world/grade.gdshader")


static func build(level: Node2D, terrain: Terrain, camera: Camera2D, theme: Dictionary = {}) -> void:
	var size := terrain.pixel_size()
	var night: bool = theme.get("night", false)

	# Sky: a screen-space gradient behind everything.
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -20
	sky_layer.name = "Sky"
	level.add_child(sky_layer)
	var sky := TextureRect.new()
	var grad := Gradient.new()
	# A place may have its own sky: [top, middle, horizon].
	var sky_cols: Array = theme.get("sky", [])
	if sky_cols.size() == 3:
		grad.set_color(0, Color(sky_cols[0]))
		grad.set_color(1, Color(sky_cols[2]))
		grad.add_point(0.62, Color(sky_cols[1]))
	else:
		grad.set_color(0, Color("#0a1024") if night else SKY_TOP)
		grad.set_color(1, Color("#3a3f5c") if night else SKY_LOW)
		grad.add_point(0.62, Color("#1c2440") if night else Color("#d9d6cc"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	sky.texture = gt
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_layer.add_child(sky)
	if night:
		var stars := TextureRect.new()
		stars.name = "Stars"
		stars.texture = _stars(480, 270)
		stars.set_anchors_preset(Control.PRESET_FULL_RECT)
		stars.stretch_mode = TextureRect.STRETCH_TILE
		sky_layer.add_child(stars)

	# Kibo far away, then the valley of groundsels: painted layers that sink
	# toward the horizon as you climb.
	var camp_floor: float = terrain.markers["P"][0].y * Terrain.TILE
	var far := CanvasLayer.new()
	far.layer = -15
	far.name = "Distance"
	far.follow_viewport_enabled = false
	level.add_child(far)
	var dim := Color(0.45, 0.5, 0.68) if night else Color(1, 1, 1)
	if theme.get("far", "res://assets/scenery/barranco-kibo.png") != "":
		var kibo := _layer("Kibo", theme.get("far", "res://assets/scenery/barranco-kibo.png"), Vector2(0.04, 0.1), Vector2(size.x * 0.45, camp_floor), 185.0, theme.get("farScale", 0.62), Color(0.9, 0.93, 0.98) * dim * Color(theme.get("farTint", "#ffffff")))
		kibo.repeat = theme.get("farRepeat", false)
		far.add_child(kibo)
	# The place's own distance, drawn in code (Skyline): forest, heath,
	# ridges, glaciers, the Breach, the crater, cloud. Far to near; "near"
	# ones go in front of the painted valley.
	_skylines(far, theme, camp_floor, false)
	if theme.get("mid", "res://assets/scenery/barranco-valley.png") != "":
		far.add_child(_layer("Valley", theme.get("mid", "res://assets/scenery/barranco-valley.png"), Vector2(0.16, 0.32), Vector2(size.x / 2.0, camp_floor), 250.0, theme.get("midScale", 0.42), Color(0.84, 0.87, 0.86) * dim))
	_skylines(far, theme, camp_floor, true)
	var mist := float(theme.get("mist", 1.0))
	var haze := _layer("FarFog", "res://assets/scenery/fog.png", Vector2(0.3, 0.25), Vector2(0, camp_floor), 230.0, 1.6, Color(1, 0.98, 0.95, minf(0.8, (0.12 if night else 0.28) * mist)))
	haze.drift = 4.0
	far.add_child(haze)

	# Morning light: a warm wash over the world, and the camp fire.
	var tint := CanvasModulate.new()
	tint.name = "Daylight"
	tint.color = Color(1.0, 0.985, 0.95)
	tint.set_script(load("res://core/world/daylight.gd"))
	tint.set("terrain", terrain)
	tint.set("night", night)
	level.add_child(tint)
	# The climber's own pool of light: in the open it is lost in daylight;
	# under the overhangs it is what you see by.
	var climber: Node2D = level.get_node_or_null("Climber")
	if climber:
		var lamp := PointLight2D.new()
		lamp.name = "Lamp"
		lamp.texture = _radial(256, Color(1.0, 0.93, 0.8))
		lamp.texture_scale = 2.6 if night else 1.6
		lamp.energy = 1.15 if night else 0.55
		lamp.position = Vector2(0, -14)
		climber.add_child(lamp)
	var fire: Node2D = level.get_node_or_null("Props/Fire")
	if fire:
		var light := PointLight2D.new()
		light.name = "FireLight"
		light.texture = _radial(128, Color(1, 0.78, 0.5))
		light.energy = 0.9
		light.texture_scale = 1.4
		light.position = fire.position + Vector2(16, 14)
		light.set_script(load("res://core/world/flicker.gd"))
		level.add_child(light)

	# Sun shafts from the upper left, faint and additive.
	var shafts := Node2D.new()
	shafts.name = "SunShafts"
	shafts.z_index = 4
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 5:
		var p := Polygon2D.new()
		var x := 300.0 + i * 520.0
		p.polygon = PackedVector2Array([Vector2(x, -100), Vector2(x + 90, -100), Vector2(x + 520, size.y), Vector2(x + 300, size.y)])
		p.color = Color(1.0, 0.9, 0.7, 0.028)
		p.material = add
		shafts.add_child(p)
	shafts.visible = theme.get("sunShafts", not night)
	level.add_child(shafts)

	# Fog banks drifting in front of the wall, at a few depths.
	var near_air := CanvasLayer.new()
	near_air.layer = 2
	near_air.name = "Fog"
	level.add_child(near_air)
	for i in 3:
		# Kept faint: fog in front of the rock softens the very edges the
		# player reads, so it never covers the route.
		var bank := _layer("Fog%d" % i, "res://assets/scenery/fog.png", Vector2(0.7 + i * 0.25, 0.8 + i * 0.2), Vector2(0, size.y * (0.3 + i * 0.25)), 220.0, 1.4 + i * 0.4, Color(1, 0.98, 0.95, minf(0.3, (0.08 - i * 0.02) * mist)) * (Color(0.5, 0.55, 0.75) if night else Color(1, 1, 1)))
		bank.drift = 6.0 + i * 5.0
		near_air.add_child(bank)

	# Dust in the air, following the camera.
	var dust := CPUParticles2D.new()
	dust.name = "Dust"
	dust.amount = 36
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(300, 170)
	dust.direction = Vector2(1, -0.2)
	dust.spread = 30.0
	dust.initial_velocity_min = 4.0
	dust.initial_velocity_max = 10.0
	dust.gravity = Vector2(0, 2)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	dust.color = Color(1, 0.96, 0.86, 0.5)
	if theme.get("snow", false):
		dust.name = "Dust"
		dust.amount = 70
		dust.direction = Vector2(0.6, 1)
		dust.initial_velocity_min = 14.0
		dust.initial_velocity_max = 30.0
		dust.gravity = Vector2(4, 10)
		dust.color = Color(0.92, 0.95, 1.0, 0.85)
	match String(theme.get("weather", "")):
		"rain":
			# Forest rain: long, fast, slanted drops.
			dust.name = "Dust"
			dust.amount = 90
			dust.lifetime = 1.1
			dust.preprocess = 2.0
			dust.direction = Vector2(0.15, 1)
			dust.spread = 3.0
			dust.initial_velocity_min = 260.0
			dust.initial_velocity_max = 330.0
			dust.gravity = Vector2(0, 40)
			dust.scale_amount_min = 1.0
			dust.scale_amount_max = 1.0
			dust.texture = _streak(2, 9)
			dust.color = Color(0.75, 0.85, 0.95, 0.45)
		"sleet":
			dust.amount = 110
			dust.lifetime = 2.0
			dust.direction = Vector2(-0.8, 1)
			dust.spread = 10.0
			dust.initial_velocity_min = 90.0
			dust.initial_velocity_max = 150.0
			dust.gravity = Vector2(-20, 30)
			dust.color = Color(0.9, 0.93, 1.0, 0.8)
		"ash":
			dust.amount = 50
			dust.direction = Vector2(0.3, -1)
			dust.initial_velocity_min = 6.0
			dust.initial_velocity_max = 16.0
			dust.gravity = Vector2(0, -3)
			dust.color = Color(0.95, 0.9, 0.7, 0.45)
	dust.z_index = 5
	camera.add_child(dust)

	# Wind streaks over the exposed ledge, switched on by gusts.
	var exposed: Array = []
	for y in terrain.height:
		for x in terrain.width:
			if terrain.kind(Vector2i(x, y)) == Terrain.Kind.EXPOSED:
				exposed.append(Vector2(x, y) * Terrain.TILE)
	if not exposed.is_empty():
		var lo: Vector2 = exposed[0]
		var hi: Vector2 = exposed[exposed.size() - 1]
		var streaks := CPUParticles2D.new()
		streaks.name = "WindStreaks"
		streaks.emitting = false
		streaks.amount = 40
		streaks.lifetime = 0.9
		streaks.position = (lo + hi) / 2.0 + Vector2(0, -24)
		streaks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		streaks.emission_rect_extents = Vector2((hi.x - lo.x) / 2.0 + 60, 40)
		streaks.direction = Vector2(1, 0.05)
		streaks.spread = 4.0
		streaks.initial_velocity_min = 180.0
		streaks.initial_velocity_max = 260.0
		streaks.gravity = Vector2.ZERO
		streaks.scale_amount_min = 1.0
		streaks.scale_amount_max = 1.0
		var line := Image.create(10, 1, false, Image.FORMAT_RGBA8)
		line.fill(Color(1, 1, 1, 0.55))
		streaks.texture = ImageTexture.create_from_image(line)
		streaks.color = Color(0.95, 0.96, 1.0, 0.6)
		streaks.z_index = 6
		level.add_child(streaks)

	# Foreground: dark groundsels passing close to the lens at the camp.
	if theme.get("foreground", "res://assets/scenery/barranco-foreground.png") != "":
		var fg := _layer("Foreground", theme.get("foreground", "res://assets/scenery/barranco-foreground.png"), Vector2(1.35, 1.2), Vector2(cairns_x(terrain), camp_floor + 30), 330.0, 0.4, Color(0.42, 0.38, 0.36, 0.95) * Color(theme.get("foregroundTint", "#ffffff")))
		fg.repeat = false
		near_air.add_child(fg)

	# Lens: a colour grade over the world (not the HUD): shadows lean cool,
	# lights warm, a little more contrast and colour, and a vignette. The
	# grade reads the screen, so it is off with "Low power".
	var lens := CanvasLayer.new()
	lens.name = "Lens"
	lens.layer = 5
	var vignette := ColorRect.new()
	vignette.name = "Grade"
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = GRADE
	var grade: Dictionary = theme.get("grade", {})
	mat.set_shader_parameter("shadow_tint", grade.get("shadow", Vector3(0.9, 0.92, 0.98) if night else Vector3(0.9, 0.9, 1.04)))
	mat.set_shader_parameter("light_tint", grade.get("light", Vector3(1.02, 1.0, 0.98) if night else Vector3(1.06, 1.01, 0.93)))
	mat.set_shader_parameter("strength", 0.42)
	vignette.material = mat
	lens.add_child(vignette)
	level.add_child(lens)

	apply_quality(level)


static func _skylines(parent: Node, theme: Dictionary, camp_floor: float, near: bool) -> void:
	var k := 0
	for sl in theme.get("skylines", []):
		k += 1
		if bool(sl.get("near", false)) != near:
			continue
		var line := Skyline.new()
		line.name = "Skyline%d" % k
		line.kind = sl.get("kind", "ridge")
		line.color = Color(sl.get("color", "#3a4250"))
		line.light = Color(sl.get("light", "#6a7484"))
		var f: Array = sl.get("factor", [0.1, 0.15])
		line.factor = Vector2(f[0], f[1])
		line.anchor = Vector2(0, camp_floor)
		line.screen_y = float(sl.get("y", 230.0))
		line.tall = float(sl.get("tall", 120.0))
		line.seed_value = int(sl.get("seed", k))
		line.drift = float(sl.get("drift", 0.0))
		parent.add_child(line)


static func apply_quality(level: Node) -> void:
	var fogs := level.get_node_or_null("Fog")
	if fogs:
		var keep: int = Settings.fog_layers()
		for i in 3:
			var bank := fogs.get_node_or_null("Fog%d" % i)
			if bank:
				bank.visible = i < keep
	for node in level.find_children("Dust", "CPUParticles2D", true, false):
		node.amount = maxi(4, int(36 * Settings.particle_scale()))
	var streaks := level.get_node_or_null("WindStreaks")
	if streaks:
		streaks.amount = maxi(6, int(40 * Settings.particle_scale()))
	var light := level.get_node_or_null("FireLight")
	if light:
		light.enabled = Settings.lights_enabled()
	var lamp := level.get_node_or_null("Climber/Lamp")
	if lamp:
		lamp.enabled = Settings.lights_enabled()
	var grade := level.get_node_or_null("Lens/Grade") as ColorRect
	if grade and grade.material:
		(grade.material as ShaderMaterial).set_shader_parameter("graded", Settings.quality != Settings.Quality.LOW_POWER)
	var shafts := level.get_node_or_null("SunShafts")
	if shafts and Settings.quality != Settings.Quality.FULL:
		shafts.visible = false


static func cairns_x(terrain: Terrain) -> float:
	return terrain.markers["P"][0].x * Terrain.TILE - 120.0


static func _layer(name: String, path: String, factor: Vector2, anchor: Vector2, screen_y: float, scale: float, tint: Color) -> Backdrop:
	var b := Backdrop.new()
	b.name = name
	b.texture = load(path)
	b.factor = factor
	b.anchor = anchor
	b.screen_y = screen_y
	b.scale_by = scale
	b.modulate = tint
	return b


## A sky of small stars, a few bright: deterministic, drawn once.
static func _stars(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in 160:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, int(h * 0.7))
		var a := rng.randf_range(0.25, 0.9)
		img.set_pixel(x, y, Color(0.95, 0.96, 1.0, a))
		if a > 0.82 and x > 0 and x < w - 1:
			img.set_pixel(x - 1, y, Color(0.9, 0.92, 1.0, a * 0.35))
			img.set_pixel(x + 1, y, Color(0.9, 0.92, 1.0, a * 0.35))
	return ImageTexture.create_from_image(img)


## A thin white streak (a rain drop), w x h pixels.
static func _streak(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.8))
	return ImageTexture.create_from_image(img)


static func _radial(size: int, color: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t
