extends "res://tests/support/expanded_technique_test_base.gd"

const BattleEffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const PassiveRuleHandlerRegistryScript = preload(
    "res://core/passives/passive_rule_handler_registry.gd")
const PassiveRuleRuntimeScript = preload(
    "res://core/passives/passive_rule_runtime.gd")
const PassiveRuleSourceScript = preload(
    "res://core/passives/passive_rule_source.gd")
const BattleRuleQueryServiceScript = preload(
    "res://core/passives/battle_rule_query_service.gd")

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


class FailingSummaryEventService:
    extends RefCounted

    var commit_calls := 0

    func next_serial() -> int:
        return commit_calls

    func make_token(
            event_kind: String,
            _actor,
            semantic_serial,
            action_token: String = "",
            _card_instance_id: String = "") -> String:
        return "fake|%s|%s|%s" % [
            event_kind, str(semantic_serial), action_token]

    func commit(event_kind: String, _values: Dictionary) -> Dictionary:
        commit_calls += 1
        if event_kind == "technique_execution_resolved":
            return {
                "success": false,
                "reason": "Fake summary handler failure",
            }
        return {"success": true, "receipt": {}}


class PreLifeLossCancelHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    var calls := 0

    func behavior_id() -> String:
        return "summary_pre_life_loss_cancel"

    func supported_hooks() -> Array[String]:
        return ["pre_life_loss_query"] as Array[String]

    func handle(
            _hook: String,
            context,
            _configuration: Dictionary) -> Dictionary:
        calls += 1
        var request = context.payload.get("int_query")
        return {
            "success": true,
            "value": 0 if request.proposed_life_loss > 0 \
                else int(request.current_value),
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
        return collect_sources(context).map(func(source):
            return source.to_dict())

    func equipped_inner_skill_entries(_context) -> Array:
        return []


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_manual_summary_and_order()
    _test_all_trigger_modes_and_echo_boundaries()
    _test_fact_attribution_and_intervened_life_loss()
    _test_continuation_replay_preview_and_cleanup()
    _test_failures_do_not_publish_or_advance()
    _test_nested_and_synchronized_attribution()
    _finish("TECHNIQUE EXECUTION SUMMARY TEST")


func _test_manual_summary_and_order() -> void:
    var engine = _manual_engine([
        {
            "id": "summary_manual",
            "name": "手动汇总探针",
            "pool": "high",
            "special": false,
            "effects": [
                {"op": "defense", "amount": 5},
                {"op": "remove_defense", "side": "target", "amount": 2},
                {"op": "heal_life", "amount": 4},
                {"op": "damage", "amount": 8},
                {"op": "damage", "amount": 3, "damage_type": "true"},
                {"op": "damage", "amount": 2, "damage_type": "poison"},
            ],
        },
        {
            "id": "summary_next",
            "name": "下一功法",
            "pool": "high",
            "special": false,
            "effects": [],
        },
    ], ["summary_manual", "summary_next"])
    engine.player.life = 90
    engine.enemy.defense = 4
    var publications: Array[Dictionary] = []
    var sequence_book_ref: WeakRef = weakref(engine.sequence_book)
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind in [
                    "technique_execution_resolved",
                    "technique_succeeded"]:
                var book: Variant = sequence_book_ref.get_ref()
                publications.append({
                    "kind": kind,
                    "values": values.duplicate(true),
                    "current_technique_id": book.current_id("high_card") \
                        if book != null else "",
                }))

    var played_id := str(engine.player.hand[0].id)
    var result: Dictionary = engine.confirm_play([played_id])
    var summaries: Array = _events_of(
        publications, "technique_execution_resolved")
    _assert_true(result.get("success", false),
        "手动功法成功完成行动")
    _assert_equal(summaries.size(), 1,
        "手动功法恰好提交一份执行汇总")
    if summaries.is_empty():
        return
    var summary: Dictionary = summaries[0]
    _assert_equal(summary.get("trigger_mode"), "manual",
        "手动汇总公开 manual trigger_mode")
    _assert_true(str(summary.get(
        "technique_execution_token", "")).contains(":technique:high_card:"),
        "手动 execution token 组合根行动、牌型和槽位")
    _assert_equal(summary.get("actor_defense_gained"), 5,
        "汇总读取 defense_gained 的实际获得量")
    _assert_equal(summary.get("target_defense_lost"), 4,
        "直接削防和伤害吸收各计一次且不重复")
    _assert_equal(summary.get("target_life_lost"), 11,
        "三类伤害的实际生命损失汇总正确")
    _assert_equal(summary.get("target_total_reduction"), 15,
        "目标总削减固定等于防御损失加生命损失")
    _assert_equal(summary.get("life_recovered"), 4,
        "汇总读取生命实际恢复量")
    _assert_equal(summary.get("requested_damage_total"), 13,
        "请求伤害总量按伤害段累计")
    _assert_equal(summary.get("final_damage_total"), 13,
        "最终伤害总量按已修正结果累计")
    _assert_equal(summary.get("damage_segment_count"), 3,
        "三个实际伤害段均进入汇总")
    _assert_equal([
        summary.get("normal_segment_count"),
        summary.get("true_segment_count"),
        summary.get("poison_segment_count"),
    ], [1, 1, 1], "普通、真伤、毒伤段分别计数")
    _assert_equal(summary.get("damage_segment_tokens", []).size(), 3,
        "汇总保留三份稳定伤害段 token")
    _assert_equal(summary.get("sequence_before", []).map(func(slot):
        return str(slot.get("technique_id", ""))),
        ["summary_manual", "summary_next"],
        "汇总冻结推进前的完整功法序列")
    var summary_index := _event_index(
        publications, "technique_execution_resolved")
    _assert_equal(publications[summary_index].get("current_technique_id"),
        "summary_manual", "执行汇总发布时功法序列尚未推进")
    _assert_true(summary_index < _event_index(
        publications, "technique_succeeded"),
        "执行汇总发生在兼容 technique_succeeded 之前")
    _assert_equal(publications[_event_index(
        publications, "technique_succeeded")].get("current_technique_id"),
        "summary_next", "technique_succeeded 发布时序列已完成推进")


