## 备战舱 v2（v0.7 属性重构轮：系统带＝Lv升级（奇偶制）＋能量/抽牌双徽＋刷新＋货架前5配件＋第6位操作位；
## 编队列 y40.7~77.6（名字行→纯立绘卡 234×329→装备格行；空位同基准）；后备 run_data 持久化。
## 机制（用户裁定）：配件购后补货·战后整架刷新·锁定免刷新·刷新带价；升级＝奇偶交替（奇次抽牌+1/偶次能量+1）；
## 最大灵力退役（v0.7）；器灵解锁/升级走战后奖励；拖拽＝原生协议。
## 用法：godot --path . res://qiforge/QiPrepBay.tscn -- --qi-shot → 1.2s 自动截图退出
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const QICARD := preload("res://qiforge/QiCardStyle.gd")
const QIDIALOG := preload("res://qiforge/QiDialog.gd")
const QI_DRAG := preload("res://qiforge/QiDragCard.gd")
const QI_DATA := preload("res://qiforge/QiData.gd")
const QIUP := preload("res://qiforge/QiUpgradePick.gd")
const BATTLE := preload("res://qiforge/QiBattleScreen.tscn")

static var PREP_W := QICARD.size_of("prep").x   # 备战舱展示位（基准 300×422 ×0.78，工厂 size_of 唯一权威）
static var PREP_H := QICARD.size_of("prep").y
const PREP_GAP := 18           # 列距 18＝步距 252
const NAME_ROW := 36           # 名字行（卡外顶行）
const EQ_W := 60               # 装备格
const EQ_H := 46
const OP_SLOT := 5             # 货架第 6 位（最右）＝操作位（2026-10-27 用户改裁；前 5 位配件）
const RESERVE_CAP := 3         # 后备上限（暂定；满员时「新增器灵」转必须装备形态）

## QiRoot 注入的 run 状态（钱袋/编队/后备/背包/卡组/系统等级同源）；直跑 tscn（截图/探针）用默认局
var run_data: Dictionary = {}

var _crew: Array = []                               # 7 槽（null＝空位）
var _reserve: Array = []                            # 后备（成员字典；随 run_data["reserve"] 持久化）
var _shelf: Array = []                              # 当前货架 6 位（第 6 位＝操作位）
var _sys_lv := 2
var _copper := 130
var _rng := RandomNumberGenerator.new()
var _odds_lbl: Label = null
const UPGRADE_COST := 100
const REFRESH_COST := 30

var _copper_lbl: Label
var _lv_btn: Button
var _energy_lbl: Label
var _draw_lbl: Label
var _shelf_box: HBoxContainer
var _crew_row: HBoxContainer
var _crew_count_lbl: Label
var _reserve_lbl: Label
var _reserve_zone: Control

func _ready() -> void:
	QISTYLE.apply_root_theme(self)
	_rng.randomize()
	if run_data.is_empty():
		run_data = QI_DATA.default_run()
	_copper = int(run_data.get("copper", 130))
	_sys_lv = int(run_data.get("sys_lv", 2))   # v0.7：奇偶制（抽=4+⌈(Lv-2)/2⌉／能=3+⌊(Lv-2)/2⌋）
	_crew = []
	for m in run_data.get("team", []):
		_crew.push_back(_crew_entry(m))
	_crew.resize(7)   # 尾部自动补 null＝空位
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
	_build_go()
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
	if kind in ["add_spirit", "upgrade_spirit"]:
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

