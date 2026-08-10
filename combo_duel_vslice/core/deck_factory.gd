class_name DeckFactory
extends RefCounted

const QiCardScript = preload("res://core/qi_card.gd")
const DATA_PATH := "res://data/base_deck.json"

static func load_definition(path: String = DATA_PATH) -> Dictionary:
    var text := FileAccess.get_file_as_string(path)
    var parsed = JSON.parse_string(text)
    if not parsed is Dictionary:
        push_error("基础牌组数据无法解析：%s" % path)
        return {}
    return parsed

static func create_standard_deck(path: String = DATA_PATH) -> Array:
    return create_standard_deck_from_definition(load_definition(path))

static func create_standard_deck_from_definition(definition: Dictionary, reshape_rules = null) -> Array:
    var cards: Array = []
    for attribute in definition.get("attributes", []):
        for rank in definition.get("ranks", []):
            var card_id := "%s_%s" % [attribute["id"], rank["id"]]
            var card = QiCardScript.new(
                card_id,
                str(rank["id"]),
                int(rank["order"]),
                int(rank["qi"]),
                str(attribute["id"]),
                str(attribute["name"]),
                card_id)
            if reshape_rules != null:
                reshape_rules.bind_card(card)
            cards.append(card)
    return cards

static func namespace_instance_ids(cards: Array, instance_namespace: String) -> Array:
    if instance_namespace == "":
        return cards
    for card in cards:
        card.id = "%s:%s" % [instance_namespace, card.definition_id]
    return cards

static func create_card_instance(card_definition: Dictionary, instance_id: String = "", reshape_rules = null):
    var definition_id := str(card_definition.get("id", ""))
    var resolved_instance_id := instance_id if instance_id != "" else definition_id
    var card = QiCardScript.new(
        resolved_instance_id,
        str(card_definition.get("rank", card_definition.get("rank_name", ""))),
        int(card_definition.get("order", card_definition.get("rank_order", 0))),
        int(card_definition.get("qi", card_definition.get("qi_value", 0))),
        str(card_definition.get("attribute", "")),
        str(card_definition.get("attribute_name", "")),
        definition_id)
    if reshape_rules != null:
        reshape_rules.bind_card(card)
    return card
