class_name BattlePassiveCommittedEventContext
extends "res://core/passives/passive_rule_context.gd"

var event_token: String = ""
var event_kind: String = ""
var owner_id: String = ""
var action_token: String = ""
var event_serial: int = -1
var card = null
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
var reason: String = ""
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

func configure(values: Dictionary):
    super.configure(values)
    event_token = str(values.get("event_token", ""))
    event_kind = str(values.get("event_kind", hook))
    owner_id = str(values.get("owner_id", ""))
    action_token = str(values.get("action_token", ""))
    event_serial = int(values.get("event_serial", -1))
    card = values.get("card")
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
    reason = str(values.get("reason", ""))
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
        "reason": reason,
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
        "payload": payload,
        "source": current_invocation.source,
        "invocation": current_invocation,
        "source_snapshot": source_snapshot,
        "battle_effect_ports": battle_effect_ports,
        "battle_effect_scope": battle_effect_scope,
    })
