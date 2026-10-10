class_name UiFont
extends RefCounted
## The app's two families, shared with the Expo game: Fraunces for titles,
## Outfit for text (SIL Open Font License, from @expo-google-fonts).

static var _display: Font
static var _body: Font


static func display() -> Font:
	if _display == null and ResourceLoader.exists("res://assets/fonts/Fraunces_600SemiBold.ttf"):
		_display = load("res://assets/fonts/Fraunces_600SemiBold.ttf")
	return _display


static func body() -> Font:
	if _body == null and ResourceLoader.exists("res://assets/fonts/Outfit_500Medium.ttf"):
		_body = load("res://assets/fonts/Outfit_500Medium.ttf")
	return _body
