class_name BattlePassiveCounterKey
extends RefCounted

var owner_id: String = ""
var source_instance_key: String = ""
var counter_instance_key: String = ""
var state_key: String = ""
var counter_id: String = ""

func configure(values: Dictionary):
    owner_id = str(values.get("owner_id", ""))
    source_instance_key = str(values.get("source_instance_key", ""))
    counter_instance_key = str(values.get("counter_instance_key", ""))
    state_key = str(values.get("state_key", ""))
    counter_id = str(values.get("counter_id", ""))
    return self

func validation_errors() -> Array[String]:
    var errors: Array[String] = []
    var pattern := RegEx.new()
    pattern.compile("^[a-z][a-z0-9_]*$")
    if owner_id == "":
        errors.append("owner_id 不能为空")
    if source_instance_key == "":
        errors.append("source_instance_key 不能为空")
    if counter_instance_key != "" and pattern.search(counter_instance_key) == null:
        errors.append("counter_instance_key 必须使用稳定 snake_case：%s" \
            % counter_instance_key)
    for field in ["state_key", "counter_id"]:
        var value := str(get(field))
        if pattern.search(value) == null:
            errors.append("%s 必须使用稳定 snake_case：%s" % [field, value])
    return errors

func storage_key() -> String:
    if counter_instance_key == "":
        return "%s|%s|%s|%s" % [
            owner_id, source_instance_key, state_key, counter_id]
    return "%s|%s|%s|%s|%s" % [
        owner_id, source_instance_key, counter_instance_key,
        state_key, counter_id]

func to_dict() -> Dictionary:
    var result := {
        "owner_id": owner_id,
        "source_instance_key": source_instance_key,
        "state_key": state_key,
        "counter_id": counter_id,
    }
    if counter_instance_key != "":
        result["counter_instance_key"] = counter_instance_key
    return result
