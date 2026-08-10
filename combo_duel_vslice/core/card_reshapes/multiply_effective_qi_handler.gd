class_name CardReshapeMultiplyEffectiveQiHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "multiply_effective_qi"

func triggers() -> Array[String]:
    return ["effective_qi"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    if not behavior.has("factor") or not _is_integer(behavior.get("factor")) \
            or int(behavior.get("factor", 0)) <= 0:
        validator.report_error(scope + ".factor", "必须是正整数")
    if behavior.has("origin_attribute") \
            and not ["wind", "forest", "fire", "mountain"].has(
                str(behavior.get("origin_attribute", ""))):
        validator.report_error(scope + ".origin_attribute", "必须是正式基础属性")
    if behavior.has("requires_participating") \
            and not behavior.get("requires_participating") is bool:
        validator.report_error(scope + ".requires_participating", "必须是布尔值")

func execute(behavior: Dictionary, context) -> Dictionary:
    if not context.matches_origin_attribute(behavior):
        return {"success": true, "value": context.value, "applied": false}
    if bool(behavior.get("requires_participating", false)) \
            and not bool(context.calculation_context.get("participating", false)):
        return {"success": true, "value": context.value, "applied": false}
    var factor := int(behavior.get("factor", 1))
    context.value *= factor
    return {"success": true, "value": context.value, "factor": factor}

func _is_integer(value) -> bool:
    return value is int or value is float and float(value) == floor(float(value))
