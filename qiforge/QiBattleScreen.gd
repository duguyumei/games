## 战斗屏 v5（布局＝UI实施 §8 v3.2；数据层接 QiBattle v0.7 属性重构管线）。
## 分区：顶栏 y0~7｜意图行贴敌牌上 25px（图标＋实际结算数字，实时刷新）｜敌排 y15~36.3
## ｜我排 y44.5~65.8（+卡下被动行）｜手牌扇 216×304 底裁 y69.5~
## ｜拖我方卡到敌卡＝普攻（连线/预估/高亮）｜打牌一律拖放（禁点按）：
## 敌方目标功法拖到敌卡；器灵目标功法（护壁/铁壁诀/引丝诀）拖到我方卡；无目标功法拖到敌区/我区任意处。
## 左能量竖栈＝奇偶制上限。战后奖励＝六类操作池三选一（刷新带价＋跳过得铜＋Boss 保证位）。
## 用法：godot --path . res://qiforge/QiBattleScreen.tscn -- --qi-shot → 1.4s 自动截图退出
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const QICARD := preload("res://qiforge/QiCardStyle.gd")
const QITIP := preload("res://qiforge/QiTooltip.gd")
const QI_DRAG := preload("res://qiforge/QiDragCard.gd")
const QIDIALOG := preload("res://qiforge/QiDialog.gd")
const QI_DATA := preload("res://qiforge/QiData.gd")
const QI_BATTLE := preload("res://qiforge/QiBattle.gd")
const QIUP := preload("res://qiforge/QiUpgradePick.gd")

## 尺寸制 v3.0（2026-10-27 用户裁定）：唯一基准 300×422×场合系数（工厂 size_of 唯一权威）
static var CARD_W := QICARD.size_of("field").x
static var CARD_H := QICARD.size_of("field").y
static var HAND_W := QICARD.size_of("hand").x
static var HAND_H := QICARD.size_of("hand").y
const SLOT_GAP := 55
const STAT_ICON := 20
const C_DEF := Color("57b8d6")   # 防御意图蓝
## 伤害飘字配色（蓝本 DemageTip 制：按伤害类型染前后色）
const FX_COLORS := {"普攻": Color("ff8a70"), "功法": Color("b48ae0"), "真伤": Color("f2f2ec"),
	"间接": Color("f2f2ec"), "中毒": Color("a86ad0"), "治疗": Color("8fd08a"), "护盾": Color("8ab8d0"),
	"追击": Color("ffd766")}

## QiRoot 出战前注入；直跑 tscn（截图/探针）用固定演示局
var run_data: Dictionary = {}
var battle: RefCounted = null

var _enemy_slots: Array = []                # [{wrap, chip, card, hp, grid, statcol, mark, enemy}]
var _ally_slots: Array = []                 # [{wrap, card, acts, hp, statcol, unit}]
var _hand_wraps: Array = []
var _round_lbl: Label = null
var _cur_lbl: Label = null
var _energy_col: Control = null
var _busy := false
var _log_lbl: Label = null
var _line: Line2D = null                    # 普攻拖拽连线（源器灵→悬停敌卡；尸姬制贝塞尔）
var _arrow: Line2D = null                   # 连线箭头双翼
var _drag_mark: Dictionary = {}             # {rec, from} 当前拖拽悬停的敌槽＋拖源
var _pile_draw_btn: Button = null           # v0.6 牌堆钮（抽/弃/消）
var _pile_discard_btn: Button = null
var _pile_exhaust_btn: Button = null

func _default_run() -> Dictionary:
	return QI_DATA.default_run()

func _ready() -> void:
	QISTYLE.apply_root_theme(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if run_data.is_empty():
		run_data = _default_run()
	battle = QI_BATTLE.new()
	battle.setup(run_data)
	battle.changed.connect(_rebind)
	battle.event.connect(_on_event)
	battle.ended.connect(_on_ended)
	battle.hit_landed.connect(_on_hit_landed)
	battle.pursuit_fired.connect(_on_pursuit)
	_build_ground()
	_build_top_bar()
	_build_pile_buttons()
	_build_drop_zones()
	_build_drag_line()
	_build_enemy_row()
	_build_ally_row()
	_build_log()
	_build_end_button()
	battle.start()
	if "--qi-shot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.4).timeout
		get_viewport().get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/.qi_battle_preview.png")
		get_tree().quit()

func _build_ground() -> void:
	var bg := ColorRect.new()
	bg.color = QISTYLE.INK_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

## 顶栏 y0~7：左＝功能钮；右＝铜钱＋回合
func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	_anchor(bar, 0.012, 0.014, 0.24, 0.052)
	bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	bar.add_theme_constant_override("separation", 10)
	for pair in [["图鉴", "器灵谱与词条图鉴"], ["重战", "快速读档：回到上一场战斗前重打本场（同敌方意图）"], ["设置", "音量与偏好设置"]]:
		var b := Button.new()
		b.text = pair[0]
		b.tooltip_text = pair[1]
		QISTYLE.apply_ghost(b)
		QISTYLE.font(b, QISTYLE.FS_SMALL)
		b.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
		if String(pair[0]) == "重战":
			b.pressed.connect(func() -> void:
				var p := get_parent()
				if p != null and p.has_method("_rewind_battle"):
					p._rewind_battle())   # 独立跑 tscn/探针＝无宿主，静默不响应
		bar.add_child(b)
	add_child(bar)
	_cur_lbl = Label.new()
	_cur_lbl.name = "Currency"
	_cur_lbl.text = "铜钱 0"
	_anchor(_cur_lbl, 0.70, 0.016, 0.88, 0.05)
	QISTYLE.font(_cur_lbl, QISTYLE.FS_SMALL, true)
	_cur_lbl.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	_cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_cur_lbl)
	_round_lbl = Label.new()
	_round_lbl.name = "RoundLbl"
	_round_lbl.text = "回合 1"
	_anchor(_round_lbl, 0.892, 0.016, 0.977, 0.05)
	QISTYLE.font(_round_lbl, QISTYLE.FS_SMALL, true)
	_round_lbl.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	_round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_round_lbl)

## 能量宝珠（2026-10-28 用户裁定改 STS2 战士款：左下抽牌堆上方单颗多层宝珠＋大数字；
## 弃炉石式珠串——2026-10-27 制随裁退役）
func _build_energy_stack() -> void:
	if _energy_col:
		_energy_col.queue_free()
		_energy_col = null
	if battle.energy_cap <= 0:
		return
	var orb := _make_gem_orb(92.0, Color("79c2f2"), battle.energy <= 0)
	orb.name = "EnergyOrb"
	_anchor(orb, 0.008, 0.615, 0.078, 0.76)
	var num := orb.get_meta("num") as Label
	num.text = "%d" % battle.energy
	var cap := Label.new()
	cap.text = "/%d" % battle.energy_cap
	QISTYLE.font(cap, 15, true)
	cap.add_theme_color_override("font_color", Color(0.75, 0.86, 0.94, 0.9))
	cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -24.0
	cap.offset_bottom = -4.0
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(cap)
	add_child(orb)
	orb.tooltip_text = "能量 %d/%d\n每回合重置到上限。上限＝系统出厂 3＋偶数次系统升级 +1。" % [battle.energy, battle.energy_cap]
	_energy_col = orb

## 宝珠件（STS2 能量珠分层制：光晕→珠体→内芯→大数字；攻次小珠同款共用）
func _make_gem_orb(d: float, hue: Color, empty: bool) -> Control:
	var orb := Control.new()
	orb.custom_minimum_size = Vector2(d, d)
	orb.mouse_filter = Control.MOUSE_FILTER_STOP
	var glow := Panel.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -d * 0.08
	glow.offset_right = d * 0.08
	glow.offset_top = -d * 0.08
	glow.offset_bottom = d * 0.08
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(hue.r, hue.g, hue.b, 0.16)
	gs.set_corner_radius_all(roundi(d * 0.54))
	glow.add_theme_stylebox_override("panel", gs)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(glow)
	var body := Panel.new()
	body.set_anchors_preset(Control.PRESET_CENTER)
	body.offset_left = -d * 0.42
	body.offset_right = d * 0.42
	body.offset_top = -d * 0.42
	body.offset_bottom = d * 0.42
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("101c26")
	bs.border_color = hue if not empty else Color(hue.r * 0.45, hue.g * 0.45, hue.b * 0.45)
	bs.set_border_width_all(maxi(2, roundi(d * 0.045)))
	bs.set_corner_radius_all(roundi(d * 0.46))
	body.add_theme_stylebox_override("panel", bs)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(body)
	var core := Panel.new()
	core.set_anchors_preset(Control.PRESET_CENTER)
	core.offset_left = -d * 0.30
	core.offset_right = d * 0.30
	core.offset_top = -d * 0.30
	core.offset_bottom = d * 0.30
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(hue.r, hue.g, hue.b, 0.9) if not empty else Color(hue.r * 0.30, hue.g * 0.30, hue.b * 0.30, 0.85)
	cs.set_corner_radius_all(roundi(d * 0.34))
	core.add_theme_stylebox_override("panel", cs)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(core)
	var num := Label.new()
	num.set_anchors_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	QISTYLE.font(num, roundi(d * 0.30), true)
	num.add_theme_color_override("font_color", Color(1, 0.96, 0.88))
	num.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 0.92))
	num.add_theme_constant_override("outline_size", 5)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(num)
	orb.set_meta("num", num)
	orb.set_meta("core", core)
	return orb

