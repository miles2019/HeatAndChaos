class_name PostFx
extends CanvasLayer
## Feeds the post shader from the Juice controller every frame.

var rect := ColorRect.new()
var mat := ShaderMaterial.new()

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	mat.shader = load("res://shaders/post_fx.gdshader")
	rect.material = mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

func _process(_dt: float) -> void:
	var names := ["wave0", "wave1", "wave2"]
	for i in 3:
		if i < Juice.waves.size():
			var w: Dictionary = Juice.waves[i]
			var uv: Vector2 = w["uv"]
			mat.set_shader_parameter(names[i], Vector4(uv.x, uv.y, w["t"] / w["dur"], w["strength"]))
		else:
			mat.set_shader_parameter(names[i], Vector4(0.5, 0.5, 2.0, 0.0))
	mat.set_shader_parameter("aberration", Juice.chroma)
	mat.set_shader_parameter("heat", Juice.heat)
	mat.set_shader_parameter("pulse_speed", Juice.pulse_rate() * 2.0)
	mat.set_shader_parameter("instability", Juice.instability)
	var f := Juice.screen_flash
	mat.set_shader_parameter("flash", Vector4(f.r, f.g, f.b, f.a))
	var a := Juice.afterglow
	mat.set_shader_parameter("afterglow", Vector4(a.r, a.g, a.b, a.a))
	mat.set_shader_parameter("fog", Game.world.fog_amount if Game.world else 0.0)
