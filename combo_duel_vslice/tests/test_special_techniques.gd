extends "res://tests/support/expanded_technique_test_base.gd"

const TechniquePhaseCatalogScript = preload(
    "res://core/effects/technique_phase_catalog.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const BattleActionProposalScript = preload(
    "res://core/battle_action_proposal.gd")

const SPECIAL_TECHNIQUES := {
    "bomb_wind_empty_hand": {"name":"风·断流无手", "pool":"bomb"},
    "pair_forest_dissipate_decay": {"name":"林·弃腐续生", "pool":"pair"},
    "bomb_fire_break_city": {"name":"火·破城焚关", "pool":"bomb"},
    "high_mountain_shed_wall": {"name":"山·舍壁还生", "pool":"high"},
    "pair_wind_returning_tide": {"name":"风·归潮蓄锋", "pool":"pair"},
    "high_forest_shared_fate_poison": {"name":"林·同命淬蛊", "pool":"high"},
    "straight_fire_return_same_qi": {"name":"火·回轮换势", "pool":"straight"},
    "straight_mountain_hidden_edge": {"name":"山·裂壁藏锋", "pool":"straight"},
    "three_wind_falling_sign": {"name":"风·落签逐影", "pool":"three"},
    "pair_forest_borrow_momentum_poison": {"name":"林·借势催蛊", "pool":"pair"},
    "pair_fire_melt_armor_momentum": {"name":"火·熔甲成势", "pool":"pair"},
    "pair_mountain_broken_armor_qi": {"name":"山·折甲行气", "pool":"pair"},
    "high_wind_three_breath_return": {"name":"风·三息回风", "pool":"high"},
    "high_forest_poison_meridian_echo": {"name":"林·蛊脉自鸣", "pool":"high"},
    "pair_mountain_three_knocks": {"name":"山·听阵三叩", "pool":"pair"},
}

func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_formal_resource_contract()
    _test_empty_hand_live_damage_branch()
    _test_dissipate_decay_choice_and_recovery()
    _test_break_city_unblockable_absorption_and_reflection()
    _test_shed_wall_marker_and_battle_reset()
    _test_returning_tide_choices_replacements_and_next_power()
    _test_shared_fate_poison_markers_and_active_slots()
    _test_return_same_qi_after_conversion()
    _test_hidden_edge_full_payment_block_and_next_power()
    _test_falling_sign_draw_progress_targets_and_expiry()
    _test_borrow_momentum_poison_choice_snapshot_and_duration()
    _test_melt_armor_momentum_sources_rounding_and_expiry()
    _test_broken_armor_qi_progress_sources_and_cleanup()
    _test_three_breath_return_battle_session_flow()
    _test_poison_meridian_echo_battle_session_flow()
    _test_three_knocks_battle_session_flow()
    _finish("SPECIAL TECHNIQUE TEST")

func _test_formal_resource_contract() -> void:
    var repository = _repository()
    var manifest = JSON.parse_string(FileAccess.get_file_as_string(
        "res://data/techniques.json"))
    for technique_id in SPECIAL_TECHNIQUES:
        var expected: Dictionary = SPECIAL_TECHNIQUES[technique_id]
        var definition = repository.get_definition(technique_id)
        _assert_true(definition != null, "%s独立资源存在" % technique_id)
        if definition == null:
            continue
        _assert_equal(definition.display_name, expected["name"], "%s冻结名称" % technique_id)
        _assert_equal(definition.pool, expected["pool"], "%s正式池资格" % technique_id)
        _assert_true(definition.special, "%s标记为特殊功法" % technique_id)
        _assert_true(not definition.built_in, "%s不是内建功法" % technique_id)
        _assert_equal(definition.base_loadout_limit, 1, "%s普通装配上限为1" % technique_id)
        _assert_equal(
            manifest.get("integration_statuses", {}).get(technique_id, ""),
            "formal_complete", "%s状态为formal_complete" % technique_id)
        _assert_true(
            manifest.get("resource_paths", []).has(
                "res://data/techniques/%s.tres" % technique_id),
            "%s资源路径已登记" % technique_id)
    for path in [
            "res://data/production_sequences.json",
            "res://data/enemies.json",
            "res://data/production_enemy_entry.json"]:
        var text := FileAccess.get_file_as_string(path)
        for technique_id in SPECIAL_TECHNIQUES:
            _assert_true(
                not text.contains(str(technique_id)),
                "%s未写入%s" % [technique_id, path])

func _test_empty_hand_live_damage_branch() -> void:
    var occupied = _engine(8101)
    occupied.enemy.defense = 10
    occupied.enemy.hand = [_card("4", "forest")]
    occupied.player.draw_pile = [_card("2", "wind"), _card("3", "wind")]
    var occupied_context = _context_for(occupied, "bomb_wind_empty_hand", 20)
    var occupied_definition = occupied.repository.get_definition(
        "bomb_wind_empty_hand")
    var damage_phase := TechniquePhaseCatalogScript.effects_for_phase(
        occupied_definition.effects, "damage", occupied.effect_executor.registry)
    var zones_phase := TechniquePhaseCatalogScript.effects_for_phase(
        occupied_definition.effects, "zones", occupied.effect_executor.registry)
    _assert_true(damage_phase.get("success", false), "断流无手伤害阶段可解析")
    _assert_true(zones_phase.get("success", false), "断流无手牌区阶段可解析")
    var result: Dictionary = occupied.effect_executor.execute_all(
        damage_phase.get("effects", []), occupied_context)
    _assert_true(result.get("success", false), "敌方有手牌分支成功")
    result = occupied.effect_executor.execute_all(
        zones_phase.get("effects", []), occupied_context)
    _assert_true(result.get("success", false), "敌方有手牌牌区阶段成功")
    _assert_equal(occupied.enemy.defense, 0, "有手牌时P点普通伤害先吸收防御")
    _assert_equal(occupied.enemy.life, 90, "有手牌时普通伤害仅损失剩余生命")
    _assert_equal(occupied.player.hand.size(), 0, "有手牌时不抽牌")

    var empty = _engine(8102)
    empty.enemy.defense = 10
    var frozen_presence = _card("5", "forest")
    empty.enemy.hand = [frozen_presence]
    empty.player.draw_pile = [_card("2", "wind"), _card("3", "wind")]
    var empty_context = _context_for(empty, "bomb_wind_empty_hand", 20)
    empty.enemy.hand.erase(frozen_presence)
    empty.enemy.discard_pile.append(frozen_presence)
    result = empty.effect_executor.execute_all(
        damage_phase.get("effects", []), empty_context)
    _assert_true(result.get("success", false), "确认后清空敌方手牌仍成功结算")
    result = empty.effect_executor.execute_all(
        zones_phase.get("effects", []), empty_context)
    _assert_true(result.get("success", false), "空手分支牌区阶段成功")
    _assert_equal(empty.enemy.defense, 10, "空手时P点真伤不消耗防御")
    _assert_equal(empty.enemy.life, 80, "空手时造成P点真伤")
    _assert_equal(empty.player.hand.size(), 2, "空手时抽2张牌")

