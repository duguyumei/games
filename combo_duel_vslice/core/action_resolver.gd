class_name ActionResolver
extends RefCounted

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const BattleActionRecordScript = preload("res://core/battle_action_record.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")

var technique_repository
var inner_skill_repository
var trigger_queue
var effect_executor
var timing_system
var rng: RandomNumberGenerator
var effect_ports
var _pending_resolution: Dictionary = {}

var _recycle_after_play: Dictionary = {}

func _init(
        effect_ports_value,
        techniques,
        inner_skills,
        queue,
        executor,
        random_source: RandomNumberGenerator,
        battle_timing_system = null) -> void:
    effect_ports = effect_ports_value
    technique_repository = techniques
    inner_skill_repository = inner_skills
    trigger_queue = queue
    effect_executor = executor
    rng = random_source
    timing_system = battle_timing_system
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
    _recycle_after_play.clear()
    _pending_resolution.clear()

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
        for source_spec in _action_trigger_sources(record):
            var source_effects: Array = source_spec["definition"].get("effects", [])
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
                "power": record["preview"]["values"]["technique_value"],
                "technique_id": source_spec["definition"].get("id", ""),
                "technique_name": source_spec["definition"].get("name", ""),
                "technique_pool": technique_pool,
                "action_token": record["token"],
                "source_kind": source_spec["kind"],
                "captures": captures_by_source[capture_key],
                "sequence_book": record["book"],
            })
            trigger_queue.enqueue(
                timing,
                source_spec["definition"].get("name", "未命名效果"),
                "%s%s" % [record["actor"].name, "功法" if source_spec["kind"] == "technique" else "内功"],
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
    var side_recycles: Dictionary = _recycle_after_play.get(side.get_instance_id(), {})
    var result: Dictionary = (
        side.commit_staging_with_recycles(side_recycles, rng)
        if cards.is_empty()
        else side.commit_selected_staging_with_recycles(cards, side_recycles, rng))
    for card in result.get("committed", []):
        side_recycles.erase(card.id)
    if side_recycles.is_empty():
        _recycle_after_play.erase(side.get_instance_id())
    else:
        _recycle_after_play[side.get_instance_id()] = side_recycles
    return result

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
    return {"committed": committed, "recycled": []}

func register_played_return(
        side,
        played_cards: Array,
        contributing_cards: Array,
        count: int,
        destination: String,
        anomaly: String,
        enter_discard_first: bool,
        shuffle: bool) -> Dictionary:
    var candidates: Array = []
    for card in played_cards:
        if contributing_cards.has(card):
            candidates.append(card)
    for index in range(candidates.size() - 1, 0, -1):
        var other := rng.randi_range(0, index)
        var temporary = candidates[index]
        candidates[index] = candidates[other]
        candidates[other] = temporary
    var registered := mini(maxi(0, count), candidates.size())
    var side_id: int = int(side.get_instance_id())
    if not _recycle_after_play.has(side_id):
        _recycle_after_play[side_id] = {}
    for card in candidates.slice(0, registered):
        _recycle_after_play[side_id][card.id] = {
            "destination": destination,
            "anomaly": anomaly,
            "enter_discard_first": enter_discard_first,
            "shuffle": shuffle,
        }
    return {"success": true, "registered": registered}

func retrigger_current_hand_technique(
        actor,
        target,
        sequence_book,
        snapshot_power: int,
        maximum_discard: int,
        excluded_technique_ids: Array) -> Dictionary:
    if effect_ports.technique_draw_count(actor) > 0:
        return {"success": true, "triggered": false, "detail": "本回合已有功法直接抽牌"}
    var best_candidates: Array = HandEvaluatorScript.evaluate_best_candidates(actor.hand)
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
    var condition: Dictionary = technique_repository.conditions_met(definition, hand_result)
    if not condition.get("ok", false):
        return {"success": true, "triggered": false, "detail": condition.get("reason", "条件失败")}
    var context = EffectContextScript.new().configure({
        "ports": effect_ports,
        "actor": actor,
        "target": target,
        "hand_result": hand_result,
        "played_cards": hand_result.get("contributing", []),
        "power": snapshot_power,
        "technique_id": technique_id,
        "technique_name": definition.display_name,
        "technique_pool": definition.pool,
        "source_kind": "technique_retrigger",
        "sequence_book": sequence_book,
        "captures": {},
    })
    var result: Dictionary = effect_executor.execute_all(definition.effects, context)
    if result.get("pending_choice", false):
        return {"success": false, "triggered": false, "detail": "回合末重触正在等待目标选择"}
    if not result.get("success", false):
        return {"success": false, "triggered": false, "detail": result.get("detail", "重触失败")}
    sequence_book.advance(str(hand_result["id"]))
    return {
        "success": true,
        "triggered": true,
        "hand_id": str(hand_result["id"]),
        "technique_id": technique_id,
        "discarded": discarded.size(),
        "detail": "重触%s" % definition.display_name,
    }

func finish_action_record(record) -> void:
    if timing_system != null:
        timing_system.emit_timing(timing_system.GROUP_END, {
            "round_number": int(record["turn_number"]),
            "actor": record["actor"],
            "actors": [record["actor"]],
            "record": record,
            "metadata": {
                "action_token": str(record["token"]),
                "hand_id": str(record["preview"]["hand"]["id"]),
            },
        })
        return
    _finish_action_record(record)

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
        record["book"].advance(hand_id)
        trigger_queue.add_history(
            "group_end", "功法序列推进", "%s·%s" % [record["actor"].name, action_preview["hand"]["name"]],
            "成功", "下一门：%s" % _technique_name(record["book"].current_id(hand_id)))
    elif not technique.is_empty():
        trigger_queue.add_history(
            "group_end", "功法序列保持", "%s·%s" % [record["actor"].name, action_preview["hand"]["name"]], "未推进")

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

func log_cards_leave(side, cards: Array, recycled: Array = []) -> void:
    trigger_queue.add_history(
        "cards_leave_play", "%s打出真气离开待出区" % side.name, "规则", "成功",
        "%d 张；其中 %d 张因蛊印洗回牌库；这不视为弃掉" % [cards.size(), recycled.size()])

func combat_order_labels(side, technique_name: String = "当前功法") -> Array[String]:
    var entries: Array = [{"order": side.technique_slot_index, "label": technique_name}]
    for index in range(side.equipped_inner_skill_ids.size()):
        var definition: Dictionary = inner_skill_repository.get_inner_skill(side.equipped_inner_skill_ids[index])
        entries.append({
            "order": side.combat_source_order(index),
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
        "defense", "defense_from_noncontributing_qi", "add_stack", "add_target_stack",
        "register_attack_counter_delay"]
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
    for index in range(actor.equipped_inner_skill_ids.size()):
        var inner_skill_id: String = actor.equipped_inner_skill_ids[index]
        var inner_skill: Dictionary = inner_skill_repository.get_inner_skill(inner_skill_id)
        if inner_skill.is_empty() or inner_skill.get("timing", "") != "on_play_resolve":
            continue
        sources.append({
            "kind": "inner_skill",
            "definition": inner_skill,
            "local_order": actor.combat_source_order(index),
            "capture_key": "inner:%d:%s" % [index, inner_skill_id],
        })
    sources.sort_custom(func(left, right): return int(left["local_order"]) < int(right["local_order"]))
    return sources

func _resolve_played_card_anomalies(records: Array) -> void:
    for record in records:
        var holder = record["actor"]
        var resolutions: Array = effect_ports.resolve_played_card_anomalies(
            holder,
            holder.staging)
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
            if bool(resolution["recycle"]):
                var side_id: int = holder.get_instance_id()
                if not _recycle_after_play.has(side_id):
                    _recycle_after_play[side_id] = {}
                _recycle_after_play[side_id][card.id] = {
                    "category": str(resolution.get("recycle_category", "")),
                    "anomaly": str(resolution.get("recycle_anomaly_id", "")),
                }
                var recycle_status_name := str(resolution.get(
                    "recycle_status_name", "状态"))
                trigger_queue.add_history(
                    "card_anomaly_recycle",
                    "%s消耗 1 层%s" % [holder.name, recycle_status_name],
                    recycle_status_name,
                    "成功",
                    "%s续上%s，结算后洗回牌库" % [card.display_name(), anomaly_name])

func _technique_name(technique_id: String) -> String:
    return technique_repository.get_technique(technique_id).get("name", "空序列")
