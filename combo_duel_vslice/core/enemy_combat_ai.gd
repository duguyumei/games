class_name EnemyCombatAI
extends RefCounted

var rng: RandomNumberGenerator

func _init(random_source: RandomNumberGenerator) -> void:
    rng = random_source

func choose_action(observation, preview_action: Callable, policy: Dictionary) -> Dictionary:
    var candidates := enumerate_actions(observation, preview_action, policy)
    if candidates.is_empty():
        return {}
    var best_priority := -1
    for candidate in candidates:
        best_priority = maxi(best_priority, int(candidate["priority"]))
    var best_score: float = -INF
    for candidate in candidates:
        if int(candidate["priority"]) != best_priority:
            continue
        best_score = maxf(best_score, float(candidate["score"]))
    var best: Array = []
    for candidate in candidates:
        if int(candidate["priority"]) == best_priority \
                and is_equal_approx(float(candidate["score"]), best_score):
            best.append(candidate)
    return best[rng.randi_range(0, best.size() - 1)]

func enumerate_actions(observation, preview_action: Callable, policy: Dictionary) -> Array:
    var candidates: Array = []
    var hand: Array = observation.actor_hand
    var maximum_cards := mini(5, hand.size())
    for card_count in range(1, maximum_cards + 1):
        _collect_candidates(hand, preview_action, policy, card_count, 0, [], candidates)
    if candidates.is_empty():
        return []
    _score_strategic_context(candidates, observation, policy)
    return candidates

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
        var immediate := _score_preview(preview, chosen.size(), policy)
        output.append({
            "card_ids": card_ids,
            "preview": preview,
            "immediate_score": immediate,
            "score": immediate,
            "priority": 0,
            "score_components": {"immediate": immediate},
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

func _score_strategic_context(
        candidates: Array,
        observation,
        policy: Dictionary) -> void:
    var target_endurance := maxi(
        0,
        int(observation.opponent_life) + int(observation.opponent_defense))
    var life_ratio := (
        float(observation.actor_life) / float(maxi(1, observation.actor_max_life)))
    var danger_ratio := float(policy.get("danger_life_ratio", 0.3))
    var expected_incoming := int(observation.expected_incoming_damage)
    var current_endurance := maxi(
        0,
        int(observation.actor_life) + int(observation.actor_defense))
    for candidate in candidates:
        var preview: Dictionary = candidate["preview"]
        var intent: Dictionary = preview.get("intent", {})
        var damage := maxi(0, int(intent.get("damage", 0)))
        var defense := maxi(0, int(intent.get("defense", 0)))
        var card_count: int = candidate["card_ids"].size()
        var remaining_cards: int = observation.actor_hand.size() - card_count
        var priority := 0
        if target_endurance > 0 and damage >= target_endurance:
            priority = 2
        elif life_ratio <= danger_ratio \
                and expected_incoming >= current_endurance \
                and current_endurance + defense > expected_incoming:
            priority = 1

        var overkill := maxi(0, damage - target_endurance)
        var overkill_penalty := (
            float(overkill) * float(policy.get("overkill_penalty", 0.35)))
        var retention_bonus := (
            float(remaining_cards) * float(policy.get("retained_card_weight", 0.0)))
        var sequence_bonus := 0.0
        if preview.get("condition", {}).get("ok", true) \
                and str(preview.get("technique_id", "")) != "":
            sequence_bonus = float(policy.get("sequence_progress_weight", 0.0))
        var next_technique_bias := float(
            policy.get("next_technique_bias", {}).get(
                str(preview.get("next_technique_id", "")),
                0.0))
        var follow_up := 0.0
        if bool(intent.get("combo", false)):
            follow_up = _best_disjoint_immediate_score(candidate, candidates)
            if follow_up <= 0.0:
                follow_up -= float(policy.get(
                    "combo_without_follow_up_penalty",
                    10.0))
        var follow_up_value := (
            follow_up * float(policy.get("combo_follow_up_weight", 0.25)))
        candidate["priority"] = priority
        candidate["score"] = (
            float(candidate["immediate_score"])
            - overkill_penalty
            + retention_bonus
            + sequence_bonus
            + next_technique_bias
            + follow_up_value)
        candidate["score_components"] = {
            "immediate": candidate["immediate_score"],
            "overkill_penalty": overkill_penalty,
            "retention_bonus": retention_bonus,
            "sequence_progress_bonus": sequence_bonus,
            "next_technique_bias": next_technique_bias,
            "combo_follow_up": follow_up_value,
        }

func _best_disjoint_immediate_score(candidate: Dictionary, candidates: Array) -> float:
    var used: Dictionary = {}
    for card_id in candidate["card_ids"]:
        used[str(card_id)] = true
    var best := -INF
    for other in candidates:
        var overlaps := false
        for other_card_id in other["card_ids"]:
            if used.has(str(other_card_id)):
                overlaps = true
                break
        if not overlaps:
            best = maxf(best, float(other["immediate_score"]))
    return 0.0 if is_inf(best) else best
