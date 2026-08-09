class_name GainExperienceRunEffectHandler
extends "res://core/run_effects/run_effect_handler.gd"

func operation_ids() -> Array[String]:
    return ["gain_experience"]

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    var amount = effect.get("amount")
    if not _is_integer(amount) or int(amount) < 0:
        validator.report_error(scope + ".amount", "gain_experience amount 必须是非负整数")

func apply(effect: Dictionary, context) -> Dictionary:
    var amount := int(effect["amount"])
    var before := int(context.growth.experience)
    context.growth.experience += amount
    return {
        "success": true,
        "applied": {
            "op": "gain_experience",
            "kind": str(effect.get("kind", "experience")),
            "source": str(effect.get("source", "")),
            "amount": amount,
            "experience_before": before,
            "experience_after": int(context.growth.experience),
        },
    }

func _is_integer(value) -> bool:
    return (value is int or value is float) and float(value) == floor(float(value))
