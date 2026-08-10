class_name CardReshapeAddPowerAmpHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "add_power_amp_percent"

func triggers() -> Array[String]:
    return ["power_amp"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    if not behavior.has("amount") or not _is_integer(behavior.get("amount")):
        validator.report_error(scope + ".amount", "必须是整数")

func execute(behavior: Dictionary, context) -> Dictionary:
    var amount := int(behavior.get("amount", 0))
    context.value += amount
    return {"success": true, "value": context.value, "amount": amount}

func _is_integer(value) -> bool:
    return value is int or value is float and float(value) == floor(float(value))
