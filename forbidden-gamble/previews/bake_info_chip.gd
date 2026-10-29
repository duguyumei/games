@tool
extends Control
## 数值 chip（V5 敌情报簇／我方账本通用件）——真节点，拖本体挪位、拖边改宽、文本检查器可改。
## 规格自 V5 效果图 chip()：CHIP_BG 底＋CHIP_BD 描边＋圆角 4＋文楷 13 骨白字（丹田类用金字）。
## 宽度约定＝3D HUD 数值槽同源：两对类 98／三对类 134（节点宽度即 chip 宽，显示原值不补零）。

const CHIP_BG := Color8(26, 24, 21)
const CHIP_BD := Color8(112, 100, 77)
const BONE := Color8(217, 204, 174)
const GOLD := Color8(235, 219, 179)

@export var chip_text := "罡 9　变 9":
	set(v):
		chip_text = v
		queue_redraw()
@export var gold_text := false:
	set(v):
		gold_text = v
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 不设 custom_minimum_size：尺寸全由 tscn 节点矩形承担（min 会顶穿小号用法，09-26 教训；
	# N2 名牌三力 chip 24 高被 28 min 顶高实锤）。

func _draw() -> void:
	if _font == null or chip_text.is_empty():
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = CHIP_BG
	sb.border_color = CHIP_BD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	draw_style_box(sb, Rect2(0, 0, size.x, size.y))
	draw_string(_font, Vector2(0, size.y * 0.5 + 4.7), chip_text,
	            HORIZONTAL_ALIGNMENT_CENTER, size.x, 13,
	            GOLD if gold_text else BONE)
