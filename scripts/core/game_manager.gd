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
signal boss_intro(boss_name, sub)
signal run_ended(summary)

const CHARACTERS := {
	"runner": {"name": "Core Runner", "desc": "Improviser. No special rules, no weaknesses.", "hp": 8, "heat_gain": 1.0, "hot_dmg": 1.0, "cost": 0},
	"pyro": {"name": "Pyromaniac", "desc": "Builds heat 25% slower - but deals +60% damage above 90% heat. 3 hearts.", "hp": 6, "heat_gain": 0.75, "hot_dmg": 1.6, "cost": 2},
	"tinker": {"name": "Tinker (Fusion ending)", "desc": "Starts with one extra random module of every slot. 3 hearts.", "hp": 6, "heat_gain": 1.0, "hot_dmg": 1.0, "cost": -1},
	"warden": {"name": "Warden (Containment ending)", "desc": "+1 heart, -10% damage, starts with Plating relic.", "hp": 10, "heat_gain": 1.0, "hot_dmg": 1.0, "dmg": 0.9, "cost": -1},
}

const RELICS := {
	"cooling_fins": ["Cooling Fins", "Heat decays 70% faster."],
	"overclock": ["Overclock Fuse", "+20% fire rate, +10 instability."],
	"plating": ["Reactive Plating", "+2 max HP (1 heart)."],
	"boots": ["Kinetic Boots", "+12% speed, dash cooldown -25%."],
	"magnet": ["Scrap Magnet", "Pickups fly from twice as far, +1 scrap each."],
	"insurance": ["Misfire Insurance", "Misfire chance -30%."],
	"vent_cap": ["Vent Capacitor", "Vent cooldown halved, +30% vent damage."],
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
var run_seed := 1
var act := 1
var relics: Array = []
var curse_inst := 0.0

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
	run_seed = randi() % 100000 + 1
	act = 1
	relics = []
	curse_inst = 0.0
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
	if character == "tinker":
		for slot in ["trigger", "trajectory", "catalyst"]:
			var opts: Array = ModuleDB.by_slot(StringName(slot)).filter(func(m: WeaponModule) -> bool: return Save.is_unlocked(m.id))
			_own(opts.pick_random().id)
	if character == "warden":
		add_relic("plating")
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
		"seed": run_seed, "act": act, "relics": relics.duplicate(), "curse": curse_inst,
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
	run_seed = int(r.get("seed", 1))
	act = int(r.get("act", 1))
	relics = r.get("relics", [])
	curse_inst = float(r.get("curse", 0.0))
	resume_requested = true
	return true

func end_run(victory: bool) -> void:
	var gain: int = stats["scrap"] + stats["rooms"] * 6 + (40 if victory else 0)
	var cores: int = stats["bosses"].size() + (3 if victory else 0)
	Save.data["scrap"] += gain
	Save.data["cores"] += cores
	var st: Dictionary = Save.data["stats"]
	st["runs"] += 1
	st["wins"] += 1 if victory else 0
	st["bosses"] += stats["bosses"].size()
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

# ---- relics / curses / endings ------------------------------------------------------------------
func has_relic(id: String) -> bool:
	return relics.has(id)

func add_relic(id: String) -> void:
	if relics.has(id):
		return
	relics.append(id)
	if id == "plating":
		max_hp += 2
		hp += 2
		player_hp_changed.emit(hp, max_hp)
	if loadout:
		loadout.recalculate()
		loadout_changed.emit()

func random_relic() -> String:
	var pool: Array = RELICS.keys().filter(func(k: String) -> bool: return not relics.has(k))
	return pool.pick_random() if not pool.is_empty() else ""

func hp_scale() -> float:
	return 1.0 + 0.4 * float(act - 1)

const ENDINGS := {
	"shutdown": ["SHUTDOWN", "You tear THE PULSE out of the core. Cinderfall goes dark, but stays free.", "log_shutdown", ""],
	"containment": ["CONTAINMENT", "You seal THE PULSE and take the controls of The Furnace.", "log_containment", "warden"],
	"fusion": ["FUSION", "You plug into THE PULSE. The next run starts in a living, changed plant.", "log_fusion", "tinker"],
	"overload": ["OVERLOAD", "You let the fever run. The city burns - and something new and chaotic hums to life.", "log_overload", "pyro"],
}

func finish_ending(id: String) -> void:
	var e: Array = ENDINGS[id]
	if not Save.data["endings"].has(id):
		Save.data["endings"].append(id)
	Save.data["codex"]["logs"].append(e[2])
	if e[3] != "" and not Save.data["chars"].has(e[3]):
		Save.data["chars"].append(e[3])
	stats["ending"] = id
	end_run(true)
