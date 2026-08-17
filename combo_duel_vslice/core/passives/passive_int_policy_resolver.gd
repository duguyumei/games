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

var _runtime_ref: WeakRef

func _init(passive_runtime) -> void:
    _runtime_ref = weakref(passive_runtime)

func resolve(request):
    if not request is RequestScript:
        return _failure(null, "整数策略查询必须使用 PassiveIntQueryRequest")
    var runtime = _runtime_ref.get_ref()
    if runtime == null:
        return _failure(request, "被动规则运行时已释放")
    if not runtime.registry.has_hook(request.hook):
        return _failure(request, "未知被动 hook：%s" % request.hook)
    var owner_state: Dictionary = _capture_owner_state(request.owner)
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
    var purity_error := _restore_if_query_mutated(request.owner, owner_state)
    if purity_error != "":
        return _failure(request, purity_error)
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
            }, true)
        var executed: Dictionary = runtime.execute_invocation(
            invocation, invocation_context, "read")
        purity_error = _restore_if_query_mutated(request.owner, owner_state)
        if purity_error != "":
            return _failure(request, purity_error)
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

func _restore_if_query_mutated(owner, state_before: Dictionary) -> String:
    if owner == null or state_before.is_empty():
        return ""
    var state_kind := str(state_before.get("kind", ""))
    var snapshot: Dictionary = state_before.get("state", {})
    var current: Dictionary = {}
    if state_kind == "run" and owner.has_method("capture_mutation_state"):
        current = owner.capture_mutation_state()
    elif state_kind == "battle" \
            and owner.has_method("capture_passive_query_state"):
        current = owner.capture_passive_query_state()
    else:
        return ""
    if current == snapshot:
        return ""
    if state_kind == "run":
        var restore_errors: Array[String] = owner.replace_mutation_state(snapshot)
        if not restore_errors.is_empty():
            return "纯查询修改了本局状态且回滚失败：%s" % "；".join(restore_errors)
    else:
        owner.replace_passive_query_state(snapshot)
    return "纯查询 Handler 不得修改本局状态"

func _capture_owner_state(owner) -> Dictionary:
    if owner == null:
        return {}
    if owner.has_method("capture_mutation_state"):
        return {"kind": "run", "state": owner.capture_mutation_state()}
    if owner.has_method("capture_passive_query_state"):
        return {"kind": "battle", "state": owner.capture_passive_query_state()}
    return {}
