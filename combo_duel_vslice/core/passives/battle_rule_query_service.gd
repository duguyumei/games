class_name BattleRuleQueryService
extends RefCounted

const RequestScript = preload(
    "res://core/passives/battle_passive_int_query_request.gd")
const ResultScript = preload(
    "res://core/passives/battle_passive_int_query_result.gd")
const ResolverScript = preload(
    "res://core/passives/passive_int_policy_resolver.gd")

const QUERY_HOOKS := [
    "hand_limit_query",
    "power_base_fixed_query",
    "power_multiplier_bonus_query",
    "power_fixed_query",
    "power_amp_percent_query",
    "outgoing_damage_query",
    "incoming_damage_query",
    "poison_defense_intervention_query",
    "defense_gain_query",
    "defense_retention_percent_query",
]

var _resolver
var _scenario_error: Callable

func _init(passive_runtime, scenario_error_callback: Callable = Callable()) -> void:
    _resolver = ResolverScript.new(passive_runtime)
    _scenario_error = scenario_error_callback

func resolve(request):
    if not request is RequestScript:
        return _failure(null, "战斗整数查询必须使用 BattlePassiveIntQueryRequest")
    if request.hook not in QUERY_HOOKS:
        return _failure(request, "不是正式战斗整数查询 Hook：%s" % request.hook)
    var observed: Array = _observed_sides(request)
    var before: Dictionary = {}
    for side in observed:
        before[str(side.owner_id)] = side.capture_passive_query_state()
    var resolved = _resolver.resolve(request)
    for side in observed:
        var owner_id := str(side.owner_id)
        var after: Dictionary = side.capture_passive_query_state()
        if after != before[owner_id]:
            side.replace_passive_query_state(before[owner_id])
            return _failure(request, "纯查询 Handler 不得修改战斗状态")
    if not resolved.success:
        return _failure(request, "；".join(resolved.errors))
    var values: Dictionary = resolved.to_dict()
    values["request_fingerprint"] = JSON.stringify({
        "hook": request.hook,
        "owner_id": str(request.owner.owner_id) if request.owner != null else "",
        "base_value": request.base_value,
        "round_number": request.round_number,
        "action_token": request.action_token,
        "hand_id": request.hand_id,
        "source_kind": request.source_kind,
        "card_facts": request.card_facts,
        "metadata": _stable_value(request.metadata),
        "source_fingerprint": resolved.source_fingerprint,
    }).sha256_text()
    return ResultScript.new().configure(values)

func resolve_values(values: Dictionary):
    return resolve(RequestScript.new().configure(values))

func _observed_sides(request) -> Array:
    var result: Array = []
    for side in [request.owner, request.actor, request.target]:
        if side != null and side.has_method("capture_passive_query_state") \
                and not result.has(side):
            result.append(side)
    return result

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

func report_failure(result, boundary: String) -> void:
    if result != null and not result.success and _scenario_error.is_valid():
        _scenario_error.call("战斗整数查询失败 boundary=%s hook=%s reason=%s" % [
            boundary, result.hook, "；".join(result.errors)])

func _stable_value(value):
    if value is Dictionary:
        var result: Dictionary = {}
        var keys: Array = value.keys()
        keys.sort_custom(func(left, right): return str(left) < str(right))
        for key in keys:
            result[str(key)] = _stable_value(value[key])
        return result
    if value is Array:
        return value.map(func(entry): return _stable_value(entry))
    if value == null or value is bool or value is int \
            or value is float or value is String:
        return value
    if value is Object and value.has_method("get_property_list"):
        for property in value.get_property_list():
            if str(property.get("name", "")) == "owner_id":
                return {"owner_id": str(value.get("owner_id"))}
    return str(value)
