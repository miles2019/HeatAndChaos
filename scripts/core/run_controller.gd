class_name RunController
extends Node2D
## Owns one run: rooms, player, pools, camera, HUD, post FX and overlays.
## Exposes the world API used by modules/enemies via Game.world.

const POOL_SIZE := 360

var player: Player
var rooms: RoomManager
var camera := Camera2D.new()
var hud: Hud
var post: PostFx
var overlay_layer := CanvasLayer.new()
var overlay: RunOverlay
var panel: Control
var projectiles: Array[Projectile] = []
var proj_root := Node2D.new()
var world_root := Node2D.new()
var fog_amount := 0.0
var overlay_open := false
var ending := false
var _pool_i := 0
var _end_timer := -1.0
var _end_victory := false
var _prev_hp := -1
const BASE_ZOOM := 1.5
var cam_pos := Vector2(320, 180)
var _snap_cam := true
var _build_cycle := 0

func _ready() -> void:
	Game.world = self
	if Game.loadout == null:
		Game.new_run({})
	if Game.stats.is_empty():
		Game.reset_stats()
	Juice.reset()
	world_root.name = "World"
	add_child(world_root)
	rooms = RoomManager.new()
	rooms.world = self
	add_child(rooms)
	rooms.build(world_root)
	proj_root.name = "Projectiles"
	proj_root.z_index = 5
	world_root.add_child(proj_root)
	for i in POOL_SIZE:
		var p := Projectile.new()
		proj_root.add_child(p)
		projectiles.append(p)
	player = Player.new()
	player.name = "Player"
	world_root.add_child(player)
	player.died.connect(_on_player_died)
	camera.position = Vector2(320, 180)
	add_child(camera)
	camera.make_current()
	hud = Hud.new()
	hud.player = player
	hud.rooms = rooms
	add_child(hud)
	post = PostFx.new()
	add_child(post)
	overlay_layer.layer = 30
	overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay_layer)
	Game.run_ended.connect(_on_run_ended)
	rooms.enter(Game.room_index, -1)
	Audio.start_music()
	_capture_mouse(true)
	Game.player_hp_changed.emit(Game.hp, Game.max_hp)

func _exit_tree() -> void:
	_capture_mouse(false)
	Audio.stop_music()
	Juice.reset()
	Juice.field = null
	Juice.heat = 0.0
	Juice.instability = 0.0
	if Game.world == self:
		Game.world = null
	for c in Game.run_ended.get_connections():
		Game.run_ended.disconnect(c["callable"])

