class_name StatusDelayService
extends RefCounted

const EffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")

const SUPPORTED_TIMINGS := ["round_start", "turn_end", "after_normal_draw"]

var _status_history
var _record_id_allocator
var _delayed_records: Array = []
var _effect_ports_ref: WeakRef
var _effect_executor = null


func _init(status_history, record_id_allocator) -> void:
    assert(status_history != null,
        "StatusDelayService requires StatusHistoryService")
    assert(record_id_allocator != null,
        "StatusDelayService requires StatusRecordIdAllocator")
    _status_history = status_history
    _record_id_allocator = record_id_allocator


func register_effect_chain(
        label: String,
        timing: String,
        occurrences: int,
        effects: Array,
        context,
        lifecycle: Dictionary = {}) -> Dictionary:
    if not is_supported_timing(timing):
        return {"success": false, "reason": "不支持的延迟时点：%s" % timing}
    var runtime = EffectContextScript.coerce(context)
    var record_key := str(lifecycle.get("record_key", ""))
    var existing: Variant = _find_keyed_effect_chain(runtime, record_key)
    var existing_policy := str(lifecycle.get(
        "existing_policy", "keep_existing"))
    if existing != null:
        match existing_policy:
            "keep_existing":
                return {
                    "success": true,
                    "record": existing,
                    "reused": true,
                    "created": false,
                }
            "reset_remaining":
                var replacement_record := _make_effect_chain_record(
                    label, timing, occurrences, effects, runtime, lifecycle)
                var existing_id := str(existing.get("id", ""))
                existing.clear()
                existing.merge(replacement_record, true)
                existing["id"] = existing_id
                return {
                    "success": true,
                    "record": existing,
                    "reused": true,
                    "reset": true,
                    "created": false,
                }
            "replace":
                _delayed_records.erase(existing)
            _:
                return {"success": false, "reason": "未知延迟既有记录策略"}
    elif existing_policy not in [
            "keep_existing", "reset_remaining", "replace"]:
        return {"success": false, "reason": "未知延迟既有记录策略"}
    var record := _make_effect_chain_record(
        label, timing, occurrences, effects, runtime, lifecycle)
    _delayed_records.append(record)
    return {
        "success": true,
        "record": record,
        "reused": false,
        "created": true,
    }


static func is_supported_timing(timing: String) -> bool:
    return timing in SUPPORTED_TIMINGS


func _make_effect_chain_record(
        label: String,
        timing: String,
        occurrences: int,
        effects: Array,
        runtime,
        lifecycle: Dictionary) -> Dictionary:
    return {
        "id": _record_id_allocator.next_id("delay"),
        "kind": "effect_chain",
        "label": label,
        "timing": timing,
        "remaining_occurrences": maxi(1, occurrences),
        "effects": effects.duplicate(true),
        "completion_effects": lifecycle.get(
            "completion_effects", []).duplicate(true),
        "record_key": str(lifecycle.get("record_key", "")),
        "existing_policy": str(lifecycle.get(
            "existing_policy", "keep_existing")),
        "trigger_count": 0,
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
        "root_action_token": runtime.root_action_token,
        "invocation_token": runtime.invocation_token,
        "caller_technique_id": runtime.caller_technique_id,
        "slot_instance_id": runtime.slot_instance_id,
        "technique_execution_token": runtime.technique_execution_token,
        "technique_execution_state": runtime.technique_execution_state.duplicate(true),
        "source_kind": runtime.source_kind,
        "source_id": runtime.source_id,
        "source_name": runtime.source_name,
        "source_instance_key": runtime.source_instance_key,
        "trigger_mode": runtime.trigger_mode,
    }


func advance_effect_chain(context, record_key: String, amount: int = 1) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    if record_key == "" or amount <= 0:
        return {"success": false, "reason": "延迟推进需要稳定记录键和正数"}
    var record = _find_keyed_effect_chain(runtime, record_key)
    if record == null:
        return {
            "success": true,
            "triggered": false,
            "record_key": record_key,
            "detail": "没有可推进的延迟记录",
        }
    # 主动推进可能在另一轮功法行动中令倒计时归零。完成效果若需要在
    # 当前调用者推进后自动调用来源功法，必须绑定这次推进所属的 root。
    record["root_action_token"] = runtime.root_action_token
    record["source_action_token"] = runtime.action_token
    return _consume_effect_chain_occurrences(record, amount, false)


func register_next_round_hand_limit(
        context,
        amount: int,
        affected_side = null) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    var side = affected_side if affected_side != null else runtime.actor
    if side == null or amount == 0:
        return {"success": false, "reason": "下一回合手牌上限参数无效"}
    var record := {
        "id": _record_id_allocator.next_id("hand-limit"),
        "kind": "next_round_hand_limit",
        "actor": side,
        "amount": amount,
        "source_round": _current_round_hint(runtime),
        "active_round": -1,
    }
    _delayed_records.append(record)
    return {"success": true, "record": record}


