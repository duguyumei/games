class_name CardReshapeFreezeIndependentChancesHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "freeze_independent_chances"

func triggers() -> Array[String]:
    return ["action_confirmed"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    _validate_chance(
        behavior.get("multiplier_chance"), validator, scope + ".multiplier_chance",
        "bonus")
    _validate_chance(
        behavior.get("experience_chance"), validator, scope + ".experience_chance",
        "amount")

func execute(behavior: Dictionary, context) -> Dictionary:
    var multiplier: Dictionary = behavior["multiplier_chance"]
    var experience: Dictionary = behavior["experience_chance"]
    var multiplier_success := _roll(multiplier, context.rng)
    var experience_success := _roll(experience, context.rng)
    var multiplier_bonus := int(multiplier["bonus"]) if multiplier_success else 0
    var experience_gained := 0
    if experience_success:
        var change: Dictionary = context.effect_ports.gain_battle_experience(
            context.holder, int(experience["amount"]))
        if not change.get("success", false):
            return change
        experience_gained = int(change.get("actual_delta", 0))
    return {
        "success": true,
        "applied": true,
        "card_multiplier_bonus": multiplier_bonus,
        "frozen": {
            "multiplier_success": multiplier_success,
            "multiplier_bonus": multiplier_bonus,
            "experience_success": experience_success,
            "experience_gained": experience_gained,
        },
    }

func _roll(spec: Dictionary, rng: RandomNumberGenerator) -> bool:
    return rng.randi_range(1, int(spec["denominator"])) <= int(spec["numerator"])

func _validate_chance(
        value,
        validator,
        scope: String,
        reward_field: String) -> void:
    if not value is Dictionary:
        validator.report_error(scope, "必须是对象")
        return
    var spec: Dictionary = value
    if not _is_integer(spec.get("numerator")) \
            or int(spec.get("numerator", 0)) <= 0:
        validator.report_error(scope + ".numerator", "必须是正整数")
    if not _is_integer(spec.get("denominator")) \
            or int(spec.get("denominator", 0)) <= 0:
        validator.report_error(scope + ".denominator", "必须是正整数")
    elif int(spec.get("numerator", 0)) > int(spec["denominator"]):
        validator.report_error(scope + ".numerator", "不能大于 denominator")
    if not _is_integer(spec.get(reward_field)) \
            or int(spec.get(reward_field, 0)) < 0:
        validator.report_error(scope + "." + reward_field, "必须是非负整数")

func _is_integer(value) -> bool:
    return value is int or value is float and float(value) == floor(float(value))
