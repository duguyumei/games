class_name HandGroupSnapshot
extends RefCounted

## A confirmed hand group owns one immutable membership/order snapshot.  Card
## objects remain live so effects can explicitly ask for the current effective
## qi value; base values and identities are copied at the freeze boundary.

const ATTRIBUTES := ["wind", "forest", "fire", "mountain"]

static func freeze(
        played_cards: Array,
        hand_result: Dictionary,
        side,
        target = null,
        on_play_success_ids: Array = []) -> Dictionary:
    var contributing: Array = hand_result.get("contributing", []).duplicate()
    var extra: Array = []
    for card in played_cards:
        if not contributing.has(card):
            extra.append(card)
    var facts_by_id: Dictionary = {}
    for card in played_cards:
        var attributes: Array[String] = []
        for attribute in ATTRIBUTES:
            if _has_attribute(card, attribute, side, target):
                attributes.append(attribute)
        facts_by_id[str(card.id)] = {
            "card": card,
            "instance_id": str(card.id),
            "base_qi_at_freeze": _base_qi(card),
            "effective_qi_at_freeze": current_effective_qi({}, card, side),
            "growth_at_freeze": card.anomaly_layers("buff", "growth"),
            "heat_at_freeze": card.anomaly_layers("buff", "qi_heat"),
            "poison_at_freeze": card.has_anomaly("state", "poison"),
            "attributes_at_freeze": attributes,
        }
    var common: Array = ATTRIBUTES.duplicate()
    for card in played_cards:
        var attributes: Array = facts_by_id[str(card.id)]["attributes_at_freeze"]
        common = common.filter(func(attribute): return attributes.has(attribute))
    var triggered_cards: Array = []
    for card in played_cards:
        if on_play_success_ids.has(str(card.id)):
            triggered_cards.append(card)
    var played_poison_cards: Array = played_cards.filter(
        func(card): return bool(facts_by_id[str(card.id)]["poison_at_freeze"]))
    var played_poison_amount := 0
    for card in played_poison_cards:
        played_poison_amount += int(facts_by_id[str(card.id)]["effective_qi_at_freeze"])
    return {
        "played_cards": played_cards.duplicate(),
        "contributing_cards": contributing,
        "extra_cards": extra,
        "facts_by_id": facts_by_id,
        "common_attributes": common,
        "on_play_success_cards": triggered_cards,
        "played_poison_cards": played_poison_cards,
        "played_poison_count": played_poison_cards.size(),
        "played_poison_amount": played_poison_amount,
    }

static func current_effective_qi(snapshot: Dictionary, card, side) -> int:
    if side != null and side.status_system != null:
        var value: int = int(card.effective_qi_value()) \
            if card.has_method("effective_qi_value") else int(card.qi_value)
        return maxi(0, side.status_system.modify_card_contribution(card, value, side))
    return maxi(0, int(card.effective_qi_value()) \
        if card.has_method("effective_qi_value") else int(card.qi_value))

static func is_same_qi(snapshot: Dictionary, attribute: String) -> bool:
    return snapshot.get("common_attributes", []).has(attribute)

static func has_non_attribute_identity(
        snapshot: Dictionary, card, excluded_attribute: String) -> bool:
    var facts: Dictionary = snapshot.get("facts_by_id", {}).get(str(card.id), {})
    for attribute in facts.get("attributes_at_freeze", []):
        if str(attribute) != excluded_attribute:
            return true
    return false

static func base_qi_sum(snapshot: Dictionary, cards: Array) -> int:
    var total := 0
    for card in cards:
        total += int(snapshot.get("facts_by_id", {}).get(
            str(card.id), {}).get("base_qi_at_freeze", _base_qi(card)))
    return total

static func frozen_effective_qi(snapshot: Dictionary, card) -> int:
    return int(snapshot.get("facts_by_id", {}).get(
        str(card.id), {}).get("effective_qi_at_freeze", 0))

static func frozen_growth(snapshot: Dictionary, card) -> int:
    return int(snapshot.get("facts_by_id", {}).get(
        str(card.id), {}).get("growth_at_freeze", 0))

static func frozen_heat(snapshot: Dictionary, card) -> int:
    return int(snapshot.get("facts_by_id", {}).get(
        str(card.id), {}).get("heat_at_freeze", 0))

static func _base_qi(card) -> int:
    return int(card.current_base_qi_value()) \
        if card.has_method("current_base_qi_value") else int(card.qi_value)

static func _has_attribute(card, attribute: String, side, target) -> bool:
    if side != null and side.card_identity_policy != null:
        var resolved: Dictionary = side.card_identity_policy.resolve(card, {
            "owner": side, "actor": side, "target": target,
        })
        if resolved.get("success", false):
            return bool(resolved["facts"].has_attribute(attribute))
    return card.is_attribute(attribute)
