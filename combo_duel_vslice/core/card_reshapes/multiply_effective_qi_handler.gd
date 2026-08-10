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

func execute(behavior: Dictionary, context) -> Dictionary:
    var factor := int(behavior.get("factor", 1))
    context.value *= factor
    return {"success": true, "value": context.value, "factor": factor}

func _is_integer(value) -> bool:
    return value is int or value is float and float(value) == floor(float(value))
