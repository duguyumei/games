class_name TechniqueEffectExecutor
extends RefCounted

const RegistryScript = preload("res://core/effects/effect_handler_registry.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")
const ContinuationScript = preload("res://core/effects/technique_effect_continuation.gd")

var rng: RandomNumberGenerator
var registry

func _init(random_source: RandomNumberGenerator, registry_override = null, content_catalog = null) -> void:
    rng = random_source
    registry = (
        registry_override
        if registry_override != null
        else RegistryScript.new(random_source, null, content_catalog))

func execute_all(effects: Array, context) -> Dictionary:
    if context is Dictionary and not context.has("captures"):
        context["captures"] = {}
    return _continue(ContinuationScript.new().configure({
        "effects": effects,
        "context": context,
    }))

func resume(continuation, request_id: String, selected_ids: Array) -> Dictionary:
    if continuation == null or continuation.choice_request == null:
        return _failed_resume("当前没有可恢复的功法选择")
    if str(continuation.choice_request.request_id) != request_id:
        return _failed_resume("选择请求已失效或不匹配")
    var selection_check: Dictionary = continuation.choice_request.validate_selection(selected_ids)
    if not selection_check.get("ok", false):
        return _failed_resume(str(selection_check.get("reason", "选择不合法")), continuation)
    continuation.context.choice_responses[request_id] = selected_ids.duplicate()
    continuation.choice_request = null
    return _continue(continuation)

func _continue(continuation) -> Dictionary:
    while continuation.effect_index < continuation.effects.size():
        var effect_value = continuation.effects[continuation.effect_index]
        var effect: Dictionary = effect_value
        if not registry.condition_met(effect.get("when", {}), continuation.context):
            continuation.effect_index += 1
            continue
        var result: Dictionary = EffectResultScript.normalize(
            registry.execute(effect, continuation.context))
        continuation.effect_results.append(_public_effect_result(result))
        if result.get("pending_choice", false):
            var request_object = result.get("_choice_request_object")
            continuation.choice_request = request_object
            return {
                "status": EffectResultScript.PENDING_CHOICE,
                "success": false,
                "pending_choice": true,
                "detail": result.get("detail", "等待选择"),
                "choice_request": (
                    continuation.choice_snapshot()
                    if request_object != null
                    else result.get("choice_request", {}).duplicate(true)),
                "effect_results": continuation.effect_results.duplicate(true),
                "_continuation": continuation if request_object != null else null,
            }
        if not result.get("success", false):
            return {
                "status": EffectResultScript.FAILED,
                "success": false,
                "pending_choice": false,
                "detail": result.get("detail", "未知效果失败"),
                "effect_results": continuation.effect_results.duplicate(true),
            }
        if result.get("detail", "") != "":
            continuation.details.append(str(result["detail"]))
        continuation.effect_index += 1
    return {
        "status": EffectResultScript.SUCCEEDED,
        "success": true,
        "pending_choice": false,
        "detail": "；".join(continuation.details),
        "effect_results": continuation.effect_results.duplicate(true),
    }

func _failed_resume(detail: String, continuation = null) -> Dictionary:
    var result := {
        "status": EffectResultScript.FAILED,
        "success": false,
        "pending_choice": continuation != null and continuation.choice_request != null,
        "detail": detail,
        "effect_results": (
            continuation.effect_results.duplicate(true)
            if continuation != null else []),
    }
    if continuation != null and continuation.choice_request != null:
        result["choice_request"] = continuation.choice_snapshot()
        result["_continuation"] = continuation
    return result

func _public_effect_result(result: Dictionary) -> Dictionary:
    var public_result := result.duplicate(true)
    public_result.erase("_choice_request_object")
    return public_result

func summarize_intent(effects: Array, context, initial_damage_percent: int = 0) -> Dictionary:
    var intent := {
        "damage": 0,
        "defense": 0,
        "segments": 0,
        "technique_combo": false,
    }
    var state := {"damage_percent": initial_damage_percent}
    for effect_value in effects:
        var effect: Dictionary = effect_value
        if registry.condition_met(effect.get("when", {}), context):
            registry.summarize(effect, context, intent, state)
    return intent
