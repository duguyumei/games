class_name PassiveCounterReadPort
extends RefCounted

const KeyScript = preload("res://core/passives/passive_counter_key.gd")

var _store
var _source
var _definitions: Dictionary = {}
var _errors: Array[String] = []

func _init(store, source, definitions: Array) -> void:
    _store = store
    _source = source
    for definition in definitions:
        _definitions[definition.counter_id] = definition

func read(counter_id: String) -> int:
    var resolved := _resolve(counter_id)
    if not resolved.get("success", false):
        return 0
    return _store.get_value(resolved["key"], resolved["definition"])

func has_non_default_value(counter_id: String) -> bool:
    var resolved := _resolve(counter_id)
    if not resolved.get("success", false):
        return false
    return _store.has_non_default_value(
        resolved["key"], resolved["definition"])

func errors() -> Array[String]:
    return _errors.duplicate()

func is_valid() -> bool:
    return _errors.is_empty()

func _resolve(counter_id: String) -> Dictionary:
    if not _definitions.has(counter_id):
        _record_error(counter_id, "未声明计数器")
        return {"success": false}
    if str(_source.state_key) == "":
        _record_error(counter_id, "有状态 behavior 缺少 state_key")
        return {"success": false}
    return {
        "success": true,
        "definition": _definitions[counter_id],
        "key": KeyScript.new().configure({
            "source_kind": _source.source_kind,
            "content_id": _source.content_id,
            "counter_instance_key": _source.counter_instance_key,
            "state_key": _source.state_key,
            "counter_id": counter_id,
            "definition_source_kind": _source.counter_definition_source_kind,
            "definition_content_id": _source.counter_definition_content_id,
            "definition_behavior_id": _source.counter_definition_behavior_id,
            "definition_behavior_index": (
                _source.counter_definition_behavior_index),
        }),
    }

func _record_error(counter_id: String, detail: String) -> void:
    var message := "%s:%s · behavior %s · state_key %s · counter %s：%s" % [
        str(_source.source_kind), str(_source.content_id),
        str(_source.behavior_id), str(_source.state_key), counter_id, detail]
    if not _errors.has(message):
        _errors.append(message)
