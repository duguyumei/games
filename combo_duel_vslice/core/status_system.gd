class_name StatusSystem
extends RefCounted

const CardStateLifecycleScript = preload("res://core/card_state_lifecycle.gd")
const StatusChangeScript = preload("res://core/status_change.gd")
const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const StatusBehaviorRegistryScript = preload(
    "res://core/statuses/status_behavior_registry.gd")
const StatusBehaviorContextScript = preload(
    "res://core/statuses/status_behavior_context.gd")

var content_catalog
var lifecycle
var timing_system
var delayed_records: Array = []
var response_records: Array = []
var history: Array = []
var _serial: int = 0
var _delay_serial: int = 0
var _game_log
var _effect_ports_ref
var _effect_executor = null
var _technique_draw_counts: Dictionary = {}
var behavior_registry
var _card_trigger_replay_service = null
var _rng: RandomNumberGenerator = null
var battle_permission_service = null

func _init(
        catalog,
        battle_timing_system = null,
        game_log_override = null,
        effect_ports = null) -> void:
    content_catalog = catalog
    lifecycle = CardStateLifecycleScript.new(catalog)
    behavior_registry = StatusBehaviorRegistryScript.new()
    timing_system = battle_timing_system
    _game_log = game_log_override
    use_effect_ports(effect_ports)
    if timing_system != null:
        timing_system.register_weak_handler(
            timing_system.AFTER_NORMAL_DRAW,
            "status_system.delayed_after_draw",
            500,
            self,
            "_on_after_normal_draw_delays")
        timing_system.register_weak_handler(
            timing_system.AFTER_NORMAL_DRAW,
            "status_system.after_normal_draw_behaviors",
            800,
            self,
            "_on_after_normal_draw")
        timing_system.register_weak_handler(
            timing_system.BATTLE_START,
            "status_system.card_battle_start",
            100,
            self,
            "_on_battle_start")
        timing_system.register_weak_handler(
            timing_system.TURN_START,
            "status_system.technique_draw_history",
            50,
            self,
            "_on_turn_start")
        timing_system.register_weak_handler(
            timing_system.TURN_END,
            "status_system.delayed_records",
            500,
            self,
            "_on_turn_end")
        timing_system.register_weak_handler(
            timing_system.DEFENSE_DECAY_RESOLVED,
            "status_system.defense_decay_records", 500, self,
            "_on_defense_decay_resolved")
        timing_system.register_weak_handler(
            timing_system.ROUND_START,
            "status_system.next_round_records", 500, self,
            "_on_round_start_records")
        timing_system.register_weak_handler(
            timing_system.ACTION_RESOLUTION_END,
            "status_system.action_resolution_records", 500, self,
            "_on_action_resolution_end_records")
        timing_system.register_weak_handler(
            timing_system.TURN_END,
            "status_system.card_turn_end_final",
            1100,
            self,
            "_on_card_turn_end_final")
        timing_system.register_weak_handler(
            timing_system.TURN_END,
            "status_system.combat_source_expiry",
            1200,
            self,
            "_on_combat_source_turn_end")
        timing_system.register_weak_handler(
            timing_system.BATTLE_END,
            "status_system.transferred_card_return",
            90,
            self,
            "_on_transferred_card_battle_end")
        timing_system.register_weak_handler(
            timing_system.BATTLE_END,
            "status_system.card_battle_end",
            100,
            self,
            "_on_card_battle_end")
        timing_system.register_weak_handler(
            timing_system.BATTLE_END,
            "status_system.transient_battle_end",
            900,
            self,
            "_on_transient_battle_end")

func use_game_log(game_log_override) -> void:
    _game_log = game_log_override

func use_effect_ports(effect_ports) -> void:
    _effect_ports_ref = weakref(effect_ports) if effect_ports != null else null

func use_effect_executor(executor) -> void:
    _effect_executor = executor

func use_card_trigger_replay_service(service) -> void:
    _card_trigger_replay_service = service

func use_rng(random_source: RandomNumberGenerator) -> void:
    _rng = random_source

func use_battle_permission_service(service) -> void:
    battle_permission_service = service

func reset() -> void:
    delayed_records.clear()
    response_records.clear()
    history.clear()
    _serial = 0
    _delay_serial = 0
    _technique_draw_counts.clear()

func register_response(
        event_kind: String,
        expiry: String,
        effects: Array,
        context,
        filters: Dictionary = {}) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    var resolved_filters := filters.duplicate(true)
    if resolved_filters.has("card_instance_ids_from_capture"):
        var capture_id := str(resolved_filters["card_instance_ids_from_capture"])
        resolved_filters["card_instance_ids"] = runtime.captures.get(capture_id, []).map(
            func(card): return str(card.id))
        resolved_filters.erase("card_instance_ids_from_capture")
    if resolved_filters.has("source_card_instance_ids_from_capture"):
        var capture_id := str(resolved_filters["source_card_instance_ids_from_capture"])
        resolved_filters["source_card_instance_ids"] = runtime.captures.get(
            capture_id, []).map(func(card): return str(card.id))
        resolved_filters.erase("source_card_instance_ids_from_capture")
    if resolved_filters.has("source_tokens_from_capture"):
        var capture_id := str(resolved_filters["source_tokens_from_capture"])
        resolved_filters["source_tokens"] = runtime.captures.get(
            capture_id, []).map(func(value): return str(
                value.get("source_token", "") if value is Dictionary else ""))
        resolved_filters.erase("source_tokens_from_capture")
    var record := {
        "id": "response-%06d" % _delay_serial,
        "event_kind": event_kind,
        "expiry": expiry,
        "effects": effects.duplicate(true),
        "filters": resolved_filters,
        "actor": runtime.actor,
        "target": runtime.target,
        "power": runtime.power,
        "initial_power": runtime.initial_power,
        "hand_result": runtime.hand_result.duplicate(true),
        "played_cards": runtime.played_cards.duplicate(),
        "group_snapshot": runtime.group_snapshot.duplicate(true),
        "captures": runtime.captures.duplicate(true),
        "technique_id": runtime.technique_id,
        "technique_name": runtime.technique_name,
        "actual_hand_id": runtime.actual_hand_id,
        "branch_hand_id": runtime.branch_hand_id,
        "technique_pool": runtime.technique_pool,
        "action_token": runtime.action_token,
        "source_round": _current_round_hint(runtime),
        "resolving": false,
        "remaining_triggers": int(filters.get("max_triggers", -1)),
    }
    _delay_serial += 1
    response_records.append(record)
    return {"success": true, "record": record}

