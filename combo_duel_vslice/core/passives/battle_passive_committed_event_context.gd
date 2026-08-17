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
        "metadata": metadata.duplicate(true),
    }, true)
    return result
