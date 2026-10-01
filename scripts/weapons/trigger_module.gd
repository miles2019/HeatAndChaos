class_name TriggerModule
extends WeaponModule

@export var pellets := 1
@export var spread_deg := 2.0
@export var shots_per_second := 4.0
@export var proj_speed := 300.0
@export var damage := 5.0
@export var lifetime := 0.9
@export var proj_size := 3.0
@export var pierce := 0
@export var knockback := 40.0
@export var recoil := 20.0
@export var charge_time := 0.0                  # >0 => hold to charge, release to fire
@export var charge_heat_per_sec := 0.0

func _init() -> void:
	slot = &"trigger"

func fire(ctx: Dictionary) -> Array:
	var shots: Array = []
	var dir: Vector2 = ctx["dir"]
	var charge: float = ctx.get("charge", 1.0)
	for i in pellets:
		var ang := 0.0
		if pellets > 1:
			ang = deg_to_rad(lerpf(-spread_deg * 0.5, spread_deg * 0.5, float(i) / float(pellets - 1)) + randf_range(-2.0, 2.0))
		else:
			ang = deg_to_rad(randf_range(-spread_deg * 0.5, spread_deg * 0.5))
		shots.append({
			"dir": dir.rotated(ang),
			"speed": proj_speed * randf_range(0.94, 1.06),
			"damage": damage * lerpf(0.35, 1.0, charge),
			"lifetime": lifetime,
			"size": proj_size * lerpf(0.6, 1.0, charge),
			"pierce": pierce,
			"knockback": knockback,
			"color": color,
		})
	return shots

func modify_projectile(p) -> void:
	if charge_time > 0.0:
		p.big = true
