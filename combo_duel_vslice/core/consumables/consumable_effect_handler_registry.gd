class_name ConsumableEffectHandlerRegistry
extends RefCounted

const GainInsightHandlerScript = preload(
	"res://core/consumables/gain_insight_consumable_handler.gd")
const CardReshapeHandlerScript = preload(
	"res://core/consumables/card_reshape_consumable_handler.gd")
const CardCollectionHandlerScript = preload(
	"res://core/consumables/card_collection_consumable_handler.gd")
const RandomReshapeHandlerScript = preload(
	"res://core/consumables/random_reshape_consumable_handler.gd")
const ConsumableGrantHandlerScript = preload(
	"res://core/consumables/consumable_grant_handler.gd")
const ExperienceHandlerScript = preload(
	"res://core/consumables/experience_consumable_handler.gd")
const InnerSkillHandlerScript = preload(
	"res://core/consumables/inner_skill_consumable_handler.gd")

var _handlers_by_operation: Dictionary = {}
var _registration_errors: Array[String] = []
var _operation_id_pattern := RegEx.new()

func _init(register_defaults: bool = true) -> void:
	_operation_id_pattern.compile("^[a-z][a-z0-9_]*$")
	if register_defaults:
		register_handler(GainInsightHandlerScript.new())
		register_handler(CardReshapeHandlerScript.new())
		register_handler(CardCollectionHandlerScript.new())
		register_handler(RandomReshapeHandlerScript.new())
		register_handler(ConsumableGrantHandlerScript.new())
		register_handler(ExperienceHandlerScript.new())
		register_handler(InnerSkillHandlerScript.new())

func register_handler(handler) -> bool:
	if handler == null \
			or not handler.has_method("operation_ids") \
			or not handler.has_method("validate_effect") \
			or not handler.has_method("apply"):
		_registration_errors.append(
			"消耗品效果处理器必须实现 operation_ids、validate_effect 与 apply")
		return false
	var declared_ids: Array = handler.operation_ids()
	if declared_ids.is_empty():
		_registration_errors.append("消耗品效果处理器必须声明至少一个操作 ID")
		return false
	var seen: Dictionary = {}
	for operation_id_value in declared_ids:
		var operation_id := str(operation_id_value)
		if _operation_id_pattern.search(operation_id) == null:
			_registration_errors.append(
				"消耗品效果操作 ID 必须使用稳定 snake_case：%s" % operation_id)
			return false
		if seen.has(operation_id):
			_registration_errors.append(
				"单个消耗品效果处理器重复声明操作 ID：%s" % operation_id)
			return false
		if _handlers_by_operation.has(operation_id):
			_registration_errors.append(
				"消耗品效果操作 ID 重复注册：%s" % operation_id)
			return false
		seen[operation_id] = true
	for operation_id_value in declared_ids:
		_handlers_by_operation[str(operation_id_value)] = handler
	return true

func has_handler(operation_id: String) -> bool:
	return _handlers_by_operation.has(operation_id)

func operation_ids() -> Array[String]:
	var result: Array[String] = []
	for operation_id in _handlers_by_operation:
		result.append(str(operation_id))
	result.sort()
	return result

func registration_errors() -> Array[String]:
	return _registration_errors.duplicate()

func validate_effect(effect: Dictionary, validator, scope: String) -> bool:
	var operation_id := str(effect.get("op", ""))
	var handler = _handlers_by_operation.get(operation_id)
	if handler == null:
		validator.report_error(
			scope + ".op",
			"未注册的消耗品效果操作：%s" % operation_id)
		return false
	handler.validate_effect(effect, validator, scope)
	return true

func apply(effect: Dictionary, context) -> Dictionary:
	var operation_id := str(effect.get("op", ""))
	var handler = _handlers_by_operation.get(operation_id)
	if handler == null:
		return {
			"success": false,
			"reason": "未注册的消耗品效果操作：%s" % operation_id,
		}
	return handler.apply(effect, context)

func eligible_targets(effect: Dictionary, context, candidates: Array) -> Array:
	var operation_id := str(effect.get("op", ""))
	var handler = _handlers_by_operation.get(operation_id)
	if handler == null or not handler.has_method("eligible_targets"):
		return candidates.duplicate(true)
	return handler.eligible_targets(effect, context, candidates)

func query_availability(effect: Dictionary, context) -> Dictionary:
	var operation_id := str(effect.get("op", ""))
	var handler = _handlers_by_operation.get(operation_id)
	if handler == null:
		return {
			"can_use": false,
			"reason": "未注册的消耗品效果操作：%s" % operation_id,
		}
	if not handler.has_method("query_availability"):
		return {"can_use": true, "reason": ""}
	return handler.query_availability(effect, context)
