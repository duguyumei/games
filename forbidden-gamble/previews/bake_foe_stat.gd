@tool
extends Control
## 敌方竖签·数据行（标签小字＋数值大字，无底）——攻/防/罡/变 各一枚真节点独立可拖。
## 规格＝C 案效果图：标签 文楷12 褐灰、数值 文楷16 墨、底对齐。

const LABEL := Color8(120, 110, 90)
const INK := Color8(33, 28, 23)

@export var stat_label := "攻":
	set(v):
		stat_label = v
		queue_redraw()
@export var stat_value := "12":
	set(v):
		stat_value = v
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if _font == null:
		return
	var baseline := size.y * 0.5 + 5.5
	draw_string(_font, Vector2(8.0, baseline), stat_label,
	            HORIZONTAL_ALIGNMENT_LEFT, -1, 12, LABEL)
	draw_string(_font, Vector2(22.0, baseline), stat_value,
	            HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
