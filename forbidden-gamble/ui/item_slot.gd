class_name ItemSlot
extends Panel

# 物品槽位（纸墨亮色系）：稀有度描边 + 居中名称 + 数量角标。
# 背包格与据点仓库格共用；点击行为由调用方挂 gui_input（背包格可点选）。

const BoardPalette := preload("res://ui/board_palette.gd")

# 有物槽位：稀有度描边（选中＝金边加粗）
static func make(item: Dictionary, slot_size: Vector2, font_px: int, selected := false) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = slot_size
	var style := StyleBoxFlat.new()
	style.bg_color = BoardPalette.COLOR_CARD
	var rarity := str(item.get("rarity", "common"))
	style.border_color = BoardPalette.RARITY_COLORS.get(rarity, BoardPalette.COLOR_INK)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	if selected:
		style.border_color = BoardPalette.COLOR_GOLD
		style.set_border_width_all(3)
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 3
	slot.add_theme_stylebox_override("panel", style)
	var label := BoardPalette.plain_label(str(item.get("name", "")), font_px, BoardPalette.COLOR_INK)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(label)
	var qty := int(item.get("qty", 1))
	if qty > 1:
		var qty_label := BoardPalette.plain_label("×%d" % qty, font_px, BoardPalette.COLOR_INK)
		qty_label.position = Vector2(slot_size.x - 22, slot_size.y - 16)
		slot.add_child(qty_label)
	return slot

# 空槽位：透明底 + 淡墨虚框
static func make_empty(slot_size: Vector2) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = slot_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(BoardPalette.COLOR_INK, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("panel", style)
	return slot
