extends Control
## Workshop hub between runs: six animated stations. Meta unlocks visibly change the garage.

const STATIONS := [
	{"id": "bay", "name": "WEAPON BAY", "pos": Vector2(110, 120), "col": Color("19e6ff"), "hint": "View modules, compare, save presets"},
	{"id": "furnace", "name": "MODULE FURNACE", "pos": Vector2(320, 120), "col": Color("ff3b1f"), "hint": "Unlock new modules and runners"},
	{"id": "recycler", "name": "SCRAP RECYCLER", "pos": Vector2(530, 120), "col": Color("8dff2a"), "hint": "Duplicates become scrap"},
	{"id": "character", "name": "CHARACTER STATION", "pos": Vector2(110, 250), "col": Color("ffb02e"), "hint": "Pick runner + starter kit"},
	{"id": "codex", "name": "CODEX TERMINAL", "pos": Vector2(320, 250), "col": Color("a24bff"), "hint": "Story fragments & research"},
	{"id": "launch", "name": "LAUNCH CONSOLE", "pos": Vector2(530, 250), "col": Color("ff6a2a"), "hint": "Start the next run"},
]

var t := 0.0
var _panel: Control
var _buttons: Array[Button] = []
var _hint := Label.new()
var _bal := Label.new()
var _glow := ArtNode.new()
var _focus := 0
var _sparks: Array = []
var _font: Font
var _root := Control.new()
const S := Vector2(1.5, 1.5)

func _ready() -> void:
	theme = UIKit.theme()
	_font = Fonts.main()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw_fn = _draw_glow
	add_child(_glow)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for i in STATIONS.size():
		var s: Dictionary = STATIONS[i]
		var b := UIKit.button(s["name"], _activate.bind(s["id"]), 200)
		b.position = (s["pos"] as Vector2) * 1.5 + Vector2(-100, 62)
		b.size = Vector2(200, 28)
		b.focus_entered.connect(func() -> void:
			_focus = i
			_hint.text = s["hint"])
		_root.add_child(b)
		_buttons.append(b)
	# explicit focus neighbours so d-pad / arrows move spatially
	for i in 6:
		var col := i % 3
		var row := i / 3
		_buttons[i].focus_neighbor_right = _buttons[row * 3 + (col + 1) % 3].get_path()
		_buttons[i].focus_neighbor_left = _buttons[row * 3 + (col + 2) % 3].get_path()
		_buttons[i].focus_neighbor_bottom = _buttons[((row + 1) % 2) * 3 + col].get_path()
		_buttons[i].focus_neighbor_top = _buttons[((row + 1) % 2) * 3 + col].get_path()
	var back := UIKit.button(Settings.t("back"), func() -> void: Router.go("menu"), 110)
	back.position = Vector2(14, 496)
	_root.add_child(back)
	_hint.position = Vector2(140, 500)
	_hint.add_theme_color_override("font_color", Pal.AMBER)
	_root.add_child(_hint)
	_bal.position = Vector2(560, 22)
	_bal.add_theme_color_override("font_color", Pal.AMBER)
	_root.add_child(_bal)
	_refresh_balance()
	_buttons[0].call_deferred("grab_focus")
	Audio.stop_music()
	Audio.start_music()
	Audio.set_heat(0.05, 0.0)

func _exit_tree() -> void:
	Audio.stop_music()

func _refresh_balance() -> void:
	_bal.text = "SCRAP %d   CORES %d   MODULES %d/%d" % [Save.data["scrap"], Save.data["cores"], _unlocked_count(), ModuleDB.order.size()]

func _unlocked_count() -> int:
	var n := 0
	for id in ModuleDB.order:
		if Save.is_unlocked(id):
			n += 1
	return n

func _activate(id: String) -> void:
	_root.visible = false
	match id:
		"bay":
			var p := WeaponBayPanel.new()
			p.meta_mode = true
			p.closed.connect(_close_panel)
			_open(p)
		"furnace":
			var p2 := ProgressionPanel.new()
			p2.closed.connect(_close_panel)
			_open(p2)
		"recycler":
			_open(_recycler_panel())
		"character":
			var p3 := RunSetupPanel.new()
			p3.hub_mode = true
			p3.closed.connect(_close_panel)
			_open(p3)
		"codex":
			var p4 := CodexPanel.new()
			p4.closed.connect(_close_panel)
			_open(p4)
		"launch":
			var p5 := RunSetupPanel.new()
			p5.closed.connect(_close_panel)
			p5.launched.connect(func() -> void: Router.go("story"))
			_open(p5)

func _open(p: Control) -> void:
	_panel = p
	add_child(p)

func _close_panel() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	_root.visible = true
	_refresh_balance()
	_buttons[_focus].call_deferred("grab_focus")

func _recycler_panel() -> Control:
	var p := PanelContainer.new()
	p.position = Vector2(290, 150)
	p.size = Vector2(380, 220)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UIKit.label("SCRAP RECYCLER", Pal.LIME))
	var info := UIKit.label("")
	v.add_child(info)
	var upd := func() -> void:
		info.text = "Duplicate modules found in runs: %d\nEach converts to 5 scrap." % Save.data["dupes"]
	upd.call()
	var go := UIKit.button("RECYCLE ALL", func() -> void:
		var n: int = Save.data["dupes"]
		Save.data["dupes"] = 0
		Save.data["scrap"] += n * 5
		Save.save_game()
		Audio.play("kill", 0.7)
		for i in 20:
			_sparks.append({"p": Vector2(530, 130), "v": Vector2.from_angle(randf() * TAU) * randf_range(30, 120), "l": 0.7, "c": Pal.LIME})
		upd.call(), 140)
	v.add_child(go)
	v.add_child(UIKit.button(Settings.t("back"), _close_panel, 80))
	go.call_deferred("grab_focus")
	return p

