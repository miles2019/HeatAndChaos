class_name Room
extends Node2D
## One arena (Soul-Knight sized, bigger than the screen). Procedurally laid out from a seed.
## Owns geometry/collision, hazards (spikes, bumpers, acid, magnet fields, pulse emitters), crack walls
## and its persistent particle field (debris stays all run).

const WALL := 48.0
const DOOR_W := 56.0
const L := 0
const R := 1
const U := 2
const D := 3
const THEMES := [
	{"name": "THE STEAM VAULTS", "floor": Color("2a1712"), "trim": Color("19e6ff")},
	{"name": "THE BIO-FOUNDRY", "floor": Color("14261a"), "trim": Color("8dff2a")},
	{"name": "THE MAGNET SPINE", "floor": Color("1b1830"), "trim": Color("a24bff")},
	{"name": "THE COREMIND", "floor": Color("2a1022"), "trim": Color("ff4f9a")},
]

var spec: Dictionary = {}
var kind := "combat"
var index := 0
var act := 1
var inner := Rect2(0, 0, 800, 520)
var title := ""
var cleared := false
var doors_closed := false
var safe := false
var trim_color := Pal.CYAN
var floor_color := Pal.RUST_DARK
var waves: Array = []
var exits: Dictionary = {}
var bench_pos := Vector2.ZERO

var blocks: Array[Rect2] = []
var cracks: Array = []             # {rect, hp, side}
var bumpers: Array = []            # [Vector2, radius]
var bumper_punch: Array[float] = []
var spikes: Array = []             # [Rect2, phase]
var magnets: Array = []            # [Vector2, radius, sign]
var emitters: Array = []           # [Vector2, timer]
var pending_acid: Array = []
var enemies: Array = []
var particles: ParticleField
var content := Node2D.new()

var _solids: Array[Rect2] = []
var _cache: Array[Rect2] = []
var _floor := ArtNode.new()
var _fx := ArtNode.new()
var _t := 0.0
var _steam_t := 0.0
var _door_anim := 0.0
var _font: Font

func center() -> Vector2:
	return inner.get_center()

func setup(s: Dictionary) -> void:
	spec = s
	kind = s["kind"]
	index = s["idx"]
	act = s["act"]
	exits = s["exits"]
	inner = Rect2(Vector2.ZERO, s["size"])
	var th: Dictionary = THEMES[act - 1]
	trim_color = th["trim"]
	floor_color = th["floor"]
	safe = kind in ["start", "workshop", "secret"]
	if safe:
		trim_color = Pal.AMBER
	var names := {"start": "ENTRY SHAFT", "combat": "PRESSURE LOCK", "elite": "KILL ZONE", "workshop": "MODULE WORKSHOP",
		"secret": "SECRET CACHE", "cursed": "CURSED CHAMBER", "boss": "BOSS CORE"}
	title = names.get(kind, kind.to_upper())
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s["seed"])
	_generate(rng)
	waves = WaveGen.make(kind, act, inner.size, rng)
	bumper_punch.resize(bumpers.size())
	bumper_punch.fill(0.0)
	_build_solids()
	_rebuild_cache()

func _lane(side: int) -> Rect2:
	var c := door_center(side)
	match side:
		L: return Rect2(inner.position.x, c.y - 70, 150, 140)
		R: return Rect2(inner.end.x - 150, c.y - 70, 150, 140)
		U: return Rect2(c.x - 70, inner.position.y, 140, 150)
		_: return Rect2(c.x - 70, inner.end.y - 150, 140, 150)

