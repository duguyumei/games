class_name StatusResponseService
extends RefCounted

const EffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const BattleEventCatalogScript = preload(
    "res://core/battle_event_catalog.gd")
const ConditionSpecRegistryScript = preload(
    "res://core/specs/condition_spec_registry.gd")

var _record_id_allocator
var _response_records: Array = []
var _condition_registry = ConditionSpecRegistryScript.new()
var _effect_ports_ref: WeakRef
var _effect_executor = null


func _init(record_id_allocator) -> void:
    assert(record_id_allocator != null,
        "StatusResponseService requires StatusRecordIdAllocator")
    _record_id_allocator = record_id_allocator


func register_response(
        event_kind: String,
        expiry: String,
        effects: Array,
        context,
        filters: Dictionary = {},
        expiry_effects: Array = [],
        lifecycle: Dictionary = {}) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    if not BattleEventCatalogScript.forwards_dynamic_response(event_kind):
        return {"success": false, "reason": "未知动态响应事件：%s" % event_kind}
    var resolved_filters := _condition_registry.resolve_event_filters(
        filters, runtime.captures)
    var record_key := str(lifecycle.get("record_key", ""))
    var existing: Variant = _find_keyed_record(runtime, record_key)
    var existing_policy := str(lifecycle.get(
        "existing_policy", "keep_existing"))
    if existing != null:
        match existing_policy:
            "keep_existing":
                return {
                    "success": true,
                    "record": existing,
                    "reused": true,
                    "created": false,
                }
            "reset_remaining":
                var replacement_record := _make_record(
                    event_kind, expiry, effects, expiry_effects,
                    resolved_filters, runtime, lifecycle)
                var existing_id := str(existing.get("id", ""))
                existing.clear()
                existing.merge(replacement_record, true)
                existing["id"] = existing_id
                return {
                    "success": true,
                    "record": existing,
                    "reused": true,
                    "reset": true,
                    "created": false,
                }
            "replace":
                _response_records.erase(existing)
            _:
                return {"success": false, "reason": "未知响应既有记录策略"}
    elif existing_policy not in [
            "keep_existing", "reset_remaining", "replace"]:
        return {"success": false, "reason": "未知响应既有记录策略"}
    var record := _make_record(
        event_kind, expiry, effects, expiry_effects, resolved_filters,
        runtime, lifecycle)
    _response_records.append(record)
    return {
        "success": true,
        "record": record,
        "reused": false,
        "created": true,
    }


func _make_record(
        event_kind: String,
        expiry: String,
        effects: Array,
        expiry_effects: Array,
        resolved_filters: Dictionary,
        runtime,
        lifecycle: Dictionary) -> Dictionary:
    return {
        "id": _record_id_allocator.next_id("response"),
        "event_kind": event_kind,
        "expiry": expiry,
        "effects": effects.duplicate(true),
        "expiry_effects": expiry_effects.duplicate(true),
        "completion_effects": lifecycle.get(
            "completion_effects", []).duplicate(true),
        "record_key": str(lifecycle.get("record_key", "")),
        "existing_policy": str(lifecycle.get(
            "existing_policy", "keep_existing")),
        "skip_registration_action": bool(lifecycle.get(
            "skip_registration_action", false)),
        "filters": resolved_filters,
        "actor": runtime.actor,
        "target": runtime.target,
        "power": runtime.power,
        "initial_power": runtime.initial_power,
        "hand_result": runtime.hand_result.duplicate(true),
        "played_cards": runtime.played_cards.duplicate(),
        "group_snapshot": runtime.group_snapshot.duplicate(true),
        "captures": runtime.captures.duplicate(true),
        "technique_id": runtime.technique_id,
        "technique_name": runtime.technique_name,
        "actual_hand_id": runtime.actual_hand_id,
        "branch_hand_id": runtime.branch_hand_id,
        "technique_pool": runtime.technique_pool,
        "action_token": runtime.action_token,
        "root_action_token": runtime.root_action_token,
        "invocation_token": runtime.invocation_token,
        "caller_technique_id": runtime.caller_technique_id,
        "slot_instance_id": runtime.slot_instance_id,
        "technique_execution_token": runtime.technique_execution_token,
        "technique_execution_state": runtime.technique_execution_state.duplicate(true),
        "trigger_mode": runtime.trigger_mode,
        "source_kind": runtime.source_kind,
        "source_id": runtime.source_id,
        "source_name": runtime.source_name,
        "source_instance_key": runtime.source_instance_key,
        "sequence_book": runtime.sequence_book,
        "source_round": _current_round_hint(runtime),
        "resolving": false,
        "remaining_triggers": int(resolved_filters.get("max_triggers", -1)),
        "trigger_count": 0,
    }


