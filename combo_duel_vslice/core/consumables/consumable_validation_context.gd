class_name ConsumableValidationContext
extends RefCounted

## 消耗品效果在内容加载阶段的窄校验上下文。
##
## 只向 Handler 暴露校验器的最小表面（report_error、内容引用查询）和消耗品
## 专属词表（精确牌型、功法池、牌型成员资格）。Handler 不需要知道
## ContentValidator 的其余结构，ContentValidator 也不复制 Handler 的字段规则。

var validator
var hand_ids: Array = []
var pool_ids: Array = []
var pool_membership: Dictionary = {}
var _content_catalog

func _init(
		validator_override,
		hand_ids_override: Array = [],
		pool_ids_override: Array = [],
		pool_membership_override: Dictionary = {},
		content_catalog = null) -> void:
	validator = validator_override
	hand_ids = hand_ids_override.duplicate()
	pool_ids = pool_ids_override.duplicate()
	pool_membership = pool_membership_override.duplicate(true)
	_content_catalog = content_catalog

func report_error(scope: String, message: String) -> void:
	if validator != null and validator.has_method("report_error"):
		validator.report_error(scope, message)

func has_content_id(content_type: String, content_id: String) -> bool:
	if validator != null and validator.has_method("has_content_id"):
		return validator.has_content_id(content_type, content_id)
	return _content_catalog != null and _content_catalog.has_id(content_type, content_id)

func content_definition(content_type: String, content_id: String) -> Dictionary:
	if validator != null and validator.has_method("content_definition"):
		return validator.content_definition(content_type, content_id)
	if _content_catalog == null:
		return {}
	return _content_catalog.get_by_id(content_type, content_id)

func membership_for(hand_id: String) -> Array:
	return pool_membership.get(hand_id, [])

func legal_attribute_ids() -> Array[String]:
	var result: Array[String] = []
	var base_deck: Dictionary = {}
	if _content_catalog != null:
		base_deck = _content_catalog.definition("base_deck")
	elif validator != null and validator.has_method("base_deck_definition"):
		base_deck = validator.base_deck_definition()
	for attribute in base_deck.get("attributes", []):
		result.append(str(attribute.get("id", "")))
	return result