func _generate(rng: RandomNumberGenerator) -> void:
	var keep: Array[Rect2] = []
	for side in exits:
		keep.append(_lane(side))
	var n_blocks := 0
	match kind:
		"combat": n_blocks = rng.randi_range(6, 10)
		"elite": n_blocks = rng.randi_range(5, 8)
		"workshop": n_blocks = 3
		"start": n_blocks = 4
		"cursed": n_blocks = 4
		"secret": n_blocks = 0
		"boss": n_blocks = 0
	if kind == "workshop":
		bench_pos = center()
		blocks.append(Rect2(bench_pos - Vector2(22, 16), Vector2(44, 32)))
		keep.append(Rect2(bench_pos - Vector2(80, 70), Vector2(160, 140)))
	if kind == "boss":
		var c := center()
		var d := Vector2(inner.size.x * 0.34, inner.size.y * 0.32)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				blocks.append(Rect2(c + Vector2(sx * d.x, sy * d.y) - Vector2(18, 18), Vector2(36, 36)))
	if kind == "cursed":
		keep.append(Rect2(center() - Vector2(170, 60), Vector2(340, 120)))
	var tries := 0
	while blocks.size() < n_blocks + (1 if kind == "workshop" else 0) and tries < 120:
		tries += 1
		var sz := Vector2(rng.randi_range(2, 5) * 16, rng.randi_range(2, 4) * 16)
		var p := Vector2(rng.randf_range(inner.position.x + 50, inner.end.x - 50 - sz.x), rng.randf_range(inner.position.y + 50, inner.end.y - 50 - sz.y))
		var r := Rect2(p, sz)
		var ok := true
		for k in keep:
			if r.grow(10).intersects(k):
				ok = false
		for b in blocks:
			if r.grow(36).intersects(b):
				ok = false
		if not ok:
			continue
		blocks.append(r)
		if rng.randf() < 0.55:        # mirror for a designed look
			var m := Rect2(Vector2(inner.end.x - (p.x - inner.position.x) - sz.x, p.y), sz)
			var ok2 := true
			for k in keep:
				if m.grow(10).intersects(k):
					ok2 = false
			for b in blocks:
				if m.grow(36).intersects(b):
					ok2 = false
			if ok2:
				blocks.append(m)
	# hazards by act / kind
	if kind in ["combat", "elite", "cursed"]:
		for i in rng.randi_range(0, 2 + act / 2):
			bumpers.append([_free_point(rng, keep), 10.0])
		if act != 3:
			for i in rng.randi_range(0, 2):
				spikes.append([Rect2(_free_point(rng, keep) - Vector2(16, 16), Vector2(32, 32)), rng.randf() * 3.0])
		if act == 2:
			for i in rng.randi_range(1, 3):
				pending_acid.append([_free_point(rng, keep), rng.randf_range(18.0, 28.0)])
		if act == 3:
			for i in rng.randi_range(1, 2):
				magnets.append([_free_point(rng, keep), 80.0, 1.0 if rng.randf() < 0.5 else -1.0])
		if act == 4:
			for i in rng.randi_range(1, 2):
				emitters.append([_free_point(rng, keep), rng.randf() * 3.0])
			magnets.append([_free_point(rng, keep), 70.0, -1.0])
	if kind == "boss" and act == 3:
		magnets.append([center() + Vector2(-inner.size.x * 0.22, 0), 70.0, 1.0])
		magnets.append([center() + Vector2(inner.size.x * 0.22, 0), 70.0, -1.0])
	for side in spec.get("crack_sides", []):
		cracks.append({"rect": door_rect(side), "hp": 26.0, "side": side})

func _free_point(rng: RandomNumberGenerator, keep: Array[Rect2]) -> Vector2:
	for i in 40:
		var p := Vector2(rng.randf_range(inner.position.x + 60, inner.end.x - 60), rng.randf_range(inner.position.y + 60, inner.end.y - 60))
		var ok := true
		for k in keep:
			if k.grow(24).has_point(p):
				ok = false
		for b in blocks:
			if b.grow(30).has_point(p):
				ok = false
		if ok:
			keep.append(Rect2(p - Vector2(30, 30), Vector2(60, 60)))
			return p
	return center()

func _ready() -> void:
	_font = Fonts.main()
	_floor.z_index = -20
	_floor.draw_fn = _draw_floor
	add_child(_floor)
	particles = ParticleField.new()
	particles.name = "Particles"
	particles.bounds = inner
	add_child(particles)
	content.name = "Content"
	add_child(content)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = mat
	_fx.z_index = -6
	_fx.draw_fn = _draw_fx
	add_child(_fx)
	_floor.queue_redraw()
	if cleared:
		_door_anim = 1.0

# ---- geometry --------------------------------------------------------------------------------
func door_center(side: int) -> Vector2:
	var c := inner.get_center()
	match side:
		L: return Vector2(inner.position.x, c.y)
		R: return Vector2(inner.end.x, c.y)
		U: return Vector2(c.x, inner.position.y)
		_: return Vector2(c.x, inner.end.y)

