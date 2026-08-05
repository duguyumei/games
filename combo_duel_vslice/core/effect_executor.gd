class_name TechniqueEffectExecutor
extends RefCounted

const RegistryScript = preload("res://core/effects/effect_handler_registry.gd")

var rng: RandomNumberGenerator
var registry

func _init(random_source: RandomNumberGenerator, registry_override = null, content_catalog = null) -> void:
    rng = random_source
    registry = (
        registry_override
        if registry_override != null
        else RegistryScript.new(random_source, null, content_catalog))

func execute_all(effects: Array, context: Dictionary) -> Dictionary:
    if not context.has("captures"):
        context["captures"] = {}
    var details: Array[String] = []
    for effect_value in effects:
        var effect: Dictionary = effect_value
        if not registry.condition_met(effect.get("when", {}), context):
            continue
        var result: Dictionary = registry.execute(effect, context)
        if not result.get("success", false):
            return {"success": false, "detail": result.get("detail", "未知效果失败")}
        if result.get("detail", "") != "":
            details.append(str(result["detail"]))
    return {"success": true, "detail": "；".join(details)}

func summarize_intent(effects: Array, context: Dictionary, initial_momentum: int = 0) -> Dictionary:
    var intent := {
        "damage": 0,
        "defense": 0,
        "segments": 0,
        "technique_combo": false,
    }
    var state := {"momentum": maxi(0, initial_momentum)}
    for effect_value in effects:
        var effect: Dictionary = effect_value
        if registry.condition_met(effect.get("when", {}), context):
            registry.summarize(effect, context, intent, state)
    return intent