func _test_all_trigger_modes_and_echo_boundaries() -> void:
    var engine = _engine(130002)
    _configure(engine, [
        {"id": "caller", "name": "调用者", "pool": "high",
            "special": false, "effects": []},
        {"id": "invoked_probe", "name": "调用探针", "pool": "high",
            "special": false, "effects": [{"op": "damage", "amount": 2}]},
        {"id": "automatic_probe", "name": "自动探针", "pool": "high",
            "special": false,
            "automatic_triggers": [{
                "id": "summary_auto",
                "event": "defense_gained",
                "filters": {"event_actor_is_owner": true},
                "p0": {"kind": "constant", "value": 1},
                "timing": "immediate",
            }],
            "effects": [{"op": "damage", "amount": 3}]},
    ], ["caller", "invoked_probe", "automatic_probe"])
    var summaries: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_execution_resolved":
                summaries.append(values.duplicate(true)))
    var caller_slot: Dictionary = engine.sequence_book.current_slot("high_card")
    var caller_context = _execution_context(
        engine, engine.player, engine.enemy, "caller",
        str(caller_slot.get("slot_instance_id", "")), "invoke-root", "manual")
    caller_context.technique_execution_token = ""
    caller_context.technique_execution_state = {}
    var invoked: Dictionary = engine.technique_invocation_service.invoke({
        "selection": {"mode": "by_id", "hand_id": "high_card",
            "technique_id": "invoked_probe"},
        "p0": {"mode": "fixed", "value": 1},
        "gain_same_qi": false,
    }, caller_context)
    _assert_true(invoked.get("success", false),
        "invoked 功法进入统一执行边界")
    _assert_equal(summaries.map(func(value):
        return str(value.get("trigger_mode", ""))), ["invoked"],
        "调用功法独立提交 invoked 汇总")

    var automatic_result: Dictionary = engine.effect_ports.add_defense_result(
        engine.player, 1, "rule", "automatic-summary-root")
    _assert_true(automatic_result.get("success", false),
        "自动功法由正式 committed 事实触发")
    _assert_true(summaries.any(func(value):
        return str(value.get("trigger_mode", "")) == "automatic"),
        "自动功法独立提交 automatic 汇总")

    var echo_engine = _manual_engine([{
        "id": "echo_probe",
        "name": "回响探针",
        "pool": "high",
        "special": false,
        "effects": [{
            "op": "repeat_effects",
            "count": 2,
            "effects": [{"op": "damage", "amount": 4}],
        }],
    }], ["echo_probe"])
    var echo_events: Array[Dictionary] = []
    echo_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind in ["technique_execution_resolved", "technique_succeeded"]:
                echo_events.append({"kind": kind,
                    "values": values.duplicate(true)}))
    var echo_result: Dictionary = echo_engine.confirm_play([
        str(echo_engine.player.hand[0].id)])
    var echo_summaries := _events_of(
        echo_events, "technique_execution_resolved")
    _assert_true(echo_result.get("success", false),
        "原执行和两次回响完整成功")
    _assert_equal(echo_summaries.size(), 3,
        "原执行加两次回响提交三份独立汇总")
    if echo_summaries.size() == 3:
        _assert_equal(echo_summaries.map(func(value):
            return str(value.get("trigger_mode", ""))),
            ["manual", "echo", "echo"],
            "原执行先汇总，随后按序汇总两次 echo")
        _assert_equal(echo_summaries.map(func(value):
            return int(value.get("target_life_lost", -1))),
            [0, 4, 4], "原执行和回响数值互不污染")
        _assert_equal(_unique_string_count(echo_summaries.map(func(value):
            return str(value.get("technique_execution_token", "")))),
            3, "每次回响拥有不同 execution token")
    _assert_true(_event_index(echo_events, "technique_succeeded") \
        > _last_event_index(echo_events, "technique_execution_resolved"),
        "全部回响汇总发生在父功法 sequence/succeeded 收尾之前")

    var retrigger_engine = _engine(130008)
    retrigger_engine.player.hand = [
        _card("6", "wind"), _card("6", "fire")]
    _configure_for_hand(retrigger_engine, [{
        "id": "retrigger_probe",
        "name": "重触探针",
        "pool": "pair",
        "special": false,
        "effects": [{"op": "damage", "amount": 2}],
    }], "pair", ["retrigger_probe"])
    var retrigger_summaries: Array[Dictionary] = []
    retrigger_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_execution_resolved":
                retrigger_summaries.append(values.duplicate(true)))
    var retrigger: Dictionary = retrigger_engine.action_resolver \
        .retrigger_current_hand_technique(
            retrigger_engine.player, retrigger_engine.enemy,
            retrigger_engine.sequence_book,
            {"initial_power": 1, "technique_value": 1}, 6, [])
    _assert_true(retrigger.get("success", false) \
        and retrigger.get("triggered", false),
        "retrigger 复用统一功法执行边界")
    _assert_equal(retrigger_summaries.size(), 1,
        "retrigger 提交一份独立汇总")
    if not retrigger_summaries.is_empty():
        _assert_equal(retrigger_summaries[0].get("trigger_mode"), "retrigger",
            "retrigger 汇总公开正确 trigger_mode")
        _assert_true(str(retrigger_summaries[0].get(
            "technique_execution_token", "")) != "",
            "retrigger execution token 稳定且非空")


