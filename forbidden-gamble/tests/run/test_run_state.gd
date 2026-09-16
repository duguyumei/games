extends GutTest

# 组挑战·RunState 状态机（代码设计 v1.4 §4.1）：战序/胜负三分支/血量带入/历练账/
# 内力守恒与锁死/槽位 caps/牌种绑定/序列化往返。数值取 mj_decks/mj_shop 真数据。


func _basic_deck() -> Dictionary:
	return DataRepo.mj_decks()["basic"]


func _shop() -> Dictionary:
	return DataRepo.mj_shop()


func _state_after_wins(wins: int) -> RunState:
	var state := RunState.new()
	state.start(_basic_deck(), 7)
	for _i in range(wins):
		state.apply_result("player", 5000, 10)
	return state


func test_start_initializes_ledger() -> void:
	var state := RunState.new()
	state.start(_basic_deck(), 7)
	assert_eq(state.phase, "hub")
	assert_eq(state.hp_fp, 10000, "血 100×100")
	assert_eq(state.lianli, 0)
	assert_eq(state.neili, {"jin": 1, "gu": 1, "qi": 1})
	assert_true(state.neili_locked, "首战锁死")
	assert_eq(state.slot_caps, {"gongfa": 1, "xinfa": 1, "hushen": 1})
	assert_eq((state.loadout["gongfa"] as Array), ["dian_xue"])
	assert_eq((state.loadout["xinfa"] as Array), ["zhao_jia_jue"])
	assert_eq((state.loadout["hushen"] as Array), ["tie_bu_shan"])
	assert_eq(state.owned_ids.size(), 3, "起始三件入已购账")
	assert_eq(state.neili_total(), 3)


func test_battle_seed_stable_per_index() -> void:
	var state := _state_after_wins(1)
	var s0 := RunState.new()
	s0.start(_basic_deck(), 7)
	assert_eq(s0.battle_seed(), 7, "战① seed")
	assert_eq(state.battle_seed(), 7 + 1000, "战② seed")
	assert_eq(s0.battle_seed(), s0.battle_seed(), "同战重打＝同墙")


func test_build_match_cfg_snapshot() -> void:
	var state := RunState.new()
	state.start(_basic_deck(), 7)
	state.hp_fp = 4300
	var opp: Dictionary = DataRepo.mj_opponents()["grp1_ronin"]
	var cfg := state.build_match_cfg(opp)
	assert_eq(cfg["seed"], state.battle_seed())
	assert_eq(cfg["player_base_attack"], 10)
	assert_eq(cfg["player_base_defense"], 0)
	assert_eq(cfg["player_start_hp_fp"], 4300, "血量带入")
	assert_eq(cfg["player_jin_li"], 1)
	assert_eq(cfg["enemy_base_max_hp"], 90)
	assert_eq(cfg["enemy_jin_li"], 1)
	assert_eq(cfg["player_techniques"], ["dian_xue"])
	state.pailing["万3"] = "ling_gang"
	cfg = state.build_match_cfg(opp)
	assert_eq((cfg["player_pailing"] as Array).size(), 1)
	assert_eq((cfg["player_pailing"][0] as Dictionary)["suit"], "万")
	assert_eq(int((cfg["player_pailing"][0] as Dictionary)["value"]), 3)


func test_apply_result_three_branches() -> void:
	var state := RunState.new()
	state.start(_basic_deck(), 7)
	assert_eq(state.apply_result("player", 8000, 9), "settlement")
	assert_true(not state.neili_locked, "第一胜解锁洗点")
	assert_eq(state.wins, 1)
	assert_eq(state.battle_index, 1)
	assert_eq(state.hp_fp, 8000, "血量带入下一战")
	assert_eq(state.apply_result("player", 6000, 11), "settlement")
	assert_eq(state.apply_result("player", 2000, 13), "victory", "组终")
	assert_eq(state.battle_index, 3)
	assert_eq(state.total_beats, 33)


func test_victory_grants_no_rewards() -> void:
	var state := _state_after_wins(2)
	var neili_before := state.neili_total()
	assert_eq(neili_before, 5, "两胜后总量 3+2")
	state.apply_result("player", 1000, 12)
	assert_eq(state.phase, "victory")
	assert_eq(state.neili_total(), neili_before, "D14：组终不加内力")
	var granted := state.grant_lianli(_shop().get("reward_lianli", []))
	assert_eq(granted, 0, "D14：组终战无历练（越界取不到）")


