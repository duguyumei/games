class_name ConsumableGrantHandler
extends "res://core/consumables/consumable_effect_handler.gd"

## 生成随机正式消耗品或最近一次可溯忆消耗品。容量读取事务上下文，因此
## 当前正在使用的消耗品可以预留其成功提交后释放的一个栏位。

const ALLOWED_KINDS := ["insight", "pill"]

func operation_ids() -> Array[String]:
	return ["grant_random_consumables", "grant_last_used_consumable"]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	match str(effect.get("op", "")):
		"grant_random_consumables":
			var kind := str(effect.get("kind", ""))
			if not ALLOWED_KINDS.has(kind):
				context.report_error(scope + ".kind", "只能为 insight 或 pill")
			elif context.has_method("content_ids_by_kind") \
					and context.content_ids_by_kind("consumable", kind).is_empty():
				context.report_error(scope + ".kind", "没有对应正式消耗品候选")
			var maximum = effect.get("maximum")
			if not _is_positive_integer(maximum):
				context.report_error(scope + ".maximum", "必须是正整数")
			if effect.has("exclude_current") \
					and not effect.get("exclude_current") is bool:
				context.report_error(scope + ".exclude_current", "必须是布尔值")

func query_availability(effect: Dictionary, context) -> Dictionary:
	if context.growth == null:
		return {"can_use": false, "reason": "成长库存不存在"}
	if context.growth.consumable_ids.size() >= context.consumable_capacity():
		return {"can_use": false, "reason": "共享消耗品栏已满"}
	var candidates: Array = _candidates(effect, context)
	if candidates.is_empty():
		return {"can_use": false, "reason": "当前没有合格消耗品候选"}
	return {"can_use": true, "reason": ""}

func apply(effect: Dictionary, context) -> Dictionary:
	match str(effect.get("op", "")):
		"grant_random_consumables":
			return _grant_random(effect, context)
		"grant_last_used_consumable":
			return _grant_last(context)
	return {"success": false, "reason": "不支持的消耗品生成操作"}

func _grant_random(effect: Dictionary, context) -> Dictionary:
	var candidates := _candidates(effect, context)
	if candidates.is_empty():
		return {"success": false, "reason": "当前没有合格消耗品候选"}
	if context.rng == null:
		return {"success": false, "reason": "随机生成缺少确定性 RNG"}
	var capacity := maxi(
		context.consumable_capacity() - context.growth.consumable_ids.size(), 0)
	var count: int = mini(int(effect.get("maximum", 1)), capacity)
	count = mini(count, candidates.size())
	if count <= 0:
		return {"success": false, "reason": "共享消耗品栏已满"}
	var granted: Array[String] = []
	for _index in range(count):
		var chosen_index: int = context.rng.randi_range(0, candidates.size() - 1)
		var consumable_id: String = str(candidates.pop_at(chosen_index))
		var result: Dictionary = context.add_consumable(consumable_id)
		if not result.get("success", false):
			return result
		granted.append(consumable_id)
	return {
		"success": true,
		"applied": {
			"op": "grant_random_consumables",
			"kind": str(effect.get("kind", "")),
			"consumable_ids": granted,
			"count": granted.size(),
			"details": ["随机获得 %d 份消耗品" % granted.size()],
		},
	}

func _grant_last(context) -> Dictionary:
	var consumable_id: String = context.last_recallable_consumable_id()
	if consumable_id == "":
		return {"success": false, "reason": "本局还没有可溯忆的消耗品使用记录"}
	if consumable_id == str(context.metadata.get("consumable_id", "")):
		return {"success": false, "reason": "最近使用记录不能是当前溯忆消耗品"}
	var candidates: Array[String] = context.consumable_candidates("pill")
	candidates.append_array(context.consumable_candidates("insight"))
	if not candidates.has(consumable_id):
		return {"success": false, "reason": "最近使用记录不再是合法丹药或心得"}
	var result: Dictionary = context.add_consumable(consumable_id)
	if not result.get("success", false):
		return result
	return {
		"success": true,
		"applied": {
			"op": "grant_last_used_consumable",
			"consumable_id": consumable_id,
			"count": 1,
			"details": ["溯忆获得最近使用的消耗品"],
		},
	}

func _candidates(effect: Dictionary, context) -> Array[String]:
	if str(effect.get("op", "")) == "grant_last_used_consumable":
		var last_id: String = context.last_recallable_consumable_id()
		if last_id == "" or last_id == str(context.metadata.get("consumable_id", "")):
			return []
		var recallable: Array[String] = context.consumable_candidates("pill")
		recallable.append_array(context.consumable_candidates("insight"))
		return [last_id] if recallable.has(last_id) else []
	var result: Array[String] = context.consumable_candidates(
		str(effect.get("kind", "")))
	if bool(effect.get("exclude_current", false)):
		result.erase(str(context.metadata.get("consumable_id", "")))
	result.sort()
	return result

func _is_positive_integer(value) -> bool:
	return (value is int or value is float) \
		and float(value) == floor(float(value)) and int(value) > 0
