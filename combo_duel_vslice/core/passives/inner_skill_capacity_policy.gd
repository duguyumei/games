class_name InnerSkillCapacityPolicy
extends RefCounted

const BASE_INNER_SKILL_CAPACITY := 6

var _runtime_ref: WeakRef

func _init(passive_runtime) -> void:
    _runtime_ref = weakref(passive_runtime)

func resolve(context, proposed_ids: Array = []) -> Dictionary:
    var runtime = _runtime_ref.get_ref()
    if runtime == null:
        return {
            "base_capacity": BASE_INNER_SKILL_CAPACITY,
            "modifiers": [],
            "effective_capacity": BASE_INNER_SKILL_CAPACITY,
            "source_breakdown": [],
            "errors": ["被动规则运行时已释放"],
        }
    var query_context = runtime.coerce_context(context)
    if not proposed_ids.is_empty() or query_context.has_proposed_inner_skill_ids:
        query_context.has_proposed_inner_skill_ids = true
        query_context.proposed_equipped_inner_skill_ids = proposed_ids.duplicate()
    query_context.hook = "inner_skill_capacity_query"
    var queried: Dictionary = runtime.query_modifiers(
        "inner_skill_capacity_query", query_context)
    var modifiers: Array = []
    var total := 0
    for entry in queried.get("results", []):
        var result: Dictionary = entry.get("result", {})
        var amount_value = result.get(
            "additional_capacity", result.get("capacity_modifier", 0))
        if not amount_value is int:
            continue
        var amount := int(amount_value)
        total += amount
        modifiers.append({
            "amount": amount,
            "source_kind": entry["source"].source_kind,
            "content_id": entry["source"].content_id,
            "source_instance_key": entry["source"].source_instance_key,
            "behavior_id": entry["source"].behavior_id,
        })
    return {
        "base_capacity": BASE_INNER_SKILL_CAPACITY,
        "modifiers": modifiers,
        "effective_capacity": maxi(0, BASE_INNER_SKILL_CAPACITY + total),
        "source_breakdown": modifiers.duplicate(true),
        "errors": queried.get("errors", []).duplicate(),
    }
