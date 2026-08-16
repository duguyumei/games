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
var _effect_executor_ref: WeakRef
var _action_resolution_scope: Dictionary = {}
var _same_qi_gauge_service
var _technique_invocation_service_ref: WeakRef
var _action_window_serial: int = 0
var _effect_context_stack: Array = []
var _effect_context_slot_entries: Dictionary = {}
var _immediate_effects_by_context: Dictionary = {}

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

func use_effect_executor(executor) -> void:
    _effect_executor_ref = weakref(executor)

func use_same_qi_gauge_service(service) -> void:
    _same_qi_gauge_service = service

func use_technique_invocation_service(service) -> void:
    _technique_invocation_service_ref = weakref(service) if service != null else null

func push_effect_context(context) -> void:
    _effect_context_stack.append(context)
    var invocation_service = _technique_invocation_service()
    if invocation_service != null:
        var slot_id := str(context.get("slot_instance_id") \
            if context is Dictionary else context.slot_instance_id)
        _effect_context_slot_entries[context] = {
            "slot_instance_id": slot_id,
            "entered": invocation_service.enter_resolution_slot(slot_id),
        }

func pop_effect_context(context) -> void:
    if not _effect_context_stack.is_empty() and _effect_context_stack.back() == context:
        _effect_context_stack.pop_back()
    else:
        _effect_context_stack.erase(context)
    var invocation_service = _technique_invocation_service()
    if invocation_service != null and _effect_context_slot_entries.has(context):
        var entry: Dictionary = _effect_context_slot_entries[context]
        invocation_service.exit_resolution_slot(
            str(entry.get("slot_instance_id", "")), bool(entry.get("entered", false)))
        _effect_context_slot_entries.erase(context)

func current_effect_context():
    return _effect_context_stack.back() if not _effect_context_stack.is_empty() else null

func schedule_immediate_effect(context, effect: Dictionary) -> bool:
    if context == null or effect.is_empty():
        return false
    if not _immediate_effects_by_context.has(context):
        _immediate_effects_by_context[context] = []
    _immediate_effects_by_context[context].append(effect.duplicate(true))
    return true

func take_immediate_effects(context) -> Array:
    var result: Array = _immediate_effects_by_context.get(context, [])
    _immediate_effects_by_context.erase(context)
    return result

func same_qi_projection(side: BattleSide, amount: int, context: Dictionary = {}) -> Dictionary:
    if _same_qi_gauge_service == null:
        return {"success": false, "reason": "同气槽服务尚未装配"}
    return _same_qi_gauge_service.project_gain(side, amount, context)

func gain_same_qi(
        side: BattleSide,
        amount: int,
        source: String,
        token: String) -> Dictionary:
    if _same_qi_gauge_service == null:
        return {"success": false, "reason": "同气槽服务尚未装配"}
    var result: Dictionary = _same_qi_gauge_service.apply_gain(
        side, amount, source, token)
    if result.get("success", false) and not result.get("reused", false):
        add_history(
            "same_qi_changed",
            "%s同气变化" % side.name,
            source,
            "成功",
            "%d +%d -%d = %d / %d；额外行动 +%d" % [
                int(result["same_qi_before"]), int(result["gained"]),
                int(result["spent"]), int(result["same_qi_after"]),
                int(result["same_qi_capacity"]),
                int(result["granted_actions"]),
            ])
        var response := result.duplicate(true)
        response["actor"] = side
        response["owner"] = side
        response["holder"] = side
        response["action_token"] = token.trim_suffix(":same_qi")
        if _committed_event_service != null:
            var serial := int(_committed_event_service.next_serial())
            response["event_serial"] = serial
            response["event_token"] = _committed_event_service.make_token(
                "same_qi_gain_resolved", side, serial, response["action_token"])
            _committed_event_service.commit("same_qi_gain_resolved", response)
        else:
            _status_system.handle_response_event("same_qi_gain_resolved", response)
    return result

