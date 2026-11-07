## VC 制战斗屏（2026-11-01 同壳轮：机柜/左右舷/顶带与地图屏共用 QiVcCabinet——
## 用户裁定「左右不变，只有中间的地图变成战斗区域」；顶带＝等级＋经验条，战斗中实时涨）。
## 中央视口＝战斗区：遭遇血池行（血池/池甲/余池/合围预警）→ 最新事件单行 →
## 敌阵（超 3 只分两排）→ 我方状态行（气/护甲/三式/连击）＋结束回合。
## 手牌＝屏级扇排（老手感全制）＋点击施放，照旧。
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const QI_CAB := preload("res://qiforge/QiVcCabinet.gd")
const VC := preload("res://qiforge/QiVcData.gd")
const VC_BATTLE := preload("res://qiforge/QiVcBattle.gd")
const CARD := preload("res://qiforge/QiCardStyle.gd")
const QIFONTS := preload("res://qiforge/QiFontBank.gd")
const ICONS := preload("res://qiforge/QiVcIcons.gd")
const TILT_SHADER := preload("res://qiforge/assets/card_tilt_glint.gdshader")
## 手牌倾斜（2026-11-03 用户令「我就想在新手第一关就见到倾斜效果」）：
## 每张手牌渲进 SubViewport（2× 超采保清晰）→ 贴图 ＋ 单应透视/边缘反光着色器。
## 内层因此是纯贴图——事件必须归外壳（手牌标准做法）；倾斜/光效由 _hand_lerp_tick 统一驱动。
const TILT_SS := 2.0          # 超采样倍数
const TILT_MARGIN := 1.18     # 显示矩形外扩（防倾斜切角）
const TILT_MAX := 0.50        # 倾斜最大量（喂 shader 的 tip）
const TILT_SMOOTH := 12.0     # 倾斜跟手平滑

## 手牌手感常量（照老战斗屏同款移植 2026-11-01 用户裁定「和之前一样」）：
## 扇位/帧 Lerp/焦点瞬弹/邻牌不让位/抽牌堆飞入/弃牌堆飞出全制照搬。
static var HAND_W := CARD.size_of("hand").x
static var HAND_H := CARD.size_of("hand").y
static var HAND_LIFT := 40.0                # 悬停抬升（原版 hoverHeightOffset=38，1:1 取 40）
const HAND_SHELL_EXTRA := 80.0              # 壳额外高（盖住弹起后超出卡面的上沿）
const HAND_POP := Vector2(1.5, 1.5)            # 悬停放大（VC hoverCardConfig scaleTo）
const DRAW_PILE_CENTER := Vector2(55.0, 1025.0)     # 牌堆位（老屏同位）
const DISCARD_PILE_CENTER := Vector2(1866.0, 1025.0)

signal battle_over(result: String)

var run: Dictionary = {}
var battle: RefCounted = null
var _pool_hp_max := 1

var _top_refs := {}             # 机柜顶带（等级/经验/层数）
var _wing_refs := {}            # 机柜舷位（血/抽/弃）
var _pool_bar: ProgressBar = null
var _pool_text: Label = null
var _enc_armor_label: Label = null
var _reserve_label: Label = null
var _merged_label: Label = null
var _event_lbl: Label = null
var _enemy_row: VBoxContainer = null
var _stat_left: GridContainer = null
var _stat_right: GridContainer = null
var _stat_vals: Dictionary = {}
var _end_btn: Button = null
var _coin_lbl: Label = null
var _play_all_btn: Button = null
var _stance_box: VBoxContainer = null
var _overlay: Control = null

var _hand_wraps: Array = []        # 屏级扇排（老屏同制：直接挂屏、视口坐标）
var _hand_focus: Control = null    # 悬停焦点（弹起位）
var _tilt_t := 0.0                 # 倾斜/光泽带驱动时钟

func setup(run_ref: Dictionary) -> void:
	run = run_ref
	battle = VC_BATTLE.new()
	battle.setup(run)
	_pool_hp_max = _pool_hp_total_max()
	battle.changed.connect(_refresh)
	battle.event.connect(_on_event)
	battle.ended.connect(_on_ended)

func _ready() -> void:
	_fill(self)
	_build()
	battle.start()
	await get_tree().process_frame   # 首帧手排未布局（_hand_row.size=0）——等一帧再刷重叠
	_refresh()