## The shutter that closes a doorway (sits just inside the wall line).
func door_rect(side: int) -> Rect2:
	var c := door_center(side)
	match side:
		L: return Rect2(c.x - 14, c.y - DOOR_W * 0.5, 14, DOOR_W)
		R: return Rect2(c.x, c.y - DOOR_W * 0.5, 14, DOOR_W)
		U: return Rect2(c.x - DOOR_W * 0.5, c.y - 14, DOOR_W, 14)
		_: return Rect2(c.x - DOOR_W * 0.5, c.y, DOOR_W, 14)

func _build_solids() -> void:
	_solids = []
	var o := inner.grow(WALL)
	var sides := {
		U: [Rect2(o.position.x, o.position.y, o.size.x, WALL), true],
		D: [Rect2(o.position.x, inner.end.y, o.size.x, WALL), true],
		L: [Rect2(o.position.x, inner.position.y, WALL, inner.size.y), false],
		R: [Rect2(inner.end.x, inner.position.y, WALL, inner.size.y), false],
	}
	for side in sides:
		var rc: Rect2 = sides[side][0]
		var horiz: bool = sides[side][1]
		if not exits.has(side):
			_solids.append(rc)
			continue
		var c := door_center(side)
		if horiz:
			_solids.append(Rect2(rc.position.x, rc.position.y, c.x - DOOR_W * 0.5 - rc.position.x, rc.size.y))
			_solids.append(Rect2(c.x + DOOR_W * 0.5, rc.position.y, rc.end.x - (c.x + DOOR_W * 0.5), rc.size.y))
		else:
			_solids.append(Rect2(rc.position.x, rc.position.y, rc.size.x, c.y - DOOR_W * 0.5 - rc.position.y))
			_solids.append(Rect2(rc.position.x, c.y + DOOR_W * 0.5, rc.size.x, rc.end.y - (c.y + DOOR_W * 0.5)))

func set_doors_closed(v: bool) -> void:
	doors_closed = v
	_rebuild_cache()

func _rebuild_cache() -> void:
	_cache = []
	_cache.append_array(_solids)
	_cache.append_array(blocks)
	for c in cracks:
		_cache.append(c["rect"])
	if doors_closed:
		for side in exits:
			_cache.append(door_rect(side))

func is_sealed(side: int) -> bool:
	for c in cracks:
		if c["side"] == side:
			return true
	return false

func resolve_circle(p: Vector2, r: float) -> Dictionary:
	var n := Vector2.ZERO
	var bump := false
	for rc in _cache:
		var cx := clampf(p.x, rc.position.x, rc.end.x)
		var cy := clampf(p.y, rc.position.y, rc.end.y)
		var d := p - Vector2(cx, cy)
		var dl := d.length()
		if dl < r:
			var nn := Vector2.ZERO
			if dl > 0.001:
				nn = d / dl
				p += nn * (r - dl)
			else:
				var l := p.x - rc.position.x
				var rr := rc.end.x - p.x
				var t := p.y - rc.position.y
				var b := rc.end.y - p.y
				var m := minf(minf(l, rr), minf(t, b))
				if m == l:
					nn = Vector2.LEFT
				elif m == rr:
					nn = Vector2.RIGHT
				elif m == t:
					nn = Vector2.UP
				else:
					nn = Vector2.DOWN
				p += nn * (m + r)
			n += nn
	for i in bumpers.size():
		var bp: Vector2 = bumpers[i][0]
		var br: float = bumpers[i][1]
		var d2 := p - bp
		if d2.length() < r + br:
			var nn2 := d2.normalized() if d2.length() > 0.001 else Vector2.RIGHT
			p = bp + nn2 * (r + br)
			n += nn2
			bump = true
			bumper_punch[i] = 1.0
	return {"pos": p, "normal": n.normalized() if n.length() > 0.001 else Vector2.ZERO, "bumper": bump}

var last_crack := -1

func hit_test(p: Vector2, r: float, through_cover: bool) -> Vector2:
	var n := Vector2.ZERO
	last_crack = -1
	for rc in _solids:
		n += _rect_normal(rc, p, r)
	for i in cracks.size():
		var cn := _rect_normal(cracks[i]["rect"], p, r)
		if cn != Vector2.ZERO:
			last_crack = i
			n += cn
	if not through_cover:
		for rc in blocks:
			n += _rect_normal(rc, p, r)
		for i in bumpers.size():
			var bp: Vector2 = bumpers[i][0]
			var d: Vector2 = p - bp
			if d.length() < r + float(bumpers[i][1]):
				bumper_punch[i] = 1.0
				n += d.normalized()
	if doors_closed:
		for side in exits:
			n += _rect_normal(door_rect(side), p, r)
	return n.normalized() if n.length() > 0.001 else Vector2.ZERO

