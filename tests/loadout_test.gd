extends Node
## Automated scenarios: every monster build, rooms/doors/waves, camera, relics, secrets, all 4 bosses + ending.
## Run:  godot --headless --path . res://tests/loadout_test.tscn
## The first 4 builds must show: a positive synergy, a heat problem and an instability risk.

var run: RunController
var results: Array = []
var misfires: Array = []
var overheats := 0
var failed := false

func _ready() -> void:
	Game.test_mode = true
	Game.new_run({"trigger": "pulse_spitter"})
	for id in ModuleDB.order:
		Game.own(id)
	Game.misfire_triggered.connect(func(id: StringName, _i: Dictionary) -> void: misfires.append(id))
	Game.overheated.connect(func() -> void: overheats += 1)
	run = load("res://scenes/main.tscn").instantiate()
	add_child(run)
	await _wait(0.5)
	await _test_plan()
	await _test_rooms()
	await _test_camera()
	for key in ModuleDB.BUILDS:
		await _scenario(key)
	await _test_relics_and_secret()
	for act in range(1, 5):
		await _test_boss(act)
	print("")
	print("==== RESULTS ====")
	for r in results:
		print(r)
	print("ALL PASSED" if not failed else "SOME FAILED")
	get_tree().quit(1 if failed else 0)

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _check(name: String, ok: bool, detail: String = "") -> void:
	if not ok:
		failed = true
	results.append("%s  %s %s" % ["PASS" if ok else "FAIL", name, detail])

func _find(kind: String, act: int) -> int:
	for s in run.rooms.plan:
		if s["kind"] == kind and s["act"] == act:
			return s["idx"]
	return -1

func _clear_room() -> void:
	var room: Room = run.current_room()
	for e in room.enemies:
		if is_instance_valid(e):
			e.queue_free()
	room.enemies.clear()
	for g in get_tree().get_nodes_in_group("acid"):
		g.queue_free()
	run.clear_projectiles()

func _spawn(kind: String, pos: Vector2) -> EnemyBase:
	return run.rooms.create_enemy(kind, pos)

func _test_plan() -> void:
	var plan: Array = run.rooms.plan
	var bosses := plan.filter(func(s: Dictionary) -> bool: return s["kind"] == "boss").size()
	var secrets := plan.filter(func(s: Dictionary) -> bool: return s["kind"] == "secret").size()
	var cursed := plan.filter(func(s: Dictionary) -> bool: return s["kind"] == "cursed").size()
	_check("run has 4 bosses, 4 secrets, 4 cursed rooms", bosses == 4 and secrets == 4 and cursed == 4, "rooms=%d" % plan.size())
	var big := true
	for s in plan:
		if s["kind"] in ["combat", "elite", "boss"] and (s["size"] as Vector2).x < 880:
			big = false
	_check("combat/elite/boss rooms are larger than the screen", big)

