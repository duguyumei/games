class_name BattleSourceResourceEffectService
extends RefCounted

const SourceMarkerAddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")
const BattleRuntimeMutationTransactionScript = preload(
    "res://core/battle_runtime_mutation_transaction.gd")

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]

## BattleEffectPorts 内部的来源标识与来源化战斗资源写入服务。
##
## 本服务集中维护来源 marker、连势、同气槽、直接功法值修正，以及反震／格挡／
## 邀战来源的建立和公开变化事件。伤害如何读取、消费这些来源仍由
## BattleSurvivalEffectService 负责；行动窗口只通过三个窄 Callable 接入。

var _status_system
var _trigger_queue
var _same_qi_gauge_service
var _committed_event_service
var _round_number_reader: Callable
var _current_action_window_id_reader: Callable
var _can_bind_current_source_reader: Callable
var _close_source_binding_window: Callable
var _battle_instance_id: String = "battle-0"
var _technique_repository_ref: WeakRef
var _sides: Array = []
var _rng: RandomNumberGenerator
var _marker_address_resolver = SourceMarkerAddressResolverScript.new()


func _init(
        status_system,
        trigger_queue,
        current_action_window_id_reader: Callable,
        can_bind_current_source_reader: Callable,
        close_source_binding_window: Callable) -> void:
    assert(status_system != null,
        "BattleSourceResourceEffectService requires StatusSystem")
    assert(trigger_queue != null,
        "BattleSourceResourceEffectService requires VisibleTriggerQueue")
    assert(current_action_window_id_reader.is_valid(),
        "BattleSourceResourceEffectService requires action-window reader")
    assert(can_bind_current_source_reader.is_valid(),
        "BattleSourceResourceEffectService requires source-binding reader")
    assert(close_source_binding_window.is_valid(),
        "BattleSourceResourceEffectService requires source-binding closer")
    _status_system = status_system
    _trigger_queue = trigger_queue
    _current_action_window_id_reader = current_action_window_id_reader
    _can_bind_current_source_reader = can_bind_current_source_reader
    _close_source_binding_window = close_source_binding_window


func use_trigger_queue(trigger_queue) -> void:
    assert(trigger_queue != null,
        "BattleSourceResourceEffectService requires VisibleTriggerQueue")
    _trigger_queue = trigger_queue


func use_sides(sides: Array) -> void:
    _sides = sides.duplicate()


func use_battle_rng(rng: RandomNumberGenerator) -> void:
    _rng = rng


func use_technique_repository(repository) -> void:
    _technique_repository_ref = weakref(repository) if repository != null else null


func use_passive_battle_services(
        event_service,
        round_reader: Callable = Callable()) -> void:
    _committed_event_service = event_service
    _round_number_reader = round_reader


func use_same_qi_gauge_service(service) -> void:
    assert(service != null,
        "BattleSourceResourceEffectService requires SameQiGaugeService")
    _same_qi_gauge_service = service


func use_battle_instance_id(value: String) -> void:
    _battle_instance_id = value if value != "" else "battle-0"


func battle_instance_id() -> String:
    return _battle_instance_id


