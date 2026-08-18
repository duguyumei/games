class_name ConsumableUseService
extends RefCounted

## 战斗内外唯一的消耗品使用用例服务。
##
## 负责目标解析（none / player_selected / deterministic_random）、效果事务边界
## 与确定性随机源。Handler 收到的目标必须是这里解析并校验完成的明确实例 ID。
##
## 事务流程只依赖 ConsumableUseContext：校验 → 冻结目标／选择 → 捕获事务与 RNG
## → 顺序执行 Handler → 消耗库存并写 unique／last／sequence → 提交。Run Context
## 使用工作副本；Battle Context 使用正式战斗 Runtime 快照。任一步失败都由同一
## rollback_transaction 入口恢复，不按 operation id 补偿。

const ConsumableEffectHandlerRegistryScript = preload(
	"res://core/consumables/consumable_effect_handler_registry.gd")
const RunConsumableUseContextScript = preload(
	"res://core/consumables/run_consumable_use_context.gd")
const ConsumableValidationContextScript = preload(
	"res://core/consumables/consumable_validation_context.gd")
const ConsumableTargetingProtocolScript = preload(
	"res://core/consumables/consumable_targeting_protocol.gd")
const RunEffectValidationScript = preload(
	"res://core/run_effects/run_effect_validation.gd")

var handler_registry
var _content_catalog
var _hand_ids: Array = []
var _pool_ids: Array = []
var _run_mutation_service

func _init(
		registry_override = null,
		content_catalog = null,
		hand_ids: Array = [],
		pool_ids: Array = [],
		run_mutation_service = null) -> void:
	handler_registry = (
		registry_override
		if registry_override != null
		else ConsumableEffectHandlerRegistryScript.new())
	_content_catalog = content_catalog
	_hand_ids = hand_ids.duplicate()
	_pool_ids = pool_ids.duplicate()
	_run_mutation_service = run_mutation_service

func use_run_mutation_service(service) -> void:
	_run_mutation_service = service

## 查询一次可用的消耗品使用信息。纯查询，不建立副本、不消费随机数。
func query_use(
		context,
		slot_index: int,
		definition: Dictionary,
		run_seed: int = 0) -> Dictionary:
	context = _normalized_context(context)
	if context == null or slot_index < 0 or slot_index >= context.inventory_size():
		return {
			"success": false,
			"reason": "消耗品槽位无效",
			"can_use": false,
			"reason_detail": "消耗品槽位无效",
		}
	var consumable_id: String = context.consumable_id_at(slot_index)
	if definition.is_empty() or str(definition.get("id", "")) != consumable_id:
		return {
			"success": false,
			"reason": "消耗品定义缺失或与槽位不一致",
			"can_use": false,
			"reason_detail": "消耗品定义缺失或与槽位不一致",
		}
	var targeting: Dictionary = definition.get("targeting", {})
	var zone := str(targeting.get("zone", "none"))
	var selection := str(targeting.get("selection", ""))
	var minimum := int(targeting.get("minimum", 0))
	var maximum: int = context.current_target_limit(targeting)
	if not ConsumableTargetingProtocolScript.TARGET_ZONES.has(zone) \
			or not ConsumableTargetingProtocolScript.TARGET_SELECTIONS.has(selection):
		return {
			"success": false,
			"reason": "消耗品目标协议无效",
			"can_use": false,
			"reason_detail": "消耗品目标协议无效",
		}
	if zone == "none" and selection == "player_selected":
		return {
			"success": false,
			"reason": "player_selected 只能用于有目标区域",
			"can_use": false,
			"reason_detail": "player_selected 只能用于有目标区域",
		}
	var validation := _validate_effects(definition.get("effects", []))
	if not validation.get("success", false):
		return {
			"success": false,
			"reason": str(validation.get("reason", "消耗品效果定义无效")),
			"can_use": false,
			"reason_detail": str(validation.get(
				"reason", "消耗品效果定义无效")),
		}
	if bool(definition.get("unique", false)) \
			and context.has_used_unique_consumable(consumable_id):
		return {
			"success": true,
			"consumable_id": consumable_id,
			"name": str(definition.get("name", "")),
			"description": str(definition.get("description", "")),
			"targeting": {"zone": zone, "selection": selection},
			"zone": zone,
			"selection": selection,
			"minimum": minimum,
			"maximum": maximum,
			"eligible_targets": [],
			"choice_schema": definition.get("choice_schema", {}).duplicate(true),
			"choice_options": [],
			"prepared_preview": {},
			"preparation_token": "",
			"can_use": false,
			"reason": "该唯一奇珍本局已经成功使用过",
		}
	var eligibility := _query_effect_eligibility(
		context,
		definition,
		zone,
		{
			"consumable_id": consumable_id,
			"reserved_consumable_slots": 1,
		})
	var eligible: Array = eligibility.get("eligible_targets", [])
	var can_use := bool(eligibility.get("can_use", true))
	var reason := str(eligibility.get("reason", ""))
	if can_use and zone != "none" and eligible.size() < minimum:
		can_use = false
		reason = "目标不足：需要至少 %d 张真气" % minimum
	var choice_info := _choice_query(context.growth, definition, eligible)
	if not choice_info.get("can_use", true):
		can_use = false
		reason = str(choice_info.get("reason", "没有合法选择"))
	var preparation: Dictionary = {}
	if can_use and bool(definition.get("requires_preparation", false)):
		preparation = _build_preparation(
			context, definition, zone, selection, minimum, maximum,
			run_seed, context.consumable_use_sequence(), consumable_id,
			eligible, true)
		if not preparation.get("success", false):
			can_use = false
			reason = str(preparation.get("reason", "无法准备随机预览"))
	return {
		"success": true,
		"consumable_id": consumable_id,
		"name": str(definition.get("name", "")),
		"description": str(definition.get("description", "")),
		"targeting": {"zone": zone, "selection": selection},
		"zone": zone,
		"selection": selection,
		"minimum": minimum,
		"maximum": maximum,
		"eligible_targets": eligible,
		"choice_schema": choice_info.get("choice_schema", {}).duplicate(true),
		"choice_options": choice_info.get("choice_options", []).duplicate(true),
		"prepared_preview": preparation.get("prepared_preview", {}).duplicate(true),
		"preparation_token": str(preparation.get("preparation_token", "")),
		"can_use": can_use,
		"reason": reason,
	}

