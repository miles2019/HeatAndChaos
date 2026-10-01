class_name ParticleField
extends Node2D
## One node draws every pixel particle of a room (no per-particle nodes -> effectively pooled).
## Debris slides, bounces and finally settles into a persistent floor layer that stays all run.

const MAX := 1100
const MAX_SETTLED := 800
const SPARK := 0
const DEBRIS := 1
const SMOKE := 2
const EMBER := 3

var p_pos := PackedVector2Array()
var p_vel := PackedVector2Array()
var p_col := PackedColorArray()
var p_life := PackedFloat32Array()
var p_max := PackedFloat32Array()
var p_size := PackedFloat32Array()
var p_kind := PackedInt32Array()
var count := 0

var rings: Array = []
var texts: Array = []
var settled_pos := PackedVector2Array()
var settled_col := PackedColorArray()
var settled_size := PackedFloat32Array()
var settle_ptr := 0
var stains: Array = []
var floor_layer := ArtNode.new()
var _floor_dirty := true
var _font: Font

func _init() -> void:
	z_index = 10
	for a in [p_pos, p_vel]:
		a.resize(MAX)
	p_col.resize(MAX)
	for a in [p_life, p_max, p_size]:
		a.resize(MAX)
	p_kind.resize(MAX)
	floor_layer.z_as_relative = false
	floor_layer.z_index = -14
	floor_layer.draw_fn = _draw_floor
	add_child(floor_layer)

func _ready() -> void:
	_font = ThemeDB.fallback_font

# ---- spawning --------------------------------------------------------------------------------
func _add(p: Vector2, v: Vector2, c: Color, life: float, size: float, kind: int) -> void:
	if count >= MAX:
		return
	p_pos[count] = p
	p_vel[count] = v
	p_col[count] = c
	p_life[count] = life
	p_max[count] = life
	p_size[count] = size
	p_kind[count] = kind
	count += 1

func burst(p: Vector2, col: Color, n: int, speed: float, dir: Vector2 = Vector2.ZERO, spread: float = TAU, life: float = 0.4, size: float = 2.0, kind: int = 0) -> void:
	var base := dir.angle() if dir.length() > 0.01 else 0.0
	var arc := spread if dir.length() > 0.01 else TAU
	for i in n:
		var a := base + randf_range(-arc * 0.5, arc * 0.5)
		var v := Vector2.from_angle(a) * speed * randf_range(0.3, 1.0)
		var c := col.lerp(Color.WHITE, randf() * 0.35)
		_add(p, v, c, life * randf_range(0.6, 1.2), size * randf_range(0.7, 1.3), kind)

func debris(p: Vector2, col: Color, n: int, power: float, dir: Vector2 = Vector2.ZERO) -> void:
	for i in n:
		var a := randf() * TAU
		if dir.length() > 0.01:
			a = dir.angle() + randf_range(-0.9, 0.9)
		var v := Vector2.from_angle(a) * power * randf_range(0.25, 1.0)
		var shade := randf_range(0.55, 1.1)
		var c := Color(col.r * shade, col.g * shade, col.b * shade, 1.0)
		if randf() < 0.2:
			c = Pal.RUST.lerp(Pal.STEEL, randf())
		_add(p, v, c, 4.0, float(1 + randi() % 3), DEBRIS)

func text(p: Vector2, s: String, col: Color, size: int = 8, big: bool = false) -> void:
	if texts.size() > 40:
		texts.pop_front()
	texts.append({"pos": p, "s": s, "col": col, "size": size, "big": big, "t": 0.0})

func ring(p: Vector2, col: Color, radius: float, dur: float = 0.35) -> void:
	if rings.size() > 24:
		rings.pop_front()
	rings.append({"pos": p, "col": col, "r": radius, "t": 0.0, "dur": dur})

func stain(p: Vector2, col: Color, r: float) -> void:
	stains.append({"pos": p, "col": Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 0.45), "r": r})
	if stains.size() > 90:
		stains.pop_front()
	_floor_dirty = true

func clear_all() -> void:
	count = 0
	rings.clear()
	texts.clear()

