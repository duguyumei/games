extends Control

# 站立组件演示（2026-09-18 用户令「给个正常的玩家手牌的站着的2.5D」）：
# 玩家手牌一行——13 张站立正姿，含交互态三件示例。


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
	felt.offset_top = -180
	felt.offset_bottom = 190
	add_child(felt)
	var title := Label.new()
	title.text = "统一模型 01：站立·正立（玩家手牌）——13 张一行｜选中升起·候选金边·新摸金条"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.98, 0.9, 0.6))
	title.position = Vector2(60, 46)
	add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BOTH
	row.offset_top = 70
	add_child(row)

	var keys := ["万1", "万2", "万3", "万4", "万5", "万6", "万7", "万8", "万9", "筒3", "筒6", "筒9", "条5"]
	var raised: Control = null
	for i in range(keys.size()):
		var k := String(keys[i])
		var t := MJTile.new(k.substr(0, 1), int(k.substr(1)))
		var tile := MJBTileStand.new()
		tile.setup(t, 62)
		row.add_child(tile)
		if i == 4:
			raised = tile   # 选中升起示例（布局后落位——HBox 会回写子 y）
		if i == 6:
			tile.candidate = true    # 候选金边示例
		if i == 9:
			tile.fresh = true        # 新摸金条示例
	await get_tree().process_frame
	if raised != null:
		raised.position.y = -10