func _test_fact_attribution_and_intervened_life_loss() -> void:
    var fixture := _pre_life_loss_fixture()
    var engine = fixture["engine"]
    engine.player.life = 90
    engine.enemy.defense = 5
    var token := "summary-attribution"
    var context = _execution_context(
        engine, engine.player, engine.enemy, "attribution_probe",
        "slot-attribution", token, "manual")
    var begun: Dictionary = engine.technique_resolution_service \
        ._begin_execution(engine.technique_resolution_service \
            ._execution_info_from_context(context, {
                "sequence_advance_requested": false,
                "same_qi_gain_enabled": false,
                "momentum_enabled": false,
                "sequence_before": [],
            }))
    _assert_true(begun.get("success", false),
        "事实归因测试建立单一 execution accumulator")
    var effects_result: Dictionary = engine.effect_executor.execute_all([
        {"op": "defense", "amount": 3},
        {"op": "remove_defense", "side": "actor", "amount": 1},
        {"op": "remove_defense", "side": "target", "amount": 1},
        {"op": "remove_defense", "side": "target", "amount": 1,
            "cause": "cost"},
        {"op": "damage", "amount": 6},
        {"op": "heal_life", "amount": 2},
    ], context)
    _assert_true(effects_result.get("success", false),
        "防御、伤害和恢复细粒度事实均成功提交")
    engine.effect_ports.add_defense_result(
        engine.player, 9, "item", token, {
            "source_kind": "item",
            "source_id": "foreign_item",
            "source_name": "外部物品",
            "source_instance_key": "item:foreign",
            "trigger_mode": "response",
        })
    engine.effect_ports.begin_action_resolution(
        [engine.player, engine.enemy], {
            "acting_owner_ids": [str(engine.player.owner_id)],
        })
    engine.effect_ports.grant_block_source(
        engine.enemy, engine.player, "unconditional", "汇总格挡")
    var blocked: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 7, context.source_metadata(), false,
        token, "normal", {"direct_attack": true})
    engine.effect_ports.abort_action_resolution()
    _assert_true(blocked.get("blocked", false),
        "被格挡伤害仍形成细粒度 blocked segment")
    var finished: Dictionary = engine.technique_resolution_service \
        .finish_execution(context)
    _assert_true(finished.get("success", false),
        "事实累计完成并提交唯一汇总")
    var summary: Dictionary = finished.get("summary", {})
    _assert_equal(summary.get("actor_defense_gained"), 3,
        "只统计当前功法自身的防御获得，不计物品响应")
    _assert_equal(summary.get("actor_defense_lost"), 1,
        "功法直接使自身减少的防御单独统计")
    _assert_equal(summary.get("target_defense_lost"), 4,
        "目标直接削防与伤害吸收计入，cost 不作为削防收益")
    _assert_equal(summary.get("target_life_lost"), 0,
        "生命写入前干预后的实际 life_lost 进入汇总")
    _assert_equal(summary.get("life_loss_canceled_segment_count"), 1,
        "生命保护取消段按 damage_resolved 事实计数")
    _assert_equal(summary.get("blocked_segment_count"), 1,
        "被格挡攻击计入 blocked segment")
    _assert_equal(summary.get("damage_segment_count"), 2,
        "取消生命损失和格挡仍各自保留伤害段")
    _assert_equal(summary.get("life_recovered"), 2,
        "恢复汇总读取实际 recovered_amount")
    _assert_equal(fixture["handler"].calls, 1,
        "只有击穿防御的非格挡段执行生命写入前干预")


