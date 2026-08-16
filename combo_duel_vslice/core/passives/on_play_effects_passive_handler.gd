class_name OnPlayEffectsPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

const DelegateScript = preload(
    "res://core/passives/battle_effects_passive_handler.gd")

var _delegate

func _init(effect_registry = null) -> void:
    _delegate = DelegateScript.new(effect_registry)

func behavior_id() -> String:
    return "on_play_effects"

func supported_hooks() -> Array[String]:
    return ["action_preview", "action_resolve"] as Array[String]

func use_effect_indexes(anomalies_by_id: Dictionary) -> void:
    _delegate.use_effect_indexes(anomalies_by_id)

func use_effect_registry(effect_registry) -> void:
    _delegate.use_effect_registry(effect_registry)

func validate_configuration(configuration: Dictionary) -> Array[String]:
    return _delegate.validate_effect_configuration(
        configuration, "action_resolve")

func handle(hook: String, context, configuration: Dictionary) -> Dictionary:
    return _delegate.handle_effects(
        hook, context, configuration, "action_resolve")