func register_next_round_hand_limit(context, amount: int, affected_side = null) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    var side = affected_side if affected_side != null else runtime.actor
    if side == null or amount == 0:
        return {"success": false, "reason": "下一回合手牌上限参数无效"}
    var record := {
        "id": "hand-limit-%06d" % _delay_serial,
        "kind": "next_round_hand_limit",
        "actor": side,
        "amount": amount,
        "source_round": _current_round_hint(runtime),
        "active_round": -1,
    }
    _delay_serial += 1
    delayed_records.append(record)
    return {"success": true, "record": record}

func handle_response_event(event_kind: String, values: Dictionary) -> void:
    if _effect_executor == null:
        return
    var matching: Array = response_records.filter(func(record):
        return str(record.get("event_kind", "")) == event_kind \
            and not bool(record.get("resolving", false)) \
            and _response_matches(record, values))
    for record in matching:
        record["resolving"] = true
        var captures: Dictionary = record.get("captures", {}).duplicate(true)
        captures["event"] = [values.duplicate(true)]
        if values.has("card"):
            captures["event_card"] = [values["card"]]
        if values.has("pre_move_snapshot"):
            captures["event_snapshot"] = [values["pre_move_snapshot"]]
        var response_context = EffectContextScript.new().configure({
            "ports": _effect_ports(), "actor": record["actor"],
            "target": record["target"], "power": int(record["power"]),
            "initial_power": int(record["initial_power"]),
            "hand_result": record["hand_result"],
            "played_cards": record["played_cards"],
            "group_snapshot": record["group_snapshot"],
            "captures": captures,
            "technique_id": record["technique_id"],
            "technique_name": record["technique_name"],
            "actual_hand_id": record["actual_hand_id"],
            "branch_hand_id": record["branch_hand_id"],
            "technique_pool": record["technique_pool"],
            "action_token": record["action_token"],
            "source_kind": "response",
        })
        var response_result: Dictionary = _effect_executor.execute_all(
            record["effects"], response_context)
        record["resolving"] = false
        if response_result.get("success", false) \
                and int(record.get("remaining_triggers", -1)) > 0:
            record["remaining_triggers"] = int(record["remaining_triggers"]) - 1
            if int(record["remaining_triggers"]) <= 0:
                response_records.erase(record)

func _response_matches(record: Dictionary, values: Dictionary) -> bool:
    var filters: Dictionary = record.get("filters", {})
    if str(filters.get("owner", "")) == "actor" \
            and values.get("actor") != record.get("actor"):
        return false
    if str(filters.get("holder", "")) == "target" \
            and values.get("holder") != record.get("target"):
        return false
    if filters.has("reason") and str(values.get("reason", "")) != str(filters["reason"]):
        return false
    if filters.has("from_zone") and str(values.get("from_zone", "")) != str(filters["from_zone"]):
        return false
    if filters.has("to_zone") and str(values.get("to_zone", "")) != str(filters["to_zone"]):
        return false
    if bool(filters.get("next_round", false)) \
            and int(values.get("round_number", -1)) != int(record.get("source_round", -1)) + 1:
        return false
    if filters.has("card_instance_ids") \
            and not filters["card_instance_ids"].has(str(values.get("source_card_instance_id", ""))):
        return false
    if filters.has("source_card_instance_ids") \
            and not filters["source_card_instance_ids"].has(str(values.get("source_card_instance_id", ""))):
        return false
    if filters.has("source_tokens") \
            and not filters["source_tokens"].has(str(values.get("source_token", ""))):
        return false
    if bool(filters.get("action_token_is_record", false)) \
            and str(values.get("action_token", "")) != str(record.get("action_token", "")):
        return false
    if bool(filters.get("attacker_is_actor", false)) \
            and values.get("attacker") != record.get("actor"):
        return false
    if bool(filters.get("defender_is_actor", false)) \
            and values.get("defender") != record.get("actor"):
        return false
    if bool(filters.get("attacker_is_target", false)) \
            and values.get("attacker") != record.get("target"):
        return false
    if bool(filters.get("holder_is_actor", false)) \
            and values.get("holder") != record.get("actor"):
        return false
    if bool(filters.get("actual_life_loss_positive", false)) \
            and int(values.get("actual_life_loss", values.get("life_lost", 0))) <= 0:
        return false
    if filters.has("life_lost_equals") \
            and int(values.get("life_lost", values.get("actual_life_loss", 0))) \
                != int(filters["life_lost_equals"]):
        return false
    if filters.has("damage_type") \
            and str(values.get("damage_type", "")) != str(filters["damage_type"]):
        return false
    if filters.has("defense_after_equals") \
            and int(values.get("defense_after", -1)) != int(filters["defense_after_equals"]):
        return false
    if bool(filters.get("defense_lost_positive", false)) \
            and int(values.get("defense_lost", 0)) <= 0:
        return false
    if filters.has("source_kind_in") \
            and not filters["source_kind_in"].has(str(values.get("source_kind", ""))):
        return false
    if filters.has("source_category") \
            and str(values.get("source_category", "")) != str(filters["source_category"]):
        return false
    if filters.has("same_qi_gain_at_least") \
            and int(values.get("same_qi_gain", values.get("gained", 0))) \
                < int(filters["same_qi_gain_at_least"]):
        return false
    if filters.has("conversion_count_at_least") \
            and int(values.get("conversion_count", values.get(
                "same_qi_trigger_count", 0))) \
                < int(filters["conversion_count_at_least"]):
        return false
    if filters.has("is_extra_action") \
            and bool(values.get("is_extra_action", false)) != bool(filters["is_extra_action"]):
        return false
    if filters.has("from_same_qi") \
            and bool(values.get("from_same_qi", false)) != bool(filters["from_same_qi"]):
        return false
    if filters.has("became_burned_out") \
            and bool(values.get("became_burned_out", false)) \
                != bool(filters["became_burned_out"]):
        return false
    if filters.has("challenge_met") \
            and bool(values.get("challenge_met", false)) \
                != bool(filters["challenge_met"]):
        return false
    if filters.has("challenge_difference_at_least") \
            and int(values.get("difference", 0)) \
                < int(filters["challenge_difference_at_least"]):
        return false
    if bool(filters.get("same_action_window", false)) \
            and not values.get("action_tokens", []).has(str(record.get("action_token", ""))):
        return false
    var snapshot: Dictionary = values.get("pre_move_snapshot", {})
    if bool(filters.get("had_poison", false)) and not bool(snapshot.get("had_poison", false)):
        return false
    if bool(filters.get("had_burned_out", false)) \
            and not bool(snapshot.get("had_burned_out", false)):
        return false
    return true

