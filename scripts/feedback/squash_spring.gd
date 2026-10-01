class_name SquashSpring
extends RefCounted
## Critically-underdamped spring around Vector2.ONE. Everything bouncy/stretchy uses this.

var value := Vector2.ONE
var velocity := Vector2.ZERO
var stiffness := 240.0
var damping := 10.0

func _init(k: float = 240.0, c: float = 10.0) -> void:
	stiffness = k
	damping = c

func punch(amount: Vector2) -> void:
	velocity += amount

func squash(v: Vector2) -> void:
	value = v

func update(dt: float) -> void:
	dt = minf(dt, 1.0 / 30.0)
	var f := (Vector2.ONE - value) * stiffness - velocity * damping
	velocity += f * dt
	value += velocity * dt
	value = value.clamp(Vector2(0.25, 0.25), Vector2(2.4, 2.4))
