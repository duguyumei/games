## 战斗特效层（2026-11-06 用户令「先把直刺这一刀做完整闭环」）。
## 只做屏级绘制：出招笔锋／命中白闪／墨点迸溅／伤害数字。
## 设计要点：敌阵每次 changed 会整批重建，所以**特效不挂在敌卡上**——
## 命中瞬间把目标矩形快照下来，用屏幕坐标画在独立的 FX 层（z 85）。
## 全层 mouse_filter=IGNORE，绝不吃按钮点击。
extends Control

var _num_live: Dictionary = {}

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const FX := preload("res://qiforge/QiFxAtlas.gd")
const BLADE := preload("res://qiforge/QiBladeAtlas.gd")

const INK := Color(0.18, 0.14, 0.09)
const PAPER := Color(0.94, 0.91, 0.84)
const GLEAM := Color(0.98, 0.99, 1.0)
const INK_BLUE := Color(0.20, 0.33, 0.49)

var _dot: GradientTexture2D

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
	z_index = 85
	_dot = _radial(64,
		PackedFloat32Array([0.0, 0.42, 1.0]),
		PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)]))

func _local(g: Vector2) -> Vector2:
	return g - global_position

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

## ── 出招：一条笔锋从 from 冲到 to（0.09s），到点回调 ──────────────
## 双层线：外层墨（宽、半透明）＋内层高光（窄、近白）＝一笔带过还有刃光。
func thrust(from_g: Vector2, to_g: Vector2, on_hit: Callable) -> void:
	# 刺＝贴身的动作，不是飞行物。所以不画「从卡飞到敌人」的长线，
	# 只在**目标身上**留一道短促的刺痕＋命中闪，卡自己往前一送（出招动画已有）。
	# 时间轴：0.06s 出痕（从短到长）→ 命中 → 0.16s 收
	var a := _local(from_g)
	var b := _local(to_g)
	var d := a.distance_to(b)
	var dir := (b - a).normalized()
	var ang := dir.angle()
	var reach := minf(150.0, maxf(90.0, d * 0.34))     # 刺痕只覆盖最后一段
	var tip := b
	var tail := b - dir * reach
	var h := maxf(14.0, d * 0.042)
	# 墨脊
	var spine := _mk_line(2.5, Color(0.13, 0.11, 0.10, 0.55))
	spine.add_point(tail)
	spine.add_point(tip)
	spine.modulate.a = 0.0
	add_child(spine)
	# 刀光（以刺痕尾端为轴，向目标方向长出来）
	var blade := TextureRect.new()
	blade.texture = BLADE.cell(1)
	blade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blade.size = Vector2(reach, h)
	blade.pivot_offset = Vector2(0.0, h * 0.5)
	blade.position = tail - Vector2(0.0, h * 0.5)
	blade.rotation = ang
	blade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blade.modulate = Color(1, 1, 1, 1)
	blade.scale = Vector2(1.0, 1.0)
	add_child(blade)
	# 命中点的一小团白芒（戳中的“点”）
	var dot := TextureRect.new()
	dot.texture = _soft_dot()
	dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dot.size = Vector2(120.0, 120.0)
	dot.pivot_offset = dot.size * 0.5
	dot.position = tip - dot.size * 0.5
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.modulate = Color(1, 0.98, 0.92, 0.0)
	add_child(dot)
	# 2026-11-06 用户裁定：不要「生长段」——刺就该是一下子到位，长了反而钝。
	# 瞬间满幅 → 立刻命中 → 快速收（全片约 0.18s）
	blade.modulate.a = 0.0
	spine.modulate.a = 0.0
	var tw := blade.create_tween()
	tw.tween_property(blade, "modulate:a", 1.0, 0.015)
	tw.parallel().tween_property(spine, "modulate:a", 1.0, 0.015)
	tw.parallel().tween_property(dot, "modulate:a", 0.9, 0.02)
	tw.parallel().tween_property(dot, "scale", Vector2(1.4, 1.4), 0.16)
	tw.tween_callback(on_hit)
	tw.tween_property(blade, "modulate:a", 0.0, 0.13)
	tw.parallel().tween_property(spine, "modulate:a", 0.0, 0.13)
	tw.parallel().tween_property(dot, "modulate:a", 0.0, 0.13)
	tw.tween_callback(func() -> void:
		blade.queue_free()
		spine.queue_free()
		dot.queue_free())

## 命中白芒（运行期径向渐变，不是火焰贴图）
static var _dot_cache: Texture2D = null
static func _soft_dot() -> Texture2D:
	if _dot_cache != null:
		return _dot_cache
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.30), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_dot_cache = t
	return t

func _mk_line(w: float, col: Color) -> Line2D:
	var l := Line2D.new()
	l.width = w
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.02))      # 尾：细
	c.add_point(Vector2(0.45, 0.30))
	c.add_point(Vector2(0.85, 0.95))     # 身：厚
	c.add_point(Vector2(1.0, 0.10))      # 尖：收针
	l.width_curve = c
	l.default_color = col
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	return l