func crack_hit(dmg: float) -> void:
	if last_crack < 0 or last_crack >= cracks.size():
		return
	var c: Dictionary = cracks[last_crack]
	c["hp"] -= dmg
	var rc: Rect2 = c["rect"]
	particles.burst(rc.get_center(), Pal.AMBER, 4, 70.0)
	if c["hp"] <= 0.0:
		_break_crack(last_crack)
	last_crack = -1

func crack_blast(pos: Vector2, radius: float, dmg: float) -> void:
	for i in range(cracks.size() - 1, -1, -1):
		var rc: Rect2 = cracks[i]["rect"]
		if rc.get_center().distance_to(pos) < radius + 20.0:
			cracks[i]["hp"] -= dmg
			if cracks[i]["hp"] <= 0.0:
				_break_crack(i)

func _break_crack(i: int) -> void:
	var rc: Rect2 = cracks[i]["rect"]
	particles.debris(rc.get_center(), Pal.RUST, 18, 200.0)
	Juice.big_effect(rc.get_center(), Pal.AMBER, 0.5)
	Game.toast.emit("A HIDDEN PASSAGE OPENS", Pal.AMBER)
	cracks.remove_at(i)
	_rebuild_cache()

func _rect_normal(rc: Rect2, p: Vector2, r: float) -> Vector2:
	var cx := clampf(p.x, rc.position.x, rc.end.x)
	var cy := clampf(p.y, rc.position.y, rc.end.y)
	var d := p - Vector2(cx, cy)
	var dl := d.length()
	if dl >= r:
		return Vector2.ZERO
	if dl > 0.001:
		return d / dl
	var m := minf(minf(p.x - rc.position.x, rc.end.x - p.x), minf(p.y - rc.position.y, rc.end.y - p.y))
	if m == p.x - rc.position.x:
		return Vector2.LEFT
	if m == rc.end.x - p.x:
		return Vector2.RIGHT
	if m == p.y - rc.position.y:
		return Vector2.UP
	return Vector2.DOWN

func field_accel(p: Vector2) -> Vector2:
	var a := Vector2.ZERO
	for m in magnets:
		var d: Vector2 = m[0] - p
		var l := d.length()
		if l < m[1] and l > 4.0:
			a += d / l * float(m[2]) * 170.0 * (1.0 - l / float(m[1]))
	return a

func random_point(margin: float = 30.0) -> Vector2:
	var r := inner.grow(-margin)
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))

func spawn_point_away(from: Vector2, min_dist: float) -> Vector2:
	var best := random_point()
	for i in 20:
		var c := random_point(40.0)
		if c.distance_to(from) >= min_dist and resolve_circle(c, 9.0)["normal"] == Vector2.ZERO:
			return c
		if c.distance_to(from) > best.distance_to(from):
			best = c
	return best

func entry_pos(side: int) -> Vector2:
	var c := door_center(side)
	match side:
		L: return c + Vector2(30, 0)
		R: return c + Vector2(-30, 0)
		U: return c + Vector2(0, 30)
		_: return c + Vector2(0, -30)

func spike_phase(i: int) -> float:
	return fposmod(_t + float(spikes[i][1]), 3.0)

func spike_active(i: int) -> bool:
	var ph := spike_phase(i)
	return ph >= 2.0 and ph < 2.6

func spike_warn(i: int) -> bool:
	var ph := spike_phase(i)
	return ph >= 1.4 and ph < 2.0

func alive_enemies() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			n += 1
	return n

