class_name BossBase
extends EnemyBase
## Shared boss skeleton: intro, heartbeat (attacks start on beats), phase thresholds, shared HP bar pool,
## dramatic multi-explosion death. Subclasses implement _pool(), _next_attack hooks and `_upd_<attack>` methods.

var phase := 1
var intro_t := 2.4
var invuln := 0.0
var beat_t := 0.0
var beat_n := 0
var dub_t := -1.0
var atk := "idle"
var at := 0.0
var idle_t := 1.2
var attack_idx := 0
var glow_flash := 0.0
var beat_flag := false
var act_no := 1
var thresholds: Array = [0.5]
var subtitle := ""
var is_child := false
var queued: Array = []

func _init() -> void:
	scale_hp = false
	speed = 0.0
	contact_on = true
	show_bar = false

func _setup() -> void:
	_boss_setup()
	if not is_child:
		Game.stats["boss_pool"] = hp
		Game.boss_intro.emit(display_name, subtitle)
		Save.discover("bosses", kind_id)
	_emit_hp()

func _boss_setup() -> void:
	pass

func beat_period() -> float:
	return 1.0

func _pool() -> Array:
	return ["idle"]

func _enter_phase(_n: int) -> void:
	pass

func _emit_hp() -> void:
	var total := 0.0
	for e in room.enemies:
		if is_instance_valid(e) and e is BossBase and not e.dead:
			total += maxf(e.hp, 0.0)
	var pool: float = Game.stats.get("boss_pool", max_hp)
	Game.boss_hp_changed.emit(clampf(total / pool, 0.0, 1.0), display_name)

# ---- damage / phases ---------------------------------------------------------------------------
func take_hit(dmg: float, dir: Vector2, _knock: float, crit: bool = false) -> void:
	if dead:
		return
	if invuln > 0.0 or intro_t > 0.0:
		Juice.burst(position + dir * -radius, Pal.WHITE, 3, 80.0, -dir, 1.2, 0.2, 2.0)
		return
	super.take_hit(dmg * 0.9, dir, 0.0, crit)
	if not dead:
		_emit_hp()
		_check_phase()

func _check_phase() -> void:
	while phase <= thresholds.size() and hp <= max_hp * float(thresholds[phase - 1]) and not dead:
		phase += 1
		invuln = 1.6
		atk = "idle"
		idle_t = 1.4
		queued.clear()
		Juice.big_effect(position, color, 1.0)
		Audio.play("slam", 0.6)
		Game.toast.emit("%s - PHASE %d" % [display_name, phase], Pal.AMBER)
		_enter_phase(phase)

func apply_knock(_v: Vector2) -> void:
	pass

func apply_pull(_t: Vector2, _s: float, _dt: float) -> void:
	pass

func stun(_t: float) -> void:
	pass

func take_dot(dmg: float, col: Color) -> void:
	if invuln <= 0.0 and intro_t <= 0.0:
		super.take_dot(dmg * 0.6, col)
		_emit_hp()
		_check_phase()

func die(dir: Vector2) -> void:
	if dead:
		return
	dead = true
	atk = "idle"
	Game.stats["kills"] += 1
	if not is_child:
		Game.stats["bosses"].append(display_name)
	Game.enemy_died.emit(self)
	Game.world.fog_amount = 0.0
	var lone := true
	for e in room.enemies:
		if e != self and is_instance_valid(e) and e is BossBase and not e.dead:
			lone = false
	_emit_hp()
	for i in 4:
		Juice.big_effect(position + Vector2.from_angle(randf() * TAU) * 14.0, color if i % 2 == 0 else Pal.AMBER, 1.0 if lone else 0.6, dir)
		Juice.debris(position, color, 22, 240.0)
		Audio.play("boom", 0.6 + i * 0.1)
		if is_inside_tree():
			await get_tree().create_timer(0.35, false, false, true).timeout
	Juice.debris(position, color, 40, 300.0)
	visible = false
	if lone and Game.world:
		Game.world.on_boss_defeated(act_no)

