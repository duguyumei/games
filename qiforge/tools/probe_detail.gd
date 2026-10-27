## 器灵详情页探针（2026-10-27 裁定：主卡＋右列功法真卡＝衍生牌；拖拽不得误弹详情）。
## 跑法＝非无头：godot --path . --script res://qiforge/tools/probe_detail.gd
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const PREP := preload("res://qiforge/QiPrepBay.tscn")
const QICARD := preload("res://qiforge/QiCardStyle.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var screen: Control = PREP.instantiate()
	root.add_child(screen)
	await _frames(25)
	var base_kids: int = screen.get_child_count()

	var wrap: Control = screen.get_node("CrewRow").get_child(0).get_child(1)
	var center: Vector2 = wrap.get_global_rect().get_center()

	# ── 试一：纯点击（按→放）应开详情页 ──
	_click(center)
	await _frames(3)
	if screen.get_child_count() != base_kids + 1:
		fails.append("点击后应新增详情层（得 %d 望 %d）" % [screen.get_child_count(), base_kids + 1])
		_finish()
		return
	var layer: Control = screen.get_child(screen.get_child_count() - 1)
	var row: HBoxContainer = null
	for c in layer.get_children():
		if c is HBoxContainer:
			row = c
	if row == null:
		fails.append("详情层内无组合行")
		_finish()
		return
	if row.get_child_count() != 2:
		fails.append("组合行应＝主卡＋衍生列（得 %d）" % row.get_child_count())
	var main_c: Control = row.get_child(0)
	var col: Control = row.get_child(1)
	_near(main_c.size.x, QICARD.size_of("detail").x, 4.0, "主卡宽（工厂 detail 档）")
	_near(main_c.size.y, QICARD.size_of("detail").y, 4.0, "主卡高（工厂 detail 档）")
	if col.global_position.x <= main_c.global_position.x + main_c.size.x:
		fails.append("衍生列应在主卡右侧")
	if col.get_child_count() != 3:
		fails.append("衍生列应＝题注＋两张功法卡（得 %d）" % col.get_child_count())
	else:
		var cap := col.get_child(0)
		if not ("衍生牌" in str(cap.get("text"))):
			fails.append("题注应为功法·衍生牌（得 %s）" % str(cap.get("text")))
		var texts := ""
		for i in 2:
			var sc: Control = col.get_child(i + 1)
			_near(sc.size.x, QICARD.size_of("field").x, 4.0, "功法卡宽（工厂 field 档）")
			_near(sc.size.y, QICARD.size_of("field").y, 4.0, "功法卡高（工厂 field 档）")
			texts += _texts_of(sc) + "|"
		for want in ["索敌令", "灭魂斩"]:
			if not (want in texts):
				fails.append("衍生卡缺「%s」（收 %s）" % [want, texts])
		if col.get_child(1).global_position.y <= cap.global_position.y:
			fails.append("功法卡应在题注下方竖排")
		if col.get_child(2).global_position.y <= col.get_child(1).global_position.y + col.get_child(1).size.y * 0.9:
			fails.append("两功法卡应竖排不重叠")
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/qi_detail_open.png")

	# ── 关闭（点遮罩）──
	layer.get_child(0).get_global_rect()  # scrim
	_click(Vector2(60.0, 60.0))
	await _frames(4)
	if screen.get_child_count() != base_kids:
		fails.append("点遮罩后详情层应关闭（得 %d 望 %d）" % [screen.get_child_count(), base_kids])

	# ── 试二：按→拖→放 不得弹详情（真实手势序＝单次按压→起拖→单次释放）──
	_press(center)
	var preview := Control.new()
	preview.size = Vector2(60.0, 60.0)
	wrap.force_drag({"drag_data": {"slot": 0}}, preview)
	await _frames(3)
	if not root.gui_is_dragging():
		fails.append("试二前置：force_drag 应已进入原生拖拽")
	if not wrap.drag_armed:
		fails.append("试二前置：起拖后 drag_armed 应为真")
	_release(center)
	await _frames(4)
	if root.gui_is_dragging():
		fails.append("释放后拖拽应已结束")
	if screen.get_child_count() != base_kids:
		fails.append("拖拽后不应弹出详情层（得 %d 望 %d）" % [screen.get_child_count(), base_kids])
	_finish()

func _finish() -> void:
	print("DETAIL_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("DETAIL_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _press(at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at
	ev.global_position = at
	root.push_input(ev)

func _click(at: Vector2) -> void:
	_press(at)
	_release(at)

func _release(at: Vector2) -> void:
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = at
	rel.global_position = at
	root.push_input(rel)

func _texts_of(node: Node) -> String:
	var out := ""
	if node.get("text") != null:
		out += str(node.get("text"))
	for c in node.get_children():
		out += _texts_of(c)
	return out

func _near(v: float, want: float, tol: float, tag: String) -> void:
	if abs(v - want) > tol:
		fails.append("%s 偏差（得 %.1f 要 %.1f 容 %.1f）" % [tag, v, want, tol])
