extends SceneTree

const QiCardScript = preload("res://core/qi_card.gd")
const DeckFactoryScript = preload("res://core/deck_factory.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")
const CombatEngineScript = preload("res://core/combat_engine.gd")

var failures: Array[String] = []
var assertions: int = 0
var card_serial: int = 0

func _initialize() -> void:
    _test_standard_deck()
    _test_pool_structure_and_turn_draw_rules()
    _test_all_nine_hand_types_and_contributors()
    _test_power_calculation()
    _test_sequence_progression_and_condition_failure()
    _test_no_automatic_damage_or_draw()
    _test_representative_damage_draw_discard()
    _test_representative_defense_and_layers()
    _test_representative_multi_attack()
    _test_representative_special_technique()
    _test_delayed_power_snapshot()
    _test_visible_queue_left_to_right()
    _test_scripted_enemy_is_deterministic_and_locked()
    _test_enemy_ai_plan_is_deterministic_and_hidden()
    _test_enemy_ai_uses_natural_combo()
    _test_both_sides_use_synchronized_combo()
    _test_ai_battle_reaches_terminal_state()
    _test_synchronized_defense_before_damage()
    _test_synchronized_lethal_and_battle_results()
    _test_data_driven_lethal_gu_needle()
    _test_lethal_poison_and_gu_recycle_chain()
    _test_scripted_poison_demo_reaches_recycle()
    if failures.is_empty():
        print("TEST PASS: %d assertions" % assertions)
        quit(0)
    else:
        for failure in failures:
            push_error("TEST FAIL: %s" % failure)
        print("TEST FAILURES: %d / %d assertions" % [failures.size(), assertions])
        quit(1)

func _card(rank: String, attribute: String = "wind"):
    card_serial += 1
    var order: int
    match rank:
        "J": order = 11
        "Q": order = 12
        "K": order = 13
        "A": order = 14
        _: order = int(rank)
    var qi: int = 12 if rank == "A" else (11 if rank in ["J", "Q", "K"] else int(rank))
    var attribute_name: String = {"wind": "风", "forest": "林", "fire": "火", "mountain": "山"}[attribute]
    return QiCardScript.new("test_%d" % card_serial, rank, order, qi, attribute, attribute_name)

func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append("%s：期望为 true" % label)

func _test_standard_deck() -> void:
    var deck := DeckFactoryScript.create_standard_deck()
    _assert_equal(deck.size(), 52, "基础牌组共 52 张")
    var attribute_counts := {"wind": 0, "forest": 0, "fire": 0, "mountain": 0}
    var face_values := {}
    for card in deck:
        attribute_counts[card.attribute] += 1
        if card.attribute == "wind":
            face_values[card.rank_name] = card.qi_value
    for attribute in attribute_counts:
        _assert_equal(attribute_counts[attribute], 13, "%s 属性 13 张" % attribute)
    _assert_equal(face_values["J"], 11, "J 真气值")
    _assert_equal(face_values["Q"], 11, "Q 真气值")
    _assert_equal(face_values["K"], 11, "K 真气值")
    _assert_equal(face_values["A"], 12, "A 真气值")

func _test_pool_structure_and_turn_draw_rules() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(7, false)
    var unique_pools: Dictionary = {}
    for hand_id in engine.repository.pool_membership:
        for pool_id in engine.repository.pool_membership[hand_id]:
            unique_pools[pool_id] = true
    _assert_equal(unique_pools.size(), 6, "六类共用功法池")
    _assert_equal(engine.repository.pool_membership.size(), 9, "九种精确牌型均配置合格池")
    engine.sequence_book.configure({"pair": ["a", "b"], "two_pair": ["a", "b"]})
    engine.sequence_book.advance("pair")
    _assert_equal(engine.sequence_book.position("pair"), 1, "一对序列独立推进")
    _assert_equal(engine.sequence_book.position("two_pair"), 0, "两对序列不受一对推进影响")
    var drawn := engine.start_player_turn()
    _assert_equal(drawn.size(), 8, "回合开始补至基础手牌上限 8")
    _assert_equal(engine.player.hand.size(), 8, "补牌后手牌为 8")
    engine.player.discard_pile = engine.player.hand.slice(0, 3)
    engine.player.hand.clear()
    engine.player.draw_pile.clear()
    var empty_draw := engine.start_player_turn()
    _assert_equal(empty_draw.size(), 0, "牌库为空不从弃牌堆自动洗回")
    _assert_equal(engine.player.discard_pile.size(), 3, "弃牌堆保持不变")
    _assert_equal(engine.preview([])["valid"], false, "不能选择 0 张")
    engine.player.hand = [_card("2"), _card("3"), _card("4"), _card("5"), _card("6"), _card("7")]
    _assert_equal(engine.preview(_ids(engine.player.hand))["valid"], false, "不能选择超过 5 张")

