@tool
class_name TechniqueCard
extends Panel

## 功法卡：标准卡牌比例 5:7。名字区／卡图区／效果区三段。
## 边框＝功法等级色（1 素白/2 绿/3 蓝/4 紫/5 金，D-044）。
## 四态：NORMAL 等级色边框；SATISFIED 当前选择满足＝金边；PENDING 待确认＝金边加粗；
## UNUSABLE 整卡压灰＋朱红原因（缺牌型/兵器/内力）。
## 编辑器内拖动宽度时高度自动跟随锁定比例；文字大小按卡宽等比缩放（基准：卡宽 150）。

signal clicked

enum CardState { NORMAL, SATISFIED, PENDING, UNUSABLE }

# 等级 → 边框色（素白/绿/蓝/紫/金）——色值收敛于 battle_palette，此处保留别名。
const Palette := preload("res://ui/battle_palette.gd")
const LEVEL_COLORS: Array[Color] = Palette.LEVEL_COLORS
const SATISFIED_COLOR: Color = Palette.SATISFIED_COLOR
const REASON_COLOR: Color = Palette.REASON_COLOR

var _locking := false
var _level: int = 1
var _state: int = CardState.NORMAL

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _locking:
		_locking = true
		var target_h := roundf(size.x * 7.0 / 5.0)
		if absf(size.y - target_h) > 0.5:
			size.y = target_h
		_apply_font_scale()
		_locking = false

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_font_scale()
	_apply_state()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit()

## 填充内容：功法名、效果摘要、等级（1~5）。
func set_card(technique_name: String, effect_text: String, level_value: int) -> void:
	_level = clampi(level_value, 1, 5)
	var name_label: Label = get_node_or_null("NameArea/NameLabel")
	if name_label != null:
		name_label.text = technique_name
	var effect_label: Label = get_node_or_null("EffectArea")
	if effect_label != null:
		effect_label.text = effect_text
	var art: ColorRect = get_node_or_null("ArtArea")
	if art != null:
		# 卡图占位：等级色深调，正式卡图随美术资产替换
		art.color = LEVEL_COLORS[_level - 1].darkened(0.25)
	_apply_state()

## 四态切换（CardState）；UNUSABLE 时 reason 为朱红原因文本。
func set_state(new_state: int, reason: String = "") -> void:
	_state = new_state
	var reason_label: Label = get_node_or_null("ReasonLabel")
	if reason_label != null:
		reason_label.text = reason
	_apply_state()

func _apply_state() -> void:
	if not is_inside_tree():
		return
	var sb: StyleBoxFlat = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate(true)
	var border_color: Color = LEVEL_COLORS[_level - 1]
	var border_width := 3
	match _state:
		CardState.SATISFIED:
			border_color = SATISFIED_COLOR
		CardState.PENDING:
			border_color = SATISFIED_COLOR
			border_width = 5
	sb.border_color = border_color
	for side in ["border_width_left", "border_width_top", "border_width_right", "border_width_bottom"]:
		sb.set(side, border_width)
	add_theme_stylebox_override("panel", sb)
	modulate = Color(0.55, 0.55, 0.55) if _state == CardState.UNUSABLE else Color.WHITE
	var reason_label: Label = get_node_or_null("ReasonLabel")
	if reason_label != null:
		reason_label.visible = _state == CardState.UNUSABLE and not reason_label.text.is_empty()

func _apply_font_scale() -> void:
	var factor := size.x / 150.0
	var name_label: Label = get_node_or_null("NameArea/NameLabel")
	if name_label != null:
		name_label.add_theme_font_size_override("font_size", maxi(8, roundi(14.0 * factor)))
	var effect_label: Label = get_node_or_null("EffectArea")
	if effect_label != null:
		effect_label.add_theme_font_size_override("font_size", maxi(8, roundi(12.0 * factor)))
	var reason_label: Label = get_node_or_null("ReasonLabel")
	if reason_label != null:
		reason_label.add_theme_font_size_override("font_size", maxi(8, roundi(11.0 * factor)))
