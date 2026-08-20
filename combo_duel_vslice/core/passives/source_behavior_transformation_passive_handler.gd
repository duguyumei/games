class_name SourceBehaviorTransformationPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

const HOOK := "battle_completed"
const COUNTER_ID := "progress"

func behavior_id() -> String:
    return "source_behavior_transformation"

func supported_hooks() -> Array[String]:
    return [HOOK] as Array[String]

func allows_behavior_copy(_configuration: Dictionary) -> bool:
    return false

func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field_value in configuration:
        if str(field_value) != "progress_required":
            errors.append("configuration 不支持字段 %s" % str(field_value))
    if not configuration.get("progress_required") is int \
            or int(configuration.get("progress_required", 0)) <= 0:
        errors.append("progress_required 必须是正整数")
    return errors

func counter_definitions(configuration: Dictionary) -> Array:
    var required := maxi(1, int(configuration.get("progress_required", 1)))
    return [{
        "counter_id": COUNTER_ID,
        "default_value": 0,
        "minimum": 0,
        "maximum": required,
        "retention_policy": "while_owned",
    }]

func handle(
        hook: String,
        context,
        configuration: Dictionary) -> Dictionary:
    if hook != HOOK:
        return {"success": true, "skipped": true}
    if context == null or context.counter_mutation_port == null:
        return {"success": false, "reason": "来源行为替换缺少持久计数器端口"}
    var required := int(configuration.get("progress_required", 0))
    var advanced: Dictionary = context.counter_mutation_port.increment(
        COUNTER_ID, 1)
    if not advanced.get("success", false):
        return advanced
    var progress := int(advanced.get("value", 0))
    if progress < required:
        return {
            "success": true,
            "transformed": false,
            "progress": progress,
            "required": required,
        }
    if context.source_behavior_transformation_port == null:
        return {"success": false, "reason": "来源行为替换缺少受控写入端口"}
    var transformed: Dictionary = context.source_behavior_transformation_port \
        .transform_current_source()
    if not transformed.get("success", false):
        return transformed
    if not transformed.get("transformed", false):
        return {
            "success": true,
            "transformed": false,
            "progress": progress,
            "required": required,
            "no_legal_target": true,
        }
    var reset: Dictionary = context.counter_mutation_port.reset(COUNTER_ID)
    if not reset.get("success", false):
        return reset
    return {
        "success": true,
        "transformed": true,
        "progress": required,
        "required": required,
        "target_content_id": str(transformed.get("target_content_id", "")),
        "target_behaviors": transformed.get(
            "target_behaviors", []).duplicate(true),
    }