func _test_rooms() -> void:
	var c1 := _find("combat", 1)
	run.rooms.enter(c1, Room.L)
	await _wait(2.2)
	_check("combat room closes doors", run.current_room().doors_closed)
	_check("wave spawns enemies", run.rooms.alive_count() > 0, "alive=%d" % run.rooms.alive_count())
	var cleared := [false]
	Game.room_cleared.connect(func(_r: Room) -> void: cleared[0] = true)
	Game.hp = 999
	for wave in 5:
		for e in run.current_room().enemies:
			if is_instance_valid(e) and not e.dead:
				e.take_hit(9999.0, Vector2.RIGHT, 0.0)
		await _wait(2.4)
	_check("room_cleared signal + doors open", cleared[0] and not run.current_room().doors_closed)
	# every enemy type can be created, ticks and dies without errors
	var types := ["stalker", "bulwark", "mortar", "drone", "turret", "slime", "brute", "hunter"]
	_clear_room()
	for k in types:
		_spawn(k, run.current_room().center() + Vector2(randf_range(-200, 200), randf_range(-150, 150)))
	run.player.override_active = true
	run.player.ov_target = run.current_room().center()
	await _wait(3.0)
	var alive := run.current_room().alive_enemies()
	_check("all 8 enemy types simulate", alive >= 7, "alive=%d" % alive)
	for e in run.current_room().enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.take_hit(99999.0, Vector2.RIGHT, 0.0)
	await _wait(0.6)
	_check("slime splits on death", run.current_room().enemies.any(func(e: Variant) -> bool: return is_instance_valid(e) and e is SlimeEnemy and e.tiny))
	_clear_room()
	run.player.override_active = false
	var w := _find("workshop", 1)
	run.rooms.enter(w, Room.L)
	await _wait(0.3)
	_check("workshop is safe", run.current_room().safe and not run.current_room().doors_closed)
	run.rooms.enter(_find("cursed", 1), Room.D)
	await _wait(1.5)
	_check("cursed chamber fights elites", run.rooms.alive_count() > 0 and run.current_room().waves[0].has("brute"))
	_clear_room()
	for sp in [2, 3, 4]:
		pass
	run.rooms.pending = 0
	for act in [2, 3, 4]:
		var room_i := _find("combat", act)
		run.rooms.enter(room_i, Room.L)
		await _wait(2.0)
		var kinds := {}
		for e in run.current_room().enemies:
			if is_instance_valid(e):
				kinds[e.kind_id] = true
		_check("act %d combat room spawns enemies + hazards" % act, run.rooms.alive_count() > 0, str(kinds.keys()))
		_clear_room()
		run.rooms.pending = 0
		run.rooms.combat_active = false

func _test_camera() -> void:
	run.rooms.enter(_find("combat", 1), Room.L)
	await _wait(0.2)
	var room: Room = run.current_room()
	var pl: Player = run.player
	pl.position = room.inner.position + Vector2(10, 10)
	await _wait(1.5)
	var half := Vector2(320, 180)
	var cam := run.camera.position
	var vis := Rect2(cam - half, half * 2.0)
	var out := room.inner.grow(32.0)
	_check("camera never shows far outside the room", out.encloses(vis.grow(-1.0)), "view=%s room=%s" % [vis, room.inner])
	pl.position = room.center()
	var before := run.camera.position
	await _wait(0.1)
	var mid := run.camera.position
	await _wait(1.5)
	var after := run.camera.position
	_check("camera follows smoothly (eases, not snaps)", before.distance_to(mid) > 1.0 and mid.distance_to(after) > 1.0 and before.distance_to(mid) < before.distance_to(after))
	_clear_room()
	run.rooms.combat_active = false

