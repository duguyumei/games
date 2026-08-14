class_name SameQiRule
extends RefCounted

## “同气”共同属性条件与行动级收益最优分组的纯规则服务。
##
## 本服务只读取卡牌身份事实，不移动牌区、不推进随机数，也不修改战斗状态。

const KNOWN_ATTRIBUTES := ["wind", "forest", "fire", "mountain"]
static func analyze(
        cards: Array,
        identity_policy,
        context: Dictionary = {}) -> Dictionary:
    if cards.is_empty():
        return _failure("同气规则至少需要一张普通真气", cards.size())
    if identity_policy == null or not identity_policy.has_method("resolve"):
        return _failure("同气规则缺少卡牌身份策略", cards.size())

    var unique_cards: Array = []
    var seen_ids: Dictionary = {}
    for card in cards:
        var card_id := str(card.id)
        if not seen_ids.has(card_id):
            seen_ids[card_id] = true
            unique_cards.append(card)
    unique_cards.sort_custom(func(left, right): return str(left.id) < str(right.id))

    var common_attributes: Array[String] = []
    var card_attributes: Array = []
    var facts_by_id: Dictionary = {}
    for index in range(unique_cards.size()):
        var card = unique_cards[index]
        var resolved: Dictionary = identity_policy.resolve(card, context)
        if not resolved.get("success", false):
            return _failure(
                "卡牌 %s 身份查询失败：%s" % [
                    str(card.id) if card != null else str(index),
                    str(resolved.get("reason", "未知错误")),
                ],
                unique_cards.size(),
                card_attributes)
        var facts = resolved.get("facts")
        if facts == null or not facts.has_method("is_card_kind") \
                or not facts.is_card_kind("normal"):
            return _failure(
                "卡牌 %s 不是普通真气" % str(card.id),
                unique_cards.size(),
                card_attributes)
        var attributes: Array[String] = []
        for attribute in KNOWN_ATTRIBUTES:
            if facts.has_attribute(attribute):
                attributes.append(attribute)
        if attributes.is_empty():
            return _failure(
                "卡牌 %s 没有可分配的真气属性" % str(card.id),
                unique_cards.size(), card_attributes)
        card_attributes.append(attributes.duplicate())
        facts_by_id[str(card.id)] = attributes.duplicate()
        if index == 0:
            common_attributes = attributes.duplicate()
        else:
            common_attributes = _intersect(common_attributes, attributes)

    var best := {"gain": -1, "assignments": {}}
    _enumerate_assignments(unique_cards, facts_by_id, 0, {}, best)
    var assignments: Dictionary = best["assignments"].duplicate(true)
    var attribute_counts := {
        "wind": 0, "forest": 0, "fire": 0, "mountain": 0,
    }
    for attribute in assignments.values():
        attribute_counts[str(attribute)] = int(
            attribute_counts[str(attribute)]) + 1
    var grouped := {
        "wind": [], "forest": [], "fire": [], "mountain": [],
    }
    for card in unique_cards:
        grouped[str(assignments[str(card.id)])].append(str(card.id))
    var fingerprint_payload := {
        "card_ids": unique_cards.map(func(card): return str(card.id)),
        "card_attributes": facts_by_id,
        "assignments": assignments,
        "gain": int(best["gain"]),
    }
    return {
        "success": true,
        "qualified": not common_attributes.is_empty(),
        "common_attributes": common_attributes,
        "gain": int(best["gain"]),
        "card_ids": unique_cards.map(func(card): return str(card.id)),
        "assignments": assignments,
        "assignment_groups": grouped,
        "attribute_counts": attribute_counts,
        "source_fingerprint": JSON.stringify(fingerprint_payload).sha256_text(),
        "card_count": unique_cards.size(),
        "card_attributes": card_attributes,
        "reason": "",
        "errors": [],
    }

static func _enumerate_assignments(
        cards: Array,
        facts_by_id: Dictionary,
        index: int,
        current: Dictionary,
        best: Dictionary) -> void:
    if index >= cards.size():
        var counts: Dictionary = {}
        for attribute in current.values():
            counts[str(attribute)] = int(counts.get(str(attribute), 0)) + 1
        var gain := 0
        for count in counts.values():
            gain += maxi(0, int(count) - 1)
        if gain > int(best["gain"]):
            best["gain"] = gain
            best["assignments"] = current.duplicate(true)
        return
    var card = cards[index]
    var card_id := str(card.id)
    # cards 已按实例 ID 排序，属性按正式优先级枚举；只替换更高收益方案，
    # 因而同收益时自然稳定保留 wind→forest→fire→mountain 的最早分配。
    for attribute in KNOWN_ATTRIBUTES:
        if not facts_by_id[card_id].has(attribute):
            continue
        current[card_id] = attribute
        _enumerate_assignments(cards, facts_by_id, index + 1, current, best)
    current.erase(card_id)

static func _intersect(left: Array[String], right: Array[String]) -> Array[String]:
    var result: Array[String] = []
    for attribute in KNOWN_ATTRIBUTES:
        if left.has(attribute) and right.has(attribute):
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
        "gain": 0,
        "card_ids": [],
        "assignments": {},
        "assignment_groups": {},
        "attribute_counts": {},
        "source_fingerprint": "",
        "card_count": card_count,
        "card_attributes": card_attributes.duplicate(true),
        "reason": reason,
        "errors": [reason],
    }
