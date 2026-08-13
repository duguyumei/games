class_name ActionResolver
extends RefCounted

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const BattleActionRecordScript = preload("res://core/battle_action_record.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")

var technique_repository
var passive_rule_runtime
var trigger_queue
var effect_executor
var timing_system
var rng: RandomNumberGenerator
var effect_ports
var _pending_resolution: Dictionary = {}
var _passive_sources_by_token: Dictionary = {}
var _set_scenario_error: Callable
var action_preview_service
var committed_event_service

func _init(
        effect_ports_value,
        techniques,
        passive_runtime,
        queue,
        executor,
        random_source: RandomNumberGenerator,
        battle_timing_system = null,
        scenario_error_callback: Callable = Callable(),
        preview_service = null,
        event_service = null) -> void:
    effect_ports = effect_ports_value
    technique_repository = techniques
    passive_rule_runtime = passive_runtime
    trigger_queue = queue
    effect_executor = executor
    rng = random_source
    timing_system = battle_timing_system
    _set_scenario_error = scenario_error_callback
    action_preview_service = preview_service
    committed_event_service = event_service
    if timing_system != null:
        timing_system.register_weak_handler(
            timing_system.GROUP_END,
            "action_resolver.sequence_progression",
            500,
            self,
            "_on_group_end")

func use_trigger_queue(queue) -> void:
    trigger_queue = queue

func reset() -> void:
    _pending_resolution.clear()
    _passive_sources_by_token.clear()
    effect_ports.abort_action_resolution()

func begin_action_resolution(actors: Array, metadata: Dictionary = {}) -> void:
    effect_ports.begin_action_resolution(actors, metadata)

func abort_action_resolution() -> void:
    effect_ports.abort_action_resolution()

func finish_action_resolution() -> Dictionary:
    var completed: Dictionary = effect_ports.finish_action_resolution()
    if not completed.get("success", false) or timing_system == null:
        return completed
    var results: Array = completed.get("results", [])
    var actors: Array = results.map(func(result): return result.get("side"))
    var emitted: Dictionary = timing_system.emit_timing(
        timing_system.ACTION_RESOLUTION_END, {
            "actors": actors,
            "action_results": results,
            "metadata": completed.get("metadata", {}),
        })
    if not emitted.get("success", false):
        var reason := str(emitted.get("reason", "action_resolution_end 处理器失败"))
        if _set_scenario_error.is_valid():
            _set_scenario_error.call(
                "战斗时点失败 hook=%s reason=%s" % [
                    timing_system.ACTION_RESOLUTION_END, reason])
        return {"success": false, "reason": reason, "results": results}
    return completed

func make_action_record(
        actor,
        target,
        action_preview: Dictionary,
        sequence_book,
        order: int,
        turn_number: int):
    return BattleActionRecordScript.new().configure(
        actor,
        target,
        action_preview,
        sequence_book,
        order,
        turn_number)

func finalize_action_preview(
        actor,
        action_preview: Dictionary,
        target = null,
        turn_number: int = 0) -> Dictionary:
    if bool(action_preview.get("action_finalized", false)):
        return {"success": true, "reused": true}
    var reshape: Dictionary = effect_ports.finalize_reshape_action(
        actor, action_preview)
    if not reshape.get("success", false):
        return reshape
    var action_token := str(action_preview.get("reshape_action_token", ""))
    if action_preview_service != null:
        var recalculated: Dictionary = action_preview_service.recalculate_confirmed_power(
            actor, target, action_preview, action_token,
            int(reshape.get("card_multiplier_bonus", 0)))
        if not recalculated.get("success", false):
            return {
                "success": false,
                "reason": recalculated.get("reason", "行动确认功法值查询失败"),
            }
    var activation_freeze := _freeze_technique_activation(
        actor, target, action_preview, turn_number, action_token)
    if not activation_freeze.get("success", false):
        return activation_freeze
    action_preview["action_finalized"] = true
    return {"success": true, "reused": false, "action_token": action_token}

