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

## ══ 语法轨 v7（2026-11-07 用户裁定）：一起出现 → 3D 椭圆绕圈 → 停 → 依次射 ═══
## 要点：① 剑是"突"一下一起出现，不分先后；② 绕圈走椭圆（俯视 3D 透视感），
## ③ 剑身始终指向敌人（不是向外张开）；④ 转完停一下（蓄势），再依次射出去。
const FORM := {
	"spawn": 0.16,          # 一起出现（弹出）
	"orbit_dur": 0.70,      # 绕圈时长（慢一点，看得清）
	"orbit_turns": 1.0,     # 转几圈
	"rx": 190.0,            # 椭圆长轴（横）
	"ry": 76.0,             # 椭圆短轴（纵）＝俯视角
	"hold": 0.20,           # 蓄势停顿
	"launch_gap": 0.11,     # 依次射出间隔
	"travel": 0.22,         # 单柄飞行时间
}

## 调试慢放倍数（QI_FXSLOW=4 → 全部时长×4；只影响表现时长，不动战斗节奏）
static func slow_k() -> float:
	var v := OS.get_environment("QI_FXSLOW")
	if v == "":
		return 1.0
	return clampf(float(v), 1.0, 12.0)

func strike(spec: Dictionary, events: Array, from_g: Vector2, on_beat: Callable) -> void:
	if OS.has_environment("QI_FX_LOG"):
		print("FX strike n=", events.size(), " t=", Time.get_ticks_msec())
	if events.is_empty():
		return
	var K := slow_k()
	var n: int = events.size()
	var pts := _strike_points(spec, events)
	var swords: Array = []
	var aims: Array = []
	# 阵心：血珠往场地里偏一点（血珠贴着屏幕左缘）
	var ctr: Vector2 = from_g + Vector2(300.0, -120.0)   # 阵心移到战场中段，阵才看得见
	var rx: float = FORM["rx"]
	var ry: float = FORM["ry"]
	# 阵环：一圈很淡的墨线（不给的话"绕圈"这条轨迹读不出来）
	var ring := Line2D.new()
	ring.width = 1.4
	ring.default_color = Color(0.12, 0.10, 0.08, 0.0)
	ring.z_index = 2
	for k in 49:
		var a0 := TAU * float(k) / 48.0
		ring.add_point(ctr + Vector2(cos(a0) * rx, sin(a0) * ry) - global_position)
	add_child(ring)
	var rt := ring.create_tween()
	rt.tween_property(ring, "default_color:a", 0.20, 0.16 * K)
	# ① 一起出现：全部同时弹出、同时亮起，没有先后
	for i in n:
		var sw := _small_sword()
		var th := TAU * float(i) / float(n) - PI * 0.5
		sw.position = ctr + Vector2(cos(th) * rx, sin(th) * ry)
		# 切线式：剑身沿圆周走（剑尖、剑柄各画一个圈），不是指向敌人也不是向外张开
		sw.rotation = th + PI * 0.5
		sw.scale = Vector2(0.25, 0.25)
		sw.modulate.a = 0.0
		add_child(sw)
		swords.push_back(sw)
		var t := sw.create_tween()
		t.set_parallel(true)
		t.tween_property(sw, "scale", Vector2.ONE, (float(FORM["spawn"]) * K))\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(sw, "modulate:a", 1.0, 0.10 * K)
	# ② 椭圆绕圈：角度转，位置沿椭圆走；剑尖朝向保持不变（始终指敌）
	var orbit_at: float = (float(FORM["spawn"]) * K) + 0.02 * K
	var turns: float = float(FORM["orbit_turns"]) * TAU
	var orbit := create_tween()
	orbit.tween_interval(orbit_at)
	orbit.tween_method(func(v: float) -> void:
		for i in n:
			var sw2 = swords[i]
			if not is_instance_valid(sw2):
				continue
			var th2 := TAU * float(i) / float(n) - PI * 0.5 + v
			sw2.position = ctr + Vector2(cos(th2) * rx, sin(th2) * ry)
			sw2.rotation = th2 + PI * 0.5
			# 俯视深度：sin>0 在近处（大、靠前），sin<0 在远处（小、靠后）
			var depth := (sin(th2) + 1.0) * 0.5
			var k2 := 0.72 + 0.52 * depth
			sw2.scale = Vector2(k2, k2)
			sw2.z_index = 3 + int(depth * 6.0)
			sw2.modulate.a = 0.72 + 0.28 * depth
	, 0.0, turns, (float(FORM["orbit_dur"]) * K))
	# ③ 蓄势 → ④ 依次射出
	var launch0: float = orbit_at + (float(FORM["orbit_dur"]) * K) + (float(FORM["hold"]) * K)
	for i in n:
		var ev: Dictionary = events[i]
		var tgt: Vector2 = pts[i]
		var sw3: Node2D = swords[i]
		var tw := create_tween()
		tw.tween_interval(launch0 + (float(FORM["launch_gap"]) * K) * float(i))
		tw.tween_callback(func() -> void:
			_launch(sw3, tgt, (float(FORM["travel"]) * K), ev, i, on_beat))
		if i == n - 1:
			var end_at: float = launch0 + (float(FORM["launch_gap"]) * K) * float(i) + 0.06
			var rtw := create_tween()
			rtw.tween_interval(end_at)
			rtw.tween_property(ring, "default_color:a", 0.0, 0.30)
			rtw.tween_callback(ring.queue_free)

