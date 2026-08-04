extends SceneTree

const QiCardScript = preload("res://core/qi_card.gd")
const DeckFactoryScript = preload("res://core/deck_factory.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")
const CombatEngineScript = preload("res://core/combat_engine.gd")
const MapGeneratorScript = preload("res://core/map_generator.gd")
const RunStateScript = preload("res://core/run_state.gd")
const RunScene = preload("res://ui/run_main.tscn")

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
    _test_inner_skill_equipment_and_extra_qi_defense()
    _test_inner_skill_preview_and_enemy_plan()
    _test_inner_skill_and_technique_left_to_right()
    _test_consumable_shared_slots_and_generation_limit()
    _test_insight_growth_and_technique_acquisition()
    _test_hierophant_bonus_enhancement_and_preview()
    _test_aura_seeded_edition_and_preview()
    _test_map_generation_is_deterministic_and_constrained()
    _test_map_routes_reach_boss_without_crossing()
    _test_run_state_node_and_practice_gate()
    _test_run_state_battle_growth_persistence()
    _test_map_practice_and_battle_scene_integration()
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

func _test_inner_skill_equipment_and_extra_qi_defense() -> void:
    var cards := [_card("4", "wind"), _card("4", "forest"), _card("2", "fire"), _card("3", "mountain")]
    var unequipped = _engine_with_hand(cards)
    unequipped.sequence_book.configure({"pair": []})
    unequipped.confirm_play(_ids(cards))
    _assert_equal(unequipped.player.defense, 0, "未装备初始内功时额外真气不提供防御")

    var equipped_cards := [_card("4", "wind"), _card("4", "forest"), _card("2", "fire"), _card("3", "mountain")]
    var equipped = _engine_with_hand(equipped_cards)
    equipped.sequence_book.configure({"pair": []})
    equipped.player.configure_inner_skills(["extra_qi_to_defense"], 1)
    equipped.confirm_play(_ids(equipped_cards))
    _assert_equal(equipped.player.defense, 5, "未参与一对的 2 与 3 转化为 5 点防御")
    _assert_equal(equipped.player.equipped_inner_skill_ids.size(), 1, "玩家独立记录已装备内功")
    _assert_equal(equipped.enemy.equipped_inner_skill_ids.size(), 0, "敌方装备状态与玩家独立")
    equipped.player.configure_inner_skills([
        "extra_qi_to_defense", "extra_qi_to_defense", "extra_qi_to_defense",
        "extra_qi_to_defense", "extra_qi_to_defense", "extra_qi_to_defense",
        "extra_qi_to_defense"], 7)
    _assert_equal(equipped.player.equipped_inner_skill_ids.size(), 6, "基础内功装备栏上限为六")
    _assert_equal(equipped.player.technique_slot_index, 6, "动态功法位限制在当前装备顺序内")

func _test_inner_skill_preview_and_enemy_plan() -> void:
    var cards := [_card("7", "wind"), _card("7", "forest"), _card("2", "fire"), _card("3", "mountain")]
    var engine = _engine_with_hand(cards)
    engine.sequence_book.configure({"pair": []})
    engine.player.configure_inner_skills(["extra_qi_to_defense"], 1)
    var preview: Dictionary = engine.preview(_ids(cards))
    _assert_equal(preview["intent"]["inner_skill_defense"], 5, "玩家预览单独显示内功预计防御")
    _assert_equal(preview["intent"]["defense"], 5, "玩家总行动预览计入内功防御")

    engine.enemy.hand = cards.duplicate()
    engine.enemy_sequence_book.configure({"pair": [], "high_card": []})
    engine.enemy.configure_inner_skills(["extra_qi_to_defense"], 1)
    var enemy_preview: Dictionary = engine._preview_for_side(engine.enemy, _ids(cards), engine.enemy_sequence_book)
    var public_plan: Dictionary = engine._public_enemy_plan(enemy_preview["intent"])
    _assert_equal(public_plan["defense"], 5, "敌方行动计划计入已装备内功防御")
    _assert_true(not public_plan.has("inner_skills"), "敌方公开计划不泄露具体内功来源")

