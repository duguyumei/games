class_name HandEvaluator
extends RefCounted

const HANDS := {
    "high_card": {"name": "高牌", "multiplier": 1, "strength": 0},
    "pair": {"name": "一对", "multiplier": 2, "strength": 1},
    "two_pair": {"name": "两对", "multiplier": 2, "strength": 2},
    "three_kind": {"name": "三条", "multiplier": 3, "strength": 3},
    "straight": {"name": "顺子", "multiplier": 4, "strength": 4},
    "flush": {"name": "同花", "multiplier": 4, "strength": 5},
    "full_house": {"name": "葫芦", "multiplier": 4, "strength": 6},
    "four_kind": {"name": "四条", "multiplier": 7, "strength": 7},
    "straight_flush": {"name": "同花顺", "multiplier": 8, "strength": 8},
}

static func evaluate(cards: Array) -> Dictionary:
    if cards.is_empty() or cards.size() > 5:
        return {}
    var rank_groups: Dictionary = {}
    for card in cards:
        if not rank_groups.has(card.rank_order):
            rank_groups[card.rank_order] = []
        rank_groups[card.rank_order].append(card)

    var is_five := cards.size() == 5
    var straight := is_five and _is_straight(cards)
    var flush := is_five and _is_flush(cards)
    if straight and flush:
        return _result("straight_flush", cards, _is_royal(cards))

    var four_rank := _highest_rank_with_count(rank_groups, 4)
    if four_rank >= 0:
        return _result("four_kind", rank_groups[four_rank])

    var three_rank := _highest_rank_with_count(rank_groups, 3)
    var pair_ranks := _ranks_with_count(rank_groups, 2)
    if is_five and three_rank >= 0 and not pair_ranks.is_empty():
        var full_cards: Array = []
        full_cards.append_array(rank_groups[three_rank])
        full_cards.append_array(rank_groups[pair_ranks[0]])
        return _result("full_house", full_cards)
    if flush:
        return _result("flush", cards)
    if straight:
        return _result("straight", cards)
    if three_rank >= 0:
        return _result("three_kind", rank_groups[three_rank])
    if pair_ranks.size() >= 2:
        var two_pair_cards: Array = []
        two_pair_cards.append_array(rank_groups[pair_ranks[0]])
        two_pair_cards.append_array(rank_groups[pair_ranks[1]])
        return _result("two_pair", two_pair_cards)
    if pair_ranks.size() == 1:
        return _result("pair", rank_groups[pair_ranks[0]])

    var highest = cards[0]
    for card in cards:
        if card.rank_order > highest.rank_order:
            highest = card
    return _result("high_card", [highest])

static func _result(hand_id: String, contributing: Array, royal: bool = false) -> Dictionary:
    var definition: Dictionary = HANDS[hand_id]
    return {
        "id": hand_id,
        "name": "皇家同花顺" if royal else definition["name"],
        "multiplier": definition["multiplier"],
        "strength": definition["strength"],
        "contributing": contributing.duplicate(),
        "royal": royal,
    }

static func _highest_rank_with_count(groups: Dictionary, count: int) -> int:
    var result := -1
    for rank in groups:
        if groups[rank].size() >= count:
            result = maxi(result, int(rank))
    return result

static func _ranks_with_count(groups: Dictionary, count: int) -> Array:
    var ranks: Array = []
    for rank in groups:
        if groups[rank].size() == count:
            ranks.append(int(rank))
    ranks.sort()
    ranks.reverse()
    return ranks

static func _is_flush(cards: Array) -> bool:
    var attribute: String = cards[0].attribute
    for card in cards:
        if card.attribute != attribute:
            return false
    return true

static func _is_straight(cards: Array) -> bool:
    var ranks: Array = []
    for card in cards:
        if ranks.has(card.rank_order):
            return false
        ranks.append(card.rank_order)
    ranks.sort()
    if ranks == [2, 3, 4, 5, 14]:
        return true
    for index in range(1, ranks.size()):
        if ranks[index] != ranks[index - 1] + 1:
            return false
    return true

static func _is_royal(cards: Array) -> bool:
    var ranks: Array = []
    for card in cards:
        ranks.append(card.rank_order)
    ranks.sort()
    return ranks == [10, 11, 12, 13, 14]
