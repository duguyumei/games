class_name MJBTableZone
extends Control

## 牌桌画布（2026-09-17 用户令「画个牌桌」）：梯形桌面（远端窄、近端宽＝近大远小）
## ＋木沿＋呢面——纯画在牌**后面**适配牌（牌规格不迁就桌面）；不吃鼠标。
## 子内容经 content（VBox·满矩形·让出桌沿）装配：远端背带／中间三列（墙|河|副露）／近端手牌。
## （2026-09-17 晚：2D 线冻结——用户令转 3D；本组件保持全绿态不再演饰。）


const FAR_SHRINK := 0.11  # 远端两侧各收进的比例
const RIM := 16.0
const RIM_COLOR := Color(0.33, 0.25, 0.17)       # 木沿
const RIM_EDGE := Color(0.22, 0.16, 0.1)
const FELT_CORE := Color(0.185, 0.23, 0.185)     # 呢面·近端
const FELT_FAR := Color(0.145, 0.185, 0.15)      # 呢面·远端（压暗推远）

var content := VBoxContainer.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = RIM + 26.0
	content.offset_right = -(RIM + 26.0)
	content.offset_top = RIM * 0.7 + 8.0
	content.offset_bottom = -(RIM * 0.7 + 8.0)
	content.add_theme_constant_override("separation", 6)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content)


func _draw() -> void:
	var s := size
	if s.x < 60.0 or s.y < 60.0:
		return
	var fi := s.x * FAR_SHRINK  # 远端水平收进
	# 木沿梯形
	draw_colored_polygon(PackedVector2Array([
		Vector2(fi, 0.0), Vector2(s.x - fi, 0.0),
		Vector2(s.x, s.y), Vector2(0.0, s.y)]), RIM_COLOR)
	draw_polygon(PackedVector2Array([
		Vector2(fi, 0.0), Vector2(s.x - fi, 0.0),
		Vector2(s.x - fi, 2.5), Vector2(fi, 2.5)]), PackedColorArray([RIM_EDGE]))
	# 呢面梯形（沿内缩）
	var ri := RIM
	var fy := RIM * 0.5
	var poly := PackedVector2Array([
		Vector2(fi + ri, fy), Vector2(s.x - fi - ri, fy),
		Vector2(s.x - ri, s.y - fy), Vector2(ri, s.y - fy)])
	draw_colored_polygon(poly, FELT_CORE)
	# 呢面远端压暗一层（近大远小的纵深暗示）
	draw_colored_polygon(PackedVector2Array([
		Vector2(fi + ri, fy), Vector2(s.x - fi - ri, fy),
		Vector2(s.x - ri, fy + (s.y - 2 * fy) * 0.55),
		Vector2(ri, fy + (s.y - 2 * fy) * 0.55)]),
		Color(FELT_FAR.r, FELT_FAR.g, FELT_FAR.b, 0.6))
	# 沿内描一圈亮线（桌沿高光）
	draw_polyline(PackedVector2Array([
		Vector2(fi + ri, fy), Vector2(s.x - fi - ri, fy),
		Vector2(s.x - ri, s.y - fy), Vector2(ri, s.y - fy), Vector2(fi + ri, fy)]),
		Color(0.5, 0.4, 0.28, 0.8), 1.5)
