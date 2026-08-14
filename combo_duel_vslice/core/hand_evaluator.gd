class_name HandEvaluator
extends RefCounted

const HANDS := {
    "high_card": {"name": "高牌", "strength": 0},
    "pair": {"name": "一对", "strength": 1},
    "two_pair": {"name": "两对", "strength": 2},
    "three_kind": {"name": "三条", "strength": 3},
    "straight": {"name": "顺子", "strength": 4},
    "full_house": {"name": "葫芦", "strength": 5},
    "four_kind": {"name": "四条", "strength": 6},
    "five_kind": {"name": "五条", "strength": 7},
}
const HandResultDtoScript = preload("res://core/hand_result_dto.gd")
const HandRecognitionOptionsScript = preload(
    "res://core/passives/hand_recognition_options.gd")

static func evaluate_dto(
        cards: Array,
        options = null,
        identity_policy = null,
        context: Dictionary = {}):
    return HandResultDtoScript.new().configure(
        evaluate(cards, options, identity_policy, context))

static func evaluate_best(
        cards: Array,
        options = null,
        identity_policy = null,
        context: Dictionary = {}) -> Dictionary:
    var candidates := evaluate_best_candidates(
        cards, options, identity_policy, context)
    return candidates[0] if not candidates.is_empty() else {}

static func evaluate_best_candidates(
        cards: Array,
        options = null,
        identity_policy = null,
        context: Dictionary = {}) -> Array:
    var resolved_options = _coerce_options(options)
    var best_strength := -1
    var candidates: Array = []
    var seen_contributing: Dictionary = {}
    for size in range(1, mini(5, cards.size()) + 1):
        for group in _combinations(cards, size):
            var candidate := evaluate(
                group, resolved_options, identity_policy, context)
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

static func evaluate(
        cards: Array,
        options = null,
        identity_policy = null,
        context: Dictionary = {}) -> Dictionary:
    if cards.is_empty() or cards.size() > 5:
        return {}
    if identity_policy != null and identity_policy.has_method("resolve"):
        for card in cards:
            var identity: Dictionary = identity_policy.resolve(card, context)
            if not identity.get("success", false):
                return {}
    var resolved_options = _coerce_options(options)
    var rank_groups: Dictionary = {}
    for card in cards:
        var rank_order := _rank_order(card, identity_policy, context)
        if not rank_groups.has(rank_order):
            rank_groups[rank_order] = []
        rank_groups[rank_order].append(card)

    var is_five := cards.size() == 5
    var straight: bool = resolved_options.straight_allowed_sizes.has(cards.size()) \
        and _is_straight(cards, resolved_options, identity_policy, context)

    var five_rank := _highest_rank_with_count(rank_groups, 5)
    if five_rank >= 0:
        return _result("five_kind", rank_groups[five_rank])

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
        var card_order := _rank_order(card, identity_policy, context)
        var highest_order := _rank_order(highest, identity_policy, context)
        if card_order > highest_order:
            highest = card
    return _result("high_card", [highest])

static func _result(hand_id: String, contributing: Array) -> Dictionary:
    var definition: Dictionary = HANDS[hand_id]
    return {
        "id": hand_id,
        "name": definition["name"],
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

static func _is_straight(
        cards: Array,
        options,
        identity_policy = null,
        context: Dictionary = {}) -> bool:
    var ranks: Array = []
    for card in cards:
        var rank_order := _rank_order(card, identity_policy, context)
        if ranks.has(rank_order):
            return false
        ranks.append(rank_order)
    ranks.sort()
    if ranks.has(14) and bool(options.ace_low_allowed):
        var ace_low_ranks := ranks.duplicate()
        ace_low_ranks.erase(14)
        ace_low_ranks.append(1)
        ace_low_ranks.sort()
        if _steps_within_limit(ace_low_ranks, int(options.straight_max_step)):
            return true
    if ranks.has(14) and not bool(options.ace_high_allowed):
        return false
    if ranks.has(14) and ranks[0] < 10:
        # A 只能占据低端特例或高端，不能与中间牌阶形成首尾循环。
        return false
    return _steps_within_limit(ranks, int(options.straight_max_step))

static func _steps_within_limit(ranks: Array, maximum_step: int) -> bool:
    for index in range(1, ranks.size()):
        var step := int(ranks[index]) - int(ranks[index - 1])
        if step < 1 or step > maximum_step:
            return false
    return true

static func _rank_order(card, identity_policy, context: Dictionary) -> int:
    if identity_policy != null and identity_policy.has_method("resolve"):
        var resolved: Dictionary = identity_policy.resolve(card, context)
        if bool(resolved.get("success", false)) and resolved.get("facts") != null:
            return int(resolved["facts"].rank_order)
    return int(card.current_rank_order()) \
        if card.has_method("current_rank_order") else int(card.rank_order)

static func _coerce_options(value):
    if value is HandRecognitionOptionsScript:
        return value
    if value is Dictionary:
        return HandRecognitionOptionsScript.new().configure(value)
    return HandRecognitionOptionsScript.new().configure()

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
