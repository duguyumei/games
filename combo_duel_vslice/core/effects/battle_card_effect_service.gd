class_name BattleCardEffectService
extends RefCounted

const EffectTargetQueryScript = preload(
    "res://core/effects/effect_target_query.gd")
const BattleRuntimeMutationTransactionScript = preload(
    "res://core/battle_runtime_mutation_transaction.gd")

## BattleEffectPorts 内部的牌区、真气实例、异状与临时重塑服务。
##
## 所有牌区写入继续由 BattleSide 已装配的 CardZoneService 完成；本服务只负责
## 跨牌区编排、统一随机选择、真气状态窄接口和战斗临时重塑。效果处理器仍只
## 面向 BattleEffectPorts，且本服务不持有 CombatEngine 或 Facade 反向引用。

var _status_system
var _sides: Array = []
var _battle_rng: RandomNumberGenerator
var _card_reshape_runtime_ref: WeakRef
var _battle_permission_service
var _trigger_queue
var _committed_event_service


func _init(status_system) -> void:
    assert(status_system != null, "BattleCardEffectService requires StatusSystem")
    _status_system = status_system


func use_sides(first, second) -> void:
    assert(first != null and second != null,
        "BattleCardEffectService requires both battle sides")
    _sides = [first, second]


func use_battle_rng(rng: RandomNumberGenerator) -> void:
    assert(rng != null, "BattleCardEffectService requires the battle RNG")
    _battle_rng = rng


func use_trigger_queue(trigger_queue) -> void:
    _trigger_queue = trigger_queue


func use_committed_event_service(service) -> void:
    _committed_event_service = service


func use_card_reshape_runtime(runtime) -> void:
    assert(runtime != null, "BattleCardEffectService requires CardReshapeBattleRuntime")
    _card_reshape_runtime_ref = weakref(runtime)


func use_battle_permission_service(service) -> void:
    assert(service != null,
        "BattleCardEffectService requires BattlePermissionService")
    _battle_permission_service = service


func card_reshape_runtime():
    return (
        _card_reshape_runtime_ref.get_ref()
        if _card_reshape_runtime_ref != null else null)


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


func side_holding_card(card, zone: String):
    for side in _sides:
        if zone_cards(side, zone).has(card):
            return side
    return null


func generate_temporary_normal_card(side, source, options: Dictionary = {}):
    assert(_battle_rng != null, "BattleCardEffectService battle RNG is not assembled")
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
            card, "mark", "void", {}, "临时真气", 1, false, {
                "holder": side, "actor": side,
                "source_kind": "rule", "source_id": "temporary_card",
                "source_name": "临时真气",
                "source_instance_key": "rule:temporary_card",
                "trigger_mode": "direct",
            })
        if not applied.get("success", false):
            return null
    var added: Dictionary = side.card_zone_service.add_generated(
        side, card, "hand", true)
    return card if added.get("success", false) else null


func steal_random_normal_card(
        actor, target, source_metadata: Dictionary = {}) -> Dictionary:
    assert(_battle_rng != null, "BattleCardEffectService battle RNG is not assembled")
    if actor == null or target == null:
        return {"success": false}
    var candidates: Array = target.card_zone_service.zone(
        target, "draw_pile").filter(
            func(card): return card.is_card_kind("normal"))
    if candidates.is_empty():
        return {"success": false}
    var card = candidates[_battle_rng.randi_range(0, candidates.size() - 1)]
    return move_card(
        target, "draw_pile", actor, "hand", card, "steal", "top",
        source_metadata)


func recover_forest_priority(
        actor,
        maximum_qi: int,
        prefer_permanent: bool,
        source_metadata: Dictionary = {}) -> Dictionary:
    assert(_battle_rng != null, "BattleCardEffectService battle RNG is not assembled")
    if actor == null:
        return {"success": false}
    var plain: Array = []
    var reshaped: Array = []
    for card in actor.card_zone_service.zone(actor, "discard_pile"):
        if not card.is_card_kind("normal") \
                or current_effective_qi(actor, card) > maximum_qi:
            continue
        var permanent: bool = not card.reshape_origin.is_empty() \
            or card.reshape_enhancement != "" or card.reshape_imprint != "" \
            or not card.reshape_others.is_empty()
        (reshaped if permanent else plain).append(card)
    var candidates: Array = (
        reshaped if prefer_permanent and not reshaped.is_empty() else plain)
    if candidates.is_empty():
        return {"success": false}
    var card = candidates[_battle_rng.randi_range(0, candidates.size() - 1)]
    return move_card(
        actor, "discard_pile", actor, "hand", card, "recover", "top",
        source_metadata)