## 编队条目从数据层组装（基础四维＋插件固定值；同源＝战斗管线取数口径）
func _crew_entry(m: Dictionary) -> Dictionary:
	var wid: String = m["id"]
	var w: Dictionary = QI_DATA.WEAPONS[wid]
	var p: Dictionary = QI_DATA.weapon_panel(wid, m.get("equips", []))
	var eq_names: Array = []
	for i in 3:
		if i < m.get("equips", []).size() and QI_DATA.ACCESSORIES.has(m["equips"][i]):
			eq_names.push_back(QI_DATA.ACCESSORIES[m["equips"][i]]["name"])
		else:
			eq_names.push_back("")
	var passive_txt := "%s：%s" % [w["passive"]["name"], w["passive"]["desc"]]
	var pdir := int(m.get("pdir", 0))
	if pdir > 0:
		passive_txt += "\n已升级（方向%d）：%s" % [pdir, String(w["passive"].get("ups", {}).get(str(pdir), ""))]
	var spells: Array = []
	for s in w["spells"]:
		spells.push_back("%s（%d 能量）：%s" % [s["name"], s["cost"], s["desc"]])
	return {"name": w["name"], "seal": w["seal"], "_member": m,
		"passive": passive_txt,
		"equips": eq_names,
		"attrs": {"耐久": "%d/%d" % [p["hp"], p["hp"]], "攻击": p["atk"], "威力": p["pow"],
			"防御": p["def"], "抗性": p["res"], "攻击次数": p["acts"]},
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
	_crew.resize(7)
	_sync_team()
	_rebuild_crew_cols()

func _reload_reserve() -> void:
	_reserve = []
	for m in run_data.get("reserve", []):
		_reserve.push_back(_crew_entry(m))
	if _reserve_lbl:
		_reserve_lbl.text = "后备（%d）" % _reserve.size()

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
	_anchor(bar, 0.012, 0.014, 0.24, 0.052)
	bar.add_theme_constant_override("separation", 10)
	for pair in [["图鉴", "器灵谱与词条图鉴"], ["重战", "快速读档：回到上一场战斗前重打本场（同敌方意图）"], ["设置", "音量与偏好设置"], ["退出", "返回主菜单"]]:
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
	_lv_btn.tooltip_text = "升级系统（奇偶交替）：奇数次升级抽牌 +1，偶数次升级能量上限 +1；配件出货率上浮。"
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
	_odds_lbl = Label.new()
	_odds_lbl.name = "OddsRow"
	QISTYLE.font(_odds_lbl, QISTYLE.FS_SMALL)
	_odds_lbl.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	_odds_lbl.tooltip_text = "每次补货/刷新按此概率抽品级，再从该品级池等权抽配件；档率对齐系统蓝本实测（稀有档 1/3/4/5，无 2 档）。"
	head.add_child(_odds_lbl)
	var rf := Button.new()
	rf.name = "ReflashButton"
	rf.text = "刷新 ·%d铜" % REFRESH_COST
	rf.tooltip_text = "立即整架刷新货架（锁定项保留）。"
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
	if _odds_lbl == null:
		return
	var odds: Array = QI_DATA.tier_odds(_sys_lv)
	var parts: Array = []
	for i in odds.size():
		parts.push_back("Lv%d %d%%" % [int(QI_DATA.TIER_LADDER[i]), int(odds[i])])
	_odds_lbl.text = "出货率（随系统升级上浮）：%s" % "｜".join(PackedStringArray(parts))

func _restyle_lv() -> void:
	_lv_btn.text = "系统 Lv%d ↑升级 ·%d铜" % [_sys_lv, UPGRADE_COST]

func _rebuild_shelf() -> void:
	for c in _shelf_box.get_children():
		c.queue_free()
	for d in _shelf:
		_shelf_box.add_child(_make_goods(d))

## 配件小卡（第 6 位＝操作位变体；2026-10-27 改正方形 170×170）：件面板（名/效果＋右上锁定钮——操作位无锁）＋价格签
func _make_goods(d: Dictionary) -> Control:
	var goods := VBoxContainer.new()
	goods.add_theme_constant_override("separation", 5)
	var part := Panel.new()
	part.custom_minimum_size = Vector2(170, 170)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.141, 0.094) if not d.get("is_op", false) else Color(0.13, 0.12, 0.18)
	sb.border_color = "6b5426" if not d.get("is_op", false) else "6a5a8a"
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	part.add_theme_stylebox_override("panel", sb)
	part.tooltip_text = "%s：%s\n%s" % [d["name"], d["desc"],
		"购后执行该操作；本位按同池补新。" if d.get("is_op", false) else "购入入背包——点器灵下装备格装配。"]
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
	nm.text = ("操作 · %s" if d.get("is_op", false) else "配件 · %s") % String(d["name"])
	QISTYLE.font(nm, QISTYLE.FS_BODY, true)
	nm.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN if not d.get("is_op", false) else Color("c8b8f0"))
	row1.add_child(nm)
	if not d.get("is_op", false):
		var lv := Label.new()
		lv.text = "Lv%d" % int(d["lv"])
		QISTYLE.font(lv, QISTYLE.FS_SMALL)
		lv.add_theme_color_override("font_color", QISTYLE.JADE)
		row1.add_child(lv)
	inner.add_child(row1)
	var eff := Label.new()
	eff.text = String(d["desc"])
	QISTYLE.font(eff, QISTYLE.FS_SMALL)
	eff.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(eff)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(sp)
	part.add_child(inner)
	if not d.get("is_op", false):
		var lock := Button.new()
		lock.name = "LockButton"
		lock.text = "已锁" if d["locked"] else "锁"
		lock.tooltip_text = "锁定：战后整架刷新时本货位保留。"
		lock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		lock.offset_left = -52.0
		lock.offset_top = 6.0
		lock.offset_right = -8.0
		lock.offset_bottom = 32.0
		lock.pressed.connect(func() -> void:
			d["locked"] = not d["locked"]
			lock.text = "已锁" if d["locked"] else "锁"
			_style_lock(lock, d["locked"]))
		_style_lock(lock, d["locked"])
		part.add_child(lock)
	goods.add_child(part)
	var price := Button.new()
	price.text = "●%d" % int(d["price"])
	if d.get("is_op", false):
		price.tooltip_text = "购入操作《%s》——购后立即执行（升级类需再选方向）。" % String(d["name"])
	else:
		price.tooltip_text = "购入《%s》（Lv%d）；购后入背包，本货位按出货率补新。" % [String(d["name"]), int(d.get("lv", 0))]
	price.pressed.connect(_on_buy.bind(d, part))
	QISTYLE.apply_ghost(price)
	QISTYLE.font(price, QISTYLE.FS_BODY, true)
	price.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
	price.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	goods.add_child(price)
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

