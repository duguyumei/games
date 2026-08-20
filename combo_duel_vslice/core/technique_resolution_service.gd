class_name TechniqueResolutionService
extends RefCounted

const EffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")
const TechniquePhaseCatalogScript = preload(
    "res://core/effects/technique_phase_catalog.gd")
const BattleRuntimeMutationTransactionScript = preload(
    "res://core/battle_runtime_mutation_transaction.gd")

const PENDING_CAPTURE := "__technique_resolution_pending"

var _repository
var _executor
var _ports
var _event_service
var _passive_runtime
var _active_executions: Dictionary = {}
var _completed_summaries: Dictionary = {}

func _init(repository, executor, ports, event_service) -> void:
    _repository = repository
    _executor = executor
    _ports = ports
    _event_service = event_service
    if _event_service != null:
        _event_service.register_weak_listener(
            self, "_on_committed_fact_for_execution")

func reset() -> void:
    _active_executions.clear()
    _completed_summaries.clear()

func use_passive_runtime(runtime) -> void:
    _passive_runtime = runtime

func discard_all_pending_executions() -> void:
    _active_executions.clear()

func pending_execution_count() -> int:
    return _active_executions.size()

func pending_echo_count(context) -> int:
    var runtime = EffectContextScript.coerce(context)
    return runtime.technique_execution_state.get("pending_echo_plans", []).size()

func append_current_technique_echo(
        context, count: int, effects: Array = []) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    var token := str(runtime.technique_execution_token)
    if token == "" or runtime.trigger_mode == "echo" \
            or _execution_is_echo(token):
        return {"success": false, "reason": "回响执行不能登记新的回响"}
    if count < 0:
        return {"success": false, "reason": "回响次数不能为负数"}
    var state: Dictionary = runtime.technique_execution_state
    if state.is_empty():
        return {"success": false, "reason": "当前功法缺少执行状态"}
    if not state.has("pending_echo_plans"):
        state["pending_echo_plans"] = []
    if not state.has("next_echo_index"):
        state["next_echo_index"] = 0
    var frozen_effects: Array = effects.duplicate(true)
    if frozen_effects.is_empty():
        frozen_effects = state.get("echo_effects", []).duplicate(true)
    for _index in range(count):
        var echo_index := int(state["next_echo_index"])
        state["next_echo_index"] = echo_index + 1
        state["pending_echo_plans"].append({
            "echo_index": echo_index,
            "effects": frozen_effects.duplicate(true),
            "frozen_context": _echo_context_snapshot(runtime),
        })
    return {"success": true, "added": count,
        "planned": state["pending_echo_plans"].size()}

func request_extra_sequence_advance(
        context, count: int, source_record: Dictionary = {}) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    if runtime.trigger_mode == "echo" or _execution_is_echo(
            str(runtime.technique_execution_token)):
        return {"success": false, "reason": "回响执行不能登记额外序列推进"}
    if count < 0:
        return {"success": false, "reason": "额外序列推进不能为负数"}
    var state: Dictionary = runtime.technique_execution_state
    if state.is_empty():
        return {"success": false, "reason": "当前功法缺少执行状态"}
    if not state.has("extra_sequence_advance_requests"):
        state["extra_sequence_advance_requests"] = []
    if count > 0:
        var record := source_record.duplicate(true)
        record["count"] = count
        state["extra_sequence_advance_requests"].append(record)
    return {"success": true, "added": count,
        "total": _extra_advance_count(state)}

func grant_pending_slot_echo(
        context, target_slot_instance_id: String, granted_count: int,
        grant_event_token: String = "") -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    if target_slot_instance_id == "" or granted_count <= 0:
        return {"success": false, "reason": "待用回响目标或次数无效"}
    if runtime.ports == null:
        return {"success": false, "reason": "待用回响缺少战斗端口"}
    var marker_definition := _marker_definition(
        runtime.source_marker_definitions, "pending_slot_echoes")
    if marker_definition.is_empty():
        return {"success": false, "reason": "当前来源未声明待用回响 marker"}
    var source := {
        "source_kind": runtime.source_kind,
        "source_instance_key": runtime.source_instance_key,
        "content_id": runtime.source_id,
        "marker_id": "pending_slot_echoes",
        "scope": str(marker_definition.get("scope", "battle")),
        "public": bool(marker_definition.get("public", true)),
        "display_name": str(marker_definition.get(
            "display_name", "待用功法回响")),
        "forget_policy": str(marker_definition.get(
            "forget_policy", "clear")),
        "marker_role": str(marker_definition.get(
            "marker_role", "pending_technique_echo")),
    }
    var insertion_serial: int = runtime.actor.source_marker_store.records(
        runtime.source_kind, runtime.source_instance_key,
        "pending_slot_echoes", "battle").size()
    var record := {
        "target_slot_instance_id": target_slot_instance_id,
        "granted_count": granted_count,
        "source_instance_key": runtime.source_instance_key,
        "grant_event_token": grant_event_token if grant_event_token != "" \
            else runtime.action_token,
        "insertion_serial": insertion_serial,
    }
    return runtime.ports.append_source_marker_records(
        runtime.actor, source, [record], runtime.action_token)

func extra_sequence_advance_count(context) -> int:
    var runtime = EffectContextScript.coerce(context)
    return _extra_advance_count(runtime.technique_execution_state)

func cleanup_pending_slot_echoes(
        side, slot_instance_ids: Array,
        action_token: String = "") -> Dictionary:
    if side == null or slot_instance_ids.is_empty():
        return {"success": true, "consumed": 0, "results": []}
    var stable_ids: Array = []
    for value in slot_instance_ids:
        var slot_id := str(value)
        if slot_id != "" and not stable_ids.has(slot_id):
            stable_ids.append(slot_id)
    if stable_ids.is_empty():
        return {"success": true, "consumed": 0, "results": []}
    var consumed_count := 0
    var results: Array = []
    for entry_value in side.source_marker_store.entries({
            "marker_id": "pending_slot_echoes", "scope": "battle"}):
        var entry: Dictionary = entry_value
        var source := {
            "source_kind": str(entry.get("source_kind", "")),
            "source_instance_key": str(entry.get(
                "source_instance_key", "")),
            "content_id": str(entry.get("content_id", "")),
            "marker_id": "pending_slot_echoes",
            "scope": "battle",
            "public": bool(entry.get("public", true)),
            "display_name": str(entry.get(
                "display_name", "待用功法回响")),
            "forget_policy": str(entry.get("forget_policy", "clear")),
            "marker_role": str(entry.get(
                "marker_role", "pending_technique_echo")),
            "remove_zero": true,
        }
        var consumed: Dictionary = _ports \
            .consume_matching_source_marker_records(
                side, source,
                {"target_slot_instance_id": stable_ids},
                -1, action_token)
        if not consumed.get("success", false):
            return consumed
        consumed_count += int(consumed.get("consumed", 0))
        results.append(consumed)
    return {
        "success": true,
        "consumed": consumed_count,
        "slot_instance_ids": stable_ids,
        "results": results,
    }

func begin_manual_execution(record) -> Dictionary:
    var preview: Dictionary = record["preview"]
    var technique: Dictionary = preview.get("technique", {})
    if technique.is_empty():
        return {"success": false, "reason": "手动功法执行缺少功法定义"}
    var root_token := str(record["token"])
    var hand_id := str(preview.get("hand", {}).get("id", ""))
    var slot_id := str(preview.get("slot_instance_id", ""))
    var sequence_before: Array = record["book"].ordered_slots(hand_id) \
        if record.get("book") != null else []
    var token := "%s:technique:%s:%s" % [root_token, hand_id, slot_id]
    record.technique_execution_token = token
    record.technique_execution_state = {
        "pending_echo_plans": [],
        "next_echo_index": 0,
        "extra_sequence_advance_requests": [],
        "echo_effects": technique.get("effects", []).duplicate(true),
    }
    return _begin_execution({
        "technique_execution_token": token,
        "root_action_token": root_token,
        "invocation_token": "",
        "caller_technique_id": "",
        "actor": record["actor"],
        "target": record["target"],
        "source_kind": "technique",
        "source_id": str(technique.get("id", "")),
        "source_name": str(technique.get("name", "")),
        "source_instance_key": slot_id,
        "technique_id": str(technique.get("id", "")),
        "technique_pool": str(technique.get("pool", "")),
        "slot_instance_id": slot_id,
        "hand_id": hand_id,
        "initial_power": int(preview.get("values", {}).get("initial_power", 0)),
        "technique_power": int(preview.get("values", {}).get("technique_value", 0)),
        "trigger_mode": "manual",
        "round_number": int(record["turn_number"]),
        "is_echo": false,
        "manual_effect_suppressed": str(technique.get(
            "manual_effect_mode", "normal")) == "advance_only",
        "sequence_advance_requested": true,
        "same_qi_gain_enabled": true,
        "momentum_enabled": true,
        "sequence_before": sequence_before.duplicate(true),
        "technique_execution_state": record.technique_execution_state,
        "group_snapshot": preview.get("group_snapshot", {}),
        "played_cards": preview.get("cards", []).duplicate(),
        "temporary": _slot_is_temporary(record["book"], slot_id),
    })

