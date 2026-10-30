## 备战舱 v2（v0.7 属性重构轮：系统带＝Lv升级（奇偶制）＋能量/抽牌双徽＋刷新＋货架前5配件＋第6位操作位；
## 编队列 y40.7~77.6（名字行→纯立绘卡 234×329→装备格行；空位同基准）；后备 run_data 持久化。
## 机制（用户裁定）：配件购后空位（2026-10-29 去自动补货）·战后整架刷新·锁定免刷新·刷新带价；升级＝奇偶交替（奇次抽牌+1/偶次能量+1）；
## 最大灵力退役（v0.7）；器灵解锁/升级走战后奖励；拖拽＝原生协议。
## 用法：godot --path . res://qiforge/QiPrepBay.tscn -- --qi-shot → 1.2s 自动截图退出
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const QICARD := preload("res://qiforge/QiCardStyle.gd")
const QIDIALOG := preload("res://qiforge/QiDialog.gd")
const QI_DRAG := preload("res://qiforge/QiDragCard.gd")
const QI_DATA := preload("res://qiforge/QiData.gd")
const QIUP := preload("res://qiforge/QiUpgradePick.gd")
const QIPREFS := preload("res://qiforge/QiPrefs.gd")
const QITIP := preload("res://qiforge/QiTooltip.gd")
const BATTLE := preload("res://qiforge/QiBattleScreen.tscn")

static var PREP_W := QICARD.size_of("prep").x   # 备战舱展示位（基准 300×422 ×0.78，工厂 size_of 唯一权威）
static var PREP_H := QICARD.size_of("prep").y
const PREP_GAP := 18           # 列距 18＝步距 252
const NAME_ROW := 36           # 名字行（卡外顶行）
const EQ_W := 60               # 装备格
const EQ_H := 46
const OP_SLOT := 5             # 货架第 6 位（最右）＝操作位（2026-10-27 用户改裁；前 5 位配件）
# 2026-10-28 槽位制＋后备上限双退役：上场 ≤7、不上场不限量；上下场走「器灵」弹窗

## QiRoot 注入的 run 状态（钱袋/编队/后备/背包/卡组/系统等级同源）；直跑 tscn（截图/探针）用默认局
var run_data: Dictionary = {}

var _crew: Array = []                               # 7 槽（null＝空位）
var _reserve: Array = []                            # 后备（成员字典；随 run_data["reserve"] 持久化）
var _shelf: Array = []                              # 当前货架 6 位（第 6 位＝操作位）
var _sys_lv := 1
var _copper := 130
var _rng := RandomNumberGenerator.new()
var _odds_parts: Array = []            # 出货率行＝前缀＋五分色 Label（RichTextLabel 在 HBox 内被压窄自动折行、
										 # fit_content 顶爆系统带高度 1358px——2026-10-29 实测弃用，单行场景用 Label 拼）
## 品阶五色（2026-10-29 用户裁定分档显色）：凡品白／二档绿／三档蓝／四档紫／五档金
const TIER_COLORS := [Color("e8e2d4"), Color("8fd8b0"), Color("57b8d6"), Color("b48ae0"), Color("ffc94d")]
## 升级费＝75 起、每次升级 +25（2026-10-29 用户裁定：第 n 次升级＝75+25×(n−1)）
func _upgrade_cost() -> int:
	return 75 + 25 * maxi(0, _sys_lv - 1)

var _copper_lbl: Label
var _lv_btn: Button
var _energy_lbl: Label
var _draw_lbl: Label
var _shelf_box: HBoxContainer
var _crew_row: HBoxContainer
var _crew_count_lbl: Label

func _ready() -> void:
	QISTYLE.apply_root_theme(self)
	_rng.randomize()
	if run_data.is_empty():
		run_data = QI_DATA.default_run()
	_copper = int(run_data.get("copper", 130))
	_sys_lv = int(run_data.get("sys_lv", 1))   # 开局 Lv1（2026-10-29 再裁）：抽=4+⌊Lv/2⌋／能=3+⌊(Lv−1)/2⌋
	_crew = []
	for m in run_data.get("team", []):
		_crew.push_back(_crew_entry(m))   # 2026-10-28 槽位制退役：_crew＝紧凑队序，无空位
	_reserve = []
	for m in run_data.get("reserve", []):
		_reserve.push_back(_crew_entry(m))
	_shelf = _draw_shelf(6)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ground()
	_build_top_bar()
	_build_system()
	_build_crew_label()
	_build_crew_row()
	_build_roster_buttons()
	_build_go()
	# Boss 战利品直授提示（敌方设计 v0.1 §五）：一闪即清
	if String(run_data.get("grant_flash", "")) != "":
		var gw := String(run_data["grant_flash"])
		run_data.erase("grant_flash")
		_flash("夺获「%s」！已入后备（跨局解锁：此后新局亦可遇之）" % QI_DATA.WEAPONS[gw]["name"])
	if "--qi-shot" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/.qi_prep_preview.png")
		get_tree().quit()

## 操作位掷货（第 6 位）：与战后奖励同池——先掷类型（等权、空池出局）→子池内掷对象；两档定价
func _draw_op() -> Dictionary:
	var kinds: Array = []
	for k in QI_DATA.OP_KINDS:
		if not QI_DATA.op_pool(run_data, k).is_empty():
			kinds.push_back(k)
	if kinds.is_empty():
		return {"is_op": false, "id": "", "name": "暂无操作可售", "lv": 1, "desc": "当前无可用卡组/器灵操作。", "price": 0, "locked": false}
	var kind: String = kinds[_rng.randi_range(0, kinds.size() - 1)]
	var pool: Array = QI_DATA.op_pool(run_data, kind)
	var opt: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
	var desc := ""
	if kind in ["add_spirit", "upgrade_spirit", "heal"]:
		# heal 条目无 sid（真凶 2026-10-29：heal 掉进功法 else 分支＝opt["sid"] 崩，与奖励页 1804 分支对齐）
		if kind == "heal":
			var mem := QI_DATA.find_member(run_data, String(opt["wid"]))
			var amt: int = QI_DATA.reward_heal_amount(mem)
			desc = "耐久 %d/%d → 回复 %d 点（至 %d/%d）" % [QI_DATA.hp_of(mem), QI_DATA.mhp_of(mem), amt,
				mini(QI_DATA.mhp_of(mem), QI_DATA.hp_of(mem) + amt), QI_DATA.mhp_of(mem)]
		else:
			var w: Dictionary = QI_DATA.WEAPONS[String(opt["wid"])]
			desc = "%s——被动「%s」：%s" % [String(w["name"]), String(w["passive"]["name"]), String(w["passive"]["desc"])]
	else:
		var spell: Dictionary = QI_DATA.spell_of(String(opt["wid"]), String(opt["sid"]), int(opt.get("dir", 0)))
		desc = "「%s」（%d 能量）：%s" % [String(spell["name"]), int(spell["cost"]), String(spell["desc"])]
	return {"is_op": true, "kind": kind, "wid": opt.get("wid", ""), "sid": opt.get("sid", ""),
		"dir": int(opt.get("dir", 0)), "name": String(QI_DATA.OP_NAMES[kind]), "desc": desc,
		"price": QI_DATA.op_price(kind), "locked": false}

## 配件抽货＝品级加权（档率对齐系统蓝本实测；空池顺延更低档）
func _draw_one() -> Dictionary:
	var odds: Array = QI_DATA.tier_odds(_sys_lv)
	var roll := _rng.randi_range(1, 100)
	var acc := 0
	var pos := 0
	for i in odds.size():
		acc += int(odds[i])
		if roll <= acc:
			pos = i
			break
	var lv := int(QI_DATA.TIER_LADDER[pos])
	var pool := QI_DATA.tier_pool(lv)
	# 空池兜底：档位循环顺延直到非空（数据缺档不炸货架）
	var guard := 0
	while pool.is_empty() and guard < QI_DATA.TIER_LADDER.size():
		guard += 1
		var ti := (QI_DATA.TIER_LADDER.find(lv) + 1) % QI_DATA.TIER_LADDER.size()
		lv = int(QI_DATA.TIER_LADDER[ti])
		pool = QI_DATA.tier_pool(lv)
	var id: String = pool[_rng.randi_range(0, pool.size() - 1)]
	var a: Dictionary = QI_DATA.ACCESSORIES[id]
	return {"is_op": false, "id": id, "name": a["name"], "lv": int(a["lv"]), "desc": a["desc"],
		"price": int(a["price"]), "locked": false}

