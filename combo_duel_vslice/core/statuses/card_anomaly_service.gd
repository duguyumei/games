class_name CardAnomalyService
extends RefCounted

const CardStateLifecycleScript = preload("res://core/card_state_lifecycle.gd")
const EffectSourceProtocolScript = preload(
    "res://core/effects/effect_source_protocol.gd")

const ANOMALY_CATEGORIES := ["buff", "debuff", "state", "mark"]
const TEMPORARY_RESHAPE_SUBSLOTS := ["enhancement", "attribute", "rank"]

var content_catalog
var status_history
var _lifecycle
var _effect_ports_ref: WeakRef
var _committed_event_service = null
var _round_number_reader: Callable
var _operation_serial: int = 0

func _init(catalog, history_service) -> void:
    assert(catalog != null, "CardAnomalyService requires ContentCatalog")
    assert(history_service != null,
        "CardAnomalyService requires StatusHistoryService")
    content_catalog = catalog
    status_history = history_service
    _lifecycle = CardStateLifecycleScript.new(catalog)

func use_effect_ports(effect_ports) -> void:
    _effect_ports_ref = weakref(effect_ports) if effect_ports != null else null

func use_committed_event_service(
        service, round_reader: Callable = Callable()) -> void:
    _committed_event_service = service
    _round_number_reader = round_reader

func reset_runtime_state() -> void:
    _operation_serial = 0

func capture_runtime_state() -> Dictionary:
    return {"operation_serial": _operation_serial}

func restore_runtime_state(state: Dictionary) -> void:
    _operation_serial = int(state.get("operation_serial", _operation_serial))

func on_committed_event_published(
        event_kind: String, values: Dictionary) -> void:
    if event_kind == "card_state_changed":
        _project_legacy_responses(values)

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

func battle_state_snapshot(card) -> Dictionary:
    if card == null:
        return {"anomalies": {}, "temporary_reshapes": {}}
    var anomalies: Dictionary = card.anomaly_snapshot()
    var temporary: Dictionary = card.temporary_reshapes.duplicate(true)
    var rank: Dictionary = temporary.get("rank", {})
    temporary["rank"] = {} if rank.is_empty() else {
        "rank_name": str(rank.get("rank_name", "")),
        "rank_order": int(rank.get("rank_order", 0)),
        "base_qi": int(rank.get("base_qi", rank.get("qi_value", 0))),
    }
    temporary["enhancement"] = str(temporary.get("enhancement", ""))
    temporary["attribute"] = str(temporary.get("attribute", ""))
    return {
        "anomalies": anomalies,
        "temporary_reshapes": temporary,
    }

func state_changes(before_state: Dictionary, after_state: Dictionary) -> Array:
    var changes: Array = []
    var before_anomalies: Dictionary = before_state.get("anomalies", {})
    var after_anomalies: Dictionary = after_state.get("anomalies", {})
    for category in ["buff", "debuff"]:
        var storage := "buffs" if category == "buff" else "debuffs"
        _append_map_changes(
            changes, "anomaly", category,
            before_anomalies.get(storage, {}), after_anomalies.get(storage, {}))
    _append_state_changes(
        changes,
        before_anomalies.get("state", {}),
        after_anomalies.get("state", {}))
    _append_map_changes(
        changes, "anomaly", "mark",
        before_anomalies.get("marks", {}), after_anomalies.get("marks", {}))

    var before_temporary: Dictionary = before_state.get("temporary_reshapes", {})
    var after_temporary: Dictionary = after_state.get("temporary_reshapes", {})
    for subslot in TEMPORARY_RESHAPE_SUBSLOTS:
        var before_value = before_temporary.get(
            subslot, {} if subslot == "rank" else "")
        var after_value = after_temporary.get(
            subslot, {} if subslot == "rank" else "")
        if before_value == after_value:
            continue
        var before_id := _temporary_content_id(subslot, before_value)
        var after_id := _temporary_content_id(subslot, after_value)
        var kind := "updated"
        if before_id == "":
            kind = "added"
        elif after_id == "":
            kind = "removed"
        changes.append(_change_entry(
            "temporary_reshape", "", subslot,
            after_id if after_id != "" else before_id,
            kind, before_value, after_value,
            0 if before_id == "" else 1,
            0 if after_id == "" else 1,
            before_id, after_id))
    return changes

func apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary = {},
        source: String = "效果",
        layers: int = 1,
        replace_state: bool = false,
        event_metadata: Dictionary = {}) -> Dictionary:
    var before_state := battle_state_snapshot(card)
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
    if before_state != battle_state_snapshot(card):
        status_history.record_change(
            "card_anomaly_apply", "card", str(card.id), anomaly_id,
            before, after, source, change_metadata)
    var metadata := event_metadata.duplicate(true)
    metadata["primary_category"] = category
    metadata["primary_content_id"] = anomaly_id
    var definition: Dictionary = content_catalog.get_by_id("anomaly", anomaly_id)
    var previous_state: Dictionary = before_state.get(
        "anomalies", {}).get("state", {})
    var operation := "purify" \
        if str(definition.get("on_apply", "")) == "purify_combat_state" \
        else "replace" if category == "state" and replace_state \
            and not previous_state.is_empty() \
            and str(previous_state.get("id", "")) != anomaly_id \
        else "apply"
    var state_event := _publish_state_change(
        card, before_state, battle_state_snapshot(card), operation, source,
        metadata)
    _merge_state_event_result(result, state_event)
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
    if card == null:
        return {"success": false, "reason": "异状移除目标为空"}
    var resolved_id := anomaly_id
    if resolved_id == "" and category == "state":
        resolved_id = str(card.current_state().get("id", ""))
    var before_state := battle_state_snapshot(card)
    var before = _card_anomaly_value(card, category, resolved_id)
    var removed = card.remove_anomaly(category, anomaly_id)
    var after_state := battle_state_snapshot(card)
    var changed := before_state != after_state
    if changed:
        status_history.record_change(
            "card_anomaly_remove", "card", str(card.id),
            resolved_id if resolved_id != "" else category,
            before, null, source,
            _change_history_metadata(event_metadata, {"category": category}))
    var metadata := event_metadata.duplicate(true)
    metadata["primary_category"] = category
    metadata["primary_content_id"] = resolved_id
    var operation := str(metadata.get("operation", "remove"))
    var state_event := _publish_state_change(
        card, before_state, after_state, operation, source, metadata)
    var result := {
        "success": true,
        "changed": changed,
        "removed": removed,
        "anomaly_id": resolved_id,
    }
    _merge_state_event_result(result, state_event)
    return result

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
    var source_before_state := battle_state_snapshot(source_card)
    var target_before_state := battle_state_snapshot(target_card)
    var source_before = _card_anomaly_value(source_card, category, anomaly_id)
    var target_before = _card_anomaly_value(target_card, category, anomaly_id)
    var applied: Dictionary = _lifecycle.apply_anomaly(
        target_card, category, anomaly_id, {}, 1, false)
    if not applied.get("success", false):
        return applied
    source_card.remove_anomaly(category, anomaly_id)
    var source_after_state := battle_state_snapshot(source_card)
    var target_after_state := battle_state_snapshot(target_card)
    var target_after = _card_anomaly_value(target_card, category, anomaly_id)
    status_history.record_change(
        "card_anomaly_transfer_out", "card", str(source_card.id), anomaly_id,
        source_before, null, source,
        _change_history_metadata(event_metadata, {
            "category": category, "target_id": str(target_card.id)}))
    status_history.record_change(
        "card_anomaly_transfer_in", "card", str(target_card.id), anomaly_id,
        target_before, target_after, source,
        _change_history_metadata(event_metadata, {
            "category": category,
            "transfer_source_card_id": str(source_card.id)}))

    var operation_token := _next_operation_token("transfer")
    var transfer_batch_token := operation_token
    var source_metadata := event_metadata.duplicate(true)
    source_metadata.merge({
        "holder": _locate_holder(source_card),
        "primary_category": category,
        "primary_content_id": anomaly_id,
        "transfer_batch_token": transfer_batch_token,
        "transfer_peer_card_id": str(target_card.id),
        "transfer_direction": "transfer_out",
    }, true)
    var target_metadata := event_metadata.duplicate(true)
    target_metadata.merge({
        "holder": _locate_holder(target_card),
        "primary_category": category,
        "primary_content_id": anomaly_id,
        "transfer_batch_token": transfer_batch_token,
        "transfer_peer_card_id": str(source_card.id),
        "transfer_direction": "transfer_in",
    }, true)
    # 两张牌已全部写完后才冻结事实；后续任一被动都看不到半完成转移。
    var source_values := _freeze_state_change(
        source_card, source_before_state, source_after_state,
        "transfer_out", source, source_metadata, operation_token)
    var target_values := _freeze_state_change(
        target_card, target_before_state, target_after_state,
        "transfer_in", source, target_metadata, operation_token)
    var source_event := _publish_frozen_state_change(source_values)
    var target_event := _publish_frozen_state_change(target_values)
    var result := {
        "success": true,
        "changed": true,
        "source_card": source_card,
        "target_card": target_card,
        "category": category,
        "anomaly_id": anomaly_id,
        "transfer_batch_token": transfer_batch_token,
    }
    if not source_event.get("success", true) or not target_event.get("success", true):
        result["passive_event_success"] = false
        result["passive_event_reason"] = str(source_event.get(
            "reason", target_event.get("reason", "")))
    return result