func confirm_finalized_action(
        actor,
        action_preview: Dictionary,
        target = null,
        turn_number: int = 0) -> Dictionary:
    if bool(action_preview.get("passive_action_confirmed", false)):
        return {"success": true, "reused": true}
    if not bool(action_preview.get("action_finalized", false)):
        return {"success": false, "reason": "行动尚未完成正式冻结"}
    var action_token := str(action_preview.get("reshape_action_token", ""))
    if committed_event_service != null:
        var confirmed: Dictionary = committed_event_service.commit(
            "action_confirmed", {
                "event_token": committed_event_service.make_token(
                    "action_confirmed", actor, action_token, action_token),
                "actor": actor, "target": target, "owner": actor,
                "round_number": turn_number, "action_token": action_token,
                "technique_triggered": bool(action_preview.get(
                    "technique_activation", {}).get("allowed", false)),
                "action_succeeded": true,
                "metadata": {
                    "hand_id": str(action_preview.get("hand", {}).get("id", "")),
                    "power_query_fingerprints": _power_query_fingerprints(action_preview),
                },
            })
        if not confirmed.get("success", false):
            return confirmed
    action_preview["passive_action_confirmed"] = true
    return {"success": true, "reused": false, "action_token": action_token}

func _freeze_technique_activation(
        actor,
        target,
        action_preview: Dictionary,
        turn_number: int,
        action_token: String) -> Dictionary:
    var technique: Dictionary = action_preview.get("technique", {})
    var condition: Dictionary = action_preview.get("condition", {})
    if technique.is_empty():
        action_preview["technique_activation"] = {
            "success": true, "checked": false, "allowed": false,
            "reason": "空功法序列", "source_breakdown": [], "errors": [],
            "frozen": true, "action_token": action_token,
        }
        return {"success": true}
    if not bool(condition.get("ok", false)):
        action_preview["technique_activation"] = {
            "success": true, "checked": false, "allowed": false,
            "reason": str(condition.get("reason", "功法条件不满足")),
            "source_breakdown": [], "errors": [],
            "frozen": true, "action_token": action_token,
        }
        return {"success": true}
    var permission = actor.battle_permission_service
    var result: Dictionary = (
        permission.can_activate_technique(
            actor,
            str(action_preview.get("technique_id", "")),
            str(action_preview.get("hand", {}).get("id", "")), {
                "target": target,
                "round_number": turn_number,
                "action_token": action_token,
                "card_instance_ids": action_preview.get("cards", []).map(
                    func(card): return str(card.id)),
                "source_kind": "action_confirmed",
            })
        if permission != null else {
            "allowed": true, "reason": "", "source_breakdown": [], "errors": [],
        })
    if not result.get("errors", []).is_empty():
        return {
            "success": false,
            "reason": str(result.get("reason", "功法启动权限查询失败")),
        }
    result["success"] = true
    result["checked"] = true
    result["frozen"] = true
    result["action_token"] = action_token
    action_preview["technique_activation"] = result
    return {"success": true, "permission": result}

func resolve_action_records(records: Array, synchronized: bool) -> Dictionary:
    if not _pending_resolution.is_empty():
        return {
            "success": false,
            "pending_choice": true,
            "choice_request": trigger_queue.pending_choice_snapshot(),
            "detail": "已有行动正在等待选择",
        }
    for record in records:
        var action_preview: Dictionary = record["preview"]
        var technique: Dictionary = action_preview["technique"]
        if technique.is_empty():
            continue
        if not action_preview["condition"]["ok"]:
            trigger_queue.add_history(
                "on_play_resolve", technique["name"], "%s功法" % record["actor"].name,
                "条件失败", action_preview["condition"]["reason"])
            continue
        var activation: Dictionary = action_preview.get(
            "technique_activation", {})
        if not bool(activation.get("frozen", false)) \
                or not bool(record["technique_activation_checked"]):
            return {
                "success": false, "pending_choice": false,
                "detail": "功法启动权限尚未冻结",
            }
        if not bool(record["technique_activation_allowed"]):
            trigger_queue.add_history(
                "on_play_resolve", technique["name"],
                "%s功法" % record["actor"].name,
                "启动被拒绝", str(activation.get("reason", "功法启动被拒绝")))
            continue
        action_preview["values"] = PowerCalculatorScript.apply_momentum(
            action_preview["values"],
            int(record["actor"].momentum_value))
        record["triggered"] = true
    _pending_resolution = {
        "records": records,
        "synchronized": synchronized,
        "phase_index": 0,
        "phase_started": false,
    }
    return _continue_resolution()

