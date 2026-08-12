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
    var passive_triggers: Dictionary = {}
    var status_transitions: Dictionary = {}
    var life_defense_deltas := {
        "player": {"life": 0, "defense": 0},
        "enemy": {"life": 0, "defense": 0},
    }
    var revealed_card_zones: Dictionary = {}
    var action_tail: Array = []
    var latest_public_state: Dictionary = {}
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
        if str(event.get("event_type", "")) == "passive_triggered":
            _increment(passive_triggers, str(payload.get("source_id", "unknown")))
        if str(event.get("event_type", "")) == "card_state_changed":
            _increment(status_transitions, "%s:%s" % [
                str(payload.get("status_id", "unknown")),
                str(payload.get("transition", "changed"))])
        if str(event.get("event_type", "")) == "action_resolved":
            latest_public_state = {
                "player_life": int(payload.get("player_life", 0)),
                "player_defense": int(payload.get("player_defense", 0)),
                "enemy_life": int(payload.get("enemy_life", 0)),
                "enemy_defense": int(payload.get("enemy_defense", 0)),
                "battle_state": str(payload.get("battle_state", "")),
            }
            action_tail.append(_action_summary(event))
            if action_tail.size() > 4:
                action_tail.pop_front()
        _accumulate_deltas(life_defense_deltas, payload.get("state_delta", {}))
        _collect_revealed_zones(revealed_card_zones, payload.get("state_delta", {}))
    return {
        "schema_version": 3,
        "through_round": through_round,
        "from_sequence": from_sequence,
        "through_sequence": through_sequence,
        "event_count": included.size(),
        "counts_by_type": counts_by_type,
        "counts_by_actor": counts_by_actor,
        "latest_public_state": latest_public_state,
        "hand_type_frequencies": hand_types,
        "technique_frequencies": techniques,
        "consumables": consumables,
        "passive_trigger_counts": passive_triggers,
        "status_transitions": status_transitions,
        "life_defense_deltas": life_defense_deltas,
        "revealed_card_zones": revealed_card_zones,
        "recent_action_tail": action_tail,
        "revealed_card_ids": revealed_cards.keys(),
    }

func _increment(target: Dictionary, key: String) -> void:
    target[key] = int(target.get(key, 0)) + 1

func _action_summary(event: Dictionary) -> Dictionary:
    var payload: Dictionary = event.get("payload", {})
    return {
        "sequence": int(event.get("sequence", -1)),
        "round_number": int(event.get("round_number", 0)),
        "action_index": int(event.get("action_index", 0)),
        "window_id": str(event.get("window_id", "")),
        "actor_id": str(event.get("actor_id", "system")),
        "state": {
            "player_life": int(payload.get("player_life", 0)),
            "player_defense": int(payload.get("player_defense", 0)),
            "enemy_life": int(payload.get("enemy_life", 0)),
            "enemy_defense": int(payload.get("enemy_defense", 0)),
        },
        "state_delta": payload.get("state_delta", {}).duplicate(true),
    }

func _accumulate_deltas(target: Dictionary, delta) -> void:
    if not delta is Dictionary:
        return
    for side in ["player", "enemy"]:
        var side_delta: Dictionary = delta.get(side, {})
        target[side]["life"] = int(target[side]["life"]) \
            + int(side_delta.get("life_delta", {}).get("delta", 0))
        target[side]["defense"] = int(target[side]["defense"]) \
            + int(side_delta.get("defense_delta", {}).get("delta", 0))

func _collect_revealed_zones(target: Dictionary, delta) -> void:
    if not delta is Dictionary:
        return
    for side in ["player", "enemy"]:
        for change in delta.get(side, {}).get("revealed_zone_changes", []):
            var key := "%s:%s" % [side, str(change.get("zone", "unknown"))]
            target[key] = change.get("after", []).duplicate(true)