func set_card_anomaly_layers(
        card,
        category: String,
        anomaly_id: String,
        layers: int,
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    if card == null or category not in ["buff", "debuff", "state"] \
            or anomaly_id == "" or layers < 0:
        return {"success": false, "reason": "异状层数设置参数无效"}
    var before_state := battle_state_snapshot(card)
    var before: int = card.anomaly_layers(category, anomaly_id)
    if before == layers:
        return {"success": true, "changed": false,
            "before": before, "after": layers}
    if layers == 0:
        card.remove_anomaly(category, anomaly_id)
    elif category == "state" and before > 0:
        card.set_state_layers(layers)
    else:
        var permission: Dictionary = _lifecycle.can_apply_anomaly(
            card, category, anomaly_id, false)
        if not permission.get("allowed", false) and before <= 0:
            return {
                "success": false,
                "reason": permission.get("reason", "不能设置异状层数"),
            }
        card.set_anomaly(category, anomaly_id, {}, layers)
    var after_state := battle_state_snapshot(card)
    if before_state == after_state:
        return {"success": true, "changed": false,
            "before": before, "after": before}
    var actual_after: int = card.anomaly_layers(category, anomaly_id)
    status_history.record_change(
        "card_anomaly_layers_set", "card", str(card.id), anomaly_id,
        before, actual_after, source,
        _change_history_metadata(event_metadata, {"category": category}))
    var metadata := event_metadata.duplicate(true)
    metadata["primary_category"] = category
    metadata["primary_content_id"] = anomaly_id
    var state_event := _publish_state_change(
        card, before_state, after_state, "set_layers", source, metadata)
    var result := {"success": true, "changed": true,
        "before": before, "after": actual_after}
    _merge_state_event_result(result, state_event)
    return result

func apply_temporary_enhancement(
        card, enhancement_id: String, source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _set_temporary_reshape(
        card, "enhancement", enhancement_id, 0, 0, source, event_metadata)

func apply_temporary_attribute(
        card, attribute_id: String, source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _set_temporary_reshape(
        card, "attribute", attribute_id, 0, 0, source, event_metadata)

func apply_temporary_rank(
        card, rank_name: String, rank_order: int, base_qi: int,
        source: String = "效果", event_metadata: Dictionary = {}) -> Dictionary:
    return _set_temporary_reshape(
        card, "rank", rank_name, rank_order, base_qi, source, event_metadata)

func clear_temporary_reshape(
        card, subslot: String, source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    if card == null or subslot not in TEMPORARY_RESHAPE_SUBSLOTS:
        return {"success": false, "reason": "临时重塑子槽无效"}
    var before_state := battle_state_snapshot(card)
    var removed = card.clear_temporary_reshape(subslot)
    var after_state := battle_state_snapshot(card)
    var metadata := event_metadata.duplicate(true)
    metadata["primary_subslot"] = subslot
    metadata["primary_content_id"] = _temporary_content_id(subslot, removed)
    var state_event := _publish_state_change(
        card, before_state, after_state, "clear", source, metadata)
    var result := {"success": true, "changed": before_state != after_state,
        "removed": removed}
    _merge_state_event_result(result, state_event)
    return result

func clear_all_temporary_reshapes(
        card, source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    if card == null:
        return {"success": false, "reason": "临时重塑目标为空"}
    var before_state := battle_state_snapshot(card)
    var removed: Dictionary = card.clear_all_temporary_reshapes()
    var after_state := battle_state_snapshot(card)
    var state_event := _publish_state_change(
        card, before_state, after_state, "clear", source, event_metadata)
    var result := {"success": true, "changed": before_state != after_state,
        "removed": removed}
    _merge_state_event_result(result, state_event)
    return result

func clear_card_anomalies(
        card, source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    if card == null:
        return {"success": false, "reason": "异状清除目标为空"}
    var before_state := battle_state_snapshot(card)
    var removed: Dictionary = card.clear_anomalies()
    var after_state := battle_state_snapshot(card)
    var state_event := _publish_state_change(
        card, before_state, after_state,
        str(event_metadata.get("operation", "clear")), source, event_metadata)
    var result := {"success": true, "changed": before_state != after_state,
        "removed": removed}
    _merge_state_event_result(result, state_event)
    return result

func on_card_zone_transition(
        card, source_zone: String, destination_zone: String,
        reason: String, event_metadata: Dictionary = {}) -> Dictionary:
    if card == null:
        return {"success": false, "reason": "真气生命周期目标为空"}
    var real_departure := source_zone == "hand" and reason != "stage"
    real_departure = real_departure \
        or source_zone == "staging" and reason == "normal_play"
    if not real_departure and destination_zone != "discard_pile":
        return {"success": true, "changed": false}
    var before_state := battle_state_snapshot(card)
    var removed := {"meridian": null, "discard": {}}
    if real_departure and card.has_anomaly("mark", "meridian"):
        removed["meridian"] = card.remove_anomaly("mark", "meridian")
    if destination_zone == "discard_pile":
        removed["discard"] = _lifecycle.on_enter_discard(card)
    var after_state := battle_state_snapshot(card)
    if before_state != after_state:
        status_history.record_change(
            "card_state_lifecycle_remove", "card", str(card.id),
            "zone_transition", before_state, after_state, reason,
            _change_history_metadata(event_metadata))
    var metadata := event_metadata.duplicate(true)
    metadata["source_zone"] = source_zone
    metadata["destination_zone"] = destination_zone
    var state_event := _publish_state_change(
        card, before_state, after_state, "lifecycle_remove", reason, metadata)
    var result := {"success": true, "changed": before_state != after_state,
        "removed": removed}
    _merge_state_event_result(result, state_event)
    return result

func on_card_enter_discard(
        card, source: String = "进入弃牌堆",
        event_metadata: Dictionary = {}) -> Dictionary:
    return on_card_zone_transition(
        card, "", "discard_pile", source, event_metadata)

func on_card_battle_start(
        card, source: String = "战斗开始重塑",
        event_metadata: Dictionary = {}) -> Dictionary:
    var before_state := battle_state_snapshot(card)
    var results: Array[Dictionary] = _lifecycle.on_battle_start(card)
    var applied_count := 0
    for result in results:
        if not result.get("success", false):
            continue
        applied_count += 1
        status_history.record_change(
            "card_anomaly_apply", "card", str(card.id),
            str(result.get("anomaly_id", result.get(
                "reshape_id", "battle_start"))),
            null, "applied", source,
            _change_history_metadata(event_metadata))
    var state_event := _publish_state_change(
        card, before_state, battle_state_snapshot(card), "apply", source,
        event_metadata)
    var outcome := {"success": true, "applied_count": applied_count,
        "results": results}
    _merge_state_event_result(outcome, state_event)
    return outcome

func on_card_battle_end(
        card, source: String = "战斗结束") -> Dictionary:
    var before: Dictionary = battle_state_snapshot(card)
    var removed: Dictionary = _lifecycle.on_battle_end(card)
    var after: Dictionary = battle_state_snapshot(card)
    if before != after:
        status_history.record_change(
            "card_battle_end_cleanup", "card", str(card.id),
            "all_combat_state", before, after, source)
    return {"success": true, "changed": before != after, "removed": removed}

func _set_temporary_reshape(
        card, subslot: String, content_id: String,
        rank_order: int, base_qi: int,
        source: String, event_metadata: Dictionary) -> Dictionary:
    if card == null:
        return {"success": false, "reason": "临时重塑目标为空"}
    var before_state := battle_state_snapshot(card)
    var success := false
    match subslot:
        "enhancement": success = card.set_temporary_enhancement(content_id)
        "attribute": success = card.set_temporary_attribute(content_id)
        "rank": success = card.set_temporary_rank(content_id, rank_order, base_qi)
    if not success:
        return {"success": false, "reason": "临时重塑参数无效"}
    var after_state := battle_state_snapshot(card)
    var metadata := event_metadata.duplicate(true)
    metadata["primary_subslot"] = subslot
    metadata["primary_content_id"] = content_id
    var operation := "replace" \
        if not _temporary_value_empty(
            subslot, before_state.get("temporary_reshapes", {}).get(
                subslot, {} if subslot == "rank" else "")) \
        else "apply"
    var state_event := _publish_state_change(
        card, before_state, after_state, operation, source, metadata)
    var result := {
        "success": true,
        "changed": before_state != after_state,
        "subslot": subslot,
        "reshape_id": content_id,
        "rank_name": content_id if subslot == "rank" else "",
        "rank_order": rank_order if subslot == "rank" else 0,
        "base_qi": base_qi if subslot == "rank" else 0,
    }
    if subslot == "enhancement":
        result["enhancement"] = content_id
    elif subslot == "attribute":
        result["attribute"] = content_id
    _merge_state_event_result(result, state_event)
    return result

func _publish_state_change(
        card, before_state: Dictionary, after_state: Dictionary,
        operation: String, reason: String, event_metadata: Dictionary,
        operation_token: String = "") -> Dictionary:
    var values := _freeze_state_change(
        card, before_state, after_state, operation, reason, event_metadata,
        operation_token)
    return _publish_frozen_state_change(values)

func _freeze_state_change(
        card, before_state: Dictionary, after_state: Dictionary,
        operation: String, reason: String, event_metadata: Dictionary,
        operation_token: String = "") -> Dictionary:
    var changes := state_changes(before_state, after_state)
    if changes.is_empty():
        return {}
    var metadata := event_metadata.duplicate(true)
    var holder = metadata.get("holder") \
        if bool(metadata.get("holder_frozen", false)) else _locate_holder(card)
    if holder == null:
        holder = metadata.get("holder")
    var actor = metadata.get(
        "source_actor", metadata.get("actor", holder))
    var source := EffectSourceProtocolScript.from_values(metadata)
    var resolved_operation_token := operation_token
    if resolved_operation_token == "":
        resolved_operation_token = _next_operation_token(operation)
    var event_serial := -1
    var event_token := ""
    if _committed_event_service != null:
        event_serial = int(_committed_event_service.next_serial())
        event_token = _committed_event_service.make_token(
            "card_state_changed", actor, event_serial,
            str(metadata.get("action_token", "")), str(card.id))
    var added: Array = changes.filter(
        func(change): return str(change.get("change_kind", "")) == "added")
    var removed: Array = changes.filter(
        func(change): return str(change.get("change_kind", "")) == "removed")
    var updated: Array = changes.filter(
        func(change): return str(change.get("change_kind", "")) == "updated")
    var domain_ids: Dictionary = {}
    for change in changes:
        domain_ids[str(change.get("domain", ""))] = true
    domain_ids.erase("")
    var change_domain := str(domain_ids.keys()[0]) if domain_ids.size() == 1 \
        else "mixed"
    var primary := _primary_change(changes, metadata)
    var values := {
        "event_token": event_token,
        "event_serial": event_serial,
        "operation_token": resolved_operation_token,
        "action_token": str(metadata.get("action_token", "")),
        "round_number": int(_round_number_reader.call()) \
            if _round_number_reader.is_valid() else 0,
        "actor": actor,
        "target": metadata.get("target"),
        "owner": actor if actor != null else holder,
        "holder": holder,
        "holder_id": str(holder.owner_id) if holder != null else "",
        "observe_all_sides": true,
        "card": card,
        "card_instance_id": str(card.id),
        "source_card_instance_id": str(metadata.get(
            "source_card_instance_id", str(card.id))),
        "change_domain": change_domain,
        "operation": operation,
        "reason": reason,
        "before_state": before_state.duplicate(true),
        "after_state": after_state.duplicate(true),
        "changes": changes.duplicate(true),
        "added_changes": added.duplicate(true),
        "removed_changes": removed.duplicate(true),
        "updated_changes": updated.duplicate(true),
        "added_count": added.size(),
        "removed_count": removed.size(),
        "updated_count": updated.size(),
        "actual_change_count": changes.size(),
        "source_kind": source["source_kind"],
        "source_id": source["source_id"],
        "source_name": source["source_name"],
        "source_instance_key": source["source_instance_key"],
        "trigger_mode": source["trigger_mode"],
        "transfer_batch_token": str(metadata.get("transfer_batch_token", "")),
        "transfer_peer_card_id": str(metadata.get("transfer_peer_card_id", "")),
        "transfer_direction": str(metadata.get("transfer_direction", "")),
        "card_base_qi": int(card.qi_value),
        "current_base_qi": int(card.current_base_qi_value()),
        "metadata": metadata,
    }
    # 临时重塑沿用 card_state_changed，但明确标注持久性；异状事件不借用
    # reshape persistence 语义。永久改牌只发布 qi_reshape_committed。
    if change_domain == "temporary_reshape":
        values["persistence"] = "temporary"
    var effective_query := _event_effective_qi(
        holder, card, "card_state_changed")
    values["effective_qi"] = int(effective_query.get("effective_value", 0))
    values["effective_qi_query"] = effective_query
    if not primary.is_empty():
        values["category"] = str(primary.get("category", ""))
        values["anomaly_id"] = str(primary.get("content_id", "")) \
            if str(primary.get("domain", "")) == "anomaly" else ""
        values["subslot"] = str(primary.get("subslot", ""))
        values["reshape_id"] = str(primary.get("content_id", "")) \
            if str(primary.get("domain", "")) == "temporary_reshape" else ""
    return values

func _event_effective_qi(holder, card, boundary: String) -> Dictionary:
    if holder != null and holder.battle_rule_query_service != null:
        var query = holder.battle_rule_query_service.resolve_effective_qi(
            holder, card, {
                "actor": holder,
                "purpose": "event_snapshot",
                "evaluation_mode": "runtime",
                "cards": [card],
                "participating_card_ids": [],
                "source_kind": "committed_event",
            })
        if query.success:
            return query.to_dict()
        holder.battle_rule_query_service.report_failure(
            query, "%s_effective_qi" % boundary)
        return query.to_dict()
    var value := int(card.effective_qi_value()) \
        if card.has_method("effective_qi_value") else int(card.qi_value)
    return {
        "success": true,
        "base_value": value,
        "effective_value": maxi(0, value),
        "source_breakdown": [],
        "fingerprint": "",
        "request_fingerprint": "",
        "errors": [],
    }

func _publish_frozen_state_change(values: Dictionary) -> Dictionary:
    if values.is_empty():
        return {"success": true, "changed": false}
    var committed := {"success": true}
    if _committed_event_service != null:
        committed = _committed_event_service.commit(
            "card_state_changed", values)
    else:
        var ports = _effect_ports()
        if ports != null:
            ports.notify_response_event("card_state_changed", values)
            _project_legacy_responses(values)
    committed["changed"] = true
    committed["values"] = values
    return committed

func _project_legacy_responses(values: Dictionary) -> void:
    var ports = _effect_ports()
    if ports == null:
        return
    var anomaly_changes: Array = values.get("changes", []).filter(
        func(change): return str(change.get("domain", "")) == "anomaly")
    if anomaly_changes.is_empty():
        return
    var primary := _primary_change(anomaly_changes, values.get("metadata", {}))
    var legacy := values.duplicate(false)
    legacy["anomaly_changes"] = anomaly_changes.duplicate(true)
    legacy["category"] = str(primary.get("category", ""))
    legacy["anomaly_id"] = str(primary.get("content_id", ""))
    legacy["before"] = _duplicate_value(primary.get("before"))
    legacy["after"] = _duplicate_value(primary.get("after"))
    legacy["changed"] = true
    legacy["applied"] = str(primary.get("change_kind", "")) != "removed"
    legacy["removed"] = str(primary.get("change_kind", "")) == "removed"
    legacy["source"] = str(values.get("reason", ""))
    legacy["base_qi"] = int(values.get("current_base_qi", 0))
    ports.notify_response_event("card_anomaly_changed", legacy)

    var burned_changes: Array = anomaly_changes.filter(func(change):
        return str(change.get("category", "")) == "mark" \
            and str(change.get("content_id", "")) == "burned_out")
    if burned_changes.is_empty():
        return
    var burned: Dictionary = burned_changes[0]
    var burned_values := values.duplicate(false)
    burned_values["category"] = "mark"
    burned_values["anomaly_id"] = "burned_out"
    burned_values["before"] = _duplicate_value(burned.get("before"))
    burned_values["after"] = _duplicate_value(burned.get("after"))
    burned_values["changed"] = true
    burned_values["applied"] = str(burned.get("change_kind", "")) != "removed"
    burned_values["removed"] = str(burned.get("change_kind", "")) == "removed"
    burned_values["became_burned_out"] = \
        str(burned.get("change_kind", "")) == "added"
    burned_values["ceased_burned_out"] = \
        str(burned.get("change_kind", "")) == "removed"
    ports.notify_response_event("card_burned_out_changed", burned_values)

func _append_map_changes(
        changes: Array, domain: String, category: String,
        before_values: Dictionary, after_values: Dictionary) -> void:
    var content_ids: Array = before_values.keys()
    for content_id in after_values.keys():
        if not content_ids.has(content_id):
            content_ids.append(content_id)
    content_ids.sort()
    for content_id_value in content_ids:
        var content_id := str(content_id_value)
        var has_before := before_values.has(content_id_value)
        var has_after := after_values.has(content_id_value)
        var before = before_values.get(content_id_value)
        var after = after_values.get(content_id_value)
        if has_before and has_after and before == after:
            continue
        var kind := "updated"
        if not has_before:
            kind = "added"
        elif not has_after:
            kind = "removed"
        changes.append(_change_entry(
            domain, category, "", content_id, kind,
            before if has_before else null,
            after if has_after else null,
            _anomaly_layers_for_value(category, before) if has_before else 0,
            _anomaly_layers_for_value(category, after) if has_after else 0))

func _append_state_changes(
        changes: Array, before: Dictionary, after: Dictionary) -> void:
    var before_id := str(before.get("id", ""))
    var after_id := str(after.get("id", ""))
    if before_id == after_id:
        if before_id != "" and before != after:
            changes.append(_change_entry(
                "anomaly", "state", "", before_id, "updated",
                before, after, int(before.get("layers", 1)),
                int(after.get("layers", 1))))
        return
    if before_id != "":
        changes.append(_change_entry(
            "anomaly", "state", "", before_id, "removed",
            before, null, int(before.get("layers", 1)), 0))
    if after_id != "":
        changes.append(_change_entry(
            "anomaly", "state", "", after_id, "added",
            null, after, 0, int(after.get("layers", 1))))

func _change_entry(
        domain: String, category: String, subslot: String,
        content_id: String, change_kind: String,
        before, after, layer_before: int, layer_after: int,
        before_content_id: String = "", after_content_id: String = "") -> Dictionary:
    return {
        "domain": domain,
        "category": category,
        "subslot": subslot,
        "content_id": content_id,
        "before_content_id": before_content_id,
        "after_content_id": after_content_id,
        "change_kind": change_kind,
        "before": _duplicate_value(before),
        "after": _duplicate_value(after),
        "layer_before": layer_before,
        "layer_after": layer_after,
        "layer_delta": layer_after - layer_before,
    }

func _primary_change(changes: Array, metadata: Dictionary) -> Dictionary:
    var wanted_category := str(metadata.get("primary_category", ""))
    var wanted_subslot := str(metadata.get("primary_subslot", ""))
    var wanted_id := str(metadata.get("primary_content_id", ""))
    for change_value in changes:
        var change: Dictionary = change_value
        if wanted_category != "" \
                and str(change.get("category", "")) != wanted_category:
            continue
        if wanted_subslot != "" \
                and str(change.get("subslot", "")) != wanted_subslot:
            continue
        if wanted_id != "" and str(change.get("content_id", "")) != wanted_id \
                and str(change.get("before_content_id", "")) != wanted_id \
                and str(change.get("after_content_id", "")) != wanted_id:
            continue
        return change
    return changes[0] if not changes.is_empty() else {}

func _anomaly_layers_for_value(category: String, value) -> int:
    if value == null:
        return 0
    if category in ["buff", "debuff"]:
        return int(value)
    if category == "state" and value is Dictionary:
        return int(value.get("layers", 1))
    return 1

func _temporary_content_id(subslot: String, value) -> String:
    if subslot == "rank":
        return str(value.get("rank_name", "")) if value is Dictionary else ""
    return str(value)

func _temporary_value_empty(subslot: String, value) -> bool:
    return _temporary_content_id(subslot, value) == ""

func _next_operation_token(operation: String) -> String:
    var token := "card-state:%s:%06d" % [operation, _operation_serial]
    _operation_serial += 1
    return token

func _locate_holder(card):
    var ports = _effect_ports()
    if ports == null or card == null:
        return null
    var location: Dictionary = ports.locate_active_card(str(card.id))
    return location.get("side") if location.get("success", false) else null

func _change_history_metadata(
        event_metadata: Dictionary,
        extra: Dictionary = {}) -> Dictionary:
    # 状态历史是长生命周期诊断数据，不能保存 holder/actor/card 等领域对象。
    var result: Dictionary = {}
    for field in [
            "source_kind", "source_id", "source_name",
            "source_instance_key", "trigger_mode", "action_token",
            "technique_id", "source_card_instance_id",
            "transfer_peer_card_id", "transfer_batch_token",
            "transfer_direction", "operation_token"]:
        if event_metadata.has(field):
            result[field] = str(event_metadata[field])
    result.merge(extra, true)
    return result

func _card_anomaly_value(card, category: String, anomaly_id: String):
    if card == null:
        return null
    match category:
        "buff", "debuff", "state":
            return card.anomaly_layers(category, anomaly_id)
        "mark":
            return card.anomaly_snapshot().get(
                "marks", {}).get(anomaly_id, null)
    return null

func _merge_state_event_result(result: Dictionary, event_result: Dictionary) -> void:
    if event_result.get("changed", false):
        result["state_event"] = event_result.get("values", {})
    if not event_result.get("success", true):
        result["passive_event_success"] = false
        result["passive_event_reason"] = str(event_result.get("reason", ""))

func _duplicate_value(value):
    return value.duplicate(true) if value is Dictionary or value is Array else value

func _effect_ports():
    return _effect_ports_ref.get_ref() \
        if _effect_ports_ref != null else null
