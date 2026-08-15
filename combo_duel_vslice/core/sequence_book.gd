class_name TechniqueSequenceBook
extends RefCounted

const DATA_PATH := "res://data/vertical_slice_sequences.json"
const SLOT_SCHEMA_VERSION := 1

var _slots_by_hand: Dictionary = {}
var _initial_slots_by_hand: Dictionary = {}
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

func configure(values: Dictionary) -> void:
    _slots_by_hand.clear()
    _initial_slots_by_hand.clear()
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
        _slots_by_hand[hand_id] = slots
        _initial_slots_by_hand[hand_id] = slots.duplicate(true)
        _current_slot_ids[hand_id] = _first_slot_id(slots)

func configure_hand_progression(values: Dictionary) -> void:
    var next: Dictionary = {}
    for hand_id_value in _slots_by_hand:
        var hand_id := str(hand_id_value)
        var progression: Dictionary = values.get(hand_id, {})
        var sequence = progression.get("sequence", []) if progression is Dictionary else []
        next[hand_id] = sequence.duplicate(true) if sequence is Array else []
    for hand_id_value in values:
        var hand_id := str(hand_id_value)
        if next.has(hand_id):
            continue
        var progression: Dictionary = values[hand_id_value]
        var sequence = progression.get("sequence", []) if progression is Dictionary else []
        next[hand_id] = sequence.duplicate(true) if sequence is Array else []
    configure(next)

func reset() -> void:
    _slots_by_hand = _initial_slots_by_hand.duplicate(true)
    _current_slot_ids.clear()
    _insertion_serial = 0
    for hand_id in _slots_by_hand:
        _current_slot_ids[hand_id] = _first_slot_id(_slots_by_hand[hand_id])

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
        "origin_technique_id": str(slot.get("origin_technique_id", "")),
        "origin_slot_instance_id": str(slot.get("origin_slot_instance_id", "")),
        "insertion_serial": int(slot.get("insertion_serial", 0)),
        "marker_mode": str(slot.get("marker_mode", "independent")),
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
            if technique_filter != "" and str(slot.get("technique_id", "")) != technique_filter:
                continue
            if origin_filter != "" and str(slot.get("origin_slot_instance_id", "")) != origin_filter:
                continue
            if temporary_filter != null and bool(slot.get("temporary", false)) != bool(temporary_filter):
                continue
            result.append(slot)
    return result

func move_slot_to_current(hand_id: String, slot_instance_id: String) -> Dictionary:
    var before := ordered_slots(hand_id)
    var slots: Array = _slots_by_hand.get(hand_id, [])
    var target_index := _slot_index(slots, slot_instance_id)
    if target_index < 0:
        return {"success": false, "reason": "功法槽位不存在", "sequence_before": before}
    var current_index := _slot_index(slots, str(_current_slot_ids.get(hand_id, "")))
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

func insert_temporary_slots(
        hand_id: String,
        technique_id: String,
        copies: int,
        options: Dictionary = {}) -> Array:
    var inserted: Array = []
    if copies <= 0:
        return inserted
    if not _slots_by_hand.has(hand_id):
        _slots_by_hand[hand_id] = []
        _initial_slots_by_hand[hand_id] = []
        _current_slot_ids[hand_id] = ""
    var slots: Array = _slots_by_hand[hand_id]
    var origin_slot_id := str(options.get("origin_slot_instance_id", ""))
    var origin_technique_id := str(options.get("origin_technique_id", technique_id))
    var marker_mode := str(options.get("marker_mode", "independent"))
    var position_mode := str(options.get("position", "after_current"))
    var frozen_indices: Array = options.get("frozen_indices", [])
    for copy_index in range(copies):
        _insertion_serial += 1
        var slot_id := "battle-slot:%s:%06d:%s" % [hand_id, _insertion_serial, technique_id]
        var slot := {
            "slot_schema_version": SLOT_SCHEMA_VERSION,
            "slot_instance_id": slot_id,
            "technique_id": technique_id,
            "hand_id": hand_id,
            "temporary": true,
            "origin_technique_id": origin_technique_id,
            "origin_slot_instance_id": origin_slot_id,
            "insertion_serial": _insertion_serial,
            "marker_mode": marker_mode,
        }
        var index := _insertion_index(slots, hand_id, position_mode, frozen_indices, copy_index)
        slots.insert(index, slot)
        inserted.append(slot.duplicate(true))
        if str(_current_slot_ids.get(hand_id, "")) == "":
            _current_slot_ids[hand_id] = slot_id
    _slots_by_hand[hand_id] = slots
    return inserted

func complete_slot(hand_id: String, expected_slot_instance_id: String) -> Dictionary:
    var before := ordered_slots(hand_id)
    var slots: Array = _slots_by_hand.get(hand_id, [])
    var completed_index := _slot_index(slots, expected_slot_instance_id)
    if completed_index < 0:
        return {"success": false, "reason": "冻结功法槽位不存在", "sequence_before": before}
    if slots.size() == 1:
        _current_slot_ids[hand_id] = expected_slot_instance_id
    else:
        _current_slot_ids[hand_id] = str(slots[(completed_index + 1) % slots.size()].get("slot_instance_id", ""))
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
        "current_slot_ids": _current_slot_ids.duplicate(true),
        "insertion_serial": _insertion_serial,
    }

func restore_snapshot(value: Dictionary) -> void:
    _slots_by_hand = value.get("slots_by_hand", {}).duplicate(true)
    _initial_slots_by_hand = value.get("initial_slots_by_hand", _slots_by_hand).duplicate(true)
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

func _make_permanent_slot(hand_id: String, technique_id: String, index: int) -> Dictionary:
    return {
        "slot_schema_version": SLOT_SCHEMA_VERSION,
        "slot_instance_id": "permanent-slot:%s:%04d:%s" % [hand_id, index, technique_id],
        "technique_id": technique_id,
        "hand_id": hand_id,
        "temporary": false,
        "origin_technique_id": technique_id,
        "origin_slot_instance_id": "",
        "insertion_serial": index,
        "marker_mode": "independent",
    }

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
        _current_slot_ids[hand_id] = str(slots[index].get("slot_instance_id", ""))

func _first_slot_id(slots: Array) -> String:
    return str(slots[0].get("slot_instance_id", "")) if not slots.is_empty() else ""

func _slot_index(slots: Array, slot_instance_id: String) -> int:
    for index in range(slots.size()):
        if str(slots[index].get("slot_instance_id", "")) == slot_instance_id:
            return index
    return -1

func _insertion_index(
        slots: Array,
        hand_id: String,
        mode: String,
        frozen_indices: Array,
        copy_index: int) -> int:
    if slots.is_empty():
        return 0
    if mode == "random" and copy_index < frozen_indices.size():
        return clampi(int(frozen_indices[copy_index]), 0, slots.size())
    var current_index := _slot_index(slots, str(_current_slot_ids.get(hand_id, "")))
    if current_index < 0:
        current_index = 0
    if mode == "before_current":
        return current_index
    return current_index + 1
