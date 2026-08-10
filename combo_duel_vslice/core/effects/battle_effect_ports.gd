class_name BattleEffectPorts
extends RefCounted

## 效果处理器修改战斗状态的唯一窄端口。
##
## 四个依赖是必需的，不接受 null：端口一旦允许缺依赖，每个方法都要带一条兜底分支，
## 而兜底分支会在依赖真的缺失时静默改用另一套判定，把装配错误伪装成正常结果。
## 装配失败应当在构造点暴露，不应推迟到某个效果结算时。

var _damage_resolver: ComboDamageResolver
var _status_system: StatusSystem
var _battle_flow: BattleFlowCoordinator
var _trigger_queue: VisibleTriggerQueue
var _sides: Array[BattleSide] = []
var _played_return_callback: Callable
var _hand_retrigger_callback: Callable
var _card_reshape_runtime_ref: WeakRef
var _consumable_repository

func _init(
        damage_resolver: ComboDamageResolver,
        status_system: StatusSystem,
        battle_flow: BattleFlowCoordinator,
        trigger_queue: VisibleTriggerQueue) -> void:
    _damage_resolver = damage_resolver
    _status_system = status_system
    _battle_flow = battle_flow
    _trigger_queue = trigger_queue

func use_trigger_queue(trigger_queue: VisibleTriggerQueue) -> void:
    _trigger_queue = trigger_queue

func use_sides(first: BattleSide, second: BattleSide) -> void:
    _sides = [first, second]

func use_played_return_callback(callback: Callable) -> void:
    _played_return_callback = callback

func use_hand_retrigger_callback(callback: Callable) -> void:
    _hand_retrigger_callback = callback

func use_card_reshape_runtime(runtime) -> void:
    _card_reshape_runtime_ref = weakref(runtime)

func use_consumable_repository(repository) -> void:
    _consumable_repository = repository

func opponent_of(side: BattleSide) -> BattleSide:
    for candidate in _sides:
        if candidate != side:
            return candidate
    return null

func side_holding_card(card, zone: String) -> BattleSide:
    for side in _sides:
        if zone_cards(side, zone).has(card):
            return side
    return null

func deal_damage(
        actor: BattleSide,
        target: BattleSide,
        amount: int,
        source_kind: String,
        true_damage: bool = false) -> Dictionary:
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
    if not bool(result["buffered"]):
        _status_system.resolve_received_attack_segment(
            actor, target, source_kind, result)
    result["success"] = true
    return result

func actor_can_continue(side: BattleSide) -> bool:
    return _damage_resolver.actor_can_continue(side)

func target_can_receive(side: BattleSide) -> bool:
    return _damage_resolver.target_can_receive(side)

func begin_synchronized_damage(records: Array) -> void:
    var actors: Array = []
    for record in records:
        actors.append(record["actor"])
    _damage_resolver.begin_synchronized(actors)

func flush_synchronized_damage() -> void:
    _damage_resolver.flush_synchronized(Callable(
        self, "_on_synchronized_damage_resolved"))

func add_defense(side: BattleSide, amount: int) -> int:
    return side.add_defense(amount)

func gain_battle_experience(side: BattleSide, amount: int) -> int:
    var gained := maxi(0, amount)
    side.experience += gained
    return gained

func can_grant_battle_consumable(side: BattleSide) -> bool:
    return side.consumable_ids.size() < side.consumable_limit

func grant_battle_consumable(side: BattleSide, consumable_id: String) -> bool:
    return side.grant_consumable(consumable_id)

func consumable_ids_by_kind(kind: String) -> Array[String]:
    return _consumable_repository.ids_by_kind(kind)

func place_on_draw_pile_top(side: BattleSide, card) -> Dictionary:
    return side.card_zone_service.place_on_draw_pile_top(side, card)

func temporarily_remove_card(
        side: BattleSide,
        instance_id: String,
        reason: String) -> Dictionary:
    return side.temporarily_remove_card(instance_id, reason)

func can_explicit_discard(side: BattleSide, card) -> Dictionary:
    var runtime = _card_reshape_runtime()
    if runtime == null:
        return {"allowed": true}
    return runtime.can_explicit_discard(side, card)

func notify_cards_played(side: BattleSide, cards: Array) -> Array[Dictionary]:
    var runtime = _card_reshape_runtime()
    return runtime.on_card_played(side, cards) if runtime != null else []

