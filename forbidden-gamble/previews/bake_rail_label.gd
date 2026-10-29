@tool
extends Control
## 挂签杆·类型标签 chip（功法/护身/心法）——2026-09-24 用户令独立可拖。
## tscn 真节点（各杆子节点），拖本体挪位、位置随场景存盘；文本检查器可改。

const CHIP_BG := Color8(26, 24, 21)
const CHIP_BD := Color8(112, 100, 77)
const GOLD := Color8(235, 219, 179)

@export var label_text := "功法":
	set(v):
		label_text = v
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if _font == null or label_text.is_empty():
		return
	var h: float = label_text.length() * 12 + 10   # 随字数收口
	var sb := StyleBoxFlat.new()
	sb.bg_color = CHIP_BG
	sb.border_color = CHIP_BD
	sb.set_corner_radius_all(3)
	draw_style_box(sb, Rect2(0, 0, 22, h))
	var y := 5.0
	for ch in label_text:
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(_font, Vector2(11.0 - w * 0.5, y + 8.8), ch,
		            HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
		y += 12.0
