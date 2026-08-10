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

func reset() -> void:
    delayed_records.clear()
    history.clear()
    _serial = 0
    _delay_serial = 0
    _technique_draw_counts.clear()

func actor_status_value(side, status_id: String) -> int:
    return maxi(0, int(side.stacks.get(status_id, 0)))

func card_numeric_modifier(card, modifier_id: String) -> int:
    if card == null or modifier_id == "":
        return 0
    var total := 0
    var snapshot: Dictionary = card.anomaly_snapshot()
    var anomaly_ids: Array = []
    if str(snapshot.get("poison", "")) != "":
        anomaly_ids.append(str(snapshot["poison"]))
    if str(snapshot.get("state", "")) != "":
        anomaly_ids.append(str(snapshot["state"]))
    anomaly_ids.append_array(snapshot.get("marks", {}).keys())
    anomaly_ids.append_array(snapshot.get("others", {}).keys())
    for anomaly_id in anomaly_ids:
        var definition: Dictionary = content_catalog.get_by_id("anomaly", str(anomaly_id))
        for modifier_value in definition.get("modifiers", []):
            var modifier: Dictionary = modifier_value
            if str(modifier.get("id", "")) == modifier_id:
                total += int(modifier.get("value", 0))
    return total

func actor_hand_card_numeric_modifier(side, modifier_id: String) -> int:
    var total := 0
    for card in side.hand:
        total += card_numeric_modifier(card, modifier_id)
    return total

func modify_card_contribution(card, contribution: int, holder = null) -> int:
    var value := int(floor(contribution * (100.0 + card_numeric_modifier(
            card, "qi_contribution_percent")) / 100.0))
    var reduction_percent := card_numeric_modifier(
        card, "poison_contribution_reduction_percent")
    if reduction_percent != 0:
        var poison_effect_percent := 100
        if holder != null:
            poison_effect_percent += actor_numeric_modifier(
                holder, "poison_effect_percent")
        value -= int(floor(value * reduction_percent * poison_effect_percent / 10000.0))
    return value

func can_play_card(holder, card) -> Dictionary:
    var result := _dispatch_card_behaviors("play_attempt", holder, card)
    if bool(result.get("blocked", false)):
        return {"allowed": false, "reason": str(result.get("reason", "此真气本回合不能打出"))}
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
    _dispatch_actor_behaviors(side, "technique_card_flow", {
        "flow_kind": flow_kind,
        "count": count,
    })

func technique_draw_count(side) -> int:
    return int(_technique_draw_counts.get(int(side.get_instance_id()), 0))

func _on_turn_start(event) -> Dictionary:
    if event.actor != null:
        _technique_draw_counts.erase(int(event.actor.get_instance_id()))
    return {"success": true}

func add_actor_status(
        side,
        status_id: String,
        amount: int,
        source: String = "效果") -> Dictionary:
    var definition: Dictionary = content_catalog.get_by_id("actor_status", status_id)
    if definition.is_empty():
        return {"success": false, "reason": "未知角色状态：%s" % status_id}
    var before := actor_status_value(side, status_id)
    var gained := maxi(0, amount)
    var after := before + gained
    var maximum := int(definition.get("maximum", -1))
    if maximum >= 0:
        after = mini(after, maximum)
    gained = after - before
    if after > 0:
        side.stacks[status_id] = after
    _record_change(
        "actor_status_add",
        "actor",
        str(side.owner_id),
        status_id,
        before,
        after,
        source)
    return {
        "success": true,
        "status_id": status_id,
        "before": before,
        "after": after,
        "changed": gained,
    }

func consume_actor_status(
        side,
        status_id: String,
        amount: int,
        source: String = "效果") -> Dictionary:
    if content_catalog.get_by_id("actor_status", status_id).is_empty():
        return {"success": false, "reason": "未知角色状态：%s" % status_id}
    var before := actor_status_value(side, status_id)
    var consumed := mini(before, maxi(0, amount))
    var after := before - consumed
    if after <= 0:
        side.stacks.erase(status_id)
    else:
        side.stacks[status_id] = after
    _record_change(
        "actor_status_consume",
        "actor",
        str(side.owner_id),
        status_id,
        before,
        after,
        source)
    return {
        "success": true,
        "status_id": status_id,
        "before": before,
        "after": after,
        "changed": consumed,
    }

func apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary = {},
        source: String = "效果") -> Dictionary:
    var before = _card_anomaly_value(card, category, anomaly_id)
    var result: Dictionary = lifecycle.apply_anomaly(
        card, category, anomaly_id, payload)
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

