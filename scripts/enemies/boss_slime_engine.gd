class_name SlimeEngineBoss
extends BossBase
## Act 2 - THE SLIME-FUSED ENGINE. Floods floor strips with acid, lobs slime mortars, rams across the arena.
## At 50% HP it undergoes MITOSIS: the screen is pulled apart, two smaller, faster engines snap away.

var strips: Array = []
var charge_dir := Vector2.RIGHT
var trail_t := 0.0
var eye := Vector2.ZERO

func _init() -> void:
	super()
	hp = 800.0
	radius = 24.0
	thresholds = [0.5]
	act_no = 2

func _boss_setup() -> void:
	kind_id = "slime_engine"
	display_name = "THE SLIME-FUSED ENGINE" if not is_child else "ENGINE HALF"
	subtitle = "Bio-Mechanical Abomination"
	color = Pal.LIME
	scrap_value = 0
	if is_child:
		intro_t = 0.5
		phase = 2
		thresholds = []

func beat_period() -> float:
	return 0.9 if not is_child else 0.65

func _pool() -> Array:
	if is_child:
		return ["lob", "charge"]
	return ["lob", "flood", "charge", "spawn"]

func _enter_phase(_n: int) -> void:
	if is_child:
		return
	_mitosis()

func _mitosis() -> void:
	Game.toast.emit("MITOSIS!", Pal.LIME)
	Juice.wave(position, 1.2, 0.9)
	Juice.zoom_punch(0.8)                         # anticipation: the arena stretches towards the split
	var half := hp * 0.5
	for s in [-1.0, 1.0]:
		var c := SlimeEngineBoss.new()
		c.is_child = true
		c.room = room
		c.position = position + Vector2(s * 26.0, 0.0)
		c.hp = half
		c.radius = 17.0
		room.content.add_child(c)
		room.enemies.append(c)
		c.kb = Vector2(s * 520.0, -90.0)          # snapped apart elastically
		c.rig.spring.squash(Vector2(1.8, 0.5))
	Juice.burst(position, Pal.LIME, 40, 240.0)
	Juice.debris(position, Pal.STEEL, 14, 220.0)
	dead = true
	visible = false
	queue_free()

func _on_attack_start(pl) -> void:
	strips = []
	trail_t = 0.0
	if atk == "flood":
		var vertical := randf() < 0.5
		var inn := room.inner
		for i in 3:
			var f := (float(i) + randf_range(0.2, 0.8)) / 3.0
			if vertical:
				strips.append(Rect2(inn.position.x + f * inn.size.x - 27.0, inn.position.y, 54.0, inn.size.y))
			else:
				strips.append(Rect2(inn.position.x, inn.position.y + f * inn.size.y - 27.0, inn.size.x, 54.0))
	if atk == "charge":
		charge_dir = (pl.position - position).normalized()

# --- Acid Flood: telegraphed strips fill with hostile acid
func _upd_flood(dt: float, _pl) -> void:
	at += dt
	rig.boost = clampf(at / 1.4, 0.0, 1.0) * 0.1
	if at >= 1.4 and not strips.is_empty() and strips[0] is Rect2:
		Audio.play("acid", 0.6, -2.0)
		Juice.shake(Vector2.ZERO, 2.0, 0.3)
		for r in strips:
			var rc: Rect2 = r
			var horizontal := rc.size.x > rc.size.y
			var n := int((rc.size.x if horizontal else rc.size.y) / 42.0)
			for k in n:
				var p := rc.position + (Vector2(k * 42.0 + 21.0, 27.0) if horizontal else Vector2(27.0, k * 42.0 + 21.0))
				Game.world.spawn_effect("acid", p, {"radius": 30.0, "duration": 6.0, "hostile": true})
		strips = [0]
		rig.boost = 0.0
	if at >= 2.2:
		strips = []
		_end_attack()

# --- Slime Lob: arcing mortars around you
func _upd_lob(dt: float, pl) -> void:
	at += dt
	rig.dir_angle = -PI * 0.5
	rig.hold_t = 0.2
	rig.boost = clampf(at / 0.8, 0.0, 1.0) * 0.18
	if at >= 0.8 and strips.is_empty():
		strips = [0]
		rig.boost = 0.0
		rig.spring.squash(Vector2(0.6, 1.5))
		var n := 3 if is_child else 5
		for i in n:
			var tgt: Vector2 = pl.position + pl.vel * 0.4 + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 70.0)
			var box := room.inner.grow(-20.0)
			tgt = Vector2(clampf(tgt.x, box.position.x, box.end.x), clampf(tgt.y, box.position.y, box.end.y))
			Game.world.spawn_effect("mortar", tgt, {"from": position, "flight": 1.0 + i * 0.12})
		Audio.play("shot_heavy", 0.5)
	if at >= 2.2:
		strips = []
		_end_attack()

