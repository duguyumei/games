extends "res://tests/support/expanded_technique_test_base.gd"

const BattleEffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const BattleRuntimeMutationTransactionScript = preload(
    "res://core/battle_runtime_mutation_transaction.gd")
const BattleObservationScript = preload("res://core/battle_observation.gd")
const AiBattleStateProjectorScript = preload(
    "res://core/ai/ai_battle_state_projector.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_card_lifecycle_and_transition_share_one_ordered_commit_chain()
    _test_effective_qi_preview_freeze_is_pure_and_reused()
    _test_compound_protocol_transaction_is_ordered_and_replayable()
    _test_ai_ui_and_observation_projections_are_pure()
    _test_card_reorder_and_dependency_access_stay_behind_formal_ports()
    _finish("C2 PROTOCOL INTEGRATION TEST")


func _test_card_lifecycle_and_transition_share_one_ordered_commit_chain() -> void:
    var engine = _engine(210001)
    var card = _card("K", "wind")
    engine.player.hand = [card]
    var metadata := _source_metadata(engine, "c2-lifecycle")
    engine.effect_ports.apply_card_anomaly(
        card, "buff", "growth", {}, "C2组合测试", 2, false, metadata)
    engine.effect_ports.apply_card_anomaly(
        card, "state", "poison", {}, "C2组合测试", 1, false, metadata)
    engine.effect_ports.apply_card_anomaly(
        card, "mark", "meridian", {}, "C2组合测试", 1, false, metadata)
    var events: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind in ["card_state_changed", "card_moved"]:
                events.append({
                    "kind": kind,
                    "values": values.duplicate(true),
                }))
    var moved: Dictionary = engine.effect_ports.move_card(
        engine.player, "hand", engine.player, "discard_pile", card,
        "explicit_discard", "top", metadata)
    _assert_true(moved.get("success", false),
        "带异状真气通过正式牌区端口完成移动")
    _assert_equal(events.map(func(entry): return entry["kind"]),
        ["card_state_changed", "card_moved"],
        "异状生命周期事实稳定先于牌区移动事实")
    _assert_equal(events[0]["values"].get("operation"), "lifecycle_remove",
        "离场状态聚合为唯一 lifecycle_remove")
    _assert_equal(events[0]["values"].get("removed_count"), 3,
        "成长、毒与经脉只由一份状态事实清除")
    _assert_equal(events.filter(func(entry):
        return entry["kind"] == "card_state_changed").size(), 1,
        "同牌同次生命周期只发布一次状态事实")
    _assert_equal(events.filter(func(entry):
        return entry["kind"] == "card_moved").size(), 1,
        "同牌同次移动只发布一次牌区事实")


func _test_effective_qi_preview_freeze_is_pure_and_reused() -> void:
    var engine = _engine(210002)
    var card = _card("7", "forest")
    engine.player.hand = [card]
    engine.actions_available = 1
    var state_before: Dictionary = engine.player.capture_passive_query_state()
    var event_before: Dictionary = \
        engine.battle_passive_event_service.capture_transaction_state()
    var queue_before: Dictionary = engine.trigger_queue.capture_runtime_state()
    var rng_before := int(engine.rng.state)
    var preview: Dictionary = engine.preview([str(card.id)])
    _assert_true(preview.get("valid", false), "有效真气预览成功")
    _assert_equal(engine.player.capture_passive_query_state(), state_before,
        "预览不修改卡牌、来源或战斗状态")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        event_before, "预览不产生 committed receipt 或 publication")
    _assert_equal(engine.trigger_queue.capture_runtime_state(), queue_before,
        "预览不写历史、延迟或响应记录")
    _assert_equal(int(engine.rng.state), rng_before, "预览不推进 RNG")
    var confirmed: Dictionary = engine.confirm_play([str(card.id)])
    _assert_true(confirmed.get("success", false), "相同卡牌正式确认成功")
    var preview_query: Dictionary = preview.get("values", {}).get(
        "effective_qi_queries", {}).get(str(card.id), {})
    var confirmed_query: Dictionary = confirmed.get("preview", {}).get(
        "values", {}).get("effective_qi_queries", {}).get(str(card.id), {})
    _assert_equal(confirmed_query.get("effective_value"),
        preview_query.get("effective_value"),
        "同一来源快照下预览与确认有效真气同值")
    _assert_equal(confirmed_query.get("source_fingerprint"),
        preview_query.get("source_fingerprint"),
        "正式确认复用同一来源快照指纹")


