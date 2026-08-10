class_name GainInsightConsumableHandler
extends "res://core/consumables/consumable_effect_handler.gd"

## 心得：使对应具体牌型功法槽位 +1，并从正式白名单中确定性抽取尚未进入该
## 牌型序列的功法。
##
## 候选范围由上下文按效果的功法池解析（本局）或按共享功法仓库解析（战斗）；
## 没有合格功法时仍成功增加槽位，不跨池抽取。五条与四条可以共用功法候选池，
## 但 progression、槽位和序列必须独立——这由 GrowthInventory 的按牌型槽位与
## 序列状态保证，Handler 不做跨牌型判断。

func operation_ids() -> Array[String]:
	return ["gain_insight"]

func validate_effect(effect: Dictionary, context, scope: String) -> void:
	var hand_id := str(effect.get("hand", ""))
	if hand_id == "":
		context.report_error(scope + ".hand", "必须是非空字符串")
	var pools = effect.get("pools")
	if not pools is Array or pools.is_empty():
		context.report_error(scope + ".pools", "pools 必须是非空数组")
		return
	var seen: Dictionary = {}
	for index in range(pools.size()):
		var pool_id := str(pools[index])
		var pool_scope := "%s.pools[%d]" % [scope, index]
		if pool_id == "":
			context.report_error(pool_scope, "功法池 ID 不能为空")
		elif seen.has(pool_id):
			context.report_error(pool_scope, "功法池重复：%s" % pool_id)
		seen[pool_id] = true
	if not "hand_ids" in context or not "pool_ids" in context:
		return
	if hand_id != "" and not context.hand_ids.has(hand_id):
		context.report_error(scope + ".hand", "引用未知精确牌型 %s" % hand_id)
	for pool_id in seen:
		if not context.pool_ids.has(str(pool_id)):
			context.report_error(scope + ".pools", "引用未知功法池 %s" % str(pool_id))
	if hand_id != "" and context.hand_ids.has(hand_id) \
			and context.has_method("membership_for") \
			and not context.membership_for(hand_id).is_empty():
		for pool_id in seen:
			if not context.membership_for(hand_id).has(str(pool_id)):
				context.report_error(
					scope + ".pools",
					"功法池 %s 不属于牌型 %s 的成员资格" % [str(pool_id), hand_id])

func apply(effect: Dictionary, context) -> Dictionary:
	var hand_id := str(effect.get("hand", ""))
	var pools: Array = effect.get("pools", [])
	var candidates: Array = context.insight_candidates(hand_id, pools)
	var result: Dictionary = context.apply_insight(hand_id, candidates)
	if not result.get("success", false):
		return result
	var acquired_id := str(result.get("acquired_technique_id", ""))
	var details: Array[String] = []
	details.append("%s功法槽位 +1" % hand_id)
	if acquired_id != "":
		details.append("获得功法：%s" % context.technique_name(acquired_id))
	else:
		details.append("合格池暂无可抽功法，保留新增槽位")
	return {
		"success": true,
		"applied": {
			"op": "gain_insight",
			"hand_id": hand_id,
			"slot_count_before": int(result.get("slot_count_before", 1)),
			"slot_count_after": int(result.get("slot_count_after", 2)),
			"acquired_technique_id": acquired_id,
			"technique_available": acquired_id != "",
			"candidates": candidates.duplicate(),
			"details": details,
		},
	}
