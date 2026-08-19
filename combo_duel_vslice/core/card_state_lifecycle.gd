class_name CardStateLifecycle
extends RefCounted

var content_catalog

func _init(catalog) -> void:
    content_catalog = catalog

func can_apply_anomaly(
        card,
        category: String,
        anomaly_id: String,
        replace_state: bool = false) -> Dictionary:
    var definition: Dictionary = content_catalog.get_by_id("anomaly", anomaly_id)
    if definition.is_empty() or str(definition.get("category", "")) != category:
        return {"allowed": false, "reason": "未知或类别不匹配的异状 %s" % anomaly_id}
    var reshape_permission: Dictionary = card.can_apply_anomaly(category, anomaly_id) \
        if card.has_method("can_apply_anomaly") else {"allowed": true}
    if not bool(reshape_permission.get("allowed", true)):
        return reshape_permission
    if category == "mark" and card.has_anomaly("mark", anomaly_id):
        return {"allowed": false, "reason": "此真气已有标记 %s" % anomaly_id}
    if category in ["buff", "debuff"] \
            and card.has_anomaly(category, anomaly_id) \
            and not bool(definition.get("stackable", false)):
        return {"allowed": false, "reason": "此真气已有异状 %s" % anomaly_id}
    if category == "state" and card.has_anomaly("state"):
        var existing_id := str(card.current_state().get("id", ""))
        if existing_id == anomaly_id:
            if str(definition.get("same_id", "keep")) == "stack":
                return {"allowed": true}
            return {"allowed": false, "reason": "同名状态不会重复获得"}
        if not replace_state:
            return {"allowed": false, "reason": "此真气已有状态 %s" % existing_id}
    return {"allowed": true}

func apply_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary = {},
        layers: int = 1,
        replace_state: bool = false) -> Dictionary:
    var definition: Dictionary = content_catalog.get_by_id("anomaly", anomaly_id)
    if definition.is_empty():
        return {"success": false, "reason": "未知真气异状：%s" % anomaly_id}
    if str(definition.get("category", "")) != category:
        return {"success": false, "reason": "异状 %s 不属于类别 %s" % [anomaly_id, category]}
    var existing_state: Dictionary = card.current_state()
    if category == "state" \
            and str(existing_state.get("id", "")) == anomaly_id \
            and str(definition.get("same_id", "keep")) == "keep":
        return {"success": true, "changed": false, "refreshed": true}
    var anomaly_permission: Dictionary = can_apply_anomaly(
        card, category, anomaly_id, replace_state)
    if not bool(anomaly_permission.get("allowed", true)):
        return {
            "success": false,
            "reason": str(anomaly_permission.get("reason", "此真气不能获得异状")),
        }
    if layers <= 0:
        return {"success": false, "reason": "异状层数必须是正整数"}
    var same_id: bool = card.has_anomaly(category, anomaly_id)
    if category == "state" and not existing_state.is_empty():
        var existing_id := str(existing_state.get("id", ""))
        if existing_id == anomaly_id:
            if str(definition.get("same_id", "keep")) == "stack":
                card.set_state_layers(int(existing_state.get("layers", 1)) + layers)
                return {"success": true, "changed": true, "refreshed": false}
            return {"success": false, "reason": "同名状态不会重复获得"}
        if not replace_state:
            return {"success": false, "reason": "此真气已有状态 %s" % existing_id}
    elif category == "mark" and same_id:
        return {"success": false, "reason": "此真气已有标记 %s" % anomaly_id}

    var removed := {"anomalies": {}, "temporary_reshapes": {}}
    if str(definition.get("on_apply", "")) == "purify_combat_state":
        removed["anomalies"] = card.clear_anomalies()
        removed["temporary_reshapes"] = card.clear_all_temporary_reshapes()
    elif category in ["buff", "debuff"] and same_id:
        card.add_anomaly_layers(category, anomaly_id, layers)
        return {"success": true, "removed": removed, "changed": true, "refreshed": false}
    if category == "state" and not existing_state.is_empty():
        card.remove_anomaly("state")
    var runtime_payload: Dictionary = definition.get("runtime_payload", {}).duplicate(true)
    runtime_payload.merge(payload, true)
    var normalized_layers: int = (
        layers if category in ["buff", "debuff"] or anomaly_id == "forbidden" else 1)
    if not card.set_anomaly(category, anomaly_id, runtime_payload, normalized_layers):
        return {"success": false, "reason": "无法施加异状 %s" % anomaly_id}
    return {"success": true, "removed": removed, "changed": true, "refreshed": false}

func on_battle_start(card) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    var reshape_ids: Array = card.reshape_others.keys().duplicate()
    for reshape_id in reshape_ids:
        var definition: Dictionary = content_catalog.get_by_id("other_reshape", str(reshape_id))
        for effect_value in definition.get("battle_start_anomalies", []):
            var effect: Dictionary = effect_value
            var result := apply_anomaly(
                card,
                str(effect.get("category", "")),
                str(effect.get("anomaly", "")),
                effect.get("payload", {}))
            result["reshape_id"] = str(reshape_id)
            result["category"] = str(effect.get("category", ""))
            result["anomaly_id"] = str(effect.get("anomaly", ""))
            results.append(result)
    return results

func on_enter_discard(card) -> Dictionary:
    var removed := {
        "buff": {}, "debuff": {}, "state": {},
        "temporary_blazing_layers": card.clear_temporary_blazing_layers(),
    }
    for category in ["buff", "debuff"]:
        var snapshot: Dictionary = card.anomaly_snapshot().get(
            "buffs" if category == "buff" else "debuffs", {})
        for anomaly_id in snapshot:
            var definition: Dictionary = content_catalog.get_by_id("anomaly", str(anomaly_id))
            if bool(definition.get("remove_on_enter_discard", false)):
                removed[category][anomaly_id] = card.remove_anomaly(category, str(anomaly_id))
    var state: Dictionary = card.current_state()
    if not state.is_empty():
        var definition: Dictionary = content_catalog.get_by_id(
            "anomaly", str(state.get("id", "")))
        if bool(definition.get("remove_on_enter_discard", true)):
            removed["state"] = card.remove_anomaly("state")
    return removed

func on_battle_end(card) -> Dictionary:
    var removed := {
        "anomalies": card.clear_anomalies(),
        "temporary_reshapes": card.clear_all_temporary_reshapes(),
        "temporary_blazing_layers": card.clear_temporary_blazing_layers(),
    }
    return removed
