class_name ShareCard
extends Control
## The daily result as a picture to share: the route's shape (drawn from
## its map, hold by hold, so every day's card looks different), its name
## and grade, and how you did. Drawn into an off-screen viewport and saved
## as a PNG; on the web it is offered as a download. The same result is
## always available as text (Crag.daily_share_text), which works anywhere.

const SIZE := Vector2i(540, 300)
const CELL := 5.0
const HOLD_COLORS := {
	Terrain.Kind.FACE: Color("#c9a27a"), Terrain.Kind.CRIMP: Color("#f2c14e"), Terrain.Kind.JUG: Color("#8fd16b"),
	Terrain.Kind.SLOPER: Color("#9fc4e0"), Terrain.Kind.POCKET: Color("#e0663c"), Terrain.Kind.ROCK: Color("#4a3a33"),
}

var route: Dictionary = {}
var lines: Array = []


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), Color("#1d1a1f"))
	draw_rect(Rect2(Vector2(8, 8), Vector2(SIZE) - Vector2(16, 16)), Color("#2a2530"))
	# The route, bottom to top, centred on its line.
	var t := Terrain.from_text(route.get("map", ""))
	var origin := Vector2(30, 20)
	var h := float(t.height) * CELL
	var k := minf(1.0, (SIZE.y - 40.0) / maxf(h, 1.0))
	for y in t.height:
		for x in range(8, t.width):
			var kind := t.kind(Vector2i(x, y))
			if HOLD_COLORS.has(kind):
				draw_rect(Rect2(origin + Vector2(x - 8, y) * CELL * k, Vector2.ONE * CELL * k * 0.9), HOLD_COLORS[kind])
	for q in t.markers.get("Q", []):
		draw_circle(origin + (Vector2(q) - Vector2(8, 0) + Vector2(0.5, 0.5)) * CELL * k, 1.6, Color("#cfe3f5"))
	var font := UiFont.display() if UiFont.display() else ThemeDB.fallback_font
	var body := UiFont.body() if UiFont.body() else ThemeDB.fallback_font
	var x0 := 240.0
	draw_string(body, Vector2(x0, 44), "CLIMB UP · DAILY ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#b9b0a4"))
	draw_string(font, Vector2(x0, 80), "%s" % route.get("name", ""), HORIZONTAL_ALIGNMENT_LEFT, 280, 26, Color("#f3efe6"))
	draw_string(body, Vector2(x0, 104), "%s · %s" % [route.get("grade", ""), route.get("date", "")], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#f2c14e"))
	var y := 140.0
	for l in lines:
		draw_string(body, Vector2(x0, y), String(l), HORIZONTAL_ALIGNMENT_LEFT, 280, 18, Color("#f3efe6"))
		y += 28.0


## Draws the card for `route` with `lines` and returns it as an image (null
## when the renderer gives nothing back, as in a headless run).
static func render(host: Node, route: Dictionary, lines: Array) -> Image:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var card := ShareCard.new()
	card.route = route
	card.lines = lines
	card.size = Vector2(SIZE)
	vp.add_child(card)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image() if vp.get_texture() else null
	vp.queue_free()
	return img


## Saves the card, and on the web offers it as a download. Returns the
## path it was saved to, or "".
static func save(host: Node, route: Dictionary, lines: Array) -> String:
	var img: Image = await render(host, route, lines)
	if img == null or img.is_empty():
		return ""
	var path := "user://climb-up-daily-%s.png" % route.get("date", "")
	if img.save_png(path) != OK:
		return ""
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), path.get_file(), "image/png")
	return path
