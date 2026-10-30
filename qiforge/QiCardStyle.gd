## qi-forge 统一卡牌系统（卡面 v3.1，2026-10-28 用户裁定：左上＝能量消耗）：
## **唯一基准 300×422 ＋ 场合缩放系数**（替代旧三档实物尺寸制）——全项目只有一套按 300×422
## 标定的卡面布局，五档系数：单位 0.60（180×253）／手牌 0.72（216×304）／备战 0.78（234×329）
## ／详情 0.90（270×380）／迷你 0.11（33×46）。系数在建卡时按真实像素等比落位（非节点 scale，
## 避容器量尺寸陷阱）；除五档系数外不得另立宽高、不得缩放、不得散建卡面。
## 分区（v3.2，2026-10-28 用户裁定：心法/术法之分整体退场——器灵就是器灵、牌一律功法）：
## **左上＝功法卡能量点（器灵卡留空）** → 右上留空 → 立绘区（暂空压暗）→ 名字带
## （**器灵卡＝菱头横带、功法卡＝长方形匾额**）→ 效果区。
## 区域保护（用户裁定）：效果/详情文字逐级自适应缩号（_wire_fit），到底仍溢出行尾省略，
## 且效果面板 clip_contents 硬裁——长文案绝不画出卡面；完整信息由详情卡承载。
## 升级预览（v3.0 起）：make_spell_card 可带 diff 行（增「＋」绿／删「－」红／改「改」琥珀，
## 其余「·」墨色），名字/费用变化时名字带文字与能量点描边转琥珀。
## 弹窗走 QiDialog；字体＝QiFontBank（≥18px 展示字走 display()）。
extends RefCounted

const QIF_FONTS = preload("res://qiforge/QiFontBank.gd")

## 唯一基准画布（一套布局只按此标定）
const BASE_SIZE: Vector2 = Vector2(300, 422)
## 场合系数表（宽度锚定旧制横宽：180/216/234/270/33，高度随基准比例）
const SCALES: Dictionary = {"field": 0.60, "hand": 0.72, "prep": 0.78, "detail": 0.90, "mini": 0.11}
## 效果文自适应字号下限
const FIT_FLOOR: int = 10

static func scale_of(ctx: String) -> float:
	return float(SCALES.get(ctx, SCALES["field"]))

static func size_of(ctx: String) -> Vector2:
	return Vector2(round(BASE_SIZE.x * scale_of(ctx)), round(BASE_SIZE.y * scale_of(ctx)))

## 心法线配色（攻击/防御/身法三线——仅旧线兼容别名在用，随 Root 线终裁再删）
const IDENTITY_COLORS: Dictionary = {
	"身法": Color(0.227, 0.651, 0.353),
	"护体": Color(0.788, 0.635, 0.227),
	"催破": Color(0.788, 0.227, 0.227),
}
## 功法卡配色（蓝）
const SPELL_COLOR: Color = Color(0.227, 0.435, 0.788)
## 器灵卡体色（绿；原心法「身法」色系沿用——2026-10-28 心法/术法退场后器灵卡唯一定色）
const SPIRIT_COLOR: Color = Color(0.227, 0.651, 0.353)

## 包 → 旧线心法体色（现役器灵卡用上方 SPIRIT_COLOR；随 Root 线终裁再删）
const PACK_IDENTITY: Dictionary = {
	"run_start_option_qif_B": "身法",
	"run_start_option_qif_C": "身法",
	"run_start_option_qif_E": "身法",
	"run_start_option_qif_F": "身法",
	"run_start_option_qif_G": "身法",
}

const COLOR_CREAM: Color = Color(0.949, 0.922, 0.847)
const COLOR_AMBER: Color = Color(0.976, 0.859, 0.451)
const COLOR_AMBER_DARK: Color = Color(0.788, 0.635, 0.227)
const COLOR_AMBER_TEXT: Color = Color(0.416, 0.329, 0.063)
const COLOR_INK: Color = Color(0.16, 0.14, 0.11)
const COLOR_NAVY: Color = Color(0.102, 0.129, 0.192)
const COLOR_INK_TEXT: Color = Color(0.2, 0.188, 0.165)
## diff 行配色（增/删/改）
const COLOR_DIFF_ADD: Color = Color(0.227, 0.651, 0.353)
const COLOR_DIFF_DEL: Color = Color(0.788, 0.227, 0.227)
const COLOR_DIFF_MOD: Color = Color(0.70, 0.50, 0.10)

