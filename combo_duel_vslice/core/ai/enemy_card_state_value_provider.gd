class_name EnemyCardStateValueProvider
extends RefCounted

## 内容无关的卡牌状态语义适配器。按正/负类别提供估值，不解释任何状态 ID。

func query(hook: String, context: Dictionary) -> Dictionary:
    if hook == "ai_action_value_query":
        return {"success": true, "estimated_value": 0.0}
    var card = context.get("card")
    if card == null:
        return {"success": false, "reason": "卡牌状态估值缺少卡牌"}
    var snapshot: Dictionary = card.anomaly_snapshot() \
        if card.has_method("anomaly_snapshot") else {}
    var buff_layers := _layer_total(snapshot.get("buffs", {}))
    var debuff_layers := _layer_total(snapshot.get("debuffs", {}))
    var has_state: bool = not snapshot.get("state", {}).is_empty()
    var mark_count: int = snapshot.get("marks", {}).size()
    var positive_identity := 0.0
    if str(card.get("reshape_enhancement")) != "":
        positive_identity += 0.75
    if str(card.get("reshape_imprint")) != "":
        positive_identity += 0.75
    var signatures: Array[String] = []
    if buff_layers > 0:
        signatures.append("positive_anomaly")
    if debuff_layers > 0 or has_state:
        signatures.append("negative_anomaly")
    if mark_count > 0:
        signatures.append("card_mark")
    match hook:
        "ai_card_play_value_query":
            return {
                "success": true,
                "estimated_value": positive_identity + float(buff_layers) * 0.25,
                "negative_card_cleanup_value": (
                    float(debuff_layers) + (2.0 if has_state else 0.0)),
                "trigger_signatures": signatures,
            }
        "ai_card_retention_value_query":
            return {
                "success": true,
                "estimated_value": (
                    positive_identity + float(buff_layers) * 0.5
                    + float(mark_count) * 0.75),
                "negative_retention_cost": (
                    float(debuff_layers) + (2.0 if has_state else 0.0)),
                "trigger_signatures": signatures,
            }
    return {"success": true, "estimated_value": 0.0}

func _layer_total(values) -> int:
    var total := 0
    if values is Dictionary:
        for value in values.values():
            total += maxi(0, int(value))
    return total
