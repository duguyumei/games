class_name CardReshapeRecycleDiscardedCardHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "recycle_discarded_card"

func triggers() -> Array[String]:
    return ["card_entered_discard"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    if not ["wind", "forest", "fire", "mountain"].has(
            str(behavior.get("origin_attribute", ""))):
        validator.report_error(scope + ".origin_attribute", "必须是正式基础属性")

func execute(behavior: Dictionary, context) -> Dictionary:
    if not context.matches_origin_attribute(behavior) \
            or not context.holder.discard_pile.has(context.card):
        return {"success": true, "moved": false, "applied": false}
    var moved: Dictionary = context.effect_ports.move_card(
        context.holder,
        "discard_pile",
        context.holder,
        "draw_pile",
        context.card,
        "reshape_recycle")
    if moved.get("success", false):
        context.effect_ports.shuffle_zone(context.holder, "draw_pile", context.rng)
    return {
        "success": bool(moved.get("success", false)),
        "moved": bool(moved.get("success", false)),
        "applied": bool(moved.get("success", false)),
    }
