@tool
extends HBoxContainer

## m20 预览专用：独立血量条 piece（2026-09-20 拆件轮起；当轮升**定长血条**——
## 用户令「血量长度最好不变 不然不好控制」：bar_width 恒定，hp_max 只改刻线密度）。
## 行＝[前缀(可选)]＋定长单平行四边形条（m20_pgram_bar）＋[数字]。
## 可调＝检查器（前缀/气血/条长条高斜边/每段气血）；位置＝拖节点本体 offset。
## 用色＝三调成员：骨白正文＋红血条段。


const PgramBar := preload("res://previews/m20_pgram_bar.gd")

const COL_TEXT := Color(0.85, 0.8, 0.68)
# 组级贴板（2026-09-20 用户令「底板不是一个大的 而是每组一个」）：血量组自画，
# 向外溢出 PAD_X/PAD_Y——不占内容布局、不挪既有摆位；Label 组用 tscn chip 样式盒。
const PAD_X := 6.0
const PAD_Y := 3.0

@export_range(0.0, 1.0) var bg_alpha := 0.35:
	set(v):
		bg_alpha = v
		queue_redraw()
@export var tag_text := "":
	set(v):
		tag_text = v
		_rebuild_if_ready()
@export var hp_now := 100:
	set(v):
		hp_now = v
		_rebuild_if_ready()
@export var hp_max := 100:
	set(v):
		hp_max = v
		_rebuild_if_ready()
@export var font_size := 13:
	set(v):
		font_size = maxi(10, v)
		_rebuild_if_ready()
@export var bar_width := 122:
	set(v):
		bar_width = maxi(40, v)
		_rebuild_if_ready()
@export var seg_h := 8:
	set(v):
		seg_h = maxi(3, v)
		_rebuild_if_ready()
@export var seg_slant := 4:
	set(v):
		seg_slant = maxi(0, v)
		_rebuild_if_ready()
@export var seg_hp := 10:
	set(v):
		seg_hp = maxi(1, v)
		_rebuild_if_ready()


func _ready() -> void:
	_build()


func _draw() -> void:
	if bg_alpha <= 0.001:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.085, 0.08, bg_alpha)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.44, 0.39, 0.3, 0.8)
	sb.set_corner_radius_all(4)
	draw_style_box(sb, Rect2(Vector2(-PAD_X, -PAD_Y), size + Vector2(PAD_X * 2.0, PAD_Y * 2.0)))


func _rebuild_if_ready() -> void:
	if is_inside_tree():
		_build()


func _build() -> void:
	for c in get_children():
		c.free()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	queue_redraw()
	if not tag_text.is_empty():
		var tag_l := Label.new()
		tag_l.text = tag_text
		tag_l.add_theme_font_size_override("font_size", font_size)
		tag_l.add_theme_color_override("font_color", COL_TEXT)
		tag_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tag_l)
	var states: Array[int] = []
	var left := hp_now
	for _i in maxi(1, ceili(hp_max / float(seg_hp))):
		if left >= seg_hp:
			states.push_back(2)
		elif left > 0:
			states.push_back(1)
		else:
			states.push_back(0)
		left -= seg_hp
	var bar: Control = PgramBar.new()
	bar.setup(float(bar_width), float(seg_h), float(seg_slant), states)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var num := Label.new()
	num.text = "%d / %d" % [hp_now, hp_max]
	num.add_theme_font_size_override("font_size", font_size)
	num.add_theme_color_override("font_color", COL_TEXT)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(num)
	# 背板贴内容（2026-09-21 用户问「右侧有一部分空着」拍板自收缩）：HBox 不自收缩，
	# offsets 定死的矩形比内容宽时多余空间全留右侧；排完把容器收到最小内容宽，
	# 自画背板即恒贴内容（条仍定长，动的只是背板宽）。
	size = get_minimum_size()