func same_qi_projection(
        side: BattleSide,
        amount: int,
        context: Dictionary = {}) -> Dictionary:
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
        _add_history(
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
        _commit_same_qi_gain(side, response, str(response["action_token"]))
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
        _add_history(
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
        _commit_same_qi_gain(side, response, resolved_action_token)
        if result.get("changed", false) and _committed_event_service != null:
            var CapabilityScript = preload(
                "res://core/passives/battle_passive_capability_implementations.gd")
            CapabilityScript.emit_battle_resource_changed(
                _committed_event_service,
                side,
                "same_qi",
                operation,
                int(result.get("same_qi_before", 0)),
                int(result.get("same_qi_after", 0)),
                int(result.get("same_qi_after", 0)) - int(result.get("same_qi_before", 0)),
                resolved_action_token,
                source_category,
                "",
                {"round_number": _round_number()})
    return result


func same_qi_receipts_for_action(
        side: BattleSide,
        action_token: String) -> Array:
    if _same_qi_gauge_service == null:
        return []
    return _same_qi_gauge_service.receipts_for_action(side, action_token)


func close_current_source_binding_window() -> void:
    _close_source_binding_window.call()


func write_source_marker(
        side: BattleSide,
        source: Dictionary,
        operation: String,
        amount: int,
        action_token: String = "") -> Dictionary:
    if side == null:
        return {"success": false, "reason": "来源标识写入缺少持有者"}
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        _transaction_sides(side), _committed_event_service, _trigger_queue, _rng)
    var result: Dictionary = side.source_marker_store.write(
        str(source.get("source_kind", "")),
        str(source.get("source_instance_key", "")),
        str(source.get("content_id", "")),
        str(source.get("marker_id", "")),
        str(source.get("scope", "battle")), operation, amount, source)
    if not result.get("success", false):
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        return result
    if result.get("changed", false):
        var emitted := _emit_source_marker_changed(
            side, source, str(source.get("reported_operation", operation)),
            result, action_token)
        if not emitted.get("success", false):
            BattleRuntimeMutationTransactionScript.rollback(transaction)
            return {
                "success": false,
                "reason": str(emitted.get(
                    "reason", "来源标识变化事件提交失败")),
                "rolled_back": true,
            }
        if str(source.get("scope", "battle")) == "run" \
                and str(source.get("contributes_to", "")) != "":
            side.recalculate_effective_max_life()
    BattleRuntimeMutationTransactionScript.commit(transaction)
    return result


func transfer_source_marker(
        side: BattleSide,
        source: Dictionary,
        target: Dictionary,
        amount: int,
        action_token: String = "") -> Dictionary:
    if side == null:
        return {"success": false, "reason": "来源标识转移缺少持有者"}
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        _transaction_sides(side), _committed_event_service, _trigger_queue, _rng)
    var result: Dictionary = side.source_marker_store.transfer(source, target, amount)
    if not result.get("success", false):
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        return result
    if int(result.get("transferred", 0)) > 0:
        var removed_event := _emit_source_marker_changed(
            side, source, "transfer_out", result.get("source", {}), action_token)
        var added_event := _emit_source_marker_changed(
            side, target, "transfer_in", result.get("target", {}), action_token)
        if not removed_event.get("success", false) \
                or not added_event.get("success", false):
            BattleRuntimeMutationTransactionScript.rollback(transaction)
            return {
                "success": false,
                "reason": str(removed_event.get("reason", added_event.get(
                    "reason", "来源标识转移事件提交失败"))),
                "rolled_back": true,
            }
        if str(source.get("scope", "battle")) == "run" \
                or str(target.get("scope", "battle")) == "run":
            side.recalculate_effective_max_life()
    BattleRuntimeMutationTransactionScript.commit(transaction)
    return result


func append_source_marker_records(
        side: BattleSide,
        source: Dictionary,
        records: Array,
        action_token: String = "") -> Dictionary:
    if side == null:
        return {"success": false, "reason": "来源标识记录写入缺少持有者"}
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        _transaction_sides(side), _committed_event_service, _trigger_queue, _rng)
    var result: Dictionary = side.source_marker_store.append_records(
        str(source.get("source_kind", "")),
        str(source.get("source_instance_key", "")),
        str(source.get("content_id", "")),
        str(source.get("marker_id", "")),
        str(source.get("scope", "battle")),
        records,
        source)
    if not result.get("success", false):
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        return result
    if result.get("changed", false):
        var emitted := _emit_source_marker_changed(
            side, source, "append_records", result, action_token)
        if not emitted.get("success", false):
            BattleRuntimeMutationTransactionScript.rollback(transaction)
            return {"success": false, "reason": emitted.get(
                "reason", "来源标识记录事件提交失败"), "rolled_back": true}
    BattleRuntimeMutationTransactionScript.commit(transaction)
    return result