## 执行一次完整的消耗品使用事务。成功时返回 applied 与递增后的序号；失败时
## 真实库存、牌组与 consumable_use_sequence 全部保持不变。
func use(
		context,
		slot_index: int,
		selected_instance_ids: Array,
		run_seed: int,
		definition: Dictionary,
		choice_payload = {}) -> Dictionary:
	context = _normalized_context(context)
	if not choice_payload is Dictionary:
		return {"success": false, "reason": "choice_payload 必须是对象"}
	if context == null:
		return {"success": false, "reason": "消耗品使用上下文不存在"}
	var sequence: int = context.consumable_use_sequence()
	if slot_index < 0 or slot_index >= context.inventory_size():
		return {"success": false, "reason": "消耗品槽位无效"}
	var consumable_id: String = context.consumable_id_at(slot_index)
	if definition.is_empty() or str(definition.get("id", "")) != consumable_id:
		return {"success": false, "reason": "消耗品定义缺失或与槽位不一致"}
	var targeting: Dictionary = definition.get("targeting", {})
	var zone := str(targeting.get("zone", "none"))
	var minimum := int(targeting.get("minimum", 0))
	var maximum: int = context.current_target_limit(targeting)
	var selection := str(targeting.get("selection", ""))
	if not ConsumableTargetingProtocolScript.TARGET_ZONES.has(zone):
		return {"success": false, "reason": "目标区域不受支持：%s" % zone}
	if not ConsumableTargetingProtocolScript.TARGET_SELECTIONS.has(selection):
		return {"success": false, "reason": "目标选择方式不受支持：%s" % selection}
	if zone == "none" and selection == "player_selected":
		return {"success": false, "reason": "player_selected 只能用于有目标区域"}
	if bool(definition.get("unique", false)) \
			and context.has_used_unique_consumable(consumable_id):
		return {"success": false, "reason": "该唯一奇珍本局已经成功使用过"}
	var eligibility := _query_effect_eligibility(
		context,
		definition,
		zone,
		{
			"consumable_id": consumable_id,
			"reserved_consumable_slots": 1,
		})
	if not eligibility.get("can_use", false):
		return {
			"success": false,
			"reason": str(eligibility.get("reason", "该消耗品当前不可用")),
		}
	var choice_check := _validate_choice_payload(
		context.growth, definition, choice_payload,
		eligibility.get("eligible_targets", []))
	if not choice_check.get("success", false):
		return choice_check
	var normalized_choice: Dictionary = choice_check.get("choice_payload", {}).duplicate(true)
	var preview_preparation: Dictionary = {}
	if bool(definition.get("requires_preparation", false)):
		preview_preparation = _build_preparation(
			context, definition, zone, selection, minimum, maximum,
			run_seed, sequence, consumable_id,
			eligibility.get("eligible_targets", []), true)
		if not preview_preparation.get("success", false):
			return preview_preparation
		if str(normalized_choice.get("preparation_token", "")) == "" \
				or str(normalized_choice.get("preparation_token", "")) \
				!= str(preview_preparation.get("preparation_token", "")):
			return {"success": false, "reason": "预览状态已失效，请重新查询后确认"}
		if not selected_instance_ids.is_empty():
			return {"success": false, "reason": "冻结预览不允许另行指定目标"}
	var effects: Array = definition.get("effects", [])
	if not effects is Array or effects.is_empty():
		return {"success": false, "reason": "消耗品没有效果"}
	var validation := _validate_effects(effects)
	if not validation.get("success", false):
		return validation

	var transaction: Dictionary = context.begin_transaction()
	if not transaction.get("success", false):
		return transaction
	var working_context = transaction.get("context")
	var state_before: Dictionary = transaction.get("snapshot", {}).duplicate(true)
	var preparation: Dictionary = {}
	var resolved: Dictionary
	if bool(definition.get("requires_preparation", false)):
		preparation = _build_preparation(
			working_context, definition, zone, selection, minimum, maximum,
			run_seed, sequence, consumable_id,
			working_context.eligible_targets(zone), false)
		if not preparation.get("success", false):
			return _rollback_failure(context, transaction, preparation)
		resolved = {
			"success": true,
			"instance_ids": preparation.get("instance_ids", []).duplicate(),
		}
	else:
		resolved = _resolve_targets(
			working_context, zone, selection, minimum, maximum,
			selected_instance_ids, run_seed, sequence, consumable_id,
			working_context.eligible_targets(zone), normalized_choice,
			targeting, null)
	if not resolved.get("success", false):
		return _rollback_failure(context, transaction, resolved)
	var instance_ids: Array = resolved.get("instance_ids", []).duplicate()
	var applied: Array = []
	var committed_events: Array = []
	for effect_index in range(effects.size()):
		var effect: Dictionary = effects[effect_index]
		var cards_before = working_context.run_card_mutation_snapshot()
		var metadata: Dictionary = working_context.metadata.duplicate(true)
		metadata.merge({
			"run_seed": run_seed,
			"consumable_use_sequence": sequence,
			"consumable_id": consumable_id,
			"consumable_slot_index": slot_index,
			"effect_index": effect_index,
			"reserved_consumable_slots": 1,
			"choice_payload": normalized_choice.duplicate(true),
			"prepared_effect": preparation.get(
				"prepared_effects", {}).get(effect_index, {}).duplicate(true),
		}, true)
		var effect_context = working_context.create_effect_context(
			instance_ids,
			working_context.random_source_for(
				run_seed, sequence, consumable_id, effect_index),
			metadata)
		var result: Dictionary = handler_registry.apply(effect, effect_context)
		if not result.get("success", false):
			return _rollback_failure(context, transaction, {
				"success": false,
				"reason": str(result.get("reason", "消耗品效果执行失败")),
				"failed_effect_index": effect_index,
				"failed_operation_id": str(effect.get("op", "")),
			})
		var fact_result := _stage_run_card_mutation_facts(
			working_context, effect, cards_before, metadata, effect_index)
		if not fact_result.get("success", false):
			return _rollback_failure(context, transaction, {
				"success": false,
				"reason": str(fact_result.get(
					"reason", "消耗品真气提交事实派发失败")),
				"failed_effect_index": effect_index,
				"failed_operation_id": str(effect.get("op", "")),
			})
		var applied_entry: Dictionary = result.get(
			"applied", {}).duplicate(true)
		if not fact_result.get("facts", []).is_empty():
			applied_entry["committed_facts"] = fact_result.get(
				"facts", []).duplicate(true)
		applied.append(applied_entry)
		committed_events.append_array(fact_result.get(
			"committed_events", []).duplicate(true))

	var consumed_id: String = working_context.consume_inventory_slot(slot_index)
	if consumed_id != consumable_id:
		return _rollback_failure(context, transaction, {
			"success": false,
			"reason": "消耗品槽位在事务期间发生变化",
		})
	if bool(definition.get("unique", false)):
		working_context.record_unique_consumable(consumable_id)
	var kind := str(definition.get("kind", ""))
	if kind in ["pill", "insight"] \
			and bool(definition.get("record_last_used", true)):
		working_context.record_last_recallable_consumable(consumable_id)
	var sequence_after: int = working_context.advance_consumable_use_sequence()
	var state_after: Dictionary = working_context.state_fingerprint()
	var commit_result: Dictionary = context.commit_transaction(transaction)
	if not commit_result.get("success", false):
		return _rollback_failure(context, transaction, commit_result)
	return {
		"success": true,
		"consumable_id": consumable_id,
		"slot_index": slot_index,
		"consumable_use_sequence": sequence_after,
		"applied": applied,
		"instance_ids": instance_ids,
		"choice_payload": normalized_choice,
		"prepared_preview": preparation.get("prepared_preview", {}).duplicate(true),
		"changed": state_before != state_after,
		"committed_events": committed_events,
	}

