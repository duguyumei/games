## qi-forge 升级方向选择件（2026-10-27 用户裁定：升级预览一律真卡对照＋diff 标记，STS2 NUpgradePreview 制）：
## 功法＝「原卡 → 方向一卡 / 方向二卡」三真卡横排（升级卡带句级 diff：＋绿／－红／改琥珀，名字与费用变化转琥珀）；
## 被动＝器灵主卡（左）＋两方向文字块（右，原被动文在标题行，方向文即按钮）——被动无结构化 ops，不做句级 diff。
## 两制共用：战后奖励方向页＋商店操作位升级。qiforge 禁 class_name。
extends RefCounted

const QICARD := preload("res://qiforge/QiCardStyle.gd")
const QI_DATA := preload("res://qiforge/QiData.gd")
const QISTYLE := preload("res://qiforge/QiStyle.gd")

## 功法升级三卡行：点升级卡＝选该方向（on_pick.call(dir)）
static func spell_dir_row(wid: String, sid: String, on_pick: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var base: Dictionary = QI_DATA.spell_of(wid, sid, 0)
	row.add_child(_labeled_card("原卡", QICARD.make_spell_card(
		String(base["name"]), int(base["cost"]), String(base["desc"])), false))
	for dir: int in [1, 2]:
		var up: Dictionary = QI_DATA.spell_of(wid, sid, dir)
		var diff: Dictionary = QI_DATA.spell_diff(wid, sid, dir)
		var card: Button = QICARD.make_spell_preview_card(up, diff)
		var d := dir
		card.pressed.connect(func() -> void: on_pick.call(d))
		row.add_child(_labeled_card("方向%s" % ("一二".substr(dir - 1, 1)), card, true))
	return row

## 被动方向对照块：主卡（被动原文进卡面 desc）＋两方向文字按钮
static func passive_dir_block(wid: String, on_pick: Callable) -> Control:
	var w: Dictionary = QI_DATA.WEAPONS[wid]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var base_desc := "被动「%s」：%s" % [w["passive"]["name"], w["passive"]["desc"]]
	row.add_child(_labeled_card("当前",
		QICARD.make_spirit_card({"name": String(w["name"]), "desc": base_desc}), false))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for dir: int in [1, 2]:
		var b := Button.new()
		b.text = "方向%s：%s" % ["一二".substr(dir - 1, 1),
			String(w["passive"]["ups"].get(str(dir), ""))]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(560, 96)
		QISTYLE.apply_ghost(b)
		QISTYLE.font(b, QISTYLE.FS_SMALL)
		b.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
		var d := dir
		b.pressed.connect(func() -> void: on_pick.call(d))
		col.add_child(b)
	row.add_child(col)
	return row

## 卡＋顶注（可点卡加琥珀描边提示）
static func _labeled_card(tag: String, card: Control, pickable: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Label.new()
	l.text = ("▶ " if pickable else "") + tag
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	QISTYLE.font(l, QISTYLE.FS_SMALL, true)
	l.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT if pickable else QISTYLE.TEXT_SUB)
	col.add_child(l)
	col.add_child(card)
	return col