func consume_source_marker_records(
        side: BattleSide,
        source: Dictionary,
        count: int,
        action_token: String = "") -> Dictionary:
    if side == null:
        return {"success": false, "reason": "来源标识记录消费缺少持有者"}
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        _transaction_sides(side), _committed_event_service, _trigger_queue, _rng)
    var result: Dictionary = side.source_marker_store.consume_records(
        str(source.get("source_kind", "")),
        str(source.get("source_instance_key", "")),
        str(source.get("marker_id", "")),
        str(source.get("scope", "battle")),
        count)
    if not result.get("success", false):
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        return result
    if result.get("changed", false):
        var emitted := _emit_source_marker_changed(
            side, source, "consume_records", result, action_token)
        if not emitted.get("success", false):
            BattleRuntimeMutationTransactionScript.rollback(transaction)
            return {"success": false, "reason": emitted.get(
                "reason", "来源标识记录事件提交失败"), "rolled_back": true}
    BattleRuntimeMutationTransactionScript.commit(transaction)
    return result


func consume_matching_source_marker_records(
        side: BattleSide,
        source: Dictionary,
        record_filters: Dictionary,
        count: int = -1,
        action_token: String = "") -> Dictionary:
    if side == null:
        return {"success": false, "reason": "来源标识过滤消费缺少持有者"}
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        _transaction_sides(side), _committed_event_service, _trigger_queue, _rng)
    var result: Dictionary = side.source_marker_store.consume_matching_records(
        str(source.get("source_kind", "")),
        str(source.get("source_instance_key", "")),
        str(source.get("marker_id", "")),
        str(source.get("scope", "battle")),
        record_filters,
        count,
        bool(source.get("remove_zero", false)))
    if not result.get("success", false):
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        return result
    if result.get("changed", false):
        var emitted := _emit_source_marker_changed(
            side, source, "consume_matching_records", result, action_token)
        if not emitted.get("success", false):
            BattleRuntimeMutationTransactionScript.rollback(transaction)
            return {"success": false, "reason": emitted.get(
                "reason", "来源标识过滤消费事件提交失败"), "rolled_back": true}
    BattleRuntimeMutationTransactionScript.commit(transaction)
    return result


## 只读枚举以功法序列簿为槽位事实源，以主要 marker 的真实存在作为活跃事实。
## 返回顺序固定为精确牌型权威顺序，再按各牌型当前槽位顺序。
func charging_technique_instances(
        side: BattleSide, public_only: bool = false) -> Array:
    if side == null or side.technique_sequence_book == null:
        return []
    var repository = _technique_repository()
    if repository == null:
        return []
    var result: Array = []
    for hand_id in HAND_IDS:
        for slot_value in side.technique_sequence_book.ordered_slots(hand_id):
            var slot: Dictionary = slot_value
            var contract := _charging_contract_for_slot(repository, slot)
            if not contract.get("success", false):
                continue
            var charging: Dictionary = contract["charging"]
            if public_only and not bool(charging.get("public", true)):
                continue
            var address: Dictionary = contract["address"]
            var entry := _marker_entry(side, address)
            if entry.is_empty():
                continue
            result.append({
                "hand_id": hand_id,
                "slot_instance_id": str(slot.get("slot_instance_id", "")),
                "technique_id": str(slot.get("technique_id", "")),
                "technique_name": str(contract.get("technique_name", "")),
                "temporary": bool(slot.get("temporary", false)),
                "origin_technique_id": str(slot.get(
                    "origin_technique_id", "")),
                "origin_slot_instance_id": str(slot.get(
                    "origin_slot_instance_id", "")),
                "primary_marker_id": str(charging["primary_marker_id"]),
                "display_name": str(charging["display_name"]),
                "current_value": int(entry.get("value", 0)),
                "minimum": int(charging["minimum"]),
                "maximum": charging.get("maximum"),
                "allowed_operations": charging[
                    "allowed_operations"].duplicate(),
                "source_instance_key": str(address["source_instance_key"]),
                "marker_entry": entry.duplicate(true),
            })
    return result.duplicate(true)


func technique_charging_state(
        side: BattleSide, slot_instance_id: String) -> Dictionary:
    var resolved := _resolve_charging_slot(side, slot_instance_id)
    if not resolved.get("success", false):
        return resolved
    var entry := _marker_entry(side, resolved["address"])
    return {
        "success": true,
        "active": not entry.is_empty(),
        "slot": resolved["slot"].duplicate(true),
        "charging": resolved["charging"].duplicate(true),
        "address": resolved["address"].duplicate(true),
        "current_value": int(entry.get("value", 0)),
        "marker_entry": entry.duplicate(true),
    }