func _draw_shelf(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.push_back(_draw_op() if i == OP_SLOT else _draw_one())
	return out

## 编队条目＝静态文案壳（名字/被动/功法——不因插件变）；
## 属性/耐久/配件名单 2026-10-29 起一律显示点现算（weapon_panel/mhp_of 活查询，
## 装/卸插件实时连锁——旧 attrs/hp/mhp/equips 快照字段已退役，反锁定制）
func _crew_entry(m: Dictionary) -> Dictionary:
	var wid: String = m["id"]
	var w: Dictionary = QI_DATA.WEAPONS[wid]
	var passive_txt := "%s：%s" % [w["passive"]["name"], w["passive"]["desc"]]
	var pdir := int(m.get("pdir", 0))
	if pdir > 0:
		passive_txt += "\n已升级（方向%d）：%s" % [pdir, String(w["passive"].get("ups", {}).get(str(pdir), ""))]
	var spells: Array = []
	for s in w["spells"]:
		spells.push_back("%s（%d 能量）：%s" % [s["name"], s["cost"], s["desc"]])
	return {"name": w["name"], "seal": w["seal"], "_member": m,
		"passive": passive_txt,
		"spells": spells}

## run.team 永远＝_crew 非空位成员序；run.reserve＝后备成员序（换位/入后备/上阵后即同步）
func _sync_team() -> void:
	var team: Array = []
	for c in _crew:
		if c != null:
			team.push_back(c["_member"])
	run_data["team"] = team
	var res: Array = []
	for r in _reserve:
		res.push_back(r["_member"])
	run_data["reserve"] = res

func _reload_crew() -> void:
	_crew = []
	for m in run_data.get("team", []):
		_crew.push_back(_crew_entry(m))
	_sync_team()
	_rebuild_crew_cols()

func _reload_reserve() -> void:
	_reserve = []
	for m in run_data.get("reserve", []):
		_reserve.push_back(_crew_entry(m))

func _next_label() -> String:
	return QI_DATA.fight_label(int(run_data.get("group", 0)), int(run_data.get("fight", 0)))

func _build_ground() -> void:
	var bg := ColorRect.new()
	bg.color = QISTYLE.INK_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

## 顶栏：左＝功能钮；右＝下一场情报＋本组情报＋铜钱（复用战斗屏建造器形制；金币已退役 2026-10-27）
func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.name = "TopBar"
	_anchor(bar, 0.012, 0.014, 0.24, 0.052)
	bar.add_theme_constant_override("separation", 10)
	for pair in [["卡组", "查看当前卡组全部功法牌（排序：按器灵/按费用；点击看详情）。"],
			["图鉴", "器灵谱与词条图鉴"], ["重战", "快速读档：回到上一场战斗前重打本场（同敌方意图）"], ["设置", "音量与偏好设置"], ["退出", "返回主菜单"]]:
		var b := Button.new()
		b.text = pair[0]
		b.tooltip_text = pair[1]
		if String(pair[0]) == "卡组":
			b.name = "DeckBtn"
			b.pressed.connect(func() -> void: _open_deck_view())
		QISTYLE.apply_ghost(b)
		QISTYLE.font(b, QISTYLE.FS_SMALL)
		b.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
		if String(pair[0]) == "重战":
			b.pressed.connect(func() -> void:
				var p := get_parent()
				if p != null and p.has_method("_rewind_battle"):
					p._rewind_battle())   # 独立跑 tscn/探针＝无宿主，静默不响应
		elif String(pair[0]) == "设置":
			b.pressed.connect(func() -> void: QIPREFS.open_settings(self))
		elif String(pair[0]) == "退出":
			b.pressed.connect(func() -> void:
				var p := get_parent()
				if p != null and p.has_method("_exit_to_menu"):
					p._exit_to_menu())   # 备战舱退出＝存档回主菜单
		bar.add_child(b)
	add_child(bar)
	var right := HBoxContainer.new()
	_anchor(right, 0.50, 0.014, 0.988, 0.052)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 16)
	var tag := PanelContainer.new()
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.24, 0.10, 0.08, 0.9)
	tsb.border_color = Color(0.72, 0.29, 0.20, 0.9)
	tsb.set_border_width_all(2)
	tsb.set_corner_radius_all(6)
	tsb.content_margin_left = 12.0
	tsb.content_margin_right = 12.0
	tsb.content_margin_top = 3.0
	tsb.content_margin_bottom = 3.0
	tag.add_theme_stylebox_override("panel", tsb)
	var tt := Label.new()
	tt.text = "下一场"
	QISTYLE.font(tt, QISTYLE.FS_SMALL)
	tt.add_theme_color_override("font_color", Color("ffb3a0"))
	tag.add_child(tt)
	right.add_child(tag)
	var nx := Label.new()
	nx.text = _next_label()
	nx.tooltip_text = "进组即可见本组三场敌档；组内可随时查看。"
	QISTYLE.font(nx, QISTYLE.FS_BODY)
	nx.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	right.add_child(nx)
	var intel := Button.new()
	intel.text = "本组情报"
	intel.tooltip_text = "查看本组三场敌档（含组末强敌）。"
	intel.pressed.connect(_open_group_intel)
	QISTYLE.apply_ghost(intel)
	QISTYLE.font(intel, QISTYLE.FS_SMALL)
	intel.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	right.add_child(intel)
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 8)
	var ic := Panel.new()
	ic.custom_minimum_size = Vector2(22, 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = QISTYLE.AMBER
	sb.set_corner_radius_all(11)
	ic.add_theme_stylebox_override("panel", sb)
	cell.add_child(ic)
	var tx := Label.new()
	tx.text = str(_copper)
	QISTYLE.font(tx, QISTYLE.FS_SMALL)
	tx.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	cell.add_child(tx)
	_copper_lbl = tx
	right.add_child(cell)
	add_child(right)

func _refresh_currency() -> void:
	_copper_lbl.text = str(_copper)
	run_data["copper"] = _copper

## 系统带：边框对齐下方器灵列（7×234＋6×18＝1746 居中，两侧各外延 14）
func _build_system() -> void:
	var panel := PanelContainer.new()
	panel.name = "SystemPanel"
	_anchor(panel, 0.0362, 0.0815, 0.9638, 0.3625)
	var psb := QISTYLE.panel(0.55)
	psb.content_margin_left = 18.0
	psb.content_margin_right = 18.0
	psb.content_margin_top = 14.0
	psb.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", psb)
	var v := VBoxContainer.new()
	v.name = "SystemBody"
	v.add_theme_constant_override("separation", 12)
	var head := HBoxContainer.new()
	head.name = "SystemHead"
	head.add_theme_constant_override("separation", 18)
	_lv_btn = Button.new()
	_lv_btn.name = "LvUpButton"
	_lv_btn.tooltip_text = "升级系统：升到偶数级→抽牌 +1、升到奇数级→能量上限 +1；费用 75 铜起、每次升级 +25；配件出货率随级上浮。"
	_lv_btn.pressed.connect(_on_upgrade)
	QISTYLE.apply_primary(_lv_btn)
	QISTYLE.font(_lv_btn, QISTYLE.FS_BIG, true)
	_lv_btn.add_theme_color_override("font_color", Color("ffe9b0"))
	head.add_child(_lv_btn)
	# v0.7：能量上限／每回合抽牌双徽（奇偶公式；最大灵力已退役）
	var chip_style := func() -> StyleBoxFlat:
		var msb := StyleBoxFlat.new()
		msb.bg_color = Color(0.06, 0.05, 0.03, 0.6)
		msb.border_color = Color(QISTYLE.AMBER.r, QISTYLE.AMBER.g, QISTYLE.AMBER.b, 0.45)
		msb.set_border_width_all(1)
		msb.set_corner_radius_all(10)
		msb.content_margin_left = 16.0
		msb.content_margin_right = 16.0
		return msb
	var ecap := PanelContainer.new()
	ecap.add_theme_stylebox_override("panel", chip_style.call())
	var eh := HBoxContainer.new()
	eh.add_theme_constant_override("separation", 9)
	var el := Label.new()
	el.text = "能量上限"
	QISTYLE.font(el, QISTYLE.FS_BODY)
	el.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	eh.add_child(el)
	_energy_lbl = Label.new()
	_energy_lbl.text = str(QI_DATA.energy_cap_of(_sys_lv))
	QISTYLE.font(_energy_lbl, 22, true)
	_energy_lbl.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	eh.add_child(_energy_lbl)
	ecap.add_child(eh)
	head.add_child(ecap)
	var dcap := PanelContainer.new()
	dcap.add_theme_stylebox_override("panel", chip_style.call())
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 9)
	var dl := Label.new()
	dl.text = "每回合抽牌"
	QISTYLE.font(dl, QISTYLE.FS_BODY)
	dl.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	dh.add_child(dl)
	_draw_lbl = Label.new()
	_draw_lbl.text = str(QI_DATA.draw_of(_sys_lv))
	QISTYLE.font(_draw_lbl, 22, true)
	_draw_lbl.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	dh.add_child(_draw_lbl)
	dcap.add_child(dh)
	head.add_child(dcap)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var odds_row := HBoxContainer.new()
	odds_row.name = "OddsRow"
	odds_row.mouse_filter = Control.MOUSE_FILTER_PASS
	odds_row.tooltip_text = "每次补货/刷新按此概率抽品级，再从该品级池等权抽配件；五档制（含 Lv2）＝2026-10-29 用户裁定表。"
	var odds_head := Label.new()
	odds_head.text = "出货率（随系统升级上浮）："
	QISTYLE.font(odds_head, QISTYLE.FS_SMALL)
	odds_head.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	odds_row.add_child(odds_head)
	_odds_parts = []
	for i in QI_DATA.TIER_LADDER.size():
		var l := Label.new()
		l.name = "OddsTier%d" % i
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		QISTYLE.font(l, QISTYLE.FS_SMALL)
		l.add_theme_color_override("font_color", TIER_COLORS[i % TIER_COLORS.size()])
		odds_row.add_child(l)
		_odds_parts.push_back(l)
	head.add_child(odds_row)
	var rf := Button.new()
	rf.name = "ReflashButton"
	rf.text = "刷新 ·%d铜" % (1 + _refresh_used)   # 1 铜起每刷 +1（2026-10-29 用户裁定）
	rf.tooltip_text = "立即整架刷新货架（锁定项保留）。价格 1 铜起、每刷 +1，每场战斗重置。"
	rf.pressed.connect(_on_refresh)
	QISTYLE.apply_ghost(rf)
	QISTYLE.font(rf, QISTYLE.FS_BODY)
	rf.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	head.add_child(rf)
	v.add_child(head)
	_shelf_box = HBoxContainer.new()
	_shelf_box.name = "GoodsRow"
	_shelf_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_shelf_box.add_theme_constant_override("separation", 20)
	v.add_child(_shelf_box)
	panel.add_child(v)
	add_child(panel)
	_restyle_lv()
	_refresh_odds()
	_rebuild_shelf()

