class_name CardReshapeBehaviorRegistry
extends RefCounted

const HandlerScript = preload("res://core/card_reshapes/card_reshape_behavior_handler.gd")
const ContextScript = preload("res://core/card_reshapes/card_reshape_behavior_context.gd")
const AddContributionScript = preload("res://core/card_reshapes/add_card_contribution_handler.gd")
const AddMultiplierScript = preload("res://core/card_reshapes/add_technique_multiplier_handler.gd")
const AddPowerAmpScript = preload("res://core/card_reshapes/add_power_amp_handler.gd")
const AttributeAliasScript = preload("res://core/card_reshapes/attribute_alias_handler.gd")
const MultiplyQiScript = preload("res://core/card_reshapes/multiply_effective_qi_handler.gd")
const SetQiScript = preload("res://core/card_reshapes/set_effective_qi_handler.gd")
const BlockAnomalyScript = preload("res://core/card_reshapes/block_anomaly_handler.gd")
const ClearAnomaliesScript = preload("res://core/card_reshapes/clear_anomalies_handler.gd")

const TRIGGERS := [
    "card_contribution", "technique_multiplier", "power_amp",
    "attribute_check", "effective_qi", "anomaly_apply", "reshape_applied",
]

var _handlers: Dictionary = {}
var _errors: Array[Dictionary] = []
var _id_pattern := RegEx.new()

func _init(register_defaults: bool = true) -> void:
    _id_pattern.compile("^[a-z][a-z0-9_]*$")
    if register_defaults:
        register_handler(AddContributionScript.new())
        register_handler(AddMultiplierScript.new())
        register_handler(AddPowerAmpScript.new())
        register_handler(AttributeAliasScript.new())
        register_handler(MultiplyQiScript.new())
        register_handler(SetQiScript.new())
        register_handler(BlockAnomalyScript.new())
        register_handler(ClearAnomaliesScript.new())

func register_handler(handler) -> bool:
    if not (handler is HandlerScript):
        _error("invalid_handler", "重塑行为处理器必须继承 CardReshapeBehaviorHandler", "")
        return false
    var behavior_id := str(handler.behavior_id())
    if behavior_id == "":
        _error("empty_id", "重塑行为 ID 不能为空", "")
        return false
    if _id_pattern.search(behavior_id) == null:
        _error("invalid_id", "重塑行为 ID 必须使用稳定 snake_case：%s" % behavior_id, behavior_id)
        return false
    if _handlers.has(behavior_id):
        _error("duplicate_id", "重塑行为 ID 重复注册：%s" % behavior_id, behavior_id)
        return false
    var triggers: Array = handler.triggers()
    for trigger in triggers:
        if not TRIGGERS.has(str(trigger)):
            _error("invalid_trigger", "重塑行为声明未知触发时点：%s" % str(trigger), behavior_id)
            return false
    _handlers[behavior_id] = handler
    return true

func has_handler(behavior_id: String) -> bool:
    return _handlers.has(behavior_id)

func handler_ids() -> Array[String]:
    var result: Array[String] = []
    for key in _handlers:
        result.append(str(key))
    result.sort()
    return result

func registration_errors() -> Array[Dictionary]:
    return _errors.duplicate(true)

func registration_error_details() -> Array[Dictionary]:
    return registration_errors()

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    var handler_id := str(behavior.get("handler", ""))
    var handler = _handlers.get(handler_id)
    if handler == null:
        validator.report_error(scope + ".handler", "未注册的重塑行为处理器：%s" % handler_id)
        return
    var trigger := str(behavior.get("trigger", ""))
    if not handler.triggers().has(trigger):
        validator.report_error(
            scope + ".trigger", "行为 %s 不支持触发时点 %s" % [handler_id, trigger])
        return
    handler.validate_behavior(behavior, validator, scope)

func execute(behavior: Dictionary, context) -> Dictionary:
    var handler = _handlers.get(str(behavior.get("handler", "")))
    if handler == null:
        return {"success": false, "reason": "未注册的重塑行为处理器"}
    return handler.execute(behavior, context)

func _error(code: String, message: String, behavior_id: String) -> void:
    _errors.append({"code": code, "behavior_id": behavior_id, "message": message})
