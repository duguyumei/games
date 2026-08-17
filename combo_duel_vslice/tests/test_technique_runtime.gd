extends SceneTree

const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const QiCardScript = preload("res://core/qi_card.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")
const TechniqueRepositoryScript = preload("res://core/technique_repository.gd")
const CombatEngineScript = preload("res://core/combat_engine.gd")
const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectValueResolverScript = preload("res://core/effects/effect_value_resolver.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const TechniqueLoadoutPolicyScript = preload(
    "res://core/technique_loadout_policy.gd")
const SequenceBookScript = preload("res://core/sequence_book.gd")
const SourceMarkerStoreScript = preload("res://core/source_marker_store.gd")
const RunProgressSnapshotScript = preload("res://core/run_progress_snapshot.gd")
const AiBattleStateProjectorScript = preload(
    "res://core/ai/ai_battle_state_projector.gd")
const AiHistoryProjectorScript = preload("res://core/ai/ai_history_projector.gd")
const BattleSideSnapshotScript = preload("res://core/battle_side_snapshot.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const UiMainScript = preload("res://ui/main.gd")
const RunBuildQueryServiceScript = preload("res://core/run_build_query_service.gd")
const PassiveRuleHandlerRegistryScript = preload(
    "res://core/passives/passive_rule_handler_registry.gd")
const PassiveRuleRuntimeScript = preload(
    "res://core/passives/passive_rule_runtime.gd")
const PassiveIntPolicyResolverScript = preload(
    "res://core/passives/passive_int_policy_resolver.gd")

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]
const POOL_MEMBERSHIP := {
    "high_card": ["high"],
    "pair": ["pair"],
    "two_pair": ["pair"],
    "three_kind": ["three"],
    "straight": ["straight"],
    "full_house": ["pair", "three"],
    "four_kind": ["bomb"],
    "five_kind": ["bomb"],
}

var failures: Array[String] = []
var assertions: int = 0
var card_serial: int = 0
var tracked_engines: Array = []

class LoadoutQueryResult:
    extends RefCounted
    var values: Dictionary
    func _init(source: Dictionary) -> void:
        values = source
    func to_dict() -> Dictionary:
        return values.duplicate(true)

class LoadoutLimitTwoResolver:
    extends RefCounted
    var calls: Array[Dictionary] = []
    func resolve(request):
        calls.append(request.to_dict())
        return LoadoutQueryResult.new({
            "success": true,
            "hook": request.hook,
            "subject_kind": request.subject_kind,
            "subject_id": request.subject_id,
            "base_value": request.base_value,
            "effective_value": 2 if request.subject_id == "normal_probe" \
                else request.base_value,
            "modifier_breakdown": [],
            "source_fingerprint": "fake_limit_two",
        })

class LoadoutCatalog:
    extends RefCounted
    var techniques: Dictionary = {}
    var items: Dictionary = {}
    var statuses: Dictionary = {}
    var sequences: Dictionary = {}
    func _init() -> void:
        var hands := [
            "high_card", "pair", "two_pair", "three_kind", "straight",
            "full_house", "four_kind", "five_kind"]
        techniques = {
            "basic_scatter": {
                "id": "basic_scatter", "name": "散招", "pool": "universal",
                "built_in": true, "base_loadout_limit": 99,
                "eligible_hand_ids": hands.duplicate(),
                "built_in_fallback_order": 0,
            },
            "basic_guard": {
                "id": "basic_guard", "name": "守招", "pool": "universal",
                "built_in": true, "base_loadout_limit": 99,
                "eligible_hand_ids": hands.duplicate(),
                "built_in_fallback_order": 1,
            },
            "normal_probe": {
                "id": "normal_probe", "name": "普通探针", "pool": "pair",
                "built_in": false, "base_loadout_limit": 1,
                "eligible_hand_ids": [],
            },
        }
        statuses = {
            "basic_scatter": "formal_complete",
            "basic_guard": "formal_complete",
            "normal_probe": "formal_complete",
        }
        items = {
            "insight_gain_probe": {
                "id": "insight_gain_probe",
                "name": "心得增量探针",
                "behaviors": [{
                    "id": "insight_slot_gain_probe",
                    "configuration": {"delta": 1},
                }],
            },
        }
        for hand_id in hands:
            sequences[hand_id] = ["basic_scatter"]
    func get_by_id(kind: String, content_id: String) -> Dictionary:
        if kind == "technique":
            return techniques.get(content_id, {}).duplicate(true)
        if kind == "item":
            return items.get(content_id, {}).duplicate(true)
        return {}
    func definition(key: String) -> Dictionary:
        if key == "sequences":
            return sequences.duplicate(true)
        if key == "techniques":
            return {
                "techniques": techniques.values(),
                "integration_statuses": statuses.duplicate(true),
                "pool_membership": {
                    "high_card": ["high"], "pair": ["pair"],
                    "two_pair": ["pair"], "three_kind": ["three"],
                    "straight": ["straight"], "full_house": ["pair", "three"],
                    "four_kind": ["bomb"], "five_kind": ["bomb"],
                },
            }
        return {}
    func all_of(kind: String) -> Array:
        return techniques.values() if kind == "technique" else []

class EmptyInnerLoadoutService:
    extends RefCounted
    func get_loadout(_editable: bool = true, _blocked_reason: String = "") -> Dictionary:
        return {}

class InsightSlotGainProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    var requests: Array[Dictionary] = []

    func behavior_id() -> String:
        return "insight_slot_gain_probe"

    func supported_hooks() -> Array[String]:
        return ["insight_slot_gain_query"] as Array[String]

    func handle(_hook: String, context, configuration: Dictionary) -> Dictionary:
        var request = context.payload.get("int_query")
        requests.append(request.to_dict())
        return {
            "success": true,
            "value": int(context.payload.get("current_value", 0)) \
                + int(configuration.get("delta", 0)),
        }

func _initialize() -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    _test_empty_repository_and_production_data()
    _test_power_snapshot_formula_and_initial_power_reader()
    _test_empty_and_failed_techniques_leave_momentum_untouched()
    _test_unchanged_momentum_is_used_then_cleared()
    _test_changed_momentum_is_used_then_preserved()
    _test_retrigger_reuses_frozen_snapshot()
    _test_delayed_effect_reuses_frozen_snapshot()
    _test_reflection_override_sources_and_recursion_guard()
    _test_defense_decay_return_records()
    _test_action_resolution_results_and_no_life_loss_disruption()
    _test_synchronized_reflection_matches_normal_damage()
    _test_unblockable_damage_still_absorbs_and_reflects()
    _test_all_insights_grow_empty_slots()
    _test_s2f6a_basic_techniques_and_loadout_limits()
    _test_permanent_loadout_capacity_insight_and_runtime_compatibility()
    _test_stable_slots_temporary_insert_and_call_orders()
    _test_source_markers_life_and_defense_ports()
    _test_manual_advance_only_suppresses_effects()
    _test_automatic_trigger_uses_special_p0_and_nested_order()
    _test_equipped_max_life_marker_and_snapshot_migration()
    _test_poison_damage_modifiers_apply_per_segment()
    _test_normal_automatic_technique_manual_effects()
    _test_automatic_multi_threshold_and_event_idempotency()
    _test_automatic_opponent_event_multi_marker_batches_and_source_kind()
    _test_nested_invocation_recursion_and_options()
    _test_invocation_rejection_does_not_move_slot()
    _test_invocation_choice_resume_freezes_randomness()
    _test_manual_automatic_invoked_resolution_consistency()
    _test_battle_session_invocation_choice_resume()
    _test_source_marker_response_and_private_projections()
    _test_temporary_slots_do_not_duplicate_run_max_life()
    _dispose_tracked_engines()
    if failures.is_empty():
        print("TECHNIQUE TEST PASS: %d assertions" % assertions)
        quit(0)
        return
    for failure in failures:
        push_error("TECHNIQUE TEST FAIL: %s" % failure)
    quit(1)

func _test_empty_repository_and_production_data() -> void:
    var repository = TechniqueRepositoryScript.new()
    _assert_true(repository.load_from_file(), "合法空功法仓库加载成功")
    _assert_true(repository.loaded_successfully, "空仓库与加载失败状态可区分")
    _assert_equal(repository.techniques.size(), 228, "正式功法仓库包含228门功法")
    _assert_equal(repository.resource_paths.size(), 228, "正式功法资源路径包含228项")
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.production())
    _assert_true(catalog.load_all(), "production 空功法内容完整通过校验")
    _assert_equal(
        catalog.definition("techniques")["integration_statuses"],
        repository.integration_statuses,
        "功法仓库与内容目录接入状态一致")
    for hand_id in HAND_IDS:
        _assert_equal(
            catalog.definition("sequences")[hand_id], ["basic_scatter"],
            "production %s 默认装备散招" % hand_id)
    for enemy in catalog.definition("enemies")["enemies"]:
        for hand_id in HAND_IDS:
            _assert_equal(enemy["sequences"][hand_id], [], "敌人功法序列为空")
    var technique_category: Dictionary = catalog.definition(
        "practice_shop")["normal"]["categories"][0]
    _assert_equal(technique_category["candidate_ids"].size(), 226, "商店包含226门非内建正式候选")
    var resource_count := 0
    for path in DirAccess.get_files_at("res://data/techniques"):
        if str(path).ends_with(".tres"):
            resource_count += 1
    _assert_equal(resource_count, 228, "正式目录存在228门正式功法资源")

func _test_power_snapshot_formula_and_initial_power_reader() -> void:
    var hand := HandEvaluatorScript.evaluate([
        _card("7", "wind"), _card("7", "fire")])
    var values := PowerCalculatorScript.calculate(hand, {
        "multiplier_bonus": 1,
        "power_fixed": -50,
        "power_amp_percent": -50,
        "insight_multiplier": 99,
    })
    _assert_equal(values["base_value"], 14, "C 为贡献层结算后的总和")
    _assert_true(not values.has("fixed_multiplier"), "固定牌型倍率字段已经退出")
    _assert_equal(values["attribute_concentration"], 1, "风火对子属性集中 N=1")
    _assert_equal(values["technique_multiplier"], 2, "乘势或机缘在 N 基础上进入 M")
    _assert_equal(values["baseline_value"], 14, "牌型基准值只读取 C")
    _assert_equal(values["initial_power"], 28, "P₀=floor(C×M)")
    _assert_equal(values["direct_power_fixed"], -50, "直接固定修正不进入 P₀")
    _assert_equal(values["direct_power_percent"], -50, "直接百分比不进入 P₀")
    _assert_equal(values["pre_momentum_power"], -11, "负的连势前功法值不提前截断")
    values = PowerCalculatorScript.apply_momentum(values, 10)
    _assert_equal(values["momentum_used"], 10, "成功功法记录连势快照")
    _assert_equal(values["technique_value"], 0, "最终 P 加入连势后统一截断")
    _assert_true(not values.has("unamplified_technique_value"), "旧混义功法值字段已删除")
    var context = EffectContextScript.new().configure({"values": values})
    var resolver = EffectValueResolverScript.new()
    _assert_equal(resolver.resolve({"kind": "initial_power"}, context), 28, "效果通用读取 P₀")
    _assert_equal(
        resolver.resolve({
            "kind": "initial_power_fraction", "numerator": 1, "denominator": 2}, context),
        14,
        "效果可以按比例读取 P₀")

    var effect_engine = _engine_with_cards([])
    var effect_context = EffectContextScript.new().configure({
        "ports": effect_engine.effect_ports,
        "actor": effect_engine.player,
        "target": effect_engine.enemy,
        "power": 0,
    })
    var direct_result: Dictionary = effect_engine.effect_executor.execute_all([
        {"op": "add_direct_power_fixed", "amount": {
            "kind": "constant", "value": 5}},
        {"op": "add_direct_power_percent", "amount": {
            "kind": "constant", "value": 25}},
    ], effect_context)
    _assert_true(direct_result["success"], "直接功法值修正操作继续通过通用效果链结算")
    _assert_equal(effect_engine.player.direct_power_fixed, 5, "固定直接功法值修正写入明确角色字段")
    _assert_equal(effect_engine.player.direct_power_percent, 25, "百分比直接功法值修正写入明确角色字段")

