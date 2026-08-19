extends "res://tests/support/expanded_technique_test_base.gd"

const BattleSideScript = preload("res://core/battle_side.gd")
const PassiveRuleHandlerRegistryScript = preload(
    "res://core/passives/passive_rule_handler_registry.gd")
const PassiveRuleRuntimeScript = preload(
    "res://core/passives/passive_rule_runtime.gd")
const PassiveRuleSourceScript = preload(
    "res://core/passives/passive_rule_source.gd")
const BattleRuleQueryServiceScript = preload(
    "res://core/passives/battle_rule_query_service.gd")
const CommittedEventServiceScript = preload(
    "res://core/passives/battle_passive_committed_event_service.gd")
const HandGroupSnapshotScript = preload("res://core/hand_group_snapshot.gd")
const EffectTargetQueryScript = preload(
    "res://core/effects/effect_target_query.gd")
const BattleEffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const EffectValueResolverScript = preload(
    "res://core/effects/effect_value_resolver.gd")
const EnemyCandidateFeatureProjectorScript = preload(
    "res://core/ai/enemy_candidate_feature_projector.gd")


class EffectiveQiProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    var calls: Array[Dictionary] = []
    var battle_rng: RandomNumberGenerator
    var event_service = null

    func behavior_id() -> String:
        return "effective_qi_probe"

    func supported_hooks() -> Array[String]:
        return ["effective_qi_query"] as Array[String]

    func handle(_hook: String, context, configuration: Dictionary) -> Dictionary:
        var request = context.payload.get("int_query")
        calls.append({
            "source_kind": context.source.source_kind,
            "purpose": str(context.payload.get("purpose", "")),
            "evaluation_mode": str(context.payload.get("evaluation_mode", "")),
            "subject": context.payload.get("subject_card_facts", {}).duplicate(true),
            "card_facts": context.payload.get("card_facts", []).duplicate(true),
            "actual_played_count": int(context.payload.get(
                "actual_played_count", 0)),
            "exact_hand": context.payload.get("exact_hand", {}).duplicate(true),
        })
        if bool(configuration.get("mutate_state", false)):
            context.owner.defense += 9
        if bool(configuration.get("advance_rng", false)) and battle_rng != null:
            battle_rng.randi()
        if bool(configuration.get("emit_event", false)) and event_service != null:
            event_service.commit("action_confirmed", {
                "event_token": "query-must-not-emit",
                "actor": context.owner,
                "owner": context.owner,
                "action_token": str(request.action_token),
            })
        if bool(configuration.get("fail", false)):
            return {"success": false, "reason": "Fake effective qi failure"}
        var purposes: Array = configuration.get("purposes", [])
        if not purposes.is_empty() and not purposes.has(request.purpose):
            return {"success": true, "value": int(request.current_value)}
        var delta := int(configuration.get("delta", 0))
        if bool(configuration.get("same_rank_only", false)):
            var ranks: Dictionary = {}
            for fact in request.card_facts:
                if bool(fact.get("participating", false)):
                    ranks[int(fact.get("rank_order", 0))] = true
            if ranks.size() != 1 or request.actual_played_count < 2:
                delta = 0
        return {
            "success": true,
            "value": int(request.current_value) + delta,
        }


class StaticSourceResolver:
    extends RefCounted

    var _catalog = null
    var sources: Array = []

    func _init(values: Array) -> void:
        sources = values.duplicate()

    func collect_sources(context) -> Array:
        if context != null and context.has_source_snapshot:
            return context.source_snapshot.map(func(value):
                return PassiveRuleSourceScript.new().configure(value))
        return sources.duplicate()

    func capture_source_snapshot(context) -> Array:
        return collect_sources(context).map(func(source): return source.to_dict())

    func equipped_inner_skill_entries(_context) -> Array:
        return []


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_intrinsic_pipeline_unchanged()
    _test_neutral_sources_purpose_and_group_facts()
    _test_modes_snapshot_and_fingerprints()
    _test_confirmed_snapshot_vs_runtime()
    _test_purity_and_failure_reporting()
    _test_power_target_and_value_spec_migrations()
    _finish("EFFECTIVE QI QUERY TEST")


func _test_intrinsic_pipeline_unchanged() -> void:
    var fixture := _fixture([])
    var owner = fixture["owner"]
    var service = fixture["service"]
    var card = _card("7", "fire")
    owner.hand = [card]
    _assert_query_matches_intrinsic(service, owner, card, "无来源")

    card.reshape_enhancement = "qi_boost"
    _assert_query_matches_intrinsic(service, owner, card, "永久强化")
    card.set_temporary_enhancement("qi_boost")
    _assert_query_matches_intrinsic(service, owner, card, "临时强化")
    card.set_anomaly("buff", "qi_heat", {}, 2)
    _assert_query_matches_intrinsic(service, owner, card, "炽气")
    card.set_anomaly("debuff", "qi_wither", {}, 1)
    _assert_query_matches_intrinsic(service, owner, card, "枯气")
    card.set_anomaly("debuff", "burned_out")
    _assert_equal(_query(service, owner, card).effective_value, 0,
        "燃尽仍在卡牌自身阶段最终覆盖为零")


