class_name RunPassiveEventService
extends RefCounted

const EventContextScript = preload(
    "res://core/passives/run_passive_event_context.gd")
const EffectPortsScript = preload(
    "res://core/passives/run_passive_effect_ports.gd")

const COMMITTED_EVENT_HOOKS := [
    "run_qi_permanently_added",
    "qi_reshape_committed",
    "practice_opened",
    "practice_purchase_committed",
    "practice_pack_opened",
    "meditation_committed",
    "inner_skill_forgotten",
    "battle_completed",
    "node_completed",
    "experience_change_resolved",
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
    var committed_tokens: Variant = _committed_tokens(event_state)
    if committed_tokens == null:
        return {"success": false, "reason": "本局被动事件缺少类型化事件状态"}
    var committed_token: String = (
        context.event_token
        if str(context.event_token) != ""
        else context.transaction_token)
    if committed_tokens.has(committed_token):
        return {
            "success": true,
            "duplicate": true,
            "hook": context.hook,
            "transaction_token": context.transaction_token,
            "event_token": committed_token,
            "results": [],
        }
    var runtime = _runtime_ref.get_ref()
    if runtime == null:
        return {"success": false, "reason": "被动规则运行时已释放"}
    var state_before: Dictionary = growth.capture_mutation_state()
    context.owner = growth
    context.actor = growth
    # 调用方可在命令变更前显式提供局部快照；否则在事件真正开始时从当前
    # owner 捕获一次。即使结果为空也标记为已有快照，避免 Invocation 间重扫。
    if not context.has_source_snapshot:
        context.has_source_snapshot = true
        context.source_snapshot = capture_source_snapshot(growth)
    var port_metadata: Dictionary = context.to_dict()
    port_metadata["experience_response_ancestry"] = context.payload.get(
        "experience_response_ancestry", []).duplicate()
    var ports = EffectPortsScript.new(
        growth, _mutation_service, port_metadata)
    context.payload["effect_ports"] = ports
    var dispatched: Dictionary = runtime.dispatch_event(
        context.hook, context, "mutation")
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
    committed_tokens.append(committed_token)
    return {
        "success": true,
        "duplicate": false,
        "hook": context.hook,
        "transaction_token": context.transaction_token,
        "event_token": committed_token,
        "invocation_count": dispatched.get("results", []).size(),
        "results": _result_breakdown(dispatched.get("results", [])),
    }

## RunMutationService 的 working-copy 事务不拥有正式 ComboRunState。它通过
## 本窄入口把去重 token 暂存在调用栈内；只有 Growth 最终提交成功后，调用方
## 才能看到返回的 canonical 事实，失败不会污染正式 RunState token。
func dispatch_staged(
        context,
        growth,
        committed_event_tokens: Array) -> Dictionary:
    return dispatch(context, growth, {
        "committed_passive_event_tokens": committed_event_tokens,
    })

func _committed_tokens(event_state):
    if event_state == null:
        return null
    if event_state is Dictionary:
        var values = event_state.get("committed_passive_event_tokens")
        return values if values is Array else null
    var values = event_state.get("committed_passive_event_tokens")
    return values if values is Array else null

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
