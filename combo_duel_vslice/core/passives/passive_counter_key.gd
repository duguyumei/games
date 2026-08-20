class_name PassiveCounterKey
extends RefCounted

const SOURCE_KINDS := ["inner_skill", "item"]

var source_kind: String = ""
var content_id: String = ""
var counter_instance_key: String = ""
var state_key: String = ""
var counter_id: String = ""
var definition_source_kind: String = ""
var definition_content_id: String = ""
var definition_behavior_id: String = ""
var definition_behavior_index: int = -1

func configure(values: Dictionary):
    source_kind = str(values.get("source_kind", ""))
    content_id = str(values.get("content_id", ""))
    counter_instance_key = str(values.get("counter_instance_key", ""))
    state_key = str(values.get("state_key", ""))
    counter_id = str(values.get("counter_id", ""))
    definition_source_kind = str(values.get("definition_source_kind", ""))
    definition_content_id = str(values.get("definition_content_id", ""))
    definition_behavior_id = str(values.get("definition_behavior_id", ""))
    definition_behavior_index = int(values.get("definition_behavior_index", -1))
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
    if counter_instance_key != "" and pattern.search(counter_instance_key) == null:
        errors.append("counter_instance_key 必须使用稳定 snake_case：%s" \
            % counter_instance_key)
    var definition_values := [
        definition_source_kind,
        definition_content_id,
        definition_behavior_id,
    ]
    var has_definition := definition_values.any(func(value): return str(value) != "") \
        or definition_behavior_index >= 0
    if has_definition:
        if definition_source_kind not in SOURCE_KINDS:
            errors.append("未知 definition_source_kind：%s" % definition_source_kind)
        for field in ["definition_content_id", "definition_behavior_id"]:
            var value := str(get(field))
            if pattern.search(value) == null:
                errors.append("%s 必须使用稳定 snake_case：%s" % [field, value])
        if definition_behavior_index < 0:
            errors.append("definition_behavior_index 必须是非负整数")
    return errors

func storage_key() -> String:
    if counter_instance_key == "":
        return "%s|%s|%s|%s" % [
            source_kind, content_id, state_key, counter_id]
    return "%s|%s|%s|%s|%s" % [
        source_kind, content_id, counter_instance_key, state_key, counter_id]

func to_dict() -> Dictionary:
    var result := {
        "source_kind": source_kind,
        "content_id": content_id,
        "state_key": state_key,
        "counter_id": counter_id,
    }
    if counter_instance_key != "":
        result["counter_instance_key"] = counter_instance_key
    if definition_behavior_index >= 0:
        result["definition_source_kind"] = definition_source_kind
        result["definition_content_id"] = definition_content_id
        result["definition_behavior_id"] = definition_behavior_id
        result["definition_behavior_index"] = definition_behavior_index
    return result
