class_name MagnetWarden
extends BossBase
## Act 3 - MAGNET WARDEN, a modular guardian that COPIES YOUR BUILD: its volleys use your trigger's pellet
## pattern and your trajectory module's behaviour (ricochet, helix, curl, split, hesitation...).
## Its three orbiting segments are tinted with your current module colours.

var spin := 0.0
var grav_t := 0.0
var spiral := 0.0
var tick := 0.0
var lock := Vector2.RIGHT
var volley_n := 0

func _init() -> void:
	super()
	hp = 1000.0
	radius = 20.0
	thresholds = [0.5]
	act_no = 3

func _boss_setup() -> void:
	kind_id = "warden"
	display_name = "MAGNET WARDEN"
	subtitle = "It learned your build"
	color = Pal.VIOLET
	scrap_value = 0

func beat_period() -> float:
	return 0.85 if phase == 1 else 0.65

func _pool() -> Array:
	return ["mimic", "rings", "gravity", "mimic", "rings"] if phase == 1 else ["mimic", "gravity", "rings", "mimic"]

func _enter_phase(_n: int) -> void:
	Game.toast.emit("WARDEN: DETACHING SATELLITES", Pal.VIOLET)

func _on_attack_start(pl) -> void:
	tick = 0.0
	grav_t = 0.0
	volley_n = 0
	lock = (pl.position - position).normalized()

func _origins() -> Array:
	var o: Array = [position]
	if phase >= 2:
		for k in 2:
			o.append(position + Vector2.from_angle(spin * 1.3 + k * PI) * 78.0)
	return o

# --- Mimic: fires volleys using YOUR trigger + trajectory
func _upd_mimic(dt: float, pl) -> void:
	at += dt
	rig.boost = clampf(at / 0.8, 0.0, 1.0) * 0.1
	var l := Game.loadout
	if l == null:
		_end_attack()
		return
	var volleys := 3
	if at >= 0.8 + volley_n * 0.75 and volley_n < volleys:
		volley_n += 1
		rig.boost = 0.0
		_mimic_volley(pl, l)
	if at >= 0.8 + volleys * 0.75 + 0.6:
		_end_attack()

func _mimic_volley(pl, l: WeaponLoadout) -> void:
	var trig: TriggerModule = l.trigger_module
	var traj: TrajectoryModule = l.trajectory_module
	Audio.play("misfire", 1.2, -8.0)
	for o in _origins():
		var dir: Vector2 = ((pl.position - o).normalized())
		var stream := 5 if trig.shots_per_second > 6.0 else 1
		for k in stream:
			var fire_it := func() -> void:
				var shots := trig.fire({"dir": dir.rotated(randf_range(-0.05, 0.05) * k), "charge": 1.0, "origin": o, "heat": 0.0, "loadout": l})
				for s in shots:
					var p: Projectile = Game.world.acquire_projectile()
					if p == null:
						return
					s["speed"] = clampf(float(s["speed"]) * 0.45, 110.0, 190.0)
					s["damage"] = 1.0
					s["lifetime"] = float(s["lifetime"]) * 2.4
					s["pierce"] = 0
					s["size"] = clampf(float(s["size"]), 2.5, 6.0)
					s["color"] = trig.color.lerp(traj.color, 0.4)
					p.setup(s, o + (s["dir"] as Vector2) * 10.0, 1)
					traj.modify_projectile(p)           # <- your own flight behaviour, turned on you
					p.pierce = 0
					p.catalyst = null
					p.orbit_state = 0
					p.return_on_miss = false
			if k == 0:
				fire_it.call()
			else:
				later(0.09 * k, fire_it)
	Juice.ring(position, Pal.VIOLET, 50.0, 0.3)

# --- Rings: expanding bullet rings with a gap
func _upd_rings(dt: float, _pl) -> void:
	at += dt
	tick -= dt
	rig.boost = 0.0
	if at > 0.7 and tick <= 0.0 and at < 3.4:
		tick = 0.65 if phase == 1 else 0.5
		ring_of_pellets(26, 100.0, 3.0, Pal.VIOLET, 3)
		Audio.play("shot", 0.6, -8.0)
		spin += 0.3
	if at >= 4.0:
		_end_attack()

# --- Gravity: alternating pull and push + spiral arms
func _upd_gravity(dt: float, pl) -> void:
	at += dt
	grav_t += dt
	var to: Vector2 = position - pl.position
	if at > 0.6 and at < 4.0:
		var sgn := 1.0 if int(at / 1.1) % 2 == 0 else -1.0
		pl.apply_impulse(to.normalized() * sgn * 200.0 * dt)
		spiral += dt * 3.0
		tick -= dt
		if tick <= 0.0:
			tick = 0.12
			for k in 2:
				pellet(Vector2.from_angle(spiral + PI * k), 105.0, 3.0, Pal.CYAN if sgn < 0.0 else Pal.VIOLET)
	if at >= 4.4:
		_end_attack()

func _process(dt: float) -> void:
	spin += dt * (1.2 + 0.8 * phase)
	super._process(dt)

# ---- drawing -----------------------------------------------------------------------------------
func _draw_world(canvas: Node2D) -> void:
	if atk == "gravity" and at > 0.6 and at < 4.0:
		var sgn := 1.0 if int(at / 1.1) % 2 == 0 else -1.0
		var col := Color(0.64, 0.3, 1.0) if sgn > 0.0 else Color(0.2, 0.9, 1.0)
		for i in 3:
			var ph := fposmod(at * 1.2 * sgn + i / 3.0, 1.0)
			canvas.draw_arc(Vector2.ZERO, 180.0 * (1.0 - ph if sgn > 0.0 else ph), 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.5 * (1.0 - ph)), 1.0)
	if phase >= 2:
		for o in _origins():
			if o != position:
				canvas.draw_circle(o - position, 6.0, Pal.STEEL)
				canvas.draw_arc(o - position, 8.0, 0.0, TAU, 12, Pal.VIOLET, 1.0)

func _draw_art(canvas: Node2D) -> void:
	var l := Game.loadout
	var cols: Array = [Pal.CYAN, Pal.VIOLET, Pal.LIME]
	if l:
		cols = [l.trigger_module.color, l.trajectory_module.color, l.catalyst_module.color]
	var body := _poly(13.0, 6, spin * 0.2)
	canvas.draw_colored_polygon(body, c(Pal.STEEL_DARK))
	canvas.draw_polyline(_closed(body), c(Pal.STEEL), 2.0)
	for i in 3:
		var a := spin + i * TAU / 3.0
		canvas.draw_arc(Vector2.ZERO, 20.0, a, a + 1.4, 12, c(cols[i]), 4.0)
		canvas.draw_circle(Vector2.from_angle(a + 0.7) * 20.0, 3.0, c(cols[i].lightened(0.4)))
	canvas.draw_circle(Vector2.ZERO, 6.0 + 2.0 * glow_flash, c(Color("1b0f30")))
	canvas.draw_circle(Vector2.ZERO, 4.0, c(Pal.VIOLET.lerp(Color.WHITE, glow_flash)))
	canvas.draw_circle(Vector2.ZERO, 1.5, c(Color.WHITE))

func _draw_glow(canvas: Node2D) -> void:
	Juice.glow(canvas, Vector2.ZERO, 48.0, Color(0.6, 0.25, 1.0, 0.3 + 0.4 * glow_flash))
