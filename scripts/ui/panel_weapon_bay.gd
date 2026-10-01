class_name WeaponBayPanel
extends PanelContainer
## Workshop weapon bay: swap Trigger/Trajectory/Catalyst, see heat + instability + misfire risks,
## store/recall three presets. `meta_mode` = hub (all unlocked modules) vs in-run (owned modules).

signal closed

var meta_mode := false
var ids: Array = ["pulse_spitter", "straight_rail", "plain_slug"]
var _cols := {}
var _info := RichTextLabel.new()
var _build := RichTextLabel.new()
var _buttons := {}
var _first: Control

func _ready() -> void:
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2(20, 14)
	custom_minimum_size = Vector2(920, 512)
	size = Vector2(920, 512)
	if not meta_mode and Game.loadout:
		ids = Game.loadout.ids().map(func(x: Variant) -> String: return String(x))
	elif meta_mode:
		ids = Game.loadout.ids().map(func(x: Variant) -> String: return String(x)) if Game.loadout else ids
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	root.add_child(UIKit.label("WEAPON BAY  -  tear it apart, bolt it back together", Pal.AMBER, 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	for slot in ["trigger", "trajectory", "catalyst"]:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(212, 0)
		col.add_theme_constant_override("separation", 2)
		var titles := {"trigger": "TRIGGER (fire type)", "trajectory": "TRAJECTORY (flight)", "catalyst": "CATALYST (impact)"}
		col.add_child(UIKit.label(titles[slot], Pal.CYAN, 16))
		row.add_child(col)
		_cols[slot] = col
	_info.bbcode_enabled = true
	_info.custom_minimum_size = Vector2(270, 190)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build.bbcode_enabled = true
	_build.custom_minimum_size = Vector2(270, 230)
	var rc := VBoxContainer.new()
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rc.add_child(_info)
	rc.add_child(_build)
	row.add_child(rc)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 3)
	root.add_child(prow)
	prow.add_child(UIKit.label("PRESETS:", Pal.AMBER))
	for i in 3:
		prow.add_child(UIKit.button("SAVE %d" % (i + 1), _save_preset.bind(i), 80))
	for i in 3:
		prow.add_child(UIKit.button("LOAD %d" % (i + 1), _load_preset.bind(i), 80))
	var close := UIKit.button("DONE", _close, 100)
	prow.add_child(close)
	_build_lists()
	_refresh()
	if _first:
		_first.call_deferred("grab_focus")

func _available(id: StringName) -> bool:
	return Save.is_unlocked(id) if meta_mode else Game.owns(id)

func _build_lists() -> void:
	for slot in _cols:
		for m in ModuleDB.by_slot(StringName(slot)):
			var mod: WeaponModule = m
			var b := UIKit.button("", _select.bind(slot, String(mod.id)), 208)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.focus_entered.connect(_show_module.bind(mod))
			b.mouse_entered.connect(_show_module.bind(mod))
			_cols[slot].add_child(b)
			_buttons[String(mod.id)] = b
			if _first == null and _available(mod.id):
				_first = b

func _slot_index(slot: String) -> int:
	return ["trigger", "trajectory", "catalyst"].find(slot)

func _select(slot: String, id: String) -> void:
	if not _available(StringName(id)):
		return
	ids[_slot_index(slot)] = id
	_apply()
	_refresh()

func _apply() -> void:
	var l := ModuleDB.make_loadout(ids)
	Game.loadout = l
	if not meta_mode and Game.world and Game.world.player:
		Game.world.player.weapon.set_loadout(l)
		Juice.burst(Game.world.player.position, Pal.AMBER, 14, 100.0)
		Audio.play("pickup", 0.7)
	else:
		Game.loadout_changed.emit()

func _refresh() -> void:
	for id in _buttons:
		var b: Button = _buttons[id]
		var m: WeaponModule = ModuleDB.get_module(StringName(id))
		var have := _available(m.id)
		var on: bool = ids.has(id)
		var txt := "%s%s %s" % [">" if on else " ", m.symbol if Settings.symbols else "", m.display_name if have else "??? (locked)"]
		b.text = txt
		b.disabled = not have
		b.add_theme_color_override("font_color", m.color if have else Color("444"))
		if on:
			b.add_theme_color_override("font_color", Color.WHITE)
	_show_loadout()

func _show_module(m: WeaponModule) -> void:
	if not _available(m.id):
		_info.text = "[color=#777]Locked. Unlock it at the Module Furnace (Progression).[/color]"
		return
	_info.text = "[color=#%s][b]%s[/b][/color]\n%s\n\nHeat/shot: %+.1f\nInstability: %d\n[color=#a24bff]Risk: %s[/color]\n[color=#8a93a5]%s[/color]\n\n[color=#ffb02e]Click to equip.[/color]" % [
		m.color.to_html(false), m.display_name, m.description, m.heat_per_shot, int(m.instability_value),
		m.risk_text if m.risk_text != "" else "none", m.get_misfire_description()]

func _show_loadout() -> void:
	var l := ModuleDB.make_loadout(ids)
	var inst := l.instability
	var hp := l.heat_per_shot()
	var build_name := ""
	for k in ModuleDB.BUILDS:
		if ModuleDB.BUILDS[k]["ids"] == ids:
			build_name = " - " + ModuleDB.BUILDS[k]["name"].to_upper()
	var s := "[color=#ffb02e][b]CURRENT BUILD%s[/b][/color]\n" % build_name
	for m in l.modules():
		s += "[color=#%s]%s %s[/color]\n" % [m.color.to_html(false), m.symbol if Settings.symbols else "", m.display_name]
	s += "\nHeat generation / shot: [color=#ff6a2a]+%.1f%%[/color]\n" % hp
	var ic := "#a24bff" if inst < 75.0 else "#ff3b1f"
	s += "Total instability: [color=%s]%d%%%s[/color]\n" % [ic, int(inst), "  (HIGH RISK - glitch misfires)" if inst >= 75.0 else ""]
	s += "Misfire chance / shot: %.0f%%\n\n[color=#8a93a5]Active misfire threats:[/color]\n" % (pow(inst / 100.0, 2.0) * 32.0)
	for m in l.modules():
		if m.misfire_id != &"":
			s += "[color=#%s] - %s[/color]\n" % [ModuleDB.MISFIRES[m.misfire_id]["color"].to_html(false), m.get_misfire_description()]
	_build.text = s

func _save_preset(i: int) -> void:
	Save.data["presets"][i] = ids.duplicate()
	Save.save_game()
	Game.toast.emit("Preset %d saved" % (i + 1), Pal.AMBER)
	Audio.play("pickup", 1.2)

func _load_preset(i: int) -> void:
	var p: Array = Save.data["presets"][i]
	if p.size() != 3:
		Game.toast.emit("Preset %d is empty" % (i + 1), Pal.RED)
		return
	for id in p:
		if not _available(StringName(id)):
			Game.toast.emit("Preset %d needs a module you don't have" % (i + 1), Pal.RED)
			return
	ids = p.duplicate()
	_apply()
	_refresh()

func _close() -> void:
	closed.emit()

func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
