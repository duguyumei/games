class_name RunBuildDTO
extends RefCounted

const HandTechniqueLoadoutDTOScript = preload(
    "res://core/hand_technique_loadout_dto.gd")
const InnerSkillLoadoutDTOScript = preload(
    "res://core/inner_skill_loadout_dto.gd")

const SCHEMA_VERSION := 1

var editable: bool = false
var blocked_reason: String = ""
var cards: Array = []
var consumable_limit: int = 3
var consumables: Array = []
var items: Array = []
var hand_loadouts: Array = []
var inner_skill_loadout = InnerSkillLoadoutDTOScript.new()
var experience: int = 0

func configure(values: Dictionary):
    editable = bool(values.get("editable", false))
    blocked_reason = str(values.get("blocked_reason", ""))
    cards = values.get("cards", []).duplicate(true)
    consumable_limit = int(values.get("consumable_limit", 3))
    consumables = values.get("consumables", []).duplicate(true)
    items = values.get("items", []).duplicate(true)
    hand_loadouts.clear()
    for loadout_value in values.get("hand_loadouts", []):
        if loadout_value is Dictionary:
            hand_loadouts.append(
                HandTechniqueLoadoutDTOScript.new().configure(loadout_value))
    var inner_value = values.get("inner_skill_loadout", {})
    if inner_value is Dictionary:
        inner_skill_loadout = InnerSkillLoadoutDTOScript.new().configure(
            inner_value)
    elif inner_value != null and inner_value.has_method("to_dict"):
        inner_skill_loadout = InnerSkillLoadoutDTOScript.new().configure(
            inner_value.to_dict())
    experience = int(values.get("experience", 0))
    return self

func hand_loadout(hand_id: String):
    for loadout in hand_loadouts:
        if loadout.hand_id == hand_id:
            return loadout
    return null

func to_dict() -> Dictionary:
    var loadout_values: Array = []
    for loadout in hand_loadouts:
        loadout_values.append(loadout.to_dict())
    return {
        "schema_version": SCHEMA_VERSION,
        "editable": editable,
        "blocked_reason": blocked_reason,
        "cards": cards.duplicate(true),
        "consumable_limit": consumable_limit,
        "consumables": consumables.duplicate(true),
        "items": items.duplicate(true),
        "hand_loadouts": loadout_values,
        "inner_skill_loadout": inner_skill_loadout.to_dict(),
        "experience": experience,
    }

func duplicate(_deep: bool = false) -> Dictionary:
    return to_dict()

