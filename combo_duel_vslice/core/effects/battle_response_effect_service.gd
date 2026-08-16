class_name BattleResponseEffectService
extends RefCounted

## BattleEffectPorts 内部的延迟效果、动态响应与直接真气监听编排服务。
##
## 延迟记录、响应匹配与到期扫描仍完全由 StatusSystem 维护；直接真气监听仍由
## CardReshapeBattleRuntime 的 replay service 维护。本服务只提供稳定的窄委托边界。

var _status_system
var _card_reshape_runtime_ref: WeakRef


func _init(status_system) -> void:
    assert(status_system != null, "BattleResponseEffectService requires StatusSystem")
    _status_system = status_system


func use_card_reshape_runtime(runtime) -> void:
    assert(runtime != null,
        "BattleResponseEffectService requires CardReshapeBattleRuntime")
    _card_reshape_runtime_ref = weakref(runtime)


func notify_response_event(event_kind: String, values: Dictionary) -> void:
    _status_system.handle_response_event(event_kind, values)


func successful_on_play_ids(action_token: String) -> Array:
    var runtime = _card_reshape_runtime()
    return runtime.successful_on_play_ids(action_token) if runtime != null else []


func register_direct_card_trigger_listener(
        listener_id: String,
        listener) -> bool:
    var runtime = _card_reshape_runtime()
    return runtime != null and runtime.trigger_replay_service \
        .register_direct_listener(listener_id, listener)


func unregister_direct_card_trigger_listener(listener_id: String) -> bool:
    var runtime = _card_reshape_runtime()
    return runtime != null and runtime.trigger_replay_service \
        .unregister_direct_listener(listener_id)


func register_delayed_effects(
        label: String,
        timing: String,
        occurrences: int,
        effects: Array,
        context) -> Dictionary:
    return _status_system.register_delayed_effects(
        label, timing, occurrences, effects, context)


func register_response(
        event_kind: String,
        expiry: String,
        effects: Array,
        context,
        filters: Dictionary = {},
        expiry_effects: Array = []) -> Dictionary:
    return _status_system.register_response(
        event_kind, expiry, effects, context, filters, expiry_effects)


func register_next_round_hand_limit(
        context, amount: int, affected_side = null) -> Dictionary:
    return _status_system.register_next_round_hand_limit(
        context, amount, affected_side)


func register_defense_decay_return(context) -> Dictionary:
    return _status_system.register_defense_decay_return(context)


func register_reflection_expiry(context, percent: int) -> Dictionary:
    return _status_system.register_reflection_expiry(context, percent)


func register_no_life_loss_disruption(
        context, effect: Dictionary) -> Dictionary:
    return _status_system.register_no_life_loss_disruption(context, effect)


func technique_draw_count(side) -> int:
    return _status_system.technique_draw_count(side)


func _card_reshape_runtime():
    return (
        _card_reshape_runtime_ref.get_ref()
        if _card_reshape_runtime_ref != null else null)
