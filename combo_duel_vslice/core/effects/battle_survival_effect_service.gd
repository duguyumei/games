class_name BattleSurvivalEffectService
extends RefCounted

## BattleEffectPorts 内部的伤害、防御与生命结算服务。
##
## 公开效果协议仍由 Facade 承担；本服务只接收已标准化的来源上下文，集中维护唯一的
## 伤害流水线、同步伤害 flush、行动伤害统计以及防御／生命 committed events。

var _damage_resolver: ComboDamageResolver
var _status_system: StatusSystem
var _trigger_queue: VisibleTriggerQueue
var _sides: Array[BattleSide] = []
var _battle_rule_query_service
var _committed_event_service
var _round_number_reader: Callable
var _action_resolution_scope: Dictionary = {}
var _action_window_serial: int = 0
var _damage_segment_serial: int = 0


func _init(
        damage_resolver: ComboDamageResolver,
        status_system: StatusSystem,
        trigger_queue: VisibleTriggerQueue) -> void:
    _damage_resolver = damage_resolver
    _status_system = status_system
    _trigger_queue = trigger_queue


func use_trigger_queue(trigger_queue: VisibleTriggerQueue) -> void:
    _trigger_queue = trigger_queue


func use_sides(first: BattleSide, second: BattleSide) -> void:
    _sides = [first, second]


func use_passive_battle_services(
        query_service,
        event_service,
        round_reader: Callable = Callable()) -> void:
    _battle_rule_query_service = query_service
    _committed_event_service = event_service
    _round_number_reader = round_reader


func deal_damage(
        actor: BattleSide,
        target: BattleSide,
        amount: int,
        source_kind: String,
        true_damage: bool = false,
        action_token: String = "",
        damage_type: String = "",
        resolution_metadata: Dictionary = {},
        source_metadata: Dictionary = {}) -> Dictionary:
    var resolved_metadata := resolution_metadata.duplicate(true)
    resolved_metadata["action_token"] = action_token
    resolved_metadata["cause"] = str(resolved_metadata.get("cause", "damage"))
    var resolved_type := damage_type
    if resolved_type == "":
        resolved_type = "true" if true_damage else "normal"
    var resolved_amount := _resolve_actual_damage_amount(
        actor, target, amount, source_kind, resolved_type, action_token)
    if not resolved_amount.get("success", false):
        return {
            "success": false,
            "reason": resolved_amount.get("reason", "伤害查询失败"),
            "buffered": false,
        }
    var final_override = null
    var poison_defense_intervention := 0
    if resolved_type == "poison":
        if not bool(resolved_metadata.get("skip_poison_modifiers", false)):
            var modifier_token := str(resolved_metadata.get(
                "poison_modifier_receipt_token", action_token))
            var modifier: Dictionary = resolve_poison_segment_amount(
                target, int(resolved_amount["amount"]), modifier_token)
            resolved_amount["amount"] = int(modifier["final_amount"])
            resolved_metadata["poison_modifier"] = modifier
        poison_defense_intervention = _poison_defense_intervention(
            actor, target, int(resolved_amount["amount"]), source_kind, action_token)
    if _damage_resolver.is_buffering():
        var buffered: Dictionary = _damage_resolver.resolve(
            actor, target, amount, source_kind, resolved_type == "true",
            _status_system, null, resolved_type,
            poison_defense_intervention, resolved_metadata)
        buffered["success"] = true
        return buffered

    final_override = int(resolved_amount["amount"])
    resolved_metadata["requested_damage"] = amount
    resolved_metadata["final_damage"] = int(final_override)
    var damage_segment_token := _next_damage_segment_token(
        actor, target, action_token)
    resolved_metadata["damage_segment_token"] = damage_segment_token
    var block_result := _try_block_damage(
        actor, target, int(final_override), resolved_type, source_kind,
        action_token, resolved_metadata)
    if block_result.get("blocked", false):
        _emit_damage_blocked(
            actor, target, int(final_override), resolved_type, source_kind,
            action_token, block_result, resolved_metadata,
            damage_segment_token)
        return _blocked_damage_result(
            int(final_override), resolved_type, block_result,
            damage_segment_token, resolved_metadata, target)

    var plan := ComboDamageResolver.plan_to_target(
        target, int(final_override), resolved_type,
        poison_defense_intervention)
    var committed := _commit_damage_plan(
        actor, target, amount, int(final_override), source_kind,
        resolved_type, plan, false, action_token, resolved_metadata)
    if not committed.get("success", false):
        return committed
    var result: Dictionary = committed
    if resolved_type == "poison" \
            and resolved_metadata.has("poison_modifier"):
        result["poison_modifier"] = target \
            .commit_poison_damage_modifier_receipt(
                resolved_metadata["poison_modifier"])
    result["defense_reduction_cause"] = "damage_absorption"
    _record_action_damage(actor, target, result)
    _log_damage(actor, target, int(result["final_amount"]), source_kind, result)
    _emit_damage_resolved(
        actor, target, amount, source_kind, resolved_type, result, false,
        action_token, source_metadata)
    _emit_damage_absorption_defense_reduced(
        actor, target, result, source_kind, action_token, source_metadata)
    result["reflection_result"] = _resolve_reflection(
        actor, target, source_kind, resolved_type, result, action_token,
        resolved_metadata)
    return result


