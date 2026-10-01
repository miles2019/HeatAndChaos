class_name RoomManager
extends Node
## Room graph (linear chain for the prototype), doors, wave spawning and room_cleared.
##   [Start] - [Combat 1] - [Workshop] - [Combat 2] - [Boss]

signal room_entered(room)

const ORDER := ["start", "combat1", "workshop", "combat2", "boss"]

var rooms: Array[Room] = []
var current: Room
var world
var wave_i := 0
var wave_delay := 0.0
var pending := 0
var combat_active := false
var transition_lock := 0.0
var _statics_done: Array = []

func build(parent: Node2D) -> void:
	for i in ORDER.size():
		var r := Room.new()
		r.name = "Room_%s" % ORDER[i]
		r.setup(ORDER[i], i)
		r.visible = false
		r.process_mode = Node.PROCESS_MODE_DISABLED
		parent.add_child(r)
		rooms.append(r)
	for i in Game.cleared_rooms:
		rooms[int(i)].cleared = true

func enter(i: int, side: int) -> void:
	if current:
		current.visible = false
		current.process_mode = Node.PROCESS_MODE_DISABLED
	current = rooms[i]
	current.visible = true
	current.process_mode = Node.PROCESS_MODE_INHERIT
	Juice.field = current.particles
	Game.room_index = i
	world.clear_projectiles()
	pending = 0
	var pl = world.player
	if side == 0:
		pl.position = Vector2(Room.INNER.position.x + 18.0, Room.CY)
	elif side == 1:
		pl.position = Vector2(Room.INNER.end.x - 18.0, Room.CY)
	else:
		pl.position = Vector2(Room.INNER.position.x + 60.0, Room.CY)
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
		wave_delay = 1.1
		Audio.play("door", 0.8)
	else:
		current.set_doors_closed(false)
	if current.kind == "workshop":
		Game.toast.emit("MARA VEX: 'Bench is hot. Rebuild that gun, Runner.'", Pal.AMBER)
	elif current.kind == "start" and Game.room_index == 0 and not Game.resume_requested:
		Game.toast.emit("MARA VEX: 'Reactor core's down the shaft. Try not to melt.'", Pal.AMBER)
	elif current.kind == "boss":
		Game.toast.emit("WARNING: VULCAN-IX ONLINE", Pal.RED)
	room_entered.emit(current)
	Game.checkpoint()

func alive_count() -> int:
	return current.alive_enemies() + pending if current else 0

func total_wave_count() -> int:
	return current.waves.size() if current else 0

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
					wave_delay = 0.8
				elif current.kind != "boss":
					_clear_room()
	# door traversal
	var pl = world.player
	if transition_lock <= 0.0 and not current.doors_closed and not pl.dead:
		if pl.position.x < Room.INNER.position.x - 8.0 and current.has_left:
			enter(current.index - 1, 1)
		elif pl.position.x > Room.INNER.end.x + 8.0 and current.has_right:
			enter(current.index + 1, 0)

func _spawn_wave(kinds: Array) -> void:
	var pl = world.player
	for k in kinds:
		if k == "boss":
			var b := VulcanBoss.new()
			b.room = current
			b.position = Vector2(320, 150)
			current.content.add_child(b)
			current.enemies.append(b)
			continue
		var pos := current.spawn_point_away(pl.position, 110.0)
		pending += 1
		var kind: String = k
		world.spawn_effect("spawn", pos, {"duration": 0.7 + randf() * 0.3, "cb": func() -> void: _create(kind, pos)})

func _create(kind: String, pos: Vector2) -> void:
	pending = maxi(0, pending - 1)
	if current == null:
		return
	var e: EnemyBase
	match kind:
		"stalker": e = StalkerEnemy.new()
		"bulwark": e = BulwarkEnemy.new()
		"mortar": e = MortarMite.new()
		_: return
	e.room = current
	e.position = pos
	current.content.add_child(e)
	current.enemies.append(e)
	Juice.burst(pos, Pal.RED, 8, 100.0)

func _clear_room() -> void:
	combat_active = false
	current.cleared = true
	if not Game.cleared_rooms.has(current.index):
		Game.cleared_rooms.append(current.index)
	Game.stats["rooms"] += 1
	current.set_doors_closed(false)
	Audio.play("door", 1.2)
	Juice.flash(Pal.LIME, 0.15)
	Juice.ring(Vector2(320, 180), Pal.LIME, 200.0, 0.6)
	Game.toast.emit("ROOM CLEARED", Pal.LIME)
	Game.room_cleared.emit(current)
	# rewards: a module crate + a chance of a heart
	var pool: Array = []
	for id in ModuleDB.order:
		if Save.is_unlocked(id) and not Game.owns(id):
			pool.append(id)
	var pick: StringName = &""
	if pool.is_empty():
		pick = ModuleDB.order.pick_random()
		while not Save.is_unlocked(pick):
			pick = ModuleDB.order.pick_random()
	else:
		pick = pool.pick_random()
	world.spawn_pickup("module", Vector2(320, 150), 1, pick)
	if randf() < 0.6 or Game.hp < Game.max_hp:
		world.spawn_pickup("heart", Vector2(290, 190), 1)
	Game.checkpoint()
