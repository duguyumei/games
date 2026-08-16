class_name OnPlayEffectsPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

const EffectSpecValidatorScript = preload("res://core/effect_spec_validator.gd")
const EffectHandlerRegistryScript = preload(
    "res://core/effects/effect_handler_registry.gd")

var _effect_registry
var _anomalies_by_id: Dictionary = {}

func _init(effect_registry = null) -> void:
    _effect_registry = effect_registry
    if _effect_registry == null:
        _effect_registry = EffectHandlerRegistryScript.new(RandomNumberGenerator.new())

func behavior_id() -> String:
    return "on_play_effects"

func supported_hooks() -> Array[String]:
    return ["action_preview", "action_resolve"] as Array[String]

func use_effect_indexes(anomalies_by_id: Dictionary) -> void:
    _anomalies_by_id = anomalies_by_id

func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for key in configuration:
        if str(key) != "effects":
            errors.append("configuration 不支持字段 %s" % str(key))
    var validator = EffectSpecValidatorScript.new(
        func(scope: String, message: String): errors.append("%s: %s" % [scope, message]),
        {
            "attribute_ids": ["wind", "forest", "fire", "mountain"],
            "anomaly_category_ids": ["buff", "debuff", "state", "mark"],
            "reshape_category_ids": ["origin", "enhancement", "imprint", "other"],
            "hand_ids": [
                "high_card", "pair", "two_pair", "three_kind", "straight",
                "full_house", "four_kind", "five_kind"],
        },
        _effect_registry)
    validator.use_indexes(_anomalies_by_id)
    validator.validate_effects(configuration.get("effects"), "battle", "effects")
    return errors

func handle(hook: String, context, configuration: Dictionary) -> Dictionary:
    var effects = configuration.get("effects")
    if not effects is Array or effects.is_empty():
        return {"success": false, "reason": "on_play_effects.effects 配置无效"}
    if hook == "action_preview":
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
    if hook == "action_resolve":
        return {"success": true, "effects": effects.duplicate(true)}
    return {"success": false, "reason": "on_play_effects 不支持 hook %s" % hook}
