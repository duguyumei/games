@tool
class_name QiOrb
extends Panel

## 真气牌（麻将样式，真气语法 v2.2）：竖版骨白牌体＋墨色数值（上）＋属性色花色字（下）。
## 足迹保持 56×56 不变（手牌层/图鉴零布局改动）。选中（凝招）态金边；紫框＝状态特效（毒等）。

@export var force_text: String = "4":
	set(value):
		force_text = value
		_apply()
## 花色字（风/火/山）：字色＝属性色。
@export var suit_text: String = "风":
	set(value):
		suit_text = value
		_apply()
@export var orb_color: Color = Color(0.45, 0.72, 0.68):
	set(value):
		orb_color = value
		_apply()
@export var selected: bool = false:
	set(value):
		selected = value
		_apply()
## 状态紫框（毒等特效位），默认隐藏。
@export var status_ring: bool = false:
	set(value):
		status_ring = value
		_apply()

## 点击牌面（手牌层选择用）。
signal clicked

const SELECT_COLOR := Color(0.95, 0.75, 0.25)
const TILE_FACE := Color(0.95, 0.92, 0.84)
const TILE_EDGE := Color(0.62, 0.56, 0.44)
const INK := Color(0.23, 0.2, 0.16)

# 属性色（24 号规格：风青/火朱/山黛/林墨绿）。
static func color_for_attribute(attribute: String) -> Color:
	match attribute:
		"风":
			return Color(0.45, 0.72, 0.68)
		"火":
			return Color(0.75, 0.35, 0.25)
		"山":
			return Color(0.45, 0.42, 0.5)
		"林":
			return Color(0.33, 0.48, 0.34)
	return Color(0.6, 0.58, 0.52)

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit()

func _apply() -> void:
	if not is_inside_tree():
		return
	var tile := get_node_or_null("Tile") as Panel
	if tile != null:
		var sb: StyleBoxFlat = (tile.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
		sb.bg_color = TILE_FACE
		sb.border_color = SELECT_COLOR if selected else TILE_EDGE
		var width := 3 if selected else 2
		sb.border_width_left = width
		sb.border_width_top = width
		sb.border_width_right = width
		sb.border_width_bottom = width
		tile.add_theme_stylebox_override("panel", sb)
	var value_label := get_node_or_null("Tile/ValueLabel") as Label
	if value_label != null:
		value_label.text = force_text
		value_label.add_theme_color_override("font_color", INK)
	var suit_label := get_node_or_null("Tile/SuitLabel") as Label
	if suit_label != null:
		suit_label.text = suit_text
		suit_label.add_theme_color_override("font_color", orb_color)
	var ring: Control = get_node_or_null("StatusRing")
	if ring != null:
		ring.visible = status_ring
