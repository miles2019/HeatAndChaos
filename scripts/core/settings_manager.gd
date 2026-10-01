extends Node
## Settings, input map (remappable keyboard), accessibility and tiny EN/DE localisation.

const PATH := "user://settings.cfg"
const DEFAULT_KEYS := {
	"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"dash": KEY_SPACE, "vent": KEY_Q, "interact": KEY_E, "pause": KEY_ESCAPE,
}
const REMAPPABLE := ["move_up", "move_down", "move_left", "move_right", "dash", "vent", "interact"]

var keys: Dictionary = DEFAULT_KEYS.duplicate()
var shake := 1.0
var hitstop := 1.0
var distortion := 1.0
var flash := 1.0
var vol := {"Master": 1.0, "Music": 0.6, "SFX": 0.8, "UI": 0.7, "Feedback": 0.8}
var fullscreen := false
var auto_aim := false
var symbols := true
var language := "en"
var show_fps := false

const TEXT := {
	"start_run": {"en": "START RUN", "de": "RUN STARTEN"},
	"continue_run": {"en": "CONTINUE RUN", "de": "RUN FORTSETZEN"},
	"workshop": {"en": "WORKSHOP", "de": "WERKSTATT"},
	"codex": {"en": "CODEX", "de": "CODEX"},
	"progression": {"en": "PROGRESSION", "de": "FORTSCHRITT"},
	"settings": {"en": "SETTINGS", "de": "EINSTELLUNGEN"},
	"quit": {"en": "QUIT", "de": "BEENDEN"},
	"back": {"en": "BACK", "de": "ZURUECK"},
	"heat": {"en": "HEAT", "de": "HITZE"},
	"instability": {"en": "INSTABILITY", "de": "INSTABILITAET"},
	"resume": {"en": "RESUME", "de": "WEITER"},
	"to_menu": {"en": "SAVE & MAIN MENU", "de": "SPEICHERN & MENUE"},
}

func t(key: String) -> String:
	if TEXT.has(key):
		return TEXT[key].get(language, TEXT[key]["en"])
	return key

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	load_settings()
	rebuild_input()
	apply_all()

func _setup_buses() -> void:
	for b in ["Music", "SFX", "UI", "Feedback"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")

func apply_all() -> void:
	for b in vol:
		var idx := AudioServer.get_bus_index(b)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(vol[b], 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	shake = cfg.get_value("fx", "shake", shake)
	hitstop = cfg.get_value("fx", "hitstop", hitstop)
	distortion = cfg.get_value("fx", "distortion", distortion)
	flash = cfg.get_value("fx", "flash", flash)
	for b in vol:
		vol[b] = cfg.get_value("audio", b, vol[b])
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	auto_aim = cfg.get_value("game", "auto_aim", auto_aim)
	symbols = cfg.get_value("game", "symbols", symbols)
	language = cfg.get_value("game", "language", language)
	show_fps = cfg.get_value("game", "show_fps", show_fps)
	for a in REMAPPABLE:
		keys[a] = cfg.get_value("keys", a, keys[a])

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("fx", "shake", shake)
	cfg.set_value("fx", "hitstop", hitstop)
	cfg.set_value("fx", "distortion", distortion)
	cfg.set_value("fx", "flash", flash)
	for b in vol:
		cfg.set_value("audio", b, vol[b])
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("game", "auto_aim", auto_aim)
	cfg.set_value("game", "symbols", symbols)
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "show_fps", show_fps)
	for a in REMAPPABLE:
		cfg.set_value("keys", a, keys[a])
	cfg.save(PATH)

func reset_keys() -> void:
	keys = DEFAULT_KEYS.duplicate()
	rebuild_input()

func rebuild_input() -> void:
	for a in ["move_up", "move_down", "move_left", "move_right", "aim_up", "aim_down", "aim_left", "aim_right",
			"shoot", "dash", "vent", "interact", "pause", "preset_1", "preset_2", "preset_3"]:
		if InputMap.has_action(a):
			InputMap.erase_action(a)
		InputMap.add_action(a, 0.25)
	for a in ["move_up", "move_down", "move_left", "move_right", "dash", "vent", "interact", "pause"]:
		_key(a, keys[a])
	_key("move_up", KEY_UP)
	_key("move_down", KEY_DOWN)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_RIGHT)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_mouse("shoot", MOUSE_BUTTON_LEFT)
	_axis("shoot", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_joy("shoot", JOY_BUTTON_RIGHT_SHOULDER)
	_mouse("vent", MOUSE_BUTTON_RIGHT)
	_joy("vent", JOY_BUTTON_B)
	_joy("dash", JOY_BUTTON_A)
	_joy("dash", JOY_BUTTON_LEFT_SHOULDER)
	_joy("interact", JOY_BUTTON_X)
	_joy("pause", JOY_BUTTON_START)
	_key("preset_1", KEY_1)
	_key("preset_2", KEY_2)
	_key("preset_3", KEY_3)

func _key(action: String, code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code as Key
	InputMap.action_add_event(action, e)

func _mouse(action: String, b: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = b
	InputMap.action_add_event(action, e)

func _joy(action: String, b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	InputMap.action_add_event(action, e)

func _axis(action: String, axis: JoyAxis, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = v
	InputMap.action_add_event(action, e)
