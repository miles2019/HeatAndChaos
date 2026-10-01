extends Node
## Visual check helper (needs a real renderer, not --headless):
##   godot --path . res://tests/capture.tscn -- mode=menu out=C:/tmp/x.png
## modes: menu | hub | story | fight:<buildkey> | boss | combat2 | workshop

var args := {}
var run: RunController

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var mode: String = args.get("mode", "menu")
	var out: String = args.get("out", "user://cap.png")
	var shots := int(args.get("shots", "1"))
	var gap := float(args.get("gap", "1.5"))
	Game.test_mode = true
	match mode:
		"menu":
			add_child(load("res://scenes/ui/main_menu.tscn").instantiate())
		"hub":
			add_child(load("res://scenes/ui/workshop_hub.tscn").instantiate())
		"story":
			add_child(load("res://scenes/ui/story_intro.tscn").instantiate())
		"setup", "codex", "settings", "progression":
			var m: Node = load("res://scenes/ui/main_menu.tscn").instantiate()
			add_child(m)
			await _t(0.3)
			m._open_panel(mode)
		"hubbay", "hubfurnace":
			var h: Node = load("res://scenes/ui/workshop_hub.tscn").instantiate()
			add_child(h)
			await _t(0.3)
			h._activate("bay" if mode == "hubbay" else "furnace")
		"bay", "pause", "summary":
			await _setup_run("workshop")
			await _t(0.5)
			if mode == "bay":
				run.open_bay()
			elif mode == "pause":
				run._open_overlay()
				run.overlay.show_pause()
			else:
				Game.stats["kills"] = 14
				Game.stats["max_heat"] = 100.0
				Game.stats["max_instability"] = 90.0
				Game.end_run(true)
		_:
			await _setup_run(mode)
	await _t(float(args.get("wait", "1.5")))
	for i in shots:
		_save(out.replace(".png", "_%d.png" % i))
		await _t(gap)
	get_tree().quit()

func _t(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path, " ", img.get_size(), " fps=", Engine.get_frames_per_second())

func _setup_run(mode: String) -> void:
	Game.new_run({"trigger": "pulse_spitter"})
	for id in ModuleDB.order:
		Game.own(id)
	run = load("res://scenes/main.tscn").instantiate()
	add_child(run)
	await _t(0.3)
	Game.hp = 8
	var pl := run.player
	if mode.begins_with("fight"):
		var key := mode.split(":")[1] if ":" in mode else "minefield"
		run.debug_equip(key)
		run.rooms.enter(1, 0)
		await _t(2.2)
		pl.override_active = true
		_drive.call_deferred(pl)
	elif mode == "boss":
		run.debug_equip("sniper")
		run.rooms.enter(4, 0)
		pl.override_active = true
		_drive.call_deferred(pl)
	elif mode == "combat2":
		run.debug_equip("carpet")
		run.rooms.enter(3, 0)
		await _t(2.0)
		pl.override_active = true
		_drive.call_deferred(pl)
	elif mode == "workshop":
		run.rooms.enter(2, 0)

func _drive(pl: Player) -> void:
	var t := 0.0
	while is_instance_valid(pl):
		await get_tree().process_frame
		t += get_process_delta_time()
		var room: Room = run.current_room()
		var best := 9999.0
		var tgt := Vector2(420, 180)
		for e in room.enemies:
			if is_instance_valid(e) and not e.dead and e.spawn_t <= 0.0:
				var d: float = e.position.distance_to(pl.position)
				if d < best:
					best = d
					tgt = e.position
		pl.ov_target = tgt
		pl.ov_move = Vector2(cos(t * 0.9), sin(t * 1.3)) * 0.7
		pl.ov_shoot = (fmod(t, 1.7) < 1.35) if pl.weapon.is_charge_trigger() else true
		Game.hp = maxi(Game.hp, 4)