func _prepare_history_order(engine, cards: Array) -> Array[String]:
    engine.sequence_book.configure({"pair": ["double_gu_bind"]})
    engine.player.configure_inner_skills(["extra_qi_to_defense"], engine.player.technique_slot_index)
    engine.confirm_play(_ids(cards))
    var labels: Array[String] = []
    for entry in engine.trigger_queue.history:
        if entry["timing"] == "solo_prepare":
            labels.append(entry["label"])
    return labels

func _test_inner_skill_and_technique_left_to_right() -> void:
    var before_cards := [_card("6", "wind"), _card("6", "forest"), _card("2", "fire")]
    var technique_before = _engine_with_hand(before_cards)
    technique_before.player.technique_slot_index = 0
    var first_order := _prepare_history_order(technique_before, before_cards)
    _assert_equal(first_order, ["双蛊缠脉", "初始内功候选"], "功法位在左时先于内功结算")

    var after_cards := [_card("6", "wind"), _card("6", "forest"), _card("2", "fire")]
    var technique_after = _engine_with_hand(after_cards)
    technique_after.player.technique_slot_index = 1
    var second_order := _prepare_history_order(technique_after, after_cards)
    _assert_equal(second_order, ["初始内功候选", "双蛊缠脉"], "内功在左时先于功法结算")

func _test_consumable_shared_slots_and_generation_limit() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(77, false)
    engine.player.configure_consumables(["high_card_insight", "hierophant", "aura", "hierophant"])
    _assert_equal(engine.player.consumable_ids.size(), 3, "三类消耗品共用三格容量")
    _assert_equal(engine.player.consumable_ids, ["high_card_insight", "hierophant", "aura"], "共享槽保留三种代表消耗品")
    _assert_equal(engine.grant_consumable(engine.player, "hierophant", "测试"), false, "没有空位时不生成消耗品")
    var used := engine.use_player_consumable(0, [])
    _assert_true(used["success"], "无目标心得可以直接使用")
    _assert_equal(engine.player.consumable_ids.size(), 2, "使用后立即释放共享槽位")
    _assert_true(engine.grant_consumable(engine.player, "hierophant", "测试"), "释放槽位后可以生成消耗品")
    _assert_equal(engine.player.consumable_ids.size(), 3, "重新生成后占满三格")

func _test_insight_growth_and_technique_acquisition() -> void:
    var high = _card("9", "wind")
    var pair := [_card("7", "forest"), _card("7", "fire")]
    var engine = _engine_with_hand([high] + pair, [], 810)
    engine.player.configure_consumables(["high_card_insight"])
    _assert_true(not engine.player.owned_technique_ids.has("fire_sparks"), "初始玩家功法库不含敌方代表功法")
    var sequence_before: Array = engine.sequence_book.sequences["high_card"].duplicate()
    var result := engine.use_player_consumable(0, [])
    _assert_true(result["success"], "高牌心得使用成功")
    _assert_equal(engine.player.insight_multipliers.get("high_card", 0), 1, "心得只增加指定精确牌型累计倍率")
    _assert_equal(engine.player.insight_multipliers.get("pair", 0), 0, "高牌心得不提高一对")
    _assert_equal(result["acquired_technique_id"], "fire_sparks", "心得从合格池获得尚未拥有的功法")
    _assert_true(engine.player.owned_technique_ids.has("fire_sparks"), "所得功法进入本局功法库")
    _assert_equal(engine.sequence_book.sequences["high_card"], sequence_before, "心得所得功法不自动修改当前序列")
    var high_preview := engine.preview([high.id])
    _assert_equal(high_preview["values"]["technique_multiplier"], 2, "高牌固定倍率与累计心得倍率相加")
    _assert_equal(high_preview["values"]["technique_value"], 18, "心得立即影响高牌功法值预览")
    var pair_preview := engine.preview(_ids(pair))
    _assert_equal(pair_preview["values"]["technique_multiplier"], 2, "其他精确牌型倍率保持不变")

