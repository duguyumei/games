extends "res://tests/support/expanded_technique_test_base.gd"

const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")
const BattleRuntimeMutationTransactionScript = preload(
    "res://core/battle_runtime_mutation_transaction.gd")
const QiCardInstanceDataScript = preload("res://core/qi_card_instance_data.gd")


class FixtureCatalog:
    extends RefCounted

    var base_catalog
    var definitions: Dictionary = {}

    func _init(base, values: Dictionary) -> void:
        base_catalog = base
        definitions = values.duplicate(true)

    func get_by_id(source_kind: String, content_id: String) -> Dictionary:
        var key := "%s:%s" % [source_kind, content_id]
        if definitions.has(key):
            return definitions[key].duplicate(true)
        return base_catalog.get_by_id(source_kind, content_id)

    func has_id(source_kind: String, content_id: String) -> bool:
        return definitions.has("%s:%s" % [source_kind, content_id]) \
            or base_catalog.has_id(source_kind, content_id)


class FailingEventHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    func behavior_id() -> String:
        return "fixture_failing_event"

    func supported_hooks() -> Array[String]:
        return ["card_moved", "effect_card_batch_committed"]

    func validate_configuration(configuration: Dictionary) -> Array[String]:
        return [] if str(configuration.get("hook", "")) in supported_hooks() \
            else ["fixture failing event hook 无效"] as Array[String]

    func handle(hook: String, _context, configuration: Dictionary) -> Dictionary:
        if hook != str(configuration.get("hook", "")):
            return {"success": true}
        return {"success": false, "reason": "合成 committed 失败"}


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_catalog_and_unified_ownership()
    _test_disposition_replacement_and_rollback()
    _test_draw_depletion_transaction()
    _test_temporary_blazing_and_status_pipeline()
    _test_growth_plan_event_and_removed_state_claim()
    _test_temporary_clone_and_effect_batch_summary()
    _finish("CARD ZONE AND QI LIFECYCLE PLATFORM TEST")


func _test_catalog_and_unified_ownership() -> void:
    var engine = _fixture_engine(81001, [])
    _assert_true(engine.passive_rule_registry.has_handler(
        "card_lifecycle_policy"), "统一 Registry 登记牌区生命周期策略 Handler")
    for hook in [
            "card_disposition_replacement_query",
            "draw_depletion_replacement_query",
            "card_lifecycle_removed_state_claim",
            "growth_trigger_execution_plan"]:
        _assert_true(engine.passive_rule_registry.has_hook(hook),
            "统一 PassiveRuleRuntime 登记 %s" % hook)
    _assert_true(BattleEventCatalogScript.is_committed(
        "growth_trigger_resolved"), "成长结果使用 canonical committed 事件")
    _assert_true(BattleEventCatalogScript.is_committed(
        "effect_card_batch_committed"), "效果牌批次使用 canonical committed 事件")
    _assert_true("growth_trigger_resolved" not in \
        BattleEventCatalogScript.RESPONSE_ONLY_EVENTS,
        "成长结果不是平行 response-only 事件")


