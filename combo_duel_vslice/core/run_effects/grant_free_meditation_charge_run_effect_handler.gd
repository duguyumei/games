class_name GrantFreeMeditationChargeRunEffectHandler
extends "res://core/run_effects/run_effect_handler.gd"

func operation_ids() -> Array[String]:
    return ["grant_free_meditation_charge"]

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    for field in effect:
        if str(field) not in ["op", "source"]:
            validator.report_error(scope + "." + str(field), "不支持该字段")

func apply(_effect: Dictionary, context) -> Dictionary:
    var before := clampi(int(context.growth.free_meditation_charge), 0, 1)
    context.growth.free_meditation_charge = 1
    return {
        "success": true,
        "applied": {
            "op": "grant_free_meditation_charge",
            "before": before,
            "after": 1,
            "changed": before != 1,
        },
    }
