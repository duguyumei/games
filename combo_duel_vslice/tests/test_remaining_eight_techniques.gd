extends "res://tests/support/expanded_technique_test_base.gd"

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]

const TECHNIQUES := {
    "straight_wind_long_wind_sea": {"name":"风·长风蓄海", "pool":"straight"},
    "bomb_forest_seize_origin_life": {"name":"林·夺元栽命", "pool":"bomb"},
    "bomb_fire_pass_flame": {"name":"火·万法传薪", "pool":"bomb"},
    "three_fire_return_style": {"name":"火·借式还招", "pool":"three"},
    "straight_fire_hanging_furnace": {"name":"火·三劫悬炉", "pool":"straight"},
    "bomb_fire_setting_sun": {"name":"火·残阳绝式", "pool":"bomb"},
    "three_fire_shadow_pursuit": {"name":"火·照影追式", "pool":"three"},
    "bomb_mountain_wait_enemy": {"name":"山·悬岳待敌", "pool":"bomb"},
}


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_formal_contract()
    _test_long_wind_countdown_and_automatic_source()
    _test_seize_origin_once_per_battle_and_cap()
    _test_pass_flame_partial_generation_and_momentum()
    _test_return_style_and_setting_sun_invocation_power()
    _test_hanging_furnace_response_reset_and_completion()
    _test_shadow_pursuit_relative_source_invocation()
    _test_wait_enemy_keep_existing_and_fallback()
    _finish("REMAINING EIGHT TECHNIQUE TEST")


func _test_formal_contract() -> void:
    var repository = _repository()
    var manifest = JSON.parse_string(FileAccess.get_file_as_string(
        "res://data/techniques.json"))
    _assert_equal(repository.techniques.size(), 236, "正式目录共236门功法")
    for technique_id in TECHNIQUES:
        var expected: Dictionary = TECHNIQUES[technique_id]
        var definition = repository.get_definition(technique_id)
        _assert_true(definition != null, "%s独立资源存在" % technique_id)
        if definition == null:
            continue
        _assert_equal(definition.display_name, expected["name"],
            "%s冻结名称" % technique_id)
        _assert_equal(definition.pool, expected["pool"],
            "%s正式池资格" % technique_id)
        _assert_true(not definition.special,
            "%s不建立特殊功法内容分类" % technique_id)
        _assert_equal(manifest["integration_statuses"].get(
            technique_id, ""), "formal_complete", "%s正式接入" % technique_id)
        _assert_true(manifest["resource_paths"].has(
            "res://data/techniques/%s.tres" % technique_id),
            "%s资源路径登记" % technique_id)
    for path in [
            "res://data/production_sequences.json",
            "res://data/enemies.json",
            "res://data/production_enemy_entry.json"]:
        var text := FileAccess.get_file_as_string(path)
        for technique_id in TECHNIQUES:
            _assert_true(not text.contains(str(technique_id)),
                "%s未进入%s" % [technique_id, path])


func _test_long_wind_countdown_and_automatic_source() -> void:
    var engine = _engine(20101)
    engine.sequence_book.configure({
        "straight":["straight_wind_long_wind_sea"]})
    var slot: Dictionary = engine.sequence_book.current_slot("straight")
    engine.player.draw_pile = [
        _card("2", "wind"), _card("3", "wind"),
        _card("4", "wind"), _card("5", "wind")]
    engine.enemy.max_life = 500
    engine.enemy.life = 500
    var context = _context_for(
        engine, "straight_wind_long_wind_sea", 20,
        str(slot["slot_instance_id"]), "straight", 0)
    var started: Dictionary = engine.effect_executor.execute_all(
        engine.repository.get_definition(
            "straight_wind_long_wind_sea").effects, context)
    _assert_true(started.get("success", false), "长风蓄海开始蓄力")
    _assert_true(engine.effect_ports.is_technique_charging(
        engine.player, str(slot["slot_instance_id"])), "长风建立真实槽位蓄风")
    _assert_equal(engine.status_system.status_delay_service.records().size(),
        1, "长风只建立一份倒计时")
    for round_number in [2, 3, 4]:
        var resolved: Dictionary = engine.status_system.status_delay_service \
            .on_round_start([engine.player], round_number)
        _assert_true(resolved.get("success", false),
            "长风第%d次回合开始结算" % round_number)
    _assert_equal(engine.status_system.status_delay_service.records().size(),
        0, "长风第三次回合开始完成倒计时")
    _assert_true(engine.enemy.life < 500, "长风完成后自动调用自身造成真伤")
    _assert_true(not engine.effect_ports.is_technique_charging(
        engine.player, str(slot["slot_instance_id"])), "长风自动分支清空蓄风")


