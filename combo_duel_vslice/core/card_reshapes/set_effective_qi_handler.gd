class_name CardReshapeSetEffectiveQiHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "set_effective_qi"

func triggers() -> Array[String]:
    return ["effective_qi"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    if not behavior.has("value") or not _is_integer(behavior.get("value")) \
            or int(behavior.get("value", -1)) < 0:
        validator.report_error(scope + ".value", "必须是非负整数")

func execute(behavior: Dictionary, context) -> Dictionary:
    var value := int(behavior.get("value", 0))
    context.value = value
    return {"success": true, "value": value}

func _is_integer(value) -> bool:
    return value is int or value is float and float(value) == floor(float(value))
