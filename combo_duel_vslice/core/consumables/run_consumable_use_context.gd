class_name RunConsumableUseContext
extends "res://core/consumables/consumable_use_context.gd"

const CardWorkshopServiceScript = preload("res://core/card_workshop_service.gd")
const CardOriginServiceScript = preload("res://core/card_origin_service.gd")
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

func begin_transaction() -> Dictionary:
	if growth == null or not growth.has_method("create_mutation_copy"):
		return {"success": false, "reason": "无法建立消耗品事务工作副本"}
	var working = growth.create_mutation_copy()
	if working == null:
		return {"success": false, "reason": "无法建立消耗品事务工作副本"}
	return {
		"success": true,
		"snapshot": growth.capture_mutation_state(),
		"context": RunConsumableUseContext.new(
			working, instance_ids, rng, _content_catalog, metadata),
	}

func capture_transaction_state() -> Dictionary:
	return growth.capture_mutation_state() if growth != null else {}

func commit_transaction(transaction: Dictionary) -> Dictionary:
	var working_context = transaction.get("context")
	if growth == null or working_context == null:
		return {"success": false, "reason": "消耗品事务工作状态不存在"}
	var errors: Array[String] = growth.replace_mutation_state(
		working_context.growth.capture_mutation_state())
	return {
		"success": errors.is_empty(),
		"reason": "；".join(errors),
	}

func rollback_transaction(_transaction: Dictionary) -> bool:
	## 正式本局效果始终写入工作副本；失败时丢弃副本即可，真实状态从未改变。
	return true

func create_effect_context(
		resolved_instance_ids: Array,
		random_source: RandomNumberGenerator,
		metadata_override: Dictionary):
	return RunConsumableUseContext.new(
		growth, resolved_instance_ids, random_source,
		_content_catalog, metadata_override)

func random_source_for(
		run_seed: int,
		sequence: int,
		consumable_id: String,
		effect_index: int,
		_preview_stream: RandomNumberGenerator = null) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = int(run_seed) * 1000003 \
		+ int(sequence) * 7919 \
		+ int(effect_index) * 9176 \
		+ _stable_id_mix(consumable_id) * 131
	return result

func preview_random_stream() -> RandomNumberGenerator:
	return null

func eligible_targets(zone: String) -> Array:
	if zone != "run_deck" or growth == null or growth.run_deck == null:
		return []
	var result: Array = []
	for values in growth.run_deck.cards_snapshot():
		result.append(_target_summary(values))
	return result

func owns_target(zone: String, instance_id: String) -> bool:
	return zone == "run_deck" and growth != null and growth.run_deck != null \
		and growth.run_deck.has_card(instance_id)

func current_target_limit(targeting: Dictionary) -> int:
	if str(targeting.get("maximum_source", "")) == "base_hand_limit":
		return growth.current_base_hand_limit()
	return int(targeting.get("maximum", 0))

func state_fingerprint() -> Dictionary:
	return growth.capture_mutation_state() if growth != null else {}

func run_card_mutation_snapshot():
	if growth == null or growth.run_deck == null:
		return []
	return growth.run_deck.cards_snapshot()

## 正式白名单：按效果的功法池过滤，只保留当前牌型成员资格内的正式功法。
func insight_candidates(hand_id: String, pools: Array) -> Array[String]:
	var result: Array[String] = []
	if _content_catalog == null:
		return result
	var techniques: Dictionary = _content_catalog.definition("techniques")
	var membership: Array = techniques.get("pool_membership", {}).get(hand_id, [])
	var statuses: Dictionary = techniques.get("integration_statuses", {})
	for value in techniques.get("techniques", []):
		if bool(value.get("built_in", false)):
			continue
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

func apply_imprint(instance_id: String, imprint_id: String) -> Dictionary:
	var result := _workshop.apply_run_card_reshape(
		growth.run_deck, [instance_id], "imprint", imprint_id)
	if not result.get("success", false):
		return result
	var change: Dictionary = result.get("changed", [{}])[0]
	return {
		"success": true,
		"instance_id": instance_id,
		"before": change.get("before", {}).duplicate(true),
		"after": change.get("after", {}).duplicate(true),
	}

func add_run_card_by_definition(definition_id: String) -> Dictionary:
	var result := _workshop.add_run_cards(growth.run_deck, [definition_id])
	if not result.get("success", false):
		return result
	var added: Dictionary = result.get("added", [{}])[0]
	return {
		"success": true,
		"instance_id": str(added.get("instance_id", "")),
		"definition_id": definition_id,
	}

func preview_origin(instance_id: String, origin_id: String, payload: Dictionary) -> Dictionary:
	var values := card_data(instance_id)
	if values.is_empty():
		return {"success": false, "reason": "找不到真气：%s" % instance_id}
	var service = CardOriginServiceScript.new(
		_content_catalog,
		_content_catalog.definition("base_deck") if _content_catalog != null else {})
	return service.plan(values, origin_id, payload)

func formal_imprint_ids() -> Array[String]:
	var result: Array[String] = []
	if _content_catalog == null:
		return result
	for definition in _content_catalog.all_of("imprint"):
		if str(definition.get("id", "")) != "":
			result.append(str(definition.get("id", "")))
	result.sort()
	return result

