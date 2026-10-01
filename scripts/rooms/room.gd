class_name Room
extends Node2D
## One arena. Owns geometry/collision, hazards and its persistent particle field (debris stays all run).

const INNER := Rect2(48, 52, 544, 256)
const DOOR_H := 44.0
const CY := 180.0

var kind := "combat"
var index := 0
var title := ""
var subtitle := ""
var cleared := false
var doors_closed := false
var has_left := true
var has_right := true
var trim_color := Pal.CYAN
var safe := false
var waves: Array = []
var bench_pos := Vector2.ZERO

var blocks: Array[Rect2] = []
var bumpers: Array = []            # [Vector2, radius]
var bumper_punch: Array[float] = []
var spikes: Array = []             # [Rect2, phase_offset]
var enemies: Array = []
var particles: ParticleField
var content := Node2D.new()
var pending_acid: Array = []       # static hazard pools to create on enter

var _solids: Array[Rect2] = []
var _cache: Array[Rect2] = []
var _floor := ArtNode.new()
var _fx := ArtNode.new()
var _t := 0.0
var _steam_t := 0.0
var _door_anim := 0.0              # 0 closed .. 1 open
var _font: Font

func setup(k: String, idx: int) -> void:
	kind = k
	index = idx
	match k:
		"start":
			title = "ENTRY SHAFT"
			safe = true
			trim_color = Pal.AMBER
			has_left = false
			blocks = [Rect2(150, 100, 24, 24), Rect2(466, 236, 24, 24), Rect2(150, 236, 24, 24)]
		"combat1":
			title = "PRESSURE LOCK"
			blocks = [Rect2(176, 92, 32, 32), Rect2(432, 92, 32, 32), Rect2(176, 228, 32, 32), Rect2(432, 228, 32, 32)]
			bumpers = [[Vector2(320, 180), 10.0]]
			waves = [["stalker", "stalker", "stalker"], ["stalker", "stalker", "bulwark", "stalker"]]
		"workshop":
			title = "MODULE WORKSHOP"
			safe = true
			trim_color = Pal.AMBER
			blocks = [Rect2(298, 164, 44, 32)]
			bench_pos = Vector2(320, 180)
		"combat2":
			title = "SLIME CONDUIT"
			blocks = [Rect2(296, 92, 48, 16), Rect2(296, 244, 48, 16)]
			bumpers = [[Vector2(220, 130), 10.0], [Vector2(420, 230), 10.0]]
			spikes = [[Rect2(124, 90, 32, 32), 0.0], [Rect2(484, 232, 32, 32), 1.4]]
			pending_acid = [[Vector2(320, 180), 20.0]]
			waves = [["mortar", "mortar", "stalker", "stalker"], ["bulwark", "bulwark", "mortar", "stalker", "stalker", "stalker"],
				["bulwark", "mortar", "mortar", "stalker", "stalker", "stalker", "stalker"]]
		"boss":
			title = "VULCAN CORE"
			trim_color = Pal.RED
			has_right = false
			blocks = []
			waves = [["boss"]]
	subtitle = k.to_upper()
	bumper_punch.resize(bumpers.size())
	bumper_punch.fill(0.0)
	_build_solids()
	_rebuild_cache()

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_floor.z_index = -20
	_floor.draw_fn = _draw_floor
	add_child(_floor)
	particles = ParticleField.new()
	particles.name = "Particles"
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
func _build_solids() -> void:
	var gt := CY - DOOR_H * 0.5
	var gb := CY + DOOR_H * 0.5
	_solids = [Rect2(0, 0, 640, INNER.position.y), Rect2(0, INNER.end.y, 640, 360.0 - INNER.end.y)]
	for side in 2:
		var x := 0.0 if side == 0 else INNER.end.x
		var w := INNER.position.x if side == 0 else 640.0 - INNER.end.x
		var present := has_left if side == 0 else has_right
		if present:
			_solids.append(Rect2(x, INNER.position.y, w, gt - INNER.position.y))
			_solids.append(Rect2(x, gb, w, INNER.end.y - gb))
		else:
			_solids.append(Rect2(x, INNER.position.y, w, INNER.size.y))

