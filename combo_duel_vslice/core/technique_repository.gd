class_name TechniqueRepository
extends RefCounted

const DATA_PATH := "res://data/techniques.json"

var techniques: Dictionary = {}
var pool_membership: Dictionary = {}

func load_from_file(path: String = DATA_PATH) -> bool:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        push_error("功法数据无法解析：%s" % path)
        return false
    return configure(parsed)

func configure(value: Dictionary) -> bool:
    techniques.clear()
    pool_membership.clear()
    var parsed := value.duplicate(true)
    pool_membership = parsed.get("pool_membership", {}).duplicate(true)
    for definition in parsed.get("techniques", []):
        techniques[str(definition["id"])] = definition.duplicate(true)
    return not techniques.is_empty()

func get_technique(technique_id: String) -> Dictionary:
    return techniques.get(technique_id, {}).duplicate(true)

func is_allowed_for_hand(technique: Dictionary, hand_id: String) -> bool:
    var eligible_pools: Array = pool_membership.get(hand_id, [])
    return eligible_pools.has(technique.get("pool", ""))

func conditions_met(technique: Dictionary, hand_result: Dictionary) -> Dictionary:
    if technique.is_empty():
        return {"ok": false, "reason": "功法不存在"}
    var hand_id: String = hand_result.get("id", "")
    if not is_allowed_for_hand(technique, hand_id):
        return {"ok": false, "reason": "功法不属于该精确牌型的合格共用池"}
    var condition: Dictionary = technique.get("condition", {})
    if condition.is_empty():
        return {"ok": true, "reason": "条件满足"}
    if condition.has("attribute"):
        var wanted: String = condition["attribute"]
        var count := 0
        for card in hand_result.get("contributing", []):
            if card.attribute == wanted:
                count += 1
        if count < int(condition.get("minimum", 1)):
            return {"ok": false, "reason": "参与最高牌型的%s属性真气不足" % wanted}
    if condition.has("pure_attribute") and not is_pure_attribute(hand_result, condition["pure_attribute"]):
        return {"ok": false, "reason": "参与最高牌型的真气不是纯属性"}
    return {"ok": true, "reason": "条件满足"}

static func is_pure_attribute(hand_result: Dictionary, attribute: String) -> bool:
    var contributing: Array = hand_result.get("contributing", [])
    if contributing.is_empty():
        return false
    for card in contributing:
        if card.attribute != attribute:
            return false
    return true
