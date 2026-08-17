class_name TechniqueSequenceBook
extends RefCounted

const DATA_PATH := "res://data/vertical_slice_sequences.json"
const SLOT_SCHEMA_VERSION := 2

var _slots_by_hand: Dictionary = {}
var _initial_slots_by_hand: Dictionary = {}
var _slot_capacity_by_hand: Dictionary = {}
var _initial_slot_capacity_by_hand: Dictionary = {}
var _current_slot_ids: Dictionary = {}
var _insertion_serial: int = 0

## Legacy read/write projections. Slot state remains the only source of truth.
var sequences: Dictionary:
    get:
        return _legacy_sequences()
    set(value):
        configure(value)

var positions: Dictionary:
    get:
        return _legacy_positions()
    set(value):
        _apply_legacy_positions(value)


func load_from_file(path: String = DATA_PATH) -> bool:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        push_error("功法序列数据无法解析：%s" % path)
        return false
    configure(parsed)
    return true


## 旧配置入口没有容量信息：容量严格等于实际序列长度；显式空序列容量为 0。
func configure(values: Dictionary) -> void:
    var capacities: Dictionary = {}
    for hand_id_value in values:
        if values[hand_id_value] is Array:
            capacities[str(hand_id_value)] = values[hand_id_value].size()
    _configure_sequences(values, capacities)


## 玩家正式进度入口同时读取永久序列和明确容量，不用空实例表示空余容量。
func configure_hand_progression(values: Dictionary) -> void:
    var next: Dictionary = {}
    var capacities: Dictionary = {}
    for hand_id_value in _slots_by_hand:
        var hand_id := str(hand_id_value)
        var progression: Dictionary = values.get(hand_id, {})
        var sequence = progression.get("sequence", []) \
            if progression is Dictionary else []
        next[hand_id] = sequence.duplicate(true) if sequence is Array else []
        capacities[hand_id] = int(progression.get(
            "slot_count", next[hand_id].size())) \
            if progression is Dictionary else next[hand_id].size()
    for hand_id_value in values:
        var hand_id := str(hand_id_value)
        if next.has(hand_id):
            continue
        var progression: Dictionary = values[hand_id_value]
        var sequence = progression.get("sequence", []) \
            if progression is Dictionary else []
        next[hand_id] = sequence.duplicate(true) if sequence is Array else []
        capacities[hand_id] = int(progression.get(
            "slot_count", next[hand_id].size())) \
            if progression is Dictionary else next[hand_id].size()
    _configure_sequences(next, capacities)


## 供敌人和测试夹具显式提供容量；玩家正式进度仍须先经过配装策略。
func configure_with_capacities(values: Dictionary, capacities: Dictionary) -> void:
    _configure_sequences(values, capacities)


func reset() -> void:
    _slots_by_hand = _initial_slots_by_hand.duplicate(true)
    _slot_capacity_by_hand = _initial_slot_capacity_by_hand.duplicate(true)
    _current_slot_ids.clear()
    _insertion_serial = 0
    for hand_id in _slots_by_hand:
        _current_slot_ids[hand_id] = _first_slot_id(_slots_by_hand[hand_id])


func slot_capacity(hand_id: String) -> int:
    return int(_slot_capacity_by_hand.get(hand_id, 0))


func occupied_slot_count(hand_id: String) -> int:
    return _slots_by_hand.get(hand_id, []).size()


func permanent_slot_count(hand_id: String) -> int:
    var count := 0
    for slot_value in _slots_by_hand.get(hand_id, []):
        if not bool(slot_value.get("temporary", false)):
            count += 1
    return count


func temporary_slot_count(hand_id: String) -> int:
    return occupied_slot_count(hand_id) - permanent_slot_count(hand_id)


func remaining_slot_count(hand_id: String) -> int:
    return maxi(0, slot_capacity(hand_id) - occupied_slot_count(hand_id))


