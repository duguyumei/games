class_name ConsumableUseContext
extends RefCounted

## 消耗品效果执行的窄端口。
##
## 正式本局入口使用 RunConsumableUseContext（目标为 RunDeck 真气实例），纵切
## 战斗兼容入口使用 BattleConsumableUseContext（目标为当前手牌 QiCard）。两个
## 实现只适配目标区域和查询来源，Handler 不区分具体场景，也不直接访问引擎。
##
## growth 在两种实现中都提供 apply_insight_growth(hand_id, candidates, rng)，
## 因此心得成长可以在基类完成；其余能力由具体实现提供。

var growth
var instance_ids: Array[String] = []
var rng: RandomNumberGenerator
var metadata: Dictionary = {}

func _init(
		growth_override,
		instance_ids_override: Array = [],
		rng_override: RandomNumberGenerator = null,
		metadata_override: Dictionary = {}) -> void:
	growth = growth_override
	for value in instance_ids_override:
		instance_ids.append(str(value))
	rng = rng_override
	metadata = metadata_override.duplicate(true)

## 返回该效果可以抽取的正式功法白名单。本局实现按效果的功法池过滤，战斗实现
## 按共享功法仓库过滤；两者都只返回尚未决定的目标信息，不消费随机数。
func insight_candidates(_hand_id: String, _pools: Array) -> Array[String]:
	return []

func apply_insight(hand_id: String, candidates: Array) -> Dictionary:
	if growth == null or not growth.has_method("apply_insight_growth"):
		return {"success": false, "reason": "该场景不支持心得成长"}
	return growth.apply_insight_growth(hand_id, candidates, rng)

func apply_enhancement(_instance_id: String, _enhancement_id: String) -> Dictionary:
	return {"success": false, "reason": "该场景不支持强化施加"}

func apply_finish(_instance_id: String, _finish_id: String) -> Dictionary:
	return {"success": false, "reason": "该场景不支持品相施加"}

func technique_name(technique_id: String) -> String:
	return technique_id

func enhancement_name(enhancement_id: String) -> String:
	return enhancement_id

func finish_name(finish_id: String) -> String:
	return finish_id

func target_display_name(instance_id: String) -> String:
	return instance_id
