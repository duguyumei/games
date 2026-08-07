class_name RewardBundle
extends RefCounted

const VERSION := 1

var _data: Dictionary

func _init(values: Dictionary = {}) -> void:
    _data = {
        "version": VERSION,
        "id": str(values.get("id", "")),
        "seed": int(values.get("seed", 0)),
        "act": int(values.get("act", 1)),
        "node_id": str(values.get("node_id", "")),
        "node_type": str(values.get("node_type", "")),
        "entries": values.get("entries", []).duplicate(true),
    }

func bundle_id() -> String:
    return str(_data.get("id", ""))

func entries() -> Array:
    return _data.get("entries", []).duplicate(true)

func total(kind: String) -> int:
    var result := 0
    for entry in _data.get("entries", []):
        if str(entry.get("kind", "")) == kind:
            result += int(entry.get("amount", 0))
    return result

func to_dict() -> Dictionary:
    return _data.duplicate(true)
