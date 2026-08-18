class_name BattlePassiveCommittedEventContext
extends "res://core/passives/passive_rule_context.gd"

var event_token: String = ""
var event_kind: String = ""
var owner_id: String = ""
var action_token: String = ""
var event_serial: int = -1
var card = null
var holder = null
var card_instance_id: String = ""
var source_kind: String = ""
var source_id: String = ""
var source_name: String = ""
var source_instance_key: String = ""
var trigger_mode: String = ""
var requested_amount: int = 0
var final_amount: int = 0
var metadata: Dictionary = {}
var technique_triggered: bool = false
var action_succeeded: bool = false
var draw_reason: String = ""
var from_zone: String = ""
var to_zone: String = ""
var reason: String = ""
var placement: String = "top"
var transition_kind: String = "move"
var from_holder = null
var to_holder = null
var from_holder_id: String = ""
var to_holder_id: String = ""
var original_owner_id: String = ""
var from_zone_count_before: int = 0
var from_zone_count_after: int = 0
var to_zone_count_before: int = 0
var to_zone_count_after: int = 0
var hand_count_before: int = 0
var hand_count_after: int = 0
var from_hand_count_before: int = 0
var from_hand_count_after: int = 0
var to_hand_count_before: int = 0
var to_hand_count_after: int = 0
var movement_batch_token: String = ""
var movement_batch_index: int = -1
var explicit_discard: bool = false
var normal_play: bool = false
var defense_lost: int = 0
var life_lost: int = 0
var true_damage: bool = false
var damage_type: String = "normal"
var synchronized: bool = false
var effective_amount: int = 0
var defense_before: int = 0
var defense_after: int = 0
var frozen_amount: int = 0
var actual_life_loss: int = 0
var requested_damage: int = 0
var final_damage: int = 0
var damage_segment_token: String = ""
var cause: String = ""
var direct_attack: bool = false
var reflection_damage: bool = false
var attack_amount: int = 0
var action_window_id: String = ""
var execution_token: String = ""
var source_token: String = ""
var cancel_kind: String = "none"
var threshold: int = 0
var consumed: bool = false
var succeeded: bool = false
var pierced: bool = false
var checked_source_tokens: Array = []
var cancel_source_kind: String = ""
var cancel_source_id: String = ""
var cancel_source_name: String = ""
var cancel_source_instance_key: String = ""
var cancel_trigger_mode: String = ""
var life_before: int = 0
var life_after: int = 0
var life_loss_before_intervention: int = 0
var life_loss_prevented: int = 0
var life_loss_canceled: bool = false
var life_loss_intervention_breakdown: Array = []
var life_loss_source_fingerprint: String = ""
var life_loss_query_fingerprint: String = ""
var source_card_instance_id: String = ""
var pre_move_snapshot: Dictionary = {}
var operation_token: String = ""
var holder_id: String = ""
var change_domain: String = ""
var operation: String = ""
var before_state: Dictionary = {}
var after_state: Dictionary = {}
var changes: Array = []
var added_changes: Array = []
var removed_changes: Array = []
var updated_changes: Array = []
var added_count: int = 0
var removed_count: int = 0
var updated_count: int = 0
var actual_change_count: int = 0
var category: String = ""
var anomaly_id: String = ""
var subslot: String = ""
var reshape_id: String = ""
var transfer_batch_token: String = ""
var transfer_peer_card_id: String = ""
var transfer_direction: String = ""
var card_base_qi: int = 0
var current_base_qi: int = 0
var technique_execution_token: String = ""
var root_action_token: String = ""
var invocation_token: String = ""
var caller_technique_id: String = ""
var is_echo: bool = false
var manual_effect_suppressed: bool = false
var sequence_advance_requested: bool = false
var same_qi_gain_enabled: bool = false
var momentum_enabled: bool = false
var actor_defense_gained: int = 0
var actor_defense_lost: int = 0
var target_defense_lost: int = 0
var actor_life_lost: int = 0
var target_life_lost: int = 0
var target_total_reduction: int = 0
var life_recovered: int = 0
var requested_damage_total: int = 0
var final_damage_total: int = 0
var damage_segment_count: int = 0
var normal_segment_count: int = 0
var true_segment_count: int = 0
var poison_segment_count: int = 0
var blocked_segment_count: int = 0
var block_canceled_segment_count: int = 0
var deflection_canceled_segment_count: int = 0
var total_canceled_segment_count: int = 0
var life_loss_canceled_segment_count: int = 0
var damage_segment_tokens: Array = []
var sequence_before: Array = []

