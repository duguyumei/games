class_name PassiveRuleSource
extends RefCounted

var source_kind: String = ""
var content_id: String = ""
var source_instance_key: String = ""
var definition: Dictionary = {}
var behavior_id: String = ""
var behavior_index: int = 0
var state_key: String = ""
var configuration: Dictionary = {}
var source_order: int = 0

func configure(values: Dictionary):
    source_kind = str(values.get("source_kind", ""))
    content_id = str(values.get("content_id", ""))
    source_instance_key = str(values.get("source_instance_key", ""))
    definition = values.get("definition", {}).duplicate(true)
    behavior_id = str(values.get("behavior_id", ""))
    behavior_index = int(values.get("behavior_index", 0))
    state_key = str(values.get("state_key", ""))
    configuration = values.get("configuration", {}).duplicate(true)
    source_order = int(values.get("source_order", 0))
    return self

func to_dict() -> Dictionary:
    return {
        "source_kind": source_kind,
        "content_id": content_id,
        "source_instance_key": source_instance_key,
        "definition": definition.duplicate(true),
        "behavior_id": behavior_id,
        "behavior_index": behavior_index,
        "state_key": state_key,
        "configuration": configuration.duplicate(true),
        "source_order": source_order,
    }