func _test_seize_origin_once_per_battle_and_cap() -> void:
    var engine = _engine(20201)
    engine.sequence_book.configure({
        "four_kind":["bomb_forest_seize_origin_life"]})
    var slot: Dictionary = engine.sequence_book.current_slot("four_kind")
    engine.player.hand_technique_progression = {
        "four_kind":{"sequence":["bomb_forest_seize_origin_life"]}}
    engine.enemy.max_life = 400
    engine.enemy.life = 400
    var definition = engine.repository.get_definition(
        "bomb_forest_seize_origin_life")
    var first: Dictionary = engine.effect_executor.execute_all(
        definition.effects, _context_for(
            engine, definition.id, 20, str(slot["slot_instance_id"]),
            "four_kind", 20))
    _assert_true(first.get("success", false), "夺元栽命首次成功")
    _assert_equal(_source_marker(engine, "technique:%s" % definition.id,
        "life_origin", "run"), 15, "单战首次命元最多增加15")
    _assert_equal(engine.player.max_life, 115, "命元实时增加有效生命上限")
    var second: Dictionary = engine.effect_executor.execute_all(
        definition.effects, _context_for(
            engine, definition.id, 20, str(slot["slot_instance_id"]),
            "four_kind", 20))
    _assert_true(second.get("success", false), "夺元栽命同战再次成功")
    _assert_equal(_source_marker(engine, "technique:%s" % definition.id,
        "life_origin", "run"), 15, "同一战斗不会再次增加命元")
    engine.player.source_marker_store.clear_scope("battle")
    engine.player.source_marker_store.write(
        "technique", "technique:%s" % definition.id, definition.id,
        "life_origin", "run", "set", 75, {
            "public":true, "display_name":"命元", "contributes_to":"max_life"})
    engine.player.recalculate_effective_max_life()
    engine.effect_executor.execute_all(definition.effects, _context_for(
        engine, definition.id, 20, str(slot["slot_instance_id"]),
        "four_kind", 20))
    _assert_equal(_source_marker(engine, "technique:%s" % definition.id,
        "life_origin", "run"), 80, "命元在80处截顶")


func _test_pass_flame_partial_generation_and_momentum() -> void:
    var engine = _engine(20301)
    var sequences: Dictionary = {}
    var capacities: Dictionary = {}
    for hand_id in HAND_IDS:
        sequences[hand_id] = [
            "bomb_fire_pass_flame" if hand_id == "four_kind" \
            else "basic_scatter"]
        capacities[hand_id] = 2
    capacities["pair"] = 1
    engine.sequence_book.configure_with_capacities(sequences, capacities)
    var slot: Dictionary = engine.sequence_book.current_slot("four_kind")
    engine.enemy.max_life = 500
    engine.enemy.life = 500
    var result: Dictionary = engine.effect_executor.execute_all(
        engine.repository.get_definition("bomb_fire_pass_flame").effects,
        _context_for(engine, "bomb_fire_pass_flame", 20,
            str(slot["slot_instance_id"]), "four_kind", 20))
    _assert_true(result.get("success", false), "万法传薪效果链成功")
    _assert_equal(engine.enemy.life, 480, "万法传薪造成P点伤害")
    _assert_equal(engine.player.momentum_value, 10,
        "万法传薪按实际生命损失一半获得连势")
    var temporary_count := 0
    for hand_id in HAND_IDS:
        temporary_count += engine.sequence_book.temporary_slot_count(hand_id)
    _assert_equal(temporary_count, 6,
        "七个目标中一池满槽时其余六池部分成功")


