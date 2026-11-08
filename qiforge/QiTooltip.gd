## qi-forge 浮窗工厂 v3（2026-11-08 重做显示效果；API：show_for / show_stack / hide_for / hide_all）：
## 规格（用户口径：撑内容、动态选边、金线切角框、斜卡带梯度）：
##  1 尺寸＝内容撑开：宽＝最宽行（上限 MAX_TEXT_W 352，超才换行）＋内边距 16/10；高＝行高合计＋12
##  2 位置＝卡外 10px；默认放右侧，**若右侧压到别的卡/出屏比左侧重则整列翻左**（按遮挡面积算，平手取右）
##  3 排布＝第一块顶边跟卡顶齐，其余一块接一块往下摞（STACK_GAP 6）
##  4 梯度＝每下移一块，位移沿宿主卡倾角走 —— step = (0, 前一块高+gap).rotate(tilt)，斜卡即斜列
##  5 皮肤＝tip_frame.png 九宫格（边距 14）：1px 墨 → 2px 亮金 → 1px 墨 → 1px 暗金 → 墨底 96%
##  6 单宿主单列（新宿主＝其余全关）；宿主亡/不可见/拖拽中自动关
extends RefCounted

const QIF_FONTS = preload("res://qiforge/QiFontBank.gd")
const QIF_STYLE := preload("res://qiforge/QiStyle.gd")
const TIP_TEX: Texture2D = preload("res://qiforge/assets/ui/tip_frame.png")

const PATCH := 14                        # 九宫格边距（贴图 64×64）
const PAD_L := 16.0
const PAD_T := 10.0
const PAD_R := 16.0
const PAD_B := 12.0
const MAX_TEXT_W := 352.0                # 正文最宽，超了才换行
const MIN_BODY_W := 88.0                 # 极短提示的地板宽
const ROW_SEP := 5
const HOST_GAP := 2.0                    # 卡与浮窗的水平间距（2026-11-08 用户令：贴住卡，原版就是几乎挨着/略微压边）
const STACK_GAP := 10.0                  # 浮窗与浮窗的竖直间距（2026-11-08 用户令：与盒内边距同量级＝间隙相等）
const SCREEN_M := 8.0
const MAX_STACK := 3                     # 一列最多几块
const TITLE_GOLD := Color(0.937, 0.784, 0.318)
const BODY_CREAM := Color(1.0, 0.965, 0.886)

static var _by_host: Dictionary = {}     # host:Object -> Array[Control]（从上到下）
static var _janitor_on := false
static var _last_mouse := Vector2(-99999, -99999)
static var _bb := RegEx.create_from_string("\\[[^\\]]*\\]")

# ── 层 ──────────────────────────────────────────────────────────────
static func ensure_layer(tree: SceneTree) -> Control:
	for node in tree.root.get_children():
		if node is CanvasLayer and node.is_in_group("qi_tip_layer"):
			return node.get_child(0) as Control
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.add_to_group("qi_tip_layer")
	var board := Control.new()
	board.name = "TipBoard"
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.theme = QIF_FONTS.default_theme()
	layer.add_child(board)
	tree.root.add_child(layer)
	_ensure_janitor(tree)
	return board

static func _ensure_janitor(tree: SceneTree) -> void:
	if _janitor_on:
		return
	_janitor_on = true
	tree.process_frame.connect(_janitor_tick)

## 自愈：宿主亡/不可见/拖拽中 → 关；鼠标真移动过且离开宿主 → 关；否则每帧重摆（跟随卡位）
static func _janitor_tick() -> void:
	if _by_host.is_empty():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if tree.root.gui_is_dragging():
		hide_all()
		return
	var mouse := tree.root.get_mouse_position()
	var moved := mouse.distance_squared_to(_last_mouse) > 1.0
	_last_mouse = mouse
	for host in _by_host.keys().duplicate():
		var panels: Array = _by_host.get(host, [])
		if not is_instance_valid(host):
			_by_host.erase(host)   # 宿主已释放：直接清键（它进不了 hide_for 的类型检查）
			continue
		if not (host as Control).is_visible_in_tree() \
				or panels.is_empty() or not is_instance_valid(panels[0]):
			hide_for(host)
			continue
		# 鼠标移到浮窗上也算"还在指着宿主"（2026-11-08 用户令）——否则这里的守门会立刻把它关掉
		if moved and not _hover_rect(host as Control, panels).grow(28.0).has_point(mouse) \
				and not pointer_over_panels(mouse):
			hide_for(host)
			continue
		_place_stack(host as Control, panels, _tilt_of(panels))

