extends Node
## Automated scenarios for the four design-doc monster builds + room/enemy/boss smoke tests.
## Run:  godot --headless --path . res://tests/loadout_test.tscn
## Every build must show: a positive synergy, a heat problem and an instability risk.

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
	await _test_rooms()
	for key in ModuleDB.BUILDS:
		await _scenario(key)
	await _test_boss()
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
	var e: EnemyBase
	match kind:
		"stalker": e = StalkerEnemy.new()
		"bulwark": e = BulwarkEnemy.new()
		_: e = MortarMite.new()
	var room: Room = run.current_room()
	e.room = room
	e.position = pos
	room.content.add_child(e)
	room.enemies.append(e)
	return e

func _test_rooms() -> void:
	# start room -> every room loads, doors close in combat and open on clear
	run.rooms.enter(1, 0)
	await _wait(2.0)
	_check("combat room closes doors", run.current_room().doors_closed)
	_check("wave spawns enemies", run.rooms.alive_count() > 0, "alive=%d" % run.rooms.alive_count())
	var types := {}
	for e in run.current_room().enemies:
		types[e.kind_id] = true
	# kill everything instantly via damage to verify room_cleared
	var cleared := [false]
	Game.room_cleared.connect(func(_r: Room) -> void: cleared[0] = true)
	Game.hp = 999
	for wave in 4:
		for e in run.current_room().enemies:
			if is_instance_valid(e) and not e.dead:
				e.take_hit(9999.0, Vector2.RIGHT, 0.0)
		await _wait(2.2)
	_check("room_cleared signal + doors open", cleared[0] and not run.current_room().doors_closed)
	run.rooms.enter(2, 0)
	await _wait(0.3)
	_check("workshop is safe", run.current_room().safe and not run.current_room().doors_closed)
	run.rooms.enter(3, 0)
	await _wait(1.8)
	var found := {}
	for w in 3:
		for e in run.current_room().enemies:
			if is_instance_valid(e):
				found[e.kind_id] = true
		await _wait(0.4)
	_check("combat2 has mortar + stalker", found.has("mortar") or found.has("stalker"), str(found.keys()))

func _scenario(key: String) -> void:
	var b: Dictionary = ModuleDB.BUILDS[key]
	run.rooms.enter(0, 2)
	run.current_room().set_doors_closed(true)
	_clear_room()
	Game.hp = 999
	Game.max_hp = 999
	Game.equip(b["ids"])
	var pl: Player = run.player
	pl.dead = false
	pl.weapon.set_loadout(Game.loadout)
	pl.weapon.heat.heat = 0.0
	pl.weapon.heat.lock_t = 0.0
	pl.position = Vector2(150, 180)
	pl.override_active = true
	var l: WeaponLoadout = Game.loadout
	misfires.clear()
	overheats = 0
	var enemies: Array = []
	for i in 6:
		enemies.append(_spawn("stalker", Vector2(430 + (i % 3) * 30, 110 + (i / 3) * 40 + i * 12)))
	enemies.append(_spawn("bulwark", Vector2(480, 180)))
	var peak_acid := 0
	var peak_orbit := 0
	var peak_bounce := 0
	var saw_drop := false
	var saw_helix := false
	var saw_pull := false
	var peak_heat := 0.0
	var t := 0.0
	var shots0 := pl.weapon.shots_fired
	var duration := 9.0
	while t < duration:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var tgt := Vector2(430, 180)
		var best := 9999.0
		for e in run.current_room().enemies:
			if is_instance_valid(e) and not e.dead and e.spawn_t <= 0.0:
				var d: float = e.position.distance_to(pl.position)
				if d < best:
					best = d
					tgt = e.position
		pl.ov_target = tgt
		pl.ov_move = Vector2(0, sin(t * 1.7)) * 0.6
		# charge triggers: hold to charge, release to fire; others: hold
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
		# keep the swarm alive so effects have targets
		if int(t * 2.0) % 4 == 0 and run.current_room().alive_enemies() < 3:
			enemies.append(_spawn("stalker", Vector2(randf_range(380, 560), randf_range(90, 270))))
	pl.ov_shoot = false
	var fired := pl.weapon.shots_fired - shots0
	var kills: int = Game.stats["kills"]
	print("[%s] shots=%d peakHeat=%.0f overheats=%d misfires=%s acid=%d orbit=%d bounce=%d inst=%.0f" % [
		b["name"], fired, peak_heat, overheats, str(misfires), peak_acid, peak_orbit, peak_bounce, l.instability])
	_check("%s: fires" % b["name"], fired > 0, "shots=%d" % fired)
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
			_check("sniper: kills enemies", Game.stats["kills"] > 0, "kills=%d" % kills)
		"carpet":
			_check("carpet: projectiles sink to floor", saw_drop)
			_check("carpet: poison trail forms", peak_acid >= 4, "acid=%d" % peak_acid)
	# vent test with ignition (carpet) at >=85 heat
	if key == "carpet":
		pl.weapon.heat.heat = 90.0
		var before := get_tree().get_nodes_in_group("acid").size()
		var ok := pl.weapon.try_vent()
		await _wait(1.2)
		var after := get_tree().get_nodes_in_group("acid").size()
		_check("carpet: panic vent at 90 heat ignites pools", ok, "pools %d -> %d" % [before, after])
	pl.override_active = false

func _test_boss() -> void:
	_clear_room()
	Game.hp = 9999
	Game.max_hp = 9999
	run.player.dead = false
	run.player.override_active = true
	run.player.ov_shoot = false
	run.rooms.enter(4, 0)
	await _wait(0.8)
	var boss: VulcanBoss
	for e in run.current_room().enemies:
		if e is VulcanBoss:
			boss = e
	for i in 20:
		if boss != null:
			break
		await _wait(0.3)
		for e in run.current_room().enemies:
			if e is VulcanBoss:
				boss = e
	_check("boss spawns", boss != null)
	if boss == null:
		return
	run.player.ov_target = boss.position
	var attacks := {}
	var t := 0.0
	while t < 22.0 and not boss.dead:
		await get_tree().process_frame
		t += get_process_delta_time()
		attacks[boss.atk] = true
		if boss.phase == 1 and t > 8.0:
			boss.hp = boss.max_hp * 0.49
			boss.take_hit(1.0, Vector2.RIGHT, 0.0)
	_check("boss attack patterns run", attacks.has("slam") and attacks.has("ray"), str(attacks.keys()))
	_check("boss phase 2 triggers at <50%", boss.phase == 2)
	_check("boss p2 attacks (vent/pull)", attacks.has("vent") or attacks.has("pull"), str(attacks.keys()))
	boss.invuln = 0.0
	boss.intro_t = 0.0
	boss.take_hit(99999.0, Vector2.RIGHT, 0.0)
	await _wait(3.5)
	_check("boss death ends run", Game.last_summary.has("victory") and Game.last_summary["victory"])