func _refresh_odds() -> void:
	if _odds_parts.is_empty():
		return
	var odds: Array = QI_DATA.tier_odds(_sys_lv)
	for i in _odds_parts.size():
		var seg := "Lv%d %d%%" % [int(QI_DATA.TIER_LADDER[i]), int(odds[i])]
		(_odds_parts[i] as Label).text = ("" if i == 0 else "｜") + seg

func _restyle_lv() -> void:
	_lv_btn.text = "系统 Lv%d ↑升级 ·%d铜" % [_sys_lv, _upgrade_cost()]

func _rebuild_shelf() -> void:
	for c in _shelf_box.get_children():
		c.queue_free()
	for d in _shelf:
		_shelf_box.add_child(_make_goods(d))

## 配件富浮窗挂接（STS2 制 QiTooltip；2026-10-29 用户点名：配件浮窗与战斗浮窗同款，
## 不再走原生 tooltip_text——简单动作提示仍留原生，少码优先③边界）。
## tail＝描述后追加行（专属效果行等）。
func _bind_tip(host: Control, title: String, desc: String, foot: String,
		title_color: Variant = null, tail: Array = []) -> void:
	var trow := {"t": "title", "text": title}
	if title_color != null:
		trow["color"] = title_color
	var rows: Array = [trow, {"t": "sep"}, {"t": "line", "text": desc}]
	for r in tail:
		rows.push_back(r)
	if foot != "":
		rows.push_back({"t": "line", "text": foot})
	host.mouse_entered.connect(func() -> void: QITIP.show_for(host, rows, {"min_w": 240.0}))
	host.mouse_exited.connect(func() -> void: QITIP.hide_for(host))

## 专属效果浮窗行（2026-10-29 用户裁定：浮窗显示专属效果，并列效果各自分框）
func _excl_tail(aid: String) -> Array:
	var tail: Array = []
	for e in QI_DATA.excl_effects(aid):
		tail.push_back({"t": "frame", "text": "专属·%s：%s" % [e["spirit"], e["text"]]})
	return tail

func _tier_color_of(lv: int) -> Color:
	return TIER_COLORS[clampi(QI_DATA.TIER_LADDER.find(lv), 0, TIER_COLORS.size() - 1)]

## 配件小卡（第 6 位＝操作位变体；2026-10-27 改正方形 170×170）：件面板（名/效果）＋
## 底行〔购买签｜锁定钮〕（2026-10-29 用户裁定：锁钮从面板右上浮层挪到购买旁；操作位无锁）
func _make_goods(d: Dictionary) -> Control:
	var goods := VBoxContainer.new()
	goods.add_theme_constant_override("separation", 5)
	var part := Panel.new()
	part.custom_minimum_size = Vector2(170, 170)
	var sb := StyleBoxFlat.new()
	if d.is_empty():
		# 已售空位（2026-10-29 用户裁定：购后不自动补货——空置待手动/战后整架刷新补新）
		sb.bg_color = Color(0.10, 0.088, 0.06)
		sb.border_color = Color(0.24, 0.20, 0.12)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(10)
		part.add_theme_stylebox_override("panel", sb)
		part.tooltip_text = "已售空位——手动刷新或战后整架刷新补新。"
		var sold := Label.new()
		sold.text = "已售"
		sold.set_anchors_preset(Control.PRESET_FULL_RECT)
		sold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		QISTYLE.font(sold, QISTYLE.FS_SMALL)
		sold.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
		part.add_child(sold)
		goods.add_child(part)
		return goods
	sb.bg_color = Color(0.165, 0.141, 0.094) if not d.get("is_op", false) else Color(0.13, 0.12, 0.18)
	sb.border_color = "6b5426" if not d.get("is_op", false) else "6a5a8a"
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	part.add_theme_stylebox_override("panel", sb)
	if d.get("is_op", false):
		_bind_tip(part, String(d["name"]), String(d["desc"]), "")
	else:
		_bind_tip(part, String(d["name"]), QI_DATA.desc_of(String(d["id"])), "",
			_tier_color_of(int(d["lv"])), _excl_tail(String(d["id"])))
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 14.0
	inner.offset_right = -14.0
	inner.offset_top = 10.0
	inner.offset_bottom = -10.0
	inner.add_theme_constant_override("separation", 4)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 9)
	var nm := Label.new()
	# 配件名＝裸名＋品阶色着色（2026-10-29 用户裁定：去「配件 ·」前缀与 Lv 品阶徽，颜色承载品阶；
	# 操作位仍留「操作 ·」前缀以分位）
	if d.get("is_op", false):
		nm.text = "操作 · %s" % String(d["name"])
		nm.add_theme_color_override("font_color", Color("c8b8f0"))
	else:
		nm.text = String(d["name"])
		nm.add_theme_color_override("font_color",
			TIER_COLORS[clampi(QI_DATA.TIER_LADDER.find(int(d["lv"])), 0, TIER_COLORS.size() - 1)])
	QISTYLE.font(nm, QISTYLE.FS_BODY, true)
	row1.add_child(nm)
	inner.add_child(row1)
	var eff := Label.new()
	eff.text = String(d["desc"]) if d.get("is_op", false) else QI_DATA.desc_of(String(d["id"]))
	QISTYLE.font(eff, QISTYLE.FS_SMALL)
	eff.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(eff)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(sp)
	part.add_child(inner)
	goods.add_child(part)
	var brow := HBoxContainer.new()   # 底行＝购买签＋锁定钮并排（2026-10-29 裁定：锁在购买旁）
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 8)
	var price := Button.new()
	price.text = "●%d" % int(d["price"])
	if d.get("is_op", false):
		price.tooltip_text = "购入操作《%s》——购后立即执行（升级类需再选方向）。" % String(d["name"])
	else:
		price.tooltip_text = "购入《%s》；购后入背包，本位空置待刷新补新。" % String(d["name"])
	price.pressed.connect(_on_buy.bind(d, part))
	QISTYLE.apply_ghost(price)
	QISTYLE.font(price, QISTYLE.FS_BODY, true)
	price.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	brow.add_child(price)
	if not d.get("is_op", false):
		var lock := Button.new()
		lock.name = "LockButton"
		lock.text = "已锁" if d["locked"] else "锁"
		lock.tooltip_text = "锁定：战后整架刷新时本货位保留。"
		lock.custom_minimum_size = Vector2(48, 30)
		lock.pressed.connect(func() -> void:
			d["locked"] = not d["locked"]
			lock.text = "已锁" if d["locked"] else "锁"
			_style_lock(lock, d["locked"]))
		_style_lock(lock, d["locked"])
		brow.add_child(lock)
	goods.add_child(brow)
	return goods

func _style_lock(lock: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.13, 0.09, 0.9)
	sb.border_color = Color(QISTYLE.AMBER.r, QISTYLE.AMBER.g, QISTYLE.AMBER.b, 0.85 if on else 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	lock.add_theme_stylebox_override("normal", sb)
	lock.add_theme_stylebox_override("hover", sb)
	lock.add_theme_stylebox_override("pressed", sb)
	lock.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT if on else QISTYLE.TEXT_SUB)
	QISTYLE.font(lock, QISTYLE.FS_SMALL)

## 编队标签行 y36.8（随系统带加高下移）：编队 n/7＋注记（后备落区已移左下角独立件，2026-10-28 用户裁定）
func _build_crew_label() -> void:
	var row := HBoxContainer.new()
	_anchor(row, 0.043, 0.368, 0.957, 0.4015)
	row.add_theme_constant_override("separation", 18)
	var zl := Label.new()
	zl.text = "编队"
	QISTYLE.font(zl, QISTYLE.FS_TITLE, true)
	zl.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	row.add_child(zl)
	var cnt := Label.new()
	cnt.name = "CrewCount"
	_crew_count_lbl = cnt
	cnt.text = "%d / 7" % _crew_count()
	QISTYLE.font(cnt, QISTYLE.FS_SMALL)
	cnt.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	row.add_child(cnt)
	var note := Label.new()
	note.text = "拖卡换位 · 点卡看详情 · 「器灵」弹窗上下场/疗伤 · 卡下＝配件装备格〔格数待定〕"
	note.tooltip_text = "被动＝器灵自身效果，见详情卡。"
	QISTYLE.font(note, QISTYLE.FS_SMALL)
	note.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	row.add_child(note)
	add_child(row)