func _test_empty_and_failed_techniques_leave_momentum_untouched() -> void:
    var empty_engine = _engine_with_cards([_card("9", "wind")])
    empty_engine.player.momentum_value = 8
    empty_engine.player.last_successful_technique_hand_id = "pair"
    var empty_preview: Dictionary = empty_engine.preview([
        empty_engine.player.hand[0].id])
    _assert_equal(empty_preview["values"]["momentum_used"], 0, "空序列预览不使用连势")
    var empty_result: Dictionary = empty_engine.confirm_play([
        empty_engine.player.hand[0].id])
    _assert_true(empty_result["success"], "空序列仍可正常出牌")
    _assert_equal(empty_engine.player.momentum_value, 8, "空序列不清空连势")
    _assert_equal(
        empty_engine.player.last_successful_technique_hand_id,
        "pair",
        "空序列不更新上次成功牌型")

    var failed_engine = _probe_engine(
        [_card("8", "wind")],
        "high_card",
        [],
        {"pure_attribute": "fire"})
    failed_engine.player.momentum_value = 7
    failed_engine.player.last_successful_technique_hand_id = "pair"
    var failed_preview: Dictionary = failed_engine.preview([
        failed_engine.player.hand[0].id])
    _assert_equal(failed_preview["values"]["momentum_used"], 0, "条件失败预览不使用连势")
    var failed_result: Dictionary = failed_engine.confirm_play([
        failed_engine.player.hand[0].id])
    _assert_true(failed_result["success"], "条件失败只令功法失败，不阻止出牌")
    _assert_equal(failed_engine.player.momentum_value, 7, "条件失败不清空连势")
    _assert_equal(failed_engine.player.last_successful_technique_hand_id, "pair", "失败不更新牌型")

func _test_unchanged_momentum_is_used_then_cleared() -> void:
    var engine = _probe_engine([_card("6", "wind")], "high_card", [])
    engine.player.momentum_value = 5
    engine.player.last_successful_technique_hand_id = "high_card"
    var preview: Dictionary = engine.preview([engine.player.hand[0].id])
    var result: Dictionary = engine.confirm_play([engine.player.hand[0].id])
    _assert_true(result["technique_triggered"], "未改变连势的探针功法成功")
    _assert_equal(preview["values"]["initial_power"], result["preview"]["values"]["initial_power"], "预览与结算 P₀ 一致")
    _assert_equal(preview["values"]["momentum_used"], 5, "成功功法预览使用当前连势")
    _assert_equal(result["preview"]["values"]["momentum_used"], 5, "实际结算使用同一连势")
    _assert_equal(preview["values"]["technique_value"], result["preview"]["values"]["technique_value"], "预览与实际 P 一致")
    _assert_equal(engine.player.momentum_value, 0, "本门及回响未改变连势时结算后清空")
    _assert_equal(engine.player.last_successful_technique_hand_id, "high_card", "成功后更新精确牌型")

func _test_changed_momentum_is_used_then_preserved() -> void:
    var engine = _probe_engine([
        _card("5", "wind"), _card("5", "fire")],
        "pair",
        [{"op": "write_momentum", "operation": "add", "amount": {
            "kind": "initial_power_fraction", "numerator": 1, "denominator": 2}}])
    engine.player.momentum_value = 9
    engine.player.last_successful_technique_hand_id = "high_card"
    var ids := [engine.player.hand[0].id, engine.player.hand[1].id]
    var preview: Dictionary = engine.preview(ids)
    var expected_new := int(floor(preview["values"]["initial_power"] / 2.0))
    var result: Dictionary = engine.confirm_play(ids)
    _assert_true(result["technique_triggered"], "改变连势的探针功法成功")
    _assert_equal(result["preview"]["values"]["momentum_used"], 9, "成功功法完整使用冻结连势")
    _assert_equal(engine.player.momentum_value, 9 + expected_new, "本门实际增加连势后保留结算余量")
    _assert_equal(engine.player.last_successful_technique_hand_id, "pair", "成功牌型只记录行动历史")

func _test_retrigger_reuses_frozen_snapshot() -> void:
    var cards := [_card("4", "wind"), _card("4", "fire")]
    var engine = _probe_engine(cards, "pair", [{
        "op": "write_momentum", "operation": "add",
        "amount": {"kind": "initial_power"}},
        {"op": "draw", "count": 1}])
    engine.player.draw_pile = [_card("9", "mountain")]
    var retrigger_draw_events: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "card_drawn" \
                    and str(values.get("source_id", "")) == "probe_technique":
                retrigger_draw_events.append(values.duplicate(true)))
    var snapshot := {
        "initial_power": 31,
        "direct_power_fixed": 4,
        "direct_power_percent": 20,
        "pre_momentum_power": 42,
        "momentum_used": 7,
        "technique_value": 49,
    }
    var result: Dictionary = engine.action_resolver.retrigger_current_hand_technique(
        engine.player, engine.enemy, engine.sequence_book, snapshot, 6, [])
    _assert_true(result["triggered"], "同组重触内存探针成功")
    _assert_equal(engine.player.momentum_value, 31, "重触按冻结 P₀ 产生连势")
    _assert_equal(engine.sequence_book.position("pair"), 0, "重触自身不重复推进序列")
    _assert_equal(retrigger_draw_events.size(), 1, "重触功法通过真实效果链抽牌一次")
    if not retrigger_draw_events.is_empty():
        _assert_equal(
            str(retrigger_draw_events[0].get("source_kind", "")),
            "technique",
            "重触抽牌仍公开功法来源类别")
        _assert_equal(
            str(retrigger_draw_events[0].get("trigger_mode", "")),
            "retrigger",
            "重触抽牌独立公开 trigger_mode")
    _assert_equal(
        engine.effect_ports.technique_draw_count(engine.player), 1,
        "重触功法抽牌计入功法效果抽牌")

func _test_delayed_effect_reuses_frozen_snapshot() -> void:
    var engine = _engine_with_cards([])
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "values": {
            "initial_power": 23,
            "direct_power_fixed": 7,
            "direct_power_percent": 50,
            "pre_momentum_power": 45,
            "momentum_used": 8,
            "technique_value": 53,
        },
        "technique_id": "probe_delayed_snapshot",
        "technique_name": "延迟快照探针",
    })
    var registered: Dictionary = engine.status_system.register_delayed_effects(
        "延迟快照探针",
        "turn_end",
        1,
        [{"op": "write_momentum", "operation": "add",
            "amount": {"kind": "initial_power"}}],
        context)
    engine.player.momentum_value = 100
    engine.player.set_momentum(0)
    var resolved: Dictionary = (
        engine.status_system.status_delay_service.resolve_turn_end_effects(
            engine.player, 0))
    _assert_true(resolved["success"], "延迟效果恢复成功")
    _assert_equal(engine.player.momentum_value, 23, "延迟恢复保留冻结 P₀")
    _assert_equal(registered["record"]["power"], 53, "延迟记录保留最终 P")
    _assert_equal(registered["record"]["momentum_used"], 8, "延迟记录保留连势快照")

func _test_stable_slots_temporary_insert_and_call_orders() -> void:
    var book = SequenceBookScript.new()
    book.configure_with_capacities(
        {"high_card": ["a", "b", "c", "d"]}, {"high_card": 8})
    var original_ids: Array = book.ordered_slots("high_card").map(
        func(slot): return str(slot["slot_instance_id"]))
    var first_insert := _generate_test_temporary_slots(book,
        "high_card", "temp", 2, {"position": "after_current"})
    var second_insert := _generate_test_temporary_slots(book,
        "high_card", "temp", 2, {"position": "after_current"})
    _assert_equal(first_insert.size() + second_insert.size(), 4,
        "临时生成触发两次后只占用明确空余容量")
    var temporary_ids: Dictionary = {}
    for slot in first_insert + second_insert:
        temporary_ids[str(slot["slot_instance_id"])] = true
    _assert_equal(temporary_ids.size(), 4, "每份临时功法拥有唯一稳定槽位 ID")
    book.reset()
    _assert_equal(book.ordered_slots("high_card").size(), 4,
        "战斗重置删除全部临时槽位")
    _assert_equal(
        book.ordered_slots("high_card").map(func(slot): return str(slot["slot_instance_id"])),
        original_ids, "战斗重置恢复永久槽位稳定身份与原始顺序")

    var engine = _engine_with_cards([_card("9", "wind")])
    var definitions: Array = []
    for technique_id in ["a", "b", "c", "d"]:
        definitions.append({
            "id": technique_id, "name": technique_id.to_upper(),
            "pool": "high", "special": false, "effects": [],
        })
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": definitions,
    })
    engine.sequence_book.configure({"high_card": ["a", "b", "c", "d"]})
    var caller_slot: Dictionary = engine.sequence_book.current_slot("high_card")
    var runtime = EffectContextScript.new().configure({
        "ports": engine.effect_ports, "actor": engine.player,
        "target": engine.enemy,
        "hand_result": {"id": "high_card", "contributing": engine.player.hand},
        "played_cards": engine.player.hand, "values": {
            "initial_power": 9, "technique_value": 9,
        },
        "technique_id": "a", "technique_name": "A",
        "action_token": "call-order", "root_action_token": "call-order",
        "slot_instance_id": str(caller_slot["slot_instance_id"]),
        "sequence_book": engine.sequence_book,
        "card_identity_policy": engine.player.card_identity_policy,
    })
    var immediate: Dictionary = engine.technique_invocation_service.invoke({
        "selection": {"mode": "by_id", "hand_id": "high_card", "technique_id": "c"},
        "timing": "immediate", "check_condition": true,
        "gain_same_qi": false,
    }, runtime)
    _assert_true(immediate.get("success", false), "甲即时调用丙完整成功")
    engine.sequence_book.complete_slot(
        "high_card", str(caller_slot["slot_instance_id"]))
    _assert_equal(
        engine.sequence_book.ordered_slots("high_card").map(func(slot): return str(slot["technique_id"])),
        ["b", "d", "c", "a"], "甲即时调用丙后的最终序列为乙丁丙甲")

    engine.sequence_book.configure({"high_card": ["a", "b", "c", "d"]})
    caller_slot = engine.sequence_book.current_slot("high_card")
    runtime.slot_instance_id = str(caller_slot["slot_instance_id"])
    runtime.action_token = "call-after"
    runtime.root_action_token = "call-after"
    var delayed: Dictionary = engine.technique_invocation_service.invoke({
        "selection": {"mode": "by_id", "hand_id": "high_card", "technique_id": "c"},
        "timing": "after_caller_advance", "gain_same_qi": false,
    }, runtime)
    _assert_true(delayed.get("deferred", false), "推进后调用先冻结目标而不提前移动")
    engine.sequence_book.complete_slot(
        "high_card", str(caller_slot["slot_instance_id"]))
    var drained: Dictionary = engine.technique_invocation_service.resolve_after_caller_advance("call-after")
    _assert_true(drained.get("success", false), "调用者推进后成功结算冻结目标")
    _assert_equal(
        engine.sequence_book.ordered_slots("high_card").map(func(slot): return str(slot["technique_id"])),
        ["b", "d", "a", "c"], "推进后调用的最终序列为乙丁甲丙")

func _test_source_markers_life_and_defense_ports() -> void:
    var store = SourceMarkerStoreScript.new()
    _assert_true(store.write(
        "technique", "slot-a", "a", "charge", "battle", "add", 3,
        {"public": true, "display_name": "蓄力"})["success"],
        "功法来源标识写入成功")
    store.write("technique", "slot-a", "a", "guard", "battle", "set", 5,
        {"public": true, "display_name": "守势"})
    _assert_equal(store.entries().size(), 2, "同一功法可以同时保存多个标识")
    _assert_equal(store.public_projection().size(), 2, "多个公开标识全部进入投影")
    var appended: Dictionary = store.append_records(
        "technique", "slot-a", "a", "ordered", "battle", [
            {"initial_power":5, "hand_id":"pair"},
            {"initial_power":8, "hand_id":"straight"}],
        {"public":true, "display_name":"有序记录"})
    _assert_true(appended.get("success", false),
        "来源标识支持追加可序列化有序记录")
    _assert_equal(store.value(
        "technique", "slot-a", "ordered", "battle"), 2,
        "有序来源标识的公开值等于当前记录数")
    _assert_equal(store.records(
        "technique", "slot-a", "ordered", "battle").map(func(record):
            return str(record.get("hand_id", ""))), ["pair", "straight"],
        "有序来源标识保持追加顺序")
    var restored_store = SourceMarkerStoreScript.new()
    _assert_equal(restored_store.restore_snapshot(store.snapshot()), [],
        "有序来源标识通过统一快照往返")
    _assert_equal(restored_store.consume_records(
        "technique", "slot-a", "ordered", "battle", 1).get(
            "consumed_records", []),
        [{"initial_power":5, "hand_id":"pair"}],
        "有序来源标识从队首稳定消费完整记录")
    store.clear_scope("battle")
    _assert_equal(store.entries().size(), 0, "战斗标识在战斗结束边界统一清理")

    var engine = _engine_with_cards([])
    engine.player.max_life = 100
    engine.player.life = 95
    var recovered: Dictionary = engine.effect_ports.recover_life(
        engine.player, 20, "test", "heal-test", engine.player)
    _assert_equal(recovered["recovered"], 5, "生命恢复不超过当前有效生命上限")
    _assert_equal(engine.player.life, 100, "恢复后生命限制在有效上限")
    engine.enemy.life = 100
    engine.player.defense = 10
    engine.player.set_reflection_percent(50)
    var hostile: Dictionary = engine.effect_ports.remove_defense(
        engine.player, 0, true, engine.enemy, "test", "remove-hostile",
        "direct_effect")
    _assert_equal(hostile["removed"], 10, "统一端口冻结敌方实际移除防御量")
    _assert_equal(engine.enemy.life, 100, "敌方直接削防不触发反震")
    engine.player.defense = 10
    var enemy_life_before: int = engine.enemy.life
    engine.effect_ports.remove_defense(
        engine.player, 0, true, engine.player, "test", "remove-self")
    _assert_equal(engine.enemy.life, enemy_life_before, "主动清空自身防御不触发反震")

