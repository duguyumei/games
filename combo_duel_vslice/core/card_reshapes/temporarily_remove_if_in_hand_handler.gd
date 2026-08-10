class_name CardReshapeTemporarilyRemoveIfInHandHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "temporarily_remove_if_in_hand"

func triggers() -> Array[String]:
    return ["turn_end_final"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    if str(behavior.get("reason", "")) == "":
        validator.report_error(scope + ".reason", "必须是非空字符串")

func execute(behavior: Dictionary, context) -> Dictionary:
    if not context.holder.hand.has(context.card):
        return {"success": true, "removed": false, "applied": false}
    var result: Dictionary = context.effect_ports.temporarily_remove_card(
        context.holder,
        str(context.card.id),
        str(behavior["reason"]))
    result["applied"] = bool(result.get("success", false))
    return result
