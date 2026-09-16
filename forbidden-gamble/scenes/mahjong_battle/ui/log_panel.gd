class_name MJBLogPanel
extends RichTextLabel

## 战报尾（最近拍）——驱动循环每次刷新；战斗现场另有整局落盘（user://mj_battle_log.txt）。


func _init() -> void:
	custom_minimum_size = Vector2(330, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	bbcode_enabled = false
	add_theme_font_size_override("normal_font_size", 12)
	add_theme_color_override("default_color", Color(0.75, 0.72, 0.66))


func update_log(lines: Array) -> void:
	text = "\n".join(lines)