func _test_manual_advance_only_suppresses_effects() -> void:
    var engine = _probe_engine([
        _card("8", "fire"), _card("7", "fire")], "high_card", [
        {"op": "damage", "amount": {"kind": "constant", "value": 20}},
    ])
    engine.repository.techniques["probe_technique"]["manual_effect_mode"] = "advance_only"
    engine.repository.techniques["next_probe"] = engine.repository.get_definition(
        "probe_technique").get_script().new().configure_from_dictionary({
            "id": "next_probe", "name": "下一功法", "pool": "high",
            "special": false, "effects": [],
        }).to_definition()
    engine.sequence_book.configure({
        "high_card": ["probe_technique", "next_probe"],
    })
    engine.player.momentum_value = 4
    var committed_events: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind, values, _receipt):
            if kind in ["action_confirmed", "action_resolved"]:
                committed_events.append(values.duplicate(true)))
    var enemy_life_before: int = engine.enemy.life
    var slot_before: Dictionary = engine.sequence_book.current_slot("high_card")
    var result: Dictionary = engine.confirm_play(engine.player.hand.map(
        func(card): return str(card.id)))
    _assert_true(result.get("technique_triggered", false),
        "advance_only 主动触发仍视为成功功法")
    _assert_equal(engine.enemy.life, enemy_life_before,
        "advance_only 主动触发跳过 effects")
    _assert_equal(result["preview"]["values"]["momentum_used"], 4,
        "advance_only 仍正常计算 P 并读取冻结连势")
    _assert_equal(engine.player.momentum_value, 0,
        "advance_only 未改变连势时仍执行普通清空规则")
    _assert_equal(engine.player.same_qi_value, 1,
        "advance_only 仍按本次两张同属性真气结算同气")
    _assert_true(str(engine.sequence_book.current_slot(
        "high_card")["slot_instance_id"]) != str(slot_before["slot_instance_id"]),
        "advance_only 成功后按冻结稳定槽位推进到下一功法")
    _assert_equal(committed_events.size(), 2,
        "advance_only 仍发送 action_confirmed 与 action_resolved")
    _assert_true(committed_events.all(func(values):
        return bool(values.get("metadata", {}).get(
            "manual_effect_suppressed", false))),
        "advance_only 行动事件明确标记 manual_effect_suppressed")
    _assert_true(committed_events.all(func(values):
        return values.get("metadata", {}).has("sequence_before") \
            and values.get("metadata", {}).has("sequence_after")),
        "手动确认与完成事件都携带 sequence_before／sequence_after")

func _test_automatic_trigger_uses_special_p0_and_nested_order() -> void:
    var engine = _engine_with_cards([_card("6", "mountain")])
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": [
            {
                "id": "a", "name": "甲", "pool": "high", "special": false,
                "effects": [
                    {"op": "defense", "amount": {"kind": "constant", "value": 10}},
                    {"op": "damage", "amount": {"kind": "constant", "value": 1}},
                ],
            },
            {"id": "b", "name": "乙", "pool": "high", "special": false, "effects": []},
            {
                "id": "c", "name": "丙", "pool": "high", "special": false,
                "manual_effect_mode": "normal",
                "marker_definitions": [{
                    "id": "guard_progress", "scope": "battle",
                    "public": true, "display_name": "守势进度",
                }],
                "automatic_triggers": [{
                    "id": "after_defense_10", "event": "defense_gained",
                    "filters": {},
                    "progress": {
                        "marker_id": "guard_progress",
                        "add": {"kind": "event_field", "field": "effective_amount"},
                        "threshold": 10, "consume": 10,
                        "retain_overflow": true,
                    },
                    "p0": {"kind": "consumed_marker_value"},
                    "timing": "immediate",
                }],
                "effects": [{"op": "damage", "amount": {"kind": "power"}}],
            },
            {"id": "d", "name": "丁", "pool": "high", "special": false, "effects": []},
        ],
    })
    engine.sequence_book.configure({"high_card": ["a", "b", "c", "d"]})
    engine.actions_available = 1
    engine.player.direct_power_fixed = 2
    engine.player.momentum_value = 3
    var enemy_life_before: int = engine.enemy.life
    var result: Dictionary = engine.confirm_play([engine.player.hand[0].id])
    _assert_true(result.get("success", false), "防御中途达标的自动功法结算成功")
    _assert_equal(engine.enemy.life, enemy_life_before - 16,
        "自动条件以10为特殊P₀，再加入2点直接修正与3点连势并在甲下一效果前结算")
    _assert_equal(
        engine.sequence_book.ordered_slots("high_card").map(func(slot): return str(slot["technique_id"])),
        ["b", "d", "c", "a"], "自动即时嵌套采用乙丁丙甲顺序")
    var c_slot: Dictionary = engine.sequence_book.find_slots({
        "hand_id": "high_card", "technique_id": "c"})[0]
    _assert_equal(engine.player.source_marker_store.value(
        "technique", str(c_slot["slot_instance_id"]), "guard_progress", "battle"),
        0, "自动阈值按声明消费且不丢失槽位身份")

func _test_equipped_max_life_marker_and_snapshot_migration() -> void:
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.production())
    _assert_true(catalog.load_all(), "生命上限标识测试载入正式目录")
    var growth = GrowthInventoryScript.new(catalog)
    growth.base_max_life = 100
    growth.max_life = 100
    growth.life = 60
    growth.source_marker_store.write(
        "technique", "technique:basic_scatter", "basic_scatter",
        "life_origin", "run", "set", 80, {
            "public": true, "display_name": "命元",
            "contributes_to": "max_life",
        })
    _assert_equal(growth.recalculate_effective_max_life(), 180,
        "命元80在来源功法装备于任意永久序列时提供生命上限")
    _assert_equal(growth.life, 60, "装备生命上限标识不会自动回血")
    for hand_id in HAND_IDS:
        growth.hand_technique_progression[hand_id]["sequence"] = ["basic_guard"]
    _assert_equal(growth.recalculate_effective_max_life(), 100,
        "卸下来源功法后标识保留但生命上限加成失效")
    growth.life = 95
    growth.hand_technique_progression["high_card"]["sequence"] = ["basic_scatter"]
    _assert_equal(growth.recalculate_effective_max_life(), 180,
        "重新装备来源功法后恢复生命上限")
    _assert_equal(growth.life, 95, "重新装备生命上限来源不恢复当前生命")
    var snapshot = growth.to_progress_snapshot()
    var restored = GrowthInventoryScript.new(catalog)
    restored.apply_progress_snapshot(snapshot)
    _assert_equal(restored.base_max_life, 100,
        "本局快照保存基础生命上限而非含装备加成的有效值")
    _assert_equal(restored.max_life, 180, "来源标识与装备状态恢复后重新计算有效上限")
    var legacy = GrowthInventoryScript.new(catalog)
    legacy.apply_progress_snapshot(RunProgressSnapshotScript.from_dict({
        "life": 120, "max_life": 150,
    }))
    _assert_equal(legacy.base_max_life, 150,
        "旧快照缺少来源标识时把原 max_life 迁移为 base_max_life")

func _test_poison_damage_modifiers_apply_per_segment() -> void:
    var engine = _engine_with_cards([
        _card("3", "forest"), _card("4", "forest")])
    for card in engine.player.hand:
        engine.effect_ports.apply_card_anomaly(
            card, "state", "poison", {}, "test", 1)
    engine.player.grant_poison_damage_modifier(
        1, 50, -1, "battle_end", "poison-plus")
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports, "actor": engine.player,
        "target": engine.enemy, "action_token": "poison-modifier-test",
        "technique_id": "poison_probe", "technique_name": "毒伤探针",
        "captures": {},
    })
    var life_before: int = engine.player.life
    var result: Dictionary = engine.effect_executor.execute_all([{
        "op": "trigger_all_poison_simultaneously",
        "result_capture": "segments",
    }], context)
    _assert_true(result.get("success", false), "同步毒触发通过通用逐段修正流程")
    _assert_equal(engine.player.life, life_before - 13,
        "固定+1与50%按每张毒牌分别执行后再合计同步写入")
    _assert_equal(context.captures["segments"].map(
        func(entry): return int(entry["modified_amount"])), [6, 7],
        "毒伤顺序为B加固定、截零、加百分比并逐段向下取整")
    _assert_equal(engine.player.poison_damage_modifier_sources.size(), 1,
        "无限次毒伤修正不会被逐段消费")

    engine.player.poison_damage_modifier_sources.clear()
    engine.player.poison_damage_modifier_receipts.clear()
    engine.player.grant_poison_damage_modifier(
        2, 0, 1, "battle_end", "one-hit")
    var frozen_once: Dictionary = engine.player.freeze_poison_damage_modifiers(
        5, "poison-receipt-1")
    _assert_equal(frozen_once["final_amount"], 7,
        "有限次数毒伤来源冻结时进入第一段计算")
    _assert_equal(engine.player.poison_damage_modifier_sources[0]["remaining_hits"], 1,
        "预览和冻结毒伤修正不消费 remaining_hits")
    engine.player.commit_poison_damage_modifier_receipt(frozen_once)
    engine.player.commit_poison_damage_modifier_receipt(frozen_once)
    _assert_equal(engine.player.freeze_poison_damage_modifiers(
        5, "poison-receipt-2")["final_amount"], 5,
        "成功提交后来源耗尽，同 receipt 重放不重复消费")

func _test_normal_automatic_technique_manual_effects() -> void:
    var engine = _engine_with_cards([_card("7", "fire")])
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": [{
            "id": "auto_normal", "name": "普通自动功法",
            "pool": "high", "special": false,
            "automatic_triggers": [{
                "id": "after_defense", "event": "defense_gained",
                "filters": {}, "p0": {"kind": "constant", "value": 5},
                "timing": "immediate",
            }],
            "effects": [{
                "op": "damage",
                "amount": {"kind": "constant", "value": 7},
            }],
        }],
    })
    engine.sequence_book.configure({"high_card": ["auto_normal"]})
    var life_before: int = engine.enemy.life
    var result: Dictionary = engine.confirm_play([engine.player.hand[0].id])
    _assert_true(result.get("technique_triggered", false),
        "带自动条件的普通功法仍能随序列主动成功触发")
    _assert_equal(engine.enemy.life, life_before - 7,
        "manual_effect_mode 默认 normal，主动触发正常执行 effects")

func _test_automatic_multi_threshold_and_event_idempotency() -> void:
    var engine = _engine_with_cards([])
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": [
            {"id": "a", "name": "甲", "pool": "high", "special": false, "effects": []},
            {
                "id": "charge_auto", "name": "蓄力自动",
                "pool": "high", "special": false,
                "marker_definitions": [{
                    "id": "charge", "scope": "battle",
                    "public": true, "display_name": "蓄力",
                }],
                "automatic_triggers": [{
                    "id": "charge_ten", "event": "defense_gained",
                    "filters": {},
                    "progress": {
                        "marker_id": "charge",
                        "add": {"kind": "event_field", "field": "effective_amount"},
                        "threshold": 10, "consume": 10,
                        "retain_overflow": true,
                    },
                    "p0": {"kind": "consumed_marker_value"},
                    "timing": "immediate",
                }],
                "effects": [{
                    "op": "damage",
                    "amount": {"kind": "constant", "value": 1},
                }],
            },
            {"id": "d", "name": "丁", "pool": "high", "special": false, "effects": []},
        ],
    })
    engine.sequence_book.configure({"high_card": ["a", "charge_auto", "d"]})
    var event_values := {
        "event_token": "automatic-multi-threshold",
        "event_serial": 7001,
        "actor": engine.player, "owner": engine.player,
        "effective_amount": 25, "action_token": "automatic-root",
        "round_number": 1,
    }
    var life_before: int = engine.enemy.life
    var first: Dictionary = engine.battle_passive_event_service.commit(
        "defense_gained", event_values)
    _assert_true(first.get("success", false), "跨过两个阈值的已提交事件成功写入")
    _assert_equal(engine.enemy.life, life_before - 2,
        "单个事件跨过两个完整阈值时自动功法触发两次且没有默认上限")
    var auto_slot: Dictionary = engine.sequence_book.find_slots({
        "hand_id": "high_card", "technique_id": "charge_auto"})[0]
    _assert_equal(engine.player.source_marker_store.value(
        "technique", str(auto_slot["slot_instance_id"]), "charge", "battle"), 5,
        "多阈值消费后保留5点溢出")
    var second: Dictionary = engine.battle_passive_event_service.commit(
        "defense_gained", event_values)
    _assert_true(second.get("reused", false), "相同事件 token 的重复提交复用既有回执")
    _assert_equal(engine.enemy.life, life_before - 2,
        "相同事件 token 不重复计数、移动或触发自动功法")

