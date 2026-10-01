class_name InstabilitySystem
extends Node
## Hybrid model: module risks are visible + pre-rolled (you see the warning BEFORE the shot, so you can
## vent/dash/skip it). From 75% instability extra unpredictable glitch misfires join the pool.

const GLITCH_THRESHOLD := 75.0

var loadout: WeaponLoadout
var next_misfire: StringName = &""
var next_is_glitch := false

func set_loadout(l: WeaponLoadout) -> void:
	loadout = l
	loadout.recalculate()
	roll_next()

func value() -> float:
	return loadout.instability if loadout else 0.0

func chance() -> float:
	return pow(value() / 100.0, 2.0) * 0.32 * (0.7 if Game.has_relic("insurance") else 1.0)

func glitch_chance() -> float:
	if value() < GLITCH_THRESHOLD:
		return 0.0
	return 0.05 + (value() - GLITCH_THRESHOLD) / (100.0 - GLITCH_THRESHOLD) * 0.17

func roll_next() -> void:
	next_misfire = &""
	next_is_glitch = false
	if loadout == null:
		return
	var pool := loadout.get_misfire_pool()
	if not pool.is_empty() and randf() < chance():
		next_misfire = pool.pick_random()
	elif randf() < glitch_chance():
		next_misfire = ModuleDB.GLITCH_POOL.pick_random()
		next_is_glitch = true
	Game.misfire_warning.emit(next_misfire)

func consume() -> StringName:
	var m := next_misfire
	roll_next()
	return m