static func identity_of(pack_id: String) -> String:
	return PACK_IDENTITY.get(pack_id, "身法")

## 器灵立绘索引（名→res 路径；未录者保持压暗占位；资源未导入/缺失时 portrait_of 返 null 退占位）
const PORTRAITS: Dictionary = {
	"幽冥剑": "res://qiforge/assets/portraits/youming.png",
}
static var _portrait_cache: Dictionary = {}

static func portrait_of(name_text: String) -> Texture2D:
	if not PORTRAITS.has(name_text):
		return null
	if not _portrait_cache.has(name_text):
		var tex: Texture2D = load(String(PORTRAITS[name_text])) as Texture2D
		if tex == null:
			return null
		_portrait_cache[name_text] = tex
	return _portrait_cache[name_text]

## 菱头名字带（StyleBoxFlat 只有圆角做不了斜角，自绘六边形）
class DiamondBand extends Control:
	var band_color: Color = Color(0.0, 0.0, 0.0, 0.32)
	var tip: float = 13.0
	func _draw() -> void:
		var half: float = size.y * 0.5
		var points: PackedVector2Array = PackedVector2Array([
			Vector2(tip, 0.0), Vector2(size.x - tip, 0.0), Vector2(size.x, half),
			Vector2(size.x - tip, size.y), Vector2(tip, size.y), Vector2(0.0, half),
		])
		draw_colored_polygon(points, band_color)

#region 统一入口（一套基准布局 × 场合系数）
## 器灵卡（菱头名字带；基础效果面；左上/右上留空——器灵等级轴 v0.6 已退役，无 Lv 徽）
static func make_spirit_card(spirit: Dictionary, ctx: String = "field") -> Button:
	var k: float = scale_of(ctx)
	var card: Button = _new_card(SPIRIT_COLOR, k)
	_add_art_zone(card, k, false, portrait_of(str(spirit.get("name", ""))))
	_add_band(card, k, str(spirit.get("name", "")), true)
	_add_effect_panel(card, k, str(spirit.get("desc", "")), 0, "")
	return card

## 纯立绘卡（整卡＝立绘位，COVERED 裁切；备战舱展示位/战斗我方位共用件；
## 无立绘器灵退「立绘位」占位——2026-10-29 用户裁定战斗我方卡整卡改立绘）
static func make_portrait_panel(name_text: String, ctx: String = "prep") -> Panel:
	var k: float = scale_of(ctx)
	var p: Panel = Panel.new()
	p.custom_minimum_size = size_of(ctx)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.141, 0.094)
	sb.border_color = Color("6b5426")
	sb.set_border_width_all(maxi(2, roundi(3.0 * k)))
	sb.set_corner_radius_all(maxi(4, roundi(13.0 * k)))
	p.add_theme_stylebox_override("panel", sb)
	var pic: Texture2D = portrait_of(name_text)
	if pic != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = pic
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		var inset: float = maxi(3.0, roundi(4.0 * k))
		tr.offset_left = inset
		tr.offset_top = inset
		tr.offset_right = -inset
		tr.offset_bottom = -inset
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(tr)
		return p
	_center_text(p, "立绘位", _fs(23, k), Color(0.36, 0.31, 0.24))
	return p

## 旧线兼容别名（心法制遗名；复原中的 Root 线在用——随 Root 线终裁一并删）
static func make_xinfa_card(xinfa: Dictionary, level: int, ctx: String = "field") -> Button:
	var identity: String = identity_of(str(xinfa.get("id", "")))
	var k: float = scale_of(ctx)
	var card: Button = _new_card(IDENTITY_COLORS.get(identity, Color(0.42, 0.42, 0.48)), k)
	_add_lv_pill(card, k, level)
	_add_art_zone(card, k)
	_add_band(card, k, str(xinfa.get("name", "")), true)
	_add_effect_panel(card, k, str(xinfa.get("desc", "")), 0, "")
	return card

