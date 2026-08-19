class_name DefenseRetentionPolicy
extends RefCounted

## 完整回合结束时的防御保留规则。
##
## 提供者必须是 Callable，或实现：
## `defense_retention_modifier(side, context) -> Dictionary`。
## 返回值可包含 `additional_retention_percent`，或用
## `prevent_decay = true` 覆盖为完全保留。提供者自行判断影响哪一方，策略层不识别
## 任何功法、物品或其他内容 ID。

const DEFAULT_RETENTION_PERCENT := 50
const PROVIDER_METHOD := "defense_retention_modifier"

var _providers: Array[Dictionary] = []
var _battle_rule_query_service = null
var _remove_defense_port: Callable

func use_battle_rule_query_service(service) -> void:
    _battle_rule_query_service = service

func use_remove_defense_port(port: Callable) -> void:
    _remove_defense_port = port

func register_provider(provider_id: String, provider) -> bool:
    if provider_id == "" or not _is_valid_provider(provider):
        return false
    for entry in _providers:
        if str(entry["id"]) == provider_id:
            return false
    _providers.append({
        "id": provider_id,
        "provider": provider,
    })
    return true

func unregister_provider(provider_id: String) -> bool:
    for index in range(_providers.size()):
        if str(_providers[index]["id"]) != provider_id:
            continue
        _providers.remove_at(index)
        return true
    return false

func clear_providers() -> void:
    _providers.clear()

func registered_provider_ids() -> Array[String]:
    var ids: Array[String] = []
    for entry in _providers:
        ids.append(str(entry["id"]))
    return ids

func resolve_retention(side, context: Dictionary = {}) -> Dictionary:
    var retention_percent := DEFAULT_RETENTION_PERCENT
    var prevented := false
    var modifiers: Array[Dictionary] = []
    for source in side.defense_retention_sources:
        var source_percent := int(source.get("additional_percent", 0))
        var source_prevents := bool(source.get("prevent_decay", false))
        retention_percent += source_percent
        prevented = prevented or source_prevents
        modifiers.append({
            "provider_id": str(source.get("source_token", "")),
            "additional_retention_percent": source_percent,
            "prevent_decay": source_prevents,
        })
    for entry in _providers:
        var modifier := _resolve_provider(entry["provider"], side, context)
        if modifier.is_empty():
            continue
        var additional_percent := int(
            modifier.get("additional_retention_percent", 0))
        var prevents_decay := bool(modifier.get("prevent_decay", false))
        retention_percent += additional_percent
        prevented = prevented or prevents_decay
        modifiers.append({
            "provider_id": str(entry["id"]),
            "additional_retention_percent": additional_percent,
            "prevent_decay": prevents_decay,
        })
    retention_percent = (
        100
        if prevented
        else clampi(retention_percent, 0, 100))
    var query_result: Dictionary = {}
    if _battle_rule_query_service != null:
        var query = _battle_rule_query_service.resolve_values({
            "hook": "defense_retention_percent_query",
            "owner": side, "actor": side,
            "subject_kind": "defense_retention",
            "subject_id": str(side.owner_id),
            "base_value": retention_percent,
            "round_number": int(context.get("round_number", 0)),
            "source_kind": "round_end_decay",
            "metadata": context,
        })
        query_result = query.to_dict()
        if not query.success:
            _battle_rule_query_service.report_failure(query, "defense_retention")
            return {
                "success": false, "side": side,
                "side_id": _side_id(side),
                "retention_percent": retention_percent,
                "prevented": prevented, "modifiers": modifiers,
                "query": query_result, "errors": query.errors.duplicate(),
            }
        retention_percent = clampi(query.effective_value, 0, 100)
        prevented = retention_percent == 100
    return {
        "success": true,
        "side": side,
        "side_id": _side_id(side),
        "retention_percent": retention_percent,
        "prevented": prevented,
        "modifiers": modifiers,
        "query": query_result,
    }

