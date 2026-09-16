class_name MJBMeldStrip
extends VBoxContainer

## 副露区（单侧·定宽）：贴本侧手牌排——敌方在手牌带下行居右、我方与牌河同行居右。
## 一行最多三组（区宽按三组设计）；多出的组换行：我方向上排（新行在上）、敌方向下排（新行在下）。
## 组＝式名（**组内居中**；我方在牌上、敌方在牌下——2026-09-17 用户令）＋牌行；
## 招架获得的牌顶缘金条（与摸到同款）；组可选＝变招·换组目标（on_group_clicked）。区宽与牌河区同宽。


const ZONE_W := MJBRiverPanel.ZONE_W  # 区宽单源（2026-09-17 审计项）：与牌河区同宽
const PER_ROW := 3


var on_group_clicked: Callable  # (meld_index: int) -> void

var _side := "player"


func _init(side := "player") -> void:
	_side = side
	custom_minimum_size = Vector2(ZONE_W, 0)
	add_theme_constant_override("separation", 4)


func update_melds(melds: Array, selected_meld := -1) -> void:
	for child in get_children():
		child.queue_free()
	if melds.is_empty():
		return
	# 1) 分行：一行 PER_ROW 组
	var rows: Array = []
	for mi in range(melds.size()):
		if rows.is_empty() or (rows.back() as Array).size() >= PER_ROW:
			rows.append([])
		(rows.back() as Array).append(mi)
	# 2) 我方新行在上（往上排）、敌方新行在下
	if _side == "player":
		rows.reverse()
	for row in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.alignment = BoxContainer.ALIGNMENT_END  # 从右缘向左排（两侧向中间——2026-09-17 用户令）
		for mi in row:
			line.add_child(_make_group(melds[mi], int(mi), selected_meld))
		add_child(line)


func _make_group(meld: Dictionary, mi: int, selected_meld: int) -> Control:
	var group := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.17, 0.15, 0.5)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	if selected_meld == mi:
		sb.set_border_width_all(2)
		sb.border_color = Color(0.98, 0.85, 0.3)
	else:
		sb.set_border_width_all(1)
		sb.border_color = Color(0.35, 0.32, 0.27)
	group.add_theme_stylebox_override("panel", sb)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	group.add_child(inner)
	var symbol := Label.new()
	var meld_type := String(meld["type"])
	symbol.text = _symbol_text(meld, meld_type)
	symbol.add_theme_font_size_override("font_size", 12)
	symbol.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # 式名在组内水平居中
	var tiles_row := HBoxContainer.new()
	tiles_row.add_theme_constant_override("separation", 2)
	# 式名位置分侧（2026-09-17 用户令）：我方在牌上面、敌方在牌下面
	if _side == "player":
		inner.add_child(symbol)
		inner.add_child(tiles_row)
	else:
		inner.add_child(tiles_row)
		inner.add_child(symbol)
	var claimed: Array = meld.get("claimed", [])
	for t in meld["tiles"]:
		var widget := MJBTileFace.make_tile(t as MJTile, 28, 40)
		if claimed.has((t as MJTile).get_instance_id()):
			# 招架获得的牌：顶缘金条（与本拍摸到同款样式，2026-09-17 用户令——非边框亮）
			MJBTileFace.fresh_mark(widget)
		tiles_row.add_child(widget)
	_meld_tip(group, meld_type)
	if on_group_clicked.is_valid():
		group.mouse_filter = Control.MOUSE_FILTER_STOP
		group.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				on_group_clicked.call(mi))
	return group


# 组首式名：碰/吃＝式字（崩/点/…），杠＝万能（本门万能式）。
func _symbol_text(meld: Dictionary, meld_type: String) -> String:
	if meld_type == "KAN":
		return "万能"
	return String(meld.get("symbol", ""))


func _meld_tip(group: Control, meld_type: String) -> void:
	match meld_type:
		"KAN":
			MJBTipFloat.bind(group, "杠·万能式", ["四张全同（截杠＝拦一张＋手里三张；暗杠＝手里四张自晒）", "本门万能式：任何功法配方可当本门式用", "顶缘金条＝招架截来的那张", "加普攻光环 50%；可被功法当式消耗（入气河）"])
		"CHI":
			MJBTipFloat.bind(group, "吃·轻式（仅虚招可截）", ["顺子成式；顶缘金条＝招架截来的那张", "加普攻光环 50%；可被功法当式消耗（入气河）"])
		_:
			MJBTipFloat.bind(group, "碰·重式", ["三张全同，截对方普攻所得（伤害取消）；顶缘金条＝截来的那张", "加普攻光环 50%；可被功法当式消耗（入气河）"])
