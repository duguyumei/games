class_name StatusSystem
extends RefCounted

const CardStateLifecycleScript = preload("res://core/card_state_lifecycle.gd")
const StatusChangeScript = preload("res://core/status_change.gd")

var content_catalog
var lifecycle
var timing_system
var delayed_records: Array = []
var history: Array = []
var _serial: int = 0
var _delay_serial: int = 0
var _game_log
var _combat_port_ref

func _init(
        catalog,
        battle_timing_system = null,
        game_log_override = null,
        combat_port = null) -> void:
    content_catalog = catalog
    lifecycle = CardStateLifecycleScript.new(catalog)
    timing_system = battle_timing_system
    _game_log = game_log_override
    if combat_port != null:
        _combat_port_ref = weakref(combat_port)
    if timing_system != null:
        timing_system.register_weak_handler(
            timing_system.BATTLE_START,
            "status_system.card_battle_start",
            100,
            self,
            "_on_battle_start")
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

func reset() -> void:
    delayed_records.clear()
    history.clear()
    _serial = 0
    _delay_serial = 0

func actor_status_value(side, status_id: String) -> int:
    return maxi(0, int(side.stacks.get(status_id, 0)))

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
    return removed

func resolve_played_card_anomalies(holder, cards: Array) -> Array:
    var resolutions: Array = []
    var combat_port = _combat_port()
    if combat_port == null:
        return resolutions
    for card in cards:
        if not card.has_anomaly("poison", "lethal_poison"):
            continue
        remove_card_anomaly(card, "poison", "lethal_poison", "烈毒触发")
        var poison_damage := _effective_qi_value(card)
        combat_port.deal_damage(holder, holder, poison_damage, "烈毒")
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
        delayed["remaining_turn_ends"] = int(delayed["remaining_turn_ends"]) - 1
        if int(delayed["remaining_turn_ends"]) <= 0:
            due.append(delayed)
    var combat_port = _combat_port()
    for delayed in due:
        delayed_records.erase(delayed)
        if combat_port != null:
            combat_port.trigger_queue.add_history(
                "turn_end", delayed["label"], "延迟功法", "结算",
                "快照 P=%d｜记录攻击段=%d｜每段=%d" % [
                    delayed["snapshot_power"],
                    delayed["attack_count"],
                    delayed["damage_per_segment"]])
            for _index in range(int(delayed["attack_count"])):
                if delayed["target"].life <= 0:
                    break
                combat_port.deal_damage(
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

func _combat_port():
    return _combat_port_ref.get_ref() if _combat_port_ref != null else null