## 右缘弃牌带：拖手牌即显，松手弃置（不扣能量）
## 敌排：意图徽（实时数字）＋敌卡（QI_DRAG 壳＝普攻落点＋功法目标点击）
func _build_enemy_row() -> void:
	var row := HBoxContainer.new()
	row.name = "EnemyRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(row, 0.0, 0.068, 1.0, 0.363)   # 上移让出血条位（2026-10-28：血条移卡外下方）
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", SLOT_GAP)
	for e in battle.enemies:
		var slot := VBoxContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.alignment = BoxContainer.ALIGNMENT_END
		slot.add_theme_constant_override("separation", 10)
		var chip := PanelContainer.new()
		chip.name = "Intent"
		# 悬停只连一次（内容随 _rebind 重建，悬停读实时数据）
		chip.mouse_entered.connect(func() -> void:
			QITIP.show_for(chip, [{"t": "title", "text": "敌方意图"},
				{"t": "line", "text": battle.intent_tip(e)}], {"type": "意图", "min_w": 260.0}))
		chip.mouse_exited.connect(func() -> void: QITIP.hide_for(chip))
		slot.add_child(chip)
		var wrap: Control = QI_DRAG.new()   # 纯落点用法（card_data 空＝不可拖）
		wrap.custom_minimum_size = Vector2(CARD_W, CARD_H)
		wrap.mouse_filter = Control.MOUSE_FILTER_STOP
		var rec := {"enemy": e, "wrap": wrap, "chip": chip, "hp": null, "atk": null, "def": null, "statcol": null, "slot": slot}
		wrap.drop_ok = func(data) -> bool:
			# 器灵卡（atk_uid）＝普攻；功法卡＝目标型拖到本卡施放、无目标型拖到本区（本卡上）也释放
			if not (data is Dictionary):
				return false
			var dd: Dictionary = data.get("drag_data", {})
			if dd.has("hand_uid"):
				if battle.phase != "player":
					return false
				var uid := int(dd["hand_uid"])
				if _none_target_ok(uid):
					_mark_drag(rec, 0)
					return true
				var card := _hand_card_by_uid(uid)
				if not battle.can_target(card, e):
					return false
				_mark_drag(rec, 0)
				return true
			if not dd.has("atk_uid") or battle.phase != "player" or not e["alive"]:
				return false
			_mark_drag(rec, int(dd["atk_uid"]))
			return true
		wrap.on_drop = func(data, _zone) -> void:
			var dd: Dictionary = data["drag_data"]
			if dd.has("hand_uid"):
				var uid := int(dd["hand_uid"])
				var card := _hand_card_by_uid(uid)
				_cast_fly(uid, wrap.get_global_rect().get_center(), func() -> void:
					if not card.is_empty() and String(card["spell"]["target"]) == "enemy":
						battle.play_card(uid, e)
					else:
						battle.play_card(uid, {}))
			else:
				_drop_attack(int(dd["atk_uid"]), e)
		var card := _make_enemy_card(rec)
		_mute_mouse(card)
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		wrap.add_child(card)
		rec["mark"] = _make_mark_layer(wrap)
		rec["statcol"] = _attach_status_col(wrap, e, false)
		wrap.mouse_entered.connect(func() -> void:
			QITIP.show_for(wrap, _enemy_rows(e), {"type": "敌方", "min_w": 260.0}))
		wrap.mouse_exited.connect(func() -> void: QITIP.hide_for(wrap))
		slot.add_child(wrap)
		slot.add_child(_make_sts2_hp_bar(rec, e))   # STS2 制血条＝卡外下方（宽出 24、盾徽压左端）
		row.add_child(slot)
		_enemy_slots.push_back(rec)
	add_child(row)

func _make_enemy_card(rec: Dictionary) -> Control:
	var e: Dictionary = rec["enemy"]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.add_theme_stylebox_override("panel", QISTYLE.panel(0.75))
	var front := VBoxContainer.new()
	front.name = "Front"
	front.add_theme_constant_override("separation", 4)
	var art := ColorRect.new()
	art.custom_minimum_size = Vector2(164, 150)
	art.color = Color("4a3030")
	front.add_child(art)
	var nm := Label.new()
	nm.text = String(e["name"])
	QISTYLE.font(nm, QISTYLE.FS_BODY, true)
	nm.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	front.add_child(nm)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	for p in [["攻", "atk"], ["防", "def"], ["抗", "res"]]:
		var kl := Label.new()
		kl.text = String(p[0])
		QISTYLE.font(kl, QISTYLE.FS_SMALL)
		kl.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
		var vl := Label.new()
		vl.text = "0"
		QISTYLE.font(vl, QISTYLE.FS_SMALL)
		vl.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
		grid.add_child(kl)
		grid.add_child(vl)
		rec[p[1]] = vl
	front.add_child(grid)
	card.add_child(front)
	return card

func _enemy_rows(e: Dictionary) -> Array:
	return [
		{"t": "title", "text": String(e["name"])},
		{"t": "sep"},
		{"t": "attr", "k": "耐久", "v": "%d/%d" % [e["hp"], e["mhp"]]},
		{"t": "attr", "k": "攻击", "v": battle.atk_of(e)},
		{"t": "attr", "k": "防御", "v": battle.def_of(e)},
		{"t": "attr", "k": "抗性", "v": battle.res_of(e)},
		{"t": "attr", "k": "攻击次数", "v": int(e["acts"])},
		{"t": "line", "text": battle.intent_tip(e)},
	]

## 我排：卡下被动行；我方卡＝QI_DRAG 拖源（拖到敌卡＝普攻）
func _build_ally_row() -> void:
	var row := HBoxContainer.new()
	row.name = "AllyRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(row, 0.0, 0.405, 1.0, 0.688)   # 上移让血条位（2026-10-28 我方血条出卡同敌制）
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", SLOT_GAP)
	for a in battle.allies:
		var slot := VBoxContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.alignment = BoxContainer.ALIGNMENT_END
		slot.add_theme_constant_override("separation", 8)
		var wrap: Control = QI_DRAG.new()
		wrap.custom_minimum_size = Vector2(CARD_W, CARD_H)
		wrap.mouse_filter = Control.MOUSE_FILTER_STOP
		var rec := {"unit": a, "wrap": wrap, "acts": null, "hp": null, "statcol": null}
		wrap.card_data = {"atk_uid": int(a["uid"])}
		wrap.preview_card = _make_attack_chip(String(a["name"]))
		wrap.on_drag_end = _clear_drag_marks
		wrap.drop_ok = func(data) -> bool:
			# 我方卡作落点：无目标功法拖到我方区（卡上）释放；器灵目标功法拖到本卡施放
			if not (data is Dictionary) or not (data["drag_data"] as Dictionary).has("hand_uid"):
				return false
			var uid0 := int(data["drag_data"]["hand_uid"])
			if _none_target_ok(uid0):
				return true
			var card0 := _hand_card_by_uid(uid0)
			if not battle.can_target(card0, a):
				return false   # 无效目标＝放不下（原生取消弹回，2026-10-28 尸姬 CheckCardUse 制）
			_mark_drag(rec, 0)
			return true
		wrap.on_drop = func(data, _zone) -> void:
			var uid := int(data["drag_data"]["hand_uid"])
			var card := _hand_card_by_uid(uid)
			var tgt: Dictionary = a if (not card.is_empty() and String(card["spell"]["target"]) == "ally") else {}
			_cast_fly(uid, wrap.get_global_rect().get_center(),
				func() -> void: battle.play_card(uid, tgt))
		wrap.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				QITIP.hide_for(wrap))
		var card := _make_ally_card(rec)
		_mute_mouse(card)
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		wrap.add_child(card)
		# 攻次宝珠（2026-10-28 仿 STS2 猎人能量珠款）挂 wrap：卡本体是 PanelContainer 会强制
		# 重排子件（首版挂卡上被容器拽走＝「位置不对」之根因）；珠挂壳层与照明环同层。
		# 攻次珠（2026-10-28 终版：圆形玉珠半搭卡左上角——倒三角方案两轮试装被评「僵硬/丑」还原）。
		# 挂 wrap（卡本体容器会重排子件）；零攻＝暗芯，与拖不动门同口径。
		var orb := _make_gem_orb(46.0, QISTYLE.JADE, int(a["acts"]) <= 0)
		orb.name = "ActOrb"
		orb.set_anchors_preset(Control.PRESET_TOP_LEFT)
		orb.offset_left = -10.0
		orb.offset_top = -10.0
		orb.offset_right = 36.0
		orb.offset_bottom = 36.0
		orb.z_index = 8
		(orb.get_meta("num") as Label).text = str(int(a["acts"]))
		wrap.add_child(orb)
		rec["acts"] = orb.get_meta("num")
		rec["actsorb"] = orb
		rec["mark"] = _make_mark_layer(wrap)   # 器灵目标/归属照明环（2026-10-28）
		rec["statcol"] = _attach_status_col(wrap, a, true)
		wrap.mouse_entered.connect(func() -> void:
			QITIP.show_for(wrap, _ally_rows(a), {"type": "单位", "min_w": 260.0}))
		wrap.mouse_exited.connect(func() -> void: QITIP.hide_for(wrap))
		slot.add_child(wrap)
		slot.add_child(_make_sts2_hp_bar(rec, a))   # 我方血条同制＝卡外下方（2026-10-28 用户裁定）
		slot.add_child(_make_trait_row(a))
		row.add_child(slot)
		rec["slot"] = slot
		_ally_slots.push_back(rec)
	add_child(row)

## 普攻拖拽预览件：小胶囊「普攻 · 名」
func _make_attack_chip(unit_name: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.16, 0.12, 0.95)
	sb.border_color = QISTYLE.AMBER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	p.add_theme_stylebox_override("panel", sb)
	var t := Label.new()
	t.text = "普攻 · %s" % unit_name
	QISTYLE.font(t, QISTYLE.FS_SMALL, true)
	t.add_theme_color_override("font_color", Color("ffe9b0"))
	p.add_child(t)
	return p

