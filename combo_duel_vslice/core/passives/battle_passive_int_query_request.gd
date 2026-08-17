class_name BattlePassiveIntQueryRequest
extends "res://core/passives/passive_int_query_request.gd"

var action_token: String = ""
var hand_id: String = ""
var source_kind: String = ""
var card_facts: Array = []
var purpose: String = ""
var evaluation_mode: String = ""
var subject_card_facts: Dictionary = {}
var actual_played_count: int = 0
var exact_hand: Dictionary = {}
var damage_segment_token: String = ""
var action_window_id: String = ""
var source_id: String = ""
var source_instance_key: String = ""
var trigger_mode: String = ""
var cause: String = ""
var damage_type: String = ""
var direct_attack: bool = false
var reflection_damage: bool = false
var synchronized: bool = false
var requested_damage: int = 0
var final_damage: int = 0
var defense_before: int = 0
var defense_lost: int = 0
var defense_after: int = 0
var life_before: int = 0
var proposed_life_loss: int = 0
var lethal: bool = false

func configure(values: Dictionary):
    super.configure(values)
    actor = values.get("actor", owner)
    target = values.get("target")
    round_number = int(values.get("round_number", 0))
    action_token = str(values.get("action_token", ""))
    hand_id = str(values.get("hand_id", ""))
    source_kind = str(values.get("source_kind", ""))
    card_facts = values.get("card_facts", []).duplicate(true)
    purpose = str(values.get("purpose", ""))
    evaluation_mode = str(values.get("evaluation_mode", ""))
    subject_card_facts = values.get("subject_card_facts", {}).duplicate(true)
    actual_played_count = int(values.get("actual_played_count", 0))
    exact_hand = values.get("exact_hand", {}).duplicate(true)
    damage_segment_token = str(values.get("damage_segment_token", ""))
    action_window_id = str(values.get("action_window_id", ""))
    source_id = str(values.get("source_id", ""))
    source_instance_key = str(values.get("source_instance_key", ""))
    trigger_mode = str(values.get("trigger_mode", ""))
    cause = str(values.get("cause", ""))
    damage_type = str(values.get("damage_type", ""))
    direct_attack = bool(values.get("direct_attack", false))
    reflection_damage = bool(values.get("reflection_damage", false))
    synchronized = bool(values.get("synchronized", false))
    requested_damage = int(values.get("requested_damage", 0))
    final_damage = int(values.get("final_damage", 0))
    defense_before = int(values.get("defense_before", 0))
    defense_lost = int(values.get("defense_lost", 0))
    defense_after = int(values.get("defense_after", 0))
    life_before = int(values.get("life_before", 0))
    proposed_life_loss = int(values.get("proposed_life_loss", base_value))
    lethal = bool(values.get("lethal", false))
    return self

func with_current_value(value: int):
    var result = get_script().new().configure({
        "hook": hook, "owner": owner, "actor": actor, "target": target,
        "subject_kind": subject_kind, "subject_id": subject_id,
        "base_value": base_value, "current_value": value,
        "round_number": round_number, "action_token": action_token,
        "hand_id": hand_id, "source_kind": source_kind,
        "card_facts": card_facts, "metadata": metadata,
        "purpose": purpose, "evaluation_mode": evaluation_mode,
        "subject_card_facts": subject_card_facts,
        "actual_played_count": actual_played_count,
        "exact_hand": exact_hand,
        "damage_segment_token": damage_segment_token,
        "action_window_id": action_window_id,
        "source_id": source_id,
        "source_instance_key": source_instance_key,
        "trigger_mode": trigger_mode,
        "cause": cause,
        "damage_type": damage_type,
        "direct_attack": direct_attack,
        "reflection_damage": reflection_damage,
        "synchronized": synchronized,
        "requested_damage": requested_damage,
        "final_damage": final_damage,
        "defense_before": defense_before,
        "defense_lost": defense_lost,
        "defense_after": defense_after,
        "life_before": life_before,
        "proposed_life_loss": proposed_life_loss,
        "lethal": lethal,
    })
    result.has_source_snapshot = has_source_snapshot
    result.source_snapshot = source_snapshot.duplicate(true)
    return result

func to_dict() -> Dictionary:
    var result := super.to_dict()
    result.merge({
        "action_token": action_token,
        "hand_id": hand_id,
        "source_kind": source_kind,
        "damage_segment_token": damage_segment_token,
        "action_window_id": action_window_id,
        "source_id": source_id,
        "source_instance_key": source_instance_key,
        "trigger_mode": trigger_mode,
        "cause": cause,
        "damage_type": damage_type,
        "direct_attack": direct_attack,
        "reflection_damage": reflection_damage,
        "synchronized": synchronized,
        "requested_damage": requested_damage,
        "final_damage": final_damage,
        "defense_before": defense_before,
        "defense_lost": defense_lost,
        "defense_after": defense_after,
        "life_before": life_before,
        "proposed_life_loss": proposed_life_loss,
        "lethal": lethal,
    }, true)
    return result