func _test_continuation_replay_preview_and_cleanup() -> void:
    var engine = _engine(130004)
    var selectable = _card("8", "fire")
    var selectable_other = _card("9", "forest")
    engine.player.hand = [selectable, selectable_other]
    _configure(engine, [
        {"id": "caller", "name": "调用者", "pool": "high",
            "special": false, "effects": []},
        {"id": "waiting_probe", "name": "等待探针", "pool": "high",
            "special": false, "effects": [
                {"op": "damage", "amount": 1},
                {"op": "select_cards", "choice_id": "summary_wait",
                    "chooser": "actor", "minimum": 1, "maximum": 1,
                    "insufficient_policy": "fail",
                    "query": {"side": "actor", "zone": "hand",
                        "order": "zone",
                        "filters": {"card_kind": "normal"}},
                    "capture": "selected"},
                {"op": "damage", "amount": 2},
            ]},
    ], ["caller", "waiting_probe"])
    var summaries: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_execution_resolved":
                summaries.append(values.duplicate(true)))
    var caller_slot: Dictionary = engine.sequence_book.current_slot("high_card")
    var caller_context = _execution_context(
        engine, engine.player, engine.enemy, "caller",
        str(caller_slot.get("slot_instance_id", "")),
        "continuation-root", "manual")
    caller_context.technique_execution_token = ""
    caller_context.technique_execution_state = {}
    var pending: Dictionary = engine.effect_executor.execute_all([{
        "op": "invoke_sequence_technique",
        "selection": {"mode": "by_id", "hand_id": "high_card",
            "technique_id": "waiting_probe"},
        "gain_same_qi": false,
    }], caller_context)
    _assert_true(pending.get("pending_choice", false),
        "调用功法进入 continuation 等待")
    _assert_equal(summaries.size(), 0,
        "等待选择前不提前发送执行汇总")
    _assert_equal(engine.technique_resolution_service.pending_execution_count(), 1,
        "等待期间保留同一 execution accumulator")
    if pending.get("pending_choice", false):
        var request_id := str(pending.get(
            "choice_request", {}).get("request_id", ""))
        var resumed: Dictionary = engine.effect_executor.resume(
            pending.get("_continuation"), request_id, [str(selectable.id)])
        _assert_true(resumed.get("success", false),
            "continuation 恢复后完成原执行")
    _assert_equal(summaries.size(), 1,
        "continuation 恢复后只发送一次汇总")
    _assert_equal(engine.technique_resolution_service.pending_execution_count(), 0,
        "执行完成后清除等待累计器")
    if not summaries.is_empty():
        var replay: Dictionary = engine.battle_passive_event_service.commit(
            "technique_execution_resolved", summaries[0])
        _assert_true(replay.get("reused", false),
            "相同 committed receipt 重放复用既有汇总")
        _assert_equal(summaries.size(), 1,
            "receipt 重放不再次发布汇总")

    var preview_engine = _manual_engine([{
        "id": "preview_probe", "name": "预览探针", "pool": "high",
        "special": false, "effects": [{"op": "damage", "amount": 5}],
    }], ["preview_probe"])
    var preview_summaries: Array = []
    preview_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_execution_resolved":
                preview_summaries.append(values))
    preview_engine.preview([str(preview_engine.player.hand[0].id)])
    _assert_equal(preview_engine.technique_resolution_service \
        .pending_execution_count(), 0,
        "纯预览不建立执行累计器")
    _assert_equal(preview_summaries.size(), 0,
        "纯预览和候选枚举不发送执行汇总")

    var cleanup_context = _execution_context(
        preview_engine, preview_engine.player, preview_engine.enemy,
        "preview_probe", "cleanup-slot", "cleanup-token", "manual")
    preview_engine.technique_resolution_service._begin_execution(
        preview_engine.technique_resolution_service \
            ._execution_info_from_context(cleanup_context))
    _assert_equal(preview_engine.technique_resolution_service \
        .pending_execution_count(), 1,
        "清理前存在未完成执行")
    preview_engine.action_resolver.reset()
    _assert_equal(preview_engine.technique_resolution_service \
        .pending_execution_count(), 0,
        "行动重置清空未完成执行和重触序号")


