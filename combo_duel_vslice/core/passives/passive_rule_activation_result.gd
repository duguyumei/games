class_name PassiveRuleActivationResult
extends RefCounted

var active: bool = true
var reason: String = ""
var blocked_by: Array[String] = []

func configure(values: Dictionary):
    active = bool(values.get("active", true))
    reason = str(values.get("reason", ""))
    blocked_by.clear()
    for value in values.get("blocked_by", []):
        blocked_by.append(str(value))
    return self

func to_dict() -> Dictionary:
    return {
        "active": active,
        "reason": reason,
        "blocked_by": blocked_by.duplicate(),
    }
