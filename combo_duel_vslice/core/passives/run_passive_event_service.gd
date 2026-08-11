class_name RunPassiveEventService
extends RefCounted

const EventContextScript = preload(
    "res://core/passives/run_passive_event_context.gd")
const EffectPortsScript = preload(
    "res://core/passives/run_passive_effect_ports.gd")

const COMMITTED_EVENT_HOOKS := [
    "practice_opened",
    "practice_purchase_committed",
    "practice_pack_opened",
    "meditation_committed",
    "inner_skill_forgotten",
    "battle_completed",
    "node_completed",
]

var _runtime_ref: WeakRef
var _mutation_service

func _init(passive_runtime, mutation_service = null) -> void:
    _runtime_ref = weakref(passive_runtime)
    _mutation_service = mutation_service

func capture_source_snapshot(owner) -> Array:
    var runtime = _runtime_ref.get_ref()
    if runtime == null:
        return []
    return runtime.capture_source_snapshot({"owner": owner})

func source_fingerprint(owner, hooks: Array, source_snapshot: Array = []) -> Dictionary:
    var runtime = _runtime_ref.get_ref()
    if runtime == null:
        return {"success": false, "fingerprint": "", "errors": ["被动规则运行时已释放"]}
    var values := {"owner": owner}
    if not source_snapshot.is_empty():
        values["source_snapshot"] = source_snapshot
    return runtime.source_fingerprint(hooks, values)

func dispatch(context, growth, event_state) -> Dictionary:
    if not context is EventContextScript:
        return {"success": false, "reason": "本局被动事件必须使用 RunPassiveEventContext"}
    if context.hook not in COMMITTED_EVENT_HOOKS:
        return {"success": false, "reason": "不是已登记的本局提交事件：%s" % context.hook}
    if context.transaction_token == "":
        return {"success": false, "reason": "%s 缺少 transaction_token" % context.hook}
    if event_state == null:
        return {"success": false, "reason": "本局被动事件缺少类型化事件状态"}
    if event_state.committed_passive_event_tokens.has(context.transaction_token):
        return {
            "success": true,
            "duplicate": true,
            "hook": context.hook,
            "transaction_token": context.transaction_token,
            "results": [],
        }
    var runtime = _runtime_ref.get_ref()
    if runtime == null:
        return {"success": false, "reason": "被动规则运行时已释放"}
    var state_before: Dictionary = growth.capture_mutation_state()
    context.owner = growth
    context.actor = growth
    var ports = EffectPortsScript.new(
        growth, _mutation_service, context.to_dict())
    context.payload["effect_ports"] = ports
    var dispatched: Dictionary = runtime.dispatch_event(context.hook, context)
    if not dispatched.get("success", false):
        var rollback_errors: Array[String] = growth.replace_mutation_state(state_before)
        var reason := "；".join(dispatched.get("errors", []))
        if not rollback_errors.is_empty():
            reason += "；回滚失败：%s" % "；".join(rollback_errors)
        return {
            "success": false,
            "reason": reason,
            "hook": context.hook,
            "transaction_token": context.transaction_token,
            "results": dispatched.get("results", []),
        }
    event_state.committed_passive_event_tokens.append(
        context.transaction_token)
    return {
        "success": true,
        "duplicate": false,
        "hook": context.hook,
        "transaction_token": context.transaction_token,
        "invocation_count": dispatched.get("results", []).size(),
        "results": _result_breakdown(dispatched.get("results", [])),
    }

func _result_breakdown(values: Array) -> Array:
    var result: Array = []
    for entry in values:
        var source = entry.get("source")
        var invocation = entry.get("invocation")
        result.append({
            "source_kind": source.source_kind,
            "content_id": source.content_id,
            "source_instance_key": source.source_instance_key,
            "behavior_id": source.behavior_id,
            "execution_index": invocation.execution_index,
            "execution_count": invocation.execution_count,
            "result": entry.get("result", {}).duplicate(true),
        })
    return result