## 铺满父级（显式锚属性＋清偏移——代码实例化控件上 set_anchors_preset 实测不生效，
## 2026-11-01 probe_vc_ui 定案）
func _fill(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0

#region 构建
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0b0b0d")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(bg)
	add_child(bg)
	QI_CAB.build_plate(self)
	_top_refs = QI_CAB.build_top(self)
	_wing_refs = QI_CAB.build_wings(self)
	_build_center()

func _build_center() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(QI_CAB.VIEW.position.x + 24.0,
		QI_CAB.VIEW.position.y + QI_CAB.BAR_TOP + 8.0)
	box.size = Vector2(QI_CAB.VIEW.size.x - 48.0, 660.0)   # 底边止于手牌扇之上
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	# 2026-11-04 用户裁定：撤掉原版没有的信息（遭遇血池条/总池余/合围/事件行）——中区只留敌阵
	_enemy_row = VBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 14)
	_enemy_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enemy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_enemy_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_enemy_row)

	# —— VC 制属性列（左右舷各一排，每行 4 个）＋结束回合 ——
	_build_stat_columns()

## VC 制属性列（2026-11-04 用户裁定）：左＝临时属性（原版 PlayerStatContainer (temporary)），
## 右＝永久属性（permanent）；每行 4 个；数值先默认（百分比 100／计数 0），机制后补。
func _build_stat_columns() -> void:
	_stat_left = GridContainer.new()
	_stat_left.columns = 4
	_stat_left.position = Vector2(20.0, 96.0)
	_stat_left.add_theme_constant_override("h_separation", 8)
	_stat_left.add_theme_constant_override("v_separation", 8)
	_stat_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stat_left)
	_stat_right = GridContainer.new()
	_stat_right.columns = 4
	_stat_right.position = Vector2(1652.0, 96.0)
	_stat_right.add_theme_constant_override("h_separation", 8)
	_stat_right.add_theme_constant_override("v_separation", 8)
	_stat_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stat_right)
	_stat_vals = {}
	for s in VC.STATS:
		var def: Dictionary = s
		var parent: Control = _stat_left if String(def["side"]) == "L" else _stat_right
		_stat_vals[String(def["id"])] = _mk_stat_chip(parent, def)
	_end_btn = Button.new()
	_end_btn.text = "结束回合"
	_style_plaque(_end_btn)
	_end_btn.position = Vector2(1644.0, 800.0)
	_end_btn.size = Vector2(260.0, 61.0)
	_end_btn.pressed.connect(func(): battle.end_turn())
	add_child(_end_btn)
	_build_stance()
	_play_all_btn = Button.new()
	_play_all_btn.text = "打出全部"
	_style_plaque(_play_all_btn)
	_play_all_btn.position = Vector2(16.0, 800.0)
	_play_all_btn.size = Vector2(260.0, 61.0)
	_play_all_btn.pressed.connect(func(): battle.play_all())
	add_child(_play_all_btn)
	# _build_sort_panel()  # 2026-11-04 用户令：排序方式先去掉
	# 金币（原版 PlayerCoinStatView 挂在经验条下——右上角条下）
	var coin := TextureRect.new()
	coin.texture = ICONS.icon("greed")
	coin.position = Vector2(1470.0, 136.0)
	coin.size = Vector2(24.0, 24.0)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_SCALE
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(coin)
	_coin_lbl = _mk_label(self, "", QISTYLE.FS_BODY, Color(0.24, 0.18, 0.12), true)
	_coin_lbl.position = Vector2(1496.0, 134.0)
	_coin_lbl.size = Vector2(56.0, 28.0)
	_coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

## 墨金匾额按钮样式（自绘；AI 按钮不采用）
## 宣纸匾额贴图（程序画：深木框＋内金线＋纸面＋四角钉；九宫格用）
static var _plaque_cache: Dictionary = {}