func finish_manual_execution(record) -> Dictionary:
    var preview: Dictionary = record["preview"]
    var technique: Dictionary = preview.get("technique", {})
    var context = EffectContextScript.new().configure({
        "ports": _ports,
        "actor": record["actor"],
        "target": record["target"],
        "hand_result": preview.get("hand", {}),
        "played_cards": preview.get("cards", []),
        "group_snapshot": preview.get("group_snapshot", {}),
        "values": preview.get("values", {}),
        "power": int(preview.get("values", {}).get("technique_value", 0)),
        "initial_power": int(preview.get("values", {}).get("initial_power", 0)),
        "technique_id": str(technique.get("id", "")),
        "technique_name": str(technique.get("name", "")),
        "technique_pool": str(technique.get("pool", "")),
        "action_token": str(record.technique_execution_token),
        "technique_execution_token": str(record.technique_execution_token),
        "technique_execution_state": record.technique_execution_state,
        "root_action_token": str(record["token"]),
        "slot_instance_id": str(preview.get("slot_instance_id", "")),
        "source_kind": "technique",
        "source_id": str(technique.get("id", "")),
        "source_name": str(technique.get("name", "")),
        "source_instance_key": str(preview.get("slot_instance_id", "")),
        "trigger_mode": "manual",
        "captures": record["captures_by_source"].get("technique", {}),
        "sequence_book": record["book"],
        "card_identity_policy": record["actor"].card_identity_policy,
        "passive_rule_runtime": _passive_runtime,
    })
    return finish_execution(context)

func resolve_direct_execution(
        definition,
        context,
        effects: Array,
        options: Dictionary = {}) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    runtime.passive_rule_runtime = _passive_runtime
    _ensure_execution_state(runtime, effects)
    var begun := _begin_execution(_execution_info_from_context(runtime, options))
    if not begun.get("success", false):
        return begun
    var result: Dictionary = _executor.execute_all(effects, runtime)
    if result.get("pending_choice", false):
        discard_execution(runtime.technique_execution_token)
        return {
            "success": false,
            "pending_choice": true,
            "reason": "直接功法执行尚未接管 continuation",
        }
    if not result.get("success", false):
        discard_execution(runtime.technique_execution_token)
        return {
            "success": false,
            "reason": str(result.get("detail", "功法效果执行失败")),
        }
    var completed := finish_execution(runtime)
    completed["effect_result"] = result
    return completed

func discard_execution(technique_execution_token: String) -> void:
    _active_executions.erase(technique_execution_token)

func finish_execution(context) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    var token := str(runtime.technique_execution_token)
    if token == "":
        return {"success": false, "reason": "功法执行汇总缺少 execution token"}
    if _completed_summaries.has(token):
        var reused_summary: Dictionary = _completed_summaries[token].duplicate(true)
        return {
            "success": true,
            "reused": true,
            "summary": reused_summary,
            "echo_results": [],
            "extra_sequence_advance_count": int(reused_summary.get(
                "extra_sequence_advance_count", 0)),
            "extra_sequence_advance_sources": reused_summary.get(
                "extra_sequence_advance_sources", []).duplicate(true),
        }
    if not _active_executions.has(token):
        return {"success": false, "reason": "功法执行累计器不存在或已失效"}
    _sync_pending_facts_for_execution(token)
    var local_snapshot := {
        "active_executions": _active_executions.duplicate(true),
        "completed_summaries": _completed_summaries.duplicate(true),
        "execution_state": runtime.technique_execution_state.duplicate(true),
        "passive_effect_state": _passive_runtime \
            .capture_battle_effect_command_state() \
            if _passive_runtime != null else {},
    }
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        _ports.transaction_sides() if _ports.has_method(
            "transaction_sides") else [runtime.actor, runtime.target],
        _event_service,
        _ports.transaction_trigger_queue() if _ports.has_method(
            "transaction_trigger_queue") else null,
        _ports.battle_rng() if _ports.has_method("battle_rng") else null)
    var state: Dictionary = runtime.technique_execution_state
    _active_executions[token]["extra_sequence_advance_count"] = \
        _extra_advance_count(state)
    _active_executions[token]["extra_sequence_advance_sources"] = state.get(
        "extra_sequence_advance_requests", []).duplicate(true)
    var summary_result := _commit_execution_summary(token)
    if not summary_result.get("success", false):
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        _restore_finish_local_state(runtime, local_snapshot)
        return summary_result
    summary_result["summary"]["extra_sequence_advance_count"] = \
        _extra_advance_count(state)
    summary_result["summary"]["extra_sequence_advance_sources"] = \
        state.get("extra_sequence_advance_requests", []).duplicate(true)
    _completed_summaries[token] = summary_result.get(
        "summary", {}).duplicate(true)
    var pending_reward := _consume_pending_slot_echoes(runtime)
    if not pending_reward.get("success", false):
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        _restore_finish_local_state(runtime, local_snapshot)
        return {
            "success": false,
            "reason": str(pending_reward.get("reason", "待用回响消费失败")),
            "summary": summary_result.get("summary", {}),
            "echo_results": [],
        }
    var echoes := _resolve_echo_plans(runtime)
    if not echoes.get("success", false):
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        _restore_finish_local_state(runtime, local_snapshot)
        return {
            "success": false,
            "reason": str(echoes.get("reason", "功法回响执行失败")),
            "summary": summary_result.get("summary", {}),
            "echo_results": echoes.get("results", []),
        }
    var post_success := _dispatch_post_success_pre_advance(
        runtime, summary_result.get("summary", {}),
        echoes.get("results", []))
    if not post_success.get("success", false):
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        _restore_finish_local_state(runtime, local_snapshot)
        return {
            "success": false,
            "reason": str(post_success.get(
                "reason", "功法成功后推进前阶段失败")),
            "summary": summary_result.get("summary", {}),
            "echo_results": echoes.get("results", []),
            "post_success": post_success,
        }
    _active_executions.erase(token)
    BattleRuntimeMutationTransactionScript.commit(transaction)
    return {
        "success": true,
        "reused": false,
        "summary": summary_result.get("summary", {}),
        "receipt": summary_result.get("receipt", {}),
        "echo_results": echoes.get("results", []),
        "post_success": post_success,
        "extra_sequence_advance_count": _extra_advance_count(state),
        "extra_sequence_advance_sources": state.get(
            "extra_sequence_advance_requests", []).duplicate(true),
    }

func has_pending_invocation(context) -> bool:
    var runtime = EffectContextScript.coerce(context)
    return runtime.captures.has(PENDING_CAPTURE)

func pending_slot_instance_id(context) -> String:
    var runtime = EffectContextScript.coerce(context)
    var state: Dictionary = runtime.captures.get(PENDING_CAPTURE, {})
    return str(state.get("slot_instance_id", ""))

func resolve_invocation(request: Dictionary, context) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    if runtime.captures.has(PENDING_CAPTURE):
        return _resume_invocation(runtime)
    var prepared: Dictionary = request.get("_resolution_preflight", {})
    if prepared.is_empty():
        prepared = prepare_invocation(request, runtime)
    if not prepared.get("success", false) \
            or not prepared.get("triggered", true):
        return prepared
    var slot: Dictionary = request.get("slot", {})
    var definition = prepared["definition"]
    var effect: Dictionary = request.get("effect", {})
    var invocation_hand_result: Dictionary = request.get(
        "hand_result", runtime.hand_result)
    var power_result: Dictionary = prepared["power_result"]
    var values: Dictionary = power_result["values"]
    var token := str(request.get("invocation_token", ""))
    var execution_state := {
        "pending_echo_plans": [],
        "next_echo_index": 0,
        "extra_sequence_advance_requests": [],
        "echo_effects": definition.effects.duplicate(true),
    }
    var invoked_context = EffectContextScript.new().configure({
        "ports": _ports, "actor": runtime.actor, "target": runtime.target,
        "hand_result": invocation_hand_result,
        "played_cards": runtime.played_cards,
        "group_snapshot": runtime.group_snapshot,
        "values": values, "power": int(values["technique_value"]),
        "initial_power": int(values["initial_power"]),
        "technique_id": definition.id,
        "technique_name": definition.display_name,
        "technique_pool": definition.pool,
        "action_token": token,
        "technique_execution_token": token,
        "technique_execution_state": execution_state,
        "root_action_token": str(request.get("root_action_token", token)),
        "invocation_token": token,
        "caller_technique_id": runtime.technique_id,
        "slot_instance_id": str(slot.get("slot_instance_id", "")),
        "trigger_mode": str(effect.get("_trigger_mode", "invoked")),
        "round_number": int(runtime.round_number),
        "source_kind": "technique",
        "source_id": definition.id,
        "source_name": definition.display_name,
        "source_instance_key": str(slot.get("slot_instance_id", "")),
        "captures": request.get("captures", {}).duplicate(true),
        "sequence_book": runtime.sequence_book,
        "card_identity_policy": runtime.actor.card_identity_policy,
        "passive_rule_runtime": _passive_runtime,
        "consumed_marker_value": int(request.get(
            "consumed_marker_value", runtime.consumed_marker_value)),
    })
    var state := {
        "request": request,
        "runtime": runtime,
        "effect": effect,
        "definition": definition,
        "slot_instance_id": str(slot.get("slot_instance_id", "")),
        "values": values,
        "invoked_context": invoked_context,
        "phase_index": 0,
        "continuation": null,
        "request_id": "",
        "pending_power_fixed_tokens": power_result.get(
            "pending_power_fixed_tokens", []).duplicate(),
        "pre_technique_cost": prepared.get(
            "pre_technique_cost_state", {}).duplicate(true),
    }
    var begun := _begin_execution(_execution_info_from_context(
        invoked_context, {
            "sequence_advance_requested": bool(effect.get(
                "advance_sequence", true)),
            "same_qi_gain_enabled": bool(effect.get("gain_same_qi", true)),
            "momentum_enabled": bool(effect.get("use_momentum", true)),
            "sequence_before": request.get("sequence_before", []).duplicate(true),
        }))
    if not begun.get("success", false):
        rollback_pre_technique_cost(state.get("pre_technique_cost", {}))
        return begun
    _commit_event("action_confirmed", state, {
        "sequence_before": request.get("sequence_before", []),
        "sequence_after": runtime.sequence_book.ordered_slots(
            str(request.get("hand_id", ""))),
    })
    _commit_event("technique_invocation_started", state, {
        "sequence_before": request.get("sequence_before", []),
        "sequence_after": runtime.sequence_book.ordered_slots(
            str(request.get("hand_id", ""))),
    })
    return _continue_invocation(state)