func _test_automatic_opponent_event_multi_marker_batches_and_source_kind() -> void:
    var engine = _engine_with_cards([_card("7", "forest")])
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": [
            {"id": "a", "name": "甲", "pool": "high", "special": false,
                "effects": []},
            {
                "id": "batch_auto", "name": "批次自动探针",
                "pool": "high", "special": false,
                "marker_definitions": [
                    {"id": "poison_count", "scope": "battle",
                        "public": true, "display_name": "毒伤次数"},
                    {"id": "poison_total", "scope": "battle",
                        "public": true, "display_name": "毒伤总额"},
                ],
                "automatic_triggers": [
                    {
                        "id": "opponent_poison_batch",
                        "event": "poison_trigger_completed",
                        "filters": {"event_actor_is_opponent": true},
                        "progress": {
                            "marker_id": "poison_count", "add": 1,
                            "threshold": 3, "consume": 3,
                            "retain_overflow": true,
                            "additional": [{
                                "marker_id": "poison_total",
                                "add": {"kind": "event_field",
                                    "field": "final_amount"},
                                "consume": "all",
                            }],
                            "consumed_marker_id": "poison_total",
                        },
                        "p0": {"kind": "consumed_marker_value"},
                        "timing": "immediate",
                    },
                    {
                        "id": "technique_draw_only", "event": "card_drawn",
                        "filters": {"source_kind": "technique"},
                        "p0": {"kind": "constant", "value": 1},
                        "timing": "immediate",
                    },
                ],
                "effects": [{"op": "damage", "amount": {"kind": "power"}}],
            },
        ],
    })
    engine.sequence_book.configure({"high_card": ["a", "batch_auto"]})
    var life_before: int = engine.enemy.life
    for index in range(3):
        var serial := 8100 + index
        var committed: Dictionary = engine.battle_passive_event_service.commit(
            "poison_trigger_completed", {
                "event_token": "opponent-poison-%d" % index,
                "event_serial": serial,
                "actor": engine.enemy, "target": engine.enemy,
                "owner": engine.enemy, "holder": engine.enemy,
                "final_amount": index + 2,
                "actual_life_loss": index + 2,
                "action_token": "opponent-poison-root",
            })
        _assert_true(committed.get("success", false),
            "敌方毒伤段%d进入统一自动事件桥" % (index + 1))
    _assert_equal(engine.enemy.life, life_before - 9,
        "敌方事件可触发我方自动功法，P0读取三段毒伤总额2+3+4")
    var auto_slot: Dictionary = engine.sequence_book.find_slots({
        "hand_id": "high_card", "technique_id": "batch_auto"})[0]
    _assert_equal(engine.player.source_marker_store.value(
        "technique", str(auto_slot["slot_instance_id"]),
        "poison_count", "battle"), 0,
        "毒伤次数阈值消费对应三段批次")
    _assert_equal(engine.player.source_marker_store.value(
        "technique", str(auto_slot["slot_instance_id"]),
        "poison_total", "battle"), 0,
        "驱动触发时同步消费毒伤总额标识")

    engine.battle_passive_event_service.commit("card_drawn", {
        "event_token": "item-draw-probe", "event_serial": 8200,
        "actor": engine.player, "owner": engine.player,
        "source_kind": "item", "draw_reason": "effect_draw",
        "action_token": "draw-root",
    })
    _assert_equal(engine.enemy.life, life_before - 9,
        "物品抽牌不会误推进只接受功法来源的自动条件")
    engine.battle_passive_event_service.commit("card_drawn", {
        "event_token": "technique-draw-probe", "event_serial": 8201,
        "actor": engine.player, "owner": engine.player,
        "source_kind": "technique", "draw_reason": "effect_draw",
        "action_token": "draw-root",
    })
    _assert_equal(engine.enemy.life, life_before - 10,
        "结构化source_kind=technique的抽牌才触发对应自动条件")

func _test_nested_invocation_recursion_and_options() -> void:
    var engine = _engine_with_cards([_card("7", "fire")])
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": [
            {"id": "a", "name": "甲", "pool": "high", "special": false, "effects": []},
            {"id": "b", "name": "乙", "pool": "high", "special": false,
                "effects": [{"op": "damage", "amount": {"kind": "power"}}]},
            {"id": "c", "name": "丙", "pool": "high", "special": false,
                "effects": [
                    {"op": "invoke_sequence_technique",
                        "selection": {"mode": "self", "hand_id": "current"},
                        "gain_same_qi": false},
                    {"op": "invoke_sequence_technique",
                        "selection": {"mode": "by_id", "hand_id": "current", "technique_id": "d"},
                        "gain_same_qi": false},
                ]},
            {"id": "d", "name": "丁", "pool": "high", "special": false,
                "effects": [{"op": "damage", "amount": {"kind": "constant", "value": 1}}]},
        ],
    })
    engine.sequence_book.configure({"high_card": ["a", "b", "c", "d"]})
    var caller: Dictionary = engine.sequence_book.current_slot("high_card")
    var runtime = EffectContextScript.new().configure({
        "ports": engine.effect_ports, "actor": engine.player,
        "target": engine.enemy,
        "hand_result": {"id": "high_card", "contributing": engine.player.hand},
        "played_cards": engine.player.hand,
        "values": {"initial_power": 7, "technique_value": 7},
        "initial_power": 7, "power": 7,
        "group_snapshot": {"action_same_qi_gain": 2},
        "technique_id": "a", "technique_name": "甲",
        "action_token": "nested-call", "root_action_token": "nested-call",
        "slot_instance_id": str(caller["slot_instance_id"]),
        "sequence_book": engine.sequence_book,
        "card_identity_policy": engine.player.card_identity_policy,
    })
    engine.technique_invocation_service.enter_resolution_slot(
        str(caller["slot_instance_id"]))
    var life_before: int = engine.enemy.life
    var nested: Dictionary = engine.technique_invocation_service.invoke({
        "selection": {"mode": "by_id", "hand_id": "high_card", "technique_id": "c"},
        "timing": "immediate", "gain_same_qi": false,
    }, runtime)
    engine.technique_invocation_service.exit_resolution_slot(
        str(caller["slot_instance_id"]), true)
    _assert_true(nested.get("success", false), "其他槽位可以继续形成多层嵌套调用")
    _assert_equal(engine.enemy.life, life_before - 1,
        "丙递归调用自身被阻止，但随后调用丁仍正常结算")
    engine.sequence_book.complete_slot("high_card", str(caller["slot_instance_id"]))
    _assert_equal(engine.sequence_book.ordered_slots("high_card").map(
        func(slot): return str(slot["technique_id"])), ["b", "d", "c", "a"],
        "多层嵌套调用后稳定槽位推进得到乙丁丙甲")
    _assert_true(engine.technique_invocation_service.stack_slot_ids().is_empty(),
        "嵌套调用完成后结算栈完整清理")

    engine.sequence_book.configure({"high_card": ["a", "b"]})
    caller = engine.sequence_book.current_slot("high_card")
    runtime.slot_instance_id = str(caller["slot_instance_id"])
    runtime.action_token = "options-on"
    runtime.root_action_token = "options-on"
    engine.player.direct_power_fixed = 1
    engine.player.momentum_value = 5
    engine.player.same_qi_value = 0
    life_before = engine.enemy.life
    var options_on: Dictionary = engine.technique_invocation_service.invoke({
        "selection": {"mode": "by_id", "hand_id": "high_card", "technique_id": "b"},
        "p0": {"mode": "fixed", "value": 7},
        "advance_sequence": true, "gain_same_qi": true,
        "use_momentum": true, "check_condition": true,
    }, runtime)
    _assert_true(options_on.get("success", false), "调用默认完整结算成功")
    _assert_equal(engine.enemy.life, life_before - 13,
        "固定初始P0=7后仍加入1点直接修正与5点连势")
    _assert_equal(engine.player.momentum_value, 0, "调用读取并正常结算连势")
    _assert_equal(engine.player.same_qi_value, 2, "调用再次结算冻结真气组同气")
    var event_kinds: Array = engine.battle_passive_event_service.receipt_store._receipts.values().map(
        func(receipt): return str(receipt.get("event_kind", "")))
    for kind in ["action_confirmed", "technique_invocation_started",
            "technique_invocation_resolved", "action_resolved"]:
        _assert_true(event_kinds.has(kind), "调用发送结构化事件 %s" % kind)

    engine.sequence_book.configure({"high_card": ["a", "b"]})
    caller = engine.sequence_book.current_slot("high_card")
    runtime.slot_instance_id = str(caller["slot_instance_id"])
    runtime.action_token = "options-off"
    runtime.root_action_token = "options-off"
    engine.player.momentum_value = 7
    var same_qi_before: int = engine.player.same_qi_value
    var options_off: Dictionary = engine.technique_invocation_service.invoke({
        "selection": {"mode": "by_id", "hand_id": "high_card", "technique_id": "b"},
        "p0": {"mode": "fixed", "value": 7},
        "advance_sequence": false, "gain_same_qi": false,
        "use_momentum": false, "check_condition": true,
    }, runtime)
    _assert_true(options_off.get("success", false), "显式关闭调用选项仍可成功结算效果")
    _assert_equal(engine.player.momentum_value, 7, "use_momentum=false 不读取或清空连势")
    _assert_equal(engine.player.same_qi_value, same_qi_before,
        "gain_same_qi=false 不获得同气")
    _assert_equal(engine.sequence_book.current_id("high_card"), "b",
        "advance_sequence=false 保持被调用槽位为当前")

func _test_invocation_choice_resume_freezes_randomness() -> void:
    var engine = _engine_with_cards([
        _card("4", "wind"), _card("9", "fire")])
    var waiting_effects := [
        {
            "op": "generate_temporary_techniques",
            "technique_source": "current_source",
            "target_hands": "current",
            "copies": 2,
            "position": "random",
            "batch_mode": "partial",
        },
        {
            "op": "select_cards",
            "choice_id": "invoked_wait",
            "chooser": "actor",
            "minimum": 1,
            "maximum": 1,
            "insufficient_policy": "fail",
            "query": {
                "side": "actor", "zone": "hand", "order": "zone",
                "filters": {"card_kind": "normal"},
            },
            "capture": "selected",
        },
        {"op": "damage", "amount": {"kind": "constant", "value": 1}},
    ]
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": [
            {"id": "a", "name": "甲", "pool": "high", "special": false,
                "effects": []},
            {"id": "b", "name": "乙", "pool": "high", "special": false,
                "effects": waiting_effects},
            {"id": "c", "name": "丙", "pool": "high", "special": false,
                "effects": waiting_effects},
        ],
    })
    engine.sequence_book.configure_with_capacities(
        {"high_card": ["a", "b", "c"]}, {"high_card": 5})
    var caller: Dictionary = engine.sequence_book.current_slot("high_card")
    var runtime = EffectContextScript.new().configure({
        "ports": engine.effect_ports, "actor": engine.player,
        "target": engine.enemy,
        "hand_result": {"id": "high_card", "contributing": engine.player.hand},
        "played_cards": engine.player.hand,
        "values": {"initial_power": 9, "technique_value": 9},
        "initial_power": 9, "power": 9,
        "technique_id": "a", "technique_name": "甲",
        "action_token": "random-resume", "root_action_token": "random-resume",
        "slot_instance_id": str(caller["slot_instance_id"]),
        "sequence_book": engine.sequence_book,
        "card_identity_policy": engine.player.card_identity_policy,
    })
    engine.technique_invocation_service.enter_resolution_slot(
        str(caller["slot_instance_id"]))
    var started: Dictionary = engine.effect_executor.execute_all([{
        "op": "invoke_sequence_technique",
        "selection": {"mode": "random", "hand_id": "high_card"},
        "timing": "immediate", "gain_same_qi": false,
    }], runtime)
    _assert_true(started.get("pending_choice", false),
        "随机调用进入被调用功法的等待选择")
    if not started.get("pending_choice", false):
        engine.technique_invocation_service.exit_resolution_slot(
            str(caller["slot_instance_id"]), true)
        return
    var request_id := str(started.get("choice_request", {}).get("request_id", ""))
    var invoked_slot_id := str(engine.sequence_book.current_slot(
        "high_card").get("slot_instance_id", ""))
    var frozen_temporary_ids: Array = engine.sequence_book.find_slots({
        "hand_id": "high_card", "temporary": true,
    }).map(func(slot): return str(slot["slot_instance_id"]))
    var sequence_before_resume: Array = engine.sequence_book.ordered_slots(
        "high_card").map(func(slot): return str(slot["slot_instance_id"]))
    var rng_state_before_resume: int = engine.rng.state
    var selected_id := str(started["choice_request"]["candidates"][0]["id"])
    var resumed: Dictionary = engine.effect_executor.resume(
        started.get("_continuation"), request_id, [selected_id])
    engine.technique_invocation_service.exit_resolution_slot(
        str(caller["slot_instance_id"]), true)
    _assert_true(resumed.get("success", false), "等待选择恢复后完成同一次调用")
    _assert_equal(engine.rng.state, rng_state_before_resume,
        "调用恢复不重新选择随机目标或随机插入位置")
    _assert_equal(engine.sequence_book.find_slots({
        "hand_id": "high_card", "temporary": true,
    }).map(func(slot): return str(slot["slot_instance_id"])), frozen_temporary_ids,
        "恢复后仍是首次冻结的两份临时槽且没有重复插入")
    _assert_true(engine.sequence_book.find_slots({
        "hand_id": "high_card",
    }).any(func(slot): return str(slot["slot_instance_id"]) == invoked_slot_id),
        "恢复结算沿用首次随机选中的稳定目标槽位")
    _assert_true(sequence_before_resume.has(invoked_slot_id),
        "等待状态保存已移动后的调用目标顺序")

