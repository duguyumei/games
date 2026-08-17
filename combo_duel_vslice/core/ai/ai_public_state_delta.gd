class_name AiPublicStateDelta
extends RefCounted

func between(before: Dictionary, after: Dictionary) -> Dictionary:
    return {
        "life_delta": _scalar_delta(before, after, "life"),
        "defense_delta": _scalar_delta(before, after, "defense"),
        "zone_count_delta": {
            "hand": int(after.get("hand_count", 0)) - int(before.get("hand_count", 0)),
            "draw_pile": int(after.get("draw_pile_count", 0)) - int(before.get("draw_pile_count", 0)),
            "discard": after.get("discard_cards", []).size() - before.get("discard_cards", []).size(),
            "temporarily_removed": int(after.get("temporarily_removed_count", 0)) - int(before.get("temporarily_removed_count", 0)),
        },
        "revealed_zone_changes": _revealed_zone_changes(before, after),
        "status_changes": _changed(before, after, "public_statuses"),
        "passive_changes": _changed(before, after, "public_passive_progress"),
        "sequence_changes": _dictionary_changes(
            before.get("sequence_positions", {}), after.get("sequence_positions", {})),
        "technique_slot_usage_changes": _dictionary_changes(
            before.get("technique_slot_usage", {}),
            after.get("technique_slot_usage", {})),
    }

func _scalar_delta(before: Dictionary, after: Dictionary, key: String) -> Dictionary:
    return {"before": int(before.get(key, 0)), "after": int(after.get(key, 0)),
        "delta": int(after.get(key, 0)) - int(before.get(key, 0))}

func _changed(before: Dictionary, after: Dictionary, key: String) -> Array:
    return [] if before.get(key, []) == after.get(key, []) else [{
        "before": before.get(key, []).duplicate(true),
        "after": after.get(key, []).duplicate(true),
    }]

func _dictionary_changes(before: Dictionary, after: Dictionary) -> Array:
    var result: Array = []
    var keys: Dictionary = {}
    for key in before.keys() + after.keys():
        keys[str(key)] = true
    var ordered: Array = keys.keys()
    ordered.sort()
    for key in ordered:
        if before.get(key) != after.get(key):
            result.append({"id": key, "before": before.get(key), "after": after.get(key)})
    return result

func _revealed_zone_changes(before: Dictionary, after: Dictionary) -> Array:
    var result: Array = []
    for zone in ["discard_cards", "temporarily_removed_cards"]:
        if before.get(zone, []) != after.get(zone, []):
            result.append({"zone": zone, "before": before.get(zone, []).duplicate(true),
                "after": after.get(zone, []).duplicate(true)})
    return result
