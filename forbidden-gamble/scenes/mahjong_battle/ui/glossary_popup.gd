@tool
class_name MJBGlossaryPopup
extends PanelContainer

## 词条弹层（顶栏问号入口，2026-09-16 用户令）：底层机制的"怎么获取/干嘛用"住这里；
## 战斗相关的当前值/上限/公式仍在读数浮窗。两页结构：词条列表 ⇄ 词条详情。
## 式与面子词条带示例面子（真牌面渲染三组）。


var _list_box := VBoxContainer.new()
var _detail_box := VBoxContainer.new()
var _detail_title := Label.new()
var _detail_body := VBoxContainer.new()
var _examples := VBoxContainer.new()


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH  # 从中心点双向生长＝真居中（PRESET_CENTER 单用会右下偏）
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.13, 0.98)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.6, 0.55, 0.4)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(560, 0)
	add_child(_build_list())
	_detail_box.visible = false
	add_child(_build_detail())


func _build_list() -> Control:
	_list_box.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "词条"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.6))
	_list_box.add_child(title)
	var hint := Label.new()
	hint.text = "底层机制说明——点击词条查看"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	_list_box.add_child(hint)
	for term in _terms():
		var b := Button.new()
		b.text = term["title"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		var t: Dictionary = term
		b.pressed.connect(func(): _show_term(t))
		_list_box.add_child(b)
	var close := Button.new()
	close.text = "关 闭"
	close.pressed.connect(func(): visible = false)
	_list_box.add_child(close)
	return _list_box


func _build_detail() -> Control:
	_detail_box.add_theme_constant_override("separation", 8)
	_detail_title.add_theme_font_size_override("font_size", 17)
	_detail_title.add_theme_color_override("font_color", Color(0.95, 0.86, 0.6))
	_detail_box.add_child(_detail_title)
	_detail_body.add_theme_constant_override("separation", 4)
	_detail_box.add_child(_detail_body)
	_examples.add_theme_constant_override("separation", 8)
	_detail_box.add_child(_examples)
	var back := Button.new()
	back.text = "‹ 返回词条"
	back.pressed.connect(func():
		_detail_box.visible = false
		_list_box.visible = true)
	_detail_box.add_child(back)
	return _detail_box


func open() -> void:
	_list_box.visible = true
	_detail_box.visible = false
	visible = true


func _show_term(term: Dictionary) -> void:
	_list_box.visible = false
	_detail_box.visible = true
	_detail_title.text = String(term["title"])
	for child in _detail_body.get_children():
		child.queue_free()
	for child in _examples.get_children():
		child.queue_free()
	for line in term.get("lines", []):
		var l := Label.new()
		l.text = str(line)
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.86, 0.83, 0.76))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 520
		_detail_body.add_child(l)
	for ex in term.get("examples", []):
		_examples.add_child(_example_row(ex))


# 示例行：真牌面一组 ＋ 说明。
func _example_row(ex: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 2)
	for key in ex.get("keys", []):
		tiles.add_child(MJBTileFace.make_tile(_tile(String(key)), 30, 42))
	row.add_child(tiles)
	var label := Label.new()
	label.text = String(ex.get("note", ""))
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.86, 0.83, 0.76))
	row.add_child(label)
	return row


func _tile(key: String) -> MJTile:
	return MJTile.new(String(key).left(1), int(String(key).substr(1)))