func remove_card_anomaly(
        card,
        category: String,
        anomaly_id: String = "",
        source: String = "效果") -> Dictionary:
    var resolved_id := anomaly_id
    if resolved_id == "":
        if category == "poison":
            resolved_id = str(card.anomaly_poison)
        elif category == "state":
            resolved_id = str(card.anomaly_state)
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
    var before_poison := str(card.anomaly_poison)
    var before_state := str(card.anomaly_state)
    var removed: Dictionary = lifecycle.on_enter_discard(card)
    if str(removed.get("poison", "")) != "":
        _record_change(
            "card_anomaly_remove", "card", str(card.id), before_poison,
            before_poison, null, source, {"category": "poison"})
    if str(removed.get("state", "")) != "":
        _record_change(
            "card_anomaly_remove", "card", str(card.id), before_state,
            before_state, null, source, {"category": "state"})
    var effect_ports = _effect_ports()
    var holder = (
        effect_ports.side_holding_card(card, "discard_pile")
        if effect_ports != null else null)
    _dispatch_card_behaviors("enter_discard", holder, card)
    return removed

func on_card_drawn(holder, card) -> void:
    var effect_ports = _effect_ports()
    if effect_ports == null:
        return
    var opponent = effect_ports.opponent_of(holder)
    if opponent != null and _dispatch_actor_behaviors(
            opponent,
            "opponent_card_drawn",
            {"holder": holder, "card": card}).get("stop_card_behaviors", false):
        return
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
    var result := _dispatch_actor_behaviors(
        event.actor, "after_normal_draw", {"event": event})
    return {"success": true, "detail": str(result.get("detail", ""))}

func resolve_played_card_anomalies(holder, cards: Array) -> Array:
    var resolutions: Array = []
    for card in cards:
        for resolution in _dispatch_card_behaviors("played", holder, card).get(
                "resolutions", []):
            _dispatch_actor_behaviors(holder, "played_card_anomaly_resolved", {
                "card": card,
                "resolution": resolution,
            })
            resolutions.append(resolution)
    return resolutions

func actor_numeric_modifier(
        side,
        modifier_id: String,
        context: Dictionary = {}) -> int:
    var total := 0
    for status_id_value in side.stacks.keys():
        var status_id := str(status_id_value)
        var stacks := actor_status_value(side, status_id)
        if stacks <= 0:
            continue
        var definition: Dictionary = content_catalog.get_by_id("actor_status", status_id)
        for modifier_value in definition.get("modifiers", []):
            var modifier: Dictionary = modifier_value
            if str(modifier.get("id", "")) != modifier_id \
                    or not _modifier_context_matches(modifier, context):
                continue
            total += int(modifier.get("presence", 0))
            total += stacks * int(modifier.get("per_stack", 0))
    return total

func status_modifier_per_stack(
        status_id: String,
        modifier_id: String,
        context: Dictionary = {}) -> int:
    var definition: Dictionary = content_catalog.get_by_id("actor_status", status_id)
    for modifier_value in definition.get("modifiers", []):
        var modifier: Dictionary = modifier_value
        if str(modifier.get("id", "")) == modifier_id \
                and _modifier_context_matches(modifier, context):
            return int(modifier.get("per_stack", 0))
    return 0

func effective_qi_value(card) -> int:
    return card.effective_qi_value(true) if card.has_method("effective_qi_value") else int(card.qi_value)

func _dispatch_card_behaviors(trigger: String, holder, card) -> Dictionary:
    var entries: Array = []
    var snapshot: Dictionary = card.anomaly_snapshot()
    _append_card_behavior_entries(entries, trigger, "poison", str(snapshot.get("poison", "")))
    _append_card_behavior_entries(entries, trigger, "state", str(snapshot.get("state", "")))
    for status_id in snapshot.get("marks", {}).keys():
        _append_card_behavior_entries(entries, trigger, "mark", str(status_id))
    for status_id in snapshot.get("others", {}).keys():
        _append_card_behavior_entries(entries, trigger, "other", str(status_id))
    entries.sort_custom(func(left, right):
        if int(left["priority"]) != int(right["priority"]):
            return int(left["priority"]) < int(right["priority"])
        if str(left["status_id"]) != str(right["status_id"]):
            return str(left["status_id"]) < str(right["status_id"])
        return int(left["behavior_index"]) < int(right["behavior_index"]))
    var resolutions: Array = []
    var stopped := false
    var blocked := false
    var block_reason := ""
    for entry_value in entries:
        var entry: Dictionary = entry_value
        if not card.has_anomaly(str(entry["category"]), str(entry["status_id"])):
            continue
        var context = StatusBehaviorContextScript.new().configure({
            "trigger": trigger,
            "status_id": entry["status_id"],
            "category": entry["category"],
            "definition": entry["definition"],
            "behavior": entry["behavior"],
            "holder": holder,
            "card": card,
            "status_system": self,
            "effect_ports": _effect_ports(),
        })
        var result: Dictionary = behavior_registry.execute(entry["behavior"], context)
        if result.has("resolution"):
            resolutions.append(result["resolution"])
        if bool(result.get("blocked", false)):
            blocked = true
            block_reason = str(result.get("reason", ""))
        if bool(result.get("stop_card_behaviors", false)):
            stopped = true
            break
    return {
        "resolutions": resolutions,
        "stop_card_behaviors": stopped,
        "blocked": blocked,
        "reason": block_reason,
    }

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

