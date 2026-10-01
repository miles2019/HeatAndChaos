class_name SettingsPanel
extends PanelContainer
## Controls (remap), audio, feedback intensity, accessibility, data management.

signal closed

var _remap_action := ""
var _remap_btn: Button
var _delete_armed := false
var _key_buttons := {}

func _ready() -> void:
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2(60, 14)
	custom_minimum_size = Vector2(520, 332)
	size = Vector2(520, 332)
	var tabs := TabContainer.new()
	add_child(tabs)
	tabs.add_child(_tab_feel())
	tabs.add_child(_tab_audio())
	tabs.add_child(_tab_controls())
	tabs.add_child(_tab_game())
	for i in tabs.get_tab_count():
		tabs.set_tab_title(i, ["FEEDBACK", "AUDIO", "CONTROLS", "GAME / DATA"][i])

func _box(title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = title
	v.add_theme_constant_override("separation", 5)
	return v

func _row(v: VBoxContainer, text: String, ctl: Control) -> void:
	var h := HBoxContainer.new()
	var l := UIKit.label(text)
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)
	h.add_child(ctl)
	v.add_child(h)

func _done_button(v: VBoxContainer) -> void:
	var b := UIKit.button(Settings.t("back"), func() -> void:
		Settings.save_settings()
		closed.emit(), 80)
	v.add_child(b)

func _tab_feel() -> Control:
	var v := _box("feel")
	v.add_child(UIKit.label("Tune the juice (0 = off). Nothing relies on animation alone.", Color("8a93a5")))
	_row(v, "Screen shake", UIKit.slider(Settings.shake, func(x: float) -> void: Settings.shake = x, 0.0, 1.5))
	_row(v, "Hit-stop", UIKit.slider(Settings.hitstop, func(x: float) -> void: Settings.hitstop = x, 0.0, 1.5))
	_row(v, "Distortion / aberration", UIKit.slider(Settings.distortion, func(x: float) -> void: Settings.distortion = x, 0.0, 1.5))
	_row(v, "Flash intensity", UIKit.slider(Settings.flash, func(x: float) -> void: Settings.flash = x, 0.0, 1.5))
	var sym := CheckButton.new()
	sym.text = "Colour-blind symbols"
	sym.button_pressed = Settings.symbols
	sym.toggled.connect(func(b: bool) -> void: Settings.symbols = b)
	v.add_child(sym)
	var aa := CheckButton.new()
	aa.text = "Auto-aim assist"
	aa.button_pressed = Settings.auto_aim
	aa.toggled.connect(func(b: bool) -> void: Settings.auto_aim = b)
	v.add_child(aa)
	_done_button(v)
	return v

func _tab_audio() -> Control:
	var v := _box("audio")
	for bus in ["Master", "Music", "SFX", "UI", "Feedback"]:
		var name_copy: String = bus
		_row(v, bus, UIKit.slider(Settings.vol[bus], func(x: float) -> void:
			Settings.vol[name_copy] = x
			Settings.apply_all()))
	_done_button(v)
	return v

func _tab_controls() -> Control:
	var v := _box("controls")
	v.add_child(UIKit.label("Click a key to remap. Mouse = aim/shoot(LMB)/vent(RMB). Pad: sticks, RT shoot, A dash, B vent, X use.", Color("8a93a5")))
	for a in Settings.REMAPPABLE:
		var action: String = a
		var b := UIKit.button("", func() -> void: _begin_remap(action), 120)
		_key_buttons[a] = b
		_row(v, a.capitalize().replace("_", " "), b)
	_refresh_keys()
	v.add_child(UIKit.button("RESET KEYS", func() -> void:
		Settings.reset_keys()
		_refresh_keys(), 100))
	_done_button(v)
	return v

func _tab_game() -> Control:
	var v := _box("game")
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(b: bool) -> void:
		Settings.fullscreen = b
		Settings.apply_all())
	v.add_child(fs)
	var fps := CheckButton.new()
	fps.text = "Show FPS"
	fps.button_pressed = Settings.show_fps
	fps.toggled.connect(func(b: bool) -> void: Settings.show_fps = b)
	v.add_child(fps)
	var lang := OptionButton.new()
	lang.add_item("English")
	lang.add_item("Deutsch")
	lang.selected = 0 if Settings.language == "en" else 1
	lang.item_selected.connect(func(i: int) -> void: Settings.language = "en" if i == 0 else "de")
	_row(v, "Language (menus)", lang)
	var del: Button
	del = UIKit.button("DELETE SAVE DATA", func() -> void:
		if not _delete_armed:
			_delete_armed = true
			del.text = "REALLY DELETE EVERYTHING? CLICK AGAIN"
			get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void:
				_delete_armed = false
				if is_instance_valid(del):
					del.text = "DELETE SAVE DATA")
		else:
			Save.wipe()
			_delete_armed = false
			del.text = "SAVE DELETED"
	, 190)
	v.add_child(del)
	_done_button(v)
	return v

func _refresh_keys() -> void:
	for a in _key_buttons:
		var code: int = Settings.keys[a]
		_key_buttons[a].text = OS.get_keycode_string(code as Key)

func _begin_remap(action: String) -> void:
	_remap_action = action
	_remap_btn = _key_buttons[action]
	_remap_btn.text = "press a key..."

func _input(e: InputEvent) -> void:
	if _remap_action == "":
		return
	if e is InputEventKey and e.pressed:
		get_viewport().set_input_as_handled()
		if e.physical_keycode != KEY_ESCAPE:
			Settings.keys[_remap_action] = e.physical_keycode
			Settings.rebuild_input()
		_remap_action = ""
		_refresh_keys()

func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel") and _remap_action == "":
		get_viewport().set_input_as_handled()
		Settings.save_settings()
		closed.emit()
