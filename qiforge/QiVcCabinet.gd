## VC 制机柜公共件（2026-11-01 用户裁定「战斗同壳」）：地图屏/战斗屏共用
## 机柜（黑框＋绗缝暗纹＋内舱＋视口）＋左右舷（血心·抽牌堆 / 气珠·弃牌堆）＋
## 视口顶带（等级＋经验条＋层数徽——两屏同源、同刷新）。两屏只换中央视口内容。
extends RefCounted

const QISTYLE := preload("res://qiforge/QiStyle.gd")

## 机柜几何（1920×1080）：左舷 0~344／中央视口 360~1560／右舷 1576~1920
const VIEW := Rect2(360.0, 70.0, 1200.0, 960.0)
const BAR_TOP := 64.0   # 视口内顶条带高（2026-11-03 VC 制加粗：蓝条经验＋Lv）

## HUD 底板槽位（2026-11-04 用户令「先画基础背景，再按背景塞按钮」）：1920×1080 唯一权威。
## 底部左右两块脚座板承载全部 HUD 件（血心/抽牌堆在左板，气珠/结束回合/弃牌堆在右板，排序面板贴右板外沿）。
const PLINTH_L := Rect2(60.0, 776.0, 384.0, 304.0)
const PLINTH_R := Rect2(1436.0, 776.0, 424.0, 304.0)

static var _tex_cache: Dictionary = {}

## HUD 贴图（AI 件；运行时读 PNG，绕开编辑器导入）
static func _art(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var p := "res://qiforge/assets/hud/%s.png" % name
	var t: Texture2D = null
	var img := Image.load_from_file(ProjectSettings.globalize_path(p))
	if img != null and not img.is_empty():
		t = ImageTexture.create_from_image(img)
	_tex_cache[name] = t
	return t

const BEZEL := Color("202024")
const BEZEL_EDGE := Color("35353c")
const SCREEN_BG := Color("0a0a0c")
const FRAME_GOLD := Color("b9a978")
const HEART := Color("8f3a2c")
const ORB := Color("1f3f74")
const ORB_RIM := Color("6f9fd8")

static func _panel_style(bg: Color, edge: Color, radius: int, border: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	return sb

static func _add_panel(parent: Control, rect: Rect2, style: StyleBoxFlat) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p

## 机柜本体：黑机柜＋暗纹＋内舱凹槽＋视口黑底米金边
static func build(parent: Control) -> void:
	var console := Panel.new()
	console.position = Vector2(16.0, 16.0)
	console.size = Vector2(1888.0, 1048.0)
	console.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = BEZEL
	sb.border_color = BEZEL_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(20)
	console.add_theme_stylebox_override("panel", sb)
	parent.add_child(console)

	var quilt := TextureRect.new()
	quilt.position = Vector2(6.0, 6.0)
	quilt.size = console.size - Vector2(12.0, 12.0)
	quilt.texture = _quilt_texture()
	quilt.stretch_mode = TextureRect.STRETCH_TILE
	quilt.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	quilt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	console.add_child(quilt)

	var bay := _add_panel(parent, Rect2(336.0, 46.0, 1248.0, 1010.0),
		_panel_style(Color("15151a"), Color("0e0e11"), 14, 3))
	bay.name = "ScreenBay"

	var view := Panel.new()
	view.position = VIEW.position
	view.size = VIEW.size
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := StyleBoxFlat.new()
	vs.bg_color = SCREEN_BG
	vs.border_color = FRAME_GOLD
	vs.set_border_width_all(3)
	vs.set_corner_radius_all(4)
	view.add_theme_stylebox_override("panel", vs)
	parent.add_child(view)


## 脚座板样式：深底＋金边＋上圆角（下缘出屏不圆角）
static func _plinth_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.055, 0.065, 0.97)
	sb.border_color = Color(0.72, 0.66, 0.47, 0.9)
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	return sb

## 战斗底（2026-11-04 用户令：去黑金框，场景图铺底＋底部柔光罩）
static func build_plate(parent: Control) -> void:
	var scene := _art("scene")
	if scene == null:
		build(parent)
		return
	var bg := TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture = scene
	bg.position = Vector2.ZERO
	bg.size = Vector2(1920.0, 1080.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	# 整体压暗一档（让浮件跳出来）
	var dim := ColorRect.new()
	dim.position = Vector2.ZERO
	dim.size = Vector2(1920.0, 1080.0)
	dim.color = Color(0.05, 0.045, 0.045, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dim)
	print("[dim] added ", dim.size)
	# 底部柔光罩：让手牌压得住亮纸
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.02, 0.03, 0.0))
	grad.set_color(1, Color(0.02, 0.02, 0.03, 0.62))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.0, 1.0)
	gt.width = 8
	gt.height = 256
	var scrim := TextureRect.new()
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.texture = gt
	scrim.position = Vector2(0.0, 500.0)
	scrim.size = Vector2(1920.0, 580.0)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(scrim)