func _test_dissipate_decay_choice_and_recovery() -> void:
    var anomaly_cases := [
        {"category":"state", "id":"poison", "label":"毒"},
        {"category":"debuff", "id":"decay", "label":"衰败"},
        {"category":"mark", "id":"burned_out", "label":"燃尽"},
    ]
    for index in range(anomaly_cases.size()):
        var anomaly: Dictionary = anomaly_cases[index]
        var engine = _engine(8200 + index)
        var card = _card("Q", "forest")
        engine.player.hand = [card]
        engine.player.life = 50
        engine.status_system.apply_card_anomaly(
            card, anomaly["category"], anomaly["id"], {}, "测试")
        var definition = engine.repository.get_definition(
            "pair_forest_dissipate_decay")
        var context = _context_for(
            engine, "pair_forest_dissipate_decay", 20)
        var pending: Dictionary = engine.effect_executor.execute_all(
            definition.effects, context)
        _assert_true(pending.get("pending_choice", false), "%s目标进入可放弃选择" % anomaly["label"])
        _assert_equal(
            pending.get("choice_request", {}).get("candidate_ids", []),
            [str(card.id)], "%s目标由任一异状查询选中" % anomaly["label"])
        var resumed: Dictionary = engine.effect_executor.resume(
            pending.get("_continuation"),
            str(pending.get("choice_request", {}).get("request_id", "")),
            [str(card.id)])
        _assert_true(resumed.get("success", false), "%s目标选择后成功结算" % anomaly["label"])
        _assert_equal(engine.player.defense, 10, "%s分支先获得floor(P/2)防御" % anomaly["label"])
        _assert_true(not engine.player.hand.has(card), "%s目标离开手牌" % anomaly["label"])
        _assert_true(engine.player.temporarily_removed_cards.has(card), "%s目标进入战斗消散区" % anomaly["label"])
        _assert_true(not engine.player.discard_pile.has(card), "%s目标不进入弃牌堆" % anomaly["label"])
        _assert_equal(engine.player.life, 61, "%s目标按基础真气值11恢复生命" % anomaly["label"])

    var skipped = _engine(8204)
    var skipped_card = _card("7", "forest")
    skipped.player.hand = [skipped_card]
    skipped.player.life = 60
    skipped.status_system.apply_card_anomaly(
        skipped_card, "state", "poison", {}, "测试")
    var skipped_definition = skipped.repository.get_definition(
        "pair_forest_dissipate_decay")
    var skipped_context = _context_for(
        skipped, "pair_forest_dissipate_decay", 20)
    var skipped_pending: Dictionary = skipped.effect_executor.execute_all(
        skipped_definition.effects, skipped_context)
    var skipped_result: Dictionary = skipped.effect_executor.resume(
        skipped_pending.get("_continuation"),
        str(skipped_pending.get("choice_request", {}).get("request_id", "")),
        [])
    _assert_true(skipped_result.get("success", false), "弃腐续生允许放弃选择")
    _assert_true(skipped.player.hand.has(skipped_card), "放弃选择时手牌不消散")
    _assert_equal(skipped.player.life, 60, "放弃选择时不恢复生命")

func _test_break_city_unblockable_absorption_and_reflection() -> void:
    var engine = _engine(8301)
    engine.enemy.defense = 10
    engine.enemy.add_reflection_source(100, "break-city-reflection", 1)
    engine.effect_ports.begin_action_resolution(
        [engine.player, engine.enemy],
        {"acting_owner_ids":[str(engine.player.owner_id)]})
    engine.effect_ports.grant_block_source(
        engine.enemy, engine.player, "unconditional", "破城格挡探针")
    var result := _execute(engine, "bomb_fire_break_city", 20)
    _assert_true(result.get("success", false), "破城焚关效果链成功")
    _assert_equal(engine.enemy.defense, 0, "P+F普通伤害仍经过防御吸收")
    _assert_equal(engine.enemy.life, 80, "记录F=10后造成30点普通伤害")
    _assert_equal(engine.enemy.block_sources.size(), 1, "不可格挡只跳过格挡且不消费来源")
    _assert_equal(engine.player.life, 90, "实际消耗10防御后仍按反震结算")
    engine.effect_ports.abort_action_resolution()

func _test_shed_wall_marker_and_battle_reset() -> void:
    var engine = _engine(8401)
    engine.sequence_book.configure({"high_card":["high_mountain_shed_wall"]})
    var slot: Dictionary = engine.sequence_book.current_slot("high_card")
    var slot_id := str(slot.get("slot_instance_id", ""))
    engine.player.life = 50
    engine.player.defense = 12
    engine.player.add_reflection_source(100, "shed-wall-reflection", 1)
    var enemy_life_before := int(engine.enemy.life)
    var first: Dictionary = engine.effect_executor.execute_all(
        engine.repository.get_definition("high_mountain_shed_wall").effects,
        _context_for(engine, "high_mountain_shed_wall", 20, slot_id))
    _assert_true(first.get("success", false), "舍壁还生首次结算成功")
    _assert_equal(engine.player.life, 54, "首次按F/3恢复4点生命")
    _assert_equal(engine.player.defense, 20, "清空后获得P点防御")
    _assert_equal(engine.enemy.life, enemy_life_before, "主动清空防御不触发反震")
    _assert_equal(_marker_value(engine, slot_id), 4, "首次完成后X从3递增到4")

    var second: Dictionary = engine.effect_executor.execute_all(
        engine.repository.get_definition("high_mountain_shed_wall").effects,
        _context_for(engine, "high_mountain_shed_wall", 20, slot_id))
    _assert_true(second.get("success", false), "舍壁还生第二次结算成功")
    _assert_equal(engine.player.life, 59, "第二次按F/4恢复5点生命")
    _assert_equal(_marker_value(engine, slot_id), 5, "第二次完成后X递增到5")

    engine.player.defense = 0
    var life_before_zero := int(engine.player.life)
    var zero: Dictionary = engine.effect_executor.execute_all(
        engine.repository.get_definition("high_mountain_shed_wall").effects,
        _context_for(engine, "high_mountain_shed_wall", 20, slot_id))
    _assert_true(zero.get("success", false), "F=0时仍成功结算")
    _assert_equal(engine.player.life, life_before_zero, "F=0时不恢复生命")
    _assert_equal(_marker_value(engine, slot_id), 6, "F=0时X仍递增")

    var ended: Dictionary = engine.timing_system.emit_timing(
        "battle_end", {"actors":[engine.player, engine.enemy]})
    _assert_true(ended.get("success", false), "战斗结束公共时点成功")
    _assert_equal(_marker_value(engine, slot_id), 0, "战斗结束清除战斗范围X")
    engine.player.defense = 0
    var restarted: Dictionary = engine.effect_executor.execute_all(
        engine.repository.get_definition("high_mountain_shed_wall").effects,
        _context_for(engine, "high_mountain_shed_wall", 20, slot_id))
    _assert_true(restarted.get("success", false), "清理后再次结算成功")
    _assert_equal(_marker_value(engine, slot_id), 4, "新战斗首次结算重新从X=3开始")