func _test_hierophant_bonus_enhancement_and_preview() -> void:
    var pair := [_card("7", "wind"), _card("7", "forest")]
    pair[0].set_enhancement("multiplier")
    var third = _card("3", "fire")
    var engine = _engine_with_hand(pair + [third])
    engine.player.configure_consumables(["hierophant"])
    var no_target := engine.use_player_consumable(0, [])
    _assert_equal(no_target["success"], false, "教皇至少需要一张目标真气")
    var too_many := engine.use_player_consumable(0, _ids(pair + [third]))
    _assert_equal(too_many["success"], false, "教皇不能选择超过两张真气")
    var result := engine.use_player_consumable(0, _ids(pair))
    _assert_true(result["success"], "教皇可以强化至多两张真气")
    _assert_equal(pair[0].enhancement, "bonus", "新强化替换同一张真气的旧强化")
    _assert_equal(pair[1].enhancement, "bonus", "第二张目标获得奖励牌强化")
    var preview := engine.preview(_ids(pair))
    _assert_equal(preview["values"]["base_value"], 18, "两张奖励七的有效真气值各加二")
    _assert_equal(preview["values"]["baseline_value"], 36, "奖励牌同时进入牌型基准值")
    _assert_equal(preview["values"]["technique_value"], 36, "奖励牌立即进入功法值预览")

func _test_aura_seeded_edition_and_preview() -> void:
    var first_card = _card("8", "mountain")
    var second_card = _card("8", "mountain")
    first_card.set_edition("foil")
    second_card.set_edition("foil")
    var first = _engine_with_hand([first_card], [], 4404)
    var second = _engine_with_hand([second_card], [], 4404)
    first.player.configure_consumables(["aura"])
    second.player.configure_consumables(["aura"])
    var first_result := first.use_player_consumable(0, [first_card.id])
    var second_result := second.use_player_consumable(0, [second_card.id])
    _assert_true(first_result["success"] and second_result["success"], "光环选择一张真气使用成功")
    _assert_true(first_card.edition in ["foil", "holographic", "polychrome"], "光环只产生三种合格版本")
    _assert_equal(first_card.edition, second_card.edition, "相同固定种子产生相同光环版本")
    _assert_true(first_card.edition != "", "新版本替换旧版本且不会清空")
    var preview := first.preview([first_card.id])
    match first_card.edition:
        "foil":
            _assert_equal(preview["values"]["base_value"], 11, "箔面使自身贡献加三")
            _assert_equal(preview["values"]["technique_value"], 11, "箔面贡献进入功法值")
        "holographic":
            _assert_equal(preview["values"]["technique_multiplier"], 2, "镭射使功法倍率加一")
            _assert_equal(preview["values"]["technique_value"], 16, "镭射立即影响功法值")
        "polychrome":
            _assert_equal(preview["values"]["power_amp_percent"], 20, "多彩加入功法值增幅加法池")
            _assert_equal(preview["values"]["technique_value"], 9, "多彩增幅后功法值向下取整")
    var foil = _card("8", "wind")
    foil.set_edition("foil")
    var foil_values := PowerCalculatorScript.calculate(HandEvaluatorScript.evaluate([foil]))
    _assert_equal(foil_values["base_value"], 11, "箔面版本固定增加三点自身贡献")
    var holographic = _card("8", "wind")
    holographic.set_edition("holographic")
    var holographic_values := PowerCalculatorScript.calculate(HandEvaluatorScript.evaluate([holographic]))
    _assert_equal(holographic_values["technique_multiplier"], 2, "镭射版本使功法倍率加一")
    _assert_equal(holographic_values["technique_value"], 16, "镭射版本进入功法值计算")
    var polychrome = _card("8", "wind")
    polychrome.set_edition("polychrome")
    var polychrome_values := PowerCalculatorScript.calculate(HandEvaluatorScript.evaluate([polychrome]))
    _assert_equal(polychrome_values["power_amp_percent"], 20, "多彩版本提供百分之二十功法值增幅")
    _assert_equal(polychrome_values["technique_value"], 9, "多彩版本统一乘算并向下取整")

