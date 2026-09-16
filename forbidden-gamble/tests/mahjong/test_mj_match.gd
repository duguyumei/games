extends GutTest

# 对弈引擎（真气语法 v3.6）：一拍＝摸牌或招架→自动效果→附属行为→打出恰一次（max(1, 超额)）。
# 攻击四式：虚招（无超额·0 伤·可被吃/碰/杠）｜普攻（100%＋光环·可被碰/杠取消）｜重击（前摇·不可截）｜反击（0 伤·不可截）。
# 伤害管线＝倍率%×攻击面板→承伤比 5/(5+防御)→护体免伤→气血（定点两位小数，显示向上取整）。
# 缺省面板：攻 12（10+2×1）、防 1（承伤 5/6）、血 100、摸 3、变招充能 2/拍（1+气力1，6 充能＝1 机会）。
# 测试驱动器：_drive 用缺省应答推进到目标 phase；关键手牌直接改 fighter.hand（仅测试用）。


var match_: MJMatch


func before_each() -> void:
	match_ = MJMatch.new()
	match_.setup({"seed": 123})


func _t(suit: String, value: int) -> MJTile:
	return MJTile.make(suit, value)


func _set_hand(side: String, tiles: Array) -> void:
	var f := match_.fighter(side)
	f.hand.clear()
	for t in tiles:
		f.hand.append(t)


# 16 张模板：万5-6-7（点×1 可付）＋散牌 13。
func _hand16() -> Array:
	return [_t("万", 5), _t("万", 6), _t("万", 7), _t("筒", 1), _t("筒", 4),
		_t("筒", 7), _t("条", 2), _t("条", 5), _t("条", 8), _t("万", 9), _t("筒", 3), _t("筒", 6),
		_t("条", 9), _t("万", 2), _t("万", 7), _t("万", 8)]


# 敌方 13 张无对子模板（确保截牌窗无碰/杠干扰）。
func _enemy13_no_pair() -> Array:
	return [_t("万", 3), _t("万", 4), _t("筒", 9), _t("筒", 2), _t("筒", 5),
		_t("条", 1), _t("条", 4), _t("条", 7), _t("万", 8), _t("筒", 1), _t("筒", 6), _t("条", 3), _t("条", 9)]


# 缺省应答：不发动、弃前三张、不截。
func _default_decide(request: Dictionary) -> Dictionary:
	match String(request.get("phase", "")):
		"free_fire":
			return {"fire": []}
		"posture":
			var count := int(request.get("discard_count", 0))
			var indexes: Array[int] = []
			for i in range(count):
				indexes.append(i)
			return {"discard_indexes": indexes}
		"claim":
			return {"claim": null}
	return {}


# 推进直到出现目标 phase 的请求（对齐 side 可选）；超步数返回空。
func _drive(wanted_phase: String, wanted_side: String = "", max_steps := 80) -> Dictionary:
	for _i in range(max_steps):
		var request := match_.next_request()
		if request.is_empty():
			return {}
		if String(request["phase"]) == wanted_phase and (wanted_side == "" or String(request["side"]) == wanted_side):
			return request
		match_.decide(_default_decide(request))
	return {}


# ---------- 开局与正常拍 ----------

func test_start_first_phase_is_free_fire_with_16() -> void:
	match_.start_battle()
	assert_eq(match_.fighter("enemy").hand.size(), 13, "敌方静息 13")
	var request := match_.next_request()
	assert_eq(String(request["phase"]), "free_fire", "摸牌环节自动完成后进入打出环节")
	assert_eq(String(request["side"]), "player")
	assert_eq((request["hand"] as Array).size(), 16, "13＋摸 3（基础定值）＝16")
	assert_eq(int(request["max_hp"]), 100, "血量面板＝基础 100（骨力不管血）")
	assert_eq(int(request["attack_panel"]), 12, "攻击面板＝基础10＋2×劲力1")
	assert_eq(match_.fighter("player").bian_charge, 2, "首个自身拍充能 1+气力1＝2")


func test_normal_turn_posture_to_cap_and_side_flips() -> void:
	match_.start_battle()
	match_.decide({"fire": []})                       # 不发重击 → 打出走普攻
	var posture_req := match_.next_request()
	assert_eq(String(posture_req["phase"]), "posture")
	assert_eq(int(posture_req["discard_count"]), 3, "打出：超 3 弃 3")
	assert_eq(String(posture_req.get("play_kind", "")), "normal", "有超额＝普攻")
	match_.decide({"discard_indexes": [0, 1, 2]})
	var claim_req := match_.next_request()
	assert_eq(String(claim_req["phase"]), "claim")
	assert_eq(String(claim_req["side"]), "enemy", "截牌窗开给对方")
	match_.decide({"claim": null})
	assert_eq(match_.river.size(), 3, "批次入气河")
	assert_eq(match_.fighter("player").gang_qi, 1, "架势（摸牌）+1")
	assert_eq(match_.fighter("player").hand.size(), 13, "回到静息")
	var next := match_.next_request()
	assert_eq(String(next["phase"]), "free_fire")
	assert_eq(String(next["side"]), "enemy", "流向对方")


# ---------- 普攻即伤（v3.6 K 曲线：100%×12 → 承伤 5/6） ----------

func test_normal_attack_lands_when_passed() -> void:
	match_.start_battle()
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})  # 敌方放行 → 普攻伤害落地
	var enemy := match_.fighter("enemy")
	assert_eq(enemy.hp_fp, 10000 - 1000, "100%×面板12→承伤5/6＝10.00（1000 定点）")
	assert_eq(enemy.hp_display(), 90, "显示整数")


