class_name CardIdentityFacts
extends RefCounted

var is_true_qi: bool = true
var effective_attributes: Array[String] = []
var rank_tags: Array[String] = []
var card_kinds: Array[String] = []
var rank_order: int = 0
var rank_name: String = ""
var definition_id: String = ""

func configure(values: Dictionary = {}):
    is_true_qi = bool(values.get("is_true_qi", true))
    effective_attributes = _strings(values.get("effective_attributes", []))
    rank_tags = _strings(values.get("rank_tags", []))
    card_kinds = _strings(values.get("card_kinds", []))
    rank_order = int(values.get("rank_order", 0))
    rank_name = str(values.get("rank_name", ""))
    definition_id = str(values.get("definition_id", ""))
    return self

func has_attribute(attribute_id: String) -> bool:
    return effective_attributes.has(attribute_id)

func has_rank_tag(tag: String) -> bool:
    return rank_tags.has(tag)

func is_card_kind(kind: String) -> bool:
    return card_kinds.has(kind)

func to_dict() -> Dictionary:
    return {
        "is_true_qi": is_true_qi,
        "effective_attributes": effective_attributes.duplicate(),
        "rank_tags": rank_tags.duplicate(),
        "card_kinds": card_kinds.duplicate(),
        "rank_order": rank_order,
        "rank_name": rank_name,
        "definition_id": definition_id,
    }

func _strings(values) -> Array[String]:
    var result: Array[String] = []
    if values is Array:
        for value in values:
            var text := str(value)
            if text != "" and not result.has(text):
                result.append(text)
    return result