func is_technique_charging(
        side: BattleSide, slot_instance_id: String) -> bool:
    var state := technique_charging_state(side, slot_instance_id)
    return state.get("success", false) and state.get("active", false)


func begin_technique_charging(
        side: BattleSide,
        slot_instance_id: String,
        initial_value: int = 0,
        action_token: String = "") -> Dictionary:
    var state := technique_charging_state(side, slot_instance_id)
    if not state.get("success", false):
        return state
    if state.get("active", false):
        return {
            "success": true,
            "already_active": true,
            "changed": false,
            "created": false,
            "removed": false,
            "before": int(state.get("current_value", 0)),
            "after": int(state.get("current_value", 0)),
            "requested_amount": initial_value,
            "actual_delta": 0,
            "slot_instance_id": slot_instance_id,
        }
    var charging: Dictionary = state["charging"]
    var bounded := _bounded_charging_value(initial_value, charging)
    var source: Dictionary = state["address"].duplicate(true)
    source.merge({
        "requested_amount": initial_value,
        "actual_delta": bounded,
        "reported_operation": "begin",
    }, true)
    var result := write_source_marker(
        side, source, "set", bounded, action_token)
    if not result.get("success", false):
        return result
    result["already_active"] = false
    result["requested_amount"] = initial_value
    result["actual_delta"] = int(result.get("delta", 0))
    result["slot_instance_id"] = slot_instance_id
    return result


func write_charging_primary_value(
        side: BattleSide,
        slot_instance_id: String,
        operation: String,
        amount: int,
        action_token: String = "") -> Dictionary:
    var state := technique_charging_state(side, slot_instance_id)
    if not state.get("success", false):
        return state
    if not state.get("active", false):
        return {"success": false, "reason": "功法实例尚未开始蓄力"}
    var charging: Dictionary = state["charging"]
    if operation not in charging["allowed_operations"]:
        return {
            "success": false,
            "reason": "主要蓄力值不允许操作：%s" % operation,
        }
    if operation in ["add", "subtract"] and amount < 0:
        return {"success": false, "reason": "主要蓄力值增减量不得为负数"}
    var before := int(state.get("current_value", 0))
    var desired := before
    match operation:
        "add":
            desired = before + amount
        "subtract":
            desired = before - maxi(0, amount)
        "set":
            desired = amount
        "clear":
            desired = 0
        _:
            return {"success": false, "reason": "未知主要蓄力值操作"}
    if operation != "clear":
        desired = _bounded_charging_value(desired, charging)
    var source: Dictionary = state["address"].duplicate(true)
    source.merge({
        "requested_amount": amount,
        "actual_delta": desired - before,
        "reported_operation": operation,
    }, true)
    var storage_operation := "clear" if operation == "clear" else "set"
    var result := write_source_marker(
        side, source, storage_operation, desired, action_token)
    if not result.get("success", false):
        return result
    result["requested_amount"] = amount
    result["actual_delta"] = int(result.get("delta", 0))
    result["slot_instance_id"] = slot_instance_id
    return result


func end_technique_charging(
        side: BattleSide,
        slot_instance_id: String,
        action_token: String = "") -> Dictionary:
    var state := technique_charging_state(side, slot_instance_id)
    if not state.get("success", false):
        return state
    if not state.get("active", false):
        return {
            "success": true,
            "changed": false,
            "removed": false,
            "final_value": 0,
            "slot_instance_id": slot_instance_id,
        }
    if "clear" not in state["charging"]["allowed_operations"]:
        return {"success": false, "reason": "主要蓄力值不允许 clear"}
    var final_value := int(state.get("current_value", 0))
    var result := write_charging_primary_value(
        side, slot_instance_id, "clear", 0, action_token)
    if result.get("success", false):
        result["final_value"] = final_value
    return result