## 功法卡（左上能量点＋长方形名字带；preview 携 diff 行与变化标记）
## preview: {"lines": [{t, cls}], "name_changed": bool, "cost_changed": bool}
static func make_spell_card(spell_name: String, cost: int, desc: String,
		power: int = 0, spec: String = "", ctx: String = "field",
		preview: Dictionary = {}) -> Button:
	var k: float = scale_of(ctx)
	var card: Button = _new_card(SPELL_COLOR, k)
	_add_cost_pip(card, k, cost, bool(preview.get("cost_changed", false)))
	_add_art_zone(card, k)
	_add_band(card, k, spell_name, false, bool(preview.get("name_changed", false)))
	_add_effect_panel(card, k, desc, power, spec, preview.get("lines", []))
	return card

## 战斗手牌卡（并入统一布局，手牌档系数；保留旧入口名）
static func make_hand_spell_card(spell_name: String, cost: int, desc: String) -> Button:
	return make_spell_card(spell_name, cost, desc, 0, "", "hand")

## 升级预览卡：升级后面貌＋diff 标记（效果区逐行「＋/－/改/·」；名字/费用变化转琥珀）
static func make_spell_preview_card(up_spell: Dictionary, diff: Dictionary,
		ctx: String = "field") -> Button:
	var preview: Dictionary = {
		"lines": diff.get("lines", []),
		"name_changed": diff.get("name_changed", false),
		"cost_changed": diff.get("cost_changed", false),
	}
	return make_spell_card(str(up_spell.get("name", "")), int(up_spell.get("cost", 0)),
		str(up_spell.get("desc", "")), int(up_spell.get("power", 0)),
		str(up_spell.get("spec", "")), ctx, preview)
#endregion

#region 详情卡（基准布局 ×0.9；立绘压成短条给全文让位）
## 器灵详情卡（v3.2 现役；无 Lv 徽）
static func make_spirit_detail_card(spirit: Dictionary, up1: String = "",
		up2: String = "", ctx: String = "detail") -> Button:
	var k: float = scale_of(ctx)
	var card: Button = _new_card(SPIRIT_COLOR, k)
	_add_art_zone(card, k, true, portrait_of(str(spirit.get("name", ""))))
	_add_band(card, k, str(spirit.get("name", "")), true)
	_add_detail_panel(card, k, str(spirit.get("desc", "")), 0, "", up1, up2)
	return card

## 旧线兼容别名（随 Root 线终裁一并删）
static func make_xinfa_detail_card(xinfa: Dictionary, level: int, up1: String = "",
		up2: String = "", ctx: String = "detail") -> Button:
	var identity: String = identity_of(str(xinfa.get("id", "")))
	var k: float = scale_of(ctx)
	var card: Button = _new_card(IDENTITY_COLORS.get(identity, Color(0.42, 0.42, 0.48)), k)
	_add_lv_pill(card, k, level)
	_add_art_zone(card, k, true)
	_add_band(card, k, str(xinfa.get("name", "")), true)
	_add_detail_panel(card, k, str(xinfa.get("desc", "")), 0, "", up1, up2)
	return card

## 功法详情卡
static func make_spell_detail_card(spell_name: String, cost: int, desc: String,
		up1: String = "", up2: String = "", power: int = 0, spec: String = "",
		ctx: String = "detail") -> Button:
	var k: float = scale_of(ctx)
	var card: Button = _new_card(SPELL_COLOR, k)
	_add_cost_pip(card, k, cost)
	_add_art_zone(card, k, true)
	_add_band(card, k, spell_name, false)
	_add_detail_panel(card, k, desc, power, spec, up1, up2)
	return card
#endregion

#region 遴选轮播件：竖版迷你卡（等比缩小，无字纯色）＋选入描边圈
static func make_face_mini(mini_color: Color, tip: String) -> Button:
	var mini: Button = Button.new()
	mini.custom_minimum_size = size_of("mini")
	mini.tooltip_text = tip
	var dim: Color = mini_color.darkened(0.55)
	var normal: StyleBoxFlat = _mini_style(dim, 0)
	var hover: StyleBoxFlat = _mini_style(mini_color.darkened(0.2), 0)
	var active: StyleBoxFlat = _mini_style(mini_color, 3)
	mini.add_theme_stylebox_override("normal", normal)
	mini.add_theme_stylebox_override("hover", hover)
	mini.add_theme_stylebox_override("pressed", hover)
	mini.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	mini.set_meta("style_active", active)
	mini.set_meta("style_normal", normal)
	return mini

