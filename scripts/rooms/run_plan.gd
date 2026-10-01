class_name RunPlan
extends RefCounted
## Builds the whole run as room specs: 4 acts x (combat, combat+secret, workshop+cursed, combat, elite, boss).
## Main path runs left->right through L/R doors; secret and cursed rooms hang off the top wall (U).

const ACT_SEQ := ["combat", "combat", "workshop", "combat", "elite", "boss"]

static func build(run_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var rooms: Array = []
	var prev_main := -1
	for act in range(1, 5):
		var seq: Array = ACT_SEQ.duplicate()
		if act == 1:
			seq.push_front("start")
		var col := 0
		for k in seq:
			var idx := _add(rooms, k, act, rng, col, 0, run_seed)
			if prev_main >= 0:
				rooms[prev_main]["exits"][Room.R] = idx
				rooms[idx]["exits"][Room.L] = prev_main
			prev_main = idx
			if k == "combat" and col == (2 if act == 1 else 1) and not rooms[idx].has("secret_done"):
				var s := _add(rooms, "secret", act, rng, col, -1, run_seed)
				rooms[idx]["exits"][Room.U] = s
				rooms[idx]["crack_sides"] = [Room.U]
				rooms[idx]["secret_done"] = true
				rooms[s]["exits"][Room.D] = idx
			if k == "workshop":
				var c := _add(rooms, "cursed", act, rng, col, -1, run_seed)
				rooms[idx]["exits"][Room.U] = c
				rooms[c]["exits"][Room.D] = idx
			col += 1
	return rooms

static func _add(rooms: Array, kind: String, act: int, rng: RandomNumberGenerator, col: int, row: int, run_seed: int) -> int:
	var sizes := {
		"start": [Vector2(640, 400)], "workshop": [Vector2(720, 440)], "secret": [Vector2(560, 360)],
		"cursed": [Vector2(800, 520)], "elite": [Vector2(1100, 700)], "boss": [Vector2(1000, 680)],
		"combat": [Vector2(880, 560), Vector2(1040, 600), Vector2(960, 680), Vector2(1200, 640)],
	}
	var opts: Array = sizes[kind]
	var idx := rooms.size()
	rooms.append({
		"idx": idx, "kind": kind, "act": act, "col": col, "row": row,
		"size": opts[rng.randi() % opts.size()], "seed": run_seed * 131 + idx * 7919, "exits": {},
	})
	return idx
