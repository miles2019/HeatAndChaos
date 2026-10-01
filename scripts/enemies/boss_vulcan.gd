class_name VulcanBoss
extends EnemyBase
## VULCAN-IX, the overcharged forge core. A heartbeat drives everything: attacks start on beats,
## the sprite swells, the lights flicker. Phase 2 (<50% HP) adds core venting and magnetic pull.

var phase := 1
var beat_t := 0.0
var beat_n := 0
var dub_t := -1.0
var intro_t := 2.4
var invuln := 0.0
var atk := "idle"
var at := 0.0
var idle_t := 1.2
var attack_idx := 0
var arms := 0.0
var ray_angle := 0.0
var ray_on := false
var ray_warn := 0.0
var ray_tick := 0.0
var slam_target := Vector2.ZERO
var slam2_done := false
var vent_tick := 0.0
var pull_tick := 0.0
var spiral := 0.0
var cannon_ang := 0.0
var glow_flash := 0.0
var beat_flag := false

func _init() -> void:
	hp = 650.0
	radius = 26.0
	speed = 0.0

func _setup() -> void:
	kind_id = "vulcan"
	display_name = "VULCAN-IX"
	color = Pal.RED
	show_bar = false
	scrap_value = 0
	contact_on = true
	Game.boss_hp_changed.emit(1.0, display_name)
	Game.toast.emit("VULCAN-IX: 'PROTOCOL: PURGE INTRUDER.'", Pal.RED)

func beat_period() -> float:
	return 1.0 if phase == 1 else 0.72

# ---- hits / phases ---------------------------------------------------------------------------
func take_hit(dmg: float, dir: Vector2, _knock: float, crit: bool = false) -> void:
	if dead:
		return
	if invuln > 0.0 or intro_t > 0.0:
		Juice.burst(position + dir * -radius, Pal.WHITE, 3, 80.0, -dir, 1.2, 0.2, 2.0)
		return
	super.take_hit(dmg * 0.9, dir, 0.0, crit)
	Game.boss_hp_changed.emit(maxf(hp, 0.0) / max_hp, display_name)
	if phase == 1 and hp <= max_hp * 0.5 and not dead:
		_enter_phase2()

func apply_knock(_v: Vector2) -> void:
	pass

func apply_pull(_t: Vector2, _s: float, _dt: float) -> void:
	pass

func stun(_t: float) -> void:
	pass

func take_dot(dmg: float, col: Color) -> void:
	if invuln <= 0.0 and intro_t <= 0.0:
		super.take_dot(dmg * 0.6, col)
		Game.boss_hp_changed.emit(maxf(hp, 0.0) / max_hp, display_name)

func _enter_phase2() -> void:
	phase = 2
	invuln = 1.6
	atk = "idle"
	idle_t = 1.6
	ray_on = false
	ray_warn = 0.0
	arms = 0.0
	Juice.big_effect(position, Pal.AMBER, 1.0)
	Game.toast.emit("VULCAN-IX: ENRAGED & OVERHEATED", Pal.AMBER)
	Audio.play("slam", 0.6)
	Juice.debris(position, Pal.RUST, 20, 220.0)

func die(dir: Vector2) -> void:
	if dead:
		return
	dead = true
	atk = "idle"
	Game.stats["kills"] += 1
	Game.boss_hp_changed.emit(0.0, display_name)
	Game.enemy_died.emit(self)
	for i in 4:
		Juice.big_effect(position + Vector2.from_angle(randf() * TAU) * 14.0, Pal.RED if i % 2 == 0 else Pal.AMBER, 1.0, dir)
		Juice.debris(position, Pal.RUST, 22, 240.0)
		Audio.play("boom", 0.6 + i * 0.1)
		if is_inside_tree():
			await get_tree().create_timer(0.35, false, false, true).timeout
	Juice.debris(position, Pal.RED, 40, 300.0)
	visible = false
	Game.world.on_boss_defeated()

# ---- AI ---------------------------------------------------------------------------------------
func _ai(dt: float, pl) -> void:
	invuln = maxf(0.0, invuln - dt)
	glow_flash = maxf(0.0, glow_flash - dt * 2.0)
	var to: Vector2 = pl.position - position
	cannon_ang = lerp_angle(cannon_ang, to.angle(), clampf(dt * 3.0, 0.0, 1.0))
	vel = Vector2.ZERO
	_heartbeat(dt)
	if intro_t > 0.0:
		intro_t -= dt
		return
	match atk:
		"idle":
			idle_t -= dt
			if idle_t <= 0.0 and beat_flag:
				_next_attack(pl)
		"slam":
			_upd_slam(dt, pl)
		"ray":
			_upd_ray(dt, pl)
		"vent":
			_upd_vent(dt, pl)
		"pull":
			_upd_pull(dt, pl)
	beat_flag = false

