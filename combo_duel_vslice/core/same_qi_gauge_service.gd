class_name SameQiGaugeService
extends RefCounted

## 双方同气槽的唯一状态服务。预估只读，正式写入以稳定 token 幂等。

const BASE_CAPACITY := 5

var _battle_flow
var _receipts: Dictionary = {}

func _init(flow = null) -> void:
    _battle_flow = flow

func reset() -> void:
    _receipts.clear()

func capacity_result(side, context: Dictionary = {}) -> Dictionary:
    if side == null:
        return _failure("同气容量查询缺少战斗方")
    var resolved: Dictionary = side.effective_same_qi_capacity_result(context)
    if not resolved.get("success", false):
        return resolved
    resolved["effective_value"] = maxi(1, int(resolved["effective_value"]))
    return resolved

func project_gain(side, amount: int, context: Dictionary = {}) -> Dictionary:
    var capacity_query := capacity_result(side, context)
    if not capacity_query.get("success", false):
        return capacity_query
    var capacity := int(capacity_query["effective_value"])
    var before := maxi(0, int(side.same_qi_value))
    var raw_after := maxi(0, before + amount)
    var can_continue := bool(context.get(
        "legal_card_available", _has_legal_card(side)))
    var trigger_count := int(floor(float(raw_after) / float(capacity))) \
        if amount >= 0 and can_continue else 0
    var spent := trigger_count * capacity
    return {
        "success": true,
        "same_qi_gain": amount,
        "same_qi_before": before,
        "same_qi_capacity": capacity,
        "same_qi_after": raw_after - spent,
        "same_qi_trigger_count": trigger_count,
        "spent": spent,
        "legal_card_available": can_continue,
        "capacity_query": capacity_query.duplicate(true),
        "reason": "",
        "errors": [],
    }

func apply_gain(
        side,
        amount: int,
        source: String,
        token: String) -> Dictionary:
    if side == null:
        return _failure("同气写入缺少战斗方")
    if token == "":
        return _failure("同气写入必须提供稳定 token")
    var receipt_key := "%s|%s" % [str(side.owner_id), token]
    if _receipts.has(receipt_key):
        var reused: Dictionary = _receipts[receipt_key].duplicate(true)
        reused["reused"] = true
        return reused
    var projection := project_gain(side, amount)
    if not projection.get("success", false):
        return projection
    side.same_qi_value = int(projection["same_qi_after"])
    var granted := 0
    if _battle_flow != null and int(projection["same_qi_trigger_count"]) > 0:
        granted = int(_battle_flow.grant_actions(
            side, int(projection["same_qi_trigger_count"])))
    var result := projection.duplicate(true)
    result.merge({
        "side": str(side.owner_id),
        "gained": amount,
        "granted_actions": granted,
        "source": source,
        "action_token": token,
        "reused": false,
    }, true)
    _receipts[receipt_key] = result.duplicate(true)
    return result

func _has_legal_card(side) -> bool:
    for card in side.hand:
        if card.has_method("is_card_kind") and not card.is_card_kind("normal"):
            continue
        if side.status_system == null:
            return true
        var permission: Dictionary = side.status_system.can_play_card(side, card)
        if bool(permission.get("allowed", false)):
            return true
    return false

func _failure(reason: String) -> Dictionary:
    return {
        "success": false,
        "reason": reason,
        "errors": [reason],
    }
