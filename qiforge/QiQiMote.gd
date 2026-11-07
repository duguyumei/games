## 轨道气粒：淡色填充＋深蓝细边（2026-11-06 用户令：不要实心深蓝，太闷）
extends Control

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 1.2
	draw_circle(c, r, Color(0.80, 0.90, 1.0, 0.92))          # 淡填充
	draw_circle(c, r * 0.42, Color(0.96, 0.99, 1.0, 0.95))   # 高光芯
	draw_arc(c, r - 0.8, 0.0, TAU, 28, Color(0.15, 0.27, 0.47), 2.2, true)   # 深蓝边
