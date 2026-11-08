## VC 制升级三选一（2026-11-01 奖励轮→教程单卡轮＋醍醐灌顶特效）。
## 常规＝三张工厂真卡（detail 档）＋原版三钮：跳过换经验／重选／排除（次数商店未开恒 0 置灰）。
## 单卡天赐模式（教程层）＝只摆一张固定卡、三钮隐藏——VC 教学卡组制（Deck_Tutorial 孤张 Knife）
## ＋2026-11-01 用户口述「只可以选一个」。
## 选卡特效＝醍醐灌顶（用户裁定：不做宝石掉落）：卡升起泛金→金光光柱自顶贯注→
## 金粒迸散坠落（灌）→白闪＋屏震，约 0.85s 后结转。全引擎原生件（Tween/GradientTexture2D/
## CPUParticles2D），零外部素材（美术三步制·自绘档）。
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const CARD := preload("res://qiforge/QiCardStyle.gd")
const VC := preload("res://qiforge/QiVcData.gd")
const QITIP := preload("res://qiforge/QiTooltip.gd")
const TILTV := preload("res://qiforge/QiCardTilt.gd")

signal done
signal card_chosen(cid: String)   # 2026-11-08 对齐原版：选卡落点由宿主定（战斗屏→进手牌＋免一次费；地图侧→进牌组）

var run: Dictionary = {}
var _force_gifts: Array = []    # 单卡天赐队列（教程）；空＝常规三选一
var _rng := RandomNumberGenerator.new()
var _offers: Array = []
var _panel: PanelContainer = null
var _card_box: HBoxContainer = null
var _skip_btn: Button = null
var _reroll_btn: Button = null
var _banish_btn: Button = null
var _count_lbl: Label = null
var _banish_mode := false
var _animating := false
var _hover_vis: Control = null
var _hover_cid := ""

func setup(run_ref: Dictionary, force_cards: Array = []) -> void:
	run = run_ref
	_force_gifts = force_cards.duplicate()

func _ready() -> void:
	# 2026-11-08 用户令「弹窗开＝全世界冻结」：WHEN_PAUSED＝暂停与否都处理——
	# 战斗屏开此弹窗时 get_tree().paused=true 冻结世界（剑/珠冻在半空），
	# 弹窗内 Tween/点击照跑；地图侧使用不暂停时行为不变
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	z_index = 300   # 盖住手牌/HUD（它们各自有 z），升级时不显示世界
	_fill(self)
	_rng.seed = int(run.get("seed", 1)) + int(run.get("xp", 0)) * 31 + int(run.get("level", 1)) * 7
	_build()
	_roll()

func _fill(c: Control) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.09, 0.08, 0.07, 1.0)   # 不透明：升级时不显示手牌/敌人（照参考蓝本）
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP   # 模态：挡住底屏点击
	_fill(scrim)
	add_child(scrim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -540.0
	_panel.offset_right = 540.0
	_panel.offset_top = -320.0
	_panel.offset_bottom = 320.0
	_panel.add_theme_stylebox_override("panel", QISTYLE.panel(0.95))
	# 金框画在**独立覆盖层**上：PanelContainer 会强制子节点铺满，直接挂上去会被拉成整块
	var frame_layer := Control.new()
	frame_layer.set_anchors_preset(Control.PRESET_CENTER)
	frame_layer.offset_left = -540.0
	frame_layer.offset_top = -320.0
	frame_layer.offset_right = 540.0
	frame_layer.offset_bottom = 320.0
	frame_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame_layer)
	_add_gold_frame(frame_layer)
	add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	_panel.add_child(v)

	# 标题：居中大字（2026-11-08 照参考蓝本：升级！／选择一份奖励）
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 2)
	v.add_child(tbox)
	var t_main := Label.new()
	t_main.text = "升级！"
	t_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	QISTYLE.font(t_main, QISTYLE.FS_TITLE + 20, true)
	QISTYLE.text_color(t_main, QISTYLE.AMBER_BRIGHT)
	tbox.add_child(t_main)
	var t_sub := Label.new()
	t_sub.text = "选择一份奖励"
	t_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	QISTYLE.font(t_sub, QISTYLE.FS_BODY + 6, true)
	QISTYLE.text_color(t_sub, Color(0.90, 0.86, 0.76))
	tbox.add_child(t_sub)
	_count_lbl = Label.new()
	_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	QISTYLE.font(_count_lbl, QISTYLE.FS_SMALL)
	QISTYLE.text_color(_count_lbl, QISTYLE.TEXT_SUB)
	tbox.add_child(_count_lbl)

	_card_box = HBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 40)
	_card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_card_box)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 18)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(btn_row)
	_skip_btn = Button.new()
	QISTYLE.apply_ghost(_skip_btn)
	_skip_btn.pressed.connect(_on_skip)
	btn_row.add_child(_skip_btn)
	_reroll_btn = Button.new()
	QISTYLE.apply_ghost(_reroll_btn)
	_reroll_btn.pressed.connect(_on_reroll)
	btn_row.add_child(_reroll_btn)
	_banish_btn = Button.new()
	QISTYLE.apply_ghost(_banish_btn)
	_banish_btn.pressed.connect(_on_banish)
	btn_row.add_child(_banish_btn)

