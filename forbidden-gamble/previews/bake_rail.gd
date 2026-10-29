@tool
extends Control
## 挂签架·单杆组件（2026-09-24 用户令拆三杆各自可拖）。
## 一节点＝一杆：木杆＋五签位；类型标签 chip＝子节点（bake_rail_label.gd）、
## 罡 chip＝护身杆子节点（bake_rail_gang.gd）——均独立可拖。
## 形制＝V5 定案：功法朱·活绳／护身赭金·活绳＋罡随杆／心法玄青·铜钉钉驻常亮。
## tscn 真节点（架层/功法杆·护身杆·心法杆），**拖节点本体挪单杆**、位置随场景存盘；
## 杆距/签距/签宽长/画区高检查器可调（改即重画）。

const WOOD := Color8(96, 68, 42)
const WOOD_D := Color8(66, 46, 28)
const CAP := Color8(202, 168, 96)
const CHIP_BG := Color8(26, 24, 21)
const CHIP_BD := Color8(112, 100, 77)
const PAPER := Color8(222, 212, 188)
const PAPER_DIM := Color8(172, 164, 148)
const INK := Color8(33, 28, 23)
const INK_DIM := Color8(100, 96, 88)
const GOLD := Color8(235, 219, 179)
const CORD := Color8(150, 132, 100)
const HOLE := Color8(120, 104, 78)
const BRONZE := Color8(176, 148, 92)
const BRONZE_D := Color8(120, 96, 52)
const ZHU := Color8(184, 64, 51)
const ZHEJIN := Color8(194, 156, 79)
const XUANQING := Color8(61, 84, 89)
const BADGE_BG := Color8(120, 38, 32)
const BADGE_FG := Color8(240, 230, 210)
const TASSEL_DIM := Color8(130, 124, 112)

# 演示数据（名称＝档内实件；护身罡 chip 随杆）
const RAIL_ZHU := 0
const RAIL_HU := 1
const RAIL_XIN := 2
const DATA := {
	RAIL_ZHU: {"label": "功法", "rail": ZHU, "kind": "hang",
		"items": [["破甲拳", "lit", ""], ["点穴", "lit", ""], ["连环掌", "dim", "式3"], [null, "empty", ""], [null, "empty", ""]]},
	RAIL_HU: {"label": "护身", "rail": ZHEJIN, "kind": "hang",
		"items": [["铁布衫", "lit", ""], ["金钟罩", "dim", "罡4"], [null, "empty", ""], [null, "empty", ""], [null, "empty", ""]]},
	RAIL_XIN: {"label": "心法", "rail": XUANQING, "kind": "pin",
		"items": ["拆招诀", "运筹诀", "洗练诀"]},
}

@export var rail_type := RAIL_ZHU:   # 0=功法 1=护身 2=心法
	set(v):
		rail_type = v
		queue_redraw()
@export var pitch := 40.0:           # 签距
	set(v):
		pitch = v
		queue_redraw()
@export var bm_w := 34.0:            # 签宽
	set(v):
		bm_w = v
		queue_redraw()
@export var paper_h := 66.0:         # 签长
	set(v):
		paper_h = v
		queue_redraw()
@export var art_h := 28.0:           # 画区高
	set(v):
		art_h = v
		queue_redraw()

var _font: Font

func _ready() -> void:
	_font = load("res://assets/fonts/LXGWWenKai-Medium.ttf")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if _font == null:
		return
	var d: Dictionary = DATA[rail_type]
	var rail: Color = d["rail"]
	var slots := 5                                   # 槽位容量（杆长按槽画，不按已挂数）
	var rx1: float = 15.0 + (slots - 1) * pitch + bm_w * 0.5 + 8.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.border_color = WOOD_D
	sb.set_corner_radius_all(2)
	sb.set_border_width_all(1)
	draw_style_box(sb, Rect2(-8, 0, rx1 + 8, 5))
	draw_rect(Rect2(-8, -3, 4, 11), CAP)               # 杆端金包头
	draw_rect(Rect2(rx1 - 4, -3, 4, 11), CAP)
	if d["kind"] == "hang":
		for i in d["items"].size():
			var it: Array = d["items"][i]
			_bm_hang(15.0 + i * pitch, rail, it[0], it[1], it[2])
	else:
		var names: Array = d["items"]
		for i in 5:
			_bm_pin(15.0 + i * pitch, names[i] if i < names.size() else null)