## 纯计算一次自然防御衰减。三个整数查询全部成功前不写防御、不发送事件。
func plan_decay(side, context: Dictionary = {}) -> Dictionary:
    var retention := resolve_retention(side, context)
    var before := maxi(0, int(side.defense))
    if not retention.get("success", false):
        return _failed_plan(side, before, retention)
    var retention_percent := int(retention["retention_percent"])
    var proportional_after := clampi(
        int(floor(float(before) * float(retention_percent) / 100.0)),
        0,
        before)
    var proposed_loss := before - proportional_after
    var loss_cap_query := _resolve_decay_query(
        "defense_decay_max_loss_query", side, proposed_loss, context, {
            "before": before,
            "retention_percent": retention_percent,
            "proportional_after": proportional_after,
            "proposed_loss": proposed_loss,
        })
    if not loss_cap_query.get("success", false):
        var failed_loss_cap := _failed_plan(
            side, before, retention, loss_cap_query)
        failed_loss_cap.merge({
            "proportional_after": proportional_after,
            "proposed_loss": proposed_loss,
            "after_cap": before,
            "final_after": before,
        }, true)
        return failed_loss_cap
    var queried_max_loss := clampi(
        int(loss_cap_query.get("effective_value", proposed_loss)),
        0,
        proposed_loss)
    var capped_loss := mini(proposed_loss, queried_max_loss)
    var after_cap := before - capped_loss
    var minimum_remaining_query := _resolve_decay_query(
        "defense_decay_minimum_remaining_query", side, 0, context, {
            "before": before,
            "retention_percent": retention_percent,
            "proportional_after": proportional_after,
            "proposed_loss": proposed_loss,
            "queried_max_loss": queried_max_loss,
            "capped_loss": capped_loss,
            "after_cap": after_cap,
        })
    if not minimum_remaining_query.get("success", false):
        var failed_minimum := _failed_plan(
            side, before, retention, loss_cap_query,
            minimum_remaining_query)
        failed_minimum.merge({
            "proportional_after": proportional_after,
            "proposed_loss": proposed_loss,
            "queried_max_loss": queried_max_loss,
            "capped_loss": capped_loss,
            "after_cap": after_cap,
            "final_after": before,
        }, true)
        return failed_minimum
    var queried_minimum_remaining := clampi(
        int(minimum_remaining_query.get("effective_value", 0)), 0, before)
    var final_after := clampi(
        maxi(after_cap, queried_minimum_remaining), 0, before)
    var lost := before - final_after
    return {
        "success": true,
        "side": side,
        "side_id": retention["side_id"],
        "before": before,
        "after": final_after,
        "lost": lost,
        "retention_percent": retention_percent,
        "prevented": bool(retention["prevented"]),
        "modifiers": retention["modifiers"].duplicate(true),
        "query": retention.get("query", {}).duplicate(true),
        "retention_query": retention.get("query", {}).duplicate(true),
        "proportional_after": proportional_after,
        "proposed_loss": proposed_loss,
        "queried_max_loss": queried_max_loss,
        "capped_loss": capped_loss,
        "after_cap": after_cap,
        "queried_minimum_remaining": queried_minimum_remaining,
        "final_after": final_after,
        "loss_cap_query": loss_cap_query.duplicate(true),
        "minimum_remaining_query": minimum_remaining_query.duplicate(true),
        "errors": [],
    }

## 保留公开兼容入口；提交阶段只调用注入的统一防御减少端口。
func apply_decay(side, context: Dictionary = {}) -> Dictionary:
    var plan: Dictionary = plan_decay(side, context)
    if not plan.get("success", false) or int(plan.get("lost", 0)) <= 0:
        return plan
    if not _remove_defense_port.is_valid():
        var missing := plan.duplicate(true)
        missing["success"] = false
        missing["after"] = int(plan["before"])
        missing["lost"] = 0
        missing["errors"] = ["自然防御衰减未装配统一防御减少端口"]
        return missing
    var round_number := int(context.get("round_number", 0))
    var action_token := str(context.get(
        "action_token", "defense-decay:%d:%s" % [
            round_number, _side_id(side)]))
    var committed = _remove_defense_port.call(side, int(plan["lost"]), {
        "cause": "decay",
        "source_kind": "rule",
        "source_id": "round_end_defense_decay",
        "source_name": "自然防御衰减",
        "source_instance_key": "rule:round_end_defense_decay",
        "trigger_mode": "rule",
        "round_number": round_number,
        "action_token": action_token,
    })
    if not committed is Dictionary or not committed.get("success", false):
        var failed := plan.duplicate(true)
        failed["success"] = false
        failed["after"] = int(side.defense)
        failed["lost"] = int(plan["before"]) - int(side.defense)
        failed["errors"] = [str(
            committed.get("reason", "自然防御衰减提交失败")
            if committed is Dictionary else "自然防御衰减提交未返回结构化结果")]
        return failed
    var result := plan.duplicate(true)
    result["after"] = int(committed.get("after", side.defense))
    result["final_after"] = result["after"]
    result["lost"] = int(committed.get("removed", plan["lost"]))
    result["defense_commit"] = committed.duplicate(true)
    return result