func _stage_run_card_mutation_facts(
		working_context,
		effect: Dictionary,
		cards_before,
		metadata: Dictionary,
		effect_index: int) -> Dictionary:
	if _run_mutation_service == null or not cards_before is Array:
		return {"success": true, "skipped": true, "facts": [], "committed_events": []}
	var fact_context := metadata.duplicate(true)
	var transaction_token := str(fact_context.get(
		"transaction_token", fact_context.get("action_token", "")))
	var consumable_id := str(fact_context.get("consumable_id", ""))
	var sequence := int(fact_context.get("consumable_use_sequence", 0))
	var slot_index := int(fact_context.get("consumable_slot_index", -1))
	if transaction_token == "":
		# RunSession 会提供同形 action_token；直接调用旧兼容入口时也必须由
		# 本事务上下文产生稳定且互不碰撞的 canonical token。
		transaction_token = "run-consumable-use:%d:%d:%s" % [
			sequence, slot_index, consumable_id]
	fact_context["transaction_token"] = transaction_token
	if str(fact_context.get("source_kind", "")) == "":
		fact_context["source_kind"] = "consumable"
	if str(fact_context.get("source_id", "")) == "":
		fact_context["source_id"] = consumable_id
	if str(fact_context.get("source_name", "")) == "":
		fact_context["source_name"] = consumable_id
	if str(fact_context.get("source_instance_key", "")) == "":
		fact_context["source_instance_key"] = "run-consumable:%d:%d:%s" % [
			sequence, slot_index, consumable_id]
	fact_context["reason"] = str(fact_context.get(
		"reason", "consumable:%s" % str(effect.get("op", ""))))
	return _run_mutation_service.stage_card_mutation_facts(
		str(effect.get("op", "")),
		cards_before,
		working_context.run_card_mutation_snapshot(),
		working_context.growth,
		fact_context,
		effect_index)

