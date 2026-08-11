class_name GrantInnerSkillsRunEffectHandler
extends "res://core/run_effects/run_effect_handler.gd"

func operation_ids() -> Array[String]:
    return ["grant_inner_skills"]

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    var ids := _validate_ids(
        effect.get("inner_skill_ids"), validator, scope + ".inner_skill_ids")
    for index in range(ids.size()):
        var content_id := str(ids[index])
        if validator.has_method("has_content_id") \
                and not validator.has_content_id("inner_skill", content_id):
            validator.report_error(
                "%s.inner_skill_ids[%d]" % [scope, index],
                "引用未知内功：%s" % content_id)
        elif validator.has_method("is_formally_obtainable") \
                and not validator.is_formally_obtainable("inner_skill", content_id):
            validator.report_error(
                "%s.inner_skill_ids[%d]" % [scope, index],
                "内功未达到正式可获得状态：%s" % content_id)

func apply(effect: Dictionary, context) -> Dictionary:
    var ids: Array = effect["inner_skill_ids"]
    for content_id_value in ids:
        var content_id := str(content_id_value)
        if context.content_catalog == null:
            return {"success": false, "reason": "本局效果缺少内容目录"}
        if not context.content_catalog.has_id("inner_skill", content_id):
            return {"success": false, "reason": "引用未知内功：%s" % content_id}
        if not context.content_catalog.is_formally_obtainable("inner_skill", content_id):
            return {"success": false, "reason": "内功未达到正式可获得状态：%s" % content_id}
    for content_id_value in ids:
        context.growth.learned_inner_skill_ids.append(str(content_id_value))
    return {
        "success": true,
        "applied": {
            "op": "grant_inner_skills",
            "inner_skill_ids": ids.duplicate(),
            "learned_inner_skill_count": context.growth.learned_inner_skill_ids.size(),
            "equipped_inner_skill_ids": context.growth.equipped_inner_skill_ids.duplicate(),
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
