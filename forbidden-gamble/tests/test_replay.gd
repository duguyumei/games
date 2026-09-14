extends GutTest

# 重放一致性：相同种子 + 相同操作序列 = 完全相同的战斗过程。
# 真气语法 v2.2：快照含气海/我河/副露；脚本策略＝有功法可发则发、否则架势（弃前四张）；
# 敌方截链在玩家架势内同步必炸；玩家截牌窗脚本一律放行。

const ENCOUNTER_PATH := "res://data/sandbox_encounter.json"

func _snapshot(tm: TurnManager) -> Dictionary:
	return {
		"actions": tm.combat.action_count,
		"swaps": tm.combat.player_swap_count,
		"active": tm.combat.active_side,
		"awaiting": tm.awaiting_player_claims,
		"player_hp": tm.combat.player.hp,
		"player_guard": tm.combat.player.guard,
		"player_hand": tm.combat.player.hand.map(func(c): return c.card_id),
		"player_melds": tm.combat.player.melds.size(),
		"wall": tm.combat.qi_wall.size(),
		"my_river": tm.combat.river_of("player").size(),
		"enemy_river": tm.combat.river_of("enemy").size(),
		"fatigue_p": int(tm.combat.fatigue_count["player"]),
		"fatigue_e": int(tm.combat.fatigue_count["enemy"]),
		"enemy_hp": tm.combat.enemy.hp,
		"enemy_guard": tm.combat.enemy.guard,
		"enemy_li": tm.combat.enemy.get_status("li"),
		"intent": str(tm.enemy_intent.get("technique", "")),
	}

# 固定脚本策略：按固定功法顺序发动第一个可用功法，否则架势（弃前四张）；
# 截牌窗一律放行；敌方由 TurnManager 驱动。
func _run_scripted_battle(seed: int, max_actions := 60) -> Array:
	var combat := EncounterLoader.load(ENCOUNTER_PATH)
	var tm := TurnManager.new(combat, seed)
	tm.start_battle()
	var snapshots: Array = [_snapshot(tm)]
	var actions := 0
	while not tm.is_over() and actions < max_actions:
		# 玩家截牌窗：脚本策略＝放行（窗口作废，被动获得后行动）
		if tm.awaiting_player_claims:
			tm.player_release_flow()
			snapshots.append(_snapshot(tm))
			actions += 1
			continue
		if combat.active_side == "player":
			if combat.player.has_active_charge():
				tm.player_charge_tick()
			else:
				var acted := false
				for technique_id in ["崩山式", "点星式", "蓄势斩", "二重·壁", "行云式", "行气式", "缠丝劲"]:
					var selection := TechniqueResolver.find_legal_selection(
						technique_id, combat.player.hand, combat.player
					)
					if not selection.is_empty():
						tm.player_act(technique_id, selection)
						acted = true
						break
				if not acted:
					var discard: Array = []
					for index in range(mini(TurnManager.SWAP_MAX, combat.player.hand.size())):
						discard.append(index)
					if not combat.player.hand.is_empty():
						tm.player_swap(discard)
					else:
						break  # 无气可动：流动会自动让拍＋疲劳兜底
		else:
			tm.enemy_act()
		snapshots.append(_snapshot(tm))
		actions += 1
	return snapshots

func test_same_seed_same_battle() -> void:
	var run_a := _run_scripted_battle(42)
	var run_b := _run_scripted_battle(42)
	assert_eq(run_a.size(), run_b.size(), "两次重放的行动步数应一致")
	for i in range(mini(run_a.size(), run_b.size())):
		assert_eq(run_a[i], run_b[i], "第%d步状态不一致" % i)

func test_different_seeds_give_different_hands() -> void:
	var run_a := _run_scripted_battle(1, 1)
	var run_b := _run_scripted_battle(2, 1)
	assert_ne(run_a[0]["player_hand"], run_b[0]["player_hand"], "不同种子的初始手牌应不同")

func test_scripted_battle_reaches_a_result() -> void:
	# 脚本化战斗应能在限定步数内分出胜负（气海有限＋疲劳递增真伤＝硬时钟），不会无限进行。
	var snapshots := _run_scripted_battle(12345, 400)
	var last: Dictionary = snapshots[snapshots.size() - 1]
	assert_true(
		int(last["player_hp"]) <= 0 or int(last["enemy_hp"]) <= 0,
		"400步内应结束战斗（末态：玩家血%d 敌方血%d 疲劳%d/%d）" % [
			int(last["player_hp"]), int(last["enemy_hp"]),
			int(last["fatigue_p"]), int(last["fatigue_e"])]
	)
