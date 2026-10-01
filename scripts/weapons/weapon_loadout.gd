class_name WeaponLoadout
extends Resource

@export var trigger_module: TriggerModule
@export var trajectory_module: TrajectoryModule
@export var catalyst_module: CatalystModule
@export_range(0.0, 100.0) var instability: float = 0.0

func recalculate() -> void:
	var total := 0.0
	for m in modules():
		total += m.instability_value
	total += Game.curse_inst
	if Game.has_relic("overclock"):
		total += 10.0
	instability = clampf(total, 0.0, 100.0)

func modules() -> Array:
	var out: Array = []
	for m in [trigger_module, trajectory_module, catalyst_module]:
		if m != null:
			out.append(m)
	return out

func heat_per_shot() -> float:
	var h := 0.0
	for m in modules():
		h += m.heat_per_shot
	return h

func get_misfire_pool() -> Array:
	var pool: Array = []
	for m in modules():
		if m.misfire_id != &"" and not pool.has(m.misfire_id):
			pool.append(m.misfire_id)
	return pool

func key() -> String:
	return "%s|%s|%s" % [trigger_module.id, trajectory_module.id, catalyst_module.id]

func ids() -> Array:
	return [trigger_module.id, trajectory_module.id, catalyst_module.id]

func copy_loadout() -> WeaponLoadout:
	var l := WeaponLoadout.new()
	l.trigger_module = trigger_module
	l.trajectory_module = trajectory_module
	l.catalyst_module = catalyst_module
	l.recalculate()
	return l