static func set_face_mini_active(mini: Button, active: bool) -> void:
	mini.add_theme_stylebox_override("normal",
		mini.get_meta("style_active" if active else "style_normal") as StyleBoxFlat)

## 选入描边圈：垫在卡面之下（卡位外扩 6px），选中时显示
static func make_pick_ring() -> Panel:
	var ring: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(4)
	style.border_color = COLOR_AMBER
	style.set_corner_radius_all(14)
	ring.add_theme_stylebox_override("panel", style)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	return ring
#endregion

#region 详情层公共件（遴选窗/装备窗共用）
## 「详情」按钮全场统一制服：藏青底奶油字，永远可按（选中态由各窗自行表达，按钮只管放大）
static func make_detail_button() -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(180, 36)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", COLOR_CREAM)
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = COLOR_NAVY
	normal.border_color = COLOR_CREAM
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.text = "详情"
	return button

## 详情层：压满弹窗＋0.45 黑罩＋内容居中（锚点 0.5＋显式偏移——弹窗内部容器重整也压不跑，
## 且不走 PRESET_CENTER 的 MINSIZE 语义，那个会按瞬时最小尺寸算出 ±4 崩坏偏移）。
## card_size 缺省（零向量）＝详情档尺寸；组合行传自身 combined min size。
## 点遮罩即关；点卡关闭由调用方连接；返回层节点由调用方持有、queue_free 关闭。
static func make_detail_layer(detail_card: Control, card_size: Vector2 = Vector2.ZERO) -> Control:
	var real_size: Vector2 = card_size if card_size.x > 0.0 else size_of("detail")
	var layer: Control = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.45)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			layer.queue_free())
	layer.add_child(scrim)
	detail_card.size = real_size
	detail_card.anchor_left = 0.5
	detail_card.anchor_right = 0.5
	detail_card.anchor_top = 0.5
	detail_card.anchor_bottom = 0.5
	var half: Vector2 = real_size * 0.5
	detail_card.offset_left = -half.x
	detail_card.offset_right = half.x
	detail_card.offset_top = -half.y
	detail_card.offset_bottom = half.y
	layer.add_child(detail_card)
	return layer

#region 空装备位（与实卡同尺寸的灰格，可点）
static func make_empty_slot_button(ctx: String = "field") -> Button:
	var k: float = scale_of(ctx)
	var slot: Button = Button.new()
	slot.custom_minimum_size = size_of(ctx)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.80, 0.77, 0.70)
	style.set_corner_radius_all(maxi(4, roundi(17.0 * k)))
	style.set_border_width_all(maxi(2, roundi(3.0 * k)))
	style.border_color = Color(0.68, 0.64, 0.56)
	slot.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.border_color = COLOR_AMBER
	slot.add_theme_stylebox_override("hover", hover)
	slot.add_theme_stylebox_override("pressed", hover)
	var empty_label: Label = _text(slot, "空", _fs(23, k), Color(0.62, 0.59, 0.53))
	empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return slot
#endregion

#region 基准卡装配（坐标按 300×422 标定，k＝场合系数）
static func _new_card(body_color: Color, k: float) -> Button:
	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(round(BASE_SIZE.x * k), round(BASE_SIZE.y * k))
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var normal: StyleBoxFlat = _card_style(body_color, maxi(4, roundi(17.0 * k)), maxi(2, roundi(5.0 * k)))
	var hover: StyleBoxFlat = _card_style(body_color, normal.corner_radius_top_left, normal.border_width_left)
	hover.border_color = COLOR_AMBER
	var pressed: StyleBoxFlat = hover.duplicate()
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", pressed)
	return card

