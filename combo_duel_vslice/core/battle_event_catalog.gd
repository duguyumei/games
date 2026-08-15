class_name BattleEventCatalog
extends RefCounted

## Battle event IDs have one owner. Consumers query this catalog instead of
## carrying local timing/committed/automatic/response whitelists.

const TIMING_EVENTS := [
    "battle_start", "round_start", "turn_start", "before_normal_draw",
    "after_normal_draw", "action_window_start", "group_end",
    "action_window_end", "turn_end", "battle_end",
]

const COMMITTED_EVENTS := [
    "action_confirmed", "action_resolved", "card_drawn",
    "card_entered_discard", "card_explicitly_discarded",
    "damage_resolved", "damage_blocked", "reflection_resolved",
    "reflection_source_changed", "block_source_changed",
    "challenge_established", "challenge_progressed", "challenge_resolved",
    "poison_trigger_completed", "defense_gained", "defense_reduced",
    "life_recovered", "source_marker_changed",
    "technique_invocation_started", "technique_invocation_resolved",
    "technique_sequence_changed", "same_qi_gain_resolved",
]

const AUTOMATIC_EVENTS := COMMITTED_EVENTS + ["round_start", "turn_end"]
const RESPONSE_ONLY_EVENTS := [
    "action_pre_commit", "action_resolution_end", "after_normal_draw",
    "card_anomaly_changed", "card_burned_out_changed", "card_moved",
    "cooperation_pre_commit", "cooperation_resolved",
    "defense_decay_resolved", "extra_action_started",
]
const DYNAMIC_RESPONSE_EVENTS := \
    COMMITTED_EVENTS + TIMING_EVENTS + RESPONSE_ONLY_EVENTS

const PUBLIC_FIELDS := [
    "event_token", "event_serial", "action_token", "round_number",
    "source_kind", "draw_reason", "damage_type", "hand_id",
    "technique_power", "requested_amount", "final_amount",
    "effective_amount", "defense_lost", "life_lost", "actual_life_loss",
    "frozen_amount", "defense_before", "defense_after", "life_before",
    "life_after", "from_zone", "to_zone", "reason", "explicit_discard",
    "normal_play", "technique_triggered", "action_succeeded",
    "source_card_instance_id", "pre_move_snapshot", "metadata",
]

static func event_ids() -> Array[String]:
    var result: Array[String] = []
    for event_id in TIMING_EVENTS + COMMITTED_EVENTS + RESPONSE_ONLY_EVENTS:
        if not result.has(str(event_id)):
            result.append(str(event_id))
    return result

static func is_timing(event_id: String) -> bool:
    return event_id in TIMING_EVENTS

static func is_committed(event_id: String) -> bool:
    return event_id in COMMITTED_EVENTS

static func can_automatic_listen(event_id: String) -> bool:
    return event_id in AUTOMATIC_EVENTS

static func forwards_dynamic_response(event_id: String) -> bool:
    return event_id in DYNAMIC_RESPONSE_EVENTS

static func public_projection(values: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for field in PUBLIC_FIELDS:
        if values.has(field):
            result[field] = values[field]
    return result