func _capture_mouse(on: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if on else Input.MOUSE_MODE_VISIBLE

# ---- world API ---------------------------------------------------------------------------------
func current_room() -> Room:
	return rooms.current

func acquire_projectile() -> Projectile:
	for i in POOL_SIZE:
		var idx := (_pool_i + i) % POOL_SIZE
		if not projectiles[idx].active:
			_pool_i = (idx + 1) % POOL_SIZE
			return projectiles[idx]
	return null

func release_projectile(_p: Projectile) -> void:
	pass

func clear_projectiles() -> void:
	for p in projectiles:
		p.active = false
		p.visible = false

func spawn_effect(kind: String, pos: Vector2, params: Dictionary) -> WorldEffect:
	var room := current_room()
	if kind == "acid" and not params.get("hostile", false):
		for g in get_tree().get_nodes_in_group("acid"):
			if g.position.distance_to(pos) < 9.0:
				g.merge(params.get("radius", 12.0))
				return g
		if get_tree().get_nodes_in_group("acid").size() > 70:
			return null
	var e := WorldEffect.new()
	e.setup(kind, pos, params)
	room.content.add_child(e)
	return e

func spawn_pickup(kind: String, pos: Vector2, amount: int, module_id: StringName = &"", cost: String = "") -> void:
	var p := Pickup.new()
	p.kind = kind
	p.amount = amount
	p.module_id = module_id
	p.cost = cost
	p.position = pos
	p.room = current_room()
	current_room().content.add_child(p)

func ignite_acid() -> void:
	var pools := get_tree().get_nodes_in_group("acid")
	pools.sort_custom(func(a: Node2D, b: Node2D) -> bool: return a.position.distance_to(player.position) < b.position.distance_to(player.position))
	var i := 0
	for g in pools:
		(g as WorldEffect).ignite(0.04 * i + g.position.distance_to(player.position) * 0.0012)
		i += 1
	if i > 0:
		Game.toast.emit("CHAIN IGNITION x%d" % i, Pal.LIME)

func dense_cluster(pos: Vector2, dir: Vector2, rng: float) -> Vector2:
	var best := Vector2.INF
	var best_score := -999.0
	var room := current_room()
	for e in room.enemies:
		if not is_instance_valid(e) or e.dead or e.spawn_t > 0.0:
			continue
		var to: Vector2 = e.position - pos
		var d := to.length()
		if d > rng or absf(dir.angle_to(to)) > deg_to_rad(80.0):
			continue
		var score := 0.0
		for o in room.enemies:
			if is_instance_valid(o) and not o.dead and o.position.distance_to(e.position) < 55.0:
				score += 1.0
		score -= d / rng * 0.5
		if score > best_score:
			best_score = score
			best = e.position
	return best

func on_boss_defeated(act_no: int) -> void:
	rooms.boss_cleared()
	if act_no < 4:
		Game.toast.emit("ACT %d COMPLETE - the way onward opens" % act_no, Pal.CYAN)
		return
	ending = true
	_end_timer = -1.0
	Game.toast.emit("THE PULSE FALLS SILENT. DECIDE ITS FATE.", Pal.CYAN)
	await get_tree().create_timer(1.8, false).timeout
	_open_overlay()
	overlay.show_endings()

func _on_player_died() -> void:
	ending = true
	_end_victory = false
	_end_timer = 2.0

func _on_run_ended(sm: Dictionary) -> void:
	_open_overlay()
	overlay.show_summary(sm)

# ---- overlays ----------------------------------------------------------------------------------
func _ensure_overlay() -> void:
	if overlay == null or not is_instance_valid(overlay):
		overlay = RunOverlay.new()
		overlay.resume.connect(_close_overlay)
		overlay.to_menu.connect(_to_menu)
		overlay.to_workshop.connect(func() -> void: Router.go("workshop"))
		overlay.new_run.connect(_restart_run)
		overlay.open_settings.connect(_open_settings)
		overlay_layer.add_child(overlay)

func _open_overlay() -> void:
	_ensure_overlay()
	overlay.visible = true
	overlay_open = true
	get_tree().paused = true
	_capture_mouse(false)

func _close_overlay() -> void:
	if overlay:
		overlay.visible = false
	if panel and is_instance_valid(panel):
		panel.queue_free()
		panel = null
	overlay_open = false
	get_tree().paused = false
	_capture_mouse(true)

func _to_menu() -> void:
	if not ending:
		Game.checkpoint()
	Router.go("menu")

func _restart_run() -> void:
	Game.new_run(Game.pending_setup if not Game.pending_setup.is_empty() else {})
	Router.go("run")

func _open_settings() -> void:
	var sp := SettingsPanel.new()
	sp.closed.connect(func() -> void:
		sp.queue_free()
		if overlay:
			overlay.show_pause())
	overlay_layer.add_child(sp)

func open_bay() -> void:
	_ensure_overlay()
	overlay.visible = false
	overlay_open = true
	get_tree().paused = true
	_capture_mouse(false)
	var b := WeaponBayPanel.new()
	panel = b
	b.closed.connect(func() -> void:
		b.queue_free()
		panel = null
		overlay_open = false
		get_tree().paused = false
		_capture_mouse(true))
	overlay_layer.add_child(b)

# ---- loop ----------------------------------------------------------------------------------------
func _process(dt: float) -> void:
	var can_act := not overlay_open and not ending
	if not overlay_open:
		Game.stats["time"] += dt
		rooms.update(dt)
		player.tick(dt, can_act)
		var room := current_room()
		if room.kind == "workshop" and can_act and not Game.test_mode:
			if Input.is_action_just_pressed("interact") and player.position.distance_to(room.bench_pos) < 46.0:
				open_bay()
		for i in 3:
			if room.kind == "workshop" and Input.is_action_just_pressed("preset_%d" % (i + 1)) and can_act:
				_quick_preset(i)
	if _end_timer > 0.0:
		_end_timer -= dt
		if _end_timer <= 0.0:
			Game.end_run(_end_victory)
	_update_camera(dt)
	Audio.set_heat(Juice.heat, Juice.instability)

func _quick_preset(i: int) -> void:
	var p: Array = Save.data["presets"][i]
	if p.size() != 3:
		Game.toast.emit("Preset %d empty - save one at the bench [E]" % (i + 1), Pal.RED)
		return
	for id in p:
		if not Game.owns(StringName(id)):
			Game.toast.emit("Preset %d needs modules you don't own" % (i + 1), Pal.RED)
			return
	Game.equip(p)
	player.weapon.set_loadout(Game.loadout)
	Game.toast.emit("PRESET %d LOADED" % (i + 1), Pal.AMBER)

func snap_camera() -> void:
	_snap_cam = true

func _update_camera(dt: float) -> void:
	var room := current_room()
	var half := Vector2(320, 180) / Juice.cam_zoom
	var want := player.position + player.aim_dir * 34.0 + Vector2(0, -6)
	var b := room.inner.grow(24.0)
	var lo := b.position + half
	var hi := b.end - half
	want.x = (lo.x + hi.x) * 0.5 if lo.x > hi.x else clampf(want.x, lo.x, hi.x)
	want.y = (lo.y + hi.y) * 0.5 if lo.y > hi.y else clampf(want.y, lo.y, hi.y)
	if _snap_cam:
		_snap_cam = false
		cam_pos = want
	else:
		cam_pos = cam_pos.lerp(want, 1.0 - exp(-dt * 5.0))     # smooth follow
	camera.position = cam_pos
	var j := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * Juice.jitter
	camera.offset = Juice.cam_offset + j
	camera.rotation = Juice.cam_roll * 0.025
	camera.zoom = Vector2.ONE * BASE_ZOOM * Juice.cam_zoom

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") and not ending:
		if overlay_open:
			if panel == null and overlay and overlay.visible:
				_close_overlay()
		else:
			_open_overlay()
			overlay.show_pause()
		get_viewport().set_input_as_handled()
		return
	if overlay_open or not (e is InputEventKey and e.pressed and not e.echo):
		return
	# developer shortcuts: F1-F4 = monster builds, F6 = cycle all builds, F5 = spawn wave, F7 = next room, F8 = boss room
	var k: int = e.keycode
	if k >= KEY_F1 and k <= KEY_F4:
		var key: String = ModuleDB.BUILDS.keys()[k - KEY_F1]
		debug_equip(key)
	elif k == KEY_F5:
		for kind in ["stalker", "drone", "drone", "bulwark", "mortar", "turret", "slime", "hunter"]:
			rooms._spawn_wave([kind])
	elif k == KEY_F6:
		_build_cycle = (_build_cycle + 1) % ModuleDB.BUILDS.size()
		debug_equip(ModuleDB.BUILDS.keys()[_build_cycle])
	elif k == KEY_F7:
		var cur := current_room()
		if cur.exits.has(Room.R):
			rooms.enter(cur.exits[Room.R], Room.L)
	elif k == KEY_F8:
		for spec in rooms.plan:
			if spec["kind"] == "boss" and spec["act"] >= current_room().act and spec["idx"] != current_room().index:
				rooms.enter(spec["idx"], Room.L)
				break

func debug_equip(build_key: String) -> void:
	var b: Dictionary = ModuleDB.BUILDS[build_key]
	for id in ModuleDB.order:
		Game.own(id)
	Game.equip(b["ids"])
	player.weapon.set_loadout(Game.loadout)
	Game.toast.emit("BUILD: %s" % String(b["name"]).to_upper(), Pal.AMBER)