func resume_choice(request_id: String, selected_ids: Array) -> Dictionary:
    if _pending_resolution.is_empty() or not trigger_queue.has_pending_choice():
        return {"success": false, "reason": "当前没有等待中的行动选择"}
    var queue_results: Array = trigger_queue.resolve_choice(request_id, selected_ids)
    _mark_failed_records(queue_results)
    for resolution in queue_results:
        if resolution.get("result", {}).get("pending_choice", false):
            return {
                "success": false,
                "pending_choice": true,
                "choice_request": trigger_queue.pending_choice_snapshot(),
                "detail": resolution["result"].get("detail", "等待选择"),
            }
    return _continue_resolution()

func has_pending_choice() -> bool:
    return not _pending_resolution.is_empty() and trigger_queue.has_pending_choice()

func pending_choice_snapshot() -> Dictionary:
    return trigger_queue.pending_choice_snapshot()

func _continue_resolution() -> Dictionary:
    var phases := ["prepare", "damage", "zones"]
    while int(_pending_resolution.get("phase_index", 0)) < phases.size():
        var phase: String = phases[int(_pending_resolution["phase_index"])]
        var records: Array = _pending_resolution["records"]
        var synchronized: bool = bool(_pending_resolution["synchronized"])
        if not bool(_pending_resolution.get("phase_started", false)):
            var timing: String = ("sync_" if synchronized else "solo_") + phase
            var phase_has_entries := _enqueue_phase_records(records, phase, timing)
            if _pending_resolution.has("runtime_error"):
                var runtime_error := str(_pending_resolution["runtime_error"])
                for failed_record in records:
                    _passive_sources_by_token.erase(str(failed_record["token"]))
                _pending_resolution.clear()
                return {
                    "success": false,
                    "pending_choice": false,
                    "detail": runtime_error,
                }
            _pending_resolution["phase_started"] = true
            _pending_resolution["timing"] = timing
            _pending_resolution["phase_has_entries"] = phase_has_entries
            if phase == "damage" and synchronized:
                effect_ports.begin_synchronized_damage(records)
            if phase_has_entries:
                var results: Array = trigger_queue.process_timing(timing, effect_executor)
                _mark_failed_records(results)
                if trigger_queue.has_pending_choice():
                    return {
                        "success": false,
                        "pending_choice": true,
                        "choice_request": trigger_queue.pending_choice_snapshot(),
                        "detail": "等待功法目标选择",
                    }
        if phase == "damage":
            _resolve_played_card_anomalies(records)
            if synchronized:
                effect_ports.flush_synchronized_damage()
        _pending_resolution["phase_index"] = int(_pending_resolution["phase_index"]) + 1
        _pending_resolution["phase_started"] = false
        _pending_resolution.erase("timing")
        _pending_resolution.erase("phase_has_entries")
    _pending_resolution.clear()
    return {"success": true, "pending_choice": false, "detail": "行动效果结算完成"}

func _enqueue_phase_records(records: Array, phase: String, timing: String) -> bool:
    var phase_has_entries := false
    for record in records:
        if record["triggered"] \
                and not bool(record["momentum_prepared"]):
            _prepare_successful_technique_momentum(record)
        for source_spec in _action_trigger_sources(record):
            var source_effects: Array = source_spec.get(
                "effects", source_spec["definition"].get("effects", []))
            if source_spec.get("entity") != null:
                source_effects = source_spec["entity"].effects
            var effects := _effects_for_phase(source_effects, phase)
            if effects.is_empty():
                continue
            phase_has_entries = true
            var capture_key: String = source_spec["capture_key"]
            var captures_by_source: Dictionary = record["captures_by_source"]
            if not captures_by_source.has(capture_key):
                captures_by_source[capture_key] = {}
            var technique_pool := ""
            if source_spec["kind"] == "technique":
                technique_pool = str(source_spec["definition"].get("pool", ""))
            var context = EffectContextScript.new().configure({
                "ports": effect_ports,
                "actor": record["actor"],
                "target": record["target"],
                "hand_result": record["preview"]["hand"],
                "played_cards": record["preview"]["cards"],
                "group_snapshot": record["preview"].get("group_snapshot", {}),
                "power": record["preview"]["values"]["technique_value"],
                "values": record["preview"]["values"],
                "technique_id": source_spec["definition"].get("id", ""),
                "technique_name": source_spec["definition"].get("name", ""),
                "technique_pool": technique_pool,
                "action_token": record["token"],
                "source_kind": source_spec["kind"],
                "captures": captures_by_source[capture_key],
                "sequence_book": record["book"],
                "card_identity_policy": record["actor"].card_identity_policy,
            })
            trigger_queue.enqueue(
                timing,
                _source_settlement_label(source_spec),
                "%s%s" % [record["actor"].name, _source_kind_label(source_spec["kind"])],
                int(record["order"]) + int(source_spec["local_order"]),
                effects,
                context)
    return phase_has_entries

