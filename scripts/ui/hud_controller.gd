class_name Hud
extends CanvasLayer
## Single custom-drawn HUD in 960x540 screen space (BoldPixels at 16px). Reads Game/Juice state.

var canvas := Control.new()
var player: Player
var rooms: RoomManager
var misfire_msg := ""
var misfire_col := Pal.VIOLET
var misfire_t := 0.0
var toasts: Array = []
var boss_ratio := -1.0
var boss_name := ""
var boss_flash := 0.0
var intro_name := ""
var intro_sub := ""
var intro_t := 0.0
var font: Font

func _ready() -> void:
	layer = 25
	font = Fonts.main()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)
	Game.misfire_triggered.connect(_on_misfire)
	Game.toast.connect(_on_toast)
	Game.boss_intro.connect(func(n: String, s: String) -> void:
		intro_name = n
		intro_sub = s
		intro_t = 3.0)
	Game.boss_hp_changed.connect(func(r: float, n: String) -> void:
		if r < boss_ratio:
			boss_flash = 1.0
		boss_ratio = r
		boss_name = n)

func _on_misfire(_id: StringName, info: Dictionary) -> void:
	misfire_msg = "MISFIRE: %s" % info["name"]
	misfire_col = info["color"]
	misfire_t = 2.5

func _on_toast(text: String, col: Color) -> void:
	toasts.append({"s": text, "c": col, "t": 0.0})
	if toasts.size() > 3:
		toasts.pop_front()

func _process(dt: float) -> void:
	misfire_t = maxf(0.0, misfire_t - dt)
	boss_flash = maxf(0.0, boss_flash - dt * 3.0)
	intro_t = maxf(0.0, intro_t - dt)
	for t in toasts:
		t["t"] += dt
	toasts = toasts.filter(func(t: Dictionary) -> bool: return t["t"] < 4.0)
	canvas.queue_redraw()

func _txt(p: Vector2, s: String, col: Color, size: int = 16, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> void:
	canvas.draw_string(font, p + Vector2(1, 1), s, align, w, size, Color(0, 0, 0, 0.9))
	canvas.draw_string(font, p, s, align, w, size, col)

func _panel(r: Rect2) -> void:
	canvas.draw_rect(r, Color(0.03, 0.02, 0.05, 0.7))
	canvas.draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)

