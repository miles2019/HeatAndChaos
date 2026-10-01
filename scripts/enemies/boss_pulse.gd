class_name PulseBoss
extends BossBase
## Act 4 - THE PULSE, the awakened overheating consciousness. Three phases; it answers to YOUR build:
## from phase 2 it can OVERRIDE your weapon with a forced glitch misfire. Defeating it opens the ending choice.

var tick := 0.0
var rays: Array = []
var ray_a := 0.0
var spiral := 0.0
var warn := 0.0
var override_done := false

func _init() -> void:
	super()
	hp = 1600.0
	radius = 28.0
	thresholds = [0.66, 0.33]
	act_no = 4

func _boss_setup() -> void:
	kind_id = "pulse"
	display_name = "THE PULSE"
	subtitle = "Chaos is not a fault. It is evolution."
	color = Color("ff4f9a")
	scrap_value = 0

func beat_period() -> float:
	return [0.95, 0.75, 0.55][clampi(phase - 1, 0, 2)]

func _pool() -> Array:
	match phase:
		1: return ["rings", "tendrils", "rings", "assimilate"]
		2: return ["rings", "tendrils", "override", "assimilate", "spirals"]
		_: return ["spirals", "tendrils", "override", "rings", "assimilate", "spirals"]

func _enter_phase(n: int) -> void:
	Game.toast.emit("THE PULSE: %s" % ["IT LEARNS", "IT ADAPTS"][n - 2], Pal.AMBER)
	rays = []

func _on_attack_start(pl) -> void:
	tick = 0.0
	override_done = false
	rays = []
	if atk == "tendrils":
		ray_a = randf() * TAU
		for i in (4 if phase < 3 else 6):
			rays.append(ray_a + TAU * i / float(4 if phase < 3 else 6))

# --- Heartbeat Rings: a ring on every beat, one gap to slip through
func _upd_rings(dt: float, _pl) -> void:
	at += dt
	rig.boost = 0.0
	if beat_flag and at > 0.5 and at < 4.0:
		ring_of_pellets(30, 105.0, 3.0, color, 4)
		Audio.play("shot", 0.5, -8.0)
		if phase == 3:
			ring_of_pellets(18, 70.0, 3.5, Pal.CYAN, 2)
	if at >= 4.6:
		_end_attack()

# --- Tendrils: rotating rays from the core
func _upd_tendrils(dt: float, pl) -> void:
	at += dt
	if at < 1.2:
		warn = at / 1.2
		for i in rays.size():
			rays[i] = float(rays[i]) + dt * 0.4
		rig.boost = warn * 0.1
	elif at < 4.4:
		warn = 1.0
		rig.boost = 0.0
		var spd := 0.75 if phase == 1 else 1.0
		for i in rays.size():
			rays[i] = float(rays[i]) + dt * spd
			var a: float = rays[i]
			var d := _dist_seg(pl.position, position, position + Vector2.from_angle(a) * ray_len(a))
			if d < 5.0 + pl.radius * 0.5:
				pl.take_damage(1, pl.position + Vector2.from_angle(a + PI * 0.5) * 5.0)
		Juice.shake(Vector2.ZERO, 0.2, 0.0, 0.4)
	else:
		rays = []
		warn = 0.0
		_end_attack()

# --- Assimilate: calls the machines of the Furnace to its heartbeat
func _upd_assimilate(dt: float, pl) -> void:
	at += dt
	rig.boost = clampf(at / 0.9, 0.0, 1.0) * 0.12
	if at >= 0.9 and not override_done:
		override_done = true
		rig.boost = 0.0
		var kinds := ["hunter", "drone", "drone", "turret"] if phase < 3 else ["hunter", "brute", "drone", "drone", "turret"]
		for i in kinds.size():
			var ang := TAU * i / float(kinds.size())
			Game.world.rooms.create_enemy(kinds[i], position + Vector2.from_angle(ang) * 90.0)
		Juice.big_effect(position, color, 0.6)
	if at < 2.2 and at > 0.9:
		pl.apply_impulse((position - pl.position).normalized() * 120.0 * dt)
	if at >= 2.4:
		_end_attack()