static func _tilt_of(panels: Array) -> float:
	if panels.is_empty():
		return 0.0
	var p = panels[0]
	if not is_instance_valid(p):
		return 0.0
	var fn = p.get_meta("tilt_fn", Callable())
	if fn is Callable and (fn as Callable).is_valid():
		return float((fn as Callable).call())
	return float(p.get_meta("tilt", 0.0))

# ── 对外入口 ────────────────────────────────────────────────────────
static func show_for(host: Control, rows: Array, opts := {}) -> void:
	show_stack(host, [rows], opts)

## groups＝一组「行数组」的数组：每组一块浮窗，自上而下摞、沿 tilt 递进
static func show_stack(host: Control, groups: Array, opts := {}) -> void:
	for other in _by_host.keys().duplicate():
		if other != host:
			if is_instance_valid(other):
				hide_for(other)
			else:
				_by_host.erase(other)   # 宿主已被释放：清掉脏键，别再把已释放对象传进 hide_for
	hide_for(host)
	if groups.is_empty():
		return
	var board := ensure_layer(host.get_tree())
	_last_mouse = host.get_tree().root.get_mouse_position()   # 开窗时对齐鼠标基准（合成 hover 不被自愈立刻关掉）
	var tilt: float = float(opts.get("tilt", host.rotation))
	var panels: Array = []
	for i in groups.size():
		if i >= MAX_STACK:
			break
		var win := _build_win(groups[i] as Array, opts)
		board.add_child(win)
		win.visible = false
		win.set_meta("ready", false)
		win.set_meta("tilt", tilt)
		win.set_meta("host", host)
		win.set_meta("anchor_fn", opts.get("anchor_fn", Callable()))
		win.set_meta("allow_above", bool(opts.get("allow_above", false)))
		win.set_meta("tilt_fn", opts.get("tilt_fn", Callable()))
		win.set_meta("corners_fn", opts.get("corners_fn", Callable()))
		win.set_meta("corner_l", opts.get("corner_l", Vector2(-1e9, -1e9)))
		win.set_meta("corner_r", opts.get("corner_r", Vector2(-1e9, -1e9)))
		win.set_meta("avoid", opts.get("avoid", []))
		panels.push_back(win)
	_by_host[host] = panels
	_settle.call_deferred(host, panels)

static func hide_for(host: Object) -> void:   # Object：允许传入已释放实例，内部再判
	if host == null or not is_instance_valid(host):
		_by_host.erase(host)
		return
	if _by_host.has(host):
		var panels: Array = _by_host[host]
		_by_host.erase(host)
		for w in panels:
			if is_instance_valid(w):
				(w as Control).queue_free()

static func hide_all() -> void:
	for host in _by_host.keys().duplicate():
		hide_for(host)

# ── 布局：先定宽，再等一帧读真实行高，最后定位显示 ──────────────────
static func _settle(host: Control, panels: Array) -> void:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return
	await host.get_tree().process_frame
	if not is_instance_valid(host):
		return
	for p in panels:
		if not is_instance_valid(p):
			return
		var box: VBoxContainer = p.get_meta("box")
		_apply_size(p, Vector2(p.size.x, box.get_combined_minimum_size().y + PAD_T + PAD_B))
	for p in panels:
		if is_instance_valid(p):
			p.set_meta("ready", true)
	_place_stack(host, panels, _tilt_of(panels))   # 先定位
	for p in panels:
		if is_instance_valid(p):
			(p as Control).visible = true              # 再显示（否则会先闪在默认坐标）

