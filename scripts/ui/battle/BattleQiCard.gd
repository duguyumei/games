## 真气战斗 HUD 使用的独立真气牌组件；不修改旧 QiCard 场景。
extends Button
class_name BattleQiCard

## 当前组件代表的真气实例 UID。
var qi_instance_uid: String = ""

## 当前组件代表的真气数据。
var qi_data: QiData = null

## 当前战斗现场，用于读取临时重塑和异状。
var battle_state: BattleQiState = null

## 当前是否显示牌背。
var face_down: bool = false

## 当前是否允许玩家点击选择。
var selectable: bool = false

## 当前是否已经被玩家选中。
var selected: bool = false

## 真气牌被点击时发出实例 UID。
signal qi_clicked(qi_instance_uid: String)

var _background: Panel
var _selection_border: Panel
var _content: VBoxContainer
var _title_label: Label
var _suit_label: Label
var _value_label: Label
var _state_label: Label
var _order_label: Label
var _back_panel: Panel
var _back_label: Label
var _base_scale: Vector2 = Vector2.ONE

## 创建牌面、选中边框和牌背节点。
func _ready() -> void:
	custom_minimum_size = Vector2(112.0, 148.0)
	size = custom_minimum_size
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = custom_minimum_size / 2.0
	_background = Panel.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.add_theme_stylebox_override("panel", _make_style(
		Color("#f4ecd9"), Color("#c5a96a"), 1.0, 8.0))
	add_child(_background)

	_selection_border = Panel.new()
	_selection_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selection_border.add_theme_stylebox_override("panel", _make_style(
		Color(1.0, 0.82, 0.22, 0.2), Color("#ffd35a"), 3.0, 8.0))
	_selection_border.visible = false
	add_child(_selection_border)

	_content = VBoxContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.offset_left = 8.0
	_content.offset_top = 8.0
	_content.offset_right = -8.0
	_content.offset_bottom = -8.0
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 4)
	add_child(_content)
	_title_label = _make_label(14, Color("#3b3025"))
	_suit_label = _make_label(22, Color("#3b3025"))
	_value_label = _make_label(13, Color("#665644"))
	_state_label = _make_label(11, Color("#806d58"))
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_title_label)
	_content.add_child(_suit_label)
	_content.add_child(_value_label)
	_content.add_child(_state_label)

	_order_label = _make_label(20, Color("#fff1a8"))
	_order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_order_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_order_label.position = Vector2(8.0, 5.0)
	_order_label.size = Vector2(32.0, 28.0)
	_order_label.visible = false
	_order_label.z_index = 4
	add_child(_order_label)

	_back_panel = Panel.new()
	_back_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back_panel.add_theme_stylebox_override("panel", _make_style(
		Color("#1f2c46"), Color("#58749c"), 2.0, 8.0))
	_back_panel.visible = false
	add_child(_back_panel)
	_back_label = _make_label(18, Color("#d7e5ff"))
	_back_label.text = "真气"
	_back_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_back_panel.add_child(_back_label)

	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## 绑定一个真气实例并刷新牌面。
func setup(
		_data: QiData,
		_state: BattleQiState,
		_should_face_down: bool,
		_should_select: bool) -> void:
	qi_data = _data
	battle_state = _state
	qi_instance_uid = qi_data.object_uid if qi_data != null else ""
	selectable = _should_select
	_base_scale = Vector2.ONE
	set_face_down(_should_face_down, false)
	refresh_display()

## 刷新名称、花色、牌阶、真气值和状态摘要。
func refresh_display() -> void:
	if qi_data == null:
		return
	_title_label.text = qi_data.qi_name
	_suit_label.text = "%s %s" % [
		_get_attribute_text(), qi_data.get_effective_rank_name(battle_state)]
	_value_label.text = "真气值 %d" % qi_data.get_qi_value(battle_state)
	_state_label.text = _get_state_text()
	tooltip_text = "" if face_down else qi_data.qi_description

## 更新牌的选中状态并播放轻微抬升动画。
func set_selected(enabled: bool, selection_order: int = 0) -> void:
	selected = enabled
	_selection_border.visible = enabled and not face_down
	_order_label.visible = enabled and not face_down and selection_order > 0
	_order_label.text = str(selection_order) if selection_order > 0 else ""
	var target_scale: Vector2 = Vector2(1.06, 1.06) if enabled else _base_scale
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, 0.12)

## 设置牌背；从牌背转为牌面时播放横向翻牌动画。
func set_face_down(enabled: bool, animate: bool = true) -> void:
	if face_down == enabled and _back_panel != null:
		return
	face_down = enabled
	if _back_panel == null:
		return
	if not animate:
		_back_panel.visible = enabled
		_content.visible = not enabled
		_selection_border.visible = selected and not enabled
		_order_label.visible = selected and not enabled
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale:x", 0.04, 0.1)
	tween.tween_callback(func() -> void:
		_back_panel.visible = enabled
		_content.visible = not enabled
		_selection_border.visible = selected and not enabled
		_order_label.visible = selected and not enabled)
	tween.tween_property(self, "scale:x", 1.0, 0.1)
	if enabled:
		_order_label.visible = false

## 设置动态布局缩放基准，不限制牌的数量。
func set_layout_scale(layout_scale: float) -> void:
	_base_scale = Vector2.ONE * clamp(layout_scale, 0.55, 1.0)
	if not selected:
		scale = _base_scale

## 返回当前牌是否已经选中。
func is_selected() -> bool:
	return selected

func _on_pressed() -> void:
	if selectable and not face_down and qi_instance_uid != "":
		qi_clicked.emit(qi_instance_uid)

func _on_mouse_entered() -> void:
	if face_down:
		return
	var target_scale: Vector2 = _base_scale * (1.1 if not selected else 1.12)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.1)

func _on_mouse_exited() -> void:
	if face_down:
		return
	var target_scale: Vector2 = _base_scale * (1.06 if selected else 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.1)

func _get_attribute_text() -> String:
	var names: Array[String] = []
	var suit_names: Dictionary = {
		"wind": "黑桃",
		"forest": "梅花",
		"fire": "红桃",
		"mountain": "方块",
	}
	for attribute_id: String in qi_data.get_effective_attribute_ids(battle_state):
		names.append(str(suit_names.get(attribute_id, attribute_id)))
	return "/".join(names)

func _get_state_text() -> String:
	var states: Array[String] = []
	for reshape_state: QiReshapeState in qi_data.qi_reshape_states:
		states.append(reshape_state.reshape_slot)
	if battle_state != null:
		for reshape_state: QiReshapeState in battle_state.get_reshape_states(qi_instance_uid):
			states.append(reshape_state.reshape_slot)
	return "、".join(states) if not states.is_empty() else "无状态"

func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_style(
		background_color: Color,
		border_color: Color,
		border_width: float,
		corner_radius: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(int(border_width))
	style.set_corner_radius_all(int(corner_radius))
	return style
