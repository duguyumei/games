## 式徽（2026-11-05 用户令）：需要＝正方形 / 可获得＝菱形 / 已拥有＝朱砂实底
extends Control

const INK := Color(0.16, 0.13, 0.10)
const PAPER := Color(0.91, 0.87, 0.78)
const RED := Color(0.59, 0.18, 0.14)
const INK_DIM := Color(0.16, 0.13, 0.10, 0.30)
## 三式三色（HUD 顶行与卡牌工厂共用——2026-11-05 用户令「卡内与顶部同款」）
const TINTS := {"斩": Color("a3352c"), "刺": Color("2c4a6e"), "撩": Color("3d5a44")}

var glyph := "斩"
var diamond := false      # false＝正方形（需要），true＝菱形（可获得）
var owned := false        # true＝朱砂实底
var dim := false          # 未获得/不可用
var tint := Color(0.59, 0.18, 0.14)   # 已拥有时的底色（三式三色）

var side := 56.0          # 边长（HUD 行放大用）

func _ready() -> void:
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	var pts := PackedVector2Array()
	if diamond:
		pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	else:
		pts = PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, r)])
	var col := INK_DIM if dim else INK
	if owned:
		draw_colored_polygon(pts, tint)
		draw_polyline(pts + PackedVector2Array([pts[0]]), tint.darkened(0.35), 2.0, true)
	else:
		draw_colored_polygon(pts, PAPER)
		draw_polyline(pts + PackedVector2Array([pts[0]]), col, 2.5, true)
	var f := ThemeDB.fallback_font
	var fs := int(r * 1.05)
	var tcol := PAPER if owned else col
	var tw := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var th := f.get_ascent(fs)
	draw_string(f, c + Vector2(-tw * 0.5, th * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)
