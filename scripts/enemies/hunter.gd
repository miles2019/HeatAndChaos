class_name HunterEnemy
extends EnemyBase
## Magnet Hunter (Act 3): orbits you at mid range, then emits a magnetic pulse that drags you in
## before firing a fan of shots. Break line of sight or dash out.

var state := "orbit"
var st := 0.0
var cd := 2.0
var side := 1.0

func _init() -> void:
	hp = 40.0
	radius = 7.0
	speed = 70.0

func _setup() -> void:
	kind_id = "hunter"
	display_name = "Magnet Hunter"
	color = Pal.VIOLET
	scrap_value = 4

func _ai(dt: float, pl) -> void:
	var to: Vector2 = pl.position - position
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	face = lerp_angle(face, dir.angle(), clampf(dt * 6.0, 0.0, 1.0))
	match state:
		"orbit":
			var want := dir.orthogonal() * side * speed
			if dist > 190.0:
				want += dir * speed
			elif dist < 120.0:
				want -= dir * speed
			vel = vel.lerp(want * speed_mult(), 1.0 - exp(-dt * 4.0))
			cd -= dt
			if cd <= 0.0:
				state = "pulse"
				st = 1.0
		"pulse":
			st -= dt
			telegraph = 1.0 - st / 1.0
			vel = vel.move_toward(Vector2.ZERO, 500.0 * dt)
			rig.boost = telegraph * 0.2
			rig.dir_angle = -PI * 0.5
			rig.hold_t = 0.2
			if telegraph > 0.35:
				pl.apply_impulse(-dir * 230.0 * dt)             # magnetic drag
			if st <= 0.0:
				rig.boost = 0.0
				for k in 3:
					var d := dir.rotated((k - 1) * 0.28)
					var p: Projectile = Game.world.acquire_projectile()
					if p:
						p.setup({"dir": d, "speed": 170.0, "damage": 1.0, "lifetime": 3.0, "size": 3.0, "pierce": 0, "knockback": 0.0, "color": color}, position + d * 10.0, 1)
				Audio.play("shot", 0.6, -8.0)
				rig.spring.squash(Vector2(0.7, 1.3))
				state = "orbit"
				cd = randf_range(2.4, 3.6)
				side = -side
				telegraph = 0.0

func _on_stunned() -> void:
	state = "orbit"
	cd = 1.5
	rig.boost = 0.0

func _draw_world(canvas: Node2D) -> void:
	if state == "pulse" and telegraph > 0.35:
		for i in 3:
			var ph := fposmod(telegraph * 3.0 + i / 3.0, 1.0)
			canvas.draw_arc(Vector2.ZERO, 70.0 * (1.0 - ph), 0.0, TAU, 28, Color(0.64, 0.3, 1.0, ph * 0.7), 1.0)

func _draw_art(canvas: Node2D) -> void:
	var o := _poly(7.0, 6, 0.0)
	canvas.draw_colored_polygon(o, c(Pal.STEEL_DARK))
	canvas.draw_polyline(_closed(o), c(color), 1.0)
	for k in 2:
		var a := Juice.phase * (1.0 if k == 0 else -1.2) + k * 2.0
		canvas.draw_arc(Vector2.ZERO, 10.0 + k * 3.0, a, a + 1.6, 10, c(color), 1.0)
	canvas.draw_circle(Vector2.ZERO, 2.5, c(Color.WHITE))

func _draw_glow(canvas: Node2D) -> void:
	Juice.glow(canvas, Vector2.ZERO, 16.0, Color(0.6, 0.3, 1.0, 0.25 + 0.4 * telegraph))
