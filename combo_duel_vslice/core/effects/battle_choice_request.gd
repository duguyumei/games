class_name BattleChoiceRequest
extends RefCounted

const INSUFFICIENT_POLICIES := ["use_available", "skip", "fail"]

var request_id: String = ""
var prompt: String = ""
var chooser: String = "actor"
var minimum: int = 0
var maximum: int = 0
var insufficient_policy: String = ""
var ordered: bool = false
var candidates: Array = []
var metadata: Dictionary = {}

func configure(values: Dictionary):
    request_id = str(values.get("request_id", ""))
    prompt = str(values.get("prompt", "请选择真气"))
    chooser = str(values.get("chooser", "actor"))
    minimum = int(values.get("minimum", 0))
    maximum = int(values.get("maximum", 0))
    insufficient_policy = str(values.get("insufficient_policy", ""))
    ordered = bool(values.get("ordered", false))
    candidates = values.get("candidates", []).duplicate()
    metadata = values.get("metadata", {}).duplicate(true)
    return self

func validate_definition() -> Dictionary:
    if request_id == "":
        return _invalid("选择请求缺少 request_id")
    if chooser not in ["actor", "target"]:
        return _invalid("选择请求 chooser 必须为 actor 或 target")
    if minimum < 0 or maximum < minimum:
        return _invalid("选择数量范围无效")
    if insufficient_policy not in INSUFFICIENT_POLICIES:
        return _invalid("选择请求必须明确合法的 insufficient_policy")
    var ids: Dictionary = {}
    for candidate in candidates:
        var candidate_id := _candidate_id(candidate)
        if candidate_id == "" or ids.has(candidate_id):
            return _invalid("选择候选包含空 ID 或重复实例")
        ids[candidate_id] = true
    return {"ok": true, "reason": ""}

func effective_limits() -> Dictionary:
    var candidate_count := candidates.size()
    if candidate_count >= minimum:
        return {"minimum": minimum, "maximum": mini(maximum, candidate_count)}
    match insufficient_policy:
        "use_available":
            return {"minimum": candidate_count, "maximum": candidate_count}
        "skip":
            return {"minimum": 0, "maximum": 0}
    return {"minimum": minimum, "maximum": mini(maximum, candidate_count)}

func requires_failure() -> bool:
    return insufficient_policy == "fail" and candidates.size() < minimum

func should_auto_resolve() -> bool:
    var limits := effective_limits()
    if ordered and int(limits["maximum"]) > 1:
        return false
    return int(limits["minimum"]) == int(limits["maximum"]) \
        and (
            int(limits["maximum"]) == 0 \
            or int(limits["maximum"]) == candidates.size())

func validate_selection(selected_ids: Array) -> Dictionary:
    var definition_check := validate_definition()
    if not definition_check["ok"]:
        return definition_check
    if requires_failure():
        return _invalid("合格目标不足：需要至少 %d，实际 %d" % [minimum, candidates.size()])
    var limits := effective_limits()
    if selected_ids.size() < int(limits["minimum"]) \
            or selected_ids.size() > int(limits["maximum"]):
        return _invalid("选择数量必须为 %d～%d" % [limits["minimum"], limits["maximum"]])
    var candidate_ids := candidate_ids()
    var seen: Dictionary = {}
    for selected_id_value in selected_ids:
        var selected_id := str(selected_id_value)
        if seen.has(selected_id):
            return _invalid("不能重复选择同一张真气")
        if not candidate_ids.has(selected_id):
            return _invalid("选择包含当前候选之外的真气：%s" % selected_id)
        seen[selected_id] = true
    return {"ok": true, "reason": ""}

func selected_cards(selected_ids: Array) -> Array:
    var by_id: Dictionary = {}
    for candidate in candidates:
        by_id[_candidate_id(candidate)] = candidate
    var result: Array = []
    for selected_id in selected_ids:
        if by_id.has(str(selected_id)):
            result.append(by_id[str(selected_id)])
    return result

func candidate_ids() -> Array[String]:
    var result: Array[String] = []
    for candidate in candidates:
        result.append(_candidate_id(candidate))
    return result

func snapshot() -> Dictionary:
    var limits := effective_limits()
    var candidate_snapshots: Array = []
    for candidate in candidates:
        candidate_snapshots.append(_candidate_snapshot(candidate))
    return {
        "request_id": request_id,
        "prompt": prompt,
        "chooser": chooser,
        "minimum": int(limits["minimum"]),
        "maximum": int(limits["maximum"]),
        "insufficient_policy": insufficient_policy,
        "ordered": ordered,
        "candidate_ids": candidate_ids(),
        "candidates": candidate_snapshots,
        "metadata": metadata.duplicate(true),
    }

func _invalid(reason: String) -> Dictionary:
    return {"ok": false, "reason": reason}

func _candidate_id(candidate) -> String:
    if candidate is Dictionary:
        return str(candidate.get("id", ""))
    if candidate != null:
        return str(candidate.id)
    return ""

func _candidate_snapshot(candidate) -> Dictionary:
    if candidate is Dictionary:
        return candidate.duplicate(true)
    if candidate != null and candidate.has_method("to_dict"):
        return candidate.to_dict()
    return {"id": _candidate_id(candidate)}
