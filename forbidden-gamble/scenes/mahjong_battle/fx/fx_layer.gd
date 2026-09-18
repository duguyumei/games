class_name MJBFxLayer
extends Control

## 实时动画与特效层（2026-09-17 用户令：摸牌/打出/吃碰杠/运行武学/心法/攻击/防御全事件
## 实时演出）。占位 VFX＝代码绘制（零商业资产提取，正式美术后补）。
## 架构＝fire-and-forget：根协调器在引擎事件时点捕获源矩形（旧渲染控件），下一次渲染后
## 喂本层 API 补飞（幽灵牌/飘字/光环/光束/闪现/脉冲）——与引擎驱动完全并行，零阻塞零回灌，
## 演出不进核心（《我地麻》研究结论：演出分离轴，规则内核纯逻辑可测）。


# 基准时长（2026-09-17 校准——我地麻 Il2Cpp dump 采样：牌移动 0.1–0.5s、特效/停留
# 0.5–1.4s、等待 0.7–0.9s。原则＝飞行保持利落，读牌时间交给拍间隙与延迟）。
const FLY_DUR := 0.45
const FLOAT_DUR := 1.0
const RING_DUR := 0.5
const BEAM_DUR := 0.3
const FLASH_DUR := 0.32

## 演出速率（预览/自动驾驶调大快进；时长与延迟同除）。排空判定＝busy()（层上还有在播节点）。
var speed := 1.0
## 飘字字体（根协调器注入：霞鹜文楷 Medium——武侠字体质感；null＝默认字体）。
var float_font: Font = null

var _board: Control          # 屏震目标（主棋盘容器——根协调器注入）
var _dot_tex: ImageTexture    # 程序粒子贴图（径向软光点，零外部素材）
var _streak_tex: ImageTexture  # 「闪」光刃贴图（程序生成）


func bind_board(board: Control) -> void:
	_board = board


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _d(t: float) -> float:
	return t / maxf(speed, 0.01)


func busy() -> bool:
	return get_child_count() > 0


