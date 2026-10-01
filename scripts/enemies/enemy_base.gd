class_name EnemyBase
extends Node2D
## Shared enemy behaviour: hit reactions (squish, 3-frame white flash, directional particles),
## knockback/pull, stun, death debris. Subclasses implement _ai() and the art callbacks.

var room: Room
var kind_id := "enemy"
var display_name := "Enemy"
var hp := 20.0
var max_hp := 20.0
var radius := 7.0
var speed := 60.0
var color := Pal.RED
var vel := Vector2.ZERO
var kb := Vector2.ZERO
var rig: SquashRig
var flash_t := 0.0
var stun_t := 0.0
var buff_t := 0.0
var spawn_t := 0.0
var dead := false
var contact_cd := 0.0
var contact_on := true
var telegraph := 0.0
var scrap_value := 1
var face := 0.0
var _dot_acc := 0.0
var _pulse_off := 0.0
var show_bar := true

func _ready() -> void:
	max_hp = hp
	spawn_t = 0.3
	_pulse_off = randf() * TAU
	rig = SquashRig.new()
	rig.art.draw_fn = _draw_art
	rig.glow.draw_fn = _draw_glow
	add_child(rig)
	z_index = 1
	rig.spring.squash(Vector2(1.5, 0.4))     # pop-in: springs up out of the spawn portal
	_setup()

func _setup() -> void:
	pass

func speed_mult() -> float:
	return 1.35 if buff_t > 0.0 else 1.0

func c(col: Color) -> Color:
	return Color.WHITE if flash_t > 0.0 else col

func _process(dt: float) -> void:
	if dead:
		return
	var pl = Game.world.player if Game.world else null
	flash_t = maxf(0.0, flash_t - dt)
	buff_t = maxf(0.0, buff_t - dt)
	contact_cd = maxf(0.0, contact_cd - dt)
	if spawn_t > 0.0:
		spawn_t -= dt
	elif stun_t > 0.0:
		stun_t -= dt
		vel = vel.move_toward(Vector2.ZERO, 600.0 * dt)
	elif pl != null and not pl.dead:
		_ai(dt, pl)
	else:
		vel = vel.move_toward(Vector2.ZERO, 400.0 * dt)
	# separation so swarms don't stack into one pixel
	if spawn_t <= 0.0:
		for o in room.enemies:
			if o != self and is_instance_valid(o) and not o.dead:
				var d: Vector2 = position - o.position
				var m: float = radius + o.radius
				var dl := d.length()
				if dl < m and dl > 0.01:
					kb += d / dl * (m - dl) * 8.0
	var total := vel + kb
	var res: Dictionary = room.resolve_circle(position + total * dt, radius)
	position = res["pos"]
	var n: Vector2 = res["normal"]
	if n != Vector2.ZERO:
		if kb.length() > 140.0:
			kb = kb.bounce(n) * 0.45              # bounce back off walls
			rig.punch_dir(-n, 0.35)
			Juice.burst(position, Pal.STEEL, 3, 60.0, n, 1.4, 0.2, 2.0)
		elif kb.dot(n) < 0.0:
			kb -= n * kb.dot(n)
		if vel.dot(n) < 0.0:
			vel -= n * vel.dot(n)
	kb *= exp(-dt * 6.0)
	if pl != null and not pl.dead and contact_on and contact_cd <= 0.0 and spawn_t <= 0.0 and stun_t <= 0.0:
		if position.distance_to(pl.position) < radius + pl.radius:
			if pl.take_damage(1, position):
				contact_cd = 0.8
	var pv := Juice.pulse_vec(_pulse_off, 0.7)
	rig.update(dt, total.normalized(), total.length(), speed * 2.4, pv)
	rig.position = position.round() - position
	queue_redraw()

func _ai(_dt: float, _pl) -> void:
	pass

