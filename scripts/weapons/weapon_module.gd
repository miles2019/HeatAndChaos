class_name WeaponModule
extends Resource
## Base of every modular weapon part. Modules change behaviour, not just numbers.

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var slot: StringName = &"trigger"
@export var color := Color.WHITE
@export var symbol := "?"                       # colour-blind friendly glyph
@export var heat_per_shot := 0.0
@export var instability_value := 0.0
@export var misfire_id: StringName = &""
@export var unlock_cost := 0                    # meta scrap; 0 = unlocked from start
@export var risk_text := ""

## Trigger modules return shot dictionaries. Others return [].
func fire(_ctx: Dictionary) -> Array:
	return []

## Called for every freshly spawned projectile (trigger -> trajectory -> catalyst order).
func modify_projectile(_p) -> void:
	pass

## ctx: kind ("hit"|"bounce"|"ground"|"expire"), pos, dir, enemy, projectile
func on_impact(_ctx: Dictionary) -> void:
	pass

## ctx: pos, heat (0..1)
func on_vent(_ctx: Dictionary) -> void:
	pass

func get_misfire_description() -> String:
	if misfire_id == &"" or not ModuleDB.MISFIRES.has(misfire_id):
		return "No misfire trait."
	var m: Dictionary = ModuleDB.MISFIRES[misfire_id]
	return "%s: %s" % [m["name"], m["desc"]]
