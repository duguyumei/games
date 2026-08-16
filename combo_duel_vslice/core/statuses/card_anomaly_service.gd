class_name CardAnomalyService
extends RefCounted

const CardStateLifecycleScript = preload("res://core/card_state_lifecycle.gd")

var content_catalog
var status_history
var _lifecycle
var _effect_ports_ref: WeakRef

func _init(catalog, history_service) -> void:
    assert(catalog != null, "CardAnomalyService requires ContentCatalog")
    assert(history_service != null,
        "CardAnomalyService requires StatusHistoryService")
    content_catalog = catalog
    status_history = history_service
    _lifecycle = CardStateLifecycleScript.new(catalog)

func use_effect_ports(effect_ports) -> void:
    _effect_ports_ref = weakref(effect_ports) if effect_ports != null else null

func card_numeric_modifier(card, modifier_id: String) -> int:
    if card == null or modifier_id == "":
        return 0
    var total := 0
    var snapshot: Dictionary = card.anomaly_snapshot()
    var anomaly_ids: Array = []
    anomaly_ids.append_array(snapshot.get("buffs", {}).keys())
    anomaly_ids.append_array(snapshot.get("debuffs", {}).keys())
    if not snapshot.get("state", {}).is_empty():
        anomaly_ids.append(str(snapshot["state"].get("id", "")))
    anomaly_ids.append_array(snapshot.get("marks", {}).keys())
    for anomaly_id in anomaly_ids:
        var definition: Dictionary = content_catalog.get_by_id(
            "anomaly", str(anomaly_id))
        for modifier_value in definition.get("modifiers", []):
            var modifier: Dictionary = modifier_value
            if str(modifier.get("id", "")) == modifier_id:
                var layers := 1
                var category := str(definition.get("category", ""))
                if category in ["buff", "debuff", "state"]:
                    layers = card.anomaly_layers(category, str(anomaly_id))
                total += layers * int(modifier.get("value", 0))
    return total

func actor_hand_card_numeric_modifier(side, modifier_id: String) -> int:
    var total := 0
    for card in side.hand:
        total += card_numeric_modifier(card, modifier_id)
    return total

func modify_card_contribution(card, contribution: int, holder = null) -> int:
    return contribution

func effective_qi_value(card) -> int:
    var value: int = (
        card.effective_qi_value(true)
        if card.has_method("effective_qi_value") else int(card.qi_value))
    return maxi(0, value)

func apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary = {},
        source: String = "效果",
        layers: int = 1,
        replace_state: bool = false,
        event_metadata: Dictionary = {}) -> Dictionary:
    var before = _card_anomaly_value(card, category, anomaly_id)
    var result: Dictionary = _lifecycle.apply_anomaly(
        card, category, anomaly_id, payload, layers, replace_state)
    if not result.get("success", false):
        return result
    var after = _card_anomaly_value(card, category, anomaly_id)
    var change_metadata := _change_history_metadata(event_metadata, {
        "category": category,
        "refreshed": bool(result.get("refreshed", false)),
    })
    status_history.record_change(
        "card_anomaly_apply",
        "card",
        str(card.id),
        anomaly_id,
        before,
        after,
        source,
        change_metadata)
    _emit_card_anomaly_change(
        card, category, anomaly_id, before, after, source, event_metadata)
    return result

func can_apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        replace_state: bool = false) -> Dictionary:
    return _lifecycle.can_apply_anomaly(
        card, category, anomaly_id, replace_state)

