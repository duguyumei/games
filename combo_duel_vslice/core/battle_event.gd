class_name BattleEvent
extends RefCounted

var _data: Dictionary

func _init(values: Dictionary = {}) -> void:
    _data = values.duplicate(true)

func event_type() -> String:
    return str(_data.get("type", "unknown"))

func value(key: String, default_value = null):
    var result = _data.get(key, default_value)
    if result is Dictionary or result is Array:
        return result.duplicate(true)
    return result

func to_dict() -> Dictionary:
    return _data.duplicate(true)
