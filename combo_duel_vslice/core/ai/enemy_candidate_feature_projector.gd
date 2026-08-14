class_name EnemyCandidateFeatureProjector
extends RefCounted

const FeaturesScript = preload("res://core/ai/enemy_candidate_features.gd")

var value_query_service

func _init(query_service = null) -> void:
    value_query_service = query_service

func project(
        proposal,
        observation,
        actor,
        target,
        policy: Dictionary = {},
        round_number: int = 0) -> Dictionary:
    if proposal == null or not bool(proposal.accepted):
        return {"success": false, "reason": "战略画像只能投影已接受的合法候选"}
    var result: Dictionary = FeaturesScript.empty()
    var preview: Dictionary = proposal.preview
    var intent: Dictionary = preview.get("intent", {})
    var played_cards: Array = _cards_for_ids(actor.hand, proposal.card_ids)
    if played_cards.size() != proposal.card_ids.size():
        return {"success": false, "reason": "候选包含不在当前手牌的卡牌"}
    var contributing_ids: Array[String] = _card_ids(
        preview.get("hand", {}).get("contributing", []))
    var retained_cards: Array = []
    for card in actor.hand:
        if not proposal.card_ids.has(str(card.id)):
            retained_cards.append(card)
    var damage: int = maxi(0, int(intent.get("damage", 0)))
    var defense: int = maxi(0, int(intent.get("defense", 0)))
    var lethal_threshold: int = maxi(
        0, int(observation.opponent_life) + int(observation.opponent_defense))
    var incoming: int = int(observation.expected_incoming_damage)
    var current_endurance: int = maxi(
        0, int(observation.actor_life) + int(observation.actor_defense))
    result["immediate"] = {
        "damage": damage,
        "defense": defense,
        "segments": maxi(0, int(intent.get("segments", 0))),
        "combo": bool(intent.get("combo", false)),
        "same_qi_gain": int(preview.get("same_qi_gain", 0)),
        "same_qi_trigger_count": int(preview.get(
            "same_qi_trigger_count", 0)),
        "lethal": lethal_threshold > 0 and damage >= lethal_threshold,
        "avoids_immediate_death": (
            incoming >= current_endurance and current_endurance + defense > incoming),
    }
    result["card_flow"] = {
        "played_count": played_cards.size(),
        "contributing_count": contributing_ids.size(),
        "extra_played_count": maxi(0, played_cards.size() - contributing_ids.size()),
        "retained_count": retained_cards.size(),
        "expected_next_normal_draw": mini(played_cards.size(), maxi(0, actor.hand_limit - retained_cards.size())),
    }
    var play_query := _query_cards(
        "ai_card_play_value_query", played_cards, proposal, preview,
        actor, target, round_number, contributing_ids)
    if not play_query.get("success", false):
        return play_query
    var retention_query := _query_cards(
        "ai_card_retention_value_query", retained_cards, proposal, preview,
        actor, target, round_number, contributing_ids)
    if not retention_query.get("success", false):
        return retention_query
    var action_query := _query("ai_action_value_query", {
        "owner": actor, "actor": actor, "target": target,
        "round_number": round_number, "proposal": proposal,
        "preview": preview, "played_cards": played_cards,
        "retained_cards": retained_cards,
        "_purity_guarded": true,
    })
    if not action_query.get("success", false):
        return action_query
    var retained_potential := _retained_hand_potential(retained_cards, actor)
    var future_discount := clampf(float(policy.get("future_value_discount", 0.5)), 0.0, 1.0)
    result["future"] = {
        "retained_hand_value": (
            retained_potential + float(retention_query.get("estimated_value", 0.0))),
        "next_hand_potential": (
            retained_potential
            + float(result["card_flow"]["expected_next_normal_draw"]) * 0.5) * future_discount,
        "sequence_progress_value": (
            1.0 if str(preview.get("technique_id", "")) != ""
            and preview.get("condition", {}).get("ok", true) else 0.0),
    }
    result["card_state"] = {
        "positive_play_value": (
            _effective_qi_total(played_cards) * 0.05
            + float(play_query.get("estimated_value", 0.0))),
        "negative_card_cleanup_value": float(
            play_query.get("negative_card_cleanup_value", 0.0)),
        "positive_retention_value": float(
            retention_query.get("estimated_value", 0.0)),
        "negative_retention_cost": float(
            retention_query.get("negative_retention_cost", 0.0)),
    }
    result["passives"] = {
        "immediate_value": float(action_query.get("estimated_value", 0.0)),
        "progress_value": float(action_query.get("progress_value", 0.0)),
        "control_value": float(action_query.get("control_value", 0.0)),
        "trigger_signatures": _unique_strings(
            play_query.get("trigger_signatures", [])
            + retention_query.get("trigger_signatures", [])
            + action_query.get("trigger_signatures", [])),
        "source_breakdown": (
            play_query.get("source_breakdown", [])
            + retention_query.get("source_breakdown", [])
            + action_query.get("source_breakdown", [])),
        "progress_entries": action_query.get("progress_entries", []).duplicate(true),
    }
    result["identity"] = {
        "hand_type": str(preview.get("hand", {}).get("id", "")),
        "technique_id": str(preview.get("technique_id", "")),
        "next_technique_id": str(preview.get("next_technique_id", "")),
    }
    result["internal"] = {
        "card_ids": proposal.card_ids.duplicate(),
        "status_change_signatures": result["passives"]["trigger_signatures"].duplicate(),
        "hard_reasons": [],
    }
    result["quality"] = _quality(result, float(proposal.score))
    return {"success": true, "features": result}

