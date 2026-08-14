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

func use_battle_rule_query_service(service) -> void:
    _battle_rule_query_service = service

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

func apply_decay(side, context: Dictionary = {}) -> Dictionary:
    var retention := resolve_retention(side, context)
    var before := maxi(0, int(side.defense))
    if not retention.get("success", false):
        return {
            "success": false, "side": side,
            "side_id": retention.get("side_id", _side_id(side)),
            "before": before, "after": before, "lost": 0,
            "retention_percent": int(retention.get("retention_percent", 50)),
            "prevented": false,
            "modifiers": retention.get("modifiers", []).duplicate(true),
            "query": retention.get("query", {}).duplicate(true),
            "errors": retention.get("errors", []).duplicate(),
        }
    var retention_percent := int(retention["retention_percent"])
    var after := maxi(0, int(floor(
        float(before) * float(retention_percent) / 100.0)))
    side.defense = after
    return {
        "success": true,
        "side": side,
        "side_id": retention["side_id"],
        "before": before,
        "after": after,
        "lost": before - after,
        "retention_percent": retention_percent,
        "prevented": bool(retention["prevented"]),
        "modifiers": retention["modifiers"].duplicate(true),
        "query": retention.get("query", {}).duplicate(true),
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