## 单柄射出：转向前方（目标方向）→ 加速飞过去 → 命中消散
func _launch(sw: Node2D, tgt_g: Vector2, dur: float,
		ev: Dictionary, idx: int, on_beat: Callable) -> void:
	if not is_instance_valid(sw):
		return
	var from := sw.position
	var d := tgt_g - global_position - from
	if d.length() < 4.0:
		sw.queue_free()
		return
	var ang := d.angle()
	var tw := sw.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sw, "rotation", ang, 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sw, "position", _local(tgt_g), dur)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		_splat(tgt_g)
		if on_beat.is_valid():
			on_beat.call(ev, idx)
		if OS.has_environment("QI_FX_LOG"):
			print("FX sword idx=%d tgt=%s t=%d" % [idx, str(tgt_g.round()), Time.get_ticks_msec()])
		sw.queue_free())

## 一柄墨色小飞剑（剑身＋剑格＋剑柄＋剑首，全墨）
func _small_sword(w := 10.5, L := 74.0) -> Node2D:
	var node := Node2D.new()
	node.z_index = 4
	var ink := Color(0.13, 0.11, 0.09, 0.97)
	var blade := Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(0.0, -w * 0.50), Vector2(L * 0.68, -w * 0.30),
		Vector2(L, 0.0),
		Vector2(L * 0.68, w * 0.30), Vector2(0.0, w * 0.50)])
	blade.color = ink
	node.add_child(blade)
	var edge := Line2D.new()
	edge.width = 1.2
	edge.default_color = Color(0.62, 0.60, 0.56, 0.55)
	edge.add_point(Vector2(1.0, -w * 0.40))
	edge.add_point(Vector2(L * 0.92, -w * 0.06))
	node.add_child(edge)
	var guard := Line2D.new()
	guard.width = 2.6
	guard.default_color = ink
	guard.add_point(Vector2(-2.0, -w * 1.05))
	guard.add_point(Vector2(-2.0, w * 1.05))
	node.add_child(guard)
	var grip := Line2D.new()
	grip.width = 3.2
	grip.default_color = ink
	grip.add_point(Vector2(-3.0, 0.0))
	grip.add_point(Vector2(-15.0, 0.0))
	grip.begin_cap_mode = Line2D.LINE_CAP_ROUND
	node.add_child(grip)
	var pommel := Polygon2D.new()
	pommel.polygon = PackedVector2Array([
		Vector2(-15.0, -2.6), Vector2(-19.0, -1.6), Vector2(-19.0, 1.6), Vector2(-15.0, 2.6)])
	pommel.color = ink
	node.add_child(pommel)
	# 淡墨拖尾
	var tail := Line2D.new()
	tail.width = 2.2
	tail.default_color = Color(0.14, 0.12, 0.10, 0.26)
	tail.add_point(Vector2(-L * 0.84, 0.0))
	tail.add_point(Vector2(-L * 0.30, 0.0))
	node.add_child(tail)
	return node

## 击拍间隔（档案口径）：多段要读得清
func _gap_of(spec: Dictionary, n: int) -> float:
	return clampf(float(spec.get("gap_budget", 0.42)) / float(maxi(1, n)),
		float(spec.get("gap_min", 0.07)), float(spec.get("gap_max", 0.10)))

## 本轮总时长（剑阵口径：凝剑＋绕圈＋停顿＋依次射出＋飞行）
func strike_timing(spec: Dictionary, n: int) -> float:
	var K := slow_k()
	return (float(FORM["spawn"]) * K) + (float(FORM["orbit_dur"]) * K) \
		+ (float(FORM["hold"]) * K) + (float(FORM["launch_gap"]) * K) * float(maxi(0, n - 1)) \
		+ (float(FORM["travel"]) * K) + 0.30

