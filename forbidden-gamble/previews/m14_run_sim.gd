extends Node
# M14 组挑战全流程仿真（挑战层 v1.4 验收）：AI 对 AI 走完整一组三战＋结算＋修习买满：
# 1) 组终态与奖励账（历练只前两战、组终不加内力）2) 修习消费链（开槽/购件/疗伤）
# 3) 存档等价（save→load 重建后逐字段一致）4) 血量组内带入 5) 拍数打印（TTK 常规观察）。
# 种子固定：全程确定性可复盘。

const MAX_STEPS := 4000
const RUN_SEED := 4242


func _ready() -> void:
	var fails: Array[String] = []

	RunSaver.save_path = "user://test_m14_run_save.json"
	RunSaver.clear()
	CodexState.reset_for_tests("user://test_m14_meta.json")

	if not RunSession.begin("basic", RUN_SEED):
		fails.append("卡组启动失败")
		get_tree().quit(1)
		return
	var state := RunSession.state
	assert(state != null)
	var shop := RunSession.shop_cfg()
	var hp_before := 0
	var beats_log: Array = []

	# —— 三战循环 ——
	for battle in range(RunState.GROUP_SIZE):
		var opp := RunSession.opponent()
		if opp.is_empty():
			fails.append("战 %d 无对手卡" % battle)
			break
		CodexState.discover(str(opp.get("id", "")))
		hp_before = state.hp_fp
		print("战 %d：%s（劲%d骨%d气%d）起手血 %d" % [battle, opp.get("name"), opp["neili"]["jin"], opp["neili"]["gu"], opp["neili"]["qi"], hp_before / 100])
		var result := _play_battle(state.build_match_cfg(opp), opp, fails, battle)
		var outcome := state.apply_result(result["winner"], result["player_hp"], result["beats"])
		beats_log.append(result["beats"])
		print("战 %d 结果：%s 拍 %d 玩家余血 %d" % [battle, outcome, result["beats"], result["player_hp"] / 100])
		# 血量带入：胜且非组终——下一战起手血＝上战终局血
		if outcome == "settlement":
			if result["winner"] == "player" and state.hp_fp != result["player_hp"]:
				fails.append("战 %d：血量带入账不符" % battle)
			var granted := state.grant_lianli(shop.get("reward_lianli", []))
			if granted != int((shop.get("reward_lianli", [40, 60]) as Array)[battle]):
				fails.append("战 %d：历练 %d 不符" % [battle, granted])
			_xiuxi_buy_all(state, shop, fails, battle)
			RunShop.roll_pick3(state, shop)  # 三选一（AI 跳过拿取亦可——派生稳定性不依赖拿取）
		elif outcome == "victory":
			var lianli_locked_at_victory := state.lianli
			if state.grant_lianli(shop.get("reward_lianli", [])) != 0:
				fails.append("组终战不得发历练")
			if state.lianli != lianli_locked_at_victory:
				fails.append("组终战动了历练账")
		else:
			fails.append("战 %d 告负——AI 双侧同構下应可推进（换种子或调对手）" % battle)
			break

	if state.phase != "victory":
		fails.append("组终态不符：%s" % state.phase)
	if state.wins != 3:
		fails.append("胜场 %d ≠ 3" % state.wins)
	if state.lianli < 0:
		fails.append("历练赤字")

	# —— 存档等价：中途快照 save→load 逐字段 ——
	var mid := RunState.from_dict(state.to_dict())
	if JSON.stringify(mid.to_dict()) != JSON.stringify(state.to_dict()):
		fails.append("save→load 重建不等价")

	print("三战拍数：%s｜终局 历练 %d｜内力 %d 点｜血 %d" % [
		str(beats_log), state.lianli, state.neili_points, state.hp_fp / 100])
	print("修习终态：槽 %d/%d/%d｜武学 %d 件｜牌灵 %d 枚｜图鉴发现 %d/%d" % [
		state.slot_caps["gongfa"], state.slot_caps["xinfa"], state.slot_caps["hushen"],
		state.owned_ids.size() - state.pailing.size(), state.pailing.size(),
		CodexState.discovered_count(), CodexState.all_ids().size()])

	RunSession.end()
	RunSaver.clear()
	RunSaver.save_path = RunSaver.DEFAULT_PATH
	CodexState.reset_for_tests()

	if fails.is_empty():
		print("PASS: M14 组挑战全流程仿真（三战/奖励账/修习消费/存档等价/血量带入）")
		get_tree().quit(0)
	else:
		for f in fails:
			printerr("FAIL: " + f)
		get_tree().quit(1)


# AI 对 AI 一场对局（复用 m12 驱动环；敌方权重按对手卡覆写）。
func _play_battle(cfg: Dictionary, opp: Dictionary, fails: Array[String], battle: int) -> Dictionary:
	var match_ := MJMatch.new()
	match_.setup(cfg)
	match_.start_battle()
	var ai_e := MJAI.new()
	var ai_cfg: Dictionary = opp.get("ai", {})
	if ai_cfg.has("suit_weights"):
		ai_e.suit_weights = ai_cfg["suit_weights"]
	if ai_cfg.has("defense_hp_ratio"):
		ai_e.defense_hp_ratio = float(ai_cfg["defense_hp_ratio"])
	if ai_cfg.has("charge_threat_power"):
		ai_e.charge_threat_power = int(ai_cfg["charge_threat_power"])
	var ai_p := MJAI.new()
	var steps := 0
	while match_.state == "running" and steps < MAX_STEPS:
		steps += 1
		var request := match_.next_request()
		if request.is_empty():
			break
		var decision: Dictionary = ai_p.decide(request) if String(request["side"]) == "player" else ai_e.decide(request)
		match_.decide(decision)
	if match_.state != "over":
		fails.append("战 %d：%d 步未终局" % [battle, steps])
		match_.fighter("enemy").hp_fp = 0  # 强制推进（避免死循环；记为玩家胜以走完流程账）
	return {"winner": match_.winner, "player_hp": match_.fighter("player").hp_fp, "beats": match_.beat}


# 修习消费链：开一枚槽→买空货架可买件→疗伤→洗点。
func _xiuxi_buy_all(state: RunState, shop: Dictionary, fails: Array[String], battle: int) -> void:
	state.begin_visit()
	RunShop.roll_shelf(state, shop)
	var before := state.lianli
	RunShop.buy_heal(state, shop)  # 消费优先级：先疗伤（生存）后发展
	RunShop.unlock_slot(state, shop, "gongfa")
	for i in range(state.shelf.size()):
		var entry: Dictionary = state.shelf[i]
		if bool(entry.get("bought", false)):
			continue
		if String(entry.get("cat", "")) == "pailing":
			# 牌灵：直接绑一枚未占牌种（量入为出）
			if state.lianli >= int(entry.get("price", 0)):
				for suit in ["万", "筒", "条"]:
					var bound := false
					for value in range(1, 10):
						if state.acquire_pailing(str(entry.get("id", "")), "%s%d" % [suit, value]):
							entry["bought"] = true
							state.lianli -= int(entry.get("price", 0))
							CodexState.discover(str(entry.get("id", "")))
							bound = true
							break
					if bound:
						break
		else:
			RunShop.buy(state, shop, i)
	state.alloc_neili(2, 1, 1 + (state.neili_points - 3))  # 洗点守恒
	if state.lianli > before:
		fails.append("战 %d：修习只花不赚（历练 %d→%d）" % [battle, before, state.lianli])
