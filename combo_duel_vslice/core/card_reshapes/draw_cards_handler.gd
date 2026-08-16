class_name CardReshapeDrawCardsHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "draw_cards"

func triggers() -> Array[String]:
    return ["card_drawn"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    if not _is_integer(behavior.get("count")) or int(behavior.get("count", 0)) <= 0:
        validator.report_error(scope + ".count", "必须是正整数")
    _validate_attribute(behavior, validator, scope)

func execute(behavior: Dictionary, context) -> Dictionary:
    if not context.matches_origin_attribute(behavior):
        return {"success": true, "drawn": [], "applied": false}
    var drawn: Array = context.effect_ports.draw(
        context.holder, int(behavior["count"]), {
            "source_kind": "card_reshape",
            "source_id": str(context.card.reshape_origin.get("id", "reshape")),
            "source_name": "真气重塑",
            "source_instance_key": "card_reshape:%s" % str(context.card.id),
            "trigger_mode": "direct",
        })
    return {"success": true, "drawn": drawn, "applied": true}

func _validate_attribute(behavior: Dictionary, validator, scope: String) -> void:
    if not ["wind", "forest", "fire", "mountain"].has(
            str(behavior.get("origin_attribute", ""))):
        validator.report_error(scope + ".origin_attribute", "必须是正式基础属性")

func _is_integer(value) -> bool:
    return value is int or value is float and float(value) == floor(float(value))