func remove_card_anomaly(
        card,
        category: String,
        anomaly_id: String = "",
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    var resolved_id := anomaly_id
    if resolved_id == "" and category == "state":
        resolved_id = str(card.current_state().get("id", ""))
    var changed: bool = card.has_anomaly(category, anomaly_id)
    var before = _card_anomaly_value(card, category, resolved_id)
    var removed = card.remove_anomaly(category, anomaly_id)
    if changed:
        var change_metadata := _change_history_metadata(event_metadata, {
            "category": category,
        })
        status_history.record_change(
            "card_anomaly_remove",
            "card",
            str(card.id),
            resolved_id if resolved_id != "" else category,
            before,
            null,
            source,
            change_metadata)
        _emit_card_anomaly_change(
            card, category, resolved_id, before, null, source, event_metadata)
    return {
        "success": true,
        "changed": changed,
        "removed": removed,
        "anomaly_id": resolved_id,
    }

func transfer_card_anomaly(
        source_card,
        target_card,
        category: String,
        anomaly_id: String,
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    if source_card == null or target_card == null or source_card == target_card:
        return {"success": false, "reason": "异状转移需要不同的来源与目标"}
    if not source_card.has_anomaly(category, anomaly_id):
        return {"success": false, "reason": "异状转移来源不再持有目标异状"}
    var permission: Dictionary = _lifecycle.can_apply_anomaly(
        target_card, category, anomaly_id, false)
    if not permission.get("allowed", false):
        return {
            "success": false,
            "reason": permission.get("reason", "目标不能获得异状"),
        }
    var source_before = _card_anomaly_value(
        source_card, category, anomaly_id)
    var target_before = _card_anomaly_value(
        target_card, category, anomaly_id)
    var applied: Dictionary = _lifecycle.apply_anomaly(
        target_card, category, anomaly_id, {}, 1, false)
    if not applied.get("success", false):
        return applied
    source_card.remove_anomaly(category, anomaly_id)
    var target_after = _card_anomaly_value(
        target_card, category, anomaly_id)
    var source_change_metadata := _change_history_metadata(event_metadata, {
        "category": category,
        "target_id": str(target_card.id),
    })
    var target_change_metadata := _change_history_metadata(event_metadata, {
        "category": category,
        "transfer_source_card_id": str(source_card.id),
    })
    status_history.record_change(
        "card_anomaly_transfer_out", "card", str(source_card.id), anomaly_id,
        source_before, null, source, source_change_metadata)
    status_history.record_change(
        "card_anomaly_transfer_in", "card", str(target_card.id), anomaly_id,
        target_before, target_after, source, target_change_metadata)
    var source_metadata := event_metadata.duplicate(true)
    source_metadata["transfer_peer_card_id"] = str(target_card.id)
    var target_metadata := event_metadata.duplicate(true)
    target_metadata["transfer_peer_card_id"] = str(source_card.id)
    _emit_card_anomaly_change(
        source_card, category, anomaly_id, source_before, null,
        source, source_metadata)
    _emit_card_anomaly_change(
        target_card, category, anomaly_id, target_before, target_after,
        source, target_metadata)
    return {
        "success": true,
        "changed": true,
        "source_card": source_card,
        "target_card": target_card,
        "category": category,
        "anomaly_id": anomaly_id,
    }

func set_card_anomaly_layers(
        card,
        category: String,
        anomaly_id: String,
        layers: int,
        source: String = "效果") -> Dictionary:
    if card == null or category not in ["buff", "debuff"] \
            or anomaly_id == "" or layers < 0:
        return {"success": false, "reason": "异状层数设置参数无效"}
    var before: int = card.anomaly_layers(category, anomaly_id)
    if before == layers:
        return {
            "success": true,
            "changed": false,
            "before": before,
            "after": layers,
        }
    if layers == 0:
        card.remove_anomaly(category, anomaly_id)
    else:
        var permission: Dictionary = _lifecycle.can_apply_anomaly(
            card, category, anomaly_id, false)
        if not permission.get("allowed", false) and before <= 0:
            return {
                "success": false,
                "reason": permission.get("reason", "不能设置异状层数"),
            }
        card.set_anomaly(category, anomaly_id, {}, layers)
    status_history.record_change(
        "card_anomaly_layers_set", "card", str(card.id), anomaly_id,
        before, layers, source, {"category": category})
    return {"success": true, "changed": true, "before": before, "after": layers}

func on_card_enter_discard(
        card, source: String = "进入弃牌堆") -> Dictionary:
    var removed: Dictionary = _lifecycle.on_enter_discard(card)
    if not removed.get("state", {}).is_empty():
        var before_state: Dictionary = removed["state"]
        status_history.record_change(
            "card_anomaly_remove",
            "card",
            str(card.id),
            str(before_state.get("id", "")),
            before_state,
            null,
            source,
            {"category": "state"})
    return removed

func on_card_battle_start(
        card, source: String = "战斗开始重塑") -> Dictionary:
    var results: Array[Dictionary] = _lifecycle.on_battle_start(card)
    var applied_count := 0
    for result in results:
        if not result.get("success", false):
            continue
        applied_count += 1
        status_history.record_change(
            "card_anomaly_apply",
            "card",
            str(card.id),
            str(result.get(
                "anomaly_id", result.get("reshape_id", "battle_start"))),
            null,
            "applied",
            source)
    return {
        "success": true,
        "applied_count": applied_count,
        "results": results,
    }

func on_card_battle_end(
        card, source: String = "战斗结束") -> Dictionary:
    var before: Dictionary = card.anomaly_snapshot()
    var removed: Dictionary = _lifecycle.on_battle_end(card)
    var after: Dictionary = card.anomaly_snapshot()
    if before != after:
        status_history.record_change(
            "card_battle_end_cleanup",
            "card",
            str(card.id),
            "all_anomalies",
            before,
            after,
            source)
    return {
        "success": true,
        "changed": before != after,
        "removed": removed,
    }

func _change_history_metadata(
        event_metadata: Dictionary,
        extra: Dictionary = {}) -> Dictionary:
    # 状态历史是长生命周期诊断数据，不能保存 holder/actor/card 等领域对象。
    var result: Dictionary = {}
    for field in [
            "source_kind", "source_id", "source_name",
            "source_instance_key", "trigger_mode", "action_token",
            "technique_id", "source_card_instance_id",
            "transfer_peer_card_id"]:
        if event_metadata.has(field):
            result[field] = str(event_metadata[field])
    result.merge(extra, true)
    return result

func _emit_card_anomaly_change(
        card,
        category: String,
        anomaly_id: String,
        before,
        after,
        source: String,
        event_metadata: Dictionary) -> void:
    if card == null or anomaly_id == "":
        return
    var effect_ports = _effect_ports()
    if effect_ports == null:
        return
    var holder = event_metadata.get("holder", event_metadata.get("actor"))
    if holder == null:
        var location: Dictionary = effect_ports.locate_active_card(str(card.id))
        holder = location.get("side") \
            if location.get("success", false) else null
    var values := event_metadata.duplicate(true)
    values.merge({
        "actor": holder,
        "holder": holder,
        "card": card,
        "source_card_instance_id": str(card.id),
        "category": category,
        "anomaly_id": anomaly_id,
        "before": before,
        "after": after,
        "changed": before != after,
        "applied": after != null,
        "removed": after == null,
        "source": source,
        "base_qi": int(card.current_base_qi_value()) \
            if card.has_method("current_base_qi_value") else int(card.qi_value),
        "card_base_qi": int(card.qi_value),
    }, true)
    effect_ports.notify_response_event("card_anomaly_changed", values)
    if category == "mark" and anomaly_id == "burned_out":
        values["became_burned_out"] = before == null and after != null
        values["ceased_burned_out"] = before != null and after == null
        effect_ports.notify_response_event("card_burned_out_changed", values)

func _card_anomaly_value(card, category: String, anomaly_id: String):
    match category:
        "buff", "debuff", "state":
            return card.anomaly_layers(category, anomaly_id)
        "mark":
            return card.anomaly_snapshot().get(
                "marks", {}).get(anomaly_id, null)
    return null

func _effect_ports():
    return _effect_ports_ref.get_ref() \
        if _effect_ports_ref != null else null
