## qi-forge 备战层（设计稿 v13 落地）：小丑牌式局结构，无地图无节点。
## 布局：顶栏（生命/组·场/进度）＋左列（属性｜可用点数、真气｜内力属性）＋
## 中场（心法槽｜可用历练，两行五列，运转在卡下）＋右列（当前卡组｜N 张，悬停出整卡预览）＋底部进入战斗。
## 活链：加号→命中属性→内力属性实时重判；运转（3 历练）→等级/轻灵真气＋1。
## 挂载：Root.tscn RunScreen/QiRunFlow（unique_name_in_owner，供 %QiRunFlow 跨脚本调用）。
extends Control

const FIGHTS_PER_GROUP: int = 3
const GROUPS_PER_RUN: int = 6
const FIGHT_EVENT_ID: String = "event_qif_g1_fight1"
const QIF_DIALOG_FACTORY = preload("res://qiforge/QiDialog.gd")
const QIF_CARD = preload("res://qiforge/QiCardStyle.gd")
const QIF_FONTS = preload("res://qiforge/QiFontBank.gd")
const QIF_GEN = preload("res://qiforge/QiForgeDataGenerator.gd")

## 心法槽：两行五列共 10 位（2026-10-25 用户口述布局）
const XINFA_SLOT_COUNT: int = 10
const XINFA_SLOT_COLUMNS: int = 5
## 战后奖励（档 §5/§7：命中属性三选二各+1 → 2 点；历练来源待定，暂定每场 3 供试玩运转）
const POINTS_PER_VICTORY: int = 2
const LILIAN_PER_VICTORY: int = 3
## 额外运转：3 历练/次，每心法每场限 1 次（档 §5）
const YUNZHUAN_COST: int = 3
## 心法线 → 真气型（攻击→催破、防御→护体、身法→轻灵）
const LINE_TO_QI: Dictionary = {"身法": "轻灵", "护体": "护体", "催破": "催破"}
## 命中属性 → 内力属性名（档 §8）
const HIT_TO_NEILI: Dictionary = {"力道": "刚", "迅疾": "轻", "精妙": "柔"}

const COLOR_BG_BLUE: Color = Color(0.157, 0.271, 0.408)
const COLOR_PANEL_CREAM: Color = Color(0.93, 0.90, 0.82)
const COLOR_INK: Color = Color(0.16, 0.14, 0.11)
const COLOR_INK_SOFT: Color = Color(0.42, 0.38, 0.32)
const COLOR_CREAM: Color = Color(0.949, 0.922, 0.847)
const COLOR_RED: Color = Color(0.788, 0.227, 0.227)
const COLOR_AMBER: Color = Color(0.976, 0.859, 0.451)
const COLOR_AMBER_TEXT: Color = Color(0.72, 0.45, 0.04)

var _group_index: int = 1
var _fight_index: int = 1

## 心法数据：全部获得、10 槽装备表、等级
var _owned_xinfa: Array = []
var _xinfa_slots: Array = []
var _xinfa_levels: Dictionary = {}

## 活链数值
var _points_available: int = 0
var _hit_stats: Dictionary = {"力道": 5, "迅疾": 5, "精妙": 5}
var _qi_amounts: Dictionary = {"催破": 0, "护体": 0, "轻灵": 0}

var _round_label: Label
var _progress_label: Label
var _hp_label: Label
var _points_chip: Label
var _neili_chip: Label
var _lilian_chip: Label
var _hit_value_labels: Dictionary = {}
var _hit_plus_buttons: Dictionary = {}
var _basic_value_labels: Dictionary = {}
var _qi_value_labels: Dictionary = {}
var _xinfa_grid: GridContainer
var _deck_count_chip: Label
var _deck_list_container: VBoxContainer
var _slot_dialog: Control = null        # QiDialogBox（Control 弹窗制，勿回 AcceptDialog）
var _slot_detail_layer: Control = null
var _settings_dialog: Control = null    # 同上
var _hover_preview: Control = null

func _ready() -> void:
	_build_ui()
	Signals.run_started.connect(_on_run_started)

#region 界面搭建
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = COLOR_BG_BLUE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	root.offset_left = 24.0
	root.offset_top = 18.0
	root.offset_right = -24.0
	root.offset_bottom = -18.0
	add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_middle_row())
	root.add_child(_build_bottom_bar())

