class_name ChTilePicker
extends RefCounted

# 牌灵绑定选牌（挑战层）：27 宫（万/筒/条×1–9）居中弹层——购入/三选一拿牌灵后弹，
# 选一枚未绑定牌种确认；同牌种限一枚（已绑置灰）。纯程序化构建，返回即销毁。


static func open(parent: Control, state: RunState, on_picked: Callable) -> void:
	var layer := PanelContainer.new()
	layer.name = "TilePickerLayer"
	layer.set_anchors_preset(Control.PRESET_CENTER)
	layer.custom_minimum_size = Vector2(420, 0)
	layer.z_index = 50
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.modulate = Color(0.12, 0.11, 0.1)
	layer.add_child(v)
	var title := Label.new()
	title.text = "择一枚牌种缚灵"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	for suit in MJTile.SUITS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var head := Label.new()
		head.text = suit
		head.custom_minimum_size = Vector2(28, 0)
		row.add_child(head)
		for value in range(MJTile.VALUE_MIN, MJTile.VALUE_MAX + 1):
			var key := "%s%d" % [suit, value]
			var btn := Button.new()
			btn.text = key
			btn.disabled = state.pailing.has(key)  # 同牌种限一枚
			btn.custom_minimum_size = Vector2(52, 34)
			btn.pressed.connect(func() -> void:
				layer.queue_free()
				on_picked.call(suit, value))
			row.add_child(btn)
		v.add_child(row)
	var cancel := Button.new()
	cancel.text = "暂不绑定（放弃本次）"
	cancel.pressed.connect(func() -> void:
		layer.queue_free()
		on_picked.call("", 0))
	v.add_child(cancel)
	parent.add_child(layer)
