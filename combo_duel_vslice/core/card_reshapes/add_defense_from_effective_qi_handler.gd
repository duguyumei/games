class_name CardReshapeAddDefenseFromEffectiveQiHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "add_defense_from_effective_qi"

func triggers() -> Array[String]:
    return ["card_played", "turn_end"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    if behavior.has("origin_attribute") \
            and not ["wind", "forest", "fire", "mountain"].has(
            str(behavior.get("origin_attribute", ""))):
        validator.report_error(scope + ".origin_attribute", "必须是正式基础属性")

func execute(behavior: Dictionary, context) -> Dictionary:
    if not context.matches_origin_attribute(behavior) \
            or context.trigger == "turn_end" \
            and not context.holder.hand.has(context.card):
        return {"success": true, "defense": 0, "applied": false}
    var amount: int = context.effect_ports.current_effective_qi(
        context.holder, context.card)
    var gained: int = context.effect_ports.add_defense(context.holder, amount)
    return {"success": true, "defense": gained, "applied": true}