static func _plaque_texture(fill: Color, frame: Color) -> ImageTexture:
	var key := "%s|%s" % [fill.to_html(), frame.to_html()]
	if _plaque_cache.has(key):
		return _plaque_cache[key]
	var w := 120
	var h := 76
	var r := 8.0
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cx := float(w) * 0.5
	var cy := float(h) * 0.5
	for y in h:
		for x in w:
			var dx: float = absf(float(x) + 0.5 - cx) - (cx - r)
			var dy: float = absf(float(y) + 0.5 - cy) - (cy - r)
			var ox: float = maxf(dx, 0.0)
			var oy: float = maxf(dy, 0.0)
			var d: float = sqrt(ox * ox + oy * oy) - r
			if d > 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var inset: float = -d
			var c: Color
			if inset < 5.0:
				c = frame.darkened(0.25)
			elif inset < 7.0:
				c = frame
			elif inset < 8.0:
				c = Color(0.62, 0.48, 0.22)
			else:
				var t: float = float(y) / float(h - 1)
				c = fill.lerp(fill.lightened(0.10), 1.0 - t)
			# 四角小钉
			var px: int = x
			var py: int = y
			var dot := (px >= 11 and px <= 15 and py >= 11 and py <= 15) or (px >= w - 16 and px <= w - 12 and py >= 11 and py <= 15) or (px >= 11 and px <= 15 and py >= h - 15 and py <= h - 11) or (px >= w - 16 and px <= w - 12 and py >= h - 15 and py <= h - 11)
			if dot:
				c = frame.darkened(0.1)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_plaque_cache[key] = tex
	return tex

func _style_plaque(b: Button) -> void:
	# AI 宣纸牌匾（2026-11-04 用户供图）：整图拉伸（接近原生比例，不九宫格以免拉歪角饰）
	var tex := QI_CAB._art("btn_paper")
	if tex == null:
		return
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.content_margin_left = 24
		sb.content_margin_right = 24
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		if state == "hover":
			sb.modulate_color = Color(1.10, 1.08, 1.04)
		elif state == "pressed":
			sb.modulate_color = Color(0.86, 0.84, 0.80)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.20, 0.15, 0.10))
	b.add_theme_color_override("font_hover_color", Color(0.12, 0.09, 0.06))
	b.add_theme_color_override("font_pressed_color", Color(0.12, 0.09, 0.06))

## 式区（2026-11-04）：气珠上方一列、无框、自绘剑势图标（1 层 1 枚，自下往上长）
func _build_stance() -> void:
	_stance_box = VBoxContainer.new()
	_stance_box.add_theme_constant_override("separation", 4)
	_stance_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stance_box)

func _refresh_stance() -> void:
	if _stance_box == null or battle == null:
		return
	for c in _stance_box.get_children():
		c.queue_free()
	var st: Dictionary = battle.player.get("stances", {})
	var tex_of := {"劈": "c_q1", "刺": "c_q2", "撩": "c_q3"}
	var shown := 0
	for k in ["劈", "刺", "撩"]:
		var n := int(st.get(k, 0))
		for _i in n:
			if shown >= 9:
				break
			var t := TextureRect.new()
			t.texture = QI_CAB._art(tex_of[k])
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.custom_minimum_size = Vector2(60.0, 60.0)
			t.size = Vector2(60.0, 60.0)
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stance_box.add_child(t)
			shown += 1
		if shown >= 9:
			break
	_stance_box.position = Vector2(1720.0, 640.0 - _stance_box.get_combined_minimum_size().y)