## 左上能量点（v3.1 用户裁定：费用徽居左上；升级预览费用变化时描边转琥珀）
static func _add_cost_pip(card: Control, k: float, cost: int, changed: bool = false) -> void:
	var pip: Panel = Panel.new()
	pip.name = "CostPip"
	# 半搭卡左上角（2026-10-28 用户裁定对齐攻次宝珠同族位；原全内置 13/7 偏内）
	_place_abs(pip, -14.0 * k, -14.0 * k, 60.0 * k, 60.0 * k)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_NAVY
	style.set_corner_radius_all(roundi(30.0 * k))
	style.set_border_width_all(maxi(2, roundi(5.0 * k)))
	style.border_color = COLOR_AMBER if changed else COLOR_CREAM
	pip.add_theme_stylebox_override("panel", style)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_text(pip, str(cost), _fs(27, k), COLOR_CREAM)
	card.add_child(pip)

## 右上 Lv 琥珀角标（仅旧线心法别名在用；现役器灵卡无等级概念）
static func _add_lv_pill(card: Control, k: float, level: int) -> void:
	var pill: Panel = Panel.new()
	pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pill.offset_left = -107.0 * k
	pill.offset_top = 13.0 * k
	pill.offset_right = -12.0 * k
	pill.offset_bottom = 66.0 * k
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_AMBER
	style.set_corner_radius_all(maxi(4, roundi(22.0 * k)))
	style.set_border_width_all(maxi(1, roundi(3.0 * k)))
	style.border_color = COLOR_AMBER_DARK
	pill.add_theme_stylebox_override("panel", style)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_text(pill, "Lv{0}".format([level]), _fs(22, k), COLOR_AMBER_TEXT)
	card.add_child(pill)

## 立绘区（无立绘＝压暗占位；strip=true 详情短条；portrait 非空时铺图 COVERED 裁切）
static func _add_art_zone(card: Control, k: float, strip: bool = false,
		portrait: Texture2D = null) -> void:
	var art: Panel = Panel.new()
	if strip:
		_place(art, 15.0 * k, 73.0 * k, -15.0 * k, -292.0 * k)
	else:
		_place(art, 15.0 * k, 73.0 * k, -15.0 * k, -235.0 * k)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.15)
	style.set_corner_radius_all(maxi(3, roundi(11.0 * k)))
	art.add_theme_stylebox_override("panel", style)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if portrait != null:
		var pic: TextureRect = TextureRect.new()
		pic.texture = portrait
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(pic)
	card.add_child(art)

## 名字带：is_xinfa=true 菱头横带；false 长方形匾额；升级换名时文字转琥珀
static func _add_band(card: Control, k: float, name_text: String, is_xinfa: bool,
		name_changed: bool = false) -> void:
	var band: Control
	if is_xinfa:
		var diamond: DiamondBand = DiamondBand.new()
		diamond.tip = 13.0 * k
		band = diamond
	else:
		var rect_band: Panel = Panel.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.24)
		style.set_corner_radius_all(maxi(2, roundi(7.0 * k)))
		rect_band.add_theme_stylebox_override("panel", style)
		band = rect_band
	_place(band, 33.0 * k, 196.0 * k, -33.0 * k, -182.0 * k)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_text(band, name_text, _fs(25, k), COLOR_AMBER if name_changed else COLOR_CREAM)
	_wire_fit(band.get_child(0) as Label, _fs(25, k), true)
	card.add_child(band)