func prepare_invocation(request: Dictionary, context) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    var slot: Dictionary = request.get("slot", {})
    var definition = _repository.get_definition(str(slot.get("technique_id", "")))
    var effect: Dictionary = request.get("effect", {})
    var invocation_hand_result: Dictionary = request.get(
        "hand_result", runtime.hand_result)
    var activation := prepare_activation(
        definition, runtime.actor, runtime.target, invocation_hand_result,
        runtime.played_cards, str(request.get("hand_id", "")),
        str(request.get("invocation_token", "")),
        str(effect.get("_trigger_mode", "invoked")),
        bool(effect.get("check_condition", true)), {},
        bool(slot.get("host_sequence_qualified", false)))
    if not activation.get("success", false):
        return activation
    if not activation.get("triggered", false):
        return {
            "success": true, "triggered": false,
            "detail": activation.get("reason", "调用启动被拒绝"),
            "activation": activation,
        }
    var cost_result := begin_pre_technique_cost(
        runtime.actor, runtime.target, definition,
        invocation_hand_result, runtime.played_cards,
        str(request.get("hand_id", "")),
        str(request.get("invocation_token", "")),
        str(effect.get("_trigger_mode", "invoked")),
        str(slot.get("slot_instance_id", "")),
        int(request.get("p0", 0)))
    if not cost_result.get("success", false):
        return cost_result
    var power_result := resolve_power(
        runtime.actor, runtime.target, invocation_hand_result,
        runtime.played_cards, int(request.get("p0", 0)),
        str(request.get("invocation_token", "")),
        str(effect.get("_trigger_mode", "invoked")),
        bool(effect.get("use_momentum", true)),
        int(runtime.actor.direct_power_fixed) + int(cost_result.get(
            "power_fixed", 0)),
        int(runtime.actor.direct_power_percent) + int(cost_result.get(
            "power_percent", 0)))
    if not power_result.get("success", false):
        rollback_pre_technique_cost(cost_result)
        return power_result
    var formation_context = EffectContextScript.new().configure({
        "ports": _ports,
        "actor": runtime.actor,
        "target": runtime.target,
        "hand_result": invocation_hand_result,
        "played_cards": runtime.played_cards,
        "group_snapshot": runtime.group_snapshot,
        "values": power_result.get("values", {}),
        "action_token": str(request.get("invocation_token", "")),
        "root_action_token": runtime.root_action_token,
        "slot_instance_id": str(slot.get("slot_instance_id", "")),
        "source_kind": "technique",
        "source_id": definition.id,
        "source_name": definition.display_name,
        "source_instance_key": str(slot.get("slot_instance_id", "")),
        "trigger_mode": str(effect.get("_trigger_mode", "invoked")),
        "captures": request.get("captures", {}).duplicate(true),
        "sequence_book": runtime.sequence_book,
        "card_identity_policy": runtime.actor.card_identity_policy,
    })
    var formation_result := resolve_power_formation_fixed_bonus(
        definition, formation_context)
    if not formation_result.get("success", false):
        rollback_pre_technique_cost(cost_result)
        return formation_result
    if formation_result.get("handled", false):
        power_result["values"] = PowerCalculatorScript.apply_direct_power_fixed(
            power_result["values"], int(formation_result.get("fixed_bonus", 0)))
        power_result["frozen_power_formation"] = formation_result.duplicate(true)
    # Invocation costs stay open until the complete invocation (including
    # choices, echoes and sequence advancement) succeeds.  The caller owns
    # the returned transaction and commits/rolls it back at that boundary.
    return {
        "success": true,
        "triggered": true,
        "definition": definition,
        "power_result": power_result,
        "activation": activation,
        "pre_technique_cost_state": cost_result,
        "pre_technique_cost": _public_cost_result(cost_result),
    }

func begin_pre_technique_cost(
        actor,
        target,
        definition,
        hand_result: Dictionary,
        cards: Array,
        hand_id: String,
        action_token: String,
        trigger_mode: String,
        slot_instance_id: String,
        initial_power: int = 0) -> Dictionary:
    if definition == null or trigger_mode == "echo" \
            or _passive_runtime == null:
        return {
            "success": true, "skipped": true,
            "power_fixed": 0, "power_percent": 0,
            "receipts": [], "transaction": {},
        }
    var context_values := {
        "owner": actor,
        "actor": actor,
        "target": target,
        "payload": {
            "action_token": action_token,
            "root_action_token": action_token,
            "trigger_mode": trigger_mode,
            "hand_id": hand_id,
            "technique_id": str(definition.id),
            "technique_pool": str(definition.pool),
            "slot_instance_id": slot_instance_id,
            "initial_power": initial_power,
            "effect_context_values": {
                "ports": _ports,
                "actor": actor,
                "target": target,
                "hand_result": hand_result,
                "played_cards": cards,
                "initial_power": initial_power,
                "technique_id": str(definition.id),
                "technique_name": str(definition.display_name),
                "technique_pool": str(definition.pool),
                "slot_instance_id": slot_instance_id,
                "action_token": action_token,
                "root_action_token": action_token,
                "trigger_mode": trigger_mode,
                "sequence_book": actor.technique_sequence_book,
                "card_identity_policy": actor.card_identity_policy,
            },
        },
    }
    var plan = _passive_runtime.build_execution_plan(
        "pre_technique_cost", context_values)
    if not plan.is_valid():
        return {"success": false, "reason": "；".join(plan.errors)}
    if plan.invocations.is_empty():
        return {
            "success": true, "skipped": true,
            "power_fixed": 0, "power_percent": 0,
            "receipts": [], "transaction": {},
        }
    var transaction: Dictionary = _ports.begin_effect_mutation_transaction()
    var passive_state: Dictionary = \
        _passive_runtime.capture_battle_effect_command_state()
    var result := {
        "success": true,
        "skipped": false,
        "power_fixed": 0,
        "power_percent": 0,
        "receipts": [],
        "transaction": transaction,
        "passive_effect_state": passive_state,
        "committed": false,
    }
    for invocation_index in range(plan.invocations.size()):
        var invocation = plan.invocations[invocation_index]
        var invocation_context = invocation.context.for_invocation(invocation)
        var executed: Dictionary = _passive_runtime.execute_invocation(
            invocation, invocation_context, "read")
        if not executed.get("success", false):
            rollback_pre_technique_cost(result)
            return {"success": false, "reason": str(executed.get(
                "reason", "功法启动成本声明失败")), "rolled_back": true}
        var plans = executed.get("result", {}).get("cost_plans", [])
        if not plans is Array:
            rollback_pre_technique_cost(result)
            return {"success": false, "reason": "功法启动成本必须返回 cost_plans 数组",
                "rolled_back": true}
        for plan_index in range(plans.size()):
            var cost_plan: Dictionary = plans[plan_index]
            var cost := maxi(0, int(cost_plan.get("amount", 0)))
            var insufficient := int(actor.experience) < cost
            if insufficient and str(cost_plan.get(
                    "insufficient_policy", "skip")) == "skip":
                result["receipts"].append({
                    "success": true, "skipped": true,
                    "reason": "历练不足", "requested": cost,
                    "source_instance_key": str(
                        invocation.source.source_instance_key),
                })
                continue
            if insufficient:
                rollback_pre_technique_cost(result)
                return {"success": false, "reason": "功法启动成本不足",
                    "rolled_back": true}
            var operation_token := "%s:pre-technique-cost:%s:%d:%d" % [
                action_token,
                str(invocation.source.source_instance_key).sha256_text().left(12),
                invocation_index,
                plan_index,
            ]
            var payment: Dictionary = _ports.spend_battle_experience(
                actor, cost, {
                    "action_token": action_token,
                    "root_execution_token": action_token,
                    "operation_token": operation_token,
                    "source_kind": str(invocation.source.source_kind),
                    "source_id": str(invocation.source.content_id),
                    "source_name": str(invocation.source.definition.get(
                        "name", "")),
                    "source_instance_key": str(
                        invocation.source.source_instance_key),
                    "trigger_mode": trigger_mode,
                })
            if not payment.get("success", false):
                rollback_pre_technique_cost(result)
                return {"success": false, "reason": str(payment.get(
                    "reason", "功法启动成本支付失败")), "rolled_back": true}
            result["receipts"].append(payment.duplicate(true))
            result["power_fixed"] = int(result["power_fixed"]) + int(
                cost_plan.get("power_fixed", 0))
            result["power_percent"] = int(result["power_percent"]) + int(
                cost_plan.get("power_percent", 0))
    return result

