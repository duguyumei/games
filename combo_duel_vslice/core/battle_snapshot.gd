class_name BattleSnapshot
extends RefCounted

var _data: Dictionary

func _init(values: Dictionary = {}) -> void:
    _data = values.duplicate(true)

func value(key: String, default_value = null):
    var result = _data.get(key, default_value)
    if result is Dictionary or result is Array:
        return result.duplicate(true)
    return result

func section(key: String) -> Dictionary:
    return _data.get(key, {}).duplicate(true)

func to_dict() -> Dictionary:
    return _data.duplicate(true)
