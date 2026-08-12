class_name ActionPreviewDto
extends RefCounted

const HandResultDtoScript = preload("res://core/hand_result_dto.gd")
const SCHEMA_VERSION := 2

var valid: bool = false
var reason: String = ""
var cards: Array = []
var hand: HandResultDtoScript
var values: Dictionary = {}
var passive_power_query_inputs: Dictionary = {}
var technique_id: String = ""
var technique: Dictionary = {}
var condition: Dictionary = {}
var technique_activation: Dictionary = {}
var cooperation: Dictionary = {}
var cooperation_permission: Dictionary = {}
var intent: Dictionary = {}
var inner_skills: Array = []
var next_technique_id: String = ""
var next_technique: Dictionary = {}

func configure(snapshot: Dictionary):
    valid = bool(snapshot.get("valid", false))
    reason = str(snapshot.get("reason", ""))
    cards = snapshot.get("cards", []).duplicate()
    hand = HandResultDtoScript.new().configure(snapshot.get("hand", {}))
    values = snapshot.get("values", {}).duplicate(true)
    passive_power_query_inputs = snapshot.get(
        "passive_power_query_inputs", {}).duplicate(true)
    technique_id = str(snapshot.get("technique_id", ""))
    technique = snapshot.get("technique", {}).duplicate(true)
    condition = snapshot.get("condition", {}).duplicate(true)
    technique_activation = snapshot.get(
        "technique_activation", {}).duplicate(true)
    cooperation = snapshot.get("cooperation", {}).duplicate(true)
    cooperation_permission = snapshot.get(
        "cooperation_permission", {}).duplicate(true)
    intent = snapshot.get("intent", {}).duplicate(true)
    inner_skills = snapshot.get("inner_skills", []).duplicate(true)
    next_technique_id = str(snapshot.get("next_technique_id", ""))
    next_technique = snapshot.get("next_technique", {}).duplicate(true)
    return self

func is_empty() -> bool:
    return not valid and reason == "" and hand.is_empty()

func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "valid": valid,
        "reason": reason,
        "cards": cards.duplicate(),
        "hand": hand.to_dict(),
        "values": values.duplicate(true),
        "passive_power_query_inputs": passive_power_query_inputs.duplicate(true),
        "technique_id": technique_id,
        "technique": technique.duplicate(true),
        "condition": condition.duplicate(true),
        "technique_activation": technique_activation.duplicate(true),
        "cooperation": cooperation.duplicate(true),
        "cooperation_permission": cooperation_permission.duplicate(true),
        "intent": intent.duplicate(true),
        "inner_skills": inner_skills.duplicate(true),
        "next_technique_id": next_technique_id,
        "next_technique": next_technique.duplicate(true),
    }

func duplicate(_deep: bool = false) -> Dictionary:
    return to_dict()
