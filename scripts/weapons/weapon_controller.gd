class_name WeaponController
extends Node
## Fires the loadout: trigger -> trajectory -> catalyst pipeline, recoil, heat, misfires and panic vent.

var player
var heat: HeatSystem
var instab: InstabilitySystem
var loadout: WeaponLoadout
var fire_cd := 0.0
var charge := 0.0
var charging := false
var gun_spring := SquashSpring.new(320.0, 9.0)
var runaway_left := 0
var runaway_t := 0.0
var last_misfire: StringName = &""
var shots_fired := 0

func _init() -> void:
	heat = HeatSystem.new()
	instab = InstabilitySystem.new()
	add_child(heat)
	add_child(instab)

func set_loadout(l: WeaponLoadout) -> void:
	loadout = l
	loadout.recalculate()
	instab.set_loadout(loadout)
	charge = 0.0
	charging = false
	Game.note_synergy(loadout)
	Game.loadout_changed.emit()

func is_charge_trigger() -> bool:
	return loadout.trigger_module.charge_time > 0.0

func update(dt: float, aim: Vector2, shoot_held: bool, can_act: bool) -> void:
	gun_spring.update(dt)
	heat.update(dt)
	fire_cd = maxf(0.0, fire_cd - dt)
	Juice.heat = heat.ratio()
	Juice.instability = instab.value() / 100.0
	Game.stats["max_heat"] = maxf(Game.stats["max_heat"], heat.heat)
	Game.stats["max_instability"] = maxf(Game.stats["max_instability"], instab.value())
	if runaway_left > 0:
		runaway_t -= dt
		if runaway_t <= 0.0:
			runaway_t = 0.06
			runaway_left -= 1
			_spawn_shots(Vector2.from_angle(randf() * TAU), 1.0, &"", true)
	if not can_act or heat.is_locked():
		if charging:
			charging = false
			charge = 0.0
		return
	var trig := loadout.trigger_module
	if is_charge_trigger():
		if shoot_held and fire_cd <= 0.0:
			if not charging:
				charging = true
				Audio.play("charge", 1.0, -6.0)
			charge = minf(1.0, charge + dt / trig.charge_time)
			heat.add(trig.charge_heat_per_sec * dt)
			if charge > 0.15 and int(Time.get_ticks_msec() / 70) % 2 == 0:
				var tip: Vector2 = player.position + aim * 10.0
				Juice.burst(tip + Vector2.from_angle(randf() * TAU) * 14.0, trig.color, 1, 8.0, Vector2.ZERO, TAU, 0.15, 2.0)
		elif charging:
			charging = false
			if charge >= 0.2:
				_fire(aim, charge)
				fire_cd = 1.0 / trig.shots_per_second
			charge = 0.0
	else:
		if shoot_held and fire_cd <= 0.0:
			_fire(aim, 1.0)
			fire_cd = 1.0 / trig.shots_per_second

func _fire(aim: Vector2, charge_ratio: float) -> void:
	var mis := instab.consume()
	_spawn_shots(aim, charge_ratio, mis, false)
	shots_fired += 1

