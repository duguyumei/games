class_name PassiveBehaviorProjectionPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

const PROJECTION_QUERY := "passive_behavior_projection_query"
const INVOCATION_PLAN_QUERY := "passive_invocation_plan_query"
const MODES := [
    "live_left_adjacent",
    "battle_locked_random_other",
    "battle_locked_leftmost_repeat",
]

func behavior_id() -> String:
    return "passive_behavior_projection"

func supported_hooks() -> Array[String]:
    return [PROJECTION_QUERY, INVOCATION_PLAN_QUERY]

func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field_value in configuration:
        if str(field_value) != "mode":
            errors.append("configuration 不支持字段 %s" % str(field_value))
    var mode := str(configuration.get("mode", ""))
    if mode not in MODES:
        errors.append("未知被动行为投影模式：%s" % mode)
    return errors

func allows_behavior_copy(_configuration: Dictionary) -> bool:
    return false

func copy_projection_spec(configuration: Dictionary) -> Dictionary:
    return {
        "mode": str(configuration.get("mode", "")),
    }

func handle(hook: String, context, configuration: Dictionary) -> Dictionary:
    var mode := str(configuration.get("mode", ""))
    if hook == PROJECTION_QUERY:
        return {"success": true, "mode": mode}
    if hook != INVOCATION_PLAN_QUERY \
            or mode != "battle_locked_leftmost_repeat":
        return {"success": true, "additional_executions": 0}
    if context == null or context.owner == null or context.source == null \
            or context.plan_target_source == null:
        return {"success": true, "additional_executions": 0}
    var store = _property_value(
        context.owner, "passive_behavior_projection_store")
    if store == null:
        return {"success": true, "additional_executions": 0}
    var record: Dictionary = store.record_for(context.source)
    var target = context.plan_target_source
    if record.is_empty() or not bool(record.get("has_target", false)) \
            or target.is_projected() \
            or not bool(target.behavior_copyable) \
            or str(target.content_id) != str(record.get(
                "target_content_id", "")) \
            or int(target.content_instance_ordinal) != int(record.get(
                "target_content_instance_ordinal", 0)) \
            or not _record_contains_behavior(record, target):
        return {"success": true, "additional_executions": 0}
    return {
        "success": true,
        "additional_executions": maxi(
            0, int(record.get("additional_executions", 0))),
        ## 锁定身份由内容副本序号确认；槽位换位后使用目标当前实例键，
        ## 避免把“锁定目标”误写成“锁定战斗开始时的槽位地址”。
        "target_instance_key": str(target.source_instance_key),
    }

func _record_contains_behavior(record: Dictionary, target) -> bool:
    for descriptor_value in record.get("target_behaviors", []):
        if not descriptor_value is Dictionary:
            continue
        var descriptor: Dictionary = descriptor_value
        if str(descriptor.get("behavior_id", "")) == target.behavior_id \
                and int(descriptor.get("behavior_index", -1)) \
                    == int(target.behavior_index):
            return true
    return false

func _property_value(owner, property_name: String):
    if owner == null or not owner.has_method("get_property_list"):
        return null
    for property in owner.get_property_list():
        if str(property.get("name", "")) == property_name:
            return owner.get(property_name)
    return null