## 编队标签行 y36.8（随系统带加高下移；后备区高 36 腾缝）：编队 n/7＋注记＋（右）后备区（同壳兼点击/落点）
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
	note.text = "拖卡换位 · 点卡看详情 · 拖到「后备」收起 · 卡下＝配件装备格〔格数待定〕"
	note.tooltip_text = "被动＝器灵自身效果，见详情卡。"
	QISTYLE.font(note, QISTYLE.FS_SMALL)
	note.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	row.add_child(note)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_reserve_zone = QI_DRAG.new()
	_reserve_zone.name = "ReserveZone"
	_reserve_zone.custom_minimum_size = Vector2(170, 36)
	_reserve_zone.tooltip_text = "后备器灵（上限 %d；点击查看/上阵）；拖卡到此＝收起入后备。" % RESERVE_CAP
	_reserve_zone.drop_ok = func(_data) -> bool: return true
	_reserve_zone.on_drop = _on_bench
	_reserve_zone.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_open_reserve())
	var rzb := Panel.new()
	rzb.set_anchors_preset(Control.PRESET_FULL_RECT)
	rzb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rzb.add_theme_stylebox_override("panel", QISTYLE.button_ghost())
	_reserve_zone.add_child(rzb)
	var rz := HBoxContainer.new()
	rz.set_anchors_preset(Control.PRESET_FULL_RECT)
	rz.alignment = BoxContainer.ALIGNMENT_CENTER
	rz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reserve_lbl = Label.new()
	_reserve_lbl.text = "后备（%d）" % _reserve.size()
	QISTYLE.font(_reserve_lbl, QISTYLE.FS_BODY)
	_reserve_lbl.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
	rz.add_child(_reserve_lbl)
	_reserve_zone.add_child(rz)
	row.add_child(_reserve_zone)
	add_child(row)

func _crew_count() -> int:
	var n := 0
	for c in _crew:
		if c != null:
			n += 1
	return n

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
		c.queue_free()
	for i in 7:
		var col := VBoxContainer.new()
		col.name = "CrewCol%d" % i
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		col.add_theme_constant_override("separation", 8)
		col.custom_minimum_size = Vector2(PREP_W, 0)
		if _crew[i] == null:
			var pad := Control.new()
			pad.custom_minimum_size = Vector2(PREP_W, NAME_ROW)
			pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(pad)
			col.add_child(_make_empty_slot(i))
		else:
			col.add_child(_make_col_name(String(_crew[i]["name"])))
			col.add_child(_make_crew_card(i, _crew[i]))
			col.add_child(_make_equip_row(i))
		_crew_row.add_child(col)
	if _crew_count_lbl:
		_crew_count_lbl.text = "%d / 7" % _crew_count()

func _make_col_name(text: String) -> Control:
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
	l.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
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

## 纯立绘卡面（整卡＝立绘位；美术到位即换 TextureRect，见两尺寸制）
func _make_card_visual(_d: Dictionary) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(PREP_W, PREP_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.141, 0.094)
	sb.border_color = Color("6b5426")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", sb)
	var t := Label.new()
	t.text = "立绘位"
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	QISTYLE.font(t, QISTYLE.FS_BODY)
	t.add_theme_color_override("font_color", Color(0.36, 0.31, 0.24))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(t)
	return p