func _test_return_style_and_setting_sun_invocation_power() -> void:
    var engine = _engine(20401)
    engine.sequence_book.configure({"three_kind":[
        "three_fire_return_style", "three_fire_rekindle"]})
    var slot: Dictionary = engine.sequence_book.current_slot("three_kind")
    engine.player.life = 40
    engine.enemy.max_life = 500
    engine.enemy.life = 500
    var result: Dictionary = engine.effect_executor.execute_all(
        engine.repository.get_definition("three_fire_return_style").effects,
        _context_for(engine, "three_fire_return_style", 20,
            str(slot["slot_instance_id"]), "three_kind", 12))
    _assert_true(result.get("success", false), "借式还招调用残阳绝式成功")
    _assert_equal(engine.enemy.life, 484,
        "借式造成10点伤害并令同池功法以C=12造成6点伤害")

    var confirm_engine = _engine(20402)
    confirm_engine.sequence_book.configure({
        "four_kind":["bomb_fire_setting_sun"]})
    var cards := [
        _card("5", "fire"), _card("5", "fire"),
        _card("5", "fire"), _card("5", "fire")]
    confirm_engine.player.hand = cards
    var preview: Dictionary = confirm_engine.preview(
        cards.map(func(card): return str(card.id)))
    confirm_engine.player.life = 40
    var confirmed: Dictionary = confirm_engine.action_resolver \
        .action_preview_service.recalculate_confirmed_power(
            confirm_engine.player, confirm_engine.enemy, preview,
            "setting-sun-confirm")
    _assert_true(confirmed.get("success", false), "残阳确认期功法值解析成功")
    _assert_equal(preview["frozen_power_formation"]["fixed_bonus"], 30,
        "残阳在确认时冻结已损生命一半")
    confirm_engine.player.life = 10
    confirm_engine.action_resolver.action_preview_service \
        .recalculate_confirmed_power(
            confirm_engine.player, confirm_engine.enemy, preview,
            "setting-sun-confirm-reuse")
    _assert_equal(preview["frozen_power_formation"]["fixed_bonus"], 30,
        "同一已冻结组不追溯改写残阳修正")


func _test_hanging_furnace_response_reset_and_completion() -> void:
    var engine = _engine(20501)
    engine.sequence_book.configure({
        "straight":["straight_fire_hanging_furnace"]})
    var slot: Dictionary = engine.sequence_book.current_slot("straight")
    engine.enemy.max_life = 500
    engine.enemy.life = 500
    var definition = engine.repository.get_definition(
        "straight_fire_hanging_furnace")
    engine.effect_executor.execute_all(definition.effects, _context_for(
        engine, definition.id, 20, str(slot["slot_instance_id"]),
        "straight", 20, "furnace-start"))
    _emit_action_end(engine, [str(engine.player.owner_id)], 0, 0, 7,
        "furnace-a")
    _assert_equal(_charging_value(engine, str(slot["slot_instance_id"])), 7,
        "悬炉记录首次我方行动生命损失")
    engine.effect_executor.execute_all(definition.effects, _context_for(
        engine, definition.id, 20, str(slot["slot_instance_id"]),
        "straight", 20, "furnace-reset"))
    var record: Dictionary = engine.status_system.status_response_service \
        .records()[0]
    _assert_equal(record["remaining_triggers"], 3,
        "再次触发把悬炉观察次数重置为3")
    _assert_equal(_charging_value(engine, str(slot["slot_instance_id"])), 7,
        "重置观察次数保留已有L")
    _emit_action_end(engine, [str(engine.player.owner_id)], 0, 0, 5,
        "furnace-b")
    _emit_action_end(engine, [str(engine.player.owner_id)], 0, 0, 3,
        "furnace-c")
    _emit_action_end(engine, [str(engine.player.owner_id)], 0, 0, 2,
        "furnace-d")
    _assert_equal(engine.enemy.life, 472,
        "两次即时10点伤害后按L=17额外造成8点真伤")
    _assert_true(not engine.effect_ports.is_technique_charging(
        engine.player, str(slot["slot_instance_id"])), "悬炉完成后清空L")


func _test_shadow_pursuit_relative_source_invocation() -> void:
    var engine = _engine(20601)
    engine.sequence_book.configure({"three_kind":[
        "three_fire_shadow_pursuit", "three_fire_rekindle",
        "three_fire_same_furnace"]})
    var slot: Dictionary = engine.sequence_book.current_slot("three_kind")
    engine.enemy.max_life = 500
    engine.enemy.life = 500
    engine.effect_executor.execute_all(
        engine.repository.get_definition("three_fire_shadow_pursuit").effects,
        _context_for(engine, "three_fire_shadow_pursuit", 20,
            str(slot["slot_instance_id"]), "three_kind", 20))
    engine.status_system.status_response_service.handle_event(
        "technique_succeeded", {
            "event_token":"shadow-enemy-low", "actor":engine.enemy,
            "target":engine.player, "initial_power":12,
            "technique_power":18, "hand_id":"three_kind",
        })
    _assert_equal(engine.enemy.life, 487,
        "照影先造成10点，再令后一槽以P₀=6造成3点伤害")
    var life_before := int(engine.enemy.life)
    engine.status_system.status_response_service.handle_event(
        "technique_succeeded", {
            "event_token":"shadow-enemy-high", "actor":engine.enemy,
            "target":engine.player, "initial_power":100,
            "technique_power":21, "hand_id":"three_kind",
        })
    _assert_equal(engine.enemy.life, life_before,
        "敌方P高于冻结值时照影不调用")


