@tool
extends Control
## 血带（V5 中线战况带·朱砂笔意）——敌我各一真节点，拖本体挪位、检查器改数值（正式件＝动态接线）。
## 09-26 两连定谳：
##  ① 方向统一左→右——满血在右、掉血从右端蚀、冷锚在左（主流非格斗惯例；镜像向心＝格斗左右对峙布局专用，弃）；
##  ② 形制＝长方形——用户令「血条就长方形吧」，斜切底槽/平行四边形语汇整体退役（V5 效果图斜切条款随之作废）。
## 保留原参：渐变朱填（冷锚暗→火头亮）＋火头竖亮线＋每 30 血段刻＋左侧骨白「气血 N」签。

const SLOT_BG := Color8(24, 21, 18)
const SLOT_BD := Color8(88, 78, 62)
const TOP_EDGE := Color8(120, 108, 84)
const HEAD := Color8(236, 128, 92)
const TICK := Color8(16, 14, 12)
const PAPER := Color8(222, 212, 188)
const CHIP_BD := Color8(112, 100, 77)
const INK := Color8(33, 28, 23)

const TAG_W := 74.0
const TAG_GAP := 8.0
const BAND_H := 26.0

@export var hp_value := 137:
	set(v):
		hp_value = v
		queue_redraw()
@export var hp_max := 150:
	set(v):
		hp_max = max(v, 1)
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(TAG_W + TAG_GAP + 120.0, BAND_H)

func _draw() -> void:
	var band_w: float = maxf(size.x - TAG_W - TAG_GAP, 40.0)
	var bx := TAG_W + TAG_GAP
	# 长方形底槽；顶缘亮线＝凹槽受光
	var slot := Rect2(bx, 0, band_w, BAND_H)
	draw_rect(slot, SLOT_BG, true)
	draw_rect(slot, SLOT_BD, false, 1.0)
	draw_line(Vector2(bx, 0.5), Vector2(bx + band_w, 0.5), TOP_EDGE, 1.0)
	# 渐变朱填（2px 条拼，冷锚左暗→火头右亮）
	var lft := bx + 4.0
	var rgt := bx + band_w - 4.0
	var span: float = rgt - lft
	var frac: float = clampf(float(hp_value) / float(hp_max), 0.0, 1.0)
	var n := int(span * frac)
	var x := lft
	while x < lft + n:
		var x2: float = minf(x + 2.0, lft + n)
		var t: float = ((x + x2) * 0.5 - lft) / span
		var col := Color8(int(150.0 + 62.0 * t), int(42.0 + 40.0 * t), int(36.0 + 24.0 * t))
		draw_rect(Rect2(x, 3, x2 - x, BAND_H - 6), col)
		x = x2
	# 火头亮帽（2px 竖亮线，落在侵蚀缘）
	if frac > 0.02:
		draw_rect(Rect2(lft + n - 2, 3, 2, BAND_H - 6), HEAD)
	# 段刻：每 30 血一段（hp_max 150 → 4 刻线 5 段）
	var seg := hp_max / 30
	for i in range(1, seg):
		var tickx: float = lft + int(span * i / seg)
		draw_line(Vector2(tickx, 2), Vector2(tickx, BAND_H - 2), TICK, 1.0)
	_draw_tag()

func _draw_tag() -> void:
	if _font == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = CHIP_BD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	draw_style_box(sb, Rect2(0, BAND_H * 0.5 - 11.0, TAG_W, 22.0))
	draw_string(_font, Vector2(0, BAND_H * 0.5 + 4.2), "气血 %d" % hp_value,
	            HORIZONTAL_ALIGNMENT_CENTER, TAG_W, 12, INK)