# 词条内容（底层机制；数值类公式在读数浮窗，不重复）。
func _terms() -> Array[Dictionary]:
	return [
		{"title": "式与面子", "lines": [
			"面子＝三张（杠四张）成组：刻子（三张全同）＝重式；顺子（同门连三）＝轻式；杠（四张全同）＝本门万能式。",
			"式是功法的弹药：重击按功法配方消耗式（手牌暗式或副露明式皆可付）。",
			"三门各有轻重两式：万＝点/崩、筒＝刺/劈、条＝碾/撼。"],
		 "examples": [
			{"keys": ["万3", "万3", "万3"], "note": "刻子 → 重式·崩（万）"},
			{"keys": ["条2", "条3", "条4"], "note": "顺子 → 轻式·碾（条）"},
			{"keys": ["筒5", "筒5", "筒5", "筒5"], "note": "杠 → 万能式（可当任何筒门配方用）"}]},
		{"title": "气海与气河", "lines": [
			"气海＝双方共吸的牌墙（108 张，万/筒/条 × 1–9 × 4），干涸时气河整条洗回、供应无限。",
			"气河＝双方打出的牌汇成的共用排出口；按打出方分侧显示，同一次打出的牌靠在一起。",
			"我方打出的普攻/虚招在入河前可被对方截走（招架）。"]},
		{"title": "罡气", "lines": [
			"怎么获取：架势（摸牌）＋1、招架（吃/碰/杠）＋1、暗杠＋1；护体生效期间冻结不涨。",
			"干嘛用：支付护体武学（铁布衫 3 罡）——护体＝行动窗口内免费即时，不占打出；生效期间不能发功法。",
			"当前值与上限在读数浮窗。"]},
		{"title": "变招", "lines": [
			"行动窗口内免费操作，不占打出：先选牌再点变招按钮。",
			"换一张＝选 1 张手牌，弃掉换新（1 机会）；换组＝选手牌暗组或副露明组整组（3 机会），弃整组摸等量、每组附带 50% 伤害。",
			"机会由充能兑换（充能进度在变招读数浮窗）。"]},
		{"title": "副露", "lines": [
			"招架（吃/碰/杠）所得的明牌面子区＝第二丹田；顶缘金条＝招架截来的那张牌。",
			"每组副露给普攻 +50% 光环；可被功法当式消耗（消耗之式入气河明牌）。",
			"静息账本：手牌＋3×副露组数 收敛于 13。"]},
		{"title": "招架（截牌）", "lines": [
			"对方打出普攻/虚招时可截：碰/杠可截两者，吃只能截虚招。",
			"截＝拆招：对方的普攻伤害取消；截者接续打出（反击）。",
			"反击不可被截——绝对安全弃牌。"]},
		{"title": "攻击四式", "lines": [
			"虚招：打出时无超额（恰好等于也不行），0 伤试探，可被吃/碰/杠。",
			"普攻：有超额，100%＋50%×副露光环，可被碰/杠（截＝拆招取消）。",
			"重击：功法打出（耗式），不可截；反击：招架后打出，不可截。"]},
		{"title": "前摇（运行中）", "lines": [
			"重击按功法前摇（缺省＝式数）延迟生效：按对方经过拍数推进，到期在你摸牌拍的自动效果阶段结算。",
			"招架拍/破绽拍不推进也不结算；在途至多一门，期间不能发动防御。",
			"式在发动那一刻打出入气河——天然预告；运行中的武学＝按钮/名目高亮，拍数在其下方小字。"]},
		{"title": "破绽", "lines": [
			"破绽拍＝只自然摸牌的一拍：无附属行为、无打出、不解算在途、不截牌、不充能。",
			"手牌清零（自动效果/附属行为结算完）会立刻触发破绽。"]},
		{"title": "内力三力", "lines": [
			"劲＝出力（攻 +2/点）；骨＝承伤（防 +1/点，不管血量）；气＝流转（每拍变招充能 +1/点，每逢 3 点缺牌补充 +1）。",
			"基础数值（基础攻 10、基础防、基础血 100）由人物携带；内力是增幅层。"]},
		{"title": "伤害与承伤", "lines": [
			"段伤 ＝ 倍率% ×（基础攻＋2×劲）× 承伤比 ×（1−护体免伤%)。",
			"承伤比 ＝ 5/(5＋防)——每点骨力恒定 +20% 有效耐久，永远到不了 100%。",
			"内部两位小数，显示向上取整；当前承伤百分比在防御读数浮窗。"]},
	]