func commit_pre_technique_cost(cost_result: Dictionary) -> Dictionary:
    if cost_result.get("transaction", {}).is_empty():
        return {"success": true, "skipped": true}
    if bool(cost_result.get("committed", false)):
        return {"success": true, "reused": true}
    var committed: Dictionary = _ports.commit_effect_mutation_transaction(
        cost_result["transaction"])
    if committed.get("success", false):
        cost_result["committed"] = true
    return committed

func rollback_pre_technique_cost(cost_result: Dictionary) -> bool:
    if cost_result.get("transaction", {}).is_empty() \
            or bool(cost_result.get("committed", false)):
        return false
    var rolled_back: bool = _ports.rollback_effect_mutation_transaction(
        cost_result["transaction"])
    if _passive_runtime != null:
        _passive_runtime.restore_battle_effect_command_state(
            cost_result.get("passive_effect_state", {}))
    cost_result["rolled_back"] = rolled_back
    return rolled_back

func prepare_activation(
        definition,
        actor,
        target,
        hand_result: Dictionary,
        cards: Array,
        hand_id: String,
        action_token: String,
        source_kind: String,
        check_condition: bool = true,
        frozen_condition: Dictionary = {},
        allow_host_hand: bool = false,
        round_number: int = 0) -> Dictionary:
    if definition == null:
        return {
            "success": true, "triggered": false,
            "checked": false, "allowed": false,
            "reason": "空功法序列", "condition": {
                "ok": false, "reason": "空功法序列"},
            "source_breakdown": [], "errors": [],
        }
    var condition: Dictionary = frozen_condition.duplicate(true)
    if condition.is_empty():
        condition = {"ok": true, "reason": "跳过功法条件"}
        if check_condition:
            condition = _repository.conditions_met(
                definition, hand_result, actor.card_identity_policy,
                allow_host_hand)
    if check_condition and not bool(condition.get("ok", false)):
        return {
            "success": true, "triggered": false,
            "checked": false, "allowed": false,
            "reason": str(condition.get("reason", "功法条件不满足")),
            "condition": condition,
            "source_breakdown": [], "errors": [],
        }
    var permission := activation_permission(
        actor, target, definition.id, hand_id, cards,
        action_token, source_kind, round_number)
    permission["triggered"] = bool(permission.get("allowed", false))
    permission["condition"] = condition
    return permission

func resolve_power(actor, target, hand_result: Dictionary, cards: Array,
        p0: int, action_token: String, source_kind: String,
        use_momentum: bool = true,
        direct_power_fixed_input = null,
        direct_power_percent_input = null,
        post_query_percent_bonus: int = 0,
        include_pending_sources: bool = true,
        round_number: int = 0,
        card_facts_override: Array = []) -> Dictionary:
    var fixed := int(actor.direct_power_fixed) \
        if direct_power_fixed_input == null \
        else int(direct_power_fixed_input)
    var percent := int(actor.direct_power_percent) \
        if direct_power_percent_input == null \
        else int(direct_power_percent_input)
    var pending_tokens: Array[String] = []
    if include_pending_sources:
        for source_value in actor.pending_power_fixed_sources:
            var source: Dictionary = source_value
            fixed += int(source.get("amount", 0))
            pending_tokens.append(str(source.get("source_token", "")))
    var query_service = actor.battle_rule_query_service
    var query_card_facts: Array = card_facts_override.duplicate(true)
    if query_card_facts.is_empty() and not cards.is_empty():
        var card_facts_result := _card_facts(
            cards, actor, target, hand_result, action_token, source_kind,
            round_number)
        if not card_facts_result.get("success", false):
            return card_facts_result
        query_card_facts = card_facts_result.get("facts", [])
    var queries: Dictionary = {}
    for stage in [
            ["power_fixed_query", "power_fixed"],
            ["power_amp_percent_query", "power_amp_percent"]]:
        var field := str(stage[1])
        var base_value := fixed if field == "power_fixed" else percent
        if query_service == null:
            queries[field] = {
                "base_value": base_value,
                "effective_value": base_value,
                "source_breakdown": [], "fingerprint": "",
            }
            continue
        var query = query_service.resolve_values({
            "hook": str(stage[0]), "owner": actor,
            "actor": actor, "target": target,
            "subject_kind": "power_stage", "subject_id": field,
            "base_value": base_value, "action_token": action_token,
            "round_number": round_number,
            "hand_id": str(hand_result.get("id", "")),
            "source_kind": source_kind,
            "card_facts": query_card_facts,
            "metadata": {"stage": field},
        })
        if not query.success:
            return {
                "success": false,
                "reason": "%s：%s" % [str(stage[0]), "；".join(query.errors)],
            }
        base_value = int(query.effective_value)
        queries[field] = {
            "base_value": int(query.base_value),
            "effective_value": base_value,
            "source_breakdown": query.modifier_breakdown.duplicate(true),
            "fingerprint": str(query.source_fingerprint),
        }
        if field == "power_fixed":
            fixed = base_value
        else:
            percent = base_value
    var momentum := int(actor.momentum_value) if use_momentum else 0
    var values: Dictionary = PowerCalculatorScript.calculate_from_initial_power(
        p0, fixed, percent + post_query_percent_bonus, momentum)
    values["passive_power_queries"] = queries
    values["group_snapshot"] = {}
    return {
        "success": true, "values": values,
        "queries": queries,
        "pending_power_fixed_tokens": pending_tokens,
    }

func resolve_power_formation_fixed_bonus(
        definition, context) -> Dictionary:
    var formation: Dictionary = {}
    if definition is Dictionary:
        formation = definition.get("power_formation", {})
    elif definition != null:
        formation = definition.power_formation
    var kind := str(formation.get("kind", ""))
    if kind != "value_spec_fixed_bonus":
        return {
            "success": true,
            "handled": false,
            "kind": kind,
            "fixed_bonus": 0,
        }
    if _executor == null or _executor.registry == null \
            or _executor.registry.value_resolver == null:
        return {"success": false, "reason": "确认期功法值缺少 ValueSpec 解析器"}
    var runtime = EffectContextScript.coerce(context)
    var fixed_bonus := int(_executor.registry.value_resolver.resolve(
        formation.get("value", 0), runtime))
    return {
        "success": true,
        "handled": true,
        "kind": kind,
        "fixed_bonus": fixed_bonus,
        "frozen_value": fixed_bonus,
    }

func settle_same_qi(
        actor,
        amount: int,
        source: String,
        token: String,
        enabled: bool = true,
        source_metadata: Dictionary = {}) -> Dictionary:
    if not enabled:
        return {"success": true, "skipped": true, "amount": 0}
    var source_category := str(source_metadata.get(
        "source_kind", "same_qi" if source == "同气槽" else "rule"))
    var action_token := str(source_metadata.get(
        "action_token", token.trim_suffix(":same_qi")))
    return _ports.write_same_qi(
        actor, "add", amount, source, token, source_category, action_token,
        source_metadata)

func activation_permission(actor, target, technique_id: String,
        hand_id: String, cards: Array, action_token: String,
        source_kind: String, round_number: int = 0) -> Dictionary:
    var permission = actor.battle_permission_service
    if permission == null:
        return {
            "success": true, "checked": true, "allowed": true,
            "reason": "", "source_breakdown": [], "errors": [],
        }
    var result: Dictionary = permission.can_activate_technique(
        actor, technique_id, hand_id, {
            "target": target, "action_token": action_token,
            "round_number": round_number,
            "card_instance_ids": cards.map(func(card): return str(card.id)),
            "source_kind": source_kind,
        })
    result["checked"] = true
    result["success"] = result.get("errors", []).is_empty()
    return result

func effects_for_phase(effects: Array, phase: String) -> Dictionary:
    return TechniquePhaseCatalogScript.effects_for_phase(
        effects, phase, _executor.registry)

func prepare_manual_record(record) -> void:
    if bool(record["momentum_prepared"]):
        return
    record["momentum_prepared"] = true
    var actor = record["actor"]
    record["momentum_snapshot"] = maxi(0, int(actor.momentum_value))
    record["preview"]["momentum_snapshot"] = int(record["momentum_snapshot"])
    record["preview"]["values"] = PowerCalculatorScript.apply_momentum(
        record["preview"]["values"], int(record["momentum_snapshot"]))

func settle_manual_record(record) -> Dictionary:
    var actor = record["actor"]
    var action_token := str(record["token"])
    var settlement: Dictionary = _settle_momentum(
        actor, action_token,
        str(record["preview"].get("technique_id", "")), true)
    record["momentum_change_receipts"] = actor.momentum_receipts_for_action(
        action_token)
    record["momentum_settlement"] = {
        "snapshot": int(record["momentum_snapshot"]),
        "changed_by_technique_or_echo": bool(settlement.get("changed", false)),
        "preserved": bool(settlement.get(
            "preservation", {}).get("preserved", false)),
        "preservation_consumed": bool(settlement.get(
            "preservation", {}).get("consumed", false)),
        "preservation_record": settlement.get(
            "preservation", {}).get("record", {}).duplicate(true),
        "clear_receipt": settlement.get(
            "clear_receipt", {}).duplicate(true),
        "remaining": int(actor.momentum_value),
    }
    record["preview"]["same_qi_write_results"] = \
        _ports.same_qi_receipts_for_action(actor, action_token)
    record["preview"]["momentum_change_receipts"] = \
        record["momentum_change_receipts"].duplicate(true)
    record["preview"]["momentum_settlement"] = \
        record["momentum_settlement"].duplicate(true)
    return settlement

