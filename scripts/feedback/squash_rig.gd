class_name SquashRig
extends Node2D
## Directional squash & stretch. Rig rotates+scales along the movement axis, art counter-rotates,
## so the visual result is a pure stretch along `dir_angle` while the art itself stays upright.

var spring := SquashSpring.new()
var art := ArtNode.new()
var glow := ArtNode.new()
var dir_angle := 0.0
var stretch := 0.0
var pulse := Vector2.ONE
var hold_t := 0.0
var boost := 0.0                 # extra stretch (>0) / squat (<0), used by attack telegraphs

func _init() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	add_child(art)
	add_child(glow)

func punch_dir(dir: Vector2, amount: float) -> void:
	dir_angle = dir.angle()
	hold_t = 0.3
	spring.squash(Vector2(1.0 - amount * 0.45, 1.0 + amount * 0.35))
	spring.punch(Vector2(amount * 7.0, -amount * 5.0))

func update(dt: float, move_dir: Vector2, move_speed: float, max_speed: float, pulse_vec: Vector2) -> void:
	hold_t = maxf(0.0, hold_t - dt)
	if hold_t <= 0.0 and move_speed > 12.0:
		dir_angle = lerp_angle(dir_angle, move_dir.angle(), clampf(dt * 18.0, 0.0, 1.0))
	var target := clampf(move_speed / maxf(max_speed, 1.0), 0.0, 1.0) * 0.3
	stretch = lerpf(stretch, target, 1.0 - exp(-dt * 14.0))
	spring.update(dt)
	rotation = dir_angle
	scale = Vector2(1.0 + stretch + boost, 1.0 - stretch - boost) * spring.value
	art.rotation = -dir_angle
	glow.rotation = -dir_angle
	art.scale = pulse_vec
	glow.scale = pulse_vec
	art.queue_redraw()
	glow.queue_redraw()
