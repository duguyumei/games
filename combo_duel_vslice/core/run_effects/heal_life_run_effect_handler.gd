class_name HealLifeRunEffectHandler
extends "res://core/run_effects/run_effect_handler.gd"

func operation_ids() -> Array[String]:
    return ["heal_life"]

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    var has_amount := effect.has("amount")
    var has_percent := effect.has("max_life_percent")
    if has_amount == has_percent:
        validator.report_error(
            scope,
            "heal_life 必须且只能提供 amount 或 max_life_percent 之一")
        return
    if has_amount:
        var amount = effect["amount"]
        if not _is_integer(amount) or int(amount) <= 0:
            validator.report_error(scope + ".amount", "heal_life amount 必须是正整数")
        return
    var percent = effect["max_life_percent"]
    if not (percent is int or percent is float) or float(percent) <= 0.0:
        validator.report_error(
            scope + ".max_life_percent",
            "heal_life max_life_percent 必须是正数")

func apply(effect: Dictionary, context) -> Dictionary:
    var life_before := int(context.growth.life)
    var max_life := int(context.growth.max_life)
    var theoretical_amount := (
        int(effect["amount"])
        if effect.has("amount")
        else floori(max_life * float(effect["max_life_percent"]) / 100.0))
    var life_after := mini(life_before + theoretical_amount, max_life)
    context.growth.life = life_after
    return {
        "success": true,
        "applied": {
            "op": "heal_life",
            "kind": str(effect.get("kind", "healing")),
            "life_before": life_before,
            "life_after": life_after,
            "theoretical_amount": theoretical_amount,
            "actual_amount": life_after - life_before,
        },
    }

func _is_integer(value) -> bool:
    return (value is int or value is float) and float(value) == floor(float(value))