func _test_all_nine_hand_types_and_contributors() -> void:
    var cases := [
        {"id": "high_card", "cards": [_card("A"), _card("7", "forest"), _card("3", "fire")], "count": 1, "sum": 12},
        {"id": "pair", "cards": [_card("7"), _card("7", "forest"), _card("A", "fire"), _card("3")], "count": 2, "sum": 14},
        {"id": "two_pair", "cards": [_card("9"), _card("9", "forest"), _card("4"), _card("4", "fire"), _card("A")], "count": 4, "sum": 26},
        {"id": "three_kind", "cards": [_card("6"), _card("6", "forest"), _card("6", "fire"), _card("A")], "count": 3, "sum": 18},
        {"id": "straight", "cards": [_card("A"), _card("2", "forest"), _card("3", "fire"), _card("4", "mountain"), _card("5")], "count": 5, "sum": 26},
        {"id": "flush", "cards": [_card("2"), _card("5"), _card("8"), _card("J"), _card("K")], "count": 5, "sum": 37},
        {"id": "full_house", "cards": [_card("7"), _card("7", "forest"), _card("7", "fire"), _card("3"), _card("3", "forest")], "count": 5, "sum": 27},
        {"id": "four_kind", "cards": [_card("8"), _card("8", "forest"), _card("8", "fire"), _card("8", "mountain"), _card("A")], "count": 4, "sum": 32},
        {"id": "straight_flush", "cards": [_card("10", "fire"), _card("J", "fire"), _card("Q", "fire"), _card("K", "fire"), _card("A", "fire")], "count": 5, "sum": 55},
    ]
    for test_case in cases:
        var result := HandEvaluatorScript.evaluate(test_case["cards"])
        _assert_equal(result["id"], test_case["id"], "识别 %s" % test_case["id"])
        _assert_equal(result["contributing"].size(), test_case["count"], "%s 参与张数" % test_case["id"])
        var qi_sum := 0
        for card in result["contributing"]:
            qi_sum += card.qi_value
        _assert_equal(qi_sum, test_case["sum"], "%s 参与真气值" % test_case["id"])
    var jq := HandEvaluatorScript.evaluate([_card("J"), _card("Q")])
    _assert_equal(jq["id"], "high_card", "J/Q 真气值相同但不成对")

func _test_power_calculation() -> void:
    var result := HandEvaluatorScript.evaluate([_card("7"), _card("7", "forest"), _card("4"), _card("3"), _card("A")])
    var values := PowerCalculatorScript.calculate(result, {
        "base_fixed": 3,
        "insight_multiplier": 1,
        "multiplier_bonus": 2,
        "power_fixed": 5,
        "power_amp_percent": 40,
    })
    _assert_equal(values["base_value"], 17, "基础值含固定修正")
    _assert_equal(values["baseline_value"], 34, "牌型基准值只读固定倍率")
    _assert_equal(values["technique_multiplier"], 5, "功法倍率加法")
    _assert_equal(values["unamplified_technique_value"], 90, "未增幅功法值")
    _assert_equal(values["technique_value"], 125, "功法值统一增幅后向下取整")

func _engine_with_hand(cards: Array, draw_cards: Array = [], seed_value: int = 99):
    var engine = CombatEngineScript.new()
    engine.setup(seed_value, false)
    engine.player.hand = cards.duplicate()
    engine.player.draw_pile = draw_cards.duplicate()
    engine.player.discard_pile.clear()
    engine.player.staging.clear()
    engine.actions_available = 1
    return engine

func _ids(cards: Array) -> Array:
    var result: Array = []
    for card in cards:
        result.append(card.id)
    return result

