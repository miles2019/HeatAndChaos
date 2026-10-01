class_name BulwarkEnemy
extends EnemyBase
## Phase Bulwark - shielding support. Physical directional shield facing the player, speed-buffs allies.
## Forces bounce / curve / helix projectiles (or flanking).

var buff_tick := 0.0
var strafe := 1.0
var strafe_t := 0.0

func _setup() -> void:
	kind_id = "bulwark"
	display_name = "Phase Bulwark"
	color = Pal.CYAN
	scrap_value = 3

func _init() -> void:
	hp = 42.0
	radius = 9.0
	speed = 46.0

func shield_blocks(p) -> bool:
	if spawn_t > 0.0 or stun_t > 0.0:
		return false
	var to_p: Vector2 = (p.position - position).normalized()
	return absf(angle_difference(face, to_p.angle())) < deg_to_rad(64.0)

func _ai(dt: float, pl) -> void:
	var to: Vector2 = pl.position - position
	var dist := to.length()
	face = lerp_angle(face, to.angle(), clampf(dt * 5.0, 0.0, 1.0))
	strafe_t -= dt
	if strafe_t <= 0.0:
		strafe_t = randf_range(1.2, 2.4)
		strafe = -strafe
	var dir := to / maxf(dist, 0.01)
	var want := Vector2.ZERO
	if dist > 135.0:
		want = dir * speed
	elif dist < 85.0:
		want = -dir * speed * 0.9
	want += dir.orthogonal() * strafe * speed * 0.5
	vel = vel.lerp(want * speed_mult(), 1.0 - exp(-dt * 4.0))
	buff_tick -= dt
	if buff_tick <= 0.0:
		buff_tick = 0.2
		for o in room.enemies:
			if o != self and is_instance_valid(o) and not o.dead and o.position.distance_to(position) < 90.0:
				o.buff_t = 0.4

func _draw_world(canvas: Node2D) -> void:
	# faint buff aura
	var a := 0.12 + 0.06 * sin(Juice.phase)
	canvas.draw_arc(Vector2.ZERO, 90.0, 0.0, TAU, 40, Color(Pal.CYAN.r, Pal.CYAN.g, Pal.CYAN.b, a), 1.0)

func _draw_art(canvas: Node2D) -> void:
	var oct := _poly(9.0, 8, PI / 8.0)
	canvas.draw_colored_polygon(oct, c(Pal.STEEL_DARK))
	canvas.draw_polyline(_closed(oct), c(Pal.STEEL), 1.0)
	canvas.draw_colored_polygon(_poly(5.0, 8, PI / 8.0), c(Pal.RUST))
	canvas.draw_circle(Vector2.ZERO, 2.0, c(Pal.CYAN))
	# the shield: thick arc + bright core line
	var open := stun_t > 0.0
	var col := c(Pal.CYAN if not open else Pal.STEEL)
	canvas.draw_arc(Vector2.ZERO, 14.0, face - 1.1, face + 1.1, 16, col, 3.0)
	canvas.draw_arc(Vector2.ZERO, 14.0, face - 1.1, face + 1.1, 16, c(Color.WHITE) if not open else col, 1.0)

func _draw_glow(canvas: Node2D) -> void:
	Juice.glow(canvas, Vector2.from_angle(face) * 14.0, 16.0, Color(0.1, 0.9, 1.0, 0.35 if stun_t <= 0.0 else 0.05))
