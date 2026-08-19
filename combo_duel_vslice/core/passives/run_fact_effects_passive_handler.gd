class_name RunFactEffectsPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

const RunEffectRegistryScript = preload(
    "res://core/run_effects/run_effect_handler_registry.gd")
const RunEffectValidationScript = preload(
    "res://core/run_effects/run_effect_validation.gd")
const ConditionSpecRegistryScript = preload(
    "res://core/specs/condition_spec_registry.gd")

const SUPPORTED_HOOKS := [
    "run_qi_permanently_added",
    "qi_reshape_committed",
    "experience_change_resolved",
]

## ContentCatalog / ContentValidator 的正式装配会注入组合根唯一的 Run
## Effect Registry。默认实例只保留给直接构造 Handler 的旧测试与工具。
var _effect_registry
var _condition_registry = ConditionSpecRegistryScript.new()


func _init(effect_registry = null) -> void:
    _effect_registry = (
        effect_registry
        if effect_registry != null
        else RunEffectRegistryScript.new())


func use_run_effect_registry(effect_registry) -> void:
    if effect_registry != null:
        _effect_registry = effect_registry


func behavior_id() -> String:
    return "run_fact_effects"


func supported_hooks() -> Array[String]:
    return SUPPORTED_HOOKS.duplicate()


func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field_value in configuration:
        if str(field_value) != "rules":
            errors.append("configuration 不支持字段 %s" % str(field_value))
    var rules = configuration.get("rules")
    if not rules is Array or rules.is_empty():
        errors.append("rules 必须是非空数组")
        return errors
    for index in range(rules.size()):
        var rule_value = rules[index]
        var scope := "rules[%d]" % index
        if not rule_value is Dictionary:
            errors.append("%s 必须是对象" % scope)
            continue
        var rule: Dictionary = rule_value
        for field_value in rule:
            if str(field_value) not in ["hook", "filters", "effects"]:
                errors.append("%s 不支持字段 %s" % [scope, str(field_value)])
        var hook := str(rule.get("hook", ""))
        if hook not in SUPPORTED_HOOKS:
            errors.append("%s.hook 不是正式 Run 提交事实：%s" % [scope, hook])
        var filters = rule.get("filters", {})
        if not filters is Dictionary:
            errors.append("%s.filters 必须是对象" % scope)
        else:
            _condition_registry.validate_event_filters(
                filters,
                func(filter_scope: String, message: String):
                    errors.append("%s: %s" % [filter_scope, message]),
                scope + ".filters")
        var effects = rule.get("effects")
        if not effects is Array or effects.is_empty():
            errors.append("%s.effects 必须是非空数组" % scope)
            continue
        for effect_index in range(effects.size()):
            var effect = effects[effect_index]
            if not effect is Dictionary:
                errors.append("%s.effects[%d] 必须是对象" % [scope, effect_index])
                continue
            var validation = RunEffectValidationScript.new()
            _effect_registry.validate_effect(
                effect, validation, "%s.effects[%d]" % [scope, effect_index])
            errors.append_array(validation.errors)
    return errors


func handle(hook: String, context, configuration: Dictionary) -> Dictionary:
    var effects: Array = []
    var matched_rules: Array[int] = []
    var rules: Array = configuration.get("rules", [])
    for index in range(rules.size()):
        var rule: Dictionary = rules[index]
        if str(rule.get("hook", "")) != hook:
            continue
        if not _filters_match(rule.get("filters", {}), context):
            continue
        matched_rules.append(index)
        effects.append_array(rule.get("effects", []).duplicate(true))
    if effects.is_empty():
        return {"success": true, "skipped": true, "matched_rules": []}
    var ports = context.payload.get("effect_ports")
    if ports == null:
        return {"success": false, "reason": "Run 提交事实缺少受控效果端口"}
    # RunPassiveEventContext 已把基础端口收窄到当前 Invocation；来源地址、
    # marker 声明和 source-specific transaction token 均由端口注入。内容与
    # Handler 不覆盖它们，避免多个来源共享同一 marker event token。
    var applied: Dictionary = ports.apply_effects(effects)
    if not applied.get("success", false):
        return applied
    return {
        "success": true,
        "matched_rules": matched_rules,
        "effect_result": applied,
        "committed_events": applied.get("committed_events", []).duplicate(true),
    }


func _filters_match(filters, context) -> bool:
    if not filters is Dictionary or filters.is_empty():
        return true
    var values: Dictionary = context.payload.duplicate(false)
    var record := {
        "actor": context.owner,
        "target": context.target,
        "action_token": str(values.get("action_token", "")),
        "root_action_token": str(values.get("root_action_token", "")),
    }
    return _condition_registry.event_matches(
        filters, values, context.owner, context.target, record)
