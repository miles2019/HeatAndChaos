class_name WorldEffect
extends Node2D
## Catalyst / hazard / telegraph effects: acid pools, shock rings, implosions, mortar shells, spawn portals, arcs.

var kind := "acid"
var p: Dictionary = {}
var t := 0.0
var radius := 20.0
var duration := 6.0
var hostile := false
var color := Pal.LIME
var _tick := 0.0
var _seed := 0.0
var _hit: Dictionary = {}
var _done := false
var _glow := ArtNode.new()
var ignited := false

func setup(k: String, pos: Vector2, params: Dictionary) -> void:
	kind = k
	p = params
	position = pos
	radius = params.get("radius", 20.0)
	duration = params.get("duration", 6.0)
	hostile = params.get("hostile", false)
	color = params.get("color", Pal.LIME)
	_seed = randf() * 100.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw_fn = _draw_glow
	add_child(_glow)
	match kind:
		"acid":
			if not hostile:
				add_to_group("acid")
			z_index = -10
		"flame":
			z_index = -9
			hostile = true
			color = Pal.RED
		"shock":
			z_index = 3
			_start_shock()
		"implode":
			z_index = 3
			color = Pal.VIOLET
			Audio.play("charge", 0.6, -6.0)
		"mortar":
			z_index = 6
			Audio.play("snap", 0.5, -4.0)
		"spawn":
			z_index = -8
		"arc":
			z_index = 8

func _start_shock() -> void:
	color = p.get("color", Pal.CYAN)
	duration = p.get("dur", 0.32)
	var boss: bool = p.get("hostile", false)
	hostile = boss
	Audio.play("boom", 1.3 if not boss else 0.7, -4.0)
	Juice.burst(position, color, 14, radius * 2.0)
	if not boss:
		Juice.shake(Vector2.ZERO, 1.2 + radius / 60.0, 0.3)
	if radius >= 90.0 and not boss:
		Juice.wave(position, 0.7)

func _process(dt: float) -> void:
	if _done:
		return
	t += dt
	match kind:
		"acid", "flame":
			_step_acid(dt)
		"shock":
			_step_shock(dt)
		"implode":
			_step_implode(dt)
		"mortar":
			if t >= p["flight"]:
				_land()
		"spawn":
			if t >= duration:
				_done = true
				if p.has("cb"):
					(p["cb"] as Callable).call()
				queue_free()
		"arc":
			if t >= 0.22:
				queue_free()
	queue_redraw()
	_glow.queue_redraw()

func _enemies() -> Array:
	var w = Game.world
	return w.current_room().enemies if w else []

# ---- acid / flame ----------------------------------------------------------------------------
func _step_acid(dt: float) -> void:
	if duration > 0.0 and t > duration:
		queue_free()
		return
	_tick -= dt
	if _tick > 0.0:
		return
	_tick = 0.3
	var r := radius * minf(1.0, t * 5.0)
	var w = Game.world
	if not hostile:
		for e in _enemies():
			if is_instance_valid(e) and not e.dead and e.position.distance_to(position) < r + e.radius * 0.4:
				e.take_dot(3.2, color)
	else:
		var pl = w.player if w else null
		if pl != null and not pl.dead and pl.position.distance_to(position) < r * 0.9 + pl.radius * 0.3:
			pl.take_damage(1, position)

func ignite(delay: float) -> void:
	if ignited:
		return
	ignited = true
	await get_tree().create_timer(delay, true, false, true).timeout
	if not is_inside_tree():
		return
	var w = Game.world
	if w:
		w.spawn_effect("shock", position, {"radius": radius * 2.4 + 18.0, "force": 240.0, "damage": 32.0, "stun": 0.8, "color": Pal.RED, "dur": 0.3})
		Juice.burst(position, Pal.LIME, 10, 120.0, Vector2.ZERO, TAU, 0.5, 2.0, ParticleField.EMBER)
	queue_free()

func merge(other_radius: float) -> void:
	radius = minf(radius + other_radius * 0.07, 22.0)
	t = minf(t, 0.3)

# ---- shock ring --------------------------------------------------------------------------------
func _step_shock(dt: float) -> void:
	var prog := clampf(t / duration, 0.0, 1.0)
	var ring := radius * (1.0 - pow(1.0 - prog, 2.0))
	var w = Game.world
	if hostile:
		var pl = w.player if w else null
		if pl != null and not pl.dead and not _hit.has("pl"):
			var d: float = pl.position.distance_to(position)
			if absf(d - ring) < 8.0 + pl.radius * 0.5:
				_hit["pl"] = true
				pl.take_damage(1, position)
	else:
		for e in _enemies():
			if not is_instance_valid(e) or e.dead:
				continue
			var key: int = e.get_instance_id()
			if _hit.has(key):
				continue
			var d2: float = e.position.distance_to(position)
			if d2 <= ring + e.radius:
				_hit[key] = true
				var dir: Vector2 = (e.position - position).normalized() if d2 > 0.5 else Vector2.RIGHT.rotated(randf() * TAU)
				e.apply_knock(dir * p.get("force", 250.0))
				e.stun(p.get("stun", 0.5))
				e.take_hit(p.get("damage", 5.0), dir, 0.0, false)
	if t >= duration + 0.15:
		queue_free()

