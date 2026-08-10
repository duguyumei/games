class_name InnerSkillLoadoutDTO
extends RefCounted

const SCHEMA_VERSION := 1

var learned: Array = []
var equipped: Array = []
var equipped_inner_skill_ids: Array[String] = []
var technique_slot_index: int = 0
var inner_skill_limit: int = 6
var editable: bool = false
var blocked_reason: String = ""

func configure(values: Dictionary):
    learned = values.get("learned", []).duplicate(true)
    equipped = values.get("equipped", []).duplicate(true)
    equipped_inner_skill_ids.clear()
    for inner_skill_id in values.get("equipped_inner_skill_ids", []):
        equipped_inner_skill_ids.append(str(inner_skill_id))
    technique_slot_index = int(values.get("technique_slot_index", 0))
    inner_skill_limit = int(values.get("inner_skill_limit", 6))
    editable = bool(values.get("editable", false))
    blocked_reason = str(values.get("blocked_reason", ""))
    return self

func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "learned": learned.duplicate(true),
        "equipped": equipped.duplicate(true),
        "equipped_inner_skill_ids": equipped_inner_skill_ids.duplicate(),
        "technique_slot_index": technique_slot_index,
        "inner_skill_limit": inner_skill_limit,
        "editable": editable,
        "blocked_reason": blocked_reason,
    }

func duplicate(_deep: bool = false) -> Dictionary:
    return to_dict()
