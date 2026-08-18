class_name BattleInvocationEffectService
extends RefCounted

## BattleEffectPorts 内部的效果上下文、即时嵌套与功法调用编排服务。
##
## EffectExecutor 仍是效果 continuation 的唯一事实源，TechniqueInvocationService
## 仍是功法调用冻结、排序、推进与递归保护的唯一事实源。本服务只维护 Facade 所需
## 的当前上下文栈和即时插入队列，并把调用时点与重触回调收束到窄边界。

var _effect_executor_ref: WeakRef
var _technique_invocation_service_ref: WeakRef
var _hand_retrigger_callback: Callable
var _effect_context_stack: Array = []
var _effect_context_slot_entries: Dictionary = {}
var _immediate_effects_by_context: Dictionary = {}


func use_effect_executor(executor) -> void:
    _effect_executor_ref = weakref(executor) if executor != null else null


func use_technique_invocation_service(service) -> void:
    _technique_invocation_service_ref = weakref(service) if service != null else null


func use_hand_retrigger_callback(callback: Callable) -> void:
    _hand_retrigger_callback = callback


func push_effect_context(context) -> void:
    _effect_context_stack.append(context)
    var invocation_service = _technique_invocation_service()
    if invocation_service != null:
        var slot_id := str(context.get("slot_instance_id") \
            if context is Dictionary else context.slot_instance_id)
        _effect_context_slot_entries[context] = {
            "slot_instance_id": slot_id,
            "entered": invocation_service.enter_resolution_slot(slot_id),
        }


func pop_effect_context(context) -> void:
    if not _effect_context_stack.is_empty() and _effect_context_stack.back() == context:
        _effect_context_stack.pop_back()
    else:
        _effect_context_stack.erase(context)
    var invocation_service = _technique_invocation_service()
    if invocation_service != null and _effect_context_slot_entries.has(context):
        var entry: Dictionary = _effect_context_slot_entries[context]
        invocation_service.exit_resolution_slot(
            str(entry.get("slot_instance_id", "")), bool(entry.get("entered", false)))
        _effect_context_slot_entries.erase(context)


func current_effect_context():
    return _effect_context_stack.back() if not _effect_context_stack.is_empty() else null


func schedule_immediate_effect(context, effect: Dictionary) -> bool:
    if context == null or effect.is_empty():
        return false
    if not _immediate_effects_by_context.has(context):
        _immediate_effects_by_context[context] = []
    _immediate_effects_by_context[context].append(effect.duplicate(true))
    return true


func take_immediate_effects(context) -> Array:
    var result: Array = _immediate_effects_by_context.get(context, [])
    _immediate_effects_by_context.erase(context)
    return result


func abort_action_resolution() -> void:
    _immediate_effects_by_context.clear()


func execute_effect_chain(effects: Array, context) -> Dictionary:
    var executor = _effect_executor()
    var parent = current_effect_context()
    if executor != null and parent != null \
            and not context is Dictionary \
            and not parent is Dictionary \
            and int(parent.effect_command_limit) > 0:
        context.effect_command_limit = int(parent.effect_command_limit)
        context.effect_chain_state = parent.effect_chain_state
    return executor.execute_all(effects, context) if executor != null else {
        "success": false, "detail": "战斗端口缺少效果执行器"}


func invoke_sequence_technique(effect: Dictionary, context) -> Dictionary:
    var invocation_service = _technique_invocation_service()
    if invocation_service == null:
        return {"success": false, "reason": "功法调用服务尚未装配"}
    return invocation_service.invoke(effect, context)


func resolve_after_caller_advance(root_action_token: String) -> Dictionary:
    var invocation_service = _technique_invocation_service()
    if invocation_service == null:
        return {"success": true, "results": []}
    return invocation_service.resolve_after_caller_advance(root_action_token)


func resolve_technique_invocations_at_timing(
        timing: String,
        root_action_token: String = "") -> Dictionary:
    var invocation_service = _technique_invocation_service()
    if invocation_service == null:
        return {"success": true, "results": []}
    return invocation_service.resolve_timing(timing, root_action_token)


func retrigger_current_hand_technique(
        actor,
        target,
        sequence_book,
        power_snapshot: Dictionary,
        maximum_discard: int,
        excluded_technique_ids: Array,
        execution_context = null) -> Dictionary:
    if not _hand_retrigger_callback.is_valid():
        return {"success": false, "detail": "当前未连接功法重触端口"}
    return _hand_retrigger_callback.call(
        actor,
        target,
        sequence_book,
        power_snapshot,
        maximum_discard,
        excluded_technique_ids,
        execution_context)


func _effect_executor():
    return _effect_executor_ref.get_ref() \
        if _effect_executor_ref != null else null


func _technique_invocation_service():
    return _technique_invocation_service_ref.get_ref() \
        if _technique_invocation_service_ref != null else null