## 菱形绗缝暗纹（48px 平铺，极淡）：TextureRect＋REPEAT 原生件，不写着色器
static func _quilt_texture() -> ImageTexture:
	var s := 48
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var line := Color(1.0, 1.0, 1.0, 0.045)
	for i in s:
		for j in s:
			if (i + j) % s == 0 or (i - j + s) % s == 0:
				img.set_pixel(i, j, line)
	return ImageTexture.create_from_image(img)

## 顶带（2026-11-03 VC 制重排）：左＝层数小字，中＝蓝条经验，右＝Lv。返回刷新引用。
static func build_top(parent: Control) -> Dictionary:
	# 经验条（AI 剑形横幅，2026-11-04 用户令）：底图先落，文字叠上面
	var xp_tex := _art("c_xpbar")
	if xp_tex != null:
		var xr := TextureRect.new()
		xr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		xr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		xr.texture = xp_tex
		xr.position = Vector2(392.0, 6.0)
		xr.size = Vector2(780.0, 164.0)
		xr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(xr)
	var bar := _add_panel(parent,
		Rect2(VIEW.position.x + 18.0, VIEW.position.y + 6.0, VIEW.size.x - 36.0, 52.0),
		_panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	var floor := _mk_lbl(bar, "", QISTYLE.FS_SMALL, Color(0.24, 0.18, 0.12), false, 110.0, Vector2(92.0, 28.0))
	var track_w: float = bar.size.x - 256.0
	var track := Panel.new()
	track.position = Vector2(106.0, 9.0)
	track.size = Vector2(track_w, 34.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel",
		_panel_style(Color(0.15, 0.13, 0.10, 0.18), Color(0, 0, 0, 0), 2, 0))
	track.visible = false
	bar.add_child(track)
	var fill := Panel.new()
	fill.position = Vector2(108.0, 11.0)
	fill.size = Vector2(0.0, 30.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel",
		_panel_style(Color("2f6bd8"), Color("7fa8ef"), 2, 1))
	fill.visible = false
	bar.add_child(fill)
	var xp_t := _mk_lbl(bar, "", QISTYLE.FS_SMALL, Color(0.24, 0.18, 0.12), false, 170.0,
		Vector2(186.0, 28.0))
	var lvl := _mk_lbl(bar, "", QISTYLE.FS_BIG, Color(0.93, 0.86, 0.68), true, 128.0,
		Vector2(650.0, 22.0))
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return {"lvl": lvl, "xp_fill": fill, "xp_text": xp_t, "floor": floor, "track_w": track_w}

## 左右舷：左下血心＋抽牌堆／右下气珠＋弃牌堆（两屏同件）。位置照原版战斗屏（2026-11-04 用户裁定）。
static func build_wings(parent: Control) -> Dictionary:
	# 左舷：血心（AI 徽章）＋数字；抽牌堆（AI 卡背）
	var heart := TextureRect.new()
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.texture = _art("c_heart")
	heart.position = Vector2(315.0, 704.0)
	heart.size = Vector2(110.0, 108.0)
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(heart)
	var hp := _mk_lbl(parent, "", 32, QISTYLE.CREAM, true, 128.0, Vector2(315.0, 738.0))
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	hp.add_theme_constant_override("shadow_offset_x", 2)
	hp.add_theme_constant_override("shadow_offset_y", 2)
	var draw_lbl := _mk_pile_block(parent, Vector2(322.0, 946.0), false)
	# 右舷：气珠（AI 徽章）＋数字；弃牌堆
	var orb := TextureRect.new()
	orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	orb.texture = _art("c_qi")
	orb.position = Vector2(1495.0, 704.0)
	orb.size = Vector2(110.0, 108.0)
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(orb)
	var qi := _mk_lbl(parent, "", 32, QISTYLE.CREAM, true, 128.0, Vector2(1495.0, 738.0))
	qi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qi.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	qi.add_theme_constant_override("shadow_offset_x", 2)
	qi.add_theme_constant_override("shadow_offset_y", 2)
	var discard_lbl := _mk_pile_block(parent, Vector2(1502.0, 946.0), true)
	return {"hp_text": hp, "draw_lbl": draw_lbl, "discard_lbl": discard_lbl, "qi": qi}

static func _mk_lbl(parent: Control, text: String, size: int, color: Color, title: bool,
		w: float, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	QISTYLE.font(l, size, title)
	QISTYLE.text_color(l, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos
	l.size = Vector2(w, 36.0)
	parent.add_child(l)
	return l

## 卡背叠（三张递错位）＋计数；弃牌堆顶牌靠左（抽牌堆靠右）
static func _mk_pile_block(parent: Control, pos: Vector2, top_lean_left: bool) -> Label:
	var holder := Control.new()
	holder.position = pos
	holder.size = Vector2(100.0, 100.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	# 叠牌贴图（AI 件）
	var stack_tex := _art("c_stack")
	if stack_tex != null:
		var st := TextureRect.new()
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		st.texture = stack_tex
		st.position = Vector2(4.0, 0.0)
		st.size = Vector2(92.0, 92.0)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(st)
	# 大计数（压在卡堆上）
	var cnt := Label.new()
	cnt.position = Vector2(0.0, 92.0)
	cnt.size = Vector2(92.0, 26.0)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	QISTYLE.font(cnt, 22, true)
	QISTYLE.text_color(cnt, QISTYLE.CREAM)
	cnt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	cnt.add_theme_constant_override("shadow_offset_x", 2)
	cnt.add_theme_constant_override("shadow_offset_y", 2)
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cnt)
	return cnt

static func _mk_card_back(pos: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(34, 48)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(QISTYLE.INK_PANEL_DEEP.r, QISTYLE.INK_PANEL_DEEP.g,
		QISTYLE.INK_PANEL_DEEP.b, 0.95)
	sb.border_color = QISTYLE.AMBER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = "剑"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	QISTYLE.font(l, QISTYLE.FS_BODY)
	QISTYLE.text_color(l, QISTYLE.CREAM)
	p.add_child(l)
	return p

## 顶带刷新（两屏同源）：Lv/经验/层数（缺件跳过——护栏见 _uniq）
## dur > 0 时填充走补间（2026-11-05 经验美术轮：珠到账条要涨，不能瞬移）。
## 同一目标的重入（changed 连发）不重开补间——否则会把正在跑的动画当场截断。
static func refresh_top(refs: Dictionary, level: int, xp: int, fidx: int, floors: int, need: int,
		dur: float = 0.0) -> void:
	var lvl := refs.get("lvl") as Label
	if lvl != null:
		lvl.text = "Lv %d" % level
	var track_w: float = float(refs.get("track_w", 800.0))
	var fill := refs.get("xp_fill") as Panel
	if fill != null:
		var fill_h := fill.size.y
		var target := (track_w - 114.0) * clampf(float(xp) / float(maxi(1, need)), 0.0, 1.0)
		var tw_old: Tween = null
		if fill.has_meta("xp_tw"):
			tw_old = fill.get_meta("xp_tw") as Tween
		var flying := tw_old != null and tw_old.is_valid()
		var same := false
		if fill.has_meta("xp_tgt"):
			same = absf(float(fill.get_meta("xp_tgt")) - target) < 0.5
		if flying and same:
			pass                                   # 已在飞向同一目标：不打断
		else:
			if flying:
				tw_old.kill()
			if dur > 0.0 and absf(fill.size.x - target) > 0.5:
				var tw := fill.create_tween()
				tw.tween_property(fill, "size:x", target, dur)\
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				fill.set_meta("xp_tw", tw)
				fill.set_meta("xp_tgt", target)
			else:
				fill.size = Vector2(target, fill_h)
				fill.remove_meta("xp_tw")
	var xp_t := refs.get("xp_text") as Label
	if xp_t != null:
		xp_t.text = "%d/%d" % [xp, need]
	var floor_l := refs.get("floor") as Label
	if floor_l != null:
		floor_l.text = "第 %d/%d 重" % [fidx + 1, floors]

## 舷位刷新：血/抽/弃/气（原版血心＝单数字当前血；气珠数字＋每回合回复量；地图屏不传气＝保留"气"字）
static func refresh_wings(refs: Dictionary, hp: int, mhp: int, draw_n: int, discard_n: int,
		qi: int = -1, qi_base: int = 0) -> void:
	var hp_l := refs.get("hp_text") as Label
	if hp_l != null:
		hp_l.text = str(hp)
	var draw_l := refs.get("draw_lbl") as Label
	if draw_l != null:
		draw_l.text = "%d" % draw_n
	var dis_l := refs.get("discard_lbl") as Label
	if dis_l != null:
		dis_l.text = "%d" % discard_n
	var qi_l := refs.get("qi") as Label
	if qi_l != null:
		qi_l.text = str(qi) if qi >= 0 else "气"
	if refs.has("qi_delta"):
		var qd := refs.get("qi_delta") as Label
		if qd != null:
			qd.text = ("+%d" % qi_base) if (qi >= 0 and qi_base > 0) else ""

## ══ 场景化机柜（2026-11-04 用户令「静态的进编辑器拖」）═════════════════════════
## 静态件住 QiVcCabinet.tscn（顶带/血心/气珠/抽弃堆——位置/大小编辑器里拖，贴图随
## .import 走编辑器可见）；build_top()/build_wings() 自此退役留档（build() 黑机柜仍供
## 地图屏底板）。wire_scene＝运行时只挂字体/描色（Noto 运行时加载，入不了场景）；
## collect_top/collect_wings＝把场景节点收成 refresh_top/refresh_wings 的引用字典
## （键名沿用旧制，刷新逻辑零改动）。2026-11-04 用户改裁「每个场景单独绘制」：
## 战斗屏把机柜件并入 QiVcBattle.tscn 自家一份（传屏根 self 即可），本 tscn 只剩地图屏用——
## 两屏起点同位、各自可拖，允许各自漂移（不再强同壳）。

## 唯一名取节点＋缺件护栏：场景树被拖散/改名时 get_node 返 null——这里点名缺谁，
## 不让 null 传下去变成「Cannot call method on a null value」天书
static func _uniq(cab: Control, n: String) -> Node:
	var x := cab.get_node("%" + n)
	if x == null:
		push_error("场景缺唯一名节点 %s——大概率是在场景树里拖动把节点改名/拖散了；回编辑器把它的名字和挂靠改回来" % n)
	return x

static func wire_scene(cab: Control) -> void:
	var xpc := Color(0.24, 0.18, 0.12)
	var floor_l := _uniq(cab, "FloorLbl") as Label
	if floor_l != null:
		QISTYLE.font(floor_l, QISTYLE.FS_SMALL, false)
		QISTYLE.text_color(floor_l, xpc)
	var xp_t := _uniq(cab, "XpText") as Label
	if xp_t != null:
		QISTYLE.font(xp_t, QISTYLE.FS_SMALL, false)
		QISTYLE.text_color(xp_t, xpc)
	var lvl := _uniq(cab, "LvlLbl") as Label
	if lvl != null:
		QISTYLE.font(lvl, 24, true)
		QISTYLE.text_color(lvl, Color(0.24, 0.20, 0.15))
	for n in ["HpText", "QiText"]:
		var l := _uniq(cab, n) as Label
		if l == null:
			continue
		QISTYLE.font(l, 32, true)
		QISTYLE.text_color(l, QISTYLE.CREAM)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
	for n in ["DrawCount", "DiscardCount"]:
		var c := _uniq(cab, n) as Label
		if c == null:
			continue
		# 2026-11-05 用户令：数值字高≈一张卡的 80%（卡约 76 高 → 56）
		QISTYLE.font(c, 46, true)
		QISTYLE.text_color(c, QISTYLE.CREAM)
		c.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		c.add_theme_constant_override("shadow_offset_x", 2)
		c.add_theme_constant_override("shadow_offset_y", 2)

static func collect_top(cab: Control) -> Dictionary:
	var track := _uniq(cab, "XpTrack") as Control
	return {
		"lvl": _uniq(cab, "LvlLbl"),
		"xp_fill": _uniq(cab, "XpFill"),
		"xp_text": _uniq(cab, "XpText"),
		"floor": _uniq(cab, "FloorLbl"),
		"track_w": track.size.x if track != null else 800.0,
	}

static func collect_wings(cab: Control) -> Dictionary:
	return {
		"hp_text": _uniq(cab, "HpText"),
		"draw_lbl": _uniq(cab, "DrawCount"),
		"discard_lbl": _uniq(cab, "DiscardCount"),
		"qi": _uniq(cab, "QiText"),
	}