func _query_effect_eligibility(
		context,
		definition: Dictionary,
		zone: String,
		metadata: Dictionary) -> Dictionary:
	var query_context = context.create_effect_context([], null, metadata)
	var eligible: Array = context.eligible_targets(zone)
	var effects = definition.get("effects", [])
	if not effects is Array or effects.is_empty():
		return {
			"can_use": false,
			"reason": "消耗品没有效果",
			"eligible_targets": [],
		}
	for effect_index in range(effects.size()):
		var effect = effects[effect_index]
		if not effect is Dictionary:
			return {
				"can_use": false,
				"reason": "效果必须是对象",
				"eligible_targets": [],
			}
		var support: Dictionary = context.supports_effect(effect)
		if not support.get("supported", false):
			return {
				"can_use": false,
				"reason": str(support.get("reason", "该场景不支持此效果")),
				"eligible_targets": eligible,
			}
		eligible = handler_registry.eligible_targets(
			effect, query_context, eligible)
		var availability: Dictionary = handler_registry.query_availability(
			effect, query_context)
		if not availability.get("can_use", false):
			return {
				"can_use": false,
				"reason": str(availability.get(
					"reason", "effects[%d] 当前不可用" % effect_index)),
				"eligible_targets": eligible,
			}
	return {
		"can_use": true,
		"reason": "",
		"eligible_targets": eligible,
	}