func slot_usage(hand_id: String) -> Dictionary:
    return {
        "capacity": slot_capacity(hand_id),
        "occupied": occupied_slot_count(hand_id),
        "permanent": permanent_slot_count(hand_id),
        "temporary": temporary_slot_count(hand_id),
        "remaining": remaining_slot_count(hand_id),
    }


func public_slot_usage_snapshot() -> Dictionary:
    var result: Dictionary = {}
    var hand_ids: Array = _slot_capacity_by_hand.keys()
    for hand_id_value in _slots_by_hand:
        if not hand_ids.has(hand_id_value):
            hand_ids.append(hand_id_value)
    hand_ids.sort()
    for hand_id_value in hand_ids:
        var hand_id := str(hand_id_value)
        result[hand_id] = slot_usage(hand_id)
    return result


## 容量修改与占用校验属于同一次领域提交；不会移动或重建任何实例。
func change_slot_capacity(
        hand_id: String,
        delta: int,
        metadata: Dictionary = {}) -> Dictionary:
    return set_slot_capacity(
        hand_id, slot_capacity(hand_id) + delta,
        metadata.merged({"requested_delta": delta}, false))


func set_slot_capacity(
        hand_id: String,
        new_capacity: int,
        metadata: Dictionary = {}) -> Dictionary:
    if not _slot_capacity_by_hand.has(hand_id) and not _slots_by_hand.has(hand_id):
        return {"success": false, "reason": "未知功法牌型：%s" % hand_id}
    var before := slot_capacity(hand_id)
    var occupied := occupied_slot_count(hand_id)
    var minimum := int(metadata.get("minimum_capacity", 0))
    var maximum := int(metadata.get("maximum_capacity", -1))
    if new_capacity < minimum:
        return {
            "success": false,
            "reason": "功法槽容量不能低于 %d" % minimum,
            "capacity_before": before,
        }
    if maximum >= 0 and new_capacity > maximum:
        return {
            "success": false,
            "reason": "功法槽容量不能高于 %d" % maximum,
            "capacity_before": before,
        }
    if new_capacity < occupied:
        return {
            "success": false,
            "reason": "新容量 %d 低于当前实际占用 %d" % [new_capacity, occupied],
            "capacity_before": before,
        }
    _slot_capacity_by_hand[hand_id] = new_capacity
    return {
        "success": true,
        "hand_id": hand_id,
        "capacity_before": before,
        "capacity_after": new_capacity,
        "requested_delta": int(metadata.get(
            "requested_delta", new_capacity - before)),
        "actual_delta": new_capacity - before,
        "changed": new_capacity != before,
        "occupied_count": occupied,
        "remaining_capacity": new_capacity - occupied,
    }


func current_slot(hand_id: String) -> Dictionary:
    var slots: Array = _slots_by_hand.get(hand_id, [])
    if slots.is_empty():
        return {}
    var current_id := str(_current_slot_ids.get(hand_id, ""))
    for slot_value in slots:
        var slot: Dictionary = slot_value
        if str(slot.get("slot_instance_id", "")) == current_id:
            return slot.duplicate(true)
    return slots[0].duplicate(true)


func next_slot(hand_id: String) -> Dictionary:
    var ordered := ordered_slots(hand_id)
    if ordered.size() < 2:
        return ordered[0].duplicate(true) if ordered.size() == 1 else {}
    return ordered[1].duplicate(true)


func ordered_slots(hand_id: String) -> Array:
    var slots: Array = _slots_by_hand.get(hand_id, [])
    if slots.is_empty():
        return []
    var start := _slot_index(slots, str(_current_slot_ids.get(hand_id, "")))
    if start < 0:
        start = 0
    var result: Array = []
    for offset in range(slots.size()):
        result.append(slots[(start + offset) % slots.size()].duplicate(true))
    return result


