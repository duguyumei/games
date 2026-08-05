class_name EffectHandlerRegistry
extends RefCounted

const ValueResolverScript = preload("res://core/effects/effect_value_resolver.gd")
const DamageHandlerScript = preload("res://core/effects/damage_effect_handler.gd")
const DefenseHandlerScript = preload("res://core/effects/defense_effect_handler.gd")
const CardZoneHandlerScript = preload("res://core/effects/card_zone_effect_handler.gd")
const CardAnomalyHandlerScript = preload("res://core/effects/card_anomaly_effect_handler.gd")
const StackHandlerScript = preload("res://core/effects/stack_effect_handler.gd")
const FlowHandlerScript = preload("res://core/effects/flow_effect_handler.gd")

var value_resolver
var _handlers_by_op: Dictionary = {}

func _init(random_source: RandomNumberGenerator, resolver_override = null, content_catalog = null) -> void:
    value_resolver = resolver_override if resolver_override != null else ValueResolverScript.new()
    register_handler(DamageHandlerScript.new(value_resolver))
    register_handler(DefenseHandlerScript.new(value_resolver))
    register_handler(CardZoneHandlerScript.new(value_resolver, random_source))
    register_handler(CardAnomalyHandlerScript.new(value_resolver, random_source, content_catalog))
    register_handler(StackHandlerScript.new(value_resolver))
    register_handler(FlowHandlerScript.new(value_resolver))

func register_handler(handler, replace_existing: bool = false) -> bool:
    if handler == null or not handler.has_method("operation_ids") \
            or not handler.has_method("execute") or not handler.has_method("summarize"):
        return false
    var operation_ids: Array = handler.operation_ids()
    if operation_ids.is_empty():
        return false
    for operation_id_value in operation_ids:
        var operation_id := str(operation_id_value)
        if operation_id == "" or (_handlers_by_op.has(operation_id) and not replace_existing):
            return false
    for operation_id_value in operation_ids:
        _handlers_by_op[str(operation_id_value)] = handler
    return true

func has_handler(operation_id: String) -> bool:
    return _handlers_by_op.has(operation_id)

func operation_ids() -> Array[String]:
    var result: Array[String] = []
    for operation_id in _handlers_by_op:
        result.append(str(operation_id))
    result.sort()
    return result

func handler_group(operation_id: String) -> String:
    var handler = _handlers_by_op.get(operation_id)
    if handler == null or not handler.has_method("group_name"):
        return ""
    return str(handler.group_name())

func condition_met(condition: Dictionary, context: Dictionary) -> bool:
    return value_resolver.condition_met(condition, context)

func execute(effect: Dictionary, context: Dictionary) -> Dictionary:
    var operation_id := str(effect.get("op", ""))
    var handler = _handlers_by_op.get(operation_id)
    if handler == null:
        return {"success": false, "detail": "未注册的功法效果操作：%s" % operation_id}
    return handler.execute(effect, context)

func summarize(effect: Dictionary, context: Dictionary, intent: Dictionary, state: Dictionary) -> void:
    var handler = _handlers_by_op.get(str(effect.get("op", "")))
    if handler != null:
        handler.summarize(effect, context, intent, state)
