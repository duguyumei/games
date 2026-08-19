class_name BattleIntQueryModifierPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

## 来源中立的战斗整数查询修正器。
##
## 内容只声明 Hook、整数运算与可选的精确请求过滤；来源收集、稳定顺序、
## 压制与纯查询校验继续由 PassiveRuleRuntime/BattleRuleQueryService 负责。

const BattleIntQueryCatalogScript = preload(
    "res://core/passives/battle_int_query_catalog.gd")

const OPERATIONS := ["add", "multiply", "minimum", "maximum", "set"]


func behavior_id() -> String:
    return "battle_int_query_modifier"


func supported_hooks() -> Array[String]:
    return BattleIntQueryCatalogScript.HOOKS.duplicate()


func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field in configuration:
        if str(field) != "rules":
            errors.append("configuration 不支持字段 %s" % str(field))
    var rules = configuration.get("rules")
    if not rules is Array or rules.is_empty():
        errors.append("rules 必须是非空数组")
        return errors
    for index in range(rules.size()):
        var value = rules[index]
        var scope := "rules[%d]" % index
        if not value is Dictionary:
            errors.append("%s 必须是对象" % scope)
            continue
        var rule: Dictionary = value
        for field in rule:
            if str(field) not in ["hook", "operation", "operand", "filters"]:
                errors.append("%s 不支持字段 %s" % [scope, str(field)])
        var hook := str(rule.get("hook", ""))
        if hook not in BattleIntQueryCatalogScript.HOOKS:
            errors.append("%s.hook 不是正式战斗整数查询" % scope)
        var operation := str(rule.get("operation", ""))
        if operation not in OPERATIONS:
            errors.append(
                "%s.operation 必须为 add、multiply、minimum、maximum 或 set" % scope)
        if not _is_integer(rule.get("operand")):
            errors.append("%s.operand 必须是整数" % scope)
        var filters = rule.get("filters", {})
        if not filters is Dictionary:
            errors.append("%s.filters 必须是对象" % scope)
            continue
        for filter_field in filters:
            var filter_name := str(filter_field)
            if not filter_name.is_valid_identifier() \
                    or filter_name.to_snake_case() != filter_name:
                errors.append(
                    "%s.filters 字段必须使用 snake_case：%s" % [
                        scope, filter_name])
            elif not _is_stable_filter_value(filters[filter_field]):
                errors.append(
                    "%s.filters.%s 必须是字符串、整数或布尔值" % [
                        scope, filter_name])
    return errors


func handle(
        hook: String,
        context,
        configuration: Dictionary) -> Dictionary:
    var current := int(context.payload.get("current_value", 0))
    var filter_values := _filter_values(context)
    for value in configuration.get("rules", []):
        if not value is Dictionary:
            continue
        var rule: Dictionary = value
        if str(rule.get("hook", "")) != hook \
                or not _filters_match(filter_values, rule.get("filters", {})):
            continue
        var operand := int(rule.get("operand", 0))
        match str(rule.get("operation", "")):
            "add":
                current += operand
            "multiply":
                current *= operand
            "minimum":
                current = mini(current, operand)
            "maximum":
                current = maxi(current, operand)
            "set":
                current = operand
    return {"success": true, "value": current}


func _filter_values(context) -> Dictionary:
    var result: Dictionary = {}
    var request = context.payload.get("int_query")
    if request != null and request.has_method("to_dict"):
        result.merge(request.to_dict(), true)
    for field in context.payload:
        var value = context.payload[field]
        if _is_stable_filter_value(value):
            result[str(field)] = value
    var metadata = context.payload.get("metadata", {})
    if metadata is Dictionary:
        for field in metadata:
            if _is_stable_filter_value(metadata[field]):
                result[str(field)] = metadata[field]
    return result


func _filters_match(values: Dictionary, filters) -> bool:
    if not filters is Dictionary:
        return false
    for field in filters:
        if not values.has(str(field)) or values[str(field)] != filters[field]:
            return false
    return true


func _is_stable_filter_value(value) -> bool:
    return value is String or value is int or value is bool \
        or (value is float and float(value) == floor(float(value)))


func _is_integer(value) -> bool:
    return (value is int or value is float) \
        and float(value) == floor(float(value))
