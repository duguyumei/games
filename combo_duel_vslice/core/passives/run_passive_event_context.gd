class_name RunPassiveEventContext
extends "res://core/passives/passive_rule_context.gd"

var run_seed: int = 0
var act: int = 0
var node_id: String = ""
var node_type: String = ""
var content_id: String = ""
var content_kind: String = ""
var shop_index: int = 0
var outcome: String = ""
var transaction_token: String = ""

func configure(values: Dictionary):
    super.configure(values)
    run_seed = int(values.get("run_seed", 0))
    act = int(values.get("act", 0))
    node_id = str(values.get("node_id", ""))
    node_type = str(values.get("node_type", ""))
    content_id = str(values.get("content_id", ""))
    content_kind = str(values.get("content_kind", ""))
    shop_index = int(values.get("shop_index", 0))
    outcome = str(values.get("outcome", ""))
    transaction_token = str(values.get("transaction_token", ""))
    return self

func for_invocation(current_invocation):
    var values := _event_values()
    values["source"] = current_invocation.source
    values["invocation"] = current_invocation
    return get_script().new().configure(values)

func for_plan_target(target_source):
    var values := _event_values()
    values["hook"] = "passive_invocation_plan_query"
    values["plan_target_source"] = target_source
    var result = get_script().new().configure(values)
    result.has_proposed_inner_skill_ids = has_proposed_inner_skill_ids
    result.proposed_equipped_inner_skill_ids = proposed_equipped_inner_skill_ids.duplicate()
    result.has_source_snapshot = has_source_snapshot
    result.source_snapshot = source_snapshot.duplicate(true)
    return result

func to_dict() -> Dictionary:
    return {
        "hook": hook,
        "run_seed": run_seed,
        "act": act,
        "node_id": node_id,
        "node_type": node_type,
        "content_id": content_id,
        "content_kind": content_kind,
        "shop_index": shop_index,
        "outcome": outcome,
        "transaction_token": transaction_token,
        "payload": payload.duplicate(true),
    }

func _event_values() -> Dictionary:
    var values := {
        "actor": actor,
        "target": target,
        "owner": owner,
        "hook": hook,
        "round_number": round_number,
        "payload": payload,
        "run_seed": run_seed,
        "act": act,
        "node_id": node_id,
        "node_type": node_type,
        "content_id": content_id,
        "content_kind": content_kind,
        "shop_index": shop_index,
        "outcome": outcome,
        "transaction_token": transaction_token,
    }
    if has_source_snapshot:
        values["source_snapshot"] = source_snapshot
    return values