func _test_disposition_replacement_and_rollback() -> void:
    var engine = _fixture_engine(81002, ["fixture_bottom"])
    var facts: Array = _committed_facts(engine)
    var bottom = _bound_card(engine, "5", "forest")
    engine.player.hand = [bottom]
    var moved: Dictionary = engine.player.card_zone_service.move_card(
        engine.player, "hand", "discard_pile", bottom,
        "explicit_discard", _metadata("disposition-bottom"))
    _assert_true(moved.get("success", false), "明确弃牌可被来源中立规则替换")
    _assert_equal(moved.get("to"), "draw_pile", "处置替换最终进入牌库")
    _assert_equal(engine.player.draw_pile.front(), bottom, "替换牌稳定置于牌库底")
    var moved_fact := _last_fact(facts, "card_moved")
    _assert_equal(moved_fact.get("reason"), "explicit_discard",
        "替换后保留原始明确弃置 reason")
    _assert_true(moved_fact.get("logical_explicit_discard", false),
        "替换后保留逻辑明确弃置事实")
    _assert_equal(moved_fact.get("final_destination"), "draw_pile",
        "committed 事实公开替换后的最终牌区")
    _assert_equal(_facts_of_kind(facts, "card_explicitly_discarded").size(), 1,
        "处置替换仍只发布一份明确弃置事实")

    engine.player.equipped_inner_skill_ids.assign(["fixture_permanent"])
    var permanent = _bound_card(engine, "6", "mountain")
    engine.player.hand.append(permanent)
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        [engine.player], engine.battle_passive_event_service,
        engine.trigger_queue, engine.rng)
    moved = engine.player.card_zone_service.move_card(
        engine.player, "hand", "discard_pile", permanent,
        "explicit_discard", _metadata("disposition-permanent"))
    _assert_true(moved.get("success", false) \
        and moved.get("to") == "permanently_removed",
        "处置替换可移出本局永久牌组工作副本")
    _assert_true(engine.player.permanently_removed_card_ids.has(permanent.id),
        "永久移出只写 BattleSide 工作副本")
    BattleRuntimeMutationTransactionScript.rollback(transaction)
    _assert_true(engine.player.hand.has(permanent), "外层事务回滚恢复原牌区")
    _assert_true(not engine.player.permanently_removed_card_ids.has(permanent.id),
        "外层事务回滚恢复本局永久牌组工作副本")

    engine.player.equipped_inner_skill_ids.assign([
        "fixture_permanent", "fixture_bottom"])
    var ordered = _bound_card(engine, "7", "wind")
    engine.player.hand.append(ordered)
    moved = engine.player.card_zone_service.move_card(
        engine.player, "hand", "discard_pile", ordered,
        "explicit_discard", _metadata("disposition-order"))
    _assert_equal(moved.get("to"), "permanently_removed",
        "多个替换来源按稳定 Invocation 顺序只取第一个")

    engine.player.equipped_inner_skill_ids.assign(["fixture_bottom"])
    var void_card = _bound_card(engine, "8", "fire")
    engine.player.hand.append(void_card)
    engine.status_system.apply_card_anomaly(
        void_card, "mark", "void", {}, "专项", 1, false,
        _holder_metadata(engine, "void-priority"))
    moved = engine.player.card_zone_service.move_card(
        engine.player, "hand", "discard_pile", void_card,
        "explicit_discard", _metadata("void-priority"))
    _assert_true(moved.get("dispersed", false), "虚无消散优先于处置替换")
    _assert_true(engine.player.temporarily_removed_cards.has(void_card) \
        and not engine.player.draw_pile.has(void_card),
        "虚无真气不能被替换规则救回牌库")

    engine.player.equipped_inner_skill_ids.assign(["fixture_invalid_disposition"])
    var invalid = _bound_card(engine, "9", "forest")
    engine.player.hand.append(invalid)
    moved = engine.player.card_zone_service.move_card(
        engine.player, "hand", "discard_pile", invalid,
        "explicit_discard", _metadata("invalid-disposition"))
    _assert_true(not moved.get("success", true), "无效替换去向明确失败")
    _assert_true(engine.player.hand.has(invalid), "替换查询失败不修改牌区")
    _disconnect_facts(engine)


