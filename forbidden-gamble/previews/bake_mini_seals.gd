@tool
extends Control
## 敌方心法小印行（V5 定案件）——玄青小章一行：挂数＝首字章、空槽＝虚点圆。
## 09-26 移名号旁并缩小（seal_size 参数化）。悬停出说明属正式件交互，预览仅示形。

const SEAL_BG := Color8(50, 69, 73)      # XUANQING (61,84,89) 向 (20,24,26) 调 25%（效果图实测值）
const SEAL_BD := Color8(96, 116, 120)
const SEAL_FG := Color8(168, 192, 196)
const DOT := Color8(90, 84, 70)

@export var titles: PackedStringArray = ["拆招诀", "运筹诀", "洗练诀"]:
	set(v):
		titles = v
		queue_redraw()
@export var slots := 5:
	set(v):
		slots = max(v, 1)
		queue_redraw()
@export var seal_size := 22.0:
	set(v):
		seal_size = max(v, 10.0)
		queue_redraw()
@export var slot_w := 30.0
@export var vertical := false:
	set(v):
		vertical = v
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if _font == null:
		return
	var fs := int(seal_size * 0.55)
	for i in slots:
		var pos := Vector2(i * slot_w, 0.0) if not vertical else Vector2(0.0, i * slot_w)
		if i < titles.size() and not titles[i].is_empty():
			var sb := StyleBoxFlat.new()
			sb.bg_color = SEAL_BG
			sb.border_color = SEAL_BD
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(int(seal_size * 0.18))
			draw_style_box(sb, Rect2(pos, Vector2(seal_size, seal_size)))
			draw_string(_font, Vector2(pos.x, pos.y + seal_size * 0.69), titles[i].substr(0, 1),
			            HORIZONTAL_ALIGNMENT_CENTER, seal_size, fs, SEAL_FG)
		else:
			draw_arc(pos + Vector2(seal_size * 0.5, seal_size * 0.5), seal_size * 0.18,
			         0.0, TAU, 10, DOT, 1.0)
