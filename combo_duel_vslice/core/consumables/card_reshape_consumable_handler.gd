class_name CardReshapeConsumableHandler
extends "res://core/consumables/consumable_effect_handler.gd"

## 丹药与奇珍的牌面重塑：apply_origin 与 apply_enhancement。
##
## 重塑规则全部委托 F1C 的 CardWorkshopService / RunDeck 窄接口（本局）或
## 战斗侧上下文（当前手牌），不在这里重新实现本源或强化的内容语义。目标
## 必须是调用方已经解析、校验完成的明确实例 ID。

func operation_ids() -> Array[String]:
	return ["apply_enhancement", "apply_origin"]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	var op := str(effect.get("op", ""))
	match op:
		"apply_origin":
			_validate_origin(effect, context, scope)
		"apply_enhancement":
			var enhancement_id := str(effect.get("enhancement", ""))
			if enhancement_id == "":
				context.report_error(scope + ".enhancement", "必须是非空字符串")
			elif context.has_method("has_content_id") \
					and not context.has_content_id("enhancement", enhancement_id):
				context.report_error(
					scope + ".enhancement", "引用未知强化 %s" % enhancement_id)
			elif context.has_method("has_content_id"):
				var definition: Dictionary = context.content_definition(
					"enhancement", enhancement_id)
				if definition.has("allowed_carriers") \
						and not definition.get("allowed_carriers", []).has("card"):
					context.report_error(
						scope + ".enhancement",
						"强化 %s 不能用于真气" % enhancement_id)

func apply(effect: Dictionary, context) -> Dictionary:
	var op := str(effect.get("op", ""))
	match op:
		"apply_origin":
			return _apply_origin(effect, context)
		"apply_enhancement":
			return _apply_enhancement(effect, context)
	return {"success": false, "reason": "不支持的牌面重塑消耗品效果：%s" % op}

func eligible_targets(
		effect: Dictionary,
		_context,
		candidates: Array) -> Array:
	if str(effect.get("op", "")) != "apply_origin":
		return candidates.duplicate(true)
	var origin_id := str(effect.get("origin", ""))
	var payload: Dictionary = effect.get("payload", {})
	var result: Array = []
	for candidate in candidates:
		if not candidate is Dictionary:
			continue
		var origin = candidate.get("origin", {})
		if not origin is Dictionary or not origin.is_empty():
			continue
		if origin_id == "rank_change":
			var direction := str(payload.get("direction", ""))
			var rank := str(candidate.get("rank", ""))
			if direction == "up" and rank == "A":
				continue
			if direction == "down" and rank == "2":
				continue
		result.append(candidate.duplicate(true))
	return result

func _apply_enhancement(effect: Dictionary, context) -> Dictionary:
	var enhancement_id := str(effect.get("enhancement", ""))
	if context.instance_ids.is_empty():
		return {"success": false, "reason": "重塑类效果需要至少一个目标真气"}
	var targets: Array = []
	for instance_id in context.instance_ids:
		var result: Dictionary = context.apply_enhancement(
			str(instance_id), enhancement_id)
		if not result.get("success", false):
			return result
		targets.append({
			"instance_id": str(instance_id),
			"enhancement": enhancement_id,
			"before": result.get("before", {}),
			"after": result.get("after", {}),
		})
	return {
		"success": true,
		"applied": {
			"op": "apply_enhancement",
			"enhancement": enhancement_id,
			"count": targets.size(),
			"targets": targets,
			"details": [
				"%d 张真气获得%s强化" % [
					targets.size(), context.enhancement_name(enhancement_id)],
			],
		},
	}

func _apply_origin(effect: Dictionary, context) -> Dictionary:
	if context.instance_ids.is_empty():
		return {"success": false, "reason": "本源类效果需要至少一个目标真气"}
	var origin_id := str(effect.get("origin", ""))
	var payload: Dictionary = effect.get("payload", {})
	var result: Dictionary = context.apply_origin(
		context.instance_ids, origin_id, payload)
	if not result.get("success", false):
		return result
	var targets: Array = []
	for change in result.get("changed", []):
		targets.append({
			"instance_id": str(change.get("instance_id", "")),
			"origin": origin_id,
			"payload": payload.duplicate(true),
			"before": change.get("before", {}).duplicate(true),
			"after": change.get("after", {}).duplicate(true),
		})
	return {
		"success": true,
		"applied": {
			"op": "apply_origin",
			"origin": origin_id,
			"payload": payload.duplicate(true),
			"count": targets.size(),
			"targets": targets,
			"details": ["%d 张真气接受本源改造" % targets.size()],
		},
	}

func _validate_origin(effect: Dictionary, context, scope: String) -> void:
	var origin_id := str(effect.get("origin", ""))
	if origin_id == "":
		context.report_error(scope + ".origin", "必须是非空字符串")
	elif context.has_method("has_content_id") \
			and not context.has_content_id("origin", origin_id):
		context.report_error(scope + ".origin", "引用未知本源 %s" % origin_id)
	var payload = effect.get("payload")
	if not payload is Dictionary:
		context.report_error(scope + ".payload", "必须是对象")
		return
	var values: Dictionary = payload
	match origin_id:
		"attribute_change":
			if values.size() != 1 or not values.get("attribute") is String:
				context.report_error(
					scope + ".payload", "转属必须且只能提供字符串 attribute")
			elif context.has_method("legal_attribute_ids") \
					and not context.legal_attribute_ids().has(str(values.get("attribute", ""))):
				context.report_error(
					scope + ".payload.attribute", "引用未知基础属性 %s" % str(values.get("attribute", "")))
		"rank_change":
			if values.size() != 1 or not values.get("direction") is String:
				context.report_error(
					scope + ".payload", "易阶必须且只能提供字符串 direction")
			elif not ["up", "down"].has(str(values.get("direction", ""))):
				context.report_error(
					scope + ".payload.direction", "只能为 up 或 down")
		"awakening":
			if not values.is_empty() and (
					values.size() != 1 or not values.get("attribute") is String):
				context.report_error(
					scope + ".payload", "觉醒只能使用空 payload 或单一字符串 attribute")
			elif values.has("attribute") \
					and context.has_method("legal_attribute_ids") \
					and not context.legal_attribute_ids().has(str(values.get("attribute", ""))):
				context.report_error(
					scope + ".payload.attribute", "引用未知基础属性 %s" % str(values.get("attribute", "")))
