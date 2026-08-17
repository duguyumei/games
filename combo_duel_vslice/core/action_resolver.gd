class_name ActionResolver
extends RefCounted

const EffectContextScript = preload("res://core/effects/battle_effect_context.gd")
const BattleActionRecordScript = preload("res://core/battle_action_record.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const TechniquePhaseCatalogScript = preload(
    "res://core/effects/technique_phase_catalog.gd")

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
var technique_resolution_service

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
        event_service = null,
        resolution_service = null) -> void:
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
    technique_resolution_service = resolution_service
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

func resolve_post_commit_phase() -> Dictionary:
    if _pending_resolution.is_empty():
        return {"success": true, "pending_choice": false, "detail": "没有待提交后效果"}
    if not bool(_pending_resolution.get("awaiting_post_commit", false)):
        return {"success": false, "pending_choice": false, "detail": "行动尚未完成牌区提交"}
    _pending_resolution["phases"] = [TechniquePhaseCatalogScript.POST_COMMIT]
    _pending_resolution["phase_index"] = 0
    _pending_resolution["phase_started"] = false
    _pending_resolution["awaiting_post_commit"] = false
    _pending_resolution["post_commit_only"] = true
    return _continue_resolution()

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
    var formation_commit := {"success": true, "changed": false}
    if action_preview_service != null:
        formation_commit = action_preview_service.commit_power_formation(
            actor, action_preview)
        if not formation_commit.get("success", false):
            return formation_commit
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
                    "trigger_mode": "manual",
                    "root_action_token": action_token,
                    "invocation_token": "",
                    "caller_technique_id": "",
                    "slot_instance_id": str(action_preview.get("slot_instance_id", "")),
                    "manual_effect_suppressed": str(action_preview.get(
                        "technique", {}).get("manual_effect_mode", "normal")) == "advance_only",
                    "sequence_before": action_preview.get(
                        "sequence_before", []).duplicate(true),
                    "sequence_after": action_preview.get(
                        "sequence_before", []).duplicate(true),
                },
            })
        if not confirmed.get("success", false):
            if action_preview_service != null \
                    and formation_commit.get("changed", false):
                action_preview_service.rollback_power_formation(
                    actor, action_preview)
            return confirmed
    action_preview["passive_action_confirmed"] = true
    return {"success": true, "reused": false, "action_token": action_token}

func _freeze_technique_activation(
        actor,
        target,
        action_preview: Dictionary,
        _turn_number: int,
        action_token: String) -> Dictionary:
    var technique: Dictionary = action_preview.get("technique", {})
    var condition: Dictionary = action_preview.get("condition", {})
    var definition = technique_repository.get_definition(
        str(action_preview.get("technique_id", ""))) \
        if not technique.is_empty() else null
    var result: Dictionary = technique_resolution_service.prepare_activation(
        definition, actor, target, action_preview.get("hand", {}),
        action_preview.get("cards", []),
        str(action_preview.get("hand", {}).get("id", "")),
        action_token, "action_confirmed", true, condition,
        bool(action_preview.get("technique_slot", {}).get(
            "host_sequence_qualified", false)),
        _turn_number)
    if not result.get("success", false):
        return {
            "success": false,
            "reason": str(result.get("reason", "功法启动权限查询失败")),
        }
    result["frozen"] = true
    result["action_token"] = action_token
    action_preview["technique_activation"] = result
    return {"success": true, "permission": result}

func settle_same_qi_gain(
        actor,
        amount: int,
        source: String,
        token: String) -> Dictionary:
    return technique_resolution_service.settle_same_qi(
        actor, amount, source, token, true)