func _test_sequence_progression_and_condition_failure() -> void:
    var mixed_pair := [_card("9", "wind"), _card("9", "forest")]
    var engine = _engine_with_hand(mixed_pair)
    engine.repository.techniques["pure_wind_gate"] = {
        "id": "pure_wind_gate",
        "name": "测试纯风门",
        "pool": "pair_two_pair",
        "condition": {"pure_attribute": "wind"},
        "effects": [{"op": "defense", "amount": {"kind": "power"}}],
    }
    engine.sequence_book.configure({"pair": ["pure_wind_gate", "double_gu_bind"]})
    var failed := engine.confirm_play(_ids(mixed_pair))
    _assert_true(failed["success"], "牌型组即使功法条件失败仍完成出牌")
    _assert_equal(failed["technique_triggered"], false, "条件失败不触发功法")
    _assert_equal(engine.sequence_book.position("pair"), 0, "条件失败序列不推进")

    var wind_pair := [_card("9", "wind"), _card("9", "wind")]
    engine.player.hand = wind_pair
    engine.actions_available = 1
    var succeeded := engine.confirm_play(_ids(wind_pair))
    _assert_equal(succeeded["technique_triggered"], true, "条件满足触发功法")
    _assert_equal(engine.sequence_book.position("pair"), 1, "成功后序列推进一格")

func _test_no_automatic_damage_or_draw() -> void:
    var pair := [_card("5"), _card("5", "forest")]
    var reserve := [_card("A", "fire")]
    var engine = _engine_with_hand(pair + reserve, [_card("2")])
    engine.sequence_book.configure({"pair": []})
    var before_draw_count: int = engine.player.draw_pile.size()
    var result := engine.confirm_play(_ids(pair))
    _assert_true(result["success"], "空序列允许出牌")
    _assert_equal(engine.enemy.life, 100, "出牌与牌型基准值不自动伤害")
    _assert_equal(engine.player.hand.size(), 1, "连击期间不自动补牌")
    _assert_equal(engine.player.draw_pile.size(), before_draw_count, "出牌后牌库未自动抽取")
    _assert_equal(engine.player.discard_pile.size(), 2, "打出牌进入弃牌堆")

func _test_representative_damage_draw_discard() -> void:
    var selected := [_card("9", "mountain")]
    var remaining := [_card("3", "forest"), _card("4", "fire")]
    var draw_cards := [_card("6", "forest"), _card("2", "wind")]
    var engine = _engine_with_hand(selected + remaining, draw_cards, 4242)
    engine.sequence_book.configure({"high_card": ["clear_wind_gap"]})
    var result := engine.confirm_play(_ids(selected))
    _assert_true(result["technique_triggered"], "清风过隙触发")
    _assert_equal(engine.enemy.life, 91, "清风过隙造成 P 点伤害")
    _assert_equal(engine.player.draw_pile.size(), 0, "首次抽到风后额外抽 1 张")
    _assert_equal(engine.player.hand.size(), 3, "抽 2、随机弃 1、打出 1 后手牌数量")

func _test_representative_defense_and_layers() -> void:
    var pair := [_card("7", "wind"), _card("7", "forest")]
    var engine = _engine_with_hand(pair)
    var result := engine.confirm_play(_ids(pair))
    _assert_true(result["technique_triggered"], "双蛊缠脉触发")
    _assert_equal(engine.player.defense, 14, "双蛊缠脉获得 floor(P/2) 防御")
    _assert_equal(engine.enemy.stacks.get("gu_mark", 0), 1, "一对施加 1 层蛊印")

func _test_representative_multi_attack() -> void:
    var straight := [_card("2", "wind"), _card("3", "forest"), _card("4", "fire"), _card("5", "mountain"), _card("6", "wind")]
    var engine = _engine_with_hand(straight)
    var result := engine.confirm_play(_ids(straight))
    _assert_true(result["technique_triggered"], "五阳逐影触发")
    _assert_equal(engine.enemy.life, 25, "五段伤害与四次连续追击逐段结算")
    _assert_equal(engine.player.stacks.get("momentum", 0), 9, "五段与四追击累计连势")