func configure(values: Dictionary):
    super.configure(values)
    event_token = str(values.get("event_token", ""))
    event_kind = str(values.get("event_kind", hook))
    owner_id = str(values.get("owner_id", ""))
    action_token = str(values.get("action_token", ""))
    event_serial = int(values.get("event_serial", -1))
    card = values.get("card")
    holder = values.get("holder")
    card_instance_id = str(values.get(
        "card_instance_id", str(card.id) if card != null else ""))
    source_kind = str(values.get("source_kind", ""))
    source_id = str(values.get("source_id", ""))
    source_name = str(values.get("source_name", ""))
    source_instance_key = str(values.get("source_instance_key", ""))
    trigger_mode = str(values.get("trigger_mode", ""))
    requested_amount = int(values.get("requested_amount", 0))
    final_amount = int(values.get("final_amount", 0))
    metadata = values.get("metadata", {}).duplicate(false)
    technique_triggered = bool(values.get("technique_triggered", false))
    action_succeeded = bool(values.get("action_succeeded", false))
    draw_reason = str(values.get("draw_reason", ""))
    from_zone = str(values.get("from_zone", ""))
    to_zone = str(values.get("to_zone", ""))
    reason = str(values.get("reason", ""))
    placement = str(values.get("placement", "top"))
    transition_kind = str(values.get("transition_kind", "move"))
    from_holder = values.get("from_holder")
    to_holder = values.get("to_holder")
    from_holder_id = str(values.get("from_holder_id", ""))
    to_holder_id = str(values.get("to_holder_id", ""))
    original_owner_id = str(values.get("original_owner_id", ""))
    from_zone_count_before = int(values.get("from_zone_count_before", 0))
    from_zone_count_after = int(values.get("from_zone_count_after", 0))
    to_zone_count_before = int(values.get("to_zone_count_before", 0))
    to_zone_count_after = int(values.get("to_zone_count_after", 0))
    hand_count_before = int(values.get("hand_count_before", 0))
    hand_count_after = int(values.get("hand_count_after", 0))
    from_hand_count_before = int(values.get("from_hand_count_before", 0))
    from_hand_count_after = int(values.get("from_hand_count_after", 0))
    to_hand_count_before = int(values.get("to_hand_count_before", 0))
    to_hand_count_after = int(values.get("to_hand_count_after", 0))
    movement_batch_token = str(values.get("movement_batch_token", ""))
    movement_batch_index = int(values.get("movement_batch_index", -1))
    explicit_discard = bool(values.get("explicit_discard", false))
    normal_play = bool(values.get("normal_play", false))
    defense_lost = int(values.get("defense_lost", 0))
    life_lost = int(values.get("life_lost", 0))
    true_damage = bool(values.get("true_damage", false))
    damage_type = str(values.get("damage_type", "true" if true_damage else "normal"))
    synchronized = bool(values.get("synchronized", false))
    effective_amount = int(values.get("effective_amount", 0))
    defense_before = int(values.get("defense_before", 0))
    defense_after = int(values.get("defense_after", 0))
    frozen_amount = int(values.get("frozen_amount", 0))
    actual_life_loss = int(values.get("actual_life_loss", life_lost))
    requested_damage = int(values.get("requested_damage", requested_amount))
    final_damage = int(values.get("final_damage", final_amount))
    damage_segment_token = str(values.get("damage_segment_token", ""))
    cause = str(values.get("cause", ""))
    direct_attack = bool(values.get("direct_attack", false))
    reflection_damage = bool(values.get("reflection_damage", false))
    attack_amount = int(values.get("attack_amount", values.get("amount", 0)))
    action_window_id = str(values.get("action_window_id", ""))
    execution_token = str(values.get("execution_token", ""))
    source_token = str(values.get("source_token", ""))
    cancel_kind = str(values.get("cancel_kind", "none"))
    threshold = int(values.get("threshold", 0))
    consumed = bool(values.get("consumed", false))
    succeeded = bool(values.get("succeeded", false))
    pierced = bool(values.get("pierced", false))
    checked_source_tokens = values.get("checked_source_tokens", []).duplicate()
    cancel_source_kind = str(values.get("cancel_source_kind", ""))
    cancel_source_id = str(values.get("cancel_source_id", ""))
    cancel_source_name = str(values.get("cancel_source_name", ""))
    cancel_source_instance_key = str(values.get(
        "cancel_source_instance_key", ""))
    cancel_trigger_mode = str(values.get("cancel_trigger_mode", ""))
    life_before = int(values.get("life_before", 0))
    life_after = int(values.get("life_after", 0))
    life_loss_before_intervention = int(values.get(
        "life_loss_before_intervention", life_lost))
    life_loss_prevented = int(values.get("life_loss_prevented", 0))
    life_loss_canceled = bool(values.get("life_loss_canceled", false))
    life_loss_intervention_breakdown = values.get(
        "life_loss_intervention_breakdown", []).duplicate(true)
    life_loss_source_fingerprint = str(values.get(
        "life_loss_source_fingerprint", ""))
    life_loss_query_fingerprint = str(values.get(
        "life_loss_query_fingerprint", ""))
    source_card_instance_id = str(values.get("source_card_instance_id", ""))
    pre_move_snapshot = values.get("pre_move_snapshot", {}).duplicate(true)
    operation_token = str(values.get("operation_token", ""))
    holder_id = str(values.get("holder_id", ""))
    change_domain = str(values.get("change_domain", ""))
    operation = str(values.get("operation", ""))
    before_state = values.get("before_state", {}).duplicate(true)
    after_state = values.get("after_state", {}).duplicate(true)
    changes = values.get("changes", []).duplicate(true)
    added_changes = values.get("added_changes", []).duplicate(true)
    removed_changes = values.get("removed_changes", []).duplicate(true)
    updated_changes = values.get("updated_changes", []).duplicate(true)
    added_count = int(values.get("added_count", 0))
    removed_count = int(values.get("removed_count", 0))
    updated_count = int(values.get("updated_count", 0))
    actual_change_count = int(values.get("actual_change_count", 0))
    category = str(values.get("category", ""))
    anomaly_id = str(values.get("anomaly_id", ""))
    subslot = str(values.get("subslot", ""))
    reshape_id = str(values.get("reshape_id", ""))
    transfer_batch_token = str(values.get("transfer_batch_token", ""))
    transfer_peer_card_id = str(values.get("transfer_peer_card_id", ""))
    transfer_direction = str(values.get("transfer_direction", ""))
    card_base_qi = int(values.get("card_base_qi", 0))
    current_base_qi = int(values.get("current_base_qi", 0))
    technique_execution_token = str(values.get(
        "technique_execution_token", ""))
    root_action_token = str(values.get("root_action_token", action_token))
    invocation_token = str(values.get("invocation_token", ""))
    caller_technique_id = str(values.get("caller_technique_id", ""))
    is_echo = bool(values.get("is_echo", false))
    manual_effect_suppressed = bool(values.get(
        "manual_effect_suppressed", false))
    sequence_advance_requested = bool(values.get(
        "sequence_advance_requested", false))
    same_qi_gain_enabled = bool(values.get("same_qi_gain_enabled", false))
    momentum_enabled = bool(values.get("momentum_enabled", false))
    actor_defense_gained = int(values.get("actor_defense_gained", 0))
    actor_defense_lost = int(values.get("actor_defense_lost", 0))
    target_defense_lost = int(values.get("target_defense_lost", 0))
    actor_life_lost = int(values.get("actor_life_lost", 0))
    target_life_lost = int(values.get("target_life_lost", 0))
    target_total_reduction = int(values.get("target_total_reduction", 0))
    life_recovered = int(values.get("life_recovered", 0))
    requested_damage_total = int(values.get("requested_damage_total", 0))
    final_damage_total = int(values.get("final_damage_total", 0))
    damage_segment_count = int(values.get("damage_segment_count", 0))
    normal_segment_count = int(values.get("normal_segment_count", 0))
    true_segment_count = int(values.get("true_segment_count", 0))
    poison_segment_count = int(values.get("poison_segment_count", 0))
    blocked_segment_count = int(values.get("blocked_segment_count", 0))
    block_canceled_segment_count = int(values.get(
        "block_canceled_segment_count", 0))
    deflection_canceled_segment_count = int(values.get(
        "deflection_canceled_segment_count", 0))
    total_canceled_segment_count = int(values.get(
        "total_canceled_segment_count", 0))
    life_loss_canceled_segment_count = int(values.get(
        "life_loss_canceled_segment_count", 0))
    damage_segment_tokens = values.get(
        "damage_segment_tokens", []).duplicate()
    sequence_before = values.get("sequence_before", []).duplicate(true)
    return self