# 2026-10-28 槽位制＋后备上限双退役：上场 ≤7、不上场不限量；入口＝顶栏「器灵」「卡组」
# 整屏页（STS2 DeckViewScreen 制，规格照抄＋免费素材优先）
## 器灵入口（2026-10-29 用户裁定：出战正上方；250×70＝满编装备格底 866px 下不压列）
func _build_roster_buttons() -> void:
	var b := Button.new()
	b.name = "RosterBtn"
	b.text = "器 灵"
	b.tooltip_text = "本局已获全部器灵：上场/离场、疗伤、功法与详情（上场至多 7 件，不上场不限量）。"
	b.pressed.connect(func() -> void: _open_roster())
	_anchor(b, 0.860, 0.806, 0.990, 0.876)
	QISTYLE.apply_primary(b)
	QISTYLE.font(b, 24, true)
	b.add_theme_color_override("font_color", Color("ffe9b0"))
	add_child(b)

func _crew_count() -> int:
	return _crew.size()

## 编队列 y40.7~77.6：7 列（列＝名字行 36 → 纯立绘卡 235×300 → 装备格行；空位同基准）
func _build_crew_row() -> void:
	_crew_row = HBoxContainer.new()
	_crew_row.name = "CrewRow"
	_crew_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(_crew_row, 0.0, 0.404, 1.0, 0.802)   # v3.0 卡高 329：带 436~866 容 立绘卡＋名字行＋装备格
	_crew_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_crew_row.add_theme_constant_override("separation", PREP_GAP)
	add_child(_crew_row)
	_rebuild_crew_cols()

func _rebuild_crew_cols() -> void:
	for c in _crew_row.get_children():
		_crew_row.remove_child(c)   # 立即离树再释放：queue_free 延帧期间同名新列会被 Godot 自动改名（@VBox…）——按名寻径即炸
		c.queue_free()
	# 2026-10-28 槽位制退役：只画在场器灵（紧凑队序），HBox 居中＝自动居中排列；
	# 换位＝卡拖到卡（_on_swap 保留），空槽/拖后备区已废。
	for i in _crew.size():
		var col := VBoxContainer.new()
		col.name = "CrewCol%d" % i
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		col.add_theme_constant_override("separation", 8)
		col.custom_minimum_size = Vector2(PREP_W, 0)
		var mem_i: Dictionary = _crew[i]["_member"]
		var mhp_i := QI_DATA.mhp_of(mem_i)
		var hp_i := QI_DATA.hp_of(mem_i)
		var hp_txt := "%d/%d" % [hp_i, mhp_i]
		var warn := false
		if hp_i <= 0:
			hp_txt = "阵亡"
			warn = true
		elif hp_i < mhp_i:
			warn = true
		col.add_child(_make_col_name("%s　%s" % [String(_crew[i]["name"]), hp_txt], warn))
		col.add_child(_make_crew_card(i, _crew[i]))
		col.add_child(_make_equip_row(_crew[i]["_member"]))
		_crew_row.add_child(col)
	if _crew_count_lbl:
		_crew_count_lbl.text = "%d / 7" % _crew_count()

func _make_col_name(text: String, warn := false) -> Control:
	# 定高 36 容器内居中（Label 行高会超 min，空位垫块是定值 36——不定高则相邻列卡顶差 3px 跳位）
	var box := Control.new()
	box.custom_minimum_size = Vector2(PREP_W, NAME_ROW)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	QISTYLE.font(l, QISTYLE.FS_TITLE, true)
	l.add_theme_color_override("font_color", Color("e07a6a") if warn else QISTYLE.TEXT_MAIN)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return box

## 器灵卡＝QiDragCard 壳（拖源＋落点＋点击详情三合一）；内层纯立绘视觉件 IGNORE
func _make_crew_card(slot_i: int, d: Dictionary) -> Control:
	var w: Control = QI_DRAG.new()
	w.name = "CrewWrap%d" % slot_i
	w.custom_minimum_size = Vector2(PREP_W, PREP_H)
	w.card_data = {"slot": slot_i, "unit": d}
	w.preview_card = _make_card_visual(d)
	w.preview_card.modulate = Color(1, 1, 1, 0.75)
	w.drop_ok = func(data) -> bool: return data is Dictionary and data.has("drag_data") and data["drag_data"].get("slot") != slot_i
	w.on_drop = func(data, _zone) -> void: _on_swap(int(data["drag_data"]["slot"]), slot_i)
	## 点击详情＝判定在「释放」而非按压，且本按压周期起过拖拽（drag_armed）即让位：
	## 拖拽收尾后的释放事件仍会落到卡上（gui_is_dragging 已翻 false），光靠它拦不住。
	w.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				w.drag_armed = false
			elif not w.drag_armed and not get_viewport().gui_is_dragging():
				_open_detail(d))
	var vis := _make_card_visual(d)
	vis.set_anchors_preset(Control.PRESET_FULL_RECT)
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(vis)
	return w

## 纯立绘卡面（整卡＝立绘位；工厂公共件，无立绘器灵由工厂退「立绘位」占位）
func _make_card_visual(d: Dictionary) -> Panel:
	return QICARD.make_portrait_panel(String(d.get("name", "")), "prep")

## 装备格行（卡下，可点＝装配入口）：全配件格（被动＝器灵自身效果走详情）
## 绑定＝成员字典引用（2026-10-28 修插件跟槽不跟灵：换位产生空位后，槽位序≠压缩队序，
## 按 run.team[i] 索引会错读到别的成员——引用制下插件永远跟着器灵走）
func _make_equip_row(m: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "EquipRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER   # 三格 196 宽在 234 列内居中（2026-10-28 用户裁定，勿左贴）
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot_i in 3:
		var eid := ""
		if slot_i < m["equips"].size():
			eid = String(m["equips"][slot_i])
		row.add_child(_make_equip_slot(eid, m, slot_i))
	return row

func _make_equip_slot(eid: String, m: Dictionary, slot_i: int) -> Button:
	var ic := Button.new()
	ic.custom_minimum_size = Vector2(EQ_W, EQ_H)
	var filled := not eid.is_empty()
	var sb := StyleBoxFlat.new()
	if not filled:
		sb.bg_color = Color(0.10, 0.08, 0.06, 0.5)
		sb.border_color = Color(0.42, 0.35, 0.16, 0.5)
	else:
		sb.bg_color = Color(QISTYLE.JADE.r * 0.2, QISTYLE.JADE.g * 0.2, QISTYLE.JADE.b * 0.2, 0.9)
		sb.border_color = QISTYLE.JADE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	ic.add_theme_stylebox_override("normal", sb)
	ic.add_theme_stylebox_override("hover", sb)
	ic.add_theme_stylebox_override("pressed", sb)
	ic.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var label_text: String = QI_DATA.ACCESSORIES[eid]["name"] if filled and QI_DATA.ACCESSORIES.has(eid) else "空"
	ic.text = label_text
	QISTYLE.font(ic, 13)
	ic.add_theme_color_override("font_color", Color(0.85, 0.93, 0.78) if filled else Color(1, 1, 1, 0.28))
	if filled and QI_DATA.ACCESSORIES.has(eid):
		var acc: Dictionary = QI_DATA.ACCESSORIES[eid]
		_bind_tip(ic, String(acc["name"]), QI_DATA.desc_of(eid), "",
			_tier_color_of(int(acc["lv"])), _excl_tail(eid))
	else:
		ic.tooltip_text = "空配件格——点击从背包装配。"
	ic.pressed.connect(func() -> void: _open_equip(m, slot_i))
	return ic

## 装备窗（1080×760 固定尺寸制）：当前槽＋背包配件网格，点选即装配/卸下（成员引用绑定，随器灵走）
## 2026-10-28 用户裁定：无背板遮罩（dim=false，输入门保留）＋免 flash 提示＋即点即关（close 管线）
func _open_equip(m: Dictionary, slot_i: int) -> void:
	var wname := String(QI_DATA.WEAPONS[m["id"]]["name"])
	var pair: Array = QIDIALOG.create(self,
		"装配 · %s · 槽位 %d" % [wname, slot_i + 1], Vector2(1080, 760), "关闭", "", true, true, false)
	var scrim: ColorRect = pair[0]
	var dialog: Control = pair[1]
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	var cur_eid := String(m["equips"][slot_i]) if slot_i < m["equips"].size() else ""
	var cur := Label.new()
	if not cur_eid.is_empty() and QI_DATA.ACCESSORIES.has(cur_eid):
		var a: Dictionary = QI_DATA.ACCESSORIES[cur_eid]
		cur.text = "当前：%s（Lv%d）—— %s" % [a["name"], a["lv"], QI_DATA.desc_of(cur_eid)]
	else:
		cur.text = "当前：空槽位。"
	QISTYLE.font(cur, QISTYLE.FS_BODY)
	cur.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	body.add_child(cur)
	if not cur_eid.is_empty():
		var uneq := Button.new()
		uneq.text = "卸下此槽"
		uneq.tooltip_text = "配件回背包。"
		uneq.pressed.connect(func() -> void:
			m["equips"][slot_i] = ""
			QI_DATA.plugin_hp_shift(m, cur_eid, false)   # 血件卸下：当前耐久同扣（2026-10-29 裁定）
			run_data.get("bag", []).push_back(cur_eid)
			QIDIALOG.close(scrim, dialog)
			_rebuild_crew_cols())
		QISTYLE.apply_ghost(uneq)
		QISTYLE.font(uneq, QISTYLE.FS_SMALL)
		uneq.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
		body.add_child(uneq)
	var head := Label.new()
	var bag: Array = run_data.get("bag", [])
	head.text = "背包（%d 件）——点击装入槽位 %d：" % [bag.size(), slot_i + 1]
	QISTYLE.font(head, QISTYLE.FS_BODY, true)
	head.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	body.add_child(head)
	if bag.is_empty():
		var hint := Label.new()
		hint.text = "背包空——到上方系统区货架购入配件（购后立即入包）。"
		QISTYLE.font(hint, QISTYLE.FS_SMALL)
		hint.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
		body.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	for eid in bag:
		if not QI_DATA.ACCESSORIES.has(String(eid)):
			continue
		grid.add_child(_make_bag_item(String(eid), m, slot_i, dialog, scrim))
	body.add_child(grid)
	dialog.content().add_child(body)
	dialog.popup_centered(Vector2i(1080, 760))

func _make_bag_item(eid: String, m: Dictionary, slot_i: int, dialog: Control, scrim: ColorRect) -> Button:
	var a: Dictionary = QI_DATA.ACCESSORIES[eid]
	var b := Button.new()
	b.custom_minimum_size = Vector2(320, 96)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.141, 0.094)
	sb.border_color = Color("6b5426")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.border_color = QISTYLE.AMBER
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# 文字＝货架同款纯 Label 拼色（bbcode 是 RichTextLabel 专属属性，挂 Label 上即崩——2026-10-28）
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 12.0
	inner.offset_right = -12.0
	inner.offset_top = 8.0
	inner.offset_bottom = -8.0
	inner.add_theme_constant_override("separation", 2)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	var nm := Label.new()
	nm.text = String(a["name"])
	QISTYLE.font(nm, QISTYLE.FS_SMALL, true)
	nm.add_theme_color_override("font_color", Color("ffd766"))
	row1.add_child(nm)
	var meta := Label.new()
	meta.text = "（Lv%d）　%d●" % [int(a["lv"]), int(a["price"])]
	QISTYLE.font(meta, QISTYLE.FS_SMALL)
	meta.add_theme_color_override("font_color", Color("8f8672"))
	row1.add_child(meta)
	inner.add_child(row1)
	var de := Label.new()
	de.text = QI_DATA.desc_of(eid)   # 含尾行「专属：器灵名」（通用件＝原文）
	QISTYLE.font(de, QISTYLE.FS_SMALL)
	de.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	de.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(de)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	b.pressed.connect(func() -> void:
		# 替换＝旧件先卸回包（配件＝背包资产，2026-10-29 补：旧覆盖即蒸发之修）＋血件耐久联动
		var old_eid := String(m["equips"][slot_i])
		if not old_eid.is_empty():
			m["equips"][slot_i] = ""
			QI_DATA.plugin_hp_shift(m, old_eid, false)
			run_data.get("bag", []).push_back(old_eid)
		m["equips"][slot_i] = eid
		QI_DATA.plugin_hp_shift(m, eid, true)
		bag_remove_one(eid)
		QIDIALOG.close(scrim, dialog)
		_rebuild_crew_cols())
	return b