func _test_draw_depletion_transaction() -> void:
    var engine = _fixture_engine(81003, [
        "fixture_depletion_a", "fixture_depletion_b"])
    var first = _bound_card(engine, "2", "wind")
    var second = _bound_card(engine, "3", "forest")
    engine.player.discard_pile = [first, second]
    var drawn: Array = engine.player.draw(
        1, "fixture_draw", _metadata("depletion-success"))
    _assert_equal(drawn.size(), 1, "牌库耗尽后洗回并继续原抽牌数量")
    _assert_equal(engine.player.discard_pile.size(), 0, "耗尽替换洗回完整弃牌堆")
    _assert_equal(engine.player.draw_pile.size(), 1, "继续抽牌后保留未抽到真气")
    _assert_equal(engine.player.last_draw_result.get(
        "depletion_receipts", []).size(), 1, "抽牌结果保存耗尽替换回执")
    _assert_equal(str(engine.player.last_draw_result[
        "depletion_receipts"][0].get("source_instance_key", "")),
        "inner:player:0:fixture_depletion_a",
        "多个耗尽来源按稳定 Invocation 顺序使用第一个")
    var counter_after: Dictionary = \
        engine.player.battle_passive_counter_store.capture_state()
    engine.player.draw_pile.clear()
    engine.player.discard_pile.clear()
    drawn = engine.player.draw(1, "fixture_draw", _metadata("depletion-empty"))
    _assert_true(drawn.is_empty(), "牌库与弃牌堆都为空时保持原停止行为")
    _assert_equal(engine.player.battle_passive_counter_store.capture_state(),
        counter_after, "空弃牌堆不消费耗尽来源机会")

    var failing = _fixture_engine(81004, [
        "fixture_depletion_a", "fixture_fail_card_moved"])
    failing.passive_rule_registry.register_handler(FailingEventHandler.new())
    var rollback_card = _bound_card(failing, "4", "fire")
    failing.player.discard_pile = [rollback_card]
    var state_before: Dictionary = failing.player.capture_passive_query_state()
    var event_before: Dictionary = failing.battle_passive_event_service \
        .capture_transaction_state()
    var rng_before := int(failing.rng.state)
    drawn = failing.player.draw(
        1, "fixture_draw", _metadata("depletion-failure"))
    _assert_true(drawn.is_empty() \
        and not failing.player.last_draw_result.get("success", true),
        "耗尽事务中 committed 失败向抽牌边界传播")
    var expected_state: Dictionary = state_before.duplicate(true)
    expected_state["last_draw_result"] = failing.player.last_draw_result.duplicate(true)
    _assert_equal(failing.player.capture_passive_query_state(), expected_state,
        "耗尽失败恢复牌区、状态、计数器及批次缓冲")
    _assert_equal(failing.battle_passive_event_service.capture_transaction_state(),
        event_before, "耗尽失败恢复 committed receipt 与事件序列")
    _assert_equal(int(failing.rng.state), rng_before, "耗尽失败恢复 RNG")