func write_same_qi(
        side: BattleSide,
        operation: String,
        amount: int,
        source: String,
        token: String,
        source_category: String = "effect",
        action_token: String = "") -> Dictionary:
    if _same_qi_gauge_service == null:
        return {"success": false, "reason": "同气槽服务尚未装配"}
    var resolved_action_token := action_token if action_token != "" \
        else token.split(":same_qi")[0]
    var result: Dictionary = _same_qi_gauge_service.apply_write(
        side, operation, amount, source, token, {
            "source_category": source_category,
            "action_token": resolved_action_token,
        })
    if result.get("success", false) and not result.get("reused", false):
        add_history(
            "same_qi_changed", "%s同气变化" % side.name, source, "成功",
            "%d → %d / %d；转换%d次" % [
                int(result.get("same_qi_before", 0)),
                int(result.get("same_qi_after", 0)),
                int(result.get("same_qi_capacity", 5)),
                int(result.get("conversion_count", 0)),
            ])
        var response := result.duplicate(true)
        response["actor"] = side
        response["owner"] = side
        response["holder"] = side
        response["action_token"] = resolved_action_token
        if _committed_event_service != null:
            var serial := int(_committed_event_service.next_serial())
            response["event_serial"] = serial
            response["event_token"] = _committed_event_service.make_token(
                "same_qi_gain_resolved", side, serial, resolved_action_token)
            _committed_event_service.commit("same_qi_gain_resolved", response)
        else:
            _status_system.handle_response_event("same_qi_gain_resolved", response)
    return result

func same_qi_receipts_for_action(side: BattleSide, action_token: String) -> Array:
    if _same_qi_gauge_service == null:
        return []
    return _same_qi_gauge_service.receipts_for_action(side, action_token)

func execute_effect_chain(effects: Array, context) -> Dictionary:
    var executor = _effect_executor_ref.get_ref() if _effect_executor_ref != null else null
    return executor.execute_all(effects, context) if executor != null else {
        "success": false, "detail": "战斗端口缺少效果执行器"}

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
        action_token: String = "",
        damage_type: String = "",
        resolution_metadata: Dictionary = {}) -> Dictionary:
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
                action_token, block_result)
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
    if not bool(result["buffered"]):
        _emit_damage_absorption_defense_reduced(
            actor, target, result, source_kind, action_token)
        _emit_damage_resolved(
            actor, target, amount, source_kind, resolved_type, result, false,
            action_token)
        _resolve_reflection(
            actor, target, source_kind, resolved_type, result, action_token)
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
        return {"base": base_amount, "fixed": 0, "percent": 0, "final_amount": maxi(0, base_amount)}
    return affected_side.freeze_poison_damage_modifiers(
        base_amount, receipt_token,
        _active_source_marker_total("poison_damage_fixed_global"))

func begin_synchronized_damage(records: Array) -> void:
    var actors: Array = []
    for record in records:
        actors.append(record["actor"])
    _damage_resolver.begin_synchronized(actors)

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
    _immediate_effects_by_context.clear()

func flush_synchronized_damage() -> Array:
    return _damage_resolver.flush_synchronized(
        Callable(self, "_on_synchronized_damage_resolved"),
        Callable(self, "_resolve_synchronized_damage_amount"))

func trigger_poison_card(
        holder: BattleSide,
        card,
        action_token: String = "",
        replayed: bool = false,
        frozen_amount_override = null) -> Dictionary:
    if holder == null or card == null or not card.has_anomaly("state", "poison"):
        return {"success": false, "reason": "毒触发目标无效"}
    var frozen_amount: int = (
        current_effective_qi(holder, card)
        if frozen_amount_override == null else maxi(0, int(frozen_amount_override)))
    var damage: Dictionary = deal_damage(
        holder, holder, frozen_amount, "毒", false, action_token, "poison", {
            "kind": "poison_card_trigger",
            "holder": holder,
            "card": card,
            "frozen_amount": frozen_amount,
            "action_token": action_token,
            "poison_modifier_receipt_token": "%s:poison:%s" % [
                action_token, str(card.id)],
            "replayed": replayed,
        })
    if not damage.get("success", false):
        return damage
    var removed: Dictionary = remove_card_anomaly(
        card, "state", "poison", "毒触发")
    if not removed.get("changed", false):
        return {"success": false, "reason": "毒伤完成后清除毒失败", "damage_result": damage}
    if not bool(damage.get("buffered", false)):
        notify_poison_triggered(
            holder, card, frozen_amount, damage, action_token, replayed)
    return {
        "success": true,
        "card": card,
        "frozen_amount": frozen_amount,
        "life_lost": int(damage.get("life_lost", 0)),
        "actual_life_loss": int(damage.get("life_lost", 0)),
        "damage_result": damage,
        "buffered": bool(damage.get("buffered", false)),
    }

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
            return {"success": false, "reason": "；".join(query.errors), "recovered": 0}
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