func _test_neutral_sources_purpose_and_group_facts() -> void:
    var fixture := _fixture([
        _source("inner_skill", "fake_inner", 0, {"delta": 1}),
        _source("item", "fake_item", 1, {"delta": 2}),
        _source("technique", "fake_technique", 2, {"delta": 3}),
    ])
    var owner = fixture["owner"]
    var cards := [_card("8", "wind"), _card("8", "forest")]
    owner.hand = cards.duplicate()
    var hand := {"id": "pair", "name": "对子", "contributing": cards,
        "numeric_contributing": cards}
    var query = fixture["service"].resolve_effective_qi(owner, cards[0], {
        "purpose": "power_calculation", "evaluation_mode": "preview",
        "cards": cards, "participating_card_ids": _ids(cards),
        "hand_result": hand, "actual_played_count": 2,
    })
    _assert_equal(query.effective_value, cards[0].effective_qi_value() + 6,
        "假内功、假物品与假功法来源走同一协议")
    _assert_equal(query.modifier_breakdown.map(
        func(entry): return entry["source_kind"]),
        ["inner_skill", "item", "technique"], "来源 breakdown 保持中立种类")

    var purpose_fixture := _fixture([
        _source("item", "power_only", 0, {
            "delta": 5, "purposes": ["power_calculation"]}),
        _source("inner_skill", "same_rank", 1, {
            "delta": 4, "same_rank_only": true,
            "purposes": ["power_calculation"]}),
    ])
    purpose_fixture["owner"].hand = cards.duplicate()
    var power = purpose_fixture["service"].resolve_effective_qi(
        purpose_fixture["owner"], cards[0], {
            "purpose": "power_calculation", "evaluation_mode": "preview",
            "cards": cards, "participating_card_ids": _ids(cards),
            "hand_result": hand, "actual_played_count": 2,
        })
    var target = purpose_fixture["service"].resolve_effective_qi(
        purpose_fixture["owner"], cards[0], {
            "purpose": "target_query", "evaluation_mode": "runtime",
            "cards": cards, "participating_card_ids": [],
        })
    _assert_equal(power.effective_value, cards[0].effective_qi_value() + 9,
        "同阶来源读取完整参与集合、实际数量与精确牌型")
    _assert_equal(target.effective_value, cards[0].effective_qi_value(),
        "仅限功法值的修正不污染 target_query")
    var last_call: Dictionary = purpose_fixture["handler"].calls[0]
    _assert_equal(last_call["card_facts"].size(), 2,
        "查询公开本次全部真气事实")
    _assert_equal(last_call["exact_hand"]["id"], "pair",
        "查询公开精确牌型")
    _assert_true(last_call["subject"].has("anomalies") \
        and last_call["subject"].has("has_temporary_reshape") \
        and last_call["subject"].has("burned_out"),
        "逐牌事实公开异状、重塑与燃尽摘要")


func _test_modes_snapshot_and_fingerprints() -> void:
    var fixture := _fixture([
        _source("item", "stable", 0, {"delta": 4}),
    ])
    var owner = fixture["owner"]
    var card = _card("9", "mountain")
    owner.hand = [card]
    var snapshot: Array = fixture["service"].capture_source_snapshot(owner)
    var values: Array[int] = []
    for mode in ["preview", "confirm", "ai"]:
        values.append(int(fixture["service"].resolve_effective_qi(
            owner, card, {
                "purpose": "power_calculation",
                "evaluation_mode": mode,
                "cards": [card],
                "participating_card_ids": [str(card.id)],
                "hand_result": {"id": "high_card", "contributing": [card]},
                "source_snapshot": snapshot,
            }).effective_value))
    _assert_equal(values, [13, 13, 13],
        "同一来源快照下 preview、confirm 与 ai 同值")
    var ai_total: Dictionary = EnemyCandidateFeatureProjectorScript.new() \
        ._effective_qi_total(
            [card], owner, null, {
                "hand": {"id": "high_card", "contributing": [card]},
                "passive_power_query_inputs": {
                    "effective_qi_source_snapshot": snapshot,
                },
            }, 1, [str(card.id)])
    _assert_equal(ai_total.get("value", 0), 13,
        "AI候选评估复用功法值用途的统一查询")
    var ai_call: Dictionary = fixture["handler"].calls[-1]
    _assert_true(ai_call["purpose"] == "power_calculation" \
        and ai_call["evaluation_mode"] == "ai",
        "AI只改变评估模式，不改用另一套有效真气语义")
    var first = fixture["service"].resolve_effective_qi(owner, card, {
        "purpose": "effect_value", "evaluation_mode": "runtime",
        "source_snapshot": snapshot,
    })
    var second = fixture["service"].resolve_effective_qi(owner, card, {
        "purpose": "effect_value", "evaluation_mode": "runtime",
        "source_snapshot": snapshot,
    })
    _assert_equal(first.modifier_breakdown, second.modifier_breakdown,
        "source breakdown 重复查询稳定")
    _assert_equal(first.source_fingerprint, second.source_fingerprint,
        "source fingerprint 稳定")
    _assert_equal(first.request_fingerprint, second.request_fingerprint,
        "request fingerprint 不依赖 Object 地址")


