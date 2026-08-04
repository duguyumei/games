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
    var definition := load_definition(path)
    var cards: Array = []
    for attribute in definition.get("attributes", []):
        for rank in definition.get("ranks", []):
            var card_id := "%s_%s" % [attribute["id"], rank["id"]]
            cards.append(QiCardScript.new(
                card_id,
                str(rank["id"]),
                int(rank["order"]),
                int(rank["qi"]),
                str(attribute["id"]),
                str(attribute["name"])))
    return cards

