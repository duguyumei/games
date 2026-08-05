class_name ActionResolver
extends RefCounted

var combat_port
var technique_repository
var inner_skill_repository
var trigger_queue
var effect_executor
var timing_system
var rng: RandomNumberGenerator

var _recycle_after_play: Dictionary = {}

func _init(
        combat_port_value,
        techniques,
        inner_skills,
        queue,
        executor,
        random_source: RandomNumberGenerator,
        battle_timing_system = null) -> void:
    combat_port = combat_port_value
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

func make_action_record(
        actor,
        target,
        action_preview: Dictionary,
        sequence_book,
        order: int,
        turn_number: int) -> Dictionary:
    return {
        "actor": actor,
        "target": target,
        "preview": action_preview,
        "book": sequence_book,
        "order": order,
        "triggered": false,
        "failed": false,
        "token": "%s-%d-%d" % [actor.name, turn_number, order],
        "captures_by_source": {},
    }

func resolve_action_records(records: Array, synchronized: bool) -> void:
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

    for phase in ["prepare", "damage", "zones"]:
        var timing: String = ("sync_" if synchronized else "solo_") + phase
        var phase_has_entries := false
        for record in records:
            for source_spec in _action_trigger_sources(record):
                var effects := _effects_for_phase(source_spec["definition"].get("effects", []), phase)
                if effects.is_empty():
                    continue
                phase_has_entries = true
                var capture_key: String = source_spec["capture_key"]
                var captures_by_source: Dictionary = record["captures_by_source"]
                if not captures_by_source.has(capture_key):
                    captures_by_source[capture_key] = {}
                var context := {
                    "engine": combat_port,
                    "actor": record["actor"],
                    "target": record["target"],
                    "hand_result": record["preview"]["hand"],
                    "played_cards": record["preview"]["cards"],
                    "power": record["preview"]["values"]["technique_value"],
                    "technique_id": source_spec["definition"].get("id", ""),
                    "technique_name": source_spec["definition"].get("name", ""),
                    "action_token": record["token"],
                    "source_kind": source_spec["kind"],
                    "captures": captures_by_source[capture_key],
                }
                trigger_queue.enqueue(
                    timing,
                    source_spec["definition"].get("name", "未命名效果"),
                    "%s%s" % [record["actor"].name, "功法" if source_spec["kind"] == "technique" else "内功"],
                    int(record["order"]) + int(source_spec["local_order"]),
                    effects,
                    context)
        if not phase_has_entries and phase != "damage":
            continue
        if phase == "damage" and synchronized:
            combat_port.begin_synchronized_damage(records)
        var results: Array = trigger_queue.process_timing(timing, effect_executor) if phase_has_entries else []
        for resolution in results:
            if resolution["result"].get("success", false):
                continue
            var failed_context: Dictionary = resolution["entry"]["context"]
            if failed_context.get("source_kind", "") != "technique":
                continue
            var token: String = failed_context.get("action_token", "")
            for record in records:
                if record["token"] == token:
                    record["failed"] = true
                    record["triggered"] = false
        if phase == "damage":
            _resolve_played_card_anomalies(records)
        if phase == "damage" and synchronized:
            combat_port.flush_synchronized_damage()

func commit_staging_for(side) -> Dictionary:
    var side_recycles: Dictionary = _recycle_after_play.get(side.get_instance_id(), {})
    var result: Dictionary = side.commit_staging_with_recycles(side_recycles, rng)
    _recycle_after_play.erase(side.get_instance_id())
    return result

func finish_action_record(record: Dictionary) -> void:
    if timing_system != null:
        timing_system.emit_timing(timing_system.GROUP_END, {
            "round_number": int(combat_port.turn_number),
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
    var record: Dictionary = event.context.get("record", {})
    if record.is_empty():
        return {"success": false, "detail": "缺少行动记录"}
    _finish_action_record(record)
    return {
        "success": true,
        "detail": "%s·%s" % [
            record["actor"].name,
            record["preview"]["hand"]["name"]],
    }

func _finish_action_record(record: Dictionary) -> void:
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

func _action_trigger_sources(record: Dictionary) -> Array:
    var sources: Array = []
    var actor = record["actor"]
    var technique: Dictionary = record["preview"]["technique"]
    if record["triggered"] and not technique.is_empty():
        sources.append({
            "kind": "technique",
            "definition": technique,
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
        var resolutions: Array = combat_port.status_system.resolve_played_card_anomalies(
            holder,
            holder.staging)
        for resolution in resolutions:
            var card = resolution["card"]
            var poison_damage := int(resolution["damage"])
            trigger_queue.add_history(
                "card_anomaly_damage", "%s·%s触发烈毒" % [holder.name, card.display_name()],
                "真气异状", "结算", "%d 点伤害" % poison_damage)
            if bool(resolution["recycle"]):
                var side_id: int = holder.get_instance_id()
                if not _recycle_after_play.has(side_id):
                    _recycle_after_play[side_id] = {}
                _recycle_after_play[side_id][card.id] = {
                    "category": "poison",
                    "anomaly": "lethal_poison",
                }
                trigger_queue.add_history(
                    "gu_mark_consume", "%s消耗 1 层蛊印" % holder.name,
                    "蛊印", "成功", "%s续上烈毒，结算后洗回牌库" % card.display_name())

func _technique_name(technique_id: String) -> String:
    return technique_repository.get_technique(technique_id).get("name", "空序列")
