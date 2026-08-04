class_name QiCard
extends RefCounted

var id: String
var rank_name: String
var rank_order: int
var qi_value: int
var attribute: String
var attribute_name: String
var enhancement: String = ""
var edition: String = ""
var combat_statuses: Dictionary = {}

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

func set_enhancement(enhancement_id: String) -> void:
    enhancement = enhancement_id

func set_edition(edition_id: String) -> void:
    edition = edition_id

func has_combat_status(slot: String, status_id: String = "") -> bool:
    if not combat_statuses.has(slot):
        return false
    return status_id == "" or str(combat_statuses[slot]) == status_id

func set_combat_status(slot: String, status_id: String) -> void:
    combat_statuses[slot] = status_id

func remove_combat_status(slot: String) -> String:
    var previous := str(combat_statuses.get(slot, ""))
    combat_statuses.erase(slot)
    return previous

func to_dict() -> Dictionary:
    return {
        "id": id,
        "rank_name": rank_name,
        "rank_order": rank_order,
        "qi_value": qi_value,
        "attribute": attribute,
        "attribute_name": attribute_name,
        "enhancement": enhancement,
        "edition": edition,
        "combat_statuses": combat_statuses.duplicate(true),
    }