func _roll() -> void:
	_banish_mode = false
	if not _force_gifts.is_empty():
		_offers = [String(_force_gifts[0])]
	else:
		_offers = VC.reward_offers(_rng, int(run.get("level", 1)), run.get("deck", []))
	_refresh_cards()
	_refresh_btns()

func _refresh_cards() -> void:
	for c in _card_box.get_children():
		c.queue_free()
	var cs := CARD.size_of("detail")
	for cid in _offers:
		var cdef: Dictionary = CARD.tcg_def_of(VC.CARDS[String(cid)])
		# 与手牌同一套斜切视图：卡随指针倾斜（2026-11-08 用户令）
		var vis: Button = Button.new()
		vis.flat = true
		vis.size = cs
		vis.custom_minimum_size = cs
		var tv: TextureRect = TILTV.make(cdef, "detail", cs.x, cs.y)
		tv.position = Vector2(-(tv.size.x - cs.x) * 0.5, -(tv.size.y - cs.y) * 0.5)
		vis.add_child(tv)
		vis.set_meta("tilt", tv)
		var the_cid := String(cid)
		vis.set_meta("offer_id", the_cid)
		vis.pressed.connect(func() -> void: _card_clicked(the_cid))
		# 悬停放大＋浮窗（2026-11-08 用户令：和手牌一样）
		vis.mouse_entered.connect(func() -> void: _offer_hover(vis, the_cid, true))
		vis.mouse_exited.connect(func() -> void: _offer_hover(vis, the_cid, false))
		vis.pivot_offset = cs * 0.5
		_card_box.add_child(vis)

func _process(delta: float) -> void:
	var mouse := get_global_mouse_position()
	# 悬停收起：卡与浮窗都不在才收（移到浮窗上保持，2026-11-08 与手牌对齐）
	if _hover_vis != null:
		if not is_instance_valid(_hover_vis):
			_hover_vis = null
		else:
			var over_card := _hover_vis.get_global_rect().grow(6.0).has_point(mouse)
			if not over_card and not QITIP.pointer_over_panels(mouse):
				var tw2 := create_tween()
				tw2.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw2.tween_property(_hover_vis, "scale", Vector2.ONE, 0.12)
				QITIP.hide_for(_hover_vis)
				_hover_vis = null
	for c in _card_box.get_children():
		var tv = c.get_meta("tilt", null)
		if tv != null:
			TILTV.drive(tv, mouse, delta)

func _card_clicked(cid: String) -> void:
	if _animating:
		return
	if _banish_mode:
		if int(run.get("banishes", 0)) <= 0:
			return
		run["banishes"] = int(run.get("banishes", 0)) - 1
		_offers.erase(cid)
		_banish_mode = false
		if _offers.is_empty():
			_consume_pick()   # 全排除光＝本次无所得，直接下一题
		else:
			_refresh_cards()
			_refresh_btns()
		return
	if not _force_gifts.is_empty():
		_force_gifts.pop_front()
	# 2026-11-08 用户令：不要特效——点完直接结算、关窗（牌由宿主收进手牌/牌组）
	card_chosen.emit(cid)
	_animating = true
	_after_anim()

