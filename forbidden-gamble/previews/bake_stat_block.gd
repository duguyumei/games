@tool
extends Control
## 敌方名牌·数字块（N2 定案）——标签小字上置、数值大字下置、水平居中（攻/防各一枚真节点）。
## 规格自效果图 stat_block：标签 文楷12 褐灰、数值 文楷22 骨白。

const LABEL := Color8(150, 138, 112)
const BONE := Color8(217, 204, 174)

@export var stat_label := "攻":
	set(v):
		stat_label = v
		queue_redraw()
@export var stat_value := "12":
	set(v):
		stat_value = v
		queue_redraw()
@export var value_size := 22:
	set(v):
		value_size = max(v, 10)
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if _font == null:
		return
	# 基线带标签/数值墨迹间隙（09-27 用户「感觉叠在一起了」实锤：旧值 14/0.38 → 标签底 15.7 与
	# 数值顶 14.6 重叠 1px；效果图原案两区有 ~6px 隙。新值＝标签基线 12、数值区下移 0.55 系数）。
	draw_string(_font, Vector2(0.0, 12.0), stat_label,
	            HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, LABEL)
	draw_string(_font, Vector2(0.0, size.y * 0.5 + value_size * 0.55), stat_value,
	            HORIZONTAL_ALIGNMENT_CENTER, size.x, value_size, BONE)