func public_ordered_slots(hand_id: String) -> Array:
    return ordered_slots(hand_id).map(func(slot): return {
        "slot_instance_id": str(slot.get("slot_instance_id", "")),
        "technique_id": str(slot.get("technique_id", "")),
        "hand_id": str(slot.get("hand_id", hand_id)),
        "temporary": bool(slot.get("temporary", false)),
        "host_sequence_qualified": bool(slot.get(
            "host_sequence_qualified", false)),
        "origin_technique_id": str(slot.get("origin_technique_id", "")),
        "origin_slot_instance_id": str(slot.get(
            "origin_slot_instance_id", "")),
        "insertion_serial": int(slot.get("insertion_serial", 0)),
        "insertion_position": int(slot.get("insertion_position", -1)),
        "insertion_mode": str(slot.get("insertion_mode", "permanent")),
        "marker_mode": str(slot.get("marker_mode", "independent")),
        "generation_batch_token": str(slot.get(
            "generation_batch_token", "")),
        "generator_source_kind": str(slot.get("generator_source_kind", "")),
        "generator_source_id": str(slot.get("generator_source_id", "")),
        "generator_source_instance_key": str(slot.get(
            "generator_source_instance_key", "")),
    })


func public_snapshot() -> Dictionary:
    var result: Dictionary = {}
    var hand_ids: Array = _slots_by_hand.keys()
    hand_ids.sort()
    for hand_id_value in hand_ids:
        var hand_id := str(hand_id_value)
        result[hand_id] = public_ordered_slots(hand_id)
    return result


func find_slots(filters: Dictionary = {}) -> Array:
    var result: Array = []
    var hand_filter := str(filters.get("hand_id", ""))
    var technique_filter := str(filters.get("technique_id", ""))
    var origin_filter := str(filters.get("origin_slot_instance_id", ""))
    var temporary_filter = filters.get("temporary", null)
    var hand_ids: Array = _slots_by_hand.keys()
    hand_ids.sort()
    for hand_id_value in hand_ids:
        var hand_id := str(hand_id_value)
        if hand_filter != "" and hand_filter != hand_id:
            continue
        for slot_value in ordered_slots(hand_id):
            var slot: Dictionary = slot_value
            if technique_filter != "" and str(slot.get(
                    "technique_id", "")) != technique_filter:
                continue
            if origin_filter != "" and str(slot.get(
                    "origin_slot_instance_id", "")) != origin_filter:
                continue
            if temporary_filter != null and bool(slot.get(
                    "temporary", false)) != bool(temporary_filter):
                continue
            result.append(slot)
    return result


func move_slot_to_current(hand_id: String, slot_instance_id: String) -> Dictionary:
    var before := ordered_slots(hand_id)
    var slots: Array = _slots_by_hand.get(hand_id, [])
    var target_index := _slot_index(slots, slot_instance_id)
    if target_index < 0:
        return {
            "success": false, "reason": "功法槽位不存在",
            "sequence_before": before,
        }
    var current_index := _slot_index(
        slots, str(_current_slot_ids.get(hand_id, "")))
    if current_index < 0:
        current_index = 0
    if target_index != current_index:
        var target: Dictionary = slots.pop_at(target_index)
        if target_index < current_index:
            current_index -= 1
        slots.insert(current_index, target)
        _slots_by_hand[hand_id] = slots
    _current_slot_ids[hand_id] = slot_instance_id
    return {
        "success": true,
        "slot": current_slot(hand_id),
        "sequence_before": before,
        "sequence_after": ordered_slots(hand_id),
    }


