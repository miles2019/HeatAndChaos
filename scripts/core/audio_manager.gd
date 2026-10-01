extends Node
## Fully procedural audio (no assets): sfx synth, dynamic heat heartbeat, drone, sound-duck.

const RATE := 22050
const POOL := 20

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _drone: AudioStreamPlayer
var _thump_t := 0.0
var heat := 0.0              # 0..1 driven by gameplay
var instability := 0.0
var music_on := false
var _duck_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_sounds()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_drone = AudioStreamPlayer.new()
	_drone.bus = "Music"
	_drone.stream = _make_drone()
	_drone.volume_db = -22.0
	add_child(_drone)

func _synth(f0: float, f1: float, dur: float, kind: int, vol: float = 0.6, noise_mix: float = 0.0, curve: float = 2.0) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / float(n)
		ph += lerpf(f0, f1, t) / float(RATE)
		var s := 0.0
		match kind:
			0: s = sin(ph * TAU)
			1: s = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
			2: s = fmod(ph, 1.0) * 2.0 - 1.0
			_: s = randf() * 2.0 - 1.0
		if noise_mix > 0.0:
			s = lerpf(s, randf() * 2.0 - 1.0, noise_mix)
		var env := pow(1.0 - t, curve) * minf(1.0, float(i) / 60.0)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w

func _make_drone() -> AudioStreamWAV:
	var n := RATE * 2
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(RATE)
		var s := sin(t * TAU * 55.0) * 0.5 + sin(t * TAU * 55.5) * 0.3 + (fmod(t * 110.0, 1.0) * 2.0 - 1.0) * 0.12
		data.encode_s16(i * 2, int(s * 0.5 * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

func _build_sounds() -> void:
	_sounds["shot"] = _synth(900.0, 260.0, 0.07, 1, 0.35)
	_sounds["shot_heavy"] = _synth(260.0, 60.0, 0.18, 2, 0.5, 0.35)
	_sounds["beam"] = _synth(120.0, 1400.0, 0.28, 2, 0.45, 0.1, 1.2)
	_sounds["charge"] = _synth(120.0, 700.0, 0.35, 2, 0.2, 0.05, 0.4)
	_sounds["hit"] = _synth(520.0, 140.0, 0.08, 1, 0.4, 0.3)
	_sounds["crit"] = _synth(1200.0, 300.0, 0.14, 1, 0.5, 0.2)
	_sounds["kill"] = _synth(300.0, 40.0, 0.25, 3, 0.5, 0.0, 1.6)
	_sounds["bounce"] = _synth(700.0, 1400.0, 0.06, 0, 0.35)
	_sounds["dash"] = _synth(1600.0, 300.0, 0.14, 3, 0.25, 0.0, 1.0)
	_sounds["vent"] = _synth(220.0, 30.0, 0.5, 3, 0.7, 0.0, 1.4)
	_sounds["misfire"] = _synth(900.0, 90.0, 0.35, 2, 0.5, 0.45, 1.0)
	_sounds["glitch"] = _synth(1800.0, 200.0, 0.3, 1, 0.4, 0.6, 0.8)
	_sounds["overheat"] = _synth(400.0, 40.0, 0.7, 2, 0.6, 0.3, 1.0)
	_sounds["pickup"] = _synth(500.0, 1500.0, 0.12, 0, 0.4, 0.0, 1.0)
	_sounds["hurt"] = _synth(300.0, 60.0, 0.3, 1, 0.55, 0.4, 1.4)
	_sounds["door"] = _synth(90.0, 50.0, 0.4, 2, 0.5, 0.3, 1.0)
	_sounds["thump"] = _synth(90.0, 36.0, 0.18, 0, 0.9, 0.0, 2.5)
	_sounds["slam"] = _synth(120.0, 30.0, 0.5, 3, 0.8, 0.0, 2.0)
	_sounds["boom"] = _synth(150.0, 25.0, 0.45, 3, 0.7, 0.0, 1.8)
	_sounds["snap"] = _synth(3000.0, 800.0, 0.025, 3, 0.25, 0.0, 1.0)
	_sounds["ui_move"] = _synth(700.0, 760.0, 0.04, 1, 0.25)
	_sounds["ui_ok"] = _synth(500.0, 1000.0, 0.1, 1, 0.3)
	_sounds["ui_back"] = _synth(700.0, 300.0, 0.1, 1, 0.3)
	_sounds["acid"] = _synth(200.0, 500.0, 0.12, 0, 0.25, 0.4)

func play(sound: String, pitch: float = 1.0, vol_db: float = 0.0, bus: String = "SFX") -> void:
	if not _sounds.has(sound) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _sounds[sound]
	p.pitch_scale = clampf(pitch * randf_range(0.96, 1.04), 0.2, 4.0)
	p.volume_db = vol_db
	p.bus = bus
	p.play()

func ui(sound: String) -> void:
	play(sound, 1.0, 0.0, "UI")

func duck(db: float = -10.0, time: float = 0.35) -> void:
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	if _duck_tween:
		_duck_tween.kill()
	var base := linear_to_db(maxf(Settings.vol["Music"], 0.0001))
	AudioServer.set_bus_volume_db(idx, base + db)
	_duck_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_duck_tween.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(idx, v), base + db, base, time)

func start_music() -> void:
	music_on = true
	if not _drone.playing:
		_drone.play()

func stop_music() -> void:
	music_on = false
	_drone.stop()

func set_heat(h: float, inst: float) -> void:
	heat = h
	instability = inst

func _process(delta: float) -> void:
	if not music_on:
		return
	_drone.pitch_scale = lerpf(0.8, 1.7, heat) + sin(Time.get_ticks_msec() * 0.01) * instability * 0.03
	_drone.volume_db = lerpf(-24.0, -14.0, heat)
	var interval := lerpf(1.1, 0.22, pow(heat, 1.2))
	_thump_t -= delta / maxf(Engine.time_scale, 0.05)
	if _thump_t <= 0.0:
		_thump_t = interval
		play("thump", lerpf(1.0, 0.7, heat), lerpf(-14.0, -6.0, heat), "Music")
