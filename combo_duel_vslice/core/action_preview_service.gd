class_name ActionPreviewService
extends RefCounted

## 行动提案的纯预览服务。
##
## 这里组合牌型、功法与内功修正，产出可展示的结算预览；故意不移动牌区、
## 推进功法序列或写入战斗状态，真实提交仍由 BattleActionService 负责。

const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")
const EffectContextScript = preload("res://core/effects/battle_effect_context.gd")
const ActionPreviewDtoScript = preload("res://core/action_preview_dto.gd")
const SameQiRuleScript = preload("res://core/same_qi_rule.gd")
const HandGroupSnapshotScript = preload("res://core/hand_group_snapshot.gd")

var technique_repository
var passive_rule_runtime
var effect_executor
var battle_rule_query_service
var battle_permission_service
var same_qi_gauge_service
var technique_resolution_service
var round_number_reader: Callable

func _init(
        techniques,
        passive_runtime,
        executor,
        query_service = null,
        round_reader: Callable = Callable(),
        permission_service = null,
        gauge_service = null,
        resolution_service = null) -> void:
    technique_repository = techniques
    passive_rule_runtime = passive_runtime
    effect_executor = executor
    battle_rule_query_service = query_service
    round_number_reader = round_reader
    battle_permission_service = permission_service
    same_qi_gauge_service = gauge_service
    technique_resolution_service = resolution_service

func preview(
        side,
        card_ids: Array,
        sequence_book,
        modifiers_by_hand: Dictionary = {},
        target = null) -> Dictionary:
    return preview_dto(
        side,
        card_ids,
        sequence_book,
        modifiers_by_hand,
        target).to_dict()