func _build_top_bar() -> Control:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _flat_style(Color(0.10, 0.13, 0.19), 0, 12))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	bar.add_child(row)

	row.add_child(_make_label("备战", 30, COLOR_CREAM))
	_hp_label = _make_label("生命 — / —", 22, Color(0.95, 0.66, 0.66))
	row.add_child(_hp_label)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_round_label = _make_label("第 1 组 · 第 1 场", 24, COLOR_CREAM)
	row.add_child(_round_label)
	_progress_label = _make_label("", 18, Color(0.78, 0.82, 0.88))
	row.add_child(_progress_label)
	var settings_button: Button = _make_flat_button("设置", Color(0.16, 0.2, 0.28))
	settings_button.pressed.connect(_on_settings_pressed)
	row.add_child(settings_button)
	return bar

func _build_middle_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# 左列：属性（3）＋真气（2）双板
	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 12)
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.custom_minimum_size = Vector2(260, 0)
	left_col.size_flags_stretch_ratio = 0.0
	row.add_child(left_col)

	var stats_panel: PanelContainer = _make_panel()
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.size_flags_stretch_ratio = 3.0
	left_col.add_child(stats_panel)
	var stats_col: VBoxContainer = VBoxContainer.new()
	stats_col.add_theme_constant_override("separation", 6)
	stats_panel.add_child(stats_col)

	var stats_head: HBoxContainer = _header_row("属性")
	_points_chip = _chip("可用点数 0")
	stats_head.add_child(_points_chip)
	stats_col.add_child(stats_head)
	stats_col.add_child(_sub_label("基础属性"))
	for pair: Array in [["攻击", "attack"], ["防御", "defense"], ["速度", "speed"]]:
		var basic_row: HBoxContainer = _stat_row(str(pair[0]), null, "—")
		stats_col.add_child(basic_row)
		_basic_value_labels[str(pair[1])] = basic_row.get_child(1)
	stats_col.add_child(_divider())
	stats_col.add_child(_sub_label("命中属性"))
	for stat_name: String in ["力道", "迅疾", "精妙"]:
		var hit_row: HBoxContainer = _stat_row(stat_name, stat_name)
		stats_col.add_child(hit_row)

	var qi_panel: PanelContainer = _make_panel()
	qi_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	qi_panel.size_flags_stretch_ratio = 2.0
	left_col.add_child(qi_panel)
	var qi_col: VBoxContainer = VBoxContainer.new()
	qi_col.add_theme_constant_override("separation", 6)
	qi_panel.add_child(qi_col)
	var qi_head: HBoxContainer = _header_row("真气")
	_neili_chip = _chip("混元")
	qi_head.add_child(_neili_chip)
	qi_col.add_child(qi_head)
	qi_col.add_child(_sub_label("三型（由心法运转提供）"))
	for qi_name: String in ["催破", "护体", "轻灵"]:
		var qi_row: HBoxContainer = _stat_row(qi_name, null)
		qi_col.add_child(qi_row)

	# 中场：心法槽
	var center_panel: PanelContainer = _make_panel()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(center_panel)
	var center_col: VBoxContainer = VBoxContainer.new()
	center_col.add_theme_constant_override("separation", 10)
	center_panel.add_child(center_col)
	var center_head: HBoxContainer = _header_row("心法槽")
	_lilian_chip = _chip("可用历练 0")
	center_head.add_child(_lilian_chip)
	center_col.add_child(center_head)
	center_col.add_child(_hint_label("点击槽位装备 · 点击已装槽查看术法与详情 · 运转在卡下"))
	center_col.add_child(_divider())
	_xinfa_grid = GridContainer.new()
	_xinfa_grid.columns = XINFA_SLOT_COLUMNS
	_xinfa_grid.add_theme_constant_override("h_separation", 24)
	_xinfa_grid.add_theme_constant_override("v_separation", 20)
	_xinfa_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xinfa_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_col.add_child(_xinfa_grid)

	# 右列：当前卡组
	var deck_panel: PanelContainer = _make_panel()
	deck_panel.custom_minimum_size = Vector2(250, 0)
	row.add_child(deck_panel)
	var deck_col: VBoxContainer = VBoxContainer.new()
	deck_col.add_theme_constant_override("separation", 8)
	deck_panel.add_child(deck_col)
	var deck_head: HBoxContainer = _header_row("当前卡组")
	_deck_count_chip = _chip("0 张")
	deck_head.add_child(_deck_count_chip)
	deck_col.add_child(deck_head)
	_deck_list_container = VBoxContainer.new()
	_deck_list_container.add_theme_constant_override("separation", 7)
	_deck_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_col.add_child(_deck_list_container)
	return row

