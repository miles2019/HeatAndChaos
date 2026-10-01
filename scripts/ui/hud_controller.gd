class_name Hud
extends CanvasLayer
## Single custom-drawn HUD. Keeps the machine-frame look and reads everything from Game/Juice state.

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
var font: Font

func _ready() -> void:
	layer = 10
	font = ThemeDB.fallback_font
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_hud)
	add_child(canvas)
	Game.misfire_triggered.connect(_on_misfire)
	Game.toast.connect(_on_toast)
	Game.boss_hp_changed.connect(func(r: float, n: String) -> void:
		if r < boss_ratio:
			boss_flash = 1.0
		boss_ratio = r
		boss_name = n)

func _on_misfire(id: StringName, info: Dictionary) -> void:
	misfire_msg = "MISFIRE  %s  -  %s" % [info["name"], info["desc"]]
	misfire_col = info["color"]
	misfire_t = 3.0

func _on_toast(text: String, col: Color) -> void:
	toasts.append({"s": text, "c": col, "t": 0.0})
	if toasts.size() > 4:
		toasts.pop_front()

func _process(dt: float) -> void:
	misfire_t = maxf(0.0, misfire_t - dt)
	boss_flash = maxf(0.0, boss_flash - dt * 3.0)
	for t in toasts:
		t["t"] += dt
	toasts = toasts.filter(func(t: Dictionary) -> bool: return t["t"] < 4.0)
	canvas.queue_redraw()

func _txt(p: Vector2, s: String, col: Color, size: int = 8, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0) -> void:
	canvas.draw_string(font, p + Vector2(1, 1), s, align, w, size, Color(0, 0, 0, 0.8))
	canvas.draw_string(font, p, s, align, w, size, col)

func _draw_hud() -> void:
	if player == null or not is_instance_valid(player):
		return
	var w: WeaponController = player.weapon
	var heat := w.heat.ratio()
	var pulse := 0.5 + 0.5 * sin(Juice.phase)
	var a := Pal.AMBER
	# ---- top bar: hearts / room / modules ----
	_draw_hearts(Vector2(10, 10))
	var room: Room = rooms.current
	var rtxt := "ROOM 1-%d: THE STEAM VAULTS" % (room.index + 1)
	_txt(Vector2(0, 14), rtxt, a, 8, HORIZONTAL_ALIGNMENT_CENTER, 640.0)
	var left := rooms.alive_count()
	var status := room.title
	if rooms.combat_active:
		status += "   ENEMIES: %d   WAVE %d/%d" % [left, mini(rooms.wave_i, rooms.total_wave_count()), rooms.total_wave_count()]
	elif room.cleared:
		status += "   [CLEARED]"
	elif room.safe:
		status += "   [SAFE]"
	_txt(Vector2(0, 28), status, Color("9aa3b5"), 8, HORIZONTAL_ALIGNMENT_CENTER, 640.0)
	_draw_modules(Vector2(480, 6))
	# ---- boss bar ----
	if boss_ratio >= 0.0 and room.kind == "boss":
		var bw := 300.0
		var bp := Vector2(170, 38)
		canvas.draw_rect(Rect2(bp - Vector2(1, 1), Vector2(bw + 2, 7)), Color(0, 0, 0, 0.8))
		var bc := Pal.RED.lerp(Color.WHITE, boss_flash)
		canvas.draw_rect(Rect2(bp, Vector2(bw * clampf(boss_ratio, 0.0, 1.0), 5)), bc)
		canvas.draw_line(bp + Vector2(bw * 0.5, 0), bp + Vector2(bw * 0.5, 5), Color(1, 1, 1, 0.6), 1.0)
		_txt(bp + Vector2(0, -2), boss_name, Pal.RED, 8)
	# ---- bottom bar: heat / instability / vent / misfire ----
	var by := 318.0
	var hc := Pal.heat_color(heat)
	var heat_label := ("^ " if Settings.symbols else "") + Settings.t("heat") + " %d%%" % int(w.heat.heat)
	if w.heat.is_locked():
		heat_label = "OVERHEAT %.1fs  [Q] vent!" % w.heat.lock_t
	_txt(Vector2(10, by + 9), heat_label, Pal.RED if (w.heat.is_locked() and int(Time.get_ticks_msec() / 150) % 2 == 0) else hc)
	var bar := Rect2(10, by + 12, 160, 7)
	canvas.draw_rect(bar.grow(1), Color(0, 0, 0, 0.8))
	canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * heat, bar.size.y)), hc.lerp(Color.WHITE, 0.3 * pulse * heat))
	for i in range(1, 10):
		canvas.draw_line(bar.position + Vector2(bar.size.x * i / 10.0, 0), bar.position + Vector2(bar.size.x * i / 10.0, bar.size.y), Color(0, 0, 0, 0.5), 1.0)
	var inst := w.instab.value()
	var ic := Pal.VIOLET if inst < 75.0 else Pal.VIOLET.lerp(Color.WHITE, 0.5 * pulse)
	var jit := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (inst / 100.0) * 1.2
	_txt(Vector2(10, by + 31) + jit, ("# " if Settings.symbols else "") + Settings.t("instability") + " %d%%" % int(inst) + ("  HIGH RISK" if inst >= 75.0 else ""), ic)
	var ibar := Rect2(10, by + 34, 160, 5)
	canvas.draw_rect(ibar.grow(1), Color(0, 0, 0, 0.8))
	canvas.draw_rect(Rect2(ibar.position, Vector2(ibar.size.x * inst / 100.0, ibar.size.y)), ic)
	canvas.draw_line(ibar.position + Vector2(ibar.size.x * 0.75, -1), ibar.position + Vector2(ibar.size.x * 0.75, 6), Color(1, 1, 1, 0.7), 1.0)
	# vent readiness
	var vx := 190.0
	var vready := w.heat.vent_ready()
	var vcol := Pal.RED if vready else Color("5a5f6b")
	_txt(Vector2(vx, by + 9), "VENT [Q]" + (" READY" if vready else (" %.1fs" % w.heat.vent_cd if w.heat.vent_cd > 0.0 else " (need heat)")), vcol)
	var vb := Rect2(vx, by + 12, 70, 5)
	canvas.draw_rect(vb.grow(1), Color(0, 0, 0, 0.8))
	var vfill := 1.0 - w.heat.vent_cd / HeatSystem.VENT_COOLDOWN
	canvas.draw_rect(Rect2(vb.position, Vector2(vb.size.x * vfill, vb.size.y)), vcol)
	# dash
	_txt(Vector2(vx, by + 31), "DASH [SPACE]", Pal.CYAN if player.dash_cd <= 0.0 else Color("5a5f6b"))
	canvas.draw_rect(Rect2(vx, by + 34, 70.0 * (1.0 - player.dash_cd / Player.DASH_COOLDOWN), 3), Pal.CYAN if player.dash_cd <= 0.0 else Color("5a5f6b"))
	# misfire risk
	var risk := w.instab.chance() * 100.0
	var nm := w.instab.next_misfire
	var rx := 275.0
	if nm != &"":
		var info: Dictionary = ModuleDB.MISFIRES[nm]
		var col: Color = info["color"]
		var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.02)
		col.a = blink
		_txt(Vector2(rx, by + 9), "! NEXT SHOT MISFIRES: " + info["name"], col)
		_txt(Vector2(rx, by + 19), info["desc"], Color(col.r, col.g, col.b, 0.8))
	else:
		_txt(Vector2(rx, by + 9), "MISFIRE RISK %.0f%%/shot  (next shot: clean)" % risk, Color("7d8596"))
	var pool_txt := ""
	for id in w.loadout.get_misfire_pool():
		pool_txt += "%s " % ModuleDB.MISFIRES[id]["symbol"]
	_txt(Vector2(rx, by + 31), "Traits: " + pool_txt + ("+GLITCH" if inst >= 75.0 else ""), Color("7d8596"))
	# active misfire feed
	if misfire_t > 0.0:
		var mc := misfire_col
		mc.a = clampf(misfire_t, 0.0, 1.0)
		_txt(Vector2(0, 62), misfire_msg, mc, 8, HORIZONTAL_ALIGNMENT_CENTER, 640.0)
	# toasts
	var ty := 76.0
	for t in toasts:
		var col2: Color = t["c"]
		col2.a = clampf(minf(t["t"] * 4.0, (4.0 - t["t"]) * 2.0), 0.0, 1.0)
		_txt(Vector2(0, ty), t["s"], col2, 8, HORIZONTAL_ALIGNMENT_CENTER, 640.0)
		ty += 11.0
	# heat rim fallback (shader does the real glow): pulsing frame at high heat
	if heat > 0.7:
		var ra := (heat - 0.7) / 0.3 * (0.35 + 0.35 * pulse)
		canvas.draw_rect(Rect2(1, 1, 638, 358), Color(1, 0.15, 0.05, ra), false, 2.0)
	_draw_reticle(w, heat, pulse)
	if Settings.show_fps:
		_txt(Vector2(600, 350), "%d fps" % Engine.get_frames_per_second(), Color.WHITE)

