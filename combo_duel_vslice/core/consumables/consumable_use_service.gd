class_name ConsumableUseService
extends RefCounted

## 正式本局消耗品使用服务。
##
## 负责目标解析（none / player_selected / deterministic_random）、效果事务边界
## 与确定性随机源。Handler 收到的目标必须是这里解析并校验完成的明确实例 ID。
##
## 事务流程：校验槽位、定义与目标 → 建立 GrowthInventory 完整工作副本 → 在副本
## 上顺序执行全部效果 → 全部成功后按 slot_index 删除消耗品并递增
## consumable_use_sequence → 一次性提交。任一步失败都不提交，也不会改变
## consumable_use_sequence，因此失败不会消费随机序号。

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

func _init(
		registry_override = null,
		content_catalog = null,
		hand_ids: Array = [],
		pool_ids: Array = []) -> void:
	handler_registry = (
		registry_override
		if registry_override != null
		else ConsumableEffectHandlerRegistryScript.new())
	_content_catalog = content_catalog
	_hand_ids = hand_ids.duplicate()
	_pool_ids = pool_ids.duplicate()

## 查询一次可用的消耗品使用信息。纯查询，不建立副本、不消费随机数。
func query_use(growth, slot_index: int, definition: Dictionary) -> Dictionary:
	if slot_index < 0 or slot_index >= growth.consumable_ids.size():
		return {
			"success": false,
			"reason": "消耗品槽位无效",
			"can_use": false,
			"reason_detail": "消耗品槽位无效",
		}
	var consumable_id := str(growth.consumable_ids[slot_index])
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
	var maximum := int(targeting.get("maximum", 0))
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
	var eligibility := _query_effect_eligibility(
		growth,
		definition,
		zone,
		{
			"consumable_id": consumable_id,
			"reserved_consumable_slots": 1,
		})
	var eligible: Array = eligibility.get("eligible_targets", [])
	var can_use := bool(eligibility.get("can_use", true))
	var reason := str(eligibility.get("reason", ""))
	if zone != "none" and eligible.size() < minimum:
		can_use = false
		reason = "目标不足：需要至少 %d 张真气" % minimum
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
		"can_use": can_use,
		"reason": reason,
	}

