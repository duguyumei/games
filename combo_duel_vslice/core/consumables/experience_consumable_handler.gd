class_name ExperienceConsumableHandler
extends "res://core/consumables/consumable_effect_handler.gd"

## 历练经济操作。只读取工作副本当前历练或已装备内功定义，不遗忘、不卸下、
## 不修改装备栏位。

func operation_ids() -> Array[String]:
	return [
		"gain_experience_capped",
		"gain_equipped_inner_skill_forget_value",
	]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	var cap = effect.get("cap")
	if not _is_nonnegative_integer(cap):
		context.report_error(scope + ".cap", "必须是非负整数")

func apply(effect: Dictionary, context) -> Dictionary:
	if context.growth == null:
		return {"success": false, "reason": "成长库存不存在"}
	match str(effect.get("op", "")):
		"gain_experience_capped":
			return _gain_current(effect, context)
		"gain_equipped_inner_skill_forget_value":
			return _gain_equipped(effect, context)
	return {"success": false, "reason": "不支持的历练操作"}

func _gain_current(effect: Dictionary, context) -> Dictionary:
	var before := int(context.growth.experience)
	var amount := mini(before, int(effect.get("cap", 0)))
	context.growth.experience = before + amount
	return _result(str(effect.get("op", "")), before, amount, context.growth.experience)

func _gain_equipped(effect: Dictionary, context) -> Dictionary:
	var total := 0
	var sources: Array = []
	for definition in context.equipped_inner_skill_definitions():
		var value := _forget_value(definition)
		total += value
		sources.append({
			"inner_skill_id": str(definition.get("id", "")),
			"forget_value": value,
		})
	var before := int(context.growth.experience)
	var amount := mini(total, int(effect.get("cap", 0)))
	context.growth.experience = before + amount
	var result := _result(
		str(effect.get("op", "")), before, amount, context.growth.experience)
	result["applied"]["uncapped_amount"] = total
	result["applied"]["sources"] = sources
	return result

func _forget_value(definition: Dictionary) -> int:
	for field in ["forget_value", "forget_experience", "forget_yield"]:
		if definition.has(field):
			return maxi(int(definition.get(field, 0)), 0)
	return 0

func _result(op: String, before: int, amount: int, after: int) -> Dictionary:
	return {
		"success": true,
		"applied": {
			"op": op,
			"amount": amount,
			"experience_before": before,
			"experience_after": after,
			"details": ["获得 %d 点历练" % amount],
		},
	}

func _is_nonnegative_integer(value) -> bool:
	return (value is int or value is float) \
		and float(value) == floor(float(value)) and int(value) >= 0