func _heartbeat(dt: float) -> void:
	beat_t += dt
	if beat_t >= beat_period():
		beat_t = 0.0
		beat_n += 1
		beat_flag = true
		dub_t = 0.0
		rig.spring.punch(Vector2(2.4, 2.4))          # lub
		glow_flash = 1.0
		Audio.play("thump", 0.8 if phase == 1 else 1.0, -2.0, "Feedback")
		Juice.shake(Vector2.ZERO, 0.45)
		Juice.afterglow = Color(1.0, 0.15, 0.05, 0.1)
		Juice.ring(position, Pal.RED, 40.0 + 6.0 * phase, 0.5)
	if dub_t >= 0.0:
		dub_t += dt
		if dub_t >= 0.2:
			dub_t = -1.0
			rig.spring.punch(Vector2(1.4, 1.4))        # dub

func _next_attack(pl) -> void:
	var pool: Array = ["slam", "ray"] if phase == 1 else ["slam", "vent", "ray", "pull"]
	atk = pool[attack_idx % pool.size()]
	attack_idx += 1
	at = 0.0
	slam2_done = false
	ray_on = false
	ray_warn = 0.0
	ray_tick = 0.0
	vent_tick = 0.0
	pull_tick = 0.0
	if atk == "ray":
		ray_angle = (pl.position - position).angle()

# --- Piston Slam: anticipation -> impact (ring + ground slam on you) -> rebound
func _upd_slam(dt: float, pl) -> void:
	at += dt
	var wind := 0.8
	if at < wind:
		arms = ease(at / wind, 2.5)
		rig.boost = arms * 0.12
		if at > wind - 0.35:
			slam_target = pl.position
	elif not slam2_done and at >= wind:
		slam2_done = true
		arms = 0.0
		rig.boost = 0.0
		rig.spring.squash(Vector2(1.3, 0.75))
		Audio.play("slam", 0.8)
		Game.world.spawn_effect("shock", position, {"radius": 250.0, "dur": 1.05, "hostile": true, "color": Pal.RED})
		Juice.big_effect(position, Pal.RED, 1.0)
		Juice.debris(position + Vector2.from_angle(randf() * TAU) * 20.0, Pal.RUST, 10, 160.0)
	if at >= wind + 0.45 and at < wind + 0.5 and slam_target != Vector2.ZERO:
		Game.world.spawn_effect("shock", slam_target, {"radius": 64.0, "dur": 0.35, "hostile": true, "color": Pal.AMBER})
		Juice.shake(Vector2.ZERO, 3.0, 0.5)
		Juice.burst(slam_target, Pal.AMBER, 14, 130.0)
		Audio.play("slam", 1.1, -4.0)
		slam_target = Vector2.ZERO
	if at >= wind + 1.5:
		_end_attack()

# --- Heat Ray: tracking telegraph -> thick laser that ignites the floor
func _upd_ray(dt: float, pl) -> void:
	at += dt
	var to: Vector2 = pl.position - position
	if at < 1.1:
		ray_warn = at / 1.1
		ray_angle = lerp_angle(ray_angle, to.angle(), clampf(dt * 6.0, 0.0, 1.0))
		rig.boost = ray_warn * 0.1
	elif at < 2.7:
		if not ray_on:
			ray_on = true
			rig.boost = 0.0
			Audio.play("beam", 0.5)
			Juice.zoom_punch(-0.3)
			Juice.shake(Vector2.ZERO, 2.0, 0.3, 0.3)
		ray_angle = lerp_angle(ray_angle, to.angle(), clampf(dt * 0.9, 0.0, 1.0))
		ray_tick -= dt
		var len := _ray_len(ray_angle)
		if ray_tick <= 0.0:
			ray_tick = 0.1
			var at_d := randf_range(30.0, len)
			Game.world.spawn_effect("flame", position + Vector2.from_angle(ray_angle) * at_d, {"radius": 9.0, "duration": 2.2})
		Juice.shake(Vector2.ZERO, 0.25, 0.0, 0.5)
		# beam damage
		var a := position
		var b := position + Vector2.from_angle(ray_angle) * len
		var d := _dist_seg(pl.position, a, b)
		if d < 4.0 + pl.radius * 0.5:
			pl.take_damage(1, pl.position + Vector2.from_angle(ray_angle + PI * 0.5) * 5.0)
	else:
		ray_on = false
		ray_warn = 0.0
		_end_attack()

