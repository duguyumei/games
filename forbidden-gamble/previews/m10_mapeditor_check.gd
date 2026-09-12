extends Node
# 锚点编辑器验收（D-059 布点调整工具）：
# 实例化 map_editor → 断言 49 个标记生成（D-059 合并定稿版）、路图层可重绘 →
# 模拟拖动一个节点（位移 30px）→ 保存 → 验证 JSON 坐标变化 → 还原保存。

func _ready() -> void:
	var editor: Control = load("res://scenes/map_editor/map_editor.tscn").instantiate()
	add_child(editor)
	await get_tree().process_frame
	await get_tree().process_frame

	var fails: Array[String] = []
	# UI 为代码搭建：markers/node_layer/edge_layer 都是脚本公开成员
	var markers: Dictionary = editor.markers
	if markers.size() != 49:
		fails.append("标记数 != 49（实际 %d）" % markers.size())
	var edge_layer: Control = editor.edge_layer
	edge_layer.queue_redraw()
	await get_tree().process_frame

	# 模拟拖动 + 点「保存」按钮（走 pressed 信号，验证按钮接线）+ 校验 + 还原
	var mk: Control = markers.get("wai_well")
	if mk == null:
		fails.append("找不到 wai_well 标记")
	else:
		var save_btn := _find_save_button(editor)
		if save_btn == null:
			fails.append("找不到保存按钮")
		else:
			var old_pos := mk.position
			mk.position = old_pos + Vector2(30, 0)
			save_btn.pressed.emit()
			var x_moved := _read_node_x("wai_well")
			mk.position = old_pos
			editor._save_json()
			var x_restored := _read_node_x("wai_well")
			var expect := (old_pos.x + mk.size.x / 2.0 + 30.0) / 1672.0
			if absf(x_moved - expect) > 0.001:
				fails.append("点保存按钮后坐标未随拖动变化（%f vs 期望 %f）" % [x_moved, expect])
			if absf(x_restored - (old_pos.x + mk.size.x / 2.0) / 1672.0) > 0.001:
				fails.append("还原失败（%f）" % x_restored)
			if editor.dirty:
				fails.append("保存后 dirty 未清零")

	if fails.is_empty():
		print("M10 PASS：49 标记·拖动保存还原全过")
		get_tree().quit(0)
	else:
		print("M10 FAIL：", "; ".join(fails))
		get_tree().quit(1)

func _find_save_button(root: Node) -> Button:
	for child in root.get_children():
		if child is Button and (child as Button).text.begins_with("保存"):
			return child
		var found: Button = _find_save_button(child)
		if found != null:
			return found
	return null

func _read_node_x(id: String) -> float:
	var f := FileAccess.open("res://data/qingfeng_map.json", FileAccess.READ)
	if f == null:
		return -1.0
	var parsed: Dictionary = JSON.parse_string(f.get_as_text())
	for n in parsed["nodes"]:
		if str(n["id"]) == id:
			return float(n["x"])
	return -1.0