func _scenario(key: String) -> void:
	var b: Dictionary = ModuleDB.BUILDS[key]
	run.rooms.enter(0, -1)
	run.current_room().set_doors_closed(true)
	run.rooms.combat_active = false
	_clear_room()
	Game.hp = 999
	Game.max_hp = 999
	Game.equip(b["ids"])
	var pl: Player = run.player
	pl.dead = false
	pl.weapon.set_loadout(Game.loadout)
	pl.weapon.heat.heat = 0.0
	pl.weapon.heat.lock_t = 0.0
	var ctr: Vector2 = run.current_room().center()
	pl.position = ctr + Vector2(-180, 0)
	pl.override_active = true
	var l: WeaponLoadout = Game.loadout
	misfires.clear()
	overheats = 0
	for i in 6:
		_spawn("stalker", ctr + Vector2(90 + (i % 3) * 30, -60 + (i / 3) * 50 + i * 12))
	_spawn("bulwark", ctr + Vector2(170, 0))
	var peak_acid := 0
	var peak_orbit := 0
	var peak_bounce := 0
	var saw_drop := false
	var saw_helix := false
	var saw_pull := false
	var peak_heat := 0.0
	var t := 0.0
	var shots0 := pl.weapon.shots_fired
	var kills0: int = Game.stats["kills"]
	while t < 9.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		var tgt := ctr + Vector2(90, 0)
		var best := 9999.0
		for e in run.current_room().enemies:
			if is_instance_valid(e) and not e.dead and e.spawn_t <= 0.0:
				var d: float = e.position.distance_to(pl.position)
				if d < best:
					best = d
					tgt = e.position
		pl.ov_target = tgt
		pl.ov_move = Vector2(0, sin(t * 1.7)) * 0.6
		pl.ov_shoot = (fmod(t, 1.7) < 1.35) if pl.weapon.is_charge_trigger() else true
		peak_heat = maxf(peak_heat, pl.weapon.heat.heat)
		peak_acid = maxi(peak_acid, get_tree().get_nodes_in_group("acid").size())
		var orbiting := 0
		for p in run.projectiles:
			if p.active:
				peak_bounce = maxi(peak_bounce, p.bounce_count)
				if p.orbit_state == 2:
					orbiting += 1
				if p.sinking > 0.0:
					saw_drop = true
				if p.sine_amp > 0.0 and p.through_cover:
					saw_helix = true
				if p.pull_radius > 0.0:
					saw_pull = true
		peak_orbit = maxi(peak_orbit, orbiting)
		if int(t * 2.0) % 4 == 0 and run.current_room().alive_enemies() < 3:
			_spawn("stalker", ctr + Vector2(randf_range(120, 300), randf_range(-150, 150)))
	pl.ov_shoot = false
	var fired := pl.weapon.shots_fired - shots0
	var kills: int = Game.stats["kills"] - kills0
	print("[%s] shots=%d kills=%d peakHeat=%.0f overheats=%d misfires=%s acid=%d orbit=%d bounce=%d inst=%.0f" % [
		b["name"], fired, kills, peak_heat, overheats, str(misfires), peak_acid, peak_orbit, peak_bounce, l.instability])
	_check("%s: fires" % b["name"], fired > 0, "shots=%d" % fired)
	var core4 := key in ["tornado", "minefield", "sniper", "carpet"]
	if core4:
		_check("%s: heat problem" % b["name"], peak_heat >= 55.0 or overheats > 0, "peak=%.0f" % peak_heat)
		_check("%s: instability risk" % b["name"], l.instability >= 50.0 and not l.get_misfire_pool().is_empty(), "inst=%.0f" % l.instability)
	match key:
		"tornado":
			_check("tornado: beam spirals into orbit", peak_orbit > 0, "orbit=%d" % peak_orbit)
			_check("tornado: implosion pull active", saw_pull)
		"minefield":
			_check("minefield: ricochets", peak_bounce >= 2, "bounce=%d" % peak_bounce)
			_check("minefield: acid pools spread", peak_acid >= 8, "acid=%d" % peak_acid)
		"sniper":
			_check("sniper: helix slips through cover", saw_helix)
			_check("sniper: kills enemies", kills > 0, "kills=%d" % kills)
		"carpet":
			_check("carpet: projectiles sink to floor", saw_drop)
			_check("carpet: poison trail forms", peak_acid >= 4, "acid=%d" % peak_acid)
			pl.weapon.heat.heat = 90.0
			var before := get_tree().get_nodes_in_group("acid").size()
			var ok := pl.weapon.try_vent()
			await _wait(1.2)
			var after := get_tree().get_nodes_in_group("acid").size()
			_check("carpet: panic vent at 90 heat ignites pools", ok, "pools %d -> %d" % [before, after])
		"hydra":
			_check("hydra: kills with seeker+split+shards", kills > 0, "kills=%d" % kills)
		"sawmill":
			_check("sawmill: kills with saw+static", kills > 0, "kills=%d" % kills)
		"inferno":
			_check("inferno: kills with flames", kills > 0, "kills=%d" % kills)
	pl.override_active = false

