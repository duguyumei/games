class_name RunCardCollectionEffectHandler
extends "res://core/run_effects/run_effect_handler.gd"

const CardWorkshopServiceScript = preload("res://core/card_workshop_service.gd")

var _workshop := CardWorkshopServiceScript.new()

func operation_ids() -> Array[String]:
    return ["add_run_cards", "remove_run_cards", "copy_run_card"]

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    match str(effect.get("op", "")):
        "add_run_cards":
            var definition_ids := _validate_id_array(
                effect.get("definition_ids"), validator, scope + ".definition_ids")
            if validator.has_method("has_content_id"):
                for index in range(definition_ids.size()):
                    var definition_id := str(definition_ids[index])
                    if not validator.has_content_id("card", definition_id):
                        validator.report_error(
                            "%s.definition_ids[%d]" % [scope, index],
                            "引用未知基础真气定义：%s" % definition_id)
        "remove_run_cards":
            _validate_id_array(
                effect.get("instance_ids"), validator, scope + ".instance_ids")
        "copy_run_card":
            _validate_required_id(
                effect.get("source_instance_id"),
                validator,
                scope + ".source_instance_id")
            var count = effect.get("count")
            if not _is_integer(count) or int(count) <= 0:
                validator.report_error(
                    scope + ".count", "copy_run_card count 必须是正整数")

func apply(effect: Dictionary, context) -> Dictionary:
    var result: Dictionary
    match str(effect["op"]):
        "add_run_cards":
            result = _workshop.add_run_cards(
                context.growth.run_deck, effect["definition_ids"])
        "remove_run_cards":
            result = _workshop.remove_run_cards(
                context.growth.run_deck, effect["instance_ids"])
        "copy_run_card":
            result = _workshop.copy_run_card(
                context.growth.run_deck,
                str(effect["source_instance_id"]),
                int(effect["count"]))
    return _applied_result(str(effect["op"]), result)

func _validate_id_array(value, validator, scope: String) -> Array:
    if not value is Array or value.is_empty():
        validator.report_error(scope, "必须是非空数组")
        return []
    var seen: Dictionary = {}
    var result: Array = []
    for index in range(value.size()):
        var content_id := str(value[index])
        if content_id == "":
            validator.report_error("%s[%d]" % [scope, index], "必须是非空字符串")
        elif seen.has(content_id):
            validator.report_error(scope, "不能包含重复 ID：%s" % content_id)
        seen[content_id] = true
        result.append(content_id)
    return result

func _validate_required_id(value, validator, scope: String) -> void:
    if not value is String or str(value) == "":
        validator.report_error(scope, "必须是非空字符串")

func _is_integer(value) -> bool:
    return (value is int or value is float) and float(value) == floor(float(value))

func _applied_result(operation_id: String, result: Dictionary) -> Dictionary:
    if not result.get("success", false):
        return result
    var applied := result.duplicate(true)
    applied.erase("success")
    applied["op"] = operation_id
    return {"success": true, "applied": applied}