func _dispatch_actor_behaviors(
        side,
        trigger: String,
        values: Dictionary = {}) -> Dictionary:
    var entries: Array = []
    for status_id_value in side.stacks.keys():
        var status_id := str(status_id_value)
        if actor_status_value(side, status_id) <= 0:
            continue
        var definition: Dictionary = content_catalog.get_by_id("actor_status", status_id)
        for behavior_index in range(definition.get("behaviors", []).size()):
            var behavior: Dictionary = definition.get("behaviors", [])[behavior_index]
            if str(behavior.get("trigger", "")) == trigger:
                entries.append({
                    "priority": int(behavior.get("priority", 500)),
                    "status_id": status_id,
                    "definition": definition,
                    "behavior": behavior,
                    "behavior_index": behavior_index,
                })
    entries.sort_custom(func(left, right):
        if int(left["priority"]) != int(right["priority"]):
            return int(left["priority"]) < int(right["priority"])
        if str(left["status_id"]) != str(right["status_id"]):
            return str(left["status_id"]) < str(right["status_id"])
        return int(left["behavior_index"]) < int(right["behavior_index"]))
    var stopped := false
    var consumed := 0
    for entry_value in entries:
        var entry: Dictionary = entry_value
        if actor_status_value(side, str(entry["status_id"])) <= 0:
            continue
        var context_values := values.duplicate()
        context_values.merge({
            "trigger": trigger,
            "status_id": entry["status_id"],
            "definition": entry["definition"],
            "behavior": entry["behavior"],
            "actor": side,
            "status_system": self,
            "effect_ports": _effect_ports(),
        }, true)
        var context = StatusBehaviorContextScript.new().configure(context_values)
        var result: Dictionary = behavior_registry.execute(entry["behavior"], context)
        consumed += int(result.get("consumed", 0))
        if bool(result.get("stop_card_behaviors", false)):
            stopped = true
            break
    return {
        "stop_card_behaviors": stopped,
        "detail": "状态层数 -%d" % consumed if consumed > 0 else "",
    }

func _modifier_context_matches(modifier: Dictionary, context: Dictionary) -> bool:
    var source_kinds = modifier.get("source_kinds", [])
    return not source_kinds is Array \
        or source_kinds.is_empty() \
        or source_kinds.has(str(context.get("source_kind", "")))

func register_attack_counter_delay(
        label: String,
        turn_ends: int,
        snapshot_power: int,
        damage_per_segment: int,
        actor,
        target) -> Dictionary:
    var record := {
        "id": "delay-%06d" % _delay_serial,
        "kind": "attack_counter",
        "label": label,
        "remaining_turn_ends": maxi(1, turn_ends),
        "snapshot_power": snapshot_power,
        "damage_per_segment": maxi(0, damage_per_segment),
        "attack_count": 0,
        "actor": actor,
        "target": target,
    }
    _delay_serial += 1
    delayed_records.append(record)
    _record_change(
        "delay_register",
        "actor",
        str(actor.owner_id),
        str(record["id"]),
        null,
        int(record["remaining_turn_ends"]),
        label,
        {
            "snapshot_power": snapshot_power,
            "damage_per_segment": damage_per_segment,
        })
    return {"success": true, "record": record}

