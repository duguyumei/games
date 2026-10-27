## 一次性探针：无头加载 Root，模拟 run_started，验证遴选窗 v2.2 交互
## （迷你卡切面／点卡面选中与选满锁定／「详情」按钮弹放大卡／点卡或遮罩关闭）
extends SceneTree

var _frames: int = 0

func _initialize() -> void:
	change_scene_to_file("res://scenes/Root.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 40:
		var run_screen = root.find_child("RunScreen", true, false)
		if run_screen != null:
			run_screen.visible = true
		var rso0 = root.find_child("RunStartOptions", true, false)
		if rso0 != null:
			rso0._on_run_started()
		return false
	if _frames == 130:
		_probe()
		quit()
		return true
	return false

func _probe() -> void:
	var rso = root.find_child("RunStartOptions", true, false)
	if rso == null:
		print("probe: RunStartOptions NOT FOUND")
		return
	print("probe: dialog=", rso._dialog.visible if rso._dialog != null else "null")
	var host = rso._cards_host
	print("probe: columns=", host.get_child_count(), " host_visible=", host.is_visible_in_tree())

	# 1) 迷你卡切面：第二列切「术法一」
	var col1 = host.get_child(1)
	(col1.get_child(1).get_child(1) as Button).pressed.emit()
	print("probe: after_mini2 face=", _visible_face(col1).name, " (expect face_spell1)",
		" face_index=", int(col1.get_meta("face_index")))

	# 2) 点卡面选中：col0、col2 → picked=2；选满后 col3 点卡应无效
	_visible_face(host.get_child(0)).pressed.emit()
	_visible_face(host.get_child(2)).pressed.emit()
	print("probe: picked=", rso._picked_columns.size(),
		" ring0=", (host.get_child(0).get_meta("ring") as Panel).visible,
		" ring2=", (host.get_child(2).get_meta("ring") as Panel).visible,
		" (expect 2/true/true)")
	_visible_face(host.get_child(3)).pressed.emit()
	print("probe: picked_after_locked=", rso._picked_columns.size(), " (expect 2)")

	# 3) 再点已选卡＝取消，随后改选 col3
	_visible_face(host.get_child(2)).pressed.emit()
	print("probe: picked_after_cancel=", rso._picked_columns.size(),
		" ring2=", (host.get_child(2).get_meta("ring") as Panel).visible, " (expect 1/false)")
	_visible_face(host.get_child(3)).pressed.emit()
	print("probe: picked_swap=", rso._picked_columns.size(), " (expect 2)")

	# 4) 「详情」按钮：col1（当前面＝术法一）→ 层开、放大卡；点卡关闭
	(col1.get_meta("detail_button") as Button).pressed.emit()
	print("probe: detail_open=", rso._detail_layer != null)
	if rso._detail_layer != null:
		var detail_card: Button = rso._detail_layer.get_child(1) as Button
		print("probe: detail_size=", detail_card.size, " (expect 270x345)")
		detail_card.pressed.emit()
		print("probe: detail_closed=", rso._detail_layer == null)

func _visible_face(column: Control) -> Button:
	for child in column.get_child(0).get_children():
		if child is Button and child.visible:
			return child
	return null