func _ray_len(ang: float) -> float:
	var d := Vector2.from_angle(ang)
	var best := 700.0
	var r := Room.INNER
	if d.x > 0.001:
		best = minf(best, (r.end.x - position.x) / d.x)
	elif d.x < -0.001:
		best = minf(best, (r.position.x - position.x) / d.x)
	if d.y > 0.001:
		best = minf(best, (r.end.y - position.y) / d.y)
	elif d.y < -0.001:
		best = minf(best, (r.position.y - position.y) / d.y)
	return maxf(best, 20.0)

func _dist_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# --- Core Venting (phase 2): steam blinds the arena, bouncing magma pellets
func _upd_vent(dt: float, _pl) -> void:
	at += dt
	var dur := 4.2
	var fog := sin(clampf(at / dur, 0.0, 1.0) * PI)
	Game.world.fog_amount = fog
	rig.boost = 0.08 * fog
	vent_tick -= dt
	if vent_tick <= 0.0:
		vent_tick = 0.34
		var base := randf() * TAU
		for i in 7:
			_spawn_pellet(Vector2.from_angle(base + TAU * i / 7.0), 105.0, true)
		Audio.play("shot_heavy", 0.7, -6.0)
		Juice.burst(position, Pal.WHITE, 10, 80.0, Vector2.ZERO, TAU, 1.2, 4.0, ParticleField.SMOKE)
	if Juice.field and randf() < 0.9:
		Juice.field.burst(Room.INNER.position + Vector2(randf() * Room.INNER.size.x, randf() * Room.INNER.size.y), Color(0.55, 0.55, 0.6), 1, 8.0, Vector2.ZERO, TAU, 2.2, 12.0, ParticleField.SMOKE)
	if at >= dur:
		Game.world.fog_amount = 0.0
		rig.boost = 0.0
		_end_attack()

# --- Magnetic Pull (phase 2): drags you in while spiral bullets fly
func _upd_pull(dt: float, pl) -> void:
	at += dt
	var to: Vector2 = position - pl.position
	if at > 0.5 and at < 3.2:
		pl.apply_impulse(to.normalized() * 210.0 * dt)
		spiral += dt * 3.2
		pull_tick -= dt
		if pull_tick <= 0.0:
			pull_tick = 0.1
			for k in 2:
				_spawn_pellet(Vector2.from_angle(spiral + PI * k), 92.0, false)
		if int(at * 10.0) % 3 == 0:
			Juice.burst(pl.position + to.normalized() * 14.0, Pal.VIOLET, 1, 40.0, to, 0.5, 0.2, 2.0)
	if at >= 3.8:
		_end_attack()

func _spawn_pellet(dir: Vector2, spd: float, bouncy: bool) -> void:
	var p: Projectile = Game.world.acquire_projectile()
	if p == null:
		return
	p.setup({"dir": dir, "speed": spd, "damage": 1.0, "lifetime": 6.0, "size": 4.0 if bouncy else 3.0, "pierce": 0,
		"knockback": 0.0, "color": Pal.AMBER if bouncy else Pal.RED, "bounces": 3 if bouncy else 0}, position + dir * (radius + 4.0), 1)

func _end_attack() -> void:
	atk = "idle"
	idle_t = 1.0 if phase == 1 else 0.55
	rig.boost = 0.0
	arms = 0.0
	Game.world.fog_amount = 0.0