func _test_failures_do_not_publish_or_advance() -> void:
    var condition_engine = _manual_engine([{
        "id": "condition_failure", "name": "条件失败探针", "pool": "high",
        "special": false, "condition": {"pure_attribute": "fire"},
        "effects": [{"op": "damage", "amount": 9}],
    }], ["condition_failure"])
    var condition_summaries: Array = []
    condition_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_execution_resolved":
                condition_summaries.append(values))
    condition_engine.confirm_play([str(condition_engine.player.hand[0].id)])
    _assert_equal(condition_summaries.size(), 0,
        "功法条件不满足不发送执行汇总")

    var permission_engine = _manual_engine([{
        "id": "permission_failure", "name": "权限拒绝探针", "pool": "high",
        "special": false, "effects": [{"op": "damage", "amount": 9}],
    }], ["permission_failure"])
    permission_engine.battle_permission_service.register_provider(
        func(hook: String, _context: Dictionary):
            return {"allowed": hook != "technique_activation_permission_query",
                "reason": "Fake deny"},
        "summary-deny", 999, ["technique_activation_permission_query"])
    var permission_summaries: Array = []
    permission_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_execution_resolved":
                permission_summaries.append(values))
    permission_engine.confirm_play([str(permission_engine.player.hand[0].id)])
    _assert_equal(permission_summaries.size(), 0,
        "功法启动权限拒绝不发送执行汇总")

    var effect_engine = _engine(130009)
    var effect_summaries: Array = []
    effect_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_execution_resolved":
                effect_summaries.append(values))
    var effect_context = _execution_context(
        effect_engine, effect_engine.player, effect_engine.enemy,
        "effect_failure", "effect-failure-slot",
        "effect-failure-token", "manual")
    var effect_result: Dictionary = effect_engine.technique_resolution_service \
        .resolve_direct_execution({}, effect_context, [{
            "op": "select_cards", "choice_id": "must_fail",
            "chooser": "actor", "minimum": 1, "maximum": 1,
            "insufficient_policy": "fail",
            "query": {"side": "actor", "zone": "hand", "order": "zone",
                "filters": {"card_kind": "normal"}},
            "capture": "selected",
        }])
    _assert_true(not effect_result.get("success", true),
        "效果执行失败向行动边界传播")
    _assert_equal(effect_summaries.size(), 0,
        "效果执行失败丢弃累计器且不发送汇总")

    var advance_engine = _manual_engine([
        {"id": "advance_only_probe", "name": "仅推进探针", "pool": "high",
            "special": false, "manual_effect_mode": "advance_only",
            "effects": [{"op": "damage", "amount": 99}]},
        {"id": "advance_next", "name": "推进目标", "pool": "high",
            "special": false, "effects": []},
    ], ["advance_only_probe", "advance_next"])
    var advance_summaries: Array[Dictionary] = []
    advance_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_execution_resolved":
                advance_summaries.append(values.duplicate(true)))
    var advance_result: Dictionary = advance_engine.confirm_play([
        str(advance_engine.player.hand[0].id)])
    _assert_true(advance_result.get("success", false),
        "advance_only 手动功法仍视为成功执行")
    _assert_equal(advance_summaries.size(), 1,
        "advance_only 提交一份零结果汇总")
    if not advance_summaries.is_empty():
        _assert_true(advance_summaries[0].get(
            "manual_effect_suppressed", false),
            "advance_only 明确标记 manual_effect_suppressed")
        _assert_equal(advance_summaries[0].get("damage_segment_count"), 0,
            "advance_only 不执行原效果且数值为零")

    var handler_engine = _manual_engine([
        {"id": "handler_failure", "name": "汇总失败探针", "pool": "high",
            "special": false, "effects": []},
        {"id": "handler_next", "name": "不应推进", "pool": "high",
            "special": false, "effects": []},
    ], ["handler_failure", "handler_next"])
    var slot_before := str(handler_engine.sequence_book.current_slot(
        "high_card").get("slot_instance_id", ""))
    var fake_service := FailingSummaryEventService.new()
    handler_engine.technique_resolution_service._event_service = fake_service
    var failed_summary_result: Dictionary = handler_engine.confirm_play([
        str(handler_engine.player.hand[0].id)])
    _assert_true(not failed_summary_result.get("success", true),
        "汇总 Handler 失败令当前行动正式失败")
    _assert_equal(str(handler_engine.sequence_book.current_slot(
        "high_card").get("slot_instance_id", "")), slot_before,
        "汇总 Handler 失败不推进当前功法槽位")
    _assert_equal(fake_service.commit_calls, 1,
        "失败汇总边界只尝试提交一次")