func resolve_action_records(records: Array, synchronized: bool) -> Dictionary:
    if not _pending_resolution.is_empty():
        return {
            "success": false,
            "pending_choice": true,
            "choice_request": trigger_queue.pending_choice_snapshot(),
            "detail": "已有行动正在等待选择",
        }
    for record in records:
        var snapshot: Dictionary = record["preview"].get("group_snapshot", {})
        snapshot["has_cooperation_group"] = not record.cooperation_groups.is_empty()
        snapshot["opposing_hand_id"] = ""
        snapshot["opposing_has_normal_attack"] = false
        if synchronized:
            for opposing in records:
                if opposing["actor"] != record["actor"]:
                    snapshot["opposing_hand_id"] = str(
                        opposing["preview"].get("hand", {}).get("id", ""))
                    snapshot["opposing_has_normal_attack"] = int(
                        opposing["preview"].get("intent", {}).get(
                            "normal_damage", 0)) > 0
                    break
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
        _prepare_successful_technique_momentum(record)
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
    var phases: Array = _pending_resolution.get(
        "phases", TechniquePhaseCatalogScript.pre_commit_phase_ids())
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
            if phase == TechniquePhaseCatalogScript.DAMAGE and synchronized:
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
        if phase == TechniquePhaseCatalogScript.DAMAGE:
            _resolve_played_card_anomalies(records)
            if synchronized:
                effect_ports.flush_synchronized_damage()
        _pending_resolution["phase_index"] = int(_pending_resolution["phase_index"]) + 1
        _pending_resolution["phase_started"] = false
        _pending_resolution.erase("timing")
        _pending_resolution.erase("phase_has_entries")
    if bool(_pending_resolution.get("post_commit_only", false)):
        _pending_resolution.clear()
        return {"success": true, "pending_choice": false, "detail": "提交后效果结算完成"}
    _pending_resolution["phases"] = phases
    _pending_resolution["awaiting_post_commit"] = true
    return {"success": true, "pending_choice": false, "detail": "行动效果结算完成"}

func _enqueue_phase_records(records: Array, phase: String, timing: String) -> bool:
    var phase_has_entries := false
    for record in records:
        for source_spec in _action_trigger_sources(record):
            var source_effects: Array = source_spec.get(
                "effects", source_spec["definition"].get("effects", []))
            if source_spec.get("entity") != null:
                source_effects = source_spec["entity"].effects
            var phase_result := TechniquePhaseCatalogScript.effects_for_phase(
                source_effects, phase, effect_executor.registry)
            if not phase_result.get("success", false):
                _pending_resolution["runtime_error"] = str(
                    phase_result.get("reason", "功法阶段解析失败"))
                return false
            var effects: Array = phase_result.get("effects", [])
            if effects.is_empty():
                continue
            phase_has_entries = true
            var capture_key: String = source_spec["capture_key"]
            var captures_by_source: Dictionary = record["captures_by_source"]
            if not captures_by_source.has(capture_key):
                captures_by_source[capture_key] = {}
            if source_spec["kind"] == "technique" \
                    and not record.cooperation_groups.is_empty():
                captures_by_source[capture_key]["cooperation_cards"] = record.cooperation_groups[0].get(
                    "preview", {}).get("cards", []).duplicate()
            var technique_pool := ""
            if source_spec["kind"] == "technique":
                technique_pool = str(source_spec["definition"].get("pool", ""))
            var source_instance_key := capture_key
            if source_spec["kind"] == "technique":
                source_instance_key = str(record["preview"].get(
                    "slot_instance_id", ""))
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
                "source_id": source_spec["definition"].get("id", ""),
                "source_name": source_spec["definition"].get("name", ""),
                "source_instance_key": source_instance_key,
                "captures": captures_by_source[capture_key],
                "sequence_book": record["book"],
                "slot_instance_id": str(record["preview"].get("slot_instance_id", "")),
                "root_action_token": str(record["token"]),
                "trigger_mode": "manual",
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

func commit_staging_for(
        side,
        cards: Array = [],
        source_metadata: Dictionary = {}) -> Dictionary:
    var committed: Array = (
        side.card_zone_service.commit_selected_staging(
            side, side.staging.duplicate(), source_metadata)
        if cards.is_empty()
        else side.commit_selected_staging(cards, source_metadata))
    return {"committed": committed}