static func _apply_size(win: Control, sz: Vector2) -> void:
	var bg: NinePatchRect = win.get_meta("bg")
	var sh: NinePatchRect = win.get_meta("shadow")
	var box: VBoxContainer = win.get_meta("box")
	win.size = sz
	bg.size = sz
	sh.size = sz
	box.position = Vector2(PAD_L, PAD_T)
	box.size = Vector2(maxf(1.0, sz.x - PAD_L - PAD_R), maxf(1.0, sz.y - PAD_T - PAD_B))

## 顶边对齐：斜卡的外接框最高点是某个角，浮窗要按「它所在那一侧的角」对齐，
## 否则右侧浮窗会悬在卡右上角上方一截（2026-11-08 用户指正）
## 悬停判定用「看得见的卡面」（弹起后比外层壳大；用壳会提前把浮窗关掉）
## 指针是否落在任一在显示的浮窗上（2026-11-08 用户令：移到浮窗上仍算"指着卡"）
## 用当前实际矩形判定——淡出动画期间也有效，避免"追不上"的空档
static func pointer_over_panels(p: Vector2) -> bool:
	for host in _by_host.keys():
		if not is_instance_valid(host):
			continue
		var arr: Array = _by_host[host]
		for w in arr:
			if not is_instance_valid(w):
				continue
			if (w as Control).is_visible_in_tree() and (w as Control).get_global_rect().grow(4.0).has_point(p):
				return true
	return false

static func _hover_rect(host: Control, panels: Array) -> Rect2:
	if not panels.is_empty() and is_instance_valid(panels[0]):
		var fn = panels[0].get_meta("corners_fn", Callable())
		if fn is Callable and (fn as Callable).is_valid():
			var pts = (fn as Callable).call()
			if pts is PackedVector2Array and (pts as PackedVector2Array).size() == 4:
				var mn: Vector2 = (pts as PackedVector2Array)[0]
				var mx: Vector2 = mn
				for q in pts:
					mn = Vector2(minf(mn.x, q.x), minf(mn.y, q.y))
					mx = Vector2(maxf(mx.x, q.x), maxf(mx.y, q.y))
				return Rect2(mn, mx - mn)
	return host.get_global_rect()

## 取「该侧顶角」：右侧＝两枚右角里靠上的那一枚，左侧同理
static func _corner_for_side(panels: Array, hr: Rect2, side: int) -> Vector2:
	if panels.is_empty() or not is_instance_valid(panels[0]):
		return Vector2(hr.position.x + (hr.size.x if side > 0 else 0.0), hr.position.y)
	var fn = panels[0].get_meta("corners_fn", Callable())
	if not (fn is Callable) or not (fn as Callable).is_valid():
		return Vector2(hr.position.x + (hr.size.x if side > 0 else 0.0), hr.position.y)
	var pts = (fn as Callable).call()
	if not (pts is PackedVector2Array) or (pts as PackedVector2Array).size() != 4:
		return Vector2(hr.position.x + (hr.size.x if side > 0 else 0.0), hr.position.y)
	var arr := Array(pts as PackedVector2Array)
	arr.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var pair: Array = [arr[2], arr[3]] if side > 0 else [arr[0], arr[1]]
	var a0: Vector2 = pair[0]
	var a1: Vector2 = pair[1]
	return a0 if a0.y <= a1.y else a1

## 宿主矩形：优先问 anchor_fn（手牌焦点态卡面比拖拽壳大且上浮，锚壳会压住卡）
static func _host_rect(host: Control, panels: Array) -> Rect2:
	if not panels.is_empty() and is_instance_valid(panels[0]):
		var fn = panels[0].get_meta("anchor_fn", Callable())
		if fn is Callable and (fn as Callable).is_valid():
			var r = (fn as Callable).call()
			if r is Rect2 and (r as Rect2).size.x > 1.0:
				return r
	return host.get_global_rect()

