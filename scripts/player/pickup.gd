class_name Pickup
extends Node2D
## Scrap (magnetic), hearts, module crates, relics and cursed pedestals.

var kind := "scrap"
var amount := 1
var module_id: StringName = &""
var cost := ""
var vel := Vector2.ZERO
var t := 0.0
var room: Room
var _glow := ArtNode.new()
var _taken := false

func _ready() -> void:
	z_index = 1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw_fn = _draw_glow
	add_child(_glow)
	if kind == "relic" and module_id == &"":
		module_id = StringName(Game.random_relic())
		if module_id == &"":
			kind = "heart"
	if kind == "cursed":
		add_to_group("cursed_pedestal")
	vel = Vector2.from_angle(randf() * TAU) * (randf_range(40.0, 110.0) if kind == "scrap" else 0.0)

func _process(dt: float) -> void:
	if _taken:
		return
	t += dt
	var pl = Game.world.player
	vel *= exp(-dt * 4.0)
	position += vel * dt
	if room:
		var box := room.inner.grow(-6.0)
		position = Vector2(clampf(position.x, box.position.x, box.end.x), clampf(position.y, box.position.y, box.end.y))
	if pl != null and not pl.dead:
		var d: float = pl.position.distance_to(position)
		var mag := 140.0 if Game.has_relic("magnet") else 70.0
		if kind == "scrap" and t > 0.35 and d < mag:
			position += (pl.position - position).normalized() * (120.0 + (mag - d) * 4.0) * dt
		var grab := 9.0 if kind in ["scrap", "heart"] else 16.0
		if d < grab and t > 0.2:
			_collect(pl)
	queue_redraw()
	_glow.queue_redraw()

func _collect(pl) -> void:
	match kind:
		"scrap":
			Game.stats["scrap"] += amount + (1 if Game.has_relic("magnet") else 0)
			Audio.play("pickup", 1.0 + randf() * 0.4, -12.0)
			Juice.burst(position, Pal.AMBER, 3, 50.0)
		"heart":
			if Game.hp >= Game.max_hp:
				return
			pl.heal(2)
		"module", "cursed":
			var m: WeaponModule = ModuleDB.get_module(module_id)
			if kind == "cursed":
				if cost == "hp":
					pl.take_damage(2, position + Vector2(0, 8), true)
				else:
					Game.curse_inst += 15.0
					Game.loadout.recalculate()
					pl.weapon.set_loadout(Game.loadout)
				for o in get_tree().get_nodes_in_group("cursed_pedestal"):
					if o != self:
						Juice.burst(o.position, Pal.VIOLET, 10, 90.0)
						o.queue_free()
			if Game.own(module_id):
				Game.toast.emit("MODULE ACQUIRED: %s [%s]" % [m.display_name, String(m.slot).to_upper()], m.color)
				Juice.big_effect(position, m.color, 0.5)
			else:
				Game.stats["scrap"] += 10
				Save.data["dupes"] += 1
				Game.toast.emit("DUPLICATE %s -> +10 SCRAP" % m.display_name, Pal.AMBER)
			Audio.play("pickup", 0.8)
		"relic":
			var info: Array = Game.RELICS[String(module_id)]
			Game.add_relic(String(module_id))
			Game.toast.emit("RELIC: %s - %s" % [info[0], info[1]], Pal.AMBER)
			Juice.big_effect(position, Pal.AMBER, 0.7)
			Audio.play("pickup", 0.6)
	_taken = true
	queue_free()

func _draw() -> void:
	var bob := sin(t * 5.0 + position.x) * 1.5
	var f := Fonts.main()
	match kind:
		"scrap":
			var s := 1.0 + 0.2 * sin(t * 9.0)
			var p := Vector2(0, bob)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3) * s, p + Vector2(3, 0) * s, p + Vector2(0, 3) * s, p + Vector2(-3, 0) * s]), Pal.AMBER)
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)
		"heart":
			var p2 := Vector2(0, bob)
			draw_circle(p2 + Vector2(-2.2, -1.5), 2.6, Pal.RED)
			draw_circle(p2 + Vector2(2.2, -1.5), 2.6, Pal.RED)
			draw_colored_polygon(PackedVector2Array([p2 + Vector2(-4.6, -0.5), p2 + Vector2(4.6, -0.5), p2 + Vector2(0, 5)]), Pal.RED)
		"module", "cursed":
			var m: WeaponModule = ModuleDB.get_module(module_id)
			var s2 := 1.0 + 0.08 * sin(t * 6.0)
			var r := Rect2(Vector2(-7, -7 + bob) * s2, Vector2(14, 14) * s2)
			draw_rect(r, Pal.STEEL_DARK)
			draw_rect(r, m.color if kind == "module" else Pal.VIOLET, false, 1.0)
			draw_rect(r.grow(-3), m.color.darkened(0.5))
			draw_string(f, Vector2(-70, -14 + bob), m.display_name, HORIZONTAL_ALIGNMENT_CENTER, 140, 16, m.color)
			if kind == "cursed":
				draw_string(f, Vector2(-70, 28 + bob), "COST: " + ("-1 HEART" if cost == "hp" else "+15 INSTAB."), HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Pal.VIOLET)
		"relic":
			var info: Array = Game.RELICS[String(module_id)]
			var s3 := 1.0 + 0.1 * sin(t * 4.0)
			var p3 := Vector2(0, bob)
			draw_colored_polygon(PackedVector2Array([p3 + Vector2(0, -8) * s3, p3 + Vector2(6, 0) * s3, p3 + Vector2(0, 8) * s3, p3 + Vector2(-6, 0) * s3]), Pal.AMBER)
			draw_colored_polygon(PackedVector2Array([p3 + Vector2(0, -4), p3 + Vector2(3, 0), p3 + Vector2(0, 4), p3 + Vector2(-3, 0)]), Color.WHITE)
			draw_string(f, Vector2(-70, -14 + bob), info[0], HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Pal.AMBER)

func _draw_glow(c: Node2D) -> void:
	var col := Pal.AMBER
	var r := 9.0
	if kind == "heart":
		col = Pal.RED
	elif kind == "module":
		col = ModuleDB.get_module(module_id).color
		r = 22.0 + 4.0 * sin(t * 6.0)
	elif kind == "cursed":
		col = Pal.VIOLET
		r = 24.0 + 6.0 * sin(t * 9.0)
	elif kind == "relic":
		r = 26.0 + 4.0 * sin(t * 4.0)
	Juice.glow(c, Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.5))
