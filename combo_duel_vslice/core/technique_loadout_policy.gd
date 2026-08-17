class_name TechniqueLoadoutPolicy
extends RefCounted

## 玩家功法配装的单一只读规则入口。所有校验都针对八种牌型组成的完整
## 拟提交快照；策略本身不修改库存、序列或随机源。

const IntQueryRequestScript = preload(
    "res://core/passives/passive_int_query_request.gd")

const MIN_SLOT_COUNT := 1
const MAX_SLOT_COUNT := 9
const MIN_SEQUENCE_COUNT := 1
const BASE_INSIGHT_SLOT_GAIN := 1

var _catalog
var _resolver = null

func _init(content_catalog = null, int_policy_resolver = null) -> void:
    _catalog = content_catalog
    _resolver = int_policy_resolver

func use_int_policy_resolver(value) -> void:
    _resolver = value

func has_catalog() -> bool:
    return _catalog != null

func definition(technique_id: String) -> Dictionary:
    return _catalog.get_by_id("technique", technique_id) \
        if _catalog != null else {}

func is_built_in(technique_id: String) -> bool:
    return bool(definition(technique_id).get("built_in", false))

func is_eligible(
        technique_id: String,
        hand_id: String,
        learned_ids: Array = []) -> bool:
    if not is_hand_eligible(technique_id, hand_id):
        return false
    var value := definition(technique_id)
    var exact_hands: Array = value.get("eligible_hand_ids", [])
    if not exact_hands.is_empty():
        return exact_hands.has(hand_id)
    if not learned_ids.has(technique_id):
        return false
    var pools: Array = _catalog.definition("techniques").get(
        "pool_membership", {}).get(hand_id, [])
    return pools.has(str(value.get("pool", "")))

func is_hand_eligible(technique_id: String, hand_id: String) -> bool:
    var value := definition(technique_id)
    if value.is_empty() or not _is_formal(technique_id):
        return false
    var exact_hands: Array = value.get("eligible_hand_ids", [])
    if not exact_hands.is_empty():
        return exact_hands.has(hand_id)
    var pools: Array = _catalog.definition("techniques").get(
        "pool_membership", {}).get(hand_id, [])
    return pools.has(str(value.get("pool", "")))

static func is_slot_count_valid(slot_count: int) -> bool:
    return slot_count >= MIN_SLOT_COUNT and slot_count <= MAX_SLOT_COUNT

static func is_sequence_size_valid(
        sequence_size: int,
        slot_count: int) -> bool:
    return is_slot_count_valid(slot_count) \
        and sequence_size >= MIN_SEQUENCE_COUNT \
        and sequence_size <= slot_count

static func has_sequence_capacity(
        sequence_size: int,
        slot_count: int) -> bool:
    return is_slot_count_valid(slot_count) and sequence_size < slot_count

static func unused_slot_count(sequence_size: int, slot_count: int) -> int:
    return maxi(0, slot_count - sequence_size) \
        if is_slot_count_valid(slot_count) else 0

