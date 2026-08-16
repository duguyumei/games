extends "res://tests/support/expanded_technique_test_base.gd"

const TechniquePhaseCatalogScript = preload(
    "res://core/effects/technique_phase_catalog.gd")

const SPECIAL_TECHNIQUES := {
    "bomb_wind_empty_hand": {"name":"风·断流无手", "pool":"bomb"},
    "pair_forest_dissipate_decay": {"name":"林·弃腐续生", "pool":"pair"},
    "bomb_fire_break_city": {"name":"火·破城焚关", "pool":"bomb"},
    "high_mountain_shed_wall": {"name":"山·舍壁还生", "pool":"high"},
    "pair_wind_returning_tide": {"name":"风·归潮蓄锋", "pool":"pair"},
    "high_forest_shared_fate_poison": {"name":"林·同命淬蛊", "pool":"high"},
    "straight_fire_return_same_qi": {"name":"火·回轮换势", "pool":"straight"},
    "straight_mountain_hidden_edge": {"name":"山·裂壁藏锋", "pool":"straight"},
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