func _mark_failed_records(results: Array) -> void:
    for resolution in results:
        var result: Dictionary = resolution.get("result", {})
        if result.get("success", false) or result.get("pending_choice", false):
            continue
        var entry: Dictionary = resolution.get("entry", {})
        if entry.is_empty():
            continue
        var failed_context = EffectContextScript.coerce(entry.get("context"))
        if failed_context.source_kind != "technique":
            continue
        for record in _pending_resolution.get("records", []):
            if record["token"] == failed_context.action_token:
                record["failed"] = true
                record["triggered"] = false

func commit_staging_for(side, cards: Array = []) -> Dictionary:
    var committed: Array = (
        side.commit_staging()
        if cards.is_empty()
        else side.commit_selected_staging(cards))
    return {"committed": committed}

func commit_cooperation_staging(record, cooperation: Dictionary) -> Dictionary:
    var destination := str(cooperation.get("post_commit", {}).get("destination", "own_discard"))
    var cards: Array = record["preview"]["cards"]
    if destination != "target_draw_pile_top":
        return commit_staging_for(record["actor"], cards)
    var committed: Array = []
    for card in cards:
        var result: Dictionary = effect_ports.move_card(
            record["actor"], "staging", record["target"], "draw_pile", card,
            "cooperation_commit", "top")
        if result.get("success", false):
            committed.append(card)
    return {"committed": committed}

func retrigger_current_hand_technique(
        actor,
        target,
        sequence_book,
        power_snapshot: Dictionary,
        maximum_discard: int,
        excluded_technique_ids: Array) -> Dictionary:
    if effect_ports.technique_draw_count(actor) > 0:
        return {"success": true, "triggered": false, "detail": "本回合已有功法直接抽牌"}
    var recognition_options = null
    if actor.hand_recognition_policy != null:
        var options_result: Dictionary = actor.hand_recognition_policy.resolve_options(actor, {
            "owner": actor, "actor": actor, "target": target,
        })
        if not options_result.get("success", false):
            return {"success": false, "triggered": false, "detail": str(options_result.get("reason", "牌型识别查询失败"))}
        recognition_options = options_result.get("options")
    var best_candidates: Array = HandEvaluatorScript.evaluate_best_candidates(
        actor.hand, recognition_options, actor.card_identity_policy, {"owner": actor, "actor": actor, "target": target})
    if best_candidates.size() > 1:
        return {
            "success": false,
            "triggered": false,
            "detail": "整手存在多个并列最高牌型组，参与牌规则尚未确认",
        }
    var hand_result: Dictionary = best_candidates[0] if not best_candidates.is_empty() else {}
    var discarded: Array = effect_ports.discard_all(actor)
    if hand_result.is_empty() or hand_result.get("id", "") == "high_card" \
            or discarded.size() > maximum_discard:
        return {"success": true, "triggered": false, "detail": "整手弃牌后不满足重触条件"}
    var technique_id: String = sequence_book.current_id(str(hand_result["id"]))
    if technique_id == "" or excluded_technique_ids.has(technique_id):
        return {"success": true, "triggered": false, "detail": "当前功法为空或被禁止递归"}
    var definition = technique_repository.get_definition(technique_id)
    if definition == null:
        return {"success": false, "triggered": false, "detail": "重触功法不存在"}
    var condition: Dictionary = technique_repository.conditions_met(
        definition, hand_result, actor.card_identity_policy)
    if not condition.get("ok", false):
        return {"success": true, "triggered": false, "detail": condition.get("reason", "条件失败")}
    var activation := _query_additional_technique_activation(
        actor, target, technique_id, str(hand_result.get("id", "")),
        hand_result.get("contributing", []), "hand_retrigger")
    if not activation.get("success", false):
        return {
            "success": false, "triggered": false,
            "detail": activation.get("reason", "重触功法启动权限查询失败"),
        }
    if not activation.get("allowed", false):
        return {
            "success": true, "triggered": false,
            "detail": activation.get("reason", "重触功法启动被拒绝"),
            "technique_activation": activation,
        }
    var context = EffectContextScript.new().configure({
        "ports": effect_ports,
        "actor": actor,
        "target": target,
        "hand_result": hand_result,
        "played_cards": hand_result.get("contributing", []),
        "power": int(power_snapshot.get("technique_value", 0)),
        "values": power_snapshot,
        "technique_id": technique_id,
        "technique_name": definition.display_name,
        "technique_pool": definition.pool,
        "source_kind": "technique_retrigger",
        "sequence_book": sequence_book,
        "captures": {},
        "group_snapshot": power_snapshot.get("group_snapshot", {}),
        "card_identity_policy": actor.card_identity_policy,
    })
    var result: Dictionary = effect_executor.execute_all(definition.effects, context)
    if result.get("pending_choice", false):
        return {"success": false, "triggered": false, "detail": "回合末重触正在等待目标选择"}
    if not result.get("success", false):
        return {"success": false, "triggered": false, "detail": result.get("detail", "重触失败")}
    return {
        "success": true,
        "triggered": true,
        "hand_id": str(hand_result["id"]),
        "technique_id": technique_id,
        "discarded": discarded.size(),
        "detail": "重触%s" % definition.display_name,
        "technique_activation": activation,
    }

