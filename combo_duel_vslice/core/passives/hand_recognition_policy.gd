class_name HandRecognitionPolicy
extends RefCounted

const OptionsScript = preload("res://core/passives/hand_recognition_options.gd")
const ContextScript = preload("res://core/passives/passive_rule_context.gd")
const PureQueryGuardScript = preload(
    "res://core/passives/battle_pure_query_guard.gd")

var _runtime_ref: WeakRef
var _providers: Array = []
var _serial: int = 0
var _pure_query_guard

func _init(passive_runtime = null, pure_query_guard = null) -> void:
    _runtime_ref = weakref(passive_runtime) if passive_runtime != null else null
    _pure_query_guard = pure_query_guard \
        if pure_query_guard != null else PureQueryGuardScript.new()

func use_pure_query_guard(guard) -> void:
    _pure_query_guard = guard if guard != null else PureQueryGuardScript.new()

func register_provider(provider, source_id: String = "", order: int = 0) -> String:
    var stable_id := source_id if source_id != "" else "provider:%06d" % _serial
    _providers.append({
        "provider": weakref(provider) if provider is Object and not provider is Callable else provider,
        "source_id": stable_id,
        "order": order,
        "serial": _serial,
    })
    _serial += 1
    _sort_providers()
    return stable_id

func unregister_provider(source_id: String) -> bool:
    for index in range(_providers.size()):
        if str(_providers[index]["source_id"]) == source_id:
            _providers.remove_at(index)
            return true
    return false

func resolve_options(owner = null, context: Dictionary = {}) -> Dictionary:
    var participants: Array = [owner] if owner != null \
        and owner.has_method("capture_transaction_state") else []
    var guarded: Dictionary = _pure_query_guard.evaluate(
        Callable(self, "_resolve_options_unguarded").bind(owner, context),
        participants)
    var purity_error := _purity_error(guarded)
    if purity_error != "":
        return _failure(OptionsScript.new().configure(), purity_error, [])
    return guarded["value"]

func _resolve_options_unguarded(
        owner = null,
        context: Dictionary = {}) -> Dictionary:
    var options = OptionsScript.new().configure()
    var breakdown: Array = []
    var runtime_result := _runtime_modifiers(owner, context)
    if not runtime_result.get("success", false):
        return _failure(options, str(runtime_result.get("reason", "牌型识别查询失败")), breakdown)
    for entry in runtime_result.get("entries", []):
        var merged := _merge(options, entry.get("value", {}))
        if not merged.get("success", false):
            return _failure(options, str(merged.get("reason", "牌型识别选项无效")), breakdown)
        breakdown.append(entry)
    for entry in _providers:
        var response := _call_provider(entry["provider"], owner, context)
        if not response.get("success", false):
            return _failure(options, "%s：%s" % [entry["source_id"], response.get("reason", "查询失败")], breakdown)
        var merged := _merge(options, response.get("value", {}))
        if not merged.get("success", false):
            return _failure(options, "%s：%s" % [entry["source_id"], merged.get("reason", "选项无效")], breakdown)
        breakdown.append({"source_id": entry["source_id"], "value": response["value"].duplicate(true)})
    return {
        "success": true,
        "options": options,
        "source_breakdown": breakdown,
        "errors": [],
    }

func resolve(owner = null, context: Dictionary = {}) -> Dictionary:
    return resolve_options(owner, context)

func _runtime_modifiers(owner, context: Dictionary) -> Dictionary:
    var runtime = _runtime_ref.get_ref() if _runtime_ref != null else null
    if runtime == null:
        return {"success": true, "entries": []}
    var values := {
        "owner": owner,
        "actor": context.get("actor", owner),
        "target": context.get("target"),
        "round_number": int(context.get("round_number", 0)),
        "payload": context.duplicate(false),
    }
    var plan = runtime.build_execution_plan(
        "hand_evaluation_options_query", ContextScript.new().configure(values))
    if not plan.is_valid():
        return {"success": false, "reason": "；".join(plan.errors)}
    var entries: Array = []
    for invocation in plan.invocations:
        var executed: Dictionary = runtime.execute_invocation(invocation, null, "read")
        if not executed.get("success", false):
            return {"success": false, "reason": executed.get("reason", "查询失败")}
        var result: Dictionary = executed["result"]
        var value = result.get("options", result)
        if not value is Dictionary:
            return {"success": false, "reason": "牌型识别 Handler 必须返回 options 对象"}
        entries.append({
            "source_id": invocation.source.source_instance_key,
            "value": value.duplicate(true),
        })
    return {"success": true, "entries": entries}

func _call_provider(provider, owner, context: Dictionary) -> Dictionary:
    if provider is WeakRef:
        provider = provider.get_ref()
        if provider == null:
            return {"success": false, "reason": "Provider 已释放"}
    var value = null
    if provider is Callable:
        value = provider.call(owner, context)
    elif provider != null and provider.has_method("resolve_options"):
        value = provider.resolve_options(owner, context)
    elif provider != null and provider.has_method("query"):
        value = provider.query("hand_evaluation_options_query", owner, context)
    if not value is Dictionary:
        return {"success": false, "reason": "Provider 必须返回对象"}
    if value.has("success") and not bool(value["success"]):
        return {"success": false, "reason": str(value.get("reason", "查询失败"))}
    var options_value = value.get("options", value)
    if not options_value is Dictionary:
        return {"success": false, "reason": "Provider 的 options 必须是对象"}
    return {"success": true, "value": options_value}

func _merge(options, values: Dictionary) -> Dictionary:
    var next: Dictionary = options.to_dict()
    for field in [
            "straight_allowed_sizes", "straight_max_step",
            "ace_low_allowed", "ace_high_allowed"]:
        if values.has(field):
            next[field] = values[field]
    options.configure(next)
    return {"success": true}

func _failure(options, reason: String, breakdown: Array) -> Dictionary:
    return {
        "success": false,
        "options": options,
        "source_breakdown": breakdown,
        "errors": [reason],
        "reason": reason,
    }

func _purity_error(report: Dictionary) -> String:
    var errors: Array[String] = []
    if bool(report.get("state_mutated", false)):
        errors.append("纯查询 Handler 不得修改战斗状态")
    if bool(report.get("rng_advanced", false)):
        errors.append("纯查询 Handler 不得推进战斗 RNG")
    if bool(report.get("committed_event_sent", false)):
        errors.append("纯查询 Handler 不得发送 committed 事件")
    var restore_errors: Array = report.get("restore_errors", [])
    if not restore_errors.is_empty():
        errors.append("牌型识别查询状态回滚失败：%s" % "；".join(
            restore_errors))
    return "；".join(errors)

func _sort_providers() -> void:
    _providers.sort_custom(func(left, right):
        if int(left["order"]) != int(right["order"]):
            return int(left["order"]) < int(right["order"])
        if str(left["source_id"]) != str(right["source_id"]):
            return str(left["source_id"]) < str(right["source_id"])
        return int(left["serial"]) < int(right["serial"]))
