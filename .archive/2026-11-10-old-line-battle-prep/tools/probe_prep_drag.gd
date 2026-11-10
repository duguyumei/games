## 备战舱拖拽/装备窗回归探针。跑法＝非无头：
## godot --path . --script res://qiforge/tools/probe_prep_drag.gd
## §1 卡拖卡换位（2026-10-28 槽位制退役后唯一拖拽形态）：列0 幽冥剑 ↔ 列1 天丝手套
## §2 复发核心：新位再拖（修前＝预览模板被引擎释放成悬空引用，再拖起不了拖）＋拖中截图
## §3 装备窗点击（修前＝AcceptDialog 注解即崩）：QiDialogBox 在树且可见、1080 宽
## 注意：合成 motion 必须带 relative（引擎按 relative 累积过阈值才启动拖拽）。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const PREP := preload("res://qiforge/QiPrepBay.tscn")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var screen: Control = PREP.instantiate()
	root.add_child(screen)
	for i in 30:
		await process_frame

	var row := screen.get_node("CrewRow") as HBoxContainer
	var name_of := func(col_i: int) -> String:
		var nl: Label = row.get_child(col_i).get_child(0).get_child(0)
		return String(nl.text).split("　")[0]

	## —— §1 卡拖卡换位：列0 幽冥剑 → 列1 天丝手套 ——
	var wrap0d: Control = row.get_child(0).get_child(1)
	var c0 := wrap0d.global_position + wrap0d.size * 0.5
	var wrap1: Control = row.get_child(1).get_child(1)
	var c1 := wrap1.global_position + wrap1.size * 0.5
	_eq(name_of.call(0), "幽冥剑", "§1 拖前列0=幽冥剑")
	await _drag(c0, c1, "§1")
	for i in 10:
		await process_frame
	_eq(name_of.call(0), "天丝手套", "§1 换位后列0=天丝手套")
	_eq(name_of.call(1), "幽冥剑", "§1 换位后列1=幽冥剑")
	_eq((screen.get("_crew") as Array).size(), 2, "§1 紧凑序无空位（列数仍 2）")

	## —— §2 复发核心：新位（列0）再拖 → 列1（拖回复原）——
	var wrap0b: Control = row.get_child(0).get_child(1)
	if not is_instance_valid(wrap0b.get("preview_card")):
		fails.append("§2 新壳预览模板悬空")
	var c0b := wrap0b.global_position + wrap0b.size * 0.5
	await _drag(c0b, c1, "§2")
	for i in 10:
		await process_frame
	_eq(name_of.call(0), "幽冥剑", "§2 拖回复原列0=幽冥剑")
	_eq(name_of.call(1), "天丝手套", "§2 拖回复原列1=天丝手套")

	## —— §3 装备窗（真点击：悬停命中→按下→释放；2026-10-28 用户报点击无效）——
	var col0: Control = row.get_child(0)
	var eqr: Control = col0.get_child(2)
	_near(eqr.global_position.x + eqr.size.x * 0.5, col0.global_position.x + col0.size.x * 0.5, 2.0,
		"§3 装备格行居中于列（偏左 bug）")
	var eq0: BaseButton = eqr.get_child(0)
	# 注包（默认局包空——不注则 _make_bag_item 永不执行，Label/bbcode 类崩溃漏网）
	var bag: Array = screen.run_data.get("bag", [])
	bag.push_back("p1")
	screen.run_data["bag"] = bag
	var ec := eq0.global_position + eq0.size * 0.5
	var hov_move := InputEventMouseMotion.new()
	hov_move.position = ec
	hov_move.global_position = ec
	Input.parse_input_event(hov_move)
	await process_frame
	await process_frame
	var hov := root.gui_get_hovered_control()
	if hov != eq0:
		fails.append("§3 悬停命中非装备格（得 %s＝点击被它吃掉）" % str(hov))
	await _click(ec)
	for i in 5:
		await process_frame
	if not is_instance_valid(screen.find_child("QiScrim", false, false)):
		fails.append("§3 装备窗背板未在树（弹窗没开＝崩溃路径复发）")
	var box := _find_dialog_box()
	if box == null:
		fails.append("§3 未找到 QiDialogBox（修前此处因注解崩溃打不开）")
	else:
		if not box.visible:
			fails.append("§3 弹窗盒不可见")
		_near(box.size.x, 1080.0, 8.0, "§3 装备窗宽 1080")
		_near(box.global_position.x, (root.size.x - box.size.x) * 0.5, 6.0, "§3 装备窗居中 x（popup 真跑了）")
		_near(box.global_position.y, (root.size.y - box.size.y) * 0.5, 6.0, "§3 装备窗居中 y")
		var found := false
		for lbl in box.find_children("*", "Label", true, false):
			if "插件1" in lbl.text:
				found = true
		if not found:
			fails.append("§3 背包条目未建（_make_bag_item 崩溃复发）")
		root.get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/.qi_equip_dialog.png")

	print("DRAG_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("PREP_DRAG_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)

## 全程拖放：按下→20 步渐移（带 relative 过阈值起拖）→§2 半程驻留断言＋截图→终点→释放
func _drag(from: Vector2, to: Vector2, tag: String) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	Input.parse_input_event(press)
	await process_frame
	var steps := 20
	var seen_drag := false
	var seen_preview := false
	var prev := from
	for i in steps:
		var m := InputEventMouseMotion.new()
		var t := float(i + 1) / float(steps)
		var p := from.lerp(to, t)
		m.position = p
		m.global_position = p
		m.relative = p - prev
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		prev = p
		Input.parse_input_event(m)
		await process_frame
		if root.gui_is_dragging():
			seen_drag = true
			var pv := root.find_child("QiDragPreview", true, false)
			if pv != null and pv.is_visible_in_tree():
				seen_preview = true
		if tag == "§2" and i == steps / 2:
			if not seen_drag:
				fails.append("§2 二拖未起拖（复发核心断言失败）")
			elif not seen_preview:
				fails.append("§2 二拖预览不在树/不可见（＝用户所见「看不到卡牌移动」）")
			else:
				root.get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/.qi_prep_drag.png")
	if not seen_drag:
		fails.append("%s 未起拖" % tag)
	if seen_drag and not seen_preview:
		fails.append("%s 拖中预览不在树/不可见" % tag)
	for i in 4:  # 停终点等落点跟踪稳定
		var hold := InputEventMouseMotion.new()
		hold.position = to
		hold.global_position = to
		hold.relative = Vector2(1, 0)
		hold.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(hold)
		await process_frame
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = to
	rel.global_position = to
	Input.parse_input_event(rel)
	for i in 3:
		await process_frame

func _click(pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	Input.parse_input_event(press)
	await process_frame
	await process_frame
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = pos
	rel.global_position = pos
	Input.parse_input_event(rel)

func _find_dialog_box() -> Control:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var sc = n.get_script() if n is Control else null
		if sc != null and sc.resource_path == "res://qiforge/QiDialogBox.gd":
			return n
		for c in n.get_children():
			stack.push_back(c)
	return null

func _eq(got, want, tag: String) -> void:
	if got != want:
		fails.append("%s：期望 %s，实测 %s" % [tag, str(want), str(got)])

func _near(got: float, want: float, tol: float, tag: String) -> void:
	if abs(got - want) > tol:
		fails.append("%s：期望 %.1f±%.1f，实测 %.1f" % [tag, want, tol, got])
