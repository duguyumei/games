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
    if not _damage_resolver.is_buffering():
        final_override = int(resolved_amount["amount"])
        var block_result := _try_block_damage(
            actor, target, int(final_override), resolved_type, source_kind,
            action_token, resolved_metadata)
        if block_result.get("blocked", false):
            _emit_damage_blocked(
                actor, target, int(final_override), resolved_type, source_kind,
                action_token, block_result, source_metadata)
            return {
                "success": true, "buffered": false, "blocked": true,
                "final_amount": 0, "requested": int(final_override),
                "defense_lost": 0, "life_lost": 0,
                "damage_type": resolved_type,
                "true_damage": resolved_type == "true",
                "block_result": block_result,
            }
    var result: Dictionary = _damage_resolver.resolve(
        actor, target, amount, source_kind, resolved_type == "true",
        _status_system, final_override, resolved_type,
        poison_defense_intervention, resolved_metadata)
    if not bool(result["buffered"]):
        if resolved_type == "poison" \
                and resolved_metadata.has("poison_modifier"):
            result["poison_modifier"] = target \
                .commit_poison_damage_modifier_receipt(
                    resolved_metadata["poison_modifier"])
        result["defense_reduction_cause"] = "damage_absorption"
        _record_action_damage(actor, target, result)
        _log_damage(actor, target, int(result["final_amount"]), source_kind, result)
        _emit_damage_absorption_defense_reduced(
            actor, target, result, source_kind, action_token)
        _emit_damage_resolved(
            actor, target, amount, source_kind, resolved_type, result, false,
            action_token, source_metadata)
        _resolve_reflection(
            actor, target, source_kind, resolved_type, result, action_token,
            resolved_metadata)
    result["success"] = true
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


func flush_synchronized_damage() -> Array:
    return _damage_resolver.flush_synchronized(
        Callable(self, "_on_synchronized_damage_resolved"),
        Callable(self, "_resolve_synchronized_damage_amount"))


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


func recover_life(
        side: BattleSide,
        amount: int,
        source_kind: String = "effect",
        action_token: String = "",
        source_actor = null) -> Dictionary:
    var requested := maxi(0, amount)
    var effective := requested
    if requested > 0 and _battle_rule_query_service != null:
        var query = _battle_rule_query_service.resolve_values({
            "hook": "life_recovery_query", "owner": side,
            "actor": source_actor if source_actor != null else side,
            "target": side, "subject_kind": "life_recovery",
            "subject_id": source_kind, "base_value": requested,
            "round_number": _round_number(), "action_token": action_token,
            "source_kind": source_kind,
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
            "source_kind": source_kind, "action_token": action_token,
            "round_number": _round_number(),
        }
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
        require_full: bool = false) -> Dictionary:
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
        "hostile": hostile, "source_kind": source_kind,
        "cause": cause, "action_token": action_token,
        "round_number": _round_number(),
    }
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


func _on_synchronized_damage_resolved(resolution: Dictionary) -> bool:
    var metadata: Dictionary = resolution.get("resolution_metadata", {})
    var resolved_action_token := str(resolution.get(
        "action_token", metadata.get("action_token", "")))
    if bool(resolution.get("blocked", false)):
        _emit_damage_blocked(
            resolution["actor"], resolution["target"],
            int(resolution.get("requested_amount", resolution.get("amount", 0))),
            str(resolution.get("damage_type", "normal")),
            str(resolution.get("source_kind", "")),
            resolved_action_token,
            resolution.get("block_result", {}), metadata)
        return false
    _record_action_damage(
        resolution["actor"], resolution["target"], resolution["result"])
    _log_damage(
        resolution["actor"],
        resolution["target"],
        int(resolution["amount"]),
        str(resolution["source_kind"]),
        resolution["result"])
    _emit_damage_resolved(
        resolution["actor"], resolution["target"],
        int(resolution.get("requested_amount", resolution["amount"])),
        str(resolution["source_kind"]), str(resolution.get("damage_type", "normal")),
        resolution["result"], true,
        str(resolution.get("action_token", "")), metadata)
    resolution["result"]["defense_reduction_cause"] = "damage_absorption"
    _emit_damage_absorption_defense_reduced(
        resolution["actor"], resolution["target"], resolution["result"],
        str(resolution["source_kind"]), resolved_action_token)
    _resolve_reflection(
        resolution["actor"],
        resolution["target"],
        str(resolution["source_kind"]), str(resolution.get("damage_type", "normal")),
        resolution["result"], resolved_action_token, metadata)
    return int(resolution["actor"].life) <= 0


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


