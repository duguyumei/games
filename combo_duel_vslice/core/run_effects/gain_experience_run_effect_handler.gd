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
    var changed: Dictionary = context.change_experience(amount, {
        "operation": "gain",
        "reason": str(effect.get("source", effect.get("kind", "experience"))),
    })
    if not changed.get("success", false):
        return changed
    return {
        "success": true,
        "applied": {
            "op": "gain_experience",
            "kind": str(effect.get("kind", "experience")),
            "source": str(effect.get("source", "")),
            "amount": int(changed.get("actual_delta", 0)),
            "requested_amount": amount,
            "experience_before": int(changed.get("experience_before", 0)),
            "experience_after": int(changed.get("experience_after", 0)),
            "experience_change": changed.duplicate(true),
        },
    }

func _is_integer(value) -> bool:
    return (value is int or value is float) and float(value) == floor(float(value))
