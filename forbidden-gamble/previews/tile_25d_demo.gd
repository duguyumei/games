extends Control

# 2.5D 牌体样板（2026-09-18 用户令「先做个麻将给我看看」）：站立正面/背面＋躺牌，
# 深底＋呢色垫布上陈列，窗口跑截图过目。样板件，不入套件。


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.11, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# 垫布（呢色横带）
	var felt := ColorRect.new()
	felt.color = Color(0.12, 0.33, 0.21)
	felt.set_anchors_preset(Control.PRESET_CENTER)
	felt.offset_left = -560
	felt.offset_right = 560
	felt.offset_top = -190
	felt.offset_bottom = 210
	add_child(felt)
	var title := Label.new()
	title.text = "2.5D 牌体样板 v1 —— 站立正面／站立背面／躺牌（贴面朝上）"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.98, 0.9, 0.6))
	title.position = Vector2(60, 40)
	add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 48)
	row.position = Vector2(180, 250)
	add_child(row)
	var specs := [
		{"label": "站立·正面 万1", "tile": MJTile.new("万", 1), "mode": "stand"},
		{"label": "站立·正面 筒9", "tile": MJTile.new("筒", 9), "mode": "stand"},
		{"label": "站立·背面", "tile": null, "mode": "back"},
		{"label": "躺牌·条5", "tile": MJTile.new("条", 5), "mode": "flat"},
		{"label": "躺牌·背面", "tile": null, "mode": "flat_back"},
	]
	for spec in specs:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 10)
		var mode := String(spec["mode"])
		var tex: Texture2D
		if mode == "back":
			tex = MJBTileFace.back_stand_tex()
		elif mode == "flat_back":
			tex = MJBTileFace.back_flat_tex()
		elif mode == "flat":
			tex = MJBTileFace.flat_tex(spec["tile"] as MJTile)
		else:
			tex = MJBTileFace.stand_tex(spec["tile"] as MJTile)
		var tile_view := MJBTileFace.make_25d(tex, 130, 178, mode)
		cell.add_child(tile_view)
		var cap := Label.new()
		cap.text = String(spec["label"])
		cap.add_theme_font_size_override("font_size", 15)
		cap.add_theme_color_override("font_color", Color(0.9, 0.87, 0.8))
		cell.add_child(cap)
		row.add_child(cell)