## 空槽＝QiDragCard 纯落点（card_data 空＝不可拖，只接换位——拖卡到空槽＝移位；
## 2026-10-27 备战舱二拖 bug：旧制纯 PanelContainer 不接拖放，拖到空槽静默失败）
func _make_empty_slot(slot_i: int) -> Control:
	var w: Control = QI_DRAG.new()
	w.name = "EmptyWrap%d" % slot_i
	w.custom_minimum_size = Vector2(PREP_W, PREP_H)
	w.drop_ok = func(data) -> bool: return data is Dictionary and data.has("drag_data") and data["drag_data"].get("slot") != slot_i
	w.on_drop = func(data, _zone) -> void: _on_swap(int(data["drag_data"]["slot"]), slot_i)
	var empty := PanelContainer.new()
	empty.name = "EmptySlot"
	empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty.custom_minimum_size = Vector2(PREP_W, PREP_H)
	var sb := QISTYLE.panel(0.25)
	sb.border_color = Color(0.42, 0.35, 0.16, 0.5)
	sb.set_corner_radius_all(10)
	empty.add_theme_stylebox_override("panel", sb)
	var el := Label.new()
	el.text = "空位"
	QISTYLE.font(el, QISTYLE.FS_BODY)
	el.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
	el.custom_minimum_size = Vector2(PREP_W - 8, 120)
	el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_child(el)
	w.add_child(empty)
	return w

## 装备格行（卡下，可点＝装配入口）：全配件格（被动＝器灵自身效果走详情）
func _make_equip_row(team_i: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "EquipRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER   # 三格 196 宽在 234 列内居中（2026-10-28 用户裁定，勿左贴）
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for slot_i in 3:
		var eid := ""
		if team_i < run_data["team"].size() and slot_i < run_data["team"][team_i]["equips"].size():
			eid = String(run_data["team"][team_i]["equips"][slot_i])
		row.add_child(_make_equip_slot(eid, team_i, slot_i))
	return row

func _make_equip_slot(eid: String, team_i: int, slot_i: int) -> Button:
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
		ic.tooltip_text = "%s（Lv%d）：%s\n点击更换/卸下。" % [QI_DATA.ACCESSORIES[eid]["name"],
			QI_DATA.ACCESSORIES[eid]["lv"], QI_DATA.ACCESSORIES[eid]["desc"]]
	else:
		ic.tooltip_text = "空配件格——点击从背包装配。"
	ic.pressed.connect(func() -> void: _open_equip(team_i, slot_i))
	return ic

## 装备窗（1080×760 固定尺寸制）：当前槽＋背包配件网格，点选即装配/卸下
func _open_equip(team_i: int, slot_i: int) -> void:
	if team_i >= run_data["team"].size():
		return
	var m: Dictionary = run_data["team"][team_i]
	var wname := String(QI_DATA.WEAPONS[m["id"]]["name"])
	var dialog: Control = QIDIALOG.create(self,
		"装配 · %s · 槽位 %d" % [wname, slot_i + 1], Vector2(1080, 760), "关闭", "", true, true)[1]
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	var cur_eid := String(m["equips"][slot_i]) if slot_i < m["equips"].size() else ""
	var cur := Label.new()
	if not cur_eid.is_empty() and QI_DATA.ACCESSORIES.has(cur_eid):
		var a: Dictionary = QI_DATA.ACCESSORIES[cur_eid]
		cur.text = "当前：%s（Lv%d）—— %s" % [a["name"], a["lv"], a["desc"]]
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
			run_data.get("bag", []).push_back(cur_eid)
			dialog.hide()
			_rebuild_crew_cols()
			_flash("已卸下：%s" % QI_DATA.ACCESSORIES[cur_eid]["name"]))
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
		grid.add_child(_make_bag_item(String(eid), m, slot_i, dialog))
	body.add_child(grid)
	dialog.content().add_child(body)
	dialog.popup_centered(Vector2i(1080, 760))

