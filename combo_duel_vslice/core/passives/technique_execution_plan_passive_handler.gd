class_name TechniqueExecutionPlanPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]
const MODES := [
    "every_second_hand",
    "first_if_none",
    "every_six_executions",
    "same_technique_different_slot",
    "random_other_slot",
    "first_burnout_per_action",
    "blocked_or_deflected",
    "first_temporary",
    "burnout_extra_advance",
]


func behavior_id() -> String:
    return "technique_execution_plan"


func supported_hooks() -> Array[String]:
    return ["technique_execution_resolved"]


func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field_value in configuration:
        if str(field_value) not in ["mode", "count", "interval"]:
            errors.append("configuration 不支持字段 %s" % str(field_value))
    var mode := str(configuration.get("mode", ""))
    if mode not in MODES:
        errors.append("mode 引用未知功法执行计划模式：%s" % mode)
    for field in ["count", "interval"]:
        if configuration.has(field) and not _is_positive_integer(
                configuration[field]):
            errors.append("%s 必须是正整数" % field)
    return errors


func battle_counter_definitions(configuration: Dictionary) -> Array:
    var mode := str(configuration.get("mode", ""))
    var definitions: Array = []
    match mode:
        "every_second_hand":
            for hand_id in HAND_IDS:
                definitions.append(_counter("%s_count" % hand_id))
        "first_if_none":
            definitions.append(_counter("first_success_consumed", 1))
        "every_six_executions":
            definitions.append(_counter("execution_count"))
        "first_temporary":
            definitions.append(_counter("first_temporary_consumed", 1))
    return definitions


func handle(
        hook: String,
        context,
        configuration: Dictionary) -> Dictionary:
    if hook != "technique_execution_resolved" \
            or not bool(context.action_succeeded):
        return _skipped()
    var count := int(configuration.get("count", 1))
    match str(configuration.get("mode", "")):
        "every_second_hand":
            return _every_second_hand(context, configuration, count)
        "first_if_none":
            return _first_if_none(context, count)
        "every_six_executions":
            return _every_six(context, configuration, count)
        "same_technique_different_slot":
            return _same_technique_different_slot(context, count)
        "random_other_slot":
            return _random_other_slot(context, count)
        "first_burnout_per_action":
            return _first_burnout_per_action(context, count)
        "blocked_or_deflected":
            return _blocked_or_deflected(context, count)
        "first_temporary":
            return _first_temporary(context, count)
        "burnout_extra_advance":
            return _burnout_extra_advance(context, count)
    return {"success": false, "reason": "未知功法执行计划模式"}


func _every_second_hand(
        context,
        configuration: Dictionary,
        count: int) -> Dictionary:
    if context.is_echo or str(context.hand_id) not in HAND_IDS:
        return _skipped()
    var counter_id := "%s_count" % str(context.hand_id)
    var interval := int(configuration.get("interval", 2))
    var incremented := _increment(context, counter_id)
    if not incremented.get("success", false):
        return incremented
    if int(incremented.get("value", 0)) < interval:
        return _skipped()
    var reset := _write(context, counter_id, 0)
    if not reset.get("success", false):
        return reset
    return _effects([_append_echo(count)])


func _first_if_none(context, count: int) -> Dictionary:
    if context.is_echo \
            or context.battle_counter_read_port.read(
                "first_success_consumed") > 0:
        return _skipped()
    var consumed := _write(context, "first_success_consumed", 1)
    if not consumed.get("success", false):
        return consumed
    return _effects([_append_echo(count, true)])


func _every_six(
        context,
        configuration: Dictionary,
        count: int) -> Dictionary:
    var interval := int(configuration.get("interval", 6))
    var incremented := _increment(context, "execution_count")
    if not incremented.get("success", false):
        return incremented
    if int(incremented.get("value", 0)) < interval:
        return _skipped()
    var reset := _write(context, "execution_count", 0)
    if not reset.get("success", false):
        return reset
    if context.is_echo:
        return _effects([_grant_pending(count, "next_non_echo")])
    return _effects([_append_echo(count)])


func _same_technique_different_slot(context, count: int) -> Dictionary:
    if context.is_echo or str(context.technique_id) == "" \
            or str(context.slot_instance_id) == "":
        return _skipped()
    var records := _source_records(context, "technique_slot_history")
    var distinct: Dictionary = {}
    for record_value in records:
        var record: Dictionary = record_value
        if str(record.get("technique_id", "")) == str(context.technique_id):
            distinct[str(record.get("slot_instance_id", ""))] = true
    if distinct.has(str(context.slot_instance_id)):
        return _skipped()
    var effects := [_append_marker_records(
        "technique_slot_history", "成功功法槽位历史", false, [{
            "technique_id": str(context.technique_id),
            "slot_instance_id": str(context.slot_instance_id),
            "event_token": str(context.event_token),
        }])]
    if distinct.size() == 1:
        effects.append(_append_echo(count))
    return _effects(effects)