func _test_nested_and_synchronized_attribution() -> void:
    var nested_engine = _engine(130006)
    _configure(nested_engine, [
        {"id": "parent_probe", "name": "父功法", "pool": "high",
            "special": false, "effects": []},
        {"id": "child_probe", "name": "子功法", "pool": "high",
            "special": false, "effects": [{"op": "damage", "amount": 4}]},
    ], ["parent_probe", "child_probe"])
    var nested_summaries: Array[Dictionary] = []
    nested_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_execution_resolved":
                nested_summaries.append(values.duplicate(true)))
    var parent_slot: Dictionary = nested_engine.sequence_book.current_slot(
        "high_card")
    var parent_context = _execution_context(
        nested_engine, nested_engine.player, nested_engine.enemy,
        "parent_probe", str(parent_slot.get("slot_instance_id", "")),
        "nested-parent", "manual")
    var nested: Dictionary = nested_engine.technique_resolution_service \
        .resolve_direct_execution({}, parent_context, [{
            "op": "invoke_sequence_technique",
            "selection": {"mode": "by_id", "hand_id": "high_card",
                "technique_id": "child_probe"},
            "gain_same_qi": false,
        }])
    _assert_true(nested.get("success", false),
        "父功法内嵌调用通过统一调用边界")
    _assert_equal(nested_summaries.size(), 2,
        "父功法和子功法各自产生独立汇总")
    if nested_summaries.size() == 2:
        var parent_summary: Dictionary = nested_summaries.filter(func(value):
            return str(value.get("technique_id", "")) == "parent_probe")[0]
        var child_summary: Dictionary = nested_summaries.filter(func(value):
            return str(value.get("technique_id", "")) == "child_probe")[0]
        _assert_equal(parent_summary.get("target_life_lost"), 0,
            "子功法伤害不污染父功法汇总")
        _assert_equal(child_summary.get("target_life_lost"), 4,
            "子功法只统计自身 execution token 的伤害")
        _assert_equal(child_summary.get("caller_technique_id"), "parent_probe",
            "子功法汇总公开稳定 caller_technique_id")

    var sync_engine = _engine(130007)
    var player_context = _execution_context(
        sync_engine, sync_engine.player, sync_engine.enemy,
        "sync_player", "sync-player-slot", "sync-player-token", "manual")
    var enemy_context = _execution_context(
        sync_engine, sync_engine.enemy, sync_engine.player,
        "sync_enemy", "sync-enemy-slot", "sync-enemy-token", "manual")
    sync_engine.technique_resolution_service._begin_execution(
        sync_engine.technique_resolution_service \
            ._execution_info_from_context(player_context))
    sync_engine.technique_resolution_service._begin_execution(
        sync_engine.technique_resolution_service \
            ._execution_info_from_context(enemy_context))
    sync_engine.effect_ports.begin_synchronized_damage([
        {"actor": sync_engine.player},
        {"actor": sync_engine.enemy},
    ])
    var player_buffer: Dictionary = sync_engine.effect_executor.execute_all([
        {"op": "damage", "amount": 5}], player_context)
    var enemy_buffer: Dictionary = sync_engine.effect_executor.execute_all([
        {"op": "damage", "amount": 3}], enemy_context)
    _assert_true(player_buffer.get("success", false) \
        and enemy_buffer.get("success", false),
        "同步 shadow 阶段接受双方独立功法伤害")
    _assert_equal(sync_engine.enemy.life, 100,
        "同步 shadow 阶段不提前写入真实生命")
    var flushed: Dictionary = sync_engine.effect_ports \
        .flush_synchronized_damage()
    _assert_true(flushed.get("success", false),
        "同步伤害按稳定段顺序统一 flush")
    var player_finished: Dictionary = sync_engine.technique_resolution_service \
        .finish_execution(player_context)
    var enemy_finished: Dictionary = sync_engine.technique_resolution_service \
        .finish_execution(enemy_context)
    _assert_equal(player_finished.get("summary", {}).get(
        "target_life_lost"), 5,
        "同步行动中玩家功法只归因自己的伤害")
    _assert_equal(enemy_finished.get("summary", {}).get(
        "target_life_lost"), 3,
        "同步行动中敌方功法只归因自己的伤害")
    _assert_true(str(player_finished.get("summary", {}).get(
        "technique_execution_token", "")) != str(enemy_finished.get(
            "summary", {}).get("technique_execution_token", "")),
        "同步双方保持不同 execution token")