## 定位：先选边（右侧优先，被卡压住/出屏才翻左），再沿倾角一块块往下摞
static func _place_stack(host: Control, panels: Array, tilt: float) -> void:
	if panels.is_empty() or not is_instance_valid(panels[0]) or not bool(panels[0].get_meta("ready", false)):
		return
	var vp := host.get_viewport_rect().size
	var hr := _host_rect(host, panels)
	var stack_w := 0.0
	var stack_h := 0.0
	var drift := 0.0
	for i in panels.size():
		var p: Control = panels[i]
		stack_w = maxf(stack_w, p.size.x)
		stack_h += p.size.y
		if i > 0:
			stack_h += STACK_GAP
			drift += absf(sin(tilt)) * (p.size.y + STACK_GAP)
	var avoid: Array = panels[0].get_meta("avoid", [])
	var side := _pick_side(host, stack_w + drift, stack_h, vp, hr,
		bool(panels[0].get_meta("allow_above", false)), avoid)
	# 位置按「卡在该侧的顶角」算（不是整个卡的外接框）——外接框取的是四个角的极值，
	# 斜卡时会离真实边框很远（2026-11-08 用户指正：左右间距不一致就是这么来的）
	var corner := _corner_for_side(panels, hr, side)
	var x := corner.x
	var y := corner.y
	if side > 0:
		x = corner.x + HOST_GAP
	elif side < 0:
		x = corner.x - HOST_GAP
	else:
		y = corner.y - HOST_GAP - stack_h   # 侧边都挤不下就摆卡上方（底部与卡顶齐）
	y = clampf(y, SCREEN_M, maxf(SCREEN_M, vp.y - stack_h - SCREEN_M))
	var pos := Vector2(x, y)
	for p in panels:
		var w: float = p.size.x
		var px := pos.x if side > 0 else pos.x - w
		p.position = Vector2(clampf(px, SCREEN_M, maxf(SCREEN_M, vp.x - w - SCREEN_M)), pos.y)
		pos += Vector2(0.0, p.size.y + STACK_GAP).rotated(tilt)

# ── 选边：右侧优先；右侧被别的卡压住或出屏更多才翻左 ────────────────
static func _pick_side(host: Control, stack_w: float, stack_h: float, vp: Vector2, hr: Rect2,
		allow_above := false, avoid: Array = []) -> int:
	# 2026-11-08 用户指正：浮窗是悬浮层，盖住别的牌不算问题——选边只看
	# ①右侧会不会出屏 ②会不会压到气珠/血心这类「盖住就看不见」的 HUD。其他牌一律不管。
	var obs: Array = []
	# 额外禁区（气珠/血心：被盖住就等于消失了）——权重 ×4，宁可压邻牌也不压 HUD
	var av: Array = []
	for a in avoid:
		if a is Control and is_instance_valid(a) and (a as Control).is_visible_in_tree():
			av.push_back((a as Control).get_global_rect().grow(8.0))
	var rr := Rect2(hr.position.x + hr.size.x + HOST_GAP, hr.position.y, stack_w, stack_h)
	var rl := Rect2(hr.position.x - HOST_GAP - stack_w, hr.position.y, stack_w, stack_h)
	var cr := _cost(rr, vp, obs) + 4.0 * _cost(rr, vp, av)
	var cl := _cost(rl, vp, obs) + 4.0 * _cost(rl, vp, av)
	if allow_above:
		var ca := _cost(Rect2(hr.position.x, hr.position.y - HOST_GAP - stack_h, stack_w, stack_h), vp, obs)
		if ca < minf(cr, cl) - 0.5:
			return 0
	return -1 if cl < cr - 0.5 else 1

static func _cost(r: Rect2, vp: Vector2, obs: Array) -> float:
	var screen := Rect2(Vector2.ZERO, vp)
	var cost := 0.0
	if not screen.encloses(r):
		var inside := r.intersection(screen)
		cost += maxf(0.0, r.get_area() - inside.get_area()) * 1.5
	for o in obs:
		var rr: Rect2 = o
		if rr.intersects(r):
			cost += rr.intersection(r).get_area()
	return cost