func _active_source_marker_total(contributes_to: String) -> int:
    var total := 0
    for side in _sides:
        if side != null and side.has_method("active_technique_marker_sum"):
            total += int(side.active_technique_marker_sum({
                "scope": "battle", "contributes_to": contributes_to,
            }))
    return total

func write_source_marker(
        side: BattleSide,
        source: Dictionary,
        operation: String,
        amount: int,
        action_token: String = "") -> Dictionary:
    var result: Dictionary = side.source_marker_store.write(
        str(source.get("source_kind", "")),
        str(source.get("source_instance_key", "")),
        str(source.get("content_id", "")),
        str(source.get("marker_id", "")),
        str(source.get("scope", "battle")), operation, amount, source)
    if result.get("success", false) and result.get("changed", false):
        _emit_source_marker_changed(side, source, operation, result, action_token)
        if str(source.get("scope", "battle")) == "run" \
                and str(source.get("contributes_to", "")) != "":
            side.recalculate_effective_max_life()
    return result

func transfer_source_marker(
        side: BattleSide,
        source: Dictionary,
        target: Dictionary,
        amount: int,
        action_token: String = "") -> Dictionary:
    var result: Dictionary = side.source_marker_store.transfer(source, target, amount)
    if result.get("success", false) and int(result.get("transferred", 0)) > 0:
        _emit_source_marker_changed(
            side, source, "transfer_out", result.get("source", {}), action_token)
        _emit_source_marker_changed(
            side, target, "transfer_in", result.get("target", {}), action_token)
        if str(source.get("scope", "battle")) == "run" \
                or str(target.get("scope", "battle")) == "run":
            side.recalculate_effective_max_life()
    return result

func invoke_sequence_technique(effect: Dictionary, context) -> Dictionary:
    var invocation_service = _technique_invocation_service()
    if invocation_service == null:
        return {"success": false, "reason": "功法调用服务尚未装配"}
    return invocation_service.invoke(effect, context)

func resolve_after_caller_advance(root_action_token: String) -> Dictionary:
    var invocation_service = _technique_invocation_service()
    if invocation_service == null:
        return {"success": true, "results": []}
    return invocation_service.resolve_after_caller_advance(root_action_token)

func resolve_technique_invocations_at_timing(
        timing: String,
        root_action_token: String = "") -> Dictionary:
    var invocation_service = _technique_invocation_service()
    if invocation_service == null:
        return {"success": true, "results": []}
    return invocation_service.resolve_timing(timing, root_action_token)

func _technique_invocation_service():
    return _technique_invocation_service_ref.get_ref() \
        if _technique_invocation_service_ref != null else null

func emit_technique_sequence_changed(
        side: BattleSide,
        action_token: String,
        reason: String,
        changed_slots: Array) -> void:
    if _committed_event_service == null:
        return
    var serial := int(_committed_event_service.next_serial())
    _committed_event_service.commit("technique_sequence_changed", {
        "event_token": _committed_event_service.make_token(
            "technique_sequence_changed", side, serial, action_token),
        "event_serial": serial, "actor": side, "owner": side,
        "action_token": action_token, "reason": reason,
        "changed_slots": changed_slots.duplicate(true),
        "round_number": _round_number(),
    })

func _emit_source_marker_changed(
        side: BattleSide,
        source: Dictionary,
        operation: String,
        result: Dictionary,
        action_token: String) -> void:
    var values := source.duplicate(true)
    values.merge({
        "actor": side, "owner": side, "holder": side,
        "operation": operation, "before": int(result.get("before", 0)),
        "after": int(result.get("after", 0)),
        "delta": int(result.get("delta", 0)),
        "consumed": int(result.get("consumed", 0)),
        "action_token": action_token, "round_number": _round_number(),
    }, true)
    if _committed_event_service != null:
        var serial := int(_committed_event_service.next_serial())
        values["event_serial"] = serial
        values["event_token"] = _committed_event_service.make_token(
            "source_marker_changed", side, serial, action_token)
        _committed_event_service.commit("source_marker_changed", values)
    if _committed_event_service == null:
        _status_system.handle_response_event("source_marker_changed", values)