func _test_map_generation_is_deterministic_and_constrained() -> void:
    var generator = MapGeneratorScript.new()
    var first: Dictionary = generator.generate(2308, 1)
    var second: Dictionary = generator.generate(2308, 1)
    _assert_equal(first, second, "相同种子生成完全相同的地图与连线")
    _assert_equal(first["width"], 7, "地图横向宽度为七列")
    _assert_equal(first["route_rows"], 15, "Boss 前有十五行路线节点")
    var row_counts: Dictionary = {}
    for node in first["nodes"]:
        var row: int = int(node["row"])
        row_counts[row] = int(row_counts.get(row, 0)) + 1
        _assert_true(node["type"] != "shop", "地图不生成商店节点")
        if row == 0:
            _assert_equal(node["type"], "combat", "第一行固定普通战斗")
        elif row == 7:
            _assert_equal(node["type"], "treasure", "第八行固定宝箱特殊奖励")
        elif row == 14:
            _assert_equal(node["type"], "rest", "第十五行固定休息")
        elif row == 15:
            _assert_equal(node["type"], "boss", "第十六行固定单一 Boss")
        elif row < 5:
            _assert_true(node["type"] not in ["elite", "rest"], "前五行不随机生成精英或休息")
    _assert_equal(row_counts.get(0, 0), 6, "六条初始路径使用六个不同起点")
    _assert_equal(row_counts.get(15, 0), 1, "地图只有一个层末 Boss")
    _assert_equal(generator.rules["weights"]["event"], 27, "商店比例并入后事件权重为百分之二十七")
    for edge in first["edges"]:
        var from_type: String = _map_node_type(first, edge["from"])
        var to_type: String = _map_node_type(first, edge["to"])
        if from_type in ["elite", "rest"]:
            _assert_true(from_type != to_type, "精英与休息不沿路径直接同类相连")

func _test_map_routes_reach_boss_without_crossing() -> void:
    var graph: Dictionary = MapGeneratorScript.new().generate(98173, 2)
    var starts: Array = []
    for node in graph["nodes"]:
        if int(node["row"]) == 0:
            starts.append(node["id"])
    for start_id in starts:
        _assert_true(_map_can_reach(graph, start_id, graph["boss_id"]), "每个起点都存在到 Boss 的完整路径")
    for left_index in range(graph["edges"].size()):
        var left: Dictionary = graph["edges"][left_index]
        for right_index in range(left_index + 1, graph["edges"].size()):
            var right: Dictionary = graph["edges"][right_index]
            if int(left["from_row"]) != int(right["from_row"]):
                continue
            var crossing := (
                int(left["from_column"]) < int(right["from_column"])
                and int(left["to_column"]) > int(right["to_column"])) or (
                int(left["from_column"]) > int(right["from_column"])
                and int(left["to_column"]) < int(right["to_column"]))
            _assert_true(not crossing, "同一行相邻路线不交叉")

func _test_run_state_node_and_practice_gate() -> void:
    var state = RunStateScript.new()
    state.setup(2308)
    _assert_true(state.can_open_practice(), "初次进入地图等待选路时可以修习")
    _assert_equal(state.available_node_ids().size(), 6, "初始可以从六个路线起点选择")
    var first_node_id: String = state.available_node_ids()[0]
    var begin := state.begin_node(first_node_id)
    _assert_true(begin["success"], "可以进入当前可达节点")
    _assert_true(not state.can_open_practice(), "节点进行中锁定修习入口")
    _assert_equal(state.purchase_consumable("hierophant", 3)["success"], false, "节点未完成时不能购买修习内容")
    var completion := state.complete_current_node()
    _assert_true(completion["success"], "节点可以完成并返回地图")
    _assert_equal(completion["reward"], 3, "普通战斗节点奖励三点历练")
    _assert_equal(state.experience, 3, "节点奖励进入本局历练")
    _assert_true(state.can_open_practice(), "节点完成到选择下一节点前重新开放修习")
    _assert_true(not state.available_node_ids().is_empty(), "返回地图后只开放相连下一节点")
    var purchase := state.purchase_consumable("hierophant", 3)
    _assert_true(purchase["success"], "待选节点期间可以消耗历练修习")
    _assert_equal(state.experience, 0, "修习购买扣除对应历练")
    _assert_equal(state.consumable_ids, ["hierophant"], "修习所得进入共享消耗品栏")
    _assert_equal(state.purchase_consumable("hierophant", 3)["success"], false, "同一地图待选阶段固定选项不能重复购买")