func _manual_engine(definitions: Array, sequence: Array):
    var engine = _engine(130000 + assertions)
    engine.player.hand = [_card("7", "wind")]
    engine.player.draw_pile.clear()
    engine.actions_available = 1
    _configure(engine, definitions, sequence)
    return engine


func _configure(engine, definitions: Array, sequence: Array) -> void:
    _configure_for_hand(engine, definitions, "high_card", sequence)


func _configure_for_hand(
        engine,
        definitions: Array,
        hand_id: String,
        sequence: Array) -> void:
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {},
        "resource_paths": [],
        "techniques": definitions,
    })
    engine.sequence_book.configure({hand_id: sequence})


func _execution_context(
        engine,
        actor,
        target,
        technique_id: String,
        slot_instance_id: String,
        token: String,
        trigger_mode: String):
    return BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": actor,
        "target": target,
        "hand_result": {"id": "high_card", "contributing": []},
        "played_cards": [],
        "group_snapshot": {
            "played_cards": [],
            "contributing_cards": [],
            "extra_cards": [],
            "action_same_qi_gain": 0,
        },
        "values": {"initial_power": 1, "technique_value": 1},
        "initial_power": 1,
        "power": 1,
        "technique_id": technique_id,
        "technique_name": technique_id,
        "technique_pool": "high",
        "action_token": token,
        "technique_execution_token": token,
        "technique_execution_state": {
            "pending_echo_plans": [],
            "next_echo_index": 0,
        },
        "root_action_token": token,
        "slot_instance_id": slot_instance_id,
        "source_kind": "technique",
        "source_id": technique_id,
        "source_name": technique_id,
        "source_instance_key": slot_instance_id,
        "trigger_mode": trigger_mode,
        "captures": {},
        "sequence_book": engine.sequence_book,
        "card_identity_policy": actor.card_identity_policy,
    })


