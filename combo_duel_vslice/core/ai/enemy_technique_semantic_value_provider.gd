class_name EnemyTechniqueSemanticValueProvider
extends RefCounted

## 只读取功法公开语义标签，提供确定性的通用估值。
## 不认识具体功法 ID，也不查询或推进随机源。

const ESTIMATED_VALUES := {
    "draw": 2.0,
    "recover": 2.0,
    "deck_control": 1.5,
    "anomaly_apply": 1.5,
    "delayed_defense": 2.0,
    "momentum": 2.0,
    "reflection": 3.0,
    "block": 4.0,
    "temporary_card": 2.0,
    "economic_gain": 1.5,
    "same_qi_payoff": 1.5,
    "retrigger_sensitive": 1.0,
}

const CONTROL_VALUES := {
    "discard": 2.0,
    "enemy_disruption": 2.5,
    "challenge": 3.0,
}

func query(hook: String, context: Dictionary) -> Dictionary:
    if hook != "ai_action_value_query":
        return {"success": true}
    var preview: Dictionary = context.get("preview", {})
    var technique: Dictionary = preview.get("technique", {})
    var tags: Array = technique.get("semantic_tags", []).duplicate()
    tags.append_array(technique.get("public_behavior_summary", []))
    var unique: Dictionary = {}
    for value in tags:
        unique[str(value)] = true
    var estimated := 0.0
    var control := 0.0
    var signatures: Array[String] = []
    for tag in unique:
        estimated += float(ESTIMATED_VALUES.get(tag, 0.0))
        control += float(CONTROL_VALUES.get(tag, 0.0))
        if ESTIMATED_VALUES.has(tag) or CONTROL_VALUES.has(tag):
            signatures.append("technique:%s" % tag)
    var extra_commitment := maxi(
        0,
        int(preview.get("cards", []).size())
        - int(preview.get("hand", {}).get("contributing", []).size()))
    if unique.has("extra_card_commitment"):
        estimated -= float(extra_commitment) * 0.5
    if unique.has("same_qi_payoff"):
        estimated += float(preview.get("same_qi_gain", 0)) * 0.5
    signatures.sort()
    return {
        "success": true,
        "estimated_value": estimated,
        "control_value": control,
        "trigger_signatures": signatures,
    }

