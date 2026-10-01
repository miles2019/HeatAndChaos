class_name Player
extends Node2D
## Twin-stick runner. Own light-weight collision (circle vs Room), physical recoil/launch impulses,
## dash with ghost trail, squash/stretch rig. Ticked by the run controller so pausing is trivial.

signal died

const MAX_SPEED := 112.0
const ACCEL := 950.0
const DECEL := 1150.0
const DASH_SPEED := 360.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.85

var vel := Vector2.ZERO
var ext := Vector2.ZERO
var radius := 6.0
var aim_dir := Vector2.RIGHT
var aim_target := Vector2.ZERO
var stick_aim := false
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.RIGHT
var grace_t := 0.0
var iframes := 0.0
var dead := false
var acid_trail_t := 0.0
var launch_t := 0.0
var launch_rest := 0.0
var launch_hurts := false
var wall_cd := 0.0
var inverted_t := 0.0
var slow_t := 0.0
var burn_acc := 0.0
var ghosts: Array = []
var _ghost_t := 0.0
var _acid_t := 0.0
var _flame_t := 0.0
var _was_dashing := false

var rig: SquashRig
var weapon: WeaponController
var override_active := false     # automated test scenarios drive the player through these
var ov_move := Vector2.ZERO
var ov_target := Vector2.ZERO
var ov_shoot := false

func _ready() -> void:
	z_index = 2
	rig = SquashRig.new()
	rig.art.draw_fn = _draw_art
	rig.glow.draw_fn = _draw_glow
	add_child(rig)
	weapon = WeaponController.new()
	weapon.player = self
	add_child(weapon)
	weapon.heat.gain_mult = Game.char_data()["heat_gain"]
	weapon.set_loadout(Game.loadout)

func damage_mult() -> float:
	var m: float = Game.char_data().get("dmg", 1.0) * (1.0 + weapon.heat.ratio() * 0.4)     # heat is power
	if weapon.heat.ratio() >= 0.9:
		m *= Game.char_data()["hot_dmg"]
	return m

func apply_impulse(v: Vector2) -> void:
	ext += v

func launch(v: Vector2, time: float, restitution: float, hurts: bool) -> void:
	ext += v
	launch_t = maxf(launch_t, time)
	launch_rest = restitution
	launch_hurts = hurts

func heal(n: int) -> void:
	Game.hp = mini(Game.hp + n, Game.max_hp)
	Game.player_hp_changed.emit(Game.hp, Game.max_hp)
	Juice.burst(position, Pal.LIME, 10, 70.0, Vector2.UP, 1.5, 0.5, 2.0)
	Audio.play("pickup", 1.3)

func take_damage(amount: int, from: Vector2, ignore_iframes: bool = false) -> bool:
	if dead:
		return false
	if not ignore_iframes and (iframes > 0.0 or dash_t > 0.0 or grace_t > 0.0):
		return false
	Game.hp -= amount
	iframes = 1.1
	var away := (position - from).normalized() if position.distance_to(from) > 0.5 else Vector2.UP
	ext += away * 170.0
	rig.punch_dir(away, 0.5)
	Juice.hit_stop(4)
	Juice.shake(away, 3.0, 0.5, 0.3)
	Juice.flash(Pal.RED, 0.3)
	Juice.aberrate(0.01)
	Juice.burst(position, Pal.RED, 12, 120.0, away, 1.6, 0.4, 2.0)
	Juice.text(position + Vector2(0, -14), "-%d" % amount, Pal.RED, 8, true)
	Audio.play("hurt", 1.0, 0.0, "Feedback")
	Game.player_hp_changed.emit(Game.hp, Game.max_hp)
	if Game.hp <= 0:
		_die()
	return true

func _die() -> void:
	dead = true
	rig.visible = false
	Juice.big_effect(position, Pal.CYAN, 1.0)
	Juice.debris(position, Pal.STEEL, 26, 200.0)
	Juice.debris(position, Pal.CYAN, 10, 160.0)
	Audio.play("kill", 0.6)
	died.emit()

