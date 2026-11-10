## 经验珠特效层（2026-11-05 经验美术轮，用户令「金色」）。
## 五段链路（VC 掉落物制）：①出生回弹 ②贝塞尔飞行＋笔锋拖尾 ③到账墨溅＋「+N」浮字
## ④条闪／满级：条冲满→金闪→归位→光环＋等级弹出 ⑤珠身＝xp_orb.png（同族金珠）。
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

var _dot: GradientTexture2D        # 软圆点（墨溅/光晕）
var _ring: GradientTexture2D       # 光环
var _band: GradientTexture2D       # 横向扫光
var _orb_tex: Texture2D
var _float_lbl: Label = null       # 同一波只飘一个「+N」（连杀时逐颗累加，不糊成一堆）
var _float_total := 0

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
	_ring = _radial(128,
		PackedFloat32Array([0.0, 0.54, 0.66, 0.76, 0.90, 1.0]),
		PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.95),
			Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.10), Color(1, 1, 1, 0)]))
	_band = _linear(256, 64,
		PackedFloat32Array([0.0, 0.42, 0.58, 1.0]),
		PackedColorArray([Color(1, 0.94, 0.78, 0), Color(1, 0.94, 0.78, 0.55),
			Color(1, 0.94, 0.78, 0.55), Color(1, 0.94, 0.78, 0)]))
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

func _linear(w: int, h: int, offs: PackedFloat32Array, cols: PackedColorArray) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = w
	t.height = h
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.0, 0.5)
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
	var at := orb.position + orb.size * 0.5
	var tw := orb.create_tween()
	tw.tween_property(orb, "scale", Vector2(0.25, 0.25), 0.12)
	tw.parallel().tween_property(orb, "modulate:a", 0.0, 0.12)
	tw.tween_callback(orb.queue_free)
	var twl := line.create_tween()
	twl.tween_property(line, "modulate:a", 0.0, 0.10)
	twl.tween_callback(line.queue_free)
	on_land.call(_glob(at))

## 到账爆点：墨溅粒子＋冲击环＋「+N」浮字
func land(at_global: Vector2, amount: int) -> void:
	var p := _local(at_global)
	var pts := CPUParticles2D.new()
	pts.position = p
	pts.one_shot = true
	pts.amount = 13
	pts.lifetime = 0.42
	pts.explosiveness = 1.0
	pts.direction = Vector2(0, -1)
	pts.spread = 180.0
	pts.initial_velocity_min = 70.0
	pts.initial_velocity_max = 210.0
	pts.damping_min = 120.0
	pts.damping_max = 240.0
	pts.gravity = Vector2.ZERO
	pts.scale_amount_min = 0.18
	pts.scale_amount_max = 0.42
	pts.texture = _dot
	pts.color = XP
	pts.z_index = 1
	add_child(pts)
	pts.emitting = true
	var twn := pts.create_tween()
	twn.tween_interval(0.9)
	twn.tween_callback(pts.queue_free)
	_ring_at(p, 26.0, 78.0, 0.28, XP)
	if amount > 0:
		_float_text(p + Vector2(10.0, 34.0), amount)

func _ring_at(p: Vector2, from: float, to: float, dur: float, tint := XP) -> void:
	var r := TextureRect.new()
	r.texture = _ring
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size = Vector2(from, from)
	r.position = p - r.size * 0.5
	r.pivot_offset = r.size * 0.5
	r.modulate = Color(tint.r, tint.g, tint.b, 0.9)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var k := to / maxf(1.0, from)
	var tw := r.create_tween()
	tw.tween_property(r, "scale", Vector2(k, k), dur)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(r, "modulate:a", 0.0, dur)
	tw.tween_callback(r.queue_free)

func _float_text(p: Vector2, amount: int) -> void:
	if _float_lbl != null and is_instance_valid(_float_lbl):
		_float_total += amount
		_float_lbl.text = "+%d" % _float_total
		_float_lbl.pivot_offset = _float_lbl.size * 0.5
		var k := _float_lbl.create_tween()
		k.tween_property(_float_lbl, "scale", Vector2(1.16, 1.16), 0.06)
		k.tween_property(_float_lbl, "scale", Vector2.ONE, 0.12)
		return
	_float_total = amount
	var l := Label.new()
	l.text = "+%d" % _float_total
	QISTYLE.font(l, 26, true)
	l.add_theme_color_override("font_color", Color(0.31, 0.49, 0.73))
	l.add_theme_color_override("font_outline_color", Color(0.93, 0.90, 0.82, 0.95))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = p
	l.modulate.a = 0.0
	add_child(l)
	_float_lbl = l
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(l, "position:y", p.y - 40.0, 0.52)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		if _float_lbl == l:
			_float_lbl = null
		l.queue_free())

## 清场（败北/换屏）：珠、拖尾、粒子全撤
func clear() -> void:
	for c in get_children():
		c.queue_free()