func _query_additional_technique_activation(
        actor,
        target,
        technique_id: String,
        hand_id: String,
        cards: Array,
        source_kind: String) -> Dictionary:
    var permission = actor.battle_permission_service
    if permission == null:
        return {
            "success": true, "checked": true, "allowed": true,
            "reason": "", "source_breakdown": [], "errors": [],
        }
    var token := "%s:%s:%s:%s" % [
        str(actor.owner_id), source_kind, hand_id, technique_id]
    var result: Dictionary = permission.can_activate_technique(
        actor, technique_id, hand_id, {
            "target": target,
            "action_token": token,
            "card_instance_ids": cards.map(func(card): return str(card.id)),
            "source_kind": source_kind,
        })
    result["checked"] = true
    result["success"] = result.get("errors", []).is_empty()
    return result

func finish_action_record(record) -> void:
    if timing_system != null:
        var emitted: Dictionary = timing_system.emit_timing(timing_system.GROUP_END, {
            "round_number": int(record["turn_number"]),
            "actor": record["actor"],
            "actors": [record["actor"]],
            "record": record,
            "metadata": {
                "action_token": str(record["token"]),
                "hand_id": str(record["preview"]["hand"]["id"]),
            },
        })
        if not emitted.get("success", false):
            var detail := "战斗时点失败 hook=%s reason=%s" % [
                timing_system.GROUP_END,
                str(emitted.get("reason", "group_end 处理器失败")),
            ]
            _passive_sources_by_token.erase(str(record["token"]))
            if _set_scenario_error.is_valid():
                _set_scenario_error.call(detail)
        else:
            _emit_action_resolved(record)
        return
    _finish_action_record(record)
    _emit_action_resolved(record)

func _on_group_end(event) -> Dictionary:
    var record = event.context.get("record", null)
    if record == null:
        return {"success": false, "detail": "缺少行动记录"}
    _finish_action_record(record)
    return {
        "success": true,
        "detail": "%s·%s" % [
            record["actor"].name,
            record["preview"]["hand"]["name"]],
    }

func _finish_action_record(record) -> void:
    var action_preview: Dictionary = record["preview"]
    var technique: Dictionary = action_preview["technique"]
    var hand_id: String = action_preview["hand"]["id"]
    if record["triggered"]:
        record["actor"].last_successful_technique_hand_id = hand_id
        record["book"].advance(hand_id)
        trigger_queue.add_history(
            "group_end", "功法序列推进", "%s·%s" % [record["actor"].name, action_preview["hand"]["name"]],
            "成功", "下一门：%s" % _technique_name(record["book"].current_id(hand_id)))
    elif not technique.is_empty():
        trigger_queue.add_history(
            "group_end", "功法序列保持", "%s·%s" % [record["actor"].name, action_preview["hand"]["name"]], "未推进")
    _passive_sources_by_token.erase(str(record["token"]))

