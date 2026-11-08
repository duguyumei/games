## 气式连击战斗逻辑探针（2026-11-01 双资源轮全量重写）：纯 QiVcBattle 断言（无 UI）。
## 断言链：数据完整性（13 卡四职）→ 开局态（气1/式0/连击0）→ 普攻经济（得式得气/多段/不吃连击的式）
## → 连击＝耗式数（重劈 2 式→连击2×2 自身放大；无式催破归零；首张 ×1）→ 奇窍吃连击增幅（抽牌×2）
## → 气流转（攻击各+1／耗气回合基础+1／式跨回合保留／连击回合清零）→ 内功门（无堆叠＝式连击全停）
## → 合并打击/护甲刷新（新卡）→ 遭遇护甲池/波次补位/win（op 直调）。
extends SceneTree

const VC := preload("res://qiforge/QiVcData.gd")
const VC_BATTLE := preload("res://qiforge/QiVcBattle.gd")
const VC_TGT := preload("res://qiforge/QiVcTargeting.gd")   # ⑫ 拍映射纯函数直测

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
	_eq("连环刺＝短剑 5×8 左→右顺发", "short/8/5/left_right",
		"%s/%d/%d/%s" % [String(VC.CARDS["zhici"]["stance"]),
			int(VC.CARDS["zhici"]["ops"][0]["value"]), int(VC.CARDS["zhici"]["ops"][0]["hits"]),
			String(VC.CARDS["zhici"]["targeting"])])
	_eq("山崩＝巨剑×2 前排整排（need 数据留档）", "2/front_row",
		"%d/%s" % [int(VC.CARDS["cuipo_pi_heavy"]["need"]["n"]),
			String(VC.CARDS["cuipo_pi_heavy"]["targeting"])])
	_eq("开局牌组＝连环刺孤张", 1, VC.START_DECK.size())

	# —— ② 开局态（气上限制：开局即满 2；2026-11-07 新口径）——
	var b: RefCounted = VC_BATTLE.new()
	b.setup(VC.default_vc_run())
	b.start()
	_eq("主角 hp50", 50, int(b.player["hp"]))
	_eq("开局气＝上限 2", 2, int(b.player["qi"]))
	_eq("开局抽到为止（孤张牌组＝1）", 1, b.hand.size())
	_eq("开局剑型无（状态制）", "", String(b.current_form))
	_eq("开局连击 0", 0, b.combo_count)

	# —— ③ 连环刺首打（状态制：进入短剑式、连击 0→1、×1；40 伤）——
	var b3: RefCounted = _mk_king_battle(["zhici"])
	var king3: Dictionary = b3.encounter["active"][0]
	var qi0 := int(b3.player["qi"])
	b3.play_card(int(b3.hand[0]["uid"]))   # 0 气：气不动；首打 combo 0→1 ×1；8×5=40
	_eq("连环刺：进入短剑式", "short", String(b3.current_form))
	_eq("连环刺：0 费气不动", qi0, int(b3.player["qi"]))
	_eq("连环刺：连击 0→1（首张即链首）", 1, b3.combo_count)
	_eq("连环刺：8×5×1＝40", 560, int(king3["hp"]))

	# —— ④ 连击·状态制（2026-11-08 改版：每张 +1/同型续/换型断链/先涨后算）——
	var b4: RefCounted = _mk_king_battle()
	var king4: Dictionary = b4.encounter["active"][0]
	b4.play_card(int(b4.hand[0]["uid"]))   # 下斩（巨剑首张）：combo 1、×1 → 5
	b4.play_card(int(b4.hand[0]["uid"]))   # 下斩（巨剑续链）：combo 2、×2 → 10
	_eq("双下斩：同型续链 1→2", 2, b4.combo_count)
	_eq("双下斩：当前型巨剑", "great", String(b4.current_form))
	b4.play_card(int(b4.hand[0]["uid"]))   # 山崩（巨剑续）：combo 3、×3 → 28×3=84
	_eq("山崩：连击 3（先涨后算）", 3, b4.combo_count)
	_eq("山崩：28×3＝84", 501, int(king4["hp"]))
	b4.play_card(int(b4.hand[0]["uid"]))   # 撩月斩（长剑硬换）：断链重 1、×1 → 25
	_eq("换剑断链：重撩月斩连击 3→1", 1, b4.combo_count)
	_eq("换剑断链：25×1", 476, int(king4["hp"]))
	b4.play_card(int(b4.hand[0]["uid"]))   # 连环刺（短剑硬换）：断链重 1、×1 → 40
	_eq("换剑断链：连环刺连击 1（短剑重开）", 1, b4.combo_count)
	_eq("换剑断链：40×1", 436, int(king4["hp"]))
	b4.play_card(int(b4.hand[0]["uid"]))   # 连珠刺（短剑续）：combo 2、×2 → 8×2×2=32
	_eq("续链：连珠刺连击 2", 2, b4.combo_count)
	_eq("续链：8×2×2＝32", 404, int(king4["hp"]))

	# —— ⑤ 奇窍吃连击增幅（无型牌不动链、按当前连击结算）——
	var b5: RefCounted = _mk_king_battle()
	b5.play_card(int(b5.hand[0]["uid"]))   # 下斩×2 → 山崩：连击 3（同 ④ 前三张）
	b5.play_card(int(b5.hand[0]["uid"]))
	b5.play_card(int(b5.hand[0]["uid"]))
	_eq("⑤ 前置连击 3", 3, b5.combo_count)
	b5.hand = [b5._make_card("ningshen")]
	var qi5 := int(b5.player["qi"])
	b5.play_card(int(b5.hand[0]["uid"]))   # 凝神诀（无型）耗 2 气：抽 1×3=3、连击不动
	_eq("凝神诀：耗 2 气", qi5 - 2, int(b5.player["qi"]))
	_eq("凝神诀：抽牌吃连击 1×3=3", 3, b5.hand.size())
	_eq("凝神诀：无型牌连击不动", 3, b5.combo_count)

	# —— ⑥ 回合流转：气重置上限/连击清零/剑型归无 ——
	var b6: RefCounted = _mk_king_battle()
	b6.play_card(int(b6.hand[0]["uid"]))   # 下斩×2 → 山崩
	b6.play_card(int(b6.hand[0]["uid"]))
	b6.play_card(int(b6.hand[0]["uid"]))
	b6.hand = []
	b6.end_turn()
	b6.discard_anim_done()   # 停摆协议：无屏直跑连调回调（弃牌表现完成）
	_eq("回合 2：气重置上限 2", 2, int(b6.player["qi"]))
	_eq("回合 2：连击清零", 0, b6.combo_count)
	_eq("回合 2：剑型归无", "", String(b6.current_form))

	# —— ⑦ 内功门：无「连击堆叠」＝连击/倍率/型全停（全 ×1）——
	var run7: Dictionary = VC.default_vc_run()
	run7["neigong"] = []
	var b7: RefCounted = _mk_king_battle(["zhici", "cuipo_ci"], run7)
	var king7: Dictionary = b7.encounter["active"][0]
	b7.play_card(int(b7.hand[0]["uid"]))   # 连环刺（无内功）：×1、40
	b7.play_card(int(b7.hand[0]["uid"]))   # 连珠刺（无内功）：×1、16
	_eq("无内功：连击恒 0", 0, b7.combo_count)
	_eq("无内功：型不换", "", String(b7.current_form))
	_eq("无内功：连环刺 40＋连珠 16 均 ×1", 544, int(king7["hp"]))

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
	_eq("铁骨：临时护甲 +2（armor，属性轴不动）", 2, int(b9.player["armor"]))
	_eq("铁骨：永久属性轴不吃卡", 0, int(b9.player["armor_stat"]))
	b9.hand = []
	b9.end_turn()
	b9.discard_anim_done()   # 逐敌 1×3：甲逐段吸 2 → 1 伤
	_eq("护甲吸 2 后 1 伤", 49, int(b9.player["hp"]))
	_eq("回合 2 临时甲清零（重置回底数 0——原版 SetValue 同构）", 0, int(b9.player["armor"]))

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
	_eq("三层合成：100+20（养成真值）+10（本局）＝130", 130, b10.stat_val("might"))
	b10.player["qi"] = 99
	b10.play_card(int(b10.hand[0]["uid"]))   # 菠菜（dungeon 型）：run.dungeon_stats.might +10
	_eq("dungeon 型回写 run（增量 10+10=20）", 20, int(run10["dungeon_stats"]["might"]))
	_eq("dungeon 型本战斗现值同步（140）", 140, b10.stat_val("might"))
	_eq("菠菜不磨连击（中立）", 0, b10.combo_count)
	_eq("菠菜→已打出区（直掷已撤——2026-11-08 同日撤令）", 1, b10.played_pile.size())
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


	# —— ⑪ 落账延迟（2026-11-08 对齐原版：账单打出瞬间算定、击中帧才结算跳数）——
	var b11: RefCounted = _mk_king_battle(["zhici"])
	b11.pending_visual = true   # 有屏模式：play_card 后账单挂起不落
	var king11: Dictionary = b11.encounter["active"][0]
	b11.player["qi"] = 99
	b11.play_card(int(b11.hand[0]["uid"]))
	_eq("延迟：打出瞬间真血未动（账单挂起）", 600, int(king11["hp"]))
	var snaps: Array = b11.strike_snapshot()
	_eq("延迟：账单事件 5 条（5 刺全中王）", 5, snaps.size())
	b11.settle_next_strike()
	_eq("延迟：第 1 击落账＝8 伤（杀不掉 600 血王，无 death）", 592, int(king11["hp"]))
	_eq("延迟：队列剩 4", 4, b11.strike_snapshot().size())
	b11.settle_all_strikes()
	_eq("延迟：全落兜底＝40 伤", 560, int(king11["hp"]))
	_eq("延迟：队列清空", 0, b11.strike_snapshot().size())
	## 杀死场景（2026-11-08 撤溢出轮：伤害封顶剩余血量——多余浪费不结转）
	var b12: RefCounted = VC_BATTLE.new()
	var run12: Dictionary = VC.default_vc_run()
	run12["neigong"] = ["combo_stack"]
	run12["enc_spec"] = {"name": "蝙蝠×2", "active_max": 2, "refill": 0, "pool": ["bat", "bat"]}
	b12.setup(run12)
	b12.start()
	b12.pending_visual = true
	b12.hand = [b12._make_card("cuipo_liao_heavy")]   # 45×1 撩月：8 血蝠封顶 8 死一只
	b12.player["qi"] = 99
	b12.play_card(int(b12.hand[0]["uid"]))
	_eq("封顶：打出瞬间两蝠真血未动", 2, b12._alive_active().size())
	var snaps12: Array = b12.strike_snapshot()
	var hit12: Dictionary = {}
	for ev12 in snaps12:
		if String(ev12.get("type", "")) == "hit":
			hit12 = ev12
	_eq("封顶：45 伤只记 8（跳数不超剩余血）", 8, int(hit12.get("amount", 0)))
	b12.settle_all_strikes()
	_eq("封顶：只杀一只（多余浪费不结转）", 1, b12._alive_active().size())
	_eq("封顶：win 不触发", "", String(b12.result))

	# —— ⑫ 余段空放（2026-11-08 用户令：多段卡按总段数飞完全程——怪死掉后余段
	#    刀照飞空放，胜利等全部拍完；对应原版武器全程飞行＋WaitWhile 等表现清空）——
	var b13: RefCounted = _mk_king_battle(["zhici"])
	b13.pending_visual = true
	b13.play_card(int(b13.hand[0]["uid"]))
	_eq("空放：5 段全落王（600 血）后总段数＝5", 5, b13.strike_total())
	var b14: RefCounted = VC_BATTLE.new()
	var run14: Dictionary = VC.default_vc_run()
	run14["neigong"] = ["combo_stack"]
	run14["enc_spec"] = {"name": "蝙蝠×1", "active_max": 1, "refill": 0, "pool": ["bat"]}
	b14.setup(run14)
	b14.start()
	b14.pending_visual = true
	b14.hand = [b14._make_card("zhici")]   # 5 刺×8 点：8 血蝠首刺即杀
	var zhici_d: Dictionary = (b14.hand[0]["def"] as Dictionary).duplicate(true)
	zhici_d["ops"] = [{"op": "dmg", "value": 8, "hits": 5}]   # 去 crit 保确定性
	b14.hand[0]["def"] = zhici_d
	b14.player["qi"] = 99
	b14.play_card(int(b14.hand[0]["uid"]))
	_eq("空放：单蝠账单 2 事件（hit,death——8 血蝠首刺 8 伤即杀）", 2, b14.strike_snapshot().size())
	_eq("空放：总段数仍＝5（演出 5 拍、4 拍空放）", 5, b14.strike_total())
	_eq("空放：win 延后（账单未清不终局）", "", String(b14.result))
	_eq("封顶：首击 amount＝8（满伤即杀不封顶）", 8,
		int((b14.strike_snapshot()[0] as Dictionary)["amount"]))
	## 拍映射纯函数：[hit,death]×5 → 拍0 settle=2（hit+death 同拍）、拍 1-4 blank
	var beats14: Array = VC_TGT.map_strike_beats(
		[{"type": "hit", "uid": 7, "amount": 8, "is_crit": false},
		 {"type": "death", "uid": 7}], 5)
	_eq("拍制：总拍数＝5（事件 2 条）", 5, beats14.size())
	_eq("拍制：拍0 settle=2（杀刺＋紧随 death 同拍）", 2, int(beats14[0]["settle"]))
	_eq("拍制：拍0 death_uids 记死者", 1, (beats14[0]["death_uids"] as Array).size())
	var blanks14 := 0
	for b14v in beats14:
		if bool((b14v as Dictionary).get("blank", false)):
			blanks14 += 1
	_eq("拍制：空放拍＝4", 4, blanks14)
	## 尾拍合并：超额事件 [hit,death,death]×1 → 单拍 settle=3
	var beats15: Array = VC_TGT.map_strike_beats(
		[{"type": "hit", "uid": 1, "amount": 45, "is_crit": false},
		 {"type": "death", "uid": 1}, {"type": "death", "uid": 2}], 1)
	_eq("拍制：尾拍合并超额事件（1 拍 settle=3）", 3, int(beats15[0]["settle"]))
	b14.settle_all_strikes()
	_eq("空放：全落后胜（演出收尾语义）", "win", String(b14.result))

	# —— ⑬ 直刺主序调向（2026-11-08 用户令：主序左→右——首目标＝最左、次刺向右；
	#    溢出结转仍最右存活起流不随主序变；与蓝本那把刀的右→左刚好相反）——
	var b16: RefCounted = _mk_king_battle(["zhici"])
	var king_l: Dictionary = b16.encounter["active"][0]   # 先在者＝active[0]＝最左
	var king_r: Dictionary = b16._make_enemy("skeleton_king")
	b16.encounter["active"].push_back(king_r)             # 数组序＝左→右，殿后＝最右
	b16.pending_visual = true
	b16.play_card(int(b16.hand[0]["uid"]))
	var snaps16: Array = b16.strike_snapshot()
	_eq("调向：首刺落最左王", int(king_l["uid"]), int((snaps16[0] as Dictionary)["uid"]))
	_eq("调向：次刺向右点名最右王", int(king_r["uid"]), int((snaps16[1] as Dictionary)["uid"]))

	# —— ⑭ 排清才打后排（2026-11-08 用户裁定对齐刀页「row 全清才 target the row
	#    behind」）：站位层旧制「死一个顶一个」退役——前排剩一活时后排不顶（旧制会
	#    立即顶上成为合法目标）；前排全灭→整排上移＋首批 skip=1。攻击账单层本就
	#    排清制（calculate row.is_empty 才上移）——双断言收口。 ——
	var b18: RefCounted = VC_BATTLE.new()
	var run18: Dictionary = VC.default_vc_run()
	run18["neigong"] = ["combo_stack"]
	b18.setup(run18)
	b18.start()
	var bat_l: Dictionary = b18._make_enemy("bat")
	var bat_r: Dictionary = b18._make_enemy("bat")
	var king18: Dictionary = b18._make_enemy("skeleton_king")
	king18["row"] = 1                       # 王殿后（蝠默认 row=0）
	b18.encounter["active"] = [bat_l, bat_r, king18]
	b18.encounter["reserve"] = []
	b18.pending_visual = true
	b18.hand = [b18._make_card("zhici")]
	var z18: Dictionary = (b18.hand[0]["def"] as Dictionary).duplicate(true)
	z18["ops"] = [{"op": "dmg", "value": 8, "hits": 5}]
	b18.hand[0]["def"] = z18
	b18.player["qi"] = 99
	b18.play_card(int(b18.hand[0]["uid"]))
	## 账单层：事件序＝hitL,deathL,hitR,deathR,hitK,hitK,hitK（王只在排清后进账）
	var snaps18: Array = b18.strike_snapshot()
	var king_hit18 := false
	for ev18 in snaps18:
		if String((ev18 as Dictionary).get("type", "")) == "hit" \
				and int((ev18 as Dictionary)["uid"]) == int(king18["uid"]):
			king_hit18 = true
	_eq("排清：王进账单（前排两蝠全灭后的段）", true, king_hit18)
	_eq("排清：事件 7 条（两蝠各一刺秒＋王三击）", 7, snaps18.size())
	for s18 in 2:                    # hitL,deathL——杀 L 落账
		b18.settle_next_strike()
	_eq("排清：前排剩一活（R 未落账满血）时后排不顶", 1, int(king18["row"]))
	b18.settle_next_strike()          # hitR
	b18.settle_next_strike()          # deathR——排清
	_eq("排清：排清后王整排压上 row0", 0, int(king18["row"]))
	_eq("排清：顶上者跳过标记", 1, int(king18.get("skip", 0)))
	b18.settle_all_strikes()
	_eq("排清：王吃余段 24 伤（600→576）", 576, int(king18["hp"]))
	_eq("排清：场未清不终局", "", String(b18.result))

	# —— ⑮ 甲补满制（2026-11-08 用户令「不会重叠」：破了补回、没破不动、不叠超）——
	var b19: RefCounted = VC_BATTLE.new()
	var run19: Dictionary = VC.default_vc_run()
	run19["enc_spec"] = {"name": "学甲蝠×1", "active_max": 1, "refill": 0, "pool": ["tut02"]}
	b19.setup(run19)
	b19.start()
	var tut_e: Dictionary = b19.encounter["active"][0]
	b19.hand = []
	b19.player["qi"] = 99
	b19.end_turn()
	b19.discard_anim_done()   # 敌动：结甲 +4（行动表唯一项自动选中）
	_eq("甲：首动结甲 4", 4, int(tut_e["armor"]))
	b19.hand = []
	b19.player["qi"] = 99
	b19.end_turn()
	b19.discard_anim_done()
	_eq("甲：再动不叠（恒 4）", 4, int(tut_e["armor"]))
	tut_e["armor"] = 2        # 模拟被打残
	b19.hand = []
	b19.player["qi"] = 99
	b19.end_turn()
	b19.discard_anim_done()
	_eq("甲：破残补回 4", 4, int(tut_e["armor"]))

	# —— ⑯ 状态制落区（2026-11-08 改版：攻击牌首打 0→1 即有连击交互→进已打出区；
	#    同型续链留区；无型效果牌连击 0 时仍直掷——菠菜段覆盖）——
	var b20: RefCounted = _mk_king_battle(["zhici", "cuipo_ci"])
	b20.pending_visual = true
	b20.player["qi"] = 99
	b20.play_card(int(b20.hand[0]["uid"]))   # 连环刺（短剑首打）：combo 0→1 → 已打出区
	b20.settle_all_strikes()
	_eq("状态制：攻击牌首打进已打出区", 1, b20.played_pile.size())
	_eq("状态制：首张不直掷", 0, b20.discard_pile.size())
	var b21: RefCounted = _mk_king_battle(["zhici", "cuipo_ci"])
	b21.player["qi"] = 99
	b21.play_card(int(b21.hand[0]["uid"]))   # 连环刺（短剑）：combo 1
	b21.play_card(int(b21.hand[0]["uid"]))   # 连珠刺（短剑续）：combo 2 → 区内 2 张
	_eq("状态制：同型续链留已打出区", 2, b21.played_pile.size())
	_eq("状态制：连击 1→2", 2, b21.combo_count)

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
			d["ops"] = [{"op": "dmg", "value": 8, "hits": 5}]
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
