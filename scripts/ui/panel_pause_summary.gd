class_name RunOverlay
extends Control
## Pause menu (with live loadout + heat/instability readout) and the end-of-run summary.

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
	var p := _panel(Vector2(180, 60), Vector2(280, 250))
	var v := p.get_child(0) as VBoxContainer
	v.add_child(UIKit.label("PAUSED", Pal.AMBER, 8))
	_body = UIKit.rich("")
	_body.custom_minimum_size = Vector2(260, 120)
	_body.bbcode_enabled = true
	v.add_child(_body)
	var l := Game.loadout
	var s := ""
	for m in l.modules():
		s += "[color=#%s]%s %s[/color]\n" % [m.color.to_html(false), m.symbol, m.display_name]
	var w = Game.world.player.weapon
	s += "\nHeat: [color=#ff6a2a]%d%%[/color]   Instability: [color=#a24bff]%d%%[/color]\nHP: %d/%d   Misfire risk: %.0f%%/shot" % [
		int(w.heat.heat), int(l.instability), Game.hp, Game.max_hp, w.instab.chance() * 100.0]
	_body.text = s
	var first := UIKit.button(Settings.t("resume"), func() -> void: resume.emit(), 200)
	v.add_child(first)
	v.add_child(UIKit.button(Settings.t("settings"), func() -> void: open_settings.emit(), 200))
	v.add_child(UIKit.button(Settings.t("to_menu"), func() -> void: to_menu.emit(), 200))
	first.call_deferred("grab_focus")

func show_summary(sm: Dictionary) -> void:
	_clear_panel()
	var p := _panel(Vector2(150, 30), Vector2(340, 300))
	var v := p.get_child(0) as VBoxContainer
	var win: bool = sm["victory"]
	v.add_child(UIKit.label("RUN COMPLETE - THE CORE IS SILENT" if win else "RUN OVER - THE FURNACE KEEPS YOU", Pal.LIME if win else Pal.RED, 8))
	var st: Dictionary = sm["stats"]
	var rich := UIKit.rich("")
	rich.custom_minimum_size = Vector2(320, 190)
	var s := "[color=#ffb02e]BUILD[/color]\n"
	for id in sm["build"]:
		var m: WeaponModule = ModuleDB.get_module(id)
		s += "  [color=#%s]%s %s[/color]\n" % [m.color.to_html(false), m.symbol, m.display_name]
	s += "\nHeat record: [color=#ff6a2a]%d%%[/color]     Instability record: [color=#a24bff]%d%%[/color]\n" % [int(st["max_heat"]), int(st["max_instability"])]
	s += "Kills: %d     Rooms cleared: %d     Misfires: %d\n" % [st["kills"], st["rooms"], st["misfires"]]
	s += "Bosses defeated: %s\n" % (", ".join(st["bosses"]) if not st["bosses"].is_empty() else "none")
	s += "New synergies: %s\n" % (str(st["new_synergies"].size()) if not st["new_synergies"].is_empty() else "none")
	s += "\n[color=#ffb02e]Rewards:[/color] +%d scrap" % sm["scrap"] + ("  +%d cores" % sm["cores"] if sm["cores"] > 0 else "")
	rich.text = s
	v.add_child(rich)
	var first := UIKit.button("NEW RUN", func() -> void: new_run.emit(), 220)
	v.add_child(first)
	v.add_child(UIKit.button("WORKSHOP", func() -> void: to_workshop.emit(), 220))
	v.add_child(UIKit.button("MAIN MENU", func() -> void: to_menu.emit(), 220))
	first.call_deferred("grab_focus")

func _panel(pos: Vector2, sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Panel"
	p.position = pos
	p.size = sz
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	add_child(p)
	return p

func _clear_panel() -> void:
	var old := get_node_or_null("Panel")
	if old:
		old.name = "OldPanel"
		old.queue_free()
