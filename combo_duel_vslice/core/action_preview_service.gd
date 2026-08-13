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
const SameQiRuleScript = preload("res://core/same_qi_rule.gd")
const HandGroupSnapshotScript = preload("res://core/hand_group_snapshot.gd")

var technique_repository
var passive_rule_runtime
var effect_executor
var battle_rule_query_service
var battle_permission_service
var round_number_reader: Callable

func _init(
        techniques,
        passive_runtime,
        executor,
        query_service = null,
        round_reader: Callable = Callable(),
        permission_service = null) -> void:
    technique_repository = techniques
    passive_rule_runtime = passive_runtime
    effect_executor = executor
    battle_rule_query_service = query_service
    round_number_reader = round_reader
    battle_permission_service = permission_service

func preview(
        side,
        card_ids: Array,
        sequence_book,
        modifiers_by_hand: Dictionary = {},
        same_qi_link_used: bool = false,
        target = null) -> Dictionary:
    return preview_dto(
        side,
        card_ids,
        sequence_book,
        modifiers_by_hand,
        same_qi_link_used,
        target).to_dict()

func preview_dto(
        side,
        card_ids: Array,
        sequence_book,
        modifiers_by_hand: Dictionary = {},
        same_qi_link_used: bool = false,
        target = null):
    if card_ids.size() < 1 or card_ids.size() > 5:
        return _invalid_preview("每次必须选择 1～5 张真气")
    var cards: Array = []
    for card_id in card_ids:
        var card = side.find_hand_card(str(card_id))
        if card == null or cards.has(card):
            return _invalid_preview("选择包含不在手牌中的真气")
        cards.append(card)
    var recognition_options = null
    var recognition_query: Dictionary = {"success": true}
    if side.hand_recognition_policy != null:
        recognition_query = side.hand_recognition_policy.resolve_options(side, {
            "actor": side, "target": target,
            "round_number": int(round_number_reader.call()) \
                if round_number_reader.is_valid() else 0,
        })
        if not recognition_query.get("success", false):
            return _invalid_preview(str(recognition_query.get("reason", "牌型识别查询失败")))
        recognition_options = recognition_query.get("options")
    var hand_result_dto = HandEvaluatorScript.evaluate_dto(
        cards,
        recognition_options,
        side.card_identity_policy,
        {"owner": side, "actor": side, "target": target})
    if hand_result_dto.is_empty():
        return _invalid_preview("无法识别牌型")
    var hand_result: Dictionary = hand_result_dto.to_dict()

    var play_check: Dictionary = side.status_system.can_play_cards(side, cards) \
        if side.status_system != null else {"allowed": true}
    if not bool(play_check.get("allowed", false)):
        return _invalid_preview(str(play_check.get("reason", "此真气本回合不能打出")))

    var same_qi: Dictionary = SameQiRuleScript.analyze(
        cards,
        side.card_identity_policy,
        {"owner": side, "actor": side, "target": target})
    if not same_qi.get("success", false):
        return _invalid_preview(str(same_qi.get("reason", "同气身份查询失败")))

    var modifiers: Dictionary = modifiers_by_hand.get(hand_result["id"], {}).duplicate(true)
    modifiers["multiplier_bonus"] = (
        int(modifiers.get("multiplier_bonus", 0))
        + int(side.hand_technique_multiplier_modifiers.get(
            hand_result["id"], 0)))
    modifiers["power_amp_percent"] = (
        int(modifiers.get("power_amp_percent", 0))
        + int(same_qi.get("power_amp_percent", 0)))
    modifiers["power_fixed"] = (
        int(modifiers.get("power_fixed", 0))
        + int(side.hand_proficiency_fixed.get(hand_result["id"], 0))
        + int(side.direct_power_fixed))
    modifiers["power_amp_percent"] = (
        int(modifiers.get("power_amp_percent", 0))
        + int(side.direct_power_percent))
    var power_result := _resolve_power_values(
        side, target, hand_result, cards, modifiers, "", "preview")
    if not power_result.get("success", false):
        return _invalid_preview(str(power_result.get(
            "reason", "功法值查询失败")))
    var values: Dictionary = power_result["values"]
    var technique_id: String = sequence_book.current_id(hand_result["id"])
    var technique_definition = technique_repository.get_definition(technique_id)
    var technique: Dictionary = (
        technique_definition.to_definition()
        if technique_definition != null else {})
    var group_snapshot := HandGroupSnapshotScript.freeze(
        cards, hand_result, side, target)
    var condition := {"ok": true, "reason": "空序列"}
    if technique_definition != null:
        condition = technique_repository.conditions_met(
            technique_definition,
            hand_result,
            side.card_identity_policy)
    var technique_activation := _preview_technique_activation(
        side, target, technique_id, hand_result, cards,
        technique_definition, condition)
    if not technique_activation.get("success", false):
        return _invalid_preview(str(technique_activation.get(
            "reason", "功法启动权限查询失败")))
    var activation_allowed := bool(technique_activation.get("allowed", false))
    values = PowerCalculatorScript.apply_momentum(
        values,
        side.momentum_value
        if technique_definition != null \
            and bool(condition.get("ok", false)) \
            and activation_allowed
        else 0)

    var intent := {
        "damage": 0,
        "defense": 0,
        "segments": 0,
        "technique_combo": false,
        "inner_skill_defense": 0,
    }
    var technique_intent_context = EffectContextScript.new().configure({
        "actor": side,
        "hand_result": hand_result,
        "played_cards": cards,
        "power": values["technique_value"],
        "values": values,
        "technique_id": str(technique.get("id", "")),
        "technique_name": str(technique.get("name", "")),
        "technique_pool": str(technique.get("pool", "")),
        "captures": {},
        "source_kind": "preview",
        "card_identity_policy": side.card_identity_policy,
    })
    var damage_percent := 0
    if side.status_system != null:
        damage_percent += side.status_system.actor_hand_card_numeric_modifier(
            side, "outgoing_damage_percent")
        if target != null:
            damage_percent += side.status_system.actor_hand_card_numeric_modifier(
                target, "incoming_damage_percent")
    if technique_definition != null and condition["ok"] and activation_allowed:
        _merge_intent(intent, effect_executor.summarize_intent(
            technique_definition.effects,
            technique_intent_context,
            damage_percent))
    var passive_preview: Dictionary = passive_rule_runtime.dispatch_event(
        "action_preview", {
            "actor": side,
            "target": target,
            "payload": {
                "effect_executor": effect_executor,
                "damage_percent": damage_percent,
                "captures_by_source": {},
                "effect_context_values": {
                    "actor": side,
                    "target": target,
                    "hand_result": hand_result,
                    "played_cards": cards,
                    "power": values["technique_value"],
                    "values": values,
                    "captures": {},
                    "source_kind": "preview",
                },
            },
        })
    if not passive_preview.get("success", false):
        return _invalid_preview(
            "被动规则预览失败：%s" % "；".join(passive_preview.get("errors", [])))
    for entry in passive_preview.get("results", []):
        var passive_intent: Dictionary = entry.get("result", {}).get("intent", {})
        if entry["source"].source_kind == "inner_skill":
            intent["inner_skill_defense"] = (
                int(intent["inner_skill_defense"])
                + int(passive_intent.get("defense", 0)))
        _merge_intent(intent, passive_intent)
    var queried_intent := _resolve_preview_intent(side, target, intent)
    if not queried_intent.get("success", false):
        return _invalid_preview(str(queried_intent.get(
            "reason", "伤害或防御预览查询失败")))
    intent = queried_intent["intent"]

    var same_qi_action := SameQiRuleScript.intersect_group_attributes([same_qi])
    var same_qi_link_available := (
        bool(same_qi_action.get("qualified", false))
        and not same_qi_link_used)
    intent["same_qi_link"] = same_qi_link_available
    intent["combo"] = same_qi_link_available or bool(intent.get("technique_combo", false))
    var next_technique_id: String = sequence_book.next_id(hand_result["id"])
    return ActionPreviewDtoScript.new().configure({
        "valid": true,
        "cards": cards,
        "hand": hand_result,
        "values": values,
        "passive_power_query_inputs": {
            "modifiers": modifiers,
            "queries": power_result["queries"],
        },
        "same_qi": same_qi,
        "group_snapshot": group_snapshot,
        "same_qi_action": same_qi_action,
        "technique_id": technique_id,
        "technique": technique,
        "condition": condition,
        "technique_activation": technique_activation,
        "cooperation": technique.get("cooperation", {}).duplicate(true) \
            if activation_allowed else {},
        "intent": intent,
        "inner_skills": _inner_skill_definitions_for(side),
        "next_technique_id": next_technique_id,
        "next_technique": technique_repository.get_technique(next_technique_id),
    })

