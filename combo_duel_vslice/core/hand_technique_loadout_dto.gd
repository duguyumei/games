class_name HandTechniqueLoadoutDTO
extends RefCounted

const SCHEMA_VERSION := 3

var hand_id: String = ""
var hand_name: String = ""
var slot_count: int = 0
var sequence: Array = []
var available_techniques: Array = []
var editable: bool = false
var blocked_reason: String = ""
var unused_slot_count: int = 0

func configure(values: Dictionary):
    hand_id = str(values.get("hand_id", ""))
    hand_name = str(values.get("hand_name", hand_id))
    slot_count = maxi(0, int(values.get("slot_count", 0)))
    sequence = values.get("sequence", []).duplicate(true)
    available_techniques = values.get(
        "available_techniques", []).duplicate(true)
    editable = bool(values.get("editable", false))
    blocked_reason = str(values.get("blocked_reason", ""))
    unused_slot_count = maxi(0, int(values.get(
        "unused_slot_count", slot_count - sequence.size())))
    return self

func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "hand_id": hand_id,
        "hand_name": hand_name,
        "slot_count": slot_count,
        "sequence": sequence.duplicate(true),
        "available_techniques": available_techniques.duplicate(true),
        "editable": editable,
        "blocked_reason": blocked_reason,
        "unused_slot_count": unused_slot_count,
    }