func handle_event(event_kind: String, values: Dictionary) -> void:
    if _effect_executor == null:
        return
    var matching: Array = _response_records.filter(func(record):
        return str(record.get("event_kind", "")) == event_kind \
            and not bool(record.get("resolving", false)) \
            and int(record.get("remaining_triggers", -1)) != 0 \
            and _response_matches(record, values))
    for record in matching:
        var remaining_before := int(record.get("remaining_triggers", -1))
        var remaining_after := remaining_before - 1 \
            if remaining_before > 0 else -1
        var is_final_trigger := remaining_before == 1
        var event_values := values.duplicate(true)
        event_values.merge({
            "response_trigger_index": int(record.get("trigger_count", 0)) + 1,
            "response_remaining_before": remaining_before,
            "response_remaining_after": remaining_after,
            "response_is_final_trigger": is_final_trigger,
        }, true)
        var effects: Array = record["effects"].duplicate(true)
        if is_final_trigger:
            effects.append_array(record.get(
                "completion_effects", []).duplicate(true))
        record["resolving"] = true
        var response_result: Dictionary = _execute_response_effects(
            record, effects, event_values, "response")
        record["resolving"] = false
        if response_result.get("success", false):
            record["trigger_count"] = int(record.get("trigger_count", 0)) + 1
            if remaining_before > 0:
                record["remaining_triggers"] = remaining_after
            if is_final_trigger:
                _response_records.erase(record)


func on_committed_event(
        event_kind: String,
        values: Dictionary,
        _receipt: Dictionary) -> void:
    if bool(values.get("defer_dynamic_response", false)):
        return
    if BattleEventCatalogScript.forwards_dynamic_response(event_kind):
        handle_event(event_kind, values)


func expire_turn_end(actor, round_number: int) -> Dictionary:
    var expired_count := 0
    var candidates := _response_records.duplicate()
    for record in candidates:
        if not _expires_at_turn_end(record, actor, round_number):
            continue
        if not record.get("expiry_effects", []).is_empty():
            _execute_response_effects(record, record["expiry_effects"], {
                "actor": actor,
                "round_number": round_number,
            }, "response_expiry")
        _response_records.erase(record)
        expired_count += 1
    return {"success": true, "expired_count": expired_count}


func clear() -> int:
    var cleared_count := _response_records.size()
    _response_records.clear()
    return cleared_count


func use_effect_ports(effect_ports) -> void:
    _effect_ports_ref = weakref(effect_ports) if effect_ports != null else null


func use_effect_executor(executor) -> void:
    _effect_executor = executor


func records() -> Array:
    return _response_records


