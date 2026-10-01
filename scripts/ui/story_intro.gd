extends Control
## Short pre-run story beat (typewriter). Any key advances, ESC skips - never a long wait.

const LINES := [
	"CINDERFALL. THE FURNACE UNDERNEATH IS RUNNING A FEVER.",
	"VULCAN-IX, THE REACTOR CORE, WAS NEVER SHUT DOWN. THE CITY NEEDS ITS HEAT.",
	"NOW THE PIPES GROW SLIME AND THE MACHINES ARE LEARNING TO WANT THINGS.",
	"MARA VEX:  \"You've got scrap, a bench and a bad idea. Build the gun. Don't blow yourself up.\"\n\"...Much.\"",
]

var idx := 0
var shown := 0.0
var t := 0.0
var _font: Font
var _done := false

func _ready() -> void:
	_font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.start_music()
	Audio.set_heat(0.3, 0.0)

func _exit_tree() -> void:
	Audio.stop_music()

func _input(e: InputEvent) -> void:
	if _done:
		return
	if e.is_action_pressed("ui_cancel"):
		_finish()
	elif (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed) or (e is InputEventJoypadButton and e.pressed):
		if shown < LINES[idx].length():
			shown = LINES[idx].length()
		else:
			idx += 1
			shown = 0.0
			Audio.ui("ui_move")
			if idx >= LINES.size():
				_finish()

func _finish() -> void:
	_done = true
	Router.go("run")

func _process(dt: float) -> void:
	t += dt
	if idx < LINES.size():
		var before := int(shown)
		shown = minf(shown + dt * 38.0, float(LINES[idx].length()))
		if int(shown) != before and int(shown) % 3 == 0:
			Audio.play("ui_move", 1.6, -16.0, "UI")
	Juice.phase += TAU * 1.2 * dt
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Pal.BG)
	var beat := 0.5 + 0.5 * sin(t * 2.4)
	for i in 6:
		var r := 30.0 + i * 24.0 + beat * 6.0
		draw_arc(Vector2(320, 180), r, 0.0, TAU, 48, Color(1.0, 0.25, 0.08, 0.28 - i * 0.04), 2.0)
	draw_circle(Vector2(320, 180), 16.0 + beat * 4.0, Color(1.0, 0.3, 0.1, 0.5))
	draw_circle(Vector2(320, 180), 7.0, Color(1, 0.9, 0.6))
	if idx < LINES.size():
		var txt: String = LINES[idx].substr(0, int(shown))
		var y := 270.0
		for line in txt.split("\n"):
			draw_string(_font, Vector2(40, y) + Vector2(1, 1), line, HORIZONTAL_ALIGNMENT_CENTER, 560.0, 8, Color(0, 0, 0, 0.9))
			draw_string(_font, Vector2(40, y), line, HORIZONTAL_ALIGNMENT_CENTER, 560.0, 8, Pal.AMBER if LINES[idx].begins_with("MARA") else Color("d6dbe6"))
			y += 12.0
	draw_string(_font, Vector2(0, 345), "[any key] next    [ESC] skip", HORIZONTAL_ALIGNMENT_CENTER, 640.0, 8, Color("5a6070"))