# ---- update ----------------------------------------------------------------------------------
func _process(dt: float) -> void:
	var inner := Room.INNER.grow(-2.0)
	var i := 0
	while i < count:
		var kind := p_kind[i]
		p_life[i] -= dt
		var v := p_vel[i]
		var pp := p_pos[i]
		match kind:
			DEBRIS:
				v *= exp(-dt * 3.2)
				pp += v * dt
				if pp.x < inner.position.x:
					pp.x = inner.position.x
					v.x = absf(v.x) * 0.55
				elif pp.x > inner.end.x:
					pp.x = inner.end.x
					v.x = -absf(v.x) * 0.55
				if pp.y < inner.position.y:
					pp.y = inner.position.y
					v.y = absf(v.y) * 0.55
				elif pp.y > inner.end.y:
					pp.y = inner.end.y
					v.y = -absf(v.y) * 0.55
			SMOKE:
				v *= exp(-dt * 1.5)
				v.y -= 14.0 * dt
				pp += v * dt
			EMBER:
				v *= exp(-dt * 1.2)
				v.y -= 22.0 * dt
				pp += v * dt
			_:
				v *= exp(-dt * 3.0)
				pp += v * dt
		p_vel[i] = v
		p_pos[i] = pp
		var dead := p_life[i] <= 0.0
		if kind == DEBRIS and (v.length() < 7.0 or dead):
			_settle(pp, p_col[i], p_size[i])
			dead = true
		if dead:
			count -= 1
			p_pos[i] = p_pos[count]
			p_vel[i] = p_vel[count]
			p_col[i] = p_col[count]
			p_life[i] = p_life[count]
			p_max[i] = p_max[count]
			p_size[i] = p_size[count]
			p_kind[i] = p_kind[count]
		else:
			i += 1
	for r in rings:
		r["t"] += dt
	rings = rings.filter(func(r: Dictionary) -> bool: return r["t"] < r["dur"])
	for t in texts:
		t["t"] += dt
		t["pos"] += Vector2(0, -22.0 * dt)
	texts = texts.filter(func(t: Dictionary) -> bool: return t["t"] < (0.9 if t["big"] else 0.65))
	queue_redraw()
	if _floor_dirty:
		_floor_dirty = false
		floor_layer.queue_redraw()

func _settle(p: Vector2, c: Color, s: float) -> void:
	if settled_pos.size() < MAX_SETTLED:
		settled_pos.append(p)
		settled_col.append(c.darkened(0.25))
		settled_size.append(s)
	else:
		settled_pos[settle_ptr] = p
		settled_col[settle_ptr] = c.darkened(0.25)
		settled_size[settle_ptr] = s
		settle_ptr = (settle_ptr + 1) % MAX_SETTLED
	_floor_dirty = true

# ---- drawing ---------------------------------------------------------------------------------
func _draw_floor(canvas: Node2D) -> void:
	for s in stains:
		var p: Vector2 = s["pos"]
		var r: float = s["r"]
		canvas.draw_circle(p, r, s["col"])
		canvas.draw_circle(p + Vector2(r * 0.4, -r * 0.3), r * 0.55, s["col"])
	for i in settled_pos.size():
		var sz := settled_size[i]
		canvas.draw_rect(Rect2(settled_pos[i].floor(), Vector2(sz, sz)), settled_col[i])

func _draw() -> void:
	for i in count:
		var t := p_life[i] / p_max[i]
		var c := p_col[i]
		var s := p_size[i]
		match p_kind[i]:
			SMOKE:
				c.a *= t * 0.5
				s *= (2.2 - t)
			SPARK, EMBER:
				c.a *= clampf(t * 1.6, 0.0, 1.0)
		draw_rect(Rect2((p_pos[i] - Vector2(s, s) * 0.5).floor(), Vector2(s, s)), c)
	for r in rings:
		var t: float = r["t"] / r["dur"]
		var c: Color = r["col"]
		c.a = (1.0 - t)
		draw_arc(r["pos"], r["r"] * (1.0 - pow(1.0 - t, 3.0)), 0.0, TAU, 28, c, 1.0)
	if _font:
		for t in texts:
			var life: float = 0.9 if t["big"] else 0.65
			var a: float = 1.0 - pow(t["t"] / life, 3.0)
			var c: Color = t["col"]
			c.a = a
			var p: Vector2 = t["pos"] - Vector2(30, 0)
			if t["big"]:
				p += Vector2(randf_range(-1, 1), randf_range(-1, 1))
			var sz: int = t["size"]
			draw_string(_font, p + Vector2(1, 1), t["s"], HORIZONTAL_ALIGNMENT_CENTER, 60, sz, Color(0, 0, 0, a))
			draw_string(_font, p, t["s"], HORIZONTAL_ALIGNMENT_CENTER, 60, sz, c)
