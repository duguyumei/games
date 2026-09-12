extends Node2D
# 对战区+手牌层+功法层整屏截图包装（设计稿验证用）

func _ready() -> void:
	get_viewport().get_window().size = Vector2i(1280, 720)
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.17, 0.19)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	var stage: Control = load("res://ui/battle_stage.tscn").instantiate()
	stage.position = Vector2(0, 0)
	add_child(stage)
	var hand_bar: Control = load("res://ui/hand_bar.tscn").instantiate()
	hand_bar.position = Vector2(0, 386)
	add_child(hand_bar)
	var tech_bar: Control = load("res://ui/technique_bar.tscn").instantiate()
	tech_bar.position = Vector2(0, 496)
	add_child(tech_bar)
	await get_tree().create_timer(1.0).timeout
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://previews/battle_stage_shot.png")
	print("预览图已保存：res://previews/battle_stage_shot.png")
	get_tree().quit()