## 障碍＝屏上「卡尺寸」的非容器控件（浮窗层/宿主自身与其祖先不算）
static func _collect_obstacles(host: Control) -> Array:
	var out: Array = []
	var tree := host.get_tree()
	if tree == null:
		return out
	_scan(tree.root, host, out)
	return out

static func _scan(n: Node, host: Control, out: Array) -> void:
	if n is CanvasLayer and n.is_in_group("qi_tip_layer"):
		return
	if n is Control:
		var c := n as Control
		if c != host and not host.is_ancestor_of(c) and not c.is_ancestor_of(host) \
				and c.is_visible_in_tree() and not (c is Container):
			var r := c.get_global_rect()
			# 卡尺寸件（卡）＋ 一切按钮（交互件一律不许被盖）
			if (r.size.x >= 120.0 and r.size.y >= 150.0) or c is BaseButton:
				_add_rect(out, r)
	for ch in n.get_children():
		_scan(ch, host, out)

static func _add_rect(out: Array, r: Rect2) -> void:
	for o in out:
		var q: Rect2 = o
		if absf(q.position.x - r.position.x) < 4.0 and absf(q.position.y - r.position.y) < 4.0 \
				and absf(q.size.x - r.size.x) < 8.0 and absf(q.size.y - r.size.y) < 8.0:
			return
	out.push_back(r)

# ── 单块装配 ────────────────────────────────────────────────────────
static func _nine(nm: String, mod: Color) -> NinePatchRect:
	var np := NinePatchRect.new()
	np.name = nm
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

static func _plain(text: String) -> String:
	return _bb.sub(text, "", true)