func add_momentum(side: BattleSide, amount: int) -> int:
    return side.add_momentum(amount)

func set_momentum(side: BattleSide, value: int) -> int:
    return side.set_momentum(value)

func write_momentum(
        side: BattleSide,
        operation: String,
        amount: int,
        source_category: String,
        action_token: String,
        source_id: String = "") -> Dictionary:
    return side.write_momentum(
        operation, amount, source_category, action_token, source_id)

func transfer_card_anomaly(
        source_card,
        target_card,
        category: String,
        anomaly_id: String,
        source: String,
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.transfer_card_anomaly(
        source_card, target_card, category, anomaly_id, source, event_metadata)

func set_reflection_percent(
        side: BattleSide, value: int, source_token: String = "") -> int:
    return side.set_reflection_percent(value, source_token)

func grant_reflection_source(
        side: BattleSide,
        percent: int,
        remaining_rounds: int,
        expiry_kind: String,
        label: String,
        source_token: String = "",
        target_side: BattleSide = null) -> Dictionary:
    var window_id := ""
    if expiry_kind == "action_window_end":
        var target_owner_id := str(target_side.owner_id) if target_side != null else ""
        if _can_bind_current_source(target_owner_id):
            window_id = _current_action_window_id()
    var record := side.add_reflection_source(
        percent, source_token, remaining_rounds, expiry_kind,
        window_id, label, true)
    _emit_source_state_changed(
        "reflection_source_changed", side, record, "established")
    return {"success": true, "record": record, "source_token": record["source_token"]}

func grant_reflection_true_damage_source(
        side: BattleSide,
        remaining_rounds: int,
        label: String,
        source_token: String = "") -> Dictionary:
    var record := side.add_reflection_true_damage_source(
        source_token, remaining_rounds, label, true)
    _emit_source_state_changed(
        "reflection_source_changed", side, record, "true_damage_established")
    return {"success": true, "record": record, "source_token": record["source_token"]}

func grant_block_source(
        side: BattleSide,
        target_side: BattleSide,
        condition,
        label: String,
        source_token: String = "",
        metadata: Dictionary = {}) -> Dictionary:
    var target_owner_id := str(target_side.owner_id) if target_side != null else ""
    var window_id := _current_action_window_id() \
        if _can_bind_current_source(target_owner_id) else ""
    var record := side.add_block_source(
        condition, source_token, target_owner_id, window_id,
        label, true, metadata)
    _emit_source_state_changed("block_source_changed", side, record, "established")
    return {"success": true, "record": record, "source_token": record["source_token"]}

func register_challenge(
        context,
        threshold: int,
        effects: Array,
        label: String = "邀战",
        met_effects: Array = []) -> Dictionary:
    var runtime = context
    var token: String = str(runtime.actor.next_combat_source_token("challenge"))
    var target_owner_id := str(runtime.target.owner_id) if runtime.target != null else ""
    var window_id := _current_action_window_id() \
        if _can_bind_current_source(target_owner_id) else ""
    var record := {
        "source_token": token,
        "threshold": maxi(0, threshold), "current": 0,
        "challenger": runtime.actor, "target": runtime.target,
        "target_owner_id": target_owner_id,
        "window_id": window_id, "waiting_for_action": window_id == "",
        "effects": effects.duplicate(true),
        "met_effects": met_effects.duplicate(true),
        "power": runtime.power, "initial_power": runtime.initial_power,
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
        "label": label, "public": true,
    }
    runtime.actor.challenge_records.append(record)
    _emit_source_state_changed(
        "challenge_established", runtime.actor, record, "established")
    return {"success": true, "record": record, "source_token": token}

func notify_source_changed(
        event_kind: String,
        side: BattleSide,
        record: Dictionary,
        change: String,
        payload: Dictionary = {}) -> void:
    _emit_source_state_changed(event_kind, side, record, change, payload)

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

func generate_temporary_normal_card(
        side: BattleSide,
        source,
        options: Dictionary = {}):
    if _battle_rng == null:
        return null
    var base_deck = JSON.parse_string(FileAccess.get_file_as_string(
        "res://data/base_deck.json"))
    if not base_deck is Dictionary or not base_deck.get("ranks") is Array:
        return null
    var ranks: Array = base_deck["ranks"]
    var attributes: Array = base_deck.get("attributes", [])
    var base_attribute: String = str(source.get("attribute")) \
        if source is Object else str(source)
    if base_attribute not in ["wind", "forest", "fire", "mountain"]:
        return null
    var attribute := base_attribute
    if str(options.get("attribute_mode", "same_base")) == "random_other_base":
        var attribute_ids: Array[String] = []
        for value in attributes:
            var attribute_id := str(value.get("id", ""))
            if attribute_id != base_attribute:
                attribute_ids.append(attribute_id)
        if attribute_ids.is_empty():
            return null
        attribute = attribute_ids[_battle_rng.randi_range(0, attribute_ids.size() - 1)]
    var rank: Dictionary = ranks[_battle_rng.randi_range(0, ranks.size() - 1)]
    if source is Object and source.has_method("current_rank_order"):
        var source_order := int(source.current_rank_order())
        var wanted_order := source_order
        match str(options.get("rank_mode", "same_current")):
            "random_adjacent":
                wanted_order = source_order + (1 if source_order <= 2 else -1 \
                    if source_order >= 14 else [-1, 1][
                        _battle_rng.randi_range(0, 1)])
            "random":
                wanted_order = int(rank.get("order", 0))
        for value in ranks:
            if int(value.get("order", 0)) == wanted_order:
                rank = value
                break
    var card = QiCard.new(
        "%s-temp-%d" % [attribute, _battle_rng.randi()],
        str(rank.get("id", "")), int(rank.get("order", 0)),
        int(rank.get("qi", 0)), attribute, attribute,
        "%s_%s" % [attribute, str(rank.get("id", "")).to_lower()])
    card.temporary_card = true
    if bool(options.get("add_void", true)):
        var applied: Dictionary = apply_card_anomaly(
            card, "mark", "void", {}, "临时真气", 1, false)
        if not applied.get("success", false):
            return null
    var added: Dictionary = side.card_zone_service.add_generated(side, card, "hand", true)
    return card if added.get("success", false) else null

func steal_random_normal_card(actor: BattleSide, target: BattleSide) -> Dictionary:
    if actor == null or target == null or _battle_rng == null:
        return {"success": false}
    var candidates: Array = target.draw_pile.filter(
        func(card): return card.is_card_kind("normal"))
    if candidates.is_empty():
        return {"success": false}
    var card = candidates[_battle_rng.randi_range(0, candidates.size() - 1)]
    return move_card(target, "draw_pile", actor, "hand", card, "steal", "top", "technique")

func recover_forest_priority(
        actor: BattleSide, maximum_qi: int, prefer_permanent: bool) -> Dictionary:
    if actor == null or _battle_rng == null:
        return {"success": false}
    var plain: Array = []
    var reshaped: Array = []
    for card in actor.discard_pile:
        if not card.is_card_kind("normal") or current_effective_qi(actor, card) > maximum_qi:
            continue
        var permanent: bool = not card.reshape_origin.is_empty() \
            or card.reshape_enhancement != "" or card.reshape_imprint != "" \
            or not card.reshape_others.is_empty()
        (reshaped if permanent else plain).append(card)
    var candidates: Array = reshaped if prefer_permanent and not reshaped.is_empty() else plain
    if candidates.is_empty():
        return {"success": false}
    var card = candidates[_battle_rng.randi_range(0, candidates.size() - 1)]
    return move_card(actor, "discard_pile", actor, "hand", card, "recover", "top", "technique")

func burn_deck_then_heat_hand(
        actor: BattleSide, bottom_first: bool, choice_capture: String, context) -> Dictionary:
    var candidates: Array = actor.draw_pile.filter(func(card):
        return card.is_card_kind("normal") and not card.is_attribute("fire") \
            and can_apply_card_anomaly(card, "mark", "burned_out").get("allowed", false))
    if candidates.is_empty():
        return {"success": true, "detail": ""}
    var card = null
    if bottom_first:
        card = candidates[0]
    else:
        card = candidates[_battle_rng.randi_range(0, candidates.size() - 1)]
    var applied := apply_card_anomaly(card, "mark", "burned_out", {}, "引火式")
    if not applied.get("success", false):
        return {"success": true, "detail": ""}
    var heat_targets: Array = context.captures.get(choice_capture, [])
    if not heat_targets.is_empty():
        var layers := int(floor(card.current_base_qi_value() / 2.0))
        if layers > 0:
            apply_card_anomaly(heat_targets[0], "buff", "qi_heat", {}, "引火式", layers)
    return {"success": true, "detail": "燃尽并施加炽气"}

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
            "source_kind": "poison",
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
        })

