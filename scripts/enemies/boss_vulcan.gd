class_name VulcanBoss
extends BossBase
## Act 1 - VULCAN-IX, the overcharged forge core. Heartbeat drives everything.
## P1: Piston Slam, Heat Ray. P2 (<50%): Core Venting (steam + bouncing magma) and Magnetic Pull.

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

func _init() -> void:
	super()
	hp = 650.0
	radius = 26.0
	thresholds = [0.5]
	act_no = 1

func _boss_setup() -> void:
	kind_id = "vulcan"
	display_name = "VULCAN-IX"
	subtitle = "The Overcharged Forge Core"
	color = Pal.RED
	scrap_value = 0

func beat_period() -> float:
	return 1.0 if phase == 1 else 0.72

func _pool() -> Array:
	return ["slam", "ray"] if phase == 1 else ["slam", "vent", "ray", "pull"]

func _on_attack_start(pl) -> void:
	slam2_done = false
	ray_on = false
	ray_warn = 0.0
	ray_tick = 0.0
	vent_tick = 0.0
	pull_tick = 0.0
	if atk == "ray":
		ray_angle = (pl.position - position).angle()

func _enter_phase(_n: int) -> void:
	ray_on = false
	ray_warn = 0.0
	arms = 0.0
	Game.toast.emit("VULCAN-IX: ENRAGED & OVERHEATED", Pal.AMBER)
	Juice.debris(position, Pal.RUST, 20, 220.0)

func _ai(dt: float, pl) -> void:
	cannon_ang = lerp_angle(cannon_ang, (pl.position - position).angle(), clampf(dt * 3.0, 0.0, 1.0))
	super._ai(dt, pl)

# --- Piston Slam: anticipation -> impact (ring + ground slam on you) -> rebound
func _upd_slam(dt: float, pl) -> void:
	at += dt
	var wind := 0.8
	if at < wind:
		arms = ease(at / wind, 2.5)
		rig.boost = arms * 0.12
		if at > wind - 0.35:
			slam_target = pl.position
	elif not slam2_done:
		slam2_done = true
		arms = 0.0
		rig.boost = 0.0
		rig.spring.squash(Vector2(1.3, 0.75))
		Audio.play("slam", 0.8)
		Game.world.spawn_effect("shock", position, {"radius": 560.0, "dur": 2.0, "hostile": true, "color": Pal.RED})
		Juice.big_effect(position, Pal.RED, 1.0)
		Juice.debris(position + Vector2.from_angle(randf() * TAU) * 20.0, Pal.RUST, 10, 160.0)
	if at >= wind + 0.45 and at < wind + 0.5 and slam_target != Vector2.ZERO:
		Game.world.spawn_effect("shock", slam_target, {"radius": 70.0, "dur": 0.35, "hostile": true, "color": Pal.AMBER})
		Juice.shake(Vector2.ZERO, 3.0, 0.5)
		Juice.burst(slam_target, Pal.AMBER, 14, 130.0)
		Audio.play("slam", 1.1, -4.0)
		slam_target = Vector2.ZERO
	if at >= wind + 2.2:
		_end_attack()

# --- Heat Ray: tracking telegraph -> thick laser that ignites the floor
func _upd_ray(dt: float, pl) -> void:
	at += dt
	var to: Vector2 = pl.position - position
	if at < 1.1:
		ray_warn = at / 1.1
		ray_angle = lerp_angle(ray_angle, to.angle(), clampf(dt * 6.0, 0.0, 1.0))
		rig.boost = ray_warn * 0.1
	elif at < 3.0:
		if not ray_on:
			ray_on = true
			rig.boost = 0.0
			Audio.play("beam", 0.5)
			Juice.zoom_punch(-0.3)
		ray_angle = lerp_angle(ray_angle, to.angle(), clampf(dt * 0.9, 0.0, 1.0))
		ray_tick -= dt
		var len := ray_len(ray_angle)
		if ray_tick <= 0.0:
			ray_tick = 0.1
			Game.world.spawn_effect("flame", position + Vector2.from_angle(ray_angle) * randf_range(30.0, len), {"radius": 9.0, "duration": 2.2})
		Juice.shake(Vector2.ZERO, 0.25, 0.0, 0.5)
		var d := _dist_seg(pl.position, position, position + Vector2.from_angle(ray_angle) * len)
		if d < 4.0 + pl.radius * 0.5:
			pl.take_damage(1, pl.position + Vector2.from_angle(ray_angle + PI * 0.5) * 5.0)
	else:
		ray_on = false
		ray_warn = 0.0
		_end_attack()

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
		for i in 8:
			var p := pellet(Vector2.from_angle(base + TAU * i / 8.0), 110.0, 4.0, Pal.AMBER, 3)
			if p:
				p.life = 7.0
		Audio.play("shot_heavy", 0.7, -6.0)
		Juice.burst(position, Pal.WHITE, 10, 80.0, Vector2.ZERO, TAU, 1.2, 4.0, ParticleField.SMOKE)
	if Juice.field and randf() < 0.9:
		Juice.field.burst(room.inner.position + Vector2(randf() * room.inner.size.x, randf() * room.inner.size.y), Color(0.55, 0.55, 0.6), 1, 8.0, Vector2.ZERO, TAU, 2.2, 12.0, ParticleField.SMOKE)
	if at >= dur:
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
				pellet(Vector2.from_angle(spiral + PI * k), 95.0, 3.0, Pal.RED)
	if at >= 3.8:
		_end_attack()