func card_numeric_modifier(card, modifier_id: String) -> int:
    if card == null or modifier_id == "":
        return 0
    var total := 0
    var snapshot: Dictionary = card.anomaly_snapshot()
    var anomaly_ids: Array = []
    anomaly_ids.append_array(snapshot.get("buffs", {}).keys())
    anomaly_ids.append_array(snapshot.get("debuffs", {}).keys())
    if not snapshot.get("state", {}).is_empty():
        anomaly_ids.append(str(snapshot["state"].get("id", "")))
    anomaly_ids.append_array(snapshot.get("marks", {}).keys())
    for anomaly_id in anomaly_ids:
        var definition: Dictionary = content_catalog.get_by_id("anomaly", str(anomaly_id))
        for modifier_value in definition.get("modifiers", []):
            var modifier: Dictionary = modifier_value
            if str(modifier.get("id", "")) == modifier_id:
                var layers := 1
                var category := str(definition.get("category", ""))
                if category in ["buff", "debuff", "state"]:
                    layers = card.anomaly_layers(category, str(anomaly_id))
                total += layers * int(modifier.get("value", 0))
    return total

func actor_hand_card_numeric_modifier(side, modifier_id: String) -> int:
    var total := 0
    for card in side.hand:
        total += card_numeric_modifier(card, modifier_id)
    return total

func modify_card_contribution(card, contribution: int, holder = null) -> int:
    return contribution

func can_play_card(holder, card) -> Dictionary:
    if battle_permission_service != null:
        return battle_permission_service.can_play_card(holder, card)
    return _legacy_can_play_card(holder, card)

func _legacy_can_play_card(holder, card) -> Dictionary:
    var result := _dispatch_card_behaviors("play_attempt", holder, card)
    if bool(result.get("blocked", false)):
        return {"allowed": false, "reason": str(result.get("reason", "此真气本回合不能打出"))}
    return {"allowed": true}

func permission_query(hook: String, context: Dictionary) -> Dictionary:
    if hook == "card_play_permission_query":
        return _legacy_can_play_card(context.get("owner", context.get("actor")), context.get("card"))
    # 状态系统目前没有额外的明确弃牌否决；统一端口仍记录这一来源。
    return {"allowed": true}

func can_play_cards(holder, cards: Array) -> Dictionary:
    for card in cards:
        var result := can_play_card(holder, card)
        if not bool(result.get("allowed", false)):
            return result
    return {"allowed": true}

func record_technique_card_flow(side, flow_kind: String, count: int) -> void:
    if flow_kind == "draw" and count > 0:
        var side_key := int(side.get_instance_id())
        _technique_draw_counts[side_key] = int(_technique_draw_counts.get(side_key, 0)) + count

func technique_draw_count(side) -> int:
    return int(_technique_draw_counts.get(int(side.get_instance_id()), 0))

func _on_turn_start(event) -> Dictionary:
    if event.actor != null:
        _technique_draw_counts.erase(int(event.actor.get_instance_id()))
    return {"success": true}

func apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary = {},
        source: String = "效果",
        layers: int = 1,
        replace_state: bool = false,
        event_metadata: Dictionary = {}) -> Dictionary:
    var before = _card_anomaly_value(card, category, anomaly_id)
    var result: Dictionary = lifecycle.apply_anomaly(
        card, category, anomaly_id, payload, layers, replace_state)
    if not result.get("success", false):
        return result
    _record_change(
        "card_anomaly_apply",
        "card",
        str(card.id),
        anomaly_id,
        before,
        _card_anomaly_value(card, category, anomaly_id),
        source,
        {"category": category, "refreshed": bool(result.get("refreshed", false))})
    _emit_card_anomaly_change(
        card, category, anomaly_id, before,
        _card_anomaly_value(card, category, anomaly_id), source,
        event_metadata)
    return result

func can_apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        replace_state: bool = false) -> Dictionary:
    return lifecycle.can_apply_anomaly(card, category, anomaly_id, replace_state)

