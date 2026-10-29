@tool
class_name MJBTableCloth
extends Control

## 中央桌布（2026-09-18 用户令：长方形·只在中央区·深绿·远近效果——直接画，不上 3D/2.5D）。
## 「像纸不像桌」修正（同日用户令）：加四件视觉线索，每件独立旋钮可关——
##   ① 近沿厚度（桌帮：上亮下暗的侧立面，纸→盒子的最大单笔）
##   ② 桌沿收口（呢面外一圈木沿，把"桌面"从背景里框出来）
##   ③ 灯斑（桌心亮四角暗的径向光——布在灯下，不是贴纸的平光）
##   ④ 呢面颗粒（NoiseTexture2D 织纹，零资产引擎生成）
## 远近感底色＝梯形（近宽远窄）＋纵向轻渐变。鼠标穿透，牌/战报等内容压其上。


@export var top_width_ratio := 0.65:
	set(v):
		top_width_ratio = v
		queue_redraw()
@export var shade_far := 0.18:
	set(v):
		shade_far = v
		queue_redraw()
@export var felt_color := Color(0.12, 0.33, 0.21):  # 呢面（2026-09-18 用户令：正绿调，去灰）
	set(v):
		felt_color = v
		queue_redraw()
@export var rim_width := 14.0:  # ② 桌沿宽（0＝无沿）
	set(v):
		rim_width = v
		queue_redraw()
@export var rim_color := Color(0.21, 0.14, 0.08):  # ② 木沿色（提亮一档增对比）
	set(v):
		rim_color = v
		queue_redraw()
@export var apron_height := 20.0:  # ① 桌帮高（0＝无厚度）
	set(v):
		apron_height = v
		queue_redraw()
@export var apron_color := Color(0.10, 0.07, 0.045):  # ① 桌帮色（上亮下暗）
	set(v):
		apron_color = v
		queue_redraw()
@export var lamp_strength := 0.06:  # ③ 灯斑强度（0＝无；2026-09-18 调低——绒面匀净，不要亮斑块）
	set(v):
		lamp_strength = v
		queue_redraw()
@export var grain_strength := 0.035:  # ④ 呢面颗粒（0＝无；2026-09-18 调细——绒毛感非马赛克）
	set(v):
		grain_strength = v
		queue_redraw()


var _lamp_tex: GradientTexture2D
var _grain_tex: NoiseTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# 灯斑纹理：径向白→透明（强度由顶点色 alpha 控制，纹理恒定）
	_lamp_tex = GradientTexture2D.new()
	_lamp_tex.fill = GradientTexture2D.FILL_RADIAL
	_lamp_tex.fill_from = Vector2(0.5, 0.5)
	_lamp_tex.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.75])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_lamp_tex.gradient = grad
	_lamp_tex.width = 256
	_lamp_tex.height = 256
	# 呢面颗粒：引擎噪声＋透明度渐变（高频细粒＝绒毛感；低频大团＝马赛克，2026-09-18 教训）
	_grain_tex = NoiseTexture2D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.35
	_grain_tex.noise = noise
	_grain_tex.width = 256
	_grain_tex.height = 256
	_grain_tex.seamless = true
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1)])
	_grain_tex.color_ramp = ramp


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	var ratio := clampf(top_width_ratio, 0.1, 1.0)
	var apron_h := clampf(apron_height, 0.0, h * 0.4)
	var felt_h := h - apron_h
	var r := clampf(rim_width, 0.0, minf(w, felt_h) * 0.25)

	# ① 桌帮（近沿厚度）：上亮下暗——亮沿接桌沿，暗底接地面影
	if apron_h > 0.5:
		var a_top := apron_color
		var a_bot := apron_color.darkened(0.5)
		draw_polygon(PackedVector2Array([
			Vector2(0, felt_h), Vector2(w, felt_h), Vector2(w, h), Vector2(0, h),
		]), PackedColorArray([a_top, a_top, a_bot, a_bot]))

	# ② 桌沿外壳（外梯形）
	var inset_out := (1.0 - ratio) * w * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(inset_out, 0), Vector2(w - inset_out, 0),
		Vector2(w, felt_h), Vector2(0, felt_h),
	]), rim_color)

	# 呢面（内梯形：三面内收桌沿宽）＋远近纵向渐变（顶点色）
	var fw := w - 2.0 * r
	var inset_in := (1.0 - ratio) * fw * 0.5
	var felt_pts := PackedVector2Array([
		Vector2(r + inset_in, r), Vector2(w - r - inset_in, r),
		Vector2(w - r, felt_h - r), Vector2(r, felt_h - r),
	])
	var far := felt_color.darkened(clampf(shade_far, 0.0, 1.0))
	var felt_cols := PackedColorArray([far, far, felt_color, felt_color])
	draw_polygon(felt_pts, felt_cols)
	# 呢面沉入桌沿的内缘暗线（绒面与木沿的接缝）
	draw_rect(Rect2(felt_pts[0], felt_pts[2] - felt_pts[0]).grow(-2.0), Color(0, 0, 0, 0.25), false, 2.0)

	# 内梯形 bbox 归一化 UV（灯斑用）
	var origin := Vector2(r + inset_in, r)
	var span := Vector2(fw - 2.0 * inset_in, felt_h - 2.0 * r)

	# ③ 灯斑：呢面径向提亮（白斑×顶点色 alpha＝强度）
	if lamp_strength > 0.001:
		var lamp_col := Color(0.85, 1.0, 0.9, clampf(lamp_strength, 0.0, 1.0))
		var lamp_cols := PackedColorArray([lamp_col, lamp_col, lamp_col, lamp_col])
		var lamp_uvs := PackedVector2Array()
		for p in felt_pts:
			lamp_uvs.append((p - origin) / span)
		draw_polygon(felt_pts, lamp_cols, lamp_uvs, _lamp_tex)

	# ④ 呢面颗粒：低强度织纹噪点（UV×8 平铺）
	if grain_strength > 0.001:
		var g := clampf(grain_strength, 0.0, 1.0)
		var grain_cols := PackedColorArray([Color(1, 1, 1, g), Color(1, 1, 1, g), Color(1, 1, 1, g), Color(1, 1, 1, g)])
		var grain_uvs := PackedVector2Array()
		for p in felt_pts:
			grain_uvs.append(((p - origin) / span) * 3.0)
		draw_polygon(felt_pts, grain_cols, grain_uvs, _grain_tex)
