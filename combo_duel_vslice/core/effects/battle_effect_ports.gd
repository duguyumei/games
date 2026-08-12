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
var _hand_retrigger_callback: Callable
var _card_reshape_runtime_ref: WeakRef
var _consumable_repository
var _battle_rule_query_service
var _committed_event_service
var _round_number_reader: Callable
var _battle_rng: RandomNumberGenerator
var _battle_instance_id: String = "battle-0"

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

func use_hand_retrigger_callback(callback: Callable) -> void:
    _hand_retrigger_callback = callback

func use_card_reshape_runtime(runtime) -> void:
    _card_reshape_runtime_ref = weakref(runtime)

func use_consumable_repository(repository) -> void:
    _consumable_repository = repository

func use_passive_battle_services(
        query_service,
        event_service,
        round_reader: Callable = Callable()) -> void:
    _battle_rule_query_service = query_service
    _committed_event_service = event_service
    _round_number_reader = round_reader

func use_battle_rng(rng: RandomNumberGenerator) -> void:
    _battle_rng = rng

func battle_rng() -> RandomNumberGenerator:
    return _battle_rng

func use_battle_instance_id(value: String) -> void:
    _battle_instance_id = value if value != "" else "battle-0"

func battle_instance_id() -> String:
    return _battle_instance_id

func is_current_side(side) -> bool:
    return side != null and _sides.has(side)

func locate_active_card(card_instance_id: String) -> Dictionary:
    if card_instance_id == "":
        return {"success": false, "reason": "卡牌实例 ID 不能为空"}
    var matches: Array[Dictionary] = []
    for side in _sides:
        var location: Dictionary = side.card_zone_service.find_active_location(
            side, card_instance_id)
        if not location.is_empty():
            matches.append({
                "side": side,
                "zone": str(location["zone"]),
                "card": location["card"],
            })
    if matches.is_empty():
        return {"success": false, "reason": "当前战斗不存在目标卡牌"}
    if matches.size() > 1:
        return {"success": false, "reason": "当前战斗存在重复卡牌实例 ID"}
    var result: Dictionary = matches[0]
    result["success"] = true
    return result

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
        true_damage: bool = false,
        action_token: String = "") -> Dictionary:
    var resolved_amount := _resolve_actual_damage_amount(
        actor, target, amount, source_kind, true_damage, action_token)
    if not resolved_amount.get("success", false):
        return {
            "success": false,
            "reason": resolved_amount.get("reason", "伤害查询失败"),
            "buffered": false,
        }
    var final_override = null
    if not _damage_resolver.is_buffering():
        final_override = int(resolved_amount["amount"])
    var result: Dictionary = _damage_resolver.resolve(
        actor, target, amount, source_kind, true_damage,
        _status_system, final_override)
    if not bool(result["buffered"]):
        _log_damage(actor, target, int(result["final_amount"]), source_kind, result)
    if not bool(result["buffered"]):
        _emit_damage_resolved(
            actor, target, amount, source_kind, true_damage, result, false,
            action_token)
        _resolve_reflection(actor, target, source_kind, result)
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
    _damage_resolver.flush_synchronized(
        Callable(self, "_on_synchronized_damage_resolved"),
        Callable(self, "_resolve_synchronized_damage_amount"))

func add_defense(
        side: BattleSide,
        amount: int,
        source_kind: String = "effect",
        action_token: String = "") -> int:
    return int(add_defense_result(
        side, amount, source_kind, action_token).get("gained", 0))