## 效果区：基础效果（威力徽在前）＋可选特殊效果块；diff 行非空时逐行标记渲染
static func _add_effect_panel(card: Control, k: float, desc: String, power: int,
		spec: String, diff_lines: Array = []) -> void:
	var panel: Panel = Panel.new()
	_place(panel, 15.0 * k, 249.0 * k, -15.0 * k, -17.0 * k)
	_eff_style(panel, k)
	card.add_child(panel)

	var box: VBoxContainer = _panel_box(panel, k)

	if power > 0:
		var power_row: HBoxContainer = _row_container(HBoxContainer.new())
		power_row.add_child(_make_chip(k, "威力 {0}".format([power]), 83.0,
			COLOR_AMBER, COLOR_AMBER_DARK, COLOR_AMBER_TEXT))
		box.add_child(power_row)

	if not diff_lines.is_empty():
		for line: Dictionary in diff_lines:
			var cls: String = str(line.get("cls", "same"))
			var mark: String = {"add": "＋ ", "del": "－ ", "mod": "改 "}.get(cls, "· ")
			var color: Color = {"add": COLOR_DIFF_ADD, "del": COLOR_DIFF_DEL,
				"mod": COLOR_DIFF_MOD}.get(cls, COLOR_INK_TEXT)
			var line_label: Label = _text(box, mark + str(line.get("t", "")),
				_fs(_effect_font_base("field"), k), color)
			line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_wire_fit(line_label, _fs(_effect_font_base("field"), k))
	else:
		var desc_label: Label = _text(box, desc, _fs(20, k), COLOR_INK_TEXT)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wire_fit(desc_label, _fs(20, k))

	if spec != "":
		var line: ColorRect = ColorRect.new()
		line.color = Color(0.847, 0.816, 0.751)
		line.custom_minimum_size = Vector2(0, maxi(1.0, roundi(2.5 * k)))
		box.add_child(line)
		var spec_row: HBoxContainer = _row_container(HBoxContainer.new())
		spec_row.add_child(_make_chip(k, "特殊", 60.0,
			Color(0.867, 0.902, 0.953), SPELL_COLOR, Color(0.153, 0.29, 0.5)))
		var spec_label: Label = _text(spec_row, spec, _fs(20, k), COLOR_INK_TEXT)
		spec_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spec_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spec_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wire_fit(spec_label, _fs(20, k))
		box.add_child(spec_row)
#endregion

#region 详情面板（基准布局；升一/升二全文行）
static func _add_detail_panel(card: Control, k: float, desc: String, power: int,
		spec: String, up1: String, up2: String) -> void:
	var panel: Panel = Panel.new()
	_place(panel, 15.0 * k, 249.0 * k, -15.0 * k, -17.0 * k)
	_eff_style(panel, k)
	card.add_child(panel)

	var box: VBoxContainer = _panel_box(panel, k, 8.0)
	var text_base: int = _fs(_effect_font_base("detail"), k)

	if power > 0:
		var power_row: HBoxContainer = _row_container(HBoxContainer.new())
		power_row.add_child(_make_chip(k, "威力 {0}".format([power]), 83.0,
			COLOR_AMBER, COLOR_AMBER_DARK, COLOR_AMBER_TEXT))
		box.add_child(power_row)

	var desc_label: Label = _text(box, desc, text_base, COLOR_INK_TEXT)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wire_fit(desc_label, text_base)

	if spec != "":
		var spec_line: ColorRect = ColorRect.new()
		spec_line.color = Color(0.847, 0.816, 0.751)
		spec_line.custom_minimum_size = Vector2(0, maxi(1.0, roundi(2.5 * k)))
		box.add_child(spec_line)
		var spec_row: HBoxContainer = _row_container(HBoxContainer.new())
		spec_row.add_child(_make_chip(k, "特殊", 60.0,
			Color(0.867, 0.902, 0.953), SPELL_COLOR, Color(0.153, 0.29, 0.5)))
		var spec_label: Label = _text(spec_row, spec, text_base, COLOR_INK_TEXT)
		spec_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spec_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spec_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wire_fit(spec_label, text_base)
		box.add_child(spec_row)

	if up1 != "" or up2 != "":
		var up_line: ColorRect = ColorRect.new()
		up_line.color = Color(0.847, 0.816, 0.751)
		up_line.custom_minimum_size = Vector2(0, maxi(1.0, roundi(2.5 * k)))
		box.add_child(up_line)
		if up1 != "":
			var row1: HBoxContainer = _row_container(HBoxContainer.new())
			row1.add_child(_make_chip(k, "升一", 60.0, COLOR_AMBER, COLOR_AMBER_DARK, COLOR_AMBER_TEXT))
			_up_text(row1, up1, text_base)
			box.add_child(row1)
		if up2 != "":
			var row2: HBoxContainer = _row_container(HBoxContainer.new())
			row2.add_child(_make_chip(k, "升二", 60.0,
				Color(0.867, 0.902, 0.953), SPELL_COLOR, Color(0.153, 0.29, 0.5)))
			_up_text(row2, up2, text_base)
			box.add_child(row2)

