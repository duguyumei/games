class_name CardCollectionConsumableHandler
extends "res://core/consumables/consumable_effect_handler.gd"

## 本局牌组集合操作。实例 ID 已由 ConsumableUseService 解析；真实增删与完整
## 复制规则继续委托 CardWorkshopService / RunDeck。

func operation_ids() -> Array[String]:
	return ["remove_run_cards", "copy_run_card"]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	var op := str(effect.get("op", ""))
	if op == "copy_run_card":
		var count = effect.get("count")
		if not _is_positive_integer(count):
			context.report_error(scope + ".count", "必须是正整数")

func eligible_targets(
		_effect: Dictionary,
		_context,
		candidates: Array) -> Array:
	return candidates.duplicate(true)

func apply(effect: Dictionary, context) -> Dictionary:
	match str(effect.get("op", "")):
		"remove_run_cards":
			return _remove(context)
		"copy_run_card":
			return _copy(effect, context)
	return {"success": false, "reason": "不支持的本局牌组操作"}

func _remove(context) -> Dictionary:
	if context.instance_ids.is_empty():
		return {"success": false, "reason": "移出效果需要至少一个目标真气"}
	var result: Dictionary = context.remove_run_cards(context.instance_ids)
	if not result.get("success", false):
		return result
	return {
		"success": true,
		"applied": {
			"op": "remove_run_cards",
			"count": result.get("removed", []).size(),
			"removed": result.get("removed", []).duplicate(true),
			"count_before": int(result.get("count_before", 0)),
			"count_after": int(result.get("count_after", 0)),
			"details": ["永久移出 %d 张本局真气" % result.get("removed", []).size()],
		},
	}

func _copy(effect: Dictionary, context) -> Dictionary:
	if context.instance_ids.size() != 1:
		return {"success": false, "reason": "完整复制需要且只能选择一个目标真气"}
	var source_id := str(context.instance_ids[0])
	var count := int(effect.get("count", 1))
	var source_before: Dictionary = context.card_data(source_id).duplicate(true)
	var result: Dictionary = context.copy_run_card(source_id, count)
	if not result.get("success", false):
		return result
	return {
		"success": true,
		"applied": {
			"op": "copy_run_card",
			"source_instance_id": source_id,
			"source": source_before,
			"instance_ids": result.get("instance_ids", []).duplicate(),
			"count": count,
			"count_before": int(result.get("count_before", 0)),
			"count_after": int(result.get("count_after", 0)),
			"details": ["完整复制 %d 张真气" % count],
		},
	}

func _is_positive_integer(value) -> bool:
	return (value is int or value is float) \
		and float(value) == floor(float(value)) and int(value) > 0
