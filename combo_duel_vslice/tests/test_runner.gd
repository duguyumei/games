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
    _test_synchronized_defense_before_damage()
    _test_synchronized_lethal_and_battle_results()
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