func _pre_life_loss_fixture() -> Dictionary:
    var engine = _engine(130003)
    var handler := PreLifeLossCancelHandler.new()
    var registry = PassiveRuleHandlerRegistryScript.new(false)
    registry.register_handler(handler)
    var source = PassiveRuleSourceScript.new().configure({
        "source_kind": "item",
        "content_id": "fake_summary_guard",
        "source_instance_key": "item:test:summary_guard",
        "definition": {
            "id": "fake_summary_guard",
            "name": "汇总生命保护夹具",
            "behaviors": [{
                "id": "summary_pre_life_loss_cancel",
                "configuration": {},
            }],
        },
        "behavior_id": "summary_pre_life_loss_cancel",
        "behavior_index": 0,
        "configuration": {},
        "source_order": 0,
    })
    var runtime = PassiveRuleRuntimeScript.new(
        registry, null, null, null, StaticSourceResolver.new([source]))
    var service = BattleRuleQueryServiceScript.new(runtime)
    service.use_rng(engine.rng)
    service.use_committed_event_service(engine.battle_passive_event_service)
    engine.player.use_battle_rule_query_service(service)
    engine.enemy.use_battle_rule_query_service(service)
    engine.effect_ports.use_passive_battle_services(
        service, engine.battle_passive_event_service)
    return {"engine": engine, "handler": handler, "runtime": runtime}


func _events_of(events: Array, kind: String) -> Array:
    return events.filter(func(entry):
        return str(entry.get("kind", "")) == kind).map(func(entry):
            return entry.get("values", {}))


func _event_index(events: Array, kind: String) -> int:
    for index in range(events.size()):
        if str(events[index].get("kind", "")) == kind:
            return index
    return -1


func _last_event_index(events: Array, kind: String) -> int:
    for index in range(events.size() - 1, -1, -1):
        if str(events[index].get("kind", "")) == kind:
            return index
    return -1


func _unique_string_count(values: Array) -> int:
    var unique: Dictionary = {}
    for value in values:
        unique[str(value)] = true
    return unique.size()
