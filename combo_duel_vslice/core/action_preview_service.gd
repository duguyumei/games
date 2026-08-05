class_name ActionPreviewService
extends RefCounted

const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")

var technique_repository
var inner_skill_repository
var effect_executor

func _init(techniques, inner_skills, executor) -> void:
    technique_repository = techniques
    inner_skill_repository = inner_skills
    effect_executor = executor

func preview(
        side,
        card_ids: Array,
        sequence_book,
        modifiers_by_hand: Dictionary = {},
        natural_combo_used: bool = false) -> Dictionary:
    if card_ids.size() < 1 or card_ids.size() > 5:
        return {"valid": false, "reason": "每次必须选择 1～5 张真气"}
    var cards: Array = []
    for card_id in card_ids:
        var card = side.find_hand_card(str(card_id))
        if card == null or cards.has(card):
            return {"valid": false, "reason": "选择包含不在手牌中的真气"}
        cards.append(card)
    var hand_result := HandEvaluatorScript.evaluate(cards)
    if hand_result.is_empty():
        return {"valid": false, "reason": "无法识别牌型"}

    var modifiers: Dictionary = modifiers_by_hand.get(hand_result["id"], {}).duplicate(true)
    modifiers["insight_multiplier"] = (
        int(modifiers.get("insight_multiplier", 0))
        + int(side.insight_multipliers.get(hand_result["id"], 0)))
    var values := PowerCalculatorScript.calculate(hand_result, modifiers)
    var technique_id: String = sequence_book.current_id(hand_result["id"])
    var technique: Dictionary = technique_repository.get_technique(technique_id)
    var condition := {"ok": true, "reason": "空序列"}
    if not technique.is_empty():
        condition = technique_repository.conditions_met(technique, hand_result)

    var intent := {
        "damage": 0,
        "defense": 0,
        "segments": 0,
        "technique_combo": false,
        "inner_skill_defense": 0,
    }
    var intent_context := {
        "hand_result": hand_result,
        "played_cards": cards,
        "power": values["technique_value"],
        "captures": {},
    }
    if not technique.is_empty() and condition["ok"]:
        _merge_intent(intent, effect_executor.summarize_intent(
            technique.get("effects", []),
            intent_context,
            int(side.stacks.get("momentum", 0))))
    for inner_skill_id in side.equipped_inner_skill_ids:
        var inner_skill: Dictionary = inner_skill_repository.get_inner_skill(inner_skill_id)
        if inner_skill.get("timing", "") != "on_play_resolve":
            continue
        var inner_intent: Dictionary = effect_executor.summarize_intent(
            inner_skill.get("effects", []),
            intent_context,
            int(side.stacks.get("momentum", 0)))
        intent["inner_skill_defense"] = (
            int(intent["inner_skill_defense"])
            + int(inner_intent.get("defense", 0)))
        _merge_intent(intent, inner_intent)

    var natural_combo_available := is_same_attribute_action(cards) and not natural_combo_used
    intent["natural_combo"] = natural_combo_available
    intent["combo"] = natural_combo_available or bool(intent.get("technique_combo", false))
    var next_technique_id: String = sequence_book.next_id(hand_result["id"])
    return {
        "valid": true,
        "cards": cards,
        "hand": hand_result,
        "values": values,
        "technique_id": technique_id,
        "technique": technique,
        "condition": condition,
        "intent": intent,
        "inner_skills": _inner_skill_definitions_for(side),
        "next_technique_id": next_technique_id,
        "next_technique": technique_repository.get_technique(next_technique_id),
    }

static func is_same_attribute_action(cards: Array) -> bool:
    if cards.is_empty():
        return false
    var attribute: String = cards[0].attribute
    if attribute == "":
        return false
    for card in cards:
        if card.attribute != attribute:
            return false
    return true

func _inner_skill_definitions_for(side) -> Array:
    var definitions: Array = []
    for inner_skill_id in side.equipped_inner_skill_ids:
        var definition: Dictionary = inner_skill_repository.get_inner_skill(inner_skill_id)
        if not definition.is_empty():
            definitions.append(definition)
    return definitions

func _merge_intent(target_intent: Dictionary, addition: Dictionary) -> void:
    for key in ["damage", "defense", "segments"]:
        target_intent[key] = int(target_intent.get(key, 0)) + int(addition.get(key, 0))
    target_intent["technique_combo"] = (
        bool(target_intent.get("technique_combo", false))
        or bool(addition.get("technique_combo", false)))