# ---- input -----------------------------------------------------------------------------------
func _input_move() -> Vector2:
	if override_active:
		return ov_move
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return v

func _update_aim(room) -> void:
	if override_active:
		aim_target = ov_target
		stick_aim = false
	else:
		var stick := Vector2(Input.get_axis("aim_left", "aim_right"), Input.get_axis("aim_up", "aim_down"))
		if stick.length() > 0.3:
			stick_aim = true
			aim_target = position + stick.normalized() * 90.0
		elif Input.get_last_mouse_velocity().length() > 0.0 or not stick_aim:
			stick_aim = false
			aim_target = get_global_mouse_position()
	var d := aim_target - position
	if d.length() > 2.0:
		aim_dir = d.normalized()
	if Settings.auto_aim and room != null:
		var best = null
		var best_d := 170.0
		for e in room.enemies:
			if not is_instance_valid(e) or e.dead:
				continue
			var to: Vector2 = e.position - position
			var dist := to.length()
			if dist < best_d and absf(aim_dir.angle_to(to)) < deg_to_rad(26.0):
				best_d = dist
				best = e
		if best != null:
			aim_dir = aim_dir.slerp((best.position - position).normalized(), 0.7)

# ---- update ----------------------------------------------------------------------------------
func tick(dt: float, can_act: bool) -> void:
	if dead:
		return
	var room: Room = Game.world.current_room()
	iframes = maxf(0.0, iframes - dt)
	grace_t = maxf(0.0, grace_t - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	wall_cd = maxf(0.0, wall_cd - dt)
	launch_t = maxf(0.0, launch_t - dt)
	inverted_t = maxf(0.0, inverted_t - dt)
	slow_t = maxf(0.0, slow_t - dt)
	_update_aim(room)
	var move := _input_move()
	if inverted_t > 0.0:
		move = -move
	# --- dash ---
	if can_act and dash_t <= 0.0 and dash_cd <= 0.0 and (Input.is_action_just_pressed("dash") and not override_active):
		_start_dash(move)
	if dash_t > 0.0:
		dash_t -= dt
		_ghost_t -= dt
		if _ghost_t <= 0.0:
			_ghost_t = 0.025
			ghosts.append({"pos": position, "t": 0.0, "ang": dash_dir.angle()})
		if dash_t <= 0.0:
			_end_dash()
	# --- accel / decel ---
	var speed_cap := MAX_SPEED * (0.62 if weapon.charging else 1.0) * (0.55 if slow_t > 0.0 else 1.0) * (1.12 if Game.has_relic("boots") else 1.0)
	if can_act:
		var target := move * speed_cap
		var rate := ACCEL if move.length() > 0.1 else DECEL
		vel = vel.move_toward(target, rate * dt)
	else:
		vel = vel.move_toward(Vector2.ZERO, DECEL * dt)
	ext *= exp(-dt * (1.4 if launch_t > 0.0 else 5.5))
	if ext.length() < 3.0:
		ext = Vector2.ZERO
	var total := ext + (dash_dir * DASH_SPEED if dash_t > 0.0 else vel)
	_move(total, dt, room)
	# --- weapon ---
	var shoot := ov_shoot if override_active else Input.is_action_pressed("shoot")
	weapon.update(dt, aim_dir, shoot, can_act and dash_t <= 0.0)
	if can_act and Input.is_action_just_pressed("vent") and not override_active:
		weapon.try_vent()
	# --- burning / acid trail ---
	if weapon.heat.burn_t > 0.0:
		burn_acc += dt
		_flame_t -= dt
		if _flame_t <= 0.0:
			_flame_t = 0.05
			Juice.burst(position + Vector2(randf_range(-4, 4), 2), Pal.RED.lerp(Pal.AMBER, randf()), 1, 30.0, Vector2.UP, 0.6, 0.45, 2.0, ParticleField.EMBER)
		if burn_acc >= 2.0:
			burn_acc = 0.0
			take_damage(1, position + Vector2(0, 8), true)
	else:
		burn_acc = 0.0
	if acid_trail_t > 0.0:
		acid_trail_t -= dt
		_acid_t -= dt
		if _acid_t <= 0.0:
			_acid_t = 0.16
			Game.world.spawn_effect("acid", position, {"radius": 11.0, "duration": 4.0, "hostile": true})
	# --- visuals ---
	for g in ghosts:
		g["t"] += dt
	ghosts = ghosts.filter(func(g: Dictionary) -> bool: return g["t"] < 0.22)
	var spd := (vel + ext).length() if dash_t <= 0.0 else DASH_SPEED * 1.1
	var dirv := (dash_dir if dash_t > 0.0 else (vel + ext).normalized())
	rig.update(dt, dirv, spd, 340.0, Juice.pulse_vec(0.0))
	rig.position = position.round() - position
	queue_redraw()

func _start_dash(move: Vector2) -> void:
	dash_dir = move.normalized() if move.length() > 0.2 else aim_dir
	dash_t = DASH_TIME
	dash_cd = DASH_COOLDOWN * (0.75 if Game.has_relic("boots") else 1.0)
	_ghost_t = 0.0
	_was_dashing = true
	rig.dir_angle = dash_dir.angle()
	rig.hold_t = DASH_TIME + 0.1
	Audio.play("dash", 1.0, -4.0)
	Juice.burst(position, Pal.CYAN, 8, 90.0, -dash_dir, 1.2, 0.25, 2.0)
	Juice.zoom_punch(0.15)

func _end_dash() -> void:
	vel = dash_dir * MAX_SPEED * 0.8
	grace_t = 0.07
	# rebound: compress along the dash axis, spring back past 1.0
	rig.hold_t = 0.3
	rig.spring.squash(Vector2(0.62, 1.35))
	rig.spring.punch(Vector2(10.0, -7.0))
	Juice.burst(position, Pal.CYAN, 6, 70.0, -dash_dir, 1.4, 0.25, 2.0)

func _move(total: Vector2, dt: float, room: Room) -> void:
	var res: Dictionary = room.resolve_circle(position + total * dt, radius)
	var n: Vector2 = res["normal"]
	position = res["pos"]
	if n == Vector2.ZERO:
		return
	var into := -(total).dot(n)
	if res["bumper"]:
		ext = n * 340.0
		vel = Vector2.ZERO
		rig.punch_dir(-n, 0.5)
		Audio.play("bounce", 0.7)
		Juice.burst(position, Pal.AMBER, 8, 110.0, n, 1.4, 0.3, 2.0)
		Juice.shake(n, 1.2)
		return
	if launch_t > 0.0 and ext.length() > 90.0 and launch_rest > 0.0:
		ext = ext.bounce(n) * launch_rest
		if launch_hurts and into > 220.0 and wall_cd <= 0.0:
			wall_cd = 0.5
			take_damage(1, position - n * 10.0)
			Juice.hit_stop(3)
	elif ext.dot(n) < 0.0:
		ext -= n * ext.dot(n)
	if vel.dot(n) < 0.0:
		vel -= n * vel.dot(n)
	if into > 120.0:
		rig.punch_dir(-n, clampf(into / 500.0, 0.1, 0.6))     # bounce-back on landing/collision
		Audio.play("bounce", 0.9, -8.0)
		Juice.burst(position - n * 5.0, Pal.STEEL, 4, 60.0, n, 1.5, 0.25, 2.0)

# ---- drawing ---------------------------------------------------------------------------------
func _poly(r: float, n: int, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2.from_angle(rot + TAU * float(i) / float(n)) * r)
	return pts

func _draw() -> void:
	# shadow
	draw_colored_polygon(_poly_ellipse(Vector2(0, 7), 7.0, 2.6), Color(0, 0, 0, 0.4))
	# dash ghosts (world-aligned stretch trail)
	for g in ghosts:
		var a: float = 1.0 - g["t"] / 0.22
		var gp: Vector2 = g["pos"] - position
		draw_set_transform(gp, g["ang"], Vector2(1.3, 0.72))
		draw_colored_polygon(_poly(7.0, 8, PI / 8.0), Color(Pal.CYAN.r, Pal.CYAN.g, Pal.CYAN.b, a * 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if dead:
		return
	# misfire pre-warning: you see it before the shot
	var mid: StringName = weapon.instab.next_misfire
	if mid != &"":
		var info: Dictionary = ModuleDB.MISFIRES[mid]
		var col: Color = info["color"]
		var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.03)
		var tp := Vector2(0, -17)
		col.a = blink
		draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -6), tp + Vector2(6, 5), tp + Vector2(-6, 5)]), Color(0.05, 0.02, 0.08, 0.9))
		draw_polyline(PackedVector2Array([tp + Vector2(0, -6), tp + Vector2(6, 5), tp + Vector2(-6, 5), tp + Vector2(0, -6)]), col, 1.0)
		draw_string(Fonts.main(), tp + Vector2(-16, 26), info["symbol"], HORIZONTAL_ALIGNMENT_CENTER, 32, 16, col)

