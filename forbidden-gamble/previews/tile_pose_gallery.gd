extends Control

# 站立姿态四式（2026-09-18 用户令：先给站在桌上的牌——正面两个、背面两个）。
# 竖＝长边竖直；横＝长边水平（转 90° 站）。


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.11, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var felt := ColorRect.new()
	felt.color = Color(0.12, 0.33, 0.21)
	felt.set_anchors_preset(Control.PRESET_CENTER)
	felt.offset_left = -600
	felt.offset_right = 600
	felt.offset_top = -220
	felt.offset_bottom = 240
	add_child(felt)
	var title := Label.new()
	title.text = "站立姿态四式——站在桌上的牌（同一张：一万）"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.98, 0.9, 0.6))
	title.position = Vector2(60, 40)
	add_child(title)

	var man1: Texture2D = load("res://assets/mj25d/竖/1m.png")
	var back_s: Texture2D = load("res://assets/mj25d/背/站立背.png")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 90)
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BOTH
	row.offset_top = 60
	add_child(row)
	row.add_child(_cell("竖·正立", man1, false))
	row.add_child(_cell("横·正立", man1, true))
	row.add_child(_cell("竖·背立", back_s, false))
	row.add_child(_cell("横·背立", back_s, true))


func _cell(cap: String, tex: Texture2D, rotated: bool) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 14)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	var tile := RotTile.new()
	tile.tex = tex
	tile.rotated = rotated
	tile.w = 140
	tile.setup()
	cell.add_child(tile)
	var label := Label.new()
	label.text = cap
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(label)
	return cell


class RotTile extends Control:
	var tex: Texture2D
	var rotated := false
	var w := 140

	func setup() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stand_a := 1.43
		if tex != null:
			stand_a = tex.get_height() / float(tex.get_width())
		if rotated:
			custom_minimum_size = Vector2(roundi(w * stand_a), w)
		else:
			custom_minimum_size = Vector2(w, roundi(w * stand_a))

	func _draw() -> void:
		if tex == null:
			return
		var r := Rect2(Vector2.ZERO, size)
		if rotated:
			var draw_w := r.size.y   # 贴图宽画在竖直方向
			var draw_h := r.size.x   # 贴图高画在水平方向
			draw_set_transform(r.get_center(), PI / 2.0, Vector2.ONE)
			draw_texture_rect(tex, Rect2(r.get_center() - Vector2(draw_w, draw_h) / 2.0, Vector2(draw_w, draw_h)), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(tex, r, false)
