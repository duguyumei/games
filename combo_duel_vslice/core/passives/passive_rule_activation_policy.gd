class_name PassiveRuleActivationPolicy
extends RefCounted

const ResultScript = preload(
    "res://core/passives/passive_rule_activation_result.gd")

var suppression_service

func _init(service = null) -> void:
    suppression_service = service

func is_source_active(source, hook: String, context):
    if suppression_service == null:
        return ResultScript.new()
    var blockers: Array = suppression_service.blockers_for(
        source, hook, context.round_number if context != null else 0)
    if blockers.is_empty():
        return ResultScript.new()
    var ids: Array[String] = []
    var reasons: Array[String] = []
    for blocker in blockers:
        ids.append(blocker.suppression_id)
        if blocker.reason != "" and not reasons.has(blocker.reason):
            reasons.append(blocker.reason)
    return ResultScript.new().configure({
        "active": false,
        "reason": "；".join(reasons),
        "blocked_by": ids,
    })
