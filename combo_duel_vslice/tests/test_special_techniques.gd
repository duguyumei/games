extends "res://tests/support/expanded_technique_test_base.gd"

const TechniquePhaseCatalogScript = preload(
    "res://core/effects/technique_phase_catalog.gd")

const SPECIAL_TECHNIQUES := {
    "bomb_wind_empty_hand": {"name":"风·断流无手", "pool":"bomb"},
    "pair_forest_dissipate_decay": {"name":"林·弃腐续生", "pool":"pair"},
    "bomb_fire_break_city": {"name":"火·破城焚关", "pool":"bomb"},
    "high_mountain_shed_wall": {"name":"山·舍壁还生", "pool":"high"},
}

func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_formal_resource_contract()
    _test_empty_hand_live_damage_branch()
    _test_dissipate_decay_choice_and_recovery()
    _test_break_city_unblockable_absorption_and_reflection()
    _test_shed_wall_marker_and_battle_reset()
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

func _context_for(
        engine, technique_id: String, power: int,
        slot_instance_id: String = ""):
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

func _marker_value(engine, slot_instance_id: String) -> int:
    return int(engine.player.source_marker_store.value(
        "technique", slot_instance_id, "x", "battle"))
