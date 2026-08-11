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
            timing_system.TURN_END,
            "status_system.card_turn_end_final",
            1100,
            self,
            "_on_card_turn_end_final")
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
    history.clear()
    _serial = 0
    _delay_serial = 0
    _technique_draw_counts.clear()

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
        replace_state: bool = false) -> Dictionary:
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
        source: String = "效果") -> Dictionary:
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
    return {
        "success": true,
        "changed": changed,
        "removed": removed,
        "anomaly_id": resolved_id,
    }

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

func on_card_explicit_discard(holder, card) -> void:
    if not holder.discard_pile.has(card):
        return
    _dispatch_card_behaviors("explicit_discard", holder, card)

func _on_after_normal_draw(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "正常补牌完成时点缺少行动方"}
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
        "technique_id": runtime.technique_id,
        "technique_name": runtime.technique_name,
        "actual_hand_id": runtime.actual_hand_id,
        "branch_hand_id": runtime.branch_hand_id,
        "technique_pool": runtime.technique_pool,
        "sequence_book": runtime.sequence_book,
    }
    _delay_serial += 1
    delayed_records.append(record)
    return {"success": true, "record": record}

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
        "source_kind": "delayed_technique",
        "captures": {},
    })
    return _effect_executor.execute_all(record["effects"], context)

func _on_card_battle_end(event) -> Dictionary:
    var cleaned_count := 0
    for side in event.actors:
        side.direct_power_fixed = 0
        side.direct_power_percent = 0
        side.momentum_value = 0
        side.last_successful_technique_hand_id = ""
        side.current_reflection_percent = 0
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
    return {
        "success": true,
        "detail": "清理 %d 张真气的战斗异状" % cleaned_count,
    }

func _on_transient_battle_end(event) -> Dictionary:
    var cleared_delays := delayed_records.size()
    delayed_records.clear()
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
