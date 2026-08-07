class_name ComboDamageResolver
extends RefCounted

var _buffer_active: bool = false
var _buffer: Array = []
var _shadows: Dictionary = {}
var _actor_start_alive: Dictionary = {}

func reset() -> void:
    _buffer_active = false
    _buffer.clear()
    _shadows.clear()
    _actor_start_alive.clear()

func resolve(
        actor,
        target,
        base_amount: int,
        source_kind: String,
        true_damage: bool = false,
        status_system = null) -> Dictionary:
    var final_amount := calculate_final_amount(
        actor,
        base_amount,
        source_kind,
        true_damage,
        status_system)
    var result: Dictionary
    if _buffer_active:
        result = _buffer_damage(actor, target, final_amount, source_kind, true_damage)
    else:
        result = apply_to_target(target, final_amount, true_damage)
    result["final_amount"] = final_amount
    result["source_kind"] = source_kind
    result["buffered"] = _buffer_active
    return result

func begin_synchronized(actors: Array) -> void:
    reset()
    _buffer_active = true
    for actor in actors:
        _actor_start_alive[actor.get_instance_id()] = actor.life > 0

func flush_synchronized() -> Array:
    var buffered := _buffer.duplicate()
    _buffer_active = false
    var resolved: Array = []
    for intent in buffered:
        var actual := apply_to_target(
            intent["target"],
            int(intent["amount"]),
            bool(intent["true_damage"]))
        resolved.append({
            "actor": intent["actor"],
            "target": intent["target"],
            "amount": intent["amount"],
            "source_kind": intent["source_kind"],
            "true_damage": intent["true_damage"],
            "preview": intent["preview"],
            "result": actual,
        })
    reset()
    return resolved

func actor_can_continue(side) -> bool:
    if not _buffer_active:
        return side.life > 0
    return bool(_actor_start_alive.get(side.get_instance_id(), side.life > 0))

func target_can_receive(side) -> bool:
    if not _buffer_active:
        return side.life > 0
    var shadow: Dictionary = _shadows.get(side.get_instance_id(), {"life": side.life})
    return int(shadow["life"]) > 0

func is_buffering() -> bool:
    return _buffer_active

static func calculate_final_amount(
        actor,
        base_amount: int,
        source_kind: String,
        true_damage: bool = false,
        status_system = null) -> int:
    var final_amount := maxi(0, base_amount)
    if not true_damage:
        var damage_percent: int = (
            status_system.actor_numeric_modifier(
                actor, "damage_percent", {"source_kind": source_kind})
            if status_system != null
            else actor.status_modifier("damage_percent", {"source_kind": source_kind}))
        final_amount = int(floor(final_amount * (1.0 + damage_percent / 100.0)))
    return final_amount

static func apply_to_target(target, amount: int, true_damage: bool = false) -> Dictionary:
    var state := {"life": target.life, "defense": target.defense}
    var result := preview_receive_damage(state, amount, true_damage)
    target.life = int(state["life"])
    target.defense = int(state["defense"])
    return result

static func preview_receive_damage(
        state: Dictionary,
        amount: int,
        true_damage: bool = false) -> Dictionary:
    var incoming := maxi(0, amount)
    var defense_lost := 0
    var life_lost := 0
    if true_damage:
        life_lost = mini(int(state["life"]), incoming)
        state["life"] = int(state["life"]) - life_lost
    else:
        defense_lost = mini(int(state["defense"]), incoming)
        state["defense"] = int(state["defense"]) - defense_lost
        var remainder := incoming - defense_lost
        life_lost = mini(int(state["life"]), remainder)
        state["life"] = int(state["life"]) - life_lost
    return {
        "requested": incoming,
        "defense_lost": defense_lost,
        "life_lost": life_lost,
        "true_damage": true_damage,
    }

func _buffer_damage(
        actor,
        target,
        amount: int,
        source_kind: String,
        true_damage: bool) -> Dictionary:
    var target_id: int = target.get_instance_id()
    if not _shadows.has(target_id):
        _shadows[target_id] = {"life": target.life, "defense": target.defense}
    var shadow: Dictionary = _shadows[target_id]
    var preview := preview_receive_damage(shadow, amount, true_damage)
    _shadows[target_id] = shadow
    _buffer.append({
        "actor": actor,
        "target": target,
        "amount": amount,
        "source_kind": source_kind,
        "true_damage": true_damage,
        "preview": preview,
    })
    return preview
