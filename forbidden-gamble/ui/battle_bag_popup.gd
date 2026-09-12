class_name BattleBagPopup
extends PanelContainer

# 随身物资弹窗：战斗中可「使用」battle 域道具（占用本回合主动行动，与发动功法互斥）。
# 锦囊整理已在探索侧落地（M3）；战斗中第一版仍只能使用背包道具、不能整理（含锦囊）。沙盒不带物资。
signal use_requested(item_id: String)

const BP := preload("res://ui/battle_palette.gd")

func setup(items: Array, in_expedition: bool) -> void:
	custom_minimum_size = Vector2(300, 0)
	add_theme_stylebox_override("panel", BP.popup_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	if not in_expedition:
		box.add_child(BP.plain_label("随身物资", 14, BP.COLOR_GOLD))
		box.add_child(BP.plain_label("演武场演练，不带物资。", 12, BP.COLOR_SECONDARY))
		return
	box.add_child(BP.plain_label("随身物资 · %d 件" % items.size(), 14, BP.COLOR_GOLD))
	if items.is_empty():
		box.add_child(BP.plain_label("（两手空空）", 12, BP.COLOR_SECONDARY))
	for item in items:
		box.add_child(_item_row(item))
	box.add_child(BP.plain_label("使用道具将占用本回合的主动行动；战斗中不能整理背包。败北将全部丢失。", 11, BP.COLOR_DIM))

func _item_row(item: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.color = BP.RARITY_COLORS.get(str(item.get("rarity", "common")), BP.COLOR_RARITY_FALLBACK)
	line.add_child(dot)
	var qty := int(item.get("qty", 1))
	var item_text := str(item.get("name", "？"))
	if qty > 1:
		item_text += " ×%d" % qty
	var item_label := BP.plain_label(item_text, 12, BP.COLOR_ITEM_NAME)
	item_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(item_label)
	var use: Dictionary = item.get("use", {})
	if not use.is_empty() and (use.get("scopes", []) as Array).has("battle"):
		var btn := Button.new()
		btn.text = "使用"
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(): use_requested.emit(str(item.get("id", ""))))
		line.add_child(btn)
	return line
