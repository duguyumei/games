class_name AiBattleStateProjector
extends RefCounted

const VisibilityScript = preload("res://core/ai/ai_visibility_policy.gd")

var visibility := VisibilityScript.new()

func project_self(side, sequence_book, battle_flow) -> Dictionary:
    return _base(side, sequence_book, battle_flow, true)

func project_opponent(side, sequence_book, battle_flow) -> Dictionary:
    return visibility.sanitize_opponent(_base(side, sequence_book, battle_flow, false))

func _base(side, sequence_book, battle_flow, is_self: bool) -> Dictionary:
    var effective_hand_limit := _hand_limit(side)
    var poison: Dictionary = side.poison_totals()
    var same_qi_capacity: Dictionary = side.effective_same_qi_capacity_result({
        "source_kind": "ai_observation",
    })
    var value := {
        "life": int(side.life),
        "max_life": int(side.max_life),
        "defense": int(side.defense),
        "momentum": int(side.momentum_value),
        "same_qi_value": int(side.same_qi_value),
        "same_qi_capacity": int(same_qi_capacity.get("effective_value", 5)),
        "hand_limit": effective_hand_limit,
        "hand_count": side.hand.size(),
        "occupied_meridian_count": side.occupied_meridian_count(),
        "meridian_capacity": effective_hand_limit,
        "next_normal_draw_count": mini(
            side.draw_pile.size(), maxi(0, effective_hand_limit - side.occupied_meridian_count())),
        "direct_power_fixed": int(side.direct_power_fixed),
        "direct_power_percent": int(side.direct_power_percent),
        "reflection_percent": int(side.current_reflection_percent),
        "reflection_sources": side.public_reflection_sources(),
        "reflection_true_damage_sources": side.public_reflection_true_damage_sources(),
        "block_sources": side.public_block_sources(),
        "challenge_records": side.public_challenge_records(),
        "last_successful_hand_id": str(side.last_successful_technique_hand_id),
        "draw_pile_count": side.draw_pile.size(),
        "discard_cards": visibility.revealed_cards(side.discard_pile),
        "temporarily_removed_count": side.temporarily_removed_cards.size(),
        "poison": poison.duplicate(true),
        "sequence_positions": sequence_book.positions.duplicate(true),
        "technique_sequences": sequence_book.public_snapshot(),
        "technique_slot_usage": sequence_book.public_slot_usage_snapshot(),
        "action_state": battle_flow.snapshot_for(side),
        "public_statuses": _public_statuses(side),
        "public_passive_progress": _passive_progress(side, false),
        "public_source_markers": side.source_marker_store.public_projection(),
        "poison_damage_modifier_sources": side.public_poison_damage_modifier_sources(),
    }
    if is_self:
        value["hand_cards"] = visibility.revealed_cards(side.hand)
        value["temporarily_removed_cards"] = visibility.revealed_cards(
            side.temporarily_removed_cards)
        value["passive_progress"] = _passive_progress(side, true)
    return value

func _hand_limit(side) -> int:
    var before: Dictionary = side.last_hand_limit_query_result.duplicate(true)
    var result := int(side.current_hand_limit())
    side.last_hand_limit_query_result = before
    return result

func _public_statuses(side) -> Array:
    var result: Array = []
    for card in side.discard_pile:
        var snapshot: Dictionary = card.anomaly_snapshot()
        if not snapshot.get("state", {}).is_empty() \
                or not snapshot.get("marks", {}).is_empty():
            result.append({"card_id": str(card.id), "anomalies": snapshot})
    return result

func _passive_progress(side, include_private: bool) -> Array:
    var result: Array = []
    var states: Array = []
    if side.passive_counter_store != null:
        states.append_array(side.passive_counter_store.capture_state().get("entries", []))
    if side.battle_passive_counter_store != null:
        states.append_array(side.battle_passive_counter_store.capture_state().get("entries", {}).values())
    for entry_value in states:
        if not entry_value is Dictionary:
            continue
        var entry: Dictionary = entry_value
        var is_public := bool(entry.get("public", true))
        if not include_private and not is_public:
            continue
        var key: Dictionary = entry.get("key", entry)
        var current := int(entry.get("value", 0))
        var threshold := int(entry.get("threshold", entry.get("maximum", 0)))
        result.append({
            "source_kind": str(key.get("source_kind", "passive")),
            "source_id": str(key.get("content_id", key.get("source_instance_key", ""))),
            "display_name": str(entry.get("display_name", key.get("content_id", ""))),
            "counter_name": str(key.get("counter_id", "")),
            "current": current,
            "threshold": threshold,
            "remaining": maxi(0, threshold - current),
            "active": bool(entry.get("active", true)),
            "public": is_public,
        })
    result.sort_custom(func(left, right):
        return "%s:%s:%s" % [left["source_kind"], left["source_id"], left["counter_name"]] \
            < "%s:%s:%s" % [right["source_kind"], right["source_id"], right["counter_name"]])
    return result