func counts_by_hand(progressions: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for hand_id in progressions:
        var counts: Dictionary = {}
        var progression = progressions[hand_id]
        if progression is Dictionary:
            for technique_id_value in progression.get("sequence", []):
                var technique_id := str(technique_id_value)
                counts[technique_id] = int(counts.get(technique_id, 0)) + 1
        result[str(hand_id)] = counts
    return result

func total_counts(progressions: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for counts in counts_by_hand(progressions).values():
        for technique_id in counts:
            result[technique_id] = int(result.get(technique_id, 0)) \
                + int(counts[technique_id])
    return result

func resolve_limit(
        owner,
        technique_id: String,
        proposed_total_count: int,
        per_hand_counts: Dictionary,
        changed_hand_id: String = "") -> Dictionary:
    var value := definition(technique_id)
    if value.is_empty():
        return {"success": false, "reason": "未知功法：%s" % technique_id}
    var base_value = value.get("base_loadout_limit", 1)
    if not base_value is int or int(base_value) <= 0:
        return {"success": false, "reason": "%s 基础装配上限必须是正整数" % technique_id}
    if _resolver == null:
        return {
            "success": true,
            "base_value": int(base_value),
            "effective_value": int(base_value),
            "modifier_breakdown": [],
            "source_fingerprint": "no_runtime",
        }
    var result = _resolver.resolve(IntQueryRequestScript.new().configure({
        "hook": "technique_loadout_copy_limit_query",
        "owner": owner,
        "subject_kind": "technique",
        "subject_id": technique_id,
        "base_value": int(base_value),
        "metadata": {
            "proposed_total_count": proposed_total_count,
            "counts_by_hand": per_hand_counts.duplicate(true),
            "changed_hand_id": changed_hand_id,
        },
    })).to_dict()
    if not result.get("success", false):
        return {
            "success": false,
            "reason": "功法装配次数查询失败：%s" % \
                "；".join(result.get("errors", [])),
            "query": result,
        }
    var effective = result.get("effective_value")
    if not effective is int or int(effective) < 0:
        return {"success": false, "reason": "功法有效装配上限必须是非负整数"}
    return result

func resolve_insight_slot_gain(
        owner,
        exact_hand_type: String,
        current_slot_count: int,
        base_slot_gain: int = BASE_INSIGHT_SLOT_GAIN) -> Dictionary:
    if not is_slot_count_valid(current_slot_count):
        return {
            "success": false,
            "reason": "%s 功法槽位容量必须位于 %d～%d" % [
                exact_hand_type, MIN_SLOT_COUNT, MAX_SLOT_COUNT],
        }
    if base_slot_gain < 0:
        return {"success": false, "reason": "心得基础槽位增量不能为负数"}
    if _resolver == null:
        return {
            "success": true,
            "base_value": base_slot_gain,
            "effective_value": base_slot_gain,
            "modifier_breakdown": [],
            "source_fingerprint": "no_runtime",
        }
    var result = _resolver.resolve(IntQueryRequestScript.new().configure({
        "hook": "insight_slot_gain_query",
        "owner": owner,
        "subject_kind": "exact_hand_type",
        "subject_id": exact_hand_type,
        "base_value": base_slot_gain,
        "metadata": {
            "exact_hand_type": exact_hand_type,
            "current_slot_count": current_slot_count,
            "base_slot_gain": base_slot_gain,
            "maximum_slot_count": MAX_SLOT_COUNT,
        },
    })).to_dict()
    if not result.get("success", false):
        return {
            "success": false,
            "reason": "心得槽位增量查询失败：%s" % \
                "；".join(result.get("errors", [])),
            "query": result,
        }
    var effective = result.get("effective_value")
    if not effective is int or int(effective) < 0:
        return {"success": false, "reason": "心得有效槽位增量必须是非负整数"}
    return result

func validate_complete(
        owner,
        progressions: Dictionary,
        learned_ids: Array,
        changed_hand_id: String = "") -> Dictionary:
    for hand_id_value in owner.HAND_IDS:
        var hand_id := str(hand_id_value)
        if not progressions.has(hand_id) or not progressions[hand_id] is Dictionary:
            return {"success": false, "reason": "功法配装缺少牌型：%s" % hand_id}
        var progression: Dictionary = progressions[hand_id]
        var slot_count = progression.get("slot_count")
        var sequence = progression.get("sequence")
        if not slot_count is int or not is_slot_count_valid(int(slot_count)):
            return {
                "success": false,
                "reason": "%s 功法槽位容量必须位于 %d～%d" % [
                    hand_id, MIN_SLOT_COUNT, MAX_SLOT_COUNT],
            }
        if not sequence is Array:
            return {"success": false, "reason": "%s 功法序列必须是数组" % hand_id}
        if not is_sequence_size_valid(sequence.size(), int(slot_count)):
            return {
                "success": false,
                "reason": "%s 必须装备 1～%d 门功法，当前为 %d 门" % [
                    hand_id, int(slot_count), sequence.size()],
            }
        for technique_id_value in sequence:
            var technique_id := str(technique_id_value)
            if technique_id == "":
                return {"success": false, "reason": "%s 功法序列包含空值" % hand_id}
            if not is_eligible(technique_id, hand_id, learned_ids):
                return {"success": false, "reason": "功法不适用于 %s：%s" % [hand_id, technique_id]}
    var by_hand := counts_by_hand(progressions)
    var totals := total_counts(progressions)
    var limits: Dictionary = {}
    var ordered_ids: Array = totals.keys()
    ordered_ids.sort()
    for technique_id_value in ordered_ids:
        var technique_id := str(technique_id_value)
        var query := resolve_limit(
            owner, technique_id, int(totals[technique_id]), by_hand,
            changed_hand_id)
        if not query.get("success", false):
            return query
        var effective := int(query["effective_value"])
        limits[technique_id] = query.duplicate(true)
        if int(totals[technique_id]) > effective:
            return {
                "success": false,
                "reason": "%s 已装配 %d/%d，超过全局次数上限" % [
                    technique_id, int(totals[technique_id]), effective],
                "technique_id": technique_id,
                "equipped_total_count": int(totals[technique_id]),
                "effective_loadout_limit": effective,
            }
    return {
        "success": true,
        "counts_by_hand": by_hand,
        "total_counts": totals,
        "limits": limits,
    }

func _is_formal(technique_id: String) -> bool:
    return _catalog != null and str(_catalog.definition("techniques").get(
        "integration_statuses", {}).get(technique_id, "")) == "formal_complete"
