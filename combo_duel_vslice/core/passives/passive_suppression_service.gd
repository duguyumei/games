class_name PassiveSuppressionService
extends RefCounted

const SuppressionScript = preload("res://core/passives/passive_suppression.gd")

var _suppressions: Dictionary = {}

func apply(values: Dictionary) -> Dictionary:
    var suppression = SuppressionScript.new()
    suppression.configure(values)
    if suppression.suppression_id == "":
        return {"success": false, "reason": "suppression_id 不能为空"}
    if _suppressions.has(suppression.suppression_id):
        return {
            "success": false,
            "reason": "suppression_id 已存在：%s" % suppression.suppression_id,
        }
    if suppression.target_source_kind not in ["", "inner_skill", "item"]:
        return {"success": false, "reason": "未知压制目标来源类型"}
    _suppressions[suppression.suppression_id] = suppression
    return {"success": true, "suppression_id": suppression.suppression_id}

func remove(suppression_id: String) -> bool:
    return _suppressions.erase(suppression_id)

func blockers_for(source, hook: String, round_number: int = 0) -> Array:
    purge_expired(round_number)
    var result: Array = []
    for id in _suppressions:
        var suppression = _suppressions[id]
        if suppression.blocks(source, hook, round_number):
            result.append(suppression)
    result.sort_custom(func(left, right):
        return left.suppression_id < right.suppression_id)
    return result

func purge_expired(round_number: int) -> void:
    var expired: Array[String] = []
    for id in _suppressions:
        if _suppressions[id].is_expired(round_number):
            expired.append(str(id))
    for id in expired:
        _suppressions.erase(id)

func clear() -> void:
    _suppressions.clear()

func snapshot() -> Array:
    var result: Array = []
    for id in _suppressions:
        var value = _suppressions[id]
        result.append({
            "suppression_id": value.suppression_id,
            "target_source_kind": value.target_source_kind,
            "target_content_id": value.target_content_id,
            "target_instance_key": value.target_instance_key,
            "blocked_hooks": value.blocked_hooks.duplicate(),
            "reason": value.reason,
            "source_id": value.source_id,
            "expiry": value.expiry.duplicate(true),
        })
    result.sort_custom(func(left, right):
        return str(left["suppression_id"]) < str(right["suppression_id"]))
    return result
