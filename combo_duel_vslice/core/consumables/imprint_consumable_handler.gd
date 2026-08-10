class_name ImprintConsumableHandler
extends "res://core/consumables/consumable_effect_handler.gd"

func operation_ids() -> Array[String]:
	return ["apply_imprint", "apply_random_imprint"]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	if str(effect.get("op", "")) == "apply_imprint":
		var imprint_id := str(effect.get("imprint", ""))
		if imprint_id == "":
			context.report_error(scope + ".imprint", "必须是非空字符串")
		elif context.has_method("has_content_id") \
				and not context.has_content_id("imprint", imprint_id):
			context.report_error(scope + ".imprint", "引用未知印记 %s" % imprint_id)
	if effect.has("only_if_empty") and not effect.get("only_if_empty") is bool:
		context.report_error(scope + ".only_if_empty", "必须是布尔值")

func query_availability(_effect: Dictionary, context) -> Dictionary:
	if context.formal_imprint_ids().is_empty():
		return {"can_use": false, "reason": "当前没有正式印记候选"}
	return {"can_use": true, "reason": ""}

func apply(effect: Dictionary, context) -> Dictionary:
	var candidates: Array[String] = context.formal_imprint_ids()
	if candidates.is_empty():
		return {"success": false, "reason": "当前没有正式印记候选"}
	var imprint_id := str(effect.get("imprint", ""))
	if str(effect.get("op", "")) == "apply_random_imprint":
		if context.rng == null:
			return {"success": false, "reason": "随机印记缺少确定性 RNG"}
		imprint_id = candidates[context.rng.randi_range(0, candidates.size() - 1)]
	if context.instance_ids.is_empty():
		return {"success": false, "reason": "印记效果需要至少一个目标真气"}
	var targets: Array = []
	for instance_id in context.instance_ids:
		var before: Dictionary = context.card_data(str(instance_id)).get("reshapes", {}).duplicate(true)
		if bool(effect.get("only_if_empty", false)) and str(before.get("imprint", "")) != "":
			continue
		var result: Dictionary = context.apply_imprint(str(instance_id), imprint_id)
		if not result.get("success", false):
			return result
		targets.append({
			"instance_id": str(instance_id),
			"imprint": imprint_id,
			"before": before,
			"after": result.get("after", {}).duplicate(true),
		})
	if targets.is_empty():
		return {
			"success": true,
			"applied": {
				"op": str(effect.get("op", "")),
				"imprint": "",
				"targets": [],
				"count": 0,
				"details": ["目标已有印记，保持不变"],
			},
		}
	return {
		"success": true,
		"applied": {
			"op": str(effect.get("op", "")),
			"imprint": imprint_id,
			"targets": targets,
			"count": targets.size(),
			"details": ["%d 张真气获得%s" % [targets.size(), imprint_id]],
		},
	}
