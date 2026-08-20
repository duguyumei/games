class_name BattleFlowCoordinator
extends RefCounted

const ActorTurnStateScript = preload("res://core/actor_turn_state.gd")

var _states: Dictionary = {}
var _passive_runtime_ref: WeakRef
var _effect_ports_ref: WeakRef
var _round_number_reader: Callable
var _extra_action_serial: int = 0

func use_passive_battle_services(
        passive_runtime,
        effect_ports,
        round_number_reader: Callable = Callable()) -> void:
    _passive_runtime_ref = weakref(passive_runtime) \
        if passive_runtime != null else null
    _effect_ports_ref = weakref(effect_ports) if effect_ports != null else null
    _round_number_reader = round_number_reader

func reset(actors: Array = []) -> void:
    _states.clear()
    _extra_action_serial = 0
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
    state_for(actor).set_action_count(value)

func available_action_count(actor) -> int:
    return state_for(actor).available_action_count()

func can_act(actor) -> bool:
    return state_for(actor).can_act()

func consume_action(actor) -> bool:
    return state_for(actor).consume_action()

func grant_actions(actor, amount: int, source: Dictionary = {}) -> int:
    var gained := 0
    for ordinal in range(maxi(0, amount)):
        _extra_action_serial += 1
        var normalized := source.duplicate(true)
        normalized["category"] = str(normalized.get(
            "category", "extra_action"))
        normalized["source"] = str(normalized.get(
            "source", normalized["category"]))
        normalized["is_extra_action"] = true
        normalized["from_same_qi"] = bool(normalized.get(
            "from_same_qi", normalized["category"] == "same_qi"))
        normalized["extra_action_ordinal"] = ordinal
        normalized["extra_action_token"] = "%s:extra-action:%06d" % [
            str(actor.owner_id), _extra_action_serial]
        var projection := project_extra_action_preflight(actor, normalized)
        normalized["preflight_projection"] = projection.duplicate(true)
        normalized["preflight_started"] = false
        gained += state_for(actor).grant_actions(1, normalized)
    return gained

func project_extra_action_preflight(
        actor,
        source: Dictionary = {}) -> Dictionary:
    var passive_runtime = _passive_runtime()
    var effect_ports = _effect_ports()
    if passive_runtime == null:
        return {"success": true, "projected_draw_count": 0,
            "breakdown": []}
    var target = effect_ports.opponent_of(actor) \
        if effect_ports != null else null
    var payload := _extra_action_payload(actor, source)
    var plan = passive_runtime.build_execution_plan(
        "extra_action_preflight_projection", {
            "owner": actor, "actor": actor, "target": target,
            "round_number": _round_number(), "payload": payload,
        })
    if not plan.is_valid():
        return {"success": false, "projected_draw_count": 0,
            "breakdown": [], "reason": "；".join(plan.errors)}
    var projected_draw_count := 0
    var breakdown: Array = []
    for invocation in plan.invocations:
        var invocation_context = invocation.context.for_invocation(invocation)
        var executed: Dictionary = passive_runtime.execute_invocation(
            invocation, invocation_context, "read")
        if not executed.get("success", false):
            return {"success": false, "projected_draw_count": 0,
                "breakdown": breakdown, "reason": str(executed.get(
                    "reason", "额外行动预投影失败"))}
        var amount := maxi(0, int(executed.get(
            "result", {}).get("projected_draw_count", 0)))
        projected_draw_count += amount
        breakdown.append({
            "source_kind": str(invocation.source.source_kind),
            "source_id": str(invocation.source.content_id),
            "source_instance_key": str(invocation.source.source_instance_key),
            "projected_draw_count": amount,
        })
    return {"success": true,
        "projected_draw_count": projected_draw_count,
        "breakdown": breakdown}

func can_establish_extra_action(
        actor,
        source: Dictionary = {},
        legal_card_available = null) -> bool:
    var has_legal := _has_legal_card(actor) \
        if legal_card_available == null else bool(legal_card_available)
    if has_legal:
        return true
    var projection: Dictionary = source.get(
        "preflight_projection", {})
    if projection.is_empty():
        projection = project_extra_action_preflight(actor, source)
    if not projection.get("success", false) \
            or int(projection.get("projected_draw_count", 0)) <= 0:
        return false
    return _has_drawable_card(actor)

