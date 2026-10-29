@tool
extends Control
## 罡 chip（罡气余量·横排）——2026-09-24 用户令独立可拖。
## 护身杆下真节点，拖本体挪位、位置随场景存盘；文本检查器可改（正式件＝动态数值接线）。

const CHIP_BG := Color8(26, 24, 21)
const CHIP_BD := Color8(112, 100, 77)
const GOLD := Color8(235, 219, 179)

@export var chip_text := "罡 10":
	set(v):
		chip_text = v
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if _font == null or chip_text.is_empty():
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = CHIP_BG
	sb.border_color = CHIP_BD
	sb.set_corner_radius_all(4)
	draw_style_box(sb, Rect2(0, 0, 48, 24))
	var w := _font.get_string_size(chip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(_font, Vector2(24.0 - w * 0.5, 16.0), chip_text,
	            HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