func _resolve_targets(
		context,
		zone: String,
		selection: String,
		minimum: int,
		maximum: int,
		selected_instance_ids: Array,
		run_seed: int,
		sequence: int,
		consumable_id: String,
		eligible_targets: Array,
		choice_payload: Dictionary = {},
		targeting: Dictionary = {},
		preview_stream: RandomNumberGenerator = null) -> Dictionary:
	if zone == "none":
		if not selected_instance_ids.is_empty():
			return {"success": false, "reason": "该消耗品不需要选择目标"}
		return {"success": true, "instance_ids": [], "mode": "none"}
	if selection == "deterministic_random":
		if not selected_instance_ids.is_empty():
			return {"success": false, "reason": "deterministic_random 不允许手动指定目标"}
		return _resolve_random_targets(
			context, zone, minimum, maximum, run_seed, sequence,
			consumable_id, eligible_targets,
			str(targeting.get("count_mode", "random")), preview_stream)
	if selection == "choice_filtered":
		if not selected_instance_ids.is_empty():
			return {"success": false, "reason": "choice_filtered 不允许手动指定真气"}
		var field := str(targeting.get("choice_field", "rank"))
		var choice_field := str(targeting.get("choice_payload_field", field))
		var expected := str(choice_payload.get(choice_field, ""))
		var matched: Array = []
		for target in eligible_targets:
			if target is Dictionary and str(target.get(field, "")) == expected:
				matched.append(str(target.get("instance_id", "")))
		if matched.size() < minimum or matched.size() > maximum:
			return {"success": false, "reason": "所选条件下的目标数量不合法"}
		return {"success": true, "instance_ids": matched, "mode": "choice_filtered"}
	if selection != "player_selected":
		return {"success": false, "reason": "目标选择方式不受支持：%s" % selection}
	if zone != "run_deck":
		return {"success": false, "reason": "目标区域不受支持：%s" % zone}
	var instance_ids: Array = []
	var seen: Dictionary = {}
	var eligible_ids: Dictionary = {}
	for target in eligible_targets:
		if target is Dictionary:
			eligible_ids[str(target.get("instance_id", ""))] = true
	for value in selected_instance_ids:
		var instance_id := str(value)
		if instance_id == "":
			return {"success": false, "reason": "目标真气实例 ID 不能为空"}
		if seen.has(instance_id):
			return {
				"success": false,
				"reason": "目标真气实例 ID 不能重复：%s" % instance_id,
			}
		seen[instance_id] = true
		if not context.owns_target(zone, instance_id):
			return {
				"success": false,
				"reason": "目标真气不属于当前合法目标区域：%s" % instance_id,
			}
		if not eligible_ids.has(instance_id):
			return {
				"success": false,
				"reason": "目标真气不符合该消耗品资格：%s" % instance_id,
			}
		instance_ids.append(instance_id)
	if instance_ids.size() < minimum or instance_ids.size() > maximum:
		return {
			"success": false,
			"reason": "需要选择 %d～%d 张真气" % [minimum, maximum],
		}
	return {"success": true, "instance_ids": instance_ids, "mode": "player_selected"}

func _resolve_random_targets(
		context,
		zone: String,
		minimum: int,
		maximum: int,
		run_seed: int,
		sequence: int,
		consumable_id: String,
		eligible_targets: Array,
		count_mode: String = "random",
		preview_stream: RandomNumberGenerator = null) -> Dictionary:
	if zone != "run_deck":
		return {"success": false, "reason": "目标区域不受支持：%s" % zone}
	var ids: Array = []
	for values in eligible_targets:
		if values is Dictionary:
			ids.append(str(values.get("instance_id", "")))
	ids.sort()
	if ids.size() < minimum:
		return {
			"success": false,
			"reason": "目标不足：需要至少 %d 张真气" % minimum,
		}
	var random_source: RandomNumberGenerator = context.random_source_for(
		run_seed, sequence, consumable_id, -1, preview_stream)
	if random_source == null:
		return {"success": false, "reason": "消耗品目标解析缺少随机源"}
	var upper := mini(maximum, ids.size())
	var count := upper if count_mode == "maximum" else random_source.randi_range(minimum, upper)
	var instance_ids: Array = []
	for _index in range(count):
		var chosen := random_source.randi_range(0, ids.size() - 1)
		instance_ids.append(ids[chosen])
		ids.remove_at(chosen)
	return {
		"success": true,
		"instance_ids": instance_ids,
		"mode": "deterministic_random",
	}

