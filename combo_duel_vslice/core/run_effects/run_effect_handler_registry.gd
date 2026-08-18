class_name RunEffectHandlerRegistry
extends RefCounted

const GainExperienceHandlerScript = preload(
    "res://core/run_effects/gain_experience_run_effect_handler.gd")
const HealLifeHandlerScript = preload(
    "res://core/run_effects/heal_life_run_effect_handler.gd")
const RunCardCollectionHandlerScript = preload(
    "res://core/run_effects/run_card_collection_effect_handler.gd")
const RunCardTransformHandlerScript = preload(
    "res://core/run_effects/run_card_transform_effect_handler.gd")
const RunCardReshapeHandlerScript = preload(
    "res://core/run_effects/run_card_reshape_effect_handler.gd")
const GrantTechniquesHandlerScript = preload(
    "res://core/run_effects/grant_techniques_run_effect_handler.gd")
const GrantInnerSkillsHandlerScript = preload(
    "res://core/run_effects/grant_inner_skills_run_effect_handler.gd")
const GrantConsumablesHandlerScript = preload(
    "res://core/run_effects/grant_consumables_run_effect_handler.gd")
const GrantItemsHandlerScript = preload(
    "res://core/run_effects/grant_items_run_effect_handler.gd")
const SourceMarkerHandlerScript = preload(
    "res://core/run_effects/run_source_marker_effect_handler.gd")

var _handlers_by_operation: Dictionary = {}
var _registration_errors: Array[String] = []
var _operation_id_pattern := RegEx.new()

func _init(register_defaults: bool = true) -> void:
    _operation_id_pattern.compile("^[a-z][a-z0-9_]*$")
    if register_defaults:
        register_handler(RunCardCollectionHandlerScript.new())
        register_handler(RunCardReshapeHandlerScript.new())
        register_handler(RunCardTransformHandlerScript.new())
        register_handler(GainExperienceHandlerScript.new())
        register_handler(HealLifeHandlerScript.new())
        register_handler(GrantTechniquesHandlerScript.new())
        register_handler(GrantInnerSkillsHandlerScript.new())
        register_handler(GrantConsumablesHandlerScript.new())
        register_handler(GrantItemsHandlerScript.new())
        register_handler(SourceMarkerHandlerScript.new())

func register_handler(handler) -> bool:
    if handler == null \
            or not handler.has_method("operation_ids") \
            or not handler.has_method("validate_effect") \
            or not handler.has_method("apply"):
        _registration_errors.append(
            "本局效果处理器必须实现 operation_ids、validate_effect 与 apply")
        return false
    var declared_ids: Array = handler.operation_ids()
    if declared_ids.is_empty():
        _registration_errors.append("本局效果处理器必须声明至少一个操作 ID")
        return false
    var seen: Dictionary = {}
    for operation_id_value in declared_ids:
        var operation_id := str(operation_id_value)
        if _operation_id_pattern.search(operation_id) == null:
            _registration_errors.append(
                "本局效果操作 ID 必须使用稳定 snake_case：%s" % operation_id)
            return false
        if seen.has(operation_id):
            _registration_errors.append(
                "单个本局效果处理器重复声明操作 ID：%s" % operation_id)
            return false
        if _handlers_by_operation.has(operation_id):
            _registration_errors.append(
                "本局效果操作 ID 重复注册：%s" % operation_id)
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
            "未注册的本局效果操作：%s" % operation_id)
        return false
    handler.validate_effect(effect, validator, scope)
    return true

func apply(effect: Dictionary, context) -> Dictionary:
    var operation_id := str(effect.get("op", ""))
    var handler = _handlers_by_operation.get(operation_id)
    if handler == null:
        return {
            "success": false,
            "reason": "未注册的本局效果操作：%s" % operation_id,
        }
    return handler.apply(effect, context)
