## 卡词条浮窗组件（2026-11-10 立件，1:1 复刻原版 KeywordTooltip 制——ISIL 实证住
## design-docs/references/吸血鬼爬行者_浮窗系统逆向_v0.1.md）。
## 结构对齐：**浮窗组件挂卡节点下、与卡同生共死**（原版 KeywordTooltip＝卡视图
## 字段持有的子组件；卡销毁组件随销毁，孤儿在结构上不存在——无全局层、无按宿主
## 字典、销毁零善后）。
## API 对齐原版：set_active（=SetActive）/refresh（=GetCardTooltips 组装，kw×词条库，
## 无词条不显示——原版无「兜底全文」，卡面 desc 承载全文）/check_screen_pos
## （=CheckTooltipScreenPos 选边贴边翻面）/is_active/pointer_over。
## top_level=true：渲染与定位用全局坐标、不继承卡的扇形旋转/弹起缩放（斜卡梯度
## 按 tilt_fn 数据计算摞列位移——原版 SetPivot 制同构）。z=96 盖过弹窗（95）。
extends Control

const QIF_FONTS = preload("res://qiforge/QiFontBank.gd")
const VC := preload("res://qiforge/QiVcData.gd")
const TIP_TEX: Texture2D = preload("res://qiforge/assets/ui/tip_frame.png")

const PATCH := 14                        # 九宫格边距（贴图 64×64）
const PAD_L := 16.0
const PAD_T := 10.0
const PAD_R := 16.0
const PAD_B := 12.0
const MAX_TEXT_W := 352.0                # 正文最宽，超了才换行
const MIN_BODY_W := 88.0                 # 极短提示的地板宽
const ROW_SEP := 5
const HOST_GAP := 2.0                    # 卡与浮窗的水平间距（贴住卡，原版就是几乎挨着）
const STACK_GAP := 10.0                  # 块与块的竖直间距
const SCREEN_M := 8.0
const TITLE_GOLD := Color(0.937, 0.784, 0.318)
const BODY_CREAM := Color(1.0, 0.965, 0.886)
static var _bb := RegEx.create_from_string("\\[[^\\]]*\\]")

var _host: Control = null
var _anchor_fn: Callable = Callable()    # 宿主矩形（焦点态卡面比壳大且上浮——锚卡面）
var _corners_fn: Callable = Callable()   # 卡面四角（选边顶角/斜列用）
var _tilt_fn: Callable = Callable()      # 卡当前倾角
var _avoid: Array = []                   # 额外禁区（气珠/血心——盖住就看不见的 HUD，×4 权重）
var _panels: Array = []                  # 词条块（一词条一块）
var _active := false
var _sized := false                      # 量高完成（一帧后 VBox 有真行高）

func setup(host: Control, opts := {}) -> void:
	_host = host
	_anchor_fn = opts.get("anchor_fn", Callable())
	_corners_fn = opts.get("corners_fn", Callable())
	_tilt_fn = opts.get("tilt_fn", Callable())
	_avoid = opts.get("avoid", [])
	top_level = true
	z_index = 96
	z_as_relative = false   # 绝对 z 制：全局 96 盖过弹窗（95）；模态路径全断焦故无更高冲突
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if get_parent() != host:
		host.add_child(self)   # 池化复用防重挂（2026-11-12 持久卡：setup 每次换面都会再跑）

## 组装（GetCardTooltips 同构）：kw × KEYWORDS 词条库；无词条＝false 不显示
func refresh(def: Dictionary) -> bool:
	for p in _panels:
		if is_instance_valid(p):
			p.queue_free()
	_panels = []
	for kwd in def.get("kw", []):
		if VC.KEYWORDS.has(kwd):
			_build_block(String(VC.KEYWORDS[kwd]["name"]), String(VC.KEYWORDS[kwd]["desc"]))
	if _panels.is_empty():
		set_active(false)
		return false
	_sized = false
	_settle.call_deferred()               # 一帧后量真实行高→定位→显示
	return true

func set_active(active: bool) -> void:
	_active = active
	for p in _panels:
		if is_instance_valid(p):
			(p as Control).visible = active and _sized

func is_active() -> bool:
	return _active