# --- Ram: telegraph line, then a slime-trailing charge that ends in a shock ring
func _upd_charge(dt: float, pl) -> void:
	at += dt
	if at < 0.9:
		charge_dir = charge_dir.lerp((pl.position - position).normalized(), clampf(dt * 5.0, 0.0, 1.0)).normalized()
		rig.dir_angle = charge_dir.angle()
		rig.hold_t = 0.2
		rig.boost = clampf(at / 0.9, 0.0, 1.0) * 0.3
	elif at < 2.6:
		rig.boost = 0.0
		var inn := room.inner.grow(-radius - 4.0)
		vel = charge_dir * (430.0 if not is_child else 520.0)
		rig.dir_angle = charge_dir.angle()
		rig.hold_t = 0.1
		trail_t -= dt
		if trail_t <= 0.0:
			trail_t = 0.09
			Game.world.spawn_effect("acid", position, {"radius": 15.0, "duration": 4.0, "hostile": true})
		if not inn.has_point(position):
			at = 2.6
	else:
		vel = Vector2.ZERO
		Game.world.spawn_effect("shock", position, {"radius": 110.0, "dur": 0.4, "hostile": true, "color": Pal.LIME})
		Juice.big_effect(position, Pal.LIME, 0.7)
		_end_attack()

func _upd_spawn(dt: float, _pl) -> void:
	at += dt
	rig.boost = clampf(at / 0.8, 0.0, 1.0) * 0.12
	if at >= 0.8 and strips.is_empty():
		strips = [0]
		rig.boost = 0.0
		for i in 3:
			Game.world.rooms.create_enemy("slime", position + Vector2.from_angle(TAU * i / 3.0) * 36.0)
		Juice.burst(position, Pal.LIME, 20, 160.0)
		Audio.play("kill", 0.6)
	if at >= 1.6:
		strips = []
		_end_attack()

# ---- drawing -----------------------------------------------------------------------------------
func _draw_world(canvas: Node2D) -> void:
	for s in strips:
		if s is Rect2:
			var k := clampf(at / 1.4, 0.0, 1.0)
			var rr := Rect2((s as Rect2).position - position, (s as Rect2).size)
			canvas.draw_rect(rr, Color(0.5, 1.0, 0.2, 0.08 + 0.18 * k * (0.5 + 0.5 * sin(at * 24.0))))
			canvas.draw_rect(rr, Color(0.6, 1.0, 0.3, 0.6), false, 1.0)
	if atk == "charge" and at < 0.9:
		canvas.draw_line(charge_dir * radius, charge_dir * 600.0, Color(0.6, 1.0, 0.3, 0.2 + 0.5 * at), 1.0 + at * 2.0)

func _draw_art(canvas: Node2D) -> void:
	var s := radius / 24.0
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(Vector2.from_angle(a) * 24.0 * s * (1.0 + 0.09 * sin(a * 3.0 + Juice.phase * 1.5) + 0.05 * sin(a * 7.0 - Juice.phase * 2.1)))
	canvas.draw_colored_polygon(pts, c(Color("1f5a12")))
	canvas.draw_polyline(_closed(pts), c(Pal.LIME), 2.0)
	# iron engine plates and pistons swallowed by slime
	for i in 4:
		var a2 := TAU * i / 4.0 + 0.4
		var p := Vector2.from_angle(a2) * 16.0 * s
		canvas.draw_rect(Rect2(p - Vector2(5, 3) * s, Vector2(10, 6) * s), c(Pal.STEEL))
		canvas.draw_rect(Rect2(p - Vector2(5, 3) * s, Vector2(10, 1) * s), c(Pal.RUST))
	canvas.draw_circle(Vector2.ZERO, 11.0 * s, c(Color("0d2a08")))
	canvas.draw_circle(Vector2.ZERO, 8.0 * s + 2.0 * glow_flash, c(Color("9dff3a")))
	canvas.draw_circle(eye * 3.0, 4.0 * s, c(Color.BLACK))
	canvas.draw_circle(Vector2(-1, -1) * s, 1.5 * s, c(Color.WHITE))
	for i in 3:
		var bp := Vector2.from_angle(Juice.phase * 0.5 + i * 2.1) * 20.0 * s
		canvas.draw_circle(bp, (2.0 + sin(Juice.phase + i) * 0.8) * s, c(Color("b4ff6a")))

func _draw_glow(canvas: Node2D) -> void:
	Juice.glow(canvas, Vector2.ZERO, radius * 2.6, Color(0.4, 1.0, 0.15, 0.3 + 0.4 * glow_flash))
