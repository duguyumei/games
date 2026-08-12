class_name AiContentSemanticProjector
extends RefCounted

const StableEncoderScript = preload("res://core/ai/ai_stable_value_encoder.gd")

var catalog
var encoder := StableEncoderScript.new()

func _init(content_catalog) -> void:
    catalog = content_catalog

func project(player, enemy, player_sequence_book, enemy_sequence_book) -> Dictionary:
    var referenced := {
        "technique": _unique_sorted(
            player.owned_technique_ids + enemy.owned_technique_ids
            + _sequence_ids(player_sequence_book) + _sequence_ids(enemy_sequence_book)
            + ["basic_scatter", "basic_guard"]),
        "inner_skill": _unique_sorted(
            player.equipped_inner_skill_ids + enemy.equipped_inner_skill_ids),
        "item": _unique_sorted(player.item_ids + enemy.item_ids),
        "consumable": _unique_sorted(player.consumable_ids + enemy.consumable_ids),
        "card_state": _referenced_card_states(
            player.all_cards_for_run_sync() + enemy.all_cards_for_run_sync()),
    }
    var result := {
        "techniques": _definitions("technique", referenced["technique"]),
        "inner_skills": _definitions("inner_skill", referenced["inner_skill"]),
        "items": _definitions("item", referenced["item"]),
        "consumables": _definitions("consumable", referenced["consumable"]),
        "card_states": _card_state_definitions(referenced["card_state"]),
    }
    return result

func fingerprint(semantics: Dictionary) -> String:
    return encoder.sha256(semantics)

func _definitions(kind: String, ids: Array) -> Array:
    var result: Array = []
    for content_id in ids:
        var definition: Dictionary = catalog.get_by_id(kind, str(content_id))
        if definition.is_empty():
            continue
        result.append({
            "id": str(definition.get("id", content_id)),
            "name": str(definition.get("name", definition.get("display_name", content_id))),
            "description": str(definition.get("description", "")),
            "eligible_hand_ids": definition.get("eligible_hand_ids", []).duplicate(),
            "semantic_tags": _semantic_tags(definition),
            "public_behavior_summary": _behavior_summaries(definition),
        })
    return result

func _card_state_definitions(references: Array) -> Array:
    var result: Array = []
    for reference in references:
        var kind := str(reference.get("kind", ""))
        var content_id := str(reference.get("id", ""))
        var definition: Dictionary = catalog.get_by_id(kind, content_id)
        if definition.is_empty():
            continue
        result.append({
            "kind": kind,
            "id": content_id,
            "name": str(definition.get("name", content_id)),
            "description": str(definition.get("description", "")),
            "semantic_tags": _semantic_tags(definition),
            "public_behavior_summary": _behavior_summaries(definition),
        })
    return result

func _behavior_summaries(definition: Dictionary) -> Array:
    var result: Array = []
    for value in definition.get("public_behavior_summary", []):
        result.append(str(value))
    if result.is_empty():
        for behavior_value in definition.get("behaviors", []):
            if not behavior_value is Dictionary:
                continue
            var behavior: Dictionary = behavior_value
            var trigger := str(behavior.get("trigger", behavior.get("id", "")))
            if trigger != "":
                result.append(trigger)
    return _unique_sorted(result)

func _semantic_tags(definition: Dictionary) -> Array:
    var tags: Array = []
    tags.append_array(definition.get("semantic_tags", []))
    for effect_value in definition.get("effects", []):
        if effect_value is Dictionary:
            var operation := str(effect_value.get("op", ""))
            if operation != "":
                tags.append(operation)
    for behavior_value in definition.get("behaviors", []):
        if behavior_value is Dictionary:
            var behavior: Dictionary = behavior_value
            for field in ["trigger", "id"]:
                var value := str(behavior.get(field, ""))
                if value != "":
                    tags.append(value)
    return _unique_sorted(tags)

func _sequence_ids(book) -> Array:
    var result: Array = []
    if book == null:
        return result
    for sequence in book.sequences.values():
        if sequence is Array:
            result.append_array(sequence)
    return result

func _referenced_card_states(cards: Array) -> Array:
    var by_key: Dictionary = {}
    for card in cards:
        var values := [
            {"kind": "origin", "id": str(card.reshape_origin.get("id", ""))},
            {"kind": "enhancement", "id": str(card.reshape_enhancement)},
            {"kind": "imprint", "id": str(card.reshape_imprint)},
        ]
        for other_id in card.reshape_others.keys():
            values.append({"kind": "other_reshape", "id": str(other_id)})
        var anomalies: Dictionary = card.anomaly_snapshot()
        for category in ["buffs", "debuffs", "marks"]:
            for anomaly_id in anomalies.get(category, {}).keys():
                values.append({"kind": "anomaly", "id": str(anomaly_id)})
        if not anomalies.get("state", {}).is_empty():
            values.append({"kind": "anomaly", "id": str(anomalies["state"].get("id", ""))})
        for value in values:
            if str(value["id"]) != "":
                by_key["%s:%s" % [value["kind"], value["id"]]] = value
    var keys: Array = by_key.keys()
    keys.sort()
    return keys.map(func(key): return by_key[key].duplicate(true))

func _unique_sorted(values: Array) -> Array:
    var seen: Dictionary = {}
    for value in values:
        var text := str(value)
        if text != "":
            seen[text] = true
    var result: Array = seen.keys()
    result.sort()
    return result
