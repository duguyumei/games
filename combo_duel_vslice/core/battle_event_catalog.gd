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
    "qi_consumed", "qi_reshape_committed",
    "card_drawn",
    "card_entered_discard", "card_explicitly_discarded",
    "damage_resolved", "damage_blocked", "deflection_resolved",
    "attack_canceled", "reflection_resolved",
    "reflection_source_changed", "block_source_changed",
    "challenge_established", "challenge_progressed", "challenge_resolved",
    "poison_trigger_completed", "defense_gained", "defense_reduced",
    "life_recovered", "source_marker_changed", "technique_succeeded",
    "technique_execution_resolved",
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
    "requested_damage", "final_damage", "damage_segment_token", "cause",
    "direct_attack", "reflection_damage",
    "amount", "attack_amount", "action_window_id", "execution_token",
    "source_token", "cancel_kind", "threshold", "consumed", "succeeded",
    "pierced", "checked_source_tokens", "established_order", "window_id",
    "waiting_for_action", "change", "public_state",
    "cancel_source_kind", "cancel_source_id", "cancel_source_name",
    "cancel_source_instance_key", "cancel_trigger_mode",
    "life_loss_before_intervention", "life_loss_prevented",
    "life_loss_canceled", "life_loss_intervention_breakdown",
    "life_loss_source_fingerprint", "life_loss_query_fingerprint",
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
    "movement_batch_token", "movement_batch_index",
    "consumption_batch_token", "consumption_batch_index",
    "consumption_batch_size", "metadata",
    "operation_token", "holder_id", "change_domain", "operation",
    "scope", "persistence", "mutation_kind", "request_fingerprint",
    "before", "after",
    "created", "removed", "existed_before", "exists_after", "changed",
    "marker_role",
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
    "technique_execution_token", "root_action_token", "invocation_token",
    "caller_technique_id", "is_echo", "manual_effect_suppressed",
    "sequence_advance_requested", "same_qi_gain_enabled", "momentum_enabled",
    "actor_defense_gained", "actor_defense_lost", "target_defense_lost",
    "actor_life_lost", "target_life_lost", "target_total_reduction",
    "life_recovered", "recovered_amount", "requested_damage_total",
    "final_damage_total", "damage_segment_count", "normal_segment_count",
    "true_segment_count", "poison_segment_count", "blocked_segment_count",
    "block_canceled_segment_count", "deflection_canceled_segment_count",
    "total_canceled_segment_count",
    "life_loss_canceled_segment_count", "damage_segment_tokens",
    "sequence_before",
    "sequence_after", "normal_advance_count", "extra_advance_count",
    "extra_sequence_advance_count", "extra_sequence_advance_sources",
    "source_records", "completed_slot_instance_id",
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