func _test_run_state_battle_growth_persistence() -> void:
    var state = RunStateScript.new()
    state.setup(420)
    state.consumable_ids.append("aura")
    state.insight_multipliers = {"high_card": 2}
    state.deck_modifiers = {"wind_8": {"enhancement": "bonus", "edition": "foil"}}
    var engine = CombatEngineScript.new()
    engine.setup(420, false)
    state.apply_to_battle_side(engine.player)
    var modified = null
    for card in engine.player.draw_pile:
        if card.id == "wind_8":
            modified = card
            break
    _assert_true(modified != null, "本局牌组改造能应用到下一场战斗")
    _assert_equal(modified.enhancement, "bonus", "跨战斗保留真气强化")
    _assert_equal(modified.edition, "foil", "跨战斗保留真气版本")
    _assert_equal(engine.player.insight_multipliers.get("high_card", 0), 2, "跨战斗保留精确牌型心得倍率")
    _assert_equal(engine.player.consumable_ids, ["aura"], "跨战斗保留共享消耗品")
    modified.set_edition("polychrome")
    engine.player.consume_at(0)
    state.sync_from_battle_side(engine.player)
    _assert_equal(state.deck_modifiers["wind_8"]["edition"], "polychrome", "战斗中的版本替换同步回本局状态")
    _assert_equal(state.consumable_ids.size(), 0, "战斗中使用消耗品后同步释放本局槽位")

func _test_map_practice_and_battle_scene_integration() -> void:
    var run_ui = RunScene.instantiate()
    run_ui.initialize_interface()
    root.add_child(run_ui)
    _assert_true(run_ui.practice_button != null, "地图场景建立右下角修习按钮")
    _assert_true(not run_ui.practice_button.disabled, "初始待选节点状态修习按钮可用")
    run_ui._open_practice()
    _assert_true(run_ui.practice_overlay.visible, "点击修习按钮打开卡片式修习页面")
    run_ui._close_practice()
    var first_node_id: String = run_ui.run_state.available_node_ids()[0]
    run_ui._on_node_selected(first_node_id)
    _assert_equal(run_ui.run_state.phase, "node_in_progress", "地图选择战斗节点后进入未完成状态")
    _assert_true(run_ui.battle_layer.visible and run_ui.current_battle != null, "战斗节点接入现有战斗场景")
    _assert_true(run_ui.practice_button.disabled, "战斗节点进行中修习按钮锁定")
    run_ui._on_battle_finished("player_victory")
    _assert_equal(run_ui.run_state.phase, "awaiting_node", "战斗胜利后直接返回地图待选状态")
    _assert_equal(run_ui.run_state.experience, 3, "战斗胜利奖励显示为当前历练")
    _assert_true(not run_ui.battle_layer.visible, "战斗胜利后关闭战斗层而不自动打开修习")
    _assert_true(not run_ui.practice_overlay.visible, "战斗胜利不会强制弹出修习页面")
    run_ui.queue_free()

func _map_node_type(graph: Dictionary, node_id: String) -> String:
    for node in graph["nodes"]:
        if node["id"] == node_id:
            return str(node["type"])
    return ""

func _map_can_reach(graph: Dictionary, start_id: String, target_id: String) -> bool:
    var pending: Array = [start_id]
    var visited: Dictionary = {}
    while not pending.is_empty():
        var current: String = pending.pop_front()
        if current == target_id:
            return true
        if visited.has(current):
            continue
        visited[current] = true
        for edge in graph["edges"]:
            if edge["from"] == current:
                pending.append(str(edge["to"]))
    return false

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
