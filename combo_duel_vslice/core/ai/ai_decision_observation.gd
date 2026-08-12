class_name AiDecisionObservation
extends RefCounted

const VERSION := 3
const FORBIDDEN_OPPONENT_KEYS := [
    "hand",
    "hand_cards",
    "draw_pile",
    "draw_order",
    "selected_card_ids",
    "staging",
    "rng_seed",
    "private_counters",
    "candidate_diagnostics",
]

var decision_id: String = ""
var window_id: String = ""
var state_hash: String = ""
var round_number: int = 0
var action_index: int = 0
var self_state: Dictionary = {}
var opponent_public_state: Dictionary = {}
var metadata: Dictionary = {}

func configure(values: Dictionary):
    decision_id = str(values.get("decision_id", ""))
    window_id = str(values.get("window_id", decision_id))
    state_hash = str(values.get("state_hash", ""))
    round_number = int(values.get("round_number", 0))
    action_index = int(values.get("action_index", 0))
    self_state = values.get("self_state", {}).duplicate(true)
    opponent_public_state = _sanitize_opponent(
        values.get("opponent_public_state", {}))
    metadata = values.get("metadata", {}).duplicate(true)
    return self

func is_valid() -> bool:
    return decision_id != "" and window_id != "" and state_hash != ""

func snapshot() -> Dictionary:
    return {
        "schema_version": VERSION,
        "decision_id": decision_id,
        "window_id": window_id,
        "state_hash": state_hash,
        "round_number": round_number,
        "action_index": action_index,
        "self": self_state.duplicate(true),
        "opponent": opponent_public_state.duplicate(true),
        "metadata": metadata.duplicate(true),
    }

func _sanitize_opponent(value: Dictionary) -> Dictionary:
    return _sanitize_value(value)

func _sanitize_value(value):
    if value is Dictionary:
        var sanitized: Dictionary = {}
        for key in value:
            if FORBIDDEN_OPPONENT_KEYS.has(str(key)):
                continue
            sanitized[key] = _sanitize_value(value[key])
        return sanitized
    if value is Array:
        var sanitized: Array = []
        for item in value:
            sanitized.append(_sanitize_value(item))
        return sanitized
    return value