func test_grant_lianli_only_first_two() -> void:
	var rewards: Array = _shop().get("reward_lianli", [])
	var s1 := _state_after_wins(1)
	assert_eq(s1.grant_lianli(rewards), 60, "战①胜")
	assert_eq(s1.lianli, 60)
	var s2 := _state_after_wins(2)
	assert_eq(s2.grant_lianli(rewards), 90, "战②胜")
	assert_eq(s2.lianli, 90)
	var s3 := _state_after_wins(3)
	assert_eq(s3.battle_index, 3)
	assert_eq(s3.grant_lianli(rewards), 0, "战③无（越界取不到）")


func test_defeat_branch() -> void:
	var state := _state_after_wins(1)
	assert_eq(state.apply_result("enemy", 0, 8), "defeat")
	assert_eq(state.phase, "over")
	assert_eq(state.wins, 1, "胜场不回滚")


func test_alloc_neili_guardrails() -> void:
	var state := RunState.new()
	state.start(_basic_deck(), 7)
	assert_false(state.alloc_neili(2, 1, 1), "首战锁死拒绝")
	state.apply_result("player", 8000, 9)
	assert_eq(state.neili_points, 4, "每胜+1")
	assert_false(state.alloc_neili(4, 1, 1), "总量不守恒拒绝")
	assert_false(state.alloc_neili(5, 0, 0), "超出总量拒绝")
	assert_true(state.alloc_neili(2, 1, 1))
	assert_eq(state.neili, {"jin": 2, "gu": 1, "qi": 1})
	assert_true(state.alloc_neili(1, 1, 2), "自由重排")


func test_wuxue_slots_and_unlock() -> void:
	var state := RunState.new()
	state.start(_basic_deck(), 7)
	assert_false(state.acquire_wuxue("lianhuan_zhang", "gongfa"), "槽满拒绝")
	assert_true(state.unlock_slot("gongfa", 2), "开槽 1→2")
	assert_true(state.free_slots("gongfa") == 1)
	assert_true(state.acquire_wuxue("lianhuan_zhang", "gongfa"))
	assert_false(state.acquire_wuxue("po_jia_quan", "gongfa"), "同 id 重复拒绝")
	for cap in range(3, 6):
		assert_true(state.unlock_slot("gongfa", cap))
	assert_false(state.unlock_slot("gongfa", 6), "上限 5")


func test_pailing_binding_rules() -> void:
	var state := RunState.new()
	state.start(_basic_deck(), 7)
	assert_true(state.acquire_pailing("ling_gang", "万3"))
	assert_false(state.acquire_pailing("ling_gang", "筒7"), "同 id 不重复")
	assert_false(state.acquire_pailing("ling_bian", "万3"), "同牌种限一枚")
	assert_true(state.acquire_pailing("ling_bian", "条5"))


func test_heal_clamped() -> void:
	var state := _state_after_wins(1)
	state.hp_fp = 9000
	assert_eq(state.heal_fp(3000), 1000, "钳于上限")
	assert_eq(state.hp_fp, 10000)
	state.hp_fp = 2000
	assert_eq(state.heal_fp(3000), 3000)


func test_dict_roundtrip() -> void:
	var state := _state_after_wins(2)
	state.lianli = 77
	state.alloc_neili(2, 2, 1)
	state.unlock_slot("xinfa", 2)
	state.acquire_wuxue("xi_lian_jue", "xinfa")
	state.acquire_pailing("ling_jia", "筒9")
	state.begin_visit()
	state.reroll_count = 2
	var restored := RunState.from_dict(state.to_dict())
	assert_eq(restored.deck_id, state.deck_id)
	assert_eq(restored.phase, "settlement")
	assert_eq(restored.hp_fp, state.hp_fp)
	assert_eq(restored.lianli, 77)
	assert_eq(restored.neili, {"jin": 2, "gu": 2, "qi": 1})
	assert_eq(restored.slot_caps, {"gongfa": 1, "xinfa": 2, "hushen": 1})
	assert_eq((restored.loadout["xinfa"] as Array), ["zhao_jia_jue", "xi_lian_jue"])
	assert_eq(restored.pailing, {"筒9": "ling_jia"})
	assert_eq(restored.reroll_count, 2)
	assert_eq(restored.battle_index, 2)