func bag_remove_one(eid: String) -> void:
	var bag: Array = run_data.get("bag", [])
	for i in bag.size():
		if String(bag[i]) == eid:
			bag.remove_at(i)
			return

## 详情页（卡牌工厂详情层承载；点遮罩或任一卡关闭）：主卡＝器灵面板（属性＋被动），
## 右列＝两张功法真卡作衍生牌（2026-10-26 用户裁定，参照 STS2 检视页：主卡旁竖排真卡）。
func _open_detail(d: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	var card := Button.new()
	card.custom_minimum_size = QICARD.size_of("detail")
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("normal", QISTYLE.panel(0.92))
	card.add_theme_stylebox_override("hover", QISTYLE.panel(0.92))
	card.add_theme_stylebox_override("pressed", QISTYLE.panel(0.92))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18.0
	v.offset_right = -18.0
	v.offset_top = 14.0
	v.offset_bottom = -14.0
	v.add_theme_constant_override("separation", 8)
	var nm := Label.new()
	nm.text = String(d["name"])
	QISTYLE.font(nm, QISTYLE.FS_TITLE, true)
	nm.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	v.add_child(nm)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 2)
	# 属性现算（2026-10-29 反锁定制）：打开时点活查询 weapon_panel——装/卸插件即时连锁
	var mem_a: Dictionary = d["_member"]
	var panel_a: Dictionary = QI_DATA.weapon_panel(String(mem_a["id"]), mem_a.get("equips", []))
	var attrs: Dictionary = {"耐久": "%d/%d" % [QI_DATA.hp_of(mem_a), QI_DATA.mhp_of(mem_a)],
		"攻击": int(panel_a["atk"]), "威力": int(panel_a["pow"]),
		"防御": int(panel_a["def"]), "抗性": int(panel_a["res"]), "攻击次数": int(panel_a["acts"])}
	for k in attrs:
		var kl := Label.new()
		kl.text = String(k)
		QISTYLE.font(kl, QISTYLE.FS_SMALL)
		kl.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
		grid.add_child(kl)
		var vl := Label.new()
		vl.text = str(attrs[k])
		QISTYLE.font(vl, QISTYLE.FS_SMALL)
		vl.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
		grid.add_child(vl)
	v.add_child(grid)
	var pv := Label.new()
	pv.text = String(d["passive"])
	pv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pv.custom_minimum_size.x = 230
	QISTYLE.font(pv, QISTYLE.FS_SMALL)
	pv.add_theme_color_override("font_color", Color("ffd766"))
	v.add_child(pv)
	card.add_child(v)
	row.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	var cap := Label.new()
	cap.text = "功法 · 衍生牌"
	QISTYLE.font(cap, QISTYLE.FS_SMALL)
	cap.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	col.add_child(cap)
	var wid: String = String(d["_member"]["id"])
	for s in QI_DATA.WEAPONS[wid]["spells"]:
		col.add_child(QICARD.make_spell_card(String(s["name"]), int(s["cost"]), String(s["desc"])))
	row.add_child(col)
	var layer: Control = QICARD.make_detail_layer(row, row.get_combined_minimum_size())
	add_child(layer)
	# 回血制（2026-10-28 §7）：疗伤（金币通道）＋收起入后备（手动后备显式入口，拖拽同效）——
	# 按钮挂层内卡正下方（不动详情卡尺寸；layer 已建故闭包引用合法）
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 12)
	act_row.mouse_filter = Control.MOUSE_FILTER_PASS
	var mem_d: Dictionary = d["_member"]
	var mhp_d := QI_DATA.mhp_of(mem_d)
	var cost_d := QI_DATA.heal_price(mem_d)
	var heal_btn := Button.new()
	if cost_d > 0:
		heal_btn.text = "疗伤（%d 铜，回复至满）" % cost_d
	else:
		heal_btn.text = "耐久完好"
	heal_btn.tooltip_text = "金币通道：存活＝缺口×1 铜；阵亡＝缺口×1.5 铜（暂定）。"
	heal_btn.disabled = cost_d <= 0 or int(run_data.get("copper", 0)) < cost_d
	QISTYLE.apply_ghost(heal_btn)
	QISTYLE.font(heal_btn, QISTYLE.FS_SMALL)
	heal_btn.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	heal_btn.pressed.connect(func() -> void:
		run_data["copper"] = int(run_data.get("copper", 0)) - cost_d
		_copper = int(run_data["copper"])
		if _copper_lbl:
			_copper_lbl.text = str(_copper)
		mem_d["hp"] = mhp_d
		if layer.is_inside_tree():
			layer.queue_free()
		_rebuild_crew_cols()
		_flash("「%s」已回复至满耐久（−%d 铜）" % [String(d["name"]), cost_d]))
	act_row.add_child(heal_btn)
	var on_field := false
	for c in _crew:
		if c["_member"] == mem_d:
			on_field = true
	if on_field:
		var bench_btn := Button.new()
		bench_btn.text = "离场"
		bench_btn.tooltip_text = "功法卡随档保留（升级不清零）；配件卸回背包；未上场池每场战后回血。"
		bench_btn.disabled = _crew_count() <= 1
		QISTYLE.apply_ghost(bench_btn)
		QISTYLE.font(bench_btn, QISTYLE.FS_SMALL)
		bench_btn.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
		bench_btn.pressed.connect(func() -> void:
			if layer.is_inside_tree():
				layer.queue_free()
			_bench_member(mem_d))
		act_row.add_child(bench_btn)
	layer.add_child(act_row)
	act_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	act_row.offset_top = 16.0
	act_row.offset_bottom = 62.0
	var closer := func() -> void:
		if layer.is_inside_tree():
			layer.queue_free()
	card.pressed.connect(closer)
	for c in col.get_children():
		if c is Button:
			c.pressed.connect(closer)

var _deny_sfx: AudioStream = null

## 买不起反馈（2026-10-27 用户裁定＝STS2 NMerchantSlot 制）：货位正弦摇摆 ±10px／0.4s Quad.Out
## ＋失望音效（参数照 STS2 WiggleAnimation；音效＝仓内 Kenney ui-pack switch-b 降调 0.55——
## 外部 error 类音源三路下载未通暂用回退，如实注记）。
func _deny_feedback(node: Control) -> void:
	if _deny_sfx == null:
		var fl: Node = get_node_or_null("/root/FileLoader")
		if fl != null:
			_deny_sfx = fl.load_audio("res://external/kenney/ui-pack/Sounds/switch-b.ogg", true)
			if _deny_sfx == null:
				_deny_sfx = AudioStream.new()   # 占位空流：探针环境无 FileLoader 时静默跳过
	if _deny_sfx != null and _deny_sfx is AudioStreamOggVorbis:
		var sm: Node = get_node_or_null("/root/SoundManager")
		if sm != null:
			sm.play_ui_sound_with_pitch(_deny_sfx, 0.55)
	if node == null or not is_instance_valid(node):
		return
	var base_x := node.position.x
	var tw := node.create_tween()
	tw.tween_method(func(p: float) -> void:
		node.position.x = base_x + sin(p * TAU) * 10.0, 0.0, 2.0, 0.4)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

