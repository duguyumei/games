class_name BattlePassiveCounterReadPort
extends RefCounted

const KeyScript = preload(
    "res://core/passives/battle_passive_counter_key.gd")

var _store
var _source
var _owner_id: String
var _definitions: Dictionary = {}
var _errors: Array[String] = []

func _init(store, owner_id: String, source, definitions: Array) -> void:
    _store = store
    _owner_id = owner_id
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
        _record_error(counter_id, "未声明战斗临时计数器")
        return {"success": false}
    if str(_source.state_key) == "":
        _record_error(counter_id, "有状态 behavior 缺少 state_key")
        return {"success": false}
    return {
        "success": true,
        "definition": _definitions[counter_id],
        "key": KeyScript.new().configure({
            "owner_id": _owner_id,
            "source_instance_key": _source.source_instance_key,
            "counter_instance_key": _source.counter_instance_key,
            "state_key": _source.state_key,
            "counter_id": counter_id,
        }),
    }

func _record_error(counter_id: String, detail: String) -> void:
    var message := "%s · %s · behavior %s · state_key %s · counter %s：%s" % [
        _owner_id, str(_source.source_instance_key),
        str(_source.behavior_id), str(_source.state_key), counter_id, detail]
    if not _errors.has(message):
        _errors.append(message)