func _build_bottom_bar() -> Control:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	var hint: Label = _make_label("三场为一组 · 共六组", 15, Color(0.80, 0.87, 0.95))
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(hint)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var fight_button: Button = Button.new()
	fight_button.text = "进入战斗"
	fight_button.custom_minimum_size = Vector2(240, 64)
	var btn_style: StyleBoxFlat = _flat_style(COLOR_RED, 3, 12)
	btn_style.content_margin_left = 32.0
	btn_style.content_margin_right = 32.0
	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = Color(0.89, 0.33, 0.26)
	fight_button.add_theme_stylebox_override("normal", btn_style)
	fight_button.add_theme_stylebox_override("hover", btn_hover)
	fight_button.add_theme_stylebox_override("pressed", btn_hover)
	fight_button.add_theme_font_override("font", QIF_FONTS.display())
	fight_button.add_theme_font_size_override("font_size", 26)
	fight_button.add_theme_color_override("font_color", COLOR_CREAM)
	fight_button.pressed.connect(_on_fight_button_pressed)
	bar.add_child(fight_button)
	return bar

#region 小构件
func _make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat_style(COLOR_PANEL_CREAM, 0, 14))
	return panel

func _header_row(title_text: String) -> HBoxContainer:
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_make_label(title_text, 22, COLOR_INK))
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	return head

func _chip(text: String) -> Label:
	var chip: Label = _make_label(text, 18, COLOR_AMBER_TEXT)
	chip.add_theme_constant_override("line_spacing", 0)
	chip.add_theme_stylebox_override("normal", _flat_style(Color(0.97, 0.94, 0.85), 2, 10))
	chip.custom_minimum_size = Vector2(0, 34)
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var st: StyleBoxFlat = chip.get_theme_stylebox("normal") as StyleBoxFlat
	st.content_margin_left = 12.0
	st.content_margin_right = 12.0
	st.content_margin_top = 4.0
	st.content_margin_bottom = 4.0
	st.border_color = Color(0.85, 0.79, 0.64)
	return chip

func _stat_row(name_text: String, plus_stat: Variant, initial_value: String = "—") -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_label: Label = _make_label(name_text, 15, COLOR_INK)
	name_label.custom_minimum_size = Vector2(64, 0)
	row.add_child(name_label)
	if plus_stat == null:
		var value_label: Label = _make_label(initial_value, 15, COLOR_INK)
		row.add_child(value_label)
		if _qi_amounts.has(name_text):
			_qi_value_labels[name_text] = value_label
		return row
	var value_label: Label = _make_label("5", 15, COLOR_INK)
	_hit_value_labels[str(plus_stat)] = value_label
	row.add_child(value_label)
	var plus_button: Button = Button.new()
	plus_button.text = "＋"
	plus_button.custom_minimum_size = Vector2(34, 30)
	var plus_style: StyleBoxFlat = _flat_style(Color(0.227, 0.651, 0.353), 2, 8)
	var plus_hover: StyleBoxFlat = plus_style.duplicate()
	plus_hover.bg_color = Color(0.3, 0.75, 0.42)
	plus_button.add_theme_stylebox_override("normal", plus_style)
	plus_button.add_theme_stylebox_override("hover", plus_hover)
	plus_button.add_theme_stylebox_override("pressed", plus_hover)
	plus_button.add_theme_stylebox_override("disabled", _flat_style(Color(0.81, 0.78, 0.71), 2, 8))
	plus_button.add_theme_font_size_override("font_size", 17)
	plus_button.add_theme_color_override("font_color", COLOR_CREAM)
	plus_button.disabled = true
	plus_button.pressed.connect(_on_plus_pressed.bind(str(plus_stat)))
	_hit_plus_buttons[str(plus_stat)] = plus_button
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(plus_button)
	return row

func _sub_label(text: String) -> Label:
	return _make_label(text, 14, COLOR_INK_SOFT)

func _hint_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", COLOR_INK_SOFT)
	return label

func _divider() -> Control:
	var line: ColorRect = ColorRect.new()
	line.color = Color(0.85, 0.80, 0.70)
	line.custom_minimum_size = Vector2(0, 2)
	return line