func _draw_hud() -> void:
	if player == null or not is_instance_valid(player):
		return
	var w: WeaponController = player.weapon
	var heat := w.heat.ratio()
	var pulse := 0.5 + 0.5 * sin(Juice.phase)
	var room: Room = rooms.current
	# ---------------- top-left: hearts + minimap ----------------
	_panel(Rect2(8, 8, 190, 30))
	_draw_hearts(Vector2(24, 24))
	_draw_minimap(Vector2(8, 44))
	# ---------------- top-center: room title ----------------
	var rtxt := "ROOM %d-%d  %s" % [room.act, int(room.spec["col"]) + 1, room.title]
	if room.row_is_side():
		rtxt = "ACT %d  %s" % [room.act, room.title]
	_panel(Rect2(300, 8, 360, 46))
	_txt(Vector2(300, 28), rtxt, Pal.AMBER, 16, HORIZONTAL_ALIGNMENT_CENTER, 360.0)
	var status: String = Room.THEMES[room.act - 1]["name"]
	if rooms.combat_active:
		status = "ENEMIES %d   WAVE %d/%d" % [rooms.alive_count(), mini(rooms.wave_i, rooms.total_wave_count()), rooms.total_wave_count()]
	elif room.cleared and not room.safe:
		status = "CLEARED"
	elif room.safe:
		status = "SAFE ZONE"
	_txt(Vector2(300, 46), status, Color("9aa3b5"), 16, HORIZONTAL_ALIGNMENT_CENTER, 360.0)
	# ---------------- top-right: modules + relics ----------------
	_draw_modules(Vector2(716, 8))
	var rx := 724.0
	for r in Game.relics:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(rx, 82), Vector2(rx + 6, 90), Vector2(rx, 98), Vector2(rx - 6, 90)]), Pal.AMBER)
		rx += 16.0
	# ---------------- boss bar ----------------
	if boss_ratio >= 0.0 and room.kind == "boss":
		var bw := 480.0
		var bp := Vector2(240, 86)
		canvas.draw_rect(Rect2(bp - Vector2(2, 2), Vector2(bw + 4, 14)), Color(0, 0, 0, 0.85))
		var bc := Pal.RED.lerp(Color.WHITE, boss_flash)
		canvas.draw_rect(Rect2(bp, Vector2(bw * clampf(boss_ratio, 0.0, 1.0), 10)), bc)
		for k in [0.33, 0.5, 0.66]:
			canvas.draw_line(bp + Vector2(bw * k, 0), bp + Vector2(bw * k, 10), Color(1, 1, 1, 0.5), 1.0)
		_txt(bp + Vector2(0, -6), boss_name, Pal.RED, 16, HORIZONTAL_ALIGNMENT_CENTER, bw)
	if intro_t > 0.0:
		var a := clampf(minf(intro_t, 3.0 - intro_t) * 2.0, 0.0, 1.0)
		var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (1.0 if intro_t > 2.6 else 0.0)
		canvas.draw_rect(Rect2(0, 200, 960, 80), Color(0, 0, 0, 0.6 * a))
		_txt(Vector2(0, 240) + shake, intro_name, Color(1, 0.3, 0.2, a), 32, HORIZONTAL_ALIGNMENT_CENTER, 960.0)
		_txt(Vector2(0, 266), intro_sub, Color(0.8, 0.8, 0.85, a), 16, HORIZONTAL_ALIGNMENT_CENTER, 960.0)
	# ---------------- bottom bar ----------------
	_panel(Rect2(0, 468, 960, 72))
	var hc := Pal.heat_color(heat)
	var heat_label := ("^ " if Settings.symbols else "") + Settings.t("heat") + " %d%%" % int(w.heat.heat)
	if w.heat.is_locked():
		heat_label = "OVERHEAT %.1fs  VENT!" % w.heat.lock_t
	_txt(Vector2(14, 488), heat_label, Pal.RED if (w.heat.is_locked() and int(Time.get_ticks_msec() / 150) % 2 == 0) else hc)
	var bar := Rect2(14, 494, 230, 9)
	canvas.draw_rect(bar.grow(1), Color(0, 0, 0, 0.8))
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * heat, bar.size.y)), hc.lerp(Color.WHITE, 0.3 * pulse * heat))
	for i in range(1, 10):
		canvas.draw_line(bar.position + Vector2(bar.size.x * i / 10.0, 0), bar.position + Vector2(bar.size.x * i / 10.0, bar.size.y), Color(0, 0, 0, 0.5), 1.0)
	var inst := w.instab.value()
	var ic := Pal.VIOLET if inst < 75.0 else Pal.VIOLET.lerp(Color.WHITE, 0.5 * pulse)
	var jit := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (inst / 100.0) * 1.2
	_txt(Vector2(14, 520) + jit, ("# " if Settings.symbols else "") + "INSTAB. %d%%" % int(inst) + ("  HIGH RISK" if inst >= 75.0 else ""), ic)
	var ibar := Rect2(14, 525, 230, 5)
	canvas.draw_rect(ibar.grow(1), Color(0, 0, 0, 0.8))
	canvas.draw_rect(Rect2(ibar.position, Vector2(ibar.size.x * inst / 100.0, ibar.size.y)), ic)
	canvas.draw_line(ibar.position + Vector2(ibar.size.x * 0.75, -1), ibar.position + Vector2(ibar.size.x * 0.75, 6), Color(1, 1, 1, 0.7), 1.0)
	# vent + dash
	var vx := 268.0
	var vready := w.heat.vent_ready()
	var vcol := Pal.RED if vready else Color("5a5f6b")
	_txt(Vector2(vx, 488), "VENT" + (" READY" if vready else (" %.1fs" % w.heat.vent_cd if w.heat.vent_cd > 0.0 else "")), vcol)
	var vb := Rect2(vx, 494, 110, 6)
	canvas.draw_rect(vb.grow(1), Color(0, 0, 0, 0.8))
	canvas.draw_rect(Rect2(vb.position, Vector2(vb.size.x * (1.0 - w.heat.vent_cd / HeatSystem.VENT_COOLDOWN), vb.size.y)), vcol)
	var dcol := Pal.CYAN if player.dash_cd <= 0.0 else Color("5a5f6b")
	_txt(Vector2(vx, 520), "DASH", dcol)
	canvas.draw_rect(Rect2(vx, 525, 110.0 * (1.0 - player.dash_cd / Player.DASH_COOLDOWN), 4), dcol)
	# misfire info
	var risk := w.instab.chance() * 100.0
	var nm := w.instab.next_misfire
	var rx2 := 400.0
	if nm != &"":
		var info: Dictionary = ModuleDB.MISFIRES[nm]
		var col: Color = info["color"]
		col.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02)
		_txt(Vector2(rx2, 488), "! NEXT SHOT: " + info["name"], col)
		_txt(Vector2(rx2, 508), info["desc"], Color(col.r, col.g, col.b, 0.85))
	else:
		_txt(Vector2(rx2, 488), "MISFIRE RISK %.0f%% / shot" % risk, Color("7d8596"))
		_txt(Vector2(rx2, 508), "next shot is clean", Color("5d6576"))
	var pool_txt := ""
	for id in w.loadout.get_misfire_pool():
		pool_txt += "%s " % ModuleDB.MISFIRES[id]["symbol"]
	_txt(Vector2(rx2, 528), "traits " + pool_txt + ("+GLITCH" if inst >= 75.0 else ""), Color("7d8596"))
	# vent / misfire feed
	if misfire_t > 0.0:
		var mc := misfire_col
		mc.a = clampf(misfire_t, 0.0, 1.0)
		_txt(Vector2(0, 140), misfire_msg, mc, 16, HORIZONTAL_ALIGNMENT_CENTER, 960.0)
	# toasts
	var ty := 112.0 if boss_ratio < 0.0 or room.kind != "boss" else 124.0
	for t in toasts:
		var col2: Color = t["c"]
		col2.a = clampf(minf(t["t"] * 4.0, (4.0 - t["t"]) * 2.0), 0.0, 1.0)
		_txt(Vector2(0, ty), t["s"], col2, 16, HORIZONTAL_ALIGNMENT_CENTER, 960.0)
		ty += 20.0
	if heat > 0.7:
		var ra := (heat - 0.7) / 0.3 * (0.35 + 0.35 * pulse)
		canvas.draw_rect(Rect2(1, 1, 958, 538), Color(1, 0.15, 0.05, ra), false, 3.0)
	_draw_reticle(w, heat)
	if Settings.show_fps:
		_txt(Vector2(890, 470), "%d fps" % Engine.get_frames_per_second(), Color.WHITE)

