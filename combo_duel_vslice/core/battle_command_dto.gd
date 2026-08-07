class_name BattleCommandDto
extends RefCounted

const SCHEMA_VERSION := 1

var type: String = ""
var card_ids: Array[String] = []
var cooperation_card_ids: Array[String] = []
var request_id: String = ""
var slot_index: int = -1
var direction: int = 0

func configure(values: Dictionary):
    type = str(values.get("type", ""))
    card_ids.clear()
    for card_id in values.get("card_ids", []):
        card_ids.append(str(card_id))
    cooperation_card_ids.clear()
    for card_id in values.get("cooperation_card_ids", []):
        cooperation_card_ids.append(str(card_id))
    request_id = str(values.get("request_id", ""))
    slot_index = int(values.get("slot_index", -1))
    direction = int(values.get("direction", 0))
    return self

func snapshot() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "type": type,
        "card_ids": card_ids.duplicate(),
        "cooperation_card_ids": cooperation_card_ids.duplicate(),
        "request_id": request_id,
        "slot_index": slot_index,
        "direction": direction,
    }