func remove_card_anomaly(
        card,
        category: String,
        anomaly_id: String = "",
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    var resolved_id := anomaly_id
    if resolved_id == "" and category == "state":
        resolved_id = str(card.current_state().get("id", ""))
    var changed: bool = card.has_anomaly(category, anomaly_id)
    var before = _card_anomaly_value(card, category, resolved_id)
    var removed = card.remove_anomaly(category, anomaly_id)
    if changed:
        _record_change(
            "card_anomaly_remove",
            "card",
            str(card.id),
            resolved_id if resolved_id != "" else category,
            before,
            null,
            source,
            {"category": category})
        _emit_card_anomaly_change(
            card, category, resolved_id, before, null, source,
            event_metadata)
    return {
        "success": true,
        "changed": changed,
        "removed": removed,
        "anomaly_id": resolved_id,
    }

func transfer_card_anomaly(
        source_card,
        target_card,
        category: String,
        anomaly_id: String,
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    if source_card == null or target_card == null or source_card == target_card:
        return {"success": false, "reason": "异状转移需要不同的来源与目标"}
    if not source_card.has_anomaly(category, anomaly_id):
        return {"success": false, "reason": "异状转移来源不再持有目标异状"}
    var permission: Dictionary = lifecycle.can_apply_anomaly(
        target_card, category, anomaly_id, false)
    if not permission.get("allowed", false):
        return {"success": false, "reason": permission.get("reason", "目标不能获得异状")}
    var source_before = _card_anomaly_value(source_card, category, anomaly_id)
    var target_before = _card_anomaly_value(target_card, category, anomaly_id)
    var applied: Dictionary = lifecycle.apply_anomaly(
        target_card, category, anomaly_id, {}, 1, false)
    if not applied.get("success", false):
        return applied
    source_card.remove_anomaly(category, anomaly_id)
    var target_after = _card_anomaly_value(target_card, category, anomaly_id)
    _record_change(
        "card_anomaly_transfer_out", "card", str(source_card.id), anomaly_id,
        source_before, null, source, {"category": category, "target_id": str(target_card.id)})
    _record_change(
        "card_anomaly_transfer_in", "card", str(target_card.id), anomaly_id,
        target_before, target_after, source,
        {"category": category, "source_id": str(source_card.id)})
    var source_metadata := event_metadata.duplicate(true)
    source_metadata["transfer_peer_card_id"] = str(target_card.id)
    var target_metadata := event_metadata.duplicate(true)
    target_metadata["transfer_peer_card_id"] = str(source_card.id)
    _emit_card_anomaly_change(
        source_card, category, anomaly_id, source_before, null,
        source, source_metadata)
    _emit_card_anomaly_change(
        target_card, category, anomaly_id, target_before, target_after,
        source, target_metadata)
    return {
        "success": true,
        "changed": true,
        "source_card": source_card,
        "target_card": target_card,
        "category": category,
        "anomaly_id": anomaly_id,
    }

func _emit_card_anomaly_change(
        card,
        category: String,
        anomaly_id: String,
        before,
        after,
        source: String,
        event_metadata: Dictionary) -> void:
    if card == null or anomaly_id == "":
        return
    var holder = event_metadata.get("holder", event_metadata.get("actor"))
    if holder == null:
        var ports = _effect_ports()
        if ports != null:
            var location: Dictionary = ports.locate_active_card(str(card.id))
            holder = location.get("side") if location.get("success", false) else null
    var values := event_metadata.duplicate(true)
    values.merge({
        "actor": holder,
        "holder": holder,
        "card": card,
        "source_card_instance_id": str(card.id),
        "category": category,
        "anomaly_id": anomaly_id,
        "before": before,
        "after": after,
        "changed": before != after,
        "applied": after != null,
        "removed": after == null,
        "source": source,
        "base_qi": int(card.current_base_qi_value()) \
            if card.has_method("current_base_qi_value") else int(card.qi_value),
        "card_base_qi": int(card.qi_value),
    }, true)
    handle_response_event("card_anomaly_changed", values)
    if category == "mark" and anomaly_id == "burned_out":
        values["became_burned_out"] = before == null and after != null
        values["ceased_burned_out"] = before != null and after == null
        handle_response_event("card_burned_out_changed", values)

func set_card_anomaly_layers(
        card,
        category: String,
        anomaly_id: String,
        layers: int,
        source: String = "效果") -> Dictionary:
    if card == null or category not in ["buff", "debuff"] or anomaly_id == "" or layers < 0:
        return {"success": false, "reason": "异状层数设置参数无效"}
    var before: int = card.anomaly_layers(category, anomaly_id)
    if before == layers:
        return {"success": true, "changed": false, "before": before, "after": layers}
    if layers == 0:
        card.remove_anomaly(category, anomaly_id)
    else:
        var permission: Dictionary = lifecycle.can_apply_anomaly(
            card, category, anomaly_id, false)
        if not permission.get("allowed", false) and before <= 0:
            return {"success": false, "reason": permission.get("reason", "不能设置异状层数")}
        card.set_anomaly(category, anomaly_id, {}, layers)
    _record_change(
        "card_anomaly_layers_set", "card", str(card.id), anomaly_id,
        before, layers, source, {"category": category})
    return {"success": true, "changed": true, "before": before, "after": layers}

func on_card_enter_discard(card, source: String = "进入弃牌堆") -> Dictionary:
    var removed: Dictionary = lifecycle.on_enter_discard(card)
    if not removed.get("state", {}).is_empty():
        var before_state: Dictionary = removed["state"]
        _record_change(
            "card_anomaly_remove", "card", str(card.id), str(before_state.get("id", "")),
            before_state, null, source, {"category": "state"})
    return removed

func on_card_enter_discard_behaviors(holder, card) -> void:
    _dispatch_card_behaviors("enter_discard", holder, card)

func on_card_enter_discard_late(holder, card) -> void:
    _dispatch_card_behaviors("enter_discard_late", holder, card)

func on_card_drawn(holder, card) -> void:
    if not holder.hand.has(card):
        return
    _dispatch_card_behaviors("draw", holder, card)

func on_card_explicit_discard(holder, card, allow_void_departure: bool = false) -> void:
    if not holder.discard_pile.has(card) and not allow_void_departure:
        return
    _dispatch_card_behaviors("explicit_discard", holder, card)

func _on_after_normal_draw(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "正常补牌完成时点缺少行动方"}
    handle_response_event("after_normal_draw", {
        "actor": event.actor,
        "holder": event.actor,
        "round_number": int(event.round_number),
        "drawn_cards": event.context.get("drawn_cards", []).duplicate(),
        "event_cards": event.context.get("drawn_cards", []).duplicate(),
    })
    return {"success": true}

func resolve_played_card_anomalies(
        holder,
        cards: Array,
        source_values: Dictionary = {}) -> Array:
    var resolutions: Array = []
    for card in cards:
        for resolution in _dispatch_card_behaviors(
                "played", holder, card, source_values).get("resolutions", []):
            resolutions.append(resolution)
    return resolutions

func effective_qi_value(card) -> int:
    var value: int = (
        card.effective_qi_value(true)
        if card.has_method("effective_qi_value") else int(card.qi_value))
    return maxi(0, value)

func _dispatch_card_behaviors(
        trigger: String,
        holder,
        card,
        source_values: Dictionary = {}) -> Dictionary:
    var entries: Array = []
    var snapshot: Dictionary = card.anomaly_snapshot()
    for status_id in snapshot.get("buffs", {}).keys():
        _append_card_behavior_entries(entries, trigger, "buff", str(status_id))
    for status_id in snapshot.get("debuffs", {}).keys():
        _append_card_behavior_entries(entries, trigger, "debuff", str(status_id))
    var state: Dictionary = snapshot.get("state", {})
    _append_card_behavior_entries(entries, trigger, "state", str(state.get("id", "")))
    for status_id in snapshot.get("marks", {}).keys():
        _append_card_behavior_entries(entries, trigger, "mark", str(status_id))
    entries.sort_custom(func(left, right):
        if int(left["priority"]) != int(right["priority"]):
            return int(left["priority"]) < int(right["priority"])
        if str(left["status_id"]) != str(right["status_id"]):
            return str(left["status_id"]) < str(right["status_id"])
        return int(left["behavior_index"]) < int(right["behavior_index"]))
    var source_trigger := _qualified_card_trigger(trigger)
    var replay_count := 0
    if source_trigger != "" and _card_trigger_replay_service != null:
        replay_count = _card_trigger_replay_service.qualified_replay_count(
            card, source_trigger, source_values)
    var normal := _execute_card_behavior_entries(
        entries,
        trigger,
        source_trigger,
        holder,
        card,
        source_values,
        0,
        0,
        true)
    var aggregate: Dictionary = normal["aggregate"]
    for replay_index in range(replay_count):
        var replayed := _execute_card_behavior_entries(
            normal["executed_entries"],
            trigger,
            source_trigger,
            holder,
            card,
            source_values,
            1,
            replay_index + 1,
            false)
        _merge_card_behavior_aggregate(
            aggregate, replayed["aggregate"])
    return aggregate

func _execute_card_behavior_entries(
        entries: Array,
        trigger: String,
        source_trigger: String,
        holder,
        card,
        source_values: Dictionary,
        replay_depth: int,
        trigger_sequence: int,
        require_current_anomaly: bool) -> Dictionary:
    var aggregate := {
        "resolutions": [],
        "stop_card_behaviors": false,
        "blocked": false,
        "reason": "",
    }
    var executed_entries: Array = []
    for entry_value in entries:
        var entry: Dictionary = entry_value.duplicate(true)
        if require_current_anomaly and not card.has_anomaly(
                str(entry["category"]), str(entry["status_id"])):
            continue
        if replay_depth == 0 \
                and str(entry.get("behavior", {}).get("handler", "")) \
                    == "damage_holder_by_current_qi":
            entry["behavior"]["frozen_amount"] = effective_qi_value(card)
        var context_values := source_values.duplicate()
        context_values.merge({
            "trigger": trigger,
            "status_id": entry["status_id"],
            "category": entry["category"],
            "definition": entry["definition"],
            "behavior": entry["behavior"],
            "holder": holder,
            "card": card,
            "status_system": self,
            "effect_ports": _effect_ports(),
            "source_card_instance_id": str(card.id),
            "source_trigger": source_trigger,
            "action_token": str(source_values.get("action_token", "")),
            "replay_depth": replay_depth,
            "trigger_sequence": trigger_sequence,
            "rng": _rng,
        }, true)
        var context = StatusBehaviorContextScript.new().configure(
            context_values)
        var result: Dictionary = behavior_registry.execute(entry["behavior"], context)
        if not bool(result.get("success", false)):
            continue
        executed_entries.append(entry)
        if result.has("resolution"):
            var resolution: Dictionary = result["resolution"]
            resolution.merge({
                "source_card_instance_id": str(card.id),
                "source_trigger": source_trigger,
                "action_token": str(source_values.get("action_token", "")),
                "replay_depth": replay_depth,
                "trigger_sequence": trigger_sequence,
            }, false)
            aggregate["resolutions"].append(resolution)
        if bool(result.get("blocked", false)):
            aggregate["blocked"] = true
            aggregate["reason"] = str(result.get("reason", ""))
        if bool(result.get("stop_card_behaviors", false)):
            aggregate["stop_card_behaviors"] = true
            break
    return {
        "aggregate": aggregate,
        "executed_entries": executed_entries,
    }

func _merge_card_behavior_aggregate(
        target: Dictionary,
        addition: Dictionary) -> void:
    target["resolutions"].append_array(addition.get("resolutions", []))
    target["stop_card_behaviors"] = (
        bool(target.get("stop_card_behaviors", false))
        or bool(addition.get("stop_card_behaviors", false)))
    target["blocked"] = (
        bool(target.get("blocked", false))
        or bool(addition.get("blocked", false)))
    if str(target.get("reason", "")) == "":
        target["reason"] = str(addition.get("reason", ""))

func _qualified_card_trigger(status_trigger: String) -> String:
    match status_trigger:
        "played": return "card_played"
        "draw": return "card_drawn"
        "explicit_discard": return "card_explicitly_discarded"
        "enter_discard": return "card_entered_discard"
        "turn_end": return "turn_end"
    return ""

func _append_card_behavior_entries(
        entries: Array,
        trigger: String,
        category: String,
        status_id: String) -> void:
    if status_id == "":
        return
    var definition: Dictionary = content_catalog.get_by_id("anomaly", status_id)
    for behavior_index in range(definition.get("behaviors", []).size()):
        var behavior_value = definition.get("behaviors", [])[behavior_index]
        var behavior: Dictionary = behavior_value
        if str(behavior.get("trigger", "")) != trigger:
            continue
        entries.append({
            "priority": int(behavior.get("priority", 500)),
            "category": category,
            "status_id": status_id,
            "definition": definition,
            "behavior": behavior,
            "behavior_index": behavior_index,
        })

func register_delayed_effects(
        label: String,
        timing: String,
        occurrences: int,
        effects: Array,
        context) -> Dictionary:
    if timing not in ["turn_end", "after_normal_draw"]:
        return {"success": false, "reason": "不支持的延迟时点：%s" % timing}
    var runtime = EffectContextScript.coerce(context)
    var record := {
        "id": "delay-%06d" % _delay_serial,
        "kind": "effect_chain",
        "label": label,
        "timing": timing,
        "remaining_occurrences": maxi(1, occurrences),
        "effects": effects.duplicate(true),
        "power": runtime.power,
        "initial_power": runtime.initial_power,
        "direct_power_fixed": runtime.direct_power_fixed,
        "direct_power_percent": runtime.direct_power_percent,
        "pre_momentum_power": runtime.pre_momentum_power,
        "momentum_used": runtime.momentum_used,
        "actor": runtime.actor,
        "target": runtime.target,
        "hand_result": runtime.hand_result.duplicate(true),
        "played_cards": runtime.played_cards.duplicate(),
        "group_snapshot": runtime.group_snapshot.duplicate(true),
        "captures": runtime.captures.duplicate(true),
        "frozen_targets": runtime.captures.values().duplicate(true),
        "technique_id": runtime.technique_id,
        "technique_name": runtime.technique_name,
        "actual_hand_id": runtime.actual_hand_id,
        "branch_hand_id": runtime.branch_hand_id,
        "technique_pool": runtime.technique_pool,
        "sequence_book": runtime.sequence_book,
        "source_action_token": runtime.action_token,
    }
    _delay_serial += 1
    delayed_records.append(record)
    return {"success": true, "record": record}

func register_defense_decay_return(runtime) -> Dictionary:
    var record := {
        "id": "decay-return-%06d" % _delay_serial,
        "kind": "defense_decay_return", "actor": runtime.actor,
        "source_round": _current_round_hint(runtime), "captured_decay": -1,
    }
    _delay_serial += 1
    delayed_records.append(record)
    return {"success": true, "record": record}

func register_reflection_expiry(runtime, percent: int) -> Dictionary:
    var token := "reflection-%06d" % _delay_serial
    _delay_serial += 1
    return _effect_ports().grant_reflection_source(
        runtime.actor, percent, 1, "round_end",
        runtime.technique_name if runtime.technique_name != "" else "反震",
        token, runtime.target)

func register_no_life_loss_disruption(runtime, effect: Dictionary) -> Dictionary:
    delayed_records.append({
        "id": "window-check-%06d" % _delay_serial,
        "kind": "no_life_loss_disruption", "actor": runtime.actor,
        "target": runtime.target,
        "action_token": runtime.action_token,
        "effect": effect.duplicate(true),
    })
    _delay_serial += 1
    return {"success": true}

func _on_defense_decay_resolved(event) -> Dictionary:
    var decay: Dictionary = event.context.get("decay", {})
    for record in delayed_records:
        if record.get("kind") == "defense_decay_return" \
                and record.get("actor") == event.actor \
                and int(record.get("captured_decay", -1)) < 0:
            record["captured_decay"] = int(decay.get("lost", 0))
            record["return_round"] = int(event.round_number) + 1
    handle_response_event("defense_decay_resolved", {
        "actor": event.actor,
        "holder": event.actor,
        "round_number": int(event.round_number),
        "decay": decay.duplicate(true),
    })
    return {"success": true}

func _on_round_start_records(event) -> Dictionary:
    var event_round := int(event.round_number)
    var event_actors: Array = (
        event.get("actors", []) if event is Dictionary else event.actors)
    for event_actor in event_actors:
        for record in delayed_records:
            if record.get("kind") == "next_round_hand_limit" \
                    and record.get("actor") == event_actor \
                    and int(record.get("source_round", -1)) + 1 == event_round:
                event_actor.base_hand_limit_modifier += int(record.get("amount", 0))
                record["active_round"] = event_round
        handle_response_event("round_start", {
            "actor": event_actor,
            "holder": event_actor,
            "round_number": event_round,
        })
    var due: Array = delayed_records.filter(func(record):
        return record.get("kind") == "defense_decay_return" \
            and int(record.get("return_round", -1)) == event_round)
    for record in due:
        var actor = record["actor"]
        if _effect_ports() != null:
            _effect_ports().add_defense(
                actor, int(record.get("captured_decay", 0)), "delayed_technique")
        delayed_records.erase(record)
    return {"success": true, "detail": "返还 %d 份防御衰减记录" % due.size()}

func _on_action_resolution_end_records(event) -> Dictionary:
    var due: Array = delayed_records.filter(func(record):
        return record.get("kind") == "no_life_loss_disruption" \
            and _action_token_matches(record, event.context))
    for record in due:
        var actor_result: Dictionary = {}
        for result_value in event.context.get("action_results", []):
            var result: Dictionary = result_value
            if result.get("side") == record["actor"]:
                actor_result = result
                break
        if int(actor_result.get("actual_life_loss", 0)) <= 0:
            var context = EffectContextScript.new().configure({
                "ports": _effect_ports(), "actor": record["actor"],
                "target": record["target"], "source_kind": "delayed_technique",
                "captures": {},
            })
            _effect_executor.execute_all([record["effect"]], context)
        delayed_records.erase(record)
    handle_response_event("action_resolution_end", {
        "actors": event.actors,
        "action_tokens": event.context.get("metadata", {}).get(
            "action_tokens", []).duplicate(),
        "action_window_id": event.context.get("metadata", {}).get(
            "action_window_id", ""),
        "action_results": event.context.get("action_results", []).duplicate(true),
        "round_number": int(event.round_number),
    })
    var window_id := str(event.context.get(
        "metadata", {}).get("action_window_id", ""))
    if window_id != "":
        for side in event.actors:
            _resolve_challenges_for_window(side, window_id)
        for side in event.actors:
            var expired: Dictionary = side.expire_action_window_sources(window_id)
            for record in expired.get("reflection_records", []):
                _effect_ports().notify_source_changed(
                    "reflection_source_changed", side, record, "expired")
            for record in expired.get("block_records", []):
                _effect_ports().notify_source_changed(
                    "block_source_changed", side, record, "expired")
            if not expired.get("reflection", []).is_empty() \
                    or not expired.get("blocks", []).is_empty():
                _effect_ports().add_history(
                    "source_expiry", "%s行动窗来源到期" % side.name,
                    "战斗来源", "成功",
                    "反震%d／格挡%d" % [
                        expired.get("reflection", []).size(),
                        expired.get("blocks", []).size()])
    return {"success": true}

func _action_token_matches(record: Dictionary, context: Dictionary) -> bool:
    var record_token := str(record.get("action_token", ""))
    if record_token == "":
        return true
    for token_value in context.get("metadata", {}).get("action_tokens", []):
        if str(token_value) == record_token:
            return true
    return false

func _current_round_hint(runtime) -> int:
    return int(runtime.action_token.split("-")[-2]) \
        if runtime.action_token.split("-").size() >= 3 else 0

func _on_battle_start(event) -> Dictionary:
    var applied_count := 0
    for side in event.actors:
        for zone in [side.draw_pile, side.hand, side.staging, side.discard_pile]:
            for card in zone:
                for result in lifecycle.on_battle_start(card):
                    if result.get("success", false):
                        applied_count += 1
                        _record_change(
                            "card_anomaly_apply",
                            "card",
                            str(card.id),
                            str(result.get("anomaly_id", result.get("reshape_id", "battle_start"))),
                            null,
                            "applied",
                            "战斗开始重塑")
    return {
        "success": true,
        "detail": "处理 %d 个战斗开始真气效果" % applied_count,
    }

func _on_turn_end(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "回合结束时点缺少行动方"}
    var event_round := int(
        event.get("round_number", -1) if event is Dictionary else event.round_number)
    var due: Array = []
    for delayed in delayed_records:
        if delayed.get("actor") != event.actor:
            continue
        if delayed.get("kind", "") == "effect_chain" \
                and delayed.get("timing", "") == "turn_end":
            due.append(delayed)
    for delayed in due:
        _resolve_delayed_effect_chain(delayed)
        delayed["remaining_occurrences"] = int(delayed["remaining_occurrences"]) - 1
        if int(delayed["remaining_occurrences"]) <= 0:
            delayed_records.erase(delayed)
        _record_change(
            "delay_resolve",
            "actor",
            str(event.actor.owner_id),
            str(delayed["id"]),
            0,
            null,
            str(delayed["label"]))
    _dispatch_card_turn_end(event.actor)
    handle_response_event("turn_end", {
        "actor": event.actor,
        "holder": event.actor,
        "round_number": event_round,
    })
    for record in delayed_records.duplicate():
        if record.get("kind") == "next_round_hand_limit" \
                and record.get("actor") == event.actor \
                and int(record.get("active_round", -1)) == event_round:
            event.actor.base_hand_limit_modifier -= int(record.get("amount", 0))
            delayed_records.erase(record)
    for record in response_records.duplicate():
        if record.get("expiry") == "turn_end" \
                and record.get("actor") == event.actor:
            response_records.erase(record)
        elif record.get("expiry") == "next_round_turn_end" \
                and record.get("actor") == event.actor \
                and int(record.get("source_round", -1)) + 1 <= event_round:
            response_records.erase(record)
    return {
        "success": true,
        "detail": "%s结算 %d 个到期延迟效果" % [event.actor.name, due.size()],
    }

func _dispatch_card_turn_end(holder) -> void:
    for card in holder.hand.duplicate():
        _dispatch_card_behaviors("turn_end", holder, card)

func _on_card_turn_end_final(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "最终回合结束时点缺少行动方"}
    for card in event.actor.hand.duplicate():
        _dispatch_card_behaviors("turn_end_final", event.actor, card)
    return {"success": true}

func _on_combat_source_turn_end(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "战斗来源到期缺少行动方"}
    var expired: Dictionary = event.actor.tick_round_limited_sources()
    for record in expired.get("reflection_records", []):
        _effect_ports().notify_source_changed(
            "reflection_source_changed", event.actor, record, "expired")
    for record in expired.get("true_damage_records", []):
        _effect_ports().notify_source_changed(
            "reflection_source_changed", event.actor, record, "true_damage_expired")
    return {
        "success": true,
        "detail": "反震来源到期%d／真伤修改到期%d" % [
            expired.get("reflection", []).size(),
            expired.get("true_damage", []).size()],
    }

func _resolve_challenges_for_window(side, window_id: String) -> void:
    if _effect_executor == null or side == null:
        return
    var due: Array = side.challenge_records.filter(func(record):
        return not bool(record.get("waiting_for_action", false)) \
            and str(record.get("window_id", "")) == window_id)
    for record in due:
        var threshold := int(record.get("threshold", 0))
        var current := int(record.get("current", 0))
        var difference := maxi(
            0, threshold - current)
        var met := current >= threshold
        var challenge_result := {
            "source_token": str(record.get("source_token", "")),
            "threshold": threshold,
            "current": current,
            "difference": difference,
            "met": met,
            "branch": "met" if met else "unmet",
        }
        record["resolution"] = challenge_result.duplicate(true)
        var branch_effects: Array = record.get(
            "met_effects", []) if met else record.get("effects", [])
        if not branch_effects.is_empty():
            var captures: Dictionary = record.get("captures", {}).duplicate(true)
            captures["challenge_result"] = [challenge_result.duplicate(true)]
            captures["challenge_difference"] = [{"amount": difference}]
            var context = EffectContextScript.new().configure({
                "ports": _effect_ports(),
                "actor": record["challenger"], "target": record["target"],
                "power": int(record.get("power", 0)),
                "initial_power": int(record.get("initial_power", 0)),
                "hand_result": record.get("hand_result", {}),
                "played_cards": record.get("played_cards", []),
                "group_snapshot": record.get("group_snapshot", {}),
                "captures": captures,
                "technique_id": str(record.get("technique_id", "")),
                "technique_name": str(record.get("technique_name", "")),
                "actual_hand_id": str(record.get("actual_hand_id", "")),
                "branch_hand_id": str(record.get("branch_hand_id", "")),
                "technique_pool": str(record.get("technique_pool", "")),
                "action_token": str(record.get("action_token", "")),
                "source_kind": "challenge",
            })
            _effect_executor.execute_all(branch_effects, context)
        _effect_ports().add_history(
            "challenge_resolved", str(record.get("label", "邀战")),
            side.name, "达标" if met else "未达标", "%d/%d，差额%d" % [
                current, threshold, difference])
        _effect_ports().notify_source_changed(
            "challenge_resolved", side, record, "resolved", challenge_result)
        handle_response_event("challenge_resolved", {
            "actor": side,
            "holder": side,
            "target": record.get("target"),
            "source_token": str(record.get("source_token", "")),
            "action_token": str(record.get("action_token", "")),
            "threshold": threshold,
            "current": current,
            "difference": difference,
            "challenge_met": met,
            "branch": challenge_result["branch"],
        })
        side.challenge_records.erase(record)

func _on_after_normal_draw_delays(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "正常补牌完成时点缺少行动方"}
    var due: Array = []
    for delayed in delayed_records:
        if delayed.get("kind", "") == "effect_chain" \
                and delayed.get("timing", "") == "after_normal_draw" \
                and delayed.get("actor") == event.actor:
            due.append(delayed)
    for delayed in due:
        _resolve_delayed_effect_chain(delayed)
        delayed["remaining_occurrences"] = int(delayed["remaining_occurrences"]) - 1
        if int(delayed["remaining_occurrences"]) <= 0:
            delayed_records.erase(delayed)
    return {"success": true, "detail": "结算%d个补牌后延迟效果" % due.size()}

func _resolve_delayed_effect_chain(record: Dictionary) -> Dictionary:
    if _effect_executor == null:
        return {"success": false, "detail": "延迟效果缺少统一执行器"}
    var context = EffectContextScript.new().configure({
        "ports": _effect_ports(),
        "actor": record["actor"],
        "target": record["target"],
        "hand_result": record["hand_result"],
        "played_cards": record["played_cards"],
        "power": int(record["power"]),
        "initial_power": int(record.get("initial_power", record["power"])),
        "direct_power_fixed": int(record.get("direct_power_fixed", 0)),
        "direct_power_percent": int(record.get("direct_power_percent", 0)),
        "pre_momentum_power": int(record.get("pre_momentum_power", record["power"])),
        "momentum_used": int(record.get("momentum_used", 0)),
        "technique_id": str(record["technique_id"]),
        "technique_name": str(record["technique_name"]),
        "actual_hand_id": str(record.get("actual_hand_id", "")),
        "branch_hand_id": str(record.get("branch_hand_id", "")),
        "technique_pool": str(record.get("technique_pool", "")),
        "sequence_book": record.get("sequence_book"),
        "action_token": "%s:delay:%s" % [
            str(record.get("source_action_token", "")),
            str(record.get("id", "delay")),
        ],
        "source_kind": "delayed_technique",
        "captures": record.get("captures", {}).duplicate(true),
        "group_snapshot": record.get("group_snapshot", {}).duplicate(true),
    })
    return _effect_executor.execute_all(record["effects"], context)

func _on_card_battle_end(event) -> Dictionary:
    var cleaned_count := 0
    for side in event.actors:
        side.direct_power_fixed = 0
        side.direct_power_percent = 0
        side.momentum_value = 0
        side.last_successful_technique_hand_id = ""
        side.clear_combat_sources()
        var cards: Array = []
        for zone in [
                side.draw_pile,
                side.hand,
                side.staging,
                side.discard_pile,
                side.temporarily_removed_cards]:
            for card in zone:
                if not cards.has(card):
                    cards.append(card)
        for card in cards:
            var before: Dictionary = card.anomaly_snapshot()
            lifecycle.on_battle_end(card)
            cleaned_count += 1
            if before != card.anomaly_snapshot():
                _record_change(
                    "card_battle_end_cleanup",
                    "card",
                    str(card.id),
                    "all_anomalies",
                    before,
                    card.anomaly_snapshot(),
                    "战斗结束")
        for card in cards:
            if bool(card.temporary_card):
                side.card_zone_service.permanently_remove(
                    side, str(card.id), "battle_end_temporary")
    return {
        "success": true,
        "detail": "清理 %d 张真气的战斗异状" % cleaned_count,
    }

func _on_transferred_card_battle_end(event) -> Dictionary:
    if event.actors.is_empty() or event.actors[0] == null:
        return {"success": true, "detail": "没有需要归还的临时转移真气"}
    var returned: Array = event.actors[0].card_zone_service.return_all_transferred_cards(
        event.actors)
    return {
        "success": true,
        "detail": "归还 %d 张临时转移真气" % returned.size(),
    }

func _on_transient_battle_end(event) -> Dictionary:
    var cleared_delays := delayed_records.size() + response_records.size()
    delayed_records.clear()
    response_records.clear()
    return {
        "success": true,
        "detail": "清理 %d 个延迟记录" % cleared_delays,
    }

func history_snapshot(limit: int = 0) -> Array:
    var copied: Array = history.duplicate(true)
    if limit > 0 and copied.size() > limit:
        return copied.slice(copied.size() - limit)
    return copied

func _record_change(
        change_type: String,
        target_kind: String,
        target_id: String,
        status_id: String,
        before_value,
        after_value,
        source: String,
        metadata: Dictionary = {}) -> Dictionary:
    var change = StatusChangeScript.new().configure({
        "serial": _serial,
        "change_type": change_type,
        "target_kind": target_kind,
        "target_id": target_id,
        "status_id": status_id,
        "before_value": before_value,
        "after_value": after_value,
        "source": source,
        "metadata": metadata,
    })
    _serial += 1
    var snapshot: Dictionary = change.snapshot()
    history.append(snapshot)
    if _game_log != null:
        _game_log.record_battle(
            "status_change",
            "%s·%s" % [target_id, _status_name(status_id)],
            source,
            "成功",
            "%s → %s" % [str(before_value), str(after_value)])
    return snapshot

func _status_name(status_id: String) -> String:
    var anomaly: Dictionary = content_catalog.get_by_id("anomaly", status_id)
    return str(anomaly.get("name", status_id)) if not anomaly.is_empty() else status_id

func _card_anomaly_value(card, category: String, anomaly_id: String):
    match category:
        "buff", "debuff", "state": return card.anomaly_layers(category, anomaly_id)
        "mark": return card.anomaly_snapshot().get("marks", {}).get(anomaly_id, null)
    return null

func _effective_qi_value(card) -> int:
    return effective_qi_value(card)

func _effect_ports():
    return _effect_ports_ref.get_ref() if _effect_ports_ref != null else null
