## 敌情图标（2026-11-06）：攻击＝剑、护盾＝盾。纯 _draw 画的，零贴图。
extends Control

var kind := "attack"
var tint := Color(0.42, 0.14, 0.10)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w := size.x
	var h := size.y
	var c := Color(tint.r, tint.g, tint.b, 1.0)
	if kind == "attack":
		# 剑：刃（上尖）＋护手＋柄
		var blade := PackedVector2Array([
			Vector2(w * 0.50, h * 0.04),
			Vector2(w * 0.62, h * 0.24),
			Vector2(w * 0.62, h * 0.64),
			Vector2(w * 0.38, h * 0.64),
			Vector2(w * 0.38, h * 0.24),
		])
		draw_colored_polygon(blade, c)
		draw_rect(Rect2(w * 0.16, h * 0.64, w * 0.68, h * 0.10), c)
		draw_rect(Rect2(w * 0.43, h * 0.74, w * 0.14, h * 0.20), c)
	elif kind == "armor":
		# 盾：六边轮廓＋内线
		var sh := PackedVector2Array([
			Vector2(w * 0.50, h * 0.04),
			Vector2(w * 0.92, h * 0.22),
			Vector2(w * 0.84, h * 0.66),
			Vector2(w * 0.50, h * 0.96),
			Vector2(w * 0.16, h * 0.66),
			Vector2(w * 0.08, h * 0.22),
		])
		draw_colored_polygon(sh, c)
		var inner := PackedVector2Array([
			Vector2(w * 0.50, h * 0.16),
			Vector2(w * 0.78, h * 0.29),
			Vector2(w * 0.72, h * 0.60),
			Vector2(w * 0.50, h * 0.82),
			Vector2(w * 0.28, h * 0.60),
			Vector2(w * 0.22, h * 0.29),
		])
		draw_colored_polygon(inner, Color(0.93, 0.90, 0.83, 1.0))
