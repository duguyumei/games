class_name CardReshapeConsumableHandler
extends "res://core/consumables/consumable_effect_handler.gd"

## 丹药与奇珍的牌面重塑：apply_enhancement（奖励牌等强化）与
## apply_random_finish（确定性随机品相）。
##
## 重塑规则全部委托 F1C 的 CardWorkshopService / RunDeck 窄接口（本局）或
## 战斗侧上下文（当前手牌），不在这里重新实现奖励牌、品相等内容语义。目标
## 必须是调用方已经解析、校验完成的明确实例 ID。

func operation_ids() -> Array[String]:
	return ["apply_enhancement", "apply_random_finish"]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	var op := str(effect.get("op", ""))
	match op:
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
		"apply_random_finish":
			var finish_ids = effect.get("finishes")
			if not finish_ids is Array or finish_ids.is_empty():
				context.report_error(scope + ".finishes", "finishes 必须是非空数组")
				return
			var seen: Dictionary = {}
			for index in range(finish_ids.size()):
				var finish_id := str(finish_ids[index])
				var finish_scope := "%s.finishes[%d]" % [scope, index]
				if finish_id == "":
					context.report_error(finish_scope, "品相 ID 不能为空")
				elif seen.has(finish_id):
					context.report_error(finish_scope, "品相重复：%s" % finish_id)
				elif context.has_method("has_content_id") \
						and not context.has_content_id("finish", finish_id):
					context.report_error(finish_scope, "引用未知品相 %s" % finish_id)
				elif context.has_method("has_content_id"):
					var definition: Dictionary = context.content_definition(
						"finish", finish_id)
					if definition.has("allowed_carriers") \
							and not definition.get("allowed_carriers", []).has("card"):
						context.report_error(
							finish_scope, "品相 %s 不能用于真气" % finish_id)
				seen[finish_id] = true

func apply(effect: Dictionary, context) -> Dictionary:
	var op := str(effect.get("op", ""))
	match op:
		"apply_enhancement":
			return _apply_enhancement(effect, context)
		"apply_random_finish":
			return _apply_random_finish(effect, context)
	return {"success": false, "reason": "不支持的牌面重塑消耗品效果：%s" % op}

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

func _apply_random_finish(effect: Dictionary, context) -> Dictionary:
	var finishes: Array = effect.get("finishes", [])
	if finishes.is_empty():
		return {"success": false, "reason": "finishes 必须是非空数组"}
	if context.instance_ids.is_empty():
		return {"success": false, "reason": "重塑类效果需要至少一个目标真气"}
	var targets: Array = []
	var details: Array[String] = []
	for instance_id in context.instance_ids:
		var finish_index := 0
		if context.rng != null:
			finish_index = context.rng.randi_range(0, finishes.size() - 1)
		var finish_id := str(finishes[finish_index])
		var result: Dictionary = context.apply_finish(str(instance_id), finish_id)
		if not result.get("success", false):
			return result
		targets.append({
			"instance_id": str(instance_id),
			"finish": finish_id,
			"before": result.get("before", {}),
			"after": result.get("after", {}),
		})
		details.append("%s获得%s品相" % [
			context.target_display_name(str(instance_id)),
			context.finish_name(finish_id)])
	return {
		"success": true,
		"applied": {
			"op": "apply_random_finish",
			"finishes": finishes.duplicate(),
			"count": targets.size(),
			"targets": targets,
			"details": details,
		},
	}
