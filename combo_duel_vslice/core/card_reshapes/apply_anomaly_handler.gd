class_name CardReshapeApplyAnomalyHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "apply_anomaly"

func triggers() -> Array[String]:
    return ["group_resolved", "battle_start"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    if str(behavior.get("trigger", "")) == "group_resolved" \
            and not ["wind", "forest", "fire", "mountain"].has(
                str(behavior.get("origin_attribute", ""))):
        validator.report_error(scope + ".origin_attribute", "必须是正式基础属性")
    if str(behavior.get("category", "")) == "":
        validator.report_error(scope + ".category", "必须是非空字符串")
    if str(behavior.get("anomaly", "")) == "":
        validator.report_error(scope + ".anomaly", "必须是非空字符串")

func execute(behavior: Dictionary, context) -> Dictionary:
    if behavior.has("origin_attribute") and not context.matches_origin_attribute(behavior):
        return {"success": true, "applied": false}
    var result: Dictionary = context.effect_ports.apply_card_anomaly(
        context.card,
        str(behavior["category"]),
        str(behavior["anomaly"]),
        {},
        "重塑行为", 1, false, {
            "holder": context.holder,
            "actor": context.holder,
            "action_token": context.action_token,
            "source_kind": "reshape_behavior",
        })
    result["applied"] = bool(result.get("success", false))
    return result