func for_invocation(current_invocation):
    return get_script().new().configure({
        "actor": actor,
        "target": target,
        "owner": owner,
        "owner_id": owner_id,
        "hook": hook,
        "round_number": round_number,
        "event_token": event_token,
        "event_kind": event_kind,
        "action_token": action_token,
        "event_serial": event_serial,
        "card": card,
        "holder": holder,
        "card_instance_id": card_instance_id,
        "source_kind": source_kind,
        "source_id": source_id,
        "source_name": source_name,
        "source_instance_key": source_instance_key,
        "trigger_mode": trigger_mode,
        "requested_amount": requested_amount,
        "final_amount": final_amount,
        "metadata": metadata,
        "technique_triggered": technique_triggered,
        "action_succeeded": action_succeeded,
        "draw_reason": draw_reason,
        "from_zone": from_zone,
        "to_zone": to_zone,
        "reason": reason,
        "placement": placement,
        "transition_kind": transition_kind,
        "from_holder": from_holder,
        "to_holder": to_holder,
        "from_holder_id": from_holder_id,
        "to_holder_id": to_holder_id,
        "original_owner_id": original_owner_id,
        "from_zone_count_before": from_zone_count_before,
        "from_zone_count_after": from_zone_count_after,
        "to_zone_count_before": to_zone_count_before,
        "to_zone_count_after": to_zone_count_after,
        "hand_count_before": hand_count_before,
        "hand_count_after": hand_count_after,
        "from_hand_count_before": from_hand_count_before,
        "from_hand_count_after": from_hand_count_after,
        "to_hand_count_before": to_hand_count_before,
        "to_hand_count_after": to_hand_count_after,
        "movement_batch_token": movement_batch_token,
        "movement_batch_index": movement_batch_index,
        "explicit_discard": explicit_discard,
        "normal_play": normal_play,
        "defense_lost": defense_lost,
        "life_lost": life_lost,
        "true_damage": true_damage,
        "damage_type": damage_type,
        "synchronized": synchronized,
        "effective_amount": effective_amount,
        "defense_before": defense_before,
        "defense_after": defense_after,
        "frozen_amount": frozen_amount,
        "actual_life_loss": actual_life_loss,
        "requested_damage": requested_damage,
        "final_damage": final_damage,
        "damage_segment_token": damage_segment_token,
        "cause": cause,
        "direct_attack": direct_attack,
        "reflection_damage": reflection_damage,
        "attack_amount": attack_amount,
        "action_window_id": action_window_id,
        "execution_token": execution_token,
        "source_token": source_token,
        "cancel_kind": cancel_kind,
        "threshold": threshold,
        "consumed": consumed,
        "succeeded": succeeded,
        "pierced": pierced,
        "checked_source_tokens": checked_source_tokens,
        "cancel_source_kind": cancel_source_kind,
        "cancel_source_id": cancel_source_id,
        "cancel_source_name": cancel_source_name,
        "cancel_source_instance_key": cancel_source_instance_key,
        "cancel_trigger_mode": cancel_trigger_mode,
        "life_before": life_before,
        "life_after": life_after,
        "life_loss_before_intervention": life_loss_before_intervention,
        "life_loss_prevented": life_loss_prevented,
        "life_loss_canceled": life_loss_canceled,
        "life_loss_intervention_breakdown": life_loss_intervention_breakdown,
        "life_loss_source_fingerprint": life_loss_source_fingerprint,
        "life_loss_query_fingerprint": life_loss_query_fingerprint,
        "source_card_instance_id": source_card_instance_id,
        "pre_move_snapshot": pre_move_snapshot,
        "operation_token": operation_token,
        "holder_id": holder_id,
        "change_domain": change_domain,
        "operation": operation,
        "before_state": before_state,
        "after_state": after_state,
        "changes": changes,
        "added_changes": added_changes,
        "removed_changes": removed_changes,
        "updated_changes": updated_changes,
        "added_count": added_count,
        "removed_count": removed_count,
        "updated_count": updated_count,
        "actual_change_count": actual_change_count,
        "category": category,
        "anomaly_id": anomaly_id,
        "subslot": subslot,
        "reshape_id": reshape_id,
        "transfer_batch_token": transfer_batch_token,
        "transfer_peer_card_id": transfer_peer_card_id,
        "transfer_direction": transfer_direction,
        "card_base_qi": card_base_qi,
        "current_base_qi": current_base_qi,
        "technique_execution_token": technique_execution_token,
        "root_action_token": root_action_token,
        "invocation_token": invocation_token,
        "caller_technique_id": caller_technique_id,
        "is_echo": is_echo,
        "manual_effect_suppressed": manual_effect_suppressed,
        "sequence_advance_requested": sequence_advance_requested,
        "same_qi_gain_enabled": same_qi_gain_enabled,
        "momentum_enabled": momentum_enabled,
        "actor_defense_gained": actor_defense_gained,
        "actor_defense_lost": actor_defense_lost,
        "target_defense_lost": target_defense_lost,
        "actor_life_lost": actor_life_lost,
        "target_life_lost": target_life_lost,
        "target_total_reduction": target_total_reduction,
        "life_recovered": life_recovered,
        "requested_damage_total": requested_damage_total,
        "final_damage_total": final_damage_total,
        "damage_segment_count": damage_segment_count,
        "normal_segment_count": normal_segment_count,
        "true_segment_count": true_segment_count,
        "poison_segment_count": poison_segment_count,
        "blocked_segment_count": blocked_segment_count,
        "block_canceled_segment_count": block_canceled_segment_count,
        "deflection_canceled_segment_count": deflection_canceled_segment_count,
        "total_canceled_segment_count": total_canceled_segment_count,
        "life_loss_canceled_segment_count": life_loss_canceled_segment_count,
        "damage_segment_tokens": damage_segment_tokens,
        "sequence_before": sequence_before,
        "payload": payload,
        "source": current_invocation.source,
        "invocation": current_invocation,
        "source_snapshot": source_snapshot,
        "battle_effect_ports": battle_effect_ports,
        "battle_effect_scope": battle_effect_scope,
    })

