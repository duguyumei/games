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
var operation_token: String = ""
var operation_id: String = ""
var event_token: String = ""
var fact_scope: String = ""
var persistence: String = ""
var holder_id: String = ""
var card_instance_id: String = ""
var definition_id: String = ""
var reason: String = ""
var fact_source: Dictionary = {}
var card_snapshot: Dictionary = {}
var before: Dictionary = {}
var after: Dictionary = {}
var changes: Array = []
var actual_change_count: int = 0

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
    operation_token = str(values.get("operation_token", ""))
    operation_id = str(values.get("operation_id", ""))
    event_token = str(values.get("event_token", ""))
    fact_scope = str(values.get("scope", values.get("fact_scope", "")))
    persistence = str(values.get("persistence", ""))
    holder_id = str(values.get("holder_id", values.get("holder", "")))
    card_instance_id = str(values.get(
        "card_instance_id", values.get("instance_id", "")))
    definition_id = str(values.get("definition_id", ""))
    reason = str(values.get("reason", ""))
    fact_source = values.get(
        "fact_source", values.get("source_description", {})).duplicate(true)
    card_snapshot = values.get(
        "card_snapshot", values.get("persistent_card_snapshot", {})).duplicate(true)
    before = values.get("before", {}).duplicate(true)
    after = values.get("after", {}).duplicate(true)
    changes = values.get("changes", []).duplicate(true)
    actual_change_count = int(values.get(
        "actual_change_count", changes.size()))
    return self

func for_invocation(current_invocation):
    var values := _event_values()
    values["source"] = current_invocation.source
    values["invocation"] = current_invocation
    var result = get_script().new().configure(values)
    # RunPassiveEventService 在事件开始时只建立一次基础端口；真正执行某个
    # Invocation 时收窄成带来源身份的端口，避免 Handler 自行拼 source key。
    var base_ports = result.payload.get("effect_ports")
    if base_ports != null and base_ports.has_method("for_invocation"):
        result.payload = result.payload.duplicate(false)
        result.payload["effect_ports"] = base_ports.for_invocation(
            current_invocation)
    return result

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
        "operation_token": operation_token,
        "operation_id": operation_id,
        "event_token": event_token,
        "scope": fact_scope,
        "persistence": persistence,
        "holder_id": holder_id,
        "card_instance_id": card_instance_id,
        "definition_id": definition_id,
        "reason": reason,
        "fact_source": fact_source.duplicate(true),
        "card_snapshot": card_snapshot.duplicate(true),
        "before": before.duplicate(true),
        "after": after.duplicate(true),
        "changes": changes.duplicate(true),
        "actual_change_count": actual_change_count,
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
        "operation_token": operation_token,
        "operation_id": operation_id,
        "event_token": event_token,
        "scope": fact_scope,
        "persistence": persistence,
        "holder_id": holder_id,
        "card_instance_id": card_instance_id,
        "definition_id": definition_id,
        "reason": reason,
        "fact_source": fact_source,
        "card_snapshot": card_snapshot,
        "before": before,
        "after": after,
        "changes": changes,
        "actual_change_count": actual_change_count,
    }
    if has_source_snapshot:
        values["source_snapshot"] = source_snapshot
    return values