func burn_deck_then_heat_hand(
        actor, bottom_first: bool, choice_capture: String, context) -> Dictionary:
    assert(_battle_rng != null, "BattleCardEffectService battle RNG is not assembled")
    var candidates: Array = actor.card_zone_service.zone(
        actor, "draw_pile").filter(func(card):
            return card.is_card_kind("normal") and not card.is_attribute("fire") \
                and can_apply_card_anomaly(
                    card, "mark", "burned_out").get("allowed", false))
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
            apply_card_anomaly(
                heat_targets[0], "buff", "qi_heat", {}, "引火式", layers)
    return {"success": true, "detail": "燃尽并施加炽气"}


func place_on_draw_pile_top(side, card) -> Dictionary:
    return side.card_zone_service.place_on_draw_pile_top(side, card)


func temporarily_remove_card(
        side,
        instance_id: String,
        reason: String,
        source_metadata: Dictionary = {}) -> Dictionary:
    if reason == "cost":
        var options := source_metadata.duplicate(true)
        options["minimum_count"] = 1
        options["exact_count"] = 1
        var prepared := prepare_qi_consumption(
            side, [instance_id], options)
        if not prepared.get("success", false):
            return prepared
        return commit_qi_consumption(prepared, source_metadata)
    return side.card_zone_service.temporarily_remove(
        side, instance_id, reason, source_metadata)


func prepare_qi_consumption(
        side,
        targets: Array,
        options: Dictionary = {}) -> Dictionary:
    if side == null or not _sides.has(side):
        return {"success": false, "reason": "真气消耗持有者不属于当前战斗"}
    var operation_token := str(options.get("operation_token", ""))
    var exact_count := int(options.get("exact_count", -1))
    var minimum_count := maxi(0, int(options.get("minimum_count", 0)))
    if exact_count >= 0 and targets.size() != exact_count:
        return {"success": false, "reason": "真气消耗目标数量不符合精确支付要求"}
    if targets.size() < minimum_count:
        return {"success": false, "reason": "真气消耗目标不足最低支付数量"}
    if targets.is_empty():
        return {"success": false, "reason": "真气消耗目标不能为空"}
    var entries: Array = []
    var seen: Dictionary = {}
    for target_value in targets:
        var requested_id := ""
        var requested_card = null
        if target_value is Dictionary:
            requested_card = target_value.get("card")
            requested_id = str(target_value.get(
                "card_instance_id", target_value.get("instance_id", "")))
        elif target_value is Object:
            requested_card = target_value
            requested_id = str(target_value.id)
        else:
            requested_id = str(target_value)
        if requested_id == "" and requested_card != null:
            requested_id = str(requested_card.id)
        if requested_id == "" or seen.has(requested_id):
            return {"success": false, "reason": "真气消耗目标包含重复或空实例 ID"}
        seen[requested_id] = true
        entries.append({
            "card": requested_card,
            "card_instance_id": requested_id,
        })
    if operation_token == "":
        operation_token = _default_consumption_operation_token(
            side, entries, options)
    if side.qi_consumption_receipts.has(
            operation_token):
        var requested_ids: Array = entries.map(func(entry):
            return str(entry["card_instance_id"]))
        var receipt_ids: Array = side.qi_consumption_receipts[
            operation_token].get("card_instance_ids", [])
        if requested_ids != receipt_ids:
            return {
                "success": false,
                "reason": "真气消耗 operation token 已绑定另一批目标",
            }
        return _reused_consumption_plan(side, operation_token)
    for index in range(entries.size()):
        var entry: Dictionary = entries[index]
        var requested_card = entry.get("card")
        var requested_id := str(entry["card_instance_id"])
        var location: Dictionary = side.card_zone_service.find_active_location(
            side, requested_id)
        if location.is_empty() or requested_card != null \
                and location.get("card") != requested_card:
            return {"success": false, "reason": "找不到待消耗真气的冻结活动牌区"}
        var card = location["card"]
        var source_zone := str(location["zone"])
        var snapshot: Dictionary = side.card_zone_service.capture_pre_move_snapshot(
            side, card, source_zone)
        if snapshot.is_empty():
            return {"success": false, "reason": "无法冻结待消耗真气的离场快照"}
        entry.merge({
            "card": card,
            "holder_id": str(side.owner_id),
            "from_zone": source_zone,
            "pre_move_snapshot": snapshot,
            "original_owner_id": str(card.original_owner_id) \
                if str(card.original_owner_id) != "" else str(side.owner_id),
            "temporary": bool(card.temporary_card),
            "input_index": index,
        }, true)
    if side.qi_consumption_receipts.has(operation_token):
        return _reused_consumption_plan(side, operation_token)
    var batch_token := str(options.get(
        "consumption_batch_token", "%s:batch" % operation_token))
    return {
        "success": true,
        "reused": false,
        "holder": side,
        "holder_id": str(side.owner_id),
        "operation_token": operation_token,
        "consumption_batch_token": batch_token,
        "minimum_count": minimum_count,
        "exact_count": exact_count,
        "entries": entries,
        "card_instance_ids": entries.map(func(entry):
            return str(entry["card_instance_id"])),
    }