func _continue_invocation(state: Dictionary) -> Dictionary:
    var runtime = state["runtime"]
    var invoked_context = state["invoked_context"]
    var phases := TechniquePhaseCatalogScript.phase_ids()
    while int(state["phase_index"]) < phases.size():
        var result: Dictionary
        if state.get("continuation") != null:
            var request_id := str(state.get("request_id", ""))
            if not runtime.choice_responses.has(request_id):
                return _pending_result(state)
            var selected: Array = runtime.choice_responses[request_id].duplicate()
            runtime.choice_responses.erase(request_id)
            runtime.choice_candidates.erase(request_id)
            result = _executor.resume(
                state["continuation"], request_id, selected)
            state["continuation"] = null
            state["request_id"] = ""
        else:
            var phase_result := effects_for_phase(
                state["definition"].effects,
                str(phases[int(state["phase_index"])]))
            if not phase_result.get("success", false):
                runtime.captures.erase(PENDING_CAPTURE)
                _abort_invocation(state)
                return {
                    "success": false,
                    "reason": phase_result.get("reason", "功法阶段解析失败"),
                }
            var effects: Array = phase_result.get("effects", [])
            if effects.is_empty():
                state["phase_index"] = int(state["phase_index"]) + 1
                continue
            result = _executor.execute_all(effects, invoked_context)
        if result.get("pending_choice", false):
            state["continuation"] = result.get("_continuation")
            var request_object = state["continuation"].choice_request \
                if state["continuation"] != null else null
            if request_object == null:
                _abort_invocation(state)
                return {"success": false, "reason": "功法结算等待选择缺少 continuation"}
            state["request_id"] = str(request_object.request_id)
            runtime.captures[PENDING_CAPTURE] = state
            return _pending_result(state)
        if not result.get("success", false):
            runtime.captures.erase(PENDING_CAPTURE)
            _abort_invocation(state)
            return {
                "success": false,
                "reason": result.get("detail", "功法阶段结算失败"),
            }
        state["phase_index"] = int(state["phase_index"]) + 1
    runtime.captures.erase(PENDING_CAPTURE)
    return _finish_invocation(state)

func _resume_invocation(runtime) -> Dictionary:
    var state: Dictionary = runtime.captures.get(PENDING_CAPTURE, {})
    if state.is_empty():
        return {"success": false, "reason": "功法结算 continuation 已失效"}
    return _continue_invocation(state)

func _pending_result(state: Dictionary) -> Dictionary:
    var continuation = state.get("continuation")
    var request_object = continuation.choice_request \
        if continuation != null else null
    return {
        "success": false, "pending_choice": true,
        "detail": "等待调用功法目标选择",
        "choice_request": request_object.snapshot() \
            if request_object != null else {},
        "_choice_request_object": request_object,
        "invocation_token": str(state["request"].get(
            "invocation_token", "")),
    }

func _finish_invocation(state: Dictionary) -> Dictionary:
    var request: Dictionary = state["request"]
    var runtime = state["runtime"]
    var effect: Dictionary = state["effect"]
    var token := str(request.get("invocation_token", ""))
    if bool(effect.get("use_momentum", true)):
        var momentum_settlement: Dictionary = _settle_momentum(
            runtime.actor, token, state["definition"].id, true)
        if not momentum_settlement.get("success", false):
            _abort_invocation(state)
            return momentum_settlement
    runtime.actor.consume_pending_power_fixed_sources(
        state.get("pending_power_fixed_tokens", []))
    var same_qi_result := settle_same_qi(
        runtime.actor,
        int(runtime.group_snapshot.get("action_same_qi_gain", 0)),
        "technique_invocation",
        token + ":same_qi",
        bool(effect.get("gain_same_qi", true)),
        state["invoked_context"].source_metadata())
    if not same_qi_result.get("success", false):
        _abort_invocation(state)
        return same_qi_result
    var summarized := finish_execution(state["invoked_context"])
    if not summarized.get("success", false):
        _abort_invocation(state)
        return summarized
    var completed := {"success": true}
    if bool(effect.get("advance_sequence", true)):
        completed = runtime.ports.complete_and_advance_technique(
            runtime.actor,
            str(request.get("hand_id", "")),
            str(state.get("slot_instance_id", "")),
            int(summarized.get("extra_sequence_advance_count", 0)),
            summarized.get("extra_sequence_advance_sources", []),
            token,
            str(request.get("root_action_token", token)),
            str(state["invoked_context"].technique_execution_token))
    if not completed.get("success", false):
        _abort_invocation(state)
        return completed
    var result := {
        "success": true, "triggered": true,
        "invocation_token": token,
        "slot_instance_id": str(state.get("slot_instance_id", "")),
        "technique_id": state["definition"].id,
        "power_values": state["values"],
        "sequence_before": request.get("sequence_before", []),
        "sequence_after": runtime.sequence_book.ordered_slots(
            str(request.get("hand_id", ""))),
        "detail": "调用%s" % state["definition"].display_name,
    }
    _commit_event("technique_succeeded", state, result)
    _commit_event("technique_invocation_resolved", state, result)
    _commit_event("action_resolved", state, result)
    var cost_commit := _commit_invocation_cost(state)
    if not cost_commit.get("success", false):
        _rollback_invocation_cost(state)
        return {
            "success": false,
            "reason": str(cost_commit.get("reason", "功法启动成本提交失败")),
        }
    return result

func _commit_invocation_cost(state: Dictionary) -> Dictionary:
    var cost_result: Dictionary = state.get("pre_technique_cost", {})
    if cost_result.is_empty():
        return {"success": true, "skipped": true}
    return commit_pre_technique_cost(cost_result)

func _rollback_invocation_cost(state: Dictionary) -> bool:
    var cost_result: Dictionary = state.get("pre_technique_cost", {})
    if cost_result.is_empty():
        return false
    return rollback_pre_technique_cost(cost_result)

func _abort_invocation(state: Dictionary) -> bool:
    var context = state.get("invoked_context")
    var token := str(context.technique_execution_token) \
        if context != null else str(state.get("request", {}).get(
            "invocation_token", ""))
    discard_execution(token)
    _completed_summaries.erase(token)
    return _rollback_invocation_cost(state)

func _settle_momentum(actor, action_token: String,
        technique_id: String, use_momentum: bool) -> Dictionary:
    if not use_momentum:
        return {"success": true}
    var changed: bool = actor.momentum_changed_for_action(action_token)
    var preservation := {"preserved": false, "consumed": false}
    var clear_receipt: Dictionary = {}
    if not changed:
        preservation = actor.consume_momentum_preservation_for(action_token)
        if not bool(preservation.get("preserved", false)):
            var definition = _repository.get_definition(technique_id)
            clear_receipt = _ports.write_momentum(
                actor, "clear", 0, "rule_clear", action_token, technique_id, {
                    "source_kind": "technique",
                    "source_id": technique_id,
                    "source_name": str(definition.display_name) \
                        if definition != null else technique_id,
                    "source_instance_key": "technique:%s" % technique_id,
                    "trigger_mode": "direct",
                    "root_action_token": action_token,
                    "operation_token": "%s:momentum-settlement:%s" % [
                        action_token, technique_id],
                })
            if not clear_receipt.get("success", false):
                return {
                    "success": false,
                    "reason": "功法结算清空连势失败",
                    "changed": changed,
                    "preservation": preservation,
                    "clear_receipt": clear_receipt,
                    "remaining": int(actor.momentum_value),
                }
    return {
        "success": true,
        "changed": changed, "preservation": preservation,
        "clear_receipt": clear_receipt,
        "remaining": int(actor.momentum_value),
    }

func _commit_event(kind: String, state: Dictionary,
        extra: Dictionary) -> void:
    if _event_service == null:
        return
    var request: Dictionary = state["request"]
    var runtime = state["runtime"]
    var token := str(request.get("invocation_token", ""))
    var serial := int(_event_service.next_serial())
    _event_service.commit(kind, {
        "event_token": _event_service.make_token(
            kind, runtime.actor, serial, token),
        "event_serial": serial,
        "actor": runtime.actor, "target": runtime.target,
        "owner": runtime.actor, "action_token": token,
        "source_kind": "technique",
        "source_id": str(state["definition"].id),
        "source_name": str(state["definition"].display_name),
        "source_instance_key": str(state.get("slot_instance_id", "")),
        "hand_id": str(request.get("hand_id", "")),
        "technique_id": str(state["definition"].id),
        "technique_pool": str(state["definition"].pool),
        "initial_power": int(state.get("values", {}).get(
            "initial_power", 0)),
        "technique_power": int(state.get("values", {}).get(
            "technique_value", 0)),
        "trigger_mode": str(state["effect"].get(
            "_trigger_mode", "invoked")),
        "technique_triggered": true,
        "action_succeeded": true,
        "metadata": {
            "hand_id": str(request.get("hand_id", "")),
            "technique_power": int(state.get("values", {}).get(
                "technique_value", 0)),
            "trigger_mode": str(state["effect"].get(
                "_trigger_mode", "invoked")),
            "root_action_token": str(request.get(
                "root_action_token", token)),
            "invocation_token": token,
            "caller_technique_id": runtime.technique_id,
            "slot_instance_id": str(state.get("slot_instance_id", "")),
            "manual_effect_suppressed": false,
            "sequence_before": extra.get(
                "sequence_before", request.get("sequence_before", [])),
            "sequence_after": extra.get("sequence_after", []),
        },
    })