func _test_temporary_blazing_and_status_pipeline() -> void:
    var engine = _fixture_engine(81005, [])
    var card = _bound_card(engine, "5", "fire")
    engine.player.hand = [card]
    var metadata := _holder_metadata(engine, "temporary-blazing")
    engine.status_system.apply_card_anomaly(
        card, "buff", "qi_heat", {}, "普通炽气", 2, false, metadata)
    _assert_true(engine.status_system.add_temporary_blazing_layers(
        card, "inner:fixture:a", 3, "临时炽气A", metadata).get(
            "success", false), "临时炽气通过统一状态入口写入")
    engine.status_system.add_temporary_blazing_layers(
        card, "item:fixture:b", 4, "临时炽气B", metadata)
    _assert_equal(card.normal_blazing_layers(), 2, "普通炽气层数独立查询")
    _assert_equal(card.temporary_blazing_layers_total(), 7,
        "不同来源临时炽气稳定聚合")
    _assert_equal(card.total_blazing_layers(), 9, "总炽气包含普通与临时来源层")
    _assert_equal(engine.effect_ports.current_effective_qi(engine.player, card), 14,
        "统一有效真气值管线加算所有炽气来源")

    engine.status_system.apply_card_anomaly(
        card, "buff", "flourish", {}, "焕发", 1, false, metadata)
    _assert_equal(engine.effect_ports.current_effective_qi(engine.player, card), 28,
        "焕发在加减完成后统一令有效真气值乘二")
    engine.status_system.apply_card_anomaly(
        card, "debuff", "burned_out", {}, "燃尽", 1, false, metadata)
    _assert_equal(engine.effect_ports.current_effective_qi(engine.player, card), 0,
        "燃尽作为 debuff 最后覆盖焕发并归零")
    engine.status_system.remove_card_anomaly(
        card, "debuff", "burned_out", "移除燃尽", metadata)
    _assert_equal(engine.effect_ports.current_effective_qi(engine.player, card), 28,
        "移除燃尽后恢复同一有效值管线结果")

    engine.player.card_zone_service.move_card(
        engine.player, "hand", "draw_pile", card, "effect", metadata)
    _assert_equal(card.temporary_blazing_layers_total(), 7,
        "非弃牌堆牌区移动不清临时炽气")
    engine.player.card_zone_service.move_card(
        engine.player, "draw_pile", "discard_pile", card, "effect", metadata)
    _assert_equal(card.temporary_blazing_layers_total(), 0,
        "真正进入弃牌堆只清临时炽气")
    _assert_equal(card.normal_blazing_layers(), 2, "进入弃牌堆保留普通炽气")
    _assert_true(card.has_anomaly("buff", "flourish"), "焕发跨牌区移动保留")

    engine.status_system.add_temporary_blazing_layers(
        card, "inner:fixture:snapshot", 5, "快照", metadata)
    var state: Dictionary = engine.player.capture_passive_query_state()
    card.clear_temporary_blazing_layers()
    engine.player.replace_passive_query_state(state)
    _assert_equal(card.temporary_blazing_layers.get(
        "inner:fixture:snapshot"), 5, "BattleSide 快照完整恢复临时来源层")
    var dto := QiCardInstanceDataScript.capture(card, true)
    var restored = QiCardInstanceDataScript.restore(
        dto, engine.content_catalog.card_reshape_rules)
    _assert_equal(restored.temporary_blazing_layers,
        card.temporary_blazing_layers, "战斗真气 DTO 往返临时炽气来源")
    _assert_true(not QiCardInstanceDataScript.capture(card).has(
        "temporary_blazing_layers"), "Run 真气 DTO 不保存临时炽气")
    engine.status_system.apply_card_anomaly(
        card, "mark", "purification", {}, "净化", 1, false, metadata)
    _assert_equal(card.temporary_blazing_layers_total(), 0,
        "统一净化协议清除临时炽气")
    engine.status_system.add_temporary_blazing_layers(
        card, "inner:fixture:battle_end", 2, "战斗结束", metadata)
    engine.status_system.card_anomaly_service.on_card_battle_end(card)
    _assert_equal(card.temporary_blazing_layers_total(), 0,
        "战斗结束统一清理全部临时来源层")


func _test_growth_plan_event_and_removed_state_claim() -> void:
    var engine = _fixture_engine(81006, [
        "fixture_growth_a", "fixture_growth_b",
        "fixture_claim_a", "fixture_claim_b"])
    var facts: Array = _committed_facts(engine)
    var card = _bound_card(engine, "6", "forest")
    engine.player.hand = [card]
    engine.status_system.apply_card_anomaly(
        card, "buff", "growth", {}, "成长准备", 2, false,
        _holder_metadata(engine, "growth-plan"))
    facts.clear()
    var result: Dictionary = engine.status_system.card_status_behavior_service \
        .on_turn_end(engine.player)
    _assert_true(result.get("success", false), "成长普通与额外计划整体提交")
    _assert_equal(card.anomaly_layers("buff", "qi_heat"), 6,
        "两个来源副本各增加一次成长触发且不递归")
    var growth_facts := _facts_of_kind(facts, "growth_trigger_resolved")
    _assert_equal(growth_facts.size(), 3, "每次实际成长触发各一份 committed 事实")
    _assert_equal(growth_facts.map(func(value): return value["growth_layers"]),
        [2, 2, 2], "每份成长事实记录参与层数")
    _assert_equal(growth_facts.map(func(value): return value["extra_trigger"]),
        [false, true, true], "成长事实区分普通与额外触发")
    _assert_equal(growth_facts.map(func(value):
        return value["source_instance_key"]), [
            "card_status:%s:growth" % card.id,
            "inner:player:0:fixture_growth_a",
            "inner:player:1:fixture_growth_b",
        ], "额外成长按稳定 Invocation 顺序记录来源")

    var claim_card = _bound_card(engine, "7", "mountain")
    engine.player.hand = [claim_card]
    engine.status_system.apply_card_anomaly(
        claim_card, "buff", "growth", {}, "认领准备", 3, false,
        _holder_metadata(engine, "claim"))
    facts.clear()
    result = engine.player.card_zone_service.move_card(
        engine.player, "hand", "discard_pile", claim_card,
        "explicit_discard", _metadata("claim"))
    _assert_true(result.get("success", false), "带可移除状态真气进入弃牌堆")
    var state_fact := _last_fact(facts, "card_state_changed")
    _assert_true(state_fact.get("claim_consumed", false),
        "生命周期清理前的一次性 claim 被成功认领")
    _assert_equal(state_fact.get("claim_source_instance_key"),
        "inner:player:2:fixture_claim_a", "第一个匹配来源独占 claim")
    _assert_equal(state_fact.get("claimed_entries", []).size(), 1,
        "同批被移除状态只交给一个来源一次")
    _assert_equal(state_fact.get("claimed_entries", [])[0].get("layers"), 3,
        "claim 冻结实际待移除成长层数")
    _assert_true(not claim_card.has_anomaly("buff", "growth"),
        "认领不阻止原生命周期清理")

    var left_engine = _fixture_engine(81007, ["fixture_growth_left"])
    var left = _bound_card(left_engine, "2", "wind")
    var right = _bound_card(left_engine, "3", "wind")
    left_engine.player.hand = [left, right]
    left_engine.status_system.apply_card_anomaly(
        right, "buff", "growth", {}, "最左测试", 1, false,
        _holder_metadata(left_engine, "growth-left"))
    left_engine.status_system.card_status_behavior_service.on_turn_end(
        left_engine.player)
    _assert_equal(right.anomaly_layers("buff", "qi_heat"), 1,
        "成长计划上下文可判断非最左手牌并拒绝额外触发")
    _disconnect_facts(engine)


