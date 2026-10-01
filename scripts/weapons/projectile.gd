class_name Projectile
extends Node2D
## Pooled projectile. All trajectory behaviours (bounce, curve, orbit, helix, boomerang) live here as flags
## that Trajectory/Catalyst modules switch on in modify_projectile().

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
var drops := false
var sine_amp := 0.0
var sine_freq := 0.0
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
var pull_player_t := 0.0
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
	drops = false
	sine_amp = 0.0
	sine_freq = 0.0
	through_cover = false
	orbit_state = 0
	orbit_after = 0.0
	orbit_time = 3.0
	orbit_dir = 1.0
	return_on_miss = false
	pull_radius = 0.0
	pull_force = 0.0
	boomerang = false
	pull_player_t = 0.0
	catalyst = null
	hit_cd.clear()
	trail.clear()
	punch = 0.0
	sinking = 0.0
	bounce_count = 0
	_target = Vector2.INF
	_retarget = 0.0
	active = true
	visible = true

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
	if faction == 0:
		_step_player(dt, w)
	else:
		_step_enemy(dt, w)
	_glow.queue_redraw()
	queue_redraw()

func _step_enemy(dt: float, w) -> void:
	position += vel * dt
	var room = w.current_room()
	var n: Vector2 = room.hit_test(position, radius, false)
	if n != Vector2.ZERO:
		if bounces_left > 0:
			vel = vel.bounce(n)
			position += n * (radius + 1.0)
			bounces_left -= 1
			punch = 1.0
			Juice.burst(position, color, 4, 60.0)
		else:
			kill("wall")
			return
	if life <= 0.0 or not Rect2(-10, -10, 660, 380).has_point(position):
		kill("expire")
		return
	var pl = w.player
	if pl != null and not pl.dead and position.distance_to(pl.position) < radius + pl.radius:
		if pl.take_damage(1, position):
			kill("hit")

func _step_player(dt: float, w) -> void:
	var room = w.current_room()
	var pl = w.player
	if pull_player_t > 0.0 and pl != null:
		pull_player_t -= dt
		pl.apply_impulse((position - pl.position).normalized() * dt * 1500.0)
	if orbit_state == 2:
		_step_orbit(dt, w, pl)
		return
	if orbit_state == 1 and age >= orbit_after and pl != null:
		_enter_orbit(pl)
		return
	# homing towards dense enemy clusters (Gravitational Curve)
	if homing > 0.0:
		_retarget -= dt
		if _retarget <= 0.0:
			_retarget = 0.12
			_target = w.dense_cluster(position, vel.normalized(), 150.0)
		if _target != Vector2.INF:
			var want := (_target - position).angle()
			var diff := wrapf(want - vel.angle(), -PI, PI)
			vel = vel.rotated(clampf(diff, -homing * dt, homing * dt))
		elif drops and age > 0.16:
			sinking += dt
			vel *= exp(-dt * 10.0)
			if sinking > 0.16:
				if catalyst:
					catalyst.on_impact({"kind": "ground", "pos": position, "dir": vel, "projectile": self})
				Juice.burst(position, color, 5, 40.0, Vector2.UP, 2.0, 0.3, 2.0)
				kill("ground")
				return
	if boomerang and age > 0.45 and pl != null:
		var want2: Vector2 = (pl.position - position).normalized() * speed * 1.1
		vel = vel.lerp(want2, 1.0 - exp(-dt * 5.0))
		life = maxf(life, 0.2)
		if position.distance_to(pl.position) < radius + pl.radius + 2.0:
			pl.take_damage(1, position)
			Juice.burst(position, color, 8, 90.0)
			kill("hit")
			return
	# movement
	var prev := position
	if sine_amp > 0.0:
		_base_pos += _base_dir * speed * dt
		var perp := _base_dir.orthogonal()
		position = _base_pos + perp * sin(age * sine_freq) * sine_amp * minf(1.0, age * 5.0)
		vel = (position - prev) / maxf(dt, 0.0001)
	else:
		position += vel * dt
	# walls
	var n: Vector2 = room.hit_test(position, radius, through_cover)
	if n != Vector2.ZERO:
		_on_wall(n, pl)
		if not active:
			return
	if life <= 0.0 or not Rect2(-12, -12, 664, 384).has_point(position):
		if return_on_miss and pl != null and Rect2(0, 0, 640, 360).has_point(position) and orbit_state == 0:
			_enter_orbit(pl)
		else:
			kill("expire")
		return
	_hit_enemies(room, pl)
	if pull_radius > 0.0:
		for e in room.enemies:
			if is_instance_valid(e) and not e.dead and e.position.distance_to(position) < pull_radius:
				e.apply_pull(position, pull_force, dt)

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
		if catalyst:
			catalyst.on_impact({"kind": "bounce", "pos": position, "dir": vel, "projectile": self})
	elif return_on_miss and pl != null and orbit_state == 0:
		Juice.burst(position, color, 4, 60.0, n, 1.6, 0.25, 2.0)
		_enter_orbit(pl)
	else:
		Juice.burst(position, color, 5, 70.0, n, 1.6, 0.3, 2.0)
		if catalyst and catalyst.kind == CatalystModule.Kind.TOXIC:
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
		hit_cd[key] = age + (0.2 if (pierce > 0 or orbit_state == 2) else 99.0)
		var dir: Vector2 = vel.normalized() if vel.length() > 1.0 else (e.position - position).normalized()
		var pl = Game.world.player
		var dmg: float = damage * (pl.damage_mult() if pl else 1.0)
		e.take_hit(dmg, dir, knockback, false)
		if catalyst:
			catalyst.on_impact({"kind": "hit", "pos": position, "dir": dir, "enemy": e, "projectile": self})
		if orbit_state != 2:
			if pierce > 0:
				pierce -= 1
			else:
				kill("hit")
				return

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
	elif orbit_state != 2:
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
	# orbiting shots grind enemy bullets
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
	var dir: Vector2 = vel.normalized() if vel.length() > 1.0 else Vector2.RIGHT
	var len := (radius * 1.2 + speed * 0.01) * (1.0 + punch * 0.7)
	if orbit_state == 2 or big:
		len = radius * 1.4
	draw_line(-dir * len, dir * len * 0.7, color, w)
	draw_line(-dir * len * 0.6, dir * len * 0.7, Color.WHITE, maxf(1.0, w * 0.45))
	if faction == 1:
		draw_circle(Vector2.ZERO, radius + 1.0, Color(0, 0, 0, 0.35))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2.ZERO, radius * 0.5, Color.WHITE)

func _draw_glow(c: Node2D) -> void:
	var r := radius * (6.0 if big else 4.2)
	Juice.glow(c, Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.55))
