class_name RunCardTransformEffectHandler
extends "res://core/run_effects/run_effect_handler.gd"

const CardWorkshopServiceScript = preload("res://core/card_workshop_service.gd")

var _workshop := CardWorkshopServiceScript.new()

func operation_ids() -> Array[String]:
    return ["transform_run_card", "copy_run_card_state"]

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    match str(effect.get("op", "")):
        "transform_run_card":
            _validate_required_id(
                effect.get("instance_id"), validator, scope + ".instance_id")
            var definition_id := _validate_required_id(
                effect.get("definition_id"), validator, scope + ".definition_id")
            if definition_id != "" \
                    and validator.has_method("has_content_id") \
                    and not validator.has_content_id("card", definition_id):
                validator.report_error(
                    scope + ".definition_id",
                    "引用未知基础真气定义：%s" % definition_id)
            if effect.has("preserve_reshapes") \
                    and not effect["preserve_reshapes"] is bool:
                validator.report_error(
                    scope + ".preserve_reshapes", "必须是布尔值")
        "copy_run_card_state":
            var source_id := _validate_required_id(
                effect.get("source_instance_id"),
                validator,
                scope + ".source_instance_id")
            var target_ids := _validate_id_array(
                effect.get("target_instance_ids"),
                validator,
                scope + ".target_instance_ids")
            if source_id != "" and target_ids.has(source_id):
                validator.report_error(
                    scope + ".target_instance_ids",
                    "来源真气不能同时作为目标：%s" % source_id)

func apply(effect: Dictionary, context) -> Dictionary:
    var result: Dictionary
    match str(effect["op"]):
        "transform_run_card":
            result = _workshop.transform_run_card(
                context.growth.run_deck,
                str(effect["instance_id"]),
                str(effect["definition_id"]),
                bool(effect.get("preserve_reshapes", true)))
        "copy_run_card_state":
            result = _workshop.copy_run_card_state(
                context.growth.run_deck,
                str(effect["source_instance_id"]),
                effect["target_instance_ids"])
    return _applied_result(str(effect["op"]), result)

func _validate_required_id(value, validator, scope: String) -> String:
    if not value is String or str(value) == "":
        validator.report_error(scope, "必须是非空字符串")
        return ""
    return str(value)

func _validate_id_array(value, validator, scope: String) -> Array:
    if not value is Array or value.is_empty():
        validator.report_error(scope, "必须是非空数组")
        return []
    var seen: Dictionary = {}
    var result: Array = []
    for index in range(value.size()):
        var instance_id := str(value[index])
        if instance_id == "":
            validator.report_error("%s[%d]" % [scope, index], "必须是非空字符串")
        elif seen.has(instance_id):
            validator.report_error(scope, "不能包含重复 ID：%s" % instance_id)
        seen[instance_id] = true
        result.append(instance_id)
    return result

func _applied_result(operation_id: String, result: Dictionary) -> Dictionary:
    if not result.get("success", false):
        return result
    var applied := result.duplicate(true)
    applied.erase("success")
    applied["op"] = operation_id
    return {"success": true, "applied": applied}
