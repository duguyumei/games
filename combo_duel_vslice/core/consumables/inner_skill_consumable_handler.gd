class_name InnerSkillConsumableHandler
extends "res://core/consumables/consumable_effect_handler.gd"

## 从统一 InnerSkillRepository 对应的内容目录索引中确定性获得一门尚未习得
## 的内功；只加入内功库，不自动装备。

func operation_ids() -> Array[String]:
	return ["grant_random_inner_skill"]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	if effect.has("count") and not _is_one(effect.get("count")):
		context.report_error(scope + ".count", "当前协议必须为 1")

func query_availability(_effect: Dictionary, context) -> Dictionary:
	if context.inner_skill_candidates().is_empty():
		return {"can_use": false, "reason": "当前没有尚未习得的内功候选"}
	return {"can_use": true, "reason": ""}

func apply(_effect: Dictionary, context) -> Dictionary:
	var candidates: Array[String] = context.inner_skill_candidates()
	candidates.sort()
	if candidates.is_empty():
		return {"success": false, "reason": "当前没有尚未习得的内功候选"}
	if context.rng == null:
		return {"success": false, "reason": "随机获得内功缺少确定性 RNG"}
	var inner_skill_id := candidates[
		context.rng.randi_range(0, candidates.size() - 1)]
	var result: Dictionary = context.add_inner_skill(inner_skill_id)
	if not result.get("success", false):
		return result
	return {
		"success": true,
		"applied": {
			"op": "grant_random_inner_skill",
			"inner_skill_id": inner_skill_id,
			"candidates": candidates.duplicate(),
			"automatically_equipped": false,
			"details": ["获得内功：%s" % inner_skill_id],
		},
	}

func _is_one(value) -> bool:
	return (value is int or value is float) \
		and float(value) == floor(float(value)) and int(value) == 1
