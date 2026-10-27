## 一次性截图探针（带渲染，墙钟计时）：五态后自退
## 1.5s 遴选设态 → 6.5s 遴选详情卡 → 8.5s 关 → 9.5s 确认入组 → 11s 装备窗（装备槽）
## → 12s 装备窗内放大详情卡 → 14s 关详情关窗 → 15s 设置窗 → 18.5s 自退
extends SceneTree

var _t0: int = 0
var _col1: Control = null
var _rso: Control = null
var _flow: Control = null
var _stage: int = 0

func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/Root.tscn")

func _process(_delta: float) -> bool:
	var elapsed: float = (Time.get_ticks_msec() - _t0) / 1000.0
	if elapsed >= 1.5 and _stage < 1:
		_stage = 1
		var run_screen = root.find_child("RunScreen", true, false)
		if run_screen != null:
			run_screen.visible = true
		_rso = root.find_child("RunStartOptions", true, false)
		if _rso == null:
			print("shot: rso missing")
			quit()
			return true
		_rso._on_run_started()
		var host = _rso._cards_host
		_col1 = host.get_child(1)
		_visible_face(host.get_child(0)).pressed.emit()
		(_col1.get_child(1).get_child(1) as Button).pressed.emit()
		_visible_face(host.get_child(2)).pressed.emit()
		print("shot: states set")
		return false
	if elapsed >= 6.5 and _stage < 2:
		_stage = 2
		(_col1.get_meta("detail_button") as Button).pressed.emit()
		print("shot: selection detail open")
		return false
	if elapsed >= 8.5 and _stage < 3:
		_stage = 3
		_rso._close_column_detail()
		print("shot: selection detail closed")
		return false
	if elapsed >= 9.5 and _stage < 4:
		_stage = 4
		_rso._on_confirm_pressed()
		_flow = root.find_child("QiRunFlow", true, false)
		print("shot: confirm pressed")
		return false
	if elapsed >= 11.0 and _stage < 5:
		_stage = 5
		if _flow != null:
			_flow._open_slot_dialog(0)
			print("shot: equip dialog open")
		return false
	if elapsed >= 12.0 and _stage < 6:
		_stage = 6
		if _flow != null and not _flow._owned_xinfa.is_empty():
			_flow._open_xinfa_detail(_flow._owned_xinfa[0])
			print("shot: equip detail open")
		return false
	if elapsed >= 14.0 and _stage < 7:
		_stage = 7
		if _flow != null:
			_flow._close_slot_detail()
			_flow._slot_dialog.hide()
			print("shot: equip dialog closed")
		return false
	if elapsed >= 15.0 and _stage < 8:
		_stage = 8
		if _flow != null:
			_flow._on_settings_pressed()
			print("shot: settings open")
		return false
	if elapsed >= 18.5:
		print("shot: done")
		quit()
		return true
	return false

func _visible_face(column: Control) -> Button:
	for child in column.get_child(0).get_children():
		if child is Button and child.visible:
			return child
	return null