func _make_ally_card(rec: Dictionary) -> Control:
	var a: Dictionary = rec["unit"]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.add_theme_stylebox_override("panel", QISTYLE.panel(0.75))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var art := ColorRect.new()
	art.custom_minimum_size = Vector2(164, 116)
	art.color = Color("2f4438")
	v.add_child(art)
	var stats := Label.new()
	stats.name = "StatLine"
	stats.text = _ally_stat_text(a)
	QISTYLE.font(stats, QISTYLE.FS_SMALL, true)
	stats.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	v.add_child(stats)
	rec["stats"] = stats
	var nm := Label.new()
	nm.text = String(a["name"])
	QISTYLE.font(nm, QISTYLE.FS_BODY, true)
	nm.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	v.add_child(nm)
	card.add_child(v)
	return card

## 我方卡属性行：攻/威/防＋蛊虫计数（实时连锁）
func _ally_stat_text(a: Dictionary) -> String:
	var txt := "攻%d 威%d 防%d" % [battle.atk_of(a), battle.pow_of(a), battle.def_of(a)]
	if int(a.get("bugs", 0)) > 0:
		txt += " 蛊%d" % int(a["bugs"])
	return txt

func _ally_rows(a: Dictionary) -> Array:
	var rows: Array = [
		{"t": "title", "text": String(a["name"])},
		{"t": "sep"},
		{"t": "attr", "k": "耐久", "v": "%d/%d" % [a["hp"], a["mhp"]]},
		{"t": "attr", "k": "攻击", "v": battle.atk_of(a)},
		{"t": "attr", "k": "威力", "v": battle.pow_of(a)},
		{"t": "attr", "k": "防御", "v": battle.def_of(a)},
		{"t": "attr", "k": "抗性", "v": battle.res_of(a)},
		{"t": "attr", "k": "攻击次数", "v": "%d/%d" % [a["acts"], a["acts_max"]]},
		{"t": "attr", "k": "蛊虫", "v": int(a.get("bugs", 0))},
		{"t": "sep"},
		{"t": "line", "text": "[color=#ffd766]%s[/color]：%s" % [a["passive"]["name"], a["passive"]["desc"]]},
	]
	# 被动升级方向（已选＝生效文本；未选＝双方向预告）
	var pdir := int(a.get("pdir", 0))
	if pdir > 0:
		rows.push_back({"t": "line", "text": "[color=#8fd08a]被动·已升级（方向%d）[/color]：%s"
			% [pdir, String(a["passive"].get("ups", {}).get(str(pdir), ""))]})
	else:
		rows.push_back({"t": "line", "text": "[color=#b0a06a]被动可升级[/color]：①%s ②%s"
			% [String(a["passive"].get("ups", {}).get("1", "")), String(a["passive"].get("ups", {}).get("2", ""))]})
	for s in a["spells"]:
		rows.push_back({"t": "line", "text": "「%s」（%d 能量）：%s" % [s["name"], s["cost"], s["desc"]]})
	return rows

## 被动行（卡下）：器灵被动单章
func _make_trait_row(a: Dictionary) -> Control:
	var tr := HBoxContainer.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr.add_theme_constant_override("separation", 8)
	tr.add_child(_make_trait_chip(String(a["passive"]["name"]).substr(0, 1),
		String(a["passive"]["name"]), String(a["passive"]["desc"])))
	return tr

func _make_trait_chip(glyph: String, ttl: String, desc: String) -> Panel:
	var ic := Panel.new()
	ic.custom_minimum_size = Vector2(STAT_ICON, STAT_ICON)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(QISTYLE.AMBER.r * 0.3, QISTYLE.AMBER.g * 0.3, QISTYLE.AMBER.b * 0.3, 0.55)
	sb.border_color = Color(QISTYLE.AMBER.r, QISTYLE.AMBER.g, QISTYLE.AMBER.b, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	ic.add_theme_stylebox_override("panel", sb)
	var gl := Label.new()
	gl.text = glyph
	QISTYLE.font(gl, 13)
	gl.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	gl.set_anchors_preset(Control.PRESET_FULL_RECT)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(gl)
	var rows: Array = [{"t": "title", "text": ttl}, {"t": "line", "text": desc}]
	ic.mouse_entered.connect(func() -> void: QITIP.show_for(ic, rows, {"type": "被动", "min_w": 240.0}))
	ic.mouse_exited.connect(func() -> void: QITIP.hide_for(ic))
	return ic

## 状态列（卡右外）：实例聚合显示（图标＋总层数角标＋悬停详情）
func _attach_status_col(wrap: Control, u: Dictionary, _ally: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.set_anchor(SIDE_LEFT, 1.0)
	col.set_anchor(SIDE_RIGHT, 1.0)
	col.offset_left = 12.0
	col.offset_right = 32.0
	col.set_anchor(SIDE_TOP, 0.0)
	col.set_anchor(SIDE_BOTTOM, 1.0)
	col.offset_top = 0.0
	col.offset_bottom = 0.0
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 5)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.set_meta("unit", u)
	wrap.add_child(col)
	return col

func _refill_status_col(col: VBoxContainer) -> void:
	var u: Dictionary = col.get_meta("unit")
	for c in col.get_children():
		c.queue_free()
	var totals: Dictionary = {}
	for s in u["statuses"]:
		totals[s["sid"]] = totals.get(s["sid"], 0) + int(s["stacks"])
	for sid in totals:
		var st: Dictionary = QI_DATA.STATUSES[sid]
		col.add_child(_make_status_icon(String(sid), String(st["glyph"]), int(totals[sid]),
			Color(String(st["color"])), String(st["name"]), String(st["desc"])))

## 状态图标（2026-10-28 制：game-icons.net 白线稿按 sid 染色——CC BY，署名挂主菜单）；
## 无图状态回落旧单字块。面板底＋描边保留（线稿可读性）。
func _make_status_icon(sid: String, glyph: String, stacks: int, tint: Color, name: String, desc: String) -> Panel:
	var ic := Panel.new()
	ic.custom_minimum_size = Vector2(STAT_ICON, STAT_ICON)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.32, tint.g * 0.32, tint.b * 0.32, 0.95)
	sb.border_color = tint
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(5)
	ic.add_theme_stylebox_override("panel", sb)
	var tex := load("res://qiforge/assets/gi/%s.svg" % sid) as Texture2D
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.modulate = tint.lightened(0.35)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 3.0
		tr.offset_right = -3.0
		tr.offset_top = 3.0
		tr.offset_bottom = -3.0
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.add_child(tr)
	else:
		var gl := Label.new()
		gl.text = glyph
		QISTYLE.font(gl, 13)
		gl.add_theme_color_override("font_color", tint.lightened(0.35))
		gl.set_anchors_preset(Control.PRESET_FULL_RECT)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.add_child(gl)
	var corner := Label.new()
	corner.text = "×%d" % stacks
	QISTYLE.font(corner, 12, true)
	corner.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	corner.offset_left = -16.0
	corner.offset_top = -8.0
	corner.offset_right = 2.0
	corner.offset_bottom = 8.0
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(corner)
	var rows: Array = [{"t": "title", "text": name}, {"t": "line", "text": desc}]
	ic.mouse_entered.connect(func() -> void: QITIP.show_for(ic, rows, {"type": "状态", "min_w": 240.0}))
	ic.mouse_exited.connect(func() -> void: QITIP.hide_for(ic))
	return ic

## 手牌扇：无卡组涌出；打牌一律拖放（禁点按）——目标型拖到该单位卡、无目标型拖到敌方区/我方区；拖右缘弃置
func _rebuild_hand() -> void:
	for w in _hand_wraps:
		w.queue_free()
	_hand_wraps = []
	for card in battle.hand:
		var w: Control = QI_DRAG.new()
		w.name = "HandCard%d" % int(card["uid"])
		w.size = Vector2(HAND_W, HAND_H)
		w.card_data = {"hand_uid": int(card["uid"])}
		w.preview_card = QICARD.make_hand_spell_card(String(card["spell"]["name"]),
			battle.card_cost(card), String(card["spell"]["desc"]))
		var visual: Button = QICARD.make_hand_spell_card(String(card["spell"]["name"]),
			battle.card_cost(card), String(card["spell"]["desc"]))
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.set_anchors_preset(Control.PRESET_FULL_RECT)
		w.add_child(visual)
		# 拖放照明（2026-10-28）：起拖亮全部有效目标＋归属；悬停亮归属；收拖全清
		var the_card: Dictionary = card
		w.on_drag_begin = func() -> void: _light_spell_targets(the_card)
		w.on_drag_end = func() -> void:
			_clear_drag_marks()
			_clear_spell_lights()
		w.mouse_entered.connect(func() -> void: _light_owner_only(the_card))
		# 拖拽期间引擎会强制退出悬停态——清灯只在该卡真离开且无拖拽时做（修「起拖高亮闪一下就灭」）
		w.mouse_exited.connect(func() -> void:
			if not get_viewport().gui_is_dragging():
				_clear_spell_lights())
		add_child(w)
		_hand_wraps.push_back(w)
	_layout_hand(false)
	_refresh_playability()

## 手牌可打性（2026-10-28 用户裁定，STS2 制＝NPlayerHand._disableModulate 灰调）：
## 能量不足/属主不可施放＝整卡压灰＋费用徽描边转红；恢复即回亮。实时随 changed 连锁。
func _refresh_playability() -> void:
	var i := 0
	for w in _hand_wraps:
		var card: Dictionary = battle.hand[i] if i < battle.hand.size() else {}
		i += 1
		if card.is_empty() or w.get_child_count() == 0:
			continue
		var ok: bool = battle.can_play(card)
		var visual: Control = w.get_child(0)
		visual.modulate = Color(1, 1, 1, 1.0) if ok else Color(0.52, 0.52, 0.52, 0.92)
		var pip := visual.find_child("CostPip", false, false)
		if pip is Panel:
			var sb: StyleBoxFlat = (pip as Panel).get_theme_stylebox("panel") as StyleBoxFlat
			sb.border_color = Color("e05545") if not ok else Color(0.95, 0.92, 0.84)

