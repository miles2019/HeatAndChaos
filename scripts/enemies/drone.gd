class_name DroneEnemy
extends EnemyBase
## Maintenance drone. Cheap, fast, arrives in swarms - the bullet-heaven fodder.

var wob := 0.0

func _init() -> void:
	hp = 7.0
	radius = 4.5
	speed = 125.0

func _setup() -> void:
	kind_id = "drone"
	display_name = "Maintenance Drone"
	color = Pal.AMBER
	scrap_value = 1
	wob = randf() * TAU
	show_bar = false

func _ai(dt: float, pl) -> void:
	var to: Vector2 = pl.position - position
	var dir := to / maxf(to.length(), 0.01)
	wob += dt * 6.0
	var want := (dir + dir.orthogonal() * sin(wob) * 0.7).normalized() * speed * speed_mult()
	vel = vel.lerp(want, 1.0 - exp(-dt * 5.0))
	face = vel.angle()

func _draw_art(canvas: Node2D) -> void:
	var spin := Juice.phase * 6.0 + wob
	canvas.draw_set_transform(Vector2.ZERO, face, Vector2.ONE)
	var body := PackedVector2Array([Vector2(5, 0), Vector2(0, -4), Vector2(-5, 0), Vector2(0, 4)])
	canvas.draw_colored_polygon(body, c(Pal.STEEL))
	canvas.draw_polyline(_closed(body), c(color), 1.0)
	canvas.draw_rect(Rect2(1, -1, 2, 2), c(Pal.RED))
	canvas.draw_line(Vector2(-1, -4) + Vector2(cos(spin), 0) * 3.0, Vector2(-1, -4) - Vector2(cos(spin), 0) * 3.0, c(Pal.WHITE), 1.0)
	canvas.draw_line(Vector2(-1, 4) + Vector2(sin(spin), 0) * 3.0, Vector2(-1, 4) - Vector2(sin(spin), 0) * 3.0, c(Pal.WHITE), 1.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_glow(canvas: Node2D) -> void:
	Juice.glow(canvas, Vector2.ZERO, 9.0, Color(1.0, 0.7, 0.2, 0.3))
