@tool
extends Control

## 定长单平行四边形血条（2026-09-20 用户令「敌我的血量长度最好不变 不然不好控制」＋
## 「依旧采取多个平行四边形 还是一个」——选**单条**：总宽 bar_width 恒定，按 seg_hp
## 分段三色填充（满红/半亮），段界画刻线保留「10 血/段」读法；多段定长在 150/200 血时
## 段宽会被压到 6–8px 拥挤，弃。轮廓线保证空槽在深底板上也有形。
## 哑 painter：尺寸/段态由属主（m20_hp_piece）喂数。


const COL_FILLED := Color(0.72, 0.25, 0.2)
const COL_PARTIAL := Color(0.82, 0.45, 0.35)
const COL_EMPTY := Color(0.2, 0.18, 0.16)
const COL_TICK := Color(0, 0, 0, 0.28)
const COL_BORDER := Color(0.44, 0.39, 0.3, 0.5)

var bar_w := 122.0   # 总宽（含斜边占位），恒定不随 hp_max 变
var bar_h := 8.0
var slant := 4.0
var states: Array[int] = []   # 每段 2＝满 1＝半 0＝空


func setup(w: float, h: float, slant_px: float, seg_states: Array[int]) -> void:
	bar_w = maxf(40.0, w)
	bar_h = maxf(3.0, h)
	slant = maxf(0.0, slant_px)
	states = seg_states
	custom_minimum_size = Vector2(bar_w, bar_h)
	queue_redraw()


func _draw() -> void:
	var fill_w := bar_w - slant          # 可填充跨度（右上角让给斜边）
	var seg_n := maxi(1, states.size())
	var seg_w := fill_w / float(seg_n)
	draw_colored_polygon(_shape(0.0, fill_w), COL_EMPTY)
	var x := 0.0
	for i in seg_n:
		var st := 0
		if i < states.size():
			st = states[i]
		if st == 2:
			draw_colored_polygon(_shape(x, seg_w), COL_FILLED)
		elif st == 1:
			draw_colored_polygon(_shape(x, seg_w * 0.5), COL_PARTIAL)
		x += seg_w
	for i in range(1, seg_n):
		var tx := i * seg_w
		draw_line(Vector2(tx, bar_h), Vector2(slant + tx, 0.0), COL_TICK, 1.0)
	var outline := PackedVector2Array([
		Vector2(0.0, bar_h), Vector2(slant, 0.0),
		Vector2(slant + fill_w, 0.0), Vector2(fill_w, bar_h),
		Vector2(0.0, bar_h),
	])
	draw_polyline(outline, COL_BORDER, 1.0, true)


func _shape(x0: float, w: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, bar_h),
		Vector2(slant + x0, 0.0),
		Vector2(slant + x0 + w, 0.0),
		Vector2(x0 + w, bar_h),
	])
