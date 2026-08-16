class_name StatusSystem
extends RefCounted

const EffectContextScript = preload("res://core/effects/battle_effect_context.gd")
const StatusHistoryServiceScript = preload(
    "res://core/statuses/status_history_service.gd")
const CardAnomalyServiceScript = preload(
    "res://core/statuses/card_anomaly_service.gd")
const CardStatusBehaviorServiceScript = preload(
    "res://core/statuses/card_status_behavior_service.gd")
const StatusResponseServiceScript = preload(
    "res://core/statuses/status_response_service.gd")
const StatusDelayServiceScript = preload(
    "res://core/statuses/status_delay_service.gd")
const StatusRecordIdAllocatorScript = preload(
    "res://core/statuses/status_record_id_allocator.gd")

var content_catalog
var timing_system
var delayed_records: Array = []
var response_records: Array = []
var history: Array = []
var status_history
var card_anomaly_service
var card_status_behavior_service
var status_response_service
var status_delay_service
var runtime_record_id_allocator
var _effect_ports_ref
var _effect_executor = null
var _technique_draw_counts: Dictionary = {}
var behavior_registry
var _rng: RandomNumberGenerator = null
var battle_permission_service = null

func _init(
        catalog,
        battle_timing_system = null,
        game_log_override = null,
        effect_ports = null) -> void:
    content_catalog = catalog
    timing_system = battle_timing_system
    status_history = StatusHistoryServiceScript.new(catalog, game_log_override)
    card_anomaly_service = CardAnomalyServiceScript.new(
        catalog, status_history)
    card_status_behavior_service = CardStatusBehaviorServiceScript.new(
        catalog, card_anomaly_service)
    runtime_record_id_allocator = StatusRecordIdAllocatorScript.new()
    status_response_service = StatusResponseServiceScript.new(
        runtime_record_id_allocator)
    status_delay_service = StatusDelayServiceScript.new(
        status_history, runtime_record_id_allocator)
    behavior_registry = card_status_behavior_service.behavior_registry
    history = status_history.history_entries()
    response_records = status_response_service.records()
    delayed_records = status_delay_service.records()
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
    status_history.use_game_log(game_log_override)

func replace_history(entries: Array) -> void:
    status_history.replace_history(entries)

func use_effect_ports(effect_ports) -> void:
    _effect_ports_ref = weakref(effect_ports) if effect_ports != null else null
    card_anomaly_service.use_effect_ports(effect_ports)
    card_status_behavior_service.use_effect_ports(effect_ports)
    status_response_service.use_effect_ports(effect_ports)
    status_delay_service.use_effect_ports(effect_ports)

func use_effect_executor(executor) -> void:
    _effect_executor = executor
    status_response_service.use_effect_executor(executor)
    status_delay_service.use_effect_executor(executor)

func use_card_trigger_replay_service(service) -> void:
    card_status_behavior_service.use_card_trigger_replay_service(service)

func use_rng(random_source: RandomNumberGenerator) -> void:
    _rng = random_source
    card_status_behavior_service.use_rng(random_source)

func use_battle_permission_service(service) -> void:
    battle_permission_service = service

func reset() -> void:
    status_delay_service.clear()
    status_response_service.clear()
    status_history.reset()
    runtime_record_id_allocator.reset()
    _technique_draw_counts.clear()

func register_response(
        event_kind: String,
        expiry: String,
        effects: Array,
        context,
        filters: Dictionary = {},
        expiry_effects: Array = []) -> Dictionary:
    return status_response_service.register_response(
        event_kind, expiry, effects, context, filters, expiry_effects)

func register_next_round_hand_limit(context, amount: int, affected_side = null) -> Dictionary:
    return status_delay_service.register_next_round_hand_limit(
        context, amount, affected_side)

func handle_response_event(event_kind: String, values: Dictionary) -> void:
    status_response_service.handle_event(event_kind, values)

func on_committed_event_for_responses(
        event_kind: String,
        values: Dictionary,
        receipt: Dictionary) -> void:
    status_response_service.on_committed_event(event_kind, values, receipt)

func runtime_record_serial() -> int:
    return runtime_record_id_allocator.current_serial()

func restore_runtime_record_serial(value: int) -> void:
    runtime_record_id_allocator.restore_serial(value)

func card_numeric_modifier(card, modifier_id: String) -> int:
    return card_anomaly_service.card_numeric_modifier(card, modifier_id)

func actor_hand_card_numeric_modifier(side, modifier_id: String) -> int:
    return card_anomaly_service.actor_hand_card_numeric_modifier(
        side, modifier_id)

func modify_card_contribution(card, contribution: int, holder = null) -> int:
    return card_anomaly_service.modify_card_contribution(
        card, contribution, holder)

func can_play_card(holder, card) -> Dictionary:
    if battle_permission_service != null:
        return battle_permission_service.can_play_card(holder, card)
    return card_status_behavior_service.can_play_card(holder, card)

func permission_query(hook: String, context: Dictionary) -> Dictionary:
    if hook == "card_play_permission_query":
        return card_status_behavior_service.can_play_card(
            context.get("owner", context.get("actor")), context.get("card"))
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
    return card_anomaly_service.apply_card_anomaly(
        card, category, anomaly_id, payload, source, layers, replace_state,
        event_metadata)

func can_apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        replace_state: bool = false) -> Dictionary:
    return card_anomaly_service.can_apply_card_anomaly(
        card, category, anomaly_id, replace_state)