func _make_bag_item(eid: String, m: Dictionary, slot_i: int, dialog: Control) -> Button:
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
	de.text = String(a["desc"])
	QISTYLE.font(de, QISTYLE.FS_SMALL)
	de.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	de.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(de)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	b.pressed.connect(func() -> void:
		m["equips"][slot_i] = eid
		bag_remove_one(eid)
		dialog.hide()
		_rebuild_crew_cols()
		_flash("已装配：%s → %s" % [a["name"], QI_DATA.WEAPONS[m["id"]]["name"]]))
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
	for k in d["attrs"]:
		var kl := Label.new()
		kl.text = String(k)
		QISTYLE.font(kl, QISTYLE.FS_SMALL)
		kl.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
		grid.add_child(kl)
		var vl := Label.new()
		vl.text = str(d["attrs"][k])
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

## 商店操作：配件购入＝扣钱入背包＋按出货率补位；操作位购入＝扣钱立即执行＋同池补位；
## 刷新＝扣钱换未锁位（操作位随刷新重掷）；升级＝奇偶交替＆出货率上浮
func _on_buy(d: Dictionary, slot_node: Control) -> void:
	var cost: int = int(d["price"])
	if _copper < cost:
		_deny_feedback(slot_node)
		return
	_copper -= cost
	_refresh_currency()
	if d.get("is_op", false):
		_restock(d)
		_apply_shop_op(d)
		return
	run_data.get("bag", []).push_back(String(d["id"]))
	_restock(d)
	_flash("已入背包：%s（点器灵下装备格装配）" % String(d["name"]))

func _restock(d: Dictionary) -> void:
	var idx := _shelf.find(d)
	if idx >= 0:
		_shelf[idx] = _draw_op() if idx == OP_SLOT else _draw_one()
		_rebuild_shelf()

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
				QIUP.spell_dir_row.bind(String(d["wid"]), String(d["sid"])),
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
				QIUP.passive_dir_block.bind(String(d["wid"])),
				func(dir: int) -> void:
					for m in run_data.get("team", []):
						if String(m["id"]) == String(d["wid"]):
							m["pdir"] = dir
					_flash("被动已升级（方向%d）" % dir))
		"add_spirit":
			var wid := String(d["wid"])
			var member := {"id": wid, "equips": ["", "", ""], "pdir": 0}
			var reserve: Array = run_data.get("reserve", [])
			if reserve.size() < RESERVE_CAP:
				reserve.push_back(member)
				run_data["reserve"] = reserve
				_reload_reserve()
				_flash("「%s」已入后备（后备名册可上阵）" % QI_DATA.WEAPONS[wid]["name"])
			elif _crew_count() < 7:
				run_data["team"].push_back(member)
				QI_DATA.deck_swap(run_data, "", wid)
				_reload_crew()
				_flash("后备满员——「%s」已直接上阵" % QI_DATA.WEAPONS[wid]["name"])
			else:
				_pick_spirit_replace(wid)

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

## 替换安置（后备与装备位皆满）：选一件装备中器灵替换；被替换者删除回未解锁
func _pick_spirit_replace(in_wid: String) -> void:
	var dialog: Control = QIDIALOG.create(self, "选一件替换（被替换者删除回未解锁）", Vector2(1080, 600), "取消")[1]
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for m in run_data.get("team", []):
		var w: Dictionary = QI_DATA.WEAPONS[String(m["id"])]
		var b := Button.new()
		b.text = "%s（被动%s）" % [w["name"], "已升级" if int(m.get("pdir", 0)) > 0 else "未升级"]
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
			team2.push_back({"id": in_wid, "equips": ["", "", ""], "pdir": 0})
			QI_DATA.deck_swap(run_data, out_wid, in_wid)
			dialog.queue_free()
			_reload_crew()
			_flash("「%s」已替换「%s」上阵" % [QI_DATA.WEAPONS[in_wid]["name"], QI_DATA.WEAPONS[out_wid]["name"]]))
		grid.add_child(b)
	dialog.content().add_child(grid)
	dialog.popup_centered()

func _on_refresh() -> void:
	if _copper < REFRESH_COST:
		_flash("铜钱不足")
		return
	_copper -= REFRESH_COST
	_refresh_currency()
	for i in _shelf.size():
		if not _shelf[i]["locked"]:
			_shelf[i] = _draw_op() if i == OP_SLOT else _draw_one()
	_rebuild_shelf()
	_flash("货架已刷新")