func door_rect(side: int) -> Rect2:
	var x := INNER.position.x - 16.0 if side == 0 else INNER.end.x
	return Rect2(x, CY - DOOR_H * 0.5, 16.0, DOOR_H)

func set_doors_closed(v: bool) -> void:
	doors_closed = v
	_rebuild_cache()

func _rebuild_cache() -> void:
	_cache = []
	_cache.append_array(_solids)
	_cache.append_array(blocks)
	if doors_closed:
		if has_left:
			_cache.append(door_rect(0))
		if has_right:
			_cache.append(door_rect(1))

## Pushes a circle out of walls/blocks/bumpers. Returns {pos, normal, bumper}.
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

## Projectile test: returns surface normal (ZERO = no hit). `through_cover` ignores crates/blocks.
func hit_test(p: Vector2, r: float, through_cover: bool) -> Vector2:
	var n := Vector2.ZERO
	for rc in _solids:
		n += _rect_normal(rc, p, r)
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
		if has_left:
			n += _rect_normal(door_rect(0), p, r)
		if has_right:
			n += _rect_normal(door_rect(1), p, r)
	return n.normalized() if n.length() > 0.001 else Vector2.ZERO

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

func random_point(margin: float = 26.0) -> Vector2:
	var r := INNER.grow(-margin)
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))

func spawn_point_away(from: Vector2, min_dist: float) -> Vector2:
	var best := random_point()
	for i in 14:
		var c := random_point()
		if c.distance_to(from) >= min_dist and resolve_circle(c, 8.0)["normal"] == Vector2.ZERO:
			return c
		if c.distance_to(from) > best.distance_to(from):
			best = c
	return best

func spike_active(i: int) -> bool:
	return fposmod(_t + float(spikes[i][1]), 3.0) >= 2.0 and fposmod(_t + float(spikes[i][1]), 3.0) < 2.6

func spike_warn(i: int) -> bool:
	var ph := fposmod(_t + float(spikes[i][1]), 3.0)
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
		_steam_t = randf_range(0.8, 2.0)
		var side := randi() % 4
		var p := Vector2(randf_range(60, 580), 60.0) if side == 0 else Vector2(randf_range(60, 580), 300.0)
		if side >= 2:
			p = Vector2(52.0, randf_range(70, 290)) if side == 2 else Vector2(588.0, randf_range(70, 290))
		particles.burst(p, Color(0.5, 0.5, 0.55), 3, 12.0, Vector2.UP if side < 2 else Vector2.DOWN, 0.8, 1.4, 4.0, ParticleField.SMOKE)
	var pl = Game.world.player if Game.world else null
	if pl != null and not pl.dead and visible:
		for i in spikes.size():
			if spike_active(i):
				var rc: Rect2 = spikes[i][0]
				var cx := clampf(pl.position.x, rc.position.x, rc.end.x)
				var cy := clampf(pl.position.y, rc.position.y, rc.end.y)
				if Vector2(cx, cy).distance_to(pl.position) < pl.radius:
					pl.take_damage(1, rc.get_center())
	_fx.queue_redraw()
	queue_redraw()

# ---- drawing ---------------------------------------------------------------------------------
func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float(h % 1000) / 1000.0

