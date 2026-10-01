class_name Pickup
extends Node2D
## Scrap (magnetic), hearts and module crates.

var kind := "scrap"
var amount := 1
var module_id: StringName = &""
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
	vel = Vector2.from_angle(randf() * TAU) * (randf_range(40.0, 110.0) if kind == "scrap" else 0.0)

func _process(dt: float) -> void:
	if _taken:
		return
	t += dt
	var pl = Game.world.player
	vel *= exp(-dt * 4.0)
	position += vel * dt
	var box := Room.INNER.grow(-6.0)
	position = Vector2(clampf(position.x, box.position.x, box.end.x), clampf(position.y, box.position.y, box.end.y))
	if pl != null and not pl.dead:
		var d: float = pl.position.distance_to(position)
		if kind == "scrap" and t > 0.35 and d < 70.0:
			position += (pl.position - position).normalized() * (120.0 + (70.0 - d) * 4.0) * dt
		var grab := 9.0 if kind != "module" else 14.0
		if d < grab and t > 0.2:
			_collect(pl)
	queue_redraw()
	_glow.queue_redraw()

func _collect(pl) -> void:
	match kind:
		"scrap":
			Game.stats["scrap"] += amount
			Audio.play("pickup", 1.0 + randf() * 0.4, -12.0)
			Juice.burst(position, Pal.AMBER, 3, 50.0)
		"heart":
			if Game.hp >= Game.max_hp:
				return
			pl.heal(2)
		"module":
			var m: WeaponModule = ModuleDB.get_module(module_id)
			if Game.own(module_id):
				Game.toast.emit("MODULE ACQUIRED: %s [%s]" % [m.display_name, String(m.slot).to_upper()], m.color)
				Juice.big_effect(position, m.color, 0.5)
			else:
				Game.stats["scrap"] += 10
				Save.data["dupes"] += 1
				Game.toast.emit("DUPLICATE %s -> +10 SCRAP" % m.display_name, Pal.AMBER)
			Audio.play("pickup", 0.8)
	_taken = true
	queue_free()

func _draw() -> void:
	var bob := sin(t * 5.0 + position.x) * 1.5
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
		"module":
			var m: WeaponModule = ModuleDB.get_module(module_id)
			var s2 := 1.0 + 0.08 * sin(t * 6.0)
			var r := Rect2(Vector2(-7, -7 + bob) * s2, Vector2(14, 14) * s2)
			draw_rect(r, Pal.STEEL_DARK)
			draw_rect(r, m.color, false, 1.0)
			draw_rect(r.grow(-3), m.color.darkened(0.5))
			draw_string(ThemeDB.fallback_font, Vector2(-8, 3 + bob), m.symbol, HORIZONTAL_ALIGNMENT_CENTER, 16, 8, Color.WHITE)
			draw_string(ThemeDB.fallback_font, Vector2(-30, -12 + bob), m.display_name, HORIZONTAL_ALIGNMENT_CENTER, 60, 7, m.color)

func _draw_glow(c: Node2D) -> void:
	var col := Pal.AMBER
	var r := 9.0
	if kind == "heart":
		col = Pal.RED
	elif kind == "module":
		col = ModuleDB.get_module(module_id).color
		r = 22.0 + 4.0 * sin(t * 6.0)
	Juice.glow(c, Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.5))
