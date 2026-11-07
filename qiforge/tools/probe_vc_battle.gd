## 气式连击战斗逻辑探针（2026-11-01 双资源轮全量重写）：纯 QiVcBattle 断言（无 UI）。
## 断言链：数据完整性（13 卡四职）→ 开局态（气1/式0/连击0）→ 普攻经济（得式得气/多段/不吃连击的式）
## → 连击＝耗式数（重劈 2 式→连击2×2 自身放大；无式催破归零；首张 ×1）→ 奇窍吃连击增幅（抽牌×2）
## → 气流转（攻击各+1／耗气回合基础+1／式跨回合保留／连击回合清零）→ 内功门（无堆叠＝式连击全停）
## → 合并打击/护甲刷新（新卡）→ 遭遇护甲池/波次补位/win（op 直调）。
extends SceneTree

const VC := preload("res://qiforge/QiVcData.gd")
const VC_BATTLE := preload("res://qiforge/QiVcBattle.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	# —— ① 数据完整性（气式连击 v0.1：13 卡）——
	_eq("卡总数 35", 35, VC.CARDS.size())
	var kinds := {}
	for c in VC.CARDS.values():
		var k := String(c.get("kind", ""))
		kinds[k] = int(kinds.get(k, 0)) + 1
	_eq("三职分布：攻击11/奇窍3/护体2", "11/3/2",
		"%d/%d/%d" % [int(kinds.get("attack", 0)),
			int(kinds.get("effect", 0)), int(kinds.get("defense", 0))])
	_eq("直刺＝刺式 6×6 右→左顺发", "刺/6/6/right_left",
		"%s/%d/%d/%s" % [String(VC.CARDS["zhici"]["stance"]),
			int(VC.CARDS["zhici"]["ops"][0]["value"]), int(VC.CARDS["zhici"]["ops"][0]["hits"]),
			String(VC.CARDS["zhici"]["targeting"])])
	_eq("山崩＝斩×2 前排整排", "2/front_row",
		"%d/%s" % [int(VC.CARDS["cuipo_pi_heavy"]["need"]["n"]),
			String(VC.CARDS["cuipo_pi_heavy"]["targeting"])])
	_eq("开局牌组＝直刺孤张", 1, VC.START_DECK.size())

	# —— ② 开局态（气上限制：开局即满 2；2026-11-07 新口径）——
	var b: RefCounted = VC_BATTLE.new()
	b.setup(VC.default_vc_run())
	b.start()
	_eq("主角 hp50", 50, int(b.player["hp"]))
	_eq("开局气＝上限 2", 2, int(b.player["qi"]))
	_eq("开局抽到为止（孤张牌组＝1）", 1, b.hand.size())
	_eq("开局三式全 0", "0/0/0", "%d/%d/%d" % [int(b.player["stances"]["斩"]),
		int(b.player["stances"]["刺"]), int(b.player["stances"]["撩"])])
	_eq("开局连击 0", 0, b.combo_count)

	# —— ③ 直刺（骷髅精英王 600 当靶；Targeting 单链：right_left 6×6）——
	var b3: RefCounted = _mk_king_battle(["zhici"])
	var king3: Dictionary = b3.encounter["active"][0]
	var qi0 := int(b3.player["qi"])
	b3.play_card(int(b3.hand[0]["uid"]))   # 0 气：气不动；得刺式1；连击不动；6×6=36
	_eq("直刺：刺式 +1", 1, int(b3.player["stances"]["刺"]))
	_eq("直刺：0 费气不动", qi0, int(b3.player["qi"]))
	_eq("直刺：连击不动", 0, b3.combo_count)
	_eq("直刺：6×6＝36", 564, int(king3["hp"]))

	# —— ④ 连击＝耗式数（2026-11-07 涨磨三口径：耗式涨/无式磨损/攻击不耗式不动）——
	var b4: RefCounted = _mk_king_battle()
	var king4: Dictionary = b4.encounter["active"][0]
	b4.play_card(int(b4.hand[0]["uid"]))   # 下斩：斩式+1（0 气不磨损连击）
	b4.play_card(int(b4.hand[0]["uid"]))   # 下斩：斩式 2
	_eq("双下斩：斩式 2、连击 0", "2/0", "%d/%d" % [int(b4.player["stances"]["斩"]), b4.combo_count])
	b4.play_card(int(b4.hand[0]["uid"]))   # 山崩（斩×2 满折 0 气）：连击 0+2=2，×2 → 28×2=56
	_eq("山崩：连击=耗式数 2", 2, b4.combo_count)
	_eq("山崩：斩耗 2 回 1", 1, int(b4.player["stances"]["斩"]))
	_eq("山崩：28×2＝56", 534, int(king4["hp"]))
	b4.play_card(int(b4.hand[0]["uid"]))   # 撩月斩（无撩式，k=0）：气 −1、连击磨损 2→1、×1=25
	_eq("无式硬打：连击磨损 2→1", 1, b4.combo_count)
	_eq("无式硬打：25×1", 509, int(king4["hp"]))
	b4.play_card(int(b4.hand[0]["uid"]))   # 直刺：刺+1、连击不动、36
	_eq("直刺垫牌：36 伤", 473, int(king4["hp"]))
	b4.play_card(int(b4.hand[0]["uid"]))   # 连珠刺（刺×1）：连击 1+1=2、×2 → 8×2×2=32
	_eq("1 式催破：连击 2", 2, b4.combo_count)
	_eq("连珠刺：8×2×2＝32", 441, int(king4["hp"]))

	# —— ⑤ 奇窍吃连击增幅（抽牌数×连击）＋连击磨损 ——
	var b5: RefCounted = _mk_king_battle()
	b5.play_card(int(b5.hand[0]["uid"]))   # 下斩×2 → 山崩：连击 2（复用 ④ 前三张）
	b5.play_card(int(b5.hand[0]["uid"]))
	b5.play_card(int(b5.hand[0]["uid"]))
	_eq("⑤ 前置连击 2", 2, b5.combo_count)
	b5.hand = [b5._make_card("ningshen")]
	var qi5 := int(b5.player["qi"])
	b5.play_card(int(b5.hand[0]["uid"]))   # 凝神诀 耗2气：抽 1×2=2、连击磨损 2−2=0
	_eq("凝神诀：耗 2 气", qi5 - 2, int(b5.player["qi"]))
	_eq("凝神诀：抽牌吃连击 1×2=2", 2, b5.hand.size())
	_eq("凝神诀：连击磨损 2−2=0", 0, b5.combo_count)

	# —— ⑥ 回合流转：气重置上限/连击清零/式保留 ——
	var b6: RefCounted = _mk_king_battle()
	b6.play_card(int(b6.hand[0]["uid"]))   # 下斩×2 → 山崩
	b6.play_card(int(b6.hand[0]["uid"]))
	b6.play_card(int(b6.hand[0]["uid"]))
	b6.hand = []
	b6.end_turn()
	b6.discard_anim_done()   # 停摆协议：无屏直跑连调回调（弃牌表现完成）
	_eq("回合 2：气重置上限 2", 2, int(b6.player["qi"]))
	_eq("回合 2：连击清零", 0, b6.combo_count)
	var b6b: RefCounted = _mk_king_battle(["zhici"])
	b6b.play_card(int(b6b.hand[0]["uid"]))   # 直刺：刺 1
	b6b.hand = []
	b6b.end_turn()
	b6b.discard_anim_done()
	_eq("式跨回合保留（刺 1 留存）", 1, int(b6b.player["stances"]["刺"]))

	# —— ⑦ 内功门：无「连击堆叠」＝连击/倍率全停（耗式照常——2026-11-07 口径）——
	var run7: Dictionary = VC.default_vc_run()
	run7["neigong"] = []
	var b7: RefCounted = _mk_king_battle(["zhici", "cuipo_ci"], run7)
	var king7: Dictionary = b7.encounter["active"][0]
	b7.play_card(int(b7.hand[0]["uid"]))   # 直刺：刺+1、36
	b7.play_card(int(b7.hand[0]["uid"]))   # 连珠刺（无内功）：k=1 耗刺→0、连击不涨、×1=16
	_eq("无内功：耗式照常但自回式（刺 1−1＋1）", 1, int(b7.player["stances"]["刺"]))
	_eq("无内功：连击恒 0", 0, b7.combo_count)
	_eq("无内功：直刺 36＋连珠 16 均 ×1", 548, int(king7["hp"]))

	# —— ⑧ 逐敌执行（PerformIntents：每敌独立伤害独立过甲；2026-11-07 新口径）——
	var b8: RefCounted = VC_BATTLE.new()
	var run8: Dictionary = VC.default_vc_run()
	run8["enc"] = 2   # 蝙蝠巢
	b8.setup(run8)
	b8.start()
	b8.hand = []
	b8.player["qi"] = 99
	b8.end_turn()
	b8.discard_anim_done()   # 蝙蝠×3 各攻 1（逐敌合计 3）
	_eq("逐敌 1×3=3", 47, int(b8.player["hp"]))
	var b9: RefCounted = VC_BATTLE.new()
	run8["enc"] = 2
	b9.setup(run8)
	b9.start()
	b9.hand = [b9._make_card("tiegu")]
	b9.player["qi"] = 99
	b9.play_card(int(b9.hand[0]["uid"]))
	_eq("铁骨：护甲属性 +2", 2, int(b9.player["armor_stat"]))
	b9.hand = []
	b9.end_turn()
	b9.discard_anim_done()   # 逐敌 1×3：甲逐段吸 2 → 1 伤
	_eq("护甲吸 2 后 1 伤", 49, int(b9.player["hp"]))
	_eq("回合 2 护甲按属性刷新", 2, int(b9.player["armor"]))

	# —— ⑨ 结甲=敌自加甲＋补位＋win（每敌甲制：2026-11-07 池退役）——
	var ba: RefCounted = VC_BATTLE.new()
	var runa: Dictionary = VC.default_vc_run()
	runa["enc"] = 3   # 乱葬岗
	ba.setup(runa)
	ba.start()
	var acta: Array = ba.encounter["active"]
	acta[0]["current_intent"] = {"kind": "attack", "value": 10}
	acta[1]["current_intent"] = {"kind": "armor", "value": 3}
	acta[2]["current_intent"] = {"kind": "attack", "value": 4}
	ba.hand = []
	ba.player["qi"] = 99
	ba.end_turn()
	ba.discard_anim_done()
	_eq("乱葬岗逐敌 10+4=14（结甲不打人）", 36, int(ba.player["hp"]))
	_eq("结甲敌自身甲=3（每敌甲制）", 3, int(acta[1]["armor"]))
	for e in ba._alive_active().duplicate():   # 抹除场上（精确语义：直调内部口）
		ba._damage_enemy(e, 99999, true)
	_eq("抹除清场：活跃 0、总池余 2 未胜", "0/false", "%d/%s" % [ba._alive_active().size(), str(String(ba.result) == "win")])
	ba.hand = []
	ba.player["qi"] = 99
	ba.end_turn()
	ba.discard_anim_done()   # 补位 1
	_eq("回合末补位 1：活跃 1", 1, ba.encounter["active"].size())
	var got := [""]
	ba.ended.connect(func(r: String): got[0] = String(r))
	ba.encounter["reserve"] = []
	for e in ba._alive_active().duplicate():
		ba._damage_enemy(e, 99999, true)
	ba.check_end()   # 终局判定挂在回合尾——直调清场需手动收口
	_eq("总池耗尽＋场上清空＝win", "win", got[0])

	# —— ⑩ 属性四层＋黄卡三型（2026-11-07 属性轮）——
	var run10: Dictionary = VC.default_vc_run()
	run10["neigong"] = ["combo_stack"]
	run10["dungeon_stats"] = {"might": 10}
	run10["_meta"] = {"upgrades": {"might": 1}}   # progression 每级 +5
	var b10: RefCounted = _mk_king_battle(["spinach", "hollow_heart"], run10)
	_eq("三层合成：100+5（养成）+10（本局）＝115", 115, b10.stat_val("might"))
	b10.player["qi"] = 99
	b10.play_card(int(b10.hand[0]["uid"]))   # 菠菜（dungeon 型）：run.dungeon_stats.might +10
	_eq("dungeon 型回写 run（增量 10+10=20）", 20, int(run10["dungeon_stats"]["might"]))
	_eq("dungeon 型本战斗现值同步（125）", 125, b10.stat_val("might"))
	_eq("菠菜不磨连击（中立）", 0, b10.combo_count)
	_eq("菠菜 Destroy=false 不自毁→已打出区", 1, b10.played_pile.size())
	var hp_before := int(b10.player["mhp"])
	b10.play_card(int(b10.hand[0]["uid"]))   # 空心之心（Destroy：encounter 型 +3 max_hp）
	_eq("encounter 型血上限 +3（50→53）", hp_before + 3, int(b10.player["mhp"]))
	_eq("Destroy 卡进消耗区", 1, b10.exhaust_pile.size())
	# 乘区：might 125% → 直刺 6 段 6×1.25=7.5→8（decrit 版直刺见 _mk_king_battle）
	var king10: Dictionary = b10.encounter["active"][0]
	var hp10 := int(king10["hp"])
	var b10b: RefCounted = _mk_king_battle(["zhici"], run10)
	b10b.player["qi"] = 99
	b10b.play_card(int(b10b.hand[0]["uid"]))
	var dealt := hp10 - int((b10b.encounter["active"][0] as Dictionary)["hp"]) if not b10b.encounter["active"].is_empty() else -1
	_eq("might 乘区（125%：每击 6×1.25=7.5→round 8；8×6=48）", 48, dealt)
	# 金币：greed 乘区（growth 已改 settle_all_xp——胜场金＝xp×greed）
	var b10c: RefCounted = _mk_king_battle(["zhici"], run10)
	b10c.xp_pending.push_back(35)   # 直注入队（王 600 血一张刺不死——金币口径直测）
	b10c.settle_all_xp()
	_eq("胜场金币＝xp×greed（35）", 35, b10c.gold_reward())
	_eq("player_out 带金币", 35, int(b10c.player_out()["gold"]))

	_finish()

## 靶场：骷髅精英王 600 单敌；手牌可指定（缺省＝下斩×2→重劈·山崩→撩月斩→直刺→连珠刺 依序）。
## 靶场常驻连击内功（宝箱解锁制下 default_run 无内功——靶场专装）；直刺去 crit 保确定性。
func _mk_king_battle(cards: Array = [], run_over: Dictionary = {}) -> RefCounted:
	var run: Dictionary = run_over if not run_over.is_empty() else VC.default_vc_run()
	if run_over.is_empty():
		run["neigong"] = ["combo_stack"]
	var bt: RefCounted = VC_BATTLE.new()
	bt.setup(run)
	bt.encounter["active"] = [bt._make_enemy("skeleton_king")]
	bt.encounter["reserve"] = []
	bt.start()
	bt.hand = []
	if cards.is_empty():
		cards = ["hengpi", "hengpi", "cuipo_pi_heavy", "cuipo_liao", "zhici", "cuipo_ci"]
	for cid in cards:
		var c: Dictionary = bt._make_card(String(cid))
		if String(cid) == "zhici":   # 探针去 crit（25% 暴击使断言不确定——暴击链另有单测位）
			var d: Dictionary = (c["def"] as Dictionary).duplicate(true)
			d["ops"] = [{"op": "dmg", "value": 6, "hits": 6}]
			c["def"] = d
		bt.hand.push_back(c)
	bt.player["qi"] = 99
	return bt

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("VC_LOGIC_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("VC_LOGIC_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
