class_name RoomManager
extends Node
## Room graph from RunPlan (lazy room creation), doors on four sides, wave spawning, rewards, room_cleared.

signal room_entered(room)

var plan: Array = []
var rooms: Dictionary = {}
var current: Room
var world
var parent_node: Node2D
var wave_i := 0
var wave_delay := 0.0
var pending := 0
var combat_active := false
var transition_lock := 0.0
var visited: Array = []
var _statics_done: Array = []
var _last_act := 0

func build(parent: Node2D) -> void:
	parent_node = parent
	plan = RunPlan.build(Game.run_seed)

func get_room(i: int) -> Room:
	if rooms.has(i):
		return rooms[i]
	var r := Room.new()
	r.name = "Room_%d" % i
	r.cleared = Game.cleared_rooms.has(i)
	r.setup(plan[i])
	r.visible = false
	r.process_mode = Node.PROCESS_MODE_DISABLED
	parent_node.add_child(r)
	rooms[i] = r
	return r

func enter(i: int, side: int) -> void:
	if current:
		current.visible = false
		current.process_mode = Node.PROCESS_MODE_DISABLED
	current = get_room(i)
	current.visible = true
	current.process_mode = Node.PROCESS_MODE_INHERIT
	Juice.field = current.particles
	Game.room_index = i
	if not visited.has(i):
		visited.append(i)
	world.clear_projectiles()
	pending = 0
	var pl = world.player
	if side >= 0:
		pl.position = current.entry_pos(side)
	else:
		pl.position = current.center() + Vector2(-120, 0)
	pl.vel = Vector2.ZERO
	pl.ext = Vector2.ZERO
	transition_lock = 0.5
	if not _statics_done.has(i):
		_statics_done.append(i)
		for a in current.pending_acid:
			world.spawn_effect("acid", a[0], {"radius": a[1], "duration": -1.0, "hostile": true})
	combat_active = false
	if not current.cleared and not current.waves.is_empty():
		current.set_doors_closed(true)
		combat_active = true
		wave_i = 0
		wave_delay = 1.2
		Audio.play("door", 0.8)
	else:
		current.set_doors_closed(false)
	if current.act != _last_act:
		_last_act = current.act
		Game.act = current.act
		Game.toast.emit("ACT %d: %s" % [current.act, Room.THEMES[current.act - 1]["name"]], Pal.AMBER)
	match current.kind:
		"workshop":
			Game.toast.emit("MARA VEX: 'Bench is hot. Rebuild that gun, Runner.'", Pal.AMBER)
		"start":
			if not Game.resume_requested:
				Game.toast.emit("MARA VEX: 'Reactor core's down the shaft. Try not to melt.'", Pal.AMBER)
		"boss":
			Game.toast.emit("WARNING: %s" % ["VULCAN-IX ONLINE", "THE SLIME-FUSED ENGINE AWAKENS", "MAGNET WARDEN: BUILD SCAN COMPLETE", "THE PULSE LOOKS BACK AT YOU"][current.act - 1], Pal.RED)
		"cursed":
			Game.toast.emit("CURSED CHAMBER: power has a price.", Pal.VIOLET)
		"secret":
			if not current.cleared:
				current.cleared = true
				if not Game.cleared_rooms.has(i):
					Game.cleared_rooms.append(i)
				world.spawn_pickup("relic", current.center() + Vector2(-40, 0), 1)
				world.spawn_pickup("module", current.center() + Vector2(40, 0), 1, _random_module(true))
				world.spawn_pickup("heart", current.center() + Vector2(0, 50), 1)
				Game.toast.emit("SECRET CACHE FOUND", Pal.AMBER)
	world.snap_camera()
	room_entered.emit(current)
	Game.checkpoint()

func _random_module(any_unlock: bool) -> StringName:
	var pool: Array = []
	for id in ModuleDB.order:
		if not Game.owns(id) and (any_unlock or Save.is_unlocked(id)):
			pool.append(id)
	if pool.is_empty():
		pool = ModuleDB.order.filter(func(id: StringName) -> bool: return Save.is_unlocked(id))
	return pool.pick_random()

func alive_count() -> int:
	return current.alive_enemies() + pending if current else 0

func total_wave_count() -> int:
	return current.waves.size() if current else 0

func bosses_remaining() -> int:
	var n := 0
	for e in current.enemies:
		if is_instance_valid(e) and e is BossBase and not e.dead:
			n += 1
	return n