func actor_can_continue(side: BattleSide) -> bool:
    return _damage_resolver.actor_can_continue(side)


func target_can_receive(side: BattleSide) -> bool:
    return _damage_resolver.target_can_receive(side)


func resolve_poison_segment_amount(
        affected_side: BattleSide,
        base_amount: int,
        receipt_token: String = "") -> Dictionary:
    if affected_side == null:
        return {
            "base": base_amount, "fixed": 0, "percent": 0,
            "final_amount": maxi(0, base_amount),
        }
    return affected_side.freeze_poison_damage_modifiers(
        base_amount, receipt_token,
        _active_source_marker_total("poison_damage_fixed_global"))


func begin_synchronized_damage(records: Array) -> void:
    var actors: Array = []
    for record in records:
        actors.append(record["actor"])
    _damage_resolver.begin_synchronized(actors)


func flush_synchronized_damage(
        before_commit: Callable = Callable()) -> Dictionary:
    var transaction := _capture_synchronized_flush_state()
    if _committed_event_service != null:
        _committed_event_service.begin_publication_transaction()
    var flushed: Dictionary = _damage_resolver.flush_synchronized(
        Callable(self, "_resolve_synchronized_damage_segment"))
    if flushed.get("success", false) and before_commit.is_valid():
        var finalized: Dictionary = before_commit.call(
            flushed.get("resolutions", []))
        if not finalized.get("success", false):
            flushed = {
                "success": false,
                "reason": str(finalized.get(
                    "reason", "同步伤害提交前收尾失败")),
                "resolutions": flushed.get("resolutions", []),
            }
    if not flushed.get("success", false):
        if _committed_event_service != null:
            _committed_event_service.rollback_publication_transaction()
        _restore_synchronized_flush_state(transaction)
        flushed["rolled_back"] = true
        return flushed
    if _committed_event_service != null:
        _committed_event_service.commit_publication_transaction()
    flushed["rolled_back"] = false
    return flushed


func begin_action_resolution(actors: Array, metadata: Dictionary = {}) -> void:
    var entries: Dictionary = {}
    for side in actors:
        if side == null:
            continue
        entries[str(side.owner_id)] = {
            "side": side,
            "life_before": int(side.life),
            "defense_before": int(side.defense),
            "damage_dealt": 0,
            "damage_received": 0,
            "defense_lost": 0,
            "life_lost": 0,
        }
    var window_id := "action-window-%06d" % _action_window_serial
    _action_window_serial += 1
    var resolved_metadata := metadata.duplicate(true)
    resolved_metadata["action_window_id"] = window_id
    var acting_owner_ids: Array = resolved_metadata.get(
        "acting_owner_ids", []).duplicate()
    for side in actors:
        if side != null:
            side.bind_waiting_action_sources(acting_owner_ids, window_id)
    _action_resolution_scope = {
        "entries": entries,
        "metadata": resolved_metadata,
        "window_id": window_id,
        "acting_owner_ids": acting_owner_ids,
        "source_binding_open": true,
    }


func close_current_source_binding_window() -> void:
    if not _action_resolution_scope.is_empty():
        _action_resolution_scope["source_binding_open"] = false


func finish_action_resolution() -> Dictionary:
    if _action_resolution_scope.is_empty():
        return {"success": false, "reason": "当前没有行动结算统计范围"}
    var results: Array = []
    for entry_value in _action_resolution_scope.get("entries", {}).values():
        var entry: Dictionary = entry_value
        var side = entry["side"]
        var result := entry.duplicate()
        result["life_after"] = int(side.life)
        result["defense_after"] = int(side.defense)
        result["actual_life_loss"] = int(entry.get("life_lost", 0))
        result["actual_defense_loss"] = int(entry.get("defense_lost", 0))
        results.append(result)
    var completed := {
        "success": true,
        "results": results,
        "metadata": _action_resolution_scope.get("metadata", {}).duplicate(true),
    }
    _action_resolution_scope.clear()
    return completed


func abort_action_resolution() -> void:
    _action_resolution_scope.clear()


func current_action_window_id() -> String:
    return str(_action_resolution_scope.get("window_id", ""))


func current_acting_owner_ids() -> Array:
    return _action_resolution_scope.get("acting_owner_ids", [])


func can_bind_current_source(target_owner_id: String) -> bool:
    return bool(_action_resolution_scope.get("source_binding_open", false)) \
        and current_acting_owner_ids().has(target_owner_id)


func add_defense(
        side: BattleSide,
        amount: int,
        source_kind: String = "effect",
        action_token: String = "",
        source_metadata: Dictionary = {}) -> int:
    return int(add_defense_result(
        side, amount, source_kind, action_token,
        source_metadata).get("gained", 0))


