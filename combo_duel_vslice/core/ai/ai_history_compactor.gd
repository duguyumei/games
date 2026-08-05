class_name AiHistoryCompactor
extends RefCounted

const DEFAULT_INTERVAL_ROUNDS := 5

var interval_rounds: int = DEFAULT_INTERVAL_ROUNDS

func _init(configured_interval: int = DEFAULT_INTERVAL_ROUNDS) -> void:
    interval_rounds = maxi(1, configured_interval)

func should_compact(completed_round: int, last_compacted_round: int) -> bool:
    return completed_round > 0 \
        and completed_round % interval_rounds == 0 \
        and completed_round > last_compacted_round

func compact(events: Array, through_round: int) -> Dictionary:
    var included: Array = []
    for event_value in events:
        if event_value is Dictionary \
                and int(event_value.get("round_number", 0)) <= through_round:
            included.append(event_value)
    var counts_by_type: Dictionary = {}
    var counts_by_actor: Dictionary = {}
    var hand_types: Dictionary = {}
    var techniques: Dictionary = {}
    var consumables: Dictionary = {}
    var revealed_cards: Dictionary = {}
    var from_sequence := -1
    var through_sequence := -1
    for event in included:
        var sequence := int(event.get("sequence", -1))
        if from_sequence < 0 or sequence < from_sequence:
            from_sequence = sequence
        through_sequence = maxi(through_sequence, sequence)
        _increment(counts_by_type, str(event.get("event_type", "unknown")))
        _increment(counts_by_actor, str(event.get("actor_id", "unknown")))
        var payload: Dictionary = event.get("payload", {})
        var hand_type := str(payload.get("hand_type", ""))
        if hand_type != "":
            _increment(hand_types, hand_type)
        var technique_id := str(payload.get("technique_id", ""))
        if technique_id != "":
            _increment(techniques, technique_id)
        var consumable_id := str(payload.get("consumable_id", ""))
        if consumable_id != "":
            _increment(consumables, consumable_id)
        for card_id in payload.get("played_card_ids", []):
            revealed_cards[str(card_id)] = true
    return {
        "schema_version": 1,
        "through_round": through_round,
        "from_sequence": from_sequence,
        "through_sequence": through_sequence,
        "event_count": included.size(),
        "counts_by_type": counts_by_type,
        "counts_by_actor": counts_by_actor,
        "hand_types": hand_types,
        "techniques": techniques,
        "consumables": consumables,
        "revealed_card_ids": revealed_cards.keys(),
    }

func _increment(target: Dictionary, key: String) -> void:
    target[key] = int(target.get(key, 0)) + 1
