extends Node
# 容器弹窗验收（D-028 弹窗翻牌）：
# 铺一个木箱（3 件）→ 点击开盖弹窗 → 翻一张亮牌 → 几何断言（卡槽都在窗内）→ 截图
# （真窗口下另存 user://container_shot.png；headless 假渲染无纹理跳过截图）。

func _ready() -> void:
	ExpeditionSession.start_run(7)
	var board: Control = load("res://scenes/board/board.tscn").instantiate()
	add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame
	var bs: BoardState = board.board
	bs.current_site()["grid"] = [
		{"kind": "chest", "chest": "wood", "opened": false, "contents": [
			{"item_id": "yaoshi", "flipped": false},
			{"item_id": "jinchuang", "flipped": false},
			{"item_id": "yinzi", "flipped": false}]},
		{"kind": "enemy", "enemy_id": "落魄拳师", "alert": 0},
	]
	board._refresh()
	board._on_card_action(0)        # 开盖 → 弹窗
	board._on_container_flip(0, 0)  # 翻一张（亮牌 + 稀有度描边）
	await get_tree().process_frame
	await get_tree().process_frame
	var fails: Array[String] = []
	var popup: ContainerPopup = board.container_popup
	if not popup.is_open():
		fails.append("弹窗未打开")
	else:
		var window := popup.get_node_or_null("PanelContainer") if popup.get_child_count() > 1 else null
		# 窗体是 CenterContainer 下的 PanelContainer
		for child in popup.get_children():
			if child is CenterContainer:
				for cc in child.get_children():
					if cc is PanelContainer:
						window = cc
		if window == null:
			fails.append("未找到弹窗窗体 PanelContainer")
		else:
			var win_rect: Rect2 = window.get_global_rect()
			var slots := 0
			for holder in _slots_of(window):
				slots += 1
				if not win_rect.grow(1.0).encloses(holder.get_global_rect()):
					fails.append("卡槽 %s 越出窗体（槽=%s 窗=%s）" % [holder.name, holder.get_global_rect(), win_rect])
			if slots != 3:
				fails.append("卡槽数 %d（应为 3）" % slots)
			var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
			if not screen.encloses(win_rect):
				fails.append("窗体越出屏幕（%s）" % win_rect)
			print("窗体=%s 卡槽=%d" % [win_rect, slots])
	if not fails.is_empty():
		for f in fails:
			push_error("M9 CHECK FAIL: " + f)
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.3).timeout
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("user://container_shot.png")
	print("PASS: 容器弹窗（开盖/翻牌/几何）通过")
	get_tree().quit(0)

# 窗体里所有内容物卡槽（Control 且带 custom_minimum_size 的直接叶子）。
func _slots_of(window: Control) -> Array:
	var out: Array = []
	for vbox in window.get_children():
		if not (vbox is VBoxContainer):
			continue
		for row in vbox.get_children():
			if row is HBoxContainer:
				for holder in row.get_children():
					if holder is Control and holder.custom_minimum_size.x > 10:
						out.append(holder)
	return out
