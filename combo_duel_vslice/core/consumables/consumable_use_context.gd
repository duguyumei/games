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
	return growth.apply_insight_growth(hand_id, candidates, rng, metadata)

func apply_enhancement(_instance_id: String, _enhancement_id: String) -> Dictionary:
	return {"success": false, "reason": "该场景不支持强化施加"}

func apply_origin(
		_instance_ids: Array,
		_origin_id: String,
		_payload: Dictionary) -> Dictionary:
	return {"success": false, "reason": "该场景不支持本源改造"}

func apply_imprint(_instance_id: String, _imprint_id: String) -> Dictionary:
	return {"success": false, "reason": "该场景不支持印记施加"}

func add_run_card_by_definition(_definition_id: String) -> Dictionary:
	return {"success": false, "reason": "该场景不支持生成本局真气"}

func preview_origin(_instance_id: String, _origin_id: String, _payload: Dictionary) -> Dictionary:
	return {"success": false, "reason": "该场景不支持本源预览"}

func formal_imprint_ids() -> Array[String]:
	return []

func base_card_definition_ids(
		_rank_ids: Array = [], _attribute_ids: Array = []) -> Array[String]:
	return []

func inner_skill_candidates_by_rarity(_rarity: String = "") -> Array[String]:
	return inner_skill_candidates()

func duplicate_equipped_inner_skill(_inner_skill_id: String) -> Dictionary:
	return {"success": false, "reason": "该场景不支持复制内功"}

func rewrite_technique_progression(_choice_payload: Dictionary, _slot_delta: int, _modifiers: Dictionary) -> Dictionary:
	return {"success": false, "reason": "该场景不支持功法槽位改造"}

func apply_base_hand_limit_modifier(_delta: int) -> Dictionary:
	return {"success": false, "reason": "该场景不支持手牌上限改造"}

func technique_name(technique_id: String) -> String:
	return technique_id

func enhancement_name(enhancement_id: String) -> String:
	return enhancement_id

func target_display_name(instance_id: String) -> String:
	return instance_id

## 以下是正式本局 Handler 的领域窄接口。基类默认返回不支持，战斗上下文
## 可以继续只实现自己拥有的能力，不会把成长库存泄漏给战斗中央流程。
func remove_run_cards(_instance_ids: Array) -> Dictionary:
	return {"success": false, "reason": "该场景不支持移出本局真气"}

func copy_run_card(_source_instance_id: String, _count: int = 1) -> Dictionary:
	return {"success": false, "reason": "该场景不支持复制本局真气"}

func add_consumable(_consumable_id: String) -> Dictionary:
	return {"success": false, "reason": "该场景不支持生成本局消耗品"}

func consumable_candidates(_kind: String) -> Array[String]:
	return []

func consumable_capacity() -> int:
	return 0

func last_recallable_consumable_id() -> String:
	return ""

func formal_enhancement_ids() -> Array[String]:
	return []

func equipped_inner_skill_definitions() -> Array[Dictionary]:
	return []

func inner_skill_candidates() -> Array[String]:
	return []

func add_inner_skill(_inner_skill_id: String) -> Dictionary:
	return {"success": false, "reason": "该场景不支持获得内功"}

func record_last_recallable_consumable(_consumable_id: String) -> void:
	pass
