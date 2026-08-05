class_name AiConversationSnapshot
extends RefCounted

const VERSION := 1

var _data: Dictionary = {}

func _init(values: Dictionary = {}) -> void:
    _data = values.duplicate(true)
    _data["schema_version"] = VERSION

func value(key: String, default_value = null):
    var result = _data.get(key, default_value)
    return result.duplicate(true) if result is Dictionary or result is Array else result

func to_dict() -> Dictionary:
    return _data.duplicate(true)
