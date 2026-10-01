class_name SlimeEnemy
extends EnemyBase
## Foundry slime. Hops (crouch -> leap -> rest) and splits into two slimelings when killed.

var tiny := false
var state := "rest"
var st := 0.5
var hop_dir := Vector2.RIGHT

func _init() -> void:
	hp = 26.0
	radius = 8.0
	speed = 150.0

func _setup() -> void:
	kind_id = "slime"
	display_name = "Foundry Slime"
	color = Color("5fd62a")
	scrap_value = 2
	if tiny:
		hp = 8.0
		max_hp = 8.0
		radius = 4.5
		scrap_value = 1
		show_bar = false

func _ai(dt: float, pl) -> void:
	var to: Vector2 = pl.position - position
	var dir := to / maxf(to.length(), 0.01)
	st -= dt
	match state:
		"rest":
			vel = vel.move_toward(Vector2.ZERO, 600.0 * dt)
			rig.boost = 0.0
			if st <= 0.0:
				state = "crouch"
				st = 0.35
				hop_dir = dir
		"crouch":
			vel = Vector2.ZERO
			telegraph = 1.0 - st / 0.35
			rig.dir_angle = -PI * 0.5
			rig.hold_t = 0.1
			rig.boost = -telegraph * 0.3                  # squash flat before the jump
			if st <= 0.0:
				state = "hop"
				st = 0.38
				telegraph = 0.0
				rig.boost = 0.0
				rig.spring.squash(Vector2(1.45, 0.65))
				hop_dir = (dir * 2.0 + hop_dir).normalized()
		"hop":
			vel = hop_dir * speed * speed_mult() * (1.0 if not tiny else 1.15)
			if st <= 0.0:
				state = "rest"
				st = randf_range(0.2, 0.5)
				rig.spring.squash(Vector2(0.7, 1.3))
				Juice.burst(position, color, 3, 40.0, Vector2.UP, 2.0, 0.25, 2.0)

func _on_stunned() -> void:
	state = "rest"
	st = 0.5
	rig.boost = 0.0

func die(dir: Vector2) -> void:
	var p := position
	var split := not tiny and not dead
	super.die(dir)
	if split and Game.world:
		for i in 2:
			var e: EnemyBase = Game.world.rooms.create_enemy("slime", p + Vector2.from_angle(randf() * TAU) * 8.0, true)
			if e:
				e.kb = Vector2.from_angle(randf() * TAU) * 200.0

func _draw_art(canvas: Node2D) -> void:
	var r := radius
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		pts.append(Vector2.from_angle(a) * r * (1.0 + 0.1 * sin(a * 3.0 + Juice.phase * 2.0 + _pulse_off)))
	canvas.draw_colored_polygon(pts, c(Color("2f7a18")))
	canvas.draw_polyline(_closed(pts), c(color), 1.0)
	canvas.draw_circle(Vector2(-r * 0.3, -r * 0.2), r * 0.18, c(Pal.WHITE))
	canvas.draw_circle(Vector2(r * 0.3, -r * 0.2), r * 0.18, c(Pal.WHITE))
	canvas.draw_rect(Rect2(-r * 0.3, -r * 0.2, 1, 1), c(Color.BLACK))
	canvas.draw_rect(Rect2(r * 0.3, -r * 0.2, 1, 1), c(Color.BLACK))
	if not tiny:
		canvas.draw_rect(Rect2(-r * 0.5, r * 0.25, r, 2), c(Pal.STEEL_DARK))     # swallowed machine part

func _draw_glow(canvas: Node2D) -> void:
	Juice.glow(canvas, Vector2.ZERO, radius * 2.0, Color(0.4, 1.0, 0.2, 0.2))
