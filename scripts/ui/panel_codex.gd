class_name CodexPanel
extends PanelContainer
## Story, enemies, bosses, modules and discovered synergies. Entries unlock through play.

signal closed

const ENEMIES := {
	"stalker": ["Steam-Gland Stalker", "Melee flanker. Zig-zags to dodge straight shots, telegraphs by stretching long and narrow, then leaps half the arena. Dash through the leap."],
	"bulwark": ["Phase Bulwark", "Shielding support. A physical shield blocks everything from the front and it speeds up nearby allies. Bounce, curve or helix shots - or flank."],
	"mortar": ["Acidic Mortar-Mite", "Zone denier. Anchors, rises and pulses, then lobs poison mortars that leave hazard pools. Watch the ground marker."],
	"drone": ["Maintenance Drone", "Cheap and fast. Arrives in swarms - the fodder of The Furnace. One hit each, but never alone."],
	"turret": ["Spit Turret", "Stationary. The barrel glows before it fires; every third volley is a full ring. Break the line, then close in."],
	"slime": ["Foundry Slime", "Hops in squash-and-leap cycles and splits into two slimelings on death. Area damage loves it."],
	"brute": ["Furnace Brute", "Elite. Slow, armoured, telegraphs a long charge and ends it with a ground-slam ring. Dash the charge, shoot the recovery."],
	"hunter": ["Magnet Hunter", "Orbits at mid range, drags you in with a magnetic pulse, then fires a fan. Dash out of the pulse."],
}
const BOSSES := {
	"vulcan": ["VULCAN-IX - The Overcharged Forge Core", "A former security core that reads its protection protocols as aggression. Phase 1: Piston Slam rings, Heat Ray. Below 50%: Core Venting (steam + bouncing magma) and Magnetic Pull (spiral bullets). Its heartbeat tells you when it will strike."],
	"slime_engine": ["THE SLIME-FUSED ENGINE", "A failed experiment that insists on producing. Floods the floor with acid strips, lobs mortars and rams. At 50% it undergoes mitosis into two faster halves."],
	"warden": ["MAGNET WARDEN", "A modular guardian that copies YOUR build: its volleys use your trigger pattern and your trajectory module. Its segments are tinted with your module colours."],
	"pulse": ["THE PULSE", "The awakened overheating consciousness. Heartbeat rings, tendrils, assimilated machines - and from phase 2 it can override your weapon with a forced glitch."],
}
const STORY := """[color=#ffb02e][b]CINDERFALL & THE FURNACE[/b][/color]
Beneath the neon city of Cinderfall lies The Furnace, a half-living industrial plant that makes energy, weapons and artificial organisms. Since the reactor core VULCAN-IX was damaged, the plant overheats. Machines mutate, slime grows through the pipes and every misfire changes the rooms.

[color=#19e6ff][b]THE CORE RUNNER[/b][/color]
You: a fast salvage-and-sabotage specialist from the last independent workshop. No chosen one - an improviser who knows how to repair, repurpose and overload at the worst possible moment.

[color=#ffb02e][b]MARA VEX[/b][/color]
Runs the independent cyber-garage. Practical, sarcastic, technically brilliant.

[color=#a24bff][b]THE PULSE[/b][/color]
Something woke up in the reactor: machine logic, bio-slime and stolen human heat. It does not see chaos as a fault, but as evolution - and it wants to connect everything. Including you.

[color=#ff3b1f][b]ACTS[/b][/color]
1. The Steam Vaults - boss VULCAN-IX
2. The Bio-Foundry - boss The Slime-Fused Engine
3. The Magnet Spine - a guardian that copies your build
4. The Coremind - THE PULSE

[color=#8dff2a][b]ENDINGS[/b][/color]
Shutdown / Containment / Fusion / Overload"""

func _ready() -> void:
	theme = UIKit.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2(100, 20)
	size = Vector2(760, 500)
	custom_minimum_size = size
	var root := VBoxContainer.new()
	add_child(root)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size = Vector2(740, 440)
	root.add_child(tabs)
	var cdx: Dictionary = Save.data["codex"]
	tabs.add_child(_rich("Story", STORY))
	tabs.add_child(_rich("Enemies", _entries(ENEMIES, cdx["enemies"])))
	tabs.add_child(_rich("Bosses", _entries(BOSSES, cdx["bosses"])))
	tabs.add_child(_rich("Modules", _modules(cdx["modules"])))
	tabs.add_child(_rich("Synergies", _synergies(cdx["synergies"])))
	tabs.add_child(_rich("Endings", _endings()))
	tabs.get_tab_bar().grab_focus.call_deferred()
	root.add_child(UIKit.button(Settings.t("back"), func() -> void: closed.emit(), 80))

func _rich(title: String, text: String) -> RichTextLabel:
	var r := UIKit.rich(text)
	r.name = title
	return r

func _entries(db: Dictionary, found: Array) -> String:
	var s := ""
	for k in db:
		if found.has(k):
			s += "[color=#ffb02e][b]%s[/b][/color]\n%s\n\n" % [db[k][0], db[k][1]]
		else:
			s += "[color=#555][b]???[/b]\nDefeat it to record an entry.[/color]\n\n"
	return s

func _modules(found: Array) -> String:
	var s := ""
	for id in ModuleDB.order:
		var m: WeaponModule = ModuleDB.get_module(id)
		if found.has(String(id)):
			s += "[color=#%s][b]%s %s[/b][/color]  (%s)\n%s\n[color=#a24bff]%s[/color]\n\n" % [m.color.to_html(false), m.symbol, m.display_name, m.slot, m.description, m.get_misfire_description()]
		else:
			s += "[color=#555][b]??? %s[/b]  - find or unlock it[/color]\n\n" % m.slot
	return s

func _synergies(found: Array) -> String:
	var s := "[color=#8a93a5]Combinations you actually fired are recorded here.[/color]\n\n"
	for k in ModuleDB.BUILDS:
		var key := "|".join(ModuleDB.BUILDS[k]["ids"])
		if found.has(key):
			s += "[color=#ffb02e][b]%s[/b][/color] (design-doc monster build)\n" % ModuleDB.BUILDS[k]["name"]
		else:
			s += "[color=#555][b]??? - a monster build[/b][/color]\n"
	s += "\n[color=#8a93a5]Other discovered combinations:[/color]\n"
	var canon: Array = []
	for k in ModuleDB.BUILDS:
		canon.append("|".join(ModuleDB.BUILDS[k]["ids"]))
	for f in found:
		if not canon.has(f):
			var parts: PackedStringArray = f.split("|")
			var names: Array = []
			for p in parts:
				names.append(ModuleDB.get_module(StringName(p)).display_name)
			s += " - " + " + ".join(names) + "\n"
	return s

func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()

func _endings() -> String:
	var s := ""
	for id in Game.ENDINGS:
		var e: Array = Game.ENDINGS[id]
		if Save.data["endings"].has(id):
			s += "[color=#ffb02e][b]%s[/b][/color]\n%s\n" % [e[0], e[1]]
			if e[3] != "":
				s += "[color=#8dff2a]Unlocked runner: %s[/color]\n" % Game.CHARACTERS[e[3]]["name"]
			s += "\n"
		else:
			s += "[color=#555][b]??? ENDING[/b]\nDefeat THE PULSE and decide its fate.[/color]\n\n"
	return s
