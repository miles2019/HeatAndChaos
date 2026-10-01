extends Node
## Module library. Balance lives in the exported Resource values created here.

const MISFIRES := {
	&"recoil_pushback": {"name": "RECOIL PUSHBACK", "desc": "Next shot kicks you backwards hard.", "color": Pal.RED, "symbol": "<<"},
	&"acid_trail": {"name": "ACID TRAIL", "desc": "Acid leaks under your feet for 3s.", "color": Pal.LIME, "symbol": "~~"},
	&"launch_back": {"name": "LAUNCH", "desc": "Blast hurls you backwards - walls hurt.", "color": Pal.CYAN, "symbol": ">>"},
	&"pull_to_shot": {"name": "TETHER PULL", "desc": "You get dragged towards your own shot.", "color": Pal.VIOLET, "symbol": "@>"},
	&"boomerang": {"name": "BOOMERANG", "desc": "Shots turn around and come back for YOU.", "color": Pal.CYAN, "symbol": "()"},
	&"flipper_recoil": {"name": "PINBALL", "desc": "Heat-scaled recoil - you bounce off walls.", "color": Pal.RED, "symbol": "|o"},
	&"phase_flip": {"name": "PHASE FLIP", "desc": "Shot fires backwards.", "color": Pal.VIOLET, "symbol": "<>"},
	&"runaway_cadence": {"name": "RUNAWAY FIRE", "desc": "Six wild shots spray in random directions.", "color": Pal.AMBER, "symbol": "///"},
	&"capacitor_arc": {"name": "ARC DISCHARGE", "desc": "Capacitor zaps you: 1 damage, +15 heat.", "color": Pal.CYAN, "symbol": "Z"},
	&"mag_overpressure": {"name": "OVERPRESSURE", "desc": "Magazine vents: +25 heat instantly.", "color": Pal.RED, "symbol": "!^"},
	&"glitch_heat_spike": {"name": "GLITCH: HEAT SPIKE", "desc": "Reality stutters - +20 heat.", "color": Pal.VIOLET, "symbol": "#^"},
	&"glitch_scatter": {"name": "GLITCH: GHOST VOLLEY", "desc": "Echo shots in random directions.", "color": Pal.VIOLET, "symbol": "#*"},
	&"glitch_input_swap": {"name": "GLITCH: CONTROL SWAP", "desc": "Movement inverted for 1.2s.", "color": Pal.VIOLET, "symbol": "#~"},
}
const GLITCH_POOL := [&"glitch_heat_spike", &"glitch_scatter", &"glitch_input_swap"]

## The four design-doc monster builds (also used by the automated scenarios).
const BUILDS := {
	"tornado": {"name": "Gravity Tornado", "ids": ["beam_capacitor", "orbital_magnet", "implosion_charge"]},
	"minefield": {"name": "Acid Minefield", "ids": ["buckshot_cluster", "ricochet_coil", "toxic_catalyst"]},
	"sniper": {"name": "Ghost Sniper", "ids": ["sniper_mag", "sinus_helix", "shockwave_core"]},
	"carpet": {"name": "Kamikaze Toxin Carpet", "ids": ["giga_pulse", "gravity_curve", "toxic_catalyst"]},
}
const BASE_IDS := ["pulse_spitter", "straight_rail", "plain_slug"]

var modules: Dictionary = {}
var order: Array = []

func _ready() -> void:
	_build()

func get_module(id: StringName) -> WeaponModule:
	return modules.get(id)

func by_slot(slot: StringName) -> Array:
	var out: Array = []
	for id in order:
		if modules[id].slot == slot:
			out.append(modules[id])
	return out

func make_loadout(ids: Array) -> WeaponLoadout:
	var l := WeaponLoadout.new()
	l.trigger_module = get_module(StringName(ids[0])) as TriggerModule
	l.trajectory_module = get_module(StringName(ids[1])) as TrajectoryModule
	l.catalyst_module = get_module(StringName(ids[2])) as CatalystModule
	l.recalculate()
	return l