func _begin_execution(info: Dictionary) -> Dictionary:
    var token := str(info.get("technique_execution_token", ""))
    if token == "":
        return {"success": false, "reason": "功法执行缺少稳定 execution token"}
    if str(info.get("source_kind", "")) != "technique":
        return {"success": false, "reason": "功法执行汇总只接受 technique 来源"}
    if _completed_summaries.has(token):
        return {"success": true, "reused": true, "token": token}
    if _active_executions.has(token):
        return {"success": true, "reused": true, "token": token}
    var accumulator := info.duplicate(false)
    accumulator.merge({
        "actor_defense_gained": 0,
        "actor_defense_lost": 0,
        "target_defense_lost": 0,
        "actor_life_lost": 0,
        "target_life_lost": 0,
        "life_recovered": 0,
        "requested_damage_total": 0,
        "final_damage_total": 0,
        "damage_segment_count": 0,
        "normal_segment_count": 0,
        "true_segment_count": 0,
        "poison_segment_count": 0,
        "blocked_segment_count": 0,
        "block_canceled_segment_count": 0,
        "deflection_canceled_segment_count": 0,
        "total_canceled_segment_count": 0,
        "life_loss_canceled_segment_count": 0,
        "damage_segment_tokens": [],
        "observed_event_tokens": [],
    }, true)
    _active_executions[token] = accumulator
    return {"success": true, "reused": false, "token": token}

func _execution_info_from_context(
        runtime,
        options: Dictionary = {}) -> Dictionary:
    return {
        "technique_execution_token": str(runtime.technique_execution_token),
        "root_action_token": str(runtime.root_action_token),
        "invocation_token": str(runtime.invocation_token),
        "caller_technique_id": str(runtime.caller_technique_id),
        "actor": runtime.actor,
        "target": runtime.target,
        "source_kind": str(runtime.source_kind),
        "source_id": str(runtime.source_id),
        "source_name": str(runtime.source_name),
        "source_instance_key": str(runtime.source_instance_key),
        "technique_id": str(runtime.technique_id),
        "technique_pool": str(runtime.technique_pool),
        "slot_instance_id": str(runtime.slot_instance_id),
        "hand_id": str(runtime.hand_result.get("id", runtime.actual_hand_id)),
        "initial_power": int(runtime.initial_power),
        "technique_power": int(runtime.power),
        "trigger_mode": str(runtime.trigger_mode),
        "is_echo": bool(options.get("is_echo", runtime.trigger_mode == "echo")),
        "manual_effect_suppressed": bool(options.get(
            "manual_effect_suppressed", false)),
        "sequence_advance_requested": bool(options.get(
            "sequence_advance_requested", false)),
        "same_qi_gain_enabled": bool(options.get(
            "same_qi_gain_enabled", false)),
        "momentum_enabled": bool(options.get("momentum_enabled", false)),
        "sequence_before": options.get("sequence_before", []).duplicate(true),
        "round_number": int(options.get("round_number", 0)),
        "technique_execution_state": runtime.technique_execution_state,
        "group_snapshot": runtime.group_snapshot,
        "played_cards": runtime.played_cards.duplicate(),
        "temporary": _slot_is_temporary(
            runtime.sequence_book, runtime.slot_instance_id),
    }

func _commit_execution_summary(token: String) -> Dictionary:
    if not _active_executions.has(token):
        return {"success": false, "reason": "功法执行累计器不存在"}
    var accumulator: Dictionary = _active_executions[token]
    var summary := accumulator.duplicate(false)
    var actor = summary.get("actor")
    summary["damage_segment_tokens"] = accumulator.get(
        "damage_segment_tokens", []).duplicate()
    summary["sequence_before"] = accumulator.get(
        "sequence_before", []).duplicate(true)
    summary["target_total_reduction"] = int(summary.get(
        "target_defense_lost", 0)) + int(summary.get("target_life_lost", 0))
    if _event_service == null:
        return {"success": true, "summary": summary, "receipt": {}}
    var serial := int(_event_service.next_serial())
    var event_token: String = str(_event_service.make_token(
        "technique_execution_resolved", summary.get("actor"), token, token))
    var values := {
        "event_token": event_token,
        "event_serial": serial,
        "technique_execution_token": token,
        "root_action_token": str(summary.get("root_action_token", token)),
        "invocation_token": str(summary.get("invocation_token", "")),
        "caller_technique_id": str(summary.get("caller_technique_id", "")),
        "actor": summary.get("actor"),
        "target": summary.get("target"),
        "owner": summary.get("actor"),
        "action_token": token,
        "round_number": int(summary.get("round_number", 0)),
        "source_kind": "technique",
        "source_id": str(summary.get("source_id", "")),
        "source_name": str(summary.get("source_name", "")),
        "source_instance_key": str(summary.get("source_instance_key", "")),
        "technique_id": str(summary.get("technique_id", "")),
        "technique_pool": str(summary.get("technique_pool", "")),
        "slot_instance_id": str(summary.get("slot_instance_id", "")),
        "hand_id": str(summary.get("hand_id", "")),
        "initial_power": int(summary.get("initial_power", 0)),
        "technique_power": int(summary.get("technique_power", 0)),
        "trigger_mode": str(summary.get("trigger_mode", "")),
        "is_echo": bool(summary.get("is_echo", false)),
        "manual_effect_suppressed": bool(summary.get(
            "manual_effect_suppressed", false)),
        "sequence_advance_requested": bool(summary.get(
            "sequence_advance_requested", false)),
        "same_qi_gain_enabled": bool(summary.get(
            "same_qi_gain_enabled", false)),
        "momentum_enabled": bool(summary.get("momentum_enabled", false)),
        "actor_defense_gained": int(summary.get("actor_defense_gained", 0)),
        "actor_defense_lost": int(summary.get("actor_defense_lost", 0)),
        "target_defense_lost": int(summary.get("target_defense_lost", 0)),
        "actor_life_lost": int(summary.get("actor_life_lost", 0)),
        "target_life_lost": int(summary.get("target_life_lost", 0)),
        "target_total_reduction": int(summary.get("target_total_reduction", 0)),
        "life_recovered": int(summary.get("life_recovered", 0)),
        "requested_damage_total": int(summary.get("requested_damage_total", 0)),
        "final_damage_total": int(summary.get("final_damage_total", 0)),
        "damage_segment_count": int(summary.get("damage_segment_count", 0)),
        "normal_segment_count": int(summary.get("normal_segment_count", 0)),
        "true_segment_count": int(summary.get("true_segment_count", 0)),
        "poison_segment_count": int(summary.get("poison_segment_count", 0)),
        "blocked_segment_count": int(summary.get("blocked_segment_count", 0)),
        "block_canceled_segment_count": int(summary.get(
            "block_canceled_segment_count", 0)),
        "deflection_canceled_segment_count": int(summary.get(
            "deflection_canceled_segment_count", 0)),
        "total_canceled_segment_count": int(summary.get(
            "total_canceled_segment_count", 0)),
        "life_loss_canceled_segment_count": int(summary.get(
            "life_loss_canceled_segment_count", 0)),
        "damage_segment_tokens": summary.get(
            "damage_segment_tokens", []).duplicate(),
        "sequence_before": summary.get("sequence_before", []).duplicate(true),
        "temporary": bool(summary.get("temporary", false)),
        "group_snapshot": summary.get("group_snapshot", {}).duplicate(true),
        "played_cards": summary.get("played_cards", []).duplicate(),
        "extra_sequence_advance_count": int(summary.get(
            "extra_sequence_advance_count", 0)),
        "extra_sequence_advance_sources": summary.get(
            "extra_sequence_advance_sources", []).duplicate(true),
        "technique_triggered": true,
        "action_succeeded": true,
        "metadata": {
            "technique_execution_token": token,
            "root_action_token": str(summary.get("root_action_token", token)),
            "invocation_token": str(summary.get("invocation_token", "")),
            "caller_technique_id": str(summary.get("caller_technique_id", "")),
            "slot_instance_id": str(summary.get("slot_instance_id", "")),
            "manual_effect_suppressed": bool(summary.get(
                "manual_effect_suppressed", false)),
            "sequence_before": summary.get("sequence_before", []).duplicate(true),
            "effect_context_values": {
                "actor": summary.get("actor"),
                "target": summary.get("target"),
                "owner": summary.get("actor"),
                "hand_result": {"id": str(summary.get("hand_id", "")),
                    "contributing": summary.get("played_cards", []).duplicate()},
                "played_cards": summary.get("played_cards", []).duplicate(),
                "group_snapshot": summary.get("group_snapshot", {}).duplicate(true),
                "values": {"initial_power": int(summary.get("initial_power", 0)),
                    "technique_value": int(summary.get("technique_power", 0))},
                "power": int(summary.get("technique_power", 0)),
                "initial_power": int(summary.get("initial_power", 0)),
                "technique_id": str(summary.get("technique_id", "")),
                "technique_name": str(summary.get("source_name", "")),
                "technique_pool": str(summary.get("technique_pool", "")),
                "action_token": token,
                "technique_execution_token": token,
                "technique_execution_state": summary.get(
                    "technique_execution_state", {}),
                "root_action_token": str(summary.get("root_action_token", token)),
                "slot_instance_id": str(summary.get("slot_instance_id", "")),
                "trigger_mode": str(summary.get("trigger_mode", "")),
                "source_kind": "technique",
                "source_id": str(summary.get("source_id", "")),
                "source_instance_key": str(summary.get("source_instance_key", "")),
                "sequence_book": actor.technique_sequence_book \
                    if actor != null else null,
            },
        },
    }
    var committed: Dictionary = _event_service.commit(
        "technique_execution_resolved", values)
    if not committed.get("success", false):
        return {
            "success": false,
            "reason": str(committed.get(
                "reason", "功法执行汇总事件处理失败")),
            "summary": values,
        }
    return {
        "success": true,
        "summary": values,
        "receipt": committed.get("receipt", {}).duplicate(true),
        "reused": bool(committed.get("reused", false)),
    }

