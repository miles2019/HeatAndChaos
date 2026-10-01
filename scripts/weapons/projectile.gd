class_name Projectile
extends Node2D
## Pooled projectile for BOTH factions. Every trajectory behaviour (bounce, curve, orbit, helix, curl, split,
## hesitate, pendulum, chain, saw, drag, magnet fields) is a flag that modules switch on. Bosses reuse the very
## same flags - the Magnet Warden literally calls your trajectory module on its own bullets.

var active := false
var faction := 0                 # 0 = player, 1 = enemy
var vel := Vector2.ZERO
var speed := 300.0
var damage := 5.0
var radius := 3.0
var life := 1.0
var max_life := 1.0
var age := 0.0
var pierce := 0
var bounces_left := 0
var bounce_gain := 1.0
var knockback := 40.0
var color := Pal.CYAN
var big := false
var homing := 0.0
var seek := false
var drops := false
var sine_amp := 0.0
var sine_freq := 0.0
var curl := 0.0
var through_cover := false
var orbit_state := 0             # 0 none, 1 armed (beam), 2 orbiting
var orbit_after := 0.0
var orbit_time := 3.0
var orbit_angle := 0.0
var orbit_radius := 20.0
var orbit_dir := 1.0
var return_on_miss := false
var pull_radius := 0.0
var pull_force := 0.0
var boomerang := false
var saw := false
var pull_player_t := 0.0
var chain := 0
var drag := 0.0
var split_at := 0.0
var split_n := 0
var hold_after := 0.0
var hold_time := 0.0
var hold_boost := 1.0
var reverse_at := 0.0
var catalyst: CatalystModule
var hit_cd := {}
var trail: Array[Vector2] = []
var punch := 0.0
var sinking := 0.0
var bounce_count := 0
var _base_pos := Vector2.ZERO
var _base_dir := Vector2.RIGHT
var _target := Vector2.INF
var _retarget := 0.0
var _held := false
var _held_dir := Vector2.ZERO
var _held_speed := 0.0
var _reversed := false
var _glow := ArtNode.new()

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = mat
	_glow.draw_fn = _draw_glow
	add_child(_glow)
	z_index = 5
	visible = false

func setup(cfg: Dictionary, origin: Vector2, fac: int = 0) -> void:
	faction = fac
	position = origin
	_base_pos = origin
	var d: Vector2 = cfg["dir"]
	_base_dir = d.normalized()
	speed = cfg["speed"]
	vel = _base_dir * speed
	damage = cfg["damage"]
	life = cfg["lifetime"]
	max_life = life
	radius = cfg["size"]
	pierce = cfg["pierce"]
	knockback = cfg["knockback"]
	color = cfg["color"]
	age = 0.0
	big = false
	bounces_left = int(cfg.get("bounces", 0))
	bounce_gain = 1.0
	homing = 0.0
	seek = false
	drops = false
	sine_amp = 0.0
	sine_freq = 0.0
	curl = 0.0
	through_cover = false
	orbit_state = 0
	orbit_after = 0.0
	orbit_time = 3.0
	orbit_dir = 1.0
	return_on_miss = false
	pull_radius = 0.0
	pull_force = 0.0
	boomerang = false
	saw = false
	pull_player_t = 0.0
	chain = 0
	drag = 0.0
	split_at = 0.0
	split_n = 0
	hold_after = 0.0
	hold_time = 0.0
	hold_boost = 1.0
	reverse_at = 0.0
	catalyst = null
	hit_cd.clear()
	trail.clear()
	punch = 0.0
	sinking = 0.0
	bounce_count = 0
	_target = Vector2.INF
	_retarget = 0.0
	_held = false
	_reversed = false
	active = true
	visible = true

func copy_from(o: Projectile) -> void:
	var cfg := {"dir": o.vel.normalized() if o.vel.length() > 1.0 else o._base_dir, "speed": o.speed, "damage": o.damage, "lifetime": o.life,
		"size": o.radius, "pierce": o.pierce, "knockback": o.knockback, "color": o.color, "bounces": o.bounces_left}
	setup(cfg, o.position, o.faction)
	big = o.big
	bounce_gain = o.bounce_gain
	homing = o.homing
	seek = o.seek
	drops = o.drops
	sine_amp = o.sine_amp
	sine_freq = o.sine_freq
	curl = o.curl
	through_cover = o.through_cover
	return_on_miss = o.return_on_miss
	boomerang = o.boomerang
	saw = o.saw
	chain = o.chain
	drag = o.drag
	hold_after = o.hold_after
	hold_time = o.hold_time
	hold_boost = o.hold_boost
	reverse_at = o.reverse_at
	max_life = o.max_life
	catalyst = o.catalyst

