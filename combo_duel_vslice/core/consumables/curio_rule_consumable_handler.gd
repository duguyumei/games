class_name CurioRuleConsumableHandler
extends "res://core/consumables/consumable_effect_handler.gd"

const HAND_IDS := ["high_card", "pair", "two_pair", "three_kind", "straight", "full_house", "four_kind", "five_kind"]

func operation_ids() -> Array[String]:
	return [
		"set_experience",
		"remove_run_cards_for_experience",
		"rewrite_technique_progression",
		"apply_origin_to_matching_rank",
		"modify_base_hand_limit",
	]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	match str(effect.get("op", "")):
		"set_experience":
			if not _is_nonnegative_integer(effect.get("amount")):
				context.report_error(scope + ".amount", "必须是非负整数")
		"remove_run_cards_for_experience":
			if not _is_nonnegative_integer(effect.get("experience_per_card")):
				context.report_error(scope + ".experience_per_card", "必须是非负整数")
		"rewrite_technique_progression":
			if not effect.get("modifiers", {}) is Dictionary:
				context.report_error(scope + ".modifiers", "必须是对象")
			elif int(effect.get("slot_delta", 0)) >= 0:
				context.report_error(scope + ".slot_delta", "必须是负数")
		"apply_origin_to_matching_rank":
			pass
		"modify_base_hand_limit":
			if not _is_integer(effect.get("delta")):
				context.report_error(scope + ".delta", "必须是整数")

func query_availability(effect: Dictionary, context) -> Dictionary:
	match str(effect.get("op", "")):
		"remove_run_cards_for_experience":
			return {"can_use": not context.instance_ids.is_empty() or context.growth.run_deck.card_count() > 0, "reason": "本局没有可移出的真气"}
		"apply_origin_to_matching_rank":
			for values in context.growth.run_deck.cards_snapshot():
				if ["2", "3", "4", "5"].has(str(values.get("rank_name", ""))) \
						and values.get("reshapes", {}).get("origin", {}).is_empty():
					return {"can_use": true, "reason": ""}
			return {"can_use": false, "reason": "选择牌阶没有尚未觉醒的合格真气"}
		"rewrite_technique_progression":
			return {"can_use": true, "reason": ""}
	return {"can_use": true, "reason": ""}

func eligible_targets(effect: Dictionary, _context, candidates: Array) -> Array:
	if str(effect.get("op", "")) != "apply_origin_to_matching_rank":
		return candidates.duplicate(true)
	var result: Array = []
	for candidate in candidates:
		if candidate is Dictionary \
				and ["2", "3", "4", "5"].has(str(candidate.get("rank", ""))) \
				and candidate.get("origin", {}).is_empty():
			result.append(candidate.duplicate(true))
	return result

func apply(effect: Dictionary, context) -> Dictionary:
	match str(effect.get("op", "")):
		"set_experience":
			var before := int(context.growth.experience)
			context.growth.experience = int(effect.get("amount", 0))
			return _applied("set_experience", {"experience_before": before, "experience_after": context.growth.experience})
		"remove_run_cards_for_experience":
			return _remove_for_experience(effect, context)
		"rewrite_technique_progression":
			return _rewrite(effect, context)
		"apply_origin_to_matching_rank":
			return _matching_rank(effect, context)
		"modify_base_hand_limit":
			var result: Dictionary = context.apply_base_hand_limit_modifier(int(effect.get("delta", 0)))
			if not result.get("success", false):
				return result
			return _applied("modify_base_hand_limit", result)
	return {"success": false, "reason": "不支持的奇珍规则操作"}

func _remove_for_experience(effect: Dictionary, context) -> Dictionary:
	var selected: Array = context.instance_ids.duplicate()
	if selected.is_empty():
		return {"success": false, "reason": "焚元祭没有可移出的真气"}
	var result: Dictionary = context.remove_run_cards(selected)
	if not result.get("success", false):
		return result
	var amount: int = result.get("removed", []).size() * int(effect.get("experience_per_card", 0))
	var before := int(context.growth.experience)
	context.growth.experience = before + amount
	return _applied("remove_run_cards_for_experience", {
		"removed": result.get("removed", []).duplicate(true),
		"experience_gained": amount,
		"experience_before": before,
		"experience_after": context.growth.experience,
	})

func _rewrite(effect: Dictionary, context) -> Dictionary:
	var result: Dictionary = context.rewrite_technique_progression(
		context.metadata.get("choice_payload", {}),
		int(effect.get("slot_delta", 0)), effect.get("modifiers", {}))
	if not result.get("success", false):
		return result
	return _applied("rewrite_technique_progression", result)

func _matching_rank(effect: Dictionary, context) -> Dictionary:
	if context.instance_ids.is_empty():
		return {"success": false, "reason": "选择牌阶没有合格真气"}
	var result: Dictionary = context.apply_origin(
		context.instance_ids, "awakening", {})
	if not result.get("success", false):
		return result
	return _applied("apply_origin_to_matching_rank", {
		"rank": str(context.metadata.get("choice_payload", {}).get("rank", "")),
		"targets": result.get("changed", []).duplicate(true),
		"count": result.get("changed", []).size(),
	})

func _applied(op: String, details: Dictionary) -> Dictionary:
	details["op"] = op
	details["details"] = [op]
	return {"success": true, "applied": details}

func _is_integer(value) -> bool:
	return value is int or (value is float and value == floor(value))

func _is_nonnegative_integer(value) -> bool:
	return _is_integer(value) and int(value) >= 0