func _emit_action_resolved(record) -> void:
    if committed_event_service == null:
        return
    committed_event_service.commit("action_resolved", {
        "event_token": committed_event_service.make_token(
            "action_resolved", record["actor"], record["token"], record["token"]),
        "actor": record["actor"], "target": record["target"],
        "owner": record["actor"], "round_number": int(record["turn_number"]),
        "action_token": str(record["token"]),
        "technique_triggered": bool(record["triggered"]),
        "action_succeeded": not bool(record["failed"]),
        "metadata": {
            "hand_id": str(record["preview"]["hand"]["id"]),
            "staging_count_after": record["actor"].staging.size(),
            "sequence_position_after": record["book"].positions.get(
                str(record["preview"]["hand"]["id"]), 0),
        },
    })

func _power_query_fingerprints(action_preview: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for stage in action_preview.get("values", {}).get(
            "passive_power_queries", {}):
        result[stage] = str(action_preview["values"][
            "passive_power_queries"][stage].get("fingerprint", ""))
    return result

func log_calculation(side, action_preview: Dictionary, hide_values: bool = false) -> void:
    var hand_result: Dictionary = action_preview["hand"]
    var values: Dictionary = action_preview["values"]
    if hide_values:
        trigger_queue.add_history(
            "calculate", "%s·隐藏出招" % side.name, "牌型", "成功",
            "敌方牌型、牌张与功法值不公开")
        return
    trigger_queue.add_history(
        "calculate", "%s·%s" % [side.name, hand_result["name"]], "牌型", "成功",
        "基础值 %d｜牌型基准值 %d｜功法值 %d（不自动造成伤害）" % [
            values["base_value"], values["baseline_value"], values["technique_value"]])

func log_cards_leave(side, cards: Array) -> void:
    trigger_queue.add_history(
        "cards_leave_play", "%s打出真气离开待出区" % side.name, "规则", "成功",
        "%d 张进入弃牌堆并完成入堆响应" % cards.size())

func combat_order_labels(side, technique_name: String = "当前功法") -> Array[String]:
    var entries: Array = [{"order": side.technique_slot_index, "label": technique_name}]
    for inner_entry in passive_rule_runtime.equipped_inner_skill_entries({"owner": side}):
        var definition: Dictionary = inner_entry["definition"]
        entries.append({
            "order": inner_entry["source_order"],
            "label": definition.get("name", "未知内功"),
        })
    entries.sort_custom(func(left, right): return int(left["order"]) < int(right["order"]))
    var labels: Array[String] = []
    for entry in entries:
        labels.append(str(entry["label"]))
    return labels

func _effects_for_phase(effects: Array, phase: String) -> Array:
    var result: Array = []
    var prepare_ops := [
        "defense", "defense_from_noncontributing_qi",
        "add_momentum", "set_momentum", "set_reflection_percent",
        "set_reflection_until_turn_end",
        "steal_random_card_if_power_target_and_same_qi",
        "add_direct_power_fixed", "add_direct_power_percent"]
    var damage_ops := ["damage", "multi_damage"]
    for effect in effects:
        var explicit_phase: String = effect.get("phase", "")
        if explicit_phase != "":
            if explicit_phase == phase:
                result.append(effect)
            continue
        var op: String = effect.get("op", "")
        if phase == "prepare" and op in prepare_ops:
            result.append(effect)
        elif phase == "damage" and op in damage_ops:
            result.append(effect)
        elif phase == "zones" and not op in prepare_ops and not op in damage_ops:
            result.append(effect)
    return result

func _action_trigger_sources(record) -> Array:
    var sources: Array = []
    var actor = record["actor"]
    var technique: Dictionary = record["preview"]["technique"]
    if record["triggered"] and not technique.is_empty():
        var technique_entity = technique_repository.get_definition(
            str(technique.get("id", "")))
        sources.append({
            "kind": "technique",
            "definition": technique,
            "entity": technique_entity,
            "local_order": actor.technique_slot_index,
            "capture_key": "technique",
        })
    var action_token := str(record["token"])
    if not _passive_sources_by_token.has(action_token):
        var dispatched: Dictionary = passive_rule_runtime.dispatch_event(
            "action_resolve", {
                "actor": actor,
                "target": record["target"],
                "round_number": int(record["turn_number"]),
                "payload": {
                    "effect_context_values": {
                        "actor": actor,
                        "target": record["target"],
                        "hand_result": record["preview"]["hand"],
                        "played_cards": record["preview"]["cards"],
                        "power": record["preview"]["values"]["technique_value"],
                        "values": record["preview"]["values"],
                        "action_token": action_token,
                        "sequence_book": record["book"],
                    },
                },
            })
        var resolved_sources: Array = []
        if not dispatched.get("success", false):
            var detail := "被动规则结算计划失败：%s" % "；".join(
                dispatched.get("errors", []))
            _pending_resolution["runtime_error"] = detail
            trigger_queue.add_history(
                "passive_rule_error", "被动规则结算失败", actor.name,
                "失败", detail)
        else:
            for entry in dispatched.get("results", []):
                var effects = entry.get("result", {}).get("effects", [])
                if not effects is Array or effects.is_empty():
                    continue
                var source = entry["source"]
                var invocation = entry["invocation"]
                resolved_sources.append({
                    "kind": source.source_kind,
                    "definition": source.definition,
                    "local_order": source.source_order,
                    "capture_key": source.source_instance_key,
                    "effects": effects,
                    "execution_index": invocation.execution_index,
                    "execution_count": invocation.execution_count,
                })
        _passive_sources_by_token[action_token] = resolved_sources
    sources.append_array(_passive_sources_by_token[action_token])
    sources.sort_custom(func(left, right): return int(left["local_order"]) < int(right["local_order"]))
    return sources

func _source_kind_label(kind: String) -> String:
    if kind == "technique":
        return "功法"
    if kind == "item":
        return "物品"
    return "内功"

func _source_settlement_label(source_spec: Dictionary) -> String:
    var label := str(source_spec["definition"].get("name", "未命名效果"))
    var count := int(source_spec.get("execution_count", 1))
    if count > 1:
        label += "（%d/%d）" % [int(source_spec.get("execution_index", 0)) + 1, count]
    return label

func _resolve_played_card_anomalies(records: Array) -> void:
    for record in records:
        var holder = record["actor"]
        var played_ids: Dictionary = {}
        for card in record["preview"].get("cards", []):
            played_ids[str(card.id)] = true
        var played_cards: Array = holder.staging.filter(
            func(card): return played_ids.has(str(card.id)))
        var resolutions: Array = effect_ports.resolve_played_card_anomalies(
            holder,
            played_cards,
            {"action_token": str(record["token"])})
        var triggered_ids: Array = record["preview"].get(
            "group_snapshot", {}).get("on_play_success_cards", []).map(
                func(value): return str(value.id))
        for source_id in effect_ports.successful_on_play_ids(str(record["token"])):
            if not triggered_ids.has(str(source_id)):
                triggered_ids.append(str(source_id))
        for resolution in resolutions:
            var card = resolution["card"]
            var anomaly_name := str(resolution.get(
                "anomaly_name", resolution.get("anomaly_id", "真气异状")))
            var anomaly_damage := int(resolution.get("damage", 0))
            var anomaly_detail := str(resolution.get(
                "detail", "%d 点伤害" % anomaly_damage))
            trigger_queue.add_history(
                "card_anomaly_damage" if resolution.has("damage") else "card_anomaly_resolved",
                "%s·%s触发%s" % [holder.name, card.display_name(), anomaly_name],
                "真气异状",
                "结算",
                anomaly_detail)
            if str(resolution.get("source_trigger", "")) == "card_played" \
                    and bool(resolution.get("applied", resolution.get("success", false))):
                var source_id := str(resolution.get("source_card_instance_id", ""))
                if source_id != "" and not triggered_ids.has(source_id):
                    triggered_ids.append(source_id)
        var triggered_cards: Array = record["preview"].get(
            "group_snapshot", {}).get("played_cards", []).filter(
                func(value): return triggered_ids.has(str(value.id)))
        if record["preview"].get("group_snapshot") is Dictionary:
            record["preview"]["group_snapshot"]["on_play_success_cards"] = triggered_cards
func _technique_name(technique_id: String) -> String:
    return technique_repository.get_technique(technique_id).get("name", "空序列")

func _prepare_successful_technique_momentum(record) -> void:
    record["momentum_prepared"] = true
    var actor = record["actor"]
    var hand_id := str(record["preview"]["hand"]["id"])
    if actor.last_successful_technique_hand_id != hand_id:
        actor.set_momentum(0)
