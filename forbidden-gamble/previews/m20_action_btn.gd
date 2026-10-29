@tool
class_name M20ActionBtn
extends Button

## 方案 B：2D HUD 行动按钮（2026-09-22 用户令「还是改用方案b吧」——A 牌令试制被否）。
## 构造＝我地麻金钮配方七成像（调研实测）：阴影→深底框→轨色主面＋内亮圈→
## 顶部高光带→底缘描金→马善政骨白字；轨色＝攻击朱/变招玄青（§3 轨色印同源）。
## 自绘走 draw_style_box（2026-09-17 教训：StyleBox.draw() 收 RID 报 canvas_item null）；
## 位置＝真节点 offset 全手调；preview_state 供编辑器切四态过目（运行态走真实交互）。
## CJK 垂直居中按 chip 轮教训加非对称补偿（+1.5px，可调）。

enum PreviewState { LIVE, NORMAL, HOVER, PRESSED, DISABLED }

const FONT := preload("res://assets/fonts/MaShanZheng-Regular.ttf")
const BONE := Color(0.92, 0.89, 0.80)   # 骨白文字（用色三调·骨白档）
const GOLD := Color(0.92, 0.86, 0.70)   # 底缘描金（用色三调·金档）

@export var btn_text := "变招":
	set(v):
		btn_text = v
		_redraw()
@export var rail_color := Color(0.24, 0.33, 0.35):
	set(v):
		rail_color = v
		_redraw()
@export var font_size := 22:
	set(v):
		font_size = maxi(10, v)
		_redraw()
@export var preview_state := PreviewState.LIVE:
	set(v):
		preview_state = v
		_redraw()


func _ready() -> void:
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, empty)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	resized.connect(queue_redraw)
	queue_redraw()


func _redraw() -> void:
	if is_inside_tree():
		queue_redraw()


func _current_state() -> String:
	if Engine.is_editor_hint() and preview_state != PreviewState.LIVE:
		return ["normal", "hover", "pressed", "disabled"][preview_state - 1]
	if disabled:
		return "disabled"
	if pressed:
		return "pressed"
	if is_hovered():
		return "hover"
	return "normal"


func _draw() -> void:
	var state := _current_state()
	var dim := 0.45 if state == "disabled" else 1.0
	var face := rail_color.darkened(0.18)
	var edge := rail_color.lightened(0.25)
	match state:
		"hover":
			face = face.lightened(0.10)
			edge = edge.lightened(0.15)
		"pressed":
			face = face.darkened(0.10)

	# 层 0：投影（下坠 2px）
	var shadow := _flat(Color(0, 0, 0, 0.28 * dim), 10, Color(0, 0, 0, 0))
	draw_style_box(shadow, Rect2(Vector2(0, 2), size))
	# 层 1：深底框（露 2px 圈＝深描边）
	draw_style_box(_flat(rail_color.darkened(0.55) * Color(dim, dim, dim, 1), 10, Color(0, 0, 0, 0)),
		Rect2(Vector2.ZERO, size))
	# 层 2：主面＋内亮圈
	var main := _flat(face * Color(dim, dim, dim, 1), 8, edge * Color(1, 1, 1, dim))
	draw_style_box(main, Rect2(Vector2(2, 2), size - Vector2(4, 4)))
	# 层 3：顶部高光带（上半 42%，只上圆角，半透明叠主面）
	var hl := _flat(face.lightened(0.22) * Color(1, 1, 1, 0.32), 0, Color(0, 0, 0, 0))
	hl.corner_radius_top_left = 8
	hl.corner_radius_top_right = 8
	draw_style_box(hl, Rect2(Vector2(2, 2), Vector2(size.x - 4, (size.y - 4) * 0.42)))
	# 层 4：底缘描金（3px 金线）
	if state != "disabled":
		draw_style_box(_flat(Color(GOLD.r, GOLD.g, GOLD.b, 0.30), 1, Color(0, 0, 0, 0)),
			Rect2(Vector2(4, size.y - 5), Vector2(size.x - 8, 3)))

	# 文字：马善政骨白，垂直居中含 CJK 补偿；按下下沉 1px
	var text_color := Color(BONE.r * dim, BONE.g * dim, BONE.b * dim, 1 if state != "disabled" else 0.5)
	var h := FONT.get_height(font_size)
	var y := (size.y - h) * 0.5 + FONT.get_ascent(font_size) + 1.5 + (1.0 if state == "pressed" else 0.0)
	draw_string(FONT, Vector2(0, y), btn_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)


func _flat(bg: Color, corner: int, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(corner)
	sb.border_color = border
	sb.set_border_width_all(1 if border.a > 0 else 0)
	return sb