func write_all_charging_primary_values(
        side: BattleSide,
        operation: String,
        amount: int,
        action_token: String = "",
        frozen_slot_instance_ids: Array = []) -> Dictionary:
    if side == null:
        return {"success": false, "reason": "批量主要蓄力值写入缺少持有者"}
    var frozen_instances := charging_technique_instances(side, false)
    if not frozen_slot_instance_ids.is_empty():
        var requested: Dictionary = {}
        for slot_id_value in frozen_slot_instance_ids:
            var slot_id := str(slot_id_value)
            if slot_id == "" or requested.has(slot_id):
                return {"success": false, "reason": "冻结蓄力槽位身份无效或重复"}
            requested[slot_id] = true
        frozen_instances = frozen_instances.filter(func(entry):
            return requested.has(str(entry.get("slot_instance_id", ""))))
        if frozen_instances.size() != requested.size():
            return {"success": false, "reason": "冻结的蓄力功法实例已经失效"}
    var frozen_ids: Array = frozen_instances.map(
        func(entry): return str(entry.get("slot_instance_id", "")))
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        _transaction_sides(side), _committed_event_service, _trigger_queue, _rng)
    var results: Array = []
    for slot_id_value in frozen_ids:
        var written := write_charging_primary_value(
            side, str(slot_id_value), operation, amount, action_token)
        if not written.get("success", false):
            BattleRuntimeMutationTransactionScript.rollback(transaction)
            return {
                "success": false,
                "reason": str(written.get("reason", "批量主要蓄力值写入失败")),
                "rolled_back": true,
                "frozen_slot_instance_ids": frozen_ids.duplicate(),
                "results": results.duplicate(true),
            }
        results.append(written.duplicate(true))
    BattleRuntimeMutationTransactionScript.commit(transaction)
    return {
        "success": true,
        "frozen_slot_instance_ids": frozen_ids.duplicate(),
        "target_count": frozen_ids.size(),
        "results": results.duplicate(true),
    }


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
    var result := side.write_momentum(
        operation, amount, source_category, action_token, source_id)
    if result.get("success", false) and result.get("changed", false) \
            and _committed_event_service != null:
        var CapabilityScript = preload(
            "res://core/passives/battle_passive_capability_implementations.gd")
        CapabilityScript.emit_battle_resource_changed(
            _committed_event_service,
            side,
            "momentum",
            operation,
            int(result.get("before", 0)),
            int(result.get("after", 0)),
            int(result.get("delta", 0)),
            action_token,
            source_category,
            source_id,
            {"round_number": _round_number()})
    return result


func set_reflection_percent(
        side: BattleSide,
        value: int,
        source_token: String = "") -> int:
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
        var target_owner_id := str(target_side.owner_id) \
            if target_side != null else ""
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
    var emitted := _emit_source_state_changed(
        "block_source_changed", side, record, "established")
    if not emitted.get("success", false):
        side.block_sources.erase(record)
        return {"success": false, "reason": emitted.get(
            "reason", "格挡来源建立事件失败")}
    return {"success": true, "record": record, "source_token": record["source_token"]}


func grant_deflection_source(
        side: BattleSide,
        target_side: BattleSide,
        threshold: int,
        label: String,
        source_token: String = "",
        metadata: Dictionary = {}) -> Dictionary:
    if side == null:
        return {"success": false, "reason": "卸力来源缺少持有者"}
    if threshold < 0:
        return {"success": false, "reason": "卸力阈值不得小于0"}
    var target_owner_id := str(target_side.owner_id) \
        if target_side != null else ""
    var window_id := _current_action_window_id() \
        if _can_bind_current_source(target_owner_id) else ""
    var record := side.add_deflection_source(
        threshold, source_token, target_owner_id, window_id,
        label, true, metadata)
    var emitted := _emit_source_state_changed(
        "block_source_changed", side, record, "established")
    if not emitted.get("success", false):
        side.block_sources.erase(record)
        return {"success": false, "reason": emitted.get(
            "reason", "卸力来源建立事件失败")}
    return {
        "success": true,
        "record": record,
        "source_token": str(record.get("source_token", "")),
    }


func register_challenge(
        context,
        threshold: int,
        effects: Array,
        label: String = "邀战",
        met_effects: Array = []) -> Dictionary:
    var runtime = context
    var token: String = str(runtime.actor.next_combat_source_token("challenge"))
    var target_owner_id := str(runtime.target.owner_id) \
        if runtime.target != null else ""
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
        "source_kind": runtime.source_kind,
        "source_id": runtime.source_id,
        "source_name": runtime.source_name,
        "source_instance_key": runtime.source_instance_key,
        "trigger_mode": runtime.trigger_mode,
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