func _reused_consumption_plan(side, operation_token: String) -> Dictionary:
    var reused_receipt: Dictionary = side.qi_consumption_receipts[
        operation_token].duplicate(true)
    return {
        "success": true,
        "reused": true,
        "operation_token": operation_token,
        "consumption_batch_token": str(reused_receipt.get(
            "consumption_batch_token", "%s:batch" % operation_token)),
        "receipt": reused_receipt,
        "entries": [],
        "holder": side,
    }


func commit_qi_consumption(
        plan: Dictionary,
        source_metadata: Dictionary = {}) -> Dictionary:
    if not plan.get("success", false):
        return {"success": false, "reason": str(plan.get(
            "reason", "真气消耗计划无效"))}
    if plan.get("reused", false):
        var reused: Dictionary = plan.get("receipt", {}).duplicate(true)
        reused["success"] = true
        reused["reused"] = true
        return reused
    var holder = plan.get("holder")
    if holder == null or not _sides.has(holder):
        return {"success": false, "reason": "真气消耗计划持有者已失效"}
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        _sides, _committed_event_service, _trigger_queue, _battle_rng)
    var committed: Dictionary = holder.card_zone_service.commit_qi_consumption_entries(
        holder, plan, source_metadata)
    if not committed.get("success", false):
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        committed["rolled_back"] = true
        return committed
    BattleRuntimeMutationTransactionScript.commit(transaction)
    return committed


func _default_consumption_operation_token(
        side, entries: Array, options: Dictionary) -> String:
    var ids: Array[String] = []
    for entry in entries:
        ids.append(str(entry["card_instance_id"]))
    var action_token := str(options.get("action_token", ""))
    var source_key := str(options.get("source_instance_key", options.get(
        "source_id", "cost")))
    return "qi-cost|%s|%s|%s|%s" % [
        str(side.owner_id), action_token, source_key, ",".join(ids)]


func can_explicit_discard(side, card) -> Dictionary:
    assert(_battle_permission_service != null,
        "BattleCardEffectService permission service is not assembled")
    return _battle_permission_service.can_explicit_discard(side, card)


func finalize_reshape_action(side, preview: Dictionary) -> Dictionary:
    var runtime = card_reshape_runtime()
    if runtime == null:
        return {"success": true, "reused": false}
    return runtime.finalize_action_preview(side, preview)


func draw(side, count: int, source_metadata: Dictionary) -> Array:
    var source := source_metadata.duplicate(true)
    var draw_reason := str(source.get("draw_reason", "effect_draw"))
    source.erase("draw_reason")
    var drawn: Array = side.card_zone_service.draw(
        side, count, draw_reason, source)
    if str(source["source_kind"]) == "technique":
        _status_system.record_technique_card_flow(side, "draw", drawn.size())
    return drawn


func shuffle_zone(side, zone: String, rng: RandomNumberGenerator) -> void:
    side.card_zone_service.shuffle(
        side.card_zone_service.zone(side, zone), rng)


func current_effective_qi(side, card, query_context: Dictionary = {}) -> int:
    if side != null and side.battle_rule_query_service != null:
        var values := query_context.duplicate(false)
        values["actor"] = values.get("actor", side)
        values["purpose"] = str(values.get("purpose", "effect_value"))
        values["evaluation_mode"] = str(values.get(
            "evaluation_mode", "runtime"))
        var query = side.battle_rule_query_service.resolve_effective_qi(
            side, card, values)
        if query.success:
            return int(query.effective_value)
        side.battle_rule_query_service.report_failure(
            query, str(values.get("boundary", "battle_card_effect_service")))
        return 0
    return maxi(0, int(card.effective_qi_value()) \
        if card.has_method("effective_qi_value") else int(card.qi_value))


func discard_random(
        side,
        count: int,
        rng: RandomNumberGenerator,
        source_metadata: Dictionary = {}) -> Array:
    var discarded: Array = side.card_zone_service.random_discard(
        side, count, rng)
    if str(source_metadata["source_kind"]) == "technique":
        _status_system.record_technique_card_flow(
            side, "discard", discarded.size())
    return discarded


