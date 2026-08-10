class_name CardStateLifecycle
extends RefCounted

var content_catalog

func _init(catalog) -> void:
    content_catalog = catalog

func apply_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary = {}) -> Dictionary:
    var definition: Dictionary = content_catalog.get_by_id("anomaly", anomaly_id)
    if definition.is_empty():
        return {"success": false, "reason": "未知真气异状：%s" % anomaly_id}
    if str(definition.get("category", "")) != category:
        return {"success": false, "reason": "异状 %s 不属于类别 %s" % [anomaly_id, category]}
    var anomaly_permission: Dictionary = card.can_apply_anomaly(category, anomaly_id) \
        if card.has_method("can_apply_anomaly") else {"allowed": true}
    if not bool(anomaly_permission.get("allowed", true)):
        return {
            "success": false,
            "reason": str(anomaly_permission.get("reason", "此真气不能获得异状")),
        }
    var removed := {"reshapes": {}, "anomalies": {}}
    if str(definition.get("on_apply", "")) == "suppress_existing_effects":
        if card.has_anomaly("mark", anomaly_id):
            return {"success": true, "removed": removed, "refreshed": true}
        removed = card.suppress_existing_reshapes_and_clear_anomalies()
    var runtime_payload: Dictionary = definition.get("runtime_payload", {}).duplicate(true)
    runtime_payload.merge(payload, true)
    if not card.set_anomaly(category, anomaly_id, runtime_payload):
        return {"success": false, "reason": "无法施加异状 %s" % anomaly_id}
    return {"success": true, "removed": removed, "refreshed": false}

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
    var removed := {"poison": "", "state": ""}
    for category in ["poison", "state"]:
        var anomaly_id: String = card.anomaly_poison if category == "poison" else card.anomaly_state
        if anomaly_id == "":
            continue
        var definition: Dictionary = content_catalog.get_by_id("anomaly", anomaly_id)
        if definition.is_empty() or not bool(definition.get("remove_on_enter_discard", false)):
            continue
        removed[category] = card.remove_anomaly(category)
    return removed

func on_battle_end(card) -> Dictionary:
    var restored: Dictionary = card.restore_suppressed_reshapes()
    card.clear_anomalies()
    return restored