func _test_returning_tide_choices_replacements_and_next_power() -> void:
    var skipped = _engine(8501)
    skipped.sequence_book.configure({"pair":["pair_wind_returning_tide"]})
    var skipped_card = _card("3", "wind")
    skipped.player.hand = [skipped_card]
    var skipped_context = _context_for(
        skipped, "pair_wind_returning_tide", 20,
        str(skipped.sequence_book.current_slot("pair").get("slot_instance_id", "")))
    var skipped_pending: Dictionary = skipped.effect_executor.execute_all(
        skipped.repository.get_definition("pair_wind_returning_tide").effects,
        skipped_context)
    _assert_true(skipped_pending.get("pending_choice", false), "归潮蓄锋选择0张进入可放弃选择")
    var skipped_result := _resume_effect_choice(skipped, skipped_pending, [])
    _assert_true(skipped_result.get("success", false), "归潮蓄锋选择0张成功结算")
    _assert_true(skipped.player.hand.has(skipped_card), "选择0张不改变手牌")
    _assert_equal(skipped.player.pending_power_fixed_sources.size(), 0, "选择0张不建立空修正来源")

    var single = _engine(8502)
    single.sequence_book.configure({"pair":["pair_wind_returning_tide"]})
    var washed = _card("3", "wind")
    single.status_system.apply_card_anomaly(
        washed, "buff", "growth", {"layers":2}, "冻结有效值测试")
    single.player.hand = [washed]
    var same_rank = _card("3", "forest")
    var other_rank = _card("4", "fire")
    single.player.draw_pile = [same_rank, other_rank]
    var frozen_v := int(single.effect_ports.current_effective_qi(single.player, washed))
    var single_context = _context_for(
        single, "pair_wind_returning_tide", 20,
        str(single.sequence_book.current_slot("pair").get("slot_instance_id", "")))
    var single_pending: Dictionary = single.effect_executor.execute_all(
        single.repository.get_definition("pair_wind_returning_tide").effects,
        single_context)
    var single_result := _resume_effect_choice(
        single, single_pending, [str(washed.id)])
    _assert_true(single_result.get("success", false), "归潮蓄锋选择1张成功结算")
    _assert_true(single.player.hand.has(other_rank), "单张替换避开对应冻结牌阶")
    _assert_true(not single.player.hand.has(same_rank), "同阶牌不会成为该张的替换牌")
    _assert_equal(single.player.pending_power_fixed_total(), frozen_v, "V读取洗回时冻结有效真气值")

    var paired = _engine(8503)
    paired.sequence_book.configure({
        "pair":["pair_wind_returning_tide"],
        "high_card":["basic_scatter"],
    })
    var washed_three = _card("3", "wind")
    var washed_five = _card("5", "forest")
    paired.player.hand = [washed_three, washed_five]
    var expected_v := int(paired.effect_ports.current_effective_qi(
        paired.player, washed_three)) + int(paired.effect_ports.current_effective_qi(
        paired.player, washed_five))
    var tide_slot := str(paired.sequence_book.current_slot("pair").get(
        "slot_instance_id", ""))
    var paired_context = _context_for(
        paired, "pair_wind_returning_tide", 20, tide_slot)
    var paired_pending: Dictionary = paired.effect_executor.execute_all(
        paired.repository.get_definition("pair_wind_returning_tide").effects,
        paired_context)
    var paired_result := _resume_effect_choice(
        paired, paired_pending, [str(washed_three.id), str(washed_five.id)])
    _assert_true(paired_result.get("success", false), "归潮蓄锋选择2张成功结算")
    _assert_equal(paired.player.hand.size(), 2, "两张分别完成替换抽牌")
    _assert_true(paired.player.hand.has(washed_three) and paired.player.hand.has(washed_five),
        "逐张限制允许两张互为不同牌阶的替换牌")
    _assert_equal(paired.player.pending_power_fixed_total(), expected_v, "两张冻结V求和正确")

    var deny_id: String = paired.battle_permission_service.register_provider(
        func(hook: String, _values: Dictionary) -> Dictionary:
            return {"allowed": hook != "technique_activation_permission_query",
                "reason":"专项拒绝"},
        "special-next-power-deny", 999,
        ["technique_activation_permission_query"])
    var denied: Dictionary = paired.technique_invocation_service.invoke({
        "selection":{"mode":"by_id","hand_id":"high_card","technique_id":"basic_scatter"},
        "p0":{"mode":"fixed","value":10},
    }, paired_context)
    _assert_true(not denied.get("triggered", true), "失败功法不触发")
    _assert_equal(paired.player.pending_power_fixed_total(), expected_v, "失败功法不消费下一功法修正")
    paired.battle_permission_service.unregister_provider(deny_id)
    paired_context.action_token = "returning-tide-next-success"
    paired_context.root_action_token = paired_context.action_token
    var life_before := int(paired.enemy.life)
    var invoked: Dictionary = paired.technique_invocation_service.invoke({
        "selection":{"mode":"by_id","hand_id":"high_card","technique_id":"basic_scatter"},
        "p0":{"mode":"fixed","value":10},
    }, paired_context)
    _assert_true(invoked.get("success", false), "调用功法可消费归潮修正")
    _assert_equal(int(invoked.get("power_values", {}).get("technique_value", 0)),
        10 + expected_v, "下一门调用功法获得V点直接修正")
    _assert_equal(paired.player.pending_power_fixed_sources.size(), 0, "成功后修正只消费一次")
    _assert_equal(paired.enemy.life, life_before - int(floor((10 + expected_v) / 4.0)),
        "被调用散招按修正后的P造成伤害")

func _test_shared_fate_poison_markers_and_active_slots() -> void:
    var engine = _engine(8601)
    engine.sequence_book.configure({"high_card":["high_forest_shared_fate_poison"]})
    var slot_id := str(engine.sequence_book.current_slot("high_card").get(
        "slot_instance_id", ""))
    for _index in range(3):
        var result: Dictionary = engine.effect_executor.execute_all(
            engine.repository.get_definition("high_forest_shared_fate_poison").effects,
            _context_for(engine, "high_forest_shared_fate_poison", 20, slot_id))
        _assert_true(result.get("success", false), "同命淬蛊成功触发并增长来源层数")
    _assert_equal(engine.player.source_marker_store.value(
        "technique", slot_id, "quench_poison", "battle"), 3,
        "每次触发淬蛊+1并保存在功法槽")
    engine.player.defense = 0
    var enemy_poison: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 5, "poison-probe", false,
        "shared-fate-enemy", "poison")
    var actor_poison: Dictionary = engine.effect_ports.deal_damage(
        engine.enemy, engine.player, 5, "poison-probe", false,
        "shared-fate-actor", "poison")
    _assert_equal(enemy_poison.get("final_amount", 0), 8, "敌方毒伤段获得固定+3")
    _assert_equal(actor_poison.get("final_amount", 0), 8, "我方毒伤段同样获得固定+3")
    engine.sequence_book.configure({"high_card":["basic_scatter"]})
    var after_unload: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 5, "poison-probe", false,
        "shared-fate-unloaded", "poison")
    _assert_equal(after_unload.get("final_amount", 0), 5, "卸下功法后来源层数不再生效")

    var copies = _engine(8602)
    copies.sequence_book.configure({"high_card":["high_forest_shared_fate_poison"]})
    var temporary: Array = copies.sequence_book.insert_temporary_slots(
        "pair", "high_forest_shared_fate_poison", 2)
    var first_id := str(temporary[0].get("slot_instance_id", ""))
    var second_id := str(temporary[1].get("slot_instance_id", ""))
    copies.effect_executor.execute_all(
        copies.repository.get_definition("high_forest_shared_fate_poison").effects,
        _context_for(copies, "high_forest_shared_fate_poison", 20, first_id))
    for _index in range(2):
        copies.effect_executor.execute_all(
            copies.repository.get_definition("high_forest_shared_fate_poison").effects,
            _context_for(copies, "high_forest_shared_fate_poison", 20, second_id))
    _assert_equal(copies.player.source_marker_store.value(
        "technique", first_id, "quench_poison", "battle"), 1,
        "第一份临时副本拥有独立淬蛊层数")
    _assert_equal(copies.player.source_marker_store.value(
        "technique", second_id, "quench_poison", "battle"), 2,
        "第二份临时副本层数不与第一份合并")

func _test_return_same_qi_after_conversion() -> void:
    var abandoned = _engine(8701)
    var abandoned_context = _context_for(
        abandoned, "straight_fire_return_same_qi", 20)
    var abandoned_pending: Dictionary = abandoned.effect_executor.execute_all(
        abandoned.repository.get_definition("straight_fire_return_same_qi").effects,
        abandoned_context)
    _assert_true(abandoned_pending.get("pending_choice", false), "回轮换势允许玩家决定是否转换")
    var abandoned_result := _resume_effect_choice(abandoned, abandoned_pending, [])
    _assert_true(abandoned_result.get("success", false), "回轮换势放弃转换成功")
    abandoned.player.same_qi_value = 3
    abandoned.effect_ports.gain_same_qi(
        abandoned.player, 0, "同气槽", abandoned_context.action_token + ":same_qi")
    _assert_equal(abandoned.player.same_qi_value, 3, "放弃转换保留余数Q")
    _assert_equal(abandoned.player.momentum_value, 0, "放弃转换不获得连势")

    var zero = _engine(8702)
    zero.player.hand = [_card("2", "fire")]
    zero.player.same_qi_value = 4
    var zero_context = _context_for(zero, "straight_fire_return_same_qi", 20)
    var zero_pending: Dictionary = zero.effect_executor.execute_all(
        zero.repository.get_definition("straight_fire_return_same_qi").effects,
        zero_context)
    _resume_effect_choice(zero, zero_pending, ["convert"])
    var zero_gain: Dictionary = zero.effect_ports.gain_same_qi(
        zero.player, 1, "同气槽", zero_context.action_token + ":same_qi")
    _assert_equal(zero_gain.get("granted_actions", 0), 1, "同气先完成阈值与额外行动结算")
    _assert_equal(zero.player.same_qi_value, 0, "Q=0转换路径保持同气为0")
    _assert_equal(zero.player.momentum_value, 0, "Q=0不产生连势")

    var converted = _engine(8703)
    converted.player.hand = [_card("2", "fire")]
    converted.player.same_qi_value = 4
    var converted_context = _context_for(
        converted, "straight_fire_return_same_qi", 20)
    var converted_pending: Dictionary = converted.effect_executor.execute_all(
        converted.repository.get_definition("straight_fire_return_same_qi").effects,
        converted_context)
    var converted_result := _resume_effect_choice(
        converted, converted_pending, ["convert"])
    _assert_true(converted_result.get("success", false), "回轮换势选择转换成功建立响应")
    var gain: Dictionary = converted.effect_ports.gain_same_qi(
        converted.player, 3, "同气槽", converted_context.action_token + ":same_qi")
    _assert_equal(gain.get("same_qi_after", -1), 2, "阈值结算后余数Q=2")
    _assert_equal(gain.get("granted_actions", 0), 1, "已转化同气先生成一次额外行动")
    _assert_equal(converted.player.same_qi_value, 0, "响应只清空阈值后的余数Q")
    _assert_equal(converted.player.momentum_value, 8, "清空Q=2后获得4Q连势")