func _preview_technique_activation(
        side,
        target,
        technique_id: String,
        hand_result: Dictionary,
        cards: Array,
        technique_definition,
        condition: Dictionary) -> Dictionary:
    if technique_definition == null:
        return {
            "success": true, "checked": false, "allowed": false,
            "reason": "空功法序列", "source_breakdown": [], "errors": [],
        }
    if not bool(condition.get("ok", false)):
        return {
            "success": true, "checked": false, "allowed": false,
            "reason": str(condition.get("reason", "功法条件不满足")),
            "source_breakdown": [], "errors": [],
        }
    if battle_permission_service == null:
        return {
            "success": true, "checked": true, "allowed": true,
            "reason": "", "source_breakdown": [], "errors": [],
        }
    var result: Dictionary = battle_permission_service.can_activate_technique(
        side, technique_id, str(hand_result.get("id", "")), {
            "target": target,
            "round_number": int(round_number_reader.call()) \
                if round_number_reader.is_valid() else 0,
            "card_instance_ids": cards.map(func(card): return str(card.id)),
            "source_kind": "preview",
        })
    result["success"] = result.get("errors", []).is_empty()
    result["checked"] = true
    return result

func recalculate_confirmed_power(
        side,
        target,
        preview: Dictionary,
        action_token: String,
        frozen_multiplier_bonus: int = 0) -> Dictionary:
    preview["group_snapshot"] = HandGroupSnapshotScript.freeze(
        preview.get("cards", []), preview.get("hand", {}), side, target)
    var inputs: Dictionary = preview.get(
        "passive_power_query_inputs", {})
    var modifiers: Dictionary = inputs.get("modifiers", {}).duplicate(true)
    modifiers["multiplier_bonus"] = (
        int(modifiers.get("multiplier_bonus", 0)) + frozen_multiplier_bonus)
    var result := _resolve_power_values(
        side, target, preview.get("hand", {}), preview.get("cards", []),
        modifiers, action_token, "action_confirmed")
    if result.get("success", false):
        preview["values"] = result["values"]
        preview["values"]["card_multiplier_bonus"] = (
            int(preview["values"].get("card_multiplier_bonus", 0))
            + frozen_multiplier_bonus)
        preview["values"]["frozen_card_multiplier_bonus"] = frozen_multiplier_bonus
        preview["values"]["passive_power_queries"] = result["queries"]
        preview["passive_power_query_inputs"]["confirmed_queries"] = result["queries"]
        preview["passive_power_query_inputs"]["confirmed_action_token"] = action_token
        _apply_technique_power_formation(side, target, preview)
    return result