func _make_label(text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	if size >= 18:
		label.add_theme_font_override("font", QIF_FONTS.display())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _flat_style(bg: Color, border_px: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	if border_px > 0:
		style.set_border_width_all(border_px)
		style.border_color = COLOR_CREAM
	return style
#endregion
#endregion

func show_prep() -> void:
	_refresh_prep_data()
	visible = true

func _refresh_prep_data() -> void:
	_round_label.text = "第 {0} 组 · 第 {1} 场".format([_group_index, _fight_index])
	var dots: String = ""
	for i in GROUPS_PER_RUN:
		dots += "●" if i < _group_index else "○"
	_progress_label.text = "组 {0}/{1}  {2}".format([_group_index, GROUPS_PER_RUN, dots])
	if Global.player_data != null:
		_hp_label.text = "生命 {0} / {1}".format([Global.player_data.player_health, Global.player_data.player_health_max])
		_lilian_chip.text = "可用历练 {0}".format([Global.player_data.player_money])
		var character: CharacterData = Global.get_character_data(Global.player_data.player_character_object_id)
		if character != null:
			(_basic_value_labels.get("attack") as Label).text = str(character.character_starting_attack)
			(_basic_value_labels.get("defense") as Label).text = str(character.character_starting_defense)
			(_basic_value_labels.get("speed") as Label).text = str(character.character_starting_speed)
	_points_chip.text = "可用点数 {0}".format([_points_available])
	_neili_chip.text = _compute_neili()

	for stat_name: String in _hit_stats:
		(_hit_value_labels[stat_name] as Label).text = str(_hit_stats[stat_name])
		(_hit_plus_buttons[stat_name] as Button).disabled = _points_available <= 0
	for qi_name: String in _qi_amounts:
		_qi_amounts[qi_name] = 0
	for i in _xinfa_slots.size():
		if _xinfa_slots[i] != null:
			var line: String = QIF_CARD.identity_of(str(_xinfa_slots[i].get("id", "")))
			var qi_name: String = LINE_TO_QI.get(line, "轻灵")
			_qi_amounts[qi_name] = int(_qi_amounts[qi_name]) + (_xinfa_levels.get(str(_xinfa_slots[i].get("id", "")), 1) - 1)
	for qi_name: String in _qi_amounts:
		if _qi_value_labels.has(qi_name):
			(_qi_value_labels[qi_name] as Label).text = str(_qi_amounts[qi_name])

	_refresh_xinfa_grid()
	_refresh_deck_list()

## 内力属性（档 §8）：最高 A/次 B/第三 C；(A−C)/A≤20%→混元；否则 (A−B)/A≤20%→主·副；否则单属性
func _compute_neili() -> String:
	var names: Array[String] = ["力道", "迅疾", "精妙"]
	var values: Array = []
	for n: String in names:
		values.append(int(_hit_stats[n]))
	var sorted_values: Array = values.duplicate()
	sorted_values.sort()
	sorted_values.reverse()
	var a: int = sorted_values[0]
	var b: int = sorted_values[1]
	var c: int = sorted_values[2]
	if float(a - c) / float(a) <= 0.2:
		return "混元"
	var main_name: String = names[values.find(a)]
	if float(a - b) / float(a) <= 0.2:
		var sub_name: String = names[values.find(b)]
		return "{0}·{1}".format([HIT_TO_NEILI[main_name], HIT_TO_NEILI[sub_name]])
	return str(HIT_TO_NEILI[main_name])

#region 加点
func _on_plus_pressed(stat_name: String) -> void:
	if _points_available <= 0:
		return
	_points_available -= 1
	_hit_stats[stat_name] = int(_hit_stats[stat_name]) + 1
	_refresh_prep_data()
#endregion

#region 心法槽与装备
func _refresh_xinfa_grid() -> void:
	for child in _xinfa_grid.get_children():
		child.queue_free()
	for i in XINFA_SLOT_COUNT:
		# 槽位容器制（2026-10-25 用户裁定）：十槽同一 VBox 容器——卡/空槽住容器里顶对齐，
		# 装备格多一行运转按钮；格子等高等宽，全区卡面同基线（空槽不再比装备卡矮/坠）
		var cell: VBoxContainer = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		cell.custom_minimum_size = Vector2(QIF_CARD.size_of("field").x, QIF_CARD.size_of("field").y + 36.0)
		if i < _xinfa_slots.size() and _xinfa_slots[i] != null:
			var xinfa: Dictionary = _xinfa_slots[i]
			var xinfa_id: String = str(xinfa.get("id", ""))
			var card: Button = QIF_CARD.make_xinfa_card(xinfa, _xinfa_levels.get(xinfa_id, 1))
			card.pressed.connect(_open_slot_dialog.bind(i))
			cell.add_child(card)
			cell.add_child(_make_yunzhuan_button(xinfa_id))
		else:
			var slot_button: Button = QIF_CARD.make_empty_slot_button()
			slot_button.pressed.connect(_open_slot_dialog.bind(i))
			cell.add_child(slot_button)
		_xinfa_grid.add_child(cell)

## 运转胶囊按钮：文字价签（3历练）＋悬停说明（Godot 原生 tooltip）
func _make_yunzhuan_button(xinfa_id: String) -> Button:
	var line: String = QIF_CARD.identity_of(xinfa_id)
	var qi_name: String = LINE_TO_QI.get(line, "轻灵")
	var button: Button = Button.new()
	button.text = "运转（3历练）"
	button.custom_minimum_size = Vector2(130, 30)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = _flat_style(Color(0.18, 0.322, 0.20), 2, 15)
	style.border_color = COLOR_CREAM
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Color(0.227, 0.42, 0.271)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", COLOR_CREAM)
	button.tooltip_text = "＋1 级 · {0}真气 +1｜花费 3 历练，每心法每场限 1 次".format([qi_name])
	button.pressed.connect(_on_yunzhuan_pressed.bind(xinfa_id))
	return button

## 运转：花 3 历练 → 等级 +1（真气随等级差累计）；每心法每场 1 次限制随战斗管线切片实装
func _on_yunzhuan_pressed(xinfa_id: String) -> void:
	if Global.player_data == null or Global.player_data.player_money < YUNZHUAN_COST:
		print("qi-forge: 运转失败——历练不足")
		return
	Global.player_data.player_money -= YUNZHUAN_COST
	_xinfa_levels[xinfa_id] = _xinfa_levels.get(xinfa_id, 1) + 1
	print("qi-forge: 运转 ", xinfa_id, " → Lv", _xinfa_levels[xinfa_id])
	if _slot_dialog != null:
		_slot_dialog.hide()
	_refresh_prep_data()

## 装备窗（固定 1080×760，2026-10-25 用户裁定）：升级文案不内嵌（不把内容往下挤），
## 全走「详情按钮」弹放大详情卡；已解锁列表超长由 ScrollContainer 滚动。
func _open_slot_dialog(slot_index: int) -> void:
	if _slot_dialog != null:
		_slot_dialog.queue_free()
	_close_slot_detail()
	_slot_dialog = QIF_DIALOG_FACTORY.create(self, "心法槽 · 装备", Vector2(1080, 760), "关闭")[1]
	_slot_dialog.confirmed.connect(func():
		_close_slot_detail()
		_slot_dialog.hide())

	var content: MarginContainer = MarginContainer.new()
	content.add_theme_constant_override("margin_left", 16)
	content.add_theme_constant_override("margin_right", 16)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_bottom", 8)
	_slot_dialog.add_child(content)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(column)

	var current: Dictionary = {}
	if slot_index < _xinfa_slots.size() and _xinfa_slots[slot_index] != null:
		current = _xinfa_slots[slot_index]
	if not current.is_empty():
		var head: HBoxContainer = HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		column.add_child(head)
		head.add_child(_sub_label("当前装备"))
		var head_spacer: Control = Control.new()
		head_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(head_spacer)
		var unequip_button: Button = _make_flat_button("卸下当前心法", COLOR_RED)
		unequip_button.pressed.connect(_on_unequip_pressed.bind(slot_index))
		head.add_child(unequip_button)

		var cards_row: HBoxContainer = HBoxContainer.new()
		cards_row.add_theme_constant_override("separation", 16)
		column.add_child(cards_row)

		var current_cell: VBoxContainer = VBoxContainer.new()
		current_cell.add_theme_constant_override("separation", 6)
		current_cell.add_child(QIF_CARD.make_xinfa_card(current, _xinfa_levels.get(str(current.get("id", "")), 1)))
		var xinfa_detail_button: Button = QIF_CARD.make_detail_button()
		xinfa_detail_button.pressed.connect(_open_xinfa_detail.bind(current))
		current_cell.add_child(xinfa_detail_button)
		cards_row.add_child(current_cell)

		var full: Dictionary = QIF_GEN.get_xinfa_pack_full(str(current.get("id", "")))
		var spell_index: int = 1
		for spell: Array in full.get("spells", []):
			var spell_cell: VBoxContainer = VBoxContainer.new()
			spell_cell.add_theme_constant_override("separation", 6)
			spell_cell.add_child(QIF_CARD.make_spell_card("术法{0}".format([_cn_num(spell_index)]),
				int(spell[0]), str(spell[1])))
			var spell_detail_button: Button = QIF_CARD.make_detail_button()
			spell_detail_button.pressed.connect(_open_spell_detail.bind(spell, spell_index))
			spell_cell.add_child(spell_detail_button)
			cards_row.add_child(spell_cell)
			spell_index += 1
	else:
		column.add_child(_sub_label("（空槽——从下方选择心法装备）"))

	column.add_child(_divider())
	column.add_child(_sub_label("已解锁心法（点击装备到此槽）"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var owned_grid: GridContainer = GridContainer.new()
	owned_grid.columns = 5
	owned_grid.add_theme_constant_override("h_separation", 14)
	owned_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(owned_grid)
	if _owned_xinfa.is_empty():
		owned_grid.add_child(_sub_label("（尚未解锁心法）"))
	for xinfa: Dictionary in _owned_xinfa:
		var pick_cell: VBoxContainer = VBoxContainer.new()
		pick_cell.add_theme_constant_override("separation", 6)
		var pick_card: Button = QIF_CARD.make_xinfa_card(xinfa, _xinfa_levels.get(str(xinfa.get("id", "")), 1))
		pick_card.pressed.connect(_on_equip_from_dialog.bind(slot_index, xinfa))
		pick_cell.add_child(pick_card)
		var pick_detail_button: Button = QIF_CARD.make_detail_button()
		pick_detail_button.pressed.connect(_open_xinfa_detail.bind(xinfa))
		pick_cell.add_child(pick_detail_button)
		owned_grid.add_child(pick_cell)

	_slot_dialog.popup_centered(Vector2i(1080, 760))
	_slot_dialog.size = Vector2i(1080, 760)
	_slot_dialog.min_size = Vector2i(1080, 760)	# 锁死尺寸：内容靠滚条消化，不把关闭键挤走
	QIF_DIALOG_FACTORY.restyle_ok.call_deferred(_slot_dialog)	# popup 的延迟重整会清确认键最小尺寸，须排其后重设

## 详情层（挂装备窗）：放大卡＋遮罩；点卡或遮罩关闭
func _open_slot_detail(detail_card: Button) -> void:
	_close_slot_detail()
	_slot_detail_layer = QIF_CARD.make_detail_layer(detail_card)
	_slot_dialog.add_child(_slot_detail_layer)

func _close_slot_detail() -> void:
	if _slot_detail_layer != null:
		_slot_detail_layer.queue_free()
		_slot_detail_layer = null

func _open_xinfa_detail(xinfa: Dictionary) -> void:
	var xinfa_id: String = str(xinfa.get("id", ""))
	var full: Dictionary = QIF_GEN.get_xinfa_pack_full(xinfa_id)
	var detail_card: Button = QIF_CARD.make_xinfa_detail_card(
		xinfa, _xinfa_levels.get(xinfa_id, 1), str(full.get("up1", "")), str(full.get("up2", "")))
	detail_card.pressed.connect(_close_slot_detail)
	_open_slot_detail(detail_card)

func _open_spell_detail(spell: Array, spell_index: int) -> void:
	var detail_card: Button = QIF_CARD.make_spell_detail_card(
		"术法{0}".format([_cn_num(spell_index)]), int(spell[0]), str(spell[1]),
		str(spell[2]), str(spell[3]))
	detail_card.pressed.connect(_close_slot_detail)
	_open_slot_detail(detail_card)

func _cn_num(n: int) -> String:
	return "一二三四五六"[n - 1] if n >= 1 and n <= 6 else str(n)

#region 设置（顶栏入口，固定 520×430）：返回主菜单／主音量／全屏
func _on_settings_pressed() -> void:
	if _settings_dialog != null and is_instance_valid(_settings_dialog):
		_settings_dialog.popup_centered(Vector2i(520, 430))
		return
	_settings_dialog = QIF_DIALOG_FACTORY.create(self, "设置", Vector2(520, 430), "关闭")[1]
	_settings_dialog.confirmed.connect(func(): _settings_dialog.hide())

	var content: MarginContainer = MarginContainer.new()
	content.add_theme_constant_override("margin_left", 18)
	content.add_theme_constant_override("margin_right", 18)
	content.add_theme_constant_override("margin_top", 10)
	content.add_theme_constant_override("margin_bottom", 10)
	_settings_dialog.add_child(content)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(column)

	column.add_child(_sub_label("音频与显示"))
	var volume_row: HBoxContainer = HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	column.add_child(volume_row)
	var volume_label: Label = _make_label("主音量", 15, Color(0.29, 0.26, 0.23))
	volume_row.add_child(volume_label)
	var volume_slider: HSlider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = clampf(db_to_linear(AudioServer.get_bus_volume_db(0)), 0.0, 1.0)
	volume_slider.custom_minimum_size = Vector2(240, 24)
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_slider.value_changed.connect(func(value: float):
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001))))
	volume_row.add_child(volume_slider)

	var fullscreen_row: HBoxContainer = HBoxContainer.new()
	fullscreen_row.add_theme_constant_override("separation", 12)
	column.add_child(fullscreen_row)
	var fullscreen_label: Label = _make_label("全屏", 15, Color(0.29, 0.26, 0.23))
	fullscreen_row.add_child(fullscreen_label)
	var fullscreen_toggle: CheckButton = CheckButton.new()
	fullscreen_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_toggle.toggled.connect(func(on: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on
			else DisplayServer.WINDOW_MODE_WINDOWED))
	fullscreen_row.add_child(fullscreen_toggle)

	var bottom_spacer: Control = Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(bottom_spacer)
	column.add_child(_divider())
	var quit_button: Button = _make_flat_button("返回主菜单", COLOR_RED)
	quit_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit_button.pressed.connect(func():
		_settings_dialog.hide()
		Global.end_run(Global.RUN_ENDS.QUIT))
	column.add_child(quit_button)

	_settings_dialog.popup_centered(Vector2i(520, 430))
	_settings_dialog.size = Vector2i(520, 430)
	_settings_dialog.min_size = Vector2i(520, 430)
	QIF_DIALOG_FACTORY.restyle_ok.call_deferred(_settings_dialog)
#endregion

func _make_flat_button(text: String, bg: Color) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 36)
	var style: StyleBoxFlat = _flat_style(bg, 2, 10)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = bg.lightened(0.12)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", COLOR_CREAM)
	return button