func _test_invocation_rejection_does_not_move_slot() -> void:
    var engine = _engine_with_cards([_card("7", "forest")])
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": [
            {"id": "caller_probe", "name": "调用者探针", "pool": "high",
                "special": false, "effects": []},
            {"id": "rejected_probe", "name": "拒绝目标探针", "pool": "high",
                "special": false, "condition": {"pure_attribute": "fire"},
                "effects": [{"op": "damage", "amount": 99}]},
            {"id": "tail_probe", "name": "尾部探针", "pool": "high",
                "special": false, "effects": []},
        ],
    })
    engine.sequence_book.configure({
        "high_card": ["caller_probe", "rejected_probe", "tail_probe"]})
    var runtime = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "hand_result": {
            "id": "high_card",
            "contributing": engine.player.hand.duplicate(),
        },
        "played_cards": engine.player.hand.duplicate(),
        "group_snapshot": {},
        "values": {"initial_power": 10, "technique_value": 10},
        "power": 10,
        "initial_power": 10,
        "technique_id": "caller_probe",
        "technique_name": "调用者探针",
        "slot_instance_id": str(
            engine.sequence_book.current_slot(
                "high_card")["slot_instance_id"]),
        "actual_hand_id": "high_card",
        "action_token": "rejected-invocation-root",
        "root_action_token": "rejected-invocation-root",
        "sequence_book": engine.sequence_book,
        "card_identity_policy": engine.player.card_identity_policy,
    })
    var sequence_before: Array = engine.sequence_book.ordered_slots(
        "high_card").map(func(slot): return str(slot["technique_id"]))
    var result: Dictionary = engine.technique_invocation_service.invoke({
        "selection": {"mode": "by_id", "hand_id": "high_card",
            "technique_id": "rejected_probe"},
        "timing": "immediate", "p0": {"mode": "fixed", "value": 10},
    }, runtime)
    _assert_true(result.get("success", false) \
        and not result.get("triggered", true),
        "调用目标条件不满足时安全拒绝")
    _assert_equal(engine.sequence_book.ordered_slots("high_card").map(
        func(slot): return str(slot["technique_id"])), sequence_before,
        "调用资格拒绝发生在槽位移动前")
    _assert_equal(engine.enemy.life, 100, "拒绝调用不执行目标效果")

func _test_manual_automatic_invoked_resolution_consistency() -> void:
    var manual_card = _card("5", "wind")
    var manual_engine = _probe_engine([
        manual_card], "high_card", [{
            "op": "damage", "amount": {"kind": "power"},
        }, {"op": "draw", "count": 1}])
    manual_engine.player.draw_pile = [_card("2", "forest")]
    manual_engine.player.direct_power_fixed = 2
    manual_engine.player.direct_power_percent = 20
    manual_engine.player.momentum_value = 3
    manual_engine.player.add_pending_power_fixed_source(
        4, "shared-manual-next-power")
    var manual_success_events: Array = []
    var manual_draw_events: Array = []
    manual_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_succeeded":
                manual_success_events.append(values.duplicate(true))
            if kind == "card_drawn" \
                    and str(values.get("source_id", "")) == "probe_technique":
                manual_draw_events.append(values.duplicate(true)))
    var manual_life_before: int = manual_engine.enemy.life
    var manual_result: Dictionary = manual_engine.confirm_play([manual_card.id])
    _assert_true(manual_result.get("success", false),
        "手动功法通过统一结算核心完成")
    var manual_loss: int = manual_life_before - manual_engine.enemy.life

    var invoked_card = _card("5", "wind")
    var invoked_engine = _engine_with_cards([invoked_card])
    invoked_engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": [
            {"id": "caller", "name": "调用者", "pool": "high",
                "special": false, "effects": []},
            {"id": "shared_probe", "name": "共核探针", "pool": "high",
                "special": false, "effects": [
                    {"op": "damage", "amount": {"kind": "power"}},
                    {"op": "draw", "count": 1},
                ]},
        ],
    })
    invoked_engine.player.draw_pile = [_card("3", "fire")]
    invoked_engine.sequence_book.configure({
        "high_card": ["caller", "shared_probe"]})
    invoked_engine.player.direct_power_fixed = 2
    invoked_engine.player.direct_power_percent = 20
    invoked_engine.player.momentum_value = 3
    invoked_engine.player.add_pending_power_fixed_source(
        4, "shared-invoked-next-power")
    var invoked_success_events: Array = []
    var invoked_draw_events: Array = []
    invoked_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_succeeded":
                invoked_success_events.append(values.duplicate(true))
            if kind == "card_drawn" \
                    and str(values.get("source_id", "")) == "shared_probe":
                invoked_draw_events.append(values.duplicate(true)))
    var caller_slot: Dictionary = invoked_engine.sequence_book.current_slot(
        "high_card")
    var invoked_runtime = EffectContextScript.new().configure({
        "ports": invoked_engine.effect_ports,
        "actor": invoked_engine.player, "target": invoked_engine.enemy,
        "hand_result": {"id": "high_card", "contributing": [invoked_card]},
        "played_cards": [invoked_card],
        "values": {"initial_power": 5, "technique_value": 5},
        "initial_power": 5, "power": 5,
        "technique_id": "caller", "technique_name": "调用者",
        "slot_instance_id": str(caller_slot["slot_instance_id"]),
        "actual_hand_id": "high_card",
        "action_token": "shared-invoked",
        "root_action_token": "shared-invoked",
        "sequence_book": invoked_engine.sequence_book,
        "card_identity_policy": invoked_engine.player.card_identity_policy,
    })
    var invoked_life_before: int = invoked_engine.enemy.life
    var invoked_result: Dictionary = invoked_engine.technique_invocation_service.invoke({
        "selection": {"mode": "by_id", "hand_id": "high_card",
            "technique_id": "shared_probe"},
        "p0": {"mode": "fixed", "value": 5},
        "gain_same_qi": false,
    }, invoked_runtime)
    _assert_true(invoked_result.get("success", false),
        "调用功法通过统一结算核心完成")
    var invoked_loss: int = invoked_life_before - invoked_engine.enemy.life

    var automatic_card = _card("5", "wind")
    var automatic_engine = _engine_with_cards([automatic_card])
    automatic_engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": [
            {"id": "caller", "name": "调用者", "pool": "high",
                "special": false, "effects": []},
            {"id": "shared_auto", "name": "自动共核探针", "pool": "high",
                "special": false,
                "automatic_triggers": [{
                    "id": "shared_event", "event": "defense_gained",
                    "filters": {"event_actor_is_owner": true},
                    "p0": {"kind": "constant", "value": 5},
                    "timing": "immediate",
                }],
                "effects": [
                    {"op": "damage", "amount": {"kind": "power"}},
                    {"op": "draw", "count": 1},
                ]},
        ],
    })
    automatic_engine.player.draw_pile = [_card("4", "mountain")]
    automatic_engine.sequence_book.configure({
        "high_card": ["caller", "shared_auto"]})
    automatic_engine.player.direct_power_fixed = 2
    automatic_engine.player.direct_power_percent = 20
    automatic_engine.player.momentum_value = 3
    automatic_engine.player.add_pending_power_fixed_source(
        4, "shared-automatic-next-power")
    var automatic_success_events: Array = []
    var automatic_draw_events: Array = []
    automatic_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_succeeded":
                automatic_success_events.append(values.duplicate(true))
            if kind == "card_drawn" \
                    and str(values.get("source_id", "")) == "shared_auto":
                automatic_draw_events.append(values.duplicate(true)))
    var automatic_life_before: int = automatic_engine.enemy.life
    var automatic_trigger_result: Dictionary = (
        automatic_engine.effect_ports.add_defense_result(
            automatic_engine.player, 1, "rule", "shared-auto-root"))
    _assert_true(
        automatic_trigger_result.get("success", false),
        "自动功法由真实防御写入提交事件触发")
    var automatic_loss: int = automatic_life_before - automatic_engine.enemy.life

    _assert_equal(manual_loss, 16,
        "手动 P0=5 经固定2、下一功法固定4、20%和连势3得到 P=16")
    _assert_equal(invoked_loss, manual_loss,
        "调用与手动复用相同 P0/P 和伤害阶段结果")
    _assert_equal(automatic_loss, manual_loss,
        "自动与手动复用相同 P0/P 和伤害阶段结果")
    _assert_equal(manual_success_events.map(func(values):
        return str(values.get("trigger_mode", ""))), ["manual"],
        "公共成功功法事件覆盖正常触发")
    _assert_equal(invoked_success_events.map(func(values):
        return str(values.get("trigger_mode", ""))), ["invoked"],
        "公共成功功法事件覆盖调用触发")
    _assert_equal(automatic_success_events.map(func(values):
        return str(values.get("trigger_mode", ""))), ["automatic"],
        "公共成功功法事件覆盖自动触发")
    for draw_case in [
            [manual_engine, manual_draw_events, "manual"],
            [invoked_engine, invoked_draw_events, "invoked"],
            [automatic_engine, automatic_draw_events, "automatic"],
        ]:
        _assert_equal(
            draw_case[1].size(), 1,
            "%s 功法通过真实效果链抽牌一次" % draw_case[2])
        if not draw_case[1].is_empty():
            _assert_equal(
                str(draw_case[1][0].get("source_kind", "")),
                "technique",
                "%s 抽牌公开功法来源类别" % draw_case[2])
            _assert_equal(
                str(draw_case[1][0].get("trigger_mode", "")),
                str(draw_case[2]),
                "%s 抽牌公开独立 trigger_mode" % draw_case[2])
        _assert_equal(
            draw_case[0].effect_ports.technique_draw_count(
                draw_case[0].player),
            1,
            "%s 抽牌计入功法效果抽牌" % draw_case[2])
    for events in [manual_success_events, invoked_success_events,
            automatic_success_events]:
        _assert_equal(int(events[0].get("initial_power", -1)), 5,
            "公共成功功法事件公开冻结P₀")
        _assert_equal(str(events[0].get("hand_id", "")), "high_card",
            "公共成功功法事件公开精确牌型")
    _assert_equal(manual_engine.player.momentum_value, 0,
        "手动结算统一清空未改变连势")
    _assert_equal(invoked_engine.player.momentum_value, 0,
        "调用结算统一清空未改变连势")
    _assert_equal(automatic_engine.player.momentum_value, 0,
        "自动结算统一清空未改变连势")
    _assert_equal(manual_engine.player.pending_power_fixed_sources.size(), 0,
        "正常成功功法消费下一功法固定修正")
    _assert_equal(invoked_engine.player.pending_power_fixed_sources.size(), 0,
        "调用成功功法消费下一功法固定修正")
    _assert_equal(automatic_engine.player.pending_power_fixed_sources.size(), 0,
        "自动成功功法消费下一功法固定修正")