func _choice_query(growth, definition: Dictionary, eligible: Array) -> Dictionary:
	var schema = definition.get("choice_schema", {})
	if not schema is Dictionary or schema.is_empty():
		return {"can_use": true, "choice_schema": {}, "choice_options": []}
	var values: Dictionary = schema
	match str(values.get("type", "")):
		"enum":
			var field := str(values.get("field", "choice"))
			var available_values: Dictionary = {}
			if str(definition.get("targeting", {}).get("selection", "")) == "choice_filtered":
				var candidate_field := str(definition.get("targeting", {}).get("choice_field", field))
				for target in eligible:
					if target is Dictionary:
						available_values[str(target.get(candidate_field, ""))] = true
			var options: Array = []
			for option in values.get("options", []):
				var option_value := str(option)
				if available_values.is_empty() or available_values.has(option_value):
					options.append({"value": option_value, "label": option_value})
			return {
				"can_use": not options.is_empty(),
				"reason": "当前没有合格选项" if options.is_empty() else "",
				"choice_schema": values.duplicate(true),
				"choice_options": options,
			}
		"technique_sequence_removals":
			var groups: Array = []
			for hand_id in growth.HAND_IDS:
				var progression: Dictionary = growth.hand_technique_progression.get(hand_id, {})
				var new_slots := maxi(1, int(progression.get("slot_count", 1)) + int(values.get("slot_delta", -1)))
				var sequence: Array = progression.get("sequence", []).duplicate()
				groups.append({
					"hand_id": hand_id,
					"required_count": maxi(0, sequence.size() - new_slots),
					"options": sequence,
				})
			var dynamic_schema := values.duplicate(true)
			dynamic_schema["groups"] = groups.duplicate(true)
			return {"can_use": true, "choice_schema": dynamic_schema, "choice_options": groups}
	return {"can_use": false, "reason": "未知 choice_schema 类型", "choice_schema": values, "choice_options": []}

func _validate_choice_payload(
		growth,
		definition: Dictionary,
		choice_payload: Dictionary,
		eligible: Array) -> Dictionary:
	var schema = definition.get("choice_schema", {})
	var normalized := choice_payload.duplicate(true)
	if not schema is Dictionary or schema.is_empty():
		return {"success": true, "choice_payload": normalized}
	var values: Dictionary = schema
	match str(values.get("type", "")):
		"enum":
			var field := str(values.get("field", "choice"))
			var selected := str(normalized.get(field, ""))
			if not values.get("options", []).has(selected):
				return {"success": false, "reason": "%s 不是合法选择" % selected}
			var query := _choice_query(growth, definition, eligible)
			var available: Array = []
			for option in query.get("choice_options", []):
				available.append(str(option.get("value", "")))
			if not available.has(selected):
				return {"success": false, "reason": "所选选项当前没有合格目标"}
		"technique_sequence_removals":
			var field := str(values.get("field", "removed_technique_ids_by_hand"))
			var selections = normalized.get(field, {})
			if not selections is Dictionary:
				return {"success": false, "reason": "功法移出选择必须是对象"}
			for hand_id in growth.HAND_IDS:
				var progression: Dictionary = growth.hand_technique_progression.get(hand_id, {})
				var sequence: Array = progression.get("sequence", []).duplicate()
				var new_slots := maxi(1, int(progression.get("slot_count", 1)) + int(values.get("slot_delta", -1)))
				var required := maxi(0, sequence.size() - new_slots)
				var selected = selections.get(hand_id, [])
				if not selected is Array or selected.size() != required:
					return {"success": false, "reason": "%s 必须选择移出 %d 门功法" % [hand_id, required]}
				var seen: Dictionary = {}
				for technique_id in selected:
					var id := str(technique_id)
					if seen.has(id) or not sequence.has(id):
						return {"success": false, "reason": "%s 功法移出选择无效" % hand_id}
					seen[id] = true
	return {"success": true, "choice_payload": normalized}