func register_defense_decay_return(context) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    var record := {
        "id": _record_id_allocator.next_id("decay-return"),
        "kind": "defense_decay_return",
        "actor": runtime.actor,
        "source_round": _current_round_hint(runtime),
        "captured_decay": -1,
        "source_kind": runtime.source_kind,
        "source_id": runtime.source_id,
        "source_name": runtime.source_name,
        "source_instance_key": runtime.source_instance_key,
        "trigger_mode": "delayed",
    }
    _delayed_records.append(record)
    return {"success": true, "record": record}


func register_no_life_loss_disruption(
        context,
        effect: Dictionary) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    _delayed_records.append({
        "id": _record_id_allocator.next_id("window-check"),
        "kind": "no_life_loss_disruption",
        "actor": runtime.actor,
        "target": runtime.target,
        "action_token": runtime.action_token,
        "effect": effect.duplicate(true),
        "source_kind": runtime.source_kind,
        "source_id": runtime.source_id,
        "source_name": runtime.source_name,
        "source_instance_key": runtime.source_instance_key,
        "trigger_mode": "delayed",
    })
    return {"success": true}


func capture_defense_decay(
        actor,
        round_number: int,
        decay: Dictionary) -> Dictionary:
    var captured_count := 0
    for record in _delayed_records:
        if record.get("kind") == "defense_decay_return" \
                and record.get("actor") == actor \
                and int(record.get("captured_decay", -1)) < 0:
            record["captured_decay"] = int(decay.get("lost", 0))
            record["return_round"] = round_number + 1
            captured_count += 1
    return {"success": true, "captured_count": captured_count}


func on_round_start(actors: Array, round_number: int) -> Dictionary:
    for actor in actors:
        for record in _delayed_records:
            if record.get("kind") == "next_round_hand_limit" \
                    and record.get("actor") == actor \
                    and int(record.get("source_round", -1)) + 1 == round_number:
                actor.base_hand_limit_modifier += int(record.get("amount", 0))
                record["active_round"] = round_number
    var due: Array = _delayed_records.filter(func(record):
        return record.get("kind") == "defense_decay_return" \
            and int(record.get("return_round", -1)) == round_number)
    for record in due:
        var actor = record["actor"]
        if _effect_ports() != null:
            _effect_ports().add_defense(
                actor, int(record.get("captured_decay", 0)),
                str(record.get("source_kind", "rule")))
        _delayed_records.erase(record)
    var resolved_effect_chains := 0
    for actor in actors:
        var round_start_due: Array = _delayed_records.filter(func(record):
            return record.get("actor") == actor \
                and record.get("kind", "") == "effect_chain" \
                and record.get("timing", "") == "round_start")
        for record in round_start_due:
            var resolved := _consume_effect_chain_occurrences(record, 1, true)
            if resolved.get("success", false):
                resolved_effect_chains += 1
    return {
        "success": true,
        "resolved_decay_count": due.size(),
        "resolved_effect_count": resolved_effect_chains,
        "detail": "返还%d份防御衰减记录，结算%d份回合开始延迟" % [
            due.size(), resolved_effect_chains],
    }


func resolve_action_end_records(event_context: Dictionary) -> Dictionary:
    var due: Array = _delayed_records.filter(func(record):
        return record.get("kind") == "no_life_loss_disruption" \
            and _action_token_matches(record, event_context))
    for record in due:
        var actor_result: Dictionary = {}
        for result_value in event_context.get("action_results", []):
            var result: Dictionary = result_value
            if result.get("side") == record["actor"]:
                actor_result = result
                break
        if int(actor_result.get("actual_life_loss", 0)) <= 0:
            var context = EffectContextScript.new().configure({
                "ports": _effect_ports(),
                "actor": record["actor"],
                "target": record["target"],
                "source_kind": record.get("source_kind", "rule"),
                "source_id": record.get("source_id", ""),
                "source_name": record.get("source_name", ""),
                "source_instance_key": record.get("source_instance_key", ""),
                "trigger_mode": "delayed",
                "captures": {},
            })
            if _effect_executor != null:
                _effect_executor.execute_all([record["effect"]], context)
        _delayed_records.erase(record)
    return {"success": true, "resolved_count": due.size()}


func resolve_turn_end_effects(actor, _round_number: int) -> Dictionary:
    var due: Array = _delayed_records.filter(func(record):
        return record.get("actor") == actor \
            and record.get("kind", "") == "effect_chain" \
            and record.get("timing", "") == "turn_end")
    for record in due:
        _consume_effect_chain_occurrences(record, 1, true)
    return {"success": true, "resolved_count": due.size()}


func expire_turn_end_modifiers(actor, round_number: int) -> Dictionary:
    var expired_count := 0
    for record in _delayed_records.duplicate():
        if record.get("kind") == "next_round_hand_limit" \
                and record.get("actor") == actor \
                and int(record.get("active_round", -1)) == round_number:
            actor.base_hand_limit_modifier -= int(record.get("amount", 0))
            _delayed_records.erase(record)
            expired_count += 1
    return {"success": true, "expired_count": expired_count}


