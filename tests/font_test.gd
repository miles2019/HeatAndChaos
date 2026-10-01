extends Node2D
func _ready():
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("C:/Users/User/Games/HeatAndChaos/tests/shots/font.png")
	get_tree().quit()
func _draw():
	draw_rect(Rect2(0,0,640,360), Color("0e0b12"))
	var f := Fonts.main()
	var y := 14.0
	for s in [8, 10, 12, 16, 24]:
		draw_string(f, Vector2(10, y), "%d: MISFIRE RISK 13%%/shot HEAT 72%% Instability ROOM 1-3 abc xyz" % s, HORIZONTAL_ALIGNMENT_LEFT, -1, s, Color("c9d2e0"))
		y += s + 10