func _commit_same_qi_gain(
        side: BattleSide,
        response: Dictionary,
        action_token: String) -> void:
    if _committed_event_service != null:
        var serial := int(_committed_event_service.next_serial())
        response["event_serial"] = serial
        response["event_token"] = _committed_event_service.make_token(
            "same_qi_gain_resolved", side, serial, action_token)
        _committed_event_service.commit("same_qi_gain_resolved", response)
    else:
        _status_system.handle_response_event("same_qi_gain_resolved", response)


func _emit_source_marker_changed(
        side: BattleSide,
        source: Dictionary,
        operation: String,
        result: Dictionary,
        action_token: String) -> Dictionary:
    var values := source.duplicate(true)
    values.merge({
        "actor": side, "owner": side, "holder": side,
        "operation": operation, "before": int(result.get("before", 0)),
        "after": int(result.get("after", 0)),
        "delta": int(result.get("delta", 0)),
        "consumed": int(result.get("consumed", 0)),
        "created": bool(result.get("created", false)),
        "removed": bool(result.get("removed", false)),
        "existed_before": bool(result.get("existed_before", false)),
        "exists_after": bool(result.get("exists_after", false)),
        "changed": bool(result.get("changed", false)),
        "action_token": action_token, "round_number": _round_number(),
    }, true)
    if _committed_event_service != null:
        var serial := int(_committed_event_service.next_serial())
        values["event_serial"] = serial
        values["event_token"] = _committed_event_service.make_token(
            "source_marker_changed", side, serial, action_token)
        return _committed_event_service.commit("source_marker_changed", values)
    else:
        _status_system.handle_response_event("source_marker_changed", values)
        return {"success": true, "receipt": {}}


func _emit_source_state_changed(
        event_kind: String,
        side: BattleSide,
        record: Dictionary,
        change: String,
        payload: Dictionary = {}) -> Dictionary:
    if _committed_event_service == null:
        return {"success": true, "receipt": {}}
    var serial: int = int(_committed_event_service.next_serial())
    return _committed_event_service.commit(event_kind, {
        "event_token": _committed_event_service.make_token(
            event_kind, side, serial, str(record.get("source_token", ""))),
        "event_serial": serial,
        "actor": side, "owner": side,
        "target": record.get("target"),
        "round_number": _round_number(),
        "action_token": str(record.get("action_token", "")),
        "source_kind": str(record.get("source_kind", event_kind)),
        "source_id": str(record.get("source_id", "")),
        "source_name": str(record.get("source_name", record.get(
            "label", ""))),
        "source_instance_key": str(record.get("source_instance_key", "")),
        "trigger_mode": str(record.get("trigger_mode", "direct")),
        "source_token": str(record.get("source_token", "")),
        "cancel_kind": str(record.get("cancel_kind", "block")),
        "threshold": int(record.get("threshold", 0)),
        "established_order": int(record.get("established_order", 0)),
        "window_id": str(record.get("window_id", "")),
        "waiting_for_action": bool(record.get("waiting_for_action", false)),
        "change": change,
        "payload": payload.duplicate(true),
        "public_state": record.duplicate(true),
    })


func _current_action_window_id() -> String:
    return str(_current_action_window_id_reader.call())


func _can_bind_current_source(target_owner_id: String) -> bool:
    return bool(_can_bind_current_source_reader.call(target_owner_id))


func _round_number() -> int:
    return int(_round_number_reader.call()) if _round_number_reader.is_valid() else 0


func _transaction_sides(primary) -> Array:
    var result: Array = []
    for side in _sides:
        if side != null and not result.has(side):
            result.append(side)
    if primary != null and not result.has(primary):
        result.append(primary)
    return result


func _technique_repository():
    return _technique_repository_ref.get_ref() \
        if _technique_repository_ref != null else null