func notify_response_event(event_kind: String, values: Dictionary) -> void:
    if _status_system != null:
        _status_system.handle_response_event(event_kind, values)

func successful_on_play_ids(action_token: String) -> Array:
    var runtime = _card_reshape_runtime()
    return runtime.successful_on_play_ids(action_token) if runtime != null else []

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

func move_cards_synchronously(records: Array) -> Array:
    if records.is_empty():
        return []
    var first_side = records[0].get("side")
    if first_side == null:
        return []
    var moved: Array = first_side.card_zone_service.move_cards_synchronously(records)
    for record in records:
        if moved.has(record.get("card")) and str(record.get("reason", "")) == "explicit_discard":
            _status_system.record_technique_card_flow(record.get("side"), "discard", 1)
    return moved

func transfer_cards_atomically(records: Array) -> Array:
    if records.is_empty():
        return []
    var first_side = records[0].get("source_side")
    if first_side == null:
        return []
    return first_side.card_zone_service.temporarily_transfer_many(records)

func atomic_exchange_cards(
        actor_side: BattleSide, actor_zone: String, actor_card,
        target_side: BattleSide, target_zone: String, target_card) -> Dictionary:
    return actor_side.card_zone_service.atomic_exchange(
        actor_side, actor_zone, actor_card, target_side, target_zone, target_card)