func rotate_dir(a: float) -> void:
	vel = vel.rotated(a)
	_base_dir = _base_dir.rotated(a)

func _process(dt: float) -> void:
	if not active:
		return
	var w = Game.world
	if w == null:
		return
	age += dt
	life -= dt
	punch = maxf(0.0, punch - dt * 5.0)
	trail.append(position)
	if trail.size() > (14 if orbit_state == 2 else 7):
		trail.pop_front()
	_step(dt, w)
	if active:
		_glow.queue_redraw()
		queue_redraw()

func _step(dt: float, w) -> void:
	var room = w.current_room()
	var pl = w.player
	var mine := faction == 0
	if pull_player_t > 0.0 and pl != null:
		pull_player_t -= dt
		pl.apply_impulse((position - pl.position).normalized() * dt * 1500.0)
	if mine and orbit_state == 2:
		_step_orbit(dt, w, pl)
		return
	if mine and orbit_state == 1 and age >= orbit_after and pl != null:
		_enter_orbit(pl)
		return
	# hesitation: freeze, then launch faster
	if hold_after > 0.0:
		if not _held and age >= hold_after and age < hold_after + hold_time:
			_held = true
			_held_dir = vel.normalized()
			_held_speed = speed
			punch = 1.0
		if _held:
			if age >= hold_after + hold_time:
				_held = false
				hold_after = 0.0
				speed = _held_speed * hold_boost
				vel = _held_dir * speed
				punch = 1.0
				Juice.burst(position, color, 5, 90.0, _held_dir, 1.0, 0.25, 2.0)
			else:
				vel = Vector2.ZERO
				_after_motion(room, pl, w, dt)
				return
	# homing
	if homing > 0.0:
		_retarget -= dt
		if _retarget <= 0.0:
			_retarget = 0.12
			if not mine and pl != null:
				_target = pl.position
			elif seek:
				_target = _nearest_enemy(room)
			else:
				_target = w.dense_cluster(position, vel.normalized(), 150.0)
		if _target != Vector2.INF:
			var want := (_target - position).angle()
			var diff := wrapf(want - vel.angle(), -PI, PI)
			vel = vel.rotated(clampf(diff, -homing * dt, homing * dt))
		elif drops and age > 0.16 and mine:
			sinking += dt
			vel *= exp(-dt * 10.0)
			if sinking > 0.16:
				if catalyst:
					catalyst.on_impact({"kind": "ground", "pos": position, "dir": vel, "projectile": self})
				Juice.burst(position, color, 5, 40.0, Vector2.UP, 2.0, 0.3, 2.0)
				kill("ground")
				return
	if curl != 0.0:
		vel = vel.rotated(curl * dt)
	if drag > 0.0:
		speed = maxf(0.0, speed * exp(-drag * dt))
		if vel.length() > 0.01:
			vel = vel.normalized() * speed
	if reverse_at > 0.0 and not _reversed and age >= reverse_at:
		_reversed = true
		_base_dir = -_base_dir
		speed *= 1.25
		vel = -vel.normalized() * speed
		hit_cd.clear()
		punch = 1.0
		Juice.ring(position, color, 14.0, 0.2)
	if ((boomerang and age > 0.45) or (saw and age > 0.55)) and pl != null:
		var want2: Vector2 = (pl.position - position).normalized() * speed * (1.1 if boomerang else 1.25)
		vel = vel.lerp(want2, 1.0 - exp(-dt * 5.0))
		life = maxf(life, 0.2)
		if position.distance_to(pl.position) < radius + pl.radius + 2.0:
			if boomerang:
				pl.take_damage(1, position)
			Juice.burst(position, color, 8, 90.0)
			kill("return")
			return
	if split_at > 0.0 and age >= split_at and split_n > 0:
		_do_split(w)
		return
	var field: Vector2 = room.field_accel(position)
	if field != Vector2.ZERO and sine_amp <= 0.0:
		vel += field * dt * 0.6
	var prev := position
	if sine_amp > 0.0:
		_base_pos += _base_dir * speed * dt
		var perp := _base_dir.orthogonal()
		position = _base_pos + perp * sin(age * sine_freq) * sine_amp * minf(1.0, age * 5.0)
		vel = (position - prev) / maxf(dt, 0.0001)
	else:
		position += vel * dt
	_after_motion(room, pl, w, dt)