## 唯一临时功法批次提交入口。容量检查、随机位置确定、插入序号和状态修改
## 在同一调用内完成；调用方不能先查询剩余容量再绕过这里单独插入。
func commit_temporary_generation(
        requests: Array,
        batch_mode: String,
        rng: RandomNumberGenerator) -> Dictionary:
    if batch_mode not in ["partial", "atomic"]:
        return {"success": false, "reason": "未知临时功法批次模式"}
    var integrity := _validate_generation_requests(requests)
    if not integrity.get("success", false):
        return integrity
    var usage_before := _usage_for_requests(requests)
    if batch_mode == "atomic":
        var preflight := _atomic_generation_preflight(requests)
        if not preflight.get("success", false):
            return _generation_receipt(
                batch_mode, requests, [], preflight.get("attempts", []),
                usage_before, true)
    var generated: Array = []
    var attempts: Array = []
    var after_current_counts: Dictionary = {}
    for request_value in requests:
        var request: Dictionary = request_value
        var hand_id := str(request.get("hand_id", ""))
        var usage := slot_usage(hand_id)
        if int(usage["remaining"]) <= 0:
            attempts.append(_generation_attempt(
                request, false, "capacity_full", "", -1,
                int(usage["remaining"])))
            continue
        var slots: Array = _slots_by_hand[hand_id]
        var insertion_position := _generation_insertion_index(
            slots, hand_id, str(request.get("position", "after_current")),
            after_current_counts, rng)
        _insertion_serial += 1
        var technique_id := str(request.get("technique_id", ""))
        var slot_id := "battle-slot:%s:%06d:%s" % [
            hand_id, _insertion_serial, technique_id]
        var slot := {
            "slot_schema_version": SLOT_SCHEMA_VERSION,
            "slot_instance_id": slot_id,
            "technique_id": technique_id,
            "hand_id": hand_id,
            "temporary": true,
            "host_sequence_qualified": true,
            "origin_technique_id": str(request.get(
                "origin_technique_id", technique_id)),
            "origin_slot_instance_id": str(request.get(
                "origin_slot_instance_id", "")),
            "insertion_serial": _insertion_serial,
            "insertion_position": insertion_position,
            "insertion_mode": str(request.get("position", "after_current")),
            "marker_mode": str(request.get("marker_mode", "independent")),
            "generation_batch_token": str(request.get(
                "generation_batch_token", "")),
            "generator_source_kind": str(request.get(
                "generator_source_kind", "")),
            "generator_source_id": str(request.get(
                "generator_source_id", "")),
            "generator_source_instance_key": str(request.get(
                "generator_source_instance_key", "")),
        }
        slots.insert(insertion_position, slot)
        _slots_by_hand[hand_id] = slots
        if str(_current_slot_ids.get(hand_id, "")) == "":
            _current_slot_ids[hand_id] = slot_id
        var remaining := remaining_slot_count(hand_id)
        generated.append(slot.duplicate(true))
        attempts.append(_generation_attempt(
            request, true, "", slot_id, insertion_position, remaining))
    return _generation_receipt(
        batch_mode, requests, generated, attempts, usage_before, false)


## 战斗结束与 reset 之间的正式清理入口。若当前实例是临时实例，按清理前
## 可见顺序选择第一门仍存在的永久功法作为新当前位置。
func release_all_temporary_slots() -> Dictionary:
    var removed: Array = []
    var hand_ids: Array = _slots_by_hand.keys()
    hand_ids.sort()
    for hand_id_value in hand_ids:
        var hand_id := str(hand_id_value)
        var ordered_before := ordered_slots(hand_id)
        var current_id := str(_current_slot_ids.get(hand_id, ""))
        var current_was_temporary := false
        for slot_value in ordered_before:
            var slot: Dictionary = slot_value
            if str(slot.get("slot_instance_id", "")) == current_id:
                current_was_temporary = bool(slot.get("temporary", false))
                break
        var fallback_id := ""
        for slot_value in ordered_before:
            var slot: Dictionary = slot_value
            if not bool(slot.get("temporary", false)):
                fallback_id = str(slot.get("slot_instance_id", ""))
                break
        var remaining: Array = []
        for slot_value in _slots_by_hand[hand_id]:
            var slot: Dictionary = slot_value
            if bool(slot.get("temporary", false)):
                removed.append(slot.duplicate(true))
            else:
                remaining.append(slot)
        _slots_by_hand[hand_id] = remaining
        if current_was_temporary or _slot_index(remaining, current_id) < 0:
            _current_slot_ids[hand_id] = fallback_id
    return {
        "success": true,
        "removed_count": removed.size(),
        "removed_slots": removed,
        "slot_usage": public_slot_usage_snapshot(),
    }