func zone_cards(side: BattleSide, zone: String) -> Array:
    match zone:
        "hand": return side.hand.duplicate()
        "draw_pile": return side.draw_pile.duplicate()
        "staging": return side.staging.duplicate()
        "discard_pile": return side.discard_pile.duplicate()
    return []

func query_effect_targets(context, query_spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    var QueryScript = load("res://core/effects/effect_target_query.gd")
    var values := query_spec.duplicate(true)
    values["card_identity_policy"] = context.card_identity_policy
    return QueryScript.new().configure(values).resolve(context, rng)

func apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary,
        source: String,
        layers: int = 1,
        replace_state: bool = false,
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.apply_card_anomaly(
        card, category, anomaly_id, payload, source, layers, replace_state,
        event_metadata)

func can_apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        replace_state: bool = false) -> Dictionary:
    return _status_system.can_apply_card_anomaly(
        card, category, anomaly_id, replace_state)

func remove_card_anomaly(
        card,
        category: String,
        anomaly_id: String = "",
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.remove_card_anomaly(
        card, category, anomaly_id, source, event_metadata)

func set_card_anomaly_layers(
        card,
        category: String,
        anomaly_id: String,
        layers: int,
        source: String = "效果") -> Dictionary:
    return _status_system.set_card_anomaly_layers(
        card, category, anomaly_id, layers, source)

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

func apply_temporary_rank(
        card,
        rank_name: String,
        rank_order: int,
        base_qi: int) -> Dictionary:
    if card == null:
        return {"success": false, "reason": "临时牌阶参数无效"}
    return {
        "success": card.set_temporary_rank(rank_name, rank_order, base_qi),
        "rank_name": rank_name,
        "rank_order": rank_order,
        "base_qi": base_qi,
    }

func clear_temporary_reshape(card, subslot: String) -> Dictionary:
    if card == null or subslot not in ["enhancement", "attribute", "rank"]:
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

func gain_extra_actions(
        side: BattleSide,
        amount: int,
        source: String,
        source_category: String = "technique",
        action_token: String = "") -> int:
    var gained: int = _battle_flow.grant_actions(side, amount, {
        "category": source_category,
        "source": source,
        "action_token": action_token,
        "from_same_qi": source_category == "same_qi",
    })
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

func register_response(
        event_kind: String,
        expiry: String,
        effects: Array,
        context,
        filters: Dictionary = {},
        expiry_effects: Array = []) -> Dictionary:
    return _status_system.register_response(
        event_kind, expiry, effects, context, filters, expiry_effects)

func register_next_round_hand_limit(
        context, amount: int, affected_side = null) -> Dictionary:
    return _status_system.register_next_round_hand_limit(
        context, amount, affected_side)

func register_defense_decay_return(context) -> Dictionary:
    return _status_system.register_defense_decay_return(context)

func register_reflection_expiry(context, percent: int) -> Dictionary:
    return _status_system.register_reflection_expiry(context, percent)

func register_no_life_loss_disruption(context, effect: Dictionary) -> Dictionary:
    return _status_system.register_no_life_loss_disruption(context, effect)

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
            resolution.get("block_result", {}))
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
        str(resolution.get("action_token", "")))
    resolution["result"]["defense_reduction_cause"] = "damage_absorption"
    _emit_damage_absorption_defense_reduced(
        resolution["actor"], resolution["target"], resolution["result"],
        str(resolution["source_kind"]), resolved_action_token)
    _resolve_reflection(
        resolution["actor"],
        resolution["target"],
        str(resolution["source_kind"]), str(resolution.get("damage_type", "normal")),
        resolution["result"], resolved_action_token)
    if str(metadata.get("kind", "")) == "poison_card_trigger":
        notify_poison_triggered(
            metadata.get("holder"), metadata.get("card"),
            int(metadata.get("frozen_amount", 0)), resolution["result"],
            str(metadata.get("action_token", "")), bool(metadata.get("replayed", false)))
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
        var window_id := _current_action_window_id()
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

