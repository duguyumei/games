class_name AiBattleConversation
extends RefCounted

signal changed

const SnapshotScript = preload("res://core/ai/ai_conversation_snapshot.gd")
const CompactorScript = preload("res://core/ai/ai_history_compactor.gd")

const VERSION := 3
const DEFAULT_SETTINGS := {
    "compression_enabled": true,
    "compression_interval_rounds": 5,
    "max_retries": 1,
}

var battle_id: String = ""
var context_snapshot: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var public_events: Array = []
var exchanges: Array = []
var work_summary: Dictionary = {}
var last_compacted_round: int = 0
var last_sent_public_sequence: int = -1
var provider_epoch: int = 0
var context_sent_in_epoch: bool = false

func configure(context, setting_overrides: Dictionary = {}):
    context_snapshot = (
        context.snapshot()
        if context is Object and context.has_method("snapshot")
        else context.duplicate(true) if context is Dictionary else {})
    battle_id = str(context_snapshot.get("battle_id", ""))
    settings = DEFAULT_SETTINGS.duplicate(true)
    settings.merge(setting_overrides, true)
    settings["compression_interval_rounds"] = maxi(
        1, int(settings.get("compression_interval_rounds", 5)))
    settings["max_retries"] = maxi(0, int(settings.get("max_retries", 1)))
    return self

func record_public_event(event) -> void:
    var snapshot: Dictionary = (
        event.snapshot()
        if event is Object and event.has_method("snapshot")
        else event.duplicate(true) if event is Dictionary else {})
    if snapshot.is_empty():
        return
    public_events.append(snapshot)
    public_events.sort_custom(func(left, right):
        return int(left.get("sequence", -1)) < int(right.get("sequence", -1)))
    changed.emit()

func complete_round(round_number: int) -> bool:
    if not bool(settings.get("compression_enabled", true)):
        return false
    var compactor = CompactorScript.new(
        int(settings.get("compression_interval_rounds", 5)))
    if not compactor.should_compact(round_number, last_compacted_round):
        return false
    work_summary = compactor.compact(public_events, round_number)
    last_compacted_round = round_number
    provider_epoch += 1
    context_sent_in_epoch = false
    changed.emit()
    return true

func build_decision_request(
        observation,
        candidates: Array,
        correction: Dictionary = {}) -> Dictionary:
    var observation_snapshot: Dictionary = (
        observation.snapshot()
        if observation is Object and observation.has_method("snapshot")
        else observation.duplicate(true) if observation is Dictionary else {})
    var candidate_snapshots: Array = []
    for candidate in candidates:
        if candidate is Object and candidate.has_method("public_snapshot"):
            candidate_snapshots.append(candidate.public_snapshot())
        elif candidate is Dictionary:
            candidate_snapshots.append(candidate.duplicate(true))
    var history_floor := last_sent_public_sequence
    if not work_summary.is_empty():
        history_floor = maxi(
            history_floor,
            int(work_summary.get("through_sequence", -1)))
    var history_delta: Array = []
    var history_through := last_sent_public_sequence
    for event in public_events:
        var sequence := int(event.get("sequence", -1))
        if sequence > history_floor:
            history_delta.append(event.duplicate(true))
        history_through = maxi(history_through, sequence)
    var request := {
        "schema_version": VERSION,
        "type": "battle_decision",
        "battle_id": battle_id,
        "provider_epoch": provider_epoch,
        "observation": observation_snapshot,
        "history_summary": work_summary.duplicate(true),
        "history_delta": history_delta,
        "history_through_sequence": history_through,
        "candidates": candidate_snapshots,
    }
    if not context_sent_in_epoch:
        request["battle_context"] = context_snapshot.duplicate(true)
    if not correction.is_empty():
        request["correction"] = correction.duplicate(true)
    return request

func record_request(request_id: String, request: Dictionary) -> void:
    exchanges.append({
        "kind": "request",
        "request_id": request_id,
        "provider_epoch": provider_epoch,
        "battle_id": battle_id,
        "decision_id": str(request.get("observation", {}).get("decision_id", "")),
        "round_number": int(request.get("observation", {}).get("round_number", 0)),
        "action_index": int(request.get("observation", {}).get("action_index", 0)),
        "retry_index": _retry_index(request_id),
        "payload": request.duplicate(true),
    })
    if request.has("battle_context"):
        context_sent_in_epoch = true
    changed.emit()

func record_response(request_id: String, response: Dictionary) -> void:
    exchanges.append({
        "kind": "response",
        "request_id": request_id,
        "provider_epoch": provider_epoch,
        "battle_id": battle_id,
        "error_code": str(response.get("error_code", "")),
        "retry_index": _retry_index(request_id),
        "payload": response.duplicate(true),
    })
    changed.emit()

func accept_decision(request: Dictionary, result: Dictionary) -> void:
    last_sent_public_sequence = maxi(
        last_sent_public_sequence,
        int(request.get("history_through_sequence", -1)))
    exchanges.append({
        "kind": "decision_accepted",
        "decision_id": str(request.get("observation", {}).get("decision_id", "")),
        "candidate_id": str(result.get("candidate_id", "")),
        "provider_epoch": provider_epoch,
        "battle_id": battle_id,
        "round_number": int(request.get("observation", {}).get("round_number", 0)),
        "action_index": int(request.get("observation", {}).get("action_index", 0)),
        "reason_code": str(result.get("reason_code", "unspecified")),
        "confidence": float(result.get("confidence", 0.0)),
        "protocol_quality_issue": bool(result.get("protocol_quality_issue", false)),
    })
    changed.emit()

func record_local_outcome(
        decision_id: String,
        outcome_kind: String,
        payload: Dictionary = {}) -> void:
    exchanges.append({
        "kind": outcome_kind,
        "decision_id": decision_id,
        "provider_epoch": provider_epoch,
        "battle_id": battle_id,
        "payload": payload.duplicate(true),
    })
    changed.emit()

func record_audit(kind: String, values: Dictionary = {}) -> void:
    var entry := {
        "kind": kind,
        "battle_id": battle_id,
        "decision_id": str(values.get("decision_id", "")),
        "request_id": str(values.get("request_id", "")),
        "provider_epoch": provider_epoch,
        "round_number": int(values.get("round_number", 0)),
        "action_index": int(values.get("action_index", 0)),
        "error_code": str(values.get("error_code", "")),
        "retry_index": int(values.get("retry_index", 0)),
    }
    for key in values:
        if not entry.has(key):
            entry[key] = values[key] if not values[key] is Dictionary \
                and not values[key] is Array else values[key].duplicate(true)
    exchanges.append(entry)
    changed.emit()

func _retry_index(request_id: String) -> int:
    return int(request_id.get_slice(":", request_id.get_slice_count(":") - 1))

func snapshot() -> AiConversationSnapshot:
    return SnapshotScript.from_dict({
        "battle_id": battle_id,
        "context_snapshot": context_snapshot.duplicate(true),
        "settings": settings.duplicate(true),
        "public_events": public_events.duplicate(true),
        "exchanges": exchanges.duplicate(true),
        "work_summary": work_summary.duplicate(true),
        "last_compacted_round": last_compacted_round,
        "last_sent_public_sequence": last_sent_public_sequence,
        "provider_epoch": provider_epoch,
        "context_sent_in_epoch": context_sent_in_epoch,
    })