func _vtext(cx: float, top: float, chars: String, size: int, color: Color) -> void:
	var y := top
	for ch in chars:
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(_font, Vector2(cx - w * 0.5, y + size * 0.8), ch,
		            HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		y += size + 1.0

func _bm_hang(cx: float, rail: Color, title, state: String, badge: String) -> void:
	draw_line(Vector2(cx, 5), Vector2(cx, 12), CORD, 2.0, true)
	draw_arc(Vector2(cx, 15), 3.0, 0, TAU, 12, HOLE, 2.0, true)
	if state == "empty":
		return
	var ytop := 21.0
	if state == "ghost":
		var gs := StyleBoxFlat.new()                    # 在途虚影（空框半透）
		gs.border_color = rail
		gs.set_corner_radius_all(3)
		gs.set_border_width_all(2)
		draw_style_box(gs, Rect2(cx - bm_w * 0.5, ytop, bm_w, paper_h))
		_vtext(cx, ytop + 8.0, title, 10, rail.lerp(PAPER, 0.5))
		return
	_paper(cx, ytop, title, rail, state == "lit", badge)
	if state == "lit":
		draw_line(Vector2(cx - bm_w * 0.5, ytop), Vector2(cx + bm_w * 0.5, ytop), GOLD, 1.0, true)
	_tassel(cx, ytop + paper_h + 2.0, rail, state == "lit")

func _paper(cx: float, ytop: float, title: String, rail: Color, lit: bool, badge: String) -> void:
	var x := cx - bm_w * 0.5
	var base := PAPER if lit else PAPER_DIM
	var pts := PackedVector2Array([
		Vector2(x + 4, ytop), Vector2(x + bm_w - 4, ytop),
		Vector2(x + bm_w, ytop + 4), Vector2(x + bm_w, ytop + paper_h),
		Vector2(x, ytop + paper_h), Vector2(x, ytop + 4)])
	var cols := PackedColorArray()
	for _i in pts.size():
		cols.append(base)
	draw_polygon(pts, cols)
	for i in pts.size():                                # 多边形无描边，线段勾一圈
		draw_line(pts[i], pts[(i + 1) % pts.size()], CHIP_BD, 1.0, true)
	var art := StyleBoxFlat.new()                       # 画区（轨色染）
	art.bg_color = rail.lerp(base, 0.55)
	art.set_corner_radius_all(2)
	draw_style_box(art, Rect2(x + 3, ytop + 5, bm_w - 6, art_h))
	var wm := title.substr(0, 1)                        # 画区水印＝标题首字
	var wm_w := _font.get_string_size(wm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(_font, Vector2(cx - wm_w * 0.5, ytop + 5.0 + art_h * 0.5 + 5.0), wm,
	            HORIZONTAL_ALIGNMENT_LEFT, -1, 15, rail.lerp(PAPER, 0.72))
	_vtext(cx, ytop + art_h + 9.0, title, 10, INK if lit else INK_DIM)
	draw_rect(Rect2(x + bm_w - 8, ytop + paper_h - 8, 5, 5), rail)   # 底角轨色印
	if badge != "":                                     # 成本角标（式X/罡X）
		var bw := 12.0 + badge.length() * 7.0
		var bs := StyleBoxFlat.new()
		bs.bg_color = BADGE_BG
		bs.set_corner_radius_all(3)
		draw_style_box(bs, Rect2(x + bm_w - bw - 2, ytop + 2, bw, 12))
		var tw := _font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(_font, Vector2(x + bm_w - 2 - bw * 0.5 - tw * 0.5, ytop + 11.5), badge,
		            HORIZONTAL_ALIGNMENT_LEFT, -1, 9, BADGE_FG)

func _tassel(cx: float, ty: float, rail: Color, lit: bool) -> void:
	var tc := rail if lit else TASSEL_DIM
	draw_rect(Rect2(cx - 2, ty, 4, 4), tc)
	for dx in [-3.0, 0.0, 3.0]:
		draw_line(Vector2(cx + dx, ty + 4), Vector2(cx + dx, ty + 10), tc, 1.0, true)

func _bm_pin(cx: float, title) -> void:
	if title == null:                                   # 空位＝钉孔
		draw_arc(Vector2(cx, 3), 2.0, 0, TAU, 10, HOLE, 1.0, true)
		return
	var ytop := 5.0
	_paper(cx, ytop, title, XUANQING, true, "")
	draw_circle(Vector2(cx, 3), 3.0, BRONZE)            # 铜钉直钉杆上
	draw_arc(Vector2(cx, 3), 3.0, 0, TAU, 12, BRONZE_D, 1.0, true)
	_tassel(cx, ytop + paper_h + 2.0, XUANQING, true)