func _reg(m: WeaponModule) -> void:
	modules[m.id] = m
	order.append(m.id)

func _trigger(id: StringName, nm: String, desc: String, col: Color, sym: String, f: Dictionary) -> void:
	var t := TriggerModule.new()
	t.id = id
	t.display_name = nm
	t.description = desc
	t.color = col
	t.symbol = sym
	for k in f:
		t.set(k, f[k])
	_reg(t)

func _traj(id: StringName, nm: String, desc: String, col: Color, sym: String, f: Dictionary) -> void:
	var t := TrajectoryModule.new()
	t.id = id
	t.display_name = nm
	t.description = desc
	t.color = col
	t.symbol = sym
	for k in f:
		t.set(k, f[k])
	_reg(t)

func _cat(id: StringName, nm: String, desc: String, col: Color, sym: String, kind: CatalystModule.Kind, f: Dictionary) -> void:
	var c := CatalystModule.new()
	c.id = id
	c.display_name = nm
	c.description = desc
	c.color = col
	c.symbol = sym
	c.kind = kind
	for k in f:
		c.set(k, f[k])
	_reg(c)

func _build() -> void:
	# ---- Triggers ----------------------------------------------------------------------------
	_trigger(&"pulse_spitter", "Pulse Spitter", "Fast light bolts. Low heat, low risk.", Pal.CYAN, "T1", {
		"pellets": 1, "spread_deg": 3.0, "shots_per_second": 8.0, "proj_speed": 330.0, "damage": 4.0, "lifetime": 0.9,
		"proj_size": 2.5, "knockback": 30.0, "recoil": 14.0, "heat_per_shot": 2.2, "instability_value": 10.0,
		"misfire_id": &"runaway_cadence", "risk_text": "Cadence can run away."})
	_trigger(&"buckshot_cluster", "Buckshot Cluster", "Eight pellets in a wide cone. Hot, heavy knockback.", Pal.AMBER, "T2", {
		"pellets": 8, "spread_deg": 40.0, "shots_per_second": 1.7, "proj_speed": 270.0, "damage": 5.0, "lifetime": 0.7,
		"proj_size": 3.0, "knockback": 130.0, "recoil": 130.0, "heat_per_shot": 12.0, "instability_value": 25.0,
		"misfire_id": &"recoil_pushback", "risk_text": "Violent recoil.", "unlock_cost": 0})
	_trigger(&"beam_capacitor", "Beam Charging Capacitor", "Hold to charge a piercing beam. Charging builds heat constantly.", Pal.CYAN, "T3", {
		"pellets": 1, "spread_deg": 0.0, "shots_per_second": 1.2, "proj_speed": 520.0, "damage": 34.0, "lifetime": 0.55,
		"proj_size": 7.0, "pierce": 99, "knockback": 90.0, "recoil": 170.0, "heat_per_shot": 8.0,
		"charge_time": 1.1, "charge_heat_per_sec": 22.0, "instability_value": 30.0,
		"misfire_id": &"capacitor_arc", "risk_text": "Capacitor arcs into you.", "unlock_cost": 40})
	_trigger(&"sniper_mag", "Pulsing Sniper Magazine", "Very fast, piercing slug. Slow cadence.", Pal.WHITE, "T4", {
		"pellets": 1, "spread_deg": 0.0, "shots_per_second": 1.5, "proj_speed": 780.0, "damage": 26.0, "lifetime": 1.1,
		"proj_size": 3.0, "pierce": 2, "knockback": 170.0, "recoil": 60.0, "heat_per_shot": 15.0, "instability_value": 20.0,
		"misfire_id": &"mag_overpressure", "risk_text": "Magazine overpressure spikes heat.", "unlock_cost": 35})
	_trigger(&"giga_pulse", "Giga-Cadence Spitter", "Absurd fire rate. Melts your own cooling.", Pal.LIME, "T5", {
		"pellets": 1, "spread_deg": 8.0, "shots_per_second": 15.0, "proj_speed": 300.0, "damage": 2.6, "lifetime": 0.8,
		"proj_size": 2.2, "knockback": 12.0, "recoil": 8.0, "heat_per_shot": 1.7, "instability_value": 20.0,
		"misfire_id": &"runaway_cadence", "risk_text": "Cadence runs away. Heat climbs fast.", "unlock_cost": 50})
	# ---- Trajectories ------------------------------------------------------------------------
	_traj(&"straight_rail", "Straight Rail", "No frills. Shots fly straight.", Pal.STEEL, "R0", {
		"heat_per_shot": 0.0, "instability_value": 0.0})
	_traj(&"ricochet_coil", "Ricochet Coil", "Bounce off walls up to 3 times, gaining speed.", Pal.AMBER, "R1", {
		"bounces": 3, "bounce_speed_gain": 1.18, "life_mult": 1.9, "heat_per_shot": 2.0, "instability_value": 25.0,
		"misfire_id": &"flipper_recoil", "risk_text": "Recoil turns you into a pinball.", "unlock_cost": 0})
	_traj(&"gravity_curve", "Gravitational Curve", "Shots bend into dense enemy groups; with no group nearby they sink to the floor at your feet.", Pal.VIOLET, "R2", {
		"homing": 4.2, "drops_without_target": true, "life_mult": 1.3, "heat_per_shot": 1.0, "instability_value": 20.0,
		"misfire_id": &"boomerang", "risk_text": "Gravity can flip towards you.", "unlock_cost": 30})
	_traj(&"orbital_magnet", "Orbital Magnet", "Misses return as orbiting shields. Beams spiral around you.", Pal.CYAN, "R3", {
		"orbital": true, "life_mult": 1.2, "heat_per_shot": 4.0, "instability_value": 30.0,
		"misfire_id": &"boomerang", "risk_text": "Orbits can snap back into you.", "unlock_cost": 45})
	_traj(&"sinus_helix", "Sinus Helix", "Double-S curve that slips through cover blocks.", Pal.WHITE, "R4", {
		"sine_amp": 13.0, "sine_freq": 13.0, "through_cover": true, "life_mult": 1.2, "heat_per_shot": 2.0, "instability_value": 25.0,
		"misfire_id": &"phase_flip", "risk_text": "Phase flip can fire backwards.", "unlock_cost": 40})
	# ---- Catalysts ---------------------------------------------------------------------------
	_cat(&"plain_slug", "Plain Slug", "No effect. Safe and boring.", Pal.STEEL, "C0", CatalystModule.Kind.PLAIN, {
		"heat_per_shot": 0.0, "instability_value": 0.0})
	_cat(&"toxic_catalyst", "Toxic Catalyst", "Impacts leave acid pools. Vent at ~90 heat ignites them all.", Pal.LIME, "C1", CatalystModule.Kind.TOXIC, {
		"heat_per_shot": 1.0, "instability_value": 20.0, "misfire_id": &"acid_trail", "risk_text": "Acid leaks beneath YOU.", "unlock_cost": 0})
	_cat(&"shockwave_core", "Shockwave Core", "Hits emit a knockback ring that stuns.", Pal.CYAN, "C2", CatalystModule.Kind.SHOCK, {
		"heat_per_shot": 3.0, "instability_value": 20.0, "misfire_id": &"launch_back", "risk_text": "Launches you into walls.", "unlock_cost": 35})
	_cat(&"implosion_charge", "Implosion Charge", "Pulls enemies together, then detonates.", Pal.VIOLET, "C3", CatalystModule.Kind.IMPLOSION, {
		"heat_per_shot": 5.0, "instability_value": 30.0, "misfire_id": &"pull_to_shot", "risk_text": "Drags YOU towards the shot.", "unlock_cost": 55})
