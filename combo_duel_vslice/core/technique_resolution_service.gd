class_name TechniqueResolutionService
extends RefCounted

const EffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")
const TechniquePhaseCatalogScript = preload(
    "res://core/effects/technique_phase_catalog.gd")

const PENDING_CAPTURE := "__technique_resolution_pending"

var _repository
var _executor
var _ports
var _event_service

func _init(repository, executor, ports, event_service) -> void:
    _repository = repository
    _executor = executor
    _ports = ports
    _event_service = event_service

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
        "root_action_token": str(request.get("root_action_token", token)),
        "invocation_token": token,
        "caller_technique_id": runtime.technique_id,
        "slot_instance_id": str(slot.get("slot_instance_id", "")),
        "trigger_mode": str(effect.get("_trigger_mode", "invoked")),
        "source_kind": "technique",
        "source_id": definition.id,
        "source_name": definition.display_name,
        "source_instance_key": str(slot.get("slot_instance_id", "")),
        "captures": request.get("captures", {}).duplicate(true),
        "sequence_book": runtime.sequence_book,
        "card_identity_policy": runtime.actor.card_identity_policy,
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
    }
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
        bool(effect.get("check_condition", true)), {}, true)
    if not activation.get("success", false):
        return activation
    if not activation.get("triggered", false):
        return {
            "success": true, "triggered": false,
            "detail": activation.get("reason", "调用启动被拒绝"),
            "activation": activation,
        }
    var power_result := resolve_power(
        runtime.actor, runtime.target, invocation_hand_result,
        runtime.played_cards, int(request.get("p0", 0)),
        str(request.get("invocation_token", "")),
        str(effect.get("_trigger_mode", "invoked")),
        bool(effect.get("use_momentum", true)))
    if not power_result.get("success", false):
        return power_result
    return {
        "success": true,
        "triggered": true,
        "definition": definition,
        "power_result": power_result,
        "activation": activation,
    }

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
        round_number: int = 0) -> Dictionary:
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
            "card_facts": _card_facts(cards, actor.card_identity_policy),
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

func settle_same_qi(
        actor,
        amount: int,
        source: String,
        token: String,
        enabled: bool = true) -> Dictionary:
    if not enabled:
        return {"success": true, "skipped": true, "amount": 0}
    return _ports.gain_same_qi(actor, amount, source, token)

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

func settle_manual_record(record) -> void:
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
                return {"success": false, "reason": "功法结算等待选择缺少 continuation"}
            state["request_id"] = str(request_object.request_id)
            runtime.captures[PENDING_CAPTURE] = state
            return _pending_result(state)
        if not result.get("success", false):
            runtime.captures.erase(PENDING_CAPTURE)
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
        _settle_momentum(
            runtime.actor, token, state["definition"].id, true)
    runtime.actor.consume_pending_power_fixed_sources(
        state.get("pending_power_fixed_tokens", []))
    var same_qi_result := settle_same_qi(
        runtime.actor,
        int(runtime.group_snapshot.get("action_same_qi_gain", 0)),
        "technique_invocation",
        token + ":same_qi",
        bool(effect.get("gain_same_qi", true)))
    if not same_qi_result.get("success", false):
        return same_qi_result
    var completed := {"success": true}
    if bool(effect.get("advance_sequence", true)):
        completed = runtime.sequence_book.complete_slot(
            str(request.get("hand_id", "")),
            str(state.get("slot_instance_id", "")))
    if not completed.get("success", false):
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
    return result

func _settle_momentum(actor, action_token: String,
        technique_id: String, use_momentum: bool) -> Dictionary:
    if not use_momentum:
        return {}
    var changed: bool = actor.momentum_changed_for_action(action_token)
    var preservation := {"preserved": false, "consumed": false}
    var clear_receipt: Dictionary = {}
    if not changed:
        preservation = actor.consume_momentum_preservation_for(action_token)
        if not bool(preservation.get("preserved", false)):
            clear_receipt = actor.write_momentum(
                "clear", 0, "rule_clear", action_token, technique_id)
    return {
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

func _card_facts(cards: Array, identity_policy) -> Array:
    var result: Array = []
    for card in cards:
        var identity: Dictionary = {}
        if identity_policy != null and identity_policy.has_method("resolve"):
            var resolved: Dictionary = identity_policy.resolve(card, {})
            if resolved.get("success", false):
                identity = resolved["facts"].to_dict()
        result.append({
            "instance_id": str(card.id),
            "definition_id": str(card.current_definition_id()) \
                if card.has_method("current_definition_id") \
                else str(card.definition_id),
            "qi": int(card.effective_qi_value()) \
                if card.has_method("effective_qi_value") else int(card.qi_value),
            "identity": identity,
            "attributes": identity.get("effective_attributes", []),
        })
    return result
