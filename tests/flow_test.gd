extends Node
## Menu -> setup -> story -> run -> pause -> menu -> continue flow (headless-safe).
## Run: godot --headless --path . res://tests/flow_test.tscn

var failed := false

func _check(name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		failed = true
	print("%s  %s %s" % ["PASS" if ok else "FAIL", name, detail])

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _go(n: String) -> void:
	Router.go(n)
	await _wait(0.4)
	while Router._busy:
		await _wait(0.1)

func _ready() -> void:
	_run_all()

func _run_all() -> void:
	Game.test_mode = true
	var placeholder := Node.new()
	placeholder.name = "Placeholder"
	get_tree().root.add_child.call_deferred(placeholder)
	await get_tree().process_frame
	get_tree().current_scene = placeholder
	await _go("menu")
	var menu := get_tree().current_scene
	_check("main menu loads", menu != null and menu.name == "MainMenu")
	menu._open_panel("setup")
	await _wait(0.3)
	var setup: RunSetupPanel = menu._panel
	_check("run setup panel opens", setup != null)
	setup._trig.selected = setup._trigs.find("buckshot_cluster")
	setup._launch()
	_check("new run created with chosen trigger", Game.loadout.trigger_module.id == &"buckshot_cluster")
	await _go("story")
	_check("story scene", get_tree().current_scene.name == "StoryIntro")
	get_tree().current_scene._finish()
	await _wait(0.4)
	while Router._busy:
		await _wait(0.1)
	var run: RunController = get_tree().current_scene as RunController
	_check("run scene loads", run != null and run.player != null)
	# real input path (no overrides): move, shoot, dash, vent
	var p: Player = run.player
	var x0 := p.position.x
	Input.action_press("move_right")
	Input.action_press("shoot")
	await _wait(0.6)
	_check("WASD movement accelerates player", p.position.x > x0 + 15.0, "dx=%.1f" % (p.position.x - x0))
	_check("held shoot fires weapon", p.weapon.shots_fired > 0, "shots=%d" % p.weapon.shots_fired)
	Input.action_release("shoot")
	await get_tree().process_frame
	Input.action_press("dash")
	await _wait(0.1)
	Input.action_release("dash")
	_check("dash cooldown starts", p.dash_cd > 0.0)
	Input.action_release("move_right")
	p.weapon.heat.heat = 60.0
	await get_tree().process_frame
	Input.action_press("vent")
	await _wait(0.1)
	Input.action_release("vent")
	_check("vent key dumps heat", p.weapon.heat.heat < 20.0, "heat=%.0f" % p.weapon.heat.heat)
	menu = null
	run._open_overlay()
	run.overlay.show_pause()
	await _wait(0.3)
	_check("pause opens + pauses tree", get_tree().paused)
	run._close_overlay()
	_check("pause closes", not get_tree().paused)
	# checkpoint save/restore
	Game.hp = 5
	Game.checkpoint()
	var snap: Dictionary = Save.data["run"].duplicate(true)
	_check("checkpoint stored", not snap.is_empty() and snap["hp"] == 5)
	await _go("menu")
	_check("back to menu", get_tree().current_scene.name == "MainMenu")
	_check("continue available", Save.has_run())
	await _go("workshop")
	var hub := get_tree().current_scene
	_check("workshop hub loads", hub.name == "WorkshopHub")
	for id in ["bay", "furnace", "recycler", "character", "codex", "launch"]:
		hub._activate(id)
		await _wait(0.2)
		_check("hub station %s opens" % id, hub._panel != null)
		hub._close_panel()
	# settings panel + remap
	var sp := SettingsPanel.new()
	add_child(sp)
	await _wait(0.2)
	sp._begin_remap("dash")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_K
	ev.pressed = true
	sp._input(ev)
	_check("key remap works", Settings.keys["dash"] == KEY_K and InputMap.action_get_events("dash").any(func(e: InputEvent) -> bool: return e is InputEventKey and e.physical_keycode == KEY_K))
	Settings.reset_keys()
	print("ALL PASSED" if not failed else "SOME FAILED")
	get_tree().quit(1 if failed else 0)
