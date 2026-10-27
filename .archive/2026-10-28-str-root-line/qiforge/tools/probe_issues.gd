## 修复验收探针（无头）：乱码字体三路兜底／详情卡居中／确认键样式／弹窗尺寸／选中位移／金圈贴边
extends SceneTree

var _frames: int = 0

func _initialize() -> void:
	change_scene_to_file("res://scenes/Root.tscn")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 39:
		var rso_pre = root.find_child("RunStartOptions", true, false)
		if rso_pre != null:
			print("diag: ok_min_弹窗前=", rso_pre._dialog.get_ok_button().custom_minimum_size)
		return false
	if _frames == 40:
		var run_screen = root.find_child("RunScreen", true, false)
		if run_screen != null:
			run_screen.visible = true
		var rso0 = root.find_child("RunStartOptions", true, false)
		if rso0 != null:
			rso0._on_run_started()
		return false
	if _frames == 41:
		var rso_post = root.find_child("RunStartOptions", true, false)
		if rso_post != null:
			print("diag: ok_min_弹窗后=", rso_post._dialog.get_ok_button().custom_minimum_size)
		return false
	if _frames == 130:
		_probe()
		quit()
		return true
	return false

func _probe() -> void:
	var rso = root.find_child("RunStartOptions", true, false)
	if rso == null:
		print("diag: RunStartOptions NOT FOUND")
		return
	var fonts = load("res://qiforge/QiFontBank.gd")
	var gen = load("res://qiforge/QiForgeDataGenerator.gd")

	# ---- A) 字体三路兜底 ----
	var noto: FontFile = fonts.noto()
	var display: FontVariation = fonts.display()
	print("diag: noto_loaded=", noto != null, " noto_has_·=", noto.has_char("·".unicode_at(0)),
		" (expect true/true)  display_base=ZCOOL:", display.base_font.get_font_name().find("ZCOOL") != -1,
		" fallbacks=", display.fallbacks.size())
	var probe_label: Label = Label.new()
	rso.add_child(probe_label)
	print("diag: 默认字体=Noto:", probe_label.get_theme_default_font() == noto,
		" name=", probe_label.get_theme_default_font().get_font_name() if probe_label.get_theme_default_font() != null else "null")
	probe_label.queue_free()

	var texts: Dictionary = {
		"弹窗标题": "备战 · 心法遴选", "确认键": "确认入组（0/2）",
		"提示行_未满": "点卡面选中两门 · 迷你卡切面 · 「详情」放大细看",
		"提示行_已满": "已选满两门，点「确认入组」生效", "按钮_详情": "详情",
	}
	for pack_id in ["run_start_option_qif_B", "run_start_option_qif_C", "run_start_option_qif_E",
			"run_start_option_qif_F", "run_start_option_qif_G"]:
		var full: Dictionary = gen.get_xinfa_pack_full(pack_id)
		texts["名_" + str(full.get("name", ""))] = str(full.get("name", ""))
		for field in ["desc", "up1", "up2"]:
			texts["文_" + field] = str(full.get(field, ""))
		for spell in full.get("spells", []):
			for seg in spell:
				texts["术法文"] = str(seg)
	var missing: int = 0
	for key in texts.keys():
		for ch in str(texts[key]):
			if not noto.has_char(ch.unicode_at(0)):
				missing += 1
				print("diag: Noto也缺 [", key, "] → ", ch, "(U+%04X)" % ch.unicode_at(0))
	print("diag: Noto覆盖缺字数=", missing, " (expect 0)")

	# ---- B) 弹窗尺寸＋确认键样式＋选中位移＋金圈 ----
	var ok: Button = rso._dialog.get_ok_button()
	print("diag: 弹窗size=", Vector2(rso._dialog.size), " (expect 1080x600)",
		" 确认键size=", ok.size, " ok_min=", ok.custom_minimum_size,
		" parent=", ok.get_parent().name)
	ok.custom_minimum_size = Vector2(300, 60)
	ok.reset_size()
	print("diag: ok_force=", ok.size, " (300x60=布局肯跟)")
	var host = rso._cards_host
	var before: Array = []
	for col in host.get_children():
		before.append(col.global_position)
	_visible_face(host.get_child(0)).pressed.emit()
	_visible_face(host.get_child(2)).pressed.emit()
	var shifted: int = 0
	for i in host.get_child_count():
		if host.get_child(i).global_position != before[i]:
			shifted += 1
	print("diag: 位移列数=", shifted, " (expect 0)")
	var ring: Panel = host.get_child(0).get_meta("ring")
	var card0: Control = _visible_face(host.get_child(0))
	print("diag: 金圈贴边 ring=", ring.global_position, ring.size,
		" 卡=", card0.global_position, card0.size, " 间隙=", card0.global_position - ring.global_position,
		" (expect 约 (4,4)=线宽)")

	# ---- C) 详情卡居中 ----
	(host.get_child(0).get_meta("detail_button") as Button).pressed.emit()
	var layer: Control = rso._detail_layer
	var card: Control = layer.get_child(1)
	var card_center: Vector2 = card.global_position + card.size * 0.5
	var layer_center: Vector2 = layer.global_position + layer.size * 0.5
	print("diag: 卡center=", card_center, " 层center=", layer_center,
		" 偏差=", card_center - layer_center, " (expect (0,0))")
	print("diag: 卡anchors=", card.anchor_left, card.anchor_top, card.anchor_right, card.anchor_bottom,
		" offsets=", card.offset_left, card.offset_top, card.offset_right, card.offset_bottom,
		" 层rect=", layer.global_position, layer.size)

func _visible_face(column: Control) -> Button:
	for child in column.get_child(0).get_children():
		if child is Button and child.visible:
			return child
	return null