func _apply_technique_power_formation(side, target, preview: Dictionary) -> void:
    if preview.has("frozen_power_formation"):
        var frozen: Dictionary = preview["frozen_power_formation"]
        preview["values"] = PowerCalculatorScript.apply_direct_power_fixed(
            preview["values"], int(frozen.get("fixed_bonus", 0)))
        return
    var definition: Dictionary = preview.get("technique", {})
    var formation: Dictionary = definition.get("power_formation", {})
    if str(formation.get("kind", "")) != "random_extra_current_qi":
        preview["frozen_power_formation"] = {"fixed_bonus": 0, "target_id": ""}
        return
    var snapshot: Dictionary = preview.get("group_snapshot", {})
    var excluded := str(formation.get("excluded_attribute", ""))
    var candidates: Array = snapshot.get("extra_cards", []).filter(
        func(card): return HandGroupSnapshotScript.has_non_attribute_identity(
            snapshot, card, excluded))
    var chosen = null
    if not candidates.is_empty():
        chosen = candidates[effect_executor.rng.randi_range(0, candidates.size() - 1)]
    var bonus := HandGroupSnapshotScript.current_effective_qi(snapshot, chosen, side) \
        if chosen != null else 0
    preview["frozen_power_formation"] = {
        "fixed_bonus": bonus,
        "target_id": str(chosen.id) if chosen != null else "",
        "target_card": chosen,
    }
    preview["group_snapshot"]["power_formation_target_cards"] = \
        [chosen] if chosen != null else []
    preview["values"] = PowerCalculatorScript.apply_direct_power_fixed(
        preview["values"], bonus)

func _resolve_power_values(
        side,
        target,
        hand_result: Dictionary,
        cards: Array,
        modifiers: Dictionary,
        action_token: String,
        source_kind: String) -> Dictionary:
    var effective := modifiers.duplicate(true)
    var details: Dictionary = {}
    var stages := [
        ["base_fixed", "power_base_fixed_query"],
        ["multiplier_bonus", "power_multiplier_bonus_query"],
        ["power_fixed", "power_fixed_query"],
        ["power_amp_percent", "power_amp_percent_query"],
    ]
    for stage in stages:
        var field := str(stage[0])
        var hook := str(stage[1])
        var base_value := int(effective.get(field, 0))
        if battle_rule_query_service == null:
            details[field] = {
                "base_value": base_value, "effective_value": base_value,
                "source_breakdown": [], "fingerprint": "",
            }
            continue
        var query = battle_rule_query_service.resolve_values({
            "hook": hook, "owner": side, "actor": side, "target": target,
            "subject_kind": "power_stage", "subject_id": field,
            "base_value": base_value, "action_token": action_token,
            "round_number": int(round_number_reader.call()) \
                if round_number_reader.is_valid() else 0,
            "hand_id": str(hand_result.get("id", "")),
            "source_kind": source_kind,
            "card_facts": _card_facts(cards, side.card_identity_policy),
            "metadata": {"stage": field},
        })
        if not query.success:
            return {
                "success": false,
                "reason": "%s：%s" % [hook, "；".join(query.errors)],
            }
        effective[field] = query.effective_value
        details[field] = {
            "base_value": query.base_value,
            "effective_value": query.effective_value,
            "source_breakdown": query.modifier_breakdown.duplicate(true),
            "fingerprint": query.source_fingerprint,
        }
    var contribution_modifier := Callable()
    if side.status_system != null:
        contribution_modifier = Callable(
            side.status_system, "modify_card_contribution").bind(side)
    var values := PowerCalculatorScript.calculate(
        hand_result,
        effective,
        contribution_modifier,
        side.card_identity_policy,
        {"owner": side, "actor": side, "target": target})
    values["passive_power_queries"] = details.duplicate(true)
    return {"success": true, "values": values, "queries": details}

