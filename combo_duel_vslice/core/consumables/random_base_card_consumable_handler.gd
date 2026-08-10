class_name RandomBaseCardConsumableHandler
extends "res://core/consumables/consumable_effect_handler.gd"

func operation_ids() -> Array[String]:
	return ["generate_random_base_cards"]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	var count = effect.get("count")
	if not _is_positive_integer(count):
		context.report_error(scope + ".count", "必须是正整数")
	for field in ["rank_ids", "attribute_ids"]:
		if effect.has(field) and not effect.get(field) is Array:
			context.report_error(scope + "." + field, "必须是数组")
		elif effect.has(field):
			var legal: Array[String] = (
				context.legal_rank_ids()
				if field == "rank_ids" else context.legal_attribute_ids())
			for value in effect.get(field, []):
				if not legal.has(str(value)):
					context.report_error(scope + "." + field, "引用未知基础牌定义维度 %s" % str(value))
	if effect.has("random_enhancement") and not effect.get("random_enhancement") is bool:
		context.report_error(scope + ".random_enhancement", "必须是布尔值")

func query_availability(effect: Dictionary, context) -> Dictionary:
	var ids: Array[String] = context.base_card_definition_ids(
		effect.get("rank_ids", []), effect.get("attribute_ids", []))
	return {"can_use": not ids.is_empty(), "reason": "当前没有合格基础真气定义" if ids.is_empty() else ""}

func apply(effect: Dictionary, context) -> Dictionary:
	var candidates: Array[String] = context.base_card_definition_ids(
		effect.get("rank_ids", []), effect.get("attribute_ids", []))
	if candidates.is_empty() or context.rng == null:
		return {"success": false, "reason": "当前没有合格基础真气或确定性 RNG"}
	var generated: Array = []
	for _index in range(int(effect.get("count", 0))):
		var definition_id: String = str(candidates[context.rng.randi_range(0, candidates.size() - 1)])
		var added: Dictionary = context.add_run_card_by_definition(definition_id)
		if not added.get("success", false):
			return added
		var enhancement_id := ""
		if bool(effect.get("random_enhancement", false)):
			var enhancements: Array[String] = context.formal_enhancement_ids()
			if enhancements.is_empty():
				return {"success": false, "reason": "当前没有正式强化候选"}
			enhancement_id = enhancements[context.rng.randi_range(0, enhancements.size() - 1)]
			var reshape: Dictionary = context.apply_enhancement(
				str(added.get("instance_id", "")), enhancement_id)
			if not reshape.get("success", false):
				return reshape
		generated.append({
			"instance_id": str(added.get("instance_id", "")),
			"definition_id": definition_id,
			"enhancement": enhancement_id,
		})
	return {
		"success": true,
		"applied": {
			"op": "generate_random_base_cards",
			"generated": generated,
			"count": generated.size(),
			"details": ["生成 %d 张随机真元牌" % generated.size()],
		},
	}

func _is_positive_integer(value) -> bool:
	return (value is int or value is float) and float(value) == floor(float(value)) and int(value) > 0
