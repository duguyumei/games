class_name RunCardReshapeEffectHandler
extends "res://core/run_effects/run_effect_handler.gd"

const CardWorkshopServiceScript = preload("res://core/card_workshop_service.gd")
const CATEGORIES := ["enhancement", "finish", "imprint", "other"]

var _workshop := CardWorkshopServiceScript.new()

func operation_ids() -> Array[String]:
    return ["apply_run_card_reshape"]

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    _validate_id_array(
        effect.get("instance_ids"), validator, scope + ".instance_ids")
    var category := str(effect.get("category", ""))
    if not CATEGORIES.has(category):
        validator.report_error(
            scope + ".category", "未知重塑类别：%s" % category)
        return
    var reshape_id := str(effect.get("reshape_id", ""))
    if reshape_id == "":
        validator.report_error(scope + ".reshape_id", "必须是非空字符串")
    elif validator.has_method("has_content_id"):
        var content_type := _content_type(category)
        if not validator.has_content_id(content_type, reshape_id):
            var actual_category := _find_category(validator, reshape_id)
            if actual_category == "":
                validator.report_error(
                    scope + ".reshape_id", "引用未知重塑：%s" % reshape_id)
            else:
                validator.report_error(
                    scope + ".reshape_id",
                    "重塑 %s 属于类别 %s，不属于 %s" % [
                        reshape_id, actual_category, category])
        else:
            var definition: Dictionary = validator.content_definition(
                content_type, reshape_id)
            if definition.has("allowed_carriers") \
                    and not definition.get("allowed_carriers", []).has("card"):
                validator.report_error(
                    scope + ".reshape_id",
                    "重塑 %s 不允许施加给真气" % reshape_id)
    if effect.has("payload") and not effect["payload"] is Dictionary:
        validator.report_error(scope + ".payload", "必须是对象")
    elif effect.has("payload") and category != "other":
        validator.report_error(
            scope + ".payload", "只有重塑·其他可以携带 payload")

func apply(effect: Dictionary, context) -> Dictionary:
    var result: Dictionary = _workshop.apply_run_card_reshape(
        context.growth.run_deck,
        effect["instance_ids"],
        str(effect["category"]),
        str(effect["reshape_id"]),
        effect.get("payload", {}))
    if not result.get("success", false):
        return result
    var applied := result.duplicate(true)
    applied.erase("success")
    applied["op"] = "apply_run_card_reshape"
    applied["category"] = str(effect["category"])
    applied["reshape_id"] = str(effect["reshape_id"])
    return {"success": true, "applied": applied}

func _validate_id_array(value, validator, scope: String) -> void:
    if not value is Array or value.is_empty():
        validator.report_error(scope, "必须是非空数组")
        return
    var seen: Dictionary = {}
    for index in range(value.size()):
        var instance_id := str(value[index])
        if instance_id == "":
            validator.report_error("%s[%d]" % [scope, index], "必须是非空字符串")
        elif seen.has(instance_id):
            validator.report_error(scope, "不能包含重复 ID：%s" % instance_id)
        seen[instance_id] = true

func _content_type(category: String) -> String:
    return "other_reshape" if category == "other" else category

func _find_category(validator, reshape_id: String) -> String:
    for category in CATEGORIES:
        if validator.has_content_id(_content_type(category), reshape_id):
            return category
    return ""