func _on_upgrade() -> void:
	if _copper < UPGRADE_COST:
		_flash("铜钱不足")
		return
	# 奇偶制（v0.7）：第 n 次升级（n＝目标 Lv−1）——奇数→抽牌+1，偶数→能量上限+1
	var n := _sys_lv - 1
	var eff := "抽牌 %d → %d" % [QI_DATA.draw_of(_sys_lv), QI_DATA.draw_of(_sys_lv + 1)] if n % 2 == 1 \
		else "能量上限 %d → %d" % [QI_DATA.energy_cap_of(_sys_lv), QI_DATA.energy_cap_of(_sys_lv + 1)]
	_copper -= UPGRADE_COST
	_refresh_currency()
	_sys_lv += 1
	run_data["sys_lv"] = _sys_lv
	_energy_lbl.text = str(QI_DATA.energy_cap_of(_sys_lv))
	_draw_lbl.text = str(QI_DATA.draw_of(_sys_lv))
	_restyle_lv()
	_refresh_odds()
	_flash("系统 Lv%d · %s" % [_sys_lv, eff])

## 编队换位／入后备（原生拖放回调）——run.team 随之同步
func _on_swap(from_i: int, to_i: int) -> void:
	var tmp = _crew[from_i]
	_crew[from_i] = _crew[to_i]
	_crew[to_i] = tmp
	_sync_team()
	_rebuild_crew_cols()

func _on_bench(data, _zone) -> void:
	if not (data is Dictionary) or not data.has("drag_data"):
		return
	var i := int(data["drag_data"]["slot"])
	if _crew[i] == null:
		return
	# v0.6 卡组制：收起入后备＝该器灵的功法卡随之下场（卡组推导自装备中器灵）
	var wid := String(_crew[i]["_member"]["id"])
	var removed := 0
	for de in run_data.get("deck", []):
		if String(de["wid"]) == wid:
			removed += 1
	QI_DATA.deck_swap(run_data, wid, "")
	_reserve.push_back(_crew[i])
	_crew[i] = null
	_sync_team()
	_rebuild_crew_cols()
	_reserve_lbl.text = "后备（%d）" % _reserve.size()
	_flash("已收起入后备（其 %d 张功法卡移出卡组）" % removed)

## 弹窗：后备名册（1080×600）——可上阵（入首个空位；卡组随供牌）
func _open_reserve() -> void:
	var dialog: Control = QIDIALOG.create(self, "后备器灵", Vector2(1080, 600), "关闭")[1]
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	var head := Label.new()
	head.text = "后备 %d/%d（上阵＝入编队首个空位，其功法卡随入卡组；拖编队卡到「后备」即可收起）" % [_reserve.size(), RESERVE_CAP]
	QISTYLE.font(head, QISTYLE.FS_SMALL)
	head.add_theme_color_override("font_color", QISTYLE.TEXT_SUB)
	body.add_child(head)
	for r in _reserve:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var lbl := Label.new()
		lbl.text = "· %s　%s" % [String(r["name"]), String(r["passive"])]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		QISTYLE.font(lbl, QISTYLE.FS_SMALL)
		lbl.add_theme_color_override("font_color", QISTYLE.TEXT_MAIN)
		row.add_child(lbl)
		var up := Button.new()
		up.text = "上阵"
		up.tooltip_text = "入编队首个空位；其功法副本随入卡组。"
		QISTYLE.apply_ghost(up)
		QISTYLE.font(up, QISTYLE.FS_SMALL)
		up.add_theme_color_override("font_color", QISTYLE.AMBER_BRIGHT)
		var member: Dictionary = r
		up.pressed.connect(func() -> void:
			var slot_i := -1
			for i in 7:
				if _crew[i] == null:
					slot_i = i
					break
			if slot_i < 0:
				_flash("编队已满（7/7）——先收起一件再上阵")
				return
			var wid := String(member["_member"]["id"])
			_crew[slot_i] = member
			_reserve.erase(member)
			QI_DATA.deck_swap(run_data, "", wid)
			_sync_team()
			_rebuild_crew_cols()
			_reserve_lbl.text = "后备（%d）" % _reserve.size()
			dialog.hide()
			_flash("「%s」已上阵（卡组 +4 张）" % member["name"]))
		row.add_child(up)
		body.add_child(row)
	dialog.content().add_child(body)
	dialog.popup_centered()

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
		for eid in f["enemies"]:
			names.push_back(QI_DATA.ENEMIES[eid]["name"])
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

## 出战：直接进战斗屏（不加确认）
func _build_go() -> void:
	var b := Button.new()
	b.name = "GoButton"
	b.text = "出 战"
	b.tooltip_text = "进入下一场战斗。"
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