static func _up_text(row: HBoxContainer, text: String, size: int) -> void:
	var label: Label = _text(row, text, size, COLOR_INK_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wire_fit(label, size)
#endregion

#region 内部工具
## 详情档正文用较小基号（×0.9 后 ≈13px，避免误入 ≥18 展示字通道）
static func _effect_font_base(ctx: String) -> int:
	return 14 if ctx == "detail" else 20

## 字号按场合系数缩放（下限 9——迷你档无字，保险闸）
static func _fs(base: int, k: float) -> int:
	return maxi(9, roundi(float(base) * k))

static func _panel_box(panel: Panel, k: float, pad: float = 10.0) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12.0 * k
	box.offset_top = pad * k
	box.offset_right = -12.0 * k
	box.offset_bottom = -pad * k
	box.add_theme_constant_override("separation", maxi(3, roundi(7.0 * k)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	return box

## 内缩矩形：四边锚点（0,0,1,1）后给偏移，负值＝从右/下边内缩
static func _place(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom

## 绝对矩形：锚点全 0，偏移即距父左上的像素
static func _place_abs(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom

static func _card_style(body_color: Color, radius: int, border_px: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = body_color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border_px)
	style.border_color = COLOR_CREAM
	return style

static func _mini_style(mini_color: Color, border_px: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = mini_color
	style.set_corner_radius_all(4)
	if border_px > 0:
		style.set_border_width_all(border_px)
		style.border_color = COLOR_CREAM
	return style

static func _eff_style(panel: Panel, k: float) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.961, 0.941, 0.902)
	style.set_corner_radius_all(maxi(3, roundi(13.0 * k)))
	style.set_border_width_all(maxi(1, roundi(3.0 * k)))
	style.border_color = Color(0.788, 0.761, 0.678)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true	# 区域保护最后一道闸：缩号＋省略号都兜不住时硬裁

static func _row_container(row: HBoxContainer) -> HBoxContainer:
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row

static func _make_chip(k: float, text: String, base_width: float, bg: Color, border: Color,
		text_color: Color) -> Panel:
	var chip: Panel = Panel.new()
	chip.custom_minimum_size = Vector2(roundi(base_width * k), maxi(16.0, roundi(33.0 * k)))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(maxi(2, roundi(6.0 * k)))
	style.set_border_width_all(maxi(1, roundi(2.0 * k)))
	style.border_color = border
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_text(chip, text, _fs(18, k), text_color)
	return chip

static func _text(parent: Control, text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	if size >= 18:
		label.add_theme_font_override("font", QIF_FONTS.display())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

## 区域保护·自适应字号（2026-10-25 用户裁定）：效果/详情/名字带文字挂此线——
## 字号 base→FIT_FLOOR 逐级缩小直到塞进标签实测区域；到底仍溢出由行尾省略号＋面板 clip 兜底。
## width_only=true 时按单行宽测（名字带）；否则按换行宽×高测（效果文）。
static func _wire_fit(label: Label, base: int, width_only: bool = false) -> void:
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.set_meta("fit_base", base)
	label.set_meta("fit_width_only", width_only)
	label.item_rect_changed.connect(_refit_text.bind(label))

static func _refit_text(label: Label) -> void:
	if not label.is_inside_tree() or label.text.is_empty():
		return
	var font: Font = label.get_theme_font("font")
	if font == null:
		return
	var base: int = int(label.get_meta("fit_base", 12))
	var width_only: bool = bool(label.get_meta("fit_width_only", false))
	var avail_w: float = maxf(1.0, label.size.x - (6.0 if width_only else 0.0))
	var avail_h: float = label.size.y
	for size: int in range(base, FIT_FLOOR - 1, -1):
		var fits: bool = false
		if width_only:
			fits = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, size).x <= avail_w
		else:
			fits = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
				avail_w, size).y <= avail_h + 0.5
		if fits:
			label.add_theme_font_size_override("font_size", size)
			return
	label.add_theme_font_size_override("font_size", FIT_FLOOR)

static func _center_text(parent: Control, text: String, size: int, color: Color) -> void:
	var label: Label = _text(parent, text, size, color)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
#endregion
