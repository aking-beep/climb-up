class_name Art
extends RefCounted
## The polished look: a prop's 4x drawing (tools/art/props_hd.py) at its
## pixel size. tex("res://assets/terrain/props/cairn.png") returns the image
## from props/hd/cairn.png, mipmapped, reporting the pixel version's size,
## so a sprite, an AtlasTexture region or a layout written for the pixel
## art draws the smooth one with no other change. Falls back to the pixel
## texture when there is no HD drawing.

const HD := 4

static var _cache: Dictionary = {}


static func hd_path(path: String) -> String:
	return path.get_base_dir() + "/hd/" + path.get_file()


static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var hd := hd_path(path)
	var out: Texture2D
	if ResourceLoader.exists(hd):
		var img: Image = (load(hd) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var size := img.get_size() / HD
		img.generate_mipmaps()
		var t := ImageTexture.create_from_image(img)
		t.set_size_override(size)
		out = t
	else:
		out = load(path)
	_cache[path] = out
	return out
