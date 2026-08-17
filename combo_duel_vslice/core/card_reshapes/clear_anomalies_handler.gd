class_name CardReshapeClearAnomaliesHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "clear_anomalies_on_apply"

func triggers() -> Array[String]:
    return ["reshape_applied"]

func execute(behavior: Dictionary, context) -> Dictionary:
    if context.card == null or context.effect_ports == null:
        return {"success": false, "removed": {}}
    return context.effect_ports.clear_card_anomalies(
        context.card, "永久重塑清除异状", {
            "holder": context.holder,
            "source_actor": context.holder,
            "action_token": context.action_token,
            "source_kind": "card_reshape",
            "source_id": str(context.card.reshape_origin.get("id", "reshape")),
            "source_name": "永久重塑清除异状",
            "source_instance_key": "card_reshape:%s" % str(context.card.id),
            "trigger_mode": "direct",
            "operation": "clear",
        })
