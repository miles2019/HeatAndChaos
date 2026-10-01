class_name RunSetupPanel
extends PanelContainer
## Character + starter loadout selection before a run. `hub_mode` hides the launch button.

signal closed
signal launched

var hub_mode := false
var _char := OptionButton.new()
var _trig := OptionButton.new()
var _extra := OptionButton.new()
var _desc := RichTextLabel.new()
var _chars: Array = []
var _trigs: Array = []
var _extras: Array = []

func _ready() -> void:
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2(110, 40)
	size = Vector2(420, 280)
	custom_minimum_size = size
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	add_child(v)
	v.add_child(UIKit.label("CHOOSE YOUR RUNNER AND STARTER KIT", Pal.AMBER))
	_row(v, "Character", _char)
	_row(v, "Start trigger", _trig)
	_row(v, "Starter module", _extra)
	for cid in Save.data["chars"]:
		_chars.append(cid)
		_char.add_item(Game.CHARACTERS[cid]["name"])
	for m in ModuleDB.by_slot(&"trigger"):
		if Save.is_unlocked(m.id):
			_trigs.append(String(m.id))
			_trig.add_item(m.display_name)
	_extras.append("")
	_extra.add_item("(none - plain rail + slug)")
	for slot in [&"trajectory", &"catalyst"]:
		for m in ModuleDB.by_slot(slot):
			if Save.is_unlocked(m.id) and not ModuleDB.BASE_IDS.has(String(m.id)):
				_extras.append(String(m.id))
				_extra.add_item("%s: %s" % [String(slot), m.display_name])
	var ps: Dictionary = Game.pending_setup
	_select(_char, _chars, ps.get("char", "runner"))
	_select(_trig, _trigs, ps.get("trigger", "pulse_spitter"))
	_select(_extra, _extras, ps.get("extra", ""))
	for o in [_char, _trig, _extra]:
		o.item_selected.connect(func(_i: int) -> void: _update())
	_desc.bbcode_enabled = true
	_desc.custom_minimum_size = Vector2(400, 110)
	v.add_child(_desc)
	_update()
	var row := HBoxContainer.new()
	v.add_child(row)
	if not hub_mode:
		var go := UIKit.button("LAUNCH RUN", _launch, 120)
		row.add_child(go)
	row.add_child(UIKit.button(Settings.t("back"), func() -> void:
		_store()
		closed.emit(), 80))
	_char.call_deferred("grab_focus")

func _row(v: VBoxContainer, label: String, ctl: OptionButton) -> void:
	var h := HBoxContainer.new()
	var l := UIKit.label(label)
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	ctl.custom_minimum_size = Vector2(250, 16)
	h.add_child(ctl)
	v.add_child(h)

func _select(ob: OptionButton, arr: Array, val: String) -> void:
	var i := arr.find(val)
	ob.selected = maxi(i, 0)

func _setup() -> Dictionary:
	var d := {"char": _chars[maxi(_char.selected, 0)], "trigger": _trigs[maxi(_trig.selected, 0)]}
	var ex: String = _extras[maxi(_extra.selected, 0)]
	if ex != "":
		d["extra"] = ex
	return d

func _store() -> void:
	Game.pending_setup = _setup()

func _update() -> void:
	var s := _setup()
	var ch: Dictionary = Game.CHARACTERS[s["char"]]
	var t: WeaponModule = ModuleDB.get_module(StringName(s["trigger"]))
	var txt := "[color=#ffb02e][b]%s[/b][/color]  (%d hearts)\n%s\n\n" % [ch["name"], ch["hp"] / 2, ch["desc"]]
	txt += "[color=#%s][b]%s[/b][/color]: %s\n[color=#a24bff]%s[/color]\n" % [t.color.to_html(false), t.display_name, t.description, t.get_misfire_description()]
	if s.has("extra"):
		var m: WeaponModule = ModuleDB.get_module(StringName(s["extra"]))
		txt += "[color=#%s][b]%s[/b][/color]: %s\n[color=#a24bff]%s[/color]" % [m.color.to_html(false), m.display_name, m.description, m.get_misfire_description()]
	_desc.text = txt

func _launch() -> void:
	_store()
	Game.new_run(Game.pending_setup)
	Audio.play("door", 1.0)
	launched.emit()

func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_store()
		closed.emit()