## 手牌排序面板（原版 SortHandButton (parent) 位≈(1757,797)）：标题＋法力/颜色两键，点了即重排
func _build_sort_panel() -> void:
	var sortp := Panel.new()
	sortp.position = Vector2(1756.0, 740.0)
	sortp.size = Vector2(158.0, 150.0)
	sortp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0, 0, 0, 0.82)
	ssb.border_color = QISTYLE.AMBER
	ssb.set_border_width_all(2)
	ssb.set_corner_radius_all(8)
	sortp.add_theme_stylebox_override("panel", ssb)
	add_child(sortp)
	var title := _mk_label(sortp, "手牌排序", QISTYLE.FS_SMALL, QISTYLE.TEXT_MAIN)
	title.position = Vector2(0.0, 6.0)
	title.size = Vector2(158.0, 24.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 2:
		var b := Button.new()
		b.text = "法力" if i == 0 else "颜色"
		QISTYLE.apply_ghost(b)
		b.position = Vector2(10.0, 34.0 + float(i) * 54.0)
		b.size = Vector2(138.0, 48.0)
		b.pressed.connect(_on_sort_pressed.bind("mana" if i == 0 else "color"))
		sortp.add_child(b)

func _on_sort_pressed(mode: String) -> void:
	battle.sort_hand(mode)

## 单个属性图标位：72×72 深底金框，上自绘像素图标、下数值；返回值 Label（刷新用）
func _mk_stat_chip(parent: Control, def: Dictionary) -> Label:
	var color := Color(String(def["color"]))
	var p := Panel.new()
	p.custom_minimum_size = Vector2(56.0, 56.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.05, 0.55)
	sb.border_color = Color(color.r, color.g, color.b, 0.60)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var tex := TextureRect.new()
	tex.texture = ICONS.icon(String(def["id"]))
	tex.position = Vector2(14.0, 2.0)
	tex.size = Vector2(28.0, 28.0)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tex)
	var v := Label.new()
	v.text = "0"
	QISTYLE.font(v, QISTYLE.FS_SMALL, true)
	QISTYLE.text_color(v, QISTYLE.CREAM)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.position = Vector2(0.0, 28.0)
	v.size = Vector2(56.0, 24.0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	return v

func _mk_label(parent: Control, text: String, size: int, color: Color, big := false) -> Label:
	var l := Label.new()
	l.text = text
	QISTYLE.font(l, size, big)
	QISTYLE.text_color(l, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l
#endregion

#region 刷新（changed 单一入口）
func _refresh() -> void:
	if battle == null:
		return
	# 顶带：等级/经验（击杀实时涨——VC 制曲线归并）
	var lp: Dictionary = VC.level_progress(int(run.get("level", 1)),
		int(run.get("xp", 0)) + int(battle.xp_gained))
	QI_CAB.refresh_top(_top_refs, int(lp["lvl"]), int(lp["xp"]), int(run.get("floor", 0)),
		VC.FLOORS.size(), int(lp["need"]))
	_coin_lbl.text = str(int(run.get("copper", 0)))
	# 舷位：血心＋抽/弃计数＋气珠（气值／每回合回复）
	var p: Dictionary = battle.player
	QI_CAB.refresh_wings(_wing_refs, int(p["hp"]), int(p["mhp"]),
		battle.draw_pile.size(), battle.discard_pile.size(),
		int(p["qi"]), int(p.get("qi_base", 0)))
	# 血池行已撤（2026-11-04 原版无此信息）——只保留刷新敌阵
	_refresh_enemies()
	# 属性列（VC 制 18 项：左临时/右永久；默认 100%/0）
	var stats: Dictionary = run.get("stats", {})
	for s in VC.STATS:
		var sid := String(s["id"])
		var val_lbl: Label = _stat_vals.get(sid)
		if val_lbl == null:
			continue
		var val := int(stats.get(sid, int(s["base"])))
		val_lbl.text = ("%d%%" % val) if bool(s["pct"]) else str(val)
	_refresh_stance()
	_rebuild_hand()
	_end_btn.disabled = String(battle.phase) != "player"

func _refresh_enemies() -> void:
	for c in _enemy_row.get_children():
		c.queue_free()
	var acts: Array = battle.encounter["active"]
	var per := acts.size() if acts.size() <= 3 else (acts.size() + 1) / 2
	var row := _mk_enemy_hbox()
	_enemy_row.add_child(row)
	for i in acts.size():
		if i == per and per < acts.size():
			row = _mk_enemy_hbox()
			_enemy_row.add_child(row)
		var e: Dictionary = acts[i]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 原版制（2026-11-04）：敌人＝剪影＋头顶数字（护甲优先），无名字/血条/意图长文
		var armor: int = int(e.get("armor", 0))
		var num := _mk_label(box, str(armor) if armor > 0 else str(int(e["hp"])),
			QISTYLE.FS_BIG, QISTYLE.CREAM, true)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sil := TextureRect.new()
		sil.texture = ICONS.silhouette(_enemy_tint(String(e["name"])))
		sil.custom_minimum_size = Vector2(96.0, 132.0)
		sil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sil.stretch_mode = TextureRect.STRETCH_SCALE
		sil.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(sil)
		var intent := _mk_label(box, battle.intent_name(e), QISTYLE.FS_SMALL, QISTYLE.TEXT_SUB)
		intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(box)

## 敌人剪影色（按名字哈希分色，敌种可辨；亮度压过近黑底）
func _enemy_tint(nm: String) -> Color:
	var palette: Array = [Color("8f9aa8"), Color("9a86a8"), Color("a87f7f"),
		Color("7fa890"), Color("a8946e")]
	return palette[absi(nm.hash()) % palette.size()]

func _mk_enemy_hbox() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 20)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
#endregion

#region 手牌（老战斗屏手感全制移植 2026-11-01 用户裁定「和之前一样」＋改点击施放）
## 屏级扇排＋帧 Lerp 逼近（k=Δ×7）＋焦点瞬弹（只弹内层卡面 ×1.5，壳稳定）＋邻牌不让位；
## 新抽卡自抽牌堆位飞入；消失卡（打出/冲弃）飞向弃牌堆位缩小淡出（0.32s、stagger 0.05）。
func _rebuild_hand() -> void:
	var old_uids := {}
	for w in _hand_wraps:
		old_uids[int(w.get_meta("hand_uid", -1))] = true
	var new_uids := {}
	for card in battle.hand:
		new_uids[int(card["uid"])] = true
	var fly_i := 0
	for w in _hand_wraps:
		if not new_uids.has(int(w.get_meta("hand_uid", -1))):
			_anim_card_fly(w, float(fly_i) * 0.05)
			fly_i += 1
		else:
			w.queue_free()
	_hand_wraps = []
	for card in battle.hand:
		var w := Control.new()
		w.name = "HandCard%d" % int(card["uid"])
		# 壳加高盖住「原位＋弹起位」两段：壳管一切事件（悬停稳定＋弹起卡可点＋底部空区不误触）
		w.size = Vector2(HAND_W, HAND_H + HAND_LIFT + HAND_SHELL_EXTRA)
		w.set_meta("hand_uid", int(card["uid"]))
		var vis: Control = _make_tilt_view(CARD.tcg_def_of(card["def"]))
		vis.position = _vis_rest(vis)
		w.set_meta("vc_card", vis.get_meta("vc_card"))
		w.add_child(vis)
		var the_uid := int(card["uid"])
		var the_wrap := w
		w.mouse_filter = Control.MOUSE_FILTER_STOP
		w.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_play_clicked(the_uid))
		w.mouse_entered.connect(func() -> void: _set_hand_focus(the_wrap))
		# 焦点收起不走 mouse_exited（2026-11-03 修「放大后移上去缩回」）：弹起的卡上半截
		# 探出壳矩形会误触离开事件——改 StS2 制每帧轮询＋迟滞（见 _hand_lerp_tick 焦点保持判据）
		add_child(w)
		_hand_wraps.push_back(w)
		if not old_uids.has(the_uid):
			# 新抽卡：起点＝抽牌堆中心（卡面视觉位），飞入手位由帧 Lerp 接管
			w.position = DRAW_PILE_CENTER - Vector2(HAND_W, HAND_H) * 0.5 - Vector2(0.0, HAND_LIFT)
			w.scale = Vector2(0.35, 0.35)
			w.rotation = randf_range(-0.22, 0.22)
			w.modulate.a = 0.25
			w.set_meta("fly_in", true)
			var twa := create_tween()
			twa.tween_property(w, "modulate:a", 1.0, 0.3)
	_hand_focus = null
	_layout_hand(false)
	_refresh_playability()