## 命中墨点（箭消失时留的一小团，0.3s 收）
## ── 剑鞘制（2026-11-08 用户令）──
## ① 出鞘：剑从血珠里竖直抽出（剑尖朝上），在珠心上方“一片区域”里各就各位（5s）
## ② 蓄力：短暂停顿
## ③ 飞行：转向后方，从下方划弧打进去（5s）
## ── 三种剑（2026-11-08 用户定稿：重剑/长剑/短剑，九宫格取 3/2/2，重剑柄压 0.65）──
const SWORD_LEN := {"heavy": 140.0, "long": 150.0, "short": 100.0}
static var _sword_tex_cache: Dictionary = {}

func _sword_tex(kind: String) -> Texture2D:
	if _sword_tex_cache.has(kind):
		return _sword_tex_cache[kind] as Texture2D
	var tex := ResourceLoader.load("res://qiforge/assets/fx/sword_%s.png" % kind) as Texture2D
	_sword_tex_cache[kind] = tex
	return tex

## 一把贴图剑：节点原点＝剑首（左端），剑身沿 +X
func _sword_node(kind: String) -> Node2D:
	var tex := _sword_tex(kind)
	if tex == null:
		return _small_sword(6.0, float(SWORD_LEN.get(kind, 100.0)))
	var node := Node2D.new()
	node.z_index = 7
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.offset = Vector2(0.0, -float(tex.get_height()) * 0.5)
	var L: float = float(SWORD_LEN.get(kind, 100.0))
	var k: float = L / maxf(1.0, float(tex.get_width()))
	sp.scale = Vector2(k, k)
	node.add_child(sp)
	return node

const SCA := {
	"draw": 0.25,     # 出鞘时长（秒）
	"fly": 0.50,      # 飞行时长（秒）
	"hold": 0.02,     # 出鞘完成后的蓄力停顿
	"turn": 0.12,     # 转向时长
	"stagger": 0.20,  # 逐把错开（秒）：≥刀长才不显得叠在一起
	"rise": 330.0,    # 出鞘点高出珠心
	"rx": 165.0,      # 出鞘区域横向半径
	"ry": 95.0,       # 出鞘区域纵向半径
	"grow": 1.0,      # 贴图剑按 SWORD_LEN 定长，不再二次放大
	"sw_w": 6.0,      # 剑身宽（细）
	"sw_l": 95.0,     # 剑身长
}

func scabbard_timing(_spec: Dictionary, _n: int) -> float:
	var K := slow_k()
	var speed0 := 1400.0 / K
	var st: float = (float(SWORD_LEN.get("short", 100.0)) + 5.0) / speed0
	var move_t: float = 1389.0 / speed0
	return (float(SCA["draw"]) + float(SCA["hold"]) + float(SCA["turn"])) * K \
		+ st * float(maxi(0, _n - 1)) + move_t + 0.35

