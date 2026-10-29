@tool
extends Control
## 朱印（题签底压角小章·书案 seal_text 语汇复用）——朱底骨白字，名号下收束身份。

const ZHU := Color8(184, 64, 51)
const BONE := Color8(217, 204, 174)

@export var stamp_char := "玄":
	set(v):
		stamp_char = v
		queue_redraw()
@export var char_size := 10:
	set(v):
		char_size = max(v, 8)
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/MaShanZheng-Regular.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if _font == null or stamp_char.is_empty():
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = ZHU
	sb.set_corner_radius_all(2)
	draw_style_box(sb, Rect2(0, 0, size.x, size.y))
	draw_string(_font, Vector2(0, size.y * 0.5 + char_size * 0.36), stamp_char,
	            HORIZONTAL_ALIGNMENT_CENTER, size.x, char_size, BONE)
