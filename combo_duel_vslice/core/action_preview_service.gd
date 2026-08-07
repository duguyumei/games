class_name ActionPreviewService
extends RefCounted

## 行动提案的纯预览服务。
##
## 这里组合牌型、功法与内功修正，产出可展示的结算预览；故意不移动牌区、
## 推进功法序列或写入战斗状态，真实提交仍由 BattleActionService 负责。

const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")
const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const ActionPreviewDtoScript = preload("res://core/action_preview_dto.gd")

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
        natural_combo_used: bool = false,
        target = null) -> Dictionary:
    return preview_dto(
        side,
        card_ids,
        sequence_book,
        modifiers_by_hand,
        natural_combo_used,
        target).to_dict()

func preview_dto(
        side,
        card_ids: Array,
        sequence_book,
        modifiers_by_hand: Dictionary = {},
        natural_combo_used: bool = false,
        target = null):
    if card_ids.size() < 1 or card_ids.size() > 5:
        return _invalid_preview("每次必须选择 1～5 张真气")
    var cards: Array = []
    for card_id in card_ids:
        var card = side.find_hand_card(str(card_id))
        if card == null or cards.has(card):
            return _invalid_preview("选择包含不在手牌中的真气")
        cards.append(card)
    var hand_result_dto = HandEvaluatorScript.evaluate_dto(cards)
    if hand_result_dto.is_empty():
        return _invalid_preview("无法识别牌型")
    var hand_result: Dictionary = hand_result_dto.to_dict()

    var play_check: Dictionary = side.status_system.can_play_cards(side, cards) \
        if side.status_system != null else {"allowed": true}
    if not bool(play_check.get("allowed", false)):
        return _invalid_preview(str(play_check.get("reason", "此真气本回合不能打出")))

    var modifiers: Dictionary = modifiers_by_hand.get(hand_result["id"], {}).duplicate(true)
    if cards.size() == 5 and is_same_attribute_action(cards):
        modifiers["power_amp_percent"] = int(modifiers.get("power_amp_percent", 0)) + 50
    modifiers["insight_multiplier"] = (
        int(modifiers.get("insight_multiplier", 0))
        + int(side.insight_multipliers.get(hand_result["id"], 0)))
    var contribution_modifier := Callable()
    if side.status_system != null:
        contribution_modifier = Callable(side.status_system, "modify_card_contribution").bind(side)
    var values := PowerCalculatorScript.calculate(hand_result, modifiers, contribution_modifier)
    var technique_id: String = sequence_book.current_id(hand_result["id"])
    var technique_definition = technique_repository.get_definition(technique_id)
    var technique: Dictionary = (
        technique_definition.to_definition()
        if technique_definition != null else {})
    var condition := {"ok": true, "reason": "空序列"}
    if technique_definition != null:
        condition = technique_repository.conditions_met(
            technique_definition,
            hand_result)

    var intent := {
        "damage": 0,
        "defense": 0,
        "segments": 0,
        "technique_combo": false,
        "inner_skill_defense": 0,
    }
    var intent_context = EffectContextScript.new().configure({
        "actor": side,
        "hand_result": hand_result,
        "played_cards": cards,
        "power": values["technique_value"],
        "captures": {},
        "source_kind": "preview",
    })
    var damage_percent: int = side.status_modifier(
        "damage_percent", {"source_kind": "technique"})
    if side.status_system != null:
        damage_percent += side.status_system.actor_hand_card_numeric_modifier(
            side, "outgoing_damage_percent")
        if target != null:
            damage_percent += side.status_system.actor_hand_card_numeric_modifier(
                target, "incoming_damage_percent")
    if technique_definition != null and condition["ok"]:
        _merge_intent(intent, effect_executor.summarize_intent(
            technique_definition.effects,
            intent_context,
            damage_percent))
    for inner_skill_id in side.equipped_inner_skill_ids:
        var inner_skill: Dictionary = inner_skill_repository.get_inner_skill(inner_skill_id)
        if inner_skill.get("timing", "") != "on_play_resolve":
            continue
        var inner_intent: Dictionary = effect_executor.summarize_intent(
            inner_skill.get("effects", []),
            intent_context,
            damage_percent)
        intent["inner_skill_defense"] = (
            int(intent["inner_skill_defense"])
            + int(inner_intent.get("defense", 0)))
        _merge_intent(intent, inner_intent)

    var natural_combo_available := is_same_attribute_action(cards) and not natural_combo_used
    intent["natural_combo"] = natural_combo_available
    intent["combo"] = natural_combo_available or bool(intent.get("technique_combo", false))
    var next_technique_id: String = sequence_book.next_id(hand_result["id"])
    return ActionPreviewDtoScript.new().configure({
        "valid": true,
        "cards": cards,
        "hand": hand_result,
        "values": values,
        "technique_id": technique_id,
        "technique": technique,
        "condition": condition,
        "cooperation": technique.get("cooperation", {}).duplicate(true),
        "intent": intent,
        "inner_skills": _inner_skill_definitions_for(side),
        "next_technique_id": next_technique_id,
        "next_technique": technique_repository.get_technique(next_technique_id),
    })

func _invalid_preview(reason: String):
    return ActionPreviewDtoScript.new().configure({
        "valid": false,
        "reason": reason,
    })

static func is_same_attribute_action(cards: Array) -> bool:
    if cards.is_empty():
        return false
    for attribute in ["wind", "forest", "fire", "mountain"]:
        var all_match := true
        for card in cards:
            if card.reshape_enhancement == "stone":
                continue
            if not card.is_attribute(attribute):
                all_match = false
                break
        if all_match:
            return true
    return false

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
