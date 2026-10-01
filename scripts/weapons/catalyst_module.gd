class_name CatalystModule
extends WeaponModule

enum Kind { PLAIN, TOXIC, SHOCK, IMPLOSION, VOLCANIC, STASIS, SPLINTER, STATIC, TWIN }
@export var kind: Kind = Kind.PLAIN

func _init() -> void:
	slot = &"catalyst"

func modify_projectile(p) -> void:
	p.catalyst = self
	if kind != Kind.PLAIN:
		p.color = p.color.lerp(color, 0.75)
	if kind == Kind.IMPLOSION and (p.big or p.orbit_state != 0):
		p.pull_radius = 78.0
		p.pull_force = 330.0
	if kind == Kind.TWIN and p.faction == 0 and Game.world:
		var c: Projectile = Game.world.acquire_projectile()
		if c:
			c.copy_from(p)
			c.rotate_dir(0.24)
			p.rotate_dir(-0.08)
			c.color = color

func on_impact(ctx: Dictionary) -> void:
	var world = Game.world
	if world == null:
		return
	var pos: Vector2 = ctx["pos"]
	var k: String = ctx["kind"]
	match kind:
		Kind.TOXIC:
			var r := 13.0
			if k == "hit":
				r = 17.0
			elif k == "bounce":
				r = 11.0
			world.spawn_effect("acid", pos, {"radius": r, "duration": 7.5, "hostile": false})
		Kind.SHOCK:
			if k == "hit":
				world.spawn_effect("shock", pos, {"radius": 46.0, "force": 300.0, "damage": 6.0, "stun": 0.9})
		Kind.IMPLOSION:
			if k == "hit" or k == "ground":
				world.spawn_effect("implode", pos, {"radius": 58.0, "delay": 0.45, "damage": 16.0})
		Kind.VOLCANIC:
			if k == "hit" or k == "ground":
				world.spawn_effect("shock", pos, {"radius": 38.0, "force": 130.0, "damage": 11.0, "stun": 0.2, "color": Pal.RED, "dur": 0.25})
				Juice.burst(pos, Pal.AMBER, 8, 120.0, Vector2.ZERO, TAU, 0.5, 2.0, ParticleField.EMBER)
		Kind.STASIS:
			if k == "hit" or k == "ground":
				world.spawn_effect("stasis", pos, {"radius": 46.0, "duration": 3.5})
		Kind.SPLINTER:
			if k == "hit" or k == "ground":
				_shards(pos, 5, false, ctx.get("dir", Vector2.RIGHT))
		Kind.STATIC:
			if k == "hit":
				_zap(pos, 3, 95.0, 6.0, ctx.get("enemy"))

func _shards(pos: Vector2, n: int, ring: bool, dir: Vector2) -> void:
	var base := randf() * TAU
	for i in n:
		var p: Projectile = Game.world.acquire_projectile()
		if p == null:
			return
		var a := base + TAU * float(i) / float(n)
		p.setup({"dir": Vector2.from_angle(a), "speed": 230.0, "damage": 3.0, "lifetime": 0.45, "size": 2.0, "pierce": 0, "knockback": 20.0, "color": color}, pos, 0)
	Juice.burst(pos, color, 6, 90.0)

func _zap(pos: Vector2, n: int, rng: float, dmg: float, skip) -> void:
	var room = Game.world.current_room()
	var cands: Array = []
	for e in room.enemies:
		if e != skip and is_instance_valid(e) and not e.dead and e.spawn_t <= 0.0 and e.position.distance_to(pos) < rng:
			cands.append(e)
	cands.sort_custom(func(a, b) -> bool: return a.position.distance_to(pos) < b.position.distance_to(pos))
	var prev := pos
	for i in mini(n, cands.size()):
		var e = cands[i]
		Game.world.spawn_effect("arc", prev, {"a": prev, "b": e.position})
		e.take_hit(dmg, (e.position - prev).normalized(), 30.0, false)
		prev = e.position

func on_vent(ctx: Dictionary) -> void:
	var world = Game.world
	if world == null:
		return
	var pos: Vector2 = ctx["pos"]
	var heat: float = ctx["heat"]
	match kind:
		Kind.TOXIC:
			if heat >= 0.85:
				world.ignite_acid()
			world.spawn_effect("acid", pos, {"radius": 46.0 + heat * 40.0, "duration": 9.0, "hostile": false, "cloud": true})
		Kind.SHOCK:
			world.spawn_effect("shock", pos, {"radius": 100.0 + heat * 40.0, "force": 520.0, "damage": 14.0, "stun": 1.6})
		Kind.IMPLOSION:
			world.spawn_effect("implode", pos, {"radius": 120.0 + heat * 30.0, "delay": 0.55, "damage": 40.0})
		Kind.VOLCANIC:
			world.spawn_effect("shock", pos, {"radius": 160.0 + heat * 60.0, "force": 200.0, "damage": 30.0 + heat * 30.0, "stun": 0.6, "color": Pal.AMBER, "dur": 0.5})
		Kind.STASIS:
			world.spawn_effect("stasis", pos, {"radius": 170.0, "duration": 5.0})
		Kind.SPLINTER:
			_shards(pos, 18, true, Vector2.RIGHT)
		Kind.STATIC:
			_zap(pos, 8, 220.0, 12.0, null)
