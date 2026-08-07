class_name BattleEffectPorts
extends RefCounted

var _damage_resolver = null
var _status_system = null
var _battle_flow = null
var _trigger_queue = null
var _sides: Array = []
var _played_return_callback: Callable
var _hand_retrigger_callback: Callable

func _init(
        damage_resolver = null,
        status_system = null,
        battle_flow = null,
        trigger_queue = null) -> void:
    _damage_resolver = damage_resolver
    _status_system = status_system
    _battle_flow = battle_flow
    _trigger_queue = trigger_queue

func use_trigger_queue(trigger_queue) -> void:
    _trigger_queue = trigger_queue

func use_sides(first, second) -> void:
    _sides = [first, second]

func use_played_return_callback(callback: Callable) -> void:
    _played_return_callback = callback

func use_hand_retrigger_callback(callback: Callable) -> void:
    _hand_retrigger_callback = callback

func opponent_of(side):
    for candidate in _sides:
        if candidate != side:
            return candidate
    return null

func is_combat_available() -> bool:
    return _damage_resolver != null and _status_system != null

func deal_damage(
        actor,
        target,
        amount: int,
        source_kind: String,
        true_damage: bool = false) -> Dictionary:
    if not is_combat_available():
        return {"success": false, "reason": "伤害端口未连接战斗"}
    var result: Dictionary = _damage_resolver.resolve(
        actor,
        target,
        amount,
        source_kind,
        true_damage,
        _status_system)
    if not bool(result["buffered"]):
        _log_damage(actor, target, int(result["final_amount"]), source_kind, result)
    _status_system.record_attack_segment(actor, source_kind)
    result["success"] = true
    return result

func actor_can_continue(side) -> bool:
    return (
        _damage_resolver.actor_can_continue(side)
        if _damage_resolver != null
        else side.life > 0)

func target_can_receive(side) -> bool:
    return (
        _damage_resolver.target_can_receive(side)
        if _damage_resolver != null
        else side.life > 0)

func begin_synchronized_damage(records: Array) -> void:
    var actors: Array = []
    for record in records:
        actors.append(record["actor"])
    _damage_resolver.begin_synchronized(actors)

func flush_synchronized_damage() -> void:
    for resolution in _damage_resolver.flush_synchronized():
        _log_damage(
            resolution["actor"],
            resolution["target"],
            int(resolution["amount"]),
            resolution["source_kind"],
            resolution["result"])

func add_defense(side, amount: int) -> int:
    return side.add_defense(amount)

func draw(side, count: int, source_kind: String = "") -> Array:
    var drawn: Array = side.draw(count)
    if source_kind == "technique" and _status_system != null:
        _status_system.record_technique_card_flow(side, "draw", drawn.size())
    return drawn

func discard_random(side, count: int, rng: RandomNumberGenerator) -> Array:
    var discarded: Array = side.random_discard(count, rng)
    if _status_system != null:
        _status_system.record_technique_card_flow(side, "discard", discarded.size())
    return discarded

func discard_all(side) -> Array:
    var discarded: Array = side.discard_all()
    if _status_system != null:
        _status_system.record_technique_card_flow(side, "discard", discarded.size())
    return discarded

func move_card(
        source_side,
        source_zone: String,
        target_side,
        destination_zone: String,
        card,
        reason: String = "effect",
        placement: String = "top",
        source_kind: String = "") -> Dictionary:
    var result: Dictionary
    if source_side == target_side:
        result = source_side.card_zone_service.move_card(
            source_side, source_zone, destination_zone, card, reason)
    else:
        result = source_side.temporarily_transfer_card_to(
            target_side, str(card.id), destination_zone)
    if result.get("success", false) and placement == "bottom":
        var destination: Array = target_side.card_zone_service.zone(
            target_side, destination_zone)
        destination.erase(card)
        destination.push_front(card)
    if result.get("success", false) and source_kind == "technique" and _status_system != null:
        if destination_zone == "hand" and reason == "draw":
            _status_system.record_technique_card_flow(target_side, "draw", 1)
        elif destination_zone == "discard_pile" and reason == "explicit_discard":
            _status_system.record_technique_card_flow(source_side, "discard", 1)
    return result

