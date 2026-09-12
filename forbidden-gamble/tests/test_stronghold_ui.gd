extends GutTest

# 据点构筑/参悟面板交互回归：注入裸 archive 隔离真档（备战页同款模式），
# 钉场景接线——构筑面板槽位/装备/卸下/规则汇总、参悟面板研读/白卷。

const TEST_META_PATH := "user://test_stronghold_ui_meta.json"
const StrongholdScene := preload("res://scenes/stronghold/stronghold.tscn")
const ArchiveScript := preload("res://core/meta/meta_archive.gd")

func after_each() -> void:
	if FileAccess.file_exists(TEST_META_PATH):
		DirAccess.remove_absolute(TEST_META_PATH)

func _archive() -> Node:
	var archive := ArchiveScript.new()
	archive.meta_path = TEST_META_PATH
	add_child_autofree(archive)
	return archive

func _make_stronghold(archive: Node) -> Control:
	var ui: Control = StrongholdScene.instantiate()
	ui.set("archive", archive)  # 场景根脚本属性经动态 set 注入（Control 静态类型无此属性）
	add_child_autofree(ui)
	await get_tree().process_frame  # _ready 里的 await 需过帧
	return ui

func _build_content(ui: Control) -> VBoxContainer:
	return ui.get_node("BuildPanel/Margin/VBox/BScroll/BContent") as VBoxContainer

func _find_button_with_text(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and str((child as Button).text).contains(text):
			return child
		if child is Container or child is Control:
			var found := _find_button_with_text(child, text)
			if found != null:
				return found
	return null

func _find_buttons_with_text(parent: Node, text: String) -> Array:
	var out: Array = []
	for child in parent.get_children():
		if child is Button and str((child as Button).text).contains(text):
			out.append(child)
		if child is Container or child is Control:
			out.append_array(_find_buttons_with_text(child, text))
	return out

func test_build_panel_shows_slots_and_rules() -> void:
	var archive := _archive()
	var ui := await _make_stronghold(archive)
	ui.call("_open_build")
	assert_true((ui.get_node("BuildPanel") as Control).visible, "构筑面板应打开")
	await get_tree().process_frame
	var content := _build_content(ui)
	assert_gt(content.get_child_count(), 6, "面板应包含心法槽/已学/功法槽/牌库/规则汇总各区")
	# 默认构筑 3 门心法：规则汇总应披露其效果文本（数据即真相）
	var rules_text := ""
	for child in content.get_children():
		if child is VBoxContainer:
			for line in child.get_children():
				if line is Label:
					rules_text += str((line as Label).text)
	assert_string_contains(rules_text, "调息诀", "规则汇总披露装备心法")
	assert_string_contains(rules_text, "洗入丹田", "规则文本来自 XinfaRuntime.effect_text")

func test_build_panel_equips_and_unequips_xinfa() -> void:
	var archive := _archive()
	archive.learn_xinfa("龟息功")
	var ui := await _make_stronghold(archive)
	ui.call("_open_build")
	await get_tree().process_frame
	# 点击已学列表里的龟息功上阵
	var equip_button := _find_button_with_text(ui.get_node("BuildPanel"), "龟息功")
	assert_not_null(equip_button, "已学心法应出现在装备列表")
	assert_false(equip_button.disabled, "未装备的心法可点")
	equip_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(archive.loadout["xinfa"].size(), 4, "装备后 3→4 门")
	assert_true(archive.loadout["xinfa"].has("龟息功"))
	# 点击装备槽里的龟息功卸下
	var slot_button := _find_buttons_with_text(ui.get_node("BuildPanel"), "龟息功").filter(
		func(b): return str(b.text) == "龟息功")
	assert_gt(slot_button.size(), 0, "装备槽应显示龟息功")
	(slot_button[0] as Button).pressed.emit()
	await get_tree().process_frame
	assert_eq(archive.loadout["xinfa"].size(), 3, "卸下后回到 3 门")
	assert_false(archive.loadout["xinfa"].has("龟息功"))

func test_study_panel_reads_and_consumes_manual() -> void:
	var archive := _archive()
	archive.store_items([{"id": "guixigupian", "name": "龟息古篇", "qty": 1, "value": 45, "rarity": "fine"}])
	var ui := await _make_stronghold(archive)
	ui.call("_open_study")
	assert_true((ui.get_node("StudyPanel") as Control).visible, "参悟面板应打开")
	await get_tree().process_frame
	var study_button := _find_button_with_text(ui.get_node("StudyPanel"), "研读")
	assert_not_null(study_button, "仓库里的秘籍应可研读")
	study_button.pressed.emit()
	await get_tree().process_frame
	assert_true(archive.knows_xinfa("龟息功"), "研读习得龟息功")
	assert_true(archive.warehouse.is_empty(), "秘籍参悟即蚀")
	# 白卷：_notice 面板给出原因，再研读同书被拒（仓库已空，列表为空提示）
	var notice := ui.get_node("NoticePanel") as Control
	assert_true(notice.visible, "参悟结果弹提示")
	var notice_text := str((notice.get_node("Margin/VBox/NText") as Label).text)
	assert_string_contains(notice_text, "龟息功")