func _layout_hand(animate: bool) -> void:
	var n := _hand_wraps.size()
	if n == 0:
		return
	var mid := float(n - 1) / 2.0
	var vp := get_viewport_rect().size
	for i in n:
		var w: Control = _hand_wraps[i]
		# 216×304 手牌：步距/扇角适档，底缘微出屏
		var x := vp.x * 0.5 + (i - mid) * vp.x * 0.075 - HAND_W * 0.5
		var y := vp.y * 0.752
		var rot := (i - mid) * 0.032
		w.pivot_offset = Vector2(HAND_W * 0.5, HAND_H)
		if animate:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(w, "position:x", x, 0.15)
			tw.tween_property(w, "position:y", y, 0.15)
			tw.tween_property(w, "rotation", rot, 0.15)
		else:
			w.position = Vector2(x, y)
			w.rotation = rot

func _drop_attack(atk_uid: int, e: Dictionary) -> void:
	if _busy:
		return
	var from: Control = null
	var to: Control = null
	for r in _ally_slots:
		if int(r["unit"]["uid"]) == atk_uid:
			from = r["wrap"]
	for r in _enemy_slots:
		if r["enemy"] == e:
			to = r["wrap"]
	_anim_attack(from, to, func() -> void:
		for r in _ally_slots:
			if int(r["unit"]["uid"]) == atk_uid:
				battle.normal_attack(r["unit"], e))

## 功法卡飞行施放：从手牌飞向落点中心，到位瞬间结算
func _cast_fly(hand_uid: int, to_center: Vector2, impact: Callable) -> void:
	if _busy:
		return
	var wrap: Control = null
	for c in get_children():
		if String(c.name) == "HandCard%d" % hand_uid:
			wrap = c
	if wrap == null:
		impact.call()
		return
	_anim_play_card(wrap, to_center, impact)

#region 攻击动画与命中特效（蓝本 EAction_HitBase/DemageTip 制，2026-10-27）
## 三段突进（蓝本 Hold0.3/Hit0.3/Back0.7 等比压缩 0.13/0.15/0.30）：
## 后撤蓄力→三次方缓动突进到目标跟前→命中瞬间结算→回位；全程锁操作。
func _anim_attack(from: Control, to: Control, impact: Callable) -> void:
	if from == null or to == null or not is_instance_valid(from) or not is_instance_valid(to):
		impact.call()
		return
	_busy = true
	var orig := from.position
	var frect := from.get_global_rect()
	var trect := to.get_global_rect()
	var dir := signf(frect.get_center().x - trect.get_center().x)
	if dir == 0.0:
		dir = 1.0
	var stop_at := trect.get_center() - Vector2(dir * (CARD_W * 0.72), 0.0)
	var tw := create_tween()
	tw.tween_property(from, "position", orig + Vector2(dir * 14.0, 6.0), 0.13)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(from, "global_position", stop_at - frect.size * 0.5, 0.15)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: impact.call())
	tw.tween_property(from, "position", orig, 0.30)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_busy = false

func _anim_play_card(wrap: Control, to_center: Vector2, impact: Callable) -> void:
	_busy = true
	wrap.pivot_offset = Vector2(HAND_W, HAND_H) * 0.5
	# 弧线飞行（2026-10-28 尸姬贝塞尔同式：中点上抬）——替换直线插值
	var start := wrap.global_position
	var endp := to_center - Vector2(HAND_W, HAND_H) * 0.5
	var ctrl := (start + endp) * 0.5 + Vector2(0.0, -150.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(t: float) -> void:
		wrap.global_position = _bez(start, ctrl, endp, t), 0.0, 1.0, 0.26)\
		.set_ease(Tween.EASE_IN)
	tw.tween_property(wrap, "scale", Vector2(0.42, 0.42), 0.26)
	tw.tween_property(wrap, "modulate:a", 0.3, 0.26)
	tw.chain().tween_callback(func() -> void: impact.call())
	await tw.finished
	_busy = false

## 命中上报：飘字＋受击抖动闪白＋击破特效（普攻/功法/真伤/中毒共用）；
## 「追击」段除外——追击的数值/受击在其自身突进的命中帧表现（2026-10-28 时序裁定）。
func _on_hit_landed(u: Dictionary, amount: int, kind: String) -> void:
	var wrap := _wrap_of_uid(int(u["uid"]))
	if wrap == null or not is_instance_valid(wrap):
		return
	if kind == "追击":
		return
	var center := wrap.get_global_rect().get_center()
	_spawn_floater(center, str(amount), kind)
	if kind != "治疗":
		_hit_reaction(wrap)
		if not u["alive"]:
			_spawn_death_fx(center)

func _wrap_of_uid(uid: int) -> Control:
	for r in _enemy_slots:
		if int(r["enemy"]["uid"]) == uid:
			return r["wrap"]
	for r in _ally_slots:
		if int(r["unit"]["uid"]) == uid:
			return r["wrap"]
	return null

## 伤害飘字（蓝本 DemageTip：随机水平偏移＋弹跳缩放＋上飘淡出；通道染色）
func _spawn_floater(center: Vector2, text: String, kind: String) -> void:
	var l := Label.new()
	l.text = text
	QISTYLE.font(l, 26, true)
	l.add_theme_color_override("font_color", FX_COLORS.get(kind, Color.WHITE))
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 0.95))
	l.add_theme_constant_override("outline_size", 5)
	l.z_index = 60
	l.position = center + Vector2(randf_range(-44.0, 4.0), -36.0)
	l.scale = Vector2(1.35, 1.35)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2(1.0, 1.0), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 46.0, 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(l.queue_free)

## 受击反应：过曝闪白回落＋左右抖动
func _hit_reaction(wrap: Control) -> void:
	var orig := wrap.position
	var orig_mod := wrap.modulate
	wrap.modulate = Color(2.4, 2.4, 2.4)
	var tw := create_tween()
	tw.tween_property(wrap, "modulate", orig_mod, 0.22)
	tw.tween_property(wrap, "position:x", orig.x + 7.0, 0.045)
	tw.tween_property(wrap, "position:x", orig.x - 7.0, 0.07)
	tw.tween_property(wrap, "position:x", orig.x + 4.0, 0.05)
	tw.tween_property(wrap, "position:x", orig.x, 0.05)

## 击破特效：橙环扩散淡出（蓝本 DeathEffect 的简版替身，待美术）
func _spawn_death_fx(center: Vector2) -> void:
	var ring := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color("e88a70")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(30)
	ring.add_theme_stylebox_override("panel", sb)
	ring.size = Vector2(30, 30)
	ring.position = center - Vector2(15, 15)
	ring.z_index = 55
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ring)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(4.2, 5.6), 0.42)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.42)
	tw.chain().tween_callback(ring.queue_free)
#endregion

#region 普攻拖拽表现（拖卡即攻击动画：悬停敌卡＝红框＋预估伤害＋源到目标连线）
func _mute_mouse(c: Control) -> void:
	# 内层卡面全部静音——事件（拖拽起手/落点/点击/悬停）一律归 QiDragCard 壳
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ch in c.get_children():
		if ch is Control:
			_mute_mouse(ch)

## 无目标功法释放区（敌方区/我方区，整片）：拖功法卡到任一区即释放——
## 打牌唯一操作＝拖放（禁点按），目标型拖到具体卡、全体/自身型拖到区。
func _build_drop_zones() -> void:
	for z in [["EnemyZone", 0.0, 0.09, 0.955, 0.375], ["AllyZone", 0.0, 0.40, 0.955, 0.70]]:
		var zone: Control = QI_DRAG.new()
		zone.name = z[0]
		zone.mouse_filter = Control.MOUSE_FILTER_STOP
		_anchor(zone, z[1], z[2], z[3], z[4])
		var glow := Panel.new()
		glow.name = "Glow"
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.55, 0.16, 0.12, 0.06)
		sb.border_color = Color("e8b070")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(16)
		glow.add_theme_stylebox_override("panel", sb)
		glow.visible = false
		zone.add_child(glow)
		zone.set_meta("glow", glow)
		zone.drop_ok = func(data) -> bool:
			if not (data is Dictionary) or not (data["drag_data"] as Dictionary).has("hand_uid"):
				return false
			if not _none_target_ok(int(data["drag_data"]["hand_uid"])):
				return false
			glow.visible = true
			return true
		zone.on_drop = func(data, _zone) -> void:
			var uid := int(data["drag_data"]["hand_uid"])
			_cast_fly(uid, zone.get_global_rect().get_center(),
				func() -> void: battle.play_card(uid, {}))
		add_child(zone)

func _hand_card_by_uid(uid: int) -> Dictionary:
	for c in battle.hand:
		if int(c["uid"]) == uid:
			return c
	return {}

func _none_target_ok(uid: int) -> bool:
	var card := _hand_card_by_uid(uid)
	return not card.is_empty() and String(card["spell"]["target"]) == "none" \
		and battle.can_play(card)

func _build_drag_line() -> void:
	_line = Line2D.new()
	_line.name = "DragLine"
	_line.width = 3.0
	_line.default_color = Color("e88a70")
	_line.z_index = 40
	_line.visible = false
	add_child(_line)
	_arrow = Line2D.new()
	_arrow.name = "DragArrow"
	_arrow.width = 3.0
	_arrow.default_color = Color("e88a70")
	_arrow.z_index = 40
	_arrow.visible = false
	add_child(_arrow)