func _test_battle_session_invocation_choice_resume() -> void:
    for trigger_mode in ["invoked", "automatic"]:
        var played = _card("4", "wind")
        var selectable = _card("9", "fire")
        var selectable_other = _card("7", "forest")
        var engine = _engine_with_cards([
            played, selectable, selectable_other])
        var waiting_effects := [
            {"op": "damage", "amount": {
                "kind": "constant", "value": 1}},
            {
                "op": "generate_temporary_techniques",
                "technique_source": "current_source",
                "target_hands": "current",
                "copies": 2, "position": "random", "batch_mode": "partial",
            },
            {
                "op": "select_cards", "choice_id": "session_wait",
                "chooser": "actor", "minimum": 1, "maximum": 1,
                "insufficient_policy": "fail",
                "query": {
                    "side": "actor", "zone": "hand", "order": "zone",
                    "filters": {"card_kind": "normal"},
                },
                "capture": "selected",
            },
        ]
        var caller_effects: Array = []
        var waiting_triggers: Array = []
        if trigger_mode == "invoked":
            caller_effects = [{
                "op": "invoke_sequence_technique",
                "selection": {"mode": "by_id", "hand_id": "current",
                    "technique_id": "waiting_probe"},
                "timing": "immediate", "gain_same_qi": false,
            }]
        else:
            caller_effects = [{
                "op": "defense", "amount": {
                    "kind": "constant", "value": 1},
            }]
            waiting_triggers = [{
                "id": "session_auto", "event": "defense_gained",
                "filters": {"event_actor_is_owner": true},
                "p0": {"kind": "constant", "value": 4},
                "timing": "immediate",
            }]
        engine.repository.configure({
            "pool_membership": POOL_MEMBERSHIP,
            "integration_statuses": {}, "resource_paths": [],
            "techniques": [
                {"id": "caller_probe", "name": "会话调用者",
                    "pool": "high", "special": false,
                    "effects": caller_effects},
                {"id": "waiting_probe", "name": "会话等待探针",
                    "pool": "high", "special": false,
                    "automatic_triggers": waiting_triggers,
                    "effects": waiting_effects},
                {"id": "tail_probe", "name": "会话尾部",
                    "pool": "high", "special": false, "effects": []},
            ],
        })
        engine.sequence_book.configure_with_capacities({
            "high_card": ["caller_probe", "waiting_probe", "tail_probe"]}, {
            "high_card": 5,
        })
        var session = BattleSessionScript.new(engine)
        var started = session.execute({
            "type": "play_cards", "card_ids": [str(played.id)],
        })
        _assert_true(started.success and bool(started.payload_value(
            "pending_choice", false)),
            "%s 等待选择完整进入 BattleSession：%s" % [
                trigger_mode, str(started.to_dict())])
        if not started.success or not bool(started.payload_value(
                "pending_choice", false)):
            continue
        var request: Dictionary = started.payload_value("choice_request", {})
        var request_id := str(request.get("request_id", ""))
        var selected_id := str(request.get("candidates", [])[0].get("id", ""))
        var temporary_ids: Array = engine.sequence_book.find_slots({
            "hand_id": "high_card", "temporary": true,
        }).map(func(slot): return str(slot["slot_instance_id"]))
        var sequence_before_resume: Array = engine.sequence_book.ordered_slots(
            "high_card").map(func(slot): return str(slot["slot_instance_id"]))
        var rng_state_before_resume: int = engine.rng.state
        var life_before_resume: int = engine.enemy.life
        _assert_equal(temporary_ids.size(), 2,
            "%s 等待前只插入两份临时槽" % trigger_mode)
        _assert_equal(100 - life_before_resume, 1,
            "%s 等待前前置伤害只执行一次" % trigger_mode)
        var resumed = session.execute({
            "type": "resolve_choice", "request_id": request_id,
            "card_ids": [selected_id],
        })
        _assert_true(resumed.success and not bool(resumed.payload_value(
            "pending_choice", false)),
            "%s 选择从 BattleSession 恢复并完成" % trigger_mode)
        _assert_equal(engine.rng.state, rng_state_before_resume,
            "%s 会话恢复不重掷随机位置" % trigger_mode)
        _assert_equal(engine.sequence_book.find_slots({
            "hand_id": "high_card", "temporary": true,
        }).map(func(slot): return str(slot["slot_instance_id"])), temporary_ids,
            "%s 会话恢复不重复插入临时槽" % trigger_mode)
        _assert_equal(engine.enemy.life, life_before_resume,
            "%s 会话恢复不重复执行前置伤害" % trigger_mode)
        _assert_true(sequence_before_resume.all(func(slot_id):
            return engine.sequence_book.ordered_slots("high_card").any(
                func(slot): return str(slot["slot_instance_id"]) == slot_id)),
            "%s 会话恢复沿用首次冻结和移动的稳定槽位" % trigger_mode)

func _test_source_marker_response_and_private_projections() -> void:
    var engine = _engine_with_cards([])
    engine.sequence_book.configure({"high_card": ["marker_source"]})
    var source_slot: Dictionary = engine.sequence_book.current_slot("high_card")
    var source_slot_id := str(source_slot["slot_instance_id"])
    var runtime = EffectContextScript.new().configure({
        "ports": engine.effect_ports, "actor": engine.player,
        "target": engine.enemy,
        "technique_id": "marker_source", "technique_name": "标识来源",
        "slot_instance_id": source_slot_id,
        "actual_hand_id": "high_card",
        "action_token": "marker-response", "root_action_token": "marker-response",
        "sequence_book": engine.sequence_book,
        "captures": {},
    })
    engine.status_system.register_response(
        "defense_gained", "battle_end", [{
            "op": "write_source_marker", "operation": "add",
            "marker_id": "charge", "scope": "battle", "amount": {
                "kind": "event_field", "field": "effective_amount"},
            "public": true, "display_name": "蓄力",
        }], runtime, {"owner": "actor"})
    engine.effect_ports.add_defense(
        engine.player, 6, "test", "marker-response:defense")
    _assert_equal(engine.player.source_marker_store.value(
        "technique", source_slot_id, "charge", "battle"), 6,
        "细粒度防御事件响应修改注册时的原功法槽位标识")

    engine.player.source_marker_store.write(
        "technique", source_slot_id, "marker_source", "public_probe",
        "battle", "set", 3, {"public": true, "display_name": "公开"})
    engine.player.source_marker_store.write(
        "technique", source_slot_id, "marker_source", "private_probe",
        "battle", "set", 9, {"public": false, "display_name": "私有"})
    var ai_state: Dictionary = AiBattleStateProjectorScript.new().project_self(
        engine.player, engine.sequence_book, engine.battle_flow)
    _assert_equal(ai_state["public_source_markers"].filter(func(marker):
        return str(marker.get("marker_id", "")) == "private_probe").size(), 0,
        "AI 状态投影不包含私有来源标识")
    var private_history: Dictionary = AiHistoryProjectorScript.new().project({
        "sequence": 1, "round_number": 1, "action_index": 0,
        "event_type": "source_marker_changed", "actor_id": "player",
        "visibility": "public", "payload": {
            "marker_id": "private_probe", "value": 9, "public": false,
        },
    })
    _assert_true(private_history.is_empty(), "AI 历史投影丢弃私有标识事件")

    var catalog = ContentCatalogScript.new(RuntimeProfileScript.production())
    _assert_true(catalog.load_all(), "私有本局标识投影测试载入正式目录")
    var growth = GrowthInventoryScript.new(catalog)
    growth.source_marker_store.write(
        "technique", "technique:basic_scatter", "basic_scatter",
        "public_run", "run", "set", 4,
        {"public": true, "display_name": "公开本局"})
    growth.source_marker_store.write(
        "technique", "technique:basic_scatter", "basic_scatter",
        "private_run", "run", "set", 8,
        {"public": false, "display_name": "私有本局"})
    var build = RunBuildQueryServiceScript.new(
        growth, catalog, EmptyInnerLoadoutService.new()).query(true)
    var scatter: Dictionary = build.hand_loadout("high_card").sequence[0]
    _assert_equal(scatter.get("run_markers", []).map(func(marker):
        return str(marker.get("marker_id", ""))), ["public_run"],
        "本局功法配装 UI DTO 只显示公开标识")
    var saved_marker_state: Dictionary = growth.to_progress_snapshot().source_marker_state
    _assert_equal(saved_marker_state.get("entries", []).size(), 2,
        "存档内部完整保留公开与私有本局标识以便恢复")

func _test_temporary_slots_do_not_duplicate_run_max_life() -> void:
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.production())
    _assert_true(catalog.load_all(), "临时槽生命上限测试载入正式目录")
    var growth = GrowthInventoryScript.new(catalog)
    growth.base_max_life = 100
    growth.life = 70
    growth.source_marker_store.write(
        "technique", "technique:basic_scatter", "basic_scatter",
        "life_origin", "run", "set", 80, {
            "public": true, "display_name": "命元",
            "contributes_to": "max_life",
        })
    _assert_equal(growth.recalculate_effective_max_life(), 180,
        "永久装备来源先提供一次命元生命上限")
    var engine = _engine_with_cards([])
    growth.apply_to_battle_side(engine.player)
    engine.sequence_book.configure({"high_card": ["basic_scatter"]})
    var origin: Dictionary = engine.sequence_book.current_slot("high_card")
    _generate_test_temporary_slots(engine.sequence_book,
        "high_card", "basic_scatter", 3, {
            "position": "after_current",
            "origin_slot_instance_id": str(origin["slot_instance_id"]),
            "origin_technique_id": "basic_scatter",
            "marker_mode": "share_origin",
        })
    _assert_equal(engine.player.max_life, 180,
        "三份临时副本不会在战斗中重复提供本局永久生命加成")
    growth.sync_from_battle_side(engine.player)
    _assert_equal(growth.max_life, 180,
        "战后同步只保存原本局标识，临时副本不污染有效生命上限")

func _test_reflection_override_sources_and_recursion_guard() -> void:
    var engine = _engine_with_cards([])
    engine.player.defense = 10
    engine.player.set_reflection_percent(50)
    var enemy_life: int = engine.enemy.life
    engine.deal_damage(engine.enemy, engine.player, 10, "technique")
    _assert_equal(engine.enemy.life, enemy_life - 5, "50% 反震读取实际削防")
    engine.player.defense = 10
    engine.player.set_reflection_percent(40)
    enemy_life = engine.enemy.life
    engine.deal_damage(engine.enemy, engine.player, 10, "technique")
    _assert_equal(engine.enemy.life, enemy_life - 4, "新 40% 比例覆盖旧比例")

    engine.player.defense = 10
    enemy_life = engine.enemy.life
    engine.deal_damage(engine.enemy, engine.player, 7, "technique", true)
    _assert_equal(engine.enemy.life, enemy_life, "真伤不触发反震")
    engine.player.defense -= 3
    _assert_equal(engine.enemy.life, enemy_life, "直接防御衰减不触发反震")

    engine.player.defense = 10
    engine.enemy.defense = 10
    engine.enemy.set_reflection_percent(100)
    var player_life: int = engine.player.life
    engine.deal_damage(engine.enemy, engine.player, 10, "technique")
    _assert_equal(engine.player.life, player_life, "反震伤害被防御吸收时不会递归反震")
    _assert_equal(engine.enemy.defense, 6, "反震作为普通伤害扣除攻击方防御")

    var expiry_context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "action_token": "player-3-100",
    })
    var expiry: Dictionary = engine.status_system.register_reflection_expiry(
        expiry_context, 50)
    engine.player.set_reflection_percent(25, "later-source")
    engine.status_system._on_turn_end({"actor": engine.player})
    _assert_equal(engine.player.current_reflection_percent, 25, "反震到期不清除后来覆盖的新来源")
    _assert_true(str(expiry.get("source_token", "")) != "", "反震延迟记录具有来源token")

func _test_defense_decay_return_records() -> void:
    var engine = _engine_with_cards([])
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "action_token": "player-4-100",
    })
    engine.status_system.register_defense_decay_return(context)
    engine.status_system.register_defense_decay_return(context)
    engine.status_system._on_defense_decay_resolved({
        "actor": engine.player,
        "round_number": 4,
        "context": {"decay": {"lost": 3}},
    })
    engine.player.defense = 0
    engine.status_system._on_round_start_records({"round_number": 5})
    _assert_equal(engine.player.defense, 6, "立山式同回合两份记录分别返还自然衰减")

    engine.status_system.register_defense_decay_return(context)
    engine.status_system._on_defense_decay_resolved({
        "actor": engine.player,
        "round_number": 4,
        "context": {"decay": {"lost": 0}},
    })
    engine.status_system._on_round_start_records({"round_number": 5})
    _assert_equal(engine.player.defense, 6, "防御提前打光时立山式返还相应减少为零")

func _test_action_resolution_results_and_no_life_loss_disruption() -> void:
    var engine = _engine_with_cards([])
    var target_card = _card("3", "wind")
    engine.enemy.hand = [target_card]
    engine.enemy.defense = 5
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
    })
    var disruption := {
        "op": "apply_anomaly_from_query",
        "query": {"side":"target", "zone":"hand", "order":"zone", "limit":1,
            "filters":{"card_kind":"normal"}},
        "capture":"suppressed", "category":"state", "anomaly":"vulnerability",
    }
    engine.status_system.register_no_life_loss_disruption(context, disruption)
    engine.action_resolver.begin_action_resolution([engine.player, engine.enemy])
    engine.deal_damage(engine.enemy, engine.player, 0, "technique")
    var completed: Dictionary = engine.action_resolver.finish_action_resolution()
    _assert_true(completed.get("success", false), "单次行动完成时点成功发出")
    _assert_true(target_card.has_anomaly("state", "vulnerability"), "本次未损失生命时镇山施加破绽")

    engine.status_system.remove_card_anomaly(target_card, "state", "vulnerability", "test")
    engine.status_system.register_no_life_loss_disruption(context, disruption)
    engine.action_resolver.begin_action_resolution([engine.player, engine.enemy])
    engine.player.defense = 0
    engine.deal_damage(engine.enemy, engine.player, 1, "technique")
    completed = engine.action_resolver.finish_action_resolution()
    var player_result: Dictionary = completed.get("results", []).filter(
        func(value): return value.get("side") == engine.player)[0]
    _assert_equal(player_result.get("actual_life_loss", 0), 1, "行动结果提供本次实际生命损失")
    _assert_true(not target_card.has_anomaly("state", "vulnerability"), "本次损失生命时镇山不施加破绽")