func _test_temporary_clone_and_effect_batch_summary() -> void:
    var engine = _fixture_engine(81008, ["fixture_bottom"])
    var source = _bound_card(engine, "9", "fire")
    source.reshape_origin = {"id": "attribute_change", "payload": {
        "attribute": "forest"}}
    source.reshape_enhancement = "momentum"
    source.reshape_imprint = "poison"
    source.reshape_others = {"absolute_void": {}}
    source.origin_base_identity = {
        "definition_id": source.definition_id,
        "rank_name": source.rank_name,
        "rank_order": source.rank_order,
        "qi_value": source.qi_value,
        "attribute": source.attribute,
        "attribute_name": source.attribute_name,
    }
    source.set_anomaly("state", "poison")
    source.temporary_reshapes["attribute"] = "mountain"
    source.add_temporary_blazing_layers("inner:fixture:clone", 4)
    engine.player.hand = [source]
    var clone = engine.effect_ports.generate_temporary_normal_card(
        engine.player, source, {
            "clone_source": true,
            "source_kind": "inner_skill",
            "source_id": "fixture_clone",
            "source_name": "合成复制",
            "source_instance_key": "inner:player:fixture_clone",
            "action_token": "clone-action",
        })
    _assert_true(clone != null and clone.id != source.id,
        "临时复制生成稳定唯一新实例")
    _assert_equal(clone.persistent_reshape_state(),
        source.persistent_reshape_state(), "临时复制保留永久重塑")
    _assert_true(clone.has_anomaly("mark", "void"), "临时复制默认带虚无")
    _assert_true(not clone.has_anomaly("state", "poison"),
        "临时复制不复制战斗异状")
    _assert_equal(clone.temporary_reshapes,
        {"enhancement": "", "attribute": "", "rank": {}},
        "临时复制不复制临时重塑")
    _assert_equal(clone.temporary_blazing_layers_total(), 0,
        "临时复制不复制临时炽气来源层")

    var facts: Array = _committed_facts(engine)
    var normal = _bound_card(engine, "4", "forest")
    var void_card = _bound_card(engine, "5", "fire")
    engine.player.hand = [normal, void_card]
    engine.status_system.apply_card_anomaly(
        void_card, "mark", "void", {}, "批次虚无", 1, false,
        _holder_metadata(engine, "effect-batch"))
    facts.clear()
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "action_token": "effect-batch-action",
        "technique_execution_token": "tech-exec-batch",
        "source_kind": "technique",
        "source_id": "fixture_batch",
        "source_name": "合成批次",
        "source_instance_key": "technique:fixture_batch",
        "trigger_mode": "manual",
    })
    var executed: Dictionary = engine.effect_executor.execute_all(
        [{"op": "discard_all_hand"}], context)
    _assert_true(executed.get("success", false), "同一效果批量弃牌成功")
    var batch_facts := _facts_of_kind(facts, "effect_card_batch_committed")
    _assert_equal(batch_facts.size(), 1, "同一 effect execution token 只汇总一次")
    var batch: Dictionary = batch_facts[0]
    _assert_equal(batch.get("actual_moved_count"), 2,
        "批次汇总只计入实际提交的两张真气")
    _assert_equal(batch.get("actual_explicit_discard_count"), 2,
        "批次汇总保留逻辑明确弃置数量")
    _assert_equal(batch.get("source_kind"), "technique",
        "批次汇总保留原效果来源")
    _assert_equal(batch.get("card_entries", []).map(func(value):
        return value["final_destination"]),
        ["draw_pile", "temporarily_removed"],
        "批次汇总按 committed 顺序记录替换与虚无最终牌区")

    var failing = _fixture_engine(81009, [
        "fixture_bottom", "fixture_fail_batch"])
    failing.passive_rule_registry.register_handler(FailingEventHandler.new())
    var one = _bound_card(failing, "6", "forest")
    var two = _bound_card(failing, "7", "fire")
    failing.player.hand = [one, two]
    var failed_facts: Array = _committed_facts(failing)
    var before_event: Dictionary = failing.battle_passive_event_service \
        .capture_transaction_state()
    context = EffectContextScript.new().configure({
        "ports": failing.effect_ports,
        "actor": failing.player,
        "target": failing.enemy,
        "action_token": "effect-batch-fail",
        "technique_execution_token": "tech-exec-fail",
        "source_kind": "technique",
        "source_id": "fixture_batch",
        "source_name": "失败批次",
        "source_instance_key": "technique:fixture_batch",
    })
    executed = failing.effect_executor.execute_all(
        [{"op": "discard_all_hand"}], context)
    _assert_true(not executed.get("success", true), "批次汇总失败使效果正式失败")
    _assert_equal(failing.player.hand, [one, two],
        "整效果事务回滚已提交的逐牌移动")
    _assert_true(failing.player.draw_pile.is_empty() \
        and failing.player.discard_pile.is_empty(),
        "批次失败不留下替换后的最终牌区")
    _assert_true(failed_facts.is_empty(), "批次失败不发布逐牌或汇总事实")
    _assert_equal(failing.battle_passive_event_service.capture_transaction_state(),
        before_event, "批次失败恢复 receipt、事件序列与 publication")
    _assert_true(failing.player.card_zone_service.capture_runtime_state().get(
        "effect_batch_entries", {}).is_empty(), "批次失败清除临时汇总缓冲")
    _disconnect_facts(engine)
    _disconnect_facts(failing)