func preview_dto(
        side,
        card_ids: Array,
        sequence_book,
        modifiers_by_hand: Dictionary = {},
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

    var same_qi_group: Dictionary = SameQiRuleScript.analyze(
        cards,
        side.card_identity_policy,
        {"owner": side, "actor": side, "target": target})
    if not same_qi_group.get("success", false):
        return _invalid_preview(str(same_qi_group.get(
            "reason", "同气身份查询失败")))

    var modifiers: Dictionary = modifiers_by_hand.get(hand_result["id"], {}).duplicate(true)
    modifiers["multiplier_bonus"] = (
        int(modifiers.get("multiplier_bonus", 0))
        + int(side.hand_technique_multiplier_modifiers.get(
            hand_result["id"], 0)))
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
    var momentum_cap_query: Dictionary = side.peek_effective_momentum_cap_result({
        "actor": side,
        "target": target,
        "round_number": int(round_number_reader.call()) \
            if round_number_reader.is_valid() else 0,
        "source_kind": "action_preview",
    })
    if not momentum_cap_query.get("success", false):
        return _invalid_preview("momentum_cap_query：%s" % "；".join(
            momentum_cap_query.get("errors", [])))
    var technique_slot: Dictionary = sequence_book.current_slot(hand_result["id"])
    var technique_id: String = str(technique_slot.get("technique_id", ""))
    var technique_definition = technique_repository.get_definition(technique_id)
    var technique: Dictionary = (
        technique_definition.to_definition()
        if technique_definition != null else {})
    var group_snapshot := HandGroupSnapshotScript.freeze(
        cards, hand_result, side, target, [],
        power_result.get("effective_qi_queries", {}))
    var condition := {"ok": true, "reason": "空序列"}
    if technique_definition != null:
        condition = technique_repository.conditions_met(
            technique_definition,
            hand_result,
            side.card_identity_policy,
            bool(technique_slot.get("host_sequence_qualified", false)))
    var technique_activation := _preview_technique_activation(
        side, target, technique_id, hand_result, cards,
        technique_definition, condition,
        bool(technique_slot.get("host_sequence_qualified", false)))
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
        "source_kind": "technique",
        "source_id": str(technique.get("id", "")),
        "source_name": str(technique.get("name", "")),
        "source_instance_key": "technique:%s" % str(technique.get("id", "")),
        "trigger_mode": "manual",
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

    var excluded_ids: Array[String] = []
    for card in cards:
        excluded_ids.append(str(card.id))
    var same_qi_projection := _same_qi_projection(
        side, int(same_qi_group.get("gain", 0)), excluded_ids, target)
    if not same_qi_projection.get("success", false):
        return _invalid_preview(str(same_qi_projection.get(
            "reason", "同气槽容量查询失败")))
    intent["combo"] = (
        int(same_qi_projection.get("same_qi_trigger_count", 0)) > 0
        or bool(intent.get("technique_combo", false)))
    intent["same_qi_gain"] = int(same_qi_projection["same_qi_gain"])
    intent["same_qi_trigger_count"] = int(
        same_qi_projection["same_qi_trigger_count"])
    var next_technique_slot: Dictionary = sequence_book.next_slot(hand_result["id"])
    var next_technique_id: String = str(next_technique_slot.get("technique_id", ""))
    return ActionPreviewDtoScript.new().configure({
        "valid": true,
        "cards": cards,
        "hand": hand_result,
        "values": values,
        "momentum_cap": int(momentum_cap_query.get("effective_value", 0)),
        "passive_power_query_inputs": {
            "modifiers": modifiers,
            "queries": power_result["queries"],
            "effective_qi_source_snapshot": power_result.get(
                "effective_qi_source_snapshot", []),
        },
        "same_qi": same_qi_group.duplicate(true),
        "same_qi_group": same_qi_group,
        "same_qi_gain": int(same_qi_projection["same_qi_gain"]),
        "same_qi_before": int(same_qi_projection["same_qi_before"]),
        "same_qi_capacity": int(same_qi_projection["same_qi_capacity"]),
        "same_qi_after": int(same_qi_projection["same_qi_after"]),
        "same_qi_trigger_count": int(
            same_qi_projection["same_qi_trigger_count"]),
        "group_snapshot": group_snapshot,
        "technique_id": technique_id,
        "slot_instance_id": str(technique_slot.get("slot_instance_id", "")),
        "technique_slot": technique_slot,
        "technique": technique,
        "condition": condition,
        "technique_activation": technique_activation,
        "cooperation": technique.get("cooperation", {}).duplicate(true) \
            if activation_allowed else {},
        "intent": intent,
        "inner_skills": _inner_skill_definitions_for(side),
        "next_technique_id": next_technique_id,
        "next_slot_instance_id": str(next_technique_slot.get("slot_instance_id", "")),
        "next_technique": technique_repository.get_technique(next_technique_id),
    })

func _preview_technique_activation(
        side,
        target,
        technique_id: String,
        hand_result: Dictionary,
        cards: Array,
        technique_definition,
        condition: Dictionary,
        host_sequence_qualified: bool) -> Dictionary:
    return technique_resolution_service.prepare_activation(
        technique_definition, side, target, hand_result, cards,
        str(hand_result.get("id", "")), "", "preview", true,
        condition, host_sequence_qualified,
        int(round_number_reader.call()) \
            if round_number_reader.is_valid() else 0)

func recalculate_confirmed_power(
        side,
        target,
        preview: Dictionary,
        action_token: String,
        frozen_multiplier_bonus: int = 0) -> Dictionary:
    var inputs: Dictionary = preview.get(
        "passive_power_query_inputs", {})
    var modifiers: Dictionary = inputs.get("modifiers", {}).duplicate(true)
    modifiers["multiplier_bonus"] = (
        int(modifiers.get("multiplier_bonus", 0)) + frozen_multiplier_bonus)
    var pending_sources: Array = side.pending_power_fixed_sources.duplicate(true)
    var pending_total := 0
    var pending_tokens: Array[String] = []
    for source in pending_sources:
        pending_total += int(source.get("amount", 0))
        pending_tokens.append(str(source.get("source_token", "")))
    modifiers["power_fixed"] = int(modifiers.get("power_fixed", 0)) + pending_total
    modifiers["power_fixed"] = int(modifiers.get("power_fixed", 0)) + int(
        preview.get("action_confirmation_power_fixed", 0))
    preview["pending_power_fixed_tokens"] = pending_tokens
    preview["pending_power_fixed_amount"] = pending_total
    var result := _resolve_power_values(
        side, target, preview.get("hand", {}), preview.get("cards", []),
        modifiers, action_token, "action_confirmed",
        inputs.get("effective_qi_source_snapshot", []))
    if result.get("success", false):
        preview["group_snapshot"] = HandGroupSnapshotScript.freeze(
            preview.get("cards", []), preview.get("hand", {}), side, target,
            [], result.get("effective_qi_queries", {}))
        preview["values"] = result["values"]
        preview["group_snapshot"]["card_contribution"] = int(
            preview["values"].get("card_total", 0))
        preview["values"]["card_multiplier_bonus"] = (
            int(preview["values"].get("card_multiplier_bonus", 0))
            + frozen_multiplier_bonus)
        preview["values"]["frozen_card_multiplier_bonus"] = frozen_multiplier_bonus
        preview["values"]["passive_power_queries"] = result["queries"]
        preview["passive_power_query_inputs"]["confirmed_queries"] = result["queries"]
        preview["passive_power_query_inputs"]["confirmed_action_token"] = action_token
        var frozen_same_qi := SameQiRuleScript.analyze(
            preview.get("cards", []), side.card_identity_policy, {
                "owner": side, "actor": side, "target": target,
                "action_token": action_token,
            })
        if not frozen_same_qi.get("success", false):
            return frozen_same_qi
        frozen_same_qi["frozen"] = true
        frozen_same_qi["action_token"] = action_token
        preview["same_qi_group"] = frozen_same_qi.duplicate(true)
        preview["same_qi"] = frozen_same_qi.duplicate(true)
        var projection := _same_qi_projection(
            side, int(frozen_same_qi.get("gain", 0)), [], target,
            action_token)
        if not projection.get("success", false):
            return projection
        _write_same_qi_projection(preview, projection)
        _apply_technique_power_formation(side, target, preview)
    return result

func _same_qi_projection(
        side,
        gain: int,
        excluded_ids: Array[String],
        target = null,
        action_token: String = "") -> Dictionary:
    if same_qi_gauge_service == null:
        return {
            "success": true,
            "same_qi_gain": gain,
            "same_qi_before": int(side.same_qi_value),
            "same_qi_capacity": 5,
            "same_qi_after": int(side.same_qi_value) + gain,
            "same_qi_trigger_count": 0,
        }
    var legal_after := false
    for card in side.hand:
        if excluded_ids.has(str(card.id)):
            continue
        if side.status_system == null or bool(
                side.status_system.can_play_card(side, card).get("allowed", false)):
            legal_after = true
            break
    return same_qi_gauge_service.project_gain(side, gain, {
        "target": target,
        "round_number": int(round_number_reader.call()) \
            if round_number_reader.is_valid() else 0,
        "action_token": action_token,
        "source_kind": "action_confirmed" if action_token != "" else "preview",
        "legal_card_available": legal_after,
    })

func _write_same_qi_projection(preview: Dictionary, projection: Dictionary) -> void:
    for field in [
            "same_qi_gain", "same_qi_before", "same_qi_capacity",
            "same_qi_after", "same_qi_trigger_count"]:
        preview[field] = int(projection.get(field, 0))
    preview["intent"]["combo"] = (
        int(preview["same_qi_trigger_count"]) > 0
        or bool(preview["intent"].get("technique_combo", false)))
    preview["intent"]["same_qi_gain"] = int(preview["same_qi_gain"])
    preview["intent"]["same_qi_trigger_count"] = int(
        preview["same_qi_trigger_count"])

func _apply_technique_power_formation(side, target, preview: Dictionary) -> void:
    if preview.has("frozen_power_formation"):
        var frozen: Dictionary = preview["frozen_power_formation"]
        preview["values"] = PowerCalculatorScript.apply_direct_power_fixed(
            preview["values"], int(frozen.get("fixed_bonus", 0)))
        return
    var definition: Dictionary = preview.get("technique", {})
    var formation: Dictionary = definition.get("power_formation", {})
    var kind := str(formation.get("kind", ""))
    if kind == "pre_momentum_consume":
        var cost := maxi(0, int(formation.get("cost", 0)))
        var eligible := cost > 0 and int(side.momentum_value) >= cost
        var selected := eligible and bool(preview.get(
            "power_formation_choice",
            formation.get("default_consume", true)))
        var fixed_bonus := 0
        if selected:
            match str(formation.get("fixed_bonus_kind", "none")):
                "card_contribution_multiplier":
                    fixed_bonus = int(preview.get("values", {}).get(
                        "card_total", 0)) * int(formation.get("multiplier", 1))
        preview["frozen_power_formation"] = {
            "kind": kind,
            "fixed_bonus": fixed_bonus,
            "target_id": "",
            "momentum_cost": cost,
            "consume_requested": selected,
            "consume_receipt": {},
        }
        preview["group_snapshot"]["pre_momentum_consume_selected"] = selected
        preview["values"] = PowerCalculatorScript.apply_direct_power_fixed(
            preview["values"], fixed_bonus)
        return
    if kind == "unburned_contributing_effective_qi":
        var total := 0
        for card in preview.get("group_snapshot", {}).get(
                "contributing_cards", []):
            if not card.has_anomaly("debuff", "burned_out"):
                total += HandGroupSnapshotScript.frozen_effective_qi(
                    preview.get("group_snapshot", {}), card)
        var fixed_bonus := total * int(formation.get("multiplier", 1))
        preview["frozen_power_formation"] = {
            "kind": kind, "fixed_bonus": fixed_bonus, "target_id": "",
            "frozen_value": total,
        }
        preview["group_snapshot"]["power_formation_frozen_value"] = total
        preview["values"] = PowerCalculatorScript.apply_direct_power_fixed(
            preview["values"], fixed_bonus)
        return
    if kind != "random_extra_current_qi":
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
    var bonus := HandGroupSnapshotScript.frozen_effective_qi(snapshot, chosen) \
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

func commit_power_formation(side, preview: Dictionary) -> Dictionary:
    var frozen: Dictionary = preview.get("frozen_power_formation", {})
    if str(frozen.get("kind", "")) != "pre_momentum_consume" \
            or not bool(frozen.get("consume_requested", false)):
        return {"success": true, "changed": false, "receipt": {}}
    if not frozen.get("consume_receipt", {}).is_empty():
        return {
            "success": true, "changed": true,
            "receipt": frozen["consume_receipt"].duplicate(true), "reused": true,
        }
    var receipt: Dictionary = side.write_momentum(
        "consume", int(frozen.get("momentum_cost", 0)),
        "power_formation", str(preview.get("reshape_action_token", "")),
        str(preview.get("technique_id", "")))
    if not receipt.get("success", false):
        return {"success": false, "reason": "确认期连势不足，前置消费失败"}
    frozen["consume_receipt"] = receipt.duplicate(true)
    preview["frozen_power_formation"] = frozen
    preview["momentum_consume_receipt"] = receipt.duplicate(true)
    return {"success": true, "changed": true, "receipt": receipt}

func rollback_power_formation(side, preview: Dictionary) -> bool:
    var receipt: Dictionary = preview.get("momentum_consume_receipt", {})
    if receipt.is_empty():
        return false
    var rolled_back: bool = side.rollback_momentum_receipt(receipt)
    if rolled_back:
        preview.erase("momentum_consume_receipt")
        var frozen: Dictionary = preview.get("frozen_power_formation", {})
        frozen["consume_receipt"] = {}
        preview["frozen_power_formation"] = frozen
    return rolled_back

func _resolve_power_values(
        side,
        target,
        hand_result: Dictionary,
        cards: Array,
        modifiers: Dictionary,
        action_token: String,
        source_kind: String,
        effective_qi_source_snapshot: Array = []) -> Dictionary:
    var effective := modifiers.duplicate(true)
    var details: Dictionary = {}
    var effective_input := _resolve_effective_qi_inputs(
        side, target, hand_result, cards, action_token, source_kind,
        effective_qi_source_snapshot)
    if not effective_input.get("success", false):
        return effective_input
    var source_snapshot: Array = effective_input.get("source_snapshot", [])
    var effective_qi_queries: Dictionary = effective_input.get("queries", {})
    var effective_qi_values: Dictionary = effective_input.get("values", {})
    var participating_ids: Array = effective_input.get("participating_ids", [])
    var query_card_facts := _card_facts(
        cards, side.card_identity_policy, effective_qi_values,
        side, target, participating_ids)
    var stages := [
        ["base_fixed", "power_base_fixed_query"],
        ["multiplier_bonus", "power_multiplier_bonus_query"],
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
            "card_facts": query_card_facts,
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
    var base_modifiers := effective.duplicate(true)
    base_modifiers["power_fixed"] = 0
    base_modifiers["power_amp_percent"] = 0
    var values := PowerCalculatorScript.calculate(
        hand_result,
        base_modifiers,
        Callable(),
        side.card_identity_policy,
        {"owner": side, "actor": side, "target": target},
        func(card): return int(effective_qi_values.get(str(card.id), 0)))
    var final_power: Dictionary = technique_resolution_service.resolve_power(
        side, target, hand_result, cards,
        int(values.get("initial_power", 0)), action_token, source_kind,
        false,
        int(effective.get("power_fixed", 0)),
        int(effective.get("power_amp_percent", 0)),
        int(values.get("card_amp_percent", 0)),
        false,
        int(round_number_reader.call()) \
            if round_number_reader.is_valid() else 0,
        query_card_facts)
    if not final_power.get("success", false):
        return final_power
    var resolved_values: Dictionary = final_power.get("values", {})
    for field in [
            "direct_power_fixed", "direct_power_percent",
            "pre_momentum_power", "momentum_used", "technique_value"]:
        values[field] = resolved_values.get(field, values.get(field, 0))
    details.merge(final_power.get("queries", {}), true)
    values["passive_power_queries"] = details.duplicate(true)
    values["effective_qi_queries"] = effective_qi_queries.duplicate(true)
    return {
        "success": true, "values": values, "queries": details,
        "effective_qi_queries": effective_qi_queries,
        "effective_qi_source_snapshot": source_snapshot,
    }

func _resolve_effective_qi_inputs(
        side, target, hand_result: Dictionary, cards: Array,
        action_token: String, source_kind: String,
        provided_source_snapshot: Array) -> Dictionary:
    var source_snapshot := provided_source_snapshot.duplicate(true)
    if source_snapshot.is_empty() and battle_rule_query_service != null \
            and source_kind != "action_confirmed":
        source_snapshot = battle_rule_query_service.capture_source_snapshot(
            side, {"actor": side, "target": target})
    var queries: Dictionary = {}
    var values: Dictionary = {}
    var participating: Array = hand_result.get(
        "numeric_contributing", hand_result.get("contributing", []))
    var participating_ids: Array = participating.map(
        func(card): return str(card.id))
    for card in cards:
        if battle_rule_query_service == null:
            var base_value := int(card.effective_qi_value(
                false, {"participating": participating_ids.has(str(card.id))}))
            queries[str(card.id)] = {
                "success": true, "base_value": base_value,
                "effective_value": base_value, "source_breakdown": [],
                "fingerprint": "", "request_fingerprint": "",
            }
            values[str(card.id)] = base_value
            continue
        var query = battle_rule_query_service.resolve_effective_qi(side, card, {
            "actor": side, "target": target,
            "purpose": "power_calculation",
            "evaluation_mode": "confirm" if action_token != "" else "preview",
            "cards": cards,
            "participating_card_ids": participating_ids,
            "hand_result": hand_result,
            "action_token": action_token,
            "round_number": int(round_number_reader.call()) \
                if round_number_reader.is_valid() else 0,
            "source_kind": source_kind,
            "source_snapshot": source_snapshot,
        })
        if not query.success:
            battle_rule_query_service.report_failure(
                query, "action_power_effective_qi")
            return {
                "success": false,
                "reason": "effective_qi_query：%s" % "；".join(query.errors),
            }
        queries[str(card.id)] = query.to_dict()
        values[str(card.id)] = int(query.effective_value)
    return {
        "success": true,
        "source_snapshot": source_snapshot,
        "queries": queries,
        "values": values,
        "participating_ids": participating_ids,
    }

func _card_facts(
        cards: Array, identity_policy = null,
        effective_qi_values: Dictionary = {}, owner = null, target = null,
        participating_ids: Array = []) -> Array:
    var result: Array = []
    for card in cards:
        var attributes: Array[String] = []
        for attribute in ["wind", "forest", "fire", "mountain"]:
            if _card_has_attribute(card, attribute, identity_policy):
                attributes.append(attribute)
        var fact: Dictionary = battle_rule_query_service.card_fact(
            card, owner, target, participating_ids.has(str(card.id))) \
            if battle_rule_query_service != null and owner != null else {
                "instance_id": str(card.id),
                "definition_id": str(card.current_definition_id()) \
                    if card.has_method("current_definition_id") \
                    else str(card.definition_id),
                "participating": participating_ids.has(str(card.id)),
            }
        fact["qi"] = int(effective_qi_values.get(str(card.id), 0))
        fact["effective_qi"] = int(effective_qi_values.get(str(card.id), 0))
        fact["attributes"] = attributes
        fact["identity"] = _card_identity_dict(card, identity_policy)
        result.append(fact)
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
