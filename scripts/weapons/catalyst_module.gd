class_name CatalystModule
extends WeaponModule

enum Kind { PLAIN, TOXIC, SHOCK, IMPLOSION }
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

func on_vent(ctx: Dictionary) -> void:
	var world = Game.world
	if world == null:
		return
	var pos: Vector2 = ctx["pos"]
	var heat: float = ctx["heat"]
	match kind:
		Kind.TOXIC:
			if heat >= 0.85:
				world.ignite_acid()     # panic-vent at ~90 heat detonates every poison cloud
			world.spawn_effect("acid", pos, {"radius": 46.0 + heat * 40.0, "duration": 9.0, "hostile": false, "cloud": true})
		Kind.SHOCK:
			world.spawn_effect("shock", pos, {"radius": 100.0 + heat * 40.0, "force": 520.0, "damage": 14.0, "stun": 1.6})
		Kind.IMPLOSION:
			world.spawn_effect("implode", pos, {"radius": 120.0 + heat * 30.0, "delay": 0.55, "damage": 40.0})
