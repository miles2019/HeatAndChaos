extends Node
## Versioned JSON save: meta progression, presets, codex and the resumable run checkpoint.

const PATH := "user://save.json"
const VERSION := 1

var data: Dictionary = {}

func _ready() -> void:
	load_game()

func default_data() -> Dictionary:
	return {
		"version": VERSION,
		"scrap": 20, "cores": 0,
		"unlocked": [],
		"chars": ["runner"],
		"presets": [[], [], []],
		"codex": {"enemies": [], "bosses": [], "modules": [], "synergies": [], "logs": ["intro"]},
		"stats": {"runs": 0, "wins": 0, "best_heat": 0.0, "best_instability": 0.0, "bosses": 0},
		"endings": [],
		"run": {},
		"dupes": 0,
	}

func load_game() -> void:
	data = default_data()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_migrate(parsed)
		for k in parsed:
			data[k] = parsed[k]

func _migrate(d: Dictionary) -> void:
	var v: int = int(d.get("version", 0))
	if v < 1:
		d["version"] = 1

func save_game() -> void:
	if Game.test_mode:
		return
	data["version"] = VERSION
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))

func wipe() -> void:
	data = default_data()
	save_game()

func is_unlocked(id: StringName) -> bool:
	var m: WeaponModule = ModuleDB.get_module(id)
	if m == null:
		return false
	return m.unlock_cost == 0 or data["unlocked"].has(String(id))

func unlock(id: StringName) -> bool:
	var m: WeaponModule = ModuleDB.get_module(id)
	if m == null or is_unlocked(id) or data["scrap"] < m.unlock_cost:
		return false
	data["scrap"] -= m.unlock_cost
	data["unlocked"].append(String(id))
	save_game()
	return true

func discover(category: String, id: String) -> bool:
	var arr: Array = data["codex"][category]
	if arr.has(id):
		return false
	arr.append(id)
	return true

func has_run() -> bool:
	return not data["run"].is_empty()
