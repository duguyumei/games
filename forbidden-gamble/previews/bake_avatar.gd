@tool
extends Control
## 头像框（V5 敌情报簇头件／我方账本尾件）——真节点，拖本体挪位、字检查器可改（正式件＝头像真图接线）。
## 规格自 V5 效果图：暗底 (33,28,23)＋CHIP_BD 描边＋圆角 4＋马善政 22 金字居中（占位字）。

const AVATAR_BG := Color8(33, 28, 23)
const CHIP_BD := Color8(112, 100, 77)
const GOLD := Color8(235, 219, 179)

@export var avatar_char := "玄":
	set(v):
		avatar_char = v
		queue_redraw()
@export var char_size := 22:
	set(v):
		char_size = max(v, 8)
		queue_redraw()
@export var gold_border := false:   # N2 名牌头像＝金框（V5 定案「头像 44 金框」）
	set(v):
		gold_border = v
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/MaShanZheng-Regular.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if _font == null or avatar_char.is_empty():
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = AVATAR_BG
	sb.border_color = Color8(168, 144, 92) if gold_border else CHIP_BD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	draw_style_box(sb, Rect2(0, 0, size.x, size.y))
	draw_string(_font, Vector2(0, size.y * 0.5 + char_size * 0.36), avatar_char,
	            HORIZONTAL_ALIGNMENT_CENTER, size.x, char_size, GOLD)
