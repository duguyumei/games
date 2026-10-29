@tool
extends Control
## 武学区分组层·编辑器区域边框（2026-09-21 用户令「武学区域也预留…固定区域」）。
## 固定区域含预留空位——空位无控件＝编辑器视口点不到，本脚本编辑器态画边框＋淡填充
## 让整个预留区域可见可抓；运行时不画（画面干净）。挂各签层（功法/护身/心法×敌我）。

@export var zone_color := Color(0.92, 0.86, 0.7, 0.3):
	set(v):
		zone_color = v
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, zone_color, false, 1.0)
	draw_rect(r.grow(-2.0), Color(zone_color.r, zone_color.g, zone_color.b, zone_color.a * 0.4), true)
