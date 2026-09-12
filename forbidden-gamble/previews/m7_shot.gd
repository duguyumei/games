extends Node
# M7a 战斗场景截图验收：初始回合 / 选珠凝招 / 待确认三态

func _ready() -> void:
	get_viewport().get_window().size = Vector2i(1280, 720)
	var main: Control = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_shot("res://previews/m7_combat_idle.png")
	# 找一对同属性真气选中（凝招演示，二重）
	var hand: Array = main.combat.player.hand
	var picked: Array[int] = []
	for i in range(hand.size()):
		for j in range(i + 1, hand.size()):
			if hand[i].attribute == hand[j].attribute:
				picked = [i, j]
				break
		if not picked.is_empty():
			break
	if picked.is_empty():
		picked = [0]
	for idx in picked:
		main._on_card_clicked(idx)
	await get_tree().process_frame
	_shot("res://previews/m7_combat_select.png")
	main._on_technique_clicked("二重·壁")
	await get_tree().process_frame
	await get_tree().process_frame
	_shot("res://previews/m7_combat_pending.png")
	get_tree().quit()

func _shot(path: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(path)
	print("预览图已保存：" + path)
