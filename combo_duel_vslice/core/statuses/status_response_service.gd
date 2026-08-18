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
        expiry_effects: Array = []) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    if not BattleEventCatalogScript.forwards_dynamic_response(event_kind):
        return {"success": false, "reason": "未知动态响应事件：%s" % event_kind}
    var resolved_filters := _condition_registry.resolve_event_filters(
        filters, runtime.captures)
    var record := {
        "id": _record_id_allocator.next_id("response"),
        "event_kind": event_kind,
        "expiry": expiry,
        "effects": effects.duplicate(true),
        "expiry_effects": expiry_effects.duplicate(true),
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
        "remaining_triggers": int(filters.get("max_triggers", -1)),
    }
    _response_records.append(record)
    return {"success": true, "record": record}


func handle_event(event_kind: String, values: Dictionary) -> void:
    if _effect_executor == null:
        return
    var matching: Array = _response_records.filter(func(record):
        return str(record.get("event_kind", "")) == event_kind \
            and not bool(record.get("resolving", false)) \
            and _response_matches(record, values))
    for record in matching:
        record["resolving"] = true
        var response_result: Dictionary = _execute_response_effects(
            record, record["effects"], values, "response")
        record["resolving"] = false
        if response_result.get("success", false) \
                and int(record.get("remaining_triggers", -1)) > 0:
            record["remaining_triggers"] = int(record["remaining_triggers"]) - 1
            if int(record["remaining_triggers"]) <= 0:
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
    if values.has("card"):
        captures["event_card"] = [values["card"]]
    if values.has("pre_move_snapshot"):
        captures["event_snapshot"] = [values["pre_move_snapshot"]]
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
    return _condition_registry.event_matches(
        record.get("filters", {}), values, record.get("actor"),
        record.get("target"), record)


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
