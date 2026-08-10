class_name RunConsumableUseContext
extends "res://core/consumables/consumable_use_context.gd"

const CardWorkshopServiceScript = preload("res://core/card_workshop_service.gd")
const QiCardInstanceDataScript = preload("res://core/qi_card_instance_data.gd")

var _content_catalog
var _workshop := CardWorkshopServiceScript.new()

func _init(
		growth_override,
		instance_ids_override: Array = [],
		rng_override: RandomNumberGenerator = null,
		content_catalog = null,
		metadata_override: Dictionary = {}) -> void:
	super(growth_override, instance_ids_override, rng_override, metadata_override)
	_content_catalog = content_catalog

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
		result.append(technique_id)
	result.sort()
	return result

func apply_enhancement(instance_id: String, enhancement_id: String) -> Dictionary:
	return _workshop.apply_run_card_reshape(
		growth.run_deck, [instance_id], "enhancement", enhancement_id)

func apply_finish(instance_id: String, finish_id: String) -> Dictionary:
	return _workshop.apply_run_card_reshape(
		growth.run_deck, [instance_id], "finish", finish_id)

func technique_name(technique_id: String) -> String:
	var definition: Dictionary = _content_definition("technique", technique_id)
	return str(definition.get("name", technique_id))

func enhancement_name(enhancement_id: String) -> String:
	var definition: Dictionary = _content_definition("enhancement", enhancement_id)
	return str(definition.get("name", enhancement_id))

func finish_name(finish_id: String) -> String:
	var definition: Dictionary = _content_definition("finish", finish_id)
	return str(definition.get("name", finish_id))

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
