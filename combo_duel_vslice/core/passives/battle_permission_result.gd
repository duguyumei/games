class_name BattlePermissionResult
extends RefCounted

var allowed: bool = true
var reason: String = ""
var source_breakdown: Array = []
var errors: Array[String] = []

func configure(values: Dictionary = {}):
    allowed = bool(values.get("allowed", true))
    reason = str(values.get("reason", ""))
    source_breakdown = values.get("source_breakdown", []).duplicate(true)
    errors.clear()
    for value in values.get("errors", []):
        errors.append(str(value))
    return self

func to_dict() -> Dictionary:
    return {
        "allowed": allowed,
        "reason": reason,
        "source_breakdown": source_breakdown.duplicate(true),
        "errors": errors.duplicate(),
    }