# ---- update ----------------------------------------------------------------------------------
func _process(dt: float) -> void:
	_t += dt
	for i in bumper_punch.size():
		bumper_punch[i] = maxf(0.0, bumper_punch[i] - dt * 3.5)
	var target := 1.0 if (not doors_closed) else 0.0
	_door_anim = move_toward(_door_anim, target, dt * 2.5)
	_steam_t -= dt
	if _steam_t <= 0.0 and visible:
		_steam_t = randf_range(0.5, 1.4)
		var p := Vector2(randf_range(inner.position.x, inner.end.x), inner.position.y + 4.0)
		if randf() < 0.5:
			p = Vector2(randf_range(inner.position.x, inner.end.x), inner.end.y - 4.0)
		particles.burst(p, Color(0.5, 0.5, 0.55), 3, 12.0, Vector2.DOWN if p.y < center().y else Vector2.UP, 0.8, 1.4, 4.0, ParticleField.SMOKE)
	var pl = Game.world.player if Game.world else null
	if pl != null and not pl.dead and visible:
		for i in spikes.size():
			if spike_active(i):
				var rc: Rect2 = spikes[i][0]
				var cx := clampf(pl.position.x, rc.position.x, rc.end.x)
				var cy := clampf(pl.position.y, rc.position.y, rc.end.y)
				if Vector2(cx, cy).distance_to(pl.position) < pl.radius:
					pl.take_damage(1, rc.get_center())
		var a := field_accel(pl.position)
		if a != Vector2.ZERO:
			pl.apply_impulse(a * dt)
	for e in emitters:
		e[1] += dt
		if e[1] >= 4.0 and visible:
			e[1] = 0.0
			Game.world.spawn_effect("bomb", e[0], {"radius": 120.0, "delay": 0.9, "dur": 0.9})
	_fx.queue_redraw()
	queue_redraw()

# ---- drawing ---------------------------------------------------------------------------------
func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263 + index * 977) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float(h % 1000) / 1000.0

func _draw_floor(c: Node2D) -> void:
	var o := inner.grow(WALL + 220.0)
	c.draw_rect(o, Pal.BG)
	var base := floor_color
	if kind == "boss":
		base = base.lerp(Color("3a1410"), 0.5)
	elif safe:
		base = Color("2a1d14")
	var tw := int(inner.size.x / 16.0) + 1
	var th := int(inner.size.y / 16.0) + 1
	for tx in tw:
		for ty in th:
			var h := _hash(tx, ty)
			var col := base.lerp(Pal.STEEL_DARK, h * 0.55)
			var p := inner.position + Vector2(tx, ty) * 16.0
			var sz := Vector2(minf(16.0, inner.end.x - p.x), minf(16.0, inner.end.y - p.y))
			c.draw_rect(Rect2(p, sz), col)
			c.draw_rect(Rect2(p, Vector2(sz.x, 1)), Color(0, 0, 0, 0.35))
			c.draw_rect(Rect2(p, Vector2(1, sz.y)), Color(0, 0, 0, 0.35))
			if h > 0.94:
				c.draw_rect(Rect2(p + Vector2(3, 5), Vector2(7, 1)), Color(0, 0, 0, 0.5))
				c.draw_rect(Rect2(p + Vector2(6, 6), Vector2(1, 5)), Color(0, 0, 0, 0.5))
			elif h < 0.04:
				c.draw_rect(Rect2(p + Vector2(4, 4), Vector2(2, 2)), Pal.RUST)
	# large floor markings
	var ctr := center()
	var mark := Color(trim_color.r, trim_color.g, trim_color.b, 0.07)
	c.draw_arc(ctr, minf(inner.size.x, inner.size.y) * 0.28, 0.0, TAU, 64, mark, 3.0)
	c.draw_arc(ctr, minf(inner.size.x, inner.size.y) * 0.18, 0.0, TAU, 48, mark, 1.0)
	# walls
	for rc in _solids:
		c.draw_rect(rc, Pal.STEEL_DARK)
		var x := rc.position.x + 6.0
		while x < rc.end.x - 3.0:
			var y := rc.position.y + 6.0
			while y < rc.end.y - 3.0:
				if _hash(int(x), int(y)) > 0.35:
					c.draw_rect(Rect2(x, y, 2, 2), Pal.STEEL)
				y += 20.0
			x += 20.0
	c.draw_rect(Rect2(inner.position.x - 4, inner.position.y - 4, inner.size.x + 8, 4), Pal.RUST.darkened(0.3))
	c.draw_rect(Rect2(inner.position.x - 4, inner.end.y, inner.size.x + 8, 4), Pal.RUST.darkened(0.3))
	c.draw_rect(Rect2(inner.position.x - 4, inner.position.y, 4, inner.size.y), Pal.RUST.darkened(0.3))
	c.draw_rect(Rect2(inner.end.x, inner.position.y, 4, inner.size.y), Pal.RUST.darkened(0.3))
	# door tunnels
	for side in exits:
		var dc := door_center(side)
		var horiz: bool = (side == U or side == D)
		var dir := Vector2.ZERO
		match side:
			L: dir = Vector2.LEFT
			R: dir = Vector2.RIGHT
			U: dir = Vector2.UP
			_: dir = Vector2.DOWN
		var tr := Rect2(dc - Vector2(WALL, DOOR_W * 0.5) if not horiz else dc - Vector2(DOOR_W * 0.5, WALL), Vector2(WALL, DOOR_W) if not horiz else Vector2(DOOR_W, WALL))
		match side:
			R: tr = Rect2(dc.x, dc.y - DOOR_W * 0.5, WALL, DOOR_W)
			D: tr = Rect2(dc.x - DOOR_W * 0.5, dc.y, DOOR_W, WALL)
		c.draw_rect(tr, Color(0.03, 0.02, 0.04))
		for k in 4:
			var o2 := dc + dir * (4.0 + k * 11.0)
			var perp := dir.orthogonal()
			for sgn in [-1.0, 1.0]:
				var q: Vector2 = o2 + perp * sgn * (DOOR_W * 0.5 - 6.0)
				c.draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), Color(0.9, 0.7, 0.1, 0.5))
	# blocks: crates
	for b in blocks:
		c.draw_rect(b, Pal.RUST.darkened(0.2))
		c.draw_rect(b.grow(-2), Pal.RUST)
		c.draw_rect(Rect2(b.position, Vector2(b.size.x, 2)), Pal.STEEL)
		c.draw_rect(Rect2(b.position + Vector2(0, b.size.y - 2), Vector2(b.size.x, 2)), Color(0, 0, 0, 0.5))
		c.draw_line(b.position + Vector2(3, 3), b.end - Vector2(3, 3), Pal.RUST_DARK, 1.0)
		c.draw_line(Vector2(b.end.x - 3, b.position.y + 3), Vector2(b.position.x + 3, b.end.y - 3), Pal.RUST_DARK, 1.0)
	for s in spikes:
		var rc2: Rect2 = s[0]
		c.draw_rect(rc2, Color(0.04, 0.03, 0.04))
		c.draw_rect(rc2, Color(0.5, 0.5, 0.55, 0.5), false, 1.0)

