class_name AiVisibilityPolicy
extends RefCounted

func card_snapshot(card) -> Dictionary:
    return card.to_dict() if card != null else {}

func revealed_cards(cards: Array) -> Array:
    return cards.map(func(card): return card_snapshot(card))

func passive_counter_is_public(entry: Dictionary) -> bool:
    return bool(entry.get("public", entry.get("visibility", "public") == "public"))

func sanitize_opponent(value):
    return _sanitize(value)

func _sanitize(value):
    if value is Dictionary:
        var result: Dictionary = {}
        for key in value:
            if str(key) in [
                    "hand", "hand_cards", "draw_pile", "draw_order",
                    "selected_card_ids", "staging", "rng_seed",
                    "private_counters", "candidate_diagnostics"]:
                continue
            result[key] = _sanitize(value[key])
        return result
    if value is Array:
        return value.map(func(item): return _sanitize(item))
    return value

