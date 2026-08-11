class_name GrantTechniquesRunEffectHandler
extends "res://core/run_effects/run_effect_handler.gd"

func operation_ids() -> Array[String]:
    return ["grant_techniques"]

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    var ids := _validate_ids(
        effect.get("technique_ids"), validator, scope + ".technique_ids", false)
    for index in range(ids.size()):
        var content_id := str(ids[index])
        if validator.has_method("has_content_id") \
                and not validator.has_content_id("technique", content_id):
            validator.report_error(
                "%s.technique_ids[%d]" % [scope, index],
                "引用未知功法：%s" % content_id)
        elif validator.has_method("is_formally_obtainable") \
                and not validator.is_formally_obtainable("technique", content_id):
            validator.report_error(
                "%s.technique_ids[%d]" % [scope, index],
                "功法未达到正式可获得状态：%s" % content_id)

func apply(effect: Dictionary, context) -> Dictionary:
    var ids: Array = effect["technique_ids"]
    for content_id_value in ids:
        var content_id := str(content_id_value)
        var check := _runtime_content_check(context, "technique", content_id)
        if check != "":
            return {"success": false, "reason": check}
        if context.growth.learned_technique_ids.has(content_id):
            return {"success": false, "reason": "功法已拥有，不能重复发放：%s" % content_id}
    for content_id_value in ids:
        context.growth.learned_technique_ids.append(str(content_id_value))
    return {
        "success": true,
        "applied": {
            "op": "grant_techniques",
            "technique_ids": ids.duplicate(),
            "learned_technique_count": context.growth.learned_technique_ids.size(),
        },
    }

func _validate_ids(value, validator, scope: String, allow_duplicates: bool) -> Array:
    if not value is Array or value.is_empty():
        validator.report_error(scope, "必须是非空 ID 数组")
        return []
    var result: Array = []
    var seen: Dictionary = {}
    for index in range(value.size()):
        if not value[index] is String or str(value[index]) == "":
            validator.report_error("%s[%d]" % [scope, index], "必须是非空字符串")
            continue
        var content_id := str(value[index])
        if seen.has(content_id) and not allow_duplicates:
            validator.report_error(scope, "不能包含重复 ID：%s" % content_id)
        seen[content_id] = true
        result.append(content_id)
    return result

func _runtime_content_check(context, content_type: String, content_id: String) -> String:
    if context.content_catalog == null:
        return "本局效果缺少内容目录"
    if not context.content_catalog.has_id(content_type, content_id):
        return "引用未知%s：%s" % ["功法", content_id]
    if not context.content_catalog.is_formally_obtainable(content_type, content_id):
        return "功法未达到正式可获得状态：%s" % content_id
    return ""
