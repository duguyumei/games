class_name BattlePassiveIntQueryRequest
extends "res://core/passives/passive_int_query_request.gd"

var action_token: String = ""
var hand_id: String = ""
var source_kind: String = ""
var card_facts: Array = []

func configure(values: Dictionary):
    super.configure(values)
    actor = values.get("actor", owner)
    target = values.get("target")
    round_number = int(values.get("round_number", 0))
    action_token = str(values.get("action_token", ""))
    hand_id = str(values.get("hand_id", ""))
    source_kind = str(values.get("source_kind", ""))
    card_facts = values.get("card_facts", []).duplicate(true)
    return self

func with_current_value(value: int):
    var result = get_script().new().configure({
        "hook": hook, "owner": owner, "actor": actor, "target": target,
        "subject_kind": subject_kind, "subject_id": subject_id,
        "base_value": base_value, "current_value": value,
        "round_number": round_number, "action_token": action_token,
        "hand_id": hand_id, "source_kind": source_kind,
        "card_facts": card_facts, "metadata": metadata,
    })
    result.has_source_snapshot = has_source_snapshot
    result.source_snapshot = source_snapshot.duplicate(true)
    return result