func _test_representative_special_technique() -> void:
    var four := [_card("8", "wind"), _card("8", "forest"), _card("8", "fire"), _card("8", "mountain")]
    var remaining := [_card("2", "fire"), _card("3", "fire"), _card("4", "wind")]
    var draw_cards := [_card("5"), _card("6"), _card("7"), _card("9")]
    var engine = _engine_with_hand(four + remaining, draw_cards)
    var result := engine.confirm_play(_ids(four))
    _assert_true(result["technique_triggered"], "弃薪开炉特殊功法触发")
    _assert_equal(engine.enemy.life, 100, "特殊功法不强制即时伤害")
    _assert_equal(engine.player.stacks.get("momentum", 0), 10, "弃牌按火牌 4 / 其他 2 获得连势")
    _assert_equal(engine.player.hand.size(), 3, "N=3 时抽 3 张")
    _assert_equal(engine.player.discard_pile.size(), 7, "剩余手牌弃掉且打出四条入弃牌堆")
    _assert_equal(engine.actions_available, 1, "获得一次额外出牌机会")

func _test_delayed_power_snapshot() -> void:
    var flush := [_card("2", "forest"), _card("4", "forest"), _card("6", "forest"), _card("8", "forest"), _card("10", "forest")]
    var engine = _engine_with_hand(flush)
    var result := engine.confirm_play(_ids(flush))
    _assert_true(result["technique_triggered"], "百击归烬建立延迟记录")
    _assert_equal(engine.delayed_effects[0]["snapshot_power"], 120, "延迟记录建立时 P")
    _assert_equal(engine.delayed_effects[0]["damage_per_segment"], 6, "延迟每段读取快照 P/20")
    engine.deal_damage(engine.player, engine.enemy, 20, "technique")
    engine.power_modifiers["flush"] = {"power_amp_percent": 500}
    engine.end_player_turn()
    _assert_equal(engine.enemy.life, 80, "第一个回合结束尚未结算延迟")
    engine.end_player_turn()
    _assert_equal(engine.enemy.life, 74, "第二个回合结束按旧快照造成一段 6 伤害")
    _assert_equal(engine.delayed_effects.size(), 0, "延迟结算后移除记录")

func _test_visible_queue_left_to_right() -> void:
    var engine = _engine_with_hand([])
    var hand_result := HandEvaluatorScript.evaluate([_card("2")])
    var context := {"engine": engine, "actor": engine.player, "target": engine.enemy, "hand_result": hand_result, "power": 1, "captures": {}}
    engine.trigger_queue.enqueue("same", "右侧", "测试", 200, [{"op": "defense", "amount": 1}], context.duplicate(true))
    engine.trigger_queue.enqueue("same", "左侧", "测试", 100, [{"op": "defense", "amount": 2}], context.duplicate(true))
    engine.trigger_queue.process_timing("same", engine.effect_executor)
    _assert_equal(engine.player.defense, 3, "同一时点效果逐项更新最新状态")
    var size: int = engine.trigger_queue.history.size()
    _assert_equal(engine.trigger_queue.history[size - 2]["label"], "左侧", "触发队列先结算左侧")
    _assert_equal(engine.trigger_queue.history[size - 1]["label"], "右侧", "触发队列后结算右侧")

func _hand_ids(cards: Array) -> Array:
    var ids: Array = []
    for card in cards:
        ids.append(card.id)
    return ids

func _test_scripted_enemy_is_deterministic_and_locked() -> void:
    var first = CombatEngineScript.new()
    var second = CombatEngineScript.new()
    _assert_true(first.setup_scripted_battle(2308), "第一个脚本场景载入")
    _assert_true(second.setup_scripted_battle(2308), "第二个脚本场景载入")
    first.start_player_turn()
    second.start_player_turn()
    _assert_equal(_hand_ids(first.enemy.hand), _hand_ids(second.enemy.hand), "相同种子敌方起手一致")
    _assert_equal(first.locked_enemy_card_ids, ["fire_2", "forest_4"], "第一回合敌方按 JSON 预先锁定")
    _assert_equal(first.locked_enemy_card_ids, second.locked_enemy_card_ids, "敌方锁定不依赖玩家选牌")