func finalize_reshape_action(side: BattleSide, preview: Dictionary) -> Dictionary:
    var runtime = _card_reshape_runtime()
    if runtime == null:
        return {"success": true, "reused": false}
    return runtime.finalize_action_preview(side, preview)

func draw(side: BattleSide, count: int, source_kind: String = "") -> Array:
    var drawn: Array = side.draw(count)
    if source_kind == "technique":
        _status_system.record_technique_card_flow(side, "draw", drawn.size())
    return drawn

func shuffle_zone(
        side: BattleSide,
        zone: String,
        rng: RandomNumberGenerator) -> void:
    side.card_zone_service.shuffle(side.card_zone_service.zone(side, zone), rng)

func current_effective_qi(side: BattleSide, card) -> int:
    var reshape_value: int = (
        card.effective_qi_value()
        if card.has_method("effective_qi_value") else int(card.qi_value))
    return maxi(0, _status_system.modify_card_contribution(
        card, reshape_value, side))

func discard_random(side: BattleSide, count: int, rng: RandomNumberGenerator) -> Array:
    var discarded: Array = side.random_discard(count, rng)
    _status_system.record_technique_card_flow(side, "discard", discarded.size())
    return discarded

func discard_all(side: BattleSide) -> Array:
    var discarded: Array = side.discard_all()
    _status_system.record_technique_card_flow(side, "discard", discarded.size())
    return discarded

func move_card(
        source_side: BattleSide,
        source_zone: String,
        target_side: BattleSide,
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
    if result.get("success", false) and source_kind == "technique":
        if destination_zone == "hand" and reason == "draw":
            _status_system.record_technique_card_flow(target_side, "draw", 1)
        elif destination_zone == "discard_pile" and reason == "explicit_discard":
            _status_system.record_technique_card_flow(source_side, "discard", 1)
    return result

func zone_cards(side: BattleSide, zone: String) -> Array:
    match zone:
        "hand": return side.hand.duplicate()
        "draw_pile": return side.draw_pile.duplicate()
        "staging": return side.staging.duplicate()
        "discard_pile": return side.discard_pile.duplicate()
    return []

func add_actor_status(side: BattleSide, status_id: String, amount: int, source: String) -> Dictionary:
    return _status_system.add_actor_status(side, status_id, amount, source)

func apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary,
        source: String) -> Dictionary:
    return _status_system.apply_card_anomaly(
        card, category, anomaly_id, payload, source)

func _card_reshape_runtime():
    return (
        _card_reshape_runtime_ref.get_ref()
        if _card_reshape_runtime_ref != null else null)

func resolve_played_card_anomalies(holder: BattleSide, cards: Array) -> Array:
    var results: Array = _status_system.resolve_played_card_anomalies(holder, cards)
    notify_cards_played(holder, cards)
    return results

func gain_extra_actions(side: BattleSide, amount: int, source: String) -> int:
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
        actor: BattleSide,
        target: BattleSide) -> Dictionary:
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
        actor: BattleSide) -> Dictionary:
    return _status_system.register_turn_end_stack(
        label, turn_ends, stack_id, amount, actor)

func register_played_return(
        side: BattleSide,
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
    return _status_system.register_delayed_effects(
        label, timing, occurrences, effects, context)

func technique_draw_count(side: BattleSide) -> int:
    return _status_system.technique_draw_count(side)

func retrigger_current_hand_technique(
        actor: BattleSide,
        target: BattleSide,
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
    _trigger_queue.add_history(timing, label, source, result, detail)

func _log_damage(
        actor: BattleSide,
        target: BattleSide,
        final_amount: int,
        source_kind: String,
        result: Dictionary) -> void:
    add_history(
        "damage_segment",
        "%s → %s" % [actor.name, target.name],
        source_kind,
        "成功",
        "%d 点：防御-%d / 生命-%d" % [
            final_amount,
            result["defense_lost"],
            result["life_lost"]])

func _on_synchronized_damage_resolved(resolution: Dictionary) -> bool:
    _log_damage(
        resolution["actor"],
        resolution["target"],
        int(resolution["amount"]),
        str(resolution["source_kind"]),
        resolution["result"])
    _status_system.resolve_received_attack_segment(
        resolution["actor"],
        resolution["target"],
        str(resolution["source_kind"]),
        resolution["result"])
    return int(resolution["actor"].life) <= 0