func _test_confirmed_snapshot_vs_runtime() -> void:
    var fixture := _fixture([
        _source("item", "snapshot", 0, {"delta": 2}),
    ])
    var owner = fixture["owner"]
    var card = _card("6", "forest")
    owner.hand = [card]
    var hand := {"id": "high_card", "contributing": [card],
        "numeric_contributing": [card]}
    var confirmed = fixture["service"].resolve_effective_qi(owner, card, {
        "purpose": "power_calculation", "evaluation_mode": "confirm",
        "cards": [card], "participating_card_ids": [str(card.id)],
        "hand_result": hand,
    })
    var snapshot := HandGroupSnapshotScript.freeze(
        [card], hand, owner, null, [], {str(card.id): confirmed.to_dict()})
    _assert_equal(HandGroupSnapshotScript.frozen_effective_qi(snapshot, card), 8,
        "HandGroupSnapshot 保存确认时逐牌结果")
    card.set_anomaly("buff", "qi_heat", {}, 3)
    var runtime = fixture["service"].resolve_effective_qi(owner, card, {
        "purpose": "effect_value", "evaluation_mode": "runtime",
    })
    _assert_equal(runtime.effective_value, 11, "runtime 查询读取变化后的当前值")
    _assert_equal(HandGroupSnapshotScript.frozen_effective_qi(snapshot, card), 8,
        "确认快照与 runtime 当前值明确区分")


func _test_purity_and_failure_reporting() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 91001
    var fixture := _fixture([
        _source("item", "impure", 0, {
            "mutate_state": true, "advance_rng": true, "emit_event": true}),
    ], rng)
    fixture["handler"].battle_rng = rng
    fixture["handler"].event_service = fixture["event_service"]
    var owner = fixture["owner"]
    var card = _card("5", "wind")
    owner.hand = [card]
    var defense_before: int = owner.defense
    var rng_before: int = rng.state
    var emitted := {"count": 0}
    fixture["event_service"].event_committed.connect(
        func(_kind, _values, _receipt): emitted["count"] += 1)
    var impure = _query(fixture["service"], owner, card)
    _assert_true(not impure.success, "修改状态、推进 RNG 或发送事件令查询失败")
    _assert_equal(owner.defense, defense_before, "查询状态修改已回滚")
    _assert_equal(rng.state, rng_before, "查询不推进 RNG")
    _assert_equal(emitted["count"], 0, "查询不发送 committed 事件")

    var errors: Array[String] = []
    var failed_fixture := _fixture([
        _source("technique", "failure", 0, {"fail": true}),
    ], null, func(message: String): errors.append(message))
    failed_fixture["owner"].hand = [card]
    var failed = _query(
        failed_fixture["service"], failed_fixture["owner"], card)
    failed_fixture["service"].report_failure(failed, "effective_qi_test")
    _assert_true(not failed.success and failed.errors[0].contains(
        "Fake effective qi failure"), "查询失败不静默回退卡牌算法")
    _assert_true(not errors.is_empty() \
        and errors[0].contains("boundary=effective_qi_test"),
        "失败由正式边界走 scenario error 协议报告")
    var failed_context = BattleEffectContextScript.new().configure({
        "actor": failed_fixture["owner"],
        "hand_result": {"id": "high_card"},
    })
    var target_failure: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand",
        "order": "highest_effective_qi", "limit": 1,
    }).resolve(failed_context)
    _assert_true(not target_failure.get("success", false) \
        and str(target_failure.get("reason", "")).contains(
            "Fake effective qi failure"),
        "目标查询边界明确返回 effective_qi_query 失败")


