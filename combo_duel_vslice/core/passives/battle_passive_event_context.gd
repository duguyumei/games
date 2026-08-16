class_name BattlePassiveEventContext
extends "res://core/passives/passive_rule_context.gd"

var actors: Array = []
var drawn_cards: Array = []
var winner = null
var battle_state: String = ""
var metadata: Dictionary = {}
var timing_serial: int = -1
var owner_id: String = ""

func configure(values: Dictionary):
    super.configure(values)
    actors = values.get("actors", []).duplicate()
    drawn_cards = values.get("drawn_cards", []).duplicate()
    winner = values.get("winner")
    battle_state = str(values.get("battle_state", ""))
    metadata = values.get("metadata", {}).duplicate(false)
    timing_serial = int(values.get("timing_serial", -1))
    owner_id = str(values.get("owner_id", ""))
    return self

func for_invocation(current_invocation):
    return get_script().new().configure({
        "actor": actor,
        "actors": actors,
        "target": target,
        "owner": owner,
        "owner_id": owner_id,
        "hook": hook,
        "round_number": round_number,
        "timing_serial": timing_serial,
        "winner": winner,
        "battle_state": battle_state,
        "drawn_cards": drawn_cards,
        "metadata": metadata,
        "payload": payload,
        "source": current_invocation.source,
        "invocation": current_invocation,
        "source_snapshot": source_snapshot,
        "battle_effect_ports": battle_effect_ports,
        "battle_effect_scope": battle_effect_scope,
    })

func public_effect_values() -> Dictionary:
    var result := payload.duplicate(true)
    result.merge({
        "event_token": "%s:%d" % [hook, timing_serial],
        "event_serial": timing_serial,
        "action_token": str(payload.get("action_token", "")),
        "round_number": round_number,
        "battle_state": battle_state,
        "owner_id": owner_id,
        "drawn_cards": drawn_cards.duplicate(),
        "metadata": metadata.duplicate(true),
    }, true)
    return result