func commit_cooperation_staging(record, cooperation: Dictionary) -> Dictionary:
    var destination := str(cooperation.get("post_commit", {}).get("destination", "own_discard"))
    var cards: Array = record["preview"]["cards"]
    if destination != "target_draw_pile_top":
        return commit_staging_for(record["actor"], cards, {
            "action_token": str(record["token"]),
        })
    var committed: Array = []
    for card in cards:
        var logical_hand_before: int = record["actor"].hand.size() \
            + record["actor"].staging.size()
        var result: Dictionary = effect_ports.move_card(
            record["actor"], "staging", record["target"], "draw_pile", card,
            "cooperation_commit", "top", {
                "action_token": str(record["token"]),
                "logical_from_zone": "hand",
                "hand_count_before": logical_hand_before,
                "hand_count_after": maxi(0, logical_hand_before - 1),
                "from_hand_count_before": logical_hand_before,
                "from_hand_count_after": maxi(0, logical_hand_before - 1),
                "from_zone_count_before": logical_hand_before,
                "from_zone_count_after": maxi(0, logical_hand_before - 1),
            })
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
    var retrigger_slot: Dictionary = sequence_book.current_slot(
        str(hand_result.get("id", "")))
    var condition: Dictionary = technique_repository.conditions_met(
        definition, hand_result, actor.card_identity_policy,
        bool(retrigger_slot.get("host_sequence_qualified", false)))
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
        "source_kind": "technique",
        "source_id": technique_id,
        "source_name": definition.display_name,
        "source_instance_key": str(retrigger_slot.get(
            "slot_instance_id", "technique:%s" % technique_id)),
        "slot_instance_id": str(retrigger_slot.get("slot_instance_id", "")),
        "trigger_mode": "retrigger",
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
        _settle_successful_technique_momentum(record)
        record["actor"].consume_pending_power_fixed_sources(
            action_preview.get("pending_power_fixed_tokens", []))
        record["actor"].last_successful_technique_hand_id = hand_id
        var completed: Dictionary = record["book"].complete_slot(
            hand_id, str(action_preview.get("slot_instance_id", "")))
        if not completed.get("success", false):
            record["failed"] = true
            trigger_queue.add_history(
                "group_end", "功法序列推进失败",
                "%s·%s" % [record["actor"].name, action_preview["hand"]["name"]],
                "失败", str(completed.get("reason", "冻结槽位不存在")))
            _passive_sources_by_token.erase(str(record["token"]))
            return
        trigger_queue.add_history(
            "group_end", "功法序列推进", "%s·%s" % [record["actor"].name, action_preview["hand"]["name"]],
            "成功", "下一门：%s" % _technique_name(record["book"].current_id(hand_id)))
        _emit_technique_succeeded(record)
        var deferred: Dictionary = effect_ports.resolve_after_caller_advance(
            str(record["token"]))
        if not deferred.get("success", false):
            record["failed"] = true
            trigger_queue.add_history(
                "group_end", "推进后功法调用失败", record["actor"].name,
                "失败", str(deferred.get("reason", "延后调用失败")))
    elif not technique.is_empty():
        trigger_queue.add_history(
            "group_end", "功法序列保持", "%s·%s" % [record["actor"].name, action_preview["hand"]["name"]], "未推进")
    _passive_sources_by_token.erase(str(record["token"]))

