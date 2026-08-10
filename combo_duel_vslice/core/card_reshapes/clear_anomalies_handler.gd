class_name CardReshapeClearAnomaliesHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "clear_anomalies_on_apply"

func triggers() -> Array[String]:
    return ["reshape_applied"]

func execute(behavior: Dictionary, context) -> Dictionary:
    var removed = context.card.clear_anomalies() if context.card != null else {}
    return {"success": true, "removed": removed}