func scabbard_strike(spec: Dictionary, events: Array, orb_g: Vector2, on_beat: Callable, alive_check := Callable()) -> void:
	if OS.has_environment("QI_FX_LOG"):
		print("FX scabbard n=", events.size())
	if events.is_empty():
		return
	var K := slow_k()
	var n: int = events.size()
	var base := _local(orb_g)
	var draw_d: float = float(SCA["draw"]) * K
	var hold_d: float = float(SCA["hold"]) * K
	var turn_d: float = float(SCA["turn"]) * K
	var speed0 := 1400.0 / K                 # 慢放时飞行也一起放慢
	var stagger_d: float = 0.0
	var grow: float = float(SCA["grow"])
	var L: float = float(SWORD_LEN.get("short", 100.0))
	stagger_d = (L + 5.0) / speed0           # X 间隔＝刀长 + 5px（2026-11-08 用户令）
	var tops: Array = []
	var tip_x: Array = []
	var tails: Array = []
	var tex_s := _sword_tex("short")
	var h_vis := 20.0
	if tex_s != null:
		h_vis = (float(tex_s.get_height()) / float(tex_s.get_width())) * L
	var step := 30.0          # 2026-11-08 用户令：Y 间隔固定 30px
	for i in n:
		var ev_a: Dictionary = events[i]
		var r_a: Rect2 = ev_a.get("rect", Rect2())
		if r_a.size.x < 2.0:
			r_a = Rect2(Vector2(880.0, 300.0), Vector2(190.0, 250.0))
		var tail_shot: bool = (ev_a.get("death", false) == true) \
			or int(ev_a.get("uid", -1)) < 0 or r_a.size.x < 2.0
		tails.append(tail_shot)
		var ys := r_a.position.y + r_a.size.y * 0.5 + (1.0 if i % 2 == 0 else -1.0) * step * 0.5
		tops.append(Vector2(base.x, ys))
		tip_x.append(1720.0 if tail_shot else r_a.position.x + 18.0)
	var swords: Array = []
	for i in n:
		var sw := _sword_node("short")
		sw.z_index = 7
		sw.rotation = PI * 0.5
		sw.position = base - Vector2(0.0, 18.0)
		sw.modulate.a = 0.0
		sw.scale = Vector2.ONE * 0.55
		add_child(sw)
		swords.append(sw)
		var peak: Vector2 = tops[i]
		var t := sw.create_tween()
		t.set_parallel(true)
		t.tween_property(sw, "position", peak, draw_d)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(sw, "modulate:a", 1.0, 0.25)
		t.tween_property(sw, "scale", Vector2.ONE * grow, draw_d)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		# 每把刀按【自己的】到位时刻淡出（2026-11-08 用户报：先到的刀停在右边等后到的）
		# 原来统一时钟到点才一起淡出 → 先到的刀看起来"卡住不动"。
		var want_i: float = float(tip_x[i]) - L
		var dist_i: float = maxf(0.0, want_i - (tops[i] as Vector2).x)
		var arrive_i: float = draw_d + hold_d + stagger_d * float(i) + turn_d + dist_i / speed0
		var wt: Tween = sw.create_tween()
		wt.tween_interval(arrive_i + 0.01)
		wt.tween_callback(sw.queue_free)   # 到位即消失，不做淡化（2026-11-08 用户令）
	# ── 统一时钟：一个 tween 驱动全部飞行，间距＝起射间隔×速度，恒定 ──
	var speed := speed0
	var max_move := 1.0
	for i in n:
		max_move = maxf(max_move, absf(float(tip_x[i]) - base.x - L))
	var total_t := draw_d + hold_d + stagger_d * float(n - 1) + turn_d + max_move / speed + 0.02
	var fired: Dictionary = {}
	var arrived: Dictionary = {}   # 已到达待落账的拍（落账按发射序保序——近敌先扎不改账序）
	var seq := {"next": 0}         # 引用容器：GDScript lambda 捕获 int 是值拷贝不跨帧持久
	var clock := create_tween()
	clock.tween_method(func(t: float) -> void:
		for i in n:
			var sw2 = swords[i]
			if not is_instance_valid(sw2):
				continue
			var t0: float = draw_d + hold_d + stagger_d * float(i)
			if t <= t0:
				continue
			var lt: float = t - t0
			sw2.rotation = lerpf(PI * 0.5, 0.0, clampf(lt / turn_d, 0.0, 1.0))
			if lt <= turn_d:
				continue
			var move: float = (lt - turn_d) * speed
			var peak2: Vector2 = tops[i]
			var want: float = float(tip_x[i]) - L
			var x := minf(peak2.x + move, want)
			sw2.position = Vector2(x, peak2.y)
			if x >= want - 0.5 and not fired.has(i):
				fired[i] = true
				_on_sword_arrive(sw2, i, tip_x, tops, tails)   # 视觉即时（近敌先扎）
				arrived[i] = true
				while arrived.has(seq["next"]):              # 落账按发射序保序补发（2026-11-08
					var _ev0: Dictionary = events[int(seq["next"])]  # 日志定谳：到达序≠发射序致队列错位）
					if on_beat.is_valid():
						on_beat.call(_ev0, int(seq["next"]))
					seq["next"] = int(seq["next"]) + 1
	, 0.0, total_t, total_t)
	clock.tween_callback(func() -> void:
		for sw3 in swords:
			if is_instance_valid(sw3) and sw3.modulate.a > 0.01:
				var ft: Tween = sw3.create_tween()
				ft.tween_property(sw3, "modulate:a", 0.0, 0.12)
				ft.tween_callback(sw3.queue_free))

## 单把到位：命中刀溅墨；甩尾刀淡出（视觉层——落账回调已上移至 clock 保序门）
func _on_sword_arrive(sw: Node2D, i: int, tip_x: Array,
		tops: Array, tails: Array) -> void:
	if (tails[i] as bool):
		sw.queue_free()   # 甩尾刀到位即消失（不做淡化）
	else:
		_splat(Vector2(float(tip_x[i]) + 10.0, (tops[i] as Vector2).y))
		sw.queue_free()