func _test_power_target_and_value_spec_migrations() -> void:
    var engine = _engine(92001)
    var fixture := _fixture([
        _source("item", "all_use", 0, {"delta": 5}),
    ], engine.rng, Callable(engine, "_set_scenario_error"),
        engine.battle_passive_event_service)
    var service = fixture["service"]
    engine.player.use_battle_rule_query_service(service)
    engine.action_preview_service.battle_rule_query_service = service
    var low = _card("3", "wind")
    var high = _card("7", "forest")
    engine.player.hand = [low, high]
    var preview: Dictionary = engine.preview([str(low.id)])
    _assert_true(preview.get("valid", false), "ActionPreview 使用统一查询成功")
    _assert_equal(preview["values"]["effective_qi_queries"][
        str(low.id)]["effective_value"], 8, "预览公开逐牌查询回执")
    _assert_equal(preview["values"]["card_total"], 8,
        "PowerCalculator 的逐牌输入来自 effective_qi_query")

    var effect_context = BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports, "actor": engine.player,
        "target": engine.enemy, "source_kind": "technique",
        "hand_result": {"id": "high_card"},
    })
    var target_result: Dictionary = EffectTargetQueryScript.new().configure({
        "side": "actor", "zone": "hand",
        "order": "highest_effective_qi", "limit": 1,
    }).resolve(effect_context, engine.rng)
    _assert_true(target_result.get("success", false), "目标排序统一查询成功")
    _assert_equal(target_result["cards"][0], high,
        "目标排序消费统一有效真气值")

    var value_context = BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports, "actor": engine.player,
        "target": engine.enemy, "source_kind": "technique",
        "captures": {"chosen": [low]},
        "played_cards": [low],
        "hand_result": {"id": "high_card", "contributing": [low]},
        "group_snapshot": {},
    })
    var resolved_value := EffectValueResolverScript.new().resolve({
        "kind": "capture_current_effective_qi", "capture": "chosen",
    }, value_context)
    _assert_equal(resolved_value, 8, "ValueSpec 当前值入口消费统一查询")

    var confirmed: Dictionary = engine.action_preview_service \
        .recalculate_confirmed_power(
            engine.player, engine.enemy, preview, "effective-confirm-1")
    _assert_true(confirmed.get("success", false), "行动确认重新验证统一查询")
    _assert_equal(HandGroupSnapshotScript.frozen_effective_qi(
        preview["group_snapshot"], low), 8,
        "行动确认将最终逐牌值写入 HandGroupSnapshot")


func _fixture(
        sources: Array,
        rng: RandomNumberGenerator = null,
        scenario_error: Callable = Callable(),
        event_service_override = null) -> Dictionary:
    var handler := EffectiveQiProbeHandler.new()
    var registry = PassiveRuleHandlerRegistryScript.new(false)
    registry.register_handler(handler)
    var resolver = StaticSourceResolver.new(sources)
    var runtime = PassiveRuleRuntimeScript.new(
        registry, null, null, null, resolver)
    var owner = BattleSideScript.new("测试方", "effective-owner")
    owner.use_passive_rule_runtime(runtime)
    var event_service = event_service_override
    if event_service == null:
        event_service = CommittedEventServiceScript.new(runtime)
        event_service.open_battle([owner], "effective-query-test")
    var service = BattleRuleQueryServiceScript.new(runtime, scenario_error)
    if rng != null:
        service.use_rng(rng)
    service.use_committed_event_service(event_service)
    owner.use_battle_rule_query_service(service)
    return {
        "handler": handler, "registry": registry, "runtime": runtime,
        "owner": owner, "service": service, "event_service": event_service,
    }


func _source(
        source_kind: String, content_id: String, order: int,
        configuration: Dictionary):
    return PassiveRuleSourceScript.new().configure({
        "source_kind": source_kind,
        "content_id": content_id,
        "source_instance_key": "%s:test:%s" % [source_kind, content_id],
        "definition": {
            "id": content_id, "name": content_id,
            "behaviors": [{
                "id": "effective_qi_probe",
                "configuration": configuration.duplicate(true),
            }],
        },
        "behavior_id": "effective_qi_probe",
        "behavior_index": 0,
        "configuration": configuration,
        "source_order": order,
    })


func _query(service, owner, card):
    return service.resolve_effective_qi(owner, card, {
        "purpose": "effect_value", "evaluation_mode": "runtime",
    })


func _assert_query_matches_intrinsic(service, owner, card, label: String) -> void:
    _assert_equal(_query(service, owner, card).effective_value,
        card.effective_qi_value(), "%s不改变卡牌自身算法" % label)


func _ids(cards: Array) -> Array[String]:
    var result: Array[String] = []
    for card in cards:
        result.append(str(card.id))
    return result