func discard_all(side, source_metadata: Dictionary = {}) -> Array:
    var discarded: Array = side.card_zone_service.discard_all(side)
    if str(source_metadata["source_kind"]) == "technique":
        _status_system.record_technique_card_flow(
            side, "discard", discarded.size())
    return discarded


func move_card(
        source_side,
        source_zone: String,
        target_side,
        destination_zone: String,
        card,
        reason: String = "effect",
        placement: String = "top",
        source_metadata: Dictionary = {}) -> Dictionary:
    var result: Dictionary
    if source_side == target_side:
        result = source_side.card_zone_service.move_card(
            source_side, source_zone, destination_zone, card, reason,
            source_metadata, placement)
    else:
        result = source_side.card_zone_service.temporarily_transfer(
            source_side, target_side, str(card.id), destination_zone, reason,
            source_metadata, placement)
    if result.get("success", false) \
            and str(source_metadata["source_kind"]) == "technique":
        if destination_zone == "hand" and reason == "draw":
            _status_system.record_technique_card_flow(target_side, "draw", 1)
        elif destination_zone == "discard_pile" and reason == "explicit_discard":
            _status_system.record_technique_card_flow(source_side, "discard", 1)
    return result


func move_cards_synchronously(
        records: Array, source_metadata: Dictionary = {}) -> Array:
    if records.is_empty():
        return []
    var first_side = records[0].get("side")
    if first_side == null:
        return []
    var sourced_records: Array = []
    for record_value in records:
        var sourced_record: Dictionary = record_value.duplicate(true)
        sourced_record["source_metadata"] = source_metadata.duplicate(true)
        sourced_records.append(sourced_record)
    var moved: Array = first_side.card_zone_service.move_cards_synchronously(
        sourced_records)
    for record in records:
        if str(source_metadata["source_kind"]) == "technique" \
                and moved.has(record.get("card")) \
                and str(record.get("reason", "")) == "explicit_discard":
            _status_system.record_technique_card_flow(
                record.get("side"), "discard", 1)
    return moved


func transfer_cards_atomically(
        records: Array, source_metadata: Dictionary = {}) -> Array:
    if records.is_empty():
        return []
    var first_side = records[0].get("source_side")
    if first_side == null:
        return []
    var sourced_records: Array = []
    for record_value in records:
        var sourced_record: Dictionary = record_value.duplicate(true)
        sourced_record["source_metadata"] = source_metadata.duplicate(true)
        sourced_records.append(sourced_record)
    return first_side.card_zone_service.temporarily_transfer_many(sourced_records)


func atomic_exchange_cards(
        actor_side, actor_zone: String, actor_card,
        target_side, target_zone: String, target_card,
        source_metadata: Dictionary = {}) -> Dictionary:
    return actor_side.card_zone_service.atomic_exchange(
        actor_side, actor_zone, actor_card,
        target_side, target_zone, target_card,
        source_metadata)


func zone_cards(side, zone: String) -> Array:
    if zone not in side.card_zone_service.ACTIVE_ZONES:
        return []
    return side.card_zone_service.zone(side, zone).duplicate()


func query_effect_targets(
        context, query_spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    var values := query_spec.duplicate(true)
    values["card_identity_policy"] = context.card_identity_policy
    return EffectTargetQueryScript.new().configure(values).resolve(context, rng)


func transfer_card_anomaly(
        source_card,
        target_card,
        category: String,
        anomaly_id: String,
        source: String,
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.transfer_card_anomaly(
        source_card, target_card, category, anomaly_id, source, event_metadata)


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
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.set_card_anomaly_layers(
        card, category, anomaly_id, layers, source, event_metadata)


func apply_temporary_enhancement(
        card, enhancement_id: String, source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.apply_temporary_enhancement(
        card, enhancement_id, source, event_metadata)


func apply_temporary_attribute(
        card, attribute_id: String, source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.apply_temporary_attribute(
        card, attribute_id, source, event_metadata)


func apply_temporary_rank(
        card,
        rank_name: String,
        rank_order: int,
        base_qi: int,
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.apply_temporary_rank(
        card, rank_name, rank_order, base_qi, source, event_metadata)


func clear_temporary_reshape(
        card, subslot: String, source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.clear_temporary_reshape(
        card, subslot, source, event_metadata)


func clear_all_temporary_reshapes(
        card, source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.clear_all_temporary_reshapes(
        card, source, event_metadata)


func clear_card_anomalies(
        card, source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.clear_card_anomalies(card, source, event_metadata)


func resolve_played_card_anomalies(
        holder, cards: Array, source_values: Dictionary = {}) -> Array:
    return _status_system.resolve_played_card_anomalies(
        holder, cards, source_values)
