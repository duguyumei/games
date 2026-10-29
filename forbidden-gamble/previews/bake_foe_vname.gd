@tool
extends Control
## 敌方名号（09-26 用户令改横排——「你名字为什么要竖着」）——马善政墨字；
## horizontal=false 保留竖排模式备查，横排＝居中单行。

const INK := Color8(33, 28, 23)
const GOLD := Color8(235, 219, 179)

@export var name_text := "玄冥子":
	set(v):
		name_text = v
		queue_redraw()
@export var char_size := 13:
	set(v):
		char_size = max(v, 8)
		queue_redraw()
@export var horizontal := false:
	set(v):
		horizontal = v
		queue_redraw()
@export var gold_text := false:   # N2 名牌名号＝金字（深底上金字）；纸底仍用墨字
	set(v):
		gold_text = v
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/MaShanZheng-Regular.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if _font == null or name_text.is_empty():
		return
	if horizontal:
		draw_string(_font, Vector2(0, size.y * 0.5 + char_size * 0.36), name_text,
		            HORIZONTAL_ALIGNMENT_CENTER, size.x, char_size, GOLD if gold_text else INK)
		return
	var y := 0.0
	for ch in name_text:
		draw_string(_font, Vector2(size.x * 0.5, y + char_size * 0.8), ch,
		            HORIZONTAL_ALIGNMENT_CENTER, size.x, char_size, INK)
		y += char_size + 1.0
