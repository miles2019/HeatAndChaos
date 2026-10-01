extends Node
## Central game-feel hub. Every big effect follows: Anticipation -> Impact -> Rebound -> Particles -> Afterglow.

var cam_offset := Vector2.ZERO
var cam_vel := Vector2.ZERO
var cam_roll := 0.0
var cam_roll_vel := 0.0
var cam_zoom := 1.0
var cam_zoom_vel := 0.0
var jitter := 0.0

var heat := 0.0                  # 0..1, set by the player's weapon
var instability := 0.0           # 0..1
var phase := 0.0                 # integrated pulse phase (so rate changes never jump)
var chroma := 0.0
var afterglow := Color(0, 0, 0, 0)
var screen_flash := Color(1, 1, 1, 0)
var waves: Array = []            # {uv, t, dur, strength}
var field: ParticleField         # current room's particle field
var glow_tex: GradientTexture2D

var _hitstop_left := 0.0
var _last_us := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	glow_tex = GradientTexture2D.new()
	glow_tex.gradient = g
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 64
	glow_tex.height = 64
	_last_us = Time.get_ticks_usec()

# ---- pulse ------------------------------------------------------------------------------------
func pulse_rate() -> float:
	return lerpf(0.9, 5.5, pow(heat, 1.3))

## Breathing scale: ~1.05 on Y / 0.95 on X at the peak. Instability de-syncs `part` phases.
func pulse_vec(part: float = 0.0, amp_mult: float = 1.0) -> Vector2:
	var ph := phase + part + sin(phase * 0.37 + part * 12.9) * instability * 2.2
	var k := (sin(ph) * 0.5 + 0.5) * (0.6 + heat * 1.1) * amp_mult
	return Vector2(1.0 - 0.05 * k, 1.0 + 0.05 * k)

func glow(canvas: CanvasItem, pos: Vector2, radius: float, col: Color) -> void:
	canvas.draw_texture_rect(glow_tex, Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)

# ---- camera / shake ----------------------------------------------------------------------------
func shake(dir: Vector2, amount: float, roll: float = 0.0, high_freq: float = 0.0) -> void:
	var s := Settings.shake
	if dir.length() > 0.01:
		cam_vel += dir.normalized() * amount * 55.0 * s
	else:
		cam_vel += Vector2.from_angle(randf() * TAU) * amount * 55.0 * s
	cam_roll_vel += roll * s * (1.0 if randf() > 0.5 else -1.0) * 4.0
	jitter = maxf(jitter, high_freq * amount * s)

func hit_stop(frames: int) -> void:
	var secs := float(frames) / 60.0 * Settings.hitstop
	if secs <= 0.001:
		return
	_hitstop_left = maxf(_hitstop_left, secs)
	Engine.time_scale = 0.02

func zoom_punch(amount: float) -> void:
	cam_zoom_vel += amount

func flash(col: Color, alpha: float = 0.5) -> void:
	var a := alpha * Settings.flash
	if a > screen_flash.a:
		screen_flash = Color(col.r, col.g, col.b, a)

func wave(world_pos: Vector2, strength: float = 1.0, dur: float = 0.6) -> void:
	var s := strength * Settings.distortion
	if s <= 0.01:
		return
	waves.append({"uv": world_to_uv(world_pos), "t": 0.0, "dur": dur, "strength": s})
	if waves.size() > 3:
		waves.pop_front()

func world_to_uv(p: Vector2) -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(0.5, 0.5)
	var sp: Vector2 = vp.get_canvas_transform() * p
	return sp / vp.get_visible_rect().size

func aberrate(amount: float) -> void:
	chroma = maxf(chroma, amount * Settings.distortion)

# ---- particles passthrough ---------------------------------------------------------------------
func burst(p: Vector2, col: Color, count: int, speed: float, dir: Vector2 = Vector2.ZERO, spread: float = TAU, life: float = 0.4, size: float = 2.0, kind: int = 0) -> void:
	if field:
		field.burst(p, col, count, speed, dir, spread, life, size, kind)

func debris(p: Vector2, col: Color, count: int, power: float, dir: Vector2 = Vector2.ZERO) -> void:
	if field:
		field.debris(p, col, count, power, dir)

func text(p: Vector2, s: String, col: Color, size: int = 8, big: bool = false) -> void:
	if field:
		field.text(p, s, col, size, big)

func ring(p: Vector2, col: Color, radius: float, dur: float = 0.35) -> void:
	if field:
		field.ring(p, col, radius, dur)

# ---- sequenced big effect ------------------------------------------------------------------------
## Anticipation -> Impact -> Rebound -> Particles -> Afterglow
func big_effect(pos: Vector2, col: Color, strength: float = 1.0, dir: Vector2 = Vector2.ZERO) -> void:
	zoom_punch(0.5 * strength)                                  # anticipation: arena draws in
	await _real_wait(0.05)
	hit_stop(3 + int(round(3.0 * clampf(strength, 0.0, 1.0)))) # impact
	shake(dir, 5.0 * strength, 0.5 * strength, 0.4)
	flash(Color.WHITE, 0.35 * strength)
	wave(pos, strength, 0.7)
	aberrate(0.012 * strength)
	Audio.duck(-9.0 * minf(strength, 1.0), 0.4)
	await _real_wait(0.07)
	zoom_punch(-1.0 * strength)                                 # rebound: arena springs back and overshoots
	burst(pos, col, int(26.0 * strength), 150.0 * strength, Vector2.ZERO, TAU, 0.55, 2.0, 0)   # particles
	ring(pos, col, 70.0 * strength, 0.45)
	afterglow = Color(col.r, col.g, col.b, 0.35 * Settings.flash * minf(strength, 1.0))        # afterglow

func _real_wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func reset() -> void:
	cam_offset = Vector2.ZERO
	cam_vel = Vector2.ZERO
	cam_roll = 0.0
	cam_roll_vel = 0.0
	cam_zoom = 1.0
	cam_zoom_vel = 0.0
	jitter = 0.0
	waves.clear()
	chroma = 0.0
	afterglow = Color(0, 0, 0, 0)
	screen_flash = Color(1, 1, 1, 0)
	_hitstop_left = 0.0
	Engine.time_scale = 1.0

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_dt := minf(float(now - _last_us) / 1000000.0, 0.1)
	_last_us = now
	if _hitstop_left > 0.0:
		_hitstop_left -= real_dt
		if _hitstop_left <= 0.0:
			Engine.time_scale = 1.0
	var dt := real_dt
	# camera springs
	cam_vel += (-cam_offset * 380.0 - cam_vel * 12.0) * dt
	cam_offset += cam_vel * dt
	cam_roll_vel += (-cam_roll * 300.0 - cam_roll_vel * 9.0) * dt
	cam_roll += cam_roll_vel * dt
	cam_zoom_vel += ((1.0 - cam_zoom) * 220.0 - cam_zoom_vel * 9.0) * dt
	cam_zoom += cam_zoom_vel * dt
	jitter = maxf(0.0, jitter - dt * 14.0)
	chroma = maxf(0.0, chroma - dt * 0.05)
	screen_flash.a = maxf(0.0, screen_flash.a - dt * 2.4)
	afterglow.a = maxf(0.0, afterglow.a - dt * 0.6)
	phase += TAU * pulse_rate() * dt
	for w in waves:
		w["t"] += dt
	waves = waves.filter(func(w: Dictionary) -> bool: return w["t"] < w["dur"])