func _resolve_charging_slot(
        side: BattleSide, slot_instance_id: String) -> Dictionary:
    if side == null or side.technique_sequence_book == null:
        return {"success": false, "reason": "参战者缺少功法序列簿"}
    if slot_instance_id == "":
        return {"success": false, "reason": "主要蓄力值缺少 slot_instance_id"}
    var slot: Dictionary = {}
    for slot_value in side.technique_sequence_book.find_slots({}):
        if str(slot_value.get("slot_instance_id", "")) == slot_instance_id:
            slot = slot_value.duplicate(true)
            break
    if slot.is_empty():
        return {"success": false, "reason": "实际功法槽位不存在"}
    var repository = _technique_repository()
    if repository == null:
        return {"success": false, "reason": "主要蓄力值缺少功法仓库"}
    var contract := _charging_contract_for_slot(repository, slot)
    if not contract.get("success", false):
        return contract
    contract["slot"] = slot
    return contract


func _charging_contract_for_slot(repository, slot: Dictionary) -> Dictionary:
    var technique_id := str(slot.get("technique_id", ""))
    var definition = repository.get_definition(technique_id)
    if definition == null:
        return {"success": false, "reason": "未知功法：%s" % technique_id}
    var raw: Dictionary = definition.charging.duplicate(true)
    if raw.is_empty():
        return {"success": false, "reason": "功法没有声明主要蓄力值"}
    var charging := {
        "primary_marker_id": str(raw.get("primary_marker_id", "")),
        "display_name": str(raw.get(
            "display_name", raw.get("primary_marker_id", ""))),
        "scope": str(raw.get("scope", "battle")),
        "public": bool(raw.get("public", true)),
        "allowed_operations": raw.get("allowed_operations", [
            "add", "subtract", "set", "clear"]).duplicate(),
        "minimum": int(raw.get("minimum", 0)),
    }
    if raw.has("maximum"):
        charging["maximum"] = int(raw["maximum"])
    if charging["primary_marker_id"] == "" \
            or charging["scope"] != "battle" \
            or not charging["public"]:
        return {"success": false, "reason": "主要蓄力值声明无效"}
    var operations: Array = charging["allowed_operations"]
    var seen_operations: Dictionary = {}
    for operation_value in operations:
        var operation := str(operation_value)
        if operation not in ["add", "subtract", "set", "clear"] \
                or seen_operations.has(operation):
            return {"success": false, "reason": "主要蓄力值操作声明无效"}
        seen_operations[operation] = true
    if charging.has("maximum") and int(charging["maximum"]) \
            < int(charging["minimum"]):
        return {"success": false, "reason": "主要蓄力值上下限无效"}
    var marker_definition: Dictionary = {}
    for marker_value in definition.marker_definitions:
        if marker_value is Dictionary and str(marker_value.get(
                "id", "")) == str(charging["primary_marker_id"]):
            marker_definition = marker_value
            break
    if marker_definition.is_empty() \
            or str(marker_definition.get("scope", "battle")) != "battle" \
            or not bool(marker_definition.get("public", true)):
        return {"success": false, "reason": "主要蓄力 marker 声明无效"}
    var address := _marker_address_resolver.resolve_charging_for_slot(
        charging, slot)
    if not address.get("success", false):
        return address
    return {
        "success": true,
        "charging": charging,
        "address": address,
        "technique_name": str(definition.display_name),
    }


func _marker_entry(side: BattleSide, address: Dictionary) -> Dictionary:
    var entries := side.source_marker_store.entries({
        "source_kind": str(address.get("source_kind", "")),
        "source_instance_key": str(address.get("source_instance_key", "")),
        "content_id": str(address.get("content_id", "")),
        "marker_id": str(address.get("marker_id", "")),
        "scope": str(address.get("scope", "battle")),
    })
    return entries[0].duplicate(true) if not entries.is_empty() else {}


func _bounded_charging_value(value: int, charging: Dictionary) -> int:
    var bounded := maxi(int(charging.get("minimum", 0)), value)
    if charging.has("maximum"):
        bounded = mini(bounded, int(charging["maximum"]))
    return bounded


func _add_history(
        timing: String,
        label: String,
        source: String,
        result: String,
        detail: String = "") -> void:
    _trigger_queue.add_history(timing, label, source, result, detail)