func _on_equip_from_dialog(slot_index: int, xinfa: Dictionary) -> void:
	var xinfa_id: String = str(xinfa.get("id", ""))
	for i in _xinfa_slots.size():
		if _xinfa_slots[i] != null and str(_xinfa_slots[i].get("id", "")) == xinfa_id:
			_xinfa_slots[i] = null
	_xinfa_slots[slot_index] = xinfa
	_close_slot_detail()
	_slot_dialog.hide()
	_refresh_prep_data()

func _on_unequip_pressed(slot_index: int) -> void:
	_xinfa_slots[slot_index] = null
	_slot_dialog.hide()
	_refresh_prep_data()
#endregion

#region 卡组牌表（炉石式小卡横条＋悬停整卡预览）
func _refresh_deck_list() -> void:
	for child in _deck_list_container.get_children():
		child.queue_free()
	var deck: Array = Global.player_data.player_deck if Global.player_data != null else []
	_deck_count_chip.text = "{0} 张".format([len(deck)])
	if deck.is_empty():
		_deck_list_container.add_child(_sub_label("（空）"))
		return
	var first_card: CardData = null
	var counts: Dictionary = {}
	for card_data: CardData in deck:
		var card_name: String = card_data.get_card_name()
		counts[card_name] = {"count": counts.get(card_name, {"count": 0})["count"] + 1, "data": card_data}
	var names: Array = counts.keys()
	names.sort()
	for card_name: String in names:
		var entry: Dictionary = counts[card_name]
		_deck_list_container.add_child(_make_deck_row(card_name, entry["data"], int(entry["count"])))