func _test_enemy_ai_plan_is_deterministic_and_hidden() -> void:
    var first = CombatEngineScript.new()
    var second = CombatEngineScript.new()
    _assert_true(first.setup_scripted_battle(2308, "res://data/scripted_battle.json", true), "第一个调试 AI 场景载入")
    _assert_true(second.setup_scripted_battle(2308, "res://data/scripted_battle.json", true), "第二个调试 AI 场景载入")
    first.start_player_turn()
    second.start_player_turn()
    _assert_equal(first.locked_enemy_card_ids, second.locked_enemy_card_ids, "相同种子与局面产生相同 AI 选牌")
    _assert_equal(first.enemy_plan, second.enemy_plan, "相同种子与局面产生相同公开计划")
    _assert_true(first.enemy_plan.has("damage"), "公开计划包含预计伤害")
    _assert_true(first.enemy_plan.has("defense"), "公开计划包含预计防御")
    _assert_true(first.enemy_plan.has("combo"), "公开计划包含连击提示")
    _assert_equal(first.enemy_plan["damage"], 6, "首击公开计划正确汇总三段预计伤害")
    _assert_equal(first.enemy_plan["defense"], 0, "首击公开计划正确显示零防御")
    _assert_true(not first.enemy_plan.has("hand"), "公开计划不包含具体牌型")
    _assert_true(not first.enemy_plan.has("cards"), "公开计划不包含具体真气")
    _assert_true(not first.enemy_plan.has("technique"), "公开计划不包含具体功法")

func _test_enemy_ai_uses_natural_combo() -> void:
    var engine = CombatEngineScript.new()
    engine.setup_scripted_battle(2308, "res://data/scripted_battle.json", true)
    engine.start_player_turn()
    engine.player.hand = [_card("2", "wind"), _card("3", "forest"), _card("4", "mountain")]
    engine.player.draw_pile.clear()
    _assert_true(engine.enemy_plan.get("combo", false), "AI 首击计划提示自然连击")
    var result := engine.confirm_play(_ids(engine.player.hand.slice(0, 2)))
    _assert_true(result["success"], "玩家混属性出牌后同步行动成功")
    _assert_true(engine.enemy_natural_combo_used, "敌方实际触发自然连击")
    _assert_equal(engine.enemy.discard_pile.size(), 2, "玩家无连击时敌方自动使用单方连击")
    _assert_equal(engine.enemy_actions_available, 0, "敌方单方连击已经消耗")

func _test_both_sides_use_synchronized_combo() -> void:
    var engine = CombatEngineScript.new()
    engine.setup_scripted_battle(2308, "res://data/scripted_battle.json", true)
    engine.start_player_turn()
    engine.player.hand = [_card("2", "wind"), _card("3", "forest"), _card("4", "mountain")]
    engine.player.draw_pile.clear()
    engine.confirm_play([engine.player.hand[0].id])
    _assert_equal(engine.actions_available, 1, "玩家单属性首击获得一次连击")
    _assert_equal(engine.enemy_actions_available, 1, "敌方单属性首击获得一次连击")
    _assert_equal(engine.enemy.discard_pile.size(), 1, "双方连击时敌方等待下一次同步出牌")
    _assert_equal(engine.enemy_plan["damage"], 0, "敌方第二击计划随功法序列更新为零伤害")
    _assert_equal(engine.enemy_plan["defense"], 11, "敌方第二击计划公开预计获得防御")
    engine.confirm_play([engine.player.hand[0].id])
    _assert_equal(engine.enemy.discard_pile.size(), 2, "双方第二击完成同步连击")
    _assert_equal(engine.enemy_actions_available, 0, "敌方自然连击不会重复触发")

func _test_ai_battle_reaches_terminal_state() -> void:
    var engine = CombatEngineScript.new()
    engine.setup_scripted_battle(2308, "res://data/scripted_battle.json", true)
    engine.start_player_turn()
    var steps := 0
    var all_actions_succeeded := true
    while engine.battle_state == "active" and steps < 200:
        if engine.actions_available > 0 and not engine.player.hand.is_empty():
            var result: Dictionary = engine.confirm_play([engine.player.hand[0].id])
            all_actions_succeeded = all_actions_succeeded and result.get("success", false)
        else:
            engine.end_player_turn()
            if engine.battle_state == "active":
                engine.start_player_turn()
        steps += 1
    _assert_true(all_actions_succeeded, "完整调试 AI 战斗中玩家动作均能结算")
    _assert_true(engine.battle_state != "active", "完整调试 AI 战斗在安全步数内结束")
    _assert_true(engine.battle_state != "scenario_error", "完整调试 AI 战斗不发生场景错误")