# ---- drawing -----------------------------------------------------------------------------------
func _draw_world(canvas: Node2D) -> void:
	if atk == "slam":
		var k := clampf(at / 0.8, 0.0, 1.0)
		var a := 0.15 + 0.4 * k
		canvas.draw_arc(Vector2.ZERO, radius + 4.0 + 5.0 * k, 0.0, TAU, 24, Color(1, 0.5, 0.2, a), 2.0)
		canvas.draw_arc(Vector2.ZERO, 120.0 * (0.2 + 0.8 * k), 0.0, TAU, 40, Color(1, 0.2, 0.1, a * 0.4), 1.0)
		if slam_target != Vector2.ZERO:
			var sp := slam_target - position
			var blink := 0.5 + 0.5 * sin(at * 40.0)
			canvas.draw_arc(sp, 70.0, 0.0, TAU, 32, Color(1, 0.7, 0.2, 0.4 + 0.5 * blink), 1.0)
			canvas.draw_circle(sp, 3.0, Color(1, 0.7, 0.2, 0.8))
	if atk == "ray":
		var len := ray_len(ray_angle)
		var dirv := Vector2.from_angle(ray_angle)
		if not ray_on:
			canvas.draw_line(dirv * radius, dirv * len, Color(1, 0.25, 0.1, 0.25 + 0.6 * ray_warn), 1.0 + ray_warn)
		else:
			var f := 0.7 + 0.3 * sin(at * 60.0)
			canvas.draw_line(dirv * radius, dirv * len, Color(1, 0.15, 0.05, 0.55), 11.0 * f)
			canvas.draw_line(dirv * radius, dirv * len, Color(1, 0.6, 0.2, 0.9), 6.0 * f)
			canvas.draw_line(dirv * radius, dirv * len, Color.WHITE, 2.5)
	if atk == "pull" and at > 0.5 and at < 3.2:
		for i in 3:
			var ph := fposmod(at * 1.4 + i / 3.0, 1.0)
			canvas.draw_arc(Vector2.ZERO, 150.0 * (1.0 - ph), 0.0, TAU, 40, Color(0.64, 0.3, 1.0, ph * 0.6), 1.0)

func _draw_art(canvas: Node2D) -> void:
	var hot := 0.3 + 0.7 * glow_flash
	var core := Pal.RED.lerp(Pal.AMBER, 0.5 if phase == 2 else 0.0).lerp(Color.WHITE, glow_flash * 0.35)
	var shell := _poly(26.0, 10, PI / 10.0)
	canvas.draw_colored_polygon(shell, c(Color("3b2a22")))
	canvas.draw_polyline(_closed(shell), c(Pal.RUST), 2.0)
	canvas.draw_colored_polygon(_poly(19.0, 10, PI / 10.0), c(Color("22171a")))
	for i in 10:
		var a := TAU * i / 10.0 + PI / 10.0
		canvas.draw_rect(Rect2(Vector2.from_angle(a) * 22.0 - Vector2(1, 1), Vector2(2, 2)), c(Pal.STEEL))
	for i in 8:
		var a2 := TAU * i / 8.0 + sin(Juice.phase * 0.2 + i) * 0.1
		var l := 11.0 + 6.0 * sin(Juice.phase + i * 1.7) * hot
		canvas.draw_line(Vector2.from_angle(a2) * 6.0, Vector2.from_angle(a2) * (6.0 + l), c(core), 2.0 if i % 2 == 0 else 1.0)
	canvas.draw_circle(Vector2.ZERO, 9.0, c(Color("14090a")))
	canvas.draw_circle(Vector2.ZERO, 7.0 + 2.0 * glow_flash, c(core))
	canvas.draw_circle(Vector2.ZERO, 3.0, c(Color.WHITE))
	for s in [-1.0, 1.0]:
		var base := Vector2(s * 12.0, -17.0)
		canvas.draw_circle(base, 5.0, c(Pal.STEEL_DARK))
		canvas.draw_line(base, base + Vector2.from_angle(cannon_ang) * 12.0, c(Pal.STEEL), 4.0)
		canvas.draw_line(base + Vector2.from_angle(cannon_ang) * 10.0, base + Vector2.from_angle(cannon_ang) * 13.0, c(core), 4.0)
	for s2 in [-1.0, 1.0]:
		var ay := 6.0 - arms * 22.0
		canvas.draw_rect(Rect2(s2 * 32.0 - 4.0, ay - 12.0, 8, 24), c(Pal.STEEL_DARK))
		canvas.draw_rect(Rect2(s2 * 32.0 - 6.0, ay + 8.0, 12, 8), c(Pal.RUST))
		canvas.draw_line(Vector2(s2 * 22.0, 0), Vector2(s2 * 30.0, ay), c(Pal.STEEL), 2.0)

func _draw_glow(canvas: Node2D) -> void:
	var a := 0.3 + 0.4 * glow_flash + (0.3 if atk == "slam" else 0.0)
	Juice.glow(canvas, Vector2.ZERO, 56.0 + 10.0 * glow_flash, Color(1.0, 0.25 if phase == 1 else 0.45, 0.08, a))
