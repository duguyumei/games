## 虚线连线（追击连带普攻预览；2026-10-28 用户裁定虚线制＝「自动触发的攻击用虚线」）。
## 与主连线同族二次贝塞尔（尸姬 Card_TargetLine 曲线制），采样隔段 draw_line＝虚线。
## 少码件：仅此一处语义，点对每帧由 QiBattleScreen._process 落位后 queue_redraw。
extends Control

var p_from := Vector2.ZERO
var p_to := Vector2.ZERO
var lift := 100.0
var line_color := Color("e8b070")
var line_width := 3.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40

func _draw() -> void:
	if p_from == p_to:
		return
	var mid := (p_from + p_to) * 0.5 + Vector2(0.0, -lift)
	var u := 1.0
	var prev := p_from
	for i in range(1, 17):
		var t := float(i) / 16.0
		u = 1.0 - t
		var pt := Vector2(u * u * p_from.x + 2.0 * u * t * mid.x + t * t * p_to.x,
			u * u * p_from.y + 2.0 * u * t * mid.y + t * t * p_to.y)
		if i % 2 == 0:
			draw_line(prev, pt, line_color, line_width)
		prev = pt

func bez_mid() -> Vector2:
	## 线边数字落位用（与主连线控制点同式）
	return (p_from + p_to) * 0.5 + Vector2(0.0, -lift)
