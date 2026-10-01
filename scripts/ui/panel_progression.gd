class_name ProgressionPanel
extends PanelContainer
## Horizontal progression: spend scrap/cores on NEW options (modules, characters) - never on raw stats.

signal closed

var _list := VBoxContainer.new()
var _bal := Label.new()
var _first: Control

func _ready() -> void:
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2(100, 14)
	size = Vector2(440, 332)
	custom_minimum_size = size
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	root.add_child(UIKit.label("MODULE FURNACE / PROGRESSION", Pal.AMBER))
	root.add_child(UIKit.label("Unlocks widen your options - they never make you stronger by default.", Color("8a93a5")))
	root.add_child(_bal)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(420, 230)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	_list.add_theme_constant_override("separation", 2)
	root.add_child(sc)
	root.add_child(UIKit.button(Settings.t("back"), func() -> void: closed.emit(), 80))
	_refresh()
	if _first:
		_first.call_deferred("grab_focus")

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	_first = null
	_bal.text = "SCRAP %d     CORES %d" % [Save.data["scrap"], Save.data["cores"]]
	_bal.add_theme_color_override("font_color", Pal.AMBER)
	for id in ModuleDB.order:
		var m: WeaponModule = ModuleDB.get_module(id)
		var owned := Save.is_unlocked(id)
		var txt := "%s %s  [%s]" % [m.symbol, m.display_name, String(m.slot)]
		if owned:
			txt += "   - UNLOCKED"
		else:
			txt += "   - %d scrap" % m.unlock_cost
		var b := UIKit.button(txt, _unlock_module.bind(id), 410)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = owned or Save.data["scrap"] < m.unlock_cost
		b.add_theme_color_override("font_color", m.color if not owned else Color("666"))
		_list.add_child(b)
		if _first == null and not b.disabled:
			_first = b
	for cid in Game.CHARACTERS:
		var ch: Dictionary = Game.CHARACTERS[cid]
		var have: bool = Save.data["chars"].has(cid)
		var b2 := UIKit.button("CHAR: %s - %s   %s" % [ch["name"], ch["desc"], "UNLOCKED" if have else "%d cores" % ch["cost"]], _unlock_char.bind(cid), 410)
		b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b2.clip_text = true
		b2.disabled = have or Save.data["cores"] < ch["cost"]
		_list.add_child(b2)
		if _first == null and not b2.disabled:
			_first = b2

func _unlock_module(id: StringName) -> void:
	if Save.unlock(id):
		Audio.play("pickup", 0.8)
		Save.discover("modules", String(id))
		_refresh()
		if _first:
			_first.call_deferred("grab_focus")

func _unlock_char(cid: String) -> void:
	var ch: Dictionary = Game.CHARACTERS[cid]
	if Save.data["cores"] >= ch["cost"] and not Save.data["chars"].has(cid):
		Save.data["cores"] -= ch["cost"]
		Save.data["chars"].append(cid)
		Save.save_game()
		Audio.play("pickup", 0.8)
		_refresh()

func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
