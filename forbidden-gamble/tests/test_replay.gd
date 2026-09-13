extends GutTest

# 重放一致性：相同种子 + 相同操作序列 = 完全相同的战斗过程。

const ENCOUNTER_PATH := "res://data/sandbox_encounter.json"

func _snapshot(tm: TurnManager) -> Dictionary:
	return {
		"actions": tm.combat.action_count,
		"breaths": tm.combat.player_breath_count,
		"active": tm.combat.active_side,
		"player_hp": tm.combat.player.hp,
		"player_guard": tm.combat.player.guard,
		"player_hand": tm.combat.player.hand.map(func(c): return c.card_id),
		"player_draw": tm.combat.player.draw_pile.size(),
		"enemy_hp": tm.combat.enemy.hp,
		"enemy_guard": tm.combat.enemy.guard,
		"enemy_li": tm.combat.enemy.get_status("li"),
		"intent": str(tm.enemy_intent.get("technique", "")),
	}

# 固定脚本策略：按固定功法顺序发动第一个可用功法，否则调息；敌方由 TurnManager 驱动。
# 沙盒演练配的是 v1 九门通用功法的六门——脚本顺序＝先攻后防。
func _run_scripted_battle(seed: int, max_actions := 40) -> Array:
	var combat := EncounterLoader.load(ENCOUNTER_PATH)
	var tm := TurnManager.new(combat, seed)
	tm.start_battle()
	var snapshots: Array = [_snapshot(tm)]
	var actions := 0
	while not tm.is_over() and actions < max_actions:
		# 玩家蓄力占用行动机会：充能拍由引擎自动执行（脚本模拟 UI 的调度）
		if combat.player.has_active_charge() and combat.active_side == "player":
			tm.player_charge_tick()
		var acted := false
		for technique_id in ["连风式", "纵横式", "点星式", "二重·壁", "二合·屏", "一气·拒"]:
			var selection := TechniqueResolver.find_legal_selection(
				technique_id, combat.player.hand, combat.player
			)
			if not selection.is_empty():
				tm.player_act(technique_id, selection)
				acted = true
				break
		if not acted:
			tm.player_breathe()
		var safety := 20
		while not tm.is_over() and combat.active_side == "enemy" and safety > 0:
			safety -= 1
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
	# 脚本化战斗应能在限定步数内分出胜负（敌方力量逐循环滚雪球＝软时钟，拖延必死），
	# 不会无限进行。
	var snapshots := _run_scripted_battle(12345, 200)
	var last: Dictionary = snapshots[snapshots.size() - 1]
	assert_true(
		int(last["player_hp"]) <= 0 or int(last["enemy_hp"]) <= 0,
		"200步内应结束战斗"
	)
