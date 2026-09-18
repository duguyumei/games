class_name MJFxNodes
extends RefCounted

## 特效节点构件（占位 VFX：代码绘制，零商业资产提取）。时序与补间住 fx_layer，本文件只造节点。


## 扩散光环：draw_arc 半径随 progress 扩大、透明度衰减（打点/招架/护体通用）。
class Ring extends Control:
	var progress := 0.0
	var color := Color(1, 1, 1)
	var width := 3.0

	func _draw() -> void:
		var r := progress * minf(size.x, size.y) * 0.5
		if r <= 1.0:
			return
		var c := Color(color.r, color.g, color.b, (1.0 - progress) * 0.9)
		draw_arc(size / 2.0, r, 0.0, TAU, 40, c, width)


## 攻击光束：from→to 一条亮线头部推进、尾部拖光、落点绽点（progress 0→1）。
class Beam extends Control:
	var from := Vector2.ZERO  # 本控件局部坐标
	var to := Vector2.ZERO
	var progress := 0.0
	var color := Color(1, 0.5, 0.4)

	func _draw() -> void:
		var head := from.lerp(to, minf(progress * 1.7, 1.0))
		var tail := from.lerp(head, 0.55)
		var a := 1.0 - progress
		draw_line(tail, head, Color(color.r, color.g, color.b, a * 0.3), 10.0)
		draw_line(tail, head, Color(color.r, color.g, color.b, a * 0.9), 4.0)
		if progress > 0.2:
			draw_circle(to, 5.0 * a + 2.0, Color(color.r, color.g, color.b, a * 0.7))


static func make_ring(at: Vector2, max_r: float, color: Color, width := 3.0) -> Ring:
	var ring := Ring.new()
	ring.color = color
	ring.width = width
	ring.size = Vector2(max_r, max_r) * 2.0
	ring.position = at - ring.size / 2.0
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.material = additive_mat()
	return ring


static func make_beam(from: Vector2, to: Vector2, color: Color) -> Beam:
	var beam := Beam.new()
	beam.color = color
	var margin := Vector2(24, 24)
	beam.position = from.min(to) - margin
	beam.size = (to - from).abs() + margin * 2.0
	beam.from = from - beam.position
	beam.to = to - beam.position
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam.material = additive_mat()
	return beam


## 加法混合材质（光环/光束/粒子＝发光体，暗底桌面天然出光感）。
static func additive_mat() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


## 飘字（伤害数/招架名/破绽等）：给定锚点居中，宽度按字数×字号估。
static func make_float(text: String, at: Vector2, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.06, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	var w := float(text.length()) * font_size * 1.05
	label.custom_minimum_size = Vector2(w, font_size * 1.7)
	label.position = at - label.custom_minimum_size / 2.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