func _draw_hearts(p: Vector2) -> void:
	var n := Game.max_hp / 2
	for i in n:
		var hp_here := clampi(Game.hp - i * 2, 0, 2)
		var c := p + Vector2(i * 14.0, 0)
		var beat := 1.0 + 0.1 * sin(Juice.phase * 1.5 + i) * (1.0 if Game.hp <= 2 else 0.4)
		_heart(c, 5.0 * beat, hp_here)

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
		var r := Rect2(p + Vector2(0, i * 14.0), Vector2(150, 12))
		canvas.draw_rect(r, Color(0, 0, 0, 0.7))
		canvas.draw_rect(Rect2(r.position, Vector2(3, 12)), m.color)
		_txt(r.position + Vector2(6, 9), "%s %s" % [m.symbol if Settings.symbols else "", m.display_name], m.color.lerp(Color.WHITE, 0.4), 8, HORIZONTAL_ALIGNMENT_LEFT, 140.0)
		i += 1

func _draw_reticle(w: WeaponController, heat: float, pulse: float) -> void:
	var p := player.get_viewport().get_mouse_position()
	if player.stick_aim or player.override_active:
		p = player.get_viewport().get_canvas_transform() * player.aim_target
	var rate := lerpf(1.0, 3.0, heat)
	var r := 6.0 + heat * 8.0 + 1.5 * sin(Juice.phase * rate) * (0.4 + heat)
	var col := Pal.CYAN.lerp(Pal.RED, heat)
	canvas.draw_arc(p, r, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.5), 1.0)
	# circular heat fill
	canvas.draw_arc(p, r + 2.0, -PI * 0.5, -PI * 0.5 + TAU * heat, 32, Pal.heat_color(heat), 2.0)
	if w.charging:
		canvas.draw_arc(p, r - 2.0, -PI * 0.5, -PI * 0.5 + TAU * w.charge, 24, Color.WHITE, 1.0)
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		canvas.draw_line(p + d * (r - 3.0), p + d * (r + 1.0 - heat * 2.0), col, 1.0)
	canvas.draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1, 1)), Color.WHITE)
	if w.heat.is_locked():
		canvas.draw_line(p + Vector2(-5, -5), p + Vector2(5, 5), Pal.RED, 1.0)
		canvas.draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), Pal.RED, 1.0)
