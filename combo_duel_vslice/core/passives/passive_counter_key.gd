class_name PassiveCounterKey
extends RefCounted

const SOURCE_KINDS := ["inner_skill", "item"]

var source_kind: String = ""
var content_id: String = ""
var state_key: String = ""
var counter_id: String = ""

func configure(values: Dictionary):
    source_kind = str(values.get("source_kind", ""))
    content_id = str(values.get("content_id", ""))
    state_key = str(values.get("state_key", ""))
    counter_id = str(values.get("counter_id", ""))
    return self

func validation_errors() -> Array[String]:
    var errors: Array[String] = []
    var pattern := RegEx.new()
    pattern.compile("^[a-z][a-z0-9_]*$")
    if source_kind not in SOURCE_KINDS:
        errors.append("未知 source_kind：%s" % source_kind)
    for field in ["content_id", "state_key", "counter_id"]:
        var value := str(get(field))
        if pattern.search(value) == null:
            errors.append("%s 必须使用稳定 snake_case：%s" % [field, value])
    return errors

func storage_key() -> String:
    return "%s|%s|%s|%s" % [
        source_kind, content_id, state_key, counter_id]

func to_dict() -> Dictionary:
    return {
        "source_kind": source_kind,
        "content_id": content_id,
        "state_key": state_key,
        "counter_id": counter_id,
    }
