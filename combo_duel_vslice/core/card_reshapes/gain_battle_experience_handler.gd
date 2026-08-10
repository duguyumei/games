class_name CardReshapeGainBattleExperienceHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "gain_battle_experience"

func triggers() -> Array[String]:
    return ["battle_victory"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    if not _is_integer(behavior.get("amount")) or int(behavior.get("amount", 0)) < 0:
        validator.report_error(scope + ".amount", "必须是非负整数")

func execute(behavior: Dictionary, context) -> Dictionary:
    var gained: int = context.effect_ports.gain_battle_experience(
        context.holder, int(behavior["amount"]))
    return {
        "success": true,
        "experience_gained": gained,
        "applied": gained > 0,
    }

func _is_integer(value) -> bool:
    return value is int or value is float and float(value) == floor(float(value))
