class_name InsightGrowthService
extends RefCounted

## 心得成长的唯一规则事实源。
##
## 本服务只计算一份可提交方案，不修改 owner、永久功法序列或 RNG 之外的状态。
## 调用适配器负责在外部提交失败时把 RNG 恢复到调用前状态。

const TechniqueLoadoutPolicyScript = preload(
    "res://core/technique_loadout_policy.gd")


static func resolve(
        owner,
        technique_loadout_policy,
        hand_id: String,
        current_progression: Dictionary,
        current_progressions: Dictionary,
        learned_ids: Array,
        candidates: Array = [],
        rng: RandomNumberGenerator = null,
        validate_complete_loadout: bool = true) -> Dictionary:
    if owner == null or hand_id not in owner.HAND_IDS:
        return {"success": false, "reason": "未知牌型：%s" % hand_id}
    if technique_loadout_policy == null:
        return {"success": false, "reason": "心得成长缺少功法配装策略"}

    var progression := current_progression.duplicate(true)
    var before := int(progression.get(
        "slot_count", TechniqueLoadoutPolicyScript.MIN_SLOT_COUNT))
    var sequence: Array = progression.get("sequence", []).duplicate()
    var gain_query: Dictionary = (
        technique_loadout_policy.resolve_insight_slot_gain(
            owner, hand_id, before))
    if not gain_query.get("success", false):
        return gain_query
    var requested_gain := int(gain_query.get(
        "effective_value",
        TechniqueLoadoutPolicyScript.BASE_INSIGHT_SLOT_GAIN))
    var after := mini(
        TechniqueLoadoutPolicyScript.MAX_SLOT_COUNT,
        before + requested_gain)
    var slot_gain := maxi(0, after - before)

    var available: Array[String] = []
    for candidate_value in candidates:
        var candidate := str(candidate_value)
        if candidate != "" \
                and technique_loadout_policy.is_hand_eligible(
                    candidate, hand_id) \
                and not technique_loadout_policy.is_built_in(candidate) \
                and not learned_ids.has(candidate) \
                and not sequence.has(candidate) \
                and not available.has(candidate):
            available.append(candidate)
    available.sort()
    var acquired := ""
    if not available.is_empty():
        var index := rng.randi_range(0, available.size() - 1) \
            if rng != null else 0
        acquired = available[index]

    progression["slot_count"] = after
    progression["sequence"] = sequence
    var proposed_progression := current_progressions.duplicate(true)
    proposed_progression[hand_id] = progression
    var proposed_learned_ids := learned_ids.duplicate()
    if acquired != "" and not proposed_learned_ids.has(acquired):
        proposed_learned_ids.append(acquired)
    if validate_complete_loadout:
        var validation: Dictionary = technique_loadout_policy.validate_complete(
            owner, proposed_progression, proposed_learned_ids, hand_id)
        if not validation.get("success", false):
            return validation

    return {
        "success": true,
        "hand_id": hand_id,
        "slot_count_before": before,
        "slot_count_after": after,
        "slot_gain": slot_gain,
        "slot_gain_requested": requested_gain,
        "slot_gain_query": gain_query.duplicate(true),
        "proposed_progression": proposed_progression,
        "proposed_learned_ids": proposed_learned_ids,
        "technique_acquired": acquired,
        "technique_equipped": false,
        "no_technique_available": acquired == "",
    }


static func public_result(plan: Dictionary) -> Dictionary:
    var result := plan.duplicate(true)
    result.erase("proposed_progression")
    result.erase("proposed_learned_ids")
    return result