# ---- AI skeleton -------------------------------------------------------------------------------
func _ai(dt: float, pl) -> void:
	invuln = maxf(0.0, invuln - dt)
	glow_flash = maxf(0.0, glow_flash - dt * 2.0)
	vel = Vector2.ZERO
	_heartbeat(dt)
	_process_queue(dt)
	if intro_t > 0.0:
		intro_t -= dt
		return
	if atk == "idle":
		idle_t -= dt
		if idle_t <= 0.0 and beat_flag:
			_next_attack(pl)
	else:
		var m := "_upd_%s" % atk
		if has_method(m):
			call(m, dt, pl)
		else:
			_end_attack()
	beat_flag = false

func _next_attack(pl) -> void:
	var pool := _pool()
	atk = pool[attack_idx % pool.size()]
	attack_idx += 1
	at = 0.0
	_on_attack_start(pl)

func _on_attack_start(_pl) -> void:
	pass

func _end_attack() -> void:
	atk = "idle"
	idle_t = 1.0 if phase == 1 else 0.6
	rig.boost = 0.0
	Game.world.fog_amount = 0.0

func _heartbeat(dt: float) -> void:
	beat_t += dt
	if beat_t >= beat_period():
		beat_t = 0.0
		beat_n += 1
		beat_flag = true
		dub_t = 0.0
		rig.spring.punch(Vector2(2.4, 2.4))          # lub
		glow_flash = 1.0
		Audio.play("thump", 0.8 if phase == 1 else 1.0, -2.0, "Feedback")
		Juice.shake(Vector2.ZERO, 0.45)
		Juice.afterglow = Color(color.r, color.g * 0.5, color.b * 0.5, 0.1)
		Juice.ring(position, color, 40.0 + 6.0 * phase, 0.5)
		_on_beat()
	if dub_t >= 0.0:
		dub_t += dt
		if dub_t >= 0.2:
			dub_t = -1.0
			rig.spring.punch(Vector2(1.4, 1.4))        # dub

func _on_beat() -> void:
	pass

## Queue a delayed action: [time_left, Callable]
func later(t: float, fn: Callable) -> void:
	queued.append([t, fn])

func _process_queue(dt: float) -> void:
	for q in queued:
		q[0] -= dt
		if q[0] <= 0.0 and not dead:
			(q[1] as Callable).call()
	queued = queued.filter(func(q: Array) -> bool: return q[0] > 0.0)

func pellet(dir: Vector2, spd: float, size: float, col: Color, bounces: int = 0, life: float = 6.0) -> Projectile:
	var p: Projectile = Game.world.acquire_projectile()
	if p == null:
		return null
	p.setup({"dir": dir, "speed": spd, "damage": 1.0, "lifetime": life, "size": size, "pierce": 0,
		"knockback": 0.0, "color": col, "bounces": bounces}, position + dir * (radius + 4.0), 1)
	return p

func ring_of_pellets(n: int, spd: float, size: float, col: Color, gap: int = 0, rot: float = -1.0) -> void:
	var base := rot if rot >= 0.0 else randf() * TAU
	var gap_at := randi() % n
	for i in n:
		if gap > 0 and (i - gap_at + n) % n < gap:
			continue
		pellet(Vector2.from_angle(base + TAU * i / float(n)), spd, size, col)

func _dist_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func ray_len(ang: float) -> float:
	var d := Vector2.from_angle(ang)
	var best := 1400.0
	var r := room.inner
	if d.x > 0.001:
		best = minf(best, (r.end.x - position.x) / d.x)
	elif d.x < -0.001:
		best = minf(best, (r.position.x - position.x) / d.x)
	if d.y > 0.001:
		best = minf(best, (r.end.y - position.y) / d.y)
	elif d.y < -0.001:
		best = minf(best, (r.position.y - position.y) / d.y)
	return maxf(best, 20.0)
