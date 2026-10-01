extends Control
## Title screen: an overheated cyber-garage. Pixel-font logo that squashes on input, a slowly beating
## energy core, steam, sparks, drones and harmless misfires when idle.

const GLYPH := {
	"H": ["X...X", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
	"E": ["XXXXX", "X....", "X....", "XXXX.", "X....", "X....", "XXXXX"],
	"A": [".XXX.", "X...X", "X...X", "XXXXX", "X...X", "X...X", "X...X"],
	"T": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."],
	"&": [".XX..", "X..X.", "X..X.", ".XX.X", "X..XX", "X..X.", ".XX.X"],
	"C": [".XXXX", "X....", "X....", "X....", "X....", "X....", ".XXXX"],
	"O": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
	"S": [".XXXX", "X....", "X....", ".XXX.", "....X", "....X", "XXXX."],
}
const LOGO := ["HEAT", "&", "CHAOS"]

var t := 0.0
var idle_t := 0.0
var misfire_t := 0.0
var letter_springs: Array[SquashSpring] = []
var sparks: Array = []
var steam: Array = []
var drones: Array = []
var menu := VBoxContainer.new()
var content_layer := Control.new()
var _panel: Control
var _core_flicker := 0.0
var _font: Font
var _glow := ArtNode.new()
var _first_btn: Button

func _ready() -> void:
	theme = UIKit.theme()
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 11:
		letter_springs.append(SquashSpring.new(200.0, 8.0))
	for i in 3:
		drones.append({"p": Vector2(randf() * 640.0, 60.0 + randf() * 120.0), "v": Vector2(randf_range(10, 25) * (1 if i % 2 == 0 else -1), 0.0), "ph": randf() * TAU})
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw_fn = _draw_glow
	add_child(_glow)
	content_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_layer)
	_build_menu()
	Audio.stop_music()
	Audio.start_music()
	Audio.set_heat(0.15, 0.0)
	for i in 3:
		_poke_letters(0.6)

func _exit_tree() -> void:
	Audio.stop_music()

func _build_menu() -> void:
	if menu.get_parent():
		menu.get_parent().remove_child(menu)
	for c in menu.get_children():
		c.queue_free()
	menu.position = Vector2(24, 150)
	menu.add_theme_constant_override("separation", 3)
	content_layer.add_child(menu)
	var entries := [
		["start_run", _start_run, true],
		["continue_run", _continue_run, Save.has_run()],
		["workshop", func() -> void: Router.go("workshop"), true],
		["codex", func() -> void: _open_panel("codex"), true],
		["progression", func() -> void: _open_panel("progression"), true],
		["settings", func() -> void: _open_panel("settings"), true],
		["quit", func() -> void: get_tree().quit(), true],
	]
	_first_btn = null
	for e in entries:
		var b := UIKit.button(Settings.t(e[0]), e[1], 150)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not e[2]
		b.focus_entered.connect(_poke_letters.bind(0.35))
		menu.add_child(b)
		if _first_btn == null and not b.disabled:
			_first_btn = b
	_first_btn.call_deferred("grab_focus")
	var sc := UIKit.label("SCRAP %d    CORES %d" % [Save.data["scrap"], Save.data["cores"]], Pal.AMBER)
	sc.position = Vector2(24, 336)
	content_layer.add_child(sc)
	var hint := UIKit.label("WASD move | Mouse aim+shoot | RMB/Q vent | Space dash | E bench | F1-F4 dev builds", Color("6a7285"))
	hint.position = Vector2(150, 346)
	content_layer.add_child(hint)

func _start_run() -> void:
	_open_panel("setup")

func _continue_run() -> void:
	if Game.restore_run():
		Router.go("run")

func _open_panel(which: String) -> void:
	if _panel:
		_panel.queue_free()
	menu.visible = false
	match which:
		"settings":
			var p := SettingsPanel.new()
			p.closed.connect(_close_panel)
			_panel = p
		"codex":
			var p2 := CodexPanel.new()
			p2.closed.connect(_close_panel)
			_panel = p2
		"progression":
			var p3 := ProgressionPanel.new()
			p3.closed.connect(_close_panel)
			_panel = p3
		"setup":
			var p4 := RunSetupPanel.new()
			p4.closed.connect(_close_panel)
			p4.launched.connect(func() -> void: Router.go("story"))
			_panel = p4
	content_layer.add_child(_panel)

func _close_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	menu.visible = true
	_build_menu()

func _poke_letters(amount: float) -> void:
	idle_t = 0.0
	for s in letter_springs:
		s.punch(Vector2(randf_range(-6, 6), randf_range(8, 18)) * amount)
		s.squash(Vector2(1.0 + randf_range(-0.3, 0.3) * amount, 1.0 + randf_range(-0.3, 0.5) * amount))
	for i in 10:
		sparks.append({"p": Vector2(randf_range(250, 580), randf_range(40, 120)), "v": Vector2.from_angle(randf() * TAU) * randf_range(40, 140), "l": 0.5, "c": Pal.CYAN if randf() < 0.6 else Pal.AMBER})