## 消失卡飞出：飞向弃牌堆位缩小淡出（打出/冲弃同走——打出进弃牌堆语义同）
func _anim_card_fly(w: Control, delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(w, "position", DISCARD_PILE_CENTER - Vector2(HAND_W, HAND_H) * 0.5
		- Vector2(0.0, HAND_LIFT), 0.32)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(w, "scale", Vector2(0.3, 0.3), 0.32)
	tw.parallel().tween_property(w, "rotation", 0.15, 0.32)
	tw.parallel().tween_property(w, "modulate:a", 0.0, 0.3).set_delay(0.06)
	tw.tween_callback(w.queue_free)

func _play_clicked(card_uid: int) -> void:
	if String(battle.phase) != "player" or result_pending():
		return
	for c in battle.hand:
		if int(c["uid"]) == card_uid:
			if not battle.can_play(c):
				return
			break
	_set_hand_focus(null)
	battle.play_card(card_uid)   # changed → _refresh → _rebuild_hand（打出的卡走飞出动画）

func result_pending() -> bool:
	return _overlay != null and is_instance_valid(_overlay)

## 可打性（老屏同制）：法力不足＝整卡压灰＋费用徽描边转红，实时随 changed 连锁
func _refresh_playability() -> void:
	var i := 0
	for w in _hand_wraps:
		var card: Dictionary = battle.hand[i] if i < battle.hand.size() else {}
		i += 1
		if card.is_empty() or w.get_child_count() == 0:
			continue
		var ok: bool = battle.can_play(card)
		var vis: Control = w.get_child(0)
		vis.modulate = Color(1, 1, 1, 1.0) if ok else Color(0.52, 0.52, 0.52, 0.92)
		var pip: Node = (w.get_meta("vc_card") as Node).find_child("CostPip", false, false)
		if pip != null:
			var icon: Node = pip.find_child("QiIcon", false, false)
			if icon is TextureRect:
				(icon as TextureRect).modulate = Color(1, 1, 1, 1) if ok else Color(1.0, 0.55, 0.5, 1.0)

## 手牌布局（2026-11-04 用户令「手牌系统做完」）：扇形＋拱形＋相让＋右压左 z 序；
## 本函数只落目标位（meta tgt_*），动画统一走 _process 帧 Lerp；焦点卡拍平回正＋内层弹起。
func _layout_hand(animate: bool) -> void:
	var n := _hand_wraps.size()
	if n == 0:
		return
	var mid := float(n - 1) / 2.0
	var vp := get_viewport_rect().size
	var fi := -1
	if _hand_focus != null and is_instance_valid(_hand_focus):
		fi = _hand_wraps.find(_hand_focus)
	# 相让（用户口述确认「有相让」）：悬停卡左右邻牌各退半个卡宽；左右对称，整行不跑位
	var extra := HAND_W * 0.35 if fi >= 0 else 0.0
	# 无上限手牌：行宽封顶，牌多就压缩间距（挤在一起）
	var step := minf(vp.x * 0.075, (860.0 - HAND_W) / maxf(1.0, float(n - 1)))
	for i in n:
		var w: Control = _hand_wraps[i]
		var shift := 0.0
		if fi >= 0 and i != fi:
			shift = -extra if i < fi else extra
		var x := vp.x * 0.5 + (i - mid) * step + shift - HAND_W * 0.5
		var t := (float(i) - mid) / maxf(1.0, mid)
		var y := vp.y * 0.63 + HAND_H - (HAND_H + HAND_LIFT + HAND_SHELL_EXTRA) - 30.0 * (1.0 - t * t)
		var rot := (i - mid) * 0.075   # 扇形（原版实测端卡约 ±10~12°）
		var vis: Control = w.get_child(0)
		vis.pivot_offset = Vector2(vis.size.x * 0.5, (vis.size.y - HAND_H) * 0.5 + HAND_H * 0.5)
		w.pivot_offset = Vector2(HAND_W * 0.5, HAND_H + HAND_LIFT + HAND_SHELL_EXTRA)
		var is_focus := fi == i
		if is_focus:
			w.rotation = 0.0
			w.scale = Vector2.ONE
			w.z_index = 60
			vis.z_index = 0
			# 弹起不再瞬跳（2026-11-03 用户裁定：放大要有动画）——目标值由 _hand_lerp_tick 逼近
		else:
			w.z_index = i   # 右压左（越靠右越上层，同原版）
			vis.z_index = 0
		if not animate and not w.has_meta("fly_in"):
			w.position = Vector2(x, y)
			w.rotation = rot if not is_focus else 0.0
			w.scale = Vector2.ONE
			if not is_focus:
				vis.scale = Vector2.ONE
				vis.rotation = 0.0
				vis.position = _vis_rest(vis)
		w.set_meta("tgt_pos", Vector2(x, y))
		w.set_meta("tgt_rot", rot if not is_focus else 0.0)

func _process(delta: float) -> void:
	_hand_lerp_tick(delta)

func _hand_lerp_tick(delta: float) -> void:
	const K := 7.0
	var snap_d := 0.75
	for w in _hand_wraps:
		var hw: Control = w
		if not hw.has_meta("tgt_pos"):
			continue
		var tp: Vector2 = hw.get_meta("tgt_pos")
		var tr: float = hw.get_meta("tgt_rot")
		var k: float = minf(delta * K, 1.0)
		hw.position = hw.position.lerp(tp, k)
		hw.rotation = lerpf(hw.rotation, tr, k)
		hw.scale = hw.scale.lerp(Vector2.ONE, k)
		if hw != _hand_focus:
			var vis: Control = hw.get_child(0)
			vis.scale = vis.scale.lerp(Vector2.ONE, k)
			vis.rotation = lerpf(vis.rotation, 0.0, k)
			vis.position = vis.position.lerp(_vis_rest(vis), k)
		else:
			# 焦点卡：弹起 ×HAND_POP 动画逼近（与归位同速曲线）
			var visf: Control = hw.get_child(0)
			var rest: Vector2 = _vis_rest(visf)
			visf.scale = visf.scale.lerp(HAND_POP, k)
			visf.rotation = lerpf(visf.rotation, 0.0, k)
			visf.position = visf.position.lerp(Vector2(rest.x, rest.y - HAND_LIFT), k)
		if hw.position.distance_squared_to(tp) < snap_d and absf(hw.rotation - tr) < 0.001:
			hw.position = tp
			hw.rotation = tr
			hw.scale = Vector2.ONE
			if hw != _hand_focus:
				var vis2: Control = hw.get_child(0)
				vis2.scale = Vector2.ONE
				vis2.rotation = 0.0
				vis2.position = _vis_rest(vis2)
	# —— 倾斜/光效驱动（2026-11-03）：鼠标指哪边哪边朝里倒＋近侧边框反光；离开回正 ——
	_tilt_t += delta
	var mouse: Vector2 = get_global_mouse_position()
	# 焦点保持判据（StS2 制轮询＋迟滞）：命中区＝壳矩形 ∪ 弹起后卡面矩形——
	# 鼠标在弹起的卡上半区（探出壳外）不丢焦点；两个矩形都离开才收起
	# 悬停进入＝每帧轮询卡面矩形（从最右/最上层往下找），不依赖壳的 mouse_entered
	if _hand_focus == null and not _hand_wraps.is_empty() and not has_meta("shot_no_hover"):
		for i in range(_hand_wraps.size() - 1, -1, -1):
			var ww: Control = _hand_wraps[i]
			if ww.get_child_count() == 0:
				continue
			var vv: Control = ww.get_child(0)
			var rr: Rect2 = vv.get_global_rect()
			var mm: float = (TILT_MARGIN - 1.0) * HAND_W * 0.5
			if rr.grow(-mm).has_point(mouse):
				_set_hand_focus(ww)
				break
	if _hand_focus != null and is_instance_valid(_hand_focus) and _hand_focus.get_child_count() > 0:
		var fvis: Control = _hand_focus.get_child(0)
		var hold: bool = (_hand_focus as Control).get_global_rect().grow(2.0).has_point(mouse) \
			or fvis.get_global_rect().grow(2.0).has_point(mouse)
		if not hold and not has_meta("shot_no_hold"):
			_set_hand_focus(null)
	for w in _hand_wraps:
		var hw2: Control = w
		if hw2.get_child_count() == 0:
			continue
		var tv: Control = hw2.get_child(0)
		var mat: ShaderMaterial = tv.material as ShaderMaterial
		if mat == null:
			continue
		var r: Rect2 = tv.get_global_rect()
		var ctr: Vector2 = r.position + r.size * 0.5
		# 归一用「当前视觉卡面」半宽高（折掉外扩 margin；含弹起缩放）——
		# 修「放到顶部没倾斜」：旧版按静止半高判 ±1，弹起后探出区全被误判不在卡内
		var half: Vector2 = r.size / (2.0 * TILT_MARGIN)
		var nv: Vector2 = Vector2((mouse.x - ctr.x) / maxf(1.0, half.x), (mouse.y - ctr.y) / maxf(1.0, half.y))
		var inside: bool = absf(nv.x) < 1.0 and absf(nv.y) < 1.0
		var tip_tgt := Vector2.ZERO
		if inside:
			tip_tgt = -Vector2(clampf(nv.x, -1.0, 1.0), clampf(nv.y, -1.0, 1.0)) * TILT_MAX
		var sheen_tgt: float = fmod(_tilt_t * 0.12, 1.4) - 0.2
		var kk: float = clampf(delta * TILT_SMOOTH, 0.0, 1.0)
		var tip: Vector2 = (tv.get_meta("tip", Vector2.ZERO) as Vector2).lerp(tip_tgt, kk)
		var sheen: float = lerpf(float(tv.get_meta("sheen", 0.2)), sheen_tgt, kk)
		var hov: float = lerpf(float(tv.get_meta("hov", 0.0)), 1.0 if inside else 0.0, kk)
		tv.set_meta("tip", tip)
		tv.set_meta("sheen", sheen)
		tv.set_meta("hov", hov)
		mat.set_shader_parameter("tip_x", tip.x)
		mat.set_shader_parameter("tip_y", tip.y)
		mat.set_shader_parameter("sheen_phase", sheen)
		mat.set_shader_parameter("hover", hov)

## 手牌倾斜视图（2026-11-03 用户令）：真卡渲进 SubViewport（2× 超采保清晰）→
## 贴图＋单应透视/边缘反光着色器。内层＝纯贴图，事件全归外壳（手牌标准做法）。
func _make_tilt_view(def: Dictionary) -> TextureRect:
	var vp := SubViewport.new()
	vp.size = Vector2i(roundi(HAND_W * TILT_SS), roundi(HAND_H * TILT_SS))
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	var card: Control = CARD.make_tcg_card(def, "hand")
	card.theme = QIFONTS.default_theme()   # SubViewport 不吃根窗主题
	card.scale = Vector2(TILT_SS, TILT_SS)
	vp.add_child(card)
	var mat := ShaderMaterial.new()
	mat.shader = TILT_SHADER
	mat.set_shader_parameter("strength", 0.09)
	mat.set_shader_parameter("uv_scale", TILT_MARGIN)
	mat.set_shader_parameter("glint_strength", 1.0)
	var tex := TextureRect.new()
	tex.name = "TiltView"
	tex.add_child(vp)   # 视口随贴图层同生共死
	tex.texture = vp.get_texture()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.size = Vector2(HAND_W, HAND_H) * TILT_MARGIN
	tex.material = mat
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 内层纯贴图——事件全归外壳
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tex.set_meta("vc_card", card)
	tex.set_meta("tip", Vector2.ZERO)
	tex.set_meta("sheen", 0.2)
	tex.set_meta("hov", 0.0)
	return tex

## 贴图层静止位：贴图比卡面外扩一圈 margin——把内区卡面对回壳的卡位
func _vis_rest(vis: Control) -> Vector2:
	return Vector2(-(vis.size.x - HAND_W) * 0.5, HAND_LIFT + HAND_SHELL_EXTRA - (vis.size.y - HAND_H) * 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed \
			or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _hand_focus == null or not is_instance_valid(_hand_focus) or _hand_focus.get_child_count() == 0:
		return
	var vis: Control = _hand_focus.get_child(0)
	var r: Rect2 = vis.get_global_rect()
	var m: float = (TILT_MARGIN - 1.0) * HAND_W * 0.5
	if r.grow(-m).has_point((event as InputEventMouseButton).position):
		_play_clicked(int(_hand_focus.get_meta("hand_uid", -1)))
		accept_event()

func _set_hand_focus(w: Control) -> void:
	if _hand_focus == w:
		return
	_hand_focus = w
	_layout_hand(true)
#endregion

## 战报事件（原版事件行已撤——此处留钩子，后面接飘字/日志）
func _on_event(text: String) -> void:
	if _event_lbl != null:
		_event_lbl.text = text

func _on_ended(result: String) -> void:
	_refresh()
	_overlay = Control.new()
	_overlay.z_index = 100   # 盖住手牌（手牌 z 序已抬到 0..60）
	_overlay.anchor_left = 0.0
	_overlay.anchor_top = 0.0
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	_fill(scrim)
	_overlay.add_child(scrim)
	var center := VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -160.0
	center.offset_right = 160.0
	center.offset_top = -90.0
	center.offset_bottom = 90.0
	center.add_theme_constant_override("separation", 18)
	_overlay.add_child(center)
	var title := _mk_label(center, "胜利！" if result == "win" else "败北", 46,
		QISTYLE.JADE if result == "win" else QISTYLE.RED, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := Button.new()
	btn.text = "返回地图" if result == "win" else "返回地图（重整旗鼓）"
	QISTYLE.apply_primary(btn)
	btn.pressed.connect(func(): battle_over.emit(String(result)))
	center.add_child(btn)
	add_child(_overlay)

## 战后写回源（宿主取 run 状态用）
func player_out() -> Dictionary:
	return battle.player_out()

## 血池读数：活跃存活＋总池全员（遭遇总剩余血）
func _pool_hp_now() -> int:
	var n := 0
	for e in battle.encounter["active"]:
		if e["alive"]:
			n += int(e["hp"])
	for eid in battle.encounter["reserve"]:
		n += int(VC.ENEMIES[String(eid)]["hp"])
	return n

func _pool_hp_total_max() -> int:
	var n := 0
	for eid in VC.ENCOUNTERS[String(VC.DUNGEON[clampi(int(run.get("enc", 0)), 0, VC.DUNGEON.size() - 1)])]["pool"]:
		n += int(VC.ENEMIES[String(eid)]["hp"])
	return n