func _resolve_synchronized_damage_amount(intent: Dictionary) -> Dictionary:
    var metadata: Dictionary = intent.get("resolution_metadata", {})
    var resolved_action_token := str(intent.get(
        "action_token", metadata.get("action_token", "")))
    var resolved := _resolve_actual_damage_amount(
        intent["actor"], intent["target"],
        int(intent.get("requested_amount", intent["amount"])),
        str(intent["source_kind"]), str(intent.get("damage_type", "normal")),
        resolved_action_token)
    if not resolved.get("success", false):
        return resolved
    var block_result := _try_block_damage(
        intent["actor"], intent["target"], int(resolved.get("amount", 0)),
        str(intent.get("damage_type", "normal")), str(intent.get("source_kind", "")),
        resolved_action_token, metadata)
    if block_result.get("blocked", false):
        resolved["amount"] = 0
        resolved["blocked"] = true
        resolved["block_result"] = block_result
    return resolved


func _resolve_reflection(
        attacker: BattleSide,
        defender: BattleSide,
        source_kind: String,
        damage_type: String,
        result: Dictionary,
        action_token: String = "",
        resolution_metadata: Dictionary = {}) -> void:
    if attacker == null or defender == null or attacker == defender \
            or bool(resolution_metadata.get("reflection_damage", false)) \
            or damage_type == "poison":
        return
    if str(result.get(
            "defense_reduction_cause", "damage_absorption")) != "damage_absorption":
        return
    var defense_lost := int(result.get("defense_lost", 0))
    var percent := int(defender.current_reflection_percent)
    if defense_lost <= 0 or percent <= 0:
        return
    var amount := int(floor(defense_lost * percent / 100.0))
    if amount <= 0:
        return
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
        "final_amount": int(result.get("final_amount", result.get("requested", 0))),
        "defense_lost": int(result.get("defense_lost", 0)),
        "life_lost": int(result.get("life_lost", 0)),
        "true_damage": damage_type == "true",
        "damage_type": damage_type,
        "synchronized": synchronized,
        "defense_after": int(target.defense) if target != null else 0,
        "life_after": int(target.life) if target != null else 0,
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
        source_metadata: Dictionary = {}) -> void:
    var source: Dictionary = block_result.get("source", {})
    var values := {
        "actor": actor, "attacker": actor,
        "target": target, "defender": target, "holder": target,
        "amount": amount, "attack_amount": amount,
        "damage_type": damage_type, "true_damage": damage_type == "true",
        "source_kind": source_kind,
        "source_token": str(source.get("source_token", "")),
        "action_token": action_token,
        "action_window_id": current_action_window_id(),
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
        action_token: String) -> void:
    var removed := int(result.get("defense_lost", 0))
    if removed <= 0 or target == null:
        return
    var after := int(target.defense)
    var values := {
        "actor": actor, "target": target, "owner": target, "holder": target,
        "requested_amount": removed, "effective_amount": removed,
        "defense_before": after + removed, "defense_after": after,
        "all": false, "hostile": actor != null and actor != target,
        "source_kind": source_kind, "cause": "damage_absorption",
        "action_token": action_token, "round_number": _round_number(),
    }
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