## 幽灵牌飞行（摸牌/打出/吃碰杠/落河共用）：tile 空或 back＝背牌；land＝落点控件（落地白闪）。
func fly(tile: MJTile, back: bool, from: Rect2, to: Rect2, delay := 0.0, land: Control = null) -> void:
	if from.size.x < 1.0 or to.size.x < 1.0:
		return
	var w := maxi(14, int(round(to.size.x)))
	var h := maxi(18, int(round(to.size.y)))
	var node: Control = MJBTileFace.make_back(w, h) if (back or tile == null) else MJBTileFace.make_tile(tile, w, h)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	var start_scale := Vector2(clampf(from.size.x / float(w), 0.5, 2.2),
		clampf(from.size.y / float(h), 0.5, 2.2))
	node.scale = start_scale
	node.global_position = from.get_center() - Vector2(w, h) * 0.5 * start_scale
	node.rotation = fmod(delay * 37.0, 0.24) - 0.12  # 确定性微倾角（零随机源）
	var tw := create_tween()
	tw.bind_node(node)
	tw.tween_interval(_d(delay))
	tw.set_parallel(true)
	tw.tween_property(node, "global_position", to.get_center() - Vector2(w, h) * 0.5, _d(FLY_DUR)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, _d(FLY_DUR)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", 0.0, _d(FLY_DUR)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_free_with_land.bind(node, land))  # land 可能先被释放：参数走 Variant 免转换


## 飘字（伤害数/招架名/破绽/护体等）：升起＋淡入淡出。
func float_text(text: String, at: Vector2, color: Color, font_size := 20, delay := 0.0, rise := 30.0) -> void:
	var label := MJFxNodes.make_float(text, at, color, font_size)
	if float_font != null:
		label.add_theme_font_override("font", float_font)
	add_child(label)
	label.modulate.a = 0.0
	var tw := create_tween()
	tw.bind_node(label)
	tw.tween_interval(_d(delay))
	tw.tween_property(label, "modulate:a", 1.0, _d(0.1))
	tw.parallel().tween_property(label, "position:y", label.position.y - _d(rise), _d(FLOAT_DUR)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(_d(0.4))
	tw.tween_property(label, "modulate:a", 0.0, _d(0.3))
	tw.chain().tween_callback(label.queue_free)


## 扩散光环（打点/招架成组/心法生效）。
func ring(at: Vector2, color: Color, max_r := 46.0, delay := 0.0) -> void:
	var node := MJFxNodes.make_ring(at, max_r, color)
	add_child(node)
	var tw := create_tween()
	tw.bind_node(node)
	tw.tween_interval(_d(delay))
	tw.tween_method(_set_ring_progress.bind(node), 0.0, 1.0, _d(RING_DUR)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(node.queue_free)


## 攻击光束：攻击方→受击方一条推进亮线（伤害读数前的先手视觉）。
func beam(from: Vector2, to: Vector2, color: Color, delay := 0.0) -> void:
	var node := MJFxNodes.make_beam(from, to, color)
	add_child(node)
	var tw := create_tween()
	tw.bind_node(node)
	tw.tween_interval(_d(delay))
	tw.tween_method(_set_beam_progress.bind(node), 0.0, 1.0, _d(BEAM_DUR)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(node.queue_free)


## 区域闪现（护体激活等面板级强调）。
func flash_rect(rect: Rect2, color: Color, delay := 0.0) -> void:
	if rect.size.x < 1.0:
		return
	var node := ColorRect.new()
	node.color = Color(color.r, color.g, color.b, 0.32)
	node.global_position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.material = MJFxNodes.additive_mat()
	add_child(node)
	var tw := create_tween()
	tw.bind_node(node)
	tw.tween_interval(_d(delay))
	tw.tween_property(node, "color:a", 0.0, _d(FLASH_DUR))
	tw.chain().tween_callback(node.queue_free)


## 控件色彩抖一下（受击红闪/心法金闪）。
func flicker(widget: Control, color: Color, delay := 0.0) -> void:
	if not is_instance_valid(widget):
		return
	var tw := create_tween()
	tw.bind_node(widget)
	tw.tween_interval(_d(delay))
	tw.tween_property(widget, "modulate", color, _d(0.07))
	tw.tween_property(widget, "modulate", Color.WHITE, _d(0.25))


## 运行态微脉（护体生效/重击在途的常亮呼吸）——重复调用不叠补间；stop_pulse 停。
func pulse_loop(widget: Control) -> void:
	if not is_instance_valid(widget) or widget.has_meta("fx_pulse_tween"):
		return
	var tw := create_tween().set_loops()
	tw.bind_node(widget)
	tw.tween_property(widget, "modulate", Color(1.4, 1.28, 0.9), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(widget, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
	widget.set_meta("fx_pulse_tween", tw)


func stop_pulse(widget: Control) -> void:
	if not is_instance_valid(widget) or not widget.has_meta("fx_pulse_tween"):
		return
	var tw: Tween = widget.get_meta("fx_pulse_tween")
	if tw != null:
		tw.kill()
	widget.remove_meta("fx_pulse_tween")


# ———— 打击感三件套（2026-09-17 用户令：屏震/打击停顿/程序粒子——全代码零素材） ————

## 屏震（棋盘级）：平移主棋盘四边偏移（不碰容器布局），4 步衰减抖动后归位。
func shake(strength := 6.0, delay := 0.0) -> void:
	if _board == null or not is_instance_valid(_board):
		return
	var bl := _board.offset_left
	var br := _board.offset_right
	var bt := _board.offset_top
	var bb := _board.offset_bottom
	var tw := create_tween()
	tw.bind_node(_board)
	tw.tween_interval(_d(delay))
	for i in range(4):
		var k := strength * (1.0 - float(i) / 4.0)
		var dx := randf_range(-k, k)
		var dy := randf_range(-k * 0.6, k * 0.6)
		tw.tween_property(_board, "offset_left", bl + dx, _d(0.03))
		tw.parallel().tween_property(_board, "offset_right", br + dx, _d(0.03))
		tw.parallel().tween_property(_board, "offset_top", bt + dy, _d(0.03))
		tw.parallel().tween_property(_board, "offset_bottom", bb + dy, _d(0.03))
	tw.tween_property(_board, "offset_left", bl, _d(0.045))
	tw.parallel().tween_property(_board, "offset_right", br, _d(0.045))
	tw.parallel().tween_property(_board, "offset_top", bt, _d(0.045))
	tw.parallel().tween_property(_board, "offset_bottom", bb, _d(0.045))


## 打击停顿：一枚短命占位节点让 busy() 为真——炉石式泵被扣住一拍（世界停一瞬再续）。
func hitstop(delay := 0.0, dur := 0.09) -> void:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	var tw := create_tween()
	tw.bind_node(node)
	tw.tween_interval(_d(delay) + _d(dur))
	tw.tween_callback(node.queue_free)


## 真气火花（程序粒子：径向软光点＋加法混合；贴图代码生成，零外部素材）。
func burst(at: Vector2, color: Color, count := 14, velocity := 220.0, delay := 0.0) -> void:
	var s := maxf(speed, 0.01)
	var p := CPUParticles2D.new()
	p.position = at
	p.texture = dot_texture()
	p.material = MJFxNodes.additive_mat()
	p.one_shot = true
	p.emitting = false
	p.amount = count
	p.lifetime = _d(0.55)
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = velocity * 0.35 / s
	p.initial_velocity_max = velocity / s
	p.gravity = Vector2(0, 260.0 / s)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	add_child(p)
	var tw := create_tween()
	tw.bind_node(p)
	tw.tween_interval(_d(delay))
	tw.tween_callback(func() -> void: p.emitting = true)
	tw.tween_interval(_d(0.55) + _d(0.12))
	tw.tween_callback(p.queue_free)


# ———— 武侠「闪」（2026-09-17 用户裁定：非小丑牌抖摆——斜向光刃扫过＋提亮一瞬） ————

## 武学发动/心法生效的触发演出：一道斜光刃扫过控件、控件提亮、少量真气火花。
## 色彩＝内容接线（technique/xinfa.vfx_color）——每门功法自己的色系。
func gleam(widget: Control, color: Color, delay := 0.0) -> void:
	if not is_instance_valid(widget):
		return
	var rect := widget.get_global_rect()
	if rect.size.x < 1.0:
		return
	flicker(widget, Color(1.5, 1.45, 1.25), delay)
	burst(rect.get_center(), color, 6, 90.0, delay + 0.05)
	var streak := TextureRect.new()
	streak.texture = streak_texture()
	streak.material = MJFxNodes.additive_mat()
	var h := maxf(rect.size.y * 1.7, 60.0)
	streak.size = Vector2(h * 0.26, h)
	streak.rotation = -0.32
	streak.modulate = Color(color.r, color.g, color.b, 0.0)
	streak.position = Vector2(rect.position.x - streak.size.x,
		rect.get_center().y - streak.size.y * 0.5)
	streak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(streak)
	var tw := create_tween()
	tw.bind_node(streak)
	tw.tween_interval(_d(delay))
	tw.set_parallel(true)
	tw.tween_property(streak, "modulate:a", 0.9, _d(0.07))
	tw.tween_property(streak, "position:x", rect.end.x + streak.size.x, _d(0.3)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_property(streak, "modulate:a", 0.0, _d(0.12))
	tw.chain().tween_callback(streak.queue_free)


func dot_texture() -> Texture2D:
	if _dot_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in range(32):
			for x in range(32):
				var dist := Vector2(x - 15.5, y - 15.5).length() / 16.0
				var a := clampf(1.0 - dist, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_dot_tex = ImageTexture.create_from_image(img)
	return _dot_tex


# 光刃贴图：横向亮心纵向软边（白底——modulate 染内容色）。
func streak_texture() -> Texture2D:
	if _streak_tex == null:
		var w := 56
		var h := 256
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in range(h):
			for x in range(w):
				var ax := absf(x - w * 0.5) / (w * 0.5)
				var ay := absf(y - h * 0.5) / (h * 0.5)
				var a := clampf(1.0 - ax, 0.0, 1.0) * clampf(1.0 - ay * ay, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, pow(a, 1.6)))
		_streak_tex = ImageTexture.create_from_image(img)
	return _streak_tex


func _set_ring_progress(v: float, node: MJFxNodes.Ring) -> void:
	node.progress = v
	node.queue_redraw()


func _set_beam_progress(v: float, node: MJFxNodes.Beam) -> void:
	node.progress = v
	node.queue_redraw()


func _free_with_land(node: Control, land) -> void:
	if is_instance_valid(land):  # 落点控件可能已随整面重绘释放
		_land_pulse(land as Control)
	node.queue_free()


## 落点白闪：飞行牌落到真实控件上的一瞬提亮。
func _land_pulse(land: Control) -> void:
	if not is_instance_valid(land):
		return
	var tw := create_tween()
	tw.bind_node(land)
	tw.tween_property(land, "modulate", Color(1.7, 1.6, 1.25), 0.06)
	tw.tween_property(land, "modulate", Color.WHITE, 0.2)
