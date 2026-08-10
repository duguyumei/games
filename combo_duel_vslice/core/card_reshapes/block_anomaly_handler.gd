class_name CardReshapeBlockAnomalyHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "block_anomaly_application"

func triggers() -> Array[String]:
    return ["anomaly_apply"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    for field in ["categories", "anomaly_ids"]:
        if behavior.has(field) and not behavior[field] is Array:
            validator.report_error(scope + "." + field, "必须是数组")

func execute(behavior: Dictionary, context) -> Dictionary:
    var categories: Array = behavior.get("categories", [])
    var anomaly_ids: Array = behavior.get("anomaly_ids", [])
    var blocks_category := categories.has(context.anomaly_category)
    var blocks_id := anomaly_ids.has(context.anomaly_id)
    if not categories.is_empty() or not anomaly_ids.is_empty():
        if not blocks_category and not blocks_id:
            return {"success": true, "blocked": false}
    return {
        "success": true,
        "blocked": true,
        "reason": str(behavior.get("reason", "此真气不能获得异状")),
    }
