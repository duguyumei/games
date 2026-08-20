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

func capture_transaction_state() -> Dictionary:
    return {
        "receipts": _receipts.duplicate(true),
        "battle_flow": _battle_flow.capture_transaction_state() \
            if _battle_flow != null and _battle_flow.has_method(
                "capture_transaction_state") else {},
    }

func restore_transaction_state(state: Dictionary) -> void:
    _receipts = state.get("receipts", {}).duplicate(true)
    if _battle_flow != null and _battle_flow.has_method(
            "restore_transaction_state"):
        _battle_flow.restore_transaction_state(state.get("battle_flow", {}))

func receipts_for_action(side, action_token: String) -> Array:
    var result: Array = []
    if side == null or action_token == "":
        return result
    for receipt_value in _receipts.values():
        var receipt: Dictionary = receipt_value
        if str(receipt.get("side", "")) != str(side.owner_id):
            continue
        var receipt_action_token := str(receipt.get("action_token", ""))
        if receipt_action_token == action_token \
                or receipt_action_token.begins_with(action_token + ":"):
            result.append(receipt.duplicate(true))
    result.sort_custom(func(left, right):
        return str(left.get("write_token", "")) < str(right.get("write_token", "")))
    return result

func capacity_result(
        side,
        context: Dictionary = {},
        record_query_result: bool = true) -> Dictionary:
    if side == null:
        return _failure("同气容量查询缺少战斗方")
    var resolved: Dictionary = (
        side.effective_same_qi_capacity_result(context)
        if record_query_result
        else side.peek_effective_same_qi_capacity_result(context))
    if not resolved.get("success", false):
        return resolved
    resolved["effective_value"] = maxi(1, int(resolved["effective_value"]))
    return resolved

func project_gain(side, amount: int, context: Dictionary = {}) -> Dictionary:
    return project_write(side, "add", amount, context)

func project_write(
        side,
        operation: String,
        amount: int = 0,
        context: Dictionary = {}) -> Dictionary:
    return _project_write(side, operation, amount, context, false)

func _project_write(
        side,
        operation: String,
        amount: int,
        context: Dictionary,
        record_query_result: bool) -> Dictionary:
    var capacity_query := capacity_result(
        side, context, record_query_result)
    if not capacity_query.get("success", false):
        return capacity_query
    var capacity := int(capacity_query["effective_value"])
    var before := maxi(0, int(side.same_qi_value))
    var raw_after := before
    match operation:
        "add": raw_after = maxi(0, before + amount)
        "set": raw_after = maxi(0, amount)
        "clear": raw_after = 0
        _:
            return _failure("未知同气写入操作：%s" % operation)
    var can_continue := bool(context.get(
        "legal_card_available", _has_legal_card(side)))
    if not can_continue and _battle_flow != null \
            and _battle_flow.has_method("can_establish_extra_action"):
        can_continue = _battle_flow.can_establish_extra_action(side, {
            "category": "same_qi",
            "source": str(context.get("source", "同气槽")),
            "source_category": str(context.get(
                "source_category", "same_qi")),
            "action_token": str(context.get("action_token", "")),
            "from_same_qi": true,
            "is_extra_action": true,
        }, false)
    var trigger_count := int(floor(float(raw_after) / float(capacity))) \
        if raw_after > before and can_continue else 0
    var spent := trigger_count * capacity
    return {
        "success": true,
        "operation": operation,
        "requested": amount,
        "before": before,
        "after": raw_after - spent,
        "changed": raw_after - spent != before,
        "same_qi_gain": raw_after - before,
        "same_qi_before": before,
        "same_qi_capacity": capacity,
        "effective_capacity": capacity,
        "same_qi_after": raw_after - spent,
        "same_qi_trigger_count": trigger_count,
        "conversion_count": trigger_count,
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
    return apply_write(side, "add", amount, source, token, {
        "source_category": "same_qi" if source == "同气槽" else "effect",
    })

func apply_write(
        side,
        operation: String,
        amount: int,
        source: String,
        token: String,
        metadata: Dictionary = {}) -> Dictionary:
    if side == null:
        return _failure("同气写入缺少战斗方")
    if token == "":
        return _failure("同气写入必须提供稳定 token")
    var receipt_key := "%s|%s" % [str(side.owner_id), token]
    if _receipts.has(receipt_key):
        var reused: Dictionary = _receipts[receipt_key].duplicate(true)
        reused["reused"] = true
        return reused
    var projection := _project_write(
        side, operation, amount, metadata, true)
    if not projection.get("success", false):
        return projection
    side.same_qi_value = int(projection["same_qi_after"])
    var granted := 0
    var source_category := str(metadata.get(
        "source_category", "same_qi" if source == "同气槽" else "effect"))
    var extra_action_sources: Array = []
    if _battle_flow != null and int(projection["same_qi_trigger_count"]) > 0:
        granted = int(_battle_flow.grant_actions(
            side, int(projection["same_qi_trigger_count"]), {
                "category": "same_qi",
                "source": source,
                "source_category": source_category,
                "action_token": str(metadata.get("action_token", token)),
                "from_same_qi": true,
            }))
        for index in range(granted):
            extra_action_sources.append({
                "category": "same_qi",
                "source": source,
                "source_category": source_category,
                "action_token": str(metadata.get("action_token", token)),
                "ordinal": index,
            })
    var resolved_action_token := str(metadata.get("action_token", token))
    var result := projection.duplicate(true)
    result.merge({
        "side": str(side.owner_id),
        "gained": int(projection.get("same_qi_gain", 0)),
        "granted_actions": granted,
        "source": source,
        "source_category": source_category,
        "action_token": resolved_action_token,
        "write_token": token,
        "extra_action_source": "same_qi" if granted > 0 else "",
        "extra_action_sources": extra_action_sources,
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
