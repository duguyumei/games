class_name RunIntQueryModifierPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

## 来源中立的 Run 整数查询修正器。
##
## 内容只声明查询键、精确元数据过滤与整数运算；候选生成、随机选择和提交仍由
## 对应领域 Service 完成。history_hand_match 只把 RunCombatHistory 的稳定最高
## 牌型集合投影成候选优先级，不监听战斗事件，也不自行统计日志。

const SUPPORTED_HOOKS := [
    "practice_normal_slot_count_query",
    "practice_offer_weight_query",
    "practice_offer_category_enabled_query",
    "practice_pack_candidate_priority_query",
    "insight_slot_gain_query",
    "rest_multi_select_count_query",
]
const OPERATIONS := ["add", "multiply", "maximum"]
const FILTER_FIELDS := [
    "group", "category_id", "offer_kind", "content_kind",
    "candidate_provider", "operation", "interaction_kind", "node_type",
]


func behavior_id() -> String:
    return "run_int_query_modifier"


func supported_hooks() -> Array[String]:
    return SUPPORTED_HOOKS.duplicate()


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
            if str(field) not in [
                    "hook", "operation", "operand", "filters",
                    "history_hand_match"]:
                errors.append("%s 不支持字段 %s" % [scope, str(field)])
        var hook := str(rule.get("hook", ""))
        if hook not in SUPPORTED_HOOKS:
            errors.append("%s.hook 不是受支持的 Run 整数查询" % scope)
        var operation := str(rule.get("operation", ""))
        if operation not in OPERATIONS:
            errors.append("%s.operation 必须为 add、multiply 或 maximum" % scope)
        if not _is_nonnegative_integer(rule.get("operand")):
            errors.append("%s.operand 必须是非负整数" % scope)
        var filters = rule.get("filters", {})
        if not filters is Dictionary:
            errors.append("%s.filters 必须是对象" % scope)
        else:
            for filter_field in filters:
                if str(filter_field) not in FILTER_FIELDS:
                    errors.append(
                        "%s.filters 不支持字段 %s" % [scope, str(filter_field)])
                elif not filters[filter_field] is String \
                        or str(filters[filter_field]) == "":
                    errors.append(
                        "%s.filters.%s 必须是非空字符串" % [
                            scope, str(filter_field)])
        if rule.has("history_hand_match") \
                and not rule.get("history_hand_match") is bool:
            errors.append("%s.history_hand_match 必须是布尔值" % scope)
        if bool(rule.get("history_hand_match", false)) \
                and hook != "practice_pack_candidate_priority_query":
            errors.append(
                "%s.history_hand_match 只允许补充包候选优先级查询" % scope)
    return errors


func handle(
        hook: String,
        context,
        configuration: Dictionary) -> Dictionary:
    var current := int(context.payload.get("current_value", 0))
    var metadata: Dictionary = context.payload.get("metadata", {})
    for value in configuration.get("rules", []):
        if not value is Dictionary:
            continue
        var rule: Dictionary = value
        if str(rule.get("hook", "")) != hook \
                or not _filters_match(metadata, rule.get("filters", {})) \
                or not _history_matches(context.owner, metadata, rule):
            continue
        var operand := int(rule.get("operand", 0))
        match str(rule.get("operation", "")):
            "add":
                current += operand
            "multiply":
                current *= operand
            "maximum":
                current = maxi(current, operand)
    return {"success": true, "value": current}


func _filters_match(metadata: Dictionary, filters) -> bool:
    if not filters is Dictionary:
        return false
    for field in filters:
        if str(metadata.get(field, "")) != str(filters[field]):
            return false
    return true


func _history_matches(owner, metadata: Dictionary, rule: Dictionary) -> bool:
    if not bool(rule.get("history_hand_match", false)):
        return true
    if owner == null:
        return false
    var history = owner.get("run_combat_history")
    if history == null or not history.has_method("most_successful_hand_ids"):
        return false
    var candidate_hand_id := str(metadata.get("candidate_hand_id", ""))
    if candidate_hand_id == "":
        return false
    var most_successful: Array = history.most_successful_hand_ids()
    # 没有成功历史时，望远镜把全部合法牌型视为同一最高优先级，随后仍由
    # 补充包自己的确定性 RNG 选择唯一保证候选。
    return most_successful.is_empty() or most_successful.has(candidate_hand_id)


func _is_nonnegative_integer(value) -> bool:
    return (value is int or value is float) \
        and float(value) == floor(float(value)) \
        and int(value) >= 0
