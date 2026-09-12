extends Node2D
# 功法卡真气槽位预览（设计稿，非游戏功能）
# 比例规定：标准卡牌 5:7。功法卡 150×210，槽位=缩小卡位 20×28（同为 5:7），
# 槽上半 14px 凸出卡顶，下半 14px 嵌入卡身。

const CARD_W := 150.0
const CARD_H := 210.0
const SLOT_W := 20.0
const SLOT_H := 28.0
const SLOT_GAP := 8.0
const SLOT_PROTRUDE := 14.0
const CARD_GAP := 40.0
const ORIGIN := Vector2(70, 110)

const PAPER := Color(0.93, 0.89, 0.80)
const SLOT_FILL := Color(0.97, 0.95, 0.88)
const INK := Color(0.25, 0.22, 0.18)
const BG := Color(0.16, 0.17, 0.19)
const LEVEL_COLORS: Array[Color] = [
	Color(0.78, 0.76, 0.72),  # 1 素白
	Color(0.38, 0.66, 0.38),  # 2 绿
	Color(0.32, 0.52, 0.78),  # 3 蓝
	Color(0.62, 0.42, 0.78),  # 4 紫
	Color(0.88, 0.66, 0.22),  # 5 金
]
const ART_COLORS: Array[Color] = [
	Color(0.55, 0.28, 0.22),  # 伤害 朱红系
	Color(0.28, 0.38, 0.52),  # 护境 黛蓝系
	Color(0.55, 0.28, 0.22),
	Color(0.55, 0.28, 0.22),
	Color(0.28, 0.38, 0.52),
]
const QI_WIND := Color(0.45, 0.72, 0.68)

var _cards: Array = [
	{"name": "推掌", "slots": 1, "desc": "伤害 2", "filled": true},
	{"name": "回身卸力", "slots": 2, "desc": "护境=传输内力", "filled": false},
	{"name": "三叠劲", "slots": 3, "desc": "伤害 6", "filled": false},
	{"name": "穿云式", "slots": 4, "desc": "伤害=内力/2", "filled": false},
	{"name": "五岳归元", "slots": 5, "desc": "护境8·下次+1", "filled": false},
]

func _ready() -> void:
	get_viewport().get_window().size = Vector2i(1280, 720)
	_make_labels()
	await get_tree().create_timer(1.0).timeout
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://previews/tech_slots_preview.png")
	print("预览图已保存：res://previews/tech_slots_preview.png")
	get_tree().quit()

func _make_labels() -> void:
	_add_label("功法卡 · 真气槽位 1~5（卡 150×210 ｜ 槽 20×28 ｜ 凸出 14 ｜ 比例均 5:7）", Vector2(70, 30), 22, Color.WHITE)
	_add_label("边框色=功法等级（示意：1素白/2绿/3蓝/4紫/5金，实际等級数据字段定）", Vector2(70, 62), 14, Color(0.7, 0.7, 0.7))
	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		var ox := ORIGIN.x + index * (CARD_W + CARD_GAP)
		var oy := ORIGIN.y
		# 功法名（避开槽嵌入的 14px 带）
		_add_label(str(card["name"]), Vector2(ox, oy + SLOT_PROTRUDE + 20), 17, INK, CARD_W, HORIZONTAL_ALIGNMENT_CENTER)
		# 描述（卡图块之下）
		_add_label(str(card["desc"]), Vector2(ox, oy + SLOT_PROTRUDE + 150), 12, INK, CARD_W, HORIZONTAL_ALIGNMENT_CENTER)
		# 槽数标注
		_add_label("%d 槽" % int(card["slots"]), Vector2(ox, oy + SLOT_PROTRUDE + CARD_H + 12), 14, Color(0.85, 0.85, 0.85), CARD_W, HORIZONTAL_ALIGNMENT_CENTER)
	# 尺寸标注
	_add_label("150", Vector2(ORIGIN.x + CARD_W + 8, ORIGIN.y + SLOT_PROTRUDE + CARD_H + 12), 12, Color(0.6, 0.6, 0.6))
	_add_label("凸出14", Vector2(ORIGIN.x - 46, ORIGIN.y - 2), 11, Color(0.6, 0.6, 0.6))

func _add_label(text: String, pos: Vector2, size: int, color: Color, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	if width > 0.0:
		label.size = Vector2(width, size + 10)
		label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	add_child(label)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), BG)
	for index in range(_cards.size()):
		var card: Dictionary = _cards[index]
		var ox := ORIGIN.x + index * (CARD_W + CARD_GAP)
		var oy := ORIGIN.y
		var card_rect := Rect2(ox, oy + SLOT_PROTRUDE, CARD_W, CARD_H)
		# 卡身：米黄底 + 等级色边框
		draw_rect(card_rect, PAPER)
		draw_rect(card_rect, LEVEL_COLORS[index], false, 3.0)
		# 卡图占位块（类型色）
		draw_rect(Rect2(ox + 10, oy + SLOT_PROTRUDE + 54, CARD_W - 20, 88), ART_COLORS[index])
		# 槽位：压在卡身上，上半凸出、下半嵌入
		var slot_count: int = card["slots"]
		var total := slot_count * SLOT_W + (slot_count - 1) * SLOT_GAP
		var sx := ox + (CARD_W - total) / 2.0
		for slot_index in range(slot_count):
			var slot_rect := Rect2(sx + slot_index * (SLOT_W + SLOT_GAP), oy, SLOT_W, SLOT_H)
			draw_rect(slot_rect, SLOT_FILL)
			draw_rect(slot_rect, INK, false, 1.5)
			# 1 槽卡演示"真气已填入"：缩小的真气卡（同 5:7）
			if bool(card["filled"]):
				draw_rect(slot_rect.grow(-2), QI_WIND)
				draw_rect(slot_rect.grow(-2), INK, false, 1.0)