func _poly_ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _draw_art(c: Node2D) -> void:
	var hr := weapon.heat.ratio()
	var hc := Pal.heat_color(hr)
	var blink := iframes > 0.0 and int(Time.get_ticks_msec() / 60) % 2 == 0
	var body := Color("2b3446") if not blink else Pal.WHITE
	var rim := Pal.CYAN.darkened(0.15) if not blink else Pal.WHITE
	var trig := weapon.loadout.trigger_module
	var ang := aim_dir.angle()
	# gun first (under body)
	var gy := weapon.gun_spring.value.y
	var gl := 9.0 * weapon.gun_spring.value.x
	c.draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	c.draw_rect(Rect2(3, -2.0 * gy, gl, 4.0 * gy), rim)
	c.draw_rect(Rect2(3, -1.0 * gy, gl, 2.0 * gy), Pal.RUST)
	c.draw_rect(Rect2(3 + gl - 2.0, -2.5 * gy, 3, 5.0 * gy), trig.color if not blink else Pal.WHITE)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# body: octagon hover-rig with rust plates
	c.draw_colored_polygon(_poly(7.5, 8, PI / 8.0), body)
	c.draw_polyline(_close(_poly(7.5, 8, PI / 8.0)), rim, 1.0)
	c.draw_colored_polygon(_poly(5.0, 8, PI / 8.0), Pal.RUST if not blink else Pal.WHITE)
	# visor towards aim direction
	var vp := aim_dir * 3.6
	c.draw_rect(Rect2((vp - Vector2(2.0, 1.5)).floor(), Vector2(4, 3)), Pal.CYAN if not blink else Pal.WHITE)
	# heat core
	c.draw_circle(Vector2.ZERO, 2.0, hc if not blink else Pal.WHITE)
	# charge ring at the muzzle
	if weapon.charging:
		var mp := aim_dir * 14.0
		c.draw_arc(mp, 3.0 + weapon.charge * 6.0, 0.0, TAU * weapon.charge, 16, trig.color, 2.0)
		c.draw_circle(mp, 1.0 + weapon.charge * 3.0, Color.WHITE)

func _close(pts: PackedVector2Array) -> PackedVector2Array:
	var o := pts.duplicate()
	o.append(pts[0])
	return o

func _draw_glow(c: Node2D) -> void:
	var hr := weapon.heat.ratio()
	var hc := Pal.heat_color(hr)
	Juice.glow(c, Vector2.ZERO, 16.0 + hr * 22.0, Color(hc.r, hc.g, hc.b, 0.25 + hr * 0.35))
	if weapon.charging:
		Juice.glow(c, aim_dir * 14.0, 6.0 + weapon.charge * 22.0, Color(1, 1, 1, 0.4 + weapon.charge * 0.4))
