class_name RunCombatHistory
extends RefCounted

## 本局战斗成功历史的唯一结构所有者。
##
## 该值对象不监听事件、不执行效果，也不持有来源。BattleSide 只把已经
## committed 的 canonical 事实投影到这里；GrowthInventory、DTO 和存档只
## 传递 snapshot，避免在各边界复制归一化规则。

const SCHEMA_VERSION := 1
const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]
const METRIC_IDS := [
    "distinct_successful_technique_count",
    "hand_success_count",
    "has_any_successful_hand",
]

var _technique_ids: Dictionary = {}
var _hand_counts: Dictionary = {}
var _id_pattern := RegEx.new()


func _init() -> void:
    _id_pattern.compile("^[a-z][a-z0-9_]*$")
    clear()


func clear() -> void:
    _technique_ids.clear()
    _hand_counts.clear()
    for hand_id in HAND_IDS:
        _hand_counts[hand_id] = 0


func record_technique_success(technique_id: String) -> bool:
    if not _valid_technique_id(technique_id):
        return false
    var changed := not _technique_ids.has(technique_id)
    _technique_ids[technique_id] = true
    return changed


func record_hand_success(hand_id: String) -> bool:
    if hand_id not in HAND_IDS:
        return false
    _hand_counts[hand_id] = int(_hand_counts.get(hand_id, 0)) + 1
    return true


func distinct_technique_count() -> int:
    return _technique_ids.size()


func successful_technique_ids() -> Array[String]:
    var result: Array[String] = []
    result.assign(_technique_ids.keys())
    result.sort()
    return result


func hand_success_count(hand_id: String) -> int:
    return int(_hand_counts.get(hand_id, 0)) if hand_id in HAND_IDS else 0


func has_any_successful_hand() -> bool:
    for hand_id in HAND_IDS:
        if hand_success_count(hand_id) > 0:
            return true
    return false


func most_successful_hand_ids() -> Array[String]:
    var highest := 0
    for hand_id in HAND_IDS:
        highest = maxi(highest, hand_success_count(hand_id))
    var result: Array[String] = []
    for hand_id in HAND_IDS:
        if hand_success_count(hand_id) == highest:
            result.append(hand_id)
    return result


func metric_value(metric: String, hand_id: String = "") -> int:
    match metric:
        "distinct_successful_technique_count":
            return distinct_technique_count()
        "hand_success_count":
            return hand_success_count(hand_id)
        "has_any_successful_hand":
            return 1 if has_any_successful_hand() else 0
    return 0


func snapshot() -> Dictionary:
    var counts: Dictionary = {}
    for hand_id in HAND_IDS:
        counts[hand_id] = hand_success_count(hand_id)
    return {
        "schema_version": SCHEMA_VERSION,
        "successful_technique_ids": successful_technique_ids(),
        "successful_hand_counts": counts,
    }


func restore_snapshot(value: Dictionary) -> Array[String]:
    if value.is_empty():
        clear()
        return []
    var errors: Array[String] = []
    if int(value.get("schema_version", 0)) != SCHEMA_VERSION:
        errors.append("run combat history schema_version 不受支持")
    var technique_values = value.get("successful_technique_ids", [])
    if not technique_values is Array:
        errors.append("successful_technique_ids 必须是数组")
        technique_values = []
    var restored_ids: Dictionary = {}
    for index in range(technique_values.size()):
        var technique_value = technique_values[index]
        var technique_id := str(technique_value)
        if not technique_value is String or not _valid_technique_id(technique_id):
            errors.append(
                "successful_technique_ids[%d] 必须是稳定 technique_id" % index)
            continue
        restored_ids[technique_id] = true
    var count_values = value.get("successful_hand_counts", {})
    if not count_values is Dictionary:
        errors.append("successful_hand_counts 必须是对象")
        count_values = {}
    var restored_counts: Dictionary = {}
    for key in count_values:
        if str(key) not in HAND_IDS:
            errors.append("successful_hand_counts 包含未知牌型：%s" % str(key))
    for hand_id in HAND_IDS:
        var count_value = count_values.get(hand_id, 0)
        if not count_value is int or int(count_value) < 0:
            errors.append("successful_hand_counts.%s 必须是非负整数" % hand_id)
            continue
        restored_counts[hand_id] = int(count_value)
    if not errors.is_empty():
        return errors
    _technique_ids = restored_ids
    _hand_counts = restored_counts
    return []


func replace_from(other) -> Array[String]:
    if not other is RunCombatHistory:
        return ["replace_from 需要 RunCombatHistory"] as Array[String]
    return restore_snapshot(other.snapshot())


func merge_from(other) -> Array[String]:
    if not other is RunCombatHistory:
        return ["merge_from 需要 RunCombatHistory"] as Array[String]
    for technique_id in other.successful_technique_ids():
        record_technique_success(technique_id)
    for hand_id in HAND_IDS:
        _hand_counts[hand_id] = hand_success_count(hand_id) \
            + other.hand_success_count(hand_id)
    return []


func _valid_technique_id(technique_id: String) -> bool:
    return technique_id != "" and _id_pattern.search(technique_id) != null