func _resolve_decay_query(
        hook: String,
        side,
        base_value: int,
        context: Dictionary,
        facts: Dictionary) -> Dictionary:
    if _battle_rule_query_service == null:
        return {
            "success": true,
            "hook": hook,
            "base_value": base_value,
            "effective_value": base_value,
            "modifier_breakdown": [],
            "source_breakdown": [],
            "source_fingerprint": "",
            "fingerprint": "",
            "request_fingerprint": "",
            "errors": [],
        }
    var metadata := context.duplicate(true)
    metadata.merge(facts, true)
    metadata["cause"] = "decay"
    var query = _battle_rule_query_service.resolve_values({
        "hook": hook,
        "owner": side,
        "actor": side,
        "target": side,
        "subject_kind": "defense_decay",
        "subject_id": _side_id(side),
        "base_value": base_value,
        "round_number": int(context.get("round_number", 0)),
        "action_token": str(context.get("action_token", "")),
        "source_kind": "rule",
        "source_id": "round_end_defense_decay",
        "source_instance_key": "rule:round_end_defense_decay",
        "trigger_mode": "rule",
        "cause": "decay",
        "defense_before": int(facts.get("before", side.defense)),
        "metadata": metadata,
    })
    var query_result: Dictionary = query.to_dict()
    if not query.success:
        _battle_rule_query_service.report_failure(
            query, "defense_decay_policy")
    return query_result

func _failed_plan(
        side,
        before: int,
        retention: Dictionary,
        loss_cap_query: Dictionary = {},
        minimum_remaining_query: Dictionary = {}) -> Dictionary:
    var errors: Array = retention.get("errors", []).duplicate()
    if not loss_cap_query.get("success", true):
        errors.append_array(loss_cap_query.get("errors", []))
    if not minimum_remaining_query.get("success", true):
        errors.append_array(minimum_remaining_query.get("errors", []))
    return {
        "success": false,
        "side": side,
        "side_id": retention.get("side_id", _side_id(side)),
        "before": before,
        "after": before,
        "lost": 0,
        "retention_percent": int(retention.get(
            "retention_percent", DEFAULT_RETENTION_PERCENT)),
        "prevented": false,
        "modifiers": retention.get("modifiers", []).duplicate(true),
        "query": retention.get("query", {}).duplicate(true),
        "retention_query": retention.get("query", {}).duplicate(true),
        "proportional_after": before,
        "proposed_loss": 0,
        "queried_max_loss": 0,
        "capped_loss": 0,
        "after_cap": before,
        "queried_minimum_remaining": 0,
        "final_after": before,
        "loss_cap_query": loss_cap_query.duplicate(true),
        "minimum_remaining_query": minimum_remaining_query.duplicate(true),
        "errors": errors,
    }

func _is_valid_provider(provider) -> bool:
    if provider is Callable:
        return provider.is_valid()
    return provider != null and provider.has_method(PROVIDER_METHOD)

func _resolve_provider(provider, side, context: Dictionary) -> Dictionary:
    var result
    if provider is Callable:
        if not provider.is_valid():
            return {}
        result = provider.call(side, context)
    elif provider != null and provider.has_method(PROVIDER_METHOD):
        result = provider.call(PROVIDER_METHOD, side, context)
    return result if result is Dictionary else {}

func _side_id(side) -> String:
    if side == null:
        return ""
    return str(side.owner_id)
