class_name QiCard
extends RefCounted

var id: String
var rank_name: String
var rank_order: int
var qi_value: int
var attribute: String
var attribute_name: String

func _init(
        card_id: String = "",
        card_rank_name: String = "",
        card_rank_order: int = 0,
        card_qi_value: int = 0,
        card_attribute: String = "",
        card_attribute_name: String = "") -> void:
    id = card_id
    rank_name = card_rank_name
    rank_order = card_rank_order
    qi_value = card_qi_value
    attribute = card_attribute
    attribute_name = card_attribute_name

func display_name() -> String:
    return "%s·%s" % [attribute_name, rank_name]

func to_dict() -> Dictionary:
    return {
        "id": id,
        "rank_name": rank_name,
        "rank_order": rank_order,
        "qi_value": qi_value,
        "attribute": attribute,
        "attribute_name": attribute_name,
    }

