class_name CardTriggerTargetPolicyPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

## 纯查询适配器：状态行为在选择候选目标前读取来源中立的排序策略。
## 该 Handler 不读取内容 ID，也不执行移动、随机或其他写操作。

const HOOK := "card_trigger_target_policy_query"
const POLICIES := [
    "random", "left", "right", "lowest_rank", "highest_rank",
]
const MATCH_FIELDS := ["trigger", "status_id", "category", "behavior"]

func behavior_id() -> String:
    return "card_trigger_target_policy"

func supported_hooks() -> Array[String]:
    return [HOOK]

func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field in configuration:
        if str(field) not in MATCH_FIELDS + ["policy"]:
            errors.append("configuration 不支持字段 %s" % field)
    for field in MATCH_FIELDS:
        if configuration.has(field) and not configuration[field] is String:
            errors.append("%s 必须是字符串" % field)
    if str(configuration.get("policy", "")) not in POLICIES:
        errors.append("policy 必须为 %s 之一" % ", ".join(POLICIES))
    return errors

func handle(hook: String, context, configuration: Dictionary) -> Dictionary:
    if hook != HOOK:
        return {"success": true, "skipped": true}
    for field in MATCH_FIELDS:
        if configuration.has(field) and str(configuration[field]) != str(
                context.payload.get(field, "")):
            return {"success": true, "matched": false}
    return {
        "success": true,
        "matched": true,
        "target_policy": str(configuration.get("policy", "random")),
        "source_instance_key": str(context.source.source_instance_key),
    }
