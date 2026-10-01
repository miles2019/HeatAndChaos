class_name TurretEnemy
extends EnemyBase
## Spit Turret - stationary bullet-hell source. Barrel glows (telegraph), then bursts; every 3rd volley is a ring.

var state := "idle"
var st := 0.0
var cd := 1.0
var volley := 0
var shots_left := 0
var shot_t := 0.0
var aim := 0.0

func _init() -> void:
	hp = 34.0
	radius = 8.0
	speed = 0.0

func _setup() -> void:
	kind_id = "turret"
	display_name = "Spit Turret"
	color = Color("ff5a4a")
	scrap_value = 3
	contact_on = true

func _ai(dt: float, pl) -> void:
	vel = Vector2.ZERO
	var to: Vector2 = pl.position - position
	match state:
		"idle":
			aim = lerp_angle(aim, to.angle(), clampf(dt * 3.0, 0.0, 1.0))
			cd -= dt
			if cd <= 0.0:
				state = "telegraph"
				st = 0.75
		"telegraph":
			st -= dt
			telegraph = 1.0 - st / 0.75
			rig.boost = telegraph * 0.2
			aim = lerp_angle(aim, to.angle(), clampf(dt * 2.0, 0.0, 1.0)) if st > 0.25 else aim
			if st <= 0.0:
				state = "fire"
				rig.boost = 0.0
				telegraph = 0.0
				volley += 1
				shots_left = 8 if volley % 3 == 0 else 3
				shot_t = 0.0
				rig.spring.squash(Vector2(0.7, 1.25))
		"fire":
			shot_t -= dt
			if shot_t <= 0.0 and shots_left > 0:
				var ring := volley % 3 == 0
				shot_t = 0.0 if ring else 0.14
				shots_left -= 1
				if ring:
					var a := TAU * float(shots_left) / 8.0 + aim
					_shoot(Vector2.from_angle(a), 90.0)
				else:
					_shoot(Vector2.from_angle(aim), 150.0)
				Audio.play("shot", 0.7, -12.0)
				rig.spring.punch(Vector2(-1.2, 0.8))
			if shots_left <= 0:
				state = "idle"
				cd = randf_range(1.4, 2.2)

func _shoot(dir: Vector2, spd: float) -> void:
	var p: Projectile = Game.world.acquire_projectile()
	if p == null:
		return
	p.setup({"dir": dir, "speed": spd, "damage": 1.0, "lifetime": 4.0, "size": 3.0, "pierce": 0, "knockback": 0.0, "color": color}, position + dir * 10.0, 1)

func _on_stunned() -> void:
	state = "idle"
	cd = 1.0
	rig.boost = 0.0

func _draw_world(canvas: Node2D) -> void:
	if state == "telegraph":
		canvas.draw_line(Vector2.from_angle(aim) * 10.0, Vector2.from_angle(aim) * 120.0, Color(1, 0.3, 0.2, 0.2 + 0.5 * telegraph), 1.0)

func _draw_art(canvas: Node2D) -> void:
	var body := _poly(8.0, 6, 0.5)
	canvas.draw_colored_polygon(body, c(Pal.STEEL_DARK))
	canvas.draw_polyline(_closed(body), c(Pal.STEEL), 1.0)
	canvas.draw_circle(Vector2.ZERO, 4.0, c(Pal.RUST))
	canvas.draw_set_transform(Vector2.ZERO, aim, Vector2.ONE)
	canvas.draw_rect(Rect2(2, -2, 10, 4), c(Pal.STEEL))
	canvas.draw_rect(Rect2(10, -2.5, 3, 5), c(color.lerp(Color.WHITE, telegraph)))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_glow(canvas: Node2D) -> void:
	Juice.glow(canvas, Vector2.from_angle(aim) * 12.0, 8.0 + 8.0 * telegraph, Color(1.0, 0.3, 0.2, 0.2 + 0.5 * telegraph))
