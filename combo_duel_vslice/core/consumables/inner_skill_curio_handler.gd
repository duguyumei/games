class_name InnerSkillCurioHandler
extends "res://core/consumables/consumable_effect_handler.gd"

func operation_ids() -> Array[String]:
	return ["duplicate_equipped_inner_skill"]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	if effect.has("count") and not _is_one(effect.get("count")):
		context.report_error(scope + ".count", "当前协议只能复制一门")

func query_availability(effect: Dictionary, context) -> Dictionary:
	return {"can_use": not context.growth.equipped_inner_skill_ids.is_empty(), "reason": "当前没有已装备内功"}

func apply(effect: Dictionary, context) -> Dictionary:
	return _duplicate(context)

func _duplicate(context) -> Dictionary:
	var equipped: Array = context.growth.equipped_inner_skill_ids.duplicate()
	equipped.sort()
	if equipped.is_empty() or context.rng == null:
		return {"success": false, "reason": "当前没有已装备内功或确定性 RNG"}
	var selected: String = str(equipped[context.rng.randi_range(0, equipped.size() - 1)])
	var result: Dictionary = context.duplicate_equipped_inner_skill(selected)
	if not result.get("success", false):
		return result
	context.growth.learned_inner_skill_ids.clear()
	context.growth.learned_inner_skill_ids.append(selected)
	context.growth.learned_inner_skill_ids.append(selected)
	context.growth.equipped_inner_skill_ids.clear()
	context.growth.equipped_inner_skill_ids.append(selected)
	context.growth.equipped_inner_skill_ids.append(selected)
	context.growth.technique_slot_index = mini(context.growth.technique_slot_index, 2)
	return {
		"success": true,
		"applied": {"op": "duplicate_equipped_inner_skill", "inner_skill_id": selected, "learned_inner_skill_ids": [selected, selected], "equipped_inner_skill_ids": [selected, selected], "details": ["一脉真传保留内功双副本：%s" % selected]},
	}

func _is_one(value) -> bool:
	return (value is int or value is float) and float(value) == 1.0
