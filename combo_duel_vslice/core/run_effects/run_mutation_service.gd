class_name RunMutationService
extends RefCounted

const RunEffectContextScript = preload(
    "res://core/run_effects/run_effect_context.gd")
const RunEffectValidationScript = preload(
    "res://core/run_effects/run_effect_validation.gd")
const RunEffectHandlerRegistryScript = preload(
    "res://core/run_effects/run_effect_handler_registry.gd")

var handler_registry
var content_catalog

func _init(registry_override = null, content_catalog_override = null) -> void:
    handler_registry = (
        registry_override
        if registry_override != null
        else RunEffectHandlerRegistryScript.new())
    content_catalog = content_catalog_override

func apply_effects(effects: Array, growth, context: Dictionary = {}) -> Dictionary:
    for registration_error in handler_registry.registration_errors():
        return _failure(str(registration_error), -1, "")
    for index in range(effects.size()):
        var effect_value = effects[index]
        if not effect_value is Dictionary:
            return _failure("本局效果必须是对象", index, "")
        var effect: Dictionary = effect_value
        var validation = RunEffectValidationScript.new()
        handler_registry.validate_effect(
            effect, validation, "effects[%d]" % index)
        if not validation.is_valid():
            return _failure(
                "；".join(validation.errors),
                index,
                str(effect.get("op", "")))

    var state_before: Dictionary = growth.capture_mutation_state()
    var working_growth = growth.create_mutation_copy()
    if working_growth == null:
        return _failure("无法建立本局事务工作副本", -1, "")
    var runtime_context = RunEffectContextScript.new(
        working_growth, context, content_catalog)
    var applied: Array = []
    for index in range(effects.size()):
        var effect: Dictionary = effects[index]
        var result: Dictionary = handler_registry.apply(effect, runtime_context)
        if not result.get("success", false):
            return _failure(
                str(result.get("reason", "本局效果执行失败")),
                index,
                str(effect.get("op", "")))
        applied.append(result.get("applied", {}).duplicate(true))

    working_growth.recalculate_effective_max_life()
    var state_after: Dictionary = working_growth.capture_mutation_state()
    var commit_errors: Array[String] = growth.replace_mutation_state(state_after)
    if not commit_errors.is_empty():
        return _failure("；".join(commit_errors), -1, "")
    return {
        "success": true,
        "applied": applied,
        "changed": state_before != state_after,
        "state_before": _summarize(state_before),
        "state_after": _summarize(state_after),
        # Run 命令只在整个工作副本提交成功后公开 canonical marker 事实；
        # 失败路径不会泄漏已经回滚的 source_marker_changed。
        "committed_events": runtime_context.committed_events.duplicate(true),
    }

func _failure(reason: String, effect_index: int, operation_id: String) -> Dictionary:
    return {
        "success": false,
        "reason": reason,
        "failed_effect_index": effect_index,
        "failed_operation_id": operation_id,
    }

func _summarize(state: Dictionary) -> Dictionary:
    return {
        "experience": int(state.get("experience", 0)),
        "life": int(state.get("life", 0)),
        "max_life": int(state.get("max_life", 0)),
        "consumable_count": state.get("consumable_ids", []).size(),
        "learned_technique_count": state.get("learned_technique_ids", []).size(),
        "learned_inner_skill_count": state.get("learned_inner_skill_ids", []).size(),
        "equipped_inner_skill_count": state.get("equipped_inner_skill_ids", []).size(),
        "run_deck_count": state.get("run_deck", {}).get("cards", []).size(),
        "practice_purchase_count": state.get("practice_purchases", {}).size(),
    }