func _after_motion(room, pl, _w, dt: float) -> void:
	var n: Vector2 = room.hit_test(position, radius, through_cover)
	if n != Vector2.ZERO:
		if faction == 0 and room.last_crack >= 0:
			room.crack_hit(damage)
		_on_wall(n, pl)
		if not active:
			return
	if life <= 0.0 or not room.inner.grow(Room.WALL + 60.0).has_point(position):
		if return_on_miss and pl != null and orbit_state == 0 and faction == 0 and room.inner.has_point(position):
			_enter_orbit(pl)
		else:
			if catalyst and catalyst.kind == CatalystModule.Kind.TOXIC and faction == 0 and life <= 0.0:
				catalyst.on_impact({"kind": "expire", "pos": position, "dir": vel, "projectile": self})
			kill("expire")
		return
	if faction == 0:
		_hit_enemies(room, pl)
		if pull_radius > 0.0:
			for e in room.enemies:
				if is_instance_valid(e) and not e.dead and e.position.distance_to(position) < pull_radius:
					e.apply_pull(position, pull_force, dt)
	elif pl != null and not pl.dead and position.distance_to(pl.position) < radius + pl.radius:
		if pl.take_damage(1, position):
			Juice.burst(position, color, 6, 90.0)
			kill("hit")

func _nearest_enemy(room) -> Vector2:
	var best := Vector2.INF
	var bd := 260.0
	for e in room.enemies:
		if is_instance_valid(e) and not e.dead and e.spawn_t <= 0.0:
			var d: float = e.position.distance_to(position)
			if d < bd:
				bd = d
				best = e.position
	return best

func _do_split(w) -> void:
	var n := split_n
	split_n = 0
	for i in n:
		var c: Projectile = w.acquire_projectile()
		if c == null:
			break
		c.copy_from(self)
		c.damage = damage * 0.6
		c.life = maxf(life, 0.5)
		c.rotate_dir((float(i) - float(n - 1) * 0.5) * 0.5)
		c.age = 0.3
		c.split_n = 0
		c.split_at = 0.0
		c.reverse_at = 0.0
		c.hold_after = 0.0
	Juice.burst(position, color, 6, 80.0)
	Audio.play("bounce", 1.6, -8.0)
	kill("split")

func _on_wall(n: Vector2, pl) -> void:
	if bounces_left > 0:
		bounces_left -= 1
		bounce_count += 1
		speed *= bounce_gain
		if sine_amp > 0.0:
			_base_dir = _base_dir.bounce(n)
			_base_pos = position + n * (radius + 2.0)
		else:
			vel = vel.bounce(n).normalized() * speed
			position += n * (radius + 1.0)
		punch = 1.0
		Juice.burst(position, color, 5, 80.0, n, 1.8, 0.3, 2.0)
		Audio.play("bounce", 1.0 + bounce_count * 0.18, -8.0)
		if catalyst and faction == 0:
			catalyst.on_impact({"kind": "bounce", "pos": position, "dir": vel, "projectile": self})
	elif return_on_miss and pl != null and orbit_state == 0 and faction == 0:
		Juice.burst(position, color, 4, 60.0, n, 1.6, 0.25, 2.0)
		_enter_orbit(pl)
	else:
		Juice.burst(position, color, 5, 70.0, n, 1.6, 0.3, 2.0)
		if catalyst and catalyst.kind == CatalystModule.Kind.TOXIC and faction == 0:
			catalyst.on_impact({"kind": "expire", "pos": position, "dir": vel, "projectile": self})
		kill("wall")

func _hit_enemies(room, _pl) -> void:
	for e in room.enemies:
		if not is_instance_valid(e) or e.dead or e.spawn_t > 0.0:
			continue
		var rr: float = radius + e.radius
		if position.distance_squared_to(e.position) > rr * rr:
			continue
		var key: int = e.get_instance_id()
		if hit_cd.has(key) and hit_cd[key] > age:
			continue
		if e.has_method("shield_blocks") and e.shield_blocks(self):
			hit_cd[key] = age + 0.12
			_shield_bounce(e)
			if not active:
				return
			continue
		hit_cd[key] = age + (0.25 if (pierce > 0 or orbit_state == 2 or saw) else 99.0)
		var dir: Vector2 = vel.normalized() if vel.length() > 1.0 else (e.position - position).normalized()
		var pl = Game.world.player
		var dmg: float = damage * (pl.damage_mult() if pl else 1.0)
		e.take_hit(dmg, dir, knockback, false)
		if catalyst:
			catalyst.on_impact({"kind": "hit", "pos": position, "dir": dir, "enemy": e, "projectile": self})
		if chain > 0 and active:
			if _chain_to(room, e):
				continue
		if orbit_state != 2:
			if pierce > 0:
				pierce -= 1
			else:
				kill("hit")
				return

