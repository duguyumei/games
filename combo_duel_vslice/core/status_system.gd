class_name StatusSystem
extends RefCounted

const CardStateLifecycleScript = preload("res://core/card_state_lifecycle.gd")
const StatusChangeScript = preload("res://core/status_change.gd")
const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")

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

func _init(
        catalog,
        battle_timing_system = null,
        game_log_override = null,
        effect_ports = null) -> void:
    content_catalog = catalog
    lifecycle = CardStateLifecycleScript.new(catalog)
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
            "status_system.qi_intake_duration",
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

func record_technique_card_flow(side, flow_kind: String, count: int) -> void:
    if flow_kind == "draw" and count > 0:
        var side_key := int(side.get_instance_id())
        _technique_draw_counts[side_key] = int(_technique_draw_counts.get(side_key, 0)) + count
    var amount := actor_status_value(side, "four_symbols_harmony")
    if amount <= 0 or count <= 0:
        return
    var effect_ports = _effect_ports()
    if flow_kind == "draw":
        side.add_defense(amount * count)
    elif flow_kind == "discard" and effect_ports != null:
        var opponent = effect_ports.opponent_of(side)
        if opponent != null:
            effect_ports.deal_damage(
                side, opponent, amount * count, "technique_persistent")

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
    if card.has_anomaly("mark", "qi_severance"):
        var effect_ports = _effect_ports()
        remove_card_anomaly(card, "mark", "qi_severance", "绝气标记触发")
        apply_card_anomaly(card, "state", "forbidden", {}, "绝气标记触发")
        if effect_ports != null:
            for side in effect_ports._sides:
                if side.discard_pile.has(card):
                    effect_ports.move_card(
                        side, "discard_pile", side, "draw_pile", card,
                        "qi_severance", "top")
                    break
    return removed

func on_card_drawn(holder, card) -> void:
    var effect_ports = _effect_ports()
    if effect_ports == null:
        return
    var opponent = effect_ports.opponent_of(holder)
    if opponent != null \
            and actor_status_value(opponent, "steal_wind") > 0 \
            and card.is_attribute("wind"):
        consume_actor_status(opponent, "steal_wind", 1, "夺风")
        effect_ports.move_card(
            holder, "hand", opponent, "hand", card, "steal_wind")
        return
    if not holder.hand.has(card):
        return
    if card.has_anomaly("mark", "turbulence"):
        remove_card_anomaly(card, "mark", "turbulence", "乱流触发")
        effect_ports.move_card(
            holder, "hand", holder, "discard_pile", card,
            "explicit_discard")
        return
    if card.has_anomaly("mark", "wind_lure"):
        remove_card_anomaly(card, "mark", "wind_lure", "风引触发")
        holder.draw(1)

func on_card_explicit_discard(holder, card) -> void:
    if not holder.discard_pile.has(card) \
            or not card.has_anomaly("mark", "returning_wind"):
        return
    remove_card_anomaly(card, "mark", "returning_wind", "回风触发")
    var effect_ports = _effect_ports()
    if effect_ports != null:
        effect_ports.move_card(
            holder, "discard_pile", holder, "draw_pile", card,
            "returning_wind", "top")

func _on_after_normal_draw(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "正常补牌完成时点缺少行动方"}
    var consumed := 0
    if actor_status_value(event.actor, "qi_intake") > 0:
        consumed = int(consume_actor_status(
            event.actor, "qi_intake", 1, "正常补牌完成").get("changed", 0))
    return {"success": true, "detail": "纳气层数 -%d" % consumed}

func resolve_played_card_anomalies(holder, cards: Array) -> Array:
    var resolutions: Array = []
    var effect_ports = _effect_ports()
    if effect_ports == null:
        return resolutions
    for card in cards:
        if not card.has_anomaly("poison", "lethal_poison"):
            continue
        remove_card_anomaly(card, "poison", "lethal_poison", "烈毒触发")
        var poison_damage := _effective_qi_value(card)
        effect_ports.deal_damage(holder, holder, poison_damage, "烈毒")
        var recycled := actor_status_value(holder, "gu_mark") > 0
        if recycled:
            consume_actor_status(holder, "gu_mark", 1, "烈毒续毒")
        resolutions.append({
            "card": card,
            "anomaly_id": "lethal_poison",
            "damage": poison_damage,
            "recycle": recycled,
        })
    return resolutions

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
    return {
        "success": true,
        "detail": "%s结算 %d 个到期延迟效果" % [event.actor.name, due.size()],
    }

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
    var value := maxi(0, int(card.qi_value))
    match str(card.reshape_enhancement):
        "bonus": value += 2
        "glass": value *= 2
        "stone": value = 0
    return value

func _effect_ports():
    return _effect_ports_ref.get_ref() if _effect_ports_ref != null else null
