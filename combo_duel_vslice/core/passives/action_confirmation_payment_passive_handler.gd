class_name ActionConfirmationPaymentPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

## 来源中立的行动确认支付声明。Handler 只返回计划，不查询目标、不修改卡牌，
## 选择、支付、功法值回执与回滚均由 BattleActionPreparationService 所有。

const HOOK := "action_confirmation_payment"
const PAYMENT_KINDS := ["blazing_layers"]
const PAYMENT_METHODS := ["remove_all_layers"]

func behavior_id() -> String:
    return "action_confirmation_payment"

func supported_hooks() -> Array[String]:
    return [HOOK]

func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field in configuration:
        if str(field) != "plans":
            errors.append("configuration 不支持字段 %s" % str(field))
    var plans = configuration.get("plans")
    if not plans is Array or plans.is_empty():
        errors.append("plans 必须是非空数组")
        return errors
    for index in range(plans.size()):
        var value = plans[index]
        var scope := "plans[%d]" % index
        if not value is Dictionary:
            errors.append("%s 必须是对象" % scope)
            continue
        var plan: Dictionary = value
        for field in plan:
            if str(field) not in [
                    "query", "payment_kind", "payment_method",
                    "power_fixed_per_unit", "optional", "prompt",
                    "insufficient_policy"]:
                errors.append("%s 不支持字段 %s" % [scope, str(field)])
        if not plan.get("query") is Dictionary:
            errors.append("%s.query 必须是目标查询对象" % scope)
        if str(plan.get("payment_kind", "")) not in PAYMENT_KINDS:
            errors.append("%s.payment_kind 不受支持" % scope)
        if str(plan.get("payment_method", "")) not in PAYMENT_METHODS:
            errors.append("%s.payment_method 不受支持" % scope)
        if not plan.get("power_fixed_per_unit") is int:
            errors.append("%s.power_fixed_per_unit 必须是整数" % scope)
        if plan.has("optional") and not plan.get("optional") is bool:
            errors.append("%s.optional 必须是布尔值" % scope)
        if str(plan.get("insufficient_policy", "skip")) not in ["skip", "fail"]:
            errors.append("%s.insufficient_policy 必须为 skip 或 fail" % scope)
    return errors

func handle(hook: String, _context, configuration: Dictionary) -> Dictionary:
    if hook != HOOK:
        return {"success": true, "skipped": true, "payment_plans": []}
    return {
        "success": true,
        "payment_plans": configuration.get("plans", []).duplicate(true),
    }