func _draw_fx(c: Node2D) -> void:
	var pulse := 0.5 + 0.5 * sin(Juice.phase)
	var slow := 0.5 + 0.5 * sin(_t * (1.2 if safe else 2.6))
	if safe:
		pulse = slow
	elif kind == "cursed":
		pulse = 0.5 + 0.5 * sin(_t * 3.0 + sin(_t * 7.3) * 2.0)      # irregular, unstable
	elif kind == "boss":
		pulse = 0.5 + 0.5 * sin(_t * 5.0)
	var col := trim_color
	col.a = 0.35 + 0.45 * pulse
	c.draw_rect(inner.grow(1.0), col, false, 1.0)
	var glow := trim_color
	glow.a = 0.07 + 0.08 * pulse
	c.draw_rect(inner.grow(4.0), glow, false, 3.0)
	if kind == "workshop":
		Juice.glow(c, bench_pos, 60.0 + 6.0 * pulse, Color(1.0, 0.65, 0.2, 0.55))
	for i in spikes.size():
		var rc: Rect2 = spikes[i][0]
		if spike_warn(i):
			c.draw_rect(rc, Color(1, 0.2, 0.1, 0.25 + 0.25 * sin(_t * 40.0)))
		elif spike_active(i):
			c.draw_rect(rc, Color(1, 0.3, 0.2, 0.6))
	for m in magnets:
		var mc := Pal.VIOLET if float(m[2]) > 0.0 else Pal.CYAN
		for k in 3:
			var ph := fposmod(_t * 0.7 * float(m[2]) + k / 3.0, 1.0)
			var rr: float = m[1] * (ph if float(m[2]) < 0.0 else 1.0 - ph)
			c.draw_arc(m[0], rr, 0.0, TAU, 32, Color(mc.r, mc.g, mc.b, 0.4 * (1.0 - ph)), 1.0)
		Juice.glow(c, m[0], 22.0, Color(mc.r, mc.g, mc.b, 0.4))
	for e in emitters:
		var k: float = e[1] / 4.0
		Juice.glow(c, e[0], 14.0 + 10.0 * k, Color(1.0, 0.3, 0.6, 0.3 + 0.5 * k))