## ── 命中：白闪（矩形快照）＋墨点迸溅 ＋伤害数字 ──────────────────
func hit(at_g: Vector2, amount: int, rect := Rect2(), power := 0, idx := 0, uid := 0) -> void:
	if rect.size.x > 1.0 and rect.size.y > 1.0:
		_flash(rect)
	if power > 0:
		_burst(at_g)          # 爆点只给强力卡（2026-11-06 用户裁定：火光/爆炸属后期角色）
	_splash(at_g)
	if amount > 0:
		_number(at_g, amount, idx, uid)

## 命中爆点：图集第 5 格（白热星芒＋火星环），加法混合
func _burst(at_g: Vector2) -> void:
	var b := TextureRect.new()
	b.texture = FX.cell(5)
	b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b.size = Vector2(240.0, 240.0)
	b.position = _local(at_g) - b.size * 0.5
	b.pivot_offset = b.size * 0.5
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.modulate = Color(1, 1, 1, 0.0)
	b.z_index = 2
	add_child(b)
	var tw := b.create_tween()
	tw.tween_property(b, "modulate:a", 1.0, 0.03)
	tw.parallel().tween_property(b, "scale", Vector2(1.22, 1.22), 0.26)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "modulate:a", 0.0, 0.22)
	tw.tween_callback(b.queue_free)

func _flash(rect: Rect2) -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 1)
	sb.set_corner_radius_all(16)
	p.add_theme_stylebox_override("panel", sb)
	var sz := rect.size * 1.04
	p.position = _local(rect.get_center()) - sz * 0.5
	p.size = sz
	p.pivot_offset = sz * 0.5
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.modulate.a = 0.0
	add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 0.92, 0.03)
	tw.parallel().tween_property(p, "scale", Vector2(1.05, 1.05), 0.05)
	tw.tween_property(p, "modulate:a", 0.0, 0.17)
	tw.tween_callback(p.queue_free)

func _splash(at_g: Vector2) -> void:
	var pts := CPUParticles2D.new()
	pts.position = _local(at_g)
	pts.one_shot = true
	pts.amount = 9
	pts.lifetime = 0.38
	pts.explosiveness = 1.0
	pts.direction = Vector2(0, -1)
	pts.spread = 180.0
	pts.initial_velocity_min = 90.0
	pts.initial_velocity_max = 240.0
	pts.damping_min = 140.0
	pts.damping_max = 280.0
	pts.gravity = Vector2.ZERO
	pts.scale_amount_min = 0.14
	pts.scale_amount_max = 0.34
	pts.texture = _dot
	pts.color = INK
	pts.z_index = 1
	add_child(pts)
	pts.emitting = true
	var tw := pts.create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(pts.queue_free)

func _number(at_g: Vector2, amount: int, idx := 0, uid := 0) -> void:
	# 同一目标 0.22s 内的后续伤害累加到正在飘的数字上（连打时屏幕才不会被数字淹没）
	var now := Time.get_ticks_msec()
	if uid > 0 and _num_live.has(uid):
		var rec: Dictionary = _num_live[uid]
		var old: Label = rec.get("label")
		if is_instance_valid(old) and now - int(rec.get("t", 0)) < 220:
			rec["sum"] = int(rec.get("sum", 0)) + amount
			rec["t"] = now
			old.text = "-%d" % int(rec["sum"])
			var tp := old.create_tween()
			tp.tween_property(old, "scale", Vector2(1.24, 1.24), 0.05)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tp.tween_property(old, "scale", Vector2.ONE, 0.10)
			return
	var l := Label.new()
	l.text = "-%d" % amount
	QISTYLE.font(l, 38, true)
	l.add_theme_color_override("font_color", Color(0.88, 0.16, 0.10))
	l.add_theme_color_override("font_outline_color", Color(0.99, 0.96, 0.90, 0.95))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 多段时错开，避免叠成一坨
	var p := Vector2(at_g.x + 58.0 + float(idx % 3) * 34.0, at_g.y - 96.0 - float(idx) * 16.0) - global_position
	l.position = p
	l.pivot_offset = Vector2(16.0, 20.0)
	if uid > 0:
		_num_live[uid] = {"label": l, "sum": amount, "t": now}
	l.scale = Vector2(0.6, 0.6)
	l.modulate.a = 0.0
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.05)
	tw.parallel().tween_property(l, "scale", Vector2(1.18, 1.18), 0.09)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.10)
	tw.parallel().tween_property(l, "position:y", p.y - 26.0, 0.42)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.22)
	tw.tween_callback(l.queue_free)

## 清场（换屏/结算）
func clear() -> void:
	for c in get_children():
		c.queue_free()