# ---- damage ----------------------------------------------------------------------------------
func take_hit(dmg: float, dir: Vector2, knock: float, crit: bool = false) -> void:
	if dead:
		return
	var is_crit := crit or randf() < 0.07
	if is_crit:
		dmg *= 2.0
	hp -= dmg
	flash_t = 0.05                                           # ~3 frames of white
	rig.punch_dir(dir, clampf(dmg / 24.0, 0.18, 0.7))         # squish inward, snap back
	kb += dir * knock * 1.4
	stun_t = maxf(stun_t, 0.0)
	Audio.play("crit" if is_crit else "hit", randf_range(0.9, 1.2), -6.0)
	Juice.burst(position, color.lerp(Color.WHITE, 0.3), 3 + int(dmg / 6.0), 130.0, dir, 1.3, 0.3, 2.0)
	var txt := str(int(round(dmg)))
	if is_crit:
		Juice.text(position + Vector2(0, -radius - 4), txt, Pal.AMBER, 10, true)
	elif dmg >= 15.0:
		Juice.text(position + Vector2(0, -radius - 4), txt, Pal.RED, 10, true)
	else:
		Juice.text(position + Vector2(randf_range(-4, 4), -radius - 4), txt, Pal.WHITE, 8, false)
	if dmg >= 24.0:
		Juice.hit_stop(5)
		Juice.shake(dir, 2.0 + dmg / 30.0, 0.4, 0.2)
	elif dmg >= 12.0 or is_crit:
		Juice.hit_stop(3)
		Juice.shake(dir, 1.4, 0.2)
	else:
		Juice.shake(dir, 0.35)
	if hp <= 0.0:
		die(dir)
	else:
		_on_hit(dir)

func take_dot(dmg: float, col: Color) -> void:
	if dead:
		return
	hp -= dmg
	_dot_acc += dmg
	rig.spring.punch(Vector2(0.6, -0.6))
	if _dot_acc >= 6.4:
		Juice.text(position + Vector2(0, -radius - 4), str(int(_dot_acc)), col, 8, false)
		_dot_acc = 0.0
	if randf() < 0.5:
		Juice.burst(position, col, 1, 30.0, Vector2.UP, 1.0, 0.4, 2.0, ParticleField.EMBER)
	if hp <= 0.0:
		die(Vector2.UP)

func _on_hit(_dir: Vector2) -> void:
	pass

func apply_knock(v: Vector2) -> void:
	kb += v

func apply_pull(target: Vector2, strength: float, dt: float) -> void:
	var d := target - position
	var l := d.length()
	if l < 3.0:
		return
	kb += d / l * strength * dt
	if kb.length() > 260.0:
		kb = kb.normalized() * 260.0

func stun(t: float) -> void:
	stun_t = maxf(stun_t, t)
	telegraph = 0.0
	_on_stunned()

func _on_stunned() -> void:
	pass

func die(dir: Vector2) -> void:
	if dead:
		return
	dead = true
	Game.stats["kills"] += 1
	Save.discover("enemies", kind_id)
	Juice.debris(position, color, 12 + int(radius * 1.5), 190.0, dir)
	Juice.debris(position, Pal.STEEL, 4, 130.0)
	Juice.burst(position, color.lerp(Color.WHITE, 0.4), 12, 170.0, dir, 2.2, 0.45, 2.0)
	Juice.ring(position, color, radius * 3.5, 0.3)
	if room.particles:
		room.particles.stain(position, color, radius * 0.9)
	Audio.play("kill", randf_range(0.9, 1.2), -4.0)
	Juice.hit_stop(2)
	Juice.shake(dir, 1.6, 0.3)
	Game.world.spawn_pickup("scrap", position, scrap_value)
	if randf() < 0.07:
		Game.world.spawn_pickup("heart", position, 1)
	Game.enemy_died.emit(self)
	visible = false
	await get_tree().create_timer(0.05).timeout
	queue_free()

# ---- drawing -----------------------------------------------------------------------------------
func _draw() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, radius), radius * 0.95, radius * 0.35), Color(0, 0, 0, 0.35))
	if show_bar and hp < max_hp and not dead:
		var w := radius * 2.0
		var p := Vector2(-radius, -radius - 8.0)
		draw_rect(Rect2(p, Vector2(w, 2)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(p, Vector2(w * clampf(hp / max_hp, 0.0, 1.0), 2)), Pal.RED)
	_draw_world(self)

func _draw_world(_canvas: Node2D) -> void:
	pass

func _draw_art(_canvas: Node2D) -> void:
	pass

func _draw_glow(_canvas: Node2D) -> void:
	pass

func _ellipse(ctr: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _poly(r: float, n: int, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(Vector2.from_angle(rot + TAU * float(i) / float(n)) * r)
	return pts

func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var o := pts.duplicate()
	o.append(pts[0])
	return o