func _install_sync_guard(engine) -> void:
    engine.repository.techniques["sync_guard"] = {
        "id": "sync_guard",
        "name": "同步护身测试",
        "pool": "high",
        "effects": [
            {"op": "defense", "amount": {"kind": "power"}},
            {"op": "damage", "amount": {"kind": "power"}},
        ],
    }
    engine.sequence_book.configure({"high_card": ["sync_guard"]})
    engine.enemy_sequence_book.configure({"high_card": ["sync_guard"]})

func _scripted_engine_with_player_high(rank: String = "5"):
    var engine = CombatEngineScript.new()
    engine.setup_scripted_battle(2308)
    engine.start_player_turn()
    engine.player.hand = [_card(rank, "mountain"), _card("3", "forest")]
    engine.player.draw_pile.clear()
    return engine

func _test_synchronized_defense_before_damage() -> void:
    var engine = _scripted_engine_with_player_high("5")
    _install_sync_guard(engine)
    var result := engine.confirm_play([engine.player.hand[0].id])
    _assert_true(result["success"], "同步出牌成功")
    _assert_equal(result["enemy_preview"]["hand"]["id"], "high_card", "敌方揭示后识别牌型")
    _assert_equal(engine.player.life, 100, "敌方伤害先被我方本击建立的防御吸收")
    _assert_equal(engine.player.defense, 1, "我方五点防御承受敌方四点伤害")
    _assert_equal(engine.enemy.life, 99, "敌方先建立四点防御后只损失一点生命")
    _assert_equal(engine.enemy.defense, 0, "敌方本击防御被我方伤害耗尽")
    _assert_equal(engine.sequence_book.position("high_card"), 0, "单门我方序列循环回第一门")
    _assert_equal(engine.enemy_sequence_book.position("high_card"), 0, "敌我序列分别推进")

func _install_lethal_strike(engine) -> void:
    engine.repository.techniques["sync_lethal"] = {
        "id": "sync_lethal",
        "name": "同步致命测试",
        "pool": "high",
        "effects": [{"op": "damage", "amount": {"kind": "power"}}],
    }
    engine.sequence_book.configure({"high_card": ["sync_lethal"]})
    engine.enemy_sequence_book.configure({"high_card": ["sync_lethal"]})

func _test_synchronized_lethal_and_battle_results() -> void:
    var unresolved = _scripted_engine_with_player_high("5")
    _install_lethal_strike(unresolved)
    unresolved.player.life = 4
    unresolved.enemy.life = 5
    var unresolved_result := unresolved.confirm_play([unresolved.player.hand[0].id])
    _assert_true(unresolved_result["success"], "双方致命同步行动成功")
    _assert_equal(unresolved.player.life, 0, "敌方即使同击被击倒仍完成已锁定伤害")
    _assert_equal(unresolved.enemy.life, 0, "我方同步伤害击倒敌方")
    _assert_equal(unresolved.battle_state, "unresolved_draw", "同归于尽不擅自判定胜负")

    var victory = _scripted_engine_with_player_high("9")
    _install_lethal_strike(victory)
    victory.enemy.life = 3
    victory.confirm_play([victory.player.hand[0].id])
    _assert_equal(victory.battle_state, "player_victory", "敌方生命归零判定胜利")

    var exhausted = _scripted_engine_with_player_high("2")
    _install_lethal_strike(exhausted)
    exhausted.player.hand = [exhausted.player.hand[0]]
    exhausted.player.draw_pile.clear()
    exhausted.confirm_play([exhausted.player.hand[0].id])
    _assert_equal(exhausted.battle_state, "player_defeat", "无手牌无牌库且敌人存活判负")

func _test_data_driven_lethal_gu_needle() -> void:
    var selected := [_card("9", "wind")]
    var engine = _engine_with_hand(selected + [_card("3", "forest")])
    var poison_target = _card("7", "fire")
    engine.enemy.hand = [poison_target]
    engine.sequence_book.configure({"high_card": ["lethal_gu_needle"]})
    var result := engine.confirm_play(_ids(selected))
    _assert_true(result["technique_triggered"], "烈蛊飞针由数据效果接口触发")
    _assert_equal(engine.enemy.life, 96, "烈蛊飞针造成 floor(P/2) 伤害")
    _assert_true(poison_target.has_combat_status("outplay", "lethal_poison"), "烈蛊飞针为对手手牌附烈毒")
    _assert_equal(engine.enemy.stacks.get("gu_mark", 0), 1, "纯风且实际附毒后获得蛊印")

