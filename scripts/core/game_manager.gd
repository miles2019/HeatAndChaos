extends Node
## Global event bus + run state. Systems talk through these signals instead of knowing each other.

signal weapon_fired(ctx)
signal heat_changed(heat)
signal misfire_triggered(id, info)
signal misfire_warning(id)
signal enemy_died(enemy)
signal room_cleared(room)
signal player_hp_changed(hp, max_hp)
signal loadout_changed()
signal vent_used(heat)
signal overheated()
signal boss_hp_changed(ratio, boss_name)
signal toast(text, color)
signal run_ended(summary)

const CHARACTERS := {
	"runner": {"name": "Core Runner", "desc": "Improviser. No special rules, no weaknesses.", "hp": 8, "heat_gain": 1.0, "hot_dmg": 1.0, "cost": 0},
	"pyro": {"name": "Pyromaniac", "desc": "Builds heat 25% slower - but deals +60% damage above 90% heat. 3 hearts.", "hp": 6, "heat_gain": 0.75, "hot_dmg": 1.6, "cost": 2},
}

var world = null                 # RunController while a run is active
var test_mode := false
var character := "runner"
var hp := 8
var max_hp := 8
var loadout: WeaponLoadout
var inventory := {"trigger": [], "trajectory": [], "catalyst": []}
var room_index := 0
var cleared_rooms: Array = []
var stats := {}
var last_summary := {}
var pending_setup := {}          # chosen on the run-setup screen
var resume_requested := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func char_data() -> Dictionary:
	return CHARACTERS[character]

func reset_stats() -> void:
	stats = {"kills": 0, "rooms": 0, "max_heat": 0.0, "max_instability": 0.0, "bosses": [], "new_synergies": [],
		"scrap": 0, "misfires": 0, "time": 0.0}

# ---- run lifecycle -----------------------------------------------------------------------------
func new_run(setup: Dictionary) -> void:
	character = setup.get("char", "runner")
	max_hp = CHARACTERS[character]["hp"]
	hp = max_hp
	room_index = 0
	cleared_rooms = []
	inventory = {"trigger": [], "trajectory": [], "catalyst": []}
	for id in ModuleDB.BASE_IDS:
		_own(StringName(id))
	var trig: String = setup.get("trigger", "pulse_spitter")
	_own(StringName(trig))
	if setup.has("extra"):
		_own(StringName(setup["extra"]))
	var ids := [trig, "straight_rail", "plain_slug"]
	if setup.has("extra"):
		var ex: WeaponModule = ModuleDB.get_module(StringName(setup["extra"]))
		if ex.slot == &"trajectory":
			ids[1] = String(ex.id)
		elif ex.slot == &"catalyst":
			ids[2] = String(ex.id)
	loadout = ModuleDB.make_loadout(ids)
	reset_stats()
	resume_requested = false
	Save.data["run"] = {}

func own(id: StringName) -> bool:
	return _own(id)

func _own(id: StringName) -> bool:
	var m: WeaponModule = ModuleDB.get_module(id)
	if m == null:
		return false
	var arr: Array = inventory[String(m.slot)]
	if arr.has(String(id)):
		return false
	arr.append(String(id))
	Save.discover("modules", String(id))
	return true

func owns(id: StringName) -> bool:
	var m: WeaponModule = ModuleDB.get_module(id)
	return m != null and inventory[String(m.slot)].has(String(id))

func equip(ids: Array) -> void:
	loadout = ModuleDB.make_loadout(ids)
	loadout_changed.emit()

func checkpoint() -> void:
	Save.data["run"] = {
		"char": character, "hp": hp, "room": room_index, "cleared": cleared_rooms.duplicate(),
		"loadout": loadout.ids().map(func(x: Variant) -> String: return String(x)),
		"inventory": inventory.duplicate(true), "stats": stats.duplicate(true),
	}
	Save.save_game()

func restore_run() -> bool:
	var r: Dictionary = Save.data["run"]
	if r.is_empty():
		return false
	character = r["char"]
	max_hp = CHARACTERS[character]["hp"]
	hp = int(r["hp"])
	room_index = int(r["room"])
	cleared_rooms = r["cleared"]
	inventory = r["inventory"]
	stats = r["stats"]
	loadout = ModuleDB.make_loadout(r["loadout"])
	resume_requested = true
	return true

func end_run(victory: bool) -> void:
	var gain: int = stats["scrap"] + stats["rooms"] * 6 + (40 if victory else 0)
	var cores := 3 if victory else 0
	if victory:
		stats["bosses"].append("VULCAN-IX")
		Save.discover("bosses", "vulcan")
	Save.data["scrap"] += gain
	Save.data["cores"] += cores
	var st: Dictionary = Save.data["stats"]
	st["runs"] += 1
	st["wins"] += 1 if victory else 0
	st["bosses"] += 1 if victory else 0
	st["best_heat"] = maxf(st["best_heat"], stats["max_heat"])
	st["best_instability"] = maxf(st["best_instability"], stats["max_instability"])
	Save.data["run"] = {}
	Save.save_game()
	last_summary = {"victory": victory, "scrap": gain, "cores": cores, "stats": stats.duplicate(true), "build": loadout.ids()}
	run_ended.emit(last_summary)

func note_synergy(l: WeaponLoadout) -> void:
	if Save.discover("synergies", l.key()):
		stats["new_synergies"].append(l.key())
		toast.emit("NEW SYNERGY DISCOVERED (Codex)", Pal.VIOLET)
