## 经验珠特效层（2026-11-05 经验美术轮，用户令「金色」）。
## 2026-11-15 用户令：只保留①出生回弹 ②贝塞尔飞行＋笔锋拖尾 ③到条头直接消失；
## 落点墨溅/冲击环/「+N」浮字/缩小淡出全部退役。珠身＝xp_orb.png（同族金珠）。
## 只吃一张贴图：软圆点/光环/扫光带全是 GradientTexture2D 运行期生成（零资源）。
## 本层铺满 1920×1080、mouse_filter 全 IGNORE——绝不吃按钮点击。
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const QI_CAB := preload("res://qiforge/QiVcCabinet.gd")

## 2026-11-06 用户裁定：经验＝淡墨蓝（跟经验条同族、比条面浅一档）；金只留给「突破」那一下
const XP := Color(0.44, 0.62, 0.84)
const XP_HI := Color(0.82, 0.90, 1.0)
const XP_DEEP := Color(0.20, 0.33, 0.49)
const GOLD := Color(0.95, 0.78, 0.40)
const ORB := 38.0                 # 珠身显示边长
const TRAIL_MAX := 10             # 拖尾点数
const FLY_REF := 2100.0           # 距离→时长基准（像素/秒）

var _dot: GradientTexture2D        # 软圆点（珠身光晕；落点粒子已退役）
var _orb_tex: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	z_index = 90
	_dot = _radial(64,
		PackedFloat32Array([0.0, 0.45, 1.0]),
		PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)]))
	_orb_tex = QI_CAB._art("xp_orb")

## 径向渐变贴图（软点/光环）：fill_to 取半径方向
func _radial(px: int, offs: PackedFloat32Array, cols: PackedColorArray) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = px
	t.height = px
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## 屏坐标 ↔ 本层局部坐标（Control 没有 to_local/to_global；本层铺满根、无缩放）
func _local(g: Vector2) -> Vector2:
	return g - global_position

func _glob(l: Vector2) -> Vector2:
	return l + global_position

## 落点＝经验条的填充右沿（每帧重算，多珠连飞时逐颗吃到最新的条头）
func _tip(fill: Control) -> Vector2:
	if fill == null or not is_instance_valid(fill):
		return _local(Vector2(960.0, 54.0))
	var r := fill.get_global_rect()
	var x := r.position.x + r.size.x
	var track := fill.get_parent() as Control
	if track != null and is_instance_valid(track):
		var tr := track.get_global_rect()
		x = clampf(x, tr.position.x + 26.0, tr.position.x + tr.size.x - 26.0)
	return _local(Vector2(x, r.position.y + r.size.y * 0.5))

## 放一颗珠：from 全局坐标；on_land 在到账那一刻回调（参数＝落点全局坐标）
const GROUND_Y := 790.0

func fly(from_global: Vector2, fill: Control, on_land: Callable, delay := 0.0, drop := 0.22) -> void:
	var a := _local(from_global)
	var g := Vector2(a.x, GROUND_Y)          # 地面线：珠子先掉到地上，再从地上飞进条
	# 拖尾（先建 → 画在珠下面）
	var line := Line2D.new()
	var wc := Curve.new()
	wc.add_point(Vector2(0.0, 0.02))
	wc.add_point(Vector2(0.45, 0.30))
	wc.add_point(Vector2(0.78, 0.78))
	wc.add_point(Vector2(1.0, 1.0))
	line.width_curve = wc
	line.width = 16.0
	var lg := Gradient.new()
	lg.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	lg.colors = PackedColorArray([Color(XP_DEEP.r, XP_DEEP.g, XP_DEEP.b, 0.0),
		Color(0.34, 0.50, 0.72, 0.16), Color(0.46, 0.64, 0.86, 0.34)])
	line.gradient = lg
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.add_point(a)
	add_child(line)
	# 珠身
	var orb := TextureRect.new()
	orb.texture = _orb_tex
	orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	orb.size = Vector2(ORB, ORB)
	orb.pivot_offset = orb.size * 0.5
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.position = a - orb.size * 0.5
	orb.scale = Vector2(0.25, 0.25)
	orb.modulate.a = 0.0
	add_child(orb)
	var glow := TextureRect.new()
	glow.texture = _dot
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(ORB * 1.9, ORB * 1.9)
	glow.position = -orb.size * 0.45
	glow.z_index = -1
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate = Color(0.72, 0.84, 1.0, 0.34)
	orb.add_child(glow)
	# 时序：出生回弹 → 悬停一拍 → 飞行
	var dur := clampf(a.distance_to(_tip(fill)) / FLY_REF, 0.30, 0.55)
	# 出生（缩放入场）与飞行同时起跑——不再串行，否则起跳前有一拍空等
	var tw_pop := orb.create_tween()
	if delay > 0.0:
		orb.visible = false
		tw_pop.tween_interval(delay)
		tw_pop.tween_callback(func() -> void: orb.visible = true)
	tw_pop.tween_property(orb, "modulate:a", 1.0, 0.06)
	tw_pop.parallel().tween_property(orb, "scale", Vector2.ONE, 0.13)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tw_fly := orb.create_tween()
	if delay > 0.0:
		tw_fly.tween_interval(delay)
	# ① 掉落到地面（纯下落，不弹）
	if drop > 0.0:
		tw_fly.tween_method(func(t: float) -> void:
			var p2 := a.lerp(g, t)
			orb.position = p2 - orb.size * 0.5
			line.add_point(p2)
		, 0.0, 1.0, drop).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw_fly.tween_interval(0.14)
	# ② 从地面飞进经验条
	tw_fly.tween_method(_step.bind(orb, line, g if drop > 0.0 else a, fill), 0.0, 1.0, dur)\
		.set_trans(Tween.TRANS_LINEAR)
	tw_fly.tween_callback(func() -> void: _arrive(orb, line, on_land))

func _step(t: float, orb: Control, line: Line2D, a: Vector2, fill: Control) -> void:
	var b := _tip(fill)
	var ctrl := a.lerp(b, 0.42) + Vector2(0.0, -150.0)   # 先上抛再扎向条
	var q := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
	orb.position = q - orb.size * 0.5
	# 按距离补点：离屏窗口帧率低时也保持笔锋连续（不补会成折线）
	var n := line.get_point_count()
	var last: Vector2 = line.get_point_position(n - 1) if n > 0 else a
	var seg := clampi(int(last.distance_to(q) / 7.0), 1, 16)
	for i in range(1, seg + 1):
		line.add_point(last.lerp(q, float(i) / float(seg)))
	while line.get_point_count() > TRAIL_MAX:
		line.remove_point(0)

func _arrive(orb: Control, line: Line2D, on_land: Callable) -> void:
	# 2026-11-15 用户令：珠到条头直接消失，只保留飞行过程和条上涨——不做缩小/淡出/
	# 墨溅/冲击环/+N。
	var at := orb.position + orb.size * 0.5
	orb.queue_free()
	line.queue_free()
	on_land.call(_glob(at))
