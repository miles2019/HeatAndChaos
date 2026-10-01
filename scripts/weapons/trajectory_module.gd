class_name TrajectoryModule
extends WeaponModule

@export var bounces := 0
@export var bounce_speed_gain := 1.0
@export var homing := 0.0
@export var drops_without_target := false
@export var sine_amp := 0.0
@export var sine_freq := 0.0
@export var through_cover := false
@export var orbital := false
@export var life_mult := 1.0
@export var curl := 0.0
@export var split_at := 0.0
@export var split_n := 0
@export var hold_after := 0.0
@export var hold_time := 0.0
@export var hold_boost := 1.0
@export var reverse_at := 0.0

func _init() -> void:
	slot = &"trajectory"

func modify_projectile(p) -> void:
	p.bounces_left += bounces
	p.bounce_gain = bounce_speed_gain
	p.homing = maxf(p.homing, homing)
	p.drops = drops_without_target
	p.sine_amp = sine_amp
	p.sine_freq = sine_freq
	p.through_cover = through_cover
	p.life *= life_mult
	p.max_life = p.life
	p.curl = curl
	p.split_at = split_at
	p.split_n = split_n
	p.hold_after = hold_after
	p.hold_time = hold_time
	p.hold_boost = hold_boost
	p.reverse_at = reverse_at
	if drops_without_target:
		p.speed *= 0.75
		p.vel = p.vel.normalized() * p.speed
	if orbital:
		if p.big:
			p.orbit_state = 1          # beam: leaves the muzzle, then spirals around the player
			p.orbit_after = 0.28
			p.orbit_time = 3.4
			p.life = 6.0
			p.max_life = 6.0
			p.pierce = 999
		else:
			p.return_on_miss = true    # misses become orbiting shields