# ---- implosion ---------------------------------------------------------------------------------
func _step_implode(dt: float) -> void:
	var delay: float = p.get("delay", 0.45)
	if t < delay:
		for e in _enemies():
			if is_instance_valid(e) and not e.dead and e.position.distance_to(position) < radius * 1.5:
				e.apply_pull(position, 420.0, dt)
		var w = Game.world
		if w:
			for pr in w.projectiles:
				if pr.active and pr.faction == 1 and pr.position.distance_to(position) < radius * 1.5:
					pr.vel = pr.vel.lerp((position - pr.position).normalized() * 160.0, 0.2)
					if pr.position.distance_to(position) < 6.0:
						pr.kill("shield")
	elif not _done:
		_done = true
		var dmg: float = p.get("damage", 16.0)
		for e in _enemies():
			if is_instance_valid(e) and not e.dead:
				var d: float = e.position.distance_to(position)
				if d < radius + e.radius:
					var dir: Vector2 = (e.position - position).normalized() if d > 0.5 else Vector2.RIGHT
					e.take_hit(dmg * (1.0 - 0.5 * d / (radius + e.radius)), dir, 140.0, false)
		Audio.play("boom", 0.8)
		if radius >= 100.0:
			Juice.big_effect(position, Pal.VIOLET, 0.9)
		else:
			Juice.shake(Vector2.ZERO, 3.0, 0.8, 0.3)
			Juice.hit_stop(2)
			Juice.wave(position, 0.5, 0.5)
			Juice.burst(position, Pal.VIOLET, 18, 140.0, Vector2.ZERO, TAU, 0.45, 2.0)
			Juice.ring(position, Pal.VIOLET, radius, 0.35)
		t = delay
		get_tree().create_timer(0.25, true, false, true).timeout.connect(queue_free)

# ---- mortar ------------------------------------------------------------------------------------
func _land() -> void:
	_done = true
	var w = Game.world
	Audio.play("boom", 1.4, -2.0)
	Juice.burst(position, Pal.LIME, 14, 110.0, Vector2.ZERO, TAU, 0.5, 2.0)
	if w:
		w.spawn_effect("shock", position, {"radius": 28.0, "dur": 0.2, "hostile": true, "color": Pal.LIME})
		w.spawn_effect("acid", position, {"radius": 22.0, "duration": 6.5, "hostile": true})
	queue_free()

