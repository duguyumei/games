class_name AiHistoryEvent
extends RefCounted

const VERSION := 3

var sequence: int = -1
var round_number: int = 0
var action_index: int = 0
var window_id: String = ""
var event_type: String = ""
var actor_id: String = ""
var visibility: String = "public"
var payload: Dictionary = {}

func configure(values: Dictionary):
    sequence = int(values.get("sequence", values.get("serial", -1)))
    round_number = int(values.get("round_number", 0))
    action_index = int(values.get("action_index", 0))
    window_id = str(values.get("window_id", ""))
    event_type = str(values.get("event_type", values.get("type", "")))
    actor_id = str(values.get("actor_id", values.get("actor", "")))
    visibility = str(values.get("visibility", "public"))
    payload = values.get("payload", {}).duplicate(true)
    return self

func snapshot() -> Dictionary:
    return {
        "schema_version": VERSION,
        "sequence": sequence,
        "round_number": round_number,
        "action_index": action_index,
        "window_id": window_id,
        "event_type": event_type,
        "actor_id": actor_id,
        "visibility": visibility,
        "payload": payload.duplicate(true),
    }
