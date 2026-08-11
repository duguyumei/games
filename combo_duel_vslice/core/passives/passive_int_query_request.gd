class_name PassiveIntQueryRequest
extends RefCounted

var hook: String = ""
var owner = null
var subject_kind: String = ""
var subject_id: String = ""
var base_value: int = 0
var current_value: int = 0
var metadata: Dictionary = {}
var source_snapshot: Array = []
var has_source_snapshot: bool = false

func configure(values: Dictionary):
    hook = str(values.get("hook", ""))
    owner = values.get("owner")
    subject_kind = str(values.get("subject_kind", ""))
    subject_id = str(values.get("subject_id", ""))
    base_value = int(values.get("base_value", 0))
    current_value = int(values.get("current_value", base_value))
    metadata = values.get("metadata", {}).duplicate(true)
    has_source_snapshot = values.has("source_snapshot")
    source_snapshot = values.get("source_snapshot", []).duplicate(true)
    return self

func with_current_value(value: int):
    var result = get_script().new().configure({
        "hook": hook,
        "owner": owner,
        "subject_kind": subject_kind,
        "subject_id": subject_id,
        "base_value": base_value,
        "current_value": value,
        "metadata": metadata,
    })
    result.has_source_snapshot = has_source_snapshot
    result.source_snapshot = source_snapshot.duplicate(true)
    return result

func to_dict() -> Dictionary:
    return {
        "hook": hook,
        "subject_kind": subject_kind,
        "subject_id": subject_id,
        "base_value": base_value,
        "current_value": current_value,
        "metadata": metadata.duplicate(true),
    }