# ---- drawing -----------------------------------------------------------------------------------
func _blob(r: float, wob: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		var rr := r * (1.0 + sin(a * 3.0 + t * 2.0 + _seed) * wob + sin(a * 5.0 - t * 1.3 + _seed * 2.0) * wob * 0.6)
		pts.append(Vector2.from_angle(a) * rr)
	return pts

func _draw() -> void:
	match kind:
		"acid", "flame":
			var r := radius * minf(1.0, t * 5.0)
			var fade := 1.0
			if duration > 0.0:
				fade = clampf((duration - t) / 1.2, 0.0, 1.0)
			var pts := _blob(r, 0.07)
			var base := Color(0.12, 0.35, 0.05, 0.75 * fade) if kind == "acid" else Color(0.45, 0.1, 0.05, 0.75 * fade)
			if hostile and kind == "acid":
				base = Color(0.2, 0.4, 0.05, 0.8 * fade)
			draw_colored_polygon(pts, base)
			var edge := color
			edge.a = (0.8 if not hostile else 1.0) * fade
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, edge, 1.0 if not hostile else 2.0)
			for i in 5:
				var ph := fposmod(t * 0.9 + _seed * 0.1 + i * 0.37, 1.0)
				var a := _seed + i * 2.4
				var bp := Vector2.from_angle(a) * r * 0.55 * (0.4 + fmod(a, 1.0))
				var br := (1.0 + ph * 2.0) * (0.6 if radius < 16.0 else 1.0)
				var bc := Color(0.7, 1.0, 0.3, (1.0 - ph) * fade) if kind == "acid" else Color(1.0, 0.7, 0.2, (1.0 - ph) * fade)
				draw_arc(bp + Vector2(0, -ph * 4.0), br, 0.0, TAU, 8, bc, 1.0)
		"shock":
			var prog := clampf(t / duration, 0.0, 1.0)
			var ring := radius * (1.0 - pow(1.0 - prog, 2.0))
			var a2 := clampf(1.0 - maxf(0.0, t - duration) / 0.15, 0.0, 1.0)
			var c := color
			c.a = 0.18 * (1.0 - prog) * a2
			draw_circle(Vector2.ZERO, ring, c)
			var rc := color.lerp(Color.WHITE, 1.0 - prog)
			rc.a = a2
			draw_arc(Vector2.ZERO, ring, 0.0, TAU, 40, rc, 3.0 if hostile else 2.0)
			rc.a *= 0.5
			draw_arc(Vector2.ZERO, ring * 0.82, 0.0, TAU, 32, rc, 1.0)
		"implode":
			var delay: float = p.get("delay", 0.45)
			var prog2 := clampf(t / delay, 0.0, 1.0)
			for i in 3:
				var ph2 := fposmod(prog2 * 1.5 + i / 3.0, 1.0)
				var cc := Pal.VIOLET.lerp(Color.WHITE, ph2)
				cc.a = ph2 * 0.9
				draw_arc(Vector2.ZERO, radius * (1.0 - ph2), 0.0, TAU, 32, cc, 1.0 + ph2)
			draw_circle(Vector2.ZERO, 2.0 + prog2 * 4.0, Color(0.05, 0.0, 0.1))
			draw_arc(Vector2.ZERO, 3.0 + prog2 * 5.0, 0.0, TAU, 12, Pal.VIOLET, 1.0)
		"mortar":
			var f: float = p["flight"]
			var k := clampf(t / f, 0.0, 1.0)
			var from: Vector2 = p["from"] - position
			var pos2 := from.lerp(Vector2.ZERO, k) + Vector2(0, -sin(k * PI) * 70.0)
			# ground marker
			var mc := Pal.RED.lerp(Pal.LIME, 1.0 - k)
			mc.a = 0.5 + 0.5 * sin(t * 30.0)
			draw_arc(Vector2.ZERO, 24.0 * (1.2 - 0.2 * k), 0.0, TAU, 24, mc, 1.0)
			draw_arc(Vector2.ZERO, 24.0 * k, 0.0, TAU, 24, Color(mc.r, mc.g, mc.b, 0.8), 1.0)
			draw_circle(Vector2.ZERO, 1.5, mc)
			draw_circle(pos2 + Vector2(1, 3), 3.0, Color(0, 0, 0, 0.3))
			draw_circle(pos2, 3.5, Pal.LIME)
			draw_circle(pos2, 1.8, Color.WHITE)
		"spawn":
			var k2 := clampf(t / duration, 0.0, 1.0)
			var c2 := Pal.RED.lerp(Color.WHITE, k2)
			c2.a = 0.4 + 0.6 * k2
			draw_arc(Vector2.ZERO, 14.0 * (1.5 - k2), 0.0, TAU, 20, c2, 1.0)
			draw_arc(Vector2.ZERO, 6.0 + 8.0 * k2, 0.0, TAU, 12, c2, 1.0)
			for i in 4:
				var a3 := t * 9.0 + i * PI * 0.5
				draw_rect(Rect2((Vector2.from_angle(a3) * 12.0 * (1.2 - k2)).floor(), Vector2(2, 2)), c2)
		"arc":
			var a: Vector2 = p["a"] - position
			var b: Vector2 = p["b"] - position
			var pts2 := PackedVector2Array([a])
			for i in 1:
				pass
			var segs := 7
			for i in range(1, segs):
				var q := a.lerp(b, float(i) / segs)
				pts2.append(q + Vector2(randf_range(-6, 6), randf_range(-6, 6)))
			pts2.append(b)
			draw_polyline(pts2, Color(Pal.CYAN.r, Pal.CYAN.g, Pal.CYAN.b, 1.0 - t / 0.22), 2.0)
			draw_polyline(pts2, Color(1, 1, 1, 1.0 - t / 0.22), 1.0)

func _draw_glow(c: Node2D) -> void:
	match kind:
		"acid", "flame":
			var fade := 1.0
			if duration > 0.0:
				fade = clampf((duration - t) / 1.2, 0.0, 1.0)
			var r := radius * minf(1.0, t * 5.0)
			Juice.glow(c, Vector2.ZERO, r * 1.8, Color(color.r, color.g, color.b, 0.35 * fade * (0.8 + 0.2 * sin(t * 4.0))))
		"shock":
			var prog := clampf(t / duration, 0.0, 1.0)
			Juice.glow(c, Vector2.ZERO, radius * (1.0 - pow(1.0 - prog, 2.0)) * 1.3, Color(color.r, color.g, color.b, 0.35 * (1.0 - prog)))
		"implode":
			var delay: float = p.get("delay", 0.45)
			Juice.glow(c, Vector2.ZERO, 14.0 + 30.0 * clampf(t / delay, 0.0, 1.0), Color(0.6, 0.2, 1.0, 0.6))
		"spawn":
			Juice.glow(c, Vector2.ZERO, 22.0, Color(1, 0.3, 0.2, 0.3 * clampf(t / duration, 0.0, 1.0)))
