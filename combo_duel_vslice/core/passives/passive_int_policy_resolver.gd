class_name PassiveIntPolicyResolver
extends RefCounted

const RequestScript = preload(
    "res://core/passives/passive_int_query_request.gd")
const BattleRequestScript = preload(
    "res://core/passives/battle_passive_int_query_request.gd")
const ResultScript = preload(
    "res://core/passives/passive_int_query_result.gd")
const ContextScript = preload(
    "res://core/passives/passive_rule_context.gd")
const PureQueryGuardScript = preload(
    "res://core/passives/battle_pure_query_guard.gd")

var _runtime_ref: WeakRef
var _pure_query_guard

func _init(passive_runtime, pure_query_guard = null) -> void:
    _runtime_ref = weakref(passive_runtime)
    _pure_query_guard = pure_query_guard \
        if pure_query_guard != null else PureQueryGuardScript.new()

func use_pure_query_guard(guard) -> void:
    _pure_query_guard = guard if guard != null else PureQueryGuardScript.new()

func resolve(request):
    var participants: Array = []
    if request is RequestScript and request.owner != null:
        participants.append(request.owner)
    var guarded: Dictionary = _pure_query_guard.evaluate(
        Callable(self, "_resolve_unguarded").bind(request), participants)
    var purity_error := _purity_error(guarded)
    if purity_error != "":
        return _failure(request, purity_error)
    return guarded["value"]

func _resolve_unguarded(request):
    if not request is RequestScript:
        return _failure(null, "整数策略查询必须使用 PassiveIntQueryRequest")
    var runtime = _runtime_ref.get_ref()
    if runtime == null:
        return _failure(request, "被动规则运行时已释放")
    if not runtime.registry.has_hook(request.hook):
        return _failure(request, "未知被动 hook：%s" % request.hook)
    var context_values := {
        "owner": request.owner,
        "actor": request.actor,
        "target": request.target,
        "round_number": request.round_number,
        "hook": request.hook,
        "payload": {},
    }
    if request.has_source_snapshot:
        context_values["source_snapshot"] = request.source_snapshot
    var context = ContextScript.new().configure(context_values)
    var plan = runtime.build_execution_plan(request.hook, context)
    if not plan.is_valid():
        return _failure(request, "；".join(plan.errors))
    var current: int = int(request.base_value)
    var breakdown: Array = []
    for invocation in plan.invocations:
        var invocation_request = request.with_current_value(current)
        var invocation_context = context.for_invocation(invocation)
        invocation_context.payload = {
            "int_query": invocation_request,
            "base_value": request.base_value,
            "current_value": current,
            "metadata": request.metadata.duplicate(true),
        }
        if request is BattleRequestScript:
            invocation_context.payload.merge({
                "purpose": request.purpose,
                "evaluation_mode": request.evaluation_mode,
                "subject_card_facts": request.subject_card_facts.duplicate(true),
                "card_facts": request.card_facts.duplicate(true),
                "actual_played_count": request.actual_played_count,
                "exact_hand": request.exact_hand.duplicate(true),
                "damage_segment_token": request.damage_segment_token,
                "action_window_id": request.action_window_id,
                "source_id": request.source_id,
                "source_instance_key": request.source_instance_key,
                "trigger_mode": request.trigger_mode,
                "cause": request.cause,
                "damage_type": request.damage_type,
                "direct_attack": request.direct_attack,
                "reflection_damage": request.reflection_damage,
                "synchronized": request.synchronized,
                "requested_damage": request.requested_damage,
                "final_damage": request.final_damage,
                "defense_before": request.defense_before,
                "defense_lost": request.defense_lost,
                "defense_after": request.defense_after,
                "life_before": request.life_before,
                "proposed_life_loss": request.proposed_life_loss,
                "lethal": request.lethal,
            }, true)
        var executed: Dictionary = runtime.execute_invocation(
            invocation, invocation_context, "read")
        if not executed.get("success", false):
            return _failure(request, str(executed.get("reason", "整数策略执行失败")))
        var handler_result: Dictionary = executed["result"]
        if not handler_result.has("value") or not handler_result["value"] is int:
            return _failure(
                request,
                "%s · %s · %s：查询 Handler 必须返回确定整数 value" % [
                    request.hook,
                    invocation.source.source_instance_key,
                    invocation.source.behavior_id])
        var before: int = current
        current = int(handler_result["value"])
        breakdown.append({
            "source_kind": invocation.source.source_kind,
            "content_id": invocation.source.content_id,
            "source_instance_key": invocation.source.source_instance_key,
            "behavior_id": invocation.source.behavior_id,
            "execution_index": invocation.execution_index,
            "execution_count": invocation.execution_count,
            "before": before,
            "after": current,
        })
    return ResultScript.new().configure({
        "success": true,
        "hook": request.hook,
        "subject_kind": request.subject_kind,
        "subject_id": request.subject_id,
        "base_value": request.base_value,
        "effective_value": current,
        "modifier_breakdown": breakdown,
        "source_fingerprint": runtime.execution_plan_fingerprint(plan),
    })

func _failure(request, reason: String):
    return ResultScript.new().configure({
        "success": false,
        "hook": request.hook if request != null else "",
        "subject_kind": request.subject_kind if request != null else "",
        "subject_id": request.subject_id if request != null else "",
        "base_value": request.base_value if request != null else 0,
        "effective_value": request.base_value if request != null else 0,
        "errors": [reason],
    })

func _purity_error(report: Dictionary) -> String:
    var errors: Array[String] = []
    var restore_errors: Array = report.get("restore_errors", [])
    if not restore_errors.is_empty():
        errors.append("纯查询修改了本局状态且回滚失败：%s" % (
            "；".join(restore_errors)))
    elif bool(report.get("state_mutated", false)):
        errors.append("纯查询 Handler 不得修改本局状态")
    if bool(report.get("rng_advanced", false)):
        errors.append("纯查询 Handler 不得推进战斗 RNG")
    if bool(report.get("committed_event_sent", false)):
        errors.append("纯查询 Handler 不得发送 committed 事件")
    return "；".join(errors)