func _test_compound_protocol_transaction_is_ordered_and_replayable() -> void:
    serial = 900
    var first: Dictionary = _run_compound_protocol_transaction(210003)
    serial = 900
    var second: Dictionary = _run_compound_protocol_transaction(210003)
    _assert_true(first.get("success", false) and second.get("success", false),
        "跨协议组合事务可重复成功提交")
    var expected_kinds := [
        "card_state_changed", "card_state_changed", "card_moved",
        "qi_consumed", "damage_resolved", "source_marker_changed",
        "technique_execution_resolved",
    ]
    _assert_equal(first.get("event_kinds"), expected_kinds,
        "卡态、移动、支付、生命、marker与汇总按稳定顺序发布")
    _assert_equal(first.get("event_kinds"), second.get("event_kinds"),
        "相同输入重演得到相同事件顺序")
    _assert_equal(first.get("stable_trace"), second.get("stable_trace"),
        "相同输入重演得到相同业务事实投影")
    _assert_equal(first.get("state_before_publication"), [],
        "外层事务提交前不泄露任何 committed publication")
    _assert_equal(first.get("life_after"), 95,
        "伤害先经过统一生命写入边界再记录实际生命损失")
    _assert_equal(first.get("marker_value"), 2,
        "同一事务中的来源 marker 通过统一 Store 提交")
    _assert_equal(first.get("summary_life_lost"), 5,
        "功法执行汇总读取干预后的实际生命损失")
    _assert_true(first.get("consumed", false),
        "真气支付与异状生命周期、牌区移动整体成功")


func _run_compound_protocol_transaction(seed_value: int) -> Dictionary:
    var engine = _engine(seed_value)
    var card = _card("8", "fire")
    engine.player.hand = [card]
    var publications: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind in [
                    "card_state_changed", "card_moved", "qi_consumed",
                    "damage_resolved", "source_marker_changed",
                    "technique_execution_resolved"]:
                publications.append({
                    "kind": kind,
                    "values": values.duplicate(true),
                }))
    var context = BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "hand_result": {"id": "high_card", "contributing": [card]},
        "played_cards": [card],
        "group_snapshot": {
            "played_cards": [card], "contributing_cards": [card],
            "extra_cards": [], "action_same_qi_gain": 0,
        },
        "values": {"initial_power": 5, "technique_value": 5},
        "initial_power": 5,
        "power": 5,
        "technique_id": "c2_compound_probe",
        "technique_name": "C2组合探针",
        "technique_pool": "high",
        "action_token": "c2-compound-execution",
        "technique_execution_token": "c2-compound-execution",
        "technique_execution_state": {
            "pending_echo_plans": [], "next_echo_index": 0,
        },
        "root_action_token": "c2-compound-action",
        "slot_instance_id": "c2-compound-slot",
        "source_kind": "technique",
        "source_id": "c2_compound_probe",
        "source_name": "C2组合探针",
        "source_instance_key": "c2-compound-slot",
        "trigger_mode": "manual",
        "captures": {"payment": [card]},
        "sequence_book": engine.sequence_book,
        "card_identity_policy": engine.player.card_identity_policy,
    })
    var begun: Dictionary = engine.technique_resolution_service \
        ._begin_execution(engine.technique_resolution_service \
            ._execution_info_from_context(context, {
                "sequence_advance_requested": false,
                "same_qi_gain_enabled": false,
                "momentum_enabled": false,
                "sequence_before": [],
            }))
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        [engine.player, engine.enemy],
        engine.battle_passive_event_service,
        engine.trigger_queue,
        engine.rng)
    var effects_result: Dictionary = engine.effect_executor.execute_all([{
            "op": "apply_card_anomaly_to_captured",
            "capture": "payment",
            "category": "mark",
            "anomaly": "meridian",
        }, {
            "op": "consume_captured",
            "capture": "payment",
            "result_capture": "consumed",
            "exact_count": 1,
        }, {
            "op": "damage",
            "amount": 5,
        }, {
            "op": "write_source_marker",
            "marker_id": "audit_marker",
            "scope": "battle",
            "operation": "add",
            "amount": 2,
        }], context) if begun.get("success", false) else begun
    var before_publication := publications.map(func(entry): return entry["kind"])
    var resolved: Dictionary = effects_result
    if effects_result.get("success", false):
        BattleRuntimeMutationTransactionScript.commit(transaction)
        resolved = engine.technique_resolution_service.finish_execution(context)
    else:
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        engine.technique_resolution_service.discard_execution(
            context.technique_execution_token)
    var stable_trace: Array = publications.map(func(entry):
        var values: Dictionary = entry["values"]
        return {
            "kind": entry["kind"],
            "operation": str(values.get("operation", "")),
            "reason": str(values.get("reason", "")),
            "cause": str(values.get("cause", "")),
            "life_lost": int(values.get("life_lost", 0)),
            "delta": int(values.get("delta", 0)),
            "trigger_mode": str(values.get("trigger_mode", "")),
        })
    return {
        "success": bool(resolved.get("success", false)),
        "event_kinds": publications.map(func(entry): return entry["kind"]),
        "stable_trace": stable_trace,
        "state_before_publication": before_publication,
        "life_after": int(engine.enemy.life),
        "marker_value": engine.player.source_marker_store.value(
            "technique", "c2-compound-slot", "audit_marker", "battle"),
        "summary_life_lost": int(resolved.get(
            "summary", {}).get("target_life_lost", -1)),
        "consumed": engine.player.temporarily_removed_cards.has(card),
    }