func _splat(at_g: Vector2) -> void:
	var pts := CPUParticles2D.new()
	pts.position = _local(at_g)
	pts.one_shot = true
	pts.amount = 7
	pts.lifetime = 0.26
	pts.explosiveness = 1.0
	pts.direction = Vector2.DOWN
	pts.spread = 180.0
	pts.initial_velocity_min = 60.0
	pts.initial_velocity_max = 170.0
	pts.damping_min = 220.0
	pts.damping_max = 380.0
	pts.gravity = Vector2.ZERO
	pts.scale_amount_min = 0.035
	pts.scale_amount_max = 0.075
	pts.texture = _dot
	pts.color = Color(0.10, 0.09, 0.08, 0.9)
	pts.z_index = 3
	add_child(pts)
	pts.emitting = true
	var tw := pts.create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(pts.queue_free)

## 落点表（账本→屏幕点）：同敌连击按 repeat_jitter 绕环散开
func _strike_points(spec: Dictionary, events: Array) -> Array:
	var out: Array = []
	var seen := {}
	var jr := float(spec.get("repeat_jitter", 9.0))
	for i in events.size():
		var ev: Dictionary = events[i]
		var r: Rect2 = ev.get("rect", Rect2())
		var p: Vector2 = r.get_center() if r.size.x > 1.0 else Vector2(960.0, 430.0)
		var uid := int(ev.get("uid", -1))
		var k := int(seen.get(uid, 0))
		seen[uid] = k + 1
		if k > 0:
			var a := 2.39 * float(k)
			p += Vector2(cos(a), sin(a)) * jr * (1.0 + 0.35 * float(k - 1))
		out.push_back(p)
	return out

## ── 伤害数字：每段一个，不合并；按击序错开 ──
func number_stack(at_g: Vector2, amount: int, idx: int, crit := false) -> void:
	var l := Label.new()
	l.text = "-%d" % amount
	# 暴击更醒目（2026-11-08 用户令）：字号更大、颜色更深、描边更粗、起始缩放更小（弹得更狠）
	QISTYLE.font(l, 58 if crit else 34, true)
	l.add_theme_color_override("font_color",
		Color(0.62, 0.04, 0.02) if crit else Color(0.78, 0.20, 0.12))
	l.add_theme_color_override("font_outline_color",
		Color(1.0, 0.86, 0.42, 1.0) if crit else Color(0.99, 0.96, 0.90, 0.95))
	l.add_theme_constant_override("outline_size", 6 if crit else 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side := 1.0 if idx % 2 == 0 else -1.0
	var p := _local(at_g) + Vector2(24.0 * side, -18.0 - float(idx) * 30.0)
	l.position = p
	l.pivot_offset = Vector2(18.0, 22.0)
	l.scale = Vector2(0.35, 0.35) if crit else Vector2(0.55, 0.55)
	l.modulate.a = 0.0
	add_child(l)
	# 寿命 0.20s（2026-11-08 用户令）：单条 tween_method 精确控时
	var tw := l.create_tween()
	tw.tween_method(func(t: float) -> void:
		var a := 1.0
		if t < 0.10:
			a = t / 0.10
		elif t > 0.72:
			a = maxf(0.0, (1.0 - t) / 0.28)
		l.modulate.a = a
		var s := 0.55 + 0.57 * minf(1.0, t / 0.25)
		l.scale = Vector2(s, s)
		l.position = p + Vector2(0.0, -30.0 * t)
	, 0.0, 1.0, 0.20)
	tw.tween_callback(l.queue_free)

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
		# 注意：不能写成 var old: Label = rec["label"]——上一轮已被 clear()/收尾释放的实例
		# 赋给有类型的变量会直接抛「invalid previously freed instance」（2026-11-07 实测）。
		var old = rec.get("label")
		if is_instance_valid(old) and now - int(rec.get("t", 0)) < 220:
			rec["sum"] = int(rec.get("sum", 0)) + amount
			rec["t"] = now
			old.text = "-%d" % int(rec["sum"])
			var tp: Tween = old.create_tween()
			tp.tween_property(old, "scale", Vector2(1.24, 1.24), 0.05)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tp.tween_property(old, "scale", Vector2.ONE, 0.10)
			return
		_num_live.erase(uid)      # 陈旧登记：就地清掉，别留给下一条
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