func _card_facts(cards: Array, identity_policy = null) -> Array:
    var result: Array = []
    for card in cards:
        var attributes: Array[String] = []
        for attribute in ["wind", "forest", "fire", "mountain"]:
            if _card_has_attribute(card, attribute, identity_policy):
                attributes.append(attribute)
        result.append({
            "instance_id": str(card.id),
            "definition_id": str(card.current_definition_id()) \
                if card.has_method("current_definition_id") else str(card.definition_id),
            "qi": int(card.effective_qi_value()) \
                if card.has_method("effective_qi_value") else int(card.qi_value),
            "attributes": attributes,
            "identity": _card_identity_dict(card, identity_policy),
        })
    return result

func _card_identity_dict(card, identity_policy) -> Dictionary:
    if identity_policy == null or not identity_policy.has_method("resolve"):
        return {}
    var resolved: Dictionary = identity_policy.resolve(card, {})
    return resolved["facts"].to_dict() if resolved.get("success", false) else {}

func _resolve_preview_intent(side, target, intent: Dictionary) -> Dictionary:
    var result := intent.duplicate(true)
    if battle_rule_query_service == null:
        return {"success": true, "intent": result}
    var damage := maxi(0, int(result.get("damage", 0)))
    if damage > 0 and target != null:
        for stage in [
                ["outgoing_damage_query", side],
                ["incoming_damage_query", target]]:
            var damage_query = battle_rule_query_service.resolve_values({
                "hook": stage[0], "owner": stage[1],
                "actor": side, "target": target,
                "subject_kind": "damage_preview", "subject_id": "preview",
                "base_value": damage,
                "round_number": int(round_number_reader.call()) \
                    if round_number_reader.is_valid() else 0,
                "source_kind": "preview",
            })
            if not damage_query.success:
                return {"success": false, "reason": "；".join(damage_query.errors)}
            damage = maxi(0, damage_query.effective_value)
        result["damage"] = damage
    var defense := maxi(0, int(result.get("defense", 0)))
    if defense > 0:
        var defense_query = battle_rule_query_service.resolve_values({
            "hook": "defense_gain_query", "owner": side,
            "actor": side, "target": target,
            "subject_kind": "defense_preview", "subject_id": "preview",
            "base_value": defense,
            "round_number": int(round_number_reader.call()) \
                if round_number_reader.is_valid() else 0,
            "source_kind": "preview",
        })
        if not defense_query.success:
            return {"success": false, "reason": "；".join(defense_query.errors)}
        result["defense"] = maxi(0, defense_query.effective_value)
    return {"success": true, "intent": result}

func _invalid_preview(reason: String):
    return ActionPreviewDtoScript.new().configure({
        "valid": false,
        "reason": reason,
    })

static func _card_has_attribute(card, attribute: String, identity_policy = null) -> bool:
    if identity_policy != null and identity_policy.has_method("resolve"):
        var resolved: Dictionary = identity_policy.resolve(card, {})
        if resolved.get("success", false):
            return bool(resolved["facts"].has_attribute(attribute))
    return card.is_attribute(attribute)

func _inner_skill_definitions_for(side) -> Array:
    var definitions: Array = []
    for entry in passive_rule_runtime.equipped_inner_skill_entries({"owner": side}):
        var definition: Dictionary = entry["definition"]
        if not definition.is_empty():
            definitions.append(definition)
    return definitions

func _merge_intent(target_intent: Dictionary, addition: Dictionary) -> void:
    for key in ["damage", "defense", "segments"]:
        target_intent[key] = int(target_intent.get(key, 0)) + int(addition.get(key, 0))
    target_intent["technique_combo"] = (
        bool(target_intent.get("technique_combo", false))
        or bool(addition.get("technique_combo", false)))