## 商店操作（2026-10-29 用户裁定：购后不自动补货——本位空置「已售」，待手动刷新/战后整架刷新补新，
## 连锁定一并清）：配件购入＝扣钱入背包＋位空置；操作位购入＝扣钱立即执行＋位空置；
## 刷新＝扣钱换未锁位（操作位随刷新重掷）；升级＝奇偶交替＆出货率上浮
func _on_buy(d: Dictionary, slot_node: Control) -> void:
	var cost: int = int(d["price"])
	if _copper < cost:
		_deny_feedback(slot_node)
		return
	_copper -= cost
	_refresh_currency()
	var idx := _shelf.find(d)
	if idx >= 0:
		_shelf[idx] = {}
		_rebuild_shelf()
	if d.get("is_op", false):
		_apply_shop_op(d)
		return
	run_data.get("bag", []).push_back(String(d["id"]))
	_flash("已入背包：%s（点器灵下装备格装配）" % String(d["name"]))

## 执行操作位购买（升级类弹方向二选一；器灵类走安置规则）
func _apply_shop_op(d: Dictionary) -> void:
	var kind := String(d["kind"])
	match kind:
		"add_spell":
			run_data.get("deck", []).push_back({"wid": d["wid"], "sid": d["sid"], "dir": 0})
			_flash("已为「%s」+1 张" % QI_DATA.spell_of(d["wid"], d["sid"], 0)["name"])
		"remove_spell":
			var deck: Array = run_data.get("deck", [])
			for i in deck.size():
				if String(deck[i]["wid"]) == String(d["wid"]) and String(deck[i]["sid"]) == String(d["sid"]) \
						and int(deck[i].get("dir", 0)) == int(d["dir"]):
					deck.remove_at(i)
					break
			_flash("已从卡组移除 1 张")
		"copy_spell":
			run_data.get("deck", []).push_back({"wid": d["wid"], "sid": d["sid"], "dir": int(d["dir"])})
			_flash("已复制 1 张（含升级方向）")
		"upgrade_spell":
			_pick_dir_dialog("为「%s」选升级方向" % QI_DATA.spell_of(d["wid"], d["sid"], 0)["name"],
				func(cb: Callable) -> Control: return QIUP.spell_dir_row(String(d["wid"]), String(d["sid"]), cb),
				func(dir: int) -> void:
					var deck: Array = run_data.get("deck", [])
					for i in deck.size():
						if String(deck[i]["wid"]) == String(d["wid"]) and String(deck[i]["sid"]) == String(d["sid"]) \
								and int(deck[i].get("dir", 0)) == 0:
							deck[i]["dir"] = dir
							break
					_flash("功法已升级（方向%d）" % dir))
		"upgrade_spirit":
			var w: Dictionary = QI_DATA.WEAPONS[String(d["wid"])]
			_pick_dir_dialog("为「%s」的被动「%s」选方向" % [w["name"], w["passive"]["name"]],
				func(cb: Callable) -> Control: return QIUP.passive_dir_block(String(d["wid"]), cb),
				func(dir: int) -> void:
					for m in run_data.get("team", []):
						if String(m["id"]) == String(d["wid"]):
							m["pdir"] = dir
					_flash("被动已升级（方向%d）" % dir))
		"add_spirit":
			var wid := String(d["wid"])
			var member := {"id": wid, "equips": ["", "", ""], "pdir": 0}
			var reserve: Array = run_data.get("reserve", [])
			reserve.push_back(member)   # 未上场池不限量（2026-10-28 后备上限退役）；上场走「器灵」弹窗
			run_data["reserve"] = reserve
			_reload_reserve()
			_flash("「%s」已入未上场池（「器灵」弹窗可上场）" % QI_DATA.WEAPONS[wid]["name"])

## 方向二选一弹窗（v3：真卡对照件 QiUpgradePick——功法＝三卡＋diff／被动＝主卡＋方向块；
## 已付费操作位，必须点选方向才关窗：无取消键、ESC 不关、确认键禁用）
func _pick_dir_dialog(title: String, chooser_bound: Callable, on_pick: Callable) -> void:
	var arr: Array = QIDIALOG.create(self, title, Vector2(1080, 640), "请点选升级方向", "", false)
	if arr[1] == null:
		return
	var dialog: Control = arr[1]
	dialog.get_ok_button().disabled = true
	var chooser: Control = chooser_bound.call(func(dir: int) -> void:
		dialog.queue_free()
		on_pick.call(dir))
	dialog.content().add_child(chooser)
	dialog.popup_centered(Vector2i(1080, 640))

var _refresh_used := 0   # 刷新递增计数（2026-10-29 用户裁定：1 铜起、每刷 +1）

func _refresh_price() -> int:
	return 1 + _refresh_used

func _on_refresh() -> void:
	var cost := _refresh_price()
	if _copper < cost:
		_flash("铜钱不足")
		return
	_copper -= cost
	_refresh_used += 1
	_refresh_currency()
	var rf2 := find_child("ReflashButton", false, false) as Button
	if rf2 != null:
		rf2.text = "刷新 ·%d铜" % _refresh_price()
	for i in _shelf.size():
		if not (_shelf[i] as Dictionary).get("locked", false):   # 已售空位无 locked 键——缺省＝未锁，照常掷新
			_shelf[i] = _draw_op() if i == OP_SLOT else _draw_one()
	_rebuild_shelf()
	_flash("货架已刷新")

func _on_upgrade() -> void:
	var cost := _upgrade_cost()
	if _copper < cost:
		_flash("铜钱不足")
		return
	# 奇偶制（2026-10-29 再裁）：升到偶数级→抽牌+1、升到奇数级→能量上限+1
	var dst := _sys_lv + 1
	var eff := "抽牌 %d → %d" % [QI_DATA.draw_of(_sys_lv), QI_DATA.draw_of(dst)] if dst % 2 == 0 \
		else "能量上限 %d → %d" % [QI_DATA.energy_cap_of(_sys_lv), QI_DATA.energy_cap_of(dst)]
	_copper -= cost
	_refresh_currency()
	_sys_lv += 1
	run_data["sys_lv"] = _sys_lv
	_energy_lbl.text = str(QI_DATA.energy_cap_of(_sys_lv))
	_draw_lbl.text = str(QI_DATA.draw_of(_sys_lv))
	_restyle_lv()
	_refresh_odds()
	_flash("系统 Lv%d · %s" % [_sys_lv, eff])

## 编队换位（原生拖放回调；2026-10-28 槽位制退役后＝紧凑队序内换位，卡拖到卡；自动居中排列）
func _on_swap(from_i: int, to_i: int) -> void:
	if from_i < 0 or from_i >= _crew.size() or to_i < 0 or to_i >= _crew.size() or from_i == to_i:
		return
	var tmp = _crew[from_i]
	_crew[from_i] = _crew[to_i]
	_crew[to_i] = tmp
	_sync_team()
	_rebuild_crew_cols()

## 离场（详情页按钮与器灵弹窗同入口；升级保留制＝功法卡随档带走；配件离队即卸回背包）
func _bench_member(m: Dictionary) -> void:
	var idx := -1
	for i in _crew.size():
		if _crew[i]["_member"] == m:
			idx = i
			break
	if idx < 0:
		return
	if _crew_count() <= 1:
		_flash("编队至少保留一件器灵")
		return
	var wid := String(m["id"])
	var removed := 0
	for de in run_data.get("deck", []):
		if String(de["wid"]) == wid:
			removed += 1
	QI_DATA.deck_swap(run_data, wid, "")
	var uneq: Array = QI_DATA.unequip_all(run_data, m)
	_reserve.push_back(_crew[idx])
	_crew.remove_at(idx)
	_sync_team()
	_rebuild_crew_cols()
	var msg := "已离场（%d 张功法卡随档保留，未上场池每场战后回血）" % removed
	if not uneq.is_empty():
		msg += "；已卸下配件→背包：%s" % "、".join(uneq)
	_flash(msg)

## 上场（器灵弹窗入口；排末位＝备战区最右；阵亡者须经回复通道复活）
func _field_member(entry: Dictionary) -> bool:
	if _crew.size() >= 7:
		_flash("上场已满（7/7）——先离场一件再上")
		return false
	var wid := String(entry["_member"]["id"])
	_crew.push_back(entry)
	_reserve.erase(entry)
	QI_DATA.deck_swap(run_data, "", wid)
	_sync_team()
	_rebuild_crew_cols()
	_flash("「%s」已上场（卡组 +4 张，排末位）" % String(entry["name"]))
	return true