func _emit_damage_resolved(
        actor,
        target,
        requested_amount: int,
        source_kind: String,
        damage_type: String,
        result: Dictionary,
        synchronized: bool,
        action_token: String = "") -> void:
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
    if _committed_event_service != null:
        var serial: int = int(_committed_event_service.next_serial())
        values["event_token"] = _committed_event_service.make_token(
            "damage_resolved", actor, serial, action_token)
        values["event_serial"] = serial
        _committed_event_service.commit("damage_resolved", values)
    if _committed_event_service == null:
        _status_system.handle_response_event("damage_resolved", values)

func _round_number() -> int:
    return int(_round_number_reader.call()) if _round_number_reader.is_valid() else 0

func _resolve_reflection(
        attacker: BattleSide,
        defender: BattleSide,
        source_kind: String,
        damage_type: String,
        result: Dictionary,
        action_token: String = "") -> void:
    if attacker == null or defender == null or attacker == defender \
            or source_kind == "reflection" \
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
    var reflected := deal_damage(
        defender, attacker, amount, "reflection", reflection_type == "true",
        action_token, reflection_type, {"direct_attack": false})
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
        "action_window_id": _current_action_window_id(),
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
        source_kind: String,
        _action_token: String,
        metadata: Dictionary) -> Dictionary:
    if actor == null or target == null or actor == target \
            or damage_type not in ["normal", "true"] \
            or source_kind == "reflection" \
            or not bool(metadata.get("direct_attack", false)):
        return {"blocked": false}
    if not bool(metadata.get("blockable", true)):
        return {"blocked": false}
    return target.try_consume_block(
        amount, damage_type, str(actor.owner_id), _current_action_window_id(),
        target.actual_hand_count(), actor.actual_hand_count())

func _emit_damage_blocked(
        actor: BattleSide,
        target: BattleSide,
        amount: int,
        damage_type: String,
        source_kind: String,
        action_token: String,
        block_result: Dictionary) -> void:
    var source: Dictionary = block_result.get("source", {})
    var values := {
        "actor": actor, "attacker": actor,
        "target": target, "defender": target, "holder": target,
        "amount": amount, "attack_amount": amount,
        "damage_type": damage_type, "true_damage": damage_type == "true",
        "source_kind": source_kind,
        "source_token": str(source.get("source_token", "")),
        "action_token": action_token,
        "action_window_id": _current_action_window_id(),
        "source_metadata": source.get("metadata", {}).duplicate(true),
    }
    add_history(
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
        change: String,
        payload: Dictionary = {}) -> void:
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
        "payload": payload.duplicate(true),
        "public_state": record.duplicate(true),
    })

func _current_action_window_id() -> String:
    return str(_action_resolution_scope.get("window_id", ""))

func _current_acting_owner_ids() -> Array:
    return _action_resolution_scope.get("acting_owner_ids", [])

func _can_bind_current_source(target_owner_id: String) -> bool:
    return bool(_action_resolution_scope.get("source_binding_open", false)) \
        and _current_acting_owner_ids().has(target_owner_id)