## 二次贝塞尔（尸姬 Card_TargetLine.SetCurveOnDrag 同式：中点上抬、距离定高）
static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

func _make_mark_layer(wrap: Control) -> Dictionary:
	var ring := Panel.new()
	ring.name = "DragMark"
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.16, 0.12, 0.10)
	sb.border_color = Color("e88a70")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	ring.add_theme_stylebox_override("panel", sb)
	ring.visible = false
	var est := Label.new()
	est.name = "DragEst"
	est.text = ""
	est.set_anchors_preset(Control.PRESET_FULL_RECT)
	est.offset_bottom = -34.0
	QISTYLE.font(est, QISTYLE.FS_BIG, true)
	est.add_theme_color_override("font_color", Color("ffe9b0"))
	est.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.03, 0.9))
	est.add_theme_constant_override("outline_size", 4)
	est.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	est.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	est.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(est)
	wrap.add_child(ring)
	return {"ring": ring, "est": est}

func _mark_drag(rec: Dictionary, atk_uid: int) -> void:
	if _drag_mark.get("rec") != rec:
		_clear_drag_marks()
		var from: Control = null
		if atk_uid > 0:
			for r in _ally_slots:
				if int(r["unit"]["uid"]) == atk_uid:
					from = r["wrap"]
		_drag_mark = {"rec": rec, "from": from}
	var est := 0
	if atk_uid > 0:
		for r in _ally_slots:
			if int(r["unit"]["uid"]) == atk_uid:
				est = battle.preview_normal_attack(r["unit"], rec["enemy"])
	# 普攻拖放＝红框口径（环样式可能被功法照明染过色，回落红）
	var sb0: StyleBoxFlat = (rec["mark"]["ring"].get_theme_stylebox("panel") as StyleBoxFlat)
	sb0.border_color = Color("e88a70")
	sb0.bg_color = Color(0.55, 0.16, 0.12, 0.10)
	(rec["mark"]["ring"] as Control).visible = true
	var lbl := rec["mark"]["est"] as Label
	if atk_uid <= 0:
		lbl.visible = false   # 功法拖放：只亮框不显预估（伤害以卡面为准）
	elif est > 0:
		lbl.text = "预估 %d" % est
		lbl.visible = true
	else:
		lbl.text = "不可普攻"
		lbl.visible = true
	if _drag_mark.get("from") != null:
		_line.visible = true

func _clear_drag_marks() -> void:
	var rec: Dictionary = _drag_mark.get("rec", {})
	if not rec.is_empty():
		var ring := rec.get("mark", {}).get("ring") as Control
		if ring != null and is_instance_valid(ring):
			ring.visible = false
	_drag_mark = {}
	if _line:
		_line.visible = false
	if _arrow:
		_arrow.visible = false
	for zname in ["EnemyZone", "AllyZone"]:
		var zn := find_child(zname, false, false)
		if zn != null:
			(zn.get_meta("glow") as Panel).visible = false

#region 功法目标/归属照明（2026-10-28 尸姬 Card_TargetLine·MarkTarget 制）
## 起拖＝全部有效目标亮玉环＋归属器灵亮琥珀环；悬停手牌＝仅亮归属；口径唯一来源 battle.can_target。
var _spell_lights: Array = []

func _light_spell_targets(card: Dictionary) -> void:
	_clear_spell_lights()
	if card.is_empty():
		return
	for r in _enemy_slots:
		if battle.can_target(card, r["enemy"]):
			_show_ring(r, "valid")
	for r in _ally_slots:
		if battle.can_target(card, r["unit"]):
			_show_ring(r, "valid")
	_show_owner_ring(String(card.get("wid", "")))

func _light_owner_only(card: Dictionary) -> void:
	_clear_spell_lights()
	if card.is_empty():
		return
	_show_owner_ring(String(card.get("wid", "")))

func _show_owner_ring(wid: String) -> void:
	for r in _ally_slots:
		if String(r["unit"]["id"]) == wid:
			_show_ring(r, "owner")
			return

func _show_ring(rec: Dictionary, kind: String) -> void:
	var m: Dictionary = rec.get("mark", {})
	if m.is_empty():
		return
	var ring: Panel = m["ring"]
	var sb: StyleBoxFlat = ring.get_theme_stylebox("panel") as StyleBoxFlat
	if kind == "owner":
		sb.border_color = Color("ffd766")
		sb.bg_color = Color(0.55, 0.42, 0.10, 0.10)
	else:
		sb.border_color = Color("8fd8b0")
		sb.bg_color = Color(0.10, 0.32, 0.18, 0.10)
	ring.visible = true
	(m["est"] as Control).visible = false
	_spell_lights.push_back(rec)

func _clear_spell_lights() -> void:
	for rec in _spell_lights:
		var ring := rec.get("mark", {}).get("ring") as Control
		if ring != null and is_instance_valid(ring):
			ring.visible = false
	_spell_lights = []
#endregion

func _process(_d: float) -> void:
	if _line and _line.visible and not _drag_mark.is_empty():
		var from: Control = _drag_mark.get("from")
		var to_wrap: Control = (_drag_mark["rec"] as Dictionary)["wrap"]
		if from != null and is_instance_valid(from) and is_instance_valid(to_wrap):
			var a0 := from.get_global_rect().get_center()
			var b0 := to_wrap.get_global_rect().get_center()
			var mid := (a0 + b0) * 0.5 + Vector2(0.0, -clampf(a0.distance_to(b0) * 0.22, 40.0, 150.0))
			var pts := PackedVector2Array()
			for i in 17:
				pts.push_back(_bez(a0, mid, b0, float(i) / 16.0))
			_line.points = pts
			var dir := (b0 - mid).normalized()
			var tip := b0 - dir * 12.0
			var back := tip - dir * 15.0
			_arrow.points = PackedVector2Array([
				back + dir.orthogonal() * 9.0, tip, back - dir.orthogonal() * 9.0])
			_arrow.visible = true
	#endregion

## 牌堆钮（v0.6 五区牌堆；STS2 制＝左下抽牌堆/右下弃牌堆，消耗堆随行）：
## 常驻计数，点击弹 QiDialog 网格视图（工厂卡 180×230）。手动弃牌带已随冲弃制退役。
func _build_pile_buttons() -> void:
	_pile_draw_btn = _make_pile_button("DrawPileBtn", "抽 0")
	_anchor(_pile_draw_btn, 0.012, 0.86, 0.105, 0.925)
	_pile_draw_btn.pressed.connect(func() -> void: _open_pile_view("抽牌堆", battle.draw_pile, true))
	add_child(_pile_draw_btn)
	_pile_discard_btn = _make_pile_button("DiscardPileBtn", "弃 0")
	_anchor(_pile_discard_btn, 0.895, 0.86, 0.988, 0.925)
	_pile_discard_btn.pressed.connect(func() -> void: _open_pile_view("弃牌堆", battle.discard_pile, false))
	add_child(_pile_discard_btn)
	_pile_exhaust_btn = _make_pile_button("ExhaustPileBtn", "消 0")
	_anchor(_pile_exhaust_btn, 0.895, 0.785, 0.988, 0.85)
	_pile_exhaust_btn.pressed.connect(func() -> void: _open_pile_view("消耗堆", battle.exhaust_pile, false))
	add_child(_pile_exhaust_btn)

func _make_pile_button(btn_name: String, txt: String) -> Button:
	var b := Button.new()
	b.name = btn_name
	b.text = txt
	b.tooltip_text = "点击查看牌堆内容（本堆顺序对局内保密的只显示数量与卡面）。"
	QISTYLE.apply_ghost(b)
	QISTYLE.font(b, QISTYLE.FS_BODY, true)
	b.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	return b

func _refresh_pile_counts() -> void:
	if _pile_draw_btn:
		_pile_draw_btn.text = "抽 %d" % battle.draw_pile.size()
	if _pile_discard_btn:
		_pile_discard_btn.text = "弃 %d" % battle.discard_pile.size()
	if _pile_exhaust_btn:
		_pile_exhaust_btn.text = "消 %d" % battle.exhaust_pile.size()

## 牌堆视图（1080×600 固定尺寸制）：工厂功法卡网格；secret=抽牌堆（不保序展示，防记序）
func _open_pile_view(title: String, pile: Array, secret: bool) -> void:
	var arr := QIDIALOG.create(self, title + " · %d 张" % pile.size(), Vector2(1080, 600), "关闭")
	var dialog: Control = arr[1]
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.content().add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	scroll.add_child(grid)
	var cards: Array = pile.duplicate()
	if secret:
		cards.shuffle()
	for c in cards:
		grid.add_child(QICARD.make_spell_card(String(c["spell"]["name"]),
			int(c["spell"]["cost"]), String(c["spell"]["desc"])))
	dialog.popup_centered()

## 结束回合 → 敌方阶段逐个行动 → 回合末结算 → 新回合
func _build_end_button() -> void:
	var b := Button.new()
	b.name = "EndButton"
	b.text = "结束回合"
	b.tooltip_text = "结束我方阶段，敌方按意图行动。"
	b.pressed.connect(_on_end_turn)
	_anchor(b, 0.88, 0.73, 0.945, 0.82)
	QISTYLE.apply_primary(b)
	QISTYLE.font(b, QISTYLE.FS_BIG, true)
	b.add_theme_color_override("font_color", Color("ffe9b0"))
	add_child(b)