func _draw_hearts(p: Vector2) -> void:
	var n := Game.max_hp / 2
	for i in n:
		var hp_here := clampi(Game.hp - i * 2, 0, 2)
		var c := p + Vector2(i * 20.0, 0)
		var beat := 1.0 + 0.1 * sin(Juice.phase * 1.5 + i) * (1.0 if Game.hp <= 2 else 0.4)
		_heart(c, 7.0 * beat, hp_here)

func _heart(c: Vector2, s: float, fill: int) -> void:
	var col := Pal.RED if fill > 0 else Color("3a2024")
	var pts := PackedVector2Array([c + Vector2(-s, -s * 0.2), c + Vector2(0, s), c + Vector2(s, -s * 0.2), c + Vector2(s * 0.6, -s * 0.9), c + Vector2(0, -s * 0.4), c + Vector2(-s * 0.6, -s * 0.9)])
	canvas.draw_colored_polygon(pts, col)
	canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]), Color(0, 0, 0, 0.8), 1.0)
	if fill == 1:
		canvas.draw_rect(Rect2(c.x, c.y - s, s, s * 2.0), Color("3a2024"))
		canvas.draw_rect(Rect2(c.x - s, c.y - s * 0.6, s, s * 1.2), Pal.RED)
		canvas.draw_line(c + Vector2(0, -s), c + Vector2(0, s), Color(0, 0, 0, 0.8), 1.0)