func complete_slot(hand_id: String, expected_slot_instance_id: String) -> Dictionary:
    var before := ordered_slots(hand_id)
    var slots: Array = _slots_by_hand.get(hand_id, [])
    var completed_index := _slot_index(slots, expected_slot_instance_id)
    if completed_index < 0:
        return {
            "success": false, "reason": "冻结功法槽位不存在",
            "sequence_before": before,
        }
    if slots.size() == 1:
        _current_slot_ids[hand_id] = expected_slot_instance_id
    else:
        _current_slot_ids[hand_id] = str(slots[
            (completed_index + 1) % slots.size()].get("slot_instance_id", ""))
    return {
        "success": true,
        "completed_slot_instance_id": expected_slot_instance_id,
        "sequence_before": before,
        "sequence_after": ordered_slots(hand_id),
    }


func snapshot() -> Dictionary:
    return {
        "schema_version": SLOT_SCHEMA_VERSION,
        "slots_by_hand": _slots_by_hand.duplicate(true),
        "initial_slots_by_hand": _initial_slots_by_hand.duplicate(true),
        "slot_capacity_by_hand": _slot_capacity_by_hand.duplicate(true),
        "initial_slot_capacity_by_hand": (
            _initial_slot_capacity_by_hand.duplicate(true)),
        "current_slot_ids": _current_slot_ids.duplicate(true),
        "insertion_serial": _insertion_serial,
    }


func restore_snapshot(value: Dictionary) -> void:
    _slots_by_hand = value.get("slots_by_hand", {}).duplicate(true)
    _initial_slots_by_hand = value.get(
        "initial_slots_by_hand", _slots_by_hand).duplicate(true)
    if value.has("slot_capacity_by_hand"):
        _slot_capacity_by_hand = value["slot_capacity_by_hand"].duplicate(true)
    else:
        _slot_capacity_by_hand = _capacities_from_slots(_slots_by_hand)
    if value.has("initial_slot_capacity_by_hand"):
        _initial_slot_capacity_by_hand = value[
            "initial_slot_capacity_by_hand"].duplicate(true)
    else:
        _initial_slot_capacity_by_hand = _capacities_from_slots(
            _initial_slots_by_hand)
    _repair_capacities(_slot_capacity_by_hand, _slots_by_hand)
    _repair_capacities(
        _initial_slot_capacity_by_hand, _initial_slots_by_hand)
    _current_slot_ids = value.get("current_slot_ids", {}).duplicate(true)
    _insertion_serial = int(value.get("insertion_serial", 0))


func clone():
    var result = get_script().new()
    result.restore_snapshot(snapshot())
    return result


func current_id(hand_id: String) -> String:
    return str(current_slot(hand_id).get("technique_id", ""))


func next_id(hand_id: String) -> String:
    return str(next_slot(hand_id).get("technique_id", ""))


func advance(hand_id: String) -> void:
    var slot := current_slot(hand_id)
    if not slot.is_empty():
        complete_slot(hand_id, str(slot.get("slot_instance_id", "")))


func position(hand_id: String) -> int:
    return _slot_index(
        _slots_by_hand.get(hand_id, []),
        str(_current_slot_ids.get(hand_id, "")))


