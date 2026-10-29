@tool
extends Control
## 敌方名牌·条下状态行件（N2 定案）——瞬态状态签：破绽＝朱、护体＝钢青（色带语汇同效果图）。
## 「有则显·无则隐」＝节点 visible 开关（编辑器预览与正式件同语义）；并排生长方向由摆位承担。

const ZHU_FILL := Color8(146, 46, 38)
const ZHU_BD := Color8(184, 64, 51)
const STEEL_FILL := Color8(70, 88, 104)
const STEEL_BD := Color8(96, 116, 132)
const BONE := Color8(217, 204, 174)

@export_enum("破绽", "护体") var kind := 0:
	set(v):
		kind = v
		queue_redraw()
@export var seal_text := "":   # 空＝按 kind 取默认名
	set(v):
		seal_text = v
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if _font == null:
		return
	var label := seal_text if not seal_text.is_empty() else ("破绽" if kind == 0 else "护体")
	var sb := StyleBoxFlat.new()
	sb.bg_color = ZHU_FILL if kind == 0 else STEEL_FILL
	sb.border_color = ZHU_BD if kind == 0 else STEEL_BD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	draw_style_box(sb, Rect2(0, 0, size.x, size.y))
	draw_string(_font, Vector2(0.0, size.y * 0.5 + 4.4), label,
	            HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, BONE)
