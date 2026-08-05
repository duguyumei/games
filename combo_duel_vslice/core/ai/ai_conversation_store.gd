class_name AiConversationStore
extends RefCounted

const REDACTED := "[REDACTED]"
const SECRET_KEYS := [
    "api_key",
    "apikey",
    "authorization",
    "proxy-authorization",
    "x-api-key",
]

func encode(snapshot) -> String:
    var values: Dictionary = (
        snapshot.to_dict()
        if snapshot is Object and snapshot.has_method("to_dict")
        else snapshot.duplicate(true) if snapshot is Dictionary else {})
    return JSON.stringify(_sanitize(values))

func decode(encoded: String) -> Dictionary:
    var parsed = JSON.parse_string(encoded)
    return parsed if parsed is Dictionary else {}

func save(path: String, snapshot) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(encode(snapshot))
    return true

func load(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    return decode(FileAccess.get_file_as_string(path))

func _sanitize(value):
    if value is Dictionary:
        var result: Dictionary = {}
        for key in value:
            var normalized := str(key).to_lower()
            result[key] = REDACTED if SECRET_KEYS.has(normalized) else _sanitize(value[key])
        return result
    if value is Array:
        var result: Array = []
        for item in value:
            result.append(_sanitize(item))
        return result
    return value