func update(dt: float) -> void:
	if current == null:
		return
	transition_lock = maxf(0.0, transition_lock - dt)
	current.enemies = current.enemies.filter(func(e: Variant) -> bool: return is_instance_valid(e) and not e.dead)
	if combat_active:
		if pending == 0 and current.enemies.is_empty():
			wave_delay -= dt
			if wave_delay <= 0.0:
				if wave_i < current.waves.size():
					_spawn_wave(current.waves[wave_i])
					wave_i += 1
					wave_delay = 0.9
				elif current.kind != "boss":
					_clear_room()
	var pl = world.player
	if transition_lock <= 0.0 and not current.doors_closed and not pl.dead:
		var inn := current.inner
		for side in current.exits:
			if current.is_sealed(side):
				continue
			var out := false
			match side:
				Room.L: out = pl.position.x < inn.position.x - 14.0
				Room.R: out = pl.position.x > inn.end.x + 14.0
				Room.U: out = pl.position.y < inn.position.y - 14.0
				_: out = pl.position.y > inn.end.y + 14.0
			if out:
				enter(current.exits[side], side ^ 1)
				break

func _spawn_wave(kinds: Array) -> void:
	var pl = world.player
	for k in kinds:
		var kind: String = k
		if kind.begins_with("boss"):
			var b: BossBase
			match kind:
				"boss1": b = VulcanBoss.new()
				"boss2": b = SlimeEngineBoss.new()
				"boss3": b = MagnetWarden.new()
				_: b = PulseBoss.new()
			b.room = current
			b.position = current.center() + Vector2(0, -50)
			current.content.add_child(b)
			current.enemies.append(b)
			continue
		var pos := current.spawn_point_away(pl.position, 160.0)
		pending += 1
		world.spawn_effect("spawn", pos, {"duration": 0.7 + randf() * 0.3, "cb": func() -> void: create_enemy(kind, pos)})

func create_enemy(kind: String, pos: Vector2, small: bool = false) -> EnemyBase:
	pending = maxi(0, pending - 1) if not small else pending
	if current == null:
		return null
	var e: EnemyBase
	match kind:
		"stalker": e = StalkerEnemy.new()
		"bulwark": e = BulwarkEnemy.new()
		"mortar": e = MortarMite.new()
		"drone": e = DroneEnemy.new()
		"turret": e = TurretEnemy.new()
		"slime": e = SlimeEnemy.new()
		"brute": e = BruteEnemy.new()
		"hunter": e = HunterEnemy.new()
		_: return null
	e.room = current
	e.position = pos
	if small and e is SlimeEnemy:
		e.tiny = true
	current.content.add_child(e)
	current.enemies.append(e)
	Juice.burst(pos, Pal.RED, 8, 100.0)
	return e

func _clear_room() -> void:
	combat_active = false
	current.cleared = true
	if not Game.cleared_rooms.has(current.index):
		Game.cleared_rooms.append(current.index)
	Game.stats["rooms"] += 1
	current.set_doors_closed(false)
	Audio.play("door", 1.2)
	Juice.flash(Pal.LIME, 0.15)
	Juice.ring(current.center(), Pal.LIME, 260.0, 0.6)
	Game.toast.emit("ROOM CLEARED", Pal.LIME)
	Game.room_cleared.emit(current)
	var c := current.center()
	match current.kind:
		"cursed":
			var ids: Array = []
			for i in 3:
				var id := _random_module(true)
				while ids.has(id) and ModuleDB.order.size() > 4:
					id = _random_module(true)
				ids.append(id)
				var costs := ["hp", "inst"]
				world.spawn_pickup("cursed", c + Vector2(-110 + i * 110, 0), 1, id, costs[(i + randi()) % 2])
			Game.toast.emit("TAKE ONE. THE OTHERS VANISH.", Pal.VIOLET)
		_:
			world.spawn_pickup("module", c + Vector2(0, -20), 1, _random_module(false))
			if current.kind == "elite":
				world.spawn_pickup("relic", c + Vector2(50, 0), 1)
			if randf() < 0.6 or Game.hp < Game.max_hp:
				world.spawn_pickup("heart", c + Vector2(-40, 20), 1)
	Game.checkpoint()

## Called by the run controller when the last boss body dies.
func boss_cleared() -> void:
	combat_active = false
	current.cleared = true
	if not Game.cleared_rooms.has(current.index):
		Game.cleared_rooms.append(current.index)
	Game.stats["rooms"] += 1
	if current.act < 4:
		current.set_doors_closed(false)
		var c := current.center()
		world.spawn_pickup("relic", c + Vector2(-40, 30), 1)
		world.spawn_pickup("heart", c + Vector2(40, 30), 1)
		world.spawn_pickup("module", c + Vector2(0, 60), 1, _random_module(true))
		Game.hp = mini(Game.hp + 2, Game.max_hp)
		Game.player_hp_changed.emit(Game.hp, Game.max_hp)
	Game.checkpoint()