func _fixture_engine(seed_value: int, source_ids: Array):
    var engine = _engine(seed_value)
    engine.passive_rule_runtime.source_resolver._catalog = FixtureCatalog.new(
        engine.content_catalog, _fixture_definitions())
    engine.player.equipped_inner_skill_ids.assign(source_ids)
    return engine


func _fixture_definitions() -> Dictionary:
    return {
        "inner_skill:fixture_bottom": _policy_definition(
            "fixture_bottom", [{
                "hook": "card_disposition_replacement_query",
                "destination": "draw_pile_bottom",
                "reasons": ["explicit_discard", "normal_play"],
            }]),
        "inner_skill:fixture_permanent": _policy_definition(
            "fixture_permanent", [{
                "hook": "card_disposition_replacement_query",
                "destination": "permanently_removed",
                "explicit_discard_only": true,
            }]),
        "inner_skill:fixture_invalid_disposition": _policy_definition(
            "fixture_invalid_disposition", [{
                "hook": "card_disposition_replacement_query",
                "destination": "invalid",
            }]),
        "inner_skill:fixture_depletion_a": _policy_definition(
            "fixture_depletion_a", [{
                "hook": "draw_depletion_replacement_query",
                "maximum_uses": 1,
            }], "depletion_a"),
        "inner_skill:fixture_depletion_b": _policy_definition(
            "fixture_depletion_b", [{
                "hook": "draw_depletion_replacement_query",
                "maximum_uses": 2,
            }], "depletion_b"),
        "inner_skill:fixture_growth_a": _policy_definition(
            "fixture_growth_a", [{
                "hook": "growth_trigger_execution_plan",
                "additional_triggers": 1,
            }]),
        "inner_skill:fixture_growth_b": _policy_definition(
            "fixture_growth_b", [{
                "hook": "growth_trigger_execution_plan",
                "additional_triggers": 1,
            }]),
        "inner_skill:fixture_growth_left": _policy_definition(
            "fixture_growth_left", [{
                "hook": "growth_trigger_execution_plan",
                "additional_triggers": 1,
                "requires_leftmost": true,
            }]),
        "inner_skill:fixture_claim_a": _policy_definition(
            "fixture_claim_a", [{
                "hook": "card_lifecycle_removed_state_claim",
                "state_ids": ["growth"],
            }]),
        "inner_skill:fixture_claim_b": _policy_definition(
            "fixture_claim_b", [{
                "hook": "card_lifecycle_removed_state_claim",
                "state_ids": ["growth"],
            }]),
        "inner_skill:fixture_fail_card_moved": _failing_definition(
            "fixture_fail_card_moved", "card_moved"),
        "inner_skill:fixture_fail_batch": _failing_definition(
            "fixture_fail_batch", "effect_card_batch_committed"),
    }