func _build_preparation(
		context,
		definition: Dictionary,
		zone: String,
		selection: String,
		minimum: int,
		maximum: int,
		run_seed: int,
		sequence: int,
		consumable_id: String,
		eligible: Array,
		preview: bool) -> Dictionary:
	var targeting: Dictionary = definition.get("targeting", {})
	var preview_stream: RandomNumberGenerator = (
		context.preview_random_stream() if preview else null)
	var resolved := _resolve_targets(
		context, zone, selection, minimum, maximum, [], run_seed, sequence,
		consumable_id, eligible, {}, targeting, preview_stream)
	if not resolved.get("success", false):
		return resolved
	var ids: Array = resolved.get("instance_ids", []).duplicate()
	var prepared_effects: Dictionary = {}
	var previews: Array = []
	var effects: Array = definition.get("effects", [])
	for effect_index in range(effects.size()):
		var prepare_context = context.create_effect_context(
			ids,
			context.random_source_for(
				run_seed, sequence, consumable_id, effect_index,
				preview_stream),
			context.metadata.merged({
				"consumable_id": consumable_id,
				"effect_index": effect_index,
			}, true))
		var prepared: Dictionary = handler_registry.prepare(
			effects[effect_index], prepare_context)
		if not prepared.get("success", false):
			return prepared
		var values: Dictionary = prepared.get("prepared", {}).duplicate(true)
		if not values.is_empty():
			prepared_effects[effect_index] = values
			previews.append({"effect_index": effect_index, "op": str(effects[effect_index].get("op", "")), "result": values})
	var state_text := JSON.stringify(context.state_fingerprint())
	var frozen_text := JSON.stringify({"ids": ids, "effects": prepared_effects})
	var token := "%s:%d:%d:%d" % [
		consumable_id,
		sequence,
		_stable_id_mix(state_text),
		_stable_id_mix(frozen_text),
	]
	return {
		"success": true,
		"instance_ids": ids,
		"prepared_effects": prepared_effects,
		"prepared_preview": {"targets": ids, "effects": previews},
		"preparation_token": token,
	}

func _validate_effects(effects: Array) -> Dictionary:
	var pool_membership: Dictionary = {}
	if _content_catalog != null:
		pool_membership = _content_catalog.definition("techniques").get(
			"pool_membership", {})
	for effect_index in range(effects.size()):
		var effect = effects[effect_index]
		if not effect is Dictionary:
			return {"success": false, "reason": "效果必须是对象"}
		var collector := RunEffectValidationScript.new()
		var validation_context = ConsumableValidationContextScript.new(
			collector, _hand_ids, _pool_ids, pool_membership, _content_catalog)
		handler_registry.validate_effect(
			effect, validation_context, "effects[%d]" % effect_index)
		if not collector.is_valid():
			return {"success": false, "reason": "；".join(collector.errors)}
	return {"success": true}

func _rollback_failure(
		context,
		transaction: Dictionary,
		result: Dictionary) -> Dictionary:
	var restored: bool = context.rollback_transaction(transaction)
	var failure := result.duplicate(true)
	failure["success"] = false
	failure["rolled_back"] = restored
	if not restored:
		failure["reason"] = "%s；消耗品事务状态恢复不完整" % str(
			failure.get("reason", "消耗品效果执行失败"))
	return failure

func _stable_id_mix(content_id: String) -> int:
	var mixed := 0
	for index in range(content_id.length()):
		mixed = (mixed * 31 + content_id.unicode_at(index)) & 0x7FFFFFFF
	return mixed

func _normalized_context(value):
	if value != null and value.has_method("inventory_size") \
			and value.has_method("begin_transaction"):
		return value
	## 兼容旧的 GrowthInventory 调用点；只负责构造正式 Context，随后仍走同一
	## 查询、Handler 顺序和事务算法，不保留第二套字段清单或补偿逻辑。
	return RunConsumableUseContextScript.new(
		value, [], null, _content_catalog, {}) if value != null else null
