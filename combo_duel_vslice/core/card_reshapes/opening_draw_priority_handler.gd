class_name CardReshapeOpeningDrawPriorityHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "opening_draw_priority"

func triggers() -> Array[String]:
    return ["battle_start_hand_priority"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    for field in behavior:
        if str(field) not in ["trigger", "handler"]:
            validator.report_error(scope + "." + str(field), "起始抽牌优先行为不接受额外参数")

func execute(_behavior: Dictionary, context) -> Dictionary:
    var moved: Dictionary = context.effect_ports.place_on_draw_pile_top(
        context.holder, context.card)
    return {
        "success": bool(moved.get("success", false)),
        "applied": bool(moved.get("success", false)),
        "reason": str(moved.get("reason", "")),
    }
