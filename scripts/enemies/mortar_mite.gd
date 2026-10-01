class_name MortarMite
extends EnemyBase
## Acidic Mortar-Mite - zone denier. Anchors, telegraphs by rising + pulsing with a ground marker,
## lobs an arcing poison shell that leaves a hazard pool.

var state := "reposition"
var st := 0.0
var cd := 1.6
var target := Vector2.ZERO

func _setup() -> void:
	kind_id = "mortar"
	display_name = "Acidic Mortar-Mite"
	color = Pal.LIME
	scrap_value = 3

func _init() -> void:
	hp = 28.0
	radius = 7.0
	speed = 48.0

func _ai(dt: float, pl) -> void:
	var to: Vector2 = pl.position - position
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	face = lerp_angle(face, dir.angle(), clampf(dt * 6.0, 0.0, 1.0))
	match state:
		"reposition":
			var want := Vector2.ZERO
			if dist < 120.0:
				want = -dir * speed * 1.4
			elif dist > 230.0:
				want = dir * speed
			vel = vel.lerp(want * speed_mult(), 1.0 - exp(-dt * 6.0))
			cd -= dt
			if cd <= 0.0 and dist > 90.0:
				state = "telegraph"
				st = 0.9
				target = pl.position + pl.vel * 0.55
				var box := room.inner.grow(-10.0)
				target = Vector2(clampf(target.x, box.position.x, box.end.x), clampf(target.y, box.position.y, box.end.y))
		"telegraph":
			st -= dt
			telegraph = 1.0 - st / 0.9
			vel = vel.move_toward(Vector2.ZERO, 600.0 * dt)
			rig.dir_angle = -PI * 0.5
			rig.hold_t = 0.2
			rig.boost = telegraph * 0.35           # rises tall and narrow
			if st > 0.35:
				target = target.lerp(pl.position + pl.vel * 0.5, 0.04)
			if st <= 0.0:
				_fire()
		"recover":
			st -= dt
			vel = vel.move_toward(Vector2.ZERO, 600.0 * dt)
			if st <= 0.0:
				state = "reposition"
				cd = randf_range(2.0, 3.0)

func _fire() -> void:
	rig.boost = 0.0
	telegraph = 0.0
	rig.spring.squash(Vector2(0.6, 1.5))
	rig.spring.punch(Vector2(6.0, -9.0))
	Audio.play("shot_heavy", 0.6, -4.0)
	Juice.burst(position + Vector2(0, -8), Pal.LIME, 8, 90.0, Vector2.UP, 1.0, 0.4, 2.0)
	Game.world.spawn_effect("mortar", target, {"from": position + Vector2(0, -8), "flight": 0.9})
	state = "recover"
	st = 0.7

func _on_stunned() -> void:
	state = "recover"
	st = 0.5
	rig.boost = 0.0

func _draw_world(canvas: Node2D) -> void:
	if state == "telegraph":
		# dotted line towards the marker so the shot is readable
		var to := target - position
		var n := int(to.length() / 10.0)
		for i in n:
			if i % 2 == 0:
				var a := to * (float(i) / n)
				var b := to * (float(i) + 0.5) / n
				canvas.draw_line(a, b, Color(Pal.LIME.r, Pal.LIME.g, Pal.LIME.b, 0.25 + 0.3 * telegraph), 1.0)

func _draw_art(canvas: Node2D) -> void:
	var pulse := 0.5 + 0.5 * sin(Juice.phase * 2.0 + _pulse_off)
	var body := _poly(7.0, 6, 0.0)
	canvas.draw_colored_polygon(body, c(Pal.RUST))
	canvas.draw_polyline(_closed(body), c(Pal.LIME), 1.0)
	# legs
	for i in 3:
		var a := PI * (0.25 + 0.25 * i)
		canvas.draw_line(Vector2(cos(a), sin(a)) * 6.0, Vector2(cos(a), sin(a)) * 10.0, c(Pal.STEEL), 1.0)
		canvas.draw_line(Vector2(-cos(a), sin(a)) * 6.0, Vector2(-cos(a), sin(a)) * 10.0, c(Pal.STEEL), 1.0)
	# mortar tube rises while telegraphing
	var tl := 4.0 + telegraph * 6.0
	canvas.draw_rect(Rect2(-2, -tl - 2.0, 4, tl), c(Pal.STEEL_DARK))
	canvas.draw_rect(Rect2(-2, -tl - 2.0, 4, 2), c(Pal.LIME))
	canvas.draw_circle(Vector2(0, 1), 2.0 + pulse, c(Pal.LIME))

func _draw_glow(canvas: Node2D) -> void:
	Juice.glow(canvas, Vector2.ZERO, 14.0, Color(0.5, 1.0, 0.2, 0.2 + 0.4 * telegraph))