func resolve_after_normal_draw(actor) -> Dictionary:
    var due: Array = _delayed_records.filter(func(record):
        return record.get("kind", "") == "effect_chain" \
            and record.get("timing", "") == "after_normal_draw" \
            and record.get("actor") == actor)
    for record in due:
        _consume_effect_chain_occurrences(record, 1, true)
    return {
        "success": true,
        "resolved_count": due.size(),
        "detail": "结算%d个补牌后延迟效果" % due.size(),
    }


func clear() -> int:
    var cleared_count := _delayed_records.size()
    _delayed_records.clear()
    return cleared_count


func records() -> Array:
    return _delayed_records


func use_effect_ports(effect_ports) -> void:
    _effect_ports_ref = weakref(effect_ports) if effect_ports != null else null


func use_effect_executor(executor) -> void:
    _effect_executor = executor


func _consume_effect_chain_occurrences(
        record: Dictionary,
        amount: int,
        execute_tick: bool) -> Dictionary:
    var remaining_before := int(record.get("remaining_occurrences", 0))
    var remaining_after := maxi(0, remaining_before - maxi(1, amount))
    var is_final_trigger := remaining_after == 0
    var trigger_index := int(record.get("trigger_count", 0)) + 1
    var effects: Array = []
    if execute_tick:
        effects.append_array(record.get("effects", []).duplicate(true))
    if is_final_trigger:
        effects.append_array(record.get(
            "completion_effects", []).duplicate(true))
    var resolved := {"success": true}
    if not effects.is_empty():
        resolved = _resolve_effect_chain(record, effects, {
            "trigger_index": trigger_index,
            "remaining_before": remaining_before,
            "remaining_after": remaining_after,
            "is_final_trigger": is_final_trigger,
        })
    if not resolved.get("success", false):
        return resolved
    record["remaining_occurrences"] = remaining_after
    record["trigger_count"] = trigger_index
    if is_final_trigger:
        _delayed_records.erase(record)
    _status_history.record_change(
        "delay_resolve",
        "actor",
        str(record.get("actor").owner_id),
        str(record.get("id", "")),
        0,
        null,
        str(record.get("label", "")))
    return {
        "success": true,
        "triggered": true,
        "record_key": str(record.get("record_key", "")),
        "remaining_before": remaining_before,
        "remaining_after": remaining_after,
        "is_final_trigger": is_final_trigger,
        "completed": is_final_trigger,
    }


func _resolve_effect_chain(
        record: Dictionary,
        effects: Array,
        lifecycle: Dictionary = {}) -> Dictionary:
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
        "pre_momentum_power": int(record.get(
            "pre_momentum_power", record["power"])),
        "momentum_used": int(record.get("momentum_used", 0)),
        "technique_id": str(record["technique_id"]),
        "technique_name": str(record["technique_name"]),
        "actual_hand_id": str(record.get("actual_hand_id", "")),
        "branch_hand_id": str(record.get("branch_hand_id", "")),
        "technique_pool": str(record.get("technique_pool", "")),
        "sequence_book": record.get("sequence_book"),
        "action_token": "%s:delay:%s:%d" % [
            str(record.get("source_action_token", "")),
            str(record.get("id", "delay")),
            int(lifecycle.get("trigger_index", 0)),
        ],
        "root_action_token": str(record.get(
            "root_action_token", record.get("source_action_token", ""))),
        "invocation_token": str(record.get("invocation_token", "")),
        "caller_technique_id": str(record.get("caller_technique_id", "")),
        "slot_instance_id": str(record.get("slot_instance_id", "")),
        "technique_execution_token": str(record.get(
            "technique_execution_token", "")),
        "technique_execution_state": record.get(
            "technique_execution_state", {}).duplicate(true),
        "source_kind": record.get("source_kind", "rule"),
        "source_id": record.get("source_id", ""),
        "source_name": record.get("source_name", ""),
        "source_instance_key": record.get("source_instance_key", ""),
        "trigger_mode": "delayed",
        "captures": _delay_captures(record, lifecycle),
        "group_snapshot": record.get("group_snapshot", {}).duplicate(true),
    })
    return _effect_executor.execute_all(effects, context)


func _delay_captures(record: Dictionary, lifecycle: Dictionary) -> Dictionary:
    var captures: Dictionary = record.get("captures", {}).duplicate(true)
    captures["delay_lifecycle"] = [lifecycle.duplicate(true)]
    return captures


func _find_keyed_effect_chain(runtime, record_key: String):
    if record_key == "":
        return null
    for record in _delayed_records:
        if record.get("kind", "") == "effect_chain" \
                and str(record.get("record_key", "")) == record_key \
                and record.get("actor") == runtime.actor \
                and str(record.get("source_instance_key", "")) \
                    == runtime.source_instance_key:
            return record
    return null


func _action_token_matches(record: Dictionary, event_context: Dictionary) -> bool:
    var record_token := str(record.get("action_token", ""))
    if record_token == "":
        return true
    for token_value in event_context.get("metadata", {}).get(
            "action_tokens", []):
        if str(token_value) == record_token:
            return true
    return false


func _current_round_hint(runtime) -> int:
    return int(runtime.action_token.split("-")[-2]) \
        if runtime.action_token.split("-").size() >= 3 else 0


func _effect_ports():
    return _effect_ports_ref.get_ref() if _effect_ports_ref != null else null
