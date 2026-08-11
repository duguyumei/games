class_name NodeInteractionDTO
extends RefCounted

const SCHEMA_VERSION := 1
const ChoiceDTOScript = preload(
    "res://core/node_interactions/node_interaction_choice_dto.gd")

var interaction_token: String = ""
var source_kind: String = ""
var source_id: String = ""
var node_id: String = ""
var node_type: String = ""
var content_id: String = ""
var interaction_kind: String = ""
var act: int = 1
var content_seed: int = 0
var title: String = ""
var description: String = ""
var choices: Array = []
var minimum_choices: int = 1
var maximum_choices: int = 1
var metadata: Dictionary = {}

func _init(values: Dictionary = {}) -> void:
    interaction_token = str(values.get("interaction_token", values.get("token", "")))
    source_kind = str(values.get("source_kind", ""))
    source_id = str(values.get("source_id", ""))
    node_id = str(values.get("node_id", ""))
    node_type = str(values.get("node_type", ""))
    content_id = str(values.get("content_id", ""))
    interaction_kind = str(values.get("interaction_kind", ""))
    act = int(values.get("act", 1))
    content_seed = int(values.get("content_seed", 0))
    title = str(values.get("title", ""))
    description = str(values.get("description", ""))
    for choice_value in values.get("choices", []):
        if choice_value is Dictionary:
            choices.append(ChoiceDTOScript.new(choice_value))
    minimum_choices = int(values.get("minimum_choices", 1))
    maximum_choices = int(values.get("maximum_choices", 1))
    metadata = values.get("metadata", {}).duplicate(true)

func snapshot() -> Dictionary:
    var frozen_choices: Array = []
    for choice in choices:
        frozen_choices.append(choice.to_dict())
    return {
        "schema_version": SCHEMA_VERSION,
        "interaction_token": interaction_token,
        "source_kind": source_kind,
        "source_id": source_id,
        "node_id": node_id,
        "node_type": node_type,
        "content_id": content_id,
        "interaction_kind": interaction_kind,
        "act": act,
        "content_seed": content_seed,
        "title": title,
        "description": description,
        "choices": frozen_choices,
        "minimum_choices": minimum_choices,
        "maximum_choices": maximum_choices,
        "metadata": metadata.duplicate(true),
    }

func to_dict() -> Dictionary:
    return snapshot()