func _configure_sequences(values: Dictionary, capacities: Dictionary) -> void:
    _slots_by_hand.clear()
    _initial_slots_by_hand.clear()
    _slot_capacity_by_hand.clear()
    _initial_slot_capacity_by_hand.clear()
    _current_slot_ids.clear()
    _insertion_serial = 0
    for hand_id_value in values:
        var hand_id := str(hand_id_value)
        if hand_id == "version" or not values[hand_id_value] is Array:
            continue
        var slots: Array = []
        var index := 0
        for technique_id_value in values[hand_id_value]:
            var technique_id := str(technique_id_value)
            slots.append(_make_permanent_slot(hand_id, technique_id, index))
            index += 1
        var capacity := int(capacities.get(hand_id, slots.size()))
        if capacity < slots.size():
            push_error("%s 功法槽容量低于实际序列，按实际占用修复" % hand_id)
            capacity = slots.size()
        _slots_by_hand[hand_id] = slots
        _initial_slots_by_hand[hand_id] = slots.duplicate(true)
        _slot_capacity_by_hand[hand_id] = capacity
        _initial_slot_capacity_by_hand[hand_id] = capacity
        _current_slot_ids[hand_id] = _first_slot_id(slots)


func _make_permanent_slot(
        hand_id: String, technique_id: String, index: int) -> Dictionary:
    return {
        "slot_schema_version": SLOT_SCHEMA_VERSION,
        "slot_instance_id": "permanent-slot:%s:%04d:%s" % [
            hand_id, index, technique_id],
        "technique_id": technique_id,
        "hand_id": hand_id,
        "temporary": false,
        "host_sequence_qualified": false,
        "origin_technique_id": technique_id,
        "origin_slot_instance_id": "",
        "insertion_serial": index,
        "insertion_position": index,
        "insertion_mode": "permanent",
        "marker_mode": "independent",
        "generation_batch_token": "",
        "generator_source_kind": "",
        "generator_source_id": "",
        "generator_source_instance_key": "",
    }


func _validate_generation_requests(requests: Array) -> Dictionary:
    for request_value in requests:
        if not request_value is Dictionary:
            return {"success": false, "reason": "临时功法请求项必须是对象"}
        var request: Dictionary = request_value
        var hand_id := str(request.get("hand_id", ""))
        if hand_id == "" or not _slots_by_hand.has(hand_id) \
                or not _slot_capacity_by_hand.has(hand_id):
            return {"success": false, "reason": "未知临时功法宿主牌型：%s" % hand_id}
        if str(request.get("technique_id", "")) == "":
            return {"success": false, "reason": "临时功法请求缺少功法 ID"}
        if str(request.get("position", "after_current")) not in [
                "before_current", "after_current", "random"]:
            return {"success": false, "reason": "临时功法请求使用未知插入位置"}
        if occupied_slot_count(hand_id) > slot_capacity(hand_id):
            return {
                "success": false,
                "reason": "%s 功法槽占用超过容量，状态已经损坏" % hand_id,
            }
    return {"success": true}


func _atomic_generation_preflight(requests: Array) -> Dictionary:
    var requested_by_hand: Dictionary = {}
    for request_value in requests:
        var hand_id := str(request_value.get("hand_id", ""))
        requested_by_hand[hand_id] = int(requested_by_hand.get(hand_id, 0)) + 1
    var failed_hands: Dictionary = {}
    for hand_id_value in requested_by_hand:
        var hand_id := str(hand_id_value)
        if int(requested_by_hand[hand_id]) > remaining_slot_count(hand_id):
            failed_hands[hand_id] = true
    if failed_hands.is_empty():
        return {"success": true}
    var attempts: Array = []
    for request_value in requests:
        var request: Dictionary = request_value
        var hand_id := str(request.get("hand_id", ""))
        attempts.append(_generation_attempt(
            request, false,
            "capacity_full" if failed_hands.has(hand_id) \
                else "atomic_rolled_back",
            "", -1, remaining_slot_count(hand_id)))
    return {"success": false, "attempts": attempts}


func _generation_insertion_index(
        slots: Array,
        hand_id: String,
        mode: String,
        after_current_counts: Dictionary,
        rng: RandomNumberGenerator) -> int:
    if slots.is_empty():
        return 0
    if mode == "random":
        return rng.randi_range(0, slots.size())
    var current_index := _slot_index(
        slots, str(_current_slot_ids.get(hand_id, "")))
    if current_index < 0:
        current_index = 0
    if mode == "before_current":
        return current_index
    var offset := int(after_current_counts.get(hand_id, 0))
    after_current_counts[hand_id] = offset + 1
    return mini(slots.size(), current_index + 1 + offset)