func _draw() -> void:
	for side in exits:
		var rc := door_rect(side)
		if is_sealed(side):
			continue
		if _door_anim < 0.99:
			var horiz: bool = (side == U or side == D)
			var f := (1.0 - _door_anim)
			var r2 := rc
			if horiz:
				r2 = Rect2(rc.position + Vector2((rc.size.x - rc.size.x * f) * 0.5, 0), Vector2(rc.size.x * f, rc.size.y))
			else:
				r2 = Rect2(rc.position + Vector2(0, (rc.size.y - rc.size.y * f) * 0.5), Vector2(rc.size.x, rc.size.y * f))
			draw_rect(r2, Color(0.55, 0.08, 0.05))
			draw_rect(r2.grow(-2), Color(1, 0.35, 0.2, 0.5 + 0.4 * sin(_t * 30.0)), false, 1.0)
		elif cleared or safe:
			var dc := door_center(side)
			var blink := 0.5 + 0.5 * sin(_t * 5.0)
			var d2 := Vector2.ZERO
			match side:
				L: d2 = Vector2.LEFT
				R: d2 = Vector2.RIGHT
				U: d2 = Vector2.UP
				_: d2 = Vector2.DOWN
			var base := dc - d2 * 12.0
			var perp := d2.orthogonal()
			draw_colored_polygon(PackedVector2Array([base + d2 * 8.0, base - d2 * 4.0 + perp * 8.0, base - d2 * 4.0 - perp * 8.0]), Color(Pal.LIME.r, Pal.LIME.g, Pal.LIME.b, 0.3 + 0.6 * blink))
	for c in cracks:
		var rc2: Rect2 = c["rect"]
		draw_rect(rc2, Pal.RUST.darkened(0.3))
		var f2: float = c["hp"] / 26.0
		for k in 4:
			draw_line(rc2.get_center() + Vector2(randf_range(-1, 1), randf_range(-1, 1)), rc2.get_center() + Vector2.from_angle(k * 1.6 + 0.4) * 14.0, Color(1, 0.7, 0.2, 0.5 + 0.4 * (1.0 - f2)), 1.0)
	for i in bumpers.size():
		var bp: Vector2 = bumpers[i][0]
		var br: float = bumpers[i][1]
		var k := 1.0 + bumper_punch[i] * 0.45
		var pr := br * k
		draw_circle(bp, pr + 2.0, Pal.STEEL_DARK)
		draw_circle(bp, pr, Pal.AMBER.darkened(0.2 + 0.5 * (1.0 - bumper_punch[i])))
		draw_circle(bp, pr * 0.5, Color(1, 0.95, 0.7, 0.4 + 0.6 * bumper_punch[i]))
	for i in spikes.size():
		if spike_active(i) or spike_warn(i):
			var rc3: Rect2 = spikes[i][0]
			var h2 := 7.0 if spike_active(i) else 2.0
			for sx in 4:
				for sy in 4:
					var o := rc3.position + Vector2(4.0 + sx * 8.0, 4.0 + sy * 8.0)
					draw_colored_polygon(PackedVector2Array([o + Vector2(-3, 3), o + Vector2(3, 3), o + Vector2(0, 3.0 - h2)]), Color(0.8, 0.82, 0.9))
	if kind == "workshop":
		var b := Rect2(bench_pos - Vector2(22, 16), Vector2(44, 32))
		draw_rect(b, Pal.STEEL)
		draw_rect(b.grow(-3), Pal.STEEL_DARK)
		draw_rect(Rect2(b.position + Vector2(6, 4), Vector2(32, 8)), Pal.AMBER.darkened(0.3 - 0.2 * sin(_t * 3.0)))
		draw_rect(Rect2(b.position + Vector2(8, 18), Vector2(10, 6)), Pal.CYAN.darkened(0.3))
		draw_rect(Rect2(b.position + Vector2(24, 18), Vector2(10, 6)), Pal.LIME.darkened(0.3))
		if _font:
			draw_string(_font, bench_pos + Vector2(-70, 36), "[E] BENCH", HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Pal.AMBER)

func row_is_side() -> bool:
	return int(spec.get("row", 0)) != 0