## 指针是否落在任一显示中的浮窗块上（宿主 hold 判定用——「移到浮窗上仍算指着卡」）
func pointer_over(p: Vector2) -> bool:
	if not _active:
		return false
	for w in _panels:
		if is_instance_valid(w) and (w as Control).is_visible_in_tree() \
				and (w as Control).get_global_rect().grow(4.0).has_point(p):
			return true
	return false

## 贴边定位（CheckTooltipScreenPos 同构）：右→左→上按出屏/压 HUD 成本选边，
## 顶边对齐卡面「该侧顶角」，沿倾角摞列。宿主每帧调（active 时）＝跟随卡位。
func check_screen_pos() -> void:
	if not _active or not _sized or _panels.is_empty() \
			or not is_instance_valid(_host) or not _host.is_inside_tree():
		return
	var vp := get_viewport_rect().size
	var hr := _host_rect()
	var tilt := _tilt()
	var stack_w := 0.0
	var stack_h := 0.0
	var drift := 0.0
	for i in _panels.size():
		var p: Control = _panels[i]
		stack_w = maxf(stack_w, p.size.x)
		stack_h += p.size.y
		if i > 0:
			stack_h += STACK_GAP
			drift += absf(sin(tilt)) * (p.size.y + STACK_GAP)
	var side := _pick_side(stack_w + drift, stack_h, vp, hr)
	var corner := _corner_for_side(hr, side)
	var x := corner.x
	var y := corner.y
	if side > 0:
		x = corner.x + HOST_GAP
	elif side < 0:
		x = corner.x - HOST_GAP
	else:
		y = corner.y - HOST_GAP - stack_h   # 侧边都挤不下＝摆卡上方
	y = clampf(y, SCREEN_M, maxf(SCREEN_M, vp.y - stack_h - SCREEN_M))
	var pos := Vector2(x, y)
	for p in _panels:
		var w: float = p.size.x
		var px := pos.x if side > 0 else pos.x - w
		p.position = Vector2(clampf(px, SCREEN_M, maxf(SCREEN_M, vp.x - w - SCREEN_M)), pos.y)
		pos += Vector2(0.0, p.size.y + STACK_GAP).rotated(tilt)

# ── 内部 ────────────────────────────────────────────────────────────

func _settle() -> void:
	if not is_instance_valid(_host) or not _host.is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_instance_valid(self) or not is_instance_valid(_host):
		return   # 审计补：await 恢复时组件可能已随卡销毁（悬停卡被打出瞬间）
	for p in _panels:
		if not is_instance_valid(p):
			return
		var box: VBoxContainer = p.get_meta("box")
		_apply_size(p, Vector2(p.size.x, box.get_combined_minimum_size().y + PAD_T + PAD_B))
	_sized = true
	check_screen_pos()
	if _active:
		for p in _panels:
			if is_instance_valid(p):
				(p as Control).visible = true

func _tilt() -> float:
	if _tilt_fn.is_valid():
		return float(_tilt_fn.call())
	return 0.0

func _host_rect() -> Rect2:
	if _anchor_fn.is_valid():
		var r = _anchor_fn.call()
		if r is Rect2 and (r as Rect2).size.x > 1.0:
			return r
	if is_instance_valid(_host):
		return _host.get_global_rect()
	return Rect2()

## 取「该侧顶角」：右侧＝两枚右角里靠上的那一枚，左侧同理（斜卡外接框极值会飘）
func _corner_for_side(hr: Rect2, side: int) -> Vector2:
	if _corners_fn.is_valid():
		var pts = _corners_fn.call()
		if pts is PackedVector2Array and (pts as PackedVector2Array).size() == 4:
			var arr := Array(pts as PackedVector2Array)
			arr.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
			var pair: Array = [arr[2], arr[3]] if side > 0 else [arr[0], arr[1]]
			var a0: Vector2 = pair[0]
			var a1: Vector2 = pair[1]
			return a0 if a0.y <= a1.y else a1
	return Vector2(hr.position.x + (hr.size.x if side > 0 else 0.0), hr.position.y)

