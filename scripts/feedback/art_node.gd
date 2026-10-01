class_name ArtNode
extends Node2D
## A node that delegates _draw to a Callable so entity scripts can keep their art in one place.

var draw_fn: Callable

func _draw() -> void:
	if draw_fn.is_valid():
		draw_fn.call(self)
