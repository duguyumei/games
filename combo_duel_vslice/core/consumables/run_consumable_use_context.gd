class_name RunConsumableUseContext
extends "res://core/consumables/consumable_use_context.gd"

const CardWorkshopServiceScript = preload("res://core/card_workshop_service.gd")
const QiCardInstanceDataScript = preload("res://core/qi_card_instance_data.gd")
const InnerSkillRepositoryScript = preload("res://core/inner_skill_repository.gd")

var _content_catalog
var _workshop := CardWorkshopServiceScript.new()
var _inner_skill_repository := InnerSkillRepositoryScript.new()

func _init(
		growth_override,
		instance_ids_override: Array = [],
		rng_override: RandomNumberGenerator = null,
		content_catalog = null,
		metadata_override: Dictionary = {}) -> void:
	super(growth_override, instance_ids_override, rng_override, metadata_override)
	_content_catalog = content_catalog
	if _content_catalog != null:
		_inner_skill_repository.configure(
			_content_catalog.definition("inner_skills"))

## 正式白名单：按效果的功法池过滤，只保留当前牌型成员资格内的正式功法。
func insight_candidates(hand_id: String, pools: Array) -> Array[String]:
	var result: Array[String] = []
	if _content_catalog == null:
		return result
	var techniques: Dictionary = _content_catalog.definition("techniques")
	var membership: Array = techniques.get("pool_membership", {}).get(hand_id, [])
	var statuses: Dictionary = techniques.get("integration_statuses", {})
	for value in techniques.get("techniques", []):
		var technique_id := str(value.get("id", ""))
		var pool_id := str(value.get("pool", ""))
		if str(statuses.get(technique_id, "missing")) != "formal_complete":
			continue
		if not pools.has(pool_id):
			continue
		if not membership.has(pool_id):
			continue
		if not result.has(technique_id):
			result.append(technique_id)
	result.sort()
	return result

func apply_enhancement(instance_id: String, enhancement_id: String) -> Dictionary:
	var result: Dictionary = _workshop.apply_run_card_reshape(
		growth.run_deck, [instance_id], "enhancement", enhancement_id)
	if not result.get("success", false):
		return result
	var change: Dictionary = result.get("changed", [{}])[0]
	return {
		"success": true,
		"instance_id": instance_id,
		"before": change.get("before", {}).duplicate(true),
		"after": change.get("after", {}).duplicate(true),
	}

func apply_origin(
		instance_ids: Array,
		origin_id: String,
		payload: Dictionary) -> Dictionary:
	return _workshop.apply_run_card_origin(
		growth.run_deck, instance_ids, origin_id, payload)

func technique_name(technique_id: String) -> String:
	var definition: Dictionary = _content_definition("technique", technique_id)
	return str(definition.get("name", technique_id))

func enhancement_name(enhancement_id: String) -> String:
	var definition: Dictionary = _content_definition("enhancement", enhancement_id)
	return str(definition.get("name", enhancement_id))

func target_display_name(instance_id: String) -> String:
	var values := card_data(instance_id)
	if values.is_empty():
		return instance_id
	var card = QiCardInstanceDataScript.restore(
		values,
		_content_catalog.card_reshape_rules if _content_catalog != null else null)
	return card.display_name()

func card_data(instance_id: String) -> Dictionary:
	if growth == null or growth.run_deck == null:
		return {}
	return growth.run_deck.card_data(instance_id)

func _content_definition(content_type: String, content_id: String) -> Dictionary:
	if _content_catalog == null:
		return {}
	return _content_catalog.get_by_id(content_type, content_id)

func remove_run_cards(instance_ids: Array) -> Dictionary:
	return _workshop.remove_run_cards(growth.run_deck, instance_ids)

func copy_run_card(source_instance_id: String, count: int = 1) -> Dictionary:
	return _workshop.copy_run_card(growth.run_deck, source_instance_id, count)

func add_consumable(consumable_id: String) -> Dictionary:
	if growth == null:
		return {"success": false, "reason": "成长库存不存在"}
	var id := str(consumable_id)
	if _content_catalog == null or not _content_catalog.has_id("consumable", id):
		return {"success": false, "reason": "未知消耗品：%s" % id}
	if growth.consumable_ids.size() >= consumable_capacity():
		return {"success": false, "reason": "共享消耗品栏已满"}
	growth.consumable_ids.append(id)
	return {"success": true, "consumable_id": id}

func consumable_capacity() -> int:
	var limit := 3
	var reserved := int(metadata.get("reserved_consumable_slots", 0))
	return limit + reserved

func consumable_candidates(kind: String) -> Array[String]:
	var result: Array[String] = []
	if _content_catalog == null:
		return result
	for definition in _content_catalog.all_of("consumable"):
		if str(definition.get("kind", "")) == kind \
				and bool(definition.get("enabled", true)) \
				and str(definition.get("status", "")) \
				not in ["disabled", "draft", "placeholder"]:
			result.append(str(definition.get("id", "")))
	result.sort()
	return result

func last_recallable_consumable_id() -> String:
	return str(growth.last_recallable_consumable_id)

func record_last_recallable_consumable(consumable_id: String) -> void:
	growth.last_recallable_consumable_id = str(consumable_id)

func formal_enhancement_ids() -> Array[String]:
	var result: Array[String] = []
	if _content_catalog == null:
		return result
	for definition in _content_catalog.all_of("enhancement"):
		if definition.has("id") and (
				not definition.has("status") or str(definition.get("status", ""))
				in ["formal", "formal_complete", ""]):
			result.append(str(definition["id"]))
	result.sort()
	return result

func equipped_inner_skill_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if growth == null or _content_catalog == null:
		return result
	for inner_skill_id in growth.equipped_inner_skill_ids:
		var definition := _inner_skill_repository.get_inner_skill(
			str(inner_skill_id))
		if not definition.is_empty():
			result.append(definition)
	return result

func inner_skill_candidates() -> Array[String]:
	var result: Array[String] = []
	if growth == null:
		return result
	for inner_skill_id in _inner_skill_repository.inner_skills:
		var id := str(inner_skill_id)
		if id != "" and not growth.learned_inner_skill_ids.has(id):
			result.append(id)
	result.sort()
	return result

func add_inner_skill(inner_skill_id: String) -> Dictionary:
	var id := str(inner_skill_id)
	if id == "":
		return {"success": false, "reason": "内功 ID 不能为空"}
	if growth.learned_inner_skill_ids.has(id):
		return {"success": false, "reason": "内功已经习得：%s" % id}
	if _content_catalog == null or not _content_catalog.has_id("inner_skill", id):
		return {"success": false, "reason": "未知内功：%s" % id}
	growth.learned_inner_skill_ids.append(id)
	return {"success": true, "inner_skill_id": id}