func _on_end_turn() -> void:
	if _busy or battle.phase != "player":
		return
	_busy = true
	battle.end_turn()
	var n: int = battle.enemies.size()
	for i in n:
		if battle.phase != "enemy":
			break
		var e: Dictionary = battle.enemies[i]
		if not e["alive"]:
			continue
		# 敌方行动也走三段突进动画（跟拍意图目标）；增益类无目标则直接结算
		var from: Control = null
		var to: Control = null
		for r in _enemy_slots:
			if r["enemy"] == e:
				from = r["wrap"]
		var tuid := int(battle.intent_target_uid(e))
		for r in _ally_slots:
			if int(r["unit"]["uid"]) == tuid:
				to = r["wrap"]
		if from != null and to != null:
			await _anim_enemy(from, to, i)
		else:
			battle.apply_enemy_action(i)
			await get_tree().create_timer(0.35).timeout
	await get_tree().create_timer(0.25).timeout
	if battle.phase == "enemy":
		battle.finish_round()
	_busy = false

## 敌方阶段专用的突进包装（复用 _anim_attack，但不抢玩家 _busy 语义）
func _anim_enemy(from: Control, to: Control, idx: int) -> void:
	await _anim_attack(from, to, func() -> void: battle.apply_enemy_action(idx))

## 追击画面表现（2026-10-28 时序裁定：数值落各自命中帧）：主攻命中帧即时起跑（主攻回位段并行），
## 追击突进自己的命中帧飘「追击」＋伤害数字＋受击抖动；目标已亡则不追（无的可打）。
func _on_pursuit(attacker: Dictionary, target: Dictionary, dealt: int) -> void:
	if not bool(target.get("alive", false)) or dealt <= 0:
		return
	var from := _wrap_of_uid(int(attacker["uid"]))
	var to := _wrap_of_uid(int(target["uid"]))
	if from == null or to == null or not is_instance_valid(from) or not is_instance_valid(to):
		return
	if not from.visible:
		return
	var tc := to.get_global_rect().get_center()
	var orig := from.position
	var frect := from.get_global_rect()
	var dir := signf(frect.get_center().x - tc.x)
	if dir == 0.0:
		dir = 1.0
	var stop_at := tc - Vector2(dir * (CARD_W * 0.72), 0.0)
	var tw := create_tween()
	tw.tween_property(from, "position", orig + Vector2(dir * 10.0, 4.0), 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(from, "global_position", stop_at - frect.size * 0.5, 0.10)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_spawn_floater(tc, str(dealt), "追击")
		_spawn_floater(tc + Vector2(0, -30), "追击", "追击")
		_hit_reaction(to))
	tw.tween_property(from, "position", orig, 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## 战报浮字（左下，最新一条淡出）
func _build_log() -> void:
	_log_lbl = Label.new()
	_log_lbl.name = "EventLog"
	_log_lbl.text = ""
	_anchor(_log_lbl, 0.02, 0.70, 0.42, 0.745)
	QISTYLE.font(_log_lbl, QISTYLE.FS_SMALL)
	_log_lbl.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	_log_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_log_lbl)

func _on_event(text: String) -> void:
	if _log_lbl:
		_log_lbl.text = text
		_log_lbl.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(1.2)
		tw.tween_property(_log_lbl, "modulate:a", 0.35, 0.6)

## 全量重绑（实时连锁：任何状态变化即刷新一切派生显示——含意图实际结算值）
func _rebind() -> void:
	if not is_inside_tree():
		return
	_round_lbl.text = "回合 %d" % battle.round_no
	_cur_lbl.text = "铜钱 %d" % int(run_data.get("copper", 0))
	_build_energy_stack()
	_refresh_pile_counts()
	for rec in _enemy_slots:
		var e: Dictionary = rec["enemy"]
		_fill_intent_chip(rec["chip"], battle.intent_parts(e))
		_update_unit_hp(rec)
		var dead: bool = not e["alive"]
		(rec["slot"] as Control).visible = not dead   # 整槽隐＝行收拢居中（2026-10-28 阵亡重排裁定）
		if not dead:
			(rec["atk"] as Label).text = str(battle.atk_of(e))
			(rec["def"] as Label).text = str(battle.def_of(e))
			(rec["res"] as Label).text = str(battle.res_of(e))
			_refill_status_col(rec["statcol"])
	for rec in _ally_slots:
		var a: Dictionary = rec["unit"]
		var dead: bool = not a["alive"]
		(rec["slot"] as Control).visible = not dead   # 整槽隐＝行收拢居中（阵亡重排；战备舱才保空位）
		if not dead:
			(rec["acts"] as Label).text = str(int(a["acts"]))
			# 攻次珠明暗实时连锁（零攻＝暗芯，同拖不动门口径）
			var aorb: Control = rec["actsorb"]
			var acore: Panel = aorb.get_meta("core")
			var asb: StyleBoxFlat = acore.get_theme_stylebox("panel") as StyleBoxFlat
			var jc: Color = QISTYLE.JADE
			asb.bg_color = Color(jc.r, jc.g, jc.b, 0.9) if int(a["acts"]) > 0 \
				else Color(jc.r * 0.30, jc.g * 0.30, jc.b * 0.30, 0.85)
			# 拖动语义＝普攻：不能普攻者（无攻次/缴械/眩）收回拖源＝玩家反馈「拖不动」；
			# 功法落点不受影响（drop 通道独立）——引丝诀补攻次后实时恢复可拖（2026-10-28 用户裁定）。
			(rec["wrap"] as Control).card_data = {"atk_uid": int(a["uid"])} \
				if int(a["acts"]) > 0 and not battle.has_status(a, "jiaoxie") and not battle.has_status(a, "xuan") \
				else {}
			(rec["stats"] as Label).text = _ally_stat_text(a)
			_update_unit_hp(rec)
			_refill_status_col(rec["statcol"])
	_rebuild_hand()

## 意图徽章：图标＋实际结算数字（攻红/防蓝/状态紫；纯状态无数字）
func _fill_intent_chip(chip: PanelContainer, parts: Array) -> void:
	for c in chip.get_children():
		c.queue_free()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.02, 0.88)
	sb.border_color = _intent_border(parts)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	chip.add_theme_stylebox_override("panel", sb)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var first := true
	for p in parts:
		if not first:
			var plus := Label.new()
			plus.text = "＋"
			QISTYLE.font(plus, 14)
			plus.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
			box.add_child(plus)
		first = false
		var is_pos := bool(p.get("is_pos", false))
		var tint := Color("ffd766") if is_pos else _glyph_tint(String(p["g"]))
		var g := Label.new()
		g.text = String(p["g"])
		QISTYLE.font(g, 15 if is_pos else 16, is_pos)
		g.add_theme_color_override("font_color", tint)
		box.add_child(g)
		if p.has("n"):
			var num := Label.new()
			num.text = String(p["n"])
			QISTYLE.font(num, 16, true)
			num.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
			box.add_child(num)
	chip.add_child(box)

func _intent_border(parts: Array) -> Color:
	for p in parts:
		if p["g"] == "攻":
			return QISTYLE.RED
		if p["g"] == "防":
			return C_DEF
	return QISTYLE.PURPLE

func _glyph_tint(g: String) -> Color:
	if g == "攻":
		return Color("e88a70")
	if g == "防":
		return C_DEF
	return QISTYLE.PURPLE

## 胜负弹窗 → 写回 run → 自毁（QiRoot 接流程）
func _on_ended(result: String) -> void:
	await get_tree().create_timer(0.5).timeout
	var gi: int = int(run_data.get("group", 0))
	var fi: int = int(run_data.get("fight", 0))
	if result == "win":
		var base := 0
		if gi < QI_DATA.GROUPS.size() and fi < QI_DATA.GROUPS[gi]["fights"].size():
			base = int(QI_DATA.GROUPS[gi]["fights"][fi]["reward"])
		run_data["copper"] = int(run_data.get("copper", 0)) + base
		var arr := QIDIALOG.create(self, "战斗胜利", Vector2(520, 300), "继续")
		var dialog: Control = arr[1]
		var body := Label.new()
		body.text = "敌队尽灭！\n战利铜钱 +%d" % base
		QISTYLE.font(body, QISTYLE.FS_BODY, true)
		body.add_theme_color_override("font_color", Color(0.16, 0.14, 0.11))
		dialog.content().add_child(body)
		dialog.confirmed.connect(func() -> void:
			dialog.hide()
			# 单弹窗互斥在胜局弹窗出树（tree_exiting）才释放——挂 tree_exited 再开奖励，免竞态
			dialog.tree_exited.connect(_open_card_ops_reward))
		dialog.popup_centered(Vector2i(520, 300))
	else:
		var arr := QIDIALOG.create(self, "败北", Vector2(520, 300), "回备战")
		var dialog: Control = arr[1]
		var body := Label.new()
		body.text = "器灵尽数离场……\n本场无奖励，回备战舱重整旗鼓。"
		QISTYLE.font(body, QISTYLE.FS_BODY, true)
		body.add_theme_color_override("font_color", Color(0.16, 0.14, 0.11))
		dialog.content().add_child(body)
		dialog.confirmed.connect(func() -> void:
			dialog.hide()
			set_meta("qi_result", "lose")
			queue_free())
		dialog.popup_centered(Vector2i(520, 300))

## 战后奖励＝六类操作池三选一（v0.7 §7：先掷类型→子池掷对象；选项位＝卡面＋动作按钮；
## 刷新＝装备中器灵数×1 铜起、每刷 +1；跳过＝+5 铜；Boss 战固定一位「新增器灵·已升级（方向随机）」）。
const SKIP_COPPER := 5          # 跳过安慰铜（暂定）
const RESERVE_CAP := 3          # 后备上限（暂定；满员时「新增器灵」转必须装备形态）
var _reward_rng := RandomNumberGenerator.new()
var _reward_refreshes := 0
var _reward_options: Array = []

