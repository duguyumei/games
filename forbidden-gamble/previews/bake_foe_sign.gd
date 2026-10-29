@tool
extends Control
## 敌方竖签·签体（C 案 09-26 定形＋截图分析轮装帧）——纸牌底只画体：
## 挂绳短绠（牌顶上方 8px 竖线＝「挂的牌」非「贴的卡」）＋装裱双线框（外 2px＋内 1px）＋柔投影
## （与气海嵌块同款立体感）＋双细横线（divider_y≤0 不画）。
## 框内＝身份区（边章列｜头像 44｜名号 18＋朱印落款）＋数据区（攻防列｜三力列，两列 54 高底边齐线）。

const PAPER := Color8(222, 212, 188)
const CORD := Color8(120, 104, 78)
const RULE := Color8(150, 132, 100)
const RULE_SOFT := Color(150.0 / 255.0, 132.0 / 255.0, 100.0 / 255.0, 0.55)

@export var divider_y := 116.0:
	set(v):
		divider_y = v
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = RULE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 4)
	draw_style_box(sb, Rect2(0, 0, size.x, size.y))
	# 装裱内细线
	draw_rect(Rect2(4, 4, size.x - 8, size.y - 8), RULE_SOFT, false, 1.0)
	# 挂绳短绠＋绳孔
	draw_line(Vector2(size.x * 0.5, -8.0), Vector2(size.x * 0.5, 1.0), CORD, 2.0)
	draw_arc(Vector2(size.x * 0.5, 10.0), 5.5, 0.0, TAU, 16, CORD, 2.0)
	# 双细横线（≤0 不画）
	if divider_y > 0.0:
		draw_line(Vector2(8.0, divider_y), Vector2(size.x - 8.0, divider_y), RULE, 1.0)
		draw_line(Vector2(8.0, divider_y + 2.5), Vector2(size.x - 8.0, divider_y + 2.5), RULE, 1.0)