func _spawn_shots(aim: Vector2, charge_ratio: float, mis: StringName, wild: bool) -> void:
	var w = Game.world
	if w == null:
		return
	var trig := loadout.trigger_module
	var dir := aim
	if mis == &"phase_flip":
		dir = -aim
	var origin: Vector2 = player.position + dir * 9.0
	var ctx := {"origin": origin, "dir": dir, "charge": charge_ratio, "heat": heat.ratio(), "loadout": loadout}
	var shots := trig.fire(ctx)
	var first: Projectile = null
	for s in shots:
		var p: Projectile = w.acquire_projectile()
		if p == null:
			break
		p.setup(s, origin, 0)
		trig.modify_projectile(p)
		loadout.trajectory_module.modify_projectile(p)
		loadout.catalyst_module.modify_projectile(p)
		if mis == &"boomerang":
			p.boomerang = true
		if mis == &"pull_to_shot" and first == null:
			p.pull_player_t = 0.7
		if first == null:
			first = p
	var rmult := 1.0
	if mis == &"recoil_pushback":
		rmult = 3.2
	elif mis == &"flipper_recoil":
		rmult = 2.0 + heat.heat / 35.0
		player.launch(Vector2.ZERO, 1.6, 0.95, false)
	var rc := trig.recoil * rmult * lerpf(0.5, 1.0, charge_ratio) * (0.5 if wild else 1.0)
	player.apply_impulse(-aim * rc)
	if not wild:
		heat.add(loadout.heat_per_shot() * lerpf(0.6, 1.0, charge_ratio))
	# --- juice: anticipation is the pull-back, impact the muzzle burst, rebound the spring overshoot ---
	gun_spring.squash(Vector2(0.45 if trig.pellets > 3 or charge_ratio > 0.8 else 0.6, 1.3))
	gun_spring.punch(Vector2(2.0, -1.0))
	player.rig.punch_dir(aim, 0.15 + rc / 500.0)
	var heavy := trig.recoil >= 100.0 or trig.charge_time > 0.0
	Juice.burst(origin, trig.color.lerp(Color.WHITE, 0.3), 3 + trig.pellets, 120.0 + rc * 0.4, dir, 0.8, 0.18, 2.0)
	Juice.shake(-aim, clampf(rc / 110.0, 0.25, 2.2), 0.0)
	if heavy:
		Audio.play("beam" if trig.charge_time > 0.0 else "shot_heavy", 1.0, -2.0)
		Juice.zoom_punch(-0.25)
		Juice.hit_stop(2)
	else:
		Audio.play("shot", randf_range(0.9, 1.15) * lerpf(1.0, 0.8, heat.ratio()), -9.0)
	Game.weapon_fired.emit(ctx)
	if mis != &"":
		_apply_misfire(mis, aim)

func _apply_misfire(id: StringName, aim: Vector2) -> void:
	last_misfire = id
	var info: Dictionary = ModuleDB.MISFIRES[id]
	var col: Color = info["color"]
	match id:
		&"acid_trail":
			player.acid_trail_t = 3.0
		&"launch_back":
			player.launch(-aim * 520.0, 0.5, 0.55, true)
		&"capacitor_arc":
			player.take_damage(1, player.position + Vector2(8, -8))
			heat.add(15.0)
			var tgt: Vector2 = player.position + Vector2.from_angle(randf() * TAU) * 40.0
			Game.world.spawn_effect("arc", player.position, {"a": player.position, "b": tgt})
		&"mag_overpressure":
			heat.add(25.0)
			Juice.burst(player.position, Pal.WHITE, 12, 80.0, Vector2.UP, 1.5, 0.6, 3.0, ParticleField.SMOKE)
		&"runaway_cadence":
			runaway_left = 6
		&"glitch_heat_spike":
			heat.add(20.0)
		&"glitch_scatter":
			runaway_left = 6
		&"glitch_input_swap":
			player.inverted_t = 1.2
	# readable, juicy feedback: distortion wave + chroma + roll shake + coloured ring
	Game.stats["misfires"] += 1
	Game.misfire_triggered.emit(id, info)
	var glitch := String(id).begins_with("glitch")
	Audio.play("glitch" if glitch else "misfire", 1.0, -3.0, "Feedback")
	Audio.duck(-8.0, 0.4)
	Juice.wave(player.position, 0.9, 0.6)
	Juice.aberrate(0.014)
	Juice.shake(Vector2.ZERO, 3.2, 1.2, 0.8)
	Juice.flash(col, 0.25)
	Juice.ring(player.position, col, 46.0, 0.4)
	Juice.burst(player.position, col, 14, 110.0)
	Juice.text(player.position + Vector2(0, -20), info["name"], col, 8, true)
	player.rig.spring.punch(Vector2(-4.0, 4.0))

func try_vent() -> bool:
	if not heat.vent_ready():
		return false
	var h := heat.vent()
	var pos: Vector2 = player.position
	var w = Game.world
	charging = false
	charge = 0.0
	w.spawn_effect("shock", pos, {"radius": 48.0 + h * 54.0, "force": 380.0, "damage": 8.0 + h * 36.0, "stun": 0.9, "color": Pal.RED, "dur": 0.35})
	loadout.catalyst_module.on_vent({"pos": pos, "heat": h})
	Juice.big_effect(pos, Pal.RED, 0.5 + h * 0.5)
	Juice.burst(pos, Pal.AMBER, 10 + int(h * 20.0), 140.0, Vector2.ZERO, TAU, 0.8, 3.0, ParticleField.SMOKE)
	Audio.play("vent", 1.0 - h * 0.3)
	player.rig.spring.punch(Vector2(6.0, 6.0))
	Game.vent_used.emit(h)
	return true
