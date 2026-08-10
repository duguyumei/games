class_name RandomReshapeConsumableHandler
extends "res://core/consumables/consumable_effect_handler.gd"

## 从 card_states.json 的正式强化池确定性抽取。候选稳定排序，每张目标分别
## 消费一次同一事务 RNG；不在本 Handler 维护第二份强化 ID 表。

func operation_ids() -> Array[String]:
	return ["apply_random_enhancement"]

func validate_effect(_effect: Dictionary, _context, _scope: String) -> void:
	pass

func query_availability(_effect: Dictionary, context) -> Dictionary:
	if context.formal_enhancement_ids().is_empty():
		return {"can_use": false, "reason": "当前没有正式强化候选"}
	return {"can_use": true, "reason": ""}

func apply(_effect: Dictionary, context) -> Dictionary:
	if context.instance_ids.is_empty():
		return {"success": false, "reason": "随机强化需要至少一个目标真气"}
	var candidates: Array[String] = context.formal_enhancement_ids()
	candidates.sort()
	if candidates.is_empty():
		return {"success": false, "reason": "当前没有正式强化候选"}
	if context.rng == null:
		return {"success": false, "reason": "随机强化缺少确定性 RNG"}
	var targets: Array = []
	for instance_id in context.instance_ids:
		var enhancement_id := candidates[
			context.rng.randi_range(0, candidates.size() - 1)]
		var result: Dictionary = context.apply_enhancement(
			str(instance_id), enhancement_id)
		if not result.get("success", false):
			return result
		targets.append({
			"instance_id": str(instance_id),
			"enhancement": enhancement_id,
			"before": result.get("before", {}).duplicate(true),
			"after": result.get("after", {}).duplicate(true),
		})
	return {
		"success": true,
		"applied": {
			"op": "apply_random_enhancement",
			"candidates": candidates.duplicate(),
			"targets": targets,
			"count": targets.size(),
			"details": ["%d 张真气分别获得随机强化" % targets.size()],
		},
	}