## 醍醐灌顶（选卡特效，2026-11-01 用户裁定）：选中卡升起泛金，金光自顶贯注成柱，
## 金粒自卡位迸散升腾后坠落（「灌」意），白闪＋轻屏震；约 0.85s 后结转下一题。
func _play_tidi(cid: String) -> void:
	var card_btn: Control = null
	for c in _card_box.get_children():
		if not c.is_queued_for_deletion() and String(c.get_meta("offer_id", "")) == cid:
			card_btn = c
			break
	if card_btn == null:
		_after_anim()
		return
	print("TIDI start ", cid)
	for c in _card_box.get_children():
		if c != card_btn:
			var tw_o := create_tween()
			tw_o.tween_property(c, "modulate:a", 0.0, 0.25)
	# ① 卡升起＋泛金
	# 先把选中卡从 HBox 里摘出来（容器每帧重排会把位置的 tween 顶回去 → 抖动/回弹）
	var gp0: Vector2 = card_btn.global_position
	_card_box.remove_child(card_btn)
	add_child(card_btn)
	card_btn.global_position = gp0
	card_btn.z_index = 70
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card_btn, "position:y", card_btn.position.y - 46.0, 0.45)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_btn, "modulate", Color(1.55, 1.32, 0.72), 0.45)
	# ② 金光光柱：自屏顶贯到卡位（GradientTexture2D 竖贯渐变，顶淡底浓＝「灌」下来）
	var gp: Vector2 = card_btn.global_position + card_btn.size * 0.5
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.55, 0.0))
	grad.set_color(1, Color(1.0, 0.84, 0.4, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var beam := TextureRect.new()
	beam.texture = gt
	beam.position = Vector2(gp.x - 70.0, 0.0)
	beam.size = Vector2(140.0, gp.y)
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam.z_index = 50
	beam.modulate.a = 0.0
	add_child(beam)
	var twb := create_tween()
	twb.tween_property(beam, "modulate:a", 1.0, 0.22)
	twb.tween_interval(0.3)
	twb.tween_property(beam, "modulate:a", 0.0, 0.3)
	twb.tween_callback(beam.queue_free)
	# ③ 金粒迸散（CPUParticles2D 单发；先升腾后受重力坠落＝醍醐灌顶的「灌」）
	var pts := CPUParticles2D.new()
	pts.position = gp
	pts.one_shot = true
	pts.amount = 26
	pts.lifetime = 0.7
	pts.explosiveness = 0.9
	pts.direction = Vector2(0, -1)
	pts.spread = 55.0
	pts.initial_velocity_min = 260.0
	pts.initial_velocity_max = 520.0
	pts.gravity = Vector2(0, 460)
	pts.scale_amount_min = 2.0
	pts.scale_amount_max = 4.5
	pts.color = Color(1.0, 0.85, 0.45)
	pts.z_index = 60
	add_child(pts)
	pts.emitting = true
	# ④ 白闪＋轻屏震
	var flash := ColorRect.new()
	flash.color = Color(1, 0.95, 0.8, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(flash)
	flash.z_index = 40
	add_child(flash)
	var twf := create_tween()
	twf.tween_property(flash, "color:a", 0.32, 0.12)
	twf.tween_property(flash, "color:a", 0.0, 0.35)
	twf.tween_callback(flash.queue_free)
	var px := _panel.position.x
	var pj := create_tween()
	pj.tween_interval(0.1)
	pj.tween_property(_panel, "position:x", px + 7.0, 0.05)
	pj.tween_property(_panel, "position:x", px - 7.0, 0.05)
	pj.tween_property(_panel, "position:x", px + 4.0, 0.05)
	pj.tween_property(_panel, "position:x", px, 0.05)
	# ⑤ 收尾结转
	var done_t := create_tween()
	done_t.tween_interval(0.85)
	done_t.tween_callback(_after_anim)

func _after_anim() -> void:
	_animating = false
	_consume_pick()

func _consume_pick() -> void:
	run["pending_picks"] = maxi(0, int(run.get("pending_picks", 1)) - 1)
	if int(run.get("pending_picks", 0)) > 0:
		_roll()
	else:
		done.emit()

func _on_skip() -> void:
	if int(run.get("skips", 0)) <= 0:
		return
	run["skips"] = int(run.get("skips", 0)) - 1
	# 得经验但不产生新突破次数（低级段 need 防无限跳）
	var lp: Dictionary = VC.level_progress(int(run.get("level", 1)), int(run.get("xp", 0)) + VC.SKIP_XP)
	run["level"] = int(lp["lvl"])
	run["xp"] = int(lp["xp"])
	_consume_pick()

func _on_reroll() -> void:
	if int(run.get("rerolls", 0)) <= 0:
		return
	run["rerolls"] = int(run.get("rerolls", 0)) - 1
	_roll()

func _on_banish() -> void:
	if int(run.get("banishes", 0)) <= 0:
		return
	_banish_mode = not _banish_mode
	_refresh_btns()

func _refresh_btns() -> void:
	var forced := not _force_gifts.is_empty()
	_skip_btn.visible = not forced
	_reroll_btn.visible = not forced
	_banish_btn.visible = not forced
	if forced:
		# 「机缘天降」撤除（2026-11-08 用户令）：这里只留突破次数，不再显示那四个字
		_count_lbl.text = "" if int(run.get("pending_picks", 0)) <= 1 \
			else "×%d" % int(run.get("pending_picks", 0))
		return
	_skip_btn.text = "跳过 · 得 %d 经验（%d）" % [VC.SKIP_XP, int(run.get("skips", 0))]
	_skip_btn.disabled = int(run.get("skips", 0)) <= 0
	_reroll_btn.text = "重选（%d）" % int(run.get("rerolls", 0))
	_reroll_btn.disabled = int(run.get("rerolls", 0)) <= 0
	if _banish_mode:
		_banish_btn.text = "排除中…点一张移除（%d）" % int(run.get("banishes", 0))
	else:
		_banish_btn.text = "排除（%d）" % int(run.get("banishes", 0))
	_banish_btn.disabled = int(run.get("banishes", 0)) <= 0
	_count_lbl.text = "突破 ×%d" % int(run.get("pending_picks", 0))

## 双层金框＋四角装饰（2026-11-08 照参考蓝本）
func _add_gold_frame(host: Control) -> void:
	var GOLD := Color("c8a24e")
	var out := Panel.new()
	out.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ob := StyleBoxFlat.new()
	ob.bg_color = Color(0, 0, 0, 0)
	ob.border_color = GOLD
	ob.set_border_width_all(3)
	ob.anti_aliasing = true
	out.add_theme_stylebox_override("panel", ob)
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(out)

	var inn := Panel.new()
	inn.set_anchors_preset(Control.PRESET_FULL_RECT)
	inn.offset_left = 9.0
	inn.offset_top = 9.0
	inn.offset_right = -9.0
	inn.offset_bottom = -9.0
	var ib := StyleBoxFlat.new()
	ib.bg_color = Color(0, 0, 0, 0)
	ib.border_color = GOLD
	ib.set_border_width_all(1)
	ib.anti_aliasing = true
	inn.add_theme_stylebox_override("panel", ib)
	inn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(inn)

	# 四角装饰块
	var cs := 18.0
	var spots := [
		[Control.PRESET_TOP_LEFT, 0.0, 0.0],
		[Control.PRESET_TOP_RIGHT, -cs, 0.0],
		[Control.PRESET_BOTTOM_LEFT, 0.0, -cs],
		[Control.PRESET_BOTTOM_RIGHT, -cs, -cs],
	]
	for sp in spots:
		var c := Panel.new()
		c.set_anchors_preset(int(sp[0]))
		c.offset_left = float(sp[1])
		c.offset_top = float(sp[2])
		c.offset_right = float(sp[1]) + cs
		c.offset_bottom = float(sp[2]) + cs
		var cb := StyleBoxFlat.new()
		cb.bg_color = GOLD
		cb.anti_aliasing = true
		c.add_theme_stylebox_override("panel", cb)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(c)

## 悬停：放大 1.12 ＋ 弹词条浮窗（与手牌同一套浮窗工厂）
func _offer_hover(vis: Control, cid: String, on: bool) -> void:
	if not is_instance_valid(vis):
		return
	if not on:
		return   # 离开卡不立刻收：交给 _process 判"是否移到浮窗上"（与手牌一致）
	_hover_vis = vis
	_hover_cid = cid
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(vis, "scale", Vector2(1.12, 1.12), 0.12)
	if true:
		var def: Dictionary = VC.CARDS.get(cid, {})
		var groups: Array = []
		for kwd in def.get("kw", []):
			if VC.KEYWORDS.has(kwd):
				groups.push_back([
					{"t": "title", "text": String(VC.KEYWORDS[kwd]["name"])},
					{"t": "line", "text": String(VC.KEYWORDS[kwd]["desc"])}])
		if groups.is_empty():
			groups.push_back([
				{"t": "title", "text": String(def.get("name", ""))},
				{"t": "line", "text": String(def.get("desc", ""))}])
		var tv2 = vis.get_meta("tilt", null)
		var csz: Vector2 = CARD.size_of("detail")
		QITIP.show_stack(vis, groups, {
			"anchor_fn": func() -> Rect2: return vis.get_global_rect(),
			"corners_fn": func() -> PackedVector2Array:
				return TILTV.corners(tv2, csz.x, csz.y) if tv2 != null else PackedVector2Array(),
		})
	else:
		QITIP.hide_for(vis)