# --- Override: forces a glitch misfire on YOUR weapon
func _upd_override(dt: float, pl) -> void:
	at += dt
	warn = clampf(at / 1.2, 0.0, 1.0)
	rig.boost = warn * 0.1
	if at >= 1.2 and not override_done:
		override_done = true
		rig.boost = 0.0
		var id: StringName = ModuleDB.GLITCH_POOL.pick_random()
		pl.weapon.force_misfire(id)
		Game.toast.emit("THE PULSE OVERRIDES YOUR WEAPON", Pal.VIOLET)
		Juice.big_effect(pl.position, Pal.VIOLET, 0.6)
	if at >= 2.0:
		warn = 0.0
		_end_attack()

# --- Spirals: interleaved bullet arms
func _upd_spirals(dt: float, _pl) -> void:
	at += dt
	if at > 0.6 and at < 4.2:
		spiral += dt * (2.6 if phase < 3 else 3.6)
		tick -= dt
		if tick <= 0.0:
			tick = 0.08
			var arms := 3 if phase < 3 else 5
			for k in arms:
				pellet(Vector2.from_angle(spiral + TAU * k / float(arms)), 100.0, 3.0, color if k % 2 == 0 else Pal.CYAN)
	if at >= 4.8:
		_end_attack()

# ---- drawing -----------------------------------------------------------------------------------
func _draw_world(canvas: Node2D) -> void:
	for a in rays:
		var len := ray_len(a)
		var dv := Vector2.from_angle(a)
		if at < 1.2:
			canvas.draw_line(dv * radius, dv * len, Color(1, 0.3, 0.6, 0.15 + 0.5 * warn), 1.0)
		else:
			var f := 0.7 + 0.3 * sin(at * 50.0)
			canvas.draw_line(dv * radius, dv * len, Color(1, 0.2, 0.5, 0.4), 8.0 * f)
			canvas.draw_line(dv * radius, dv * len, Color(1, 0.7, 0.9, 0.9), 3.0 * f)
	if atk == "override":
		canvas.draw_arc(Vector2.ZERO, 40.0 + 60.0 * warn, 0.0, TAU, 32, Color(0.64, 0.3, 1.0, 0.8 * (1.0 - warn * 0.5)), 2.0)

func _draw_art(canvas: Node2D) -> void:
	var b := 1.0 + 0.1 * glow_flash
	var pts := PackedVector2Array()
	for i in 22:
		var a := TAU * float(i) / 22.0
		pts.append(Vector2.from_angle(a) * 28.0 * b * (1.0 + 0.1 * sin(a * 4.0 + Juice.phase) + 0.06 * sin(a * 9.0 - Juice.phase * 1.7)))
	canvas.draw_colored_polygon(pts, c(Color("3a0f2a")))
	canvas.draw_polyline(_closed(pts), c(color), 2.0)
	# half machine, half organism: plates and pulsing veins
	for i in 6:
		var a2 := TAU * i / 6.0 + 0.3
		canvas.draw_line(Vector2.from_angle(a2) * 10.0, Vector2.from_angle(a2) * (22.0 + 4.0 * sin(Juice.phase + i)), c(color.lightened(0.2)), 2.0)
		canvas.draw_rect(Rect2(Vector2.from_angle(a2 + 0.5) * 22.0 - Vector2(3, 2), Vector2(6, 4)), c(Pal.STEEL))
	for k in 3:
		canvas.draw_arc(Vector2.ZERO, 12.0 + k * 4.0, Juice.phase * (k + 1) * 0.3, Juice.phase * (k + 1) * 0.3 + 2.0, 10, c(Pal.CYAN if k == 1 else color), 1.0)
	canvas.draw_circle(Vector2.ZERO, 9.0 + 2.0 * glow_flash, c(Color("1a0612")))
	canvas.draw_circle(Vector2.ZERO, 6.0, c(color.lerp(Color.WHITE, glow_flash)))
	canvas.draw_circle(Vector2.ZERO, 2.5, c(Color.WHITE))

func _draw_glow(canvas: Node2D) -> void:
	Juice.glow(canvas, Vector2.ZERO, 70.0 + 10.0 * glow_flash, Color(1.0, 0.3, 0.6, 0.3 + 0.4 * glow_flash + 0.1 * phase))
