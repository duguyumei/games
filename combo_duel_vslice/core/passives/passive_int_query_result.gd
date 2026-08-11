class_name PassiveIntQueryResult
extends RefCounted

var success: bool = false
var hook: String = ""
var subject_kind: String = ""
var subject_id: String = ""
var base_value: int = 0
var effective_value: int = 0
var modifier_breakdown: Array = []
var source_fingerprint: String = ""
var errors: Array[String] = []

func configure(values: Dictionary):
    success = bool(values.get("success", false))
    hook = str(values.get("hook", ""))
    subject_kind = str(values.get("subject_kind", ""))
    subject_id = str(values.get("subject_id", ""))
    base_value = int(values.get("base_value", 0))
    effective_value = int(values.get("effective_value", base_value))
    modifier_breakdown = values.get("modifier_breakdown", []).duplicate(true)
    source_fingerprint = str(values.get("source_fingerprint", ""))
    errors.clear()
    for value in values.get("errors", []):
        errors.append(str(value))
    return self

func to_dict() -> Dictionary:
    return {
        "success": success,
        "hook": hook,
        "subject_kind": subject_kind,
        "subject_id": subject_id,
        "base_value": base_value,
        "effective_value": effective_value,
        "modifier_breakdown": modifier_breakdown.duplicate(true),
        "source_fingerprint": source_fingerprint,
        "errors": errors.duplicate(),
    }