func _test_synchronized_reflection_matches_normal_damage() -> void:
    var engine = _engine_with_cards([])
    engine.player.defense = 12
    engine.player.set_reflection_percent(50)
    var enemy_life: int = engine.enemy.life
    engine.begin_synchronized_damage([{"actor": engine.enemy}])
    var buffered: Dictionary = engine.deal_damage(
        engine.enemy, engine.player, 12, "technique")
    _assert_true(buffered["buffered"], "同步伤害先进入缓冲")
    _assert_equal(engine.enemy.life, enemy_life, "缓冲刷新前不提前反震")
    engine.flush_synchronized_damage()
    _assert_equal(engine.enemy.life, enemy_life - 6, "同步刷新按同一反震规则结算")

func _test_unblockable_damage_still_absorbs_and_reflects() -> void:
    var engine = _engine_with_cards([])
    engine.enemy.defense = 6
    engine.enemy.set_reflection_percent(50)
    engine.enemy.add_block_source(
        "unconditional", "block-probe", engine.player.owner_id, "")
    var player_life_before: int = engine.player.life
    var result: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 8, "probe", false,
        "unblockable-probe", "normal", {
            "direct_attack": true,
            "blockable": false,
        })
    _assert_true(result.get("success", false) \
        and not result.get("blocked", false),
        "blockable=false 只跳过格挡查询")
    _assert_equal(engine.enemy.defense, 0,
        "不可格挡伤害仍正常消耗防御")
    _assert_equal(engine.enemy.life, 98,
        "不可格挡伤害仍按防御后余量扣除生命")
    _assert_equal(engine.player.life, player_life_before - 3,
        "不可格挡伤害吸收防御后仍触发反震")
    _assert_equal(engine.enemy.block_sources.size(), 1,
        "跳过格挡查询不会消费格挡来源")

func _test_all_insights_grow_empty_slots() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "心得空池测试内容加载成功")
    var normal_ids: Array = []
    for category in catalog.definition("practice_shop")["normal"]["categories"]:
        if str(category.get("content_kind", "")) == "insight":
            normal_ids = category["candidate_ids"]
    _assert_equal(normal_ids.size(), 8, "普通池继续包含八种心得")
    for pack_id in ["insight_pack_basic", "large_insight_pack", "deluxe_insight_pack"]:
        var found := []
        for pack in catalog.definition("practice_shop")["packs"]["candidates"]:
            if str(pack["id"]) == pack_id:
                found = pack["candidate_ids"]
        _assert_equal(found.size(), 8, "%s 继续包含八种心得" % pack_id)
    var insight_engine = CombatEngineScript.new()
    var side = insight_engine.player
    var initial_progression: Dictionary = {}
    for hand_id in HAND_IDS:
        initial_progression[hand_id] = {
            "slot_count": 1,
            "sequence": ["basic_scatter"],
        }
    side.hand_technique_progression = initial_progression.duplicate(true)
    side.hand_technique_progression_active = true
    insight_engine.sequence_book.configure_hand_progression(initial_progression)
    for hand_id in HAND_IDS:
        var before := int(side.hand_technique_progression.get(
            hand_id, {"slot_count": 1})["slot_count"])
        var result: Dictionary = side.apply_insight_growth(hand_id, [])
        _assert_true(result.get("success", false),
            "%s 心得在空池成功使用：%s" % [hand_id, str(result)])
        if not result.get("success", false):
            continue
        _assert_equal(result["slot_count_after"], before + 1, "%s 槽位增加一" % hand_id)
        _assert_equal(result["technique_acquired"], "", "%s 不生成功法" % hand_id)
        _assert_equal(result["technique_equipped"], false, "%s 不自动装备功法" % hand_id)
        _assert_true(result["no_technique_available"], "%s 明确报告池空" % hand_id)

func _test_s2f6a_basic_techniques_and_loadout_limits() -> void:
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.production())
    _assert_true(catalog.load_all(), "F6A 正式基础功法内容可加载")
    var scatter: Dictionary = catalog.get_by_id("technique", "basic_scatter")
    var guard: Dictionary = catalog.get_by_id("technique", "basic_guard")
    var effect_engine = _engine_with_cards([])
    for power in [3, 4]:
        effect_engine.enemy.life = 100
        effect_engine.enemy.defense = 0
        effect_engine.player.defense = 0
        var context = EffectContextScript.new().configure({
            "ports": effect_engine.effect_ports,
            "actor": effect_engine.player,
            "target": effect_engine.enemy,
            "power": power,
        })
        _assert_true(effect_engine.effect_executor.execute_all(
            scatter["effects"], context)["success"], "散招走通用效果链")
        _assert_equal(100 - effect_engine.enemy.life, int(floor(power / 4.0)),
            "散招 P=%d 造成 floor(P/4)" % power)
        _assert_true(effect_engine.effect_executor.execute_all(
            guard["effects"], context)["success"], "守招走通用效果链")
        _assert_equal(effect_engine.player.defense, int(floor(power / 4.0)),
            "守招 P=%d 获得 floor(P/4) 防御" % power)

    var action_engine = _engine_with_cards([_card("4", "wind")])
    action_engine.repository.configure(catalog.definition("techniques"), true)
    var action_sequences := _empty_sequences()
    action_sequences["high_card"] = ["basic_scatter", "basic_guard"]
    action_engine.sequence_book.configure(action_sequences)
    action_engine.player.momentum_value = 3
    action_engine.player.last_successful_technique_hand_id = "high_card"
    var played: Dictionary = action_engine.confirm_play([action_engine.player.hand[0].id])
    _assert_true(played.get("technique_triggered", false), "基础功法是真实功法并正常启动")
    _assert_equal(played["preview"]["values"]["momentum_used"], 3, "基础功法读取连势")
    _assert_equal(action_engine.sequence_book.current_id("high_card"), "basic_guard", "基础功法成功后推进真实序列")

    var fake_catalog := LoadoutCatalog.new()
    var growth = GrowthInventoryScript.new(fake_catalog, false)
    growth.learned_technique_ids.assign(["normal_probe"])
    var policy = growth.technique_loadout_policy
    var baseline: Dictionary = growth.hand_technique_progression.duplicate(true)
    var cross_hand: Dictionary = baseline.duplicate(true)
    cross_hand["pair"] = {"slot_count": 1, "sequence": ["normal_probe"]}
    cross_hand["two_pair"] = {"slot_count": 1, "sequence": ["normal_probe"]}
    _assert_true(not policy.validate_complete(
        growth, cross_hand, growth.learned_technique_ids, "two_pair")["success"],
        "普通功法跨八牌型合计第二次被拒绝")
    var same_hand: Dictionary = baseline.duplicate(true)
    same_hand["pair"] = {
        "slot_count": 2,
        "sequence": ["normal_probe", "normal_probe"],
    }
    _assert_true(not policy.validate_complete(
        growth, same_hand, growth.learned_technique_ids, "pair")["success"],
        "普通功法同一序列第二次被拒绝")

    var resolver := LoadoutLimitTwoResolver.new()
    policy.use_int_policy_resolver(resolver)
    var before_state := growth.capture_mutation_state()
    _assert_true(policy.validate_complete(
        growth, cross_hand, growth.learned_technique_ids, "two_pair")["success"],
        "Fake 查询将普通功法上限改为 2 后跨牌型合法")
    _assert_true(policy.validate_complete(
        growth, same_hand, growth.learned_technique_ids, "pair")["success"],
        "Fake 查询上限 2 后同序列重复合法")
    _assert_equal(growth.capture_mutation_state(), before_state, "装配次数查询不修改本局状态")
    _assert_true(resolver.calls.all(func(call):
        return call.get("hook") == "technique_loadout_copy_limit_query"),
        "所有 Fake 次数查询使用统一 hook")

    policy.use_int_policy_resolver(null)
    var maximum_built_in: Dictionary = baseline.duplicate(true)
    var remaining := HAND_IDS.size() * TechniqueLoadoutPolicyScript.MAX_SLOT_COUNT
    for hand_id in HAND_IDS:
        var count := mini(
            remaining, TechniqueLoadoutPolicyScript.MAX_SLOT_COUNT)
        maximum_built_in[hand_id] = {
            "slot_count": count,
            "sequence": [],
        }
        for _index in range(count):
            maximum_built_in[hand_id]["sequence"].append("basic_scatter")
        remaining -= count
    _assert_equal(remaining, 0, "测试夹具填满八种牌型的合法容量")
    _assert_true(policy.validate_complete(
        growth, maximum_built_in, growth.learned_technique_ids)["success"],
        "基础功法可以填满全部 72 个当前合法永久槽位")

    var original: Dictionary = growth.hand_technique_progression.duplicate(true)
    _assert_true(not growth.set_hand_technique_loadout("pair", [])["success"],
        "每个精确牌型不能卸下最后一门功法")
    _assert_equal(growth.hand_technique_progression, original,
        "空序列提交失败时八牌型原状态不变")
    var insight := growth.apply_insight_growth("high_card", [])
    _assert_true(insight["success"], "心得无普通候选时仍成功")
    _assert_equal(insight["technique_acquired"], "",
        "心得无普通候选时不使用散招补位")
    _assert_equal(growth.hand_progression("high_card")["sequence"].size(), 1,
        "心得完成后实际序列保持原装备数量")
    _assert_equal(growth.hand_progression("high_card")["slot_count"], 2,
        "心得完成后允许保留空余容量")
    _assert_equal(growth.learned_technique_ids, ["normal_probe"],
        "基础功法不写入已习得功法集合")