func _emit_technique_succeeded(record) -> void:
    if committed_event_service == null:
        return
    var preview: Dictionary = record["preview"]
    var technique: Dictionary = preview.get("technique", {})
    var values: Dictionary = preview.get("values", {})
    var serial := int(committed_event_service.next_serial())
    committed_event_service.commit("technique_succeeded", {
        "event_token": committed_event_service.make_token(
            "technique_succeeded", record["actor"], serial,
            str(record["token"])),
        "event_serial": serial,
        "actor": record["actor"], "target": record["target"],
        "owner": record["actor"], "round_number": int(record["turn_number"]),
        "action_token": str(record["token"]),
        "source_kind": "technique",
        "source_id": str(technique.get("id", "")),
        "source_name": str(technique.get("name", "")),
        "source_instance_key": str(preview.get("slot_instance_id", "")),
        "hand_id": str(preview.get("hand", {}).get("id", "")),
        "technique_id": str(technique.get("id", "")),
        "technique_pool": str(technique.get("pool", "")),
        "initial_power": int(values.get("initial_power", 0)),
        "technique_power": int(values.get("technique_value", 0)),
        "trigger_mode": "manual",
        "technique_triggered": true,
        "action_succeeded": true,
        "metadata": {
            "hand_id": str(preview.get("hand", {}).get("id", "")),
            "trigger_mode": "manual",
            "root_action_token": str(record["token"]),
            "invocation_token": "",
            "caller_technique_id": "",
            "slot_instance_id": str(preview.get("slot_instance_id", "")),
            "manual_effect_suppressed": str(technique.get(
                "manual_effect_mode", "normal")) == "advance_only",
            "sequence_before": preview.get(
                "sequence_before", []).duplicate(true),
            "sequence_after": record["book"].ordered_slots(
                str(preview.get("hand", {}).get("id", ""))),
        },
    })

func _emit_action_resolved(record) -> void:
    if committed_event_service == null:
        return
    var preview: Dictionary = record["preview"]
    var technique: Dictionary = preview.get("technique", {})
    var values: Dictionary = preview.get("values", {})
    committed_event_service.commit("action_resolved", {
        "event_token": committed_event_service.make_token(
            "action_resolved", record["actor"], record["token"], record["token"]),
        "actor": record["actor"], "target": record["target"],
        "owner": record["actor"], "round_number": int(record["turn_number"]),
        "action_token": str(record["token"]),
        "source_kind": "technique" if bool(record["triggered"]) else "rule",
        "source_id": str(technique.get("id", "")) \
            if bool(record["triggered"]) else "action",
        "source_name": str(technique.get("name", "")) \
            if bool(record["triggered"]) else "行动",
        "source_instance_key": str(preview.get("slot_instance_id", "")) \
            if bool(record["triggered"]) else "rule:action",
        "hand_id": str(preview.get("hand", {}).get("id", "")),
        "technique_id": str(technique.get("id", "")),
        "technique_pool": str(technique.get("pool", "")),
        "initial_power": int(values.get("initial_power", 0)),
        "technique_power": int(values.get("technique_value", 0)),
        "trigger_mode": "manual",
        "technique_triggered": bool(record["triggered"]),
        "action_succeeded": not bool(record["failed"]),
        "metadata": {
            "hand_id": str(preview["hand"]["id"]),
            "staging_count_after": record["actor"].staging.size(),
            "sequence_position_after": record["book"].positions.get(
                str(record["preview"]["hand"]["id"]), 0),
            "trigger_mode": "manual",
            "root_action_token": str(record["token"]),
            "invocation_token": "",
            "caller_technique_id": "",
            "slot_instance_id": str(record["preview"].get("slot_instance_id", "")),
            "manual_effect_suppressed": str(record["preview"].get(
                "technique", {}).get("manual_effect_mode", "normal")) == "advance_only",
            "sequence_before": record["preview"].get(
                "sequence_before", []).duplicate(true),
            "sequence_after": record["book"].ordered_slots(
                str(record["preview"]["hand"]["id"])),
        },
    })
    var deferred: Dictionary = effect_ports.resolve_technique_invocations_at_timing(
        "action_end", str(record["token"]))
    if not deferred.get("success", false) and _set_scenario_error.is_valid():
        _set_scenario_error.call(
            "行动结束功法调用失败：%s" % str(deferred.get(
                "reason", "等待选择尚未由行动层接管")))

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

func _action_trigger_sources(record) -> Array:
    var sources: Array = []
    var actor = record["actor"]
    var technique: Dictionary = record["preview"]["technique"]
    var suppress_manual_effects := str(technique.get(
        "manual_effect_mode", "normal")) == "advance_only"
    if record["triggered"] and not technique.is_empty() and not suppress_manual_effects:
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
    technique_resolution_service.prepare_manual_record(record)

func _settle_successful_technique_momentum(record) -> void:
    technique_resolution_service.settle_manual_record(record)
