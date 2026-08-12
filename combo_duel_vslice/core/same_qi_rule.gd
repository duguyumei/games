class_name SameQiRule
extends RefCounted

## “同气”组级识别与行动级共同属性求交的纯规则服务。
##
## 本服务只读取卡牌身份事实，不移动牌区、不推进随机数，也不修改战斗状态。

const KNOWN_ATTRIBUTES := ["wind", "forest", "fire", "mountain"]
const POWER_AMP_BY_CARD_COUNT := {
    1: 0,
    2: 10,
    3: 20,
    4: 30,
    5: 50,
}

static func analyze(
        cards: Array,
        identity_policy,
        context: Dictionary = {}) -> Dictionary:
    if cards.is_empty() or cards.size() > 5:
        return _failure("同气规则要求 1～5 张普通真气", cards.size())
    if identity_policy == null or not identity_policy.has_method("resolve"):
        return _failure("同气规则缺少卡牌身份策略", cards.size())

    var common_attributes: Array[String] = []
    var card_attributes: Array = []
    for index in range(cards.size()):
        var card = cards[index]
        var resolved: Dictionary = identity_policy.resolve(card, context)
        if not resolved.get("success", false):
            return _failure(
                "卡牌 %s 身份查询失败：%s" % [
                    str(card.id) if card != null else str(index),
                    str(resolved.get("reason", "未知错误")),
                ],
                cards.size(),
                card_attributes)
        var facts = resolved.get("facts")
        if facts == null or not facts.has_method("is_card_kind") \
                or not facts.is_card_kind("normal"):
            return _failure(
                "卡牌 %s 不是普通真气" % str(card.id),
                cards.size(),
                card_attributes)
        var attributes: Array[String] = []
        for attribute in KNOWN_ATTRIBUTES:
            if facts.has_attribute(attribute):
                attributes.append(attribute)
        card_attributes.append(attributes.duplicate())
        if index == 0:
            common_attributes = attributes.duplicate()
        else:
            common_attributes = _intersect(common_attributes, attributes)

    var qualified := not common_attributes.is_empty()
    return {
        "success": true,
        "qualified": qualified,
        "common_attributes": common_attributes,
        "card_count": cards.size(),
        "power_amp_percent": int(POWER_AMP_BY_CARD_COUNT.get(
            cards.size(), 0)) if qualified else 0,
        "card_attributes": card_attributes,
        "reason": "",
        "errors": [],
    }

static func intersect_group_attributes(group_results: Array) -> Dictionary:
    if group_results.is_empty():
        return _failure("同气行动至少需要一个牌型组", 0)
    var common_attributes: Array[String] = []
    var card_count := 0
    for index in range(group_results.size()):
        var group = group_results[index]
        if not group is Dictionary:
            return _failure("同气组结果必须是对象", card_count)
        if not group.get("success", false):
            return _failure(
                "同气组结果失败：%s" % str(group.get("reason", "未知错误")),
                card_count)
        card_count += int(group.get("card_count", 0))
        var attributes := _normalized_attributes(
            group.get("common_attributes", []))
        if index == 0:
            common_attributes = attributes
        else:
            common_attributes = _intersect(common_attributes, attributes)
    return {
        "success": true,
        "qualified": not common_attributes.is_empty(),
        "common_attributes": common_attributes,
        "card_count": card_count,
        "group_count": group_results.size(),
        "reason": "",
        "errors": [],
    }

static func _intersect(left: Array[String], right: Array[String]) -> Array[String]:
    var result: Array[String] = []
    for attribute in KNOWN_ATTRIBUTES:
        if left.has(attribute) and right.has(attribute):
            result.append(attribute)
    return result

static func _normalized_attributes(values) -> Array[String]:
    var result: Array[String] = []
    if values is Array:
        for attribute in KNOWN_ATTRIBUTES:
            if values.has(attribute):
                result.append(attribute)
    return result

static func _failure(
        reason: String,
        card_count: int,
        card_attributes: Array = []) -> Dictionary:
    return {
        "success": false,
        "qualified": false,
        "common_attributes": [],
        "card_count": card_count,
        "power_amp_percent": 0,
        "card_attributes": card_attributes.duplicate(true),
        "reason": reason,
        "errors": [reason],
    }