func _execute_response_effects(
        record: Dictionary,
        effects: Array,
        values: Dictionary,
        trigger_mode: String) -> Dictionary:
    if _effect_executor == null:
        return {"success": false, "detail": "动态响应缺少统一执行器"}
    var captures: Dictionary = record.get("captures", {}).duplicate(true)
    captures["event"] = [values.duplicate(true)]
    captures["response_lifecycle"] = [{
        "trigger_index": int(values.get("response_trigger_index", 0)),
        "remaining_before": int(values.get("response_remaining_before", -1)),
        "remaining_after": int(values.get("response_remaining_after", -1)),
        "is_final_trigger": bool(values.get(
            "response_is_final_trigger", false)),
    }]
    var action_results = values.get("action_results", [])
    if action_results is Array:
        captures["action_results"] = action_results.duplicate(true)
        captures["event_actor_result"] = _results_for_side(
            action_results, record.get("actor"))
        captures["event_target_result"] = _results_for_side(
            action_results, record.get("target"))
    if values.has("card"):
        captures["event_card"] = [values["card"]]
    if values.has("pre_move_snapshot"):
        captures["event_snapshot"] = [values["pre_move_snapshot"]]
    var event_identity := str(values.get("event_token", ""))
    if event_identity == "":
        event_identity = "%s:%s" % [
            str(values.get("action_token", record.get("action_token", ""))),
            str(values.get("round_number", record.get("source_round", 0))),
        ]
    # 注册来源的 technique_execution_token 只标识“谁建立了响应”，不能
    # 直接作为每次响应效果的幂等键。响应记录与触发事件共同构成独立、稳定
    # 的 EffectSpec 作用域：同一事件重放仍复用，不同事件或不同响应不碰撞。
    var response_effect_scope := "response:%s:%s:%s" % [
        str(record.get("id", "")), trigger_mode, event_identity]
    var response_context = EffectContextScript.new().configure({
        "ports": _effect_ports(),
        "actor": record["actor"],
        "target": record["target"],
        "power": int(record["power"]),
        "initial_power": int(record["initial_power"]),
        "hand_result": record["hand_result"],
        "played_cards": record["played_cards"],
        "group_snapshot": record["group_snapshot"],
        "captures": captures,
        "technique_id": record["technique_id"],
        "technique_name": record["technique_name"],
        "actual_hand_id": record["actual_hand_id"],
        "branch_hand_id": record["branch_hand_id"],
        "technique_pool": record["technique_pool"],
        "action_token": record["action_token"],
        "root_action_token": record.get(
            "root_action_token", record["action_token"]),
        "invocation_token": record.get("invocation_token", ""),
        "caller_technique_id": record.get("caller_technique_id", ""),
        "slot_instance_id": record.get("slot_instance_id", ""),
        "technique_execution_token": record.get(
            "technique_execution_token", ""),
        "effect_execution_scope_token": response_effect_scope,
        "technique_execution_state": record.get(
            "technique_execution_state", {}).duplicate(true),
        "trigger_mode": trigger_mode,
        "sequence_book": record.get("sequence_book"),
        "source_kind": record.get("source_kind", "rule"),
        "source_id": record.get("source_id", ""),
        "source_name": record.get("source_name", ""),
        "source_instance_key": record.get("source_instance_key", ""),
    })
    return _effect_executor.execute_all(effects, response_context)


func _response_matches(record: Dictionary, values: Dictionary) -> bool:
    if bool(record.get("skip_registration_action", false)):
        var action_tokens: Array = values.get(
            "action_tokens", values.get("metadata", {}).get(
                "action_tokens", []))
        if action_tokens.has(str(record.get("action_token", ""))) \
                or action_tokens.has(str(record.get(
                    "root_action_token", ""))):
            return false
    return _condition_registry.event_matches(
        record.get("filters", {}), values, record.get("actor"),
        record.get("target"), record)


func _find_keyed_record(runtime, record_key: String):
    if record_key == "":
        return null
    for record in _response_records:
        if str(record.get("record_key", "")) == record_key \
                and record.get("actor") == runtime.actor \
                and str(record.get("source_instance_key", "")) \
                    == runtime.source_instance_key:
            return record
    return null


func _results_for_side(results: Array, side) -> Array:
    var matched: Array = []
    for result_value in results:
        if result_value is Dictionary \
                and result_value.get("side") == side:
            matched.append(result_value.duplicate(true))
    return matched


func _expires_at_turn_end(
        record: Dictionary,
        actor,
        round_number: int) -> bool:
    if record.get("actor") != actor:
        return false
    if record.get("expiry") == "turn_end":
        return true
    return record.get("expiry") == "next_round_turn_end" \
        and int(record.get("source_round", -1)) + 1 <= round_number


func _current_round_hint(runtime) -> int:
    return int(runtime.action_token.split("-")[-2]) \
        if runtime.action_token.split("-").size() >= 3 else 0


func _effect_ports():
    return _effect_ports_ref.get_ref() if _effect_ports_ref != null else null