## —— STS2 DeckViewScreen 式整屏页（2026-10-28 用户裁定：弹窗逻辑/画面表现与 STS2 一致；
## 规格实测 scenes/screens/deck_view_screen.tscn：全屏覆盖＋顶排序带 y92~152 高 60＋
## 排序钮 250×42 居中间距 50＋滚动区左右各让 175＋底中黑 75% 计数条＋底左返回钮；
## 素材三步制：底板 kenney CC0（qiforge/assets/kenney），无可搬贴图处自绘复刻）。
func _sts2_page(page_name: String, bottom_text: String) -> Dictionary:
	var layer := Control.new()
	layer.name = page_name
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 60
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var plate := ColorRect.new()
	plate.color = Color(0, 0, 0, 0.85)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(plate)
	# 返回钮（back_button.tscn 位制＝底左）：kenney 西向箭头＋文字
	var back := Button.new()
	back.text = " 返回"
	back.tooltip_text = "回到备战舱。"
	back.icon = load("res://qiforge/assets/kenney/arrow_basic_w.png") as Texture2D
	back.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.custom_minimum_size = Vector2(190, 56)
	_anchor(back, 0.012, 0.886, 0.13, 0.964)
	QISTYLE.apply_ghost(back)
	QISTYLE.font(back, 20, true)
	back.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	back.pressed.connect(func() -> void: layer.queue_free())
	layer.add_child(back)
	# 底中计数条（BottomText 制：黑 75% 圆角＋内边 16）
	var btm := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0, 0, 0, 0.7529)
	bsb.set_corner_radius_all(6)
	bsb.content_margin_left = 16.0
	bsb.content_margin_right = 16.0
	bsb.content_margin_top = 4.0
	bsb.content_margin_bottom = 4.0
	btm.add_theme_stylebox_override("panel", bsb)
	btm.anchor_left = 0.5
	btm.anchor_right = 0.5
	btm.anchor_top = 1.0
	btm.anchor_bottom = 1.0
	btm.offset_left = -160.0
	btm.offset_right = 160.0
	btm.offset_top = -57.0
	btm.offset_bottom = -17.0
	var blbl := Label.new()
	blbl.text = bottom_text
	QISTYLE.font(blbl, QISTYLE.FS_SMALL)
	blbl.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	btm.add_child(blbl)
	layer.add_child(btm)
	# 滚动区（左右各让 175；顶让排序带 176、底让 80）
	var scroll := ScrollContainer.new()
	scroll.name = "PageScroll"
	_anchor(scroll, 0.0, 0.0, 1.0, 1.0)
	scroll.offset_left = 175.0
	scroll.offset_right = -175.0
	scroll.offset_top = 176.0
	scroll.offset_bottom = -80.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	# 上下渐隐（card_grid.tscn BorderGradient 制）：单张全屏＋Cubic 平滑＋上下各 5% 黑 0.9；
	# 旧两张 CONSTANT 阶梯插值是黑线病根（95% 区域全透明渐隐失效＋尾缘 ~3px 硬黑线，2026-10-29 修）
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	grad.offsets = PackedFloat32Array([0.0, 0.05, 0.95, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.9), Color(0, 0, 0, 0),
		Color(0, 0, 0, 0), Color(0, 0, 0, 0.9)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 2
	gt.height = 256
	gt.fill_to = Vector2(0, 1)
	var fade := TextureRect.new()
	fade.texture = gt
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.z_index = 5
	layer.add_child(fade)
	add_child(layer)
	return {"layer": layer, "scroll": scroll, "bottom": blbl}

## 器灵页：本局全部已获器灵——真卡＋血量＋功法名＋上场/离场/疗伤；点卡＝详情页
func _open_roster() -> void:
	if find_child("RosterPage", false, false) != null:
		return
	var page: Dictionary = _sts2_page("RosterPage",
		"上场 %d/7 · 共 %d 件" % [_crew.size(), _crew.size() + _reserve.size()])
	var layer: Control = page["layer"]
	var scroll: ScrollContainer = page["scroll"]
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	var head := Label.new()
	head.text = "本局已获 %d 件 · 上场 %d/7（不上场不限量；未上场池每场战后回血；在场顺序＝备战区排列）" \
		% [_crew.size() + _reserve.size(), _crew.size()]
	QISTYLE.font(head, QISTYLE.FS_SMALL)
	head.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	body.add_child(head)
	for i in _crew.size():
		body.add_child(_make_roster_row(_crew[i], true, i, layer))
	for r in _reserve:
		body.add_child(_make_roster_row(r, false, -1, layer))
	scroll.add_child(body)

func _make_roster_row(entry: Dictionary, equipped: bool, order_i: int, layer: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	# 真卡（点击＝详情页；按钮壳包立绘面板，点击面积＝整卡）
	var card_btn := Button.new()
	card_btn.custom_minimum_size = Vector2(PREP_W, PREP_H)
	card_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	card_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	card_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	card_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var visual: Panel = _make_card_visual(entry)
	visual.set_anchors_preset(Control.PRESET_FULL_RECT)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_btn.add_child(visual)
	card_btn.pressed.connect(func() -> void: _open_detail(entry))
	row.add_child(card_btn)
	# 信息列：名（在场位次/阵亡）＋血量＋功法名
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 6)
	var m: Dictionary = entry["_member"]
	var mhp := QI_DATA.mhp_of(m)
	var hp := clampi(int(m.get("hp", mhp)), 0, mhp)
	var t1 := Label.new()
	t1.text = "%s%s　耐久 %d/%d%s" % [String(entry["name"]),
		" · 在场第 %d 位" % (order_i + 1) if equipped else "", hp, mhp,
		" · 阵亡" if hp <= 0 else ""]
	QISTYLE.font(t1, QISTYLE.FS_BODY, true)
	t1.add_theme_color_override("font_color",
		Color("e07a6a") if hp <= 0 else (QISTYLE.AMBER_BRIGHT if equipped else QISTYLE.TEXT_MAIN))
	info.add_child(t1)
	var sp_names: Array = []
	for s in QI_DATA.WEAPONS[String(m["id"])]["spells"]:
		sp_names.push_back(String(s["name"]))
	var t2 := Label.new()
	t2.text = "功法：%s" % "、".join(PackedStringArray(sp_names))
	QISTYLE.font(t2, QISTYLE.FS_SMALL)
	t2.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	info.add_child(t2)
	# 操作行：上场/离场＋疗伤（页内即关页再执行，回备战看新状态）
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	var tog := Button.new()
	if equipped:
		tog.text = "离场"
		tog.tooltip_text = "功法卡随档保留（升级不清零）；配件卸回背包；未上场池每场战后回血。"
		tog.disabled = _crew_count() <= 1
		tog.pressed.connect(func() -> void:
			layer.queue_free()
			_bench_member(m))
	else:
		tog.text = "上场"
		tog.tooltip_text = "入备战区末位；功法卡随档还原（升级保留）。阵亡者须经回复通道复活。"
		tog.disabled = hp <= 0 or _crew.size() >= 7
		tog.pressed.connect(func() -> void:
			if _field_member(entry):
				layer.queue_free())
	QISTYLE.apply_ghost(tog)
	QISTYLE.font(tog, QISTYLE.FS_SMALL)
	tog.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	btns.add_child(tog)
	var heal := Button.new()
	var cost_r := QI_DATA.heal_price(m)
	heal.text = "疗伤 %d 铜" % cost_r if cost_r > 0 else "耐久完好"
	heal.tooltip_text = "金币通道：回复至满耐久（存活＝缺口×1 铜、阵亡＝×1.5，暂定）。"
	heal.disabled = cost_r <= 0 or int(run_data.get("copper", 0)) < cost_r
	heal.pressed.connect(func() -> void:
		run_data["copper"] = int(run_data.get("copper", 0)) - cost_r
		_copper = int(run_data["copper"])
		if _copper_lbl:
			_copper_lbl.text = str(_copper)
		m["hp"] = mhp
		layer.queue_free()
		_rebuild_crew_cols()
		_flash("「%s」已回复至满耐久（−%d 铜）" % [String(entry["name"]), cost_r]))
	QISTYLE.apply_ghost(heal)
	QISTYLE.font(heal, QISTYLE.FS_SMALL)
	heal.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	btns.add_child(heal)
	info.add_child(btns)
	row.add_child(info)
	return row

var _deck_sort := "wid"   # 卡组弹窗排序："wid"＝按器灵（默认，备战区序）/ "cost"＝按费用

## 卡组页（STS2 DeckViewScreen 制）：顶排序带（钮 250×42 居中间距 50，kenney 底）＋真卡网格＋底中计数
func _open_deck_view() -> void:
	if find_child("DeckPage", false, false) != null:
		return
	var deck: Array = run_data.get("deck", [])
	var page: Dictionary = _sts2_page("DeckPage", "当前卡组 %d 张" % deck.size())
	var layer: Control = page["layer"]
	var scroll: ScrollContainer = page["scroll"]
	# 顶排序带（SortingOptions 制：y92~152 高 60、左让 56 右让 33）
	var strip := PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.07, 0.06, 0.045, 0.92)
	ssb.border_color = Color(QISTYLE.AMBER.r, QISTYLE.AMBER.g, QISTYLE.AMBER.b, 0.55)
	ssb.set_border_width_all(2)
	ssb.set_corner_radius_all(10)
	ssb.content_margin_left = 14.0
	ssb.content_margin_right = 14.0
	strip.add_theme_stylebox_override("panel", ssb)
	strip.anchor_top = 0.0
	strip.anchor_bottom = 0.0
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.offset_left = 231.0    # 175 滚动让位＋56
	strip.offset_right = -208.0  # 175＋33
	strip.offset_top = 92.0
	strip.offset_bottom = 152.0
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 50)
	# kenney CC0 长条钮底＝StyleBoxTexture 九宫格（规格照抄制：免费素材优先）
	var kbtn: StyleBoxTexture = StyleBoxTexture.new()
	kbtn.texture = load("res://qiforge/assets/kenney/button_rectangle_flat.png") as Texture2D
	kbtn.texture_margin_left = 24.0
	kbtn.texture_margin_right = 24.0
	kbtn.texture_margin_top = 12.0
	kbtn.texture_margin_bottom = 12.0
	kbtn.modulate_color = Color(0.32, 0.27, 0.18)
	for mode in [["wid", "按器灵分组"], ["cost", "按费用排序"]]:
		var sb2 := Button.new()
		sb2.text = mode[1]
		sb2.tooltip_text = "切换排序：%s。" % mode[1]
		sb2.custom_minimum_size = Vector2(250, 42)
		var kx: StyleBoxTexture = kbtn.duplicate() as StyleBoxTexture
		if String(mode[0]) == _deck_sort:
			kx.modulate_color = Color(0.52, 0.42, 0.24)
		sb2.add_theme_stylebox_override("normal", kx)
		var kxh: StyleBoxTexture = kbtn.duplicate() as StyleBoxTexture
		kxh.modulate_color = Color(0.62, 0.52, 0.30)
		sb2.add_theme_stylebox_override("hover", kxh)
		sb2.add_theme_stylebox_override("pressed", kxh)
		sb2.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		QISTYLE.font(sb2, 17, true)
		sb2.add_theme_color_override("font_color", Color("ffe9b0"))
		var mode_s := String(mode[0])
		sb2.pressed.connect(func() -> void:
			_deck_sort = mode_s
			for c in scroll.get_children():
				c.queue_free()
			_fill_deck_scroll(scroll)
			var sort_name := "按器灵" if _deck_sort == "wid" else "按费用"
			(page["bottom"] as Label).text = "当前卡组 %d 张 · %s" % [deck.size(), sort_name]
			for b2 in hbox.get_children():
				var bb := b2 as Button
				var is_wid_btn := "器灵" in String(bb.text)
				var active := (is_wid_btn and _deck_sort == "wid") or (not is_wid_btn and _deck_sort == "cost")
				var sbx := bb.get_theme_stylebox("normal") as StyleBoxTexture
				sbx.modulate_color = Color(0.52, 0.42, 0.24) if active else Color(0.32, 0.27, 0.18))
		hbox.add_child(sb2)
	strip.add_child(hbox)
	layer.add_child(strip)
	_fill_deck_scroll(scroll)

