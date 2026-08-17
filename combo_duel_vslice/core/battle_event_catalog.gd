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
    "action_confirmed", "action_resolved", "card_moved", "card_state_changed",
    "card_drawn",
    "card_entered_discard", "card_explicitly_discarded",
    "damage_resolved", "damage_blocked", "reflection_resolved",
    "reflection_source_changed", "block_source_changed",
    "challenge_established", "challenge_progressed", "challenge_resolved",
    "poison_trigger_completed", "defense_gained", "defense_reduced",
    "life_recovered", "source_marker_changed", "technique_succeeded",
    "technique_invocation_started", "technique_invocation_resolved",
    "technique_sequence_changed", "technique_slot_capacity_changed",
    "temporary_technique_generated", "same_qi_gain_resolved",
]

const AUTOMATIC_EVENTS := COMMITTED_EVENTS + ["round_start", "turn_end"]
const RESPONSE_ONLY_EVENTS := [
    "action_pre_commit", "action_resolution_end", "after_normal_draw",
    "card_anomaly_changed", "card_burned_out_changed",
    "cooperation_pre_commit", "cooperation_resolved",
    "defense_decay_resolved", "extra_action_started",
]
const DYNAMIC_RESPONSE_EVENTS := \
    COMMITTED_EVENTS + TIMING_EVENTS + RESPONSE_ONLY_EVENTS

const PUBLIC_FIELDS := [
    "event_token", "event_serial", "action_token", "round_number",
    "source_kind", "source_id", "source_name", "source_instance_key",
    "draw_reason", "damage_type", "hand_id",
    "technique_id", "technique_pool", "initial_power", "technique_power",
    "trigger_mode", "effective_qi", "requested_amount", "final_amount",
    "effective_amount", "defense_lost", "life_lost", "actual_life_loss",
    "frozen_amount", "defense_before", "defense_after", "life_before",
    "life_after", "from_zone", "to_zone", "reason", "placement",
    "transition_kind", "explicit_discard",
    "normal_play", "technique_triggered", "action_succeeded",
    "card_instance_id", "source_card_instance_id", "pre_move_snapshot",
    "from_holder_id", "to_holder_id", "original_owner_id",
    "from_zone_count_before", "from_zone_count_after",
    "to_zone_count_before", "to_zone_count_after",
    "hand_count_before", "hand_count_after",
    "from_hand_count_before", "from_hand_count_after",
    "to_hand_count_before", "to_hand_count_after",
    "movement_batch_token", "movement_batch_index", "metadata",
    "operation_token", "holder_id", "change_domain", "operation",
    "before_state", "after_state", "changes",
    "added_changes", "removed_changes", "updated_changes",
    "added_count", "removed_count", "updated_count", "actual_change_count",
    "category", "anomaly_id", "subslot", "reshape_id",
    "transfer_batch_token", "transfer_peer_card_id", "transfer_direction",
    "card_base_qi", "current_base_qi",
    "host_hand_id", "slot_instance_id", "origin_technique_id",
    "origin_slot_instance_id", "insertion_serial", "insertion_position",
    "marker_mode", "generation_batch_token", "temporary",
    "capacity_before", "capacity_after", "requested_delta", "actual_delta",
    "occupied_count", "remaining_capacity", "changed_slots",
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