func remove_card_anomaly(
        card,
        category: String,
        anomaly_id: String = "",
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return card_anomaly_service.remove_card_anomaly(
        card, category, anomaly_id, source, event_metadata)

func transfer_card_anomaly(
        source_card,
        target_card,
        category: String,
        anomaly_id: String,
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return card_anomaly_service.transfer_card_anomaly(
        source_card, target_card, category, anomaly_id, source,
        event_metadata)

func set_card_anomaly_layers(
        card,
        category: String,
        anomaly_id: String,
        layers: int,
        source: String = "效果") -> Dictionary:
    return card_anomaly_service.set_card_anomaly_layers(
        card, category, anomaly_id, layers, source)

func on_card_enter_discard(card, source: String = "进入弃牌堆") -> Dictionary:
    return card_anomaly_service.on_card_enter_discard(card, source)

func on_card_enter_discard_behaviors(holder, card) -> void:
    card_status_behavior_service.on_card_enter_discard(holder, card)

func on_card_enter_discard_late(holder, card) -> void:
    card_status_behavior_service.on_card_enter_discard_late(holder, card)

func on_card_drawn(holder, card) -> void:
    card_status_behavior_service.on_card_drawn(holder, card)

func on_card_explicit_discard(holder, card, allow_void_departure: bool = false) -> void:
    card_status_behavior_service.on_card_explicit_discard(
        holder, card, allow_void_departure)

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
    return card_status_behavior_service.resolve_played_card_anomalies(
        holder, cards, source_values)

func effective_qi_value(card) -> int:
    return card_anomaly_service.effective_qi_value(card)

func register_delayed_effects(
        label: String,
        timing: String,
        occurrences: int,
        effects: Array,
        context) -> Dictionary:
    return status_delay_service.register_effect_chain(
        label, timing, occurrences, effects, context)

func register_defense_decay_return(runtime) -> Dictionary:
    return status_delay_service.register_defense_decay_return(runtime)

func register_reflection_expiry(runtime, percent: int) -> Dictionary:
    var token: String = runtime_record_id_allocator.next_id("reflection")
    return _effect_ports().grant_reflection_source(
        runtime.actor, percent, 1, "round_end",
        runtime.source_name if runtime.source_name != "" else "反震",
        token, runtime.target)

func register_no_life_loss_disruption(runtime, effect: Dictionary) -> Dictionary:
    return status_delay_service.register_no_life_loss_disruption(
        runtime, effect)

func _on_defense_decay_resolved(event) -> Dictionary:
    var decay: Dictionary = event.context.get("decay", {})
    status_delay_service.capture_defense_decay(
        event.actor, int(event.round_number), decay)
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
    return status_delay_service.on_round_start(event_actors, event_round)

func _on_action_resolution_end_records(event) -> Dictionary:
    status_delay_service.resolve_action_end_records(event.context)
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

func _on_battle_start(event) -> Dictionary:
    var applied_count := 0
    for side in event.actors:
        for zone in [side.draw_pile, side.hand, side.staging, side.discard_pile]:
            for card in zone:
                var result: Dictionary = (
                    card_anomaly_service.on_card_battle_start(card))
                applied_count += int(result.get("applied_count", 0))
    return {
        "success": true,
        "detail": "处理 %d 个战斗开始真气效果" % applied_count,
    }

func _on_turn_end(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "回合结束时点缺少行动方"}
    var event_round := int(
        event.get("round_number", -1) if event is Dictionary else event.round_number)
    var delay_result: Dictionary = status_delay_service.resolve_turn_end_effects(
        event.actor, event_round)
    card_status_behavior_service.on_turn_end(event.actor)
    status_delay_service.expire_turn_end_modifiers(event.actor, event_round)
    status_response_service.expire_turn_end(event.actor, event_round)
    return {
        "success": true,
        "detail": "%s结算 %d 个到期延迟效果" % [
            event.actor.name, int(delay_result.get("resolved_count", 0))],
    }

func _on_card_turn_end_final(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "最终回合结束时点缺少行动方"}
    card_status_behavior_service.on_turn_end_final(event.actor)
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
                "source_kind": record.get("source_kind", "rule"),
                "source_id": record.get("source_id", ""),
                "source_name": record.get("source_name", ""),
                "source_instance_key": record.get("source_instance_key", ""),
                "trigger_mode": "delayed",
            })
            _effect_executor.execute_all(branch_effects, context)
        _effect_ports().add_history(
            "challenge_resolved", str(record.get("label", "邀战")),
            side.name, "达标" if met else "未达标", "%d/%d，差额%d" % [
                current, threshold, difference])
        _effect_ports().notify_source_changed(
            "challenge_resolved", side, record, "resolved", challenge_result)
        side.challenge_records.erase(record)

func _on_after_normal_draw_delays(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "正常补牌完成时点缺少行动方"}
    return status_delay_service.resolve_after_normal_draw(event.actor)

func _on_card_battle_end(event) -> Dictionary:
    var cleaned_count := 0
    for side in event.actors:
        side.direct_power_fixed = 0
        side.direct_power_percent = 0
        side.momentum_value = 0
        side.last_successful_technique_hand_id = ""
        side.clear_combat_sources()
        side.source_marker_store.clear_scope("battle")
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
            card_anomaly_service.on_card_battle_end(card)
            cleaned_count += 1
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
    var cleared_delays: int = status_delay_service.clear()
    cleared_delays += status_response_service.clear()
    return {
        "success": true,
        "detail": "清理 %d 个延迟记录" % cleared_delays,
    }

func history_snapshot(limit: int = 0) -> Array:
    return status_history.history_snapshot(limit)

func _effect_ports():
    return _effect_ports_ref.get_ref() if _effect_ports_ref != null else null
