class_name AiHistoryProjector
extends RefCounted

const HistoryEventScript = preload("res://core/ai/ai_history_event.gd")
const HIDDEN_ID_KEYS := [
    "card_id",
    "card_ids",
    "target_card_id",
    "target_card_ids",
    "drawn_card_ids",
]
const PUBLIC_EVENT_TYPES := [
    "action_window_opened", "cards_played", "technique_resolved",
    "cooperation_resolved", "same_qi_changed", "combo_granted", "damage_resolved",
    "defense_changed", "defense_decayed", "card_drawn",
    "card_entered_discard", "card_explicitly_discarded",
    "card_temporarily_removed", "card_returned", "card_state_changed",
    "passive_triggered", "passive_counter_changed", "sequence_advanced",
    "consumable_used", "action_resolved", "round_completed",
    "battle_completed",
    "source_marker_changed", "technique_invocation_started",
    "technique_invocation_resolved", "technique_sequence_changed",
    "life_recovered", "defense_reduced",
]

func project(raw_event: Dictionary) -> Dictionary:
    var values := raw_event.duplicate(true)
    if not PUBLIC_EVENT_TYPES.has(str(values.get("event_type", values.get("type", "")))):
        return {}
    var visibility := str(values.get("visibility", "public"))
    if visibility == "private":
        return {}
    var payload: Dictionary = values.get("payload", {}).duplicate(true)
    if str(values.get("event_type", values.get("type", ""))) == "source_marker_changed" \
            and not bool(payload.get("public", values.get("public", true))):
        return {}
    if visibility == "hidden_random_target":
        var hidden_count := [int(payload.get("count", 0))]
        payload = _redact_hidden_targets(payload, hidden_count)
        payload["hidden_target_count"] = int(hidden_count[0])
    if str(values.get("actor_id", "")) == "player" \
            and str(values.get("event_type", "")) == "card_drawn":
        var drawn_count := int(payload.get("count", payload.get("drawn_count", 0)))
        payload = {"count": drawn_count}
    values["payload"] = payload
    values["visibility"] = "public_redacted" if visibility == "hidden_random_target" else "public"
    return HistoryEventScript.new().configure(values).snapshot()

func project_many(raw_events: Array) -> Array:
    var projected: Array = []
    for raw_event_value in raw_events:
        if not raw_event_value is Dictionary:
            continue
        var event: Dictionary = project(raw_event_value)
        if not event.is_empty():
            projected.append(event)
    projected.sort_custom(func(left, right):
        return int(left.get("sequence", -1)) < int(right.get("sequence", -1)))
    return projected

func from_game_log_entry(entry: Dictionary, round_number: int, action_index: int = 0) -> Dictionary:
    return project({
        "sequence": int(entry.get("serial", -1)),
        "round_number": round_number,
        "action_index": action_index,
        "event_type": str(entry.get("category", "log")),
        "actor_id": str(entry.get("context", {}).get("actor_id", "")),
        "visibility": str(entry.get("context", {}).get("ai_visibility", "public")),
        "payload": {
            "message": str(entry.get("message", "")),
            "detail": str(entry.get("detail", "")),
            "context": entry.get("context", {}).duplicate(true),
        },
    })

func _redact_hidden_targets(value, hidden_count: Array):
    if value is Dictionary:
        var redacted: Dictionary = {}
        for key in value:
            if HIDDEN_ID_KEYS.has(str(key)):
                if value[key] is Array:
                    hidden_count[0] = maxi(int(hidden_count[0]), value[key].size())
                elif value[key] != null and str(value[key]) != "":
                    hidden_count[0] = maxi(int(hidden_count[0]), 1)
                continue
            redacted[key] = _redact_hidden_targets(value[key], hidden_count)
        return redacted
    if value is Array:
        var redacted: Array = []
        for item in value:
            redacted.append(_redact_hidden_targets(item, hidden_count))
        return redacted
    return value