func _chain_to(room, from_e) -> bool:
	var best = null
	var bd := 130.0
	for o in room.enemies:
		if o == from_e or not is_instance_valid(o) or o.dead or o.spawn_t > 0.0:
			continue
		if hit_cd.has(o.get_instance_id()):
			continue
		var d: float = o.position.distance_to(position)
		if d < bd:
			bd = d
			best = o
	if best == null:
		chain = 0
		return false
	chain -= 1
	Game.world.spawn_effect("arc", position, {"a": position, "b": best.position})
	vel = (best.position - position).normalized() * speed
	_base_dir = vel.normalized()
	life = maxf(life, 0.4)
	Audio.play("hit", 1.8, -10.0)
	return true

func _shield_bounce(e) -> void:
	var n: Vector2 = (position - e.position).normalized()
	Juice.burst(position, Pal.CYAN, 6, 90.0, n, 1.6, 0.25, 2.0)
	Audio.play("bounce", 1.6, -6.0)
	e.rig.spring.punch(Vector2(-0.8, 0.6))
	if bounces_left > 0 or return_on_miss:
		vel = vel.bounce(n)
		position += n * (radius + 3.0)
		if bounces_left > 0:
			bounces_left -= 1
		punch = 1.0
	elif orbit_state != 2 and not saw:
		kill("shield")

# ---- orbit -------------------------------------------------------------------------------------
func _enter_orbit(pl) -> void:
	orbit_state = 2
	var rel: Vector2 = position - pl.position
	orbit_angle = rel.angle()
	orbit_radius = clampf(rel.length(), 16.0, 52.0)
	orbit_dir = 1.0 if (vel.cross(rel) < 0.0) else -1.0
	if not big:
		orbit_time = 5.0
		orbit_radius = clampf(rel.length(), 18.0, 34.0)
	life = 99.0
	pierce = 999
	Juice.burst(position, color, 8, 80.0)
	Audio.play("bounce", 0.6, -6.0)

func _step_orbit(dt: float, w, pl) -> void:
	orbit_time -= dt
	if pl == null or pl.dead or orbit_time <= 0.0:
		kill("orbit_end")
		return
	orbit_angle += orbit_dir * (4.6 if big else 5.4) * dt
	orbit_radius = minf(orbit_radius + (34.0 if big else 4.0) * dt, 100.0 if big else 40.0)
	position = pl.position + Vector2.from_angle(orbit_angle) * orbit_radius
	vel = Vector2.from_angle(orbit_angle + orbit_dir * PI * 0.5) * 220.0
	var room = w.current_room()
	_hit_enemies(room, pl)
	if pull_radius > 0.0:
		for e in room.enemies:
			if is_instance_valid(e) and not e.dead and e.position.distance_to(position) < pull_radius:
				e.apply_pull(position, pull_force, dt)
	for p in w.projectiles:
		if p.active and p.faction == 1 and p.position.distance_to(position) < radius + p.radius + (6.0 if big else 2.0):
			Juice.burst(p.position, Pal.WHITE, 4, 70.0)
			p.kill("shield")

func kill(_reason: String = "expire") -> void:
	if not active:
		return
	active = false
	visible = false
	if Game.world:
		Game.world.release_projectile(self)

# ---- drawing -------------------------------------------------------------------------------------
func _draw() -> void:
	var n := trail.size()
	var w := radius * 2.0 * (1.0 - punch * 0.3)
	for i in n - 1:
		var t := float(i + 1) / float(n)
		var c := color
		c.a = t * 0.55
		draw_line(trail[i] - position, trail[i + 1] - position, c, maxf(1.0, w * t * (0.9 if big else 0.7)))
	var dir: Vector2 = vel.normalized() if vel.length() > 1.0 else _base_dir
	var len := (radius * 1.2 + speed * 0.01) * (1.0 + punch * 0.7)
	if orbit_state == 2 or big or saw:
		len = radius * 1.4
	if faction == 1:
		draw_circle(Vector2.ZERO, radius + 1.0, Color(0, 0, 0, 0.35))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.5, Color.WHITE)
		return
	if saw:
		var spin := age * 22.0
		for i in 4:
			var a := spin + i * PI * 0.5
			draw_line(Vector2.from_angle(a) * radius * 0.4, Vector2.from_angle(a) * radius * 1.3, color, 2.0)
		draw_circle(Vector2.ZERO, radius * 0.6, Color.WHITE)
		return
	draw_line(-dir * len, dir * len * 0.7, color, w)
	draw_line(-dir * len * 0.6, dir * len * 0.7, Color.WHITE, maxf(1.0, w * 0.45))
	if _held:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 10, Color(1, 1, 1, 0.6), 1.0)

func _draw_glow(c: Node2D) -> void:
	var r := radius * (6.0 if big else 4.2)
	Juice.glow(c, Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.55))
