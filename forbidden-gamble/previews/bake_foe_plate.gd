@tool
extends Control
## 敌方名牌·条体（N2 定案 2026-09-27）——CHIP_BG 深底＋CHIP_BD 描边 2＋圆角 8＋行1/行2 分隔细线。
## 只画体；行内件（头像/名号/攻防块/心法印/三力 chip）与条下状态行＝同组「敌方名牌组」真节点独立可拖。

const CHIP_BG := Color8(26, 24, 21)
const CHIP_BD := Color8(112, 100, 77)
const RULE := Color8(70, 64, 52)

@export var divider_y := 62.0:   # 分隔线（节点内 y；≤0 不画）
	set(v):
		divider_y = v
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CHIP_BG
	sb.border_color = CHIP_BD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	draw_style_box(sb, Rect2(0, 0, size.x, size.y))
	if divider_y > 0.0:
		draw_line(Vector2(12.0, divider_y), Vector2(size.x - 10.0, divider_y), RULE, 1.0)
