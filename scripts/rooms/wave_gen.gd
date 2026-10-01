class_name WaveGen
extends RefCounted
## Procedural wave composition per act. Enemy ids map to scripts in RoomManager._create().

const POOLS := [
	[["stalker", 4], ["drone", 4], ["bulwark", 2], ["mortar", 2]],
	[["slime", 4], ["stalker", 2], ["mortar", 2], ["turret", 2], ["bulwark", 1], ["drone", 2]],
	[["hunter", 3], ["bulwark", 3], ["turret", 2], ["stalker", 2], ["drone", 3], ["brute", 1]],
	[["hunter", 2], ["brute", 2], ["slime", 2], ["turret", 2], ["stalker", 2], ["bulwark", 2], ["mortar", 2], ["drone", 2]],
]

static func make(kind: String, act: int, size: Vector2, rng: RandomNumberGenerator) -> Array:
	if kind == "boss":
		return [["boss%d" % act]]
	if kind in ["start", "workshop", "secret"]:
		return []
	var pool: Array = POOLS[act - 1]
	var n_waves := rng.randi_range(2, 3) + (1 if act >= 3 else 0)
	if kind == "cursed":
		n_waves = 1
	var waves: Array = []
	for w in n_waves:
		var count := clampi(4 + act * 2 + rng.randi_range(0, 3) + int(size.x * size.y / 300000.0) + w, 5, 16)
		if kind == "cursed":
			count = 5 + act
		var wave: Array = []
		for i in count:
			wave.append(_pick(pool, rng))
		if kind in ["elite", "cursed"]:
			for i in mini(1 + act / 2, wave.size()):
				wave[i] = "brute"
		waves.append(wave)
	return waves

static func _pick(pool: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for e in pool:
		total += int(e[1])
	var r := rng.randi_range(1, total)
	for e in pool:
		r -= int(e[1])
		if r <= 0:
			return e[0]
	return pool[0][0]
