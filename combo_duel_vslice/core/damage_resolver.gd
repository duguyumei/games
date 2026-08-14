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
        status_system = null,
        final_amount_override = null,
        damage_type: String = "",
        poison_defense_intervention: int = 0,
        resolution_metadata: Dictionary = {}) -> Dictionary:
    var resolved_type := damage_type
    if resolved_type == "":
        resolved_type = "true" if true_damage else "normal"
    var final_amount := (
        int(final_amount_override)
        if final_amount_override != null
        else calculate_final_amount(
            actor, target, base_amount, source_kind, resolved_type, status_system))
    var result: Dictionary
    if _buffer_active:
        result = _buffer_damage(
            actor, target, final_amount, base_amount, source_kind, resolved_type,
            poison_defense_intervention, resolution_metadata)
    else:
        result = apply_to_target(
            target, final_amount, resolved_type, poison_defense_intervention)
    result["final_amount"] = final_amount
    result["source_kind"] = source_kind
    result["damage_type"] = resolved_type
    result["true_damage"] = resolved_type == "true"
    result["buffered"] = _buffer_active
    return result

func begin_synchronized(actors: Array) -> void:
    reset()
    _buffer_active = true
    for actor in actors:
        _actor_start_alive[actor.get_instance_id()] = actor.life > 0

func flush_synchronized(
        after_resolution: Callable = Callable(),
        actual_amount_resolver: Callable = Callable()) -> Array:
    var buffered := _buffer.duplicate()
    _buffer_active = false
    var resolved: Array = []
    var stopped_actor_ids: Dictionary = {}
    for intent in buffered:
        var actor_id: int = int(intent["actor"].get_instance_id())
        if stopped_actor_ids.has(actor_id):
            continue
        var actual_amount := int(intent["amount"])
        if actual_amount_resolver.is_valid():
            var amount_result: Dictionary = actual_amount_resolver.call(intent)
            if not amount_result.get("success", false):
                break
            actual_amount = maxi(0, int(amount_result["amount"]))
        var actual := apply_to_target(
            intent["target"],
            actual_amount,
            str(intent.get("damage_type", "true" if bool(intent["true_damage"]) else "normal")),
            int(intent.get("poison_defense_intervention", 0)))
        actual["final_amount"] = actual_amount
        var resolution := {
            "actor": intent["actor"],
            "target": intent["target"],
            "amount": actual_amount,
            "requested_amount": intent.get("requested_amount", intent["amount"]),
            "source_kind": intent["source_kind"],
            "true_damage": intent["true_damage"],
            "damage_type": intent.get("damage_type", "normal"),
            "preview": intent["preview"],
            "resolution_metadata": intent.get("resolution_metadata", {}).duplicate(true),
            "result": actual,
        }
        resolved.append(resolution)
        if after_resolution.is_valid() \
                and bool(after_resolution.call(resolution)):
            stopped_actor_ids[actor_id] = true
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
        target,
        base_amount: int,
        source_kind: String,
        damage_type = "normal",
        status_system = null) -> int:
    var final_amount := maxi(0, base_amount)
    var resolved_type := str(damage_type)
    if damage_type is bool:
        resolved_type = "true" if bool(damage_type) else "normal"
    if resolved_type == "normal":
        var damage_percent := 0
        if status_system != null:
            damage_percent += status_system.actor_hand_card_numeric_modifier(
                actor, "outgoing_damage_percent")
            damage_percent += status_system.actor_hand_card_numeric_modifier(
                target, "incoming_damage_percent")
        final_amount = int(floor(final_amount * (1.0 + damage_percent / 100.0)))
    return final_amount

static func apply_to_target(
        target,
        amount: int,
        damage_type = "normal",
        poison_defense_intervention: int = 0) -> Dictionary:
    var state := {"life": target.life, "defense": target.defense}
    var result := preview_receive_damage(
        state, amount, damage_type, poison_defense_intervention)
    target.life = int(state["life"])
    target.defense = int(state["defense"])
    return result

static func preview_receive_damage(
        state: Dictionary,
        amount: int,
        damage_type = "normal",
        poison_defense_intervention: int = 0) -> Dictionary:
    var resolved_type := str(damage_type)
    if damage_type is bool:
        resolved_type = "true" if bool(damage_type) else "normal"
    var incoming := maxi(0, amount)
    var defense_lost := 0
    var life_lost := 0
    if resolved_type == "true":
        life_lost = mini(int(state["life"]), incoming)
        state["life"] = int(state["life"]) - life_lost
    elif resolved_type == "poison":
        var intervened: int = mini(
            incoming,
            mini(int(state["defense"]), maxi(0, poison_defense_intervention)))
        defense_lost = intervened
        state["defense"] = int(state["defense"]) - intervened
        life_lost = mini(int(state["life"]), incoming - intervened)
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
        "true_damage": resolved_type == "true",
        "damage_type": resolved_type,
    }

func _buffer_damage(
        actor,
        target,
        amount: int,
        requested_amount: int,
        source_kind: String,
        damage_type: String,
        poison_defense_intervention: int = 0,
        resolution_metadata: Dictionary = {}) -> Dictionary:
    var target_id: int = target.get_instance_id()
    if not _shadows.has(target_id):
        _shadows[target_id] = {"life": target.life, "defense": target.defense}
    var shadow: Dictionary = _shadows[target_id]
    var preview := preview_receive_damage(
        shadow, amount, damage_type, poison_defense_intervention)
    _shadows[target_id] = shadow
    _buffer.append({
        "actor": actor,
        "target": target,
        "amount": amount,
        "requested_amount": requested_amount,
        "source_kind": source_kind,
        "true_damage": damage_type == "true",
        "damage_type": damage_type,
        "poison_defense_intervention": poison_defense_intervention,
        "resolution_metadata": resolution_metadata.duplicate(true),
        "preview": preview,
    })
    return preview
