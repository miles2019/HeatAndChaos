class_name Fonts
extends RefCounted
## Single pixel font for the whole game (BoldPixels). Sizes are multiples of 8 to stay crisp.

static var _font: FontFile

static func main() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/BoldPixels.ttf") as FontFile
		if _font:
			_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			_font.hinting = TextServer.HINTING_NONE
			_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			_font.oversampling = 1.0
	return _font if _font else Fonts.main()