func _resolve_echo_plans(parent) -> Dictionary:
    var state: Dictionary = parent.technique_execution_state
    var plans: Array = state.get("pending_echo_plans", []).duplicate(true)
    state["pending_echo_plans"] = []
    var results: Array = []
    for plan_value in plans:
        var plan: Dictionary = plan_value
        var echo_index := int(plan.get("echo_index", results.size()))
        var token := "%s:echo:%06d" % [
            parent.technique_execution_token, echo_index]
        var child_state := {
            "pending_echo_plans": [],
            "next_echo_index": 0,
            "extra_sequence_advance_requests": [],
            "echo_effects": [],
        }
        var child = EffectContextScript.new().configure({
            "ports": parent.ports,
            "actor": parent.actor,
            "target": parent.target,
            "hand_result": parent.hand_result,
            "played_cards": parent.played_cards,
            "group_snapshot": parent.group_snapshot,
            "power": parent.power,
            "initial_power": parent.initial_power,
            "direct_power_fixed": parent.direct_power_fixed,
            "direct_power_percent": parent.direct_power_percent,
            "pre_momentum_power": parent.pre_momentum_power,
            "momentum_used": parent.momentum_used,
            "technique_id": parent.technique_id,
            "technique_name": parent.technique_name,
            "actual_hand_id": parent.actual_hand_id,
            "branch_hand_id": parent.branch_hand_id,
            "technique_pool": parent.technique_pool,
            "action_token": token,
            "technique_execution_token": token,
            "technique_execution_state": child_state,
            "root_action_token": parent.root_action_token,
            "invocation_token": parent.invocation_token,
            "caller_technique_id": parent.caller_technique_id,
            "slot_instance_id": parent.slot_instance_id,
            "source_kind": "technique",
            "source_id": parent.source_id,
            "source_name": parent.source_name,
            "source_instance_key": parent.source_instance_key,
            "trigger_mode": "echo",
            "captures": {},
            "sequence_book": parent.sequence_book,
            "card_identity_policy": parent.card_identity_policy,
        })
        var begun := _begin_execution(_execution_info_from_context(child, {
            "is_echo": true,
            "sequence_advance_requested": false,
            "same_qi_gain_enabled": false,
            "momentum_enabled": false,
            "sequence_before": _completed_summaries.get(
                parent.technique_execution_token, {}).get(
                    "sequence_before", []).duplicate(true),
        }))
        if not begun.get("success", false):
            return {"success": false, "reason": begun.get("reason", "回响启动失败"), "results": results}
        var executed: Dictionary = _executor.execute_all(
            plan.get("effects", []), child)
        if executed.get("pending_choice", false) \
                or not executed.get("success", false):
            discard_execution(token)
            return {
                "success": false,
                "reason": str(executed.get(
                    "detail", "回响不支持等待选择" if executed.get(
                        "pending_choice", false) else "回响效果失败")),
                "results": results,
            }
        var completed := finish_execution(child)
        results.append(completed)
        if not completed.get("success", false):
            return {
                "success": false,
                "reason": completed.get("reason", "回响汇总失败"),
                "results": results,
            }
    return {"success": true, "results": results}

func _consume_pending_slot_echoes(runtime) -> Dictionary:
    if runtime.trigger_mode == "echo" or runtime.slot_instance_id == "":
        return {"success": true, "consumed": []}
    if runtime.ports == null or not runtime.ports.has_method(
            "consume_matching_source_marker_records"):
        return {"success": true, "consumed": []}
    var total := 0
    var consumed_all: Array = []
    for entry in runtime.actor.source_marker_store.entries({
            "marker_id": "pending_slot_echoes", "scope": "battle"}):
        var source := {
            "source_kind": str(entry.get("source_kind", "")),
            "source_instance_key": str(entry.get("source_instance_key", "")),
            "content_id": str(entry.get("content_id", "")),
            "marker_id": "pending_slot_echoes", "scope": "battle",
            "public": bool(entry.get("public", true)),
            "display_name": str(entry.get("display_name", "待用功法回响")),
            "forget_policy": str(entry.get("forget_policy", "clear")),
            "marker_role": str(entry.get(
                "marker_role", "pending_technique_echo")),
            "remove_zero": true,
        }
        var consumed: Dictionary = runtime.ports.consume_matching_source_marker_records(
            runtime.actor, source,
            {"target_slot_instance_id": [str(runtime.slot_instance_id), "*"]},
            -1, runtime.action_token)
        if not consumed.get("success", false):
            return consumed
        for record in consumed.get("consumed_records", []):
            total += int(record.get("granted_count", 0))
            consumed_all.append(record.duplicate(true))
    if total > 0:
        var appended := append_current_technique_echo(runtime, total)
        if not appended.get("success", false):
            return appended
    return {"success": true, "consumed": consumed_all, "added": total}

func _ensure_execution_state(runtime, effects: Array) -> void:
    if runtime.technique_execution_state.is_empty():
        runtime.technique_execution_state = {
            "pending_echo_plans": [], "next_echo_index": 0,
            "extra_sequence_advance_requests": [],
            "echo_effects": effects.duplicate(true),
        }
    elif not runtime.technique_execution_state.has("echo_effects"):
        runtime.technique_execution_state["echo_effects"] = effects.duplicate(true)

func _execution_is_echo(token: String) -> bool:
    return token.contains(":echo:")

func _dispatch_post_success_pre_advance(
        runtime,
        summary: Dictionary,
        echo_results: Array) -> Dictionary:
    if _passive_runtime == null or runtime.trigger_mode == "echo" \
            or _execution_is_echo(str(runtime.technique_execution_token)):
        return {"success": true, "skipped": true, "results": []}
    var sequence_before: Array = summary.get(
        "sequence_before", []).duplicate(true)
    var payload := summary.duplicate(false)
    payload.merge({
        "action_token": str(runtime.technique_execution_token),
        "root_action_token": str(runtime.root_action_token),
        "hand_id": str(runtime.actual_hand_id),
        "technique_id": str(runtime.technique_id),
        "technique_pool": str(runtime.technique_pool),
        "slot_instance_id": str(runtime.slot_instance_id),
        "trigger_mode": str(runtime.trigger_mode),
        "initial_power": int(runtime.initial_power),
        "technique_power": int(runtime.power),
        "sequence_before": sequence_before,
        "sequence_after": runtime.sequence_book.ordered_slots(
            str(runtime.actual_hand_id)) if runtime.sequence_book != null else [],
        "echo_results": echo_results.duplicate(true),
        "echo_count": echo_results.size(),
        "effect_context_values": {
            "ports": _ports,
            "actor": runtime.actor,
            "target": runtime.target,
            "hand_result": runtime.hand_result,
            "played_cards": runtime.played_cards,
            "group_snapshot": runtime.group_snapshot,
            "values": {
                "technique_value": int(runtime.power),
                "initial_power": int(runtime.initial_power),
                "direct_power_fixed": int(runtime.direct_power_fixed),
                "direct_power_percent": int(runtime.direct_power_percent),
                "pre_momentum_power": int(runtime.pre_momentum_power),
                "momentum_used": int(runtime.momentum_used),
            },
            "power": int(runtime.power),
            "initial_power": int(runtime.initial_power),
            "technique_id": str(runtime.technique_id),
            "technique_name": str(runtime.technique_name),
            "technique_pool": str(runtime.technique_pool),
            "slot_instance_id": str(runtime.slot_instance_id),
            "action_token": str(runtime.technique_execution_token),
            "technique_execution_token": str(
                runtime.technique_execution_token),
            "root_action_token": str(runtime.root_action_token),
            "invocation_token": str(runtime.invocation_token),
            "caller_technique_id": str(runtime.caller_technique_id),
            "trigger_mode": str(runtime.trigger_mode),
            "sequence_book": runtime.sequence_book,
            "card_identity_policy": runtime.card_identity_policy,
        },
    }, true)
    var dispatched: Dictionary = _passive_runtime.dispatch_event(
        "technique_post_success_pre_advance", {
            "owner": runtime.actor,
            "actor": runtime.actor,
            "target": runtime.target,
            "round_number": int(summary.get("round_number", 0)),
            "payload": payload,
        }, "write")
    if not dispatched.get("success", false):
        return {"success": false, "reason": "；".join(
            dispatched.get("errors", [])), "results": dispatched.get(
                "results", [])}
    return {"success": true, "skipped": false,
        "results": dispatched.get("results", [])}