func _process(dt: float) -> void:
	t += dt
	for sp in _sparks:
		sp["p"] += sp["v"] * dt
		sp["v"] *= exp(-dt * 2.0)
		sp["l"] -= dt
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s["l"] > 0.0)
	Juice.phase += TAU * 0.9 * dt
	queue_redraw()
	_glow.queue_redraw()

func _unhandled_input(e: InputEvent) -> void:
	if _panel == null and e.is_action_pressed("ui_cancel"):
		Router.go("menu")

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, S)
	draw_rect(Rect2(0, 0, 640, 360), Pal.BG)
	for ty in 12:
		for tx in 22:
			var h := fposmod(float(tx * 53 + ty * 97) * 0.173, 1.0)
			draw_rect(Rect2(tx * 30, ty * 30, 29, 29), Color("2a1d14").lerp(Pal.STEEL_DARK, h * 0.6))
	draw_rect(Rect2(0, 0, 640, 40), Pal.STEEL_DARK)
	draw_rect(Rect2(0, 40, 640, 3), Pal.RUST)
	var unlocked := _unlocked_count()
	for i in STATIONS.size():
		_draw_station(i, STATIONS[i], i == _focus, unlocked)
	for sp in _sparks:
		var c: Color = sp["c"]
		c.a = clampf(sp["l"] * 2.0, 0.0, 1.0)
		draw_rect(Rect2((sp["p"] as Vector2).floor(), Vector2(2, 2)), c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(_font, Vector2(20, 30), "MARA VEX'S CYBER-GARAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Pal.AMBER)
	draw_string(_font, Vector2(20, 50), "last independent workshop under Cinderfall", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("6a7285"))

func _draw_station(i: int, s: Dictionary, focused: bool, unlocked: int) -> void:
	var p: Vector2 = s["pos"]
	var col: Color = s["col"]
	var beat := 0.5 + 0.5 * sin(t * (1.5 + i * 0.4) + i)
	var sq := Vector2(1.0 + 0.04 * sin(t * 3.0 + i) + (0.06 if focused else 0.0), 1.0 - 0.04 * sin(t * 3.0 + i) + (0.06 if focused else 0.0))
	draw_set_transform(p * 1.5, 0.0, sq * 1.5)
	draw_rect(Rect2(-52, -42, 104, 78), Pal.STEEL_DARK)
	draw_rect(Rect2(-52, -42, 104, 78), col if focused else Pal.STEEL, false, 2.0 if focused else 1.0)
	draw_rect(Rect2(-48, -38, 96, 14), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(-48, -38, 96.0 * (0.4 + 0.6 * beat), 14), Color(col.r, col.g, col.b, 0.25))
	match s["id"]:
		"bay":
			for k in 3:
				draw_rect(Rect2(-40 + k * 28, -16, 22, 28), Color(0.05, 0.06, 0.08))
				draw_rect(Rect2(-38 + k * 28, -14, 18, 24 * (0.5 + 0.5 * sin(t * 2.0 + k))), [Pal.CYAN, Pal.LIME, Pal.AMBER][k].darkened(0.2))
		"furnace":
			draw_circle(Vector2(0, -2), 22.0, Color(0.1, 0.03, 0.03))
			draw_circle(Vector2(0, -2), 14.0 + beat * 3.0, Pal.RED)
			draw_circle(Vector2(0, -2), 7.0 + beat * 2.0, Color(1, 0.9, 0.6))
			for k in mini(unlocked, 11):
				draw_rect(Rect2(-46 + k * 8, 22, 6, 4), Pal.AMBER)
		"recycler":
			for k in 4:
				var a := t * (2.0 + k * 0.4) + k
				draw_arc(Vector2(0, -2), 6.0 + k * 5.0, a, a + PI * 1.2, 12, Pal.LIME.darkened(0.2), 2.0)
		"character":
			draw_colored_polygon(PackedVector2Array([Vector2(-10, 14), Vector2(10, 14), Vector2(14, -6), Vector2(0, -18), Vector2(-14, -6)]), Pal.STEEL)
			draw_rect(Rect2(-6, -8, 12, 5), Pal.CYAN)
			draw_circle(Vector2(0, 4), 3.0 + beat, Pal.AMBER)
		"codex":
			for k in 6:
				var w := 20.0 + 30.0 * fposmod(sin(k * 12.9 + floorf(t * 0.8)) * 4375.0, 1.0)
				draw_rect(Rect2(-42, -16 + k * 6, w, 2), Color(Pal.VIOLET.r, Pal.VIOLET.g, Pal.VIOLET.b, 0.5 + 0.4 * beat))
		"launch":
			draw_rect(Rect2(-30, -14, 60, 26), Color(0.1, 0.05, 0.03))
			var blink := 1.0 if int(t * 3.0) % 2 == 0 else 0.3
			draw_circle(Vector2(0, -1), 9.0, Color(Pal.RED.r, Pal.RED.g, Pal.RED.b, blink))
	draw_set_transform(Vector2.ZERO, 0.0, S)

func _draw_glow(c: Node2D) -> void:
	c.draw_set_transform(Vector2.ZERO, 0.0, S)
	for i in STATIONS.size():
		var s: Dictionary = STATIONS[i]
		var col: Color = s["col"]
		var beat := 0.5 + 0.5 * sin(t * (1.5 + i * 0.4) + i)
		Juice.glow(c, s["pos"], 56.0 + (12.0 if i == _focus else 0.0), Color(col.r, col.g, col.b, 0.12 + 0.12 * beat + (0.15 if i == _focus else 0.0)))
