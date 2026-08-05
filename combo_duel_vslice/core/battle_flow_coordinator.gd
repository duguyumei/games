class_name BattleFlowCoordinator
extends RefCounted

const ActorTurnStateScript = preload("res://core/actor_turn_state.gd")

var _states: Dictionary = {}

func reset(actors: Array = []) -> void:
    _states.clear()
    for actor in actors:
        register_actor(actor)

func register_actor(actor):
    var actor_key := _actor_key(actor)
    if not _states.has(actor_key):
        _states[actor_key] = ActorTurnStateScript.new(actor)
    return _states[actor_key]

func begin_round(entries: Array) -> void:
    clear_intents()
    for entry_value in entries:
        var entry: Dictionary = entry_value
        var actor = entry.get("actor")
        if actor == null:
            continue
        state_for(actor).begin_round(int(entry.get("actions", 0)))

func state_for(actor):
    return register_actor(actor)

func set_action_count(actor, value: int) -> void:
    state_for(actor).action_count = maxi(0, value)

func available_action_count(actor) -> int:
    return state_for(actor).available_action_count()

func can_act(actor) -> bool:
    return state_for(actor).can_act()

func consume_action(actor) -> bool:
    return state_for(actor).consume_action()

func grant_actions(actor, amount: int) -> int:
    return state_for(actor).grant_actions(amount)

func forfeit_remaining(actor, reason: String) -> void:
    state_for(actor).forfeit_remaining(reason)

func disable_current_round(actor, reason: String) -> void:
    state_for(actor).disable_current(reason)

func enable_current_round(actor, reason: String) -> void:
    state_for(actor).enable_current(reason)

func disable_next_rounds(actor, reason: String, round_count: int = 1) -> void:
    state_for(actor).disable_future(reason, round_count)

func claim_combo(actor, combo_id: String) -> bool:
    return state_for(actor).claim_combo(combo_id)

func has_claimed_combo(actor, combo_id: String) -> bool:
    return state_for(actor).has_claimed_combo(combo_id)

func set_combo_claimed(actor, combo_id: String, claimed: bool) -> void:
    if claimed:
        state_for(actor).claim_combo(combo_id)
    else:
        state_for(actor).combo_claims.erase(combo_id)

func lock_intent(actor, intent: Dictionary) -> bool:
    return state_for(actor).lock_intent(intent)

func clear_intents() -> void:
    for state in _states.values():
        state.clear_intent()

func resolution_mode() -> String:
    var intent_count := 0
    for state in _states.values():
        if not state.pending_intent.is_empty():
            intent_count += 1
    if intent_count >= 2:
        return "synchronized"
    if intent_count == 1:
        return "single"
    return "none"

func snapshot_for(actor) -> Dictionary:
    return state_for(actor).snapshot()

func _actor_key(actor) -> int:
    return actor.get_instance_id()