func _public_cost_result(cost_result: Dictionary) -> Dictionary:
    return {
        "skipped": bool(cost_result.get("skipped", false)),
        "power_fixed": int(cost_result.get("power_fixed", 0)),
        "power_percent": int(cost_result.get("power_percent", 0)),
        "receipts": cost_result.get("receipts", []).duplicate(true),
    }

func _extra_advance_count(state: Dictionary) -> int:
    var total := 0
    for request in state.get("extra_sequence_advance_requests", []):
        total += maxi(0, int(request.get("count", 0)))
    return total

func _echo_context_snapshot(runtime) -> Dictionary:
    return {
        "hand_id": str(runtime.actual_hand_id),
        "slot_instance_id": str(runtime.slot_instance_id),
        "group_snapshot": runtime.group_snapshot.duplicate(true),
        "played_cards": runtime.played_cards.duplicate(),
        "power": int(runtime.power),
        "initial_power": int(runtime.initial_power),
        "technique_id": str(runtime.technique_id),
    }

func _slot_is_temporary(book, slot_instance_id: String) -> bool:
    if book == null or slot_instance_id == "":
        return false
    for slot in book.find_slots({}):
        if str(slot.get("slot_instance_id", "")) == slot_instance_id:
            return bool(slot.get("temporary", false))
    return false

func _marker_definition(definitions: Array, marker_id: String) -> Dictionary:
    for value in definitions:
        if value is Dictionary and str(value.get("id", "")) == marker_id:
            return value.duplicate(true)
    return {}

func _restore_finish_local_state(runtime, snapshot: Dictionary) -> void:
    _active_executions = snapshot.get(
        "active_executions", {}).duplicate(true)
    _completed_summaries = snapshot.get(
        "completed_summaries", {}).duplicate(true)
    runtime.technique_execution_state.clear()
    runtime.technique_execution_state.merge(
        snapshot.get("execution_state", {}).duplicate(true), true)
    var token := str(runtime.technique_execution_token)
    if _active_executions.has(token):
        _active_executions[token]["technique_execution_state"] = \
            runtime.technique_execution_state
    if _passive_runtime != null:
        _passive_runtime.restore_battle_effect_command_state(
            snapshot.get("passive_effect_state", {}))

func _on_committed_fact_for_execution(
        event_kind: String,
        values: Dictionary,
        _receipt: Dictionary) -> void:
    if event_kind == "technique_execution_resolved":
        return
    var token := str(values.get("action_token", ""))
    if token == "" or not _active_executions.has(token):
        return
    var accumulator: Dictionary = _active_executions[token]
    if str(values.get("source_kind", "")) != "technique" \
            or str(values.get("source_id", "")) != str(accumulator.get(
                "source_id", "")) \
            or str(values.get("source_instance_key", "")) != str(
                accumulator.get("source_instance_key", "")):
        return
    var event_token := str(values.get("event_token", ""))
    var observed_tokens: Array = accumulator.get(
        "observed_event_tokens", [])
    if event_token != "" and observed_tokens.has(event_token):
        return
    if event_token != "":
        observed_tokens.append(event_token)
        accumulator["observed_event_tokens"] = observed_tokens
    var actor = accumulator.get("actor")
    var target = accumulator.get("target")
    match event_kind:
        "defense_gained":
            if values.get("actor") == actor:
                accumulator["actor_defense_gained"] = int(accumulator.get(
                    "actor_defense_gained", 0)) + int(values.get(
                        "effective_amount", 0))
        "defense_reduced":
            if str(values.get("cause", "direct_effect")) != "direct_effect":
                return
            var removed := int(values.get("effective_amount", 0))
            if values.get("target") == actor:
                accumulator["actor_defense_lost"] = int(accumulator.get(
                    "actor_defense_lost", 0)) + removed
            elif values.get("target") == target:
                accumulator["target_defense_lost"] = int(accumulator.get(
                    "target_defense_lost", 0)) + removed
        "life_recovered":
            accumulator["life_recovered"] = int(accumulator.get(
                "life_recovered", 0)) + int(values.get(
                    "recovered_amount", values.get("effective_amount", 0)))
        "damage_resolved", "attack_canceled":
            _accumulate_damage_fact(
                accumulator, event_kind, values, actor, target)

func _sync_pending_facts_for_execution(token: String) -> void:
    if _event_service == null or not _event_service.has_method(
            "pending_publications_snapshot"):
        return
    for publication_value in _event_service.pending_publications_snapshot():
        var publication: Dictionary = publication_value
        var values: Dictionary = publication.get("values", {})
        if str(values.get("action_token", "")) != token:
            continue
        _on_committed_fact_for_execution(
            str(publication.get("event_kind", "")), values,
            publication.get("receipt", {}))

func _accumulate_damage_fact(
        accumulator: Dictionary,
        event_kind: String,
        values: Dictionary,
        actor,
        target) -> void:
    accumulator["requested_damage_total"] = int(accumulator.get(
        "requested_damage_total", 0)) + int(values.get(
            "requested_damage", values.get("requested_amount", values.get(
                "amount", 0))))
    accumulator["final_damage_total"] = int(accumulator.get(
        "final_damage_total", 0)) + int(values.get(
            "final_damage", values.get("final_amount", values.get("amount", 0))))
    accumulator["damage_segment_count"] = int(accumulator.get(
        "damage_segment_count", 0)) + 1
    var damage_type := str(values.get("damage_type", "normal"))
    var count_field := "%s_segment_count" % damage_type
    if accumulator.has(count_field):
        accumulator[count_field] = int(accumulator[count_field]) + 1
    if event_kind == "attack_canceled":
        var cancel_kind := str(values.get("cancel_kind", "none"))
        accumulator["total_canceled_segment_count"] = int(accumulator.get(
            "total_canceled_segment_count", 0)) + 1
        if cancel_kind == "block":
            accumulator["blocked_segment_count"] = int(accumulator.get(
                "blocked_segment_count", 0)) + 1
            accumulator["block_canceled_segment_count"] = int(
                accumulator.get("block_canceled_segment_count", 0)) + 1
        elif cancel_kind == "deflection":
            accumulator["deflection_canceled_segment_count"] = int(
                accumulator.get("deflection_canceled_segment_count", 0)) + 1
    else:
        var defense_lost := int(values.get("defense_lost", 0))
        var life_lost := int(values.get("life_lost", 0))
        if values.get("target") == actor:
            accumulator["actor_defense_lost"] = int(accumulator.get(
                "actor_defense_lost", 0)) + defense_lost
            accumulator["actor_life_lost"] = int(accumulator.get(
                "actor_life_lost", 0)) + life_lost
        elif values.get("target") == target:
            accumulator["target_defense_lost"] = int(accumulator.get(
                "target_defense_lost", 0)) + defense_lost
            accumulator["target_life_lost"] = int(accumulator.get(
                "target_life_lost", 0)) + life_lost
        if bool(values.get("life_loss_canceled", false)):
            accumulator["life_loss_canceled_segment_count"] = int(
                accumulator.get("life_loss_canceled_segment_count", 0)) + 1
    var segment_token := str(values.get("damage_segment_token", ""))
    if segment_token != "" \
            and not accumulator["damage_segment_tokens"].has(segment_token):
        accumulator["damage_segment_tokens"].append(segment_token)

func _card_facts(
        cards: Array, actor, target, hand_result: Dictionary,
        action_token: String, source_kind: String,
        round_number: int) -> Dictionary:
    var result: Array = []
    var identity_policy = actor.card_identity_policy if actor != null else null
    var participating_ids: Array = hand_result.get(
        "numeric_contributing", hand_result.get("contributing", [])).map(
            func(card): return str(card.id))
    for card in cards:
        var identity: Dictionary = {}
        if identity_policy != null and identity_policy.has_method("resolve"):
            var resolved: Dictionary = identity_policy.resolve(card, {})
            if resolved.get("success", false):
                identity = resolved["facts"].to_dict()
        var fact: Dictionary = actor.battle_rule_query_service.card_fact(
            card, actor, target, participating_ids.has(str(card.id))) \
            if actor != null and actor.battle_rule_query_service != null else {
                "instance_id": str(card.id),
                "definition_id": str(card.current_definition_id()) \
                    if card.has_method("current_definition_id") \
                    else str(card.definition_id),
                "effective_attributes": identity.get("effective_attributes", []),
                "participating": participating_ids.has(str(card.id)),
            }
        var effective := 0
        if actor != null and actor.battle_rule_query_service != null:
            var query = actor.battle_rule_query_service.resolve_effective_qi(
                actor, card, {
                    "actor": actor, "target": target,
                    "purpose": "power_calculation",
                    "evaluation_mode": "preview" if source_kind == "preview" \
                        else "confirm" if source_kind == "action_confirmed" \
                        else "runtime",
                    "cards": cards,
                    "participating_card_ids": participating_ids,
                    "hand_result": hand_result,
                    "action_token": action_token,
                    "source_kind": source_kind,
                    "round_number": round_number,
                })
            if not query.success:
                actor.battle_rule_query_service.report_failure(
                    query, "technique_resolution_card_facts")
                return {
                    "success": false,
                    "reason": "effective_qi_query：%s" % "；".join(query.errors),
                }
            effective = int(query.effective_value)
        else:
            effective = int(card.effective_qi_value()) \
                if card.has_method("effective_qi_value") else int(card.qi_value)
        fact["qi"] = effective
        fact["effective_qi"] = effective
        fact["identity"] = identity
        fact["attributes"] = identity.get("effective_attributes", [])
        result.append(fact)
    return {"success": true, "facts": result}
