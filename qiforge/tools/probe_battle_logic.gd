## 战斗管线逻辑探针（v0.7 属性重构版）：纯 QiBattle 数值断言（无 UI）。跑法＝非无头 -s。
## 断言链：奇偶公式 → 普攻过防/功法跳防 → 杀意平值（被动+卡面双产）→ 格挡/抵抗
## → 中毒尖塔制 → 护盾回合末清空 → 蛊虫循环（藏身/增幅/回归/毒发计数）→ 弹射段数
## → 召蛊三方向 → 铁壁系（被动/升1/升2 分配）→ 插件6 → 引丝诀攻次操控 → 雷反防环
## → 冲弃/复用/唯一/阵亡牌消 → 两仪刀剑（形态机/费用实时查询/裂甲破甲/三配件）。
extends SceneTree

const QI_BATTLE := preload("res://qiforge/QiBattle.gd")
const QI_DATA := preload("res://qiforge/QiData.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	# —— 奇偶公式（QiData 直断言）——
	_eq("Lv2 能量=3", 3, QI_DATA.energy_cap_of(2))
	_eq("Lv2 抽牌=4", 4, QI_DATA.draw_of(2))
	_eq("Lv3 抽牌=5（奇次升级）", 5, QI_DATA.draw_of(3))
	_eq("Lv3 能量=3（不动）", 3, QI_DATA.energy_cap_of(3))
	_eq("Lv4 能量=4（偶次升级）", 4, QI_DATA.energy_cap_of(4))
	_eq("Lv4 抽牌=5", 5, QI_DATA.draw_of(4))
	_eq("Lv5 抽牌=6", 6, QI_DATA.draw_of(5))

	# —— 局一：幽冥＋天丝（默认队）——
	var b: RefCounted = QI_BATTLE.new()
	b.setup({"copper": 0,
		"team": [{"id": "youming", "equips": [], "pdir": 0},
			{"id": "tiansi", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b.start()
	var ym: Dictionary = b.allies[0]
	var ts: Dictionary = b.allies[1]
	var dashou: Dictionary = b.enemies[0]
	var lieshou: Dictionary = b.enemies[1]

	_eq("开局能量=3", 3, b.energy)
	_eq("开局抽牌=4", 4, b.hand.size())
	_eq("幽冥面板 攻26 威8 防0 攻次1", "26/8/0/1",
		"%d/%d/%d/%d" % [b.atk_of(ym), b.pow_of(ym), b.def_of(ym), int(ym["acts_max"])])
	_eq("天丝面板 攻10 威10 攻次0", "10/10/0",
		"%d/%d/%d" % [b.atk_of(ts), b.pow_of(ts), int(ts["acts_max"])])

	# 普攻：26−8（刀客防）=18；追击（天丝）10−8=2 → 刀客 92−20=72
	b.normal_attack(ym, dashou)
	_eq("普攻过防 26−8=18＋追击 10−8=2 → 72", 72, int(dashou["hp"]))
	_eq("幽冥攻次耗尽", 0, int(ym["acts"]))
	_eq("杀意=1（幽冥造成伤害）", 1, b.status_total(ym, "shayi"))
	_eq("天丝无杀意", 0, b.status_total(ts, "shayi"))

	# 功法跳防：灭魂斩 10+威8=19（杀意1×1 已在普攻时产生）→ 21；施法产生伤害→被动+1、卡面「获得1层」→+1＝3
	b.hand = [_card(9001, "youming", 1)]
	b.play_card(9001, dashou)
	_eq("灭魂斩 10+8威+1杀意=19 跳防 → 53", 53, int(dashou["hp"]))
	_eq("施法后杀意=3（被动+1·卡面+1）", 3, b.status_total(ym, "shayi"))

	# 格挡：打手挂格挡 2 → 普攻被挡一段
	b.apply_status(dashou, "gebi", 2)
	ym["acts"] = 1
	b.normal_attack(ym, dashou)
	_eq("格挡挡一段（血量不动 53）", 53, int(dashou["hp"]))
	_eq("格挡剩 1 层", 1, b.status_total(dashou, "gebi"))

	# 抵抗：打手挂抵抗 1 → 我方施负面（破绽）被挡、层消耗
	b.apply_status(dashou, "dikang", 1)
	b.apply_status(dashou, "poxian", 1, 0, -1, true, ym)
	_eq("抵抗挡下敌方施加的负面", 0, b.status_total(dashou, "poxian"))
	_eq("抵抗层消耗", 0, b.status_total(dashou, "dikang"))

	# 破绽平值：普攻 = 26 + 破绽1×1 − 防8 = 19（杀意只走功法通道）；天丝追击 10+1−8=3 → 垫至 22 血＝22−22=0 离场
	b._consume_stacks(dashou, "gebi", 9)
	dashou["hp"] = 22
	b.apply_status(dashou, "poxian", 1, 0, -1, true, ym)
	ym["acts"] = 1
	b.normal_attack(ym, dashou)
	_eq("普攻吃破绽＋追击 → 打手离场", false, bool(dashou["alive"]))
	_eq("击杀产杀意（段伤+敌亡=+2 → 3+2=5）", 5, b.status_total(ym, "shayi"))

	# 中毒尖塔制＋回合末结算（垫高我方耐久防敌方阶段致死）
	ym["hp"] = 300; ym["mhp"] = 300
	ts["hp"] = 300; ts["mhp"] = 300
	b.apply_status(lieshou, "zhongdu", 5)
	var lieshou_hp: int = int(lieshou["hp"])
	b.end_turn()
	for i in b.enemies.size():
		b.apply_enemy_action(i)
	b.finish_round()
	_eq("毒 5 层回合末 −5（间接直扣）", lieshou_hp - 5, int(lieshou["hp"]))
	_eq("毒层 −1=4", 4, b.status_total(lieshou, "zhongdu"))
	_eq("杀意回合末清空", 0, b.status_total(ym, "shayi"))

	# 护盾回合末清空＋格挡/抵抗纯按次不衰减（2026-10-28 用户裁定改制，直接驱动回合末结算）
	b.apply_status(ts, "hudun", 1, 10)
	b.apply_status(ts, "gebi", 2)
	b.apply_status(ts, "dikang", 1)
	_eq("天丝挂盾 10", 10, b._status_valued(ts, "hudun"))
	b._tick_statuses()
	_eq("护盾回合末清空", 0, b.status_total(ts, "hudun"))
	_eq("格挡跨回合末不衰减", 2, b.status_total(ts, "gebi"))
	_eq("抵抗跨回合末不衰减", 1, b.status_total(ts, "dikang"))

	# —— 局二：青蛊铃蛊虫循环＋弹射＋召蛊 ——
	var b2: RefCounted = QI_BATTLE.new()
	b2.setup({"copper": 0,
		"team": [{"id": "qinggu", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 7})
	b2.start()
	var qg: Dictionary = b2.allies[0]
	qg["hp"] = 300; qg["mhp"] = 300
	var e0: Dictionary = b2.enemies[0]
	var e1: Dictionary = b2.enemies[1]
	qg["bugs"] = 3
	b2._hide_all_bugs()
	_eq("蛊虫藏身后自身=0", 0, int(qg["bugs"]))
	_eq("敌身上蛊虫合计=3", 3, int(e0["bugs_on"]) + int(e1["bugs_on"]))
	# 施毒增幅：对藏蛊的敌人施 5 层毒 → +藏匿数
	var hide_on: Dictionary = e0 if int(e0["bugs_on"]) >= int(e1["bugs_on"]) else e1
	var hide_n: int = int(hide_on["bugs_on"])
	b2.apply_status(hide_on, "zhongdu", 5, 0, -1, true, qg)
	_eq("施毒增幅 5+%d" % hide_n, 5 + hide_n, b2.status_total(hide_on, "zhongdu"))
	# 回合结束次序（先虫后毒）：蛊虫回归（3）→ 毒结算（敌方毒发 → 青蛊铃 +1/毒敌）
	b2._return_all_bugs()
	_eq("蛊虫回归（自身 3）", 3, int(qg["bugs"]))
	_eq("敌身上蛊虫清零", 0, int(e0["bugs_on"]) + int(e1["bugs_on"]))
	var stacks_before: int = b2.status_total(hide_on, "zhongdu")
	var poisoned_hp: int = int(hide_on["hp"])
	b2._poison_tick(hide_on)
	_eq("毒结算 −%d（间接）" % stacks_before, poisoned_hp - stacks_before, int(hide_on["hp"]))
	_eq("毒发产虫（3+1=4）", 4, int(qg["bugs"]))

	# 弹射段数：青蛊铃 威 12 → 4+floor(12/3)=8 段 ×3 点（功法跳防；威力转化率 1:1 断点律）
	qg["bugs"] = 0
	for e in b2.enemies:
		e["bugs_on"] = 0
	var hp_sum: int = int(e0["hp"]) + int(e1["hp"])
	b2.energy = 3
	b2.hand = [_card(9201, "qinggu", 0)]
	b2.play_card(9201, e0)
	_eq("弹射 8 段×3=24 伤害总量", hp_sum - 24, int(e0["hp"]) + int(e1["hp"]))

	# 召蛊术·升二：4 只 → 4 点间接伤分布＋全队护盾 4＋自身清虫
	qg["bugs"] = 4
	b2.energy = 3
	b2.hand = [_card_dir(9202, "qinggu", 1, 2)]
	var hp_sum2: int = int(e0["hp"]) + int(e1["hp"])
	b2.play_card(9202, {})
	_eq("召蛊 4 点间接伤", hp_sum2 - 4, int(e0["hp"]) + int(e1["hp"]))
	_eq("召蛊后自身虫=0", 0, int(qg["bugs"]))
	_eq("全队获护盾=召回数 4", 4, b2._status_valued(qg, "hudun"))

	# —— 局三：金刚盾铁壁系（被动/升1/升2）＋插件6 ——
	var b3: RefCounted = QI_BATTLE.new()
	b3.setup({"copper": 0,
		"team": [{"id": "jingang", "equips": ["p6"], "pdir": 2},
			{"id": "youming", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 3})
	b3.start()
	var jg: Dictionary = b3.allies[0]
	var ym3: Dictionary = b3.allies[1]
	jg["hp"] = 300; jg["mhp"] = 300
	ym3["hp"] = 300; ym3["mhp"] = 300
	var d3: Dictionary = b3.enemies[0]
	# 插件6：一回合一次普攻后 +1 能量（先降能量避开上限截断）
	b3.energy = 1
	b3.normal_attack(jg, d3)
	_eq("插件6 普攻回能 1→2", 2, b3.energy)
	_eq("铁壁被动：自身防御 +1", 1, b3.def_of(jg))
	_eq("铁壁被动：相邻幽冥防御 +1", 1, b3.def_of(ym3))
	# 升2：回合末自身盾不清（幽冥的清）→ 回合开始分配（仅一邻 → 各半）
	b3.apply_status(ym3, "hudun", 1, 6)
	b3._tick_statuses()
	_eq("幽冥盾回合末清空", 0, b3._status_valued(ym3, "hudun"))
	b3.end_turn()
	for i in b3.enemies.size():
		b3.apply_enemy_action(i)
	b3.apply_status(jg, "hudun", 1, 10)
	b3.finish_round()   # 回合末 jg 留盾 → 新回合开始分配
	_eq("金刚盾升2 分配后自身减半", 5, b3._status_valued(jg, "hudun"))
	_eq("仅一邻 → 幽冥获半", 5, b3._status_valued(ym3, "hudun"))
	# 升1：耐久损伤 → 等量护盾＋1 防（先清分配盾，隔离断言）
	jg["pdir"] = 1
	for i in range(jg["statuses"].size() - 1, -1, -1):
		if jg["statuses"][i]["sid"] == "hudun":
			jg["statuses"].remove_at(i)
	var def_before: int = b3.def_of(jg)
	var jg_hp: int = int(jg["hp"])
	b3.resolve_damage(d3, jg, 20.0, "普攻")
	_eq("耐久损伤 20−防%d" % def_before, jg_hp - (20 - def_before), int(jg["hp"]))
	_eq("铁壁升1：获等量护盾", 20 - def_before, b3._status_valued(jg, "hudun"))
	_eq("铁壁升1：防御 +1", def_before + 1, b3.def_of(jg))

	# —— 局四：引丝诀攻次操控＋灭魂斩·升二动态段数 ——
	var b4: RefCounted = QI_BATTLE.new()
	b4.setup({"copper": 0,
		"team": [{"id": "tiansi", "equips": [], "pdir": 0},
			{"id": "youming", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 11})
	b4.start()
	var ts4: Dictionary = b4.allies[0]
	var ym4: Dictionary = b4.allies[1]
	b4.hand = [_card(9301, "tiansi", 0)]
	b4.play_card(9301, ym4)
	_eq("引丝诀：幽冥攻次 +1", 2, int(ym4["acts"]))
	b4.energy = 3
	b4.hand = [_card_dir(9302, "tiansi", 0, 1)]
	b4.play_card(9302, ym4)
	_eq("升一：重置攻次=初始 1", 1, int(ym4["acts"]))
	var d4: Dictionary = b4.enemies[0]
	var d4_hp: int = int(d4["hp"])
	b4.energy = 3
	b4.hand = [_card_dir(9303, "youming", 1, 2)]
	b4.play_card(9303, d4)
	_eq("升二三段（杀意逐段+1：5+6+7=18）", d4_hp - 18, int(d4["hp"]))
	_eq("段伤产杀意 3（升二面不含卡面杀意op）", 3, b4.status_total(ym4, "shayi"))
	_eq("复用回手", 1, b4.hand.size())

	# —— 局五：雷反防环（间接反震）——
	var b5: RefCounted = QI_BATTLE.new()
	b5.setup({"copper": 0,
		"team": [{"id": "youming", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 5})
	b5.start()
	var ym5: Dictionary = b5.allies[0]
	var d5: Dictionary = b5.enemies[0]
	b5.apply_status(ym5, "leifan", 3)
	b5.resolve_damage(d5, ym5, 10.0, "普攻")
	_eq("雷反即时落地（间接 6，不入队）", 6, 92 - int(d5["hp"]))
	_eq("延迟队列为空（即时制）", 0, b5._deferred.size())

	# —— 五区牌堆：冲弃/复用豁免/唯一/阵亡牌消 ——
	var b6: RefCounted = QI_BATTLE.new()
	b6.setup({"copper": 0,
		"team": [{"id": "youming", "equips": [], "pdir": 0},
			{"id": "tiansi", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 3})
	b6.start()
	_eq("卡组 8 张（抽4 后堆4）", 4, b6.draw_pile.size())
	b6.hand = [_card(9401, "youming", 0), _card(9402, "youming", 1)]
	var disc0: int = b6.discard_pile.size()
	b6.end_turn()
	_eq("冲弃：手牌 0", 0, b6.hand.size())
	_eq("冲弃：弃牌堆 +2", disc0 + 2, b6.discard_pile.size())
	b6.phase = "player"
	b6.energy = 3
	b6.hand = [_card_dir(9403, "tiansi", 1, 1)]
	b6.play_card(9403, b6.enemies[0])
	_eq("复用回流仍在手", 1, b6.hand.size())
	b6.end_turn()
	_eq("复用豁免冲弃", 1, b6.hand.size())
	b6.phase = "player"
	var uni: Dictionary = _card_dir(9404, "youming", 0, 2)
	b6.hand = [uni]
	var dup: Dictionary = _card_dir(9405, "youming", 0, 2)
	var norm: Dictionary = _card(9406, "tiansi", 0)
	b6.draw_pile = [dup, norm]
	b6.discard_pile = []
	b6.draw_cards(2)
	_eq("唯一：重复抽取自动弃置", 2, b6.hand.size())
	_eq("唯一：重复张进弃牌堆", 1, b6.discard_pile.size())
	b6.hand = [_card(9407, "youming", 0)]
	b6.draw_pile = [_card(9408, "youming", 1)]
	b6.discard_pile = [_card(9409, "tiansi", 0)]
	var ym6: Dictionary = b6.allies[0]
	ym6["hp"] = 0
	b6._on_death({}, ym6)
	_eq("阵亡牌消：手牌清", 0, _count_wid(b6.hand, "youming"))
	_eq("阵亡牌消：抽牌堆清", 0, _count_wid(b6.draw_pile, "youming"))
	_eq("阵亡牌消：弃牌堆天丝保留", 1, _count_wid(b6.discard_pile, "tiansi"))

	# —— 局七：雷反即时插入＋反击引擎（2026-10-27 裁定：不排延迟队列）——
	var b7: RefCounted = QI_BATTLE.new()
	b7.setup({"copper": 0, "team": [{"id": "youming", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b7.start()
	var ym7: Dictionary = b7.allies[0]
	var e7: Dictionary = b7.enemies[0]
	# ① 敌挂 2 层雷反：幽冥普攻 26−8=18 → 敌 42；反震 2×2=4 同拍落幽冥 34→30
	b7.apply_status(e7, "leifan", 2)
	var evs: Array = []
	b7.event.connect(func(m: String) -> void: evs.push_back(m))
	ym7["acts"] = 1
	b7.normal_attack(ym7, e7)
	_eq("雷反即时·敌 92−18=74", 74, int(e7["hp"]))
	_eq("雷反即时·幽冥 34−4=30（同拍结算非回合末）", 30, int(ym7["hp"]))
	var leifan_now := false
	for m in evs:
		if String(m).begins_with("雷反"):
			leifan_now = true
	_eq("雷反即时·事件当场发出", true, leifan_now)
	# ② 反击 1 层：敌直击 20 → 幽冥 30−20=10；反击普攻 18 → 敌 42−18=24；
	#    反击属直击 → 再引雷反 4 → 幽冥 10−4=6（链：反击→雷反→间接封死）
	b7.apply_status(ym7, "fanji", 1)
	b7.resolve_damage(e7, ym7, 20.0, "普攻")
	_eq("反击·敌 74−18=56", 56, int(e7["hp"]))
	_eq("反击·幽冥 30−20−4=6", 6, int(ym7["hp"]))
	# ③ 每回合上限 1：再挨 5 点不反击（敌血不动）
	b7.resolve_damage(e7, ym7, 5.0, "普攻")
	_eq("反击上限·第二次不再反击", 56, int(e7["hp"]))
	_eq("反击上限·只吃本伤 6−5=1", 1, int(ym7["hp"]))

	# —— 局八：双向反击链有界＋间接不触发反击 ——
	var b8: RefCounted = QI_BATTLE.new()
	b8.setup({"copper": 0, "team": [{"id": "youming", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b8.start()
	var ym8: Dictionary = b8.allies[0]
	var e8: Dictionary = b8.enemies[0]
	e8["hp"] = 50
	b8.apply_status(ym8, "fanji", 1)
	b8.apply_status(e8, "fanji", 1)
	ym8["acts"] = 1
	b8.normal_attack(ym8, e8)   # 18 → 敌反 20 → 我反 18 → 双方上限已用，链止
	_eq("双向反击链·敌 50−18−18=14", 14, int(e8["hp"]))
	_eq("双向反击链·幽冥 34−16=18（敌反击＝战意后攻16；探针未挂死即防环成立）", 18, int(ym8["hp"]))
	b8._round_start()           # 重置每回合计数
	e8["hp"] = 50
	ym8["hp"] = 34
	b8.resolve_damage(e8, ym8, 3.0, "功法", {"indirect": true})
	_eq("间接不触发反击·敌不动", 50, int(e8["hp"]))
	_eq("间接不触发反击·幽冥 34−3=31", 31, int(ym8["hp"]))

	# —— 局九：灭魂斩·升一清杀意出「消耗」副本（2026-10-28 重做）＋消耗堆路由 ——
	var b9: RefCounted = QI_BATTLE.new()
	b9.setup({"copper": 0, "team": [{"id": "youming", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b9.start()
	var ym9: Dictionary = b9.allies[0]
	var d9: Dictionary = b9.enemies[0]
	b9.apply_status(ym9, "shayi", 12)
	b9.hand = [_card_dir(9900, "youming", 1, 1)]
	var hp9: int = int(d9["hp"])
	b9.play_card(9900, d9)
	_eq("升一灭魂斩 16+2×8威+12杀意=44 跳防", hp9 - 44, int(d9["hp"]))
	_eq("杀意清空（本刀被动 +1 亦被清）", 0, b9.status_total(ym9, "shayi"))
	_eq("13 层（12+被动1）→ 副本 2 张", 2, b9.hand.size())
	var c9: Dictionary = b9.hand[0]
	_eq("副本 0 费", 0, b9.card_cost(c9))
	_eq("副本带消耗标记", true, bool(c9.get("exhaust", false)))
	d9["hp"] = 50
	d9["mhp"] = 50
	b9.play_card(int(c9["uid"]), d9)
	_eq("副本伤害 10+8威=18（杀意已清）", 32, int(d9["hp"]))
	_eq("副本打出进消耗堆", 1, b9.exhaust_pile.size())
	_eq("弃牌堆只有原升一卡（dir=1，副本不回弃牌堆）", 1, b9.discard_pile.size())
	_eq("弃牌堆内确为原升一卡", 1, int(b9.discard_pile[0]["dir"]))
	b9.end_turn()
	_eq("未打副本回合末冲弃 → 弃牌堆 2（原卡＋副本）", 2, b9.discard_pile.size())
	_eq("消耗堆仍 1（冲弃不误进消耗堆）", 1, b9.exhaust_pile.size())

	# —— 局十：面板状态具名制（2026-10-28 用户裁定）：力量/竭力/护甲/破甲/强度，±1/层、无持续时间 ——
	var b10: RefCounted = QI_BATTLE.new()
	b10.setup({"copper": 0, "team": [{"id": "youming", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b10.start()
	var ym10: Dictionary = b10.allies[0]
	var e10: Dictionary = b10.enemies[0]
	ym10["hp"] = 300; ym10["mhp"] = 300   # 垫耐久防敌方阶段致死
	var atk0: int = b10.atk_of(ym10)
	b10.apply_status(ym10, "liliang", 3)
	b10.apply_status(ym10, "jieli", 1)
	_eq("力量3＋竭力1 → 攻击 +2", atk0 + 2, b10.atk_of(ym10))
	var pow0: int = b10.pow_of(ym10)
	b10.apply_status(ym10, "qiangdu", 4)
	_eq("强度4 → 威力 +4", pow0 + 4, b10.pow_of(ym10))
	var def0: int = b10.def_of(e10)
	b10.apply_status(e10, "hujia", 5)
	b10.apply_status(e10, "pojia", 2)
	_eq("护甲5＋破甲2 → 防御 +3", def0 + 3, b10.def_of(e10))
	b10.end_turn()
	for i in b10.enemies.size():
		b10.apply_enemy_action(i)
	b10.finish_round()
	_eq("力量/强度跨回合不消失（无持续时间）", true,
		b10.status_total(ym10, "liliang") == 3 and b10.status_total(ym10, "qiangdu") == 4)
	_eq("竭力/护甲/破甲跨回合不消失", true,
		b10.status_total(ym10, "jieli") == 1 and b10.status_total(e10, "hujia") == 5
		and b10.status_total(e10, "pojia") == 2)

	# —— 局十一：攻方段间死亡→剩余段作废（2026-10-28 用户裁定，STS2 AttackCommand 同制；弹射同制作废）——
	var b11: RefCounted = QI_BATTLE.new()
	b11.setup({"copper": 0, "team": [{"id": "youming", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b11.start()
	var ym11: Dictionary = b11.allies[0]
	var d11: Dictionary = b11.enemies[0]
	ym11["hp"] = 4; ym11["mhp"] = 4          # 雷反 2层×2=4 → 首段反杀
	b11.apply_status(d11, "leifan", 2)
	b11.hand = [_card_dir(9910, "youming", 1, 2)]   # 灭魂斩·升二：2+威8/5=3 段×5
	var d11_hp: int = int(d11["hp"])
	b11.play_card(9910, d11)
	_eq("雷反首段反杀攻方·剩余段作废 → 敌只吃 1 段（−5）", d11_hp - 5, int(d11["hp"]))
	_eq("攻方已阵亡", false, bool(ym11["alive"]))
	_eq("阵亡清状态·尸体不留杀意（首段曾+1，随死清零）", 0, b11.status_total(ym11, "shayi"))

	# 弹射同制：蛊箭术 3 段伤+威12/3=8 段，首段雷反反杀 → 弹射段全部作废、另一敌零伤
	var b12: RefCounted = QI_BATTLE.new()
	b12.setup({"copper": 0, "team": [{"id": "qinggu", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 7})
	b12.start()
	var qg12: Dictionary = b12.allies[0]
	var ea: Dictionary = b12.enemies[0]
	var eb: Dictionary = b12.enemies[1]
	qg12["hp"] = 4; qg12["mhp"] = 4
	b12.apply_status(ea, "leifan", 2)
	var ea_hp: int = int(ea["hp"])
	var eb_hp: int = int(eb["hp"])
	b12.hand = [_card(9911, "qinggu", 0)]    # 蛊箭术：弹射 3+1+威12/3=8 段
	b12.play_card(9911, ea)
	_eq("弹射首段反杀攻方·弹射段作废 → 目标只吃首段 3", ea_hp - 3, int(ea["hp"]))
	_eq("另一敌零伤（后续弹射段未飞出）", eb_hp, int(eb["hp"]))
	_eq("弹射攻方已阵亡", false, bool(qg12["alive"]))

	# —— 局十三：静态「消耗」透传（2026-10-28 过秤轮：铁壁诀·升二 0 费·消耗）——
	var b13: RefCounted = QI_BATTLE.new()
	b13.setup({"copper": 0, "team": [{"id": "jingang", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b13.start()
	var c13: Dictionary = b13._make_card_instance({"wid": "jingang", "sid": "tiezhao", "dir": 2})
	_eq("铁壁诀·升二实例透传静态 exhaust", true, bool(c13.get("exhaust", false)))
	_eq("铁壁诀·升二 0 费", 0, b13.card_cost(c13))
	b13.energy = 3
	b13.hand = [c13]
	b13.play_card(int(c13["uid"]), b13.allies[0])
	_eq("升二打出进消耗堆", 1, b13.exhaust_pile.size())
	_eq("升二不进弃牌堆", 0, b13.discard_pile.size())

	# —— 局十四：配件轮（2026-10-28）——插件12 开局抵抗层＋品阶重定档（只按通用面定档）——
	var b14: RefCounted = QI_BATTLE.new()
	b14.setup({"copper": 0, "team": [{"id": "jingang", "equips": ["p12"], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b14.start()
	_eq("插件12：开局 1 层抵抗", 1, b14.status_total(b14.allies[0], "dikang"))
	_eq("品阶重定：金刚三入 Lv2 池（专属不计档）", true, QI_DATA.tier_pool(2).has("x_jg_3"))
	_eq("Lv2 池充实（≥8 件）", true, QI_DATA.tier_pool(2).size() >= 8)
	_eq("Lv1 池充实（≥3 件）", true, QI_DATA.tier_pool(1).size() >= 3)

	# —— 局十五：普攻预览族（2026-10-28 用户裁定）：镜像结算口径＋追击连带查询 ——
	var b15: RefCounted = QI_BATTLE.new()
	b15.setup({"copper": 0,
		"team": [{"id": "youming", "equips": [], "pdir": 0},
			{"id": "tiansi", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b15.start()
	var ym15: Dictionary = b15.allies[0]
	var ts15: Dictionary = b15.allies[1]
	var e15: Dictionary = b15.enemies[0]
	_eq("主攻预估 26−8=18", 18, b15.preview_normal_attack(ym15, e15))
	var ps15: Array = b15.preview_pursuits(ym15, e15)
	_eq("追击连带 1 人（天丝）", 1, ps15.size())
	_eq("追击预估 10−8=2", 2, int(ps15[0]["dmg"]))
	b15.apply_status(ym15, "shayi", 5)
	_eq("杀意只入功法池·普攻预估不变", 18, b15.preview_normal_attack(ym15, e15))
	b15.apply_status(ts15, "xuruo", 1)
	_eq("追击者虚弱×0.5 镜像 → 封底 1", 1, int(b15.preview_pursuits(ym15, e15)[0]["dmg"]))
	b15._consume_stacks(ts15, "xuruo", 9)
	b15.apply_status(ts15, "jiaoxie", 1, 0, -1, true)
	_eq("追击者缴械→不放行", 0, b15.preview_pursuits(ym15, e15).size())
	ym15["acts"] = 0
	_eq("主攻攻次耗尽→预估 0", 0, b15.preview_normal_attack(ym15, e15))

	# —— 局十六：回血制（2026-10-28 §7 耐久跨场持久）——带伤上阵/跳阵亡/写回/档案制/后备回血/疗伤价/奖励池 ——
	var run16: Dictionary = QI_DATA.default_run()
	run16["team"][0]["hp"] = 10     # 幽冥 34 血带伤
	run16["team"][1]["hp"] = 0      # 天丝阵亡（不上场）
	var b16: RefCounted = QI_BATTLE.new()
	b16.setup(run16)
	b16.start()
	_eq("带伤上阵：幽冥 10 血", 10, int(b16.allies[0]["hp"]))
	_eq("阵亡未复活者不上场（仅幽冥）", 1, b16.allies.size())
	_eq("team_out 写回源", true, b16.team_out().size() == 1 and int(b16.team_out()[0]["hp"]) == 10)
	QI_DATA.apply_team_out(run16, b16.team_out())
	_eq("apply_team_out 写回", 10, int(QI_DATA.find_member(run16, "youming")["hp"]))
	# 档案制（升级保留）：升级卡随收起存档、随上阵还原
	for e in run16["deck"]:
		if String(e["wid"]) == "youming" and String(e["sid"]) == "miehun":
			e["dir"] = 1
			break
	QI_DATA.deck_swap(run16, "youming", "")
	QI_DATA.deck_swap(run16, "", "youming")
	var seen_up16 := false
	for e in run16["deck"]:
		if String(e["wid"]) == "youming" and String(e["sid"]) == "miehun" and int(e["dir"]) == 1:
			seen_up16 = true
	_eq("升级随档：收起再上阵还原 dir=1", true, seen_up16)
	# 后备每场回血 25%（青蛊 40 血：8 → 18）；疗伤价（缺 22×1＝22；阵亡天丝缺 48×1.5＝72）
	run16["reserve"] = [{"id": "qinggu", "equips": ["", "", ""], "pdir": 0, "hp": 8}]
	QI_DATA.reserve_tick(run16)
	_eq("后备每场回血 25%（40 血 8→18）", 18, int(run16["reserve"][0]["hp"]))
	_eq("疗伤价＝缺口×1", 22, QI_DATA.heal_price(run16["reserve"][0]))
	_eq("复活价＝缺口×1.5", 72, QI_DATA.heal_price(run16["team"][1]))
	# 奖励回复池：带伤幽冥(10/34)＋阵亡天丝(0/48)＋带伤青蛊(18/40) 入池；满血出局
	_eq("回复池＝3（带伤×2＋阵亡×1）", 3, QI_DATA.op_pool(run16, "heal").size())
	run16["reserve"][0]["hp"] = QI_DATA.mhp_of(run16["reserve"][0])
	_eq("满血者不入回复池", 2, QI_DATA.op_pool(run16, "heal").size())

	# —— 局十七：两仪刀剑（形态机逐段判定＋双功法＋配件三件＋费用实时查询）——
	# 17A：纯形态机（pdir0 无装）——首伤定形/同形态不触发/一卡两转
	var b17: RefCounted = QI_BATTLE.new()
	b17.setup({"copper": 0,
		"team": [{"id": "liangyi", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b17.start()
	var ly: Dictionary = b17.allies[0]
	var d17: Dictionary = b17.enemies[0]
	var l17: Dictionary = b17.enemies[1]
	_eq("两仪初始无形态", false, b17._forms.has(int(ly["uid"])))
	b17.normal_attack(ly, d17)
	_eq("普攻 15−8=7 → 85", 85, int(d17["hp"]))
	_eq("首伤定形＝刀", "dao", String(b17._forms[int(ly["uid"])]))
	_eq("转刀＋1 强度（威 13）", 13, b17.pow_of(ly))
	ly["acts"] = 1
	b17.normal_attack(ly, d17)
	_eq("同形态不触发（强度仍 1 层）", 1, b17.status_total(ly, "qiangdu"))
	_eq("二次普攻 → 78", 78, int(d17["hp"]))
	b17.hand = [_card(9001, "liangyi", 1)]
	b17.play_card(9001, d17)
	_eq("合击全卡 功法17＋普攻1=18 → 60", 60, int(d17["hp"]))
	_eq("转剑＋1 力量（攻 16）", 16, b17.atk_of(ly))
	_eq("合击普攻段 16/2−8=封底1 → 60", 60, int(d17["hp"]))
	_eq("一张两转终态＝刀", "dao", String(b17._forms[int(ly["uid"])]))
	_eq("强度累计 2（威 14）", 14, b17.pow_of(ly))
	var dj2: Dictionary = _card_dir(9102, "liangyi", 1, 2)
	_eq("合击·升二 刀形态 0 费（实时查询）", 0, b17.card_cost(dj2))
	b17._forms[int(ly["uid"])] = "jian"
	_eq("剑形态恢复 1 费", 1, b17.card_cost(dj2))
	b17._forms.erase(int(ly["uid"]))
	_eq("无形态恢复 1 费", 1, b17.card_cost(dj2))
	b17.hand = [_card(9002, "liangyi", 0)]
	b17.play_card(9002, l17)
	_eq("裂甲斩 6+16/2+14/3−6=12 → 37", 37, int(l17["hp"]))
	_eq("伤害段先转刀（威15）→破甲 1+15/5=4（目标）", 4, b17.status_total(l17, "pojia"))
	_eq("破甲 4（相邻打手）", 4, b17.status_total(d17, "pojia"))
	b17.hand = [_card_dir(9003, "liangyi", 0, 1)]
	b17.play_card(9003, l17)
	_eq("升一附带基础版合击入手", true, b17.hand.size() == 1
		and String(b17.hand[0]["sid"]) == "daojian" and int(b17.hand[0]["dir"]) == 0)
	_eq("升一再裂甲（破甲削防 6−4=2）19−2=17 → 20", 20, int(l17["hp"]))
	_eq("破甲累计 8", 8, b17.status_total(l17, "pojia"))
	b17.energy = 2
	b17.hand = [_card_dir(9004, "liangyi", 1, 1)]
	b17.play_card(9004, d17)
	_eq("合击·升一 功法19＋（转剑攻17/2=9·破甲防0）普攻9=28 → 32", 32, int(d17["hp"]))
	_eq("升一互赠基础版裂甲斩入手", true, b17.hand.size() == 1
		and String(b17.hand[0]["sid"]) == "liejia" and int(b17.hand[0]["dir"]) == 0)
	_eq("合击·升一两转终态仍刀", "dao", String(b17._forms[int(ly["uid"])]))

	# 17B：升2＋三配件（护盾缩放/杀意跨层/转刀攻次/回耐久/回合首功法降费）
	var b18: RefCounted = QI_BATTLE.new()
	b18.setup({"copper": 0,
		"team": [{"id": "liangyi", "equips": ["x_ly_2", "x_ly_3", "x_ly_1"], "pdir": 2}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b18.start()
	var ly2: Dictionary = b18.allies[0]
	var d18: Dictionary = b18.enemies[0]
	_eq("配件面板 攻20 威17 抗25", "20/17/25",
		"%d/%d/%d" % [b18.atk_of(ly2), b18.pow_of(ly2), b18.res_of(ly2)])
	_eq("回合首功法 −1（充能期全牌面）", 0, b18.card_cost(_card(9201, "liangyi", 0)))
	b18.hand = [_card(9201, "liangyi", 0)]
	b18.play_card(9201, d18)
	_eq("裂甲 6+20/2+17/3−8=13 → 79", 79, int(d18["hp"]))
	_eq("转刀后升2护盾 3+18/5=6", 6, b18._status_valued(ly2, "hudun"))
	_eq("配件三：转换后 1 层杀意", 1, b18.status_total(ly2, "shayi"))
	_eq("配件二：转刀攻次+1 → 2", 2, int(ly2["acts"]))
	_eq("0 费打出（能量未扣）", 3, b18.energy)
	_eq("首张提交后充能消耗（恢复 1 费）", 1, b18.card_cost(_card(9202, "liangyi", 1)))
	ly2["hp"] = 50
	b18.normal_attack(ly2, d18)
	_eq("普攻 20−(8−破甲4)=16 → 63", 63, int(d18["hp"]))
	_eq("配件二特殊：普攻后回 5 耐久", 55, int(ly2["hp"]))
	b18.hand = [_card(9202, "liangyi", 1)]
	b18.play_card(9202, d18)
	_eq("合击全卡 功法23＋普攻7=30 → 33", 33, int(d18["hp"]))
	_eq("转剑抽一张（配件一）", true, b18.hand.size() == 1)
	_eq("两转后护盾累计 18", 18, b18._status_valued(ly2, "hudun"))
	_eq("杀意累计 3", 3, b18.status_total(ly2, "shayi"))
	_eq("终态强度 2（威 19）", 19, b18.pow_of(ly2))
	_eq("转刀再得攻次 → 2", 2, int(ly2["acts"]))

	# 17C：裂甲·升二 全体破甲＋护甲翻倍＋强度自buff
	var b19: RefCounted = QI_BATTLE.new()
	b19.setup({"copper": 0,
		"team": [{"id": "liangyi", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b19.start()
	var d19: Dictionary = b19.enemies[0]
	var l19: Dictionary = b19.enemies[1]
	b19.apply_status(d19, "hujia", 5)
	b19.hand = [_card_dir(9100, "liangyi", 0, 2)]
	b19.play_card(9100, d19)
	_eq("升二全体破甲 威12/5=2（无护甲者）", 2, b19.status_total(l19, "pojia"))
	_eq("护甲5＞破甲2 → 翻倍 4", 4, b19.status_total(d19, "pojia"))
	_eq("破甲先行：防 8+5−4=9 → 伤 17−9=8 → 84", 84, int(d19["hp"]))
	_eq("转刀1＋自buff 1+15/10=2 → 强度3（威 15）", 15, b19.pow_of(b19.allies[0]))

	# 17D：升1 转换后随机手牌功法 −1（至回合末、可叠、封 0；排除正在结算的卡）
	var b20: RefCounted = QI_BATTLE.new()
	b20.setup({"copper": 0,
		"team": [{"id": "liangyi", "equips": [], "pdir": 1}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b20.start()
	var d20: Dictionary = b20.enemies[0]
	b20.hand = [_card(9301, "liangyi", 1), _card(9302, "liangyi", 0)]
	b20.play_card(9301, d20)
	_eq("一卡两转＝降费叠加（1−2 封 0）", 0, b20.card_cost(b20.hand[0]))
	b20._round_start()
	_eq("回合末降费清空（恢复 1 费）", 1, b20.card_cost(b20.hand[0]))

	# —— 局十八：敌方系统 v0.2（G1 三场）——新套件/敌方护盾持续制/集火制/召唤/死咒/解锁直授 ——
	# 18A：G1F2（战×2＋射＋辅）——战意/猛击自眩/蓄势/连珠段数/穿甲/瞄准集火/祝祷/敌盾持续/蚀骨/封穴
	var b21: RefCounted = QI_BATTLE.new()
	b21.setup({"copper": 0,
		"team": [{"id": "youming", "equips": [], "pdir": 0},
			{"id": "tiansi", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 1, "seed": 20261026})
	b21.start()
	var ym21: Dictionary = b21.allies[0]
	var ts21: Dictionary = b21.allies[1]
	ym21["hp"] = 500; ym21["mhp"] = 500
	ts21["hp"] = 500; ts21["mhp"] = 500
	var z0: Dictionary = b21.enemies[0]
	var sh21: Dictionary = b21.enemies[2]
	var fz21: Dictionary = b21.enemies[3]
	_eq("G1F2＝四槽（战×2＋射＋辅）", 4, b21.enemies.size())
	_eq("战意：回合开始战士+1 力量（攻 16）", 16, b21.atk_of(z0))
	b21.phase = "enemy"
	b21._enemy_intent[0] = {"action": _act_of(z0, "mengji"), "target_uid": int(ym21["uid"])}
	b21.apply_enemy_action(0)
	_eq("猛击 16×1.4=22 过防 → 478", 478, int(ym21["hp"]))
	_eq("猛击自眩（跳过下回合）", 1, b21.status_total(z0, "xuan"))
	b21._enemy_intent[0] = {"action": _act_of(z0, "huiji"), "target_uid": int(ym21["uid"])}
	b21.apply_enemy_action(0)
	_eq("敌方眩晕＝跳过行动即消耗", 0, b21.status_total(z0, "xuan"))
	_eq("眩晕回合不出手（血不动）", 478, int(ym21["hp"]))
	b21._enemy_intent[0] = {"action": _act_of(z0, "xushi"), "target_uid": int(ym21["uid"])}
	b21.apply_enemy_action(0)
	_eq("蓄势：8 点护盾", 8, b21._status_valued(z0, "hudun"))
	_eq("蓄势：+1 强度（喂猛击威力）", 1, b21.status_total(z0, "qiangdu"))
	b21._enemy_intent[2] = {"action": _act_of(sh21, "lianzhu"), "target_uid": int(ts21["uid"])}
	b21.apply_enemy_action(2)
	_eq("连珠 3 段（穿甲逐段削防 7+8+9=24）→ 476", 476, int(ts21["hp"]))
	_eq("穿甲：每段命中挂 1 层（共 3）", 3, b21.status_total(ts21, "pojia"))
	b21._enemy_intent[2] = {"action": _act_of(sh21, "miaozhun"), "target_uid": int(ym21["uid"])}
	b21.apply_enemy_action(2)
	var mk21: Dictionary = {}
	for a21 in b21.allies:
		if b21.status_total(a21, "biaoji") > 0:
			mk21 = a21
	_eq("瞄准：标记＋1 层破绽", true, (not mk21.is_empty()) and b21.status_total(mk21, "poxian") == 1)
	var other21: Dictionary = ts21 if mk21 == ym21 else ym21
	b21.apply_status(other21, "chaofeng", 1)
	_eq("集火制：标记优先且无视嘲讽", int(mk21["uid"]), int(b21._pick_target()["uid"]))
	b21._enemy_round_start_passives()
	_eq("祝祷：相邻（射手）获 5+12/4=8 盾", 8, b21._status_valued(sh21, "hudun"))
	_eq("祝祷：非相邻（战士）不获", 8, b21._status_valued(z0, "hudun"))
	b21._enemy_intent[2] = {"action": _act_of(sh21, "sheji"), "target_uid": int(ym21["uid"])}
	b21.apply_enemy_action(2)
	_eq("敌盾持续：行动时才清（射后盾 0）", 0, b21._status_valued(sh21, "hudun"))
	_eq("射击 12 过防 → 466", 466, int(ym21["hp"]))
	b21._enemy_intent[3] = {"action": _act_of(fz21, "shigu"), "target_uid": int(ym21["uid"])}
	b21.apply_enemy_action(3)
	_eq("蚀骨 4+12/2=10 功法直伤 → 456", 456, int(ym21["hp"]))
	b21._enemy_intent[3] = {"action": _act_of(fz21, "fengxue_zhou"), "target_uid": int(ym21["uid"])}
	b21.apply_enemy_action(3)
	var fx_seen := false
	for a22 in b21.allies:
		if b21.status_total(a22, "fengxue") == 2:
			fx_seen = true
	_eq("封穴咒：随机我方器灵 2 层封穴", true, fx_seen)

	# 18B：G1F3（两仪剑主＋力士＋巫祝）——形态池/御召召唤/落地不行动/剑罡/死咒
	var b22: RefCounted = QI_BATTLE.new()
	b22.setup({"copper": 0,
		"team": [{"id": "youming", "equips": [], "pdir": 0},
			{"id": "tiansi", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 2, "seed": 20261026})
	b22.start()
	var boss: Dictionary = b22.enemies[0]
	var dun22: Dictionary = b22.enemies[1]
	var ym22: Dictionary = b22.allies[0]
	ym22["hp"] = 500; ym22["mhp"] = 500
	_eq("G1F3＝Boss＋肉盾＋辅助", 3, b22.enemies.size())
	_eq("第 1 回合＝刀形态", "dao", b22._enemy_form(boss))
	_eq("刀形态池不出剑系行动", true,
		String(b22._enemy_intent[0]["action"].get("form", "")) != "jian")
	b22.phase = "enemy"
	b22._enemy_intent[0] = {"action": _act_of(boss, "yuzhao"), "target_uid": int(ym22["uid"])}
	b22.apply_enemy_action(0)
	_eq("御召：刀奴＋剑仆入场（3→5）", 5, b22.enemies.size())
	_eq("召唤物＝刀奴/剑仆", "daonu|jianpu",
		"%s|%s" % [String(b22.enemies[3]["id"]), String(b22.enemies[4]["id"])])
	var hp22 := int(ym22["hp"])
	b22.apply_enemy_action(3)
	_eq("召唤物落地回合不行动", hp22, int(ym22["hp"]))
	b22.summon_enemy("daonu")
	_eq("已存活者不重复召唤", 5, b22.enemies.size())
	b22._enemy_intent[0] = {"action": _act_of(boss, "zhantie"), "target_uid": int(ym22["uid"])}
	b22.apply_enemy_action(0)
	_eq("斩铁 20×1.2=24 过防", hp22 - 24, int(ym22["hp"]))
	b22.round_no = 2
	_eq("第 2 回合＝剑形态", "jian", b22._enemy_form(boss))
	b22.roll_intents()
	_eq("剑形态池不出刀系行动", true,
		String(b22._enemy_intent[0]["action"].get("form", "")) != "dao")
	b22._enemy_intent[0] = {"action": _act_of(boss, "jiangang"), "target_uid": int(ym22["uid"])}
	b22.apply_enemy_action(0)
	_eq("剑罡 8+16威=24 功法直伤", hp22 - 48, int(ym22["hp"]))
	dun22["hp"] = 1
	ym22["acts"] = 1
	b22.phase = "player"
	b22.normal_attack(ym22, dun22)
	_eq("死咒：力士亡→攻最高（幽冥）3 层虚弱", 3, b22.status_total(ym22, "xuruo"))

	# 18C：两仪解锁制——G1F3 授两仪；锁池/直授/后备持有者出局
	_eq("G1F3 带 grant 标", "liangyi", String(QI_DATA.GROUPS[0]["fights"][2].get("grant", "")))
	var run22: Dictionary = QI_DATA.default_run()
	_eq("新局未解锁→两仪入锁", true, QI_DATA.spirit_locked(run22, "liangyi"))
	var ly_in_pool := false
	for o22 in QI_DATA.op_pool(run22, "add_spirit"):
		if String(o22["wid"]) == "liangyi":
			ly_in_pool = true
	_eq("未解锁局两仪不进新增池（仅青蛊/金刚）", false, ly_in_pool)
	run22["reserve"] = [{"id": "qinggu", "equips": ["", "", ""], "pdir": 0, "hp": 40}]
	_eq("后备持有者不入新增池（owned 含后备）", 1, QI_DATA.op_pool(run22, "add_spirit").size())
	var meta22 := {"unlocks": []}
	QI_DATA.grant_spirit(run22, "liangyi", meta22)
	_eq("直授入后备（出厂 42 血随档）", "liangyi|42",
		"%s|%d" % [String(run22["reserve"][1]["id"]), int(run22["reserve"][1]["hp"])])
	_eq("直授本局解锁", false, QI_DATA.spirit_locked(run22, "liangyi"))
	_eq("直授跨局 meta 解锁", true, (meta22["unlocks"] as Array).has("liangyi"))
	_eq("解锁后池＝仅金刚", 1, QI_DATA.op_pool(run22, "add_spirit").size())

	# —— 局十九：临时增减伤三型＋眩晕意图失效＋反震预估（2026-10-28 用户裁定）——
	var b23: RefCounted = QI_BATTLE.new()
	b23.setup({"copper": 0,
		"team": [{"id": "youming", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026})
	b23.start()
	var ym23: Dictionary = b23.allies[0]
	var e23: Dictionary = b23.enemies[0]
	ym23["hp"] = 500; ym23["mhp"] = 500
	e23["hp"] = 500; e23["mhp"] = 500
	# 虚弱＝−25%（蓝本 0.75 同制；幽冥每结算攒杀意→逐发前清）
	b23.apply_status(ym23, "xuruo", 1)
	b23._consume_stacks(ym23, "shayi", 99)
	_eq("虚弱 20×0.75=15", 15, b23.resolve_damage(ym23, e23, 20.0, "功法"))
	b23._consume_stacks(ym23, "xuruo", 9)
	# 锋芒＝直伤固定值 +1/层（间接不吃）
	b23.apply_status(ym23, "fengmang", 3)
	b23._consume_stacks(ym23, "shayi", 99)
	_eq("锋芒 3 层 10+3=13", 13, b23.resolve_damage(ym23, e23, 10.0, "功法"))
	b23._consume_stacks(ym23, "shayi", 99)
	_eq("锋芒不吃间接（10 原样）", 10,
		b23.resolve_damage(ym23, e23, 10.0, "功法", {"indirect": true}))
	# 脆弱＝受到攻击伤 ×1.5（功法不吃）
	b23.apply_status(e23, "cuiruo", 1)
	b23._consume_stacks(ym23, "fengmang", 9)
	b23._consume_stacks(ym23, "shayi", 99)
	_eq("脆弱 20×1.5−防8=22", 22, b23.resolve_damage(ym23, e23, 20.0, "普攻"))
	b23.apply_status(ym23, "fengmang", 3)
	b23._consume_stacks(ym23, "shayi", 99)
	_eq("脆弱不吃功法（10+锋3=13）", 13, b23.resolve_damage(ym23, e23, 10.0, "功法"))
	# 韧性＝直伤 −1/层（保底 1；间接不吃）
	b23.apply_status(e23, "renxing", 5)
	b23._consume_stacks(ym23, "shayi", 99)
	_eq("韧性 5 层 13−5=8", 8, b23.resolve_damage(ym23, e23, 10.0, "功法"))
	b23._consume_stacks(e23, "renxing", 99)
	b23.apply_status(e23, "renxing", 99)
	b23._consume_stacks(ym23, "shayi", 99)
	_eq("韧性保底 1", 1, b23.resolve_damage(ym23, e23, 10.0, "功法"))
	b23._consume_stacks(e23, "renxing", 99)
	b23._consume_stacks(ym23, "shayi", 99)
	_eq("韧性不吃间接（10 原样）", 10,
		b23.resolve_damage(ym23, e23, 10.0, "功法", {"indirect": true}))
	# 眩晕＝意图失效显示（蓝本 Stun 制）
	b23.apply_status(e23, "xuan", 1)
	_eq("眩晕意图位＝眩·失效", "眩|失效",
		"%s|%s" % [String(b23.intent_parts(e23)[0]["g"]), String(b23.intent_parts(e23)[0]["n"])])
	# 反震/反击预估（拖拽吸附态）
	b23._consume_stacks(e23, "xuan", 9)
	b23.apply_status(e23, "leifan", 2)
	_eq("反震预估＝雷反 2×2=4", 4, b23.preview_reflect(ym23, e23))
	b23.apply_status(e23, "fanji", 1)
	_eq("反震预估＋反击（16−0）＝20", 20, b23.preview_reflect(ym23, e23))
	# 六组同构缩放抽检（G6 档）
	_eq("G6 刀客＝黑风×2.55 血＋攻10", "235|25", "%d|%d" % [
		int(QI_DATA.ENEMIES["zhanshi_g5"]["panel"]["hp"]),
		int(QI_DATA.ENEMIES["zhanshi_g5"]["panel"]["atk"])])
	_eq("G6 Boss＝两仪剑主·极", true,
		"两仪剑主·极" == String(QI_DATA.ENEMIES["boss_g5"]["name"]))

	_finish()

func _act_of(e: Dictionary, aid: String) -> Dictionary:
	for a in e["actions"]:
		if String(a["id"]) == aid:
			return a
	return {}

func _count_wid(pile: Array, wid: String) -> int:
	var n := 0
	for c in pile:
		if String(c["wid"]) == wid:
			n += 1
	return n

func _card(uid: int, wid: String, spell_i: int) -> Dictionary:
	var spell: Dictionary = QI_DATA.WEAPONS[wid]["spells"][spell_i]
	return {"uid": uid, "wid": wid, "sid": String(spell["id"]), "dir": 0, "spell": spell,
		"reuse_left": int(spell.get("reuse", 0)), "retain": false}

func _card_dir(uid: int, wid: String, spell_i: int, dir: int) -> Dictionary:
	var base: Dictionary = QI_DATA.WEAPONS[wid]["spells"][spell_i]
	var spell: Dictionary = QI_DATA.spell_of(wid, String(base["id"]), dir)
	return {"uid": uid, "wid": wid, "sid": String(base["id"]), "dir": dir, "spell": spell,
		"reuse_left": int(spell.get("reuse", 0)), "retain": false}

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("LOGIC_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("LOGIC_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