func _draw_floor(c: Node2D) -> void:
	c.draw_rect(Rect2(0, 0, 640, 360), Pal.BG)
	var base := Pal.RUST_DARK
	if kind == "boss":
		base = Color("2b1210")
	elif safe:
		base = Color("2a1d14")
	for tx in 34:
		for ty in 16:
			var h := _hash(tx + index * 7, ty)
			var col := base.lerp(Pal.STEEL_DARK, h * 0.55)
			var p := INNER.position + Vector2(tx, ty) * 16.0
			c.draw_rect(Rect2(p, Vector2(16, 16)), col)
			c.draw_rect(Rect2(p, Vector2(16, 1)), Color(0, 0, 0, 0.35))
			c.draw_rect(Rect2(p, Vector2(1, 16)), Color(0, 0, 0, 0.35))
			if h > 0.93:
				c.draw_rect(Rect2(p + Vector2(3, 5), Vector2(7, 1)), Color(0, 0, 0, 0.5))
				c.draw_rect(Rect2(p + Vector2(6, 6), Vector2(1, 5)), Color(0, 0, 0, 0.5))
			elif h < 0.05:
				c.draw_rect(Rect2(p + Vector2(4, 4), Vector2(2, 2)), Pal.RUST)
	# walls with rivets and cable runs
	for rc in _solids:
		c.draw_rect(rc, Pal.STEEL_DARK)
		var step := 20.0
		var x := rc.position.x + 6.0
		while x < rc.end.x - 3.0:
			var y := rc.position.y + 6.0
			while y < rc.end.y - 3.0:
				if _hash(int(x), int(y)) > 0.35:
					c.draw_rect(Rect2(x, y, 2, 2), Pal.STEEL)
				y += step
			x += step
	# pipes behind the HUD frames
	for i in 6:
		var y2 := 10.0 + i * 6.0
		c.draw_rect(Rect2(0, y2, 640, 2), Color(0.12, 0.13, 0.17))
	c.draw_rect(Rect2(0, INNER.position.y - 3, 640, 3), Pal.RUST.darkened(0.3))
	c.draw_rect(Rect2(0, INNER.end.y, 640, 3), Pal.RUST.darkened(0.3))
	# door tunnels
	for side in 2:
		var present := has_left if side == 0 else has_right
		if present:
			var x0 := 0.0 if side == 0 else INNER.end.x
			var w := INNER.position.x if side == 0 else 640.0 - INNER.end.x
			c.draw_rect(Rect2(x0, CY - DOOR_H * 0.5, w, DOOR_H), Color(0.03, 0.02, 0.04))
			for k in 4:
				var sx := x0 + 4.0 + k * 11.0
				c.draw_colored_polygon(PackedVector2Array([Vector2(sx, CY - 22), Vector2(sx + 6, CY - 22), Vector2(sx + 2, CY - 16), Vector2(sx - 4, CY - 16)]), Color(0.9, 0.7, 0.1, 0.5))
				c.draw_colored_polygon(PackedVector2Array([Vector2(sx, CY + 22), Vector2(sx + 6, CY + 22), Vector2(sx + 2, CY + 16), Vector2(sx - 4, CY + 16)]), Color(0.9, 0.7, 0.1, 0.5))
	# blocks: crates
	for b in blocks:
		c.draw_rect(b, Pal.RUST.darkened(0.2))
		c.draw_rect(b.grow(-2), Pal.RUST)
		c.draw_rect(Rect2(b.position, Vector2(b.size.x, 2)), Pal.STEEL)
		c.draw_rect(Rect2(b.position + Vector2(0, b.size.y - 2), Vector2(b.size.x, 2)), Color(0, 0, 0, 0.5))
		c.draw_line(b.position + Vector2(3, 3), b.end - Vector2(3, 3), Pal.RUST_DARK, 1.0)
		c.draw_line(Vector2(b.end.x - 3, b.position.y + 3), Vector2(b.position.x + 3, b.end.y - 3), Pal.RUST_DARK, 1.0)
	# spike pits
	for s in spikes:
		var rc2: Rect2 = s[0]
		c.draw_rect(rc2, Color(0.04, 0.03, 0.04))
		c.draw_rect(rc2, Color(0.5, 0.5, 0.55, 0.5), false, 1.0)

