class_name CardReshapeBlockAnomalyHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "block_anomaly_application"

func triggers() -> Array[String]:
    return ["anomaly_apply"]

func execute(behavior: Dictionary, context) -> Dictionary:
    return {"success": true, "blocked": true, "reason": str(behavior.get("reason", "此真气不能获得异状"))}