func _make_deck_row(card_name: String, card_data: CardData, count: int) -> Control:
	var row_wrap: Control = Control.new()
	row_wrap.custom_minimum_size = Vector2(0, 44)

	var stack_tip: Panel = Panel.new()
	stack_tip.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack_tip.offset_left = 3.0
	stack_tip.offset_top = -3.0
	var tip_style: StyleBoxFlat = _flat_style(Color(0.788, 0.761, 0.678), 2, 8)
	stack_tip.add_theme_stylebox_override("panel", tip_style)
	row_wrap.add_child(stack_tip)

	var mini: Panel = Panel.new()
	mini.set_anchors_preset(Control.PRESET_FULL_RECT)
	var is_attack: bool = card_data.card_type == CardData.CARD_TYPES.ATTACK
	var mini_style: StyleBoxFlat = _flat_style(Color(0.788, 0.227, 0.227) if is_attack else Color(0.227, 0.651, 0.353), 2, 8)
	mini_style.border_color = COLOR_CREAM
	mini.add_theme_stylebox_override("panel", mini_style)
	row_wrap.add_child(mini)

	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_right = -10.0
	row.add_theme_constant_override("separation", 8)
	mini.add_child(row)

	var cost_pip: Panel = Panel.new()
	cost_pip.custom_minimum_size = Vector2(26, 26)
	cost_pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pip_style: StyleBoxFlat = _flat_style(Color(0.102, 0.129, 0.192), 2, 13)
	pip_style.border_color = COLOR_CREAM
	cost_pip.add_theme_stylebox_override("panel", pip_style)
	row.add_child(cost_pip)
	var cost_label: Label = _make_label(str(card_data.get_card_energy_cost(true, true)), 13, COLOR_CREAM)
	cost_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_pip.add_child(cost_label)

	var name_label: Label = _make_label(card_name, 14, COLOR_CREAM)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var count_badge: Label = _make_label("×{0}".format([count]), 13, Color(0.416, 0.329, 0.063))
	count_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count_badge.add_theme_stylebox_override("normal", _flat_style(COLOR_AMBER, 2, 11))
	count_badge.custom_minimum_size = Vector2(40, 26)
	count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(count_badge)

	# 悬停整卡预览（统一卡牌实例）
	mini.mouse_entered.connect(_show_deck_preview.bind(card_data, row_wrap))
	mini.mouse_exited.connect(_hide_deck_preview)
	return row_wrap