func _query_cards(
        hook: String,
        cards: Array,
        proposal,
        preview: Dictionary,
        actor,
        target,
        round_number: int,
        contributing_ids: Array[String]) -> Dictionary:
    var total := _empty_query_result()
    for card in cards:
        var response := _query(hook, {
            "owner": actor, "actor": actor, "target": target,
            "round_number": round_number, "card": card,
            "proposal": proposal, "preview": preview,
            "_purity_guarded": true,
            "is_contributing": contributing_ids.has(str(card.id)),
            "is_extra_played": (
                hook == "ai_card_play_value_query"
                and not contributing_ids.has(str(card.id))),
        })
        if not response.get("success", false):
            return response
        _merge_query(total, response)
    total["success"] = true
    return total

func _query(hook: String, values: Dictionary) -> Dictionary:
    if value_query_service == null:
        var result := _empty_query_result()
        result["success"] = true
        return result
    return value_query_service.query(hook, values)

func _empty_query_result() -> Dictionary:
    return {
        "success": false, "estimated_value": 0.0, "progress_value": 0.0,
        "control_value": 0.0, "negative_card_cleanup_value": 0.0,
        "negative_retention_cost": 0.0, "trigger_signatures": [],
        "progress_entries": [], "source_breakdown": [], "errors": [],
    }

func _merge_query(target: Dictionary, source: Dictionary) -> void:
    for field in [
            "estimated_value", "progress_value", "control_value",
            "negative_card_cleanup_value", "negative_retention_cost"]:
        target[field] = float(target[field]) + float(source.get(field, 0.0))
    for field in ["trigger_signatures", "progress_entries", "source_breakdown"]:
        target[field].append_array(source.get(field, []))

func _retained_hand_potential(cards: Array, actor) -> float:
    if cards.is_empty():
        return 0.0
    var ranks: Dictionary = {}
    for card in cards:
        var rank := int(card.current_rank_order())
        ranks[rank] = int(ranks.get(rank, 0)) + 1
    var pair_links := 0
    var multiplicity_value := 0.0
    for count in ranks.values():
        pair_links += maxi(0, int(count) - 1)
        multiplicity_value += float(maxi(0, int(count) - 1) * int(count))
    var sorted_ranks: Array = ranks.keys()
    sorted_ranks.sort()
    var adjacent_links := 0
    for index in range(1, sorted_ranks.size()):
        if int(sorted_ranks[index]) - int(sorted_ranks[index - 1]) == 1:
            adjacent_links += 1
    # 这里只做一步未来启发，不重新判定正式牌型；正式身份/牌型已在 preview 中统一处理。
    return (
        multiplicity_value + float(pair_links)
        + float(adjacent_links) * 0.5 + float(cards.size()) * 0.15)

func _quality(features: Dictionary, legacy_score: float) -> float:
    return (
        float(features["immediate"]["damage"])
        + float(features["immediate"]["defense"]) * 0.75
        + (25.0 if features["immediate"]["lethal"] else 0.0)
        + (20.0 if features["immediate"]["avoids_immediate_death"] else 0.0)
        + float(features["future"]["retained_hand_value"])
        + float(features["future"]["next_hand_potential"])
        + float(features["future"]["sequence_progress_value"]) * 2.0
        + float(features["card_state"]["negative_card_cleanup_value"]) * 2.0
        - float(features["card_state"]["negative_retention_cost"])
        + float(features["passives"]["immediate_value"])
        + float(features["passives"]["progress_value"])
        + float(features["passives"]["control_value"])
        + legacy_score * 0.05)

func _cards_for_ids(cards: Array, ids: Array) -> Array:
    var by_id: Dictionary = {}
    for card in cards:
        by_id[str(card.id)] = card
    var result: Array = []
    for card_id in ids:
        if by_id.has(str(card_id)):
            result.append(by_id[str(card_id)])
    return result

func _card_ids(cards: Array) -> Array[String]:
    var result: Array[String] = []
    for card in cards:
        result.append(str(card.id))
    return result

func _effective_qi_total(cards: Array) -> int:
    var total := 0
    for card in cards:
        total += maxi(0, int(card.effective_qi_value()))
    return total

func _unique_strings(values: Array) -> Array[String]:
    var result: Array[String] = []
    for value in values:
        var text := str(value)
        if text != "" and not result.has(text):
            result.append(text)
    result.sort()
    return result
