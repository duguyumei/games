class_name PreTechniqueCostPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

## Declares a source-neutral payment and the power modifier granted only when
## that payment succeeds.  TechniqueResolutionService owns payment, power
## freezing and rollback; the Handler never writes BattleSide state.

const HOOK := "pre_technique_cost"
const RESOURCES := ["experience"]
const INSUFFICIENT_POLICIES := ["skip", "fail"]

func behavior_id() -> String:
    return "pre_technique_cost"

func supported_hooks() -> Array[String]:
    return [HOOK]

func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field in configuration:
        if str(field) not in [
                "resource", "amount", "power_fixed", "power_percent",
                "insufficient_policy"]:
            errors.append("configuration 不支持字段 %s" % str(field))
    if str(configuration.get("resource", "")) not in RESOURCES:
        errors.append("resource 目前只支持 experience")
    if not configuration.get("amount") is int \
            or int(configuration.get("amount", 0)) <= 0:
        errors.append("amount 必须是正整数")
    for field in ["power_fixed", "power_percent"]:
        if configuration.has(field) and not configuration[field] is int:
            errors.append("%s 必须是整数" % field)
    if str(configuration.get(
            "insufficient_policy", "skip")) not in INSUFFICIENT_POLICIES:
        errors.append("insufficient_policy 必须为 skip 或 fail")
    return errors

func handle(hook: String, _context, configuration: Dictionary) -> Dictionary:
    if hook != HOOK:
        return {"success": true, "skipped": true, "cost_plans": []}
    return {
        "success": true,
        "cost_plans": [configuration.duplicate(true)],
    }
