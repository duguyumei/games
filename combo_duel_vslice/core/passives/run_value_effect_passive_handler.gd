class_name RunValueEffectPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

const EffectValueResolverScript = preload(
    "res://core/effects/effect_value_resolver.gd")
const ValueSpecRegistryScript = preload(
    "res://core/specs/value_spec_registry.gd")

const SUPPORTED_HOOKS := ["battle_completed"]
const SUPPORTED_RUN_EFFECTS := ["gain_experience"]

var _value_resolver = EffectValueResolverScript.new()


func behavior_id() -> String:
    return "run_value_effect"


func supported_hooks() -> Array[String]:
    return SUPPORTED_HOOKS.duplicate()


func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field in configuration:
        if str(field) not in ["hook", "outcome", "effect"]:
            errors.append("configuration 不支持字段 %s" % str(field))
    var hook := str(configuration.get("hook", ""))
    if hook not in SUPPORTED_HOOKS:
        errors.append("hook 不是已支持的 Run committed 事件：%s" % hook)
    if str(configuration.get("outcome", "")) != "player_victory":
        errors.append("当前战果值效果必须明确限定 player_victory")
    var effect = configuration.get("effect")
    if not effect is Dictionary:
        errors.append("effect 必须是对象")
        return errors
    for field in effect:
        if str(field) not in ["op", "kind", "amount"]:
            errors.append("effect 不支持字段 %s" % str(field))
    if str(effect.get("op", "")) not in SUPPORTED_RUN_EFFECTS:
        errors.append("effect.op 不是已登记的本局效果")
    var amount = effect.get("amount")
    var registry = ValueSpecRegistryScript.new()
    registry.validate_amount_spec(
        amount,
        func(scope: String, message: String):
            errors.append("%s：%s" % [scope, message]),
        "effect.amount")
    return errors


func handle(
        hook: String,
        context,
        configuration: Dictionary) -> Dictionary:
    if hook != str(configuration.get("hook", "")):
        return {"success": true, "skipped": true}
    if str(context.outcome) != str(configuration.get("outcome", "")):
        return {"success": true, "skipped": true}
    var ports = context.payload.get("effect_ports")
    if ports == null:
        return {"success": false, "reason": "Run 值效果缺少受控效果端口"}
    var effect: Dictionary = configuration.get("effect", {}).duplicate(true)
    effect["amount"] = _value_resolver.resolve(effect.get("amount", 0), {
        "actor": context.owner,
        "owner": context.owner,
    })
    effect["source"] = str(context.source.content_id) \
        if context.source != null else "run_value_effect"
    var applied: Dictionary = ports.apply_effects([effect])
    if not applied.get("success", false):
        return applied
    return {
        "success": true,
        "amount": int(effect["amount"]),
        "effect_result": applied,
    }
