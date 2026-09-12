@tool
class_name QiOrb
extends Panel

## 真气丹珠：圆形。颜色=属性，字标=品级（下/中/上），外圈=状态特效（毒等）。
## 选中（凝招）态金环。

@export var force_text: String = "中":
	set(value):
		force_text = value
		_apply()
@export var orb_color: Color = Color(0.45, 0.72, 0.68):
	set(value):
		orb_color = value
		_apply()
@export var selected: bool = false:
	set(value):
		selected = value
		_apply()
## 状态外圈（毒等特效位），默认隐藏。
@export var status_ring: bool = false:
	set(value):
		status_ring = value
		_apply()

## 点击丹珠（手牌层选择用）。
signal clicked

const SELECT_COLOR := Color(0.95, 0.75, 0.25)

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
	var sb: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	sb.bg_color = orb_color
	sb.border_color = SELECT_COLOR if selected else orb_color.darkened(0.35)
	sb.border_width_left = 3 if selected else 2
	sb.border_width_top = 3 if selected else 2
	sb.border_width_right = 3 if selected else 2
	sb.border_width_bottom = 3 if selected else 2
	add_theme_stylebox_override("panel", sb)
	var force: Label = get_node_or_null("ForceLabel")
	if force != null:
		force.text = force_text
	var ring: Control = get_node_or_null("StatusRing")
	if ring != null:
		ring.visible = status_ring