## 执行一次完整的消耗品使用事务。成功时返回 applied 与递增后的序号；失败时
## 真实库存、牌组与 consumable_use_sequence 全部保持不变。
func use(
		growth,
		slot_index: int,
		selected_instance_ids: Array,
		run_seed: int,
		definition: Dictionary) -> Dictionary:
	var sequence := int(growth.consumable_use_sequence)
	if slot_index < 0 or slot_index >= growth.consumable_ids.size():
		return {"success": false, "reason": "消耗品槽位无效"}
	var consumable_id := str(growth.consumable_ids[slot_index])
	if definition.is_empty() or str(definition.get("id", "")) != consumable_id:
		return {"success": false, "reason": "消耗品定义缺失或与槽位不一致"}
	var targeting: Dictionary = definition.get("targeting", {})
	var zone := str(targeting.get("zone", "none"))
	var minimum := int(targeting.get("minimum", 0))
	var maximum := int(targeting.get("maximum", 0))
	var selection := str(targeting.get("selection", ""))
	if not ConsumableTargetingProtocolScript.TARGET_ZONES.has(zone):
		return {"success": false, "reason": "目标区域不受支持：%s" % zone}
	if not ConsumableTargetingProtocolScript.TARGET_SELECTIONS.has(selection):
		return {"success": false, "reason": "目标选择方式不受支持：%s" % selection}
	if zone == "none" and selection == "player_selected":
		return {"success": false, "reason": "player_selected 只能用于有目标区域"}
	var eligibility := _query_effect_eligibility(
		growth,
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
	var resolved := _resolve_targets(
		growth,
		zone,
		selection,
		minimum,
		maximum,
		selected_instance_ids,
		run_seed,
		sequence,
		consumable_id,
		eligibility.get("eligible_targets", []))
	if not resolved.get("success", false):
		return resolved
	var instance_ids: Array = resolved["instance_ids"]
	var effects: Array = definition.get("effects", [])
	if not effects is Array or effects.is_empty():
		return {"success": false, "reason": "消耗品没有效果"}

	var state_before: Dictionary = growth.capture_mutation_state()
	var working = growth.create_mutation_copy()
	if working == null:
		return {"success": false, "reason": "无法建立消耗品事务工作副本"}
	var applied: Array = []
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
			return {
				"success": false,
				"reason": "；".join(collector.errors),
			}
		var context = RunConsumableUseContextScript.new(
			working,
			instance_ids,
			_rng_for(run_seed, sequence, consumable_id, effect_index),
			_content_catalog,
			{
				"run_seed": run_seed,
				"consumable_use_sequence": sequence,
				"consumable_id": consumable_id,
				"effect_index": effect_index,
				"reserved_consumable_slots": 1,
			})
		var result: Dictionary = handler_registry.apply(effect, context)
		if not result.get("success", false):
			return {
				"success": false,
				"reason": str(result.get("reason", "消耗品效果执行失败")),
				"failed_effect_index": effect_index,
				"failed_operation_id": str(effect.get("op", "")),
			}
		applied.append(result.get("applied", {}).duplicate(true))

	working.consumable_ids.remove_at(slot_index)
	var kind := str(definition.get("kind", ""))
	if kind in ["pill", "insight"] \
			and bool(definition.get("record_last_used", true)):
		working.last_recallable_consumable_id = consumable_id
	working.consumable_use_sequence = sequence + 1
	var state_after: Dictionary = working.capture_mutation_state()
	var commit_errors: Array[String] = growth.replace_mutation_state(state_after)
	if not commit_errors.is_empty():
		return {"success": false, "reason": "；".join(commit_errors)}
	return {
		"success": true,
		"consumable_id": consumable_id,
		"slot_index": slot_index,
		"consumable_use_sequence": sequence + 1,
		"applied": applied,
		"changed": state_before != state_after,
	}

func _eligible_targets(growth, zone: String) -> Array:
	if zone != "run_deck" or growth == null or growth.run_deck == null:
		return []
	var result: Array = []
	for values in growth.run_deck.cards_snapshot():
		result.append(_target_summary(values))
	return result

func _query_effect_eligibility(
		growth,
		definition: Dictionary,
		zone: String,
		metadata: Dictionary) -> Dictionary:
	var context = RunConsumableUseContextScript.new(
		growth, [], null, _content_catalog, metadata)
	var eligible := _eligible_targets(growth, zone)
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
		eligible = handler_registry.eligible_targets(effect, context, eligible)
		var availability: Dictionary = handler_registry.query_availability(
			effect, context)
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

func _resolve_targets(
		growth,
		zone: String,
		selection: String,
		minimum: int,
		maximum: int,
		selected_instance_ids: Array,
		run_seed: int,
		sequence: int,
		consumable_id: String,
		eligible_targets: Array) -> Dictionary:
	if zone == "none":
		if not selected_instance_ids.is_empty():
			return {"success": false, "reason": "该消耗品不需要选择目标"}
		return {"success": true, "instance_ids": [], "mode": "none"}
	if selection == "deterministic_random":
		if not selected_instance_ids.is_empty():
			return {"success": false, "reason": "deterministic_random 不允许手动指定目标"}
		return _resolve_random_targets(
			zone, minimum, maximum, run_seed, sequence, consumable_id,
			eligible_targets)
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
		if growth == null or growth.run_deck == null \
				or not growth.run_deck.has_card(instance_id):
			return {
				"success": false,
				"reason": "目标真气不属于当前本局牌组：%s" % instance_id,
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
		zone: String,
		minimum: int,
		maximum: int,
		run_seed: int,
		sequence: int,
		consumable_id: String,
		eligible_targets: Array) -> Dictionary:
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
	var rng := _rng_for(run_seed, sequence, consumable_id, -1)
	var count := rng.randi_range(minimum, mini(maximum, ids.size()))
	var instance_ids: Array = []
	for _index in range(count):
		var chosen := rng.randi_range(0, ids.size() - 1)
		instance_ids.append(ids[chosen])
		ids.remove_at(chosen)
	return {
		"success": true,
		"instance_ids": instance_ids,
		"mode": "deterministic_random",
	}

## 相同存档状态与相同操作产生相同结果的稳定种子：run seed、使用序号、
## 消耗品 ID 与效果序号。目标顺序在 player_selected 下由选择顺序决定，
## deterministic_random 下由排序后的实例 ID 决定。
func _rng_for(
		run_seed: int,
		sequence: int,
		consumable_id: String,
		effect_index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(run_seed) * 1000003 \
		+ int(sequence) * 7919 \
		+ int(effect_index) * 9176 \
		+ _stable_id_mix(consumable_id) * 131
	return rng

func _stable_id_mix(content_id: String) -> int:
	var mixed := 0
	for index in range(content_id.length()):
		mixed = (mixed * 31 + content_id.unicode_at(index)) & 0x7FFFFFFF
	return mixed