func public_effect_values() -> Dictionary:
    var result := payload.duplicate(true)
    result.merge({
        "event_token": event_token,
        "event_serial": event_serial,
        "action_token": action_token,
        "round_number": round_number,
        "card": card,
        "holder": holder,
        "card_instance_id": card_instance_id,
        "source_kind": source_kind,
        "source_id": source_id,
        "source_name": source_name,
        "source_instance_key": source_instance_key,
        "trigger_mode": trigger_mode,
        "requested_amount": requested_amount,
        "final_amount": final_amount,
        "effective_amount": effective_amount,
        "defense_lost": defense_lost,
        "life_lost": life_lost,
        "actual_life_loss": actual_life_loss,
        "requested_damage": requested_damage,
        "final_damage": final_damage,
        "damage_segment_token": damage_segment_token,
        "cause": cause,
        "direct_attack": direct_attack,
        "reflection_damage": reflection_damage,
        "attack_amount": attack_amount,
        "action_window_id": action_window_id,
        "execution_token": execution_token,
        "source_token": source_token,
        "cancel_kind": cancel_kind,
        "threshold": threshold,
        "consumed": consumed,
        "succeeded": succeeded,
        "pierced": pierced,
        "checked_source_tokens": checked_source_tokens.duplicate(),
        "cancel_source_kind": cancel_source_kind,
        "cancel_source_id": cancel_source_id,
        "cancel_source_name": cancel_source_name,
        "cancel_source_instance_key": cancel_source_instance_key,
        "cancel_trigger_mode": cancel_trigger_mode,
        "life_before": life_before,
        "life_after": life_after,
        "life_loss_before_intervention": life_loss_before_intervention,
        "life_loss_prevented": life_loss_prevented,
        "life_loss_canceled": life_loss_canceled,
        "life_loss_intervention_breakdown": (
            life_loss_intervention_breakdown.duplicate(true)),
        "life_loss_source_fingerprint": life_loss_source_fingerprint,
        "life_loss_query_fingerprint": life_loss_query_fingerprint,
        "damage_type": damage_type,
        "defense_before": defense_before,
        "defense_after": defense_after,
        "frozen_amount": frozen_amount,
        "draw_reason": draw_reason,
        "from_zone": from_zone,
        "to_zone": to_zone,
        "reason": reason,
        "placement": placement,
        "transition_kind": transition_kind,
        "from_holder_id": from_holder_id,
        "to_holder_id": to_holder_id,
        "original_owner_id": original_owner_id,
        "from_zone_count_before": from_zone_count_before,
        "from_zone_count_after": from_zone_count_after,
        "to_zone_count_before": to_zone_count_before,
        "to_zone_count_after": to_zone_count_after,
        "hand_count_before": hand_count_before,
        "hand_count_after": hand_count_after,
        "from_hand_count_before": from_hand_count_before,
        "from_hand_count_after": from_hand_count_after,
        "to_hand_count_before": to_hand_count_before,
        "to_hand_count_after": to_hand_count_after,
        "movement_batch_token": movement_batch_token,
        "movement_batch_index": movement_batch_index,
        "explicit_discard": explicit_discard,
        "normal_play": normal_play,
        "technique_triggered": technique_triggered,
        "action_succeeded": action_succeeded,
        "source_card_instance_id": source_card_instance_id,
        "pre_move_snapshot": pre_move_snapshot.duplicate(true),
        "operation_token": operation_token,
        "holder_id": holder_id,
        "change_domain": change_domain,
        "operation": operation,
        "before_state": before_state.duplicate(true),
        "after_state": after_state.duplicate(true),
        "changes": changes.duplicate(true),
        "added_changes": added_changes.duplicate(true),
        "removed_changes": removed_changes.duplicate(true),
        "updated_changes": updated_changes.duplicate(true),
        "added_count": added_count,
        "removed_count": removed_count,
        "updated_count": updated_count,
        "actual_change_count": actual_change_count,
        "category": category,
        "anomaly_id": anomaly_id,
        "subslot": subslot,
        "reshape_id": reshape_id,
        "transfer_batch_token": transfer_batch_token,
        "transfer_peer_card_id": transfer_peer_card_id,
        "transfer_direction": transfer_direction,
        "card_base_qi": card_base_qi,
        "current_base_qi": current_base_qi,
        "technique_execution_token": technique_execution_token,
        "root_action_token": root_action_token,
        "invocation_token": invocation_token,
        "caller_technique_id": caller_technique_id,
        "is_echo": is_echo,
        "manual_effect_suppressed": manual_effect_suppressed,
        "sequence_advance_requested": sequence_advance_requested,
        "same_qi_gain_enabled": same_qi_gain_enabled,
        "momentum_enabled": momentum_enabled,
        "actor_defense_gained": actor_defense_gained,
        "actor_defense_lost": actor_defense_lost,
        "target_defense_lost": target_defense_lost,
        "actor_life_lost": actor_life_lost,
        "target_life_lost": target_life_lost,
        "target_total_reduction": target_total_reduction,
        "life_recovered": life_recovered,
        "requested_damage_total": requested_damage_total,
        "final_damage_total": final_damage_total,
        "damage_segment_count": damage_segment_count,
        "normal_segment_count": normal_segment_count,
        "true_segment_count": true_segment_count,
        "poison_segment_count": poison_segment_count,
        "blocked_segment_count": blocked_segment_count,
        "block_canceled_segment_count": block_canceled_segment_count,
        "deflection_canceled_segment_count": deflection_canceled_segment_count,
        "total_canceled_segment_count": total_canceled_segment_count,
        "life_loss_canceled_segment_count": life_loss_canceled_segment_count,
        "damage_segment_tokens": damage_segment_tokens.duplicate(),
        "sequence_before": sequence_before.duplicate(true),
        "metadata": metadata.duplicate(true),
    }, true)
    return result