func _test_hidden_edge_full_payment_block_and_next_power() -> void:
    var abandoned = _engine(8801)
    abandoned.player.defense = 5
    var abandoned_context = _context_for(
        abandoned, "straight_mountain_hidden_edge", 20, "", 12)
    var abandoned_pending: Dictionary = abandoned.effect_executor.execute_all(
        abandoned.repository.get_definition("straight_mountain_hidden_edge").effects,
        abandoned_context)
    _resume_effect_choice(abandoned, abandoned_pending, [])
    _assert_equal(abandoned.player.defense, 25, "裂壁藏锋放弃支付时只获得P防御")
    _assert_equal(abandoned.player.block_sources.size(), 0, "放弃支付不获得格挡")
    _assert_equal(abandoned.player.pending_power_fixed_sources.size(), 0, "放弃支付不建立下一功法修正")

    var insufficient = _engine(8802)
    var insufficient_context = _context_for(
        insufficient, "straight_mountain_hidden_edge", 10, "", 12)
    var insufficient_pending: Dictionary = insufficient.effect_executor.execute_all(
        insufficient.repository.get_definition("straight_mountain_hidden_edge").effects,
        insufficient_context)
    _resume_effect_choice(insufficient, insufficient_pending, ["pay"])
    _assert_equal(insufficient.player.defense, 10, "不足C时防御不得部分支付")
    _assert_equal(insufficient.player.block_sources.size(), 0, "不足C不获得格挡")
    _assert_equal(insufficient.player.pending_power_fixed_sources.size(), 0, "不足C不建立修正")

    var paid = _engine(8803)
    paid.sequence_book.configure({"high_card":["basic_scatter"]})
    paid.player.defense = 5
    paid.player.add_reflection_source(100, "hidden-edge-reflection", 1)
    var enemy_life_before := int(paid.enemy.life)
    var paid_context = _context_for(
        paid, "straight_mountain_hidden_edge", 20, "", 12)
    var paid_pending: Dictionary = paid.effect_executor.execute_all(
        paid.repository.get_definition("straight_mountain_hidden_edge").effects,
        paid_context)
    var paid_result := _resume_effect_choice(paid, paid_pending, ["pay"])
    _assert_true(paid_result.get("success", false), "裂壁藏锋足额支付成功")
    _assert_equal(paid.player.defense, 13, "获得P后足额支付C点防御")
    _assert_equal(paid.player.block_sources.size(), 1, "足额支付后获得一次无条件格挡")
    _assert_equal(paid.player.pending_power_fixed_total(), 6, "足额支付后建立floor(C/2)修正")
    _assert_equal(paid.enemy.life, enemy_life_before, "主动防御支付不触发反震")
    paid_context.action_token = "hidden-edge-next-success"
    paid_context.root_action_token = paid_context.action_token
    var invoked: Dictionary = paid.technique_invocation_service.invoke({
        "selection":{"mode":"by_id","hand_id":"high_card","technique_id":"basic_scatter"},
        "p0":{"mode":"fixed","value":10},
    }, paid_context)
    _assert_true(invoked.get("success", false), "下一门调用功法成功消费藏锋修正")
    _assert_equal(int(invoked.get("power_values", {}).get("technique_value", 0)), 16,
        "下一门成功功法获得floor(C/2)直接修正")
    _assert_equal(paid.player.pending_power_fixed_sources.size(), 0, "藏锋修正成功后只消费一次")

func _test_falling_sign_draw_progress_targets_and_expiry() -> void:
    var targeted = _engine(8901)
    targeted.sequence_book.configure({"three_kind":["three_wind_falling_sign"]})
    var slot_id := str(targeted.sequence_book.current_slot("three_kind").get(
        "slot_instance_id", ""))
    var target_card = _card("7", "forest")
    targeted.enemy.hand = [target_card]
    targeted.player.draw_pile = [
        _card("2", "wind"), _card("3", "forest"), _card("4", "fire")]
    var context = _context_for(
        targeted, "three_wind_falling_sign", 20, slot_id)
    var established: Dictionary = targeted.effect_executor.execute_all(
        targeted.repository.get_definition("three_wind_falling_sign").effects,
        context)
    _assert_true(established.get("success", false), "落签逐影建立本完整回合抽牌响应")
    targeted.player.draw(1, "normal_draw")
    _assert_equal(_slot_marker_value(targeted, slot_id, "draw_count"), 0,
        "正常补牌不推进落签逐影记录")
    targeted.player.draw(1, "item")
    _assert_equal(_slot_marker_value(targeted, slot_id, "draw_count"), 1,
        "其他来源实际抽牌推进1次记录")
    targeted.effect_ports.draw(targeted.player, 1, "technique")
    _assert_equal(_slot_marker_value(targeted, slot_id, "draw_count"), 0,
        "累计2张后消耗2次落签记录")
    _assert_true(target_card.has_anomaly("state", "vulnerability"),
        "有合法目标时随机手牌获得破绽")

    var fallback = _engine(8902)
    fallback.sequence_book.configure({"three_kind":["three_wind_falling_sign"]})
    var fallback_slot := str(fallback.sequence_book.current_slot("three_kind").get(
        "slot_instance_id", ""))
    fallback.player.draw_pile = [
        _card("2", "wind"), _card("3", "wind"),
        _card("4", "wind"), _card("5", "wind")]
    fallback.effect_executor.execute_all(
        fallback.repository.get_definition("three_wind_falling_sign").effects,
        _context_for(fallback, "three_wind_falling_sign", 20, fallback_slot))
    var life_after_initial := int(fallback.enemy.life)
    fallback.effect_ports.draw(fallback.player, 4, "technique")
    _assert_equal(fallback.enemy.life, life_after_initial - 8,
        "单次实际抽4张无目标时触发两次floor(P/5)真伤")
    _assert_equal(_slot_marker_value(fallback, fallback_slot, "draw_count"), 0,
        "单次抽4张分别消费两组记录且不留溢出")

    fallback.player.draw_pile = [_card("6", "wind"), _card("7", "wind")]
    fallback.effect_ports.draw(fallback.player, 1, "item")
    _assert_equal(_slot_marker_value(fallback, fallback_slot, "draw_count"), 1,
        "回合结束前未满阈值记录保留在具体槽位")
    fallback.timing_system.emit_timing("turn_end", {
        "round_number":1, "actor":fallback.player,
        "actors":[fallback.player, fallback.enemy]})
    _assert_equal(_slot_marker_value(fallback, fallback_slot, "draw_count"), 0,
        "完整回合结束清除未满阈值抽牌记录")
    var life_after_expiry := int(fallback.enemy.life)
    fallback.effect_ports.draw(fallback.player, 1, "technique")
    _assert_equal(fallback.enemy.life, life_after_expiry,
        "完整回合结束后落签逐影响应彻底失效")

