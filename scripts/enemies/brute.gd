class_name BruteEnemy
extends EnemyBase
## Elite brute: slow, armoured, telegraphs a charge and ends it with a ground-slam ring.

var state := "approach"
var st := 0.0
var cd := 1.5
var lock := Vector2.RIGHT

func _init() -> void:
	hp = 120.0
	radius = 11.0
	speed = 54.0

func _setup() -> void:
	kind_id = "brute"
	display_name = "Furnace Brute"
	color = Color("e0301c")
	scrap_value = 8

func _ai(dt: float, pl) -> void:
	var to: Vector2 = pl.position - position
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	match state:
		"approach":
			face = lerp_angle(face, dir.angle(), clampf(dt * 6.0, 0.0, 1.0))
			vel = vel.lerp(dir * speed * speed_mult(), 1.0 - exp(-dt * 4.0))
			cd -= dt
			if cd <= 0.0 and dist < 230.0:
				state = "telegraph"
				st = 0.9
				lock = dir
		"telegraph":
			st -= dt
			telegraph = 1.0 - st / 0.9
			vel = vel.move_toward(Vector2.ZERO, 500.0 * dt)
			if st > 0.35:
				lock = dir
			face = lock.angle()
			rig.dir_angle = -PI * 0.5
			rig.hold_t = 0.2
			rig.boost = telegraph * 0.22
			if st <= 0.0:
				state = "charge"
				st = 0.55
				rig.boost = 0.0
				rig.dir_angle = lock.angle()
				rig.spring.squash(Vector2(1.5, 0.65))
				Audio.play("dash", 0.5, -2.0)
		"charge":
			st -= dt
			telegraph = 0.0
			vel = lock * 290.0
			rig.dir_angle = lock.angle()
			rig.hold_t = 0.1
			if st <= 0.0:
				state = "recover"
				st = 0.9
				Game.world.spawn_effect("shock", position, {"radius": 74.0, "dur": 0.35, "hostile": true, "color": Pal.RED})
				Juice.shake(Vector2.ZERO, 2.0, 0.4)
				rig.spring.squash(Vector2(0.7, 1.3))
		"recover":
			st -= dt
			vel = vel.move_toward(Vector2.ZERO, 900.0 * dt)
			if st <= 0.0:
				state = "approach"
				cd = randf_range(1.5, 2.5)

func _on_stunned() -> void:
	state = "recover"
	st = 0.5
	rig.boost = 0.0

func _draw_world(canvas: Node2D) -> void:
	if state == "telegraph":
		var a := 0.2 + 0.6 * telegraph
		for i in 12:
			if i % 2 == 0:
				canvas.draw_line(lock * (14.0 + i * 12.0), lock * (14.0 + i * 12.0 + 7.0), Color(1, 0.2, 0.1, a), 2.0)

func _draw_art(canvas: Node2D) -> void:
	var oct := _poly(11.0, 8, PI / 8.0)
	canvas.draw_colored_polygon(oct, c(Color("3b1a16")))
	canvas.draw_polyline(_closed(oct), c(color), 2.0)
	canvas.draw_colored_polygon(_poly(7.0, 8, PI / 8.0), c(Pal.RUST))
	canvas.draw_set_transform(Vector2.ZERO, face, Vector2.ONE)
	canvas.draw_rect(Rect2(4, -5, 8, 3), c(Pal.STEEL))
	canvas.draw_rect(Rect2(4, 2, 8, 3), c(Pal.STEEL))
	canvas.draw_rect(Rect2(3, -1, 3, 2), c(Pal.WHITE if telegraph > 0.5 else Pal.RED))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_glow(canvas: Node2D) -> void:
	Juice.glow(canvas, Vector2.ZERO, 20.0, Color(1.0, 0.25, 0.1, 0.25 + 0.4 * telegraph))