func _draw_modules(p: Vector2) -> void:
	var l := player.weapon.loadout
	var i := 0
	for m in l.modules():
		var r := Rect2(p + Vector2(0, i * 22.0), Vector2(236, 20))
		canvas.draw_rect(r, Color(0, 0, 0, 0.7))
		canvas.draw_rect(Rect2(r.position, Vector2(4, 20)), m.color)
		_txt(r.position + Vector2(10, 16), "%s %s" % [m.symbol if Settings.symbols else "", m.display_name], m.color.lerp(Color.WHITE, 0.4), 16, HORIZONTAL_ALIGNMENT_LEFT, 224.0)
		i += 1

func _draw_minimap(p: Vector2) -> void:
	var act := rooms.current.act
	var cell := 14.0
	var specs: Array = []
	for s in rooms.plan:
		if s["act"] == act:
			specs.append(s)
	for s in specs:
		var pos := p + Vector2(float(s["col"]) * (cell + 4.0), (1.0 if int(s["row"]) == 0 else 0.0) * (cell + 4.0)) + Vector2(2, 2)
		var idx: int = s["idx"]
		var seen := rooms.visited.has(idx)
		var hidden: bool = (s["kind"] == "secret" and not seen)
		if hidden:
			continue
		var col := Color(0.2, 0.22, 0.28)
		if seen:
			col = Color(0.45, 0.5, 0.6)
		if Game.cleared_rooms.has(idx):
			col = Pal.LIME.darkened(0.35)
		if s["kind"] == "boss":
			col = Pal.RED if seen else Pal.RED.darkened(0.6)
		elif s["kind"] == "workshop":
			col = Pal.AMBER if seen else Pal.AMBER.darkened(0.6)
		elif s["kind"] == "cursed":
			col = Pal.VIOLET if seen else Pal.VIOLET.darkened(0.6)
		canvas.draw_rect(Rect2(pos, Vector2(cell, cell)), col)
		if idx == rooms.current.index:
			canvas.draw_rect(Rect2(pos - Vector2(2, 2), Vector2(cell + 4, cell + 4)), Color(1, 1, 1, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)), false, 2.0)
		for side in s["exits"]:
			if side == Room.R:
				canvas.draw_rect(Rect2(pos + Vector2(cell, 5), Vector2(4, 4)), Color(0.35, 0.38, 0.45))

func _draw_reticle(w: WeaponController, heat: float) -> void:
	var p := player.get_viewport().get_mouse_position()
	if player.stick_aim or player.override_active:
		p = player.get_viewport().get_canvas_transform() * player.aim_target
	var rate := lerpf(1.0, 3.0, heat)
	var r := 9.0 + heat * 12.0 + 2.0 * sin(Juice.phase * rate) * (0.4 + heat)
	var col := Pal.CYAN.lerp(Pal.RED, heat)
	canvas.draw_arc(p, r, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.5), 1.0)
	canvas.draw_arc(p, r + 3.0, -PI * 0.5, -PI * 0.5 + TAU * heat, 32, Pal.heat_color(heat), 3.0)
	if w.charging:
		canvas.draw_arc(p, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * w.charge, 24, Color.WHITE, 2.0)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		canvas.draw_line(p + d * (r - 4.0), p + d * (r + 1.0 - heat * 3.0), col, 2.0)
	canvas.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
	if w.heat.is_locked():
		canvas.draw_line(p + Vector2(-7, -7), p + Vector2(7, 7), Pal.RED, 2.0)
		canvas.draw_line(p + Vector2(-7, 7), p + Vector2(7, -7), Pal.RED, 2.0)
