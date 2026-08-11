class_name BattlePermissionService
extends RefCounted

const ResultScript = preload("res://core/passives/battle_permission_result.gd")
const ContextScript = preload("res://core/passives/passive_rule_context.gd")

const QUERY_HOOKS := [
    "card_play_permission_query",
    "explicit_discard_permission_query",
    "technique_activation_permission_query",
    "cooperation_permission_query",
]

var _runtime_ref: WeakRef
var _providers: Array = []
var _serial: int = 0

func _init(passive_runtime = null) -> void:
    _runtime_ref = weakref(passive_runtime) if passive_runtime != null else null

func register_provider(provider, source_id: String = "", order: int = 0, hooks: Array = []) -> String:
    var stable_id := source_id if source_id != "" else "provider:%06d" % _serial
    _providers.append({
        "provider": weakref(provider) if provider is Object and not provider is Callable else provider,
        "source_id": stable_id, "order": order,
        "serial": _serial, "hooks": hooks.duplicate(),
    })
    _serial += 1
    _providers.sort_custom(func(left, right):
        if int(left["order"]) != int(right["order"]):
            return int(left["order"]) < int(right["order"])
        if str(left["source_id"]) != str(right["source_id"]):
            return str(left["source_id"]) < str(right["source_id"])
        return int(left["serial"]) < int(right["serial"]))
    return stable_id

func unregister_provider(source_id: String) -> bool:
    for index in range(_providers.size()):
        if str(_providers[index]["source_id"]) == source_id:
            _providers.remove_at(index)
            return true
    return false

func query(hook: String, context: Dictionary = {}):
    if hook not in QUERY_HOOKS:
        return _denied("未知权限 Hook：%s" % hook, [], ["unknown_hook"])
    var breakdown: Array = []
    var owner = context.get("owner", context.get("actor"))
    var state_before: Dictionary = owner.capture_passive_query_state() \
        if owner != null and owner.has_method("capture_passive_query_state") else {}
    var runtime_entries := _runtime_entries(hook, context)
    var purity_error := _restore_if_mutated(owner, state_before)
    if purity_error != "":
        return _denied(purity_error, breakdown, ["query_mutation"])
    if not runtime_entries.get("success", false):
        return _denied(str(runtime_entries.get("reason", "权限查询失败")), breakdown, ["query_failure"])
    for entry in runtime_entries.get("entries", []):
        breakdown.append(entry)
        if not bool(entry.get("allowed", false)):
            return _denied(str(entry.get("reason", "操作被拒绝")), breakdown)
    for source in _providers:
        var hooks: Array = source["hooks"]
        if not hooks.is_empty() and hook not in hooks:
            continue
        var response := _call_provider(source["provider"], hook, context)
        purity_error = _restore_if_mutated(owner, state_before)
        if purity_error != "":
            return _denied(purity_error, breakdown, ["query_mutation"])
        if not response.get("success", false):
            breakdown.append({
                "source_id": source["source_id"], "allowed": false,
                "reason": str(response.get("reason", "权限查询失败")), "query_failed": true,
            })
            return _denied(str(response.get("reason", "权限查询失败")), breakdown, ["query_failure"])
        var entry := {
            "source_id": source["source_id"],
            "allowed": bool(response["allowed"]),
            "reason": str(response.get("reason", "")),
        }
        breakdown.append(entry)
        if not entry["allowed"]:
            return _denied(entry["reason"] if entry["reason"] != "" else "操作被拒绝", breakdown)
    return ResultScript.new().configure({"allowed": true, "source_breakdown": breakdown})

func can_play_card(owner, card, context: Dictionary = {}) -> Dictionary:
    var values := context.duplicate(false)
    values.merge({"owner": owner, "actor": owner, "card": card}, false)
    return query("card_play_permission_query", values).to_dict()

func can_explicit_discard(owner, card, context: Dictionary = {}) -> Dictionary:
    var values := context.duplicate(false)
    values.merge({"owner": owner, "actor": owner, "card": card}, false)
    return query("explicit_discard_permission_query", values).to_dict()

func check(hook: String, context: Dictionary = {}) -> Dictionary:
    return query(hook, context).to_dict()

func card_play_permission(owner, card, context: Dictionary = {}) -> Dictionary:
    return can_play_card(owner, card, context)

func explicit_discard_permission(owner, card, context: Dictionary = {}) -> Dictionary:
    return can_explicit_discard(owner, card, context)

func _runtime_entries(hook: String, context: Dictionary) -> Dictionary:
    var runtime = _runtime_ref.get_ref() if _runtime_ref != null else null
    if runtime == null:
        return {"success": true, "entries": []}
    var owner = context.get("owner", context.get("actor"))
    var rule_context = ContextScript.new().configure({
        "owner": owner, "actor": context.get("actor", owner),
        "target": context.get("target"),
        "round_number": int(context.get("round_number", 0)),
        "payload": context.duplicate(false),
    })
    var plan = runtime.build_execution_plan(hook, rule_context)
    if not plan.is_valid():
        return {"success": false, "reason": "；".join(plan.errors)}
    var entries: Array = []
    for invocation in plan.invocations:
        var executed: Dictionary = runtime.execute_invocation(invocation, null, "read")
        if not executed.get("success", false):
            return {"success": false, "reason": executed.get("reason", "权限查询失败")}
        var result: Dictionary = executed["result"]
        if not result.has("allowed") or not result["allowed"] is bool:
            return {"success": false, "reason": "权限 Handler 必须返回布尔 allowed"}
        entries.append({
            "source_id": invocation.source.source_instance_key,
            "allowed": result["allowed"],
            "reason": str(result.get("reason", "")),
        })
    return {"success": true, "entries": entries}

func _call_provider(provider, hook: String, context: Dictionary) -> Dictionary:
    if provider is WeakRef:
        provider = provider.get_ref()
        if provider == null:
            return {"success": false, "reason": "权限 Provider 已释放"}
    var value = null
    if provider is Callable:
        value = provider.call(hook, context)
    elif provider != null and provider.has_method("query_permission"):
        value = provider.query_permission(hook, context)
    elif provider != null and provider.has_method("permission_query"):
        value = provider.permission_query(hook, context)
    elif provider != null and provider.has_method("query"):
        value = provider.query(hook, context)
    elif provider != null and hook == "card_play_permission_query" \
            and provider.has_method("can_play_card"):
        value = provider.can_play_card(context.get("owner"), context.get("card"))
    elif provider != null and hook == "explicit_discard_permission_query" \
            and provider.has_method("can_explicit_discard"):
        value = provider.can_explicit_discard(context.get("owner"), context.get("card"))
    if not value is Dictionary:
        return {"success": false, "reason": "权限 Provider 必须返回对象"}
    if value.has("success") and not bool(value["success"]):
        return {"success": false, "reason": str(value.get("reason", "权限查询失败"))}
    if not value.has("allowed") or not value["allowed"] is bool:
        return {"success": false, "reason": "权限 Provider 必须返回布尔 allowed"}
    return {"success": true, "allowed": value["allowed"], "reason": str(value.get("reason", ""))}

func _denied(reason: String, breakdown: Array, errors: Array = []):
    return ResultScript.new().configure({
        "allowed": false, "reason": reason,
        "source_breakdown": breakdown, "errors": errors,
    })

func _restore_if_mutated(owner, before: Dictionary) -> String:
    if owner == null or before.is_empty() \
            or not owner.has_method("capture_passive_query_state"):
        return ""
    if owner.capture_passive_query_state() == before:
        return ""
    owner.replace_passive_query_state(before)
    return "权限查询 Handler 不得修改战斗状态"