func add_defense_result(
        side: BattleSide,
        amount: int,
        source_kind: String = "effect",
        action_token: String = "") -> Dictionary:
    var requested := maxi(0, amount)
    if requested <= 0:
        return {"success": true, "gained": 0, "requested": requested}
    var effective := requested
    if _battle_rule_query_service != null:
        var query = _battle_rule_query_service.resolve_values({
            "hook": "defense_gain_query",
            "owner": side, "actor": side,
            "subject_kind": "defense_gain",
            "subject_id": source_kind,
            "base_value": requested,
            "round_number": _round_number(),
            "action_token": action_token,
            "source_kind": source_kind,
        })
        if not query.success:
            _battle_rule_query_service.report_failure(query, "defense_gain")
            return {
                "success": false,
                "gained": 0,
                "requested": requested,
                "reason": "；".join(query.errors),
            }
        effective = maxi(0, query.effective_value)
    if effective <= 0:
        return {
            "success": true,
            "gained": 0,
            "requested": requested,
            "effective": effective,
        }
    var before := int(side.defense)
    var gained := side.add_defense(effective)
    if gained > 0 and _committed_event_service != null:
        var serial: int = int(_committed_event_service.next_serial())
        _committed_event_service.commit("defense_gained", {
            "event_token": _committed_event_service.make_token(
                "defense_gained", side, serial, action_token),
            "event_serial": serial,
            "actor": side, "owner": side,
            "round_number": _round_number(),
            "action_token": action_token,
            "source_kind": source_kind,
            "requested_amount": requested,
            "effective_amount": gained,
            "defense_before": before,
            "defense_after": int(side.defense),
        })
    return {
        "success": true,
        "gained": gained,
        "requested": requested,
        "effective": effective,
        "before": before,
        "after": int(side.defense),
    }

func add_momentum(side: BattleSide, amount: int) -> int:
    return side.add_momentum(amount)

func set_momentum(side: BattleSide, value: int) -> int:
    return side.set_momentum(value)

func set_reflection_percent(side: BattleSide, value: int) -> int:
    return side.set_reflection_percent(value)

func add_direct_power_fixed(side: BattleSide, amount: int) -> int:
    side.direct_power_fixed += amount
    return side.direct_power_fixed

func add_direct_power_percent(side: BattleSide, amount: int) -> int:
    side.direct_power_percent += amount
    return side.direct_power_percent

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

func notify_cards_played(
        side: BattleSide,
        cards: Array,
        source_values: Dictionary = {}) -> Array[Dictionary]:
    var runtime = _card_reshape_runtime()
    return runtime.on_card_played(
        side, cards, source_values) if runtime != null else []

func register_direct_card_trigger_listener(
        listener_id: String,
        listener) -> bool:
    var runtime = _card_reshape_runtime()
    return runtime != null and runtime.trigger_replay_service \
        .register_direct_listener(listener_id, listener)

func unregister_direct_card_trigger_listener(listener_id: String) -> bool:
    var runtime = _card_reshape_runtime()
    return runtime != null and runtime.trigger_replay_service \
        .unregister_direct_listener(listener_id)

func finalize_reshape_action(side: BattleSide, preview: Dictionary) -> Dictionary:
    var runtime = _card_reshape_runtime()
    if runtime == null:
        return {"success": true, "reused": false}
    return runtime.finalize_action_preview(side, preview)

func draw(side: BattleSide, count: int, source_kind: String = "") -> Array:
    var draw_reason := source_kind if source_kind != "" else "effect_draw"
    var drawn: Array = side.draw(count, draw_reason)
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
            target_side, str(card.id), destination_zone, reason)
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

func apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary,
        source: String,
        layers: int = 1,
        replace_state: bool = false) -> Dictionary:
    return _status_system.apply_card_anomaly(
        card, category, anomaly_id, payload, source, layers, replace_state)

func can_apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        replace_state: bool = false) -> Dictionary:
    return _status_system.can_apply_card_anomaly(
        card, category, anomaly_id, replace_state)

func apply_temporary_enhancement(card, enhancement_id: String) -> Dictionary:
    if card == null or enhancement_id == "":
        return {"success": false, "reason": "临时强化参数无效"}
    return {
        "success": card.set_temporary_enhancement(enhancement_id),
        "enhancement": enhancement_id,
    }

func apply_temporary_attribute(card, attribute_id: String) -> Dictionary:
    if card == null:
        return {"success": false, "reason": "临时属性目标为空"}
    return {
        "success": card.set_temporary_attribute(attribute_id),
        "attribute": attribute_id,
    }

func clear_temporary_reshape(card, subslot: String) -> Dictionary:
    if card == null or subslot not in ["enhancement", "attribute"]:
        return {"success": false, "reason": "临时重塑子槽无效"}
    return {"success": true, "removed": card.clear_temporary_reshape(subslot)}

func clear_all_temporary_reshapes(card) -> Dictionary:
    if card == null:
        return {"success": false, "reason": "临时重塑目标为空"}
    return {"success": true, "removed": card.clear_all_temporary_reshapes()}

func _card_reshape_runtime():
    return (
        _card_reshape_runtime_ref.get_ref()
        if _card_reshape_runtime_ref != null else null)

