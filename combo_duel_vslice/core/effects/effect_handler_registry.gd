class_name EffectHandlerRegistry
extends RefCounted

const ValueResolverScript = preload("res://core/effects/effect_value_resolver.gd")
const DamageHandlerScript = preload("res://core/effects/damage_effect_handler.gd")
const DefenseHandlerScript = preload("res://core/effects/defense_effect_handler.gd")
const CardZoneHandlerScript = preload("res://core/effects/card_zone_effect_handler.gd")
const CardAnomalyHandlerScript = preload("res://core/effects/card_anomaly_effect_handler.gd")
const PermanentQiMutationHandlerScript = preload(
    "res://core/effects/permanent_qi_mutation_effect_handler.gd")
const FlowHandlerScript = preload("res://core/effects/flow_effect_handler.gd")
const ChoiceHandlerScript = preload("res://core/effects/choice_effect_handler.gd")
const CollectionHandlerScript = preload("res://core/effects/collection_effect_handler.gd")
const PoisonHandlerScript = preload("res://core/effects/poison_effect_handler.gd")
const AnomalyLayerHandlerScript = preload("res://core/effects/anomaly_layer_effect_handler.gd")
const SourceMarkerHandlerScript = preload("res://core/effects/source_marker_effect_handler.gd")
const LifeHandlerScript = preload("res://core/effects/life_effect_handler.gd")
const TechniqueSequenceHandlerScript = preload("res://core/effects/technique_sequence_effect_handler.gd")
const TechniqueExecutionHandlerScript = preload(
    "res://core/effects/technique_execution_effect_handler.gd")
const TechniquePhaseCatalogScript = preload(
    "res://core/effects/technique_phase_catalog.gd")

var value_resolver
var _handlers_by_op: Dictionary = {}
var registration_errors: Array[String] = []
var _operation_id_pattern := RegEx.new()

func _init(random_source: RandomNumberGenerator, resolver_override = null, content_catalog = null) -> void:
    _operation_id_pattern.compile("^[a-z][a-z0-9_]*$")
    value_resolver = resolver_override if resolver_override != null else ValueResolverScript.new()
    register_handler(DamageHandlerScript.new(value_resolver))
    register_handler(DefenseHandlerScript.new(value_resolver))
    register_handler(CardZoneHandlerScript.new(value_resolver, random_source))
    register_handler(CardAnomalyHandlerScript.new(value_resolver, random_source, content_catalog))
    register_handler(PermanentQiMutationHandlerScript.new())
    register_handler(FlowHandlerScript.new(value_resolver))
    register_handler(ChoiceHandlerScript.new(random_source, value_resolver))
    register_handler(CollectionHandlerScript.new(value_resolver, random_source))
    register_handler(PoisonHandlerScript.new(value_resolver))
    register_handler(AnomalyLayerHandlerScript.new(value_resolver))
    register_handler(SourceMarkerHandlerScript.new(value_resolver))
    register_handler(LifeHandlerScript.new(value_resolver))
    register_handler(TechniqueSequenceHandlerScript.new(value_resolver, random_source))
    register_handler(TechniqueExecutionHandlerScript.new(
        value_resolver, random_source))

func register_handler(handler, replace_existing: bool = false) -> bool:
    if not (handler is EffectHandler):
        registration_errors.append("效果处理器必须继承 EffectHandler")
        return false
    var operation_ids: Array = handler.operation_ids()
    if operation_ids.is_empty():
        registration_errors.append("效果处理器必须声明至少一个效果 ID")
        return false
    var seen: Dictionary = {}
    for operation_id_value in operation_ids:
        var operation_id := str(operation_id_value)
        if _operation_id_pattern.search(operation_id) == null:
            registration_errors.append("效果 ID 必须使用稳定 snake_case：%s" % operation_id)
            return false
        if seen.has(operation_id):
            registration_errors.append("单个处理器重复声明效果 ID：%s" % operation_id)
            return false
        if _handlers_by_op.has(operation_id) and not replace_existing:
            registration_errors.append("效果 ID 重复注册：%s" % operation_id)
            return false
        var default_phase := str(handler.default_phase(operation_id))
        if not TechniquePhaseCatalogScript.has_phase(default_phase):
            registration_errors.append(
                "效果 %s 声明未知默认阶段：%s" % [
                    operation_id, default_phase])
            return false
        seen[operation_id] = true
    for operation_id_value in operation_ids:
        _handlers_by_op[str(operation_id_value)] = handler
    return true

func validation_errors() -> Array[String]:
    return registration_errors.duplicate()

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

func default_phase(operation_id: String) -> String:
    var handler = _handlers_by_op.get(operation_id)
    if handler == null:
        return ""
    return str(handler.default_phase(operation_id))

func validate_effect(effect: Dictionary, validator, scope: String) -> bool:
    var operation_id := str(effect.get("op", ""))
    var handler = _handlers_by_op.get(operation_id)
    if handler == null:
        return false
    handler.validate_effect(effect, validator, scope)
    return true

func condition_met(condition: Dictionary, context) -> bool:
    return value_resolver.condition_met(condition, context)

func execute(effect: Dictionary, context):
    var operation_id := str(effect.get("op", ""))
    var handler = _handlers_by_op.get(operation_id)
    if handler == null:
        return {"success": false, "detail": "未注册的功法效果操作：%s" % operation_id}
    return handler.execute(effect, context)

func summarize(effect: Dictionary, context, intent: Dictionary, state: Dictionary) -> void:
    var handler = _handlers_by_op.get(str(effect.get("op", "")))
    if handler != null:
        handler.summarize(effect, context, intent, state)