func _test_borrow_momentum_poison_choice_snapshot_and_duration() -> void:
    var abandoned = _engine(9001)
    abandoned.player.momentum_value = 7
    var abandoned_context = _context_for(
        abandoned, "pair_forest_borrow_momentum_poison", 27)
    abandoned_context.momentum_used = 7
    var pending: Dictionary = abandoned.effect_executor.execute_all(
        abandoned.repository.get_definition(
            "pair_forest_borrow_momentum_poison").effects,
        abandoned_context)
    _assert_true(pending.get("pending_choice", false), "借势催蛊允许选择是否清空连势")
    var abandoned_result := _resume_effect_choice(abandoned, pending, [])
    _assert_true(abandoned_result.get("success", false), "借势催蛊可以放弃清空连势")
    _assert_equal(abandoned.player.momentum_value, 7, "放弃时保留当前连势")
    _assert_equal(abandoned.player.defense, 13, "放弃时仍按冻结P获得floor(P/2)防御")
    _assert_true(abandoned.enemy.poison_damage_modifier_sources.is_empty(),
        "放弃时不建立毒伤百分比来源")

    var consumed = _engine(9002)
    consumed.sequence_book.configure({
        "pair":["pair_forest_borrow_momentum_poison"]})
    var slot_id := str(consumed.sequence_book.current_slot("pair").get(
        "slot_instance_id", ""))
    consumed.player.momentum_value = 10
    var consumed_context = _context_for(
        consumed, "pair_forest_borrow_momentum_poison", 30, slot_id)
    consumed_context.initial_power = 20
    consumed_context.pre_momentum_power = 20
    consumed_context.momentum_used = 10
    pending = consumed.effect_executor.execute_all(
        consumed.repository.get_definition(
            "pair_forest_borrow_momentum_poison").effects,
        consumed_context)
    var consumed_result := _resume_effect_choice(consumed, pending, ["consume"])
    _assert_true(consumed_result.get("success", false), "借势催蛊选择清空后成功结算")
    _assert_equal(consumed.player.defense, 15,
        "本门先使用含连势快照的冻结P再实际消费S")
    _assert_equal(consumed.player.momentum_value, 0, "实际清空并记录S=10")
    _assert_true(consumed.player.momentum_changed_for_action(
        consumed_context.action_token), "实际清空算作本门改变过连势")
    _assert_equal(consumed.enemy.poison_damage_modifier_sources.size(), 1,
        "清空正数连势建立一份毒伤修正来源")
    var source: Dictionary = consumed.enemy.poison_damage_modifier_sources[0]
    _assert_equal(source.get("percent", 0), 50, "S=10建立+5S%=50%毒伤修正")
    _assert_equal(source.get("remaining_rounds", 0), 2,
        "毒伤来源公开当前与下一完整回合两段剩余时间")
    _assert_equal(source.get("source_instance_key", ""), slot_id,
        "毒伤修正依附产生它的具体功法槽位")
    _assert_equal(source.get("content_id", ""),
        "pair_forest_borrow_momentum_poison", "毒伤修正公开功法来源ID")
    _assert_equal(source.get("label", ""), "林·借势催蛊",
        "修正与剩余时间显示在功法来源上")
    var current_round_poison: Dictionary = consumed.effect_ports.deal_damage(
        consumed.player, consumed.enemy, 10, "poison-probe", false,
        "borrow-poison-current", "poison")
    _assert_equal(current_round_poison.get("final_amount", 0), 15,
        "建立后的当前剩余完整回合毒伤修正生效")
    consumed.timing_system.emit_timing("turn_end", {
        "round_number":1, "actor":consumed.enemy,
        "actors":[consumed.player, consumed.enemy]})
    _assert_equal(consumed.enemy.poison_damage_modifier_sources[0].get(
        "remaining_rounds", 0), 1, "当前完整回合结束后剩余1回合")
    var next_round_poison: Dictionary = consumed.effect_ports.deal_damage(
        consumed.player, consumed.enemy, 10, "poison-probe", false,
        "borrow-poison-next", "poison")
    _assert_equal(next_round_poison.get("final_amount", 0), 15,
        "下一个完整回合内毒伤修正仍生效")
    consumed.timing_system.emit_timing("turn_end", {
        "round_number":2, "actor":consumed.enemy,
        "actors":[consumed.player, consumed.enemy]})
    _assert_true(consumed.enemy.poison_damage_modifier_sources.is_empty(),
        "下一个完整回合结束后毒伤修正彻底到期")
    var expired_poison: Dictionary = consumed.effect_ports.deal_damage(
        consumed.player, consumed.enemy, 10, "poison-probe", false,
        "borrow-poison-expired", "poison")
    _assert_equal(expired_poison.get("final_amount", 0), 10,
        "到期后的后续毒伤不再获得修正")

func _test_melt_armor_momentum_sources_rounding_and_expiry() -> void:
    var engine = _engine(9101)
    engine.enemy.defense = 10
    engine.enemy.add_reflection_source(100, "melt-armor-reflection", 1)
    var context = _context_for(engine, "pair_fire_melt_armor_momentum", 20)
    var result: Dictionary = engine.effect_executor.execute_all(
        engine.repository.get_definition("pair_fire_melt_armor_momentum").effects,
        context)
    _assert_true(result.get("success", false), "熔甲成势完整效果链成功")
    _assert_equal(engine.enemy.defense, 0, "本门伤害实际吸收敌方10点防御")
    _assert_equal(engine.player.momentum_value, 3,
        "伤害前建立响应令本门攻击的floor(10/3)计入连势")
    var actor_life_before := int(engine.player.life)

    engine.enemy.defense = 8
    engine.effect_ports.remove_defense(
        engine.enemy, 2, false, engine.player, "technique",
        "melt-direct-a", "direct_effect")
    engine.effect_ports.remove_defense(
        engine.enemy, 2, false, engine.player, "technique",
        "melt-direct-b", "direct_effect")
    _assert_equal(engine.player.momentum_value, 3,
        "两次D=2分别floor(D/3)而非合并后取整")
    engine.effect_ports.remove_defense(
        engine.enemy, 4, false, engine.player, "technique",
        "melt-direct-c", "direct_effect")
    _assert_equal(engine.player.momentum_value, 4,
        "我方直接削防D=4单次获得floor(4/3)连势")
    _assert_equal(engine.player.life, actor_life_before,
        "直接削防虽可记录但不触发敌方反震")

    engine.enemy.defense = 6
    engine.effect_ports.remove_defense(
        engine.enemy, 6, false, engine.enemy, "enemy_effect",
        "melt-foreign", "direct_effect")
    _assert_equal(engine.player.momentum_value, 4, "非我方来源削防不触发熔甲响应")
    engine.timing_system.emit_timing("turn_end", {
        "round_number":1, "actor":engine.player,
        "actors":[engine.player, engine.enemy]})
    engine.enemy.defense = 6
    engine.effect_ports.remove_defense(
        engine.enemy, 6, false, engine.player, "technique",
        "melt-expired", "direct_effect")
    _assert_equal(engine.player.momentum_value, 4, "完整回合结束后削防不再触发熔甲响应")

