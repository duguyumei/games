class_name NodeInteractionChoiceDTO
extends RefCounted

var choice_id: String = ""
var label: String = ""
var description: String = ""
var enabled: bool = true
var disabled_reason: String = ""
var metadata: Dictionary = {}

func _init(values: Dictionary = {}) -> void:
    choice_id = str(values.get("id", ""))
    label = str(values.get("label", ""))
    description = str(values.get("description", ""))
    enabled = bool(values.get("enabled", true))
    disabled_reason = str(values.get("disabled_reason", ""))
    metadata = values.get("metadata", {}).duplicate(true)

func snapshot() -> Dictionary:
    return {
        "id": choice_id,
        "label": label,
        "description": description,
        "enabled": enabled,
        "disabled_reason": disabled_reason,
        "metadata": metadata.duplicate(true),
    }

func to_dict() -> Dictionary:
    return snapshot()
