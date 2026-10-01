extends CanvasLayer
## Central scene changes with a neon wipe so menu <-> run never pops.

const SCENES := {
	"menu": "res://scenes/ui/main_menu.tscn",
	"workshop": "res://scenes/ui/workshop_hub.tscn",
	"run": "res://scenes/main.tscn",
	"story": "res://scenes/ui/story_intro.tscn",
}
var _rect := ColorRect.new()
var _busy := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect.color = Color(0.02, 0.01, 0.03, 1.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)

func go(scene_name: String) -> void:
	if _busy or not SCENES.has(scene_name):
		return
	_busy = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_rect, "modulate:a", 1.0, 0.18)
	await tw.finished
	get_tree().change_scene_to_file(SCENES[scene_name])
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween().set_ignore_time_scale(true)
	tw2.tween_property(_rect, "modulate:a", 0.0, 0.25)
	await tw2.finished
	_busy = false