func resolve_played_card_anomalies(
        holder: BattleSide,
        cards: Array,
        source_values: Dictionary = {}) -> Array:
    var results: Array = _status_system.resolve_played_card_anomalies(
        holder, cards, source_values)
    notify_cards_played(holder, cards, source_values)
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
        power_snapshot: Dictionary,
        maximum_discard: int,
        excluded_technique_ids: Array) -> Dictionary:
    if not _hand_retrigger_callback.is_valid():
        return {"success": false, "detail": "当前未连接功法重触端口"}
    return _hand_retrigger_callback.call(
        actor,
        target,
        sequence_book,
        power_snapshot,
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
    _emit_damage_resolved(
        resolution["actor"], resolution["target"],
        int(resolution.get("requested_amount", resolution["amount"])),
        str(resolution["source_kind"]), bool(resolution["true_damage"]),
        resolution["result"], true,
        str(resolution.get("action_token", "")))
    _resolve_reflection(
        resolution["actor"],
        resolution["target"],
        str(resolution["source_kind"]),
        resolution["result"])
    return int(resolution["actor"].life) <= 0

func _resolve_actual_damage_amount(
        actor,
        target,
        requested_amount: int,
        source_kind: String,
        true_damage: bool,
        action_token: String = "") -> Dictionary:
    if true_damage or _damage_resolver.is_buffering():
        return {"success": true, "amount": maxi(0, requested_amount)}
    var current := ComboDamageResolver.calculate_final_amount(
        actor, target, requested_amount, source_kind, false, _status_system)
    for stage in [
            ["outgoing_damage_query", actor],
            ["incoming_damage_query", target]]:
        if _battle_rule_query_service == null:
            continue
        var owner = stage[1]
        var query = _battle_rule_query_service.resolve_values({
            "hook": stage[0], "owner": owner,
            "actor": actor, "target": target,
            "subject_kind": "damage", "subject_id": source_kind,
            "base_value": current, "round_number": _round_number(),
            "source_kind": source_kind,
            "action_token": action_token,
            "metadata": {"requested_amount": requested_amount},
        })
        if not query.success:
            _battle_rule_query_service.report_failure(query, "damage")
            return {"success": false, "reason": "；".join(query.errors)}
        current = query.effective_value
    return {"success": true, "amount": maxi(0, int(floor(float(current))))}

func _resolve_synchronized_damage_amount(intent: Dictionary) -> Dictionary:
    return _resolve_actual_damage_amount(
        intent["actor"], intent["target"],
        int(intent.get("requested_amount", intent["amount"])),
        str(intent["source_kind"]), bool(intent["true_damage"]),
        str(intent.get("action_token", "")))

func _emit_damage_resolved(
        actor,
        target,
        requested_amount: int,
        source_kind: String,
        true_damage: bool,
        result: Dictionary,
        synchronized: bool,
        action_token: String = "") -> void:
    if _committed_event_service == null:
        return
    var serial: int = int(_committed_event_service.next_serial())
    _committed_event_service.commit("damage_resolved", {
        "event_token": _committed_event_service.make_token(
            "damage_resolved", actor, serial, action_token),
        "event_serial": serial,
        "actor": actor, "target": target, "owner": actor,
        "include_target_owner": true,
        "round_number": _round_number(),
        "action_token": action_token,
        "source_kind": source_kind,
        "requested_amount": requested_amount,
        "final_amount": int(result.get("final_amount", result.get("requested", 0))),
        "defense_lost": int(result.get("defense_lost", 0)),
        "life_lost": int(result.get("life_lost", 0)),
        "true_damage": true_damage,
        "synchronized": synchronized,
    })

func _round_number() -> int:
    return int(_round_number_reader.call()) if _round_number_reader.is_valid() else 0

func _resolve_reflection(
        attacker: BattleSide,
        defender: BattleSide,
        source_kind: String,
        result: Dictionary) -> void:
    if attacker == null or defender == null or attacker == defender \
            or source_kind == "reflection" \
            or bool(result.get("true_damage", false)):
        return
    var defense_lost := int(result.get("defense_lost", 0))
    var percent := int(defender.current_reflection_percent)
    if defense_lost <= 0 or percent <= 0:
        return
    var amount := int(floor(defense_lost * percent / 100.0))
    if amount <= 0:
        return
    deal_damage(defender, attacker, amount, "reflection", false)