func _show_deck_preview(card_data: CardData, row_wrap: Control) -> void:
	_hide_deck_preview()
	var preview: Control = Scenes.CARD.instantiate()
	preview.position = Vector2(row_wrap.global_position.x - 190.0, row_wrap.global_position.y - 60.0)
	add_child(preview)	# 先入树：Card 的 @onready（pivot 等）挂树后才可用，入树前 init 会撞 null
	if preview is Card:
		(preview as Card).init(card_data, 0.0, false, false)
	_hover_preview = preview

func _hide_deck_preview() -> void:
	if _hover_preview != null:
		_hover_preview.queue_free()
		_hover_preview = null
#endregion

## 遴选确认后由 RunStartOptions 写入：全部获得＋自动占前两槽
func set_chosen_xinfa(xinfa_list: Array) -> void:
	_owned_xinfa = xinfa_list
	_xinfa_slots = []
	_xinfa_slots.resize(XINFA_SLOT_COUNT)
	for i in min(2, xinfa_list.size()):
		_xinfa_slots[i] = xinfa_list[i]
	if _xinfa_grid != null:
		_refresh_prep_data()

func _on_run_started() -> void:
	_group_index = 1
	_fight_index = 1
	_owned_xinfa = []
	_xinfa_slots = []
	_xinfa_slots.resize(XINFA_SLOT_COUNT)
	_xinfa_levels = {}
	_points_available = 0
	_hit_stats = {"力道": 5, "迅疾": 5, "精妙": 5}
	_qi_amounts = {"催破": 0, "护体": 0, "轻灵": 0}
	show_prep()

func _on_fight_button_pressed() -> void:
	_hide_deck_preview()
	visible = false
	Signals.combat_started.emit(FIGHT_EVENT_ID)

## 战后收口：推进组/场；胜场奖励（命中属性 2 点＋历练暂定 3——历练来源待定清单项）
func on_fight_finished() -> void:
	_points_available += POINTS_PER_VICTORY
	if Global.player_data != null:
		Global.player_data.player_money += LILIAN_PER_VICTORY
	_fight_index += 1
	if _fight_index > FIGHTS_PER_GROUP:
		_fight_index = 1
		_group_index += 1
		if _group_index > GROUPS_PER_RUN:
			_group_index = 1
			visible = false
			Signals.run_victory.emit()
			return
	show_prep()