static func _text_w(text: String, size: int) -> float:
	return QIF_FONTS.noto().get_string_size(_plain(text), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

static func _build_win(rows: Array, opts: Dictionary) -> Control:
	var debuff := bool(opts.get("debuff", false))
	var root := Control.new()
	root.name = "QiTipWin"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shadow := _nine("Shadow", Color(0, 0, 0, 0.28))
	shadow.position = Vector2(4, 4)
	root.add_child(shadow)
	var bg := _nine("Bg", Color(1.0, 0.62, 0.58) if debuff else Color.WHITE)
	root.add_child(bg)

	var box := VBoxContainer.new()
	box.name = "Content"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", ROW_SEP)
	root.add_child(box)
	root.set_meta("bg", bg)
	root.set_meta("shadow", shadow)
	root.set_meta("box", box)

	var items: Array = []   # {node, rich, extra, text, size}
	for row in rows:
		_add_row(box, row, items)

	# 定宽：文本行走 font 量，其余走控件最小宽
	var body_w := MIN_BODY_W
	for it in items:
		var w := 0.0
		if it.has("text"):
			w = _text_w(String(it["text"]), int(it["size"])) + float(it.get("extra", 0.0))
		else:
			w = (it["node"] as Control).get_combined_minimum_size().x + float(it.get("extra", 0.0))
		body_w = maxf(body_w, w)
	if body_w > MAX_TEXT_W:
		for it in items:
			var rr = it.get("rich")
			if rr != null:
				(rr as RichTextLabel).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				(rr as RichTextLabel).custom_minimum_size.x = maxf(30.0, MAX_TEXT_W - float(it.get("extra", 0.0)))
		body_w = MAX_TEXT_W
	# 属性键列对齐（同列左键同宽）
	var key_w := 0.0
	for it in items:
		var kk = it.get("key")
		if kk != null:
			key_w = maxf(key_w, (kk as Label).get_combined_minimum_size().x)
	for it in items:
		var kk2 = it.get("key")
		if kk2 != null:
			(kk2 as Label).custom_minimum_size.x = key_w

	_apply_size(root, Vector2(body_w + PAD_L + PAD_R, 60.0))
	return root

static func _add_row(box: VBoxContainer, row: Dictionary, items: Array) -> void:
	match String(row.get("t", "line")):
		"title":
			var l := Label.new()
			l.text = String(row.get("text", ""))
			l.add_theme_font_override("font", QIF_FONTS.display())
			l.add_theme_font_size_override("font_size", 22)
			l.add_theme_color_override("font_color", row.get("color", TITLE_GOLD))
			l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
			l.add_theme_constant_override("shadow_offset_x", 3)
			l.add_theme_constant_override("shadow_offset_y", 2)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(l)
			items.push_back({"node": l, "rich": null, "extra": 0.0, "key": null})
		"attr":
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 16)
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var k := Label.new()
			k.text = String(row.get("k", ""))
			k.add_theme_font_size_override("font_size", 20)
			k.add_theme_color_override("font_color", Color(0.62, 0.54, 0.36))
			k.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
			k.add_theme_constant_override("shadow_offset_x", 3)
			k.add_theme_constant_override("shadow_offset_y", 2)
			h.add_child(k)
			var v := Label.new()
			v.text = str(row.get("v", ""))
			v.add_theme_font_size_override("font_size", 20)
			v.add_theme_color_override("font_color", BODY_CREAM)
			v.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
			v.add_theme_constant_override("shadow_offset_x", 3)
			v.add_theme_constant_override("shadow_offset_y", 2)
			h.add_child(v)
			h.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(h)
			items.push_back({"node": h, "rich": null, "extra": 0.0, "key": k})
		"line":
			var r := RichTextLabel.new()
			r.bbcode_enabled = true
			r.fit_content = true
			r.scroll_active = false
			r.autowrap_mode = TextServer.AUTOWRAP_OFF
			r.text = String(row.get("text", ""))
			r.add_theme_font_override("normal_font", QIF_FONTS.noto())
			r.add_theme_font_size_override("normal_font_size", 22)
			r.add_theme_color_override("default_color", BODY_CREAM)
			r.add_theme_constant_override("line_separation", -2)
			r.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
			r.add_theme_constant_override("shadow_offset_x", 3)
			r.add_theme_constant_override("shadow_offset_y", 2)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(r)
			items.push_back({"node": r, "rich": r, "extra": 0.0, "key": null,
				"text": String(row.get("text", "")), "size": 22})
		"note":
			var n := RichTextLabel.new()
			n.bbcode_enabled = true
			n.fit_content = true
			n.scroll_active = false
			n.autowrap_mode = TextServer.AUTOWRAP_OFF
			n.text = String(row.get("text", ""))
			n.add_theme_font_override("normal_font", QIF_FONTS.noto())
			n.add_theme_font_size_override("normal_font_size", 18)
			n.add_theme_color_override("default_color", QIF_STYLE.TEXT_SUB)
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(n)
			items.push_back({"node": n, "rich": n, "extra": 0.0, "key": null,
				"text": String(row.get("text", "")), "size": 18})
		"frame":
			var fr := PanelContainer.new()
			var fsb := StyleBoxFlat.new()
			fsb.bg_color = Color(0.07, 0.06, 0.045, 0.88)
			fsb.border_color = Color(0.72, 0.58, 0.30, 0.75)
			fsb.set_border_width_all(1)
			fsb.set_corner_radius_all(6)
			fsb.content_margin_left = 10.0
			fsb.content_margin_right = 10.0
			fsb.content_margin_top = 6.0
			fsb.content_margin_bottom = 6.0
			fr.add_theme_stylebox_override("panel", fsb)
			fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ft := RichTextLabel.new()
			ft.bbcode_enabled = true
			ft.fit_content = true
			ft.scroll_active = false
			ft.autowrap_mode = TextServer.AUTOWRAP_OFF
			ft.text = String(row.get("text", ""))
			ft.add_theme_font_override("normal_font", QIF_FONTS.noto())
			ft.add_theme_font_size_override("normal_font_size", 20)
			ft.add_theme_color_override("default_color", Color("ffe9b0"))
			ft.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fr.add_child(ft)
			box.add_child(fr)
			items.push_back({"node": fr, "rich": ft, "extra": 20.0, "key": null,
				"text": String(row.get("text", "")), "size": 20})
		"sep":
			var sp := HSeparator.new()
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(sp)
			items.push_back({"node": sp, "rich": null, "extra": 0.0, "key": null})