func _test_ai_ui_and_observation_projections_are_pure() -> void:
    var engine = _engine(210004)
    engine.player.hand = [_card("6", "mountain")]
    var player_before: Dictionary = engine.player.capture_passive_query_state()
    var enemy_before: Dictionary = engine.enemy.capture_passive_query_state()
    var events_before: Dictionary = \
        engine.battle_passive_event_service.capture_transaction_state()
    var queue_before: Dictionary = engine.trigger_queue.capture_runtime_state()
    var rng_before := int(engine.rng.state)
    var observation = BattleObservationScript.new().capture(
        engine.player, engine.enemy, engine.sequence_book, engine.battle_flow)
    var ai_state: Dictionary = AiBattleStateProjectorScript.new().project_self(
        engine.player, engine.sequence_book, engine.battle_flow)
    var session = BattleSessionScript.new(engine)
    var ui_snapshot = session.snapshot()
    _assert_true(not observation.public_snapshot().is_empty(),
        "公共 BattleObservation 可正常建立")
    _assert_true(not ai_state.is_empty(), "AI 状态投影可正常建立")
    _assert_true(ui_snapshot != null, "UI BattleSnapshot 可正常建立")
    _assert_equal(engine.player.capture_passive_query_state(), player_before,
        "AI/UI/Observation 不改玩家运行状态或查询回执缓存")
    _assert_equal(engine.enemy.capture_passive_query_state(), enemy_before,
        "AI/UI/Observation 不改敌方运行状态或查询回执缓存")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        events_before, "AI/UI/Observation 不产生 committed 事实或 receipt")
    _assert_equal(engine.trigger_queue.capture_runtime_state(), queue_before,
        "AI/UI/Observation 不写历史、延迟或响应")
    _assert_equal(int(engine.rng.state), rng_before,
        "AI/UI/Observation 不推进 RNG")
    session.close_battle()


func _test_card_reorder_and_dependency_access_stay_behind_formal_ports() -> void:
    var engine = _engine(210005)
    var bottom = _card("2", "wind")
    var middle = _card("3", "forest")
    var top = _card("4", "fire")
    engine.player.draw_pile = [bottom, middle, top]
    var publications: Array[String] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, _values: Dictionary, _receipt: Dictionary):
            publications.append(kind))
    var context = BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "source_kind": "technique",
        "source_id": "reorder_probe",
        "source_instance_key": "reorder-probe-slot",
        "captures": {
            "inspected": [top, middle],
            "ordered": [middle, top],
        },
    })
    var reordered: Dictionary = engine.effect_executor.execute_all([{
        "op": "reorder_captured_draw_pile",
        "capture": "inspected",
        "ordered_capture": "ordered",
    }], context)
    _assert_true(reordered.get("success", false),
        "活跃重排内容经 BattleEffectPorts/CardZoneService 成功")
    _assert_equal(engine.player.draw_pile, [bottom, top, middle],
        "下沉牌区 Service 后保持既有牌序语义")
    _assert_true(publications.is_empty(),
        "同牌区重排不伪造 card_moved committed 事实")
    var stale: Dictionary = engine.effect_ports.reorder_draw_pile(
        engine.player, [bottom, middle, top], [top, middle, bottom])
    _assert_true(not stale.get("success", true),
        "原子重排拒绝已失效的冻结顺序")
    _assert_equal(engine.player.draw_pile, [bottom, top, middle],
        "失效重排不留下部分牌序写入")
    _assert_true(not engine.effect_executor.registry.has_handler("swap_hands"),
        "无调用且绕过牌区事实的旧 swap_hands op 已移除")
    _assert_true(engine.player.content_catalog() == engine.content_catalog,
        "BattleSide 通过正式只读接口公开内容目录依赖")
    _assert_true(engine.passive_rule_runtime.content_catalog() \
        == engine.content_catalog,
        "PassiveRuleRuntime 不再要求调用方读取 resolver 私有字段")


func _source_metadata(engine, action_token: String) -> Dictionary:
    return {
        "holder": engine.player,
        "source_actor": engine.player,
        "target": engine.enemy,
        "action_token": action_token,
        "source_kind": "technique",
        "source_id": "c2_integration_probe",
        "source_name": "C2组合探针",
        "source_instance_key": "c2-integration-slot",
        "trigger_mode": "manual",
    }
