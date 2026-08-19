class_name CardLifecyclePolicyPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

## 牌区与真气状态生命周期的来源中立策略适配器。
##
## 这个 Handler 只解释冻结上下文并返回计划，不直接移动真气、修改状态或
## 发布事件。真实写入仍由 CardZoneService / CardAnomalyService 完成。

const HOOKS := [
    "card_disposition_replacement_query",
    "draw_depletion_replacement_query",
    "card_lifecycle_removed_state_claim",
    "growth_trigger_execution_plan",
]
const DISPOSITIONS := ["draw_pile_bottom", "permanently_removed"]
const DRAW_COUNTER_ID := "draw_depletion_uses"


func behavior_id() -> String:
    return "card_lifecycle_policy"


func supported_hooks() -> Array[String]:
    return HOOKS.duplicate()


func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    var rules = configuration.get("rules")
    if not rules is Array or rules.is_empty():
        return ["card_lifecycle_policy.rules 必须是非空数组"] as Array[String]
    for index in range(rules.size()):
        var value = rules[index]
        var scope := "rules[%d]" % index
        if not value is Dictionary:
            errors.append("%s 必须是对象" % scope)
            continue
        var rule: Dictionary = value
        var hook := str(rule.get("hook", ""))
        if hook not in HOOKS:
            errors.append("%s.hook 不是牌区／真气生命周期策略 Hook" % scope)
            continue
        match hook:
            "card_disposition_replacement_query":
                if str(rule.get("destination", "")) not in DISPOSITIONS:
                    errors.append("%s.destination 必须是 draw_pile_bottom 或 permanently_removed" % scope)
                if rule.has("reasons") and not rule.get("reasons") is Array:
                    errors.append("%s.reasons 必须是数组" % scope)
            "draw_depletion_replacement_query":
                if int(rule.get("maximum_uses", 0)) <= 0:
                    errors.append("%s.maximum_uses 必须是正整数" % scope)
            "card_lifecycle_removed_state_claim":
                if not rule.get("state_ids", []) is Array \
                        or rule.get("state_ids", []).is_empty():
                    errors.append("%s.state_ids 必须是非空数组" % scope)
            "growth_trigger_execution_plan":
                if int(rule.get("additional_triggers", 0)) < 0:
                    errors.append("%s.additional_triggers 必须是非负整数" % scope)
                if rule.has("requires_leftmost") \
                        and not rule.get("requires_leftmost") is bool:
                    errors.append("%s.requires_leftmost 必须是布尔值" % scope)
    return errors


func battle_counter_definitions(configuration: Dictionary) -> Array:
    var maximum := 0
    for rule_value in configuration.get("rules", []):
        if rule_value is Dictionary \
                and str(rule_value.get("hook", "")) \
                    == "draw_depletion_replacement_query":
            maximum = maxi(maximum, int(rule_value.get("maximum_uses", 0)))
    if maximum <= 0:
        return []
    return [{
        "counter_id": DRAW_COUNTER_ID,
        "default_value": 0,
        "minimum": 0,
        "maximum": maximum,
        "reset_scope": "battle",
    }]


func handle(hook: String, context, configuration: Dictionary) -> Dictionary:
    var rule := _rule_for(configuration, hook)
    if rule.is_empty():
        return {"success": true, "matched": false}
    match hook:
        "card_disposition_replacement_query":
            return _disposition(context, rule)
        "draw_depletion_replacement_query":
            return _draw_depletion(context, rule)
        "card_lifecycle_removed_state_claim":
            return _removed_state_claim(context, rule)
        "growth_trigger_execution_plan":
            return _growth_plan(context, rule)
    return {"success": true, "matched": false}


func _disposition(context, rule: Dictionary) -> Dictionary:
    var reason := str(context.payload.get("reason", ""))
    var reasons: Array = rule.get("reasons", [])
    if not reasons.is_empty() and reason not in reasons:
        return {"success": true, "matched": false}
    if bool(rule.get("explicit_discard_only", false)) \
            and not bool(context.payload.get("explicit_discard", false)):
        return {"success": true, "matched": false}
    return {
        "success": true,
        "matched": true,
        "destination": str(rule.get("destination", "")),
    }


func _draw_depletion(context, rule: Dictionary) -> Dictionary:
    var maximum := int(rule.get("maximum_uses", 0))
    var current: int = context.battle_counter_read_port.read(DRAW_COUNTER_ID) \
        if context.battle_counter_read_port != null else 0
    if current >= maximum:
        return {
            "success": true,
            "matched": false,
            "uses_before": current,
            "maximum_uses": maximum,
        }
    if not bool(context.payload.get("commit", false)):
        return {
            "success": true,
            "matched": true,
            "uses_before": current,
            "uses_after": current,
            "maximum_uses": maximum,
        }
    if context.battle_counter_mutation_port == null:
        return {"success": false, "reason": "牌库耗尽替换缺少战斗计数器写端口"}
    var written: Dictionary = context.battle_counter_mutation_port.increment(
        DRAW_COUNTER_ID, 1)
    if not written.get("success", false):
        return written
    return {
        "success": true,
        "matched": true,
        "uses_before": current,
        "uses_after": int(written.get("value", current + 1)),
        "maximum_uses": maximum,
    }


func _removed_state_claim(context, rule: Dictionary) -> Dictionary:
    var wanted: Array = rule.get("state_ids", [])
    var claimed: Array = []
    for entry_value in context.payload.get("claim_entries", []):
        if not entry_value is Dictionary:
            continue
        var entry: Dictionary = entry_value
        if str(entry.get("content_id", "")) in wanted \
                and int(entry.get("layers", 0)) > 0:
            claimed.append(entry.duplicate(true))
    return {
        "success": true,
        "matched": not claimed.is_empty(),
        "claimed_entries": claimed,
    }


func _growth_plan(context, rule: Dictionary) -> Dictionary:
    if bool(rule.get("requires_leftmost", false)) \
            and not bool(context.payload.get("is_leftmost_hand_card", false)):
        return {"success": true, "matched": false, "additional_triggers": 0}
    var count := maxi(0, int(rule.get("additional_triggers", 0)))
    return {
        "success": true,
        "matched": count > 0,
        "additional_triggers": count,
    }


func _rule_for(configuration: Dictionary, hook: String) -> Dictionary:
    for value in configuration.get("rules", []):
        if value is Dictionary and str(value.get("hook", "")) == hook:
            return value
    return {}