func _random_other_slot(context, count: int) -> Dictionary:
    if context.is_echo:
        return _skipped()
    return _effects([_grant_pending(count, "random_other_slot")])


func _first_burnout_per_action(context, count: int) -> Dictionary:
    if context.is_echo or not _uses_frozen_burnout(context):
        return _skipped()
    var root_token := str(context.root_action_token)
    if root_token == "":
        root_token = str(context.technique_execution_token)
    for record_value in _source_records(context, "burnout_action_gates"):
        if str(record_value.get("root_action_token", "")) == root_token:
            return _skipped()
    return _effects([
        _append_marker_records(
            "burnout_action_gates", "燃尽功法行动门禁", false, [{
                "root_action_token": root_token,
                "technique_execution_token": str(
                    context.technique_execution_token),
                "event_token": str(context.event_token),
            }]),
        _append_echo(count),
    ])


func _blocked_or_deflected(context, count: int) -> Dictionary:
    if context.is_echo or (
            int(context.block_canceled_segment_count) <= 0 \
            and int(context.deflection_canceled_segment_count) <= 0):
        return _skipped()
    return _effects([_append_echo(count)])


func _first_temporary(context, count: int) -> Dictionary:
    if context.is_echo or not bool(context.temporary) \
            or context.battle_counter_read_port.read(
                "first_temporary_consumed") > 0:
        return _skipped()
    var consumed := _write(context, "first_temporary_consumed", 1)
    if not consumed.get("success", false):
        return consumed
    return _effects([_append_echo(count)])


func _burnout_extra_advance(context, count: int) -> Dictionary:
    if context.is_echo or not _uses_frozen_burnout(context):
        return _skipped()
    return _effects([{
        "op": "request_extra_sequence_advance",
        "count": count,
    }])


func _uses_frozen_burnout(context) -> bool:
    var snapshot: Dictionary = context.payload.get(
        "effect_context_values", {}).get("group_snapshot", {})
    var facts_by_id: Dictionary = snapshot.get("facts_by_id", {})
    for card_value in snapshot.get("contributing_cards", []):
        var instance_id := str(card_value.get("instance_id", "")) \
            if card_value is Dictionary else str(card_value.id)
        if bool(facts_by_id.get(instance_id, {}).get(
                "burned_out_at_freeze", false)):
            return true
    return false


func _source_records(context, marker_id: String) -> Array:
    if context.owner == null or context.source == null:
        return []
    return context.owner.source_marker_store.records(
        str(context.source.source_kind),
        str(context.source.source_instance_key),
        marker_id,
        "battle")


func _append_echo(count: int, only_if_zero: bool = false) -> Dictionary:
    return {
        "op": "append_current_technique_echo",
        "count": count,
        "only_if_current_count_zero": only_if_zero,
    }


func _grant_pending(count: int, target_mode: String) -> Dictionary:
    return {
        "op": "grant_pending_slot_echo",
        "count": count,
        "target_mode": target_mode,
    }


func _append_marker_records(
        marker_id: String,
        display_name: String,
        public: bool,
        records: Array) -> Dictionary:
    return {
        "op": "append_source_marker_records",
        "marker_id": marker_id,
        "scope": "battle",
        "public": public,
        "display_name": display_name,
        "forget_policy": "clear",
        "records": records,
    }


func _increment(context, counter_id: String) -> Dictionary:
    var result: Dictionary = context.battle_counter_mutation_port.increment(
        counter_id, 1)
    if not result.get("success", false):
        return {"success": false, "reason": str(result.get(
            "reason", "战斗计数器增加失败"))}
    return result


func _write(context, counter_id: String, value: int) -> Dictionary:
    var result: Dictionary = context.battle_counter_mutation_port.write(
        counter_id, value)
    if not result.get("success", false):
        return {"success": false, "reason": str(result.get(
            "reason", "战斗计数器写入失败"))}
    return result


func _counter(counter_id: String, maximum = null) -> Dictionary:
    var result := {
        "counter_id": counter_id,
        "default_value": 0,
        "minimum": 0,
        "reset_scope": "battle",
    }
    if maximum is int:
        result["maximum"] = int(maximum)
    return result


func _effects(values: Array) -> Dictionary:
    return {"success": true, "effects": values}


func _skipped() -> Dictionary:
    return {"success": true, "skipped": true}


func _is_positive_integer(value) -> bool:
    if value is int:
        return int(value) > 0
    if value is float:
        return float(value) > 0.0 \
            and is_equal_approx(float(value), float(int(value)))
    return false
