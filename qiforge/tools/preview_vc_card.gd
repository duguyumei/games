## TCG 框式武侠卡预览（2026-11-03）：上排详情档 270×380，下排手牌档 216×304；出图后退出。
## 用法：godot --path /Users/cc/Documents/qi-forge-2 res://qiforge/tools/preview_vc_card.tscn
extends Control

const CARD := preload("res://qiforge/QiCardStyle.gd")
const QISTYLE := preload("res://qiforge/QiStyle.gd")

const DEFS: Array = [
	{"name": "上撩", "tone": "red", "qi": 0, "gain": ["撩"],
		"type_line": "攻击 · 剑式",
		"rules": "对最前敌人造成 10 点伤害。"},
	{"name": "万化十四剑", "tone": "red", "qi": 3, "need": ["撩", "撩", "刺"], "gain": ["撩"],
		"type_line": "攻击 · 剑式",
		"rules": "对全体敌人造成 40 点伤害。"},
	{"name": "护盾", "tone": "blue", "qi": 2,
		"type_line": "防御 · 护体",
		"rules": "获得 3 点防御。"},
	{"name": "恢复", "tone": "blue", "qi": 1,
		"type_line": "防御 · 调息",
		"rules": "恢复 2 点气血。"},
	{"name": "强化", "tone": "gold", "qi": 1,
		"type_line": "效果 · 心法",
		"rules": "本回合造成的伤害提高 20%。"},
]

func _ready() -> void:
	QISTYLE.apply_root_theme(self)
	var bg := ColorRect.new()
	bg.color = Color("101014")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	row.position = Vector2(0.0, 110.0)
	row.size = Vector2(1920.0, 400.0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for d in DEFS:
		row.add_child(CARD.make_tcg_card(d, "detail"))

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 34)
	row2.position = Vector2(0.0, 570.0)
	row2.size = Vector2(1920.0, 330.0)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row2)
	for d in DEFS:
		row2.add_child(CARD.make_tcg_card(d, "hand"))

	var title := Label.new()
	title.text = "TCG 框式 · 上排详情 270×380 · 下手牌 216×304"
	title.position = Vector2(0.0, 40.0)
	title.size = Vector2(1920.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	QISTYLE.font(title, QISTYLE.FS_TITLE, true)
	QISTYLE.text_color(title, QISTYLE.TEXT_MAIN)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.tcg_card_preview_v39.png")
	get_tree().quit()
