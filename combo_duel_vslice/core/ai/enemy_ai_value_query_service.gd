class_name EnemyAiValueQueryService
extends RefCounted

const ContextScript = preload("res://core/passives/passive_rule_context.gd")
const CardStateProviderScript = preload(
    "res://core/ai/enemy_card_state_value_provider.gd")
const TechniqueSemanticProviderScript = preload(
    "res://core/ai/enemy_technique_semantic_value_provider.gd")

const HOOKS := [
    "ai_action_value_query",
    "ai_card_play_value_query",
    "ai_card_retention_value_query",
]

var _runtime_ref: WeakRef
var _providers: Array = []
var _serial: int = 0
var _unsupported_source_queries: Dictionary = {}

func _init(passive_runtime = null) -> void:
    _runtime_ref = weakref(passive_runtime) if passive_runtime != null else null
    register_provider(CardStateProviderScript.new(), "card_state_semantics", 100)
    register_provider(
        TechniqueSemanticProviderScript.new(), "technique_semantics", 110)

func register_provider(provider, source_id: String, order: int = 0) -> String:
    _providers.append({
        # Provider 由查询服务拥有；WeakRef 会让内建语义适配器在首帧前释放。
        "provider": provider,
        "source_id": source_id, "order": order, "serial": _serial,
    })
    _serial += 1
    _providers.sort_custom(func(left, right):
        if int(left["order"]) != int(right["order"]):
            return int(left["order"]) < int(right["order"])
        if str(left["source_id"]) != str(right["source_id"]):
            return str(left["source_id"]) < str(right["source_id"])
        return int(left["serial"]) < int(right["serial"]))
    return source_id

func query(hook: String, values: Dictionary) -> Dictionary:
    if hook not in HOOKS:
        return _failure("未知敌方 AI 估值 Hook：%s" % hook)
    var actor = values.get("actor", values.get("owner"))
    var target = values.get("target")
    var purity_guarded := bool(values.get("_purity_guarded", false))
    var observed := _observed_sides(actor, target) if not purity_guarded else []
    var before: Dictionary = {}
    for side in observed:
        before[str(side.owner_id)] = side.capture_passive_query_state()
    var total := _empty_result()
    var runtime_result := _query_runtime(hook, values)
    if not runtime_result.get("success", false):
        _restore(observed, before)
        return runtime_result
    _merge(total, runtime_result)
    for entry in _providers:
        var provider = entry["provider"]
        if provider is WeakRef:
            provider = provider.get_ref()
        if provider == null:
            _restore(observed, before)
            return _failure("AI 估值 Provider 已释放：%s" % entry["source_id"])
        var response = provider.query(hook, values)
        if not response is Dictionary or not bool(response.get("success", true)):
            _restore(observed, before)
            return _failure("%s：%s" % [
                entry["source_id"],
                str(response.get("reason", "查询失败")) if response is Dictionary else "必须返回对象"])
        _merge_entry(total, response, str(entry["source_id"]), "semantic_provider", "")
    for side in observed:
        if side.capture_passive_query_state() != before[str(side.owner_id)]:
            _restore(observed, before)
            return _failure("AI 估值纯查询不得修改战斗状态或推进 RNG")
    total["success"] = true
    return total

func _query_runtime(hook: String, values: Dictionary) -> Dictionary:
    var runtime = _runtime_ref.get_ref() if _runtime_ref != null else null
    var result := _empty_result()
    if runtime == null:
        result["success"] = true
        return result
    var actor = values.get("actor", values.get("owner"))
    if not _has_runtime_sources(runtime, hook, actor):
        result["success"] = true
        return result
    var context = ContextScript.new().configure({
        "owner": values.get("owner", actor),
        "actor": actor,
        "target": values.get("target"),
        "round_number": int(values.get("round_number", 0)),
        "payload": values.duplicate(false),
    })
    var plan = runtime.build_execution_plan(hook, context)
    if not plan.is_valid():
        return _failure("；".join(plan.errors))
    for invocation in plan.invocations:
        var executed: Dictionary = runtime.execute_invocation(invocation, null, "read")
        if not executed.get("success", false):
            return _failure(str(executed.get("reason", "AI 估值 Handler 失败")))
        _merge_entry(
            result,
            executed.get("result", {}),
            invocation.source.source_instance_key,
            invocation.source.source_kind,
            invocation.source.content_id)
    result["success"] = true
    return result

func _has_runtime_sources(runtime, hook: String, actor) -> bool:
    var equipped: Array = actor.equipped_inner_skill_ids if actor != null else []
    var items: Array = actor.item_ids if actor != null else []
    var key := "%s|%s|%s|%s" % [
        str(actor.owner_id) if actor != null else "", hook,
        JSON.stringify(equipped), JSON.stringify(items)]
    if _unsupported_source_queries.has(key):
        return false
    for source in runtime.collect_sources({"owner": actor}):
        var handler = runtime.registry.handler(source.behavior_id)
        if handler != null and handler.supported_hooks().has(hook):
            return true
    _unsupported_source_queries[key] = true
    return false

func _empty_result() -> Dictionary:
    return {
        "success": false,
        "estimated_value": 0.0,
        "progress_value": 0.0,
        "control_value": 0.0,
        "negative_card_cleanup_value": 0.0,
        "negative_retention_cost": 0.0,
        "trigger_signatures": [],
        "progress_entries": [],
        "source_breakdown": [],
        "errors": [],
    }

func _merge(target: Dictionary, source: Dictionary) -> void:
    for field in [
            "estimated_value", "progress_value", "control_value",
            "negative_card_cleanup_value", "negative_retention_cost"]:
        target[field] = float(target[field]) + float(source.get(field, 0.0))
    for field in ["trigger_signatures", "progress_entries", "source_breakdown"]:
        target[field].append_array(source.get(field, []))

func _merge_entry(
        target: Dictionary,
        response: Dictionary,
        source_id: String,
        source_kind: String,
        content_id: String) -> void:
    var entry := {
        "source_id": source_id,
        "source_kind": source_kind,
        "source_content_id": content_id,
        "estimated_value": float(response.get("estimated_value", 0.0)),
        "progress_value": float(response.get("progress_value", 0.0)),
        "control_value": float(response.get("control_value", 0.0)),
        "trigger_signatures": response.get("trigger_signatures", []).duplicate(),
    }
    target["source_breakdown"].append(entry)
    for field in [
            "estimated_value", "progress_value", "control_value",
            "negative_card_cleanup_value", "negative_retention_cost"]:
        target[field] = float(target[field]) + float(response.get(field, 0.0))
    target["trigger_signatures"].append_array(
        response.get("trigger_signatures", []))
    target["progress_entries"].append_array(
        response.get("progress_entries", []))

func _observed_sides(actor, target) -> Array:
    var result: Array = []
    for side in [actor, target]:
        if side != null and side.has_method("capture_passive_query_state") \
                and not result.has(side):
            result.append(side)
    return result

func _restore(sides: Array, snapshots: Dictionary) -> void:
    for side in sides:
        side.replace_passive_query_state(snapshots[str(side.owner_id)])

func _failure(reason: String) -> Dictionary:
    var result := _empty_result()
    result["errors"] = [reason]
    result["reason"] = reason
    return result