func _test_broken_armor_qi_progress_sources_and_cleanup() -> void:
    var engine = _engine(9201)
    engine.sequence_book.configure({
        "pair":["pair_mountain_broken_armor_qi"]})
    var slot_id := str(engine.sequence_book.current_slot("pair").get(
        "slot_instance_id", ""))
    var context = _context_for(
        engine, "pair_mountain_broken_armor_qi", 20, slot_id)
    var result: Dictionary = engine.effect_executor.execute_all(
        engine.repository.get_definition("pair_mountain_broken_armor_qi").effects,
        context)
    _assert_true(result.get("success", false), "折甲行气建立本完整回合累计响应")
    _assert_equal(engine.player.defense, 20, "折甲行气先获得P点防御")
    engine.player.defense = 25
    engine.effect_ports.deal_damage(
        engine.enemy, engine.player, 25, "technique", false,
        "broken-armor-damage", "normal")
    _assert_equal(engine.player.same_qi_value, 2,
        "敌方伤害吸收25点防御触发2次同气收益")
    _assert_equal(_slot_marker_value(engine, slot_id, "armor_loss"), 5,
        "25点损失消费20并在具体槽位保留5点溢出")

    engine.player.add_reflection_source(100, "broken-armor-reflection", 1)
    engine.player.defense = 5
    var enemy_life_before := int(engine.enemy.life)
    engine.effect_ports.remove_defense(
        engine.player, 5, false, engine.enemy, "enemy_effect",
        "broken-armor-direct", "direct_effect")
    _assert_equal(engine.player.same_qi_value, 3,
        "敌方直接削防与已有5点累计共同跨过10点阈值")
    _assert_equal(_slot_marker_value(engine, slot_id, "armor_loss"), 0,
        "敌方直接削防跨阈值后正确消费累计值")
    _assert_equal(engine.enemy.life, enemy_life_before,
        "敌方直接削防不会因此触发我方反震")

    engine.player.defense = 18
    engine.effect_ports.remove_defense(
        engine.player, 4, false, engine.player, "technique",
        "broken-armor-cost", "cost")
    engine.effect_ports.remove_defense(
        engine.player, 4, false, engine.player, "rule",
        "broken-armor-decay", "decay")
    engine.effect_ports.remove_defense(
        engine.player, 4, false, null, "rule",
        "broken-armor-clear", "reset")
    _assert_equal(_slot_marker_value(engine, slot_id, "armor_loss"), 0,
        "我方支付、自然衰减、清空及其他非敌方来源均不计数")

    engine.player.defense = 7
    engine.effect_ports.remove_defense(
        engine.player, 7, false, engine.enemy, "enemy_effect",
        "broken-armor-partial", "direct_effect")
    _assert_equal(_slot_marker_value(engine, slot_id, "armor_loss"), 7,
        "未满10点的本次限时累计暂存在槽位")
    engine.timing_system.emit_timing("turn_end", {
        "round_number":1, "actor":engine.player,
        "actors":[engine.player, engine.enemy]})
    _assert_equal(_slot_marker_value(engine, slot_id, "armor_loss"), 0,
        "完整回合结束清除未满阈值的折甲记录")
    engine.player.defense = 10
    engine.effect_ports.remove_defense(
        engine.player, 10, false, engine.enemy, "enemy_effect",
        "broken-armor-expired", "direct_effect")
    _assert_equal(engine.player.same_qi_value, 3,
        "响应过期后的敌方削防不再推进同气")

func _test_three_breath_return_battle_session_flow() -> void:
    var engine = _engine(9301)
    engine.sequence_book.configure({
        "high_card":["high_wind_three_breath_return"]})
    var wind_slot_id := str(engine.sequence_book.current_slot(
        "high_card").get("slot_instance_id", ""))
    engine.player.draw_pile = [
        _card("2", "wind"), _card("3", "forest"),
        _card("4", "fire"), _card("5", "mountain")]
    for reason in ["normal_draw", "inner_skill", "item", "card_effect"]:
        engine.player.draw(1, reason)
    _assert_equal(_slot_marker_value(
        engine, wind_slot_id, "technique_draw_count"), 0,
        "三息回风排除正常补牌、内功、物品和真气自身抽牌")

    engine.repository.techniques["special_draw_six_probe"] = {
        "id":"special_draw_six_probe", "name":"专项抽六探针",
        "pool":"high", "effects":[
            {"op":"draw", "count":6},
            {"op":"select_cards", "choice_id":"after_six_wait",
                "chooser":"actor", "minimum":1, "maximum":1,
                "insufficient_policy":"fail",
                "query":{"side":"actor", "zone":"hand", "order":"zone",
                    "filters":{"card_kind":"normal"}},
                "capture":"selected"},
        ],
    }
    engine.sequence_book.configure({"high_card":[
        "special_draw_six_probe", "high_wind_three_breath_return",
        "basic_guard"]})
    wind_slot_id = str(engine.sequence_book.find_slots({
        "hand_id":"high_card",
        "technique_id":"high_wind_three_breath_return"})[0].get(
            "slot_instance_id", ""))
    var selected = _card("9", "wind")
    engine.player.hand = [selected]
    engine.player.draw_pile = [
        _card("2", "wind"), _card("3", "forest"),
        _card("4", "fire"), _card("5", "mountain"),
        _card("6", "wind"), _card("7", "forest")]
    var automatic_events: Array = []
    var sequence_events: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "action_resolved" \
                    and str(values.get("technique_id", "")) \
                    == "high_wind_three_breath_return" \
                    and str(values.get("trigger_mode", "")) == "automatic":
                automatic_events.append(values.duplicate(true))
            if kind == "technique_sequence_changed" \
                    and values.get("changed_slots", []).any(func(slot):
                        return str(slot.get("slot_instance_id", "")) \
                            == wind_slot_id):
                sequence_events.append(values.duplicate(true)))
    var session = BattleSessionScript.new(engine)
    engine.actions_available = 1
    var life_before := int(engine.enemy.life)
    var started = session.execute({
        "type":"play_cards", "card_ids":[str(selected.id)]})
    _assert_true(started.success and bool(started.payload_value(
        "pending_choice", false)),
        "三息回风由BattleSession行动中的功法抽六触发并进入等待选择")
    _assert_equal(engine.enemy.life, life_before - 27,
        "一次功法抽6张按稳定抽牌顺序连续造成18与9点伤害")
    _assert_equal(automatic_events.map(func(values):
        return int(values.get("initial_power", -1))), [18, 9],
        "三息回风两次自动触发分别冻结每组三张的特殊P₀")
    _assert_true(not sequence_events.is_empty(),
        "三息回风自动触发发送真实槽位移动事件")
    _assert_equal(_slot_marker_value(
        engine, wind_slot_id, "technique_draw_count"), 0,
        "抽6张完整消费两组计数且无虚构上限")
    var life_while_waiting := int(engine.enemy.life)
    var event_count_while_waiting := automatic_events.size()
    var request: Dictionary = started.payload_value("choice_request", {})
    var candidate_ids: Array = request.get("candidate_ids", [])
    var selected_choice_id := str(candidate_ids[0]) \
        if not candidate_ids.is_empty() else ""
    var resumed = session.execute({
        "type":"resolve_choice",
        "request_id":str(request.get("request_id", "")),
        "card_ids":[selected_choice_id] if selected_choice_id != "" else [],
    })
    _assert_true(resumed.success and not bool(resumed.payload_value(
        "pending_choice", false)), "三息回风等待选择从BattleSession恢复完成")
    _assert_equal(engine.enemy.life, life_while_waiting,
        "等待选择恢复不重复执行三息回风伤害")
    _assert_equal(automatic_events.size(), event_count_while_waiting,
        "等待选择恢复不重复触发三息回风")
    _assert_equal(str(engine.sequence_book.current_slot(
        "high_card").get("technique_id", "")), "basic_guard",
        "嵌套自动触发后调用者与真实槽位均按稳定身份推进")

    var manual = _engine(9302)
    manual.sequence_book.configure({"high_card":[
        "high_wind_three_breath_return", "basic_guard"]})
    var manual_slot := str(manual.sequence_book.current_slot(
        "high_card").get("slot_instance_id", ""))
    manual.player.draw_pile = [
        _card("2", "wind"), _card("3", "forest")]
    manual.player.draw(2, "technique")
    _assert_equal(_slot_marker_value(
        manual, manual_slot, "technique_draw_count"), 2,
        "三息回风主动触发前已有抽牌进度保存在具体槽位")
    var manual_selected = manual.player.hand[0]
    var manual_session = BattleSessionScript.new(manual)
    manual.actions_available = 1
    var manual_life_before := int(manual.enemy.life)
    var manual_result = manual_session.execute({
        "type":"play_cards", "card_ids":[str(manual_selected.id)]})
    _assert_true(manual_result.success, "三息回风主动触发正常完成行动")
    _assert_equal(manual.enemy.life, manual_life_before,
        "三息回风主动触发正文效果无效")
    _assert_equal(_slot_marker_value(
        manual, manual_slot, "technique_draw_count"), 2,
        "三息回风主动触发不清除已有记录")
    _assert_equal(str(manual.sequence_book.current_slot(
        "high_card").get("technique_id", "")), "basic_guard",
        "三息回风主动无效模式仍推进真实序列")