func _input(e: InputEvent) -> void:
	if (e is InputEventKey and e.pressed) or (e is InputEventMouseButton and e.pressed):
		idle_t = 0.0

func _process(dt: float) -> void:
	t += dt
	idle_t += dt
	_core_flicker = maxf(0.0, _core_flicker - dt * 2.0)
	if idle_t > 18.0 and misfire_t <= 0.0:
		# idle: the core gets restless and fires a harmless misfire
		misfire_t = 3.0
		idle_t = 10.0
	if misfire_t > 0.0:
		misfire_t -= dt
		if misfire_t < 2.7 and misfire_t + dt >= 2.7:
			_core_flicker = 1.0
			Audio.play("misfire", 0.8, -6.0, "Feedback")
			for i in 40:
				sparks.append({"p": Vector2(413, 100), "v": Vector2.from_angle(randf() * TAU) * randf_range(50, 220), "l": 0.9, "c": Pal.VIOLET if randf() < 0.5 else Pal.RED})
	for s in letter_springs:
		s.update(dt)
	for sp in sparks:
		sp["p"] += sp["v"] * dt
		sp["v"] *= exp(-dt * 2.5)
		sp["l"] -= dt
	sparks = sparks.filter(func(s: Dictionary) -> bool: return s["l"] > 0.0)
	if randf() < dt * 8.0:
		steam.append({"p": Vector2(randf_range(0, 640), 360.0), "l": 0.0, "x": randf_range(-6, 6)})
	for st in steam:
		st["l"] += dt
		st["p"] += Vector2(st["x"], -22.0) * dt
	steam = steam.filter(func(s: Dictionary) -> bool: return s["l"] < 4.0)
	for d in drones:
		d["p"] += d["v"] * dt
		if d["p"].x < -20.0:
			d["p"].x = 660.0
		elif d["p"].x > 660.0:
			d["p"].x = -20.0
	# idle restlessness speeds the pulse
	var restless := clampf((idle_t - 8.0) / 10.0, 0.0, 1.0)
	Audio.set_heat(0.12 + restless * 0.5, 0.0)
	Juice.heat = restless * 0.5
	Juice.phase += TAU * (0.8 + restless * 3.0) * dt
	queue_redraw()
	_glow.queue_redraw()