func _fill_deck_scroll(scroll: ScrollContainer) -> void:
	var deck: Array = run_data.get("deck", [])
	if _deck_sort == "wid":
		var by_wid := {}
		for de in deck:
			var w0 := String(de["wid"])
			if not by_wid.has(w0):
				by_wid[w0] = []
			by_wid[w0].push_back(de)
		var grid := VBoxContainer.new()
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("separation", 8)
		var wids: Array = []
		for e0 in _crew + _reserve:
			var w1 := String(e0["_member"]["id"])
			if not wids.has(w1):
				wids.push_back(w1)
		for w2 in by_wid.keys():
			if not wids.has(w2):
				wids.push_back(w2)
		for w3 in wids:
			if not by_wid.has(w3):
				continue
			var grp := VBoxContainer.new()
			grp.add_theme_constant_override("separation", 6)
			var gl := Label.new()
			gl.text = "「%s」×%d" % [String(QI_DATA.WEAPONS[w3]["name"]), (by_wid[w3] as Array).size()]
			QISTYLE.font(gl, QISTYLE.FS_SMALL)
			gl.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
			grp.add_child(gl)
			var hb := HFlowContainer.new()
			hb.add_theme_constant_override("separation", 10)
			for de0 in by_wid[w3]:
				hb.add_child(_make_deck_card(de0))
			grp.add_child(hb)
			grid.add_child(grp)
		scroll.add_child(grid)
	else:
		var cards: Array = deck.duplicate()
		cards.sort_custom(func(a, b) -> bool:
			var ca := _deck_card_cost(a)
			var cb := _deck_card_cost(b)
			if ca != cb:
				return ca < cb
			if String(a["wid"]) != String(b["wid"]):
				return String(a["wid"]) < String(b["wid"])
			return String(a["sid"]) < String(b["sid"]))
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("separation", 10)
		for de1 in cards:
			flow.add_child(_make_deck_card(de1))
		scroll.add_child(flow)

func _deck_card_cost(de: Dictionary) -> int:
	var sp := QI_DATA.spell_of(String(de["wid"]), String(de["sid"]), int(de.get("dir", 0)))
	return int(sp.get("cost", 0))

func _make_deck_card(de: Dictionary) -> Button:
	var sp := QI_DATA.spell_of(String(de["wid"]), String(de["sid"]), int(de.get("dir", 0)))
	var card: Button = QICARD.make_spell_card(String(sp["name"]), int(sp.get("cost", 0)),
		String(sp.get("desc", "")), 0, "", "field")
	var sp_copy: Dictionary = sp
	card.pressed.connect(func() -> void:
		var big: Button = QICARD.make_spell_card(String(sp_copy["name"]), int(sp_copy.get("cost", 0)),
			String(sp_copy.get("desc", "")), 0, "", "detail")
		add_child(QICARD.make_detail_layer(big)))
	return card

func _open_group_intel() -> void:
	var gi: int = int(run_data.get("group", 0))
	var fi: int = int(run_data.get("fight", 0))
	var gname := "第 1 组 · 黑风寨" if gi >= QI_DATA.GROUPS.size() else String(QI_DATA.GROUPS[gi]["name"])
	var dialog: Control = QIDIALOG.create(self, "本组情报 · %s" % gname, Vector2(900, 540), "关闭")[1]
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	var fights: Array = QI_DATA.GROUPS[gi]["fights"] if gi < QI_DATA.GROUPS.size() else []
	for i in fights.size():
		var f: Dictionary = fights[i]
		var names: Array = []
		for eid0 in f["enemies"]:
			var ids0: Array = eid0 if eid0 is Array else [eid0]   # 块队列制：标签按块顶计
			if not ids0.is_empty():
				names.push_back(QI_DATA.ENEMIES[String(ids0[0])]["name"])
		var state := "（当前）" if i == fi else ("（已胜）" if i < fi else "")
		var row := VBoxContainer.new()
		var t := Label.new()
		t.text = "%s%s" % [String(f["label"]), state]
		QISTYLE.font(t, QISTYLE.FS_BODY, true)
		t.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
		row.add_child(t)
		var d := Label.new()
		d.text = "%s —— 胜场铜钱 +%d" % [" ＋ ".join(PackedStringArray(names)), int(f["reward"])]
		QISTYLE.font(d, QISTYLE.FS_BODY)
		d.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
		row.add_child(d)
		body.add_child(row)
	dialog.content().add_child(body)
	dialog.popup_centered()

## 出战：直接进战斗屏（不加确认）；组末无下一场时封死（2026-10-28 修空战斗越界）
func _build_go() -> void:
	var b := Button.new()
	b.name = "GoButton"
	b.text = "出 战"
	b.tooltip_text = "进入下一场战斗。"
	var gi: int = int(run_data.get("group", 0))
	var fights: Array = QI_DATA.GROUPS[gi]["fights"] if gi < QI_DATA.GROUPS.size() else []
	if int(run_data.get("fight", 0)) >= fights.size():
		b.disabled = true
		b.text = "已通关"
		b.tooltip_text = "本组全部场次已通关（后续内容待续）。"
	b.pressed.connect(_on_go)
	_anchor(b, 0.860, 0.886, 0.990, 0.977)
	QISTYLE.apply_primary(b)
	QISTYLE.font(b, 30, true)
	b.add_theme_color_override("font_color", Color("ffe9b0"))
	add_child(b)

func _on_go() -> void:
	var parent := get_parent()
	if parent != null and parent.has_method("spawn_battle"):
		parent.spawn_battle()   # QiRoot 持 run：战斗直接由主流程生成
	else:
		var bt := BATTLE.instantiate()
		parent.add_child(bt)
	queue_free()

## 浮字提示（战斗屏同款）
func _flash(text: String) -> void:
	var t := Label.new()
	t.text = text
	QISTYLE.font(t, QISTYLE.FS_BIG, true)
	t.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	t.set_anchor(SIDE_LEFT, 0.35)
	t.set_anchor(SIDE_RIGHT, 0.65)
	t.set_anchor(SIDE_TOP, 0.345)
	t.set_anchor(SIDE_BOTTOM, 0.385)
	t.offset_left = 0.0
	t.offset_top = 0.0
	t.offset_right = 0.0
	t.offset_bottom = 0.0
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(t)
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_property(t, "modulate:a", 0.0, 0.7)
	tw.tween_callback(t.queue_free)

func _anchor(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.set_anchor(SIDE_LEFT, l)
	c.set_anchor(SIDE_TOP, t)
	c.set_anchor(SIDE_RIGHT, r)
	c.set_anchor(SIDE_BOTTOM, b)
	c.offset_left = 0.0
	c.offset_top = 0.0
	c.offset_right = 0.0
	c.offset_bottom = 0.0
