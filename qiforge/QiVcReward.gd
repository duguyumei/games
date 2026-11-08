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

signal done

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

func setup(run_ref: Dictionary, force_cards: Array = []) -> void:
	run = run_ref
	_force_gifts = force_cards.duplicate()

func _ready() -> void:
	# 2026-11-08 用户令「弹窗开＝全世界冻结」：WHEN_PAUSED＝暂停与否都处理——
	# 战斗屏开此弹窗时 get_tree().paused=true 冻结世界（剑/珠冻在半空），
	# 弹窗内 Tween/点击照跑；地图侧使用不暂停时行为不变
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
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
	scrim.color = Color(0, 0, 0, 0.72)
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
	add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	_panel.add_child(v)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	v.add_child(top_row)
	var title := Label.new()
	title.text = "突破 · 择一功法"
	QISTYLE.font(title, QISTYLE.FS_TITLE, true)
	QISTYLE.text_color(title, QISTYLE.AMBER_BRIGHT)
	top_row.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(sp)
	_count_lbl = Label.new()
	QISTYLE.font(_count_lbl, QISTYLE.FS_BODY)
	QISTYLE.text_color(_count_lbl, QISTYLE.TEXT_SUB)
	top_row.add_child(_count_lbl)

	var sub := Label.new()
	sub.text = "习得一门新功法加入卡组——点击即得"
	QISTYLE.font(sub, QISTYLE.FS_SMALL)
	QISTYLE.text_color(sub, QISTYLE.TEXT_SUB)
	v.add_child(sub)

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
		var vis: Button = CARD.make_tcg_card(CARD.tcg_def_of(VC.CARDS[String(cid)]), "detail")
		vis.size = cs
		var the_cid := String(cid)
		vis.set_meta("offer_id", the_cid)
		vis.pressed.connect(func() -> void: _card_clicked(the_cid))
		_card_box.add_child(vis)

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
	run["deck"].push_back(cid)
	_animating = true
	_play_tidi(cid)

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
	for c in _card_box.get_children():
		if c != card_btn:
			var tw_o := create_tween()
			tw_o.tween_property(c, "modulate:a", 0.0, 0.25)
	# ① 卡升起＋泛金
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
		_count_lbl.text = "机缘天降" if int(run.get("pending_picks", 0)) <= 1 \
			else "机缘天降 ×%d" % int(run.get("pending_picks", 0))
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
