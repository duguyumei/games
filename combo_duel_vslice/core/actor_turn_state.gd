class_name ActorTurnState
extends RefCounted

var actor
var action_count: int = 0
var current_disabled_reasons: Dictionary = {}
var scheduled_disabled_reasons: Dictionary = {}
var combo_claims: Dictionary = {}
var pending_intent: Dictionary = {}
var last_forfeit_reason: String = ""

func _init(actor_value = null) -> void:
    actor = actor_value

func begin_round(initial_actions: int) -> void:
    action_count = maxi(0, initial_actions)
    current_disabled_reasons.clear()
    combo_claims.clear()
    pending_intent.clear()
    last_forfeit_reason = ""
    var expired: Array = []
    for reason in scheduled_disabled_reasons:
        var remaining := int(scheduled_disabled_reasons[reason])
        if remaining > 0:
            current_disabled_reasons[reason] = true
            remaining -= 1
        if remaining <= 0:
            expired.append(reason)
        else:
            scheduled_disabled_reasons[reason] = remaining
    for reason in expired:
        scheduled_disabled_reasons.erase(reason)

func can_act() -> bool:
    return action_count > 0 and current_disabled_reasons.is_empty()

func available_action_count() -> int:
    return action_count if current_disabled_reasons.is_empty() else 0

func consume_action() -> bool:
    if not can_act():
        return false
    action_count -= 1
    return true

func grant_actions(amount: int) -> int:
    var gained := maxi(0, amount)
    action_count += gained
    return gained

func forfeit_remaining(reason: String) -> void:
    action_count = 0
    last_forfeit_reason = reason
    pending_intent.clear()

func disable_current(reason: String) -> void:
    if reason != "":
        current_disabled_reasons[reason] = true
        pending_intent.clear()

func enable_current(reason: String) -> void:
    current_disabled_reasons.erase(reason)

func disable_future(reason: String, round_count: int = 1) -> void:
    if reason == "" or round_count <= 0:
        return
    scheduled_disabled_reasons[reason] = maxi(
        int(scheduled_disabled_reasons.get(reason, 0)),
        round_count)

func claim_combo(combo_id: String) -> bool:
    if combo_id == "" or combo_claims.has(combo_id):
        return false
    combo_claims[combo_id] = true
    return true

func has_claimed_combo(combo_id: String) -> bool:
    return combo_claims.has(combo_id)

func lock_intent(intent: Dictionary) -> bool:
    if not can_act() or intent.is_empty():
        return false
    pending_intent = intent.duplicate(true)
    return true

func clear_intent() -> void:
    pending_intent.clear()

func snapshot() -> Dictionary:
    return {
        "actor_name": str(actor.name) if actor != null else "",
        "action_count": action_count,
        "available_action_count": available_action_count(),
        "can_act": can_act(),
        "disabled_reasons": current_disabled_reasons.keys(),
        "scheduled_disabled_reasons": scheduled_disabled_reasons.duplicate(true),
        "combo_claims": combo_claims.keys(),
        "has_pending_intent": not pending_intent.is_empty(),
        "last_forfeit_reason": last_forfeit_reason,
    }