func _test_poison_meridian_echo_battle_session_flow() -> void:
    var engine = _engine(9401)
    engine.repository.techniques["special_poison_all_probe"] = {
        "id":"special_poison_all_probe", "name":"专项逐段毒探针",
        "pool":"high", "effects":[{
            "op":"trigger_all_poison_simultaneously"}],
    }
    engine.sequence_book.configure({"high_card":[
        "special_poison_all_probe", "high_forest_poison_meridian_echo",
        "basic_guard"]})
    var echo_slot := str(engine.sequence_book.find_slots({
        "hand_id":"high_card",
        "technique_id":"high_forest_poison_meridian_echo"})[0].get(
            "slot_instance_id", ""))
    var selected = _card("9", "forest")
    engine.player.hand = [selected]
    engine.player.draw_pile.clear()
    for rank in ["2", "3", "4", "5", "6", "7", "8"]:
        var poison_card = _card(rank, "forest")
        engine.status_system.apply_card_anomaly(
            poison_card, "state", "poison", {}, "蛊脉专项")
        engine.player.draw_pile.append(poison_card)
    var automatic_events: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "action_resolved" \
                    and str(values.get("technique_id", "")) \
                    == "high_forest_poison_meridian_echo" \
                    and str(values.get("trigger_mode", "")) == "automatic":
                automatic_events.append(values.duplicate(true)))
    var session = BattleSessionScript.new(engine)
    engine.actions_available = 1
    var started = session.execute({
        "type":"play_cards", "card_ids":[str(selected.id)]})
    _assert_true(started.success, "蛊脉自鸣由BattleSession同步毒段完整触发")
    _assert_equal(automatic_events.map(func(values):
        return int(values.get("initial_power", -1))), [9, 18],
        "七个毒伤段按稳定逐段顺序冻结两组特殊P₀")
    _assert_equal(engine.player.defense, 27,
        "蛊脉自鸣两次自动分支分别获得P防御")
    _assert_equal(engine.player.same_qi_value, 2,
        "蛊脉自鸣两次自动分支分别使同气槽+1")
    _assert_equal(_slot_marker_value(
        engine, echo_slot, "poison_segment_count"), 1,
        "七段毒伤触发两次后保留1段溢出")
    _assert_equal(_slot_marker_value(
        engine, echo_slot, "poison_segment_damage"), 8,
        "蛊脉自鸣溢出段保留进入毒防御前的最终伤害")

    var zero_loss = _engine(9402)
    zero_loss.repository.techniques["special_poison_all_probe"] = \
        engine.repository.techniques["special_poison_all_probe"].duplicate(true)
    zero_loss.sequence_book.configure({"high_card":[
        "special_poison_all_probe", "high_forest_poison_meridian_echo"]})
    zero_loss.player.grant_poison_damage_modifier(
        0, -100, -1, "battle_end", "zero-poison", true, 1)
    var zero_selected = _card("9", "forest")
    zero_loss.player.hand = [zero_selected]
    for rank in ["2", "3", "4"]:
        var poison_card = _card(rank, "forest")
        zero_loss.status_system.apply_card_anomaly(
            poison_card, "state", "poison", {}, "零损毒段")
        zero_loss.player.draw_pile.append(poison_card)
    var zero_events: Array = []
    zero_loss.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "action_resolved" \
                    and str(values.get("technique_id", "")) \
                    == "high_forest_poison_meridian_echo" \
                    and str(values.get("trigger_mode", "")) == "automatic":
                zero_events.append(values.duplicate(true)))
    var zero_session = BattleSessionScript.new(zero_loss)
    zero_loss.actions_available = 1
    var zero_result = zero_session.execute({
        "type":"play_cards", "card_ids":[str(zero_selected.id)]})
    _assert_true(zero_result.success, "被毒防御归零的有效毒段仍完成行动")
    _assert_equal(zero_loss.player.life, 100,
        "-100%毒防御令三段实际生命损失均为0")
    _assert_equal(zero_events.map(func(values):
        return int(values.get("initial_power", -1))), [0],
        "实际生命损失为0仍计三段且特殊P₀读取毒防御前最终值")
    _assert_equal(zero_loss.player.same_qi_value, 1,
        "零生命损失毒段仍触发蛊脉自鸣自动同气")

    var manual = _engine(9403)
    manual.sequence_book.configure({"high_card":[
        "high_forest_poison_meridian_echo", "basic_guard"]})
    var manual_slot := str(manual.sequence_book.current_slot(
        "high_card").get("slot_instance_id", ""))
    var progress_card = _card("2", "forest")
    manual.player.hand = [progress_card]
    manual.status_system.apply_card_anomaly(
        progress_card, "state", "poison", {}, "主动进度")
    manual.effect_ports.trigger_poison_card(
        manual.player, progress_card, "manual-progress")
    _assert_equal(_slot_marker_value(
        manual, manual_slot, "poison_segment_count"), 1,
        "蛊脉自鸣主动触发前已有毒段进度")
    var manual_selected = _card("9", "forest")
    manual.player.hand = [manual_selected]
    var manual_session = BattleSessionScript.new(manual)
    manual.actions_available = 1
    var manual_result = manual_session.execute({
        "type":"play_cards", "card_ids":[str(manual_selected.id)]})
    _assert_true(manual_result.success, "蛊脉自鸣主动无效模式正常完成")
    _assert_equal(manual.player.defense, 0,
        "蛊脉自鸣主动触发不执行防御正文")
    _assert_equal(manual.player.same_qi_value, 0,
        "蛊脉自鸣主动触发不执行自动同气分支")
    _assert_equal(_slot_marker_value(
        manual, manual_slot, "poison_segment_count"), 1,
        "蛊脉自鸣主动触发不清除毒段进度")

    var copies = _engine(9404)
    copies.repository.techniques["special_poison_all_probe"] = \
        engine.repository.techniques["special_poison_all_probe"].duplicate(true)
    copies.sequence_book.configure({"high_card":[
        "special_poison_all_probe", "high_forest_poison_meridian_echo"]})
    var permanent_slot := str(copies.sequence_book.find_slots({
        "hand_id":"high_card",
        "technique_id":"high_forest_poison_meridian_echo"})[0].get(
            "slot_instance_id", ""))
    var probe_slot := str(copies.sequence_book.current_slot(
        "high_card").get("slot_instance_id", ""))
    var first_high = _card("9", "wind")
    var second_high = _card("10", "fire")
    copies.player.hand = [first_high, second_high]
    var first_poison = _card("2", "forest")
    copies.status_system.apply_card_anomaly(
        first_poison, "state", "poison", {}, "副本首段")
    copies.player.draw_pile = [first_poison]
    var copies_session = BattleSessionScript.new(copies)
    copies.actions_available = 1
    var first_result = copies_session.execute({
        "type":"play_cards", "card_ids":[str(first_high.id)]})
    _assert_true(first_result.success, "永久蛊脉槽先记录1段")
    _assert_equal(_slot_marker_value(
        copies, permanent_slot, "poison_segment_count"), 1,
        "临时副本插入前永久蛊脉槽独立保存首段")
    var inserted: Array = copies.sequence_book.insert_temporary_slots(
        "high_card", "high_forest_poison_meridian_echo", 1,
        {"position":"after_current", "marker_mode":"independent"})
    var temporary_slot := str(inserted[0].get("slot_instance_id", ""))
    _assert_equal(_slot_marker_value(
        copies, temporary_slot, "poison_segment_count"), 0,
        "新插入临时蛊脉副本从0开始记录")
    copies.sequence_book.move_slot_to_current("high_card", probe_slot)
    for rank in ["5"]:
        var poison_card = _card(rank, "forest")
        copies.status_system.apply_card_anomaly(
            poison_card, "state", "poison", {}, "副本后段")
        copies.player.draw_pile.append(poison_card)
    copies.actions_available = 1
    var second_result = copies_session.execute({
        "type":"play_cards", "card_ids":[str(second_high.id)]})
    _assert_true(second_result.success, "插入临时副本后第二次BattleSession行动完成")
    _assert_equal(_slot_marker_value(
        copies, permanent_slot, "poison_segment_count"), 2,
        "永久蛊脉槽累计插入前后两段")
    _assert_equal(_slot_marker_value(
        copies, temporary_slot, "poison_segment_count"), 1,
        "临时蛊脉副本只记录插入后的一段并保持独立")