func zone_cards(side, zone: String) -> Array:
    match zone:
        "hand": return side.hand.duplicate()
        "draw_pile": return side.draw_pile.duplicate()
        "staging": return side.staging.duplicate()
        "discard_pile": return side.discard_pile.duplicate()
    return []

func add_actor_status(side, status_id: String, amount: int, source: String) -> Dictionary:
    if _status_system != null:
        return _status_system.add_actor_status(side, status_id, amount, source)
    var changed: int = side.add_stack(status_id, amount)
    return {"success": true, "changed": changed}

func apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary,
        source: String) -> Dictionary:
    if _status_system == null:
        return {"success": false, "reason": "异状端口未连接战斗状态系统"}
    return _status_system.apply_card_anomaly(
        card, category, anomaly_id, payload, source)

func resolve_played_card_anomalies(holder, cards: Array) -> Array:
    return _status_system.resolve_played_card_anomalies(holder, cards)

func gain_extra_actions(side, amount: int, source: String) -> int:
    if _battle_flow == null:
        return 0
    var gained: int = _battle_flow.grant_actions(side, amount)
    add_history(
        "action_end",
        "%s额外出牌机会" % side.name,
        source,
        "成功",
        "+%d（连击不自动补牌）" % gained)
    return gained

func register_attack_counter_delay(
        label: String,
        turn_ends: int,
        snapshot_power: int,
        damage_per_segment: int,
        actor,
        target) -> Dictionary:
    if _status_system == null:
        return {"success": false, "reason": "延迟端口未连接战斗"}
    var result: Dictionary = _status_system.register_attack_counter_delay(
        label,
        turn_ends,
        snapshot_power,
        damage_per_segment,
        actor,
        target)
    add_history(
        "delayed_register",
        label,
        "%s延迟功法" % actor.name,
        "成功",
        "记录建立时 P=%d" % snapshot_power)
    return result

func register_turn_end_stack(
        label: String,
        turn_ends: int,
        stack_id: String,
        amount: int,
        actor) -> Dictionary:
    if _status_system == null:
        return {"success": false, "reason": "延迟端口未连接战斗"}
    return _status_system.register_turn_end_stack(
        label, turn_ends, stack_id, amount, actor)

func register_played_return(
        side,
        played_cards: Array,
        contributing_cards: Array,
        count: int,
        destination: String,
        anomaly: String,
        enter_discard_first: bool,
        shuffle: bool) -> Dictionary:
    if not _played_return_callback.is_valid():
        return {"success": false, "registered": 0}
    return _played_return_callback.call(
        side,
        played_cards,
        contributing_cards,
        count,
        destination,
        anomaly,
        enter_discard_first,
        shuffle)

func register_delayed_effects(
        label: String,
        timing: String,
        occurrences: int,
        effects: Array,
        context) -> Dictionary:
    if _status_system == null:
        return {"success": false, "reason": "延迟端口未连接状态系统"}
    return _status_system.register_delayed_effects(
        label, timing, occurrences, effects, context)

func technique_draw_count(side) -> int:
    return _status_system.technique_draw_count(side) if _status_system != null else 0

func retrigger_current_hand_technique(
        actor,
        target,
        sequence_book,
        snapshot_power: int,
        maximum_discard: int,
        excluded_technique_ids: Array) -> Dictionary:
    if not _hand_retrigger_callback.is_valid():
        return {"success": false, "detail": "当前未连接功法重触端口"}
    return _hand_retrigger_callback.call(
        actor,
        target,
        sequence_book,
        snapshot_power,
        maximum_discard,
        excluded_technique_ids)

func add_history(
        timing: String,
        label: String,
        source: String,
        result: String,
        detail: String = "") -> void:
    if _trigger_queue != null:
        _trigger_queue.add_history(timing, label, source, result, detail)

func _log_damage(actor, target, final_amount: int, source_kind: String, result: Dictionary) -> void:
    add_history(
        "damage_segment",
        "%s → %s" % [actor.name, target.name],
        source_kind,
        "成功",
        "%d 点：防御-%d / 生命-%d" % [
            final_amount,
            result["defense_lost"],
            result["life_lost"]])