func prepare_next_action(actor) -> Dictionary:
    var source: Dictionary = next_action_source(actor)
    if source.is_empty() or not bool(source.get("is_extra_action", false)):
        return {"success": true, "skipped": true, "reason": "队首不是额外行动"}
    if bool(source.get("preflight_started", false)):
        return {"success": true, "reused": true, "source": source}
    var projection: Dictionary = source.get("preflight_projection", {})
    if projection.is_empty():
        projection = project_extra_action_preflight(actor, source)
    if not projection.get("success", false):
        return {"success": false, "reason": str(projection.get(
            "reason", "额外行动预投影失败")), "projection": projection}
    if not can_establish_extra_action(actor, source):
        var discarded: Dictionary = state_for(actor).discard_next_action(
            "没有可用于建立额外行动的真气")
        return {"success": true, "established": false,
            "discarded": discarded, "projection": projection}
    var passive_runtime = _passive_runtime()
    var effect_ports = _effect_ports()
    if passive_runtime == null or effect_ports == null:
        var marked: Dictionary = state_for(actor).mark_next_action_started({
            "projection": projection, "passive_invocation_count": 0})
        return {"success": marked.get("success", false),
            "established": marked.get("success", false),
            "source": marked.get("source", source),
            "projection": projection, "passive_results": []}
    var transaction: Dictionary = effect_ports.begin_effect_mutation_transaction()
    var passive_state: Dictionary = \
        passive_runtime.capture_battle_effect_command_state()
    var target = effect_ports.opponent_of(actor)
    var payload := _extra_action_payload(actor, source)
    payload["preflight_projection"] = projection.duplicate(true)
    payload["effect_context_values"] = {
        "ports": effect_ports,
        "actor": actor,
        "target": target,
        "action_token": str(source.get("extra_action_token", "")),
        "root_action_token": str(source.get("action_token", "")),
        "source_kind": "extra_action",
        "trigger_mode": "direct",
        "card_identity_policy": actor.card_identity_policy,
        "sequence_book": actor.technique_sequence_book,
    }
    var dispatched: Dictionary = passive_runtime.dispatch_event(
        "extra_action_started", {
            "owner": actor, "actor": actor, "target": target,
            "round_number": _round_number(), "payload": payload,
        }, "write")
    if not dispatched.get("success", false):
        effect_ports.rollback_effect_mutation_transaction(transaction)
        passive_runtime.restore_battle_effect_command_state(passive_state)
        return {"success": false, "reason": "；".join(
            dispatched.get("errors", [])), "projection": projection}
    ## Registered status responses and equipped passive sources observe the
    ## same logical start, but the projection and passive start effects have
    ## already completed before the public response is emitted.
    effect_ports.notify_response_event("extra_action_started", payload)
    var marked: Dictionary = state_for(actor).mark_next_action_started({
        "projection": projection,
        "passive_invocation_count": dispatched.get("results", []).size(),
    })
    if not marked.get("success", false):
        effect_ports.rollback_effect_mutation_transaction(transaction)
        passive_runtime.restore_battle_effect_command_state(passive_state)
        return marked
    var committed: Dictionary = effect_ports.commit_effect_mutation_transaction(
        transaction)
    if not committed.get("success", false):
        effect_ports.rollback_effect_mutation_transaction(transaction)
        passive_runtime.restore_battle_effect_command_state(passive_state)
        return committed
    return {"success": true, "established": true,
        "source": marked.get("source", source),
        "projection": projection,
        "passive_results": dispatched.get("results", [])}

func next_action_source(actor) -> Dictionary:
    return state_for(actor).next_action_source()

func last_consumed_action_source(actor) -> Dictionary:
    return state_for(actor).last_consumed_action_source.duplicate(true)

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

func capture_transaction_state() -> Dictionary:
    var entries: Array = []
    for actor_key in _states:
        var state = _states[actor_key]
        entries.append({
            "actor_key": actor_key,
            "state": state,
            "values": state.capture_transaction_state(),
        })
    return {"entries": entries, "extra_action_serial": _extra_action_serial}

func restore_transaction_state(snapshot: Dictionary) -> void:
    _states.clear()
    _extra_action_serial = int(snapshot.get(
        "extra_action_serial", _extra_action_serial))
    for entry in snapshot.get("entries", []):
        var state = entry.get("state")
        if state == null:
            continue
        state.restore_transaction_state(entry.get("values", {}))
        _states[entry.get("actor_key")] = state

func _actor_key(actor) -> int:
    return actor.get_instance_id()

func _extra_action_payload(actor, source: Dictionary) -> Dictionary:
    return {
        "actor": actor,
        "holder": actor,
        "action_token": str(source.get("extra_action_token", "")),
        "root_action_token": str(source.get("action_token", "")),
        "round_number": _round_number(),
        "action_source": source.duplicate(true),
        "is_extra_action": true,
        "from_same_qi": bool(source.get("from_same_qi", false)),
        "source_category": str(source.get("category", "extra_action")),
    }

func _has_legal_card(actor) -> bool:
    for card in actor.hand:
        if card.has_method("is_card_kind") and not card.is_card_kind("normal"):
            continue
        if actor.status_system == null or bool(
                actor.status_system.can_play_card(actor, card).get(
                    "allowed", false)):
            return true
    return false

func _has_drawable_card(actor) -> bool:
    for card in actor.draw_pile:
        if not card.has_method("is_card_kind") or card.is_card_kind("normal"):
            return true
    return false

func _round_number() -> int:
    return int(_round_number_reader.call()) \
        if _round_number_reader.is_valid() else 0

func _passive_runtime():
    return _passive_runtime_ref.get_ref() \
        if _passive_runtime_ref != null else null

func _effect_ports():
    return _effect_ports_ref.get_ref() if _effect_ports_ref != null else null
