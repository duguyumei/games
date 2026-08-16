class_name CardReshapeDealDamageFromEffectiveQiHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "deal_damage_from_effective_qi"

func triggers() -> Array[String]:
    return ["card_played"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    if str(behavior.get("source_kind", "")) == "":
        validator.report_error(scope + ".source_kind", "必须是非空字符串")

func execute(behavior: Dictionary, context) -> Dictionary:
    var target = context.effect_ports.opponent_of(context.holder)
    var amount: int = context.effect_ports.current_effective_qi(
        context.holder, context.card)
    var result: Dictionary = context.effect_ports.deal_damage(
        context.holder,
        target,
        amount,
        {
            "source_kind": "card_reshape",
            "source_id": str(behavior["source_kind"]),
            "source_name": "真气重塑",
            "source_instance_key": "card_reshape:%s" % str(context.card.id),
            "trigger_mode": "direct",
        })
    result["applied"] = bool(result.get("success", false))
    return result
