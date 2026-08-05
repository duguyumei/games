class_name EnemyCombatAI
extends RefCounted

var rng: RandomNumberGenerator

func _init(random_source: RandomNumberGenerator) -> void:
    rng = random_source

func choose_action(hand: Array, preview_action: Callable, policy: Dictionary) -> Dictionary:
    var candidates: Array = []
    var maximum_cards := mini(5, hand.size())
    for card_count in range(1, maximum_cards + 1):
        _collect_candidates(hand, preview_action, policy, card_count, 0, [], candidates)
    if candidates.is_empty():
        return {}
    var best_score: float = -INF
    for candidate in candidates:
        best_score = maxf(best_score, float(candidate["score"]))
    var best: Array = []
    for candidate in candidates:
        if is_equal_approx(float(candidate["score"]), best_score):
            best.append(candidate)
    return best[rng.randi_range(0, best.size() - 1)]

func _collect_candidates(
        hand: Array,
        preview_action: Callable,
        policy: Dictionary,
        wanted_count: int,
        start_index: int,
        chosen: Array,
        output: Array) -> void:
    if chosen.size() == wanted_count:
        var card_ids: Array = []
        for card in chosen:
            card_ids.append(card.id)
        var preview: Dictionary = preview_action.call(card_ids)
        if not preview.get("valid", false):
            return
        output.append({
            "card_ids": card_ids,
            "preview": preview,
            "score": _score_preview(preview, chosen.size(), policy),
        })
        return
    var cards_still_needed := wanted_count - chosen.size()
    var last_start := hand.size() - cards_still_needed
    for index in range(start_index, last_start + 1):
        chosen.append(hand[index])
        _collect_candidates(hand, preview_action, policy, wanted_count, index + 1, chosen, output)
        chosen.pop_back()

func _score_preview(preview: Dictionary, card_count: int, policy: Dictionary) -> float:
    var intent: Dictionary = preview.get("intent", {})
    var values: Dictionary = preview.get("values", {})
    var condition: Dictionary = preview.get("condition", {"ok": true})
    var score := (
        float(intent.get("damage", 0)) * float(policy.get("damage_weight", 1.0))
        + float(intent.get("defense", 0)) * float(policy.get("defense_weight", 0.7))
        + float(values.get("technique_value", 0)) * float(policy.get("power_weight", 0.02))
        - float(card_count) * float(policy.get("card_cost", 0.5)))
    if bool(intent.get("combo", false)):
        score += float(policy.get("combo_bonus", 8.0))
    if not condition.get("ok", true):
        score -= float(policy.get("failed_condition_penalty", 1000.0))
    return score
