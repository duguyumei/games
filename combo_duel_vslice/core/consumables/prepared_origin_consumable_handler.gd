class_name PreparedOriginConsumableHandler
extends "res://core/consumables/consumable_effect_handler.gd"

func operation_ids() -> Array[String]:
	return ["apply_prepared_group_origin"]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	var origin := str(effect.get("origin", ""))
	if not ["attribute_change", "rank_change"].has(origin):
		context.report_error(scope + ".origin", "只能使用 attribute_change 或 rank_change")
	var pool = effect.get("pool", [])
	if not pool is Array or pool.is_empty():
		context.report_error(scope + ".pool", "必须是非空数组")
	elif origin == "attribute_change":
		for value in pool:
			if not context.legal_attribute_ids().has(str(value)):
				context.report_error(scope + ".pool", "引用未知基础属性 %s" % str(value))
	elif origin == "rank_change":
		for value in pool:
			if not context.legal_rank_ids().has(str(value)):
				context.report_error(scope + ".pool", "引用未知基础牌阶 %s" % str(value))

func eligible_targets(_effect: Dictionary, _context, candidates: Array) -> Array:
	var result: Array = []
	for candidate in candidates:
		if candidate is Dictionary and candidate.get("origin", {}).is_empty():
			result.append(candidate.duplicate(true))
	return result

func prepare(effect: Dictionary, context) -> Dictionary:
	var pool: Array = effect.get("pool", []).duplicate()
	pool.sort()
	if context.rng == null or pool.is_empty():
		return {"success": false, "reason": "预览缺少确定性 RNG 或候选池为空"}
	var chosen: String = str(pool[context.rng.randi_range(0, pool.size() - 1)])
	var payload: Dictionary = {"attribute": chosen} if str(effect.get("origin", "")) == "attribute_change" else {"target_rank": chosen}
	var preview_targets: Array = []
	for instance_id in context.instance_ids:
		var planned: Dictionary = context.preview_origin(str(instance_id), str(effect.get("origin", "")), payload)
		if not planned.get("success", false):
			return planned
		preview_targets.append({
			"instance_id": str(instance_id),
			"before": context.card_data(str(instance_id)).duplicate(true),
			"after": planned.get("after", {}).duplicate(true),
		})
	return {
		"success": true,
		"prepared": {
			"origin": str(effect.get("origin", "")),
			"payload": payload,
			"chosen": chosen,
			"targets": preview_targets,
		},
	}

func apply(effect: Dictionary, context) -> Dictionary:
	var prepared: Dictionary = context.metadata.get("prepared_effect", {})
	var payload: Dictionary = prepared.get("payload", {})
	if payload.is_empty():
		return {"success": false, "reason": "缺少已冻结的本源改造结果"}
	var result: Dictionary = context.apply_origin(
		context.instance_ids, str(effect.get("origin", "")), payload)
	if not result.get("success", false):
		return result
	return {
		"success": true,
		"applied": {
			"op": "apply_prepared_group_origin",
			"origin": str(effect.get("origin", "")),
			"payload": payload.duplicate(true),
			"targets": result.get("changed", []).duplicate(true),
			"count": result.get("changed", []).size(),
			"details": ["%d 张真气完成同一组本源改造" % result.get("changed", []).size()],
		},
	}
