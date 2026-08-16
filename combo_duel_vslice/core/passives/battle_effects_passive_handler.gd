class_name BattleEffectsPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

const EffectSpecValidatorScript = preload("res://core/effect_spec_validator.gd")
const EffectHandlerRegistryScript = preload(
    "res://core/effects/effect_handler_registry.gd")
const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")

const MUTATION_HOOKS := ["action_resolve"] \
    + BattleEventCatalogScript.TIMING_EVENTS \
    + BattleEventCatalogScript.COMMITTED_EVENTS
const SUPPORTED_HOOKS := ["action_preview"] + MUTATION_HOOKS
const RESERVED_EFFECT_FIELDS := [
    "source_kind", "source_id", "source_name", "source_instance_key",
    "trigger_mode", "event_token", "action_token",
]

var _effect_registry_ref: WeakRef
var _fallback_effect_registry = null
var _anomalies_by_id: Dictionary = {}

func _init(effect_registry = null) -> void:
    use_effect_registry(effect_registry)

func behavior_id() -> String:
    return "battle_effects"

func supported_hooks() -> Array[String]:
    return SUPPORTED_HOOKS.duplicate()

func use_effect_registry(effect_registry) -> void:
    _fallback_effect_registry = null
    if effect_registry == null:
        _fallback_effect_registry = EffectHandlerRegistryScript.new(
            RandomNumberGenerator.new())
        _effect_registry_ref = weakref(_fallback_effect_registry)
    else:
        _effect_registry_ref = weakref(effect_registry)

func use_effect_indexes(anomalies_by_id: Dictionary) -> void:
    _anomalies_by_id = anomalies_by_id

func validate_configuration(configuration: Dictionary) -> Array[String]:
    return validate_effect_configuration(configuration, "")

func validate_effect_configuration(
        configuration: Dictionary,
        forced_hook: String) -> Array[String]:
    var errors: Array[String] = []
    var allowed_fields := ["effects"] if forced_hook != "" \
        else ["hook", "order", "effects"]
    for key in configuration:
        if str(key) not in allowed_fields:
            errors.append("configuration 不支持字段 %s" % str(key))
    var hook := forced_hook if forced_hook != "" \
        else str(configuration.get("hook", ""))
    if hook not in MUTATION_HOOKS:
        errors.append("hook 不是正式可写战斗 Hook：%s" % hook)
    if hook in BattleEventCatalogScript.TIMING_EVENTS:
        if not configuration.get("order") is int:
            errors.append("生命周期 Hook 必须声明整数 order")
    elif forced_hook == "" and configuration.has("order"):
        errors.append("只有生命周期 Hook 可以声明 order")
    _validate_reserved_fields(
        configuration.get("effects", []), "effects", errors)
    if hook != "action_resolve":
        _validate_non_action_phase_fields(
            configuration.get("effects", []), "effects", errors)
    var validator = EffectSpecValidatorScript.new(
        func(scope: String, message: String):
            errors.append("%s: %s" % [scope, message]),
        {
            "attribute_ids": ["wind", "forest", "fire", "mountain"],
            "anomaly_category_ids": ["buff", "debuff", "state", "mark"],
            "reshape_category_ids": [
                "origin", "enhancement", "imprint", "other",
                "temporary_enhancement", "temporary_attribute",
                "temporary_rank"],
            "hand_ids": [
                "high_card", "pair", "two_pair", "three_kind", "straight",
                "full_house", "four_kind", "five_kind"],
        },
        _effect_registry())
    validator.use_indexes(_anomalies_by_id)
    validator.validate_effects(
        configuration.get("effects"), "battle", "effects")
    return errors

func _effect_registry():
    return _effect_registry_ref.get_ref() \
        if _effect_registry_ref != null else null

func battle_timing_bindings(configuration: Dictionary) -> Array:
    var hook := str(configuration.get("hook", ""))
    if hook not in BattleEventCatalogScript.TIMING_EVENTS:
        return []
    return [{"hook": hook, "order": int(configuration.get("order", 0))}]

func handle(hook: String, context, configuration: Dictionary) -> Dictionary:
    return handle_effects(hook, context, configuration, "")

func handle_effects(
        hook: String,
        context,
        configuration: Dictionary,
        forced_hook: String) -> Dictionary:
    var configured_hook := forced_hook if forced_hook != "" \
        else str(configuration.get("hook", ""))
    var effects = configuration.get("effects")
    if not effects is Array or effects.is_empty():
        return {"success": false, "reason": "battle_effects.effects 配置无效"}
    if hook == "action_preview":
        if configured_hook != "action_resolve":
            return {"success": true, "skipped": true, "intent": {}}
        var executor = context.payload.get("effect_executor")
        if executor == null:
            return {"success": false, "reason": "action_preview 缺少 EffectExecutor"}
        return {
            "success": true,
            "intent": executor.summarize_intent(
                effects,
                context.effect_context_for(),
                int(context.payload.get("damage_percent", 0))),
        }
    if hook != configured_hook:
        return {"success": true, "skipped": true}
    return {"success": true, "effects": effects.duplicate(true)}

func _validate_reserved_fields(value, scope: String, errors: Array[String]) -> void:
    if value is Dictionary:
        # 只在 EffectSpec 根上保留来源字段；ConditionSpec、事件 filters 与
        # ValueSpec 可以合法地读取同名公开字段，不能因递归扫描而被误判为伪造。
        if value.has("op"):
            for field in RESERVED_EFFECT_FIELDS:
                if value.has(field):
                    errors.append(
                        "%s.%s 由运行时注入，内容不得伪造" % [scope, field])
        for key in value:
            _validate_reserved_fields(
                value[key], "%s.%s" % [scope, str(key)], errors)
    elif value is Array:
        for index in range(value.size()):
            _validate_reserved_fields(
                value[index], "%s[%d]" % [scope, index], errors)

func _validate_non_action_phase_fields(
        value, scope: String, errors: Array[String]) -> void:
    if value is Dictionary:
        if value.has("op") and value.has("phase"):
            errors.append(
                "%s.phase 只允许 action_resolve 参与功法阶段编排" % scope)
        for key in value:
            _validate_non_action_phase_fields(
                value[key], "%s.%s" % [scope, str(key)], errors)
    elif value is Array:
        for index in range(value.size()):
            _validate_non_action_phase_fields(
                value[index], "%s[%d]" % [scope, index], errors)
