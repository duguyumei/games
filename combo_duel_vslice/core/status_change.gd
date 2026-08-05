class_name StatusChange
extends RefCounted

var serial: int = -1
var change_type: String = ""
var target_kind: String = ""
var target_id: String = ""
var status_id: String = ""
var before_value = null
var after_value = null
var source: String = ""
var metadata: Dictionary = {}

func configure(values: Dictionary):
    serial = int(values.get("serial", -1))
    change_type = str(values.get("change_type", ""))
    target_kind = str(values.get("target_kind", ""))
    target_id = str(values.get("target_id", ""))
    status_id = str(values.get("status_id", ""))
    before_value = values.get("before_value")
    after_value = values.get("after_value")
    source = str(values.get("source", ""))
    metadata = values.get("metadata", {}).duplicate(true)
    return self

func snapshot() -> Dictionary:
    return {
        "serial": serial,
        "change_type": change_type,
        "target_kind": target_kind,
        "target_id": target_id,
        "status_id": status_id,
        "before_value": before_value,
        "after_value": after_value,
        "source": source,
        "metadata": metadata.duplicate(true),
    }