# ---- drawing -----------------------------------------------------------------------------------
func _draw_world(canvas: Node2D) -> void:
	# slam markers
	if atk == "slam":
		var k := clampf(at / 0.8, 0.0, 1.0)
		var a := 0.15 + 0.4 * k
		canvas.draw_arc(Vector2.ZERO, 250.0 * (0.2 + 0.8 * k), 0.0, TAU, 48, Color(1, 0.2, 0.1, a * 0.4), 1.0)
		canvas.draw_arc(Vector2.ZERO, radius + 4.0 + 5.0 * k, 0.0, TAU, 24, Color(1, 0.5, 0.2, a), 2.0)
		if slam_target != Vector2.ZERO:
			var sp := slam_target - position
			var blink := 0.5 + 0.5 * sin(at * 40.0)
			canvas.draw_arc(sp, 64.0, 0.0, TAU, 32, Color(1, 0.7, 0.2, 0.4 + 0.5 * blink), 1.0)
			canvas.draw_circle(sp, 3.0, Color(1, 0.7, 0.2, 0.8))
	# heat ray
	if atk == "ray":
		var len := _ray_len(ray_angle)
		var dirv := Vector2.from_angle(ray_angle)
		if not ray_on:
			var a2 := 0.25 + 0.6 * ray_warn
			canvas.draw_line(dirv * radius, dirv * len, Color(1, 0.25, 0.1, a2), 1.0 + ray_warn)
		else:
			var f := 0.7 + 0.3 * sin(at * 60.0)
			canvas.draw_line(dirv * radius, dirv * len, Color(1, 0.15, 0.05, 0.55), 11.0 * f)
			canvas.draw_line(dirv * radius, dirv * len, Color(1, 0.6, 0.2, 0.9), 6.0 * f)
			canvas.draw_line(dirv * radius, dirv * len, Color.WHITE, 2.5)
			canvas.draw_circle(dirv * len, 6.0 * f, Color(1, 0.6, 0.2, 0.8))
	if atk == "pull" and at > 0.5 and at < 3.2:
		for i in 3:
			var ph := fposmod(at * 1.4 + i / 3.0, 1.0)
			canvas.draw_arc(Vector2.ZERO, 150.0 * (1.0 - ph), 0.0, TAU, 40, Color(0.64, 0.3, 1.0, ph * 0.6), 1.0)

func _draw_art(canvas: Node2D) -> void:
	var hot := 0.3 + 0.7 * glow_flash
	var core := Pal.RED.lerp(Pal.AMBER, 0.5 if phase == 2 else 0.0).lerp(Color.WHITE, glow_flash * 0.35)
	# armoured shell
	var shell := _poly(26.0, 10, PI / 10.0)
	canvas.draw_colored_polygon(shell, c(Color("3b2a22")))
	canvas.draw_polyline(_closed(shell), c(Pal.RUST), 2.0)
	canvas.draw_colored_polygon(_poly(19.0, 10, PI / 10.0), c(Color("22171a")))
	for i in 10:
		var a := TAU * i / 10.0 + PI / 10.0
		canvas.draw_rect(Rect2(Vector2.from_angle(a) * 22.0 - Vector2(1, 1), Vector2(2, 2)), c(Pal.STEEL))
	# magma veins
	for i in 8:
		var a2 := TAU * i / 8.0 + sin(Juice.phase * 0.2 + i) * 0.1
		var l := 11.0 + 6.0 * sin(Juice.phase + i * 1.7) * hot
		canvas.draw_line(Vector2.from_angle(a2) * 6.0, Vector2.from_angle(a2) * (6.0 + l), c(core), 2.0 if i % 2 == 0 else 1.0)
	# core eye
	canvas.draw_circle(Vector2.ZERO, 9.0, c(Color("14090a")))
	canvas.draw_circle(Vector2.ZERO, 7.0 + 2.0 * glow_flash, c(core))
	canvas.draw_circle(Vector2.ZERO, 3.0, c(Color.WHITE))
	# dual volcanic cannons, aimed at you
	for s in [-1.0, 1.0]:
		var base := Vector2(s * 12.0, -17.0)
		canvas.draw_circle(base, 5.0, c(Pal.STEEL_DARK))
		canvas.draw_line(base, base + Vector2.from_angle(cannon_ang) * 12.0, c(Pal.STEEL), 4.0)
		canvas.draw_line(base + Vector2.from_angle(cannon_ang) * 10.0, base + Vector2.from_angle(cannon_ang) * 13.0, c(core), 4.0)
	# piston arms: rise during anticipation, slam down on impact
	for s2 in [-1.0, 1.0]:
		var ay := 6.0 - arms * 22.0
		canvas.draw_rect(Rect2(s2 * 32.0 - 4.0, ay - 12.0, 8, 24), c(Pal.STEEL_DARK))
		canvas.draw_rect(Rect2(s2 * 32.0 - 6.0, ay + 8.0, 12, 8), c(Pal.RUST))
		canvas.draw_line(Vector2(s2 * 22.0, 0), Vector2(s2 * 30.0, ay), c(Pal.STEEL), 2.0)

func _draw_glow(canvas: Node2D) -> void:
	var a := 0.3 + 0.4 * glow_flash + (0.3 if atk == "slam" else 0.0)
	Juice.glow(canvas, Vector2.ZERO, 56.0 + 10.0 * glow_flash, Color(1.0, 0.25 if phase == 1 else 0.45, 0.08, a))