func _policy_definition(
        content_id: String, rules: Array, state_key: String = "") -> Dictionary:
    var behavior := {
        "id": "card_lifecycle_policy",
        "configuration": {"rules": rules.duplicate(true)},
    }
    if state_key != "":
        behavior["state_key"] = state_key
    return {
        "id": content_id,
        "name": content_id,
        "behaviors": [behavior],
    }


func _failing_definition(content_id: String, hook: String) -> Dictionary:
    return {
        "id": content_id,
        "name": content_id,
        "behaviors": [{
            "id": "fixture_failing_event",
            "configuration": {"hook": hook},
        }],
    }


func _bound_card(engine, rank: String, attribute: String):
    var card = _card(rank, attribute)
    card.configure_reshape_rule_service(engine.content_catalog.card_reshape_rules)
    engine.player.card_zone_service.bind_card_policies(engine.player, card)
    return card


func _metadata(action_token: String) -> Dictionary:
    return {
        "source_kind": "technique",
        "source_id": "fixture_zone_effect",
        "source_name": "合成牌区效果",
        "source_instance_key": "technique:fixture_zone_effect",
        "trigger_mode": "manual",
        "action_token": action_token,
        "effect_execution_token": "%s:effect:0" % action_token,
    }


func _holder_metadata(engine, action_token: String) -> Dictionary:
    var result := _metadata(action_token)
    result["holder"] = engine.player
    result["actor"] = engine.player
    result["source_actor"] = engine.player
    return result


func _committed_facts(engine) -> Array:
    var facts: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            var entry := values.duplicate(true)
            entry["_kind"] = kind
            facts.append(entry))
    return facts


func _facts_of_kind(facts: Array, kind: String) -> Array:
    return facts.filter(func(value): return str(value.get("_kind", "")) == kind)


func _last_fact(facts: Array, kind: String) -> Dictionary:
    var matching := _facts_of_kind(facts, kind)
    return matching.back() if not matching.is_empty() else {}


func _disconnect_facts(engine) -> void:
    for connection in engine.battle_passive_event_service \
            .event_committed.get_connections():
        engine.battle_passive_event_service.event_committed.disconnect(
            connection["callable"])