func register_turn_end_stack(
        label: String,
        turn_ends: int,
        stack_id: String,
        amount: int,
        actor) -> Dictionary:
    if content_catalog.get_by_id("actor_status", stack_id).is_empty():
        return {"success": false, "reason": "未知角色状态：%s" % stack_id}
    var record := {
        "id": "delay-%06d" % _delay_serial,
        "kind": "turn_end_stack",
        "label": label,
        "remaining_turn_ends": maxi(1, turn_ends),
        "stack_id": stack_id,
        "amount": maxi(0, amount),
        "actor": actor,
    }
    _delay_serial += 1
    delayed_records.append(record)
    return {"success": true, "record": record}

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

func record_attack_segment(actor, source_kind: String) -> void:
    if source_kind not in ["technique", "chase", "counter"]:
        return
    for delayed in delayed_records:
        if delayed.get("kind", "") == "attack_counter" \
                and delayed.get("actor") == actor:
            delayed["attack_count"] = int(delayed.get("attack_count", 0)) + 1

func resolve_received_attack_segment(
        attacker,
        target,
        source_kind: String,
        result: Dictionary) -> Dictionary:
    if attacker == null or target == null or attacker == target \
            or source_kind not in ["technique", "chase", "counter"]:
        return {"success": true}
    return _dispatch_actor_behaviors(target, "attack_segment_received", {
        "attacker": attacker,
        "source_kind": source_kind,
        "defense_lost": int(result.get("defense_lost", 0)),
        "life_lost": int(result.get("life_lost", 0)),
    })

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
        if delayed.get("kind", "") == "effect_chain":
            if delayed.get("timing", "") == "turn_end":
                due.append(delayed)
            continue
        delayed["remaining_turn_ends"] = int(delayed["remaining_turn_ends"]) - 1
        if int(delayed["remaining_turn_ends"]) <= 0:
            due.append(delayed)
    var effect_ports = _effect_ports()
    for delayed in due:
        if delayed.get("kind", "") == "effect_chain":
            _resolve_delayed_effect_chain(delayed)
            delayed["remaining_occurrences"] = int(delayed["remaining_occurrences"]) - 1
            if int(delayed["remaining_occurrences"]) <= 0:
                delayed_records.erase(delayed)
        elif delayed.get("kind", "") == "turn_end_stack":
            delayed_records.erase(delayed)
            add_actor_status(
                delayed["actor"],
                str(delayed["stack_id"]),
                int(delayed["amount"]),
                str(delayed["label"]))
        elif effect_ports != null:
            delayed_records.erase(delayed)
            effect_ports.add_history(
                "turn_end", delayed["label"], "延迟功法", "结算",
                "快照 P=%d｜记录攻击段=%d｜每段=%d" % [
                    delayed["snapshot_power"],
                    delayed["attack_count"],
                    delayed["damage_per_segment"]])
            for _index in range(int(delayed["attack_count"])):
                if delayed["target"].life <= 0:
                    break
                effect_ports.deal_damage(
                    delayed["actor"],
                    delayed["target"],
                    delayed["damage_per_segment"],
                    "delayed_chase")
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
    var cards: Array = []
    for zone in [holder.draw_pile, holder.hand, holder.staging, holder.discard_pile]:
        for card in zone:
            if not cards.has(card):
                cards.append(card)
    for card in cards:
        _dispatch_card_behaviors("turn_end", holder, card)

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
    var cleared_stack_kinds := 0
    for side in event.actors:
        for status_id in side.stacks.keys():
            var before := int(side.stacks[status_id])
            side.stacks.erase(status_id)
            cleared_stack_kinds += 1
            _record_change(
                "actor_status_clear",
                "actor",
                str(side.owner_id),
                str(status_id),
                before,
                0,
                "战斗结束")
    var cleared_delays := delayed_records.size()
    delayed_records.clear()
    return {
        "success": true,
        "detail": "清理 %d 类层数与 %d 个延迟记录" % [
            cleared_stack_kinds,
            cleared_delays],
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
    var actor_status: Dictionary = content_catalog.get_by_id(
        "actor_status", status_id)
    if not actor_status.is_empty():
        return str(actor_status.get("name", status_id))
    var anomaly: Dictionary = content_catalog.get_by_id("anomaly", status_id)
    return str(anomaly.get("name", status_id)) if not anomaly.is_empty() else status_id

func _card_anomaly_value(card, category: String, anomaly_id: String):
    match category:
        "poison": return str(card.anomaly_poison)
        "state": return str(card.anomaly_state)
        "mark": return card.anomaly_marks.get(anomaly_id, null)
        "other": return card.anomaly_others.get(anomaly_id, null)
    return null

func _effective_qi_value(card) -> int:
    return effective_qi_value(card)

func _effect_ports():
    return _effect_ports_ref.get_ref() if _effect_ports_ref != null else null