func _open_card_ops_reward() -> void:
	_reward_rng.randomize()
	_reward_refreshes = 0
	_reward_options = _roll_reward_options()
	var arr := QIDIALOG.create(self, "战利品 · 三选一", Vector2(1080, 640), "跳过（+%d铜）" % SKIP_COPPER)
	var dialog: Control = arr[1]
	dialog.confirmed.connect(func() -> void:
		run_data["copper"] = int(run_data.get("copper", 0)) + SKIP_COPPER
		_reward_finish(dialog, "已跳过奖励，铜钱 +%d" % SKIP_COPPER))
	dialog.content().add_child(_reward_page(dialog))
	dialog.popup_centered(Vector2i(1080, 640))

func _opt_key(opt: Dictionary) -> String:
	return "%s#%s#%s#%s" % [opt.get("kind", ""), opt.get("wid", ""), opt.get("sid", ""), str(opt.get("pre_dir", ""))]

func _roll_reward_options() -> Array:
	var out: Array = []
	var used := {}
	var boss := QI_DATA.is_boss_fight(int(run_data.get("group", 0)), int(run_data.get("fight", 0)))
	for i in 3:
		# Boss 保证位（第 0 位）：新增器灵·已升级（方向随机）；池空退化普通掷
		if i == 0 and boss and not QI_DATA.op_pool(run_data, "add_spirit").is_empty():
			var bpool: Array = QI_DATA.op_pool(run_data, "add_spirit")
			var pick: Dictionary = bpool[_reward_rng.randi_range(0, bpool.size() - 1)].duplicate()
			pick["pre_dir"] = 1 + _reward_rng.randi_range(0, 1)
			out.push_back(pick)
			used[_opt_key(pick)] = true
			continue
		for attempt in 40:
			var kinds: Array = []
			for k in QI_DATA.OP_KINDS:
				if not QI_DATA.op_pool(run_data, k).is_empty():
					kinds.push_back(k)
			if kinds.is_empty():
				break
			var kind: String = kinds[_reward_rng.randi_range(0, kinds.size() - 1)]
			var pool: Array = QI_DATA.op_pool(run_data, kind)
			var cand: Dictionary = pool[_reward_rng.randi_range(0, pool.size() - 1)].duplicate()
			if used.has(_opt_key(cand)):
				continue
			used[_opt_key(cand)] = true
			out.push_back(cand)
			break
	return out

