class_name HeatSystem
extends Node
## Heat 0..100. At 100 the weapon locks for 4s and the player burns. Panic vent dumps heat.

const LOCKOUT := 4.0
const VENT_COOLDOWN := 2.5
const DECAY := 7.0

var heat := 0.0
var lock_t := 0.0
var burn_t := 0.0
var vent_cd := 0.0
var idle_t := 0.0
var gain_mult := 1.0

func ratio() -> float:
	return heat / 100.0

func is_locked() -> bool:
	return lock_t > 0.0

func vent_ready() -> bool:
	return vent_cd <= 0.0 and heat >= 8.0

func add(amount: float, raw: bool = false) -> void:
	if amount > 0.0 and is_locked():
		return
	heat = clampf(heat + amount * (1.0 if raw else gain_mult), 0.0, 100.0)
	idle_t = 0.0
	if heat >= 100.0 and lock_t <= 0.0:
		lock_t = LOCKOUT
		burn_t = LOCKOUT
		Game.overheated.emit()
	Game.heat_changed.emit(heat)

func update(dt: float) -> void:
	vent_cd = maxf(0.0, vent_cd - dt)
	idle_t += dt
	if lock_t > 0.0:
		lock_t -= dt
		burn_t = minf(burn_t, lock_t + 0.0)
		if lock_t <= 0.0:
			heat = 45.0
			burn_t = 0.0
			Game.heat_changed.emit(heat)
		return
	if idle_t > 0.6 and heat > 0.0:
		heat = maxf(0.0, heat - DECAY * dt)
		Game.heat_changed.emit(heat)

## Returns the heat ratio that was dumped.
func vent() -> float:
	var h := ratio()
	heat = 0.0
	vent_cd = VENT_COOLDOWN
	if lock_t > 0.0:
		lock_t = minf(lock_t, 1.2)
		burn_t = 0.0
	idle_t = 0.0
	Game.heat_changed.emit(heat)
	return h