func _test_three_knocks_battle_session_flow() -> void:
    var engine = _engine(9501)
    engine.sequence_book.configure({
        "pair":["pair_mountain_three_knocks", "basic_guard"],
        "high_card":["basic_scatter"]})
    var knock_slot := str(engine.sequence_book.current_slot(
        "pair").get("slot_instance_id", ""))
    for rejected in [
            {"actor":engine.player, "pool":"pair", "success":true},
            {"actor":engine.enemy, "pool":"three", "success":true},
            {"actor":engine.enemy, "pool":"pair", "success":false}]:
        _commit_technique_action_event(
            engine, rejected["actor"], "pair", str(rejected["pool"]),
            99, "manual", bool(rejected["success"]))
    _assert_equal(_slot_marker_value(
        engine, knock_slot, "enemy_pair_technique_count"), 0,
        "听阵三叩排除我方、非对子池和失败功法事件")
    _commit_technique_action_event(
        engine, engine.enemy, "pair", "pair", 5, "invoked", true)
    _commit_technique_action_event(
        engine, engine.enemy, "two_pair", "pair", 8, "automatic", true)
    _assert_equal(_slot_marker_value(
        engine, knock_slot, "enemy_pair_technique_count"), 2,
        "一对调用与两对自动成功功法都逐门记录")
    _assert_equal(_slot_marker_value(
        engine, knock_slot, "enemy_pair_technique_p0"), 13,
        "听阵三叩在阈值前累计两门功法P₀")

    var pair_cards = [_card("3", "wind"), _card("3", "forest")]
    var reserve = _card("9", "fire")
    engine.player.hand = pair_cards + [reserve]
    var session = BattleSessionScript.new(engine)
    engine.actions_available = 1
    var manual_result = session.execute({
        "type":"play_cards", "card_ids":pair_cards.map(
            func(card): return str(card.id))})
    _assert_true(manual_result.success, "听阵三叩主动分支由BattleSession完成")
    var manual_power := int(manual_result.payload_value(
        "preview", {}).get("values", {}).get("technique_value", 0))
    _assert_equal(engine.player.defense, manual_power,
        "听阵三叩主动分支只获得P防御")
    _assert_equal(engine.player.same_qi_value, 0,
        "听阵三叩主动分支不获得自动同气")
    _assert_equal(_slot_marker_value(
        engine, knock_slot, "enemy_pair_technique_count"), 2,
        "听阵三叩主动分支不清除已有进度")
    _assert_equal(str(engine.sequence_book.current_slot(
        "pair").get("technique_id", "")), "basic_guard",
        "听阵三叩主动分支正常推进真实槽位")

    engine.repository.techniques["enemy_full_house_pair_probe"] = {
        "id":"enemy_full_house_pair_probe", "name":"敌方葫芦对子池探针",
        "pool":"pair", "effects":[{"op":"defense", "amount":1}],
    }
    engine.enemy_sequence_book.configure({
        "full_house":["enemy_full_house_pair_probe"]})
    engine.enemy.hand = [
        _card("5", "wind"), _card("5", "forest"),
        _card("7", "fire"), _card("7", "mountain"),
        _card("7", "wind")]
    var enemy_ids: Array = engine.enemy.hand.map(
        func(card): return str(card.id))
    var enemy_preview: Dictionary = engine._preview_for_side(
        engine.enemy, enemy_ids, engine.enemy_sequence_book)
    _assert_equal(enemy_preview.get("hand", {}).get("id", ""), "full_house",
        "敌方第三门由葫芦读取对子池功法")
    engine.enemy_actions_available = 1
    var proposal = BattleActionProposalScript.new().configure_accept(
        "three-knocks-probe", enemy_ids, enemy_preview)
    var stored: Dictionary = engine._store_enemy_action_proposal(
        proposal, "听阵专项")
    _assert_true(stored.get("success", false), "敌方葫芦对子池行动已锁定")
    engine.scripted_mode = true
    engine.actions_available = 1
    var spare = _card("10", "mountain")
    engine.player.hand = [reserve, spare]
    var automatic_events: Array = []
    var sequence_events: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "action_resolved" \
                    and str(values.get("technique_id", "")) \
                    == "pair_mountain_three_knocks" \
                    and str(values.get("trigger_mode", "")) == "automatic":
                automatic_events.append(values.duplicate(true))
            if kind == "technique_sequence_changed" \
                    and values.get("changed_slots", []).any(func(slot):
                        return str(slot.get("slot_instance_id", "")) \
                            == knock_slot):
                sequence_events.append(values.duplicate(true)))
    var defense_before := int(engine.player.defense)
    var same_qi_before := int(engine.player.same_qi_value)
    var resolved = session.execute({
        "type":"play_cards", "card_ids":[str(reserve.id)]})
    _assert_true(resolved.success and bool(resolved.payload_value(
        "enemy_technique_triggered", false)),
        "敌方葫芦对子池功法经BattleSession成功发动")
    var enemy_p0 := int(resolved.payload_value(
        "enemy_preview", {}).get("values", {}).get("initial_power", 0))
    var expected_p0 := int(floor((5 + 8 + enemy_p0) / 3.0))
    _assert_equal(automatic_events.map(func(values):
        return int(values.get("initial_power", -1))), [expected_p0],
        "听阵三叩以三门P₀平均值向下取整自动触发")
    _assert_equal(engine.player.defense, defense_before + expected_p0,
        "听阵三叩自动分支获得P防御")
    _assert_equal(engine.player.same_qi_value, same_qi_before + 1,
        "听阵三叩自动分支使同气槽+1")
    _assert_equal(_slot_marker_value(
        engine, knock_slot, "enemy_pair_technique_count"), 0,
        "听阵三叩触发后消费三门计数")
    _assert_equal(_slot_marker_value(
        engine, knock_slot, "enemy_pair_technique_p0"), 0,
        "听阵三叩触发后消费对应三门P₀")
    _assert_true(not sequence_events.is_empty(),
        "听阵三叩自动分支移动并推进声明条件的真实槽位")

func _commit_technique_action_event(
        engine, actor, hand_id: String, pool: String, p0: int,
        trigger_mode: String, succeeded: bool) -> void:
    var serial_value := int(engine.battle_passive_event_service.next_serial())
    engine.battle_passive_event_service.commit("action_resolved", {
        "event_token":engine.battle_passive_event_service.make_token(
            "action_resolved", actor, serial_value,
            "three-knocks-%d" % serial_value),
        "event_serial":serial_value,
        "actor":actor,
        "target":engine.enemy if actor == engine.player else engine.player,
        "owner":actor,
        "action_token":"three-knocks-%d" % serial_value,
        "source_kind":"technique",
        "hand_id":hand_id,
        "technique_id":"pair-event-probe",
        "technique_pool":pool,
        "initial_power":p0,
        "technique_power":p0,
        "trigger_mode":trigger_mode,
        "technique_triggered":true,
        "action_succeeded":succeeded,
    })

func _context_for(
        engine, technique_id: String, power: int,
        slot_instance_id: String = "", card_contribution: int = 0):
    var definition = engine.repository.get_definition(technique_id)
    return EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "power": power,
        "initial_power": power,
        "values": {"technique_value":power, "initial_power":power},
        "hand_result": {"id":"high_card", "contributing":[]},
        "played_cards": [],
        "group_snapshot": {
            "played_cards":[], "contributing_cards":[], "extra_cards":[],
            "played_poison_amount":0, "played_poison_count":0,
            "card_contribution":card_contribution,
        },
        "captures": {},
        "technique_id": technique_id,
        "technique_name": definition.display_name,
        "technique_pool": definition.pool,
        "slot_instance_id": slot_instance_id,
        "sequence_book": engine.sequence_book,
        "action_token": "special-%s-%d" % [technique_id, assertions],
        "source_kind": "technique",
    })

func _resume_effect_choice(engine, pending: Dictionary, selected_ids: Array) -> Dictionary:
    return engine.effect_executor.resume(
        pending.get("_continuation"),
        str(pending.get("choice_request", {}).get("request_id", "")),
        selected_ids)

func _marker_value(engine, slot_instance_id: String) -> int:
    return int(engine.player.source_marker_store.value(
        "technique", slot_instance_id, "x", "battle"))

func _slot_marker_value(
        engine, slot_instance_id: String, marker_id: String) -> int:
    return int(engine.player.source_marker_store.value(
        "technique", slot_instance_id, marker_id, "battle"))
