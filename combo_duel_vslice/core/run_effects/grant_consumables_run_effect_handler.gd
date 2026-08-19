class_name GrantConsumablesRunEffectHandler
extends "res://core/run_effects/run_effect_handler.gd"

func operation_ids() -> Array[String]:
    return ["grant_consumables"]

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    var ids := _validate_ids(
        effect.get("consumable_ids"), validator, scope + ".consumable_ids")
    for index in range(ids.size()):
        var content_id := str(ids[index])
        if validator.has_method("has_content_id") \
                and not validator.has_content_id("consumable", content_id):
            validator.report_error(
                "%s.consumable_ids[%d]" % [scope, index],
                "引用未知消耗品：%s" % content_id)
        elif validator.has_method("is_formally_obtainable") \
                and not validator.is_formally_obtainable("consumable", content_id):
            validator.report_error(
                "%s.consumable_ids[%d]" % [scope, index],
                "消耗品未达到正式可获得状态：%s" % content_id)

func apply(effect: Dictionary, context) -> Dictionary:
    var ids: Array = effect["consumable_ids"]
    var capacity: Dictionary = context.growth.effective_consumable_capacity_result()
    if not capacity.get("success", false):
        return capacity
    if context.growth.consumable_ids.size() + ids.size() \
            > int(capacity.get("effective_capacity", 0)):
        return {"success": false, "reason": "整组发放后将超过共享消耗品栏容量"}
    for content_id_value in ids:
        var content_id := str(content_id_value)
        if context.content_catalog == null:
            return {"success": false, "reason": "本局效果缺少内容目录"}
        if not context.content_catalog.has_id("consumable", content_id):
            return {"success": false, "reason": "引用未知消耗品：%s" % content_id}
        if not context.content_catalog.is_formally_obtainable("consumable", content_id):
            return {"success": false, "reason": "消耗品未达到正式可获得状态：%s" % content_id}
    for content_id_value in ids:
        context.growth.consumable_ids.append(str(content_id_value))
    context.growth.refresh_consumable_capacity_state()
    return {
        "success": true,
        "applied": {
            "op": "grant_consumables",
            "consumable_ids": ids.duplicate(),
            "consumable_count": context.growth.consumable_ids.size(),
            "consumable_limit": int(capacity.get("effective_capacity", 0)),
            "capacity_query": capacity.duplicate(true),
        },
    }

func _validate_ids(value, validator, scope: String) -> Array:
    if not value is Array or value.is_empty():
        validator.report_error(scope, "必须是非空 ID 数组")
        return []
    var result: Array = []
    for index in range(value.size()):
        if not value[index] is String or str(value[index]) == "":
            validator.report_error("%s[%d]" % [scope, index], "必须是非空字符串")
        else:
            result.append(str(value[index]))
    return result