func _test_wait_enemy_keep_existing_and_fallback() -> void:
    var engine = _engine(20701)
    engine.sequence_book.configure({
        "four_kind":["bomb_mountain_wait_enemy"]})
    var slot: Dictionary = engine.sequence_book.current_slot("four_kind")
    var definition = engine.repository.get_definition(
        "bomb_mountain_wait_enemy")
    engine.effect_executor.execute_all(definition.effects, _context_for(
        engine, definition.id, 20, str(slot["slot_instance_id"]),
        "four_kind", 12, "wait-start"))
    engine.effect_executor.execute_all(definition.effects, _context_for(
        engine, definition.id, 20, str(slot["slot_instance_id"]),
        "four_kind", 12, "wait-reuse"))
    _assert_equal(engine.status_system.status_response_service.records().size(),
        1, "悬岳重复触发不建立第二份观察")
    _emit_action_end(engine, [str(engine.enemy.owner_id)], 0, 0, 0, "wait-a")
    _emit_action_end(engine, [str(engine.enemy.owner_id)], 4, 3, 0, "wait-b")
    _assert_equal(engine.player.defense, 39,
        "两次即时各10防御，再按Z=19获得19防御")
    _assert_equal(engine.enemy.life, 91, "悬岳按floor(Z/2)造成9点真伤")
    _assert_true(not engine.effect_ports.is_technique_charging(
        engine.player, str(slot["slot_instance_id"])), "悬岳完成后清空Z")


func _context_for(
        engine,
        technique_id: String,
        power: int,
        slot_instance_id: String,
        hand_id: String,
        card_contribution: int,
        action_token: String = ""):
    var definition = engine.repository.get_definition(technique_id)
    var token := action_token if action_token != "" \
        else "remaining-%s-%d" % [technique_id, assertions]
    return EffectContextScript.new().configure({
        "ports":engine.effect_ports,
        "actor":engine.player,
        "target":engine.enemy,
        "power":power,
        "initial_power":power,
        "values":{"technique_value":power, "initial_power":power},
        "hand_result":{"id":hand_id, "contributing":[]},
        "played_cards":[],
        "group_snapshot":{
            "played_cards":[], "contributing_cards":[], "extra_cards":[],
            "card_contribution":card_contribution,
        },
        "captures":{},
        "technique_id":technique_id,
        "technique_name":definition.display_name,
        "technique_pool":definition.pool,
        "slot_instance_id":slot_instance_id,
        "sequence_book":engine.sequence_book,
        "action_token":token,
        "root_action_token":token,
        "technique_execution_token":"%s:execution" % token,
        "source_kind":"technique",
        "source_id":technique_id,
        "source_name":definition.display_name,
        "source_instance_key":slot_instance_id,
        "trigger_mode":"manual",
        "card_identity_policy":engine.player.card_identity_policy,
    })


func _emit_action_end(
        engine,
        acting_owner_ids: Array,
        actor_life_loss: int,
        actor_defense_loss: int,
        target_life_loss: int,
        event_token: String) -> void:
    engine.status_system.status_response_service.handle_event(
        "action_resolution_end", {
            "event_token":event_token,
            "action_tokens":[event_token],
            "acting_owner_ids":acting_owner_ids,
            "action_results":[{
            "side":engine.player,
                "actual_life_loss":actor_life_loss,
                "actual_defense_loss":actor_defense_loss,
            }, {
                "side":engine.enemy,
                "actual_life_loss":target_life_loss,
                "actual_defense_loss":0,
            }],
        })


func _source_marker(
        engine,
        source_instance_key: String,
        marker_id: String,
        scope: String) -> int:
    return engine.player.source_marker_store.value(
        "technique", source_instance_key, marker_id, scope)


func _charging_value(engine, slot_instance_id: String) -> int:
    return int(engine.effect_ports.technique_charging_state(
        engine.player, slot_instance_id).get("current_value", 0))