func base_card_definition_ids(
		rank_ids: Array = [], attribute_ids: Array = []) -> Array[String]:
	var result: Array[String] = []
	if _content_catalog == null:
		return result
	var ranks: Array = rank_ids
	var attributes: Array = attribute_ids
	if ranks.is_empty():
		for rank in _content_catalog.definition("base_deck").get("ranks", []):
			ranks.append(str(rank.get("id", "")))
	if attributes.is_empty():
		for attribute in _content_catalog.definition("base_deck").get("attributes", []):
			attributes.append(str(attribute.get("id", "")))
	for attribute in attributes:
		for rank in ranks:
			var definition_id := "%s_%s" % [str(attribute), str(rank)]
			if _content_catalog.has_id("card", definition_id):
				result.append(definition_id)
	result.sort()
	return result

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

func _target_summary(values: Dictionary) -> Dictionary:
	var reshapes: Dictionary = values.get("reshapes", {})
	return {
		"instance_id": str(values.get("instance_id", "")),
		"card_id": str(values.get("definition_id", "")),
		"rank": str(values.get("rank_name", "")),
		"suit": str(values.get("attribute", "")),
		"attribute": str(values.get("attribute", "")),
		"origin": reshapes.get("origin", {}).duplicate(true),
		"enhancement": str(reshapes.get("enhancement", "")),
		"imprint": str(reshapes.get("imprint", "")),
		"others": reshapes.get("others", {}).duplicate(true),
		"display_name": _display_name(values),
	}

func _display_name(values: Dictionary) -> String:
	if values.is_empty():
		return ""
	return "%s·%s" % [
		str(values.get("attribute_name", "")),
		str(values.get("rank_name", "")),
	]

func _stable_id_mix(content_id: String) -> int:
	var mixed := 0
	for index in range(content_id.length()):
		mixed = (mixed * 31 + content_id.unicode_at(index)) & 0x7FFFFFFF
	return mixed

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

func inner_skill_candidates_by_rarity(rarity: String = "") -> Array[String]:
	var result: Array[String] = []
	if _content_catalog == null or growth == null:
		return result
	for inner_skill_id in _inner_skill_repository.inner_skills:
		var id := str(inner_skill_id)
		var definition := _inner_skill_repository.get_inner_skill(id)
		if id == "" or growth.learned_inner_skill_ids.has(id):
			continue
		if rarity != "" and str(definition.get("rarity", "")) != rarity:
			continue
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

func duplicate_equipped_inner_skill(inner_skill_id: String) -> Dictionary:
	var id := str(inner_skill_id)
	if id == "" or not growth.equipped_inner_skill_ids.has(id):
		return {"success": false, "reason": "内功未装备：%s" % id}
	if not growth.learned_inner_skill_ids.has(id):
		return {"success": false, "reason": "内功不在已获内功库：%s" % id}
	growth.learned_inner_skill_ids.append(id)
	growth.equipped_inner_skill_ids.append(id)
	return {"success": true, "inner_skill_id": id}

func rewrite_technique_progression(
		choice_payload: Dictionary, slot_delta: int, modifiers: Dictionary) -> Dictionary:
	if growth == null:
		return {"success": false, "reason": "成长库存不存在"}
	var removals: Dictionary = choice_payload.get("removed_technique_ids_by_hand", {})
	if not removals is Dictionary:
		return {"success": false, "reason": "缺少各牌型功法移出选择"}
	var before: Dictionary = growth.hand_technique_progression.duplicate(true)
	for hand_id in growth.HAND_IDS:
		var progression: Dictionary = growth.hand_technique_progression.get(hand_id, {}).duplicate(true)
		var old_slots := int(progression.get("slot_count", 1))
		var new_slots := maxi(1, old_slots + slot_delta)
		var sequence: Array = progression.get("sequence", []).duplicate()
		var selected: Array = removals.get(hand_id, [])
		if selected.size() != maxi(0, sequence.size() - new_slots):
			return {"success": false, "reason": "%s 功法移出数量不足" % hand_id}
		for value in selected:
			if not sequence.has(str(value)):
				return {"success": false, "reason": "%s 选择了不在序列中的功法" % hand_id}
			sequence.erase(str(value))
		progression["slot_count"] = new_slots
		progression["sequence"] = sequence
		growth.hand_technique_progression[hand_id] = progression
	var validation: Dictionary = growth.technique_loadout_policy.validate_complete(
		growth, growth.hand_technique_progression,
		growth.learned_technique_ids, "")
	if not validation.get("success", false):
		growth.hand_technique_progression = before
		return validation
	for hand_id in modifiers:
		growth.hand_technique_multiplier_modifiers[hand_id] = (
			int(growth.hand_technique_multiplier_modifiers.get(hand_id, 0))
			+ int(modifiers[hand_id]))
	return {
		"success": true,
		"before": before,
		"after": growth.hand_technique_progression.duplicate(true),
		"modifiers": growth.hand_technique_multiplier_modifiers.duplicate(true),
	}

func apply_base_hand_limit_modifier(delta: int) -> Dictionary:
	var before: int = growth.base_hand_limit_modifier
	growth.base_hand_limit_modifier = maxi(-7, before + int(delta))
	return {
		"success": true,
		"before": before,
		"after": growth.base_hand_limit_modifier,
	}