func _test_permanent_loadout_capacity_insight_and_runtime_compatibility() -> void:
    var catalog := LoadoutCatalog.new()
    var growth = GrowthInventoryScript.new(catalog, false)
    var policy = growth.technique_loadout_policy
    var baseline: Dictionary = growth.hand_technique_progression.duplicate(true)
    for count in [1, 2, 3]:
        var proposed := baseline.duplicate(true)
        var sequence := ["basic_scatter", "basic_guard", "basic_scatter"].slice(
            0, count)
        proposed["pair"] = {"slot_count": 3, "sequence": sequence}
        _assert_true(policy.validate_complete(
            growth, proposed, growth.learned_technique_ids, "pair")["success"],
            "容量3时装备%d门功法合法" % count)
    var empty := baseline.duplicate(true)
    empty["pair"] = {"slot_count": 3, "sequence": []}
    _assert_true(not policy.validate_complete(
        growth, empty, growth.learned_technique_ids, "pair")["success"],
        "每个精确牌型装备0门功法非法")
    var overflow := baseline.duplicate(true)
    overflow["pair"] = {
        "slot_count": 3,
        "sequence": [
            "basic_scatter", "basic_guard",
            "basic_scatter", "basic_guard"],
    }
    _assert_true(not policy.validate_complete(
        growth, overflow, growth.learned_technique_ids, "pair")["success"],
        "装备数量超过容量非法")
    var too_many_slots := baseline.duplicate(true)
    too_many_slots["pair"] = {"slot_count": 10, "sequence": ["basic_scatter"]}
    _assert_true(not policy.validate_complete(
        growth, too_many_slots, growth.learned_technique_ids, "pair")["success"],
        "单个精确牌型容量超过9非法")
    var missing_capacity := baseline.duplicate(true)
    missing_capacity["pair"] = {"slot_count": 0, "sequence": ["basic_scatter"]}
    _assert_true(not policy.validate_complete(
        growth, missing_capacity, growth.learned_technique_ids, "pair")["success"],
        "单个精确牌型容量低于1非法")

    growth.hand_technique_progression["pair"] = {
        "slot_count": 3, "sequence": ["basic_scatter"]}
    var before_sequence: Array = growth.hand_progression("pair")["sequence"]
    var insight := growth.apply_insight_growth("pair", ["normal_probe"])
    _assert_true(insight["success"], "心得容量成长与功法获得可以同时成功")
    _assert_equal(insight["slot_gain"], 1, "心得默认实际增加1个槽位")
    _assert_equal(insight["technique_acquired"], "normal_probe",
        "心得获得合法功法进入功法库")
    _assert_equal(insight["technique_equipped"], false,
        "心得回执明确不自动装备功法")
    _assert_equal(growth.hand_progression("pair")["sequence"], before_sequence,
        "心得所得功法不改变实际装备序列")
    _assert_true(growth.learned_technique_ids.has("normal_probe"),
        "心得所得功法写入本局功法库")

    var empty_pool_growth = GrowthInventoryScript.new(catalog, false)
    var empty_pool_sequence: Array = empty_pool_growth.hand_progression(
        "pair")["sequence"]
    var empty_pool := empty_pool_growth.apply_insight_growth("pair", [])
    _assert_true(empty_pool["success"], "没有功法候选时仍可增加容量")
    _assert_equal(empty_pool["slot_gain"], 1, "空候选心得仍实际增加1个槽位")
    _assert_equal(empty_pool["technique_acquired"], "", "空候选心得不伪造所得功法")
    _assert_equal(empty_pool_growth.hand_progression("pair")["sequence"],
        empty_pool_sequence, "空候选心得不使用基础功法补位")

    var handler := InsightSlotGainProbeHandler.new()
    var registry = PassiveRuleHandlerRegistryScript.new(false)
    _assert_true(registry.register_handler(handler), "心得增量测试 Handler 注册成功")
    var runtime = PassiveRuleRuntimeScript.new(registry, catalog)
    var resolver = PassiveIntPolicyResolverScript.new(runtime)
    var modified_growth = GrowthInventoryScript.new(catalog, false)
    modified_growth.item_ids.assign(["insight_gain_probe"])
    modified_growth.use_technique_loadout_policy_resolver(resolver)
    var modified_sequence: Array = modified_growth.hand_progression("pair")["sequence"]
    var modified := modified_growth.apply_insight_growth("pair", [])
    _assert_equal(modified["slot_gain_requested"], 2,
        "insight_slot_gain_query把基础+1改为+2")
    _assert_equal(modified["slot_gain"], 2, "远离上限时实际增加2个槽位")
    _assert_equal(modified_growth.hand_progression("pair")["sequence"],
        modified_sequence, "查询修改容量仍不自动装备功法")
    _assert_equal(handler.requests[0]["metadata"], {
        "exact_hand_type": "pair",
        "current_slot_count": 1,
        "base_slot_gain": 1,
        "maximum_slot_count": 9,
    }, "心得增量查询公开精确牌型、当前容量、基础增量与上限")

    var capped_growth = GrowthInventoryScript.new(catalog, false)
    capped_growth.item_ids.assign(["insight_gain_probe"])
    capped_growth.use_technique_loadout_policy_resolver(resolver)
    capped_growth.hand_technique_progression["pair"] = {
        "slot_count": 8, "sequence": ["basic_scatter"]}
    var capped := capped_growth.apply_insight_growth("pair", [])
    _assert_equal(capped["slot_gain_requested"], 2, "接近上限仍记录查询理论增量")
    _assert_equal(capped["slot_gain"], 1, "接近9槽时按上限裁剪实际增量")
    _assert_equal(capped["slot_count_after"], 9, "裁剪后容量恰为9")
    var at_cap_sequence: Array = capped_growth.hand_progression("pair")["sequence"]
    var at_cap := capped_growth.apply_insight_growth("pair", ["normal_probe"])
    _assert_true(at_cap["success"], "达到9槽后仍正常结算心得其他结果")
    _assert_equal(at_cap["slot_gain"], 0, "达到9槽时实际槽位增量为0")
    _assert_equal(at_cap["technique_acquired"], "normal_probe",
        "达到9槽后仍可获得合法功法")
    _assert_equal(capped_growth.hand_progression("pair")["sequence"],
        at_cap_sequence, "达到9槽获得功法仍不自动装备")

    var engine = _engine_with_cards([])
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": [{
            "id": "underfilled_auto", "name": "未满槽自动功法",
            "pool": "high", "special": false,
            "automatic_triggers": [{
                "id": "after_defense", "event": "defense_gained",
                "filters": {}, "p0": {"kind": "constant", "value": 1},
                "timing": "immediate",
            }],
            "effects": [{
                "op": "damage",
                "amount": {"kind": "constant", "value": 2},
            }],
        }],
    })
    engine.sequence_book.configure_hand_progression({
        "high_card": {
            "slot_count": 3,
            "sequence": ["underfilled_auto"],
        },
    })
    var actual_slots: Array = engine.sequence_book.find_slots({
        "hand_id": "high_card"})
    _assert_equal(actual_slots.size(), 1,
        "容量3但装备1门时只实例化1个实际功法槽位")
    var stable_slot_id := str(actual_slots[0]["slot_instance_id"])
    var life_before: int = engine.enemy.life
    engine.battle_passive_event_service.commit("defense_gained", {
        "event_token": "underfilled-auto", "event_serial": 9101,
        "actor": engine.player, "owner": engine.player,
        "effective_amount": 1, "action_token": "underfilled-root",
        "round_number": 1,
    })
    _assert_equal(engine.enemy.life, life_before - 2,
        "未填满永久容量时实际装备的自动功法仍正常触发")
    _assert_equal(engine.sequence_book.find_slots({
        "hand_id": "high_card"}).size(), 1,
        "空余2格不会产生自动触发候选或空槽实例")
    var caller: Dictionary = engine.sequence_book.current_slot("high_card")
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports, "actor": engine.player,
        "target": engine.enemy,
        "hand_result": {"id": "high_card", "contributing": []},
        "played_cards": [], "initial_power": 1, "power": 1,
        "technique_id": "underfilled_auto",
        "technique_name": "未满槽自动功法",
        "action_token": "underfilled-call",
        "root_action_token": "underfilled-call",
        "slot_instance_id": stable_slot_id,
        "sequence_book": engine.sequence_book,
        "card_identity_policy": engine.player.card_identity_policy,
    })
    var next_call: Dictionary = engine.effect_ports.invoke_sequence_technique({
        "selection": {"mode": "next", "hand_id": "high_card"},
    }, context)
    _assert_true(next_call.get("success", false) \
        and not next_call.get("triggered", true),
        "容量3但只装备1门时调用下一门没有合法目标")
    var random_candidates: Array = engine.technique_invocation_service._candidates(
        {"mode": "random", "hand_id": "high_card"}, context, "high_card")
    _assert_equal(random_candidates.size(), 1, "随机调用只从实际装备功法中选择")
    _assert_equal(str(random_candidates[0]["slot_instance_id"]), stable_slot_id,
        "随机调用候选保留实际稳定功法实例身份")
    var random_call: Dictionary = engine.effect_ports.invoke_sequence_technique({
        "selection": {"mode": "random", "hand_id": "high_card"},
    }, context)
    _assert_true(random_call.get("success", false) \
        and random_call.get("triggered", false),
        "随机调用可以触发唯一实际装备功法")
    _assert_equal(str(engine.sequence_book.current_slot(
        "high_card")["slot_instance_id"]), stable_slot_id,
        "调用并推进功法后原slot_instance_id保持稳定")
    engine.player.source_marker_store.write(
        "technique", stable_slot_id, "underfilled_auto",
        "underfilled_probe", "battle", "set", 3)
    engine.player.source_marker_store.write(
        "technique", "missing-slot", "underfilled_auto",
        "underfilled_probe", "battle", "set", 7)
    _assert_equal(engine.player.active_technique_marker_sum({
        "marker_id": "underfilled_probe", "scope": "battle"}), 3,
        "active_technique_marker_sum不统计不存在的功法实例")
    engine.sequence_book.complete_slot("high_card", stable_slot_id)
    engine.sequence_book.move_slot_to_current("high_card", stable_slot_id)
    _assert_equal(str(engine.sequence_book.current_slot(
        "high_card")["slot_instance_id"]), stable_slot_id,
        "推进和移动后实际功法slot_instance_id保持稳定")

func _probe_engine(
        cards: Array,
        hand_id: String,
        effects: Array,
        condition: Dictionary = {}):
    var engine = _engine_with_cards(cards)
    var probe := {
        "id": "probe_technique",
        "name": "内存探针功法",
        "pool": str(POOL_MEMBERSHIP[hand_id][0]),
        "special": false,
        "condition": condition,
        "effects": effects,
    }
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {},
        "resource_paths": [],
        "techniques": [probe],
    })
    var sequences := _empty_sequences()
    sequences[hand_id] = ["probe_technique"]
    engine.sequence_book.configure(sequences)
    engine.actions_available = 1
    return engine

func _engine_with_cards(cards: Array):
    var engine = CombatEngineScript.new()
    tracked_engines.append(engine)
    engine.setup(2308, false, cards)
    engine.player.hand = cards.duplicate()
    engine.player.draw_pile.clear()
    engine.player.staging.clear()
    engine.player.discard_pile.clear()
    engine.actions_available = 1
    engine.enemy.defense = 0
    return engine

func _dispose_tracked_engines() -> void:
    for engine in tracked_engines:
        engine.battle_passive_timing_bridge.close_battle()
        engine.battle_passive_event_service.close_battle()
        engine.passive_rule_runtime.close_battle_effect_commands()
        engine.effect_ports.use_hand_retrigger_callback(Callable())
        engine.battle_passive_event_service._scenario_error = Callable()
        engine.battle_rule_query_service._scenario_error = Callable()
        engine.passive_rule_runtime._battle_effect_scenario_error = Callable()
        engine.player.use_committed_event_service(null)
        engine.enemy.use_committed_event_service(null)
        engine.player.use_battle_rule_query_service(null)
        engine.enemy.use_battle_rule_query_service(null)
        engine.player.use_status_system(null)
        engine.enemy.use_status_system(null)
        engine.player.use_card_state_lifecycle(null)
        engine.enemy.use_card_state_lifecycle(null)
        engine.player.use_card_reshape_runtime(null)
        engine.enemy.use_card_reshape_runtime(null)
        engine.player.use_card_policies(null, null)
        engine.enemy.use_card_policies(null, null)
        engine.player.use_battle_permission_service(null)
        engine.enemy.use_battle_permission_service(null)
        engine.status_system.reset()
        engine.status_system.use_effect_ports(null)
        engine.status_system.use_effect_executor(null)
        engine.status_system.use_card_trigger_replay_service(null)
        engine.status_system.use_battle_permission_service(null)
        engine.effect_ports._sides.clear()
        engine.effect_ports._survival_effect_service \
            .use_passive_battle_services(null, null, Callable())
        engine.effect_ports._source_resource_effect_service \
            .use_passive_battle_services(null, Callable())
        engine.effect_ports._technique_sequence_effect_service \
            .use_passive_battle_services(null, Callable())
        engine.effect_ports._action_resource_effect_service \
            ._consumable_repository = null
        engine.delayed_effects.clear()
        engine.action_service = null
        engine.round_service = null
        engine.enemy_planning_service = null
        engine.outcome_service = null
        engine.consumable_service = null
        engine.loadout_service = null
        engine.action_resolver = null
        engine.battle_rule_query_service = null
        engine.battle_passive_event_service = null
        engine.battle_passive_timing_bridge = null
        engine.battle_permission_service = null
        engine.passive_rule_runtime = null
        engine.status_system = null
        engine.card_reshape_runtime = null
        engine.effect_executor = null
        engine.effect_ports = null
    tracked_engines.clear()

func _empty_sequences() -> Dictionary:
    var result := {"version": 1}
    for hand_id in HAND_IDS:
        result[hand_id] = []
    return result

func _generate_test_temporary_slots(
        book,
        hand_id: String,
        technique_id: String,
        copies: int,
        options: Dictionary = {}) -> Array:
    var missing := maxi(0, copies - book.remaining_slot_count(hand_id))
    if missing > 0:
        book.change_slot_capacity(hand_id, missing)
    var requests: Array = []
    for copy_index in range(copies):
        requests.append({
            "hand_id": hand_id,
            "copy_index": copy_index,
            "technique_id": technique_id,
            "position": str(options.get("position", "after_current")),
            "marker_mode": str(options.get("marker_mode", "independent")),
            "origin_technique_id": str(options.get(
                "origin_technique_id", technique_id)),
            "origin_slot_instance_id": str(options.get(
                "origin_slot_instance_id", "")),
            "generation_batch_token": "test-generation",
            "generator_source_kind": "rule",
            "generator_source_id": "test",
            "generator_source_instance_key": "rule:test",
        })
    var test_rng := RandomNumberGenerator.new()
    test_rng.seed = 2308
    return book.commit_temporary_generation(
        requests, "partial", test_rng).get("generated_slots", [])

func _card(rank: String, attribute: String):
    card_serial += 1
    var order := 14 if rank == "A" else int(rank)
    var qi := 12 if rank == "A" else int(rank)
    return QiCardScript.new(
        "probe_card_%d" % card_serial,
        rank,
        order,
        qi,
        attribute,
        attribute)

func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append("%s：期望为 true" % label)
