class_name UIKit
extends RefCounted
## Neon-industrial UI theme + small builders. Everything is keyboard / mouse / gamepad navigable via focus.

static var _theme: Theme

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	var font := Fonts.main()
	t.default_font = font
	t.default_font_size = 16
	t.set_stylebox("normal", "Button", box(Pal.STEEL_DARK, Pal.STEEL, 1))
	t.set_stylebox("hover", "Button", box(Color("232838"), Pal.CYAN.darkened(0.2), 1))
	t.set_stylebox("pressed", "Button", box(Pal.CYAN.darkened(0.6), Pal.CYAN, 1))
	t.set_stylebox("focus", "Button", box(Color("232838"), Pal.AMBER, 2))
	t.set_stylebox("disabled", "Button", box(Color("14161c"), Color("2a2d36"), 1))
	t.set_color("font_color", "Button", Color("c9d2e0"))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Pal.AMBER)
	t.set_color("font_disabled_color", "Button", Color("555a66"))
	t.set_font_size("font_size", "Button", 16)
	t.set_stylebox("panel", "PanelContainer", box(Color(0.06, 0.05, 0.09, 1.0), Pal.STEEL, 1))
	t.set_stylebox("panel", "Panel", box(Color(0.06, 0.05, 0.09, 1.0), Pal.STEEL, 1))
	t.set_color("font_color", "Label", Color("c9d2e0"))
	t.set_font_size("font_size", "Label", 16)
	t.set_color("default_color", "RichTextLabel", Color("c9d2e0"))
	t.set_font_size("normal_font_size", "RichTextLabel", 16)
	t.set_font_size("bold_font_size", "RichTextLabel", 16)
	t.set_font("bold_font", "RichTextLabel", font)
	t.set_font("normal_font", "RichTextLabel", font)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_stylebox("slider", "HSlider", box(Color("14161c"), Pal.STEEL, 1))
	t.set_stylebox("grabber_area", "HSlider", box(Pal.CYAN.darkened(0.4), Pal.CYAN, 1))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Pal.AMBER.darkened(0.3), Pal.AMBER, 1))
	t.set_stylebox("panel", "ItemList", box(Color("0d0c12"), Pal.STEEL, 1))
	t.set_stylebox("focus", "ItemList", box(Color(0, 0, 0, 0), Pal.AMBER, 1))
	t.set_stylebox("selected", "ItemList", box(Pal.CYAN.darkened(0.6), Pal.CYAN, 1))
	t.set_stylebox("selected_focus", "ItemList", box(Pal.AMBER.darkened(0.6), Pal.AMBER, 1))
	t.set_font_size("font_size", "ItemList", 16)
	t.set_stylebox("normal", "CheckButton", box(Pal.STEEL_DARK, Pal.STEEL, 1))
	t.set_stylebox("hover", "CheckButton", box(Color("232838"), Pal.CYAN, 1))
	t.set_stylebox("pressed", "CheckButton", box(Pal.STEEL_DARK, Pal.CYAN, 1))
	t.set_stylebox("focus", "CheckButton", box(Color("232838"), Pal.AMBER, 2))
	t.set_font_size("font_size", "CheckButton", 16)
	t.set_font_size("font_size", "OptionButton", 16)
	t.set_stylebox("normal", "OptionButton", box(Pal.STEEL_DARK, Pal.STEEL, 1))
	t.set_stylebox("focus", "OptionButton", box(Color("232838"), Pal.AMBER, 2))
	t.set_stylebox("normal", "TabContainer", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	t.set_stylebox("panel", "TabContainer", box(Color(0.04, 0.04, 0.07, 0.9), Pal.STEEL, 1))
	t.set_stylebox("tab_selected", "TabContainer", box(Pal.CYAN.darkened(0.6), Pal.CYAN, 1))
	t.set_stylebox("tab_unselected", "TabContainer", box(Pal.STEEL_DARK, Pal.STEEL, 1))
	t.set_stylebox("tab_focus", "TabContainer", box(Pal.AMBER.darkened(0.6), Pal.AMBER, 1))
	t.set_font_size("font_size", "TabContainer", 16)
	_theme = t
	return t

static func box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(w)
	s.set_corner_radius_all(0)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

static func button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(min_w, 26)
	b.pressed.connect(func() -> void:
		Audio.ui("ui_ok")
		cb.call())
	b.focus_entered.connect(func() -> void: Audio.ui("ui_move"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	return b

static func label(text: String, col: Color = Color("c9d2e0"), size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	return l

static func rich(text: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = true
	r.text = text
	return r

static func slider(value: float, cb: Callable, lo: float = 0.0, hi: float = 1.0) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(200, 18)
	s.value_changed.connect(func(v: float) -> void:
		Audio.ui("ui_move")
		cb.call(v))
	return s

static func module_line(m: WeaponModule) -> String:
	return "[%s] %s" % [m.symbol if Settings.symbols else "", m.display_name]