func _draw_fx(c: Node2D) -> void:
	var pulse := 0.5 + 0.5 * sin(Juice.phase)
	var slow := 0.5 + 0.5 * sin(_t * (1.2 if safe else 2.6))
	if kind == "start" or kind == "workshop":
		pulse = slow
	elif kind == "boss":
		pulse = 0.5 + 0.5 * sin(_t * 5.0)
	var col := trim_color
	col.a = 0.35 + 0.45 * pulse
	# neon trim along the playfield edge
	c.draw_rect(INNER.grow(1.0), col, false, 1.0)
	var glow := trim_color
	glow.a = 0.07 + 0.08 * pulse
	c.draw_rect(INNER.grow(4.0), glow, false, 3.0)
	# bench glow
	if kind == "workshop":
		Juice.glow(c, bench_pos, 54.0 + 6.0 * pulse, Color(1.0, 0.65, 0.2, 0.55))
	# spikes warnings
	for i in spikes.size():
		var rc: Rect2 = spikes[i][0]
		if spike_warn(i):
			c.draw_rect(rc, Color(1, 0.2, 0.1, 0.25 + 0.25 * sin(_t * 40.0)))
		elif spike_active(i):
			c.draw_rect(rc, Color(1, 0.3, 0.2, 0.6))

func _draw() -> void:
	# door shutters and arrows
	for side in 2:
		var present := has_left if side == 0 else has_right
		if not present:
			continue
		var rc := door_rect(side)
		if _door_anim < 0.99:
			var h := rc.size.y * (1.0 - _door_anim)
			var r2 := Rect2(rc.position + Vector2(0, (rc.size.y - h) * 0.5), Vector2(rc.size.x, h))
			draw_rect(r2, Color(0.55, 0.08, 0.05))
			for i in int(h / 4.0):
				draw_rect(Rect2(r2.position.x, r2.position.y + i * 4.0, r2.size.x, 1.0), Color(1, 0.35, 0.2, 0.6 + 0.4 * sin(_t * 30.0 + i)))
		elif cleared or safe:
			var dirx := -1.0 if side == 0 else 1.0
			var blink := 0.5 + 0.5 * sin(_t * 5.0)
			var cx := rc.get_center().x
			draw_colored_polygon(PackedVector2Array([Vector2(cx + dirx * 5, CY), Vector2(cx - dirx * 3, CY - 7), Vector2(cx - dirx * 3, CY + 7)]), Color(Pal.LIME.r, Pal.LIME.g, Pal.LIME.b, 0.3 + 0.6 * blink))
	# bumpers
	for i in bumpers.size():
		var bp: Vector2 = bumpers[i][0]
		var br: float = bumpers[i][1]
		var k := 1.0 + bumper_punch[i] * 0.45
		var pr := br * k
		draw_circle(bp, pr + 2.0, Pal.STEEL_DARK)
		draw_circle(bp, pr, Pal.AMBER.darkened(0.2 + 0.5 * (1.0 - bumper_punch[i])))
		draw_circle(bp, pr * 0.5, Color(1, 0.95, 0.7, 0.4 + 0.6 * bumper_punch[i]))
	# spike teeth
	for i in spikes.size():
		if spike_active(i) or spike_warn(i):
			var rc3: Rect2 = spikes[i][0]
			var h2 := 7.0 if spike_active(i) else 2.0
			for sx in 4:
				for sy in 4:
					var o := rc3.position + Vector2(4.0 + sx * 8.0, 4.0 + sy * 8.0)
					draw_colored_polygon(PackedVector2Array([o + Vector2(-3, 3), o + Vector2(3, 3), o + Vector2(0, 3.0 - h2)]), Color(0.8, 0.82, 0.9))
	# workshop bench props
	if kind == "workshop":
		var b := Rect2(298, 164, 44, 32)
		draw_rect(b, Pal.STEEL)
		draw_rect(b.grow(-3), Pal.STEEL_DARK)
		draw_rect(Rect2(304, 168, 32, 8), Pal.AMBER.darkened(0.3 - 0.2 * sin(_t * 3.0)))
		draw_rect(Rect2(306, 182, 10, 6), Pal.CYAN.darkened(0.3))
		draw_rect(Rect2(322, 182, 10, 6), Pal.LIME.darkened(0.3))
		if _font:
			draw_string(_font, Vector2(270, 206), "[E] WORKSHOP BENCH", HORIZONTAL_ALIGNMENT_CENTER, 100, 8, Pal.AMBER)
