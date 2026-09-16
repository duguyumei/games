class_name MJBTileFace
extends RefCounted

## 牌面构件（占位美术：代码绘制，零商业资产提取）。
## 正面（属性色＋数值）、背牌（敌方手牌明码张数）、高亮描边——全部静态构造，供各区块共用。


const SUIT_COLORS := {"万": Color(0.2, 0.47, 0.34), "筒": Color(0.66, 0.25, 0.22), "条": Color(0.5, 0.42, 0.2)}


static func make_tile(tile: MJTile, w: int, h: int, dimmed := false) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SUIT_COLORS.get(tile.suit, Color.GRAY)
	if dimmed:
		sb.bg_color = sb.bg_color.darkened(0.25)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.1, 0.09, 0.08)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	var value_label := Label.new()
	value_label.text = str(tile.value)
	value_label.add_theme_font_size_override("font_size", maxi(11, int(h * 0.5)))
	value_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	value_label.set_anchors_preset(Control.PRESET_CENTER)
	value_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	value_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(value_label)
	var suit_label := Label.new()
	suit_label.text = tile.suit
	suit_label.add_theme_font_size_override("font_size", maxi(9, int(h * 0.2)))
	suit_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.8))
	suit_label.position = Vector2(3, 1)
	panel.add_child(suit_label)
	return panel


## 背牌（敌方手牌：明码张数，不露内容）。
static func make_back(w: int, h: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.22, 0.2)
	sb.set_corner_radius_all(5)
	sb.border_color = Color(0.38, 0.35, 0.3)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	return panel


static func glow(widget: Control, color: Color) -> Control:
	var sb := widget.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		var glow_sb := sb.duplicate() as StyleBoxFlat
		glow_sb.set_border_width_all(3)
		glow_sb.border_color = color
		widget.add_theme_stylebox_override("panel", glow_sb)
	return widget


## 刚摸到的牌（2026-09-17 用户令）：顶缘金条＝新牌标记（选中他牌即消失）。
static func fresh_mark(widget: Control) -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.98, 0.82, 0.3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.add_child(bar)
	bar.position = Vector2(2, 1)
	bar.size = Vector2(widget.custom_minimum_size.x - 4, 3)