func _generation_attempt(
        request: Dictionary,
        succeeded: bool,
        reason: String,
        slot_instance_id: String,
        insertion_position: int,
        remaining: int) -> Dictionary:
    return {
        "hand_id": str(request.get("hand_id", "")),
        "copy_index": int(request.get("copy_index", 0)),
        "technique_id": str(request.get("technique_id", "")),
        "success": succeeded,
        "reason": reason,
        "slot_instance_id": slot_instance_id,
        "insertion_position": insertion_position,
        "remaining_capacity": remaining,
    }


func _generation_receipt(
        batch_mode: String,
        requests: Array,
        generated: Array,
        attempts: Array,
        usage_before: Dictionary,
        atomic_rolled_back: bool) -> Dictionary:
    var target_usage: Dictionary = {}
    for hand_id_value in usage_before:
        var hand_id := str(hand_id_value)
        target_usage[hand_id] = {
            "capacity_before": int(usage_before[hand_id]["capacity"]),
            "capacity_after": slot_capacity(hand_id),
            "remaining_before": int(usage_before[hand_id]["remaining"]),
            "remaining_after": remaining_slot_count(hand_id),
        }
    return {
        "success": true,
        "batch_mode": batch_mode,
        "generation_batch_token": str(requests[0].get(
            "generation_batch_token", "")) if not requests.is_empty() else "",
        "requested_count": requests.size(),
        "generated_count": generated.size(),
        "failed_count": requests.size() - generated.size(),
        "generated_slots": generated.duplicate(true),
        "attempts": attempts.duplicate(true),
        "target_usage": target_usage,
        "atomic_rolled_back": atomic_rolled_back,
    }


func _usage_for_requests(requests: Array) -> Dictionary:
    var result: Dictionary = {}
    for request_value in requests:
        var hand_id := str(request_value.get("hand_id", ""))
        if hand_id != "" and not result.has(hand_id):
            result[hand_id] = slot_usage(hand_id)
    return result


func _capacities_from_slots(slots_by_hand: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for hand_id_value in slots_by_hand:
        result[str(hand_id_value)] = slots_by_hand[hand_id_value].size()
    return result


func _repair_capacities(capacities: Dictionary, slots_by_hand: Dictionary) -> void:
    for hand_id_value in slots_by_hand:
        var hand_id := str(hand_id_value)
        capacities[hand_id] = maxi(
            int(capacities.get(hand_id, 0)),
            slots_by_hand[hand_id_value].size())


func _legacy_sequences() -> Dictionary:
    var result: Dictionary = {}
    for hand_id in _slots_by_hand:
        result[hand_id] = _slots_by_hand[hand_id].map(
            func(slot): return str(slot.get("technique_id", "")))
    return result


func _legacy_positions() -> Dictionary:
    var result: Dictionary = {}
    for hand_id in _slots_by_hand:
        result[hand_id] = position(str(hand_id))
    return result


func _apply_legacy_positions(value: Dictionary) -> void:
    for hand_id_value in value:
        var hand_id := str(hand_id_value)
        var slots: Array = _slots_by_hand.get(hand_id, [])
        if slots.is_empty():
            continue
        var index := posmod(int(value[hand_id_value]), slots.size())
        _current_slot_ids[hand_id] = str(slots[index].get(
            "slot_instance_id", ""))


func _first_slot_id(slots: Array) -> String:
    return str(slots[0].get("slot_instance_id", "")) \
        if not slots.is_empty() else ""


func _slot_index(slots: Array, slot_instance_id: String) -> int:
    for index in range(slots.size()):
        if str(slots[index].get("slot_instance_id", "")) == slot_instance_id:
            return index
    return -1
