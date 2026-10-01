class_name StalkerEnemy
extends EnemyBase
## Steam-Gland Stalker - melee flanker. Zig-zag approach, elastic telegraph (long + narrow), half-arena leap.

var state := "approach"
var st := 0.0
var zig := 1.0
var zig_t := 0.0
var lock_dir := Vector2.RIGHT
var cd := 1.2

func _setup() -> void:
	kind_id = "stalker"
	display_name = "Steam-Gland Stalker"
	color = Color("ff6a2a")
	scrap_value = 2

func _init() -> void:
	hp = 22.0
	radius = 6.0
	speed = 80.0

func _ai(dt: float, pl) -> void:
	var to: Vector2 = pl.position - position
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	match state:
		"approach":
			face = lerp_angle(face, dir.angle(), clampf(dt * 10.0, 0.0, 1.0))
			zig_t -= dt
			if zig_t <= 0.0:
				zig = -zig
				zig_t = randf_range(0.28, 0.5)
			var want := (dir + dir.orthogonal() * zig * 0.95).normalized() * speed * speed_mult()
			vel = vel.lerp(want, 1.0 - exp(-dt * 9.0))
			cd -= dt
			contact_on = true
			if cd <= 0.0 and dist < 170.0 and dist > 40.0:
				state = "telegraph"
				st = 0.6
				lock_dir = dir
		"telegraph":
			st -= dt
			telegraph = 1.0 - st / 0.6
			vel = vel.move_toward(Vector2.ZERO, 500.0 * dt)
			if st > 0.25:
				lock_dir = dir                       # tracks you, then commits
			face = lock_dir.angle()
			rig.dir_angle = face
			rig.hold_t = 0.2
			rig.boost = telegraph * 0.42             # longer + narrower before the snap
			if st <= 0.0:
				state = "leap"
				st = 0.34
				rig.boost = 0.0
				rig.spring.squash(Vector2(1.5, 0.6))
				Audio.play("dash", 0.8, -4.0)
				Juice.burst(position, color, 6, 90.0, -lock_dir, 1.2, 0.25, 2.0)
		"leap":
			st -= dt
			telegraph = 0.0
			vel = lock_dir * 340.0
			rig.dir_angle = lock_dir.angle()
			rig.hold_t = 0.1
			if st <= 0.0:
				state = "recover"
				st = 0.6
				rig.spring.squash(Vector2(0.65, 1.3))
				rig.spring.punch(Vector2(8.0, -6.0))
		"recover":
			st -= dt
			vel = vel.move_toward(Vector2.ZERO, 900.0 * dt)
			if st <= 0.0:
				state = "approach"
				cd = randf_range(1.0, 1.8)

func _on_stunned() -> void:
	state = "recover"
	st = 0.4
	rig.boost = 0.0

func _draw_world(canvas: Node2D) -> void:
	if state == "telegraph":
		var a := 0.25 + 0.6 * telegraph
		var col := Color(1.0, 0.25, 0.1, a)
		var steps := 9
		for i in steps:
			if i % 2 == 0:
				var p0 := lock_dir * (10.0 + i * 8.0)
				var p1 := lock_dir * (10.0 + i * 8.0 + 5.0)
				canvas.draw_line(p0, p1, col, 1.0 + telegraph)

func _draw_art(canvas: Node2D) -> void:
	# crab-like wedge with a steam gland on its back
	canvas.draw_set_transform(Vector2.ZERO, face, Vector2.ONE)
	var body := PackedVector2Array([Vector2(8, 0), Vector2(-2, -6), Vector2(-7, -3), Vector2(-7, 3), Vector2(-2, 6)])
	canvas.draw_colored_polygon(body, c(Pal.RUST))
	canvas.draw_polyline(_closed(body), c(color), 1.0)
	# claws
	canvas.draw_line(Vector2(5, -3), Vector2(10, -6), c(color), 1.0)
	canvas.draw_line(Vector2(5, 3), Vector2(10, 6), c(color), 1.0)
	# gland
	canvas.draw_circle(Vector2(-4, 0), 2.0 + 0.8 * sin(Juice.phase * 2.0 + _pulse_off), c(Pal.CYAN))
	# eyes
	canvas.draw_rect(Rect2(3, -2.5, 2, 1.5), c(Pal.RED))
	canvas.draw_rect(Rect2(3, 1.0, 2, 1.5), c(Pal.RED))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_glow(canvas: Node2D) -> void:
	var a := 0.22 + (0.4 * telegraph if state == "telegraph" else 0.0) + (0.3 if state == "leap" else 0.0)
	Juice.glow(canvas, Vector2.ZERO, 14.0, Color(1.0, 0.35, 0.15, a))