## 主页：三选项位（卡面＋动作按钮）＋刷新／卡组计数
func _reward_page(dialog: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var tip := Label.new()
	tip.text = "先掷操作类型、再在该类型子池内掷对象——选一项即应用并关闭。"
	QISTYLE.font(tip, QISTYLE.FS_BODY)
	tip.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	box.add_child(tip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for opt in _reward_options:
		row.add_child(_reward_option_cell(dialog, opt))
	box.add_child(row)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	var rf := Button.new()
	rf.text = "刷新 ·%d铜" % _reward_refresh_price()
	rf.tooltip_text = "花铜钱重掷三个选项（每刷一次下次价格 +1；Boss 保证位刷新后仍在）。"
	QISTYLE.apply_ghost(rf)
	QISTYLE.font(rf, QISTYLE.FS_BODY, true)
	rf.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	rf.pressed.connect(func() -> void:
		var price := _reward_refresh_price()
		if int(run_data.get("copper", 0)) < price:
			return
		run_data["copper"] = int(run_data.get("copper", 0)) - price
		_reward_refreshes += 1
		_reward_options = _roll_reward_options()
		for c in dialog.content().get_children():
			c.queue_free()
		dialog.content().add_child(_reward_page(dialog)))
	foot.add_child(rf)
	var cnt := Label.new()
	cnt.text = "当前卡组 %d 张 · 装备中器灵 %d 件" % [run_data.get("deck", []).size(), run_data.get("team", []).size()]
	QISTYLE.font(cnt, QISTYLE.FS_SMALL)
	cnt.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	foot.add_child(cnt)
	box.add_child(foot)
	return box

func _reward_refresh_price() -> int:
	# 基价＝装备中器灵数 ×1（不含后备），每刷一次 +1
	return run_data.get("team", []).size() + _reward_refreshes

## 单个选项位：类型标＋卡面（功法＝功法卡／器灵＝器灵卡）＋动作按钮
func _reward_option_cell(dialog: Control, opt: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var kind := String(opt["kind"])
	var head := Label.new()
	head.text = String(QI_DATA.OP_NAMES[kind]) + ("·已升级" if opt.has("pre_dir") else "")
	QISTYLE.font(head, QISTYLE.FS_SMALL, true)
	head.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	col.add_child(head)
	var card: Control
	if kind in ["add_spirit", "upgrade_spirit"]:
		var w: Dictionary = QI_DATA.WEAPONS[String(opt["wid"])]
		var ptxt := "被动「%s」：%s" % [w["passive"]["name"], w["passive"]["desc"]]
		if opt.has("pre_dir"):
			ptxt += "\n已升级（方向%d）：%s" % [int(opt["pre_dir"]), String(w["passive"]["ups"].get(str(opt["pre_dir"]), ""))]
		card = QICARD.make_spirit_card({"name": String(w["name"]), "desc": ptxt})
	else:
		var spell: Dictionary = QI_DATA.spell_of(String(opt["wid"]), String(opt["sid"]), int(opt.get("dir", 0)))
		card = QICARD.make_spell_card(String(spell["name"]), int(spell["cost"]), String(spell["desc"]))
	col.add_child(card)
	var btn := Button.new()
	btn.text = String(QI_DATA.OP_BUTTONS[kind])
	btn.custom_minimum_size = Vector2(150, 44)
	QISTYLE.apply_primary(btn)
	QISTYLE.font(btn, QISTYLE.FS_BODY, true)
	btn.add_theme_color_override("font_color", Color("ffe9b0"))
	var o: Dictionary = opt
	btn.pressed.connect(func() -> void: _reward_apply(dialog, o))
	col.add_child(btn)
	return col

## 应用选项（升级类先换方向页；其余直接生效收尾）
func _reward_apply(dialog: Control, opt: Dictionary) -> void:
	match String(opt["kind"]):
		"add_spirit":
			_reward_add_spirit(dialog, opt)
		"upgrade_spirit":
			_reward_page_spirit_dir(dialog, opt)
		"upgrade_spell":
			_reward_page_spell_dir(dialog, opt)
		"add_spell":
			run_data.get("deck", []).push_back({"wid": opt["wid"], "sid": opt["sid"], "dir": 0})
			_reward_finish(dialog, "已为「%s」+1 张" % QI_DATA.spell_of(opt["wid"], opt["sid"], 0)["name"])
		"remove_spell":
			var deck: Array = run_data.get("deck", [])
			for i in deck.size():
				if String(deck[i]["wid"]) == String(opt["wid"]) and String(deck[i]["sid"]) == String(opt["sid"]) \
						and int(deck[i].get("dir", 0)) == int(opt.get("dir", 0)):
					deck.remove_at(i)
					break
			_reward_finish(dialog, "已从卡组移除 1 张「%s」"
				% QI_DATA.spell_of(opt["wid"], opt["sid"], int(opt.get("dir", 0)))["name"])
		"copy_spell":
			run_data.get("deck", []).push_back({"wid": opt["wid"], "sid": opt["sid"], "dir": int(opt.get("dir", 0))})
			_reward_finish(dialog, "已复制「%s」1 张（含升级方向）"
				% QI_DATA.spell_of(opt["wid"], opt["sid"], int(opt.get("dir", 0)))["name"])

## 功法升级方向页（v3：三真卡对照＋句级 diff 标记，点升级卡＝选方向）
func _reward_page_spell_dir(dialog: Control, opt: Dictionary) -> void:
	for c in dialog.content().get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := Label.new()
	var base_name: String = QI_DATA.spell_of(opt["wid"], opt["sid"], 0)["name"]
	head.text = "为「%s」选升级方向（一次机会，不可回退）：＋新增 －删除 改修改" % base_name
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	QISTYLE.font(head, QISTYLE.FS_BODY, true)
	head.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	box.add_child(head)
	box.add_child(QIUP.spell_dir_row(String(opt["wid"]), String(opt["sid"]), func(dir: int) -> void:
		var up: Dictionary = QI_DATA.spell_of(opt["wid"], opt["sid"], dir)
		var deck: Array = run_data.get("deck", [])
		for i in deck.size():
			if String(deck[i]["wid"]) == String(opt["wid"]) and String(deck[i]["sid"]) == String(opt["sid"]) \
					and int(deck[i].get("dir", 0)) == 0:
				deck[i]["dir"] = dir
				break
		_reward_finish(dialog, "已升级为「%s」" % up["name"])))
	dialog.content().add_child(box)

## 被动升级方向页（v3：主卡＋原被动文 vs 方向文对照块，点块＝选方向）
func _reward_page_spirit_dir(dialog: Control, opt: Dictionary) -> void:
	for c in dialog.content().get_children():
		c.queue_free()
	var w: Dictionary = QI_DATA.WEAPONS[String(opt["wid"])]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var head := Label.new()
	head.text = "为「%s」的被动「%s」选升级方向（不可回退）：" % [w["name"], w["passive"]["name"]]
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	QISTYLE.font(head, QISTYLE.FS_BODY, true)
	head.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	box.add_child(head)
	box.add_child(QIUP.passive_dir_block(String(opt["wid"]), func(dir: int) -> void:
		for m in run_data.get("team", []):
			if String(m["id"]) == String(opt["wid"]):
				m["pdir"] = dir
		_reward_finish(dialog, "「%s」被动已升级（方向%d）" % [w["name"], dir])))
	dialog.content().add_child(box)

## 新增器灵：后备有空位→入后备；后备满→必须装备（装备位空直接上；满则选一件替换——被替换者删除回未解锁）
func _reward_add_spirit(dialog: Control, opt: Dictionary) -> void:
	var wid := String(opt["wid"])
	var member := {"id": wid, "equips": ["", "", ""], "pdir": int(opt.get("pre_dir", 0))}
	var reserve: Array = run_data.get("reserve", [])
	if reserve.size() < RESERVE_CAP:
		reserve.push_back(member)
		run_data["reserve"] = reserve
		_reward_finish(dialog, "「%s」已入后备（备战舱拖上编队供牌）" % QI_DATA.WEAPONS[wid]["name"])
		return
	var team: Array = run_data.get("team", [])
	if team.size() < 7:
		team.push_back(member)
		run_data["team"] = team
		QI_DATA.deck_swap(run_data, "", wid)
		_reward_finish(dialog, "后备满员——「%s」已直接上阵（卡组 +4 张）" % QI_DATA.WEAPONS[wid]["name"])
		return
	# 替换页：选一件装备中器灵替换；被替换者删除回未解锁（升级清零、卡组条目移除）
	for c in dialog.content().get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var head := Label.new()
	head.text = "后备与装备位皆满——选一件装备中器灵替换（被替换者删除、回未解锁池）："
	QISTYLE.font(head, QISTYLE.FS_BODY, true)
	head.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for m in team:
		var w: Dictionary = QI_DATA.WEAPONS[String(m["id"])]
		var b := Button.new()
		b.text = "%s\n（被动%s）" % [w["name"], "已升级" if int(m.get("pdir", 0)) > 0 else "未升级"]
		b.custom_minimum_size = Vector2(230, 64)
		QISTYLE.apply_ghost(b)
		QISTYLE.font(b, QISTYLE.FS_SMALL)
		b.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
		var out_wid := String(m["id"])
		b.pressed.connect(func() -> void:
			var team2: Array = run_data.get("team", [])
			for i in range(team2.size() - 1, -1, -1):
				if String(team2[i]["id"]) == out_wid:
					team2.remove_at(i)
			team2.push_back({"id": wid, "equips": ["", "", ""], "pdir": int(opt.get("pre_dir", 0))})
			run_data["team"] = team2
			QI_DATA.deck_swap(run_data, out_wid, wid)
			_reward_finish(dialog, "「%s」已替换「%s」上阵（后者回未解锁池）"
				% [QI_DATA.WEAPONS[wid]["name"], QI_DATA.WEAPONS[out_wid]["name"]]))
		grid.add_child(b)
	box.add_child(grid)
	dialog.content().add_child(box)

func _reward_finish(dialog: Control, note: String) -> void:
	dialog.queue_free()
	dialog.tree_exited.connect(func() -> void:
		var arr := QIDIALOG.create(self, "战利品已入账", Vector2(520, 260), "继续")
		var fin: Control = arr[1]
		var body := Label.new()
		body.text = note + "\n（功法/插件新名现为占位，待正名）"
		QISTYLE.font(body, QISTYLE.FS_BODY)
		body.add_theme_color_override("font_color", Color(0.16, 0.14, 0.11))
		fin.content().add_child(body)
		fin.confirmed.connect(func() -> void:
			fin.queue_free()
			set_meta("qi_result", "win")
			queue_free())
		fin.popup_centered(Vector2i(520, 260)))

## 敌方血条（2026-10-28 用户裁定抄 STS2，实测 sts2-extract/scenes/combat/health_bar.tscn＋NHealthBar.cs）：
## 卡外下方；条宽＝卡宽＋24（两侧各探 12）高 16；墨青底 α0.75＋有盾淡蓝描边；填充红 F1373E/
## 有盾蓝 3B6FA3、中毒段绿 (0.475,0.753,0.235) 从血端左蚀；血数字奶油字红描边；盾徽 44 压条左端。
func _make_sts2_hp_bar(rec: Dictionary, unit: Dictionary) -> Control:
	rec["hpunit"] = unit
	var bar := Control.new()
	bar.name = "Sts2HpBar"
	bar.custom_minimum_size = Vector2(0, 16)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Control.new()
	box.name = "HpBox"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = -12.0    # 两侧各探出 12（锚点外扩不占槽宽）
	box.offset_right = 12.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(box)
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 1.0
	bg.offset_right = -1.0
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0.165, 0.376, 0.420, 0.753)
	bgs.set_corner_radius_all(3)
	bg.add_theme_stylebox_override("panel", bgs)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)
	var outline := Panel.new()
	outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	outline.offset_left = 1.0
	outline.offset_right = -1.0
	var ols := StyleBoxFlat.new()
	ols.bg_color = Color(0, 0, 0, 0)
	ols.border_color = Color(0.706, 0.886, 1.0, 0.95)
	ols.set_border_width_all(2)
	ols.set_corner_radius_all(3)
	outline.add_theme_stylebox_override("panel", ols)
	outline.visible = false
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(outline)
	var host := Control.new()
	host.name = "FillHost"
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.offset_left = 5.0
	host.offset_top = 3.0
	host.offset_right = -5.0
	host.offset_bottom = -3.0
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(host)
	var fill := Panel.new()
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 0.0
	fill.offset_right = 0.0
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color("F1373E")
	fill.add_theme_stylebox_override("panel", fs)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(fill)
	var pois := Panel.new()
	pois.anchor_top = 0.0
	pois.anchor_bottom = 1.0
	pois.offset_left = 0.0
	pois.offset_right = 0.0
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.475, 0.753, 0.235)
	pois.add_theme_stylebox_override("panel", ps)
	pois.visible = false
	pois.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(pois)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_top = -7.0
	lbl.offset_bottom = 8.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	QISTYLE.font(lbl, 15, true)
	lbl.add_theme_color_override("font_color", Color(1, 0.965, 0.886))
	lbl.add_theme_color_override("font_outline_color", Color(0.565, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	# 盾徽：压条左端（中心＝卡左缘），有护盾才显
	var blk := Panel.new()
	blk.custom_minimum_size = Vector2(44, 44)
	blk.position = Vector2(-10.0, -14.0)
	blk.z_index = 10
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.043, 0.332, 0.420)
	bs.border_color = Color(0.706, 0.886, 1.0, 0.9)
	bs.set_border_width_all(2)
	bs.corner_radius_top_left = 8
	bs.corner_radius_top_right = 8
	bs.corner_radius_bottom_left = 20
	bs.corner_radius_bottom_right = 20
	blk.add_theme_stylebox_override("panel", bs)
	blk.visible = false
	blk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(blk)
	# 真盾形线稿（game-icons.net badges/shield，CC BY；白线稿染淡蓝叠于徽底）
	var stex := load("res://qiforge/assets/gi/shield.svg") as Texture2D
	if stex != null:
		var str_ := TextureRect.new()
		str_.texture = stex
		str_.modulate = Color(0.706, 0.886, 1.0, 0.95)
		str_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		str_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		str_.set_anchors_preset(Control.PRESET_FULL_RECT)
		str_.offset_left = 5.0
		str_.offset_right = -5.0
		str_.offset_top = 4.0
		str_.offset_bottom = -4.0
		str_.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blk.add_child(str_)
	var blkl := Label.new()
	blkl.set_anchors_preset(Control.PRESET_FULL_RECT)
	blkl.offset_top = -3.0
	blkl.offset_bottom = 3.0
	blkl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blkl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	QISTYLE.font(blkl, 15, true)
	blkl.add_theme_color_override("font_color", Color(1, 0.965, 0.886))
	blkl.add_theme_color_override("font_outline_color", Color(0.043, 0.332, 0.420))
	blkl.add_theme_constant_override("outline_size", 4)
	blkl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blk.add_child(blkl)
	rec["hpbox"] = box
	rec["hpfill"] = fill
	rec["hppois"] = pois
	rec["hplbl"] = lbl
	rec["hpout"] = outline
	rec["hpblk"] = blk
	rec["hpblkl"] = blkl
	return bar

## 敌方血条实时刷新（STS2 制三态：红/有盾蓝；中毒段从血端左蚀；盾徽显隐＋数值）
## 单位血条实时刷新（敌我通用 STS2 制：红/有盾蓝；中毒段从血端左蚀；盾徽显隐＋数值）
func _update_unit_hp(rec: Dictionary) -> void:
	var e: Dictionary = rec["hpunit"]
	var mhp := maxi(1, int(e["mhp"]))
	var cur := clampi(int(e["hp"]), 0, mhp)
	var shield := int(battle.shield_of(e))
	var pois_n := int(battle.status_total(e, "zhongdu"))
	var ratio := float(cur) / float(mhp)
	var fill: Panel = rec["hpfill"]
	(fill.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("3B6FA3") if shield > 0 else Color("F1373E")
	fill.anchor_right = ratio
	var pl := maxf(0.0, float(cur - pois_n)) / float(mhp)
	(rec["hppois"] as Panel).visible = pois_n > 0 and pl < ratio
	(rec["hppois"] as Panel).anchor_left = pl
	(rec["hppois"] as Panel).anchor_right = ratio
	(rec["hpout"] as Control).visible = shield > 0
	(rec["hpblk"] as Control).visible = shield > 0
	(rec["hpblkl"] as Label).text = str(shield)
	(rec["hplbl"] as Label).text = "%d/%d" % [cur, mhp]

func _anchor(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.set_anchor(SIDE_LEFT, l)
	c.set_anchor(SIDE_TOP, t)
	c.set_anchor(SIDE_RIGHT, r)
	c.set_anchor(SIDE_BOTTOM, b)
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0

func _sb(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(8)
	return sb