func add_defense_result(
        side: BattleSide,
        amount: int,
        source_kind: String = "effect",
        action_token: String = "",
        source_metadata: Dictionary = {}) -> Dictionary:
    var resolved_source_kind := str(source_metadata.get(
        "source_kind", source_kind))
    var requested := maxi(0, amount)
    if requested <= 0:
        return {"success": true, "gained": 0, "requested": requested}
    var effective := requested
    if _battle_rule_query_service != null:
        var query = _battle_rule_query_service.resolve_values({
            "hook": "defense_gain_query",
            "owner": side, "actor": side,
            "subject_kind": "defense_gain",
            "subject_id": resolved_source_kind,
            "base_value": requested,
            "round_number": _round_number(),
            "action_token": action_token,
            "source_kind": resolved_source_kind,
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
        var values := {
            "event_token": _committed_event_service.make_token(
                "defense_gained", side, serial, action_token),
            "event_serial": serial,
            "actor": side, "owner": side,
            "round_number": _round_number(),
            "action_token": action_token,
            "source_kind": resolved_source_kind,
            "requested_amount": requested,
            "effective_amount": gained,
            "defense_before": before,
            "defense_after": int(side.defense),
        }
        for field in ["source_id", "source_name", "source_instance_key", "trigger_mode"]:
            if source_metadata.has(field):
                values[field] = source_metadata[field]
        _committed_event_service.commit("defense_gained", values)
    return {
        "success": true,
        "gained": gained,
        "requested": requested,
        "effective": effective,
        "before": before,
        "after": int(side.defense),
    }


func recover_life(
        side: BattleSide,
        amount: int,
        source_kind: String = "effect",
        action_token: String = "",
        source_actor = null,
        source_metadata: Dictionary = {}) -> Dictionary:
    var resolved_source_kind := str(source_metadata.get(
        "source_kind", source_kind))
    var requested := maxi(0, amount)
    var effective := requested
    if requested > 0 and _battle_rule_query_service != null:
        var query = _battle_rule_query_service.resolve_values({
            "hook": "life_recovery_query", "owner": side,
            "actor": source_actor if source_actor != null else side,
            "target": side, "subject_kind": "life_recovery",
            "subject_id": resolved_source_kind, "base_value": requested,
            "round_number": _round_number(), "action_token": action_token,
            "source_kind": resolved_source_kind,
        })
        if not query.success:
            _battle_rule_query_service.report_failure(query, "life_recovery")
            return {
                "success": false, "reason": "；".join(query.errors),
                "recovered": 0,
            }
        effective = maxi(0, int(query.effective_value))
    var before := int(side.life)
    side.life = mini(int(side.max_life), before + effective)
    var recovered := int(side.life) - before
    if recovered > 0:
        var values := {
            "actor": source_actor if source_actor != null else side,
            "target": side, "owner": side, "holder": side,
            "requested_amount": requested, "effective_amount": effective,
            "recovered_amount": recovered, "life_before": before,
            "life_after": int(side.life), "max_life": int(side.max_life),
            "source_kind": resolved_source_kind, "action_token": action_token,
            "round_number": _round_number(),
        }
        for field in ["source_id", "source_name", "source_instance_key", "trigger_mode"]:
            if source_metadata.has(field):
                values[field] = source_metadata[field]
        if _committed_event_service != null:
            var serial := int(_committed_event_service.next_serial())
            values["event_serial"] = serial
            values["event_token"] = _committed_event_service.make_token(
                "life_recovered", side, serial, action_token)
            _committed_event_service.commit("life_recovered", values)
        if _committed_event_service == null:
            _status_system.handle_response_event("life_recovered", values)
    return {
        "success": true, "requested": requested, "effective": effective,
        "recovered": recovered, "before": before, "after": int(side.life),
    }


func remove_defense(
        side: BattleSide,
        amount: int,
        remove_all: bool,
        source_actor = null,
        source_kind: String = "effect",
        action_token: String = "",
        cause: String = "direct_effect",
        require_full: bool = false,
        source_metadata: Dictionary = {}) -> Dictionary:
    var resolved_source_kind := str(source_metadata.get(
        "source_kind", source_kind))
    var before := int(side.defense)
    var requested := before if remove_all else maxi(0, amount)
    if require_full and not remove_all and before < requested:
        return {
            "success": true, "removed": 0,
            "before": before, "after": before,
            "requested": requested, "paid": false,
            "hostile": source_actor != null and source_actor != side,
            "cause": cause,
        }
    var removed := before if remove_all else mini(before, maxi(0, amount))
    side.defense = before - removed
    if removed <= 0:
        return {
            "success": true, "removed": 0,
            "before": before, "after": before,
            "requested": requested,
            "paid": remove_all or requested == 0,
        }
    var hostile: bool = source_actor != null and source_actor != side
    var values := {
        "actor": source_actor if source_actor != null else side,
        "target": side, "owner": side, "holder": side,
        "requested_amount": requested,
        "effective_amount": removed, "defense_before": before,
        "defense_after": int(side.defense), "all": remove_all,
        "hostile": hostile, "source_kind": resolved_source_kind,
        "cause": cause, "action_token": action_token,
        "round_number": _round_number(),
    }
    for field in ["source_id", "source_name", "source_instance_key", "trigger_mode"]:
        if source_metadata.has(field):
            values[field] = source_metadata[field]
    if _committed_event_service != null:
        var serial := int(_committed_event_service.next_serial())
        values["event_serial"] = serial
        values["event_token"] = _committed_event_service.make_token(
            "defense_reduced", side, serial, action_token)
        _committed_event_service.commit("defense_reduced", values)
    if _committed_event_service == null:
        _status_system.handle_response_event("defense_reduced", values)
    return {
        "success": true, "removed": removed,
        "before": before, "after": int(side.defense), "hostile": hostile,
        "cause": cause, "requested": requested,
        "paid": remove_all or removed == requested,
    }


func notify_poison_triggered(
        holder: BattleSide,
        card,
        frozen_amount: int,
        damage_result: Dictionary,
        action_token: String = "",
        replayed: bool = false) -> void:
    if _committed_event_service != null:
        var serial: int = int(_committed_event_service.next_serial())
        _committed_event_service.commit("poison_trigger_completed", {
            "event_token": _committed_event_service.make_token(
                "poison_trigger_completed", holder, serial, action_token),
            "event_serial": serial,
            "actor": holder,
            "target": holder,
            "owner": holder,
            "holder": holder,
            "source_card": card,
            "source_card_instance_id": str(card.id),
            "round_number": _round_number(),
            "action_token": action_token,
            "source_kind": "card_status",
            "source_id": "poison",
            "source_name": "毒",
            "source_instance_key": "card_status:%s:poison" % str(card.id),
            "trigger_mode": "direct",
            "damage_type": "poison",
            "requested_amount": maxi(0, frozen_amount),
            "frozen_amount": maxi(0, frozen_amount),
            "final_amount": int(damage_result.get(
                "poison_final_amount", damage_result.get("final_amount", 0))),
            "actual_life_loss": int(damage_result.get("life_lost", 0)),
            "damage_result": damage_result.duplicate(true),
            "replayed": replayed,
        })
    if _committed_event_service == null:
        _status_system.handle_response_event("poison_trigger_completed", {
            "holder": holder, "actor": holder, "target": holder,
            "card": card, "source_card_instance_id": str(card.id),
            "frozen_amount": maxi(0, frozen_amount),
            "final_amount": int(damage_result.get(
                "poison_final_amount", damage_result.get("final_amount", 0))),
            "actual_life_loss": int(damage_result.get("life_lost", 0)),
            "damage_result": damage_result.duplicate(true),
            "action_token": action_token, "replayed": replayed,
            "source_kind": "card_status",
            "source_id": "poison",
            "source_name": "毒",
            "source_instance_key": "card_status:%s:poison" % str(card.id),
            "trigger_mode": "direct",
        })


func _capture_synchronized_flush_state() -> Dictionary:
    var side_states: Array = []
    for side in _sides:
        if side != null:
            side_states.append({
                "side": side,
                "state": side.capture_passive_query_state(),
            })
    return {
        "side_states": side_states,
        "event_state": _committed_event_service.capture_transaction_state() \
            if _committed_event_service != null else {},
        "trigger_state": _trigger_queue.capture_runtime_state() \
            if _trigger_queue != null else {},
        "action_resolution_scope": _action_resolution_scope.duplicate(true),
        "damage_segment_serial": _damage_segment_serial,
    }


func _restore_synchronized_flush_state(snapshot: Dictionary) -> void:
    for entry in snapshot.get("side_states", []):
        var side = entry.get("side")
        if side != null:
            side.replace_passive_query_state(entry.get("state", {}))
    if _committed_event_service != null:
        _committed_event_service.restore_transaction_state(
            snapshot.get("event_state", {}))
    if _trigger_queue != null:
        _trigger_queue.restore_runtime_state(snapshot.get("trigger_state", {}))
    _action_resolution_scope = snapshot.get(
        "action_resolution_scope", {}).duplicate(true)
    _damage_segment_serial = int(snapshot.get(
        "damage_segment_serial", _damage_segment_serial))


func _commit_damage_plan(
        actor,
        target,
        requested_damage: int,
        final_damage: int,
        source_kind: String,
        damage_type: String,
        plan: Dictionary,
        synchronized: bool,
        action_token: String,
        metadata: Dictionary) -> Dictionary:
    var proposed := int(plan.get("proposed_life_loss", 0))
    var cause := str(metadata.get("cause", "damage"))
    var effective := proposed
    var query_values := {
        "source_breakdown": [],
        "source_fingerprint": "",
        "request_fingerprint": "",
    }
    if proposed > 0 and cause != "cost" \
            and _battle_rule_query_service != null:
        var query_context := {
            "actor": actor,
            "target": target,
            "damage_segment_token": str(metadata.get(
                "damage_segment_token", "")),
            "action_token": action_token,
            "action_window_id": current_action_window_id(),
            "source_kind": source_kind,
            "source_id": str(metadata.get("source_id", "")),
            "source_instance_key": str(metadata.get(
                "source_instance_key", "")),
            "trigger_mode": str(metadata.get("trigger_mode", "")),
            "cause": cause,
            "damage_type": damage_type,
            "direct_attack": bool(metadata.get("direct_attack", false)),
            "reflection_damage": bool(metadata.get(
                "reflection_damage", false)),
            "synchronized": synchronized,
            "requested_damage": requested_damage,
            "final_damage": final_damage,
            "defense_before": int(plan.get("defense_before", 0)),
            "defense_lost": int(plan.get("defense_lost", 0)),
            "defense_after": int(plan.get("defense_after", 0)),
            "life_before": int(plan.get("life_before", 0)),
            "proposed_life_loss": proposed,
            "lethal": proposed >= int(plan.get("life_before", 0)) \
                and int(plan.get("life_before", 0)) > 0,
            "round_number": _round_number(),
            "metadata": metadata.duplicate(true),
        }
        if metadata.has("source_snapshot"):
            query_context["source_snapshot"] = metadata.get(
                "source_snapshot", []).duplicate(true)
        var query = _battle_rule_query_service.resolve_pre_life_loss(
            target, query_context)
        query_values = query.to_dict()
        if not query.success:
            _battle_rule_query_service.report_failure(
                query, "pre_life_loss")
            return {
                "success": false,
                "reason": "；".join(query.errors),
                "damage_segment_token": str(metadata.get(
                    "damage_segment_token", "")),
                "life_loss_before_intervention": proposed,
                "query_result": query_values,
            }
        effective = int(query.effective_value)
    var committed := ComboDamageResolver.commit_plan(
        target, plan, effective)
    if not committed.get("success", false):
        return committed
    committed.merge({
        "success": true,
        "buffered": false,
        "blocked": false,
        "final_amount": final_damage,
        "source_kind": source_kind,
        "damage_type": damage_type,
        "true_damage": damage_type == "true",
        "damage_segment_token": str(metadata.get(
            "damage_segment_token", "")),
        "cause": cause,
        "direct_attack": bool(metadata.get("direct_attack", false)),
        "reflection_damage": bool(metadata.get("reflection_damage", false)),
        "synchronized": synchronized,
        "life_loss_intervention_breakdown": query_values.get(
            "source_breakdown", []).duplicate(true),
        "life_loss_source_fingerprint": str(query_values.get(
            "source_fingerprint", query_values.get("fingerprint", ""))),
        "life_loss_query_fingerprint": str(query_values.get(
            "request_fingerprint", "")),
        "life_loss_intervention_skipped": proposed <= 0 or cause == "cost",
        "life_loss_intervention_skip_reason": (
            "cost" if cause == "cost" else "no_life_loss" \
                if proposed <= 0 else ""),
    }, true)
    return committed


func _record_action_damage(actor, target, result: Dictionary) -> void:
    if _action_resolution_scope.is_empty():
        return
    var entries: Dictionary = _action_resolution_scope.get("entries", {})
    var actor_key := str(actor.owner_id) if actor != null else ""
    var target_key := str(target.owner_id) if target != null else ""
    var final_amount := int(result.get("final_amount", result.get("requested", 0)))
    if entries.has(actor_key):
        entries[actor_key]["damage_dealt"] = (
            int(entries[actor_key].get("damage_dealt", 0)) + final_amount)
    if entries.has(target_key):
        entries[target_key]["damage_received"] = (
            int(entries[target_key].get("damage_received", 0)) + final_amount)
        entries[target_key]["defense_lost"] = (
            int(entries[target_key].get("defense_lost", 0))
            + int(result.get("defense_lost", 0)))
        entries[target_key]["life_lost"] = (
            int(entries[target_key].get("life_lost", 0))
            + int(result.get("life_lost", 0)))
    var actual_loss := int(result.get("defense_lost", 0)) \
        + int(result.get("life_lost", 0))
    if actual_loss > 0 and actor != null and target != null and actor != target:
        var window_id := current_action_window_id()
        for record in target.challenge_records:
            if str(record.get("window_id", "")) != window_id \
                    or str(record.get("target_owner_id", "")) != str(actor.owner_id):
                continue
            record["current"] = int(record.get("current", 0)) + actual_loss
            _emit_source_state_changed(
                "challenge_progressed", target, record, "progressed")


func _resolve_actual_damage_amount(
        actor,
        target,
        requested_amount: int,
        source_kind: String,
        damage_type: String,
        action_token: String = "") -> Dictionary:
    if damage_type != "normal" or _damage_resolver.is_buffering():
        return {"success": true, "amount": maxi(0, requested_amount)}
    var current := ComboDamageResolver.calculate_final_amount(
        actor, target, requested_amount, source_kind, "normal", _status_system)
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


func _poison_defense_intervention(
        actor,
        target,
        requested_amount: int,
        source_kind: String,
        action_token: String) -> int:
    if _battle_rule_query_service == null or target == null:
        return 0
    var query = _battle_rule_query_service.resolve_values({
        "hook": "poison_defense_intervention_query",
        "owner": target, "actor": actor, "target": target,
        "subject_kind": "poison_damage", "subject_id": source_kind,
        "base_value": 0, "round_number": _round_number(),
        "source_kind": source_kind, "action_token": action_token,
        "metadata": {"requested_amount": requested_amount},
    })
    if not query.success:
        _battle_rule_query_service.report_failure(query, "poison_damage")
        return 0
    return maxi(0, mini(requested_amount, int(query.effective_value)))


func _resolve_synchronized_damage_segment(intent: Dictionary) -> Dictionary:
    var metadata: Dictionary = intent.get("resolution_metadata", {})
    var resolved_action_token := str(metadata.get("action_token", ""))
    var actor = intent["actor"]
    var target = intent["target"]
    var requested_amount := int(intent.get(
        "requested_amount", intent.get("amount", 0)))
    var source_kind := str(intent.get("source_kind", ""))
    var damage_type := str(intent.get("damage_type", "normal"))
    var resolved := _resolve_actual_damage_amount(
        actor, target, requested_amount, source_kind, damage_type,
        resolved_action_token)
    if not resolved.get("success", false):
        return resolved
    var final_amount := maxi(0, int(resolved.get("amount", 0)))
    metadata["requested_damage"] = requested_amount
    metadata["final_damage"] = final_amount
    var segment_token := _next_damage_segment_token(
        actor, target, resolved_action_token)
    metadata["damage_segment_token"] = segment_token
    var block_result := _try_block_damage(
        actor, target, final_amount, damage_type, source_kind,
        resolved_action_token, metadata)
    if block_result.get("blocked", false):
        _emit_damage_blocked(
            actor, target, final_amount, damage_type, source_kind,
            resolved_action_token, block_result, metadata, segment_token)
        var blocked_result := _blocked_damage_result(
            final_amount, damage_type, block_result, segment_token, metadata,
            target)
        var blocked_resolution := _synchronized_resolution(
            intent, final_amount, blocked_result, metadata, true, block_result)
        return {
            "success": true,
            "resolution": blocked_resolution,
            "stop_actor": false,
        }
    var poison_defense_intervention := 0
    if damage_type == "poison":
        poison_defense_intervention = _poison_defense_intervention(
            actor, target, final_amount, source_kind, resolved_action_token)
    var plan := ComboDamageResolver.plan_to_target(
        target, final_amount, damage_type, poison_defense_intervention)
    var result := _commit_damage_plan(
        actor, target, requested_amount, final_amount, source_kind,
        damage_type, plan, true, resolved_action_token, metadata)
    if not result.get("success", false):
        return result
    if damage_type == "poison" and metadata.has("poison_modifier"):
        result["poison_modifier"] = target \
            .commit_poison_damage_modifier_receipt(metadata["poison_modifier"])
    result["defense_reduction_cause"] = "damage_absorption"
    _record_action_damage(actor, target, result)
    _log_damage(actor, target, final_amount, source_kind, result)
    _emit_damage_resolved(
        actor, target, requested_amount, source_kind, damage_type,
        result, true, resolved_action_token, metadata)
    _emit_damage_absorption_defense_reduced(
        actor, target, result, source_kind, resolved_action_token, metadata)
    var reflection := _resolve_reflection(
        actor, target, source_kind, damage_type, result,
        resolved_action_token, metadata)
    if not reflection.get("success", false):
        return {
            "success": false,
            "reason": str(reflection.get("reason", "同步反震伤害结算失败")),
        }
    result["reflection_result"] = reflection
    return {
        "success": true,
        "resolution": _synchronized_resolution(
            intent, final_amount, result, metadata, false, {}),
        "stop_actor": int(actor.life) <= 0,
    }


func _synchronized_resolution(
        intent: Dictionary,
        final_amount: int,
        result: Dictionary,
        metadata: Dictionary,
        blocked: bool,
        block_result: Dictionary) -> Dictionary:
    return {
        "actor": intent["actor"],
        "target": intent["target"],
        "amount": final_amount,
        "requested_amount": intent.get("requested_amount", intent["amount"]),
        "source_kind": intent["source_kind"],
        "true_damage": str(intent.get("damage_type", "normal")) == "true",
        "damage_type": intent.get("damage_type", "normal"),
        "preview": intent["preview"],
        "resolution_metadata": metadata.duplicate(true),
        "action_token": str(metadata.get("action_token", "")),
        "blocked": blocked,
        "block_result": block_result.duplicate(true),
        "result": result,
    }


func _blocked_damage_result(
        final_amount: int,
        damage_type: String,
        block_result: Dictionary,
        segment_token: String,
        metadata: Dictionary,
        target = null) -> Dictionary:
    var defense := int(target.defense) if target != null else 0
    var life := int(target.life) if target != null else 0
    return {
        "success": true,
        "buffered": false,
        "blocked": true,
        "final_amount": 0,
        "requested": final_amount,
        "defense_before": defense,
        "defense_lost": 0,
        "defense_after": defense,
        "life_before": life,
        "life_loss_before_intervention": 0,
        "life_loss_prevented": 0,
        "life_lost": 0,
        "actual_life_loss": 0,
        "life_loss_canceled": false,
        "life_after": life,
        "damage_type": damage_type,
        "true_damage": damage_type == "true",
        "damage_segment_token": segment_token,
        "cause": str(metadata.get("cause", "damage")),
        "direct_attack": bool(metadata.get("direct_attack", false)),
        "reflection_damage": bool(metadata.get("reflection_damage", false)),
        "life_loss_intervention_breakdown": [],
        "life_loss_query_fingerprint": "",
        "block_result": block_result,
    }


func _next_damage_segment_token(actor, target, action_token: String) -> String:
    var token := "damage-segment|%06d|%s|%s|%s" % [
        _damage_segment_serial,
        action_token,
        str(actor.owner_id) if actor != null else "none",
        str(target.owner_id) if target != null else "none",
    ]
    _damage_segment_serial += 1
    return token


func _resolve_reflection(
        attacker: BattleSide,
        defender: BattleSide,
        source_kind: String,
        damage_type: String,
        result: Dictionary,
        action_token: String = "",
        resolution_metadata: Dictionary = {}) -> Dictionary:
    if attacker == null or defender == null or attacker == defender \
            or bool(resolution_metadata.get("reflection_damage", false)) \
            or damage_type == "poison":
        return {"success": true, "applied": false}
    if str(result.get(
            "defense_reduction_cause", "damage_absorption")) != "damage_absorption":
        return {"success": true, "applied": false}
    var defense_lost := int(result.get("defense_lost", 0))
    var percent := int(defender.current_reflection_percent)
    if defense_lost <= 0 or percent <= 0:
        return {"success": true, "applied": false}
    var amount := int(floor(defense_lost * percent / 100.0))
    if amount <= 0:
        return {"success": true, "applied": false}
    var reflection_source_token := str(defender.current_reflection_source_token)
    var reflection_type := "true" if defender.reflection_is_true_damage() else "normal"
    var reflection_source := {
        "source_kind": "rule",
        "source_id": "reflection",
        "source_name": "反震",
        "source_instance_key": "rule:reflection:%s" % reflection_source_token,
        "trigger_mode": "response",
    }
    var reflected := deal_damage(
        defender, attacker, amount, "rule", reflection_type == "true",
        action_token, reflection_type, {
            "direct_attack": false,
            "reflection_damage": true,
            "source_kind": reflection_source["source_kind"],
            "source_id": reflection_source["source_id"],
            "source_name": reflection_source["source_name"],
            "source_instance_key": reflection_source["source_instance_key"],
            "trigger_mode": reflection_source["trigger_mode"],
        }, reflection_source)
    if not reflected.get("success", false):
        return {
            "success": false,
            "applied": false,
            "reason": str(reflected.get("reason", "反震伤害结算失败")),
            "damage_result": reflected,
        }
    var event_values := {
        "attacker": attacker, "defender": defender,
        "actor": defender, "holder": defender, "target": attacker,
        "defense_lost": defense_lost, "percent": percent,
        "requested_damage": amount,
        "actual_life_loss": int(reflected.get("life_lost", 0)),
        "damage_type": reflection_type,
        "true_damage": reflection_type == "true",
        "source_token": reflection_source_token,
        "action_token": action_token,
        "action_window_id": current_action_window_id(),
    }
    if _committed_event_service != null:
        var serial: int = int(_committed_event_service.next_serial())
        event_values["event_serial"] = serial
        event_values["event_token"] = _committed_event_service.make_token(
            "reflection_resolved", defender, serial, action_token)
        _committed_event_service.commit("reflection_resolved", event_values)
    if _committed_event_service == null:
        _status_system.handle_response_event("reflection_resolved", event_values)
    return {
        "success": true,
        "applied": true,
        "damage_result": reflected,
    }


func _try_block_damage(
        actor: BattleSide,
        target: BattleSide,
        amount: int,
        damage_type: String,
        _source_kind: String,
        _action_token: String,
        metadata: Dictionary) -> Dictionary:
    if actor == null or target == null or actor == target \
            or damage_type not in ["normal", "true"] \
            or str(metadata.get("cause", "damage")) == "cost" \
            or bool(metadata.get("reflection_damage", false)) \
            or not bool(metadata.get("direct_attack", false)):
        return {"blocked": false}
    if not bool(metadata.get("blockable", true)):
        return {"blocked": false}
    return target.try_consume_block(
        amount, damage_type, str(actor.owner_id), current_action_window_id(),
        target.actual_hand_count(), actor.actual_hand_count())


func _emit_damage_resolved(
        actor,
        target,
        requested_amount: int,
        source_kind: String,
        damage_type: String,
        result: Dictionary,
        synchronized: bool,
        action_token: String = "",
        source_metadata: Dictionary = {}) -> void:
    var values := {
        "actor": actor, "target": target, "owner": actor,
        "attacker": actor, "defender": target, "holder": target,
        "include_target_owner": true,
        "round_number": _round_number(),
        "action_token": action_token,
        "source_kind": source_kind,
        "requested_amount": requested_amount,
        "requested_damage": requested_amount,
        "final_amount": int(result.get("final_amount", result.get("requested", 0))),
        "final_damage": int(result.get("final_amount", result.get("requested", 0))),
        "damage_segment_token": str(result.get("damage_segment_token", "")),
        "cause": str(result.get("cause", "damage")),
        "direct_attack": bool(result.get("direct_attack", false)),
        "reflection_damage": bool(result.get("reflection_damage", false)),
        "defense_before": int(result.get("defense_before", 0)),
        "defense_lost": int(result.get("defense_lost", 0)),
        "life_loss_before_intervention": int(result.get(
            "life_loss_before_intervention", result.get("life_lost", 0))),
        "life_loss_prevented": int(result.get("life_loss_prevented", 0)),
        "life_lost": int(result.get("life_lost", 0)),
        "actual_life_loss": int(result.get("life_lost", 0)),
        "life_loss_canceled": bool(result.get("life_loss_canceled", false)),
        "life_loss_intervention_breakdown": result.get(
            "life_loss_intervention_breakdown", []).duplicate(true),
        "life_loss_source_fingerprint": str(result.get(
            "life_loss_source_fingerprint", "")),
        "life_loss_query_fingerprint": str(result.get(
            "life_loss_query_fingerprint", "")),
        "true_damage": damage_type == "true",
        "damage_type": damage_type,
        "synchronized": synchronized,
        "defense_after": int(result.get(
            "defense_after", target.defense if target != null else 0)),
        "life_before": int(result.get("life_before", 0)),
        "life_after": int(result.get(
            "life_after", target.life if target != null else 0)),
    }
    for field in [
            "source_id", "source_name", "source_instance_key", "trigger_mode"]:
        if source_metadata.has(field):
            values[field] = source_metadata[field]
    if _committed_event_service != null:
        var serial: int = int(_committed_event_service.next_serial())
        values["event_token"] = _committed_event_service.make_token(
            "damage_resolved", actor, serial, action_token)
        values["event_serial"] = serial
        _committed_event_service.commit("damage_resolved", values)
    if _committed_event_service == null:
        _status_system.handle_response_event("damage_resolved", values)


func _emit_damage_blocked(
        actor: BattleSide,
        target: BattleSide,
        amount: int,
        damage_type: String,
        source_kind: String,
        action_token: String,
        block_result: Dictionary,
        source_metadata: Dictionary = {},
        damage_segment_token: String = "") -> void:
    var source: Dictionary = block_result.get("source", {})
    var values := {
        "actor": actor, "attacker": actor,
        "target": target, "defender": target, "holder": target,
        "amount": amount, "attack_amount": amount,
        "requested_amount": int(source_metadata.get(
            "requested_damage", amount)),
        "requested_damage": int(source_metadata.get(
            "requested_damage", amount)),
        "final_amount": int(source_metadata.get("final_damage", amount)),
        "final_damage": int(source_metadata.get("final_damage", amount)),
        "damage_type": damage_type, "true_damage": damage_type == "true",
        "source_kind": source_kind,
        "source_token": str(source.get("source_token", "")),
        "action_token": action_token,
        "action_window_id": current_action_window_id(),
        "damage_segment_token": damage_segment_token,
        "cause": str(source_metadata.get("cause", "damage")),
        "direct_attack": bool(source_metadata.get("direct_attack", false)),
        "reflection_damage": bool(source_metadata.get(
            "reflection_damage", false)),
        "source_metadata": source.get("metadata", {}).duplicate(true),
    }
    for field in [
            "source_id", "source_name", "source_instance_key", "trigger_mode"]:
        if source_metadata.has(field):
            values[field] = source_metadata[field]
    _trigger_queue.add_history(
        "damage_blocked", "%s格挡%s攻击" % [target.name, actor.name],
        str(source.get("label", "格挡")), "成功", "%d点%s" % [amount, damage_type])
    _emit_source_state_changed(
        "block_source_changed", target, source, "consumed")
    if _committed_event_service != null:
        var serial: int = int(_committed_event_service.next_serial())
        values["event_serial"] = serial
        values["event_token"] = _committed_event_service.make_token(
            "damage_blocked", target, serial, action_token)
        _committed_event_service.commit("damage_blocked", values)
    if _committed_event_service == null:
        _status_system.handle_response_event("damage_blocked", values)


func _emit_damage_absorption_defense_reduced(
        actor, target, result: Dictionary, source_kind: String,
        action_token: String,
        source_metadata: Dictionary = {}) -> void:
    var removed := int(result.get("defense_lost", 0))
    if removed <= 0 or target == null:
        return
    var after := int(result.get("defense_after", target.defense))
    var values := {
        "actor": actor, "target": target, "owner": target, "holder": target,
        "requested_amount": removed, "effective_amount": removed,
        "defense_before": int(result.get("defense_before", after + removed)),
        "defense_after": after,
        "all": false, "hostile": actor != null and actor != target,
        "source_kind": str(source_metadata.get("source_kind", source_kind)),
        "cause": "damage_absorption",
        "action_token": action_token, "round_number": _round_number(),
    }
    for field in ["source_id", "source_name", "source_instance_key", "trigger_mode"]:
        if source_metadata.has(field):
            values[field] = source_metadata[field]
    if _committed_event_service != null:
        var serial := int(_committed_event_service.next_serial())
        values["event_serial"] = serial
        values["event_token"] = _committed_event_service.make_token(
            "defense_reduced", target, serial, action_token)
        _committed_event_service.commit("defense_reduced", values)
    else:
        _status_system.handle_response_event("defense_reduced", values)


func _emit_source_state_changed(
        event_kind: String,
        side: BattleSide,
        record: Dictionary,
        change: String) -> void:
    if _committed_event_service == null:
        return
    var serial: int = int(_committed_event_service.next_serial())
    _committed_event_service.commit(event_kind, {
        "event_token": _committed_event_service.make_token(
            event_kind, side, serial, str(record.get("source_token", ""))),
        "event_serial": serial,
        "actor": side, "owner": side,
        "target": record.get("target"),
        "round_number": _round_number(),
        "action_token": str(record.get("action_token", "")),
        "source_kind": str(record.get("source_kind", event_kind)),
        "source_token": str(record.get("source_token", "")),
        "change": change,
        "payload": {},
        "public_state": record.duplicate(true),
    })


func _log_damage(
        actor: BattleSide,
        target: BattleSide,
        final_amount: int,
        source_kind: String,
        result: Dictionary) -> void:
    _trigger_queue.add_history(
        "damage_segment",
        "%s → %s" % [actor.name, target.name],
        source_kind,
        "成功",
        "%d 点：防御-%d / 生命-%d" % [
            final_amount,
            result["defense_lost"],
            result["life_lost"]])


func _active_source_marker_total(contributes_to: String) -> int:
    var total := 0
    for side in _sides:
        if side != null and side.has_method("active_technique_marker_sum"):
            total += int(side.active_technique_marker_sum({
                "scope": "battle", "contributes_to": contributes_to,
            }))
    return total


func _round_number() -> int:
    return int(_round_number_reader.call()) if _round_number_reader.is_valid() else 0