func _core_pulse() -> float:
	var restless := clampf((idle_t - 8.0) / 10.0, 0.0, 1.0)
	return 0.5 + 0.5 * sin(t * (1.6 + restless * 5.0)) + _core_flicker * randf()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Pal.BG)
	# back wall: tiles, pipes, cables
	for ty in 12:
		for tx in 22:
			var h := fposmod(float(tx * 73 + ty * 151) * 0.137, 1.0)
			draw_rect(Rect2(tx * 30, ty * 30, 29, 29), Pal.RUST_DARK.lerp(Pal.STEEL_DARK, h * 0.7))
	for i in 7:
		var y := 20.0 + i * 52.0
		draw_rect(Rect2(0, y, 640, 6), Pal.STEEL_DARK)
		draw_rect(Rect2(0, y + 1, 640, 1), Pal.STEEL)
		for k in 16:
			draw_rect(Rect2(10 + k * 42, y + 2, 2, 2), Pal.RUST)
	# vibrating cables
	for i in 5:
		var pts := PackedVector2Array()
		for k in 21:
			var x := k * 32.0
			pts.append(Vector2(x, 300.0 + i * 8.0 + sin(x * 0.03 + t * (3.0 + i)) * (3.0 + i) + sin(t * 25.0 + k) * 0.6))
		draw_polyline(pts, Color(0.1, 0.1, 0.12), 2.0)
		draw_polyline(pts, Pal.RUST.darkened(0.2), 1.0)
	# core housing
	var c := Vector2(413, 100)
	var p := _core_pulse()
	draw_circle(c, 64.0, Pal.STEEL_DARK)
	draw_arc(c, 62.0, 0.0, TAU, 40, Pal.STEEL, 3.0)
	for i in 12:
		var a := TAU * i / 12.0 + t * 0.05
		draw_rect(Rect2(c + Vector2.from_angle(a) * 56.0 - Vector2(2, 2), Vector2(4, 4)), Pal.RUST)
	draw_circle(c, 44.0, Color(0.08, 0.04, 0.05))
	var coreC := Pal.RED.lerp(Pal.AMBER, p * 0.4).lerp(Pal.VIOLET, _core_flicker * 0.6)
	draw_circle(c, 30.0 + p * 4.0, coreC.darkened(0.5))
	draw_circle(c, 22.0 + p * 4.0, coreC)
	draw_circle(c, 11.0 + p * 3.0, Color(1, 0.9, 0.7))
	for i in 10:
		var a2 := TAU * i / 10.0 + sin(t * 0.7 + i) * 0.2
		draw_line(c + Vector2.from_angle(a2) * 24.0, c + Vector2.from_angle(a2) * (40.0 + 6.0 * sin(t * 3.0 + i * 2.0)), coreC, 1.0)
	# neon tubes
	for i in 4:
		var x := 30.0 + i * 190.0
		var flick := 0.7 + 0.3 * sin(t * (7.0 + i * 3.0)) * (1.0 if fmod(t + i, 7.0) > 0.3 else 0.2)
		var col := Pal.CYAN if i % 2 == 0 else Pal.LIME
		draw_rect(Rect2(x, 22, 3, 56), Color(col.r, col.g, col.b, flick))
		draw_rect(Rect2(x - 1, 22, 5, 56), Color(col.r, col.g, col.b, flick * 0.2))
	# drones
	for d in drones:
		var dp: Vector2 = d["p"] + Vector2(0, sin(t * 2.0 + d["ph"]) * 5.0)
		var s := Vector2(1.0 + 0.1 * sin(t * 4.0 + d["ph"]), 1.0 - 0.1 * sin(t * 4.0 + d["ph"]))
		draw_set_transform(dp, 0.0, s)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(-2, -4), Vector2(2, -4), Vector2(6, 0), Vector2(2, 4), Vector2(-2, 4)]), Pal.STEEL)
		draw_rect(Rect2(-1, -1, 3, 2), Pal.RED if int(t * 2.0 + d["ph"]) % 2 == 0 else Pal.CYAN)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_logo()
	for sp in sparks:
		var col2: Color = sp["c"]
		col2.a = clampf(sp["l"] * 2.0, 0.0, 1.0)
		draw_rect(Rect2((sp["p"] as Vector2).floor(), Vector2(2, 2)), col2)
	for st in steam:
		var a3: float = (1.0 - st["l"] / 4.0) * 0.18
		draw_circle(st["p"], 6.0 + st["l"] * 8.0, Color(0.7, 0.7, 0.75, a3))
	# left panel for the menu
	draw_rect(Rect2(12, 140, 174, 190), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(12, 140, 174, 190), Pal.STEEL, false, 1.0)

func _draw_logo() -> void:
	var px := 5.0
	var y0 := 168.0
	# layout: "HEAT & CHAOS" on one line above the panel
	var total_w := 0.0
	var order: Array = []
	for word in LOGO:
		for ch in word:
			order.append(ch)
		order.append(" ")
	order.pop_back()
	var letter_w := 5.0 * px + px
	var start := Vector2(413.0 - (order.size() * letter_w) * 0.5, 196.0)
	start.y = 168.0
	var idx := 0
	var letter_i := 0
	for ch in order:
		if ch == " ":
			idx += 1
			continue
		var s := letter_springs[letter_i % letter_springs.size()]
		letter_i += 1
		var wave := sin(t * 2.5 + idx * 0.6) * 2.0
		var base := start + Vector2(idx * letter_w, wave)
		var col := Pal.RED.lerp(Pal.AMBER, float(idx) / 3.0)
		if ch == "&":
			col = Pal.VIOLET
		elif idx > 5:
			col = Pal.CYAN.lerp(Pal.LIME, float(idx - 5) / 6.0)
		var g: Array = GLYPH[ch]
		var ctr := base + Vector2(2.5 * px, 3.5 * px)
		for ry in 7:
			for rx in 5:
				if g[ry][rx] == "X":
					var lp := Vector2(rx * px, ry * px) - Vector2(2.5 * px, 3.5 * px)
					lp = lp * s.value
					var pos := (ctr + lp).floor()
					draw_rect(Rect2(pos + Vector2(2, 2), Vector2(px * s.value.x, px * s.value.y)), Color(0, 0, 0, 0.7))
					draw_rect(Rect2(pos, Vector2(px * s.value.x, px * s.value.y)), col)
					draw_rect(Rect2(pos, Vector2(px * s.value.x, 1)), Color(1, 1, 1, 0.5))
		idx += 1
	var tag := "an overheated roguelike"
	draw_string(_font, Vector2(213, 224), tag, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 8, Color("8a93a5"))

func _draw_glow(c: Node2D) -> void:
	var p := _core_pulse()
	Juice.glow(c, Vector2(413, 100), 120.0 + p * 20.0, Color(1.0, 0.3, 0.1, 0.35 + 0.2 * p))
	for i in 4:
		var col := Pal.CYAN if i % 2 == 0 else Pal.LIME
		Juice.glow(c, Vector2(31.5 + i * 190.0, 50), 34.0, Color(col.r, col.g, col.b, 0.22))
