extends GutTest

# 演武场功法/内功槽弹窗回归：弹窗标注当前槽与他槽、选已装项＝两槽互换不重复、选空位只清本槽。

const DojoScene := preload("res://scenes/dojo/dojo.tscn")

# 初始装配（data/player.json）：techniques 6 槽满编、xinfa 前 3 槽
const TECH_INITIAL := ["点星式", "连风式", "纵横式", "一气·拒", "二重·壁", "二合·屏"]
const XINFA_INITIAL := ["调息诀", "先纳功", "养木功"]

func _make_dojo() -> Control:
	var ui: Control = DojoScene.instantiate()
	add_child_autofree(ui)
	await get_tree().process_frame
	return ui

func _picker_grid(ui: Control) -> GridContainer:
	return ui._picker.get_node("Center/Panel/Margin/VBox/Scroll/Grid") as GridContainer

# 找弹窗卡上叠的角签文本（"当前"／"第N槽"）；功法卡自身的名字/效果 Label 不会长这样
func _corner_tags(card: Control) -> Array[String]:
	var out: Array[String] = []
	for sub in card.get_children():
		if sub is Label:
			var text := str((sub as Label).text)
			if text == "当前" or (text.begins_with("第") and text.ends_with("槽")):
				out.append(text)
	return out

func test_picker_marks_current_and_other_slots() -> void:
	var ui := await _make_dojo()
	ui._open_picker("tech", 0)
	var current_ids: Array[String] = []
	var other_ids: Array[String] = []
	for child in _picker_grid(ui).get_children():
		var v: Dictionary = child.get_meta("pick_value", {})
		if v.is_empty():
			continue
		var tags := _corner_tags(child)
		if tags.has("当前"):
			current_ids.append(str(v.get("id", "")))
		elif not tags.is_empty():
			other_ids.append("%s@%s" % [str(v.get("id", "")), tags[0]])
	assert_eq(current_ids.size(), 1, "恰一张卡标'当前'")
	assert_eq(current_ids[0] if not current_ids.is_empty() else "", TECH_INITIAL[0], "'当前'＝点击槽的功法")
	assert_eq(other_ids.size(), TECH_INITIAL.size() - 1, "其余已装槽各标'第N槽'")
	# 点第 1 槽时：连风式@第2槽、纵横式@第3槽、一气·拒@第4槽、二重·壁@第5槽、二合·屏@第6槽
	for i in range(1, TECH_INITIAL.size()):
		assert_true(other_ids.has("%s@第%d槽" % [TECH_INITIAL[i], i + 1]),
			"%s 应标第 %d 槽" % [TECH_INITIAL[i], i + 1])

func test_picking_equipped_technique_swaps_slots() -> void:
	var ui := await _make_dojo()
	ui._on_picked({"kind": "tech", "index": 4, "id": "点星式"})
	assert_eq(ui._tech_sel[4], "点星式", "点星式换到第 5 槽")
	assert_eq(ui._tech_sel[0], "二重·壁", "原第 5 槽功法填回第 1 槽（互换）")
	var seen := {}
	for sel in ui._tech_sel:
		assert_false(seen.has(sel), "每门功法只占一槽：%s" % sel)
		seen[sel] = true

func test_picking_into_empty_slot_moves_and_clears_old() -> void:
	var ui := await _make_dojo()
	ui._on_picked({"kind": "tech", "index": 2, "id": ""})  # 第 3 槽清空
	assert_eq(ui._tech_sel[2], "", "选空位清空点击槽")
	assert_eq(ui._tech_sel[0], TECH_INITIAL[0], "其余槽不动")
	ui._on_picked({"kind": "tech", "index": 2, "id": "点星式"})  # 已装项移入空槽
	assert_eq(ui._tech_sel[2], "点星式", "点星式移入第 3 槽")
	assert_eq(ui._tech_sel[0], "", "原槽因互换而清空（本槽原来是空）")

func test_picking_xinfa_swaps_and_marks() -> void:
	var ui := await _make_dojo()
	ui._on_picked({"kind": "xinfa", "index": 4, "id": XINFA_INITIAL[0]})
	assert_eq(ui._xinfa_sel[4], XINFA_INITIAL[0], "心法换到第 5 槽")
	assert_eq(ui._xinfa_sel[0], "", "原槽清空（第 5 槽原来是空）")
	ui._open_picker("xinfa", 4)
	var current_ids: Array[String] = []
	for child in _picker_grid(ui).get_children():
		var v: Dictionary = child.get_meta("pick_value", {})
		if v.is_empty():
			continue
		if _corner_tags(child).has("当前"):
			current_ids.append(str(v.get("id", "")))
	assert_eq(current_ids, [XINFA_INITIAL[0]], "心法弹窗同样标注当前槽")