## 选边：右侧优先；右侧出屏更多或压到气珠/血心（×4 权重）才翻左；allow_above 时上方参选
func _pick_side(stack_w: float, stack_h: float, vp: Vector2, hr: Rect2) -> int:
	var av: Array = []
	for a in _avoid:
		if a is Control and is_instance_valid(a) and (a as Control).is_visible_in_tree():
			av.push_back((a as Control).get_global_rect().grow(8.0))
	var rr := Rect2(hr.position.x + hr.size.x + HOST_GAP, hr.position.y, stack_w, stack_h)
	var rl := Rect2(hr.position.x - HOST_GAP - stack_w, hr.position.y, stack_w, stack_h)
	var cr := _cost(rr, vp) + 4.0 * _cost_rects(rr, av)
	var cl := _cost(rl, vp) + 4.0 * _cost_rects(rl, av)
	return -1 if cl < cr - 0.5 else 1

func _cost(r: Rect2, vp: Vector2) -> float:
	var screen := Rect2(Vector2.ZERO, vp)
	if screen.encloses(r):
		return 0.0
	var inside := r.intersection(screen)
	return maxf(0.0, r.get_area() - inside.get_area()) * 1.5

func _cost_rects(r: Rect2, rects: Array) -> float:
	var cost := 0.0
	for rr in rects:
		if (rr as Rect2).intersects(r):
			cost += (rr as Rect2).intersection(r).get_area()
	return cost

# ── 单块装配（皮肤沿用 QiTooltip v3：金线切角九宫格＋阴影＋VBox）──────

func _build_block(kname: String, kdesc: String) -> void:
	var rows: Array = [{"t": "title", "text": kname}, {"t": "line", "text": kdesc}]
	var root := Control.new()
	root.name = "KwTipBlock"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	var shadow := _nine(Color(0, 0, 0, 0.28))
	shadow.position = Vector2(4, 4)
	root.add_child(shadow)
	var bg := _nine(Color.WHITE)
	root.add_child(bg)
	var box := VBoxContainer.new()
	box.name = "Content"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", ROW_SEP)
	root.add_child(box)
	root.set_meta("bg", bg)
	root.set_meta("shadow", shadow)
	root.set_meta("box", box)

	var l := Label.new()
	l.text = kname
	l.add_theme_font_override("font", QIF_FONTS.display())
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", TITLE_GOLD)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)

	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.text = kdesc
	r.add_theme_font_override("normal_font", QIF_FONTS.noto())
	r.add_theme_font_size_override("normal_font_size", 22)
	r.add_theme_color_override("default_color", BODY_CREAM)
	r.add_theme_constant_override("line_separation", -2)
	r.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
	r.add_theme_constant_override("shadow_offset_x", 3)
	r.add_theme_constant_override("shadow_offset_y", 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(r)

	# 定宽：最宽行撑开（上限 MAX_TEXT_W 超才换行）
	var w := maxf(_text_w(kname, 22), _text_w(kdesc, 22))
	w = clampf(w, MIN_BODY_W, MAX_TEXT_W)
	if w >= MAX_TEXT_W:
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size.x = maxf(30.0, MAX_TEXT_W)
	_apply_size(root, Vector2(w + PAD_L + PAD_R, 60.0))
	add_child(root)   # 审计补漏：面板必须挂进树（组件下；top_level 令 position 即全局坐标）
	_panels.push_back(root)

func _apply_size(win: Control, sz: Vector2) -> void:
	(win.get_meta("bg") as NinePatchRect).size = sz
	(win.get_meta("shadow") as NinePatchRect).size = sz
	var box: VBoxContainer = win.get_meta("box")
	win.size = sz
	box.position = Vector2(PAD_L, PAD_T)
	box.size = Vector2(maxf(1.0, sz.x - PAD_L - PAD_R), maxf(1.0, sz.y - PAD_T - PAD_B))

func _nine(mod: Color) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.texture = TIP_TEX
	np.patch_margin_left = PATCH
	np.patch_margin_top = PATCH
	np.patch_margin_right = PATCH
	np.patch_margin_bottom = PATCH
	np.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	np.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	np.modulate = mod
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return np

func _text_w(text: String, size: int) -> float:
	return QIF_FONTS.noto().get_string_size(_bb.sub(text, "", true), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