func test_aura_melds_boost_normal_attack() -> void:
	match_.start_battle()
	match_.fighter("player").melds.append(
		{"tiles": [_t("条", 5), _t("条", 5), _t("条", 5)], "type": "PON", "suit": "条", "symbol": "撼"})
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	assert_eq(match_.fighter("enemy").hp_fp, 10000 - 1500, "一组副露光环：150%×12→承伤5/6＝15.00")


func test_claim_cancels_attack_and_counter_deals_none() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("条", 5), _t("条", 5), _t("万", 1), _t("万", 2), _t("万", 4),
		_t("筒", 3), _t("筒", 6), _t("筒", 7), _t("条", 1), _t("条", 9), _t("万", 8), _t("筒", 5), _t("万", 6)])
	_set_hand("player", [_t("条", 5), _t("万", 3), _t("万", 5), _t("万", 7), _t("筒", 4),
		_t("筒", 6), _t("筒", 8), _t("条", 2), _t("条", 3), _t("条", 4), _t("万", 9), _t("筒", 9), _t("条", 8),
		_t("筒", 1), _t("筒", 2), _t("筒", 3)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 弃条5＋万3＋万5
	match_.decide({"claim": {"type": "pon", "batch_index": 0}})
	assert_eq(match_.fighter("enemy").hp_fp, 10000, "被招架：普攻伤害取消")
	var enemy := match_.fighter("enemy")
	assert_eq(enemy.melds.size(), 1)
	assert_eq(String(enemy.melds[0]["symbol"]), "撼", "条重＝撼")
	assert_eq(enemy.gang_qi, 1, "招架 +1（v3.5 经济）")
	# 截牌拍：敌方（截者）打出至上限＝1 张＝反击（不可截、暂不造成伤害）
	var posture := match_.next_request()
	assert_eq(String(posture["side"]), "enemy", "截牌拍归截者")
	assert_eq(String(posture.get("play_kind", "")), "counter", "反击拍单列标记：不得按虚招/普攻口径提示（不可截）")
	assert_eq(int(posture["discard_count"]), 1, "碰后恰好弃 1（麻将原生）")
	match_.decide({"discard_indexes": [0]})
	# 反击不可被截（v3.6）：不开窗——下一请求直接归玩家
	var next := match_.next_request()
	assert_eq(String(next["phase"]), "free_fire", "反击无窗：直接轮到玩家")
	assert_eq(String(next["side"]), "player")
	assert_eq(match_.fighter("player").hp_fp, 10000, "反击暂不造成伤害（插座）")
	assert_eq(match_.river.side_at(match_.river.size() - 1), "enemy", "反击的牌入气河（绝对安全弃牌）")
	assert_eq(match_.fighter("enemy").bian_charge, 3, "招架拍充能 2（1+气1）＋拆招诀 1＝3")


# ---------- 虚招（v3.6：打出时无超额→0 伤、可被吃） ----------

func test_xuzhao_zero_damage_and_play_kind() -> void:
	match_.start_battle()
	_set_hand("enemy", _enemy13_no_pair())
	# 玩家首拍手牌直接压到 9（打出阶段前）：无超额＝虚招（回气拍已退役）
	_set_hand("player", [_t("万", 5), _t("万", 1), _t("万", 4), _t("万", 7), _t("筒", 2),
		_t("筒", 5), _t("筒", 8), _t("条", 3), _t("条", 6)])
	match_.decide({"fire": []})
	var posture_req := match_.next_request()
	assert_eq(String(posture_req["side"]), "player", "虚招拍照常行动（不再整拍跳过）")
	assert_eq(int(posture_req["discard_count"]), 1, "打出至少一张：max(1, 9-13)＝1")
	assert_eq(String(posture_req.get("play_kind", "")), "xuzhao", "无超额＝虚招")
	match_.decide({"discard_indexes": [0]})
	var claim_req := match_.next_request()
	assert_eq(String(claim_req["phase"]), "claim", "虚招照样开截牌窗（可被吃/碰/杠）")
	match_.decide({"claim": null})
	assert_eq(match_.fighter("enemy").hp_fp, 10000, "虚招 0 伤")
	assert_eq(match_.fighter("player").hand.size(), 8, "打出后 8＜13：静息收敛（非每时刻相等）")


func test_chi_only_against_xuzhao() -> void:
	match_.start_battle()
	_set_hand("enemy", _enemy13_no_pair())  # 含 万3＋万4（可与万5 成顺）
	_set_hand("player", [_t("万", 5), _t("万", 1), _t("万", 4), _t("万", 7), _t("筒", 2),
		_t("筒", 5), _t("筒", 8), _t("条", 3), _t("条", 6)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0]})  # 虚招打出 万5
	var claim_req := match_.next_request()
	var has_chi := false
	for option in claim_req["claim_options"]:
		if String(option["type"]) == "chi":
			has_chi = true
	assert_true(has_chi, "虚招批开放吃（敌方手里 万3-4 可与 万5 成顺）")
	match_.decide({"claim": {"type": "chi", "batch_index": 0}})
	var enemy := match_.fighter("enemy")
	assert_eq(enemy.melds.size(), 1, "吃成副露")
	assert_eq(String(enemy.melds[0]["type"]), "CHI")
	assert_eq(String(enemy.melds[0]["symbol"]), "点", "吃来的顺子＝万门轻式")
	assert_eq(enemy.gang_qi, 1, "吃＝招架族：罡气+1")
	assert_eq(match_.fighter("player").hp_fp, 10000, "被吃的虚招本来就 0 伤")
	var posture := match_.next_request()
	assert_eq(String(posture["side"]), "enemy", "截者接续")
	assert_true(match_.log.any(func(line: String): return line.contains("招架·吃")), "日志记录吃")


func test_no_chi_against_normal_attack() -> void:
	match_.start_battle()
	_set_hand("enemy", _enemy13_no_pair())  # 含 万3＋万4（若开放吃可吃 万5）
	match_.decide({"fire": []})
	# 普攻批次 [万5,万6,万7]（超额打出）——敌方有 万3-4 顺搭但普攻不可吃
	match_.decide({"discard_indexes": [0, 1, 2]})
	var claim_req := match_.next_request()
	var has_chi := false
	for option in claim_req["claim_options"]:
		if String(option["type"]) == "chi":
			has_chi = true
	assert_false(has_chi, "普攻批不开放吃（吃仅对虚招）")
	match_.decide({"claim": null})


# ---------- 护体（铁布衫）：免费即时、激活/衰减/持续/禁发功/冻结/在途锁 ----------

func test_defense_iron_activation() -> void:
	match_.start_battle()
	match_.fighter("player").gang_qi = 3
	var hand_before := match_.fighter("player").hand.size()
	assert_true(match_.try_defense("player", "tie_bu_shan"))
	var f := match_.fighter("player")
	assert_true(f.iron_active, "铁布衫激活")
	assert_eq(f.iron_reduction, 80, "80% 免伤起算")
	assert_eq(f.iron_beats_left, 3, "持续 3 个敌方拍")
	assert_eq(f.gang_qi, 0)
	assert_eq(f.hand.size(), hand_before, "护体免费：手牌不动、不占打出")
	assert_eq(String(match_.next_request()["phase"]), "free_fire", "拍照常继续")


func test_defense_window_and_no_reactivate() -> void:
	match_.start_battle()
	match_.fighter("player").gang_qi = 3
	assert_true(match_.try_defense("player", "tie_bu_shan"), "摸牌后出牌前＝窗口内")
	match_.fighter("player").gang_qi = 3
	assert_false(match_.try_defense("player", "tie_bu_shan"), "激活期内不可重开（衰减从 80% 起算的前提）")
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	# 截牌窗（敌方应答）：双方都无窗口
	match_.fighter("player").gang_qi = 3
	match_.fighter("enemy").gang_qi = 3
	assert_false(match_.try_defense("player", "tie_bu_shan"), "自己开出的截牌窗中无窗口")
	assert_false(match_.try_defense("enemy", "tie_bu_shan"), "截牌决定期无窗口")
	match_.decide({"claim": null})
	# 敌方 free_fire：玩家无窗口、敌方有
	match_.fighter("enemy").gang_qi = 3
	assert_false(match_.try_defense("player", "tie_bu_shan"), "对方回合无窗口")
	assert_true(match_.try_defense("enemy", "tie_bu_shan"), "行动方有窗口")


func test_defense_window_on_claim_beat() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("条", 5), _t("条", 5), _t("万", 1), _t("万", 4), _t("万", 7),
		_t("筒", 2), _t("筒", 5), _t("筒", 8), _t("条", 3), _t("条", 6), _t("条", 9), _t("万", 8), _t("筒", 6)])
	_set_hand("player", [_t("条", 5), _t("万", 3), _t("万", 5), _t("万", 7), _t("筒", 4),
		_t("筒", 6), _t("筒", 8), _t("条", 2), _t("条", 3), _t("条", 4), _t("万", 9), _t("筒", 9), _t("条", 8),
		_t("筒", 1), _t("筒", 2), _t("筒", 3)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.fighter("enemy").gang_qi = 3
	assert_false(match_.try_defense("enemy", "tie_bu_shan"), "截牌决定期无窗口（招架＝摸牌环节，还没到打出）")
	match_.decide({"claim": {"type": "pon", "batch_index": 0}})
	assert_eq(String(match_.next_request()["phase"]), "posture", "截牌拍归截者打出")
	match_.fighter("enemy").gang_qi = 3
	assert_true(match_.try_defense("enemy", "tie_bu_shan"), "招架后的打出阶段＝窗口内")


func test_iron_mitigates_and_degrades() -> void:
	match_.start_battle()
	var p := match_.fighter("player")
	p.gang_qi = 3
	assert_true(match_.try_defense("player", "tie_bu_shan"))
	# 敌方 100%×12→承伤5/6＝1000 定点；铁布衫 80%：只入 200，减免 800
	match_._strike("enemy", 100, "测试一")
	assert_eq(p.hp_fp, 10000 - 200, "80% 免伤：10.00 只入 2.00")
	assert_eq(p.iron_reduction, 70, "累计减免 8.00 ≥ 5：免伤率立刻 −10%（K 曲线下伤害变大）")
	match_._strike("enemy", 100, "测试二")
	assert_eq(p.hp_fp, 10000 - 200 - 300, "70% 档：10.00 只入 3.00")
	assert_eq(p.iron_reduction, 50, "结转 3.00＋本次减免 7.00＝10.00：连掉两档")
	match_._strike("enemy", 100, "测试三")
	assert_eq(p.hp_fp, 10000 - 200 - 300 - 500, "50% 档：10.00 只入 5.00")
	assert_eq(p.iron_reduction, 40, "减免 5.00 再掉一档")


func test_iron_duration_decrements_on_enemy_beats() -> void:
	match_.start_battle()
	match_.fighter("player").gang_qi = 3
	assert_true(match_.try_defense("player", "tie_bu_shan"))
	# 拍序：玩家激活 → P1（不减）→ E1（→2）→ P2 → E2（→1）→ P3 → E3（→0 解除）
	for beat_i in range(6):
		match_.decide({"fire": []})  # 该拍行动方的 free_fire
		var req := match_.next_request()
		if String(req.get("phase", "")) == "posture":
			match_.decide({"discard_indexes": [0, 1, 2]})
		req = match_.next_request()
		if String(req.get("phase", "")) == "claim":
			match_.decide({"claim": null})
		# 偶数索引＝玩家拍（激活拍），奇数＝敌方拍 → 递减
		if beat_i % 2 == 1:
			assert_eq(match_.fighter("player").iron_beats_left, 3 - (beat_i + 1) / 2,
				"敌方拍末 −1（第 %d 拍后）" % (beat_i + 1))
	assert_false(match_.fighter("player").iron_active, "3 个敌方拍到 → 解除")
	assert_true(match_.log.any(func(line: String): return line.contains("到期解除")))


func test_iron_blocks_fire_and_freezes_gang_qi() -> void:
	match_.start_battle()
	_set_hand("player", _hand16())
	match_.fighter("player").gang_qi = 3
	assert_true(match_.try_defense("player", "tie_bu_shan"))
	assert_false(match_.try_fire("player", "dian_xue"), "护体期间不能发功法（重击封锁）")
	match_.fighter("player").add_gang_qi(2)
	assert_eq(match_.fighter("player").gang_qi, 0, "护体期间罡气冻结不增")


# ---------- 罡气经济（上限 5；摸牌/招架 +1） ----------

func test_gang_qi_cap_and_freeze() -> void:
	var f := MJFighter.new()
	f.add_gang_qi(10)
	assert_eq(f.gang_qi, 5, "上限 5")


# ---------- 重击（前摇）：式发动即打出、对方拍计数、我方摸牌后发动、在途锁防御 ----------

func test_fire_windup_resolves_after_opponent_beats() -> void:
	match_.start_battle()
	_set_hand("player", _hand16())
	match_.decide({"fire": ["dian_xue"]})  # 重击＝打出：耗点式 3 张，13＝上限直接收拍
	var player := match_.fighter("player")
	assert_eq(player.hand.size(), 13, "耗 3 不回填：16−3＝13（恰静息）")
	assert_eq(match_.fighter("enemy").hp_fp, 10000, "前摇期不即时伤")
	assert_eq(match_.river.size(), 3, "式在发动那一刻入河明牌")
	assert_eq(player.pending.size(), 1, "点穴式在途（前摇＝式数 1）")
	assert_eq(int(player.pending[0]["windup"]), 1)
	match_.fighter("player").gang_qi = 3
	assert_false(match_.try_defense("player", "tie_bu_shan"), "在途期间＋对方回合：无防御（双闸）")
	# 敌拍（普攻落地）→ 玩家下拍摸牌后：自动效果阶段结算在途
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	assert_eq(match_.fighter("player").hp_fp, 10000 - 1000, "敌普攻照常落地（10.00）")
	assert_eq(match_.fighter("enemy").hp_fp, 10000 - 2000, "200%×12→承伤5/6＝20.00（我方摸牌后发动）")
	assert_eq(player.pending.size(), 0)
	assert_eq(String(match_.next_request()["side"]), "player")


func test_fire_windup_two_waits_and_locks_defense() -> void:
	match_.start_battle()
	var tech: MJTechnique = load("res://core/mahjong/techniques/tech_dian_xue.gd").new()
	tech.windup = 2  # 手动加倍前摇：验证按对方经过拍数计
	match_.techniques["player"]["dian_xue"] = tech
	_set_hand("player", _hand16())
	match_.decide({"fire": ["dian_xue"]})
	# 敌拍 1（elapsed→1）
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	assert_eq(match_.fighter("enemy").hp_fp, 10000, "前摇 2：对方只过了 1 拍，不发动")
	# 我拍中段（pending 存在）：在途锁防御
	match_.fighter("player").gang_qi = 3
	assert_false(match_.try_defense("player", "tie_bu_shan"), "前摇未满的我方拍：在途期间不能发动防御（互斥对称）")
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	# 敌拍 2（elapsed→2）→ 我方摸牌后发动
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	assert_eq(match_.fighter("enemy").hp_fp, 10000 - 1000 - 2000, "我拍普攻 10.00＋到期重击 20.00")


func test_fire_once_per_beat_and_plan_picks_displayed() -> void:
	match_.start_battle()
	# 两个万顺（万4-5-6＋万5-6-7）——点穴式（点×1）可付但一拍只一发；变体枚举供选择
	_set_hand("player", [_t("万", 4), _t("万", 5), _t("万", 6), _t("万", 5), _t("万", 6),
		_t("万", 7), _t("筒", 1), _t("筒", 4), _t("筒", 7), _t("条", 2), _t("条", 5), _t("条", 8), _t("万", 9),
		_t("条", 3), _t("条", 6), _t("条", 9)])
	var request := match_.next_request()
	var plans: Array = []
	for tech in request["techniques"]:
		if String(tech["id"]) == "dian_xue":
			plans = tech["plans"]
	assert_true(plans.size() >= 2, "两个万顺：付法 ≥2 种")
	match_.decide({"fire": ["dian_xue", "dian_xue"], "fire_variant": 1})
	assert_eq(match_.fighter("player").pending.size(), 1, "每拍至多一门")


# 重击无超额前置（2026-09-16 用户拍板）：静息位（手牌≤上限）也可发，付式后手牌低于上限、坑留摸牌回填。
func test_fire_from_rest_position() -> void:
	match_.start_battle()
	_set_hand("player", [_t("万", 5), _t("万", 6), _t("万", 7), _t("筒", 1), _t("筒", 4),
		_t("筒", 7), _t("条", 2), _t("条", 5), _t("条", 8), _t("万", 9), _t("筒", 3), _t("筒", 6), _t("条", 9)])
	var request := match_.next_request()
	var can := false
	for tech in request["techniques"]:
		if String(tech["id"]) == "dian_xue":
			can = bool(tech["can_use"])
	assert_true(can, "手牌＝13（无超额）也可发重击：视图超额前置已撤（引擎本就放行）")
	match_.decide({"fire": ["dian_xue"]})
	var p := match_.fighter("player")
	assert_eq(p.hand.size(), 10, "付式后手牌低于上限：坑留给摸牌回填")
	assert_eq(match_.river.size(), 3, "式三张入河（明牌预告）")
	assert_eq(p.pending.size(), 1, "前摇进在途")
	assert_eq(String(match_.next_request()["side"]), "enemy", "重击＝本拍打出：直接收拍")


# ---------- 变招（v3.6 按拍充能：1+气力/拍、6 充能＝1 机会） ----------

func test_bian_charge_per_beat() -> void:
	match_.start_battle()
	var p := match_.fighter("player")
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	assert_eq(p.bian_charge, 2, "打出张数不再计充能（按拍计：1+气1＝2）")
	assert_eq(p.bian_opps, 0, "2＜6 未转机会")
	# 再走两个完整回合（玩家共 3 拍）：2+2+2＝6 → 1 机会
	for _i in range(2):
		match_.decide({"fire": []})                   # 敌 free_fire
		match_.decide({"discard_indexes": [0, 1, 2]})
		match_.decide({"claim": null})
		match_.decide({"fire": []})                   # 我 free_fire
		match_.decide({"discard_indexes": [0, 1, 2]})
		match_.decide({"claim": null})
	assert_eq(p.bian_charge, 0, "满 6 转机会、余量清零")
	assert_eq(p.bian_opps, 1, "3 拍充能 6＝1 次机会（气力 1 基线）")


func test_bian_hand_swap() -> void:
	match_.start_battle()
	var p := match_.fighter("player")
	p.bian_opps = 1
	var old_key := (p.hand[0] as MJTile).key()
	var wall_before := match_.wall.live_left()
	assert_true(match_.try_bian_hand("player", 0))
	assert_eq(p.bian_opps, 0)
	assert_eq(p.hand.size(), 16, "弃 1 摸 1：手牌数不变")
	assert_eq(match_.wall.live_left(), wall_before - 1)
	assert_eq(match_.river.side_at(match_.river.size() - 1), "player", "换掉的牌入气河")
	assert_true(match_.river.tiles.any(func(t: MJTile): return t.key() == old_key))
	assert_false(match_.try_bian_hand("player", 0), "机会不足不可再换")


func test_bian_group_from_hand_deals_half() -> void:
	match_.start_battle()
	_set_hand("player", [_t("万", 5), _t("万", 5), _t("万", 5), _t("筒", 1), _t("筒", 4),
		_t("筒", 7), _t("条", 2), _t("条", 5), _t("条", 8), _t("万", 9), _t("筒", 3), _t("筒", 6),
		_t("条", 9), _t("万", 2), _t("万", 7), _t("万", 8)])
	var p := match_.fighter("player")
	p.bian_opps = 3
	assert_true(match_.try_bian_group("player", -1, [0, 1, 2]))
	assert_eq(p.bian_opps, 0)
	assert_eq(p.hand.size(), 16, "弃组 3 摸 3：手牌数不变")
	assert_eq(match_.fighter("enemy").hp_fp, 10000 - 500, "换组：50%×12→承伤5/6＝5.00")
	assert_false(match_.try_bian_group("player", -1, [0, 1, 5]), "非面子组（3 张不成刻/顺）拒斥")


func test_bian_group_from_meld_keeps_invariant() -> void:
	match_.start_battle()
	var p := match_.fighter("player")
	p.melds.append({"tiles": [_t("条", 5), _t("条", 5), _t("条", 5)], "type": "PON", "suit": "条", "symbol": "撼"})
	p.bian_opps = 3
	var hand_before := p.hand.size()
	assert_true(match_.try_bian_group("player", 0))
	assert_eq(p.melds.size(), 0, "副露组被换走")
	assert_eq(p.hand.size(), hand_before + 3, "弃 3 摸 3 入手牌")
	assert_eq(match_.fighter("enemy").hp_fp, 10000 - 500, "换副露组同样 50% 伤害")


func test_bian_window_gates() -> void:
	match_.start_battle()
	var p := match_.fighter("player")
	p.bian_opps = 3
	match_.decide({"fire": []})
	assert_true(match_.try_bian_hand("player", 0), "打出前的窗口内可变招")
	match_.decide({"discard_indexes": [0, 1, 2]})
	p.bian_opps = 3
	assert_false(match_.try_bian_hand("player", 0), "自己开出的截牌窗中无窗口")


# ---------- 拆招诀（基础心法）：招架 +1 变招充能 ----------

func test_zhao_jia_jue_charges_on_claim() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("条", 5), _t("条", 5), _t("万", 1), _t("万", 4), _t("万", 7),
		_t("筒", 3), _t("筒", 6), _t("筒", 7), _t("条", 1), _t("条", 9), _t("万", 8), _t("筒", 5), _t("万", 6)])
	_set_hand("player", [_t("条", 5), _t("万", 3), _t("万", 5), _t("万", 7), _t("筒", 4),
		_t("筒", 6), _t("筒", 8), _t("条", 2), _t("条", 3), _t("条", 4), _t("万", 9), _t("筒", 9), _t("条", 8),
		_t("筒", 1), _t("筒", 2), _t("筒", 3)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 弃条5＋万3＋万5 → 敌方可碰条5
	match_.decide({"claim": {"type": "pon", "batch_index": 0}})
	match_.decide({"discard_indexes": [0]})  # 敌方反击弃 1 张（不可截，无窗）
	assert_eq(match_.fighter("enemy").bian_charge, 3, "拆招诀：敌碰拍充能 2＋心法 1＝3")


# ---------- 截牌拍：杠、万能式 ----------

func test_claim_kan_rinshan_and_wildcard() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("筒", 2), _t("筒", 2), _t("筒", 2), _t("万", 1), _t("万", 2),
		_t("万", 4), _t("筒", 3), _t("筒", 6), _t("筒", 7), _t("条", 1), _t("条", 9), _t("万", 8), _t("筒", 5)])
	_set_hand("player", [_t("筒", 2), _t("万", 3), _t("万", 5), _t("万", 6), _t("万", 7),
		_t("条", 4), _t("条", 5), _t("条", 6), _t("筒", 8), _t("筒", 9), _t("万", 9), _t("条", 7), _t("条", 8),
		_t("条", 1), _t("条", 9), _t("万", 1)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": {"type": "kan", "batch_index": 0}})
	var enemy := match_.fighter("enemy")
	assert_eq(String(enemy.melds[0]["type"]), "KAN")
	assert_eq(enemy.hand.size(), 13 - 3 + 1, "岭上摸 1：11＝上限10＋待弃1")
	assert_eq(match_.fighter("player").hp_fp, 10000, "招架（杠）不造成伤害（v3.5）")
	var posture := match_.next_request()
	assert_eq(int(posture["discard_count"]), 1)
	match_.decide({"discard_indexes": [0]})
	assert_eq(String(match_.next_request()["phase"]), "free_fire", "反击无窗：直接轮到玩家")
	# 万能式（隔离验证）：筒杠可付筒轻/筒重，一杠只付一个
	var dummy := MJFighter.new()
	dummy.melds.append({"tiles": [_t("筒", 2), _t("筒", 2), _t("筒", 2), _t("筒", 2)], "type": "KAN", "suit": "筒", "symbol": ""})
	assert_false(match_._plan_recipe(dummy, {"刺": 1}).is_empty(), "KAN 本门万能式可付筒轻")
	assert_false(match_._plan_recipe(dummy, {"劈": 1}).is_empty(), "KAN 也可付筒重")
	assert_true(match_._plan_recipe(dummy, {"刺": 1, "劈": 1}).is_empty(), "一杠不能同时付两个符号")
	# 吃来的轻式可付轻配方
	var dummy2 := MJFighter.new()
	dummy2.melds.append({"tiles": [_t("筒", 2), _t("筒", 3), _t("筒", 4)], "type": "CHI", "suit": "筒", "symbol": "刺"})
	assert_false(match_._plan_recipe(dummy2, {"刺": 1}).is_empty(), "CHI 轻式可付本门轻")
	assert_true(match_._plan_recipe(dummy2, {"劈": 1}).is_empty(), "CHI 不能付重式")


# ---------- 暗杠（2026-09-16 用户拍板：手里四张自晒） ----------

func test_ankan_meld_rinshan() -> void:
	match_.start_battle()
	_set_hand("player", [_t("万", 5), _t("万", 5), _t("万", 5), _t("万", 5), _t("筒", 1), _t("筒", 4),
		_t("筒", 7), _t("条", 2), _t("条", 5), _t("条", 8), _t("万", 9), _t("筒", 3), _t("筒", 6),
		_t("条", 9), _t("万", 2), _t("万", 7)])
	var wall_before := match_.wall.live_left()
	var request := match_.next_request()
	assert_eq((request["ankan_options"] as Array).size(), 1, "手里万5×4 → 暗杠选项浮现")
	assert_eq(String((request["ankan_options"] as Array)[0]["key"]), "万5")
	match_.decide({"ankan": "万5", "fire": []})
	var p := match_.fighter("player")
	assert_eq(String(p.melds[0]["type"]), "KAN", "四张入副露＝本门万能式")
	assert_eq(p.hand.size(), 16 - 4 + 1, "岭上摸 1：手 13")
	assert_eq(match_.wall.live_left(), wall_before - 1, "岭上消耗一张墙牌")
	assert_eq(p.gang_qi, 2, "暗杠拍：架势（摸牌）+1＋暗杠+1")
	assert_eq(match_.fighter("enemy").hp_fp, 10000, "暗杠无伤害（招架/晒牌不打人）")
	var next := match_.next_request()
	assert_eq(String(next["phase"]), "posture", "暗杠后照常打出（13＞上限10 → 弃 3）")
	assert_eq(int(next["discard_count"]), 3, "打出张数＝超额 3（回气拍退役）")
	assert_eq(p.hand.size() + 3 * p.melds.size(), 16, "静息账本（拍内）：13＋3×1＝16")
	assert_false(match_._plan_recipe(p, {"崩": 1}).is_empty(), "暗杠成的万能式可付本门重式")


func test_ankan_out_of_window_rejected() -> void:
	match_.start_battle()
	match_.decide({"fire": []})
	assert_false(match_.try_ankan("player", "万5"), "打出阶段（posture）不可暗杠")
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	assert_false(match_.try_ankan("player", "万5"), "对方回合不可暗杠")


# ---------- 一次按钮多截（2026-09-16 用户定案） ----------

func test_multi_claim_one_button() -> void:
	match_.start_battle()
	# 敌方手里 条5×2＋万3×3：一批弃 [条5, 万3, 万5]——claim_indexes 一次两截：碰条5＋杠万3
	_set_hand("enemy", [_t("条", 5), _t("条", 5), _t("万", 3), _t("万", 3), _t("万", 3), _t("万", 1),
		_t("万", 4), _t("万", 7), _t("筒", 2), _t("筒", 5), _t("筒", 8), _t("条", 3), _t("条", 6)])
	_set_hand("player", [_t("条", 5), _t("万", 3), _t("万", 5), _t("万", 7), _t("筒", 4),
		_t("筒", 6), _t("筒", 8), _t("条", 2), _t("条", 3), _t("条", 4), _t("万", 9), _t("筒", 9), _t("条", 8),
		_t("筒", 1), _t("筒", 2), _t("筒", 3)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim_indexes": [0, 1]})
	var enemy := match_.fighter("enemy")
	assert_eq(enemy.melds.size(), 2, "一次应答两截")
	var types := {}
	for meld in enemy.melds:
		types[String(meld["type"])] = true
	assert_true(types.has("PON") and types.has("KAN"), "条5×2→碰；万3×3→自动按杠（无需指定）")
	assert_eq(enemy.gang_qi, 2, "每截 +1")
	assert_eq(match_.fighter("player").hp_fp, 10000, "被招架的普攻取消")
	assert_eq(match_.river.size(), 1, "余牌 万5 入河")
	var posture_req := match_.next_request()
	assert_eq(String(posture_req["phase"]), "posture", "截后截者接续打出")
	assert_eq(int(posture_req["discard_count"]), 2, "账目：手 9（含岭上），超 2 弃 2")


func test_claim_pass_still_ends_window() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("条", 5), _t("万", 3), _t("万", 5), _t("万", 1), _t("万", 4), _t("万", 7),
		_t("筒", 2), _t("筒", 5), _t("筒", 8), _t("条", 3), _t("条", 6), _t("条", 9), _t("万", 8)])
	_set_hand("player", [_t("条", 5), _t("条", 5), _t("万", 3), _t("万", 5), _t("万", 7), _t("筒", 4),
		_t("筒", 6), _t("筒", 8), _t("条", 2), _t("条", 3), _t("条", 4), _t("万", 9), _t("筒", 9), _t("条", 8),
		_t("筒", 1), _t("筒", 2)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [3, 4, 5]})  # 弃 万5＋万7＋筒4（留住条5对）→ 敌方无对子
	match_.decide({"claim": null})  # 敌方放行 → 玩家普攻落地；敌方拍
	assert_eq(match_.fighter("enemy").hp_fp, 9000, "放行＝普攻伤害落地（10.00）")
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 敌方弃 条5＋万3＋万5 → 玩家能碰 条5
	var claim_req := match_.next_request()
	assert_eq(String(claim_req["side"]), "player")
	assert_true((claim_req["claim_options"] as Array).size() >= 1, "玩家有碰的选项")
	match_.decide({"claim": null})  # 但选放行
	assert_eq(match_.fighter("player").melds.size(), 0, "放行＝整批关闭（第一次放行即死不变）")
	assert_eq(match_.river.size(), 6, "双方各弃 3 全入河")
	assert_eq(match_.fighter("player").hp_fp, 9000, "敌方普攻落地（同账 10.00）")


# ---------- 定点显示与胜负 ----------

func test_display_ceil() -> void:
	assert_eq(MJFighter.ceil_fp(0), 0)
	assert_eq(MJFighter.ceil_fp(1), 1, "0.01 → 1")
	assert_eq(MJFighter.ceil_fp(360), 4, "3.60 → 4")
	assert_eq(MJFighter.ceil_fp(1000), 10, "10.00 → 10")


func test_win_on_hp_zero() -> void:
	match_.start_battle()
	match_.fighter("enemy").hp_fp = 300  # 3.00
	match_._strike("player", 100, "测试")
	assert_eq(match_.state, "over")
	assert_eq(match_.winner, "player")


# ---------- 气河循环 ----------

func test_draw_recycles_river_when_dry() -> void:
	match_.start_battle()
	match_.river.add([_t("万", 1), _t("筒", 2), _t("条", 3), _t("条", 4), _t("条", 5)])
	match_.wall.live.clear()
	var drawn := match_._draw_with_recycle(3)
	assert_eq(drawn.size(), 3, "干涸→气河洗回后照摸")
	assert_true(match_.wall.live_left() >= 2)


# 多截应答的失败语义（2026-09-16 审计修正）：部分失败＝成功截保留；全部无效＝按放行收窗（普攻照落地）。
func test_multi_claim_invalid_treated_as_pass() -> void:
	match_.start_battle()
	_set_hand("enemy", _enemy13_no_pair())
	_set_hand("player", _hand16())
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 普攻批 [万5,万6,万7]
	var e_hp := match_.fighter("enemy").hp_fp
	match_.decide({"claim_indexes": [9]})  # 全部无效的批位
	assert_eq(match_.fighter("enemy").hp_fp, e_hp - 1000, "应答全无效＝放行：普攻照落地（100%×12→5/6＝10.00）")
	var next := match_.next_request()
	assert_eq(String(next["side"]), "enemy", "拍照常流向敌方")
	assert_eq(String(next["phase"]), "free_fire", "不进截者反击拍（旧缺陷：全失败也取消普攻＋白送反击）")


func test_multi_claim_partial_failure_keeps_first() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("条", 5), _t("条", 5), _t("万", 3), _t("万", 4), _t("筒", 9),
		_t("筒", 2), _t("筒", 5), _t("条", 1), _t("条", 4), _t("条", 7), _t("万", 8), _t("筒", 1), _t("筒", 6)])
	_set_hand("player", [_t("条", 5), _t("条", 5), _t("万", 9), _t("筒", 3), _t("筒", 6),
		_t("筒", 8), _t("条", 2), _t("条", 8), _t("条", 9), _t("万", 1), _t("万", 2), _t("万", 7), _t("万", 8),
		_t("筒", 1), _t("筒", 4), _t("筒", 7)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 普攻批 [条5,条5,万9]：敌方恰一对条5
	match_.decide({"claim_indexes": [0, 1]})
	var e := match_.fighter("enemy")
	assert_eq(e.melds.size(), 1, "对子只够一碰：第二截失败跳过（不白吃取消）")
	assert_eq(match_.river.size(), 2, "余批（条5＋万9）入河")
	assert_eq(e.gang_qi, 1, "成功的那截照常 +1")
	var req := match_.next_request()
	assert_eq(String(req["side"]), "enemy", "截者照常进入反击拍")
	assert_eq(String(req.get("play_kind", "")), "counter")


# ---------- 破绽：拍＝只自然摸牌；空手兜底即时触发 ----------

func test_flaw_beat_draws_only() -> void:
	match_.fighter("player").flawed = true
	match_.start_battle()
	var request := match_.next_request()
	assert_eq(String(request["side"]), "enemy", "破绽：玩家错失一拍，首请求直接归敌方")
	assert_eq(match_.fighter("player").hand.size(), 16, "破绽拍＝只自然摸牌：13＋3（修订 v3.4 不摸牌旧默认）")
	assert_false(match_.fighter("player").flawed, "破绽消耗不叠加")
	assert_eq(match_.fighter("player").bian_charge, 0, "破绽拍不充能")
	assert_true(match_.last_marker.begins_with("flaw:player"), "破绽拍留演出标记")


# 前摇按对方经过拍数计——破绽拍照常推进（§13.6 条款直钉）。
func test_windup_advances_on_flaw_beat() -> void:
	match_.fighter("enemy").flawed = true
	match_.start_battle()
	_set_hand("player", _hand16())
	match_.decide({"fire": ["dian_xue"]})
	# 我方发射即收拍 → 敌方破绽拍（只自然摸牌）拍末照推前摇 → 我方摸牌后点穴落地
	var e := match_.fighter("enemy")
	assert_eq(e.hp_fp, 10000 - 2000, "破绽拍照常推进前摇：200%×12→承伤5/6＝20.00")
	assert_false(match_.fighter("player").has_pending(), "前摇走完已解算")
	assert_false(e.flawed, "破绽已消耗")
	assert_eq(String(match_.next_request()["side"]), "player", "回到我方")


func test_empty_hand_grants_flaw_immediately() -> void:
	match_.start_battle()
	_set_hand("enemy", [_t("条", 5), _t("条", 5)])  # 敌方仅两张同牌：碰后清零
	_set_hand("player", [_t("条", 5), _t("万", 3), _t("万", 5), _t("万", 7), _t("筒", 4),
		_t("筒", 6), _t("筒", 8), _t("条", 2), _t("条", 3), _t("条", 4), _t("万", 9), _t("筒", 9), _t("条", 8),
		_t("筒", 1), _t("筒", 2), _t("筒", 3)])
	match_.decide({"fire": []})
	match_.decide({"discard_indexes": [0, 1, 2]})  # 批次含条5
	match_.decide({"claim": {"type": "pon", "batch_index": 0}})
	var enemy := match_.fighter("enemy")
	assert_eq(enemy.hand.size(), 0, "碰后手牌清零")
	assert_true(enemy.flawed, "效果完成点即时触发：获得破绽")
	var next := match_.next_request()
	assert_eq(String(next["side"]), "player", "本拍就地终止、轮到玩家")
	assert_true(match_.log.any(func(line: String): return line.contains("手牌清零")), "日志记录空手破绽")


# ---------- 缺牌补充（v3.6 气力：⌊气÷3⌋、至容量） ----------

func test_topup_fills_toward_capacity() -> void:
	match_.setup({"seed": 123, "player_qi_li": 3})
	match_.start_battle()
	match_.decide({"fire": []})                   # 我拍 1（充能 4）
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	_set_hand("player", [_t("万", 1), _t("万", 4), _t("万", 7), _t("筒", 2), _t("筒", 5),
		_t("筒", 8), _t("条", 3), _t("条", 6), _t("条", 9)])  # 9 张
	match_.decide({"fire": []})                   # 敌拍
	match_.decide({"discard_indexes": [0, 1, 2]})
	match_.decide({"claim": null})
	match_.decide({"fire": []})                   # 我拍 2：摸 3 → 12；气力 3 → 补 1 → 13
	var req := match_.next_request()
	assert_eq(String(req.get("play_kind", "")), "xuzhao", "补到容量恰无超额：虚招")
	assert_eq(int(req["discard_count"]), 1)
	assert_true(match_.log.any(func(line: String): return line.contains("缺牌补充")), "日志记录缺牌补充")
	match_.decide({"discard_indexes": [0]})
	match_.decide({"claim": null})
	var p := match_.fighter("player")
	assert_eq(p.bian_charge, 2, "两拍充能 4+4＝8 → 转 1 机会余 2")
	assert_eq(p.bian_opps, 1)
