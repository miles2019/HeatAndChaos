class_name RunOverlay
extends Control
## Pause menu (live loadout + heat/instability + relics), end-of-run summary and the final ending choice.

signal resume
signal to_menu
signal to_workshop
signal new_run
signal open_settings

var _body := RichTextLabel.new()

func _ready() -> void:
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

func show_pause() -> void:
	_clear_panel()
	var p := _panel(Vector2(290, 40), Vector2(380, 460))
	var v := p.get_child(0) as VBoxContainer
	v.add_child(UIKit.label("PAUSED", Pal.AMBER))
	_body = UIKit.rich("")
	_body.custom_minimum_size = Vector2(360, 270)
	_body.bbcode_enabled = true
	v.add_child(_body)
	var l := Game.loadout
	var s := ""
	for m in l.modules():
		s += "[color=#%s]%s %s[/color]\n" % [m.color.to_html(false), m.symbol, m.display_name]
	var w = Game.world.player.weapon
	s += "\nHeat [color=#ff6a2a]%d%%[/color]   Instability [color=#a24bff]%d%%[/color]\nHP %d/%d   Misfire risk %.0f%%/shot\n" % [
		int(w.heat.heat), int(l.instability), Game.hp, Game.max_hp, w.instab.chance() * 100.0]
	if not Game.relics.is_empty():
		s += "\n[color=#ffb02e]Relics:[/color]\n"
		for r in Game.relics:
			s += " - %s: %s\n" % [Game.RELICS[r][0], Game.RELICS[r][1]]
	if Game.curse_inst > 0.0:
		s += "\n[color=#a24bff]Curse: +%d instability[/color]" % int(Game.curse_inst)
	_body.text = s
	var first := UIKit.button(Settings.t("resume"), func() -> void: resume.emit(), 340)
	v.add_child(first)
	v.add_child(UIKit.button(Settings.t("settings"), func() -> void: open_settings.emit(), 340))
	v.add_child(UIKit.button(Settings.t("to_menu"), func() -> void: to_menu.emit(), 340))
	first.call_deferred("grab_focus")

func show_summary(sm: Dictionary) -> void:
	_clear_panel()
	var p := _panel(Vector2(210, 30), Vector2(540, 480))
	var v := p.get_child(0) as VBoxContainer
	var win: bool = sm["victory"]
	v.add_child(UIKit.label("RUN COMPLETE" if win else "RUN OVER - THE FURNACE KEEPS YOU", Pal.LIME if win else Pal.RED))
	var st: Dictionary = sm["stats"]
	var rich := UIKit.rich("")
	rich.custom_minimum_size = Vector2(520, 330)
	var s := ""
	if st.has("ending"):
		s += "[color=#ffb02e]ENDING: %s[/color]\n%s\n\n" % [Game.ENDINGS[st["ending"]][0], Game.ENDINGS[st["ending"]][1]]
	s += "[color=#ffb02e]BUILD[/color]\n"
	for id in sm["build"]:
		var m: WeaponModule = ModuleDB.get_module(id)
		s += "  [color=#%s]%s %s[/color]\n" % [m.color.to_html(false), m.symbol, m.display_name]
	s += "\nHeat record [color=#ff6a2a]%d%%[/color]   Instability record [color=#a24bff]%d%%[/color]\n" % [int(st["max_heat"]), int(st["max_instability"])]
	s += "Kills %d   Rooms %d   Misfires %d\n" % [st["kills"], st["rooms"], st["misfires"]]
	s += "Bosses: %s\n" % (", ".join(st["bosses"]) if not st["bosses"].is_empty() else "none")
	s += "New synergies: %d   Relics: %d\n" % [st["new_synergies"].size(), Game.relics.size()]
	s += "\n[color=#ffb02e]Rewards[/color] +%d scrap" % sm["scrap"] + ("  +%d cores" % sm["cores"] if sm["cores"] > 0 else "")
	rich.text = s
	v.add_child(rich)
	var first := UIKit.button("NEW RUN", func() -> void: new_run.emit(), 500)
	v.add_child(first)
	v.add_child(UIKit.button("WORKSHOP", func() -> void: to_workshop.emit(), 500))
	v.add_child(UIKit.button("MAIN MENU", func() -> void: to_menu.emit(), 500))
	first.call_deferred("grab_focus")

func show_endings() -> void:
	_clear_panel()
	var p := _panel(Vector2(130, 50), Vector2(700, 440))
	var v := p.get_child(0) as VBoxContainer
	v.add_child(UIKit.label("THE PULSE LIES OPEN. WHAT DO YOU DO?", Pal.AMBER))
	var first: Button
	for id in Game.ENDINGS:
		var e: Array = Game.ENDINGS[id]
		var eid: String = id
		var b := UIKit.button("%s - %s" % [e[0], e[1]], func() -> void:
			Game.finish_ending(eid), 660)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(660, 70)
		v.add_child(b)
		if first == null:
			first = b
	v.add_child(UIKit.label("Each ending unlocks codex entries and alternative start rules.", Color("8a93a5")))
	first.call_deferred("grab_focus")

func _panel(pos: Vector2, sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Panel"
	p.position = pos
	p.size = sz
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	add_child(p)
	return p

func _clear_panel() -> void:
	var old := get_node_or_null("Panel")
	if old:
		old.name = "OldPanel"
		old.queue_free()
