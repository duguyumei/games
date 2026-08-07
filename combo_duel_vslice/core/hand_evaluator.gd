class_name HandEvaluator
extends RefCounted

const HANDS := {
    "high_card": {"name": "高牌", "multiplier": 1, "strength": 0},
    "pair": {"name": "一对", "multiplier": 2, "strength": 1},
    "two_pair": {"name": "两对", "multiplier": 2, "strength": 2},
    "three_kind": {"name": "三条", "multiplier": 3, "strength": 3},
    "straight": {"name": "顺子", "multiplier": 4, "strength": 4},
    "full_house": {"name": "葫芦", "multiplier": 4, "strength": 5},
    "four_kind": {"name": "四条", "multiplier": 7, "strength": 6},
}
const HandResultDtoScript = preload("res://core/hand_result_dto.gd")

static func evaluate_dto(cards: Array):
    return HandResultDtoScript.new().configure(evaluate(cards))

static func evaluate_best(cards: Array) -> Dictionary:
    var candidates := evaluate_best_candidates(cards)
    return candidates[0] if not candidates.is_empty() else {}

static func evaluate_best_candidates(cards: Array) -> Array:
    var best_strength := -1
    var candidates: Array = []
    var seen_contributing: Dictionary = {}
    for size in range(1, mini(5, cards.size()) + 1):
        for group in _combinations(cards, size):
            var candidate := evaluate(group)
            if candidate.is_empty():
                continue
            var strength := int(candidate["strength"])
            if strength < best_strength:
                continue
            if strength > best_strength:
                best_strength = strength
                candidates.clear()
                seen_contributing.clear()
            var contributing_ids: Array[String] = []
            for card in candidate["contributing"]:
                contributing_ids.append(str(card.id))
            contributing_ids.sort()
            var key := "|".join(contributing_ids)
            if not seen_contributing.has(key):
                seen_contributing[key] = true
                candidates.append(candidate)
    return candidates

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

static func _result(hand_id: String, contributing: Array) -> Dictionary:
    var definition: Dictionary = HANDS[hand_id]
    return {
        "id": hand_id,
        "name": definition["name"],
        "multiplier": definition["multiplier"],
        "strength": definition["strength"],
        "contributing": contributing.duplicate(),
        "royal": false,
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

static func _combinations(cards: Array, size: int, start: int = 0, prefix: Array = []) -> Array:
    if prefix.size() == size:
        return [prefix.duplicate()]
    var groups: Array = []
    var remaining := size - prefix.size()
    for index in range(start, cards.size() - remaining + 1):
        prefix.append(cards[index])
        groups.append_array(_combinations(cards, size, index + 1, prefix))
        prefix.pop_back()
    return groups