func _poison_chain_engine(with_gu: bool):
    var engine = CombatEngineScript.new()
    engine.setup(5150, false)
    engine.scripted_mode = true
    engine.actions_available = 1
    engine.enemy_actions_available = 1
    engine.sequence_book.configure({"high_card": []})
    engine.enemy_sequence_book.configure({"high_card": []})
    engine.player.hand = [_card("2", "mountain"), _card("3", "forest")]
    engine.player.draw_pile.clear()
    var poisoned = _card("7", "fire")
    poisoned.set_combat_status("outplay", "lethal_poison")
    var companion = _card("4", "forest")
    engine.enemy.hand = [poisoned, companion]
    engine.enemy.draw_pile.clear()
    engine.locked_enemy_card_ids = [poisoned.id, companion.id]
    if with_gu:
        engine.enemy.stacks["gu_mark"] = 1
    return {"engine": engine, "poisoned": poisoned, "player_card": engine.player.hand[0]}

func _test_lethal_poison_and_gu_recycle_chain() -> void:
    var without_gu: Dictionary = _poison_chain_engine(false)
    var plain_engine = without_gu["engine"]
    plain_engine.confirm_play([without_gu["player_card"].id])
    _assert_equal(plain_engine.enemy.life, 93, "烈毒按真气值造成普通伤害")
    _assert_true(plain_engine.enemy.discard_pile.has(without_gu["poisoned"]), "没有蛊印时毒牌正常进入弃牌堆")
    _assert_true(not without_gu["poisoned"].has_combat_status("outplay"), "烈毒触发后移除")

    var with_gu: Dictionary = _poison_chain_engine(true)
    var gu_engine = with_gu["engine"]
    gu_engine.confirm_play([with_gu["player_card"].id])
    _assert_equal(gu_engine.enemy.life, 93, "蛊印不取消本次烈毒伤害")
    _assert_equal(gu_engine.enemy.stacks.get("gu_mark", 0), 0, "烈毒结算后消耗一层蛊印")
    _assert_true(gu_engine.enemy.draw_pile.has(with_gu["poisoned"]), "蛊印使毒牌洗回对手牌库")
    _assert_true(not gu_engine.enemy.discard_pile.has(with_gu["poisoned"]), "洗回牌不留在弃牌堆")
    _assert_true(with_gu["poisoned"].has_combat_status("outplay", "lethal_poison"), "洗回牌重新获得同种烈毒")

func _test_scripted_poison_demo_reaches_recycle() -> void:
    var engine = CombatEngineScript.new()
    engine.setup_scripted_battle(2308)
    engine.start_player_turn()
    var first_wind = null
    for card in engine.player.hand:
        if card.attribute == "wind":
            first_wind = card
            break
    _assert_true(first_wind != null, "固定种子起手存在风牌用于一线悬蛊")
    engine.confirm_play([first_wind.id])
    engine.end_player_turn()
    engine.start_player_turn()
    engine.confirm_play([engine.player.hand[0].id])
    var poisoned = engine.enemy.find_hand_card("mountain_3")
    _assert_true(poisoned != null and poisoned.has_combat_status("outplay", "lethal_poison"), "固定场景第二回合将山3附烈毒")
    var gu_before := int(engine.enemy.stacks.get("gu_mark", 0))
    engine.end_player_turn()
    engine.start_player_turn()
    _assert_true(engine.locked_enemy_card_ids.has("mountain_3"), "第三回合脚本锁定带毒山3")
    engine.confirm_play([engine.player.hand[0].id])
    _assert_equal(engine.enemy.stacks.get("gu_mark", 0), gu_before - 1, "场景实战链消耗一层蛊印")
    _assert_true(engine.enemy.draw_pile.has(poisoned), "场景实战链将山3洗回牌库")
    _assert_true(poisoned.has_combat_status("outplay", "lethal_poison"), "场景洗回山3继续携带烈毒")