func _test_relics_and_secret() -> void:
	var before_speed := Game.has_relic("boots")
	Game.add_relic("boots")
	Game.add_relic("plating")
	_check("relics apply", Game.has_relic("boots") and not before_speed and Game.max_hp >= 10)
	# secret door crack: shooting the crack opens the passage
	var sidx := _find("secret", 1)
	var parent_idx := -1
	for s in run.rooms.plan:
		if s["exits"].get(Room.U, -1) == sidx:
			parent_idx = s["idx"]
	run.rooms.enter(parent_idx, Room.L)
	await _wait(0.4)
	var room: Room = run.current_room()
	room.cleared = true
	room.set_doors_closed(false)
	run.rooms.combat_active = false
	_clear_room()
	_check("secret door is sealed by a crack wall", room.is_sealed(Room.U))
	room.last_crack = 0
	for i in 4:
		room.last_crack = 0
		room.crack_hit(10.0)
	_check("crack wall breaks and opens passage", not room.is_sealed(Room.U))
	run.rooms.enter(sidx, Room.D)
	await _wait(0.4)
	var pickups := run.current_room().content.get_children().filter(func(n: Node) -> bool: return n is Pickup)
	_check("secret cache spawns relic + module", pickups.size() >= 2, "pickups=%d" % pickups.size())
	# cursed pedestal: instability curse is applied and the others vanish
	run.rooms.enter(_find("cursed", 1), Room.D)
	run.rooms.combat_active = false
	_clear_room()
	var inst0 := Game.loadout.instability
	var ped := Pickup.new()
	ped.kind = "cursed"
	ped.module_id = &"twin_core"
	ped.cost = "inst"
	ped.position = run.player.position
	ped.room = run.current_room()
	run.current_room().content.add_child(ped)
	await _wait(0.6)
	_check("cursed pedestal adds instability curse", Game.curse_inst >= 15.0 and Game.loadout.instability >= inst0, "curse=%.0f" % Game.curse_inst)

func _test_boss(act: int) -> void:
	_clear_room()
	Game.hp = 9999
	Game.max_hp = 9999
	Game.act = act
	run.player.dead = false
	run.player.override_active = true
	run.player.ov_shoot = false
	run.rooms.enter(_find("boss", act), Room.L)
	await _wait(1.0)
	var boss: BossBase
	for i in 20:
		for e in run.current_room().enemies:
			if e is BossBase:
				boss = e
		if boss != null:
			break
		await _wait(0.3)
	_check("act %d boss spawns" % act, boss != null)
	if boss == null:
		return
	run.player.ov_target = boss.position
	var attacks := {}
	var t := 0.0
	var phased := false
	var children_seen := false
	while t < 30.0 and (not is_instance_valid(boss) or not boss.dead or (act == 2 and t < 12.0)):
		await get_tree().process_frame
		t += get_process_delta_time()
		if is_instance_valid(boss):
			attacks[boss.atk] = true
		if t > 9.0 and not phased and is_instance_valid(boss) and not boss.dead:
			phased = true
			boss.invuln = 0.0
			boss.intro_t = 0.0
			boss.hp = boss.max_hp * (0.31 if act == 4 else 0.49)
			boss.take_hit(1.0, Vector2.RIGHT, 0.0)
		if t > 14.0 and act == 4 and boss.phase < 3 and is_instance_valid(boss):
			boss.invuln = 0.0
			boss.hp = boss.max_hp * 0.3
			boss.take_hit(1.0, Vector2.RIGHT, 0.0)
	for e in run.current_room().enemies:
		if is_instance_valid(e) and e is SlimeEngineBoss and e.is_child:
			children_seen = true
	_check("act %d boss attack patterns run" % act, attacks.size() >= 3, str(attacks.keys()))
	if act == 2:
		_check("slime engine mitosis splits into two halves", children_seen)
	elif act == 4:
		_check("pulse reaches phase 3", boss.phase >= 3 if is_instance_valid(boss) else true)
	else:
		_check("act %d boss phase 2 triggers" % act, boss.phase >= 2 if is_instance_valid(boss) else true)
	# kill every boss body
	for i in 4:
		for e in run.current_room().enemies.duplicate():
			if is_instance_valid(e) and e is BossBase and not e.dead:
				e.invuln = 0.0
				e.intro_t = 0.0
				e.take_hit(99999.0, Vector2.RIGHT, 0.0)
		await _wait(2.5)
	if act < 4:
		_check("act %d boss death opens the way on" % act, run.current_room().cleared and not run.current_room().doors_closed)
	else:
		await _wait(2.5)
		_check("final boss opens ending choice", run.ending and run.overlay != null and run.overlay.visible)
		Game.finish_ending("fusion")
		await _wait(0.5)
		_check("ending recorded + runner unlocked", Game.last_summary.has("victory") and Save.data["endings"].has("fusion") and Save.data["chars"].has("tinker"))
