## qi-forge 浮窗工厂 v2（2026-10-27 按 STS2 实测规格重造，API 不变：show_for/hide_for/hide_all）：
## 规格＝design-docs/references/STS2浮窗与弹窗调研_v0.1.md——无悬停延迟；锚源控件右侧 +10px 每帧跟拍；
## 皮肤＝hover_tip.png 九宫格双层（影层偏移 8,8 黑 25%｜本体边距 左55/上43/右91/下32）；
## 金题 #EFC851／奶油文 #FFF5E2，22px，行距 −2，投影 (3,2) 黑 25%；debuff 变体红染；
## 单浮窗制（新窗＝其余全关）；保留我方自愈巡检（宿主亡/拖拽中自动关——STS2 无此坑，我方有重绑）。
extends RefCounted

const QIF_FONTS = preload("res://qiforge/QiFontBank.gd")
const QIF_STYLE := preload("res://qiforge/QiStyle.gd")
const TIP_TEX: Texture2D = preload("res://qiforge/assets/sts2ref/hover_tip.png")

const PATCH := Rect2(55, 43, 91, 32)     # STS2 hover_tip 九宫格边距（左/上/右/下）
const CONTENT_M := Vector2(22, 16)       # 文本区内边距（左/上）；右 45／下 28
const TITLE_GOLD := Color(0.937, 0.784, 0.318)
const BODY_CREAM := Color(1.0, 0.965, 0.886)
const MIN_DESC_W := 300.0
const HOST_GAP := 10.0                   # 源控件右侧间距

static var _by_host: Dictionary = {}    # host:Object -> window:Control
static var _janitor_on := false

## 取/建唯一 TipLayer（CanvasLayer 90；挂 Noto 默认主题——CanvasLayer 子树不吃 Control 主题）
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

## 自愈＋跟拍：宿主亡/不可见/鼠标离位(28px 容差)/拖拽中 → 关；否则每帧重摆（锚源右侧，右溢翻左，上下夹紧）
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
	for host in _by_host.keys().duplicate():
		var win: Control = _by_host.get(host)
		if not is_instance_valid(host) or not host.is_visible_in_tree() \
				or not is_instance_valid(win) \
				or not (host as Control).get_global_rect().grow(28.0).has_point(mouse):
			hide_for(host)
			continue
		_place(win, host as Control)

static func show_for(host: Control, rows: Array, opts := {}) -> void:
	# 单浮窗制：新窗出现＝其余全关
	for other in _by_host.keys().duplicate():
		if other != host:
			hide_for(other)
	hide_for(host)
	var board := ensure_layer(host.get_tree())
	var win := _build_win(rows, opts)
	board.add_child(win)
	_by_host[host] = win
	win.set_meta("host", host)
	win.visible = false   # 先量尺寸再定位（同 STS2 二段式）
	_place.call_deferred(win, host)

static func hide_for(host: Control) -> void:
	if _by_host.has(host):
		var win: Control = _by_host[host]
		_by_host.erase(host)
		if is_instance_valid(win):
			win.queue_free()

static func hide_all() -> void:
	for host in _by_host.keys().duplicate():
		hide_for(host)

## 定位：源控件右侧 +10，顶对齐源顶；右溢翻左；上下夹紧 8px
static func _place(win: Control, host: Control) -> void:
	if not is_instance_valid(win) or not is_instance_valid(host):
		return
	var vp := host.get_viewport_rect().size
	var hrect := host.get_global_rect()
	var w := win.size.x
	var pos := Vector2(hrect.end.x + HOST_GAP, hrect.position.y)
	if pos.x + w > vp.x - 8.0:
		pos.x = hrect.position.x - w - HOST_GAP
	pos.y = clampf(pos.y, 8.0, vp.y - win.size.y - 8.0)
	win.position = pos
	win.visible = true

## 单窗装配：影层＋九宫格本体＋文本区（悬停浮窗不接受任何输入）
static func _build_win(rows: Array, opts: Dictionary) -> Control:
	var debuff := bool(opts.get("debuff", false))
	var root := Control.new()
	root.name = "QiTipWin"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shadow := NinePatchRect.new()
	shadow.name = "Shadow"
	shadow.texture = TIP_TEX
	shadow.patch_margin_left = PATCH.position.x
	shadow.patch_margin_top = PATCH.position.y
	shadow.patch_margin_right = PATCH.size.x
	shadow.patch_margin_bottom = PATCH.size.y
	shadow.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	shadow.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	shadow.modulate = Color(0, 0, 0, 0.25)
	shadow.position = Vector2(8, 8)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shadow)

	var bg := NinePatchRect.new()
	bg.name = "Bg"
	bg.texture = TIP_TEX
	bg.patch_margin_left = PATCH.position.x
	bg.patch_margin_top = PATCH.position.y
	bg.patch_margin_right = PATCH.size.x
	bg.patch_margin_bottom = PATCH.size.y
	bg.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	bg.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	if debuff:
		bg.modulate = Color(1.0, 0.62, 0.58)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var box := VBoxContainer.new()
	box.name = "Content"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = CONTENT_M.x
	box.offset_top = CONTENT_M.y
	box.offset_right = -45.0
	box.offset_bottom = -28.0
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	var min_w: float = opts.get("min_w", MIN_DESC_W)
	for row in rows:
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
				box.add_child(l)
			"attr":
				var h := HBoxContainer.new()
				h.add_theme_constant_override("separation", 14)
				h.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var k := Label.new()
				k.text = String(row.get("k", ""))
				k.add_theme_font_size_override("font_size", 20)
				k.add_theme_color_override("font_color", TITLE_GOLD)
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
				box.add_child(h)
			"line":
				var r := RichTextLabel.new()
				r.bbcode_enabled = true
				r.fit_content = true
				r.scroll_active = false
				r.custom_minimum_size.x = min_w
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
			"note":
				var n := Label.new()
				n.text = String(row.get("text", ""))
				n.add_theme_font_size_override("font_size", 18)
				n.add_theme_color_override("font_color", QIF_STYLE.TEXT_SUB)
				n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				n.custom_minimum_size.x = min_w
				n.mouse_filter = Control.MOUSE_FILTER_IGNORE
				box.add_child(n)
			"sep":
				var sp := HSeparator.new()
				sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
				box.add_child(sp)

	# 量尺寸后回填三层（影＋底＋窗根）
	_sizer.call_deferred(root, shadow, bg, box)
	return root

static func _sizer(root: Control, shadow: NinePatchRect, bg: NinePatchRect, box: VBoxContainer) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	var need := box.get_combined_minimum_size()
	var total := need + Vector2(CONTENT_M.x + 45.0, CONTENT_M.y + 28.0)
	root.size = total
	bg.size = total
	shadow.size = total
