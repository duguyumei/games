class_name InnerSkillLoadoutService
extends RefCounted

const InnerSkillLoadoutDTOScript = preload(
    "res://core/inner_skill_loadout_dto.gd")
const InnerSkillForgetValuePolicyScript = preload(
    "res://core/inner_skill_forget_value_policy.gd")
const InnerSkillCapacityPolicyScript = preload(
    "res://core/passives/inner_skill_capacity_policy.gd")
const PassiveRuleRuntimeScript = preload(
    "res://core/passives/passive_rule_runtime.gd")

var _growth
var _repository
var _forget_value_policy
var _passive_runtime

func _init(growth, repository, forget_value_policy = null, passive_runtime = null) -> void:
    _growth = growth
    _repository = repository
    _forget_value_policy = (
        forget_value_policy
        if forget_value_policy != null
        else InnerSkillForgetValuePolicyScript.new())
    _passive_runtime = passive_runtime
    if _passive_runtime == null:
        var catalog = _growth.get("_content_catalog")
        if catalog != null and catalog.get("passive_rule_registry") != null:
            _passive_runtime = PassiveRuleRuntimeScript.new(
                catalog.passive_rule_registry, catalog)

func use_passive_runtime(runtime) -> void:
    _passive_runtime = runtime

## 查询完整配装。`editable` 只描述当前会话门禁，不改变领域库存。
func get_loadout(
        editable: bool = true,
        blocked_reason: String = ""):
    var capacity := _resolve_capacity(_growth.equipped_inner_skill_ids)
    var learned_counts := _counts(_growth.learned_inner_skill_ids)
    var equipped_counts := _counts(_growth.equipped_inner_skill_ids)
    var learned: Array = []
    var emitted: Dictionary = {}
    for inner_skill_id_value in _growth.learned_inner_skill_ids:
        var inner_skill_id := str(inner_skill_id_value)
        if emitted.has(inner_skill_id):
            continue
        emitted[inner_skill_id] = true
        var definition: Dictionary = _repository.get_inner_skill(inner_skill_id)
        var total_count := int(learned_counts.get(inner_skill_id, 0))
        var equipped_count := int(equipped_counts.get(inner_skill_id, 0))
        var forget_resolution := query_forget_value(inner_skill_id)
        learned.append({
            "id": inner_skill_id,
            "name": str(definition.get("name", inner_skill_id)),
            "total_count": total_count,
            "equipped_count": equipped_count,
            "unequipped_count": maxi(0, total_count - equipped_count),
            "base_forget_value": (
                int(definition["forget_value"])
                if definition.has("forget_value")
                and definition["forget_value"] is int
                else null),
            "forget_value": (
                int(forget_resolution.get("forget_value", 0))
                if forget_resolution.get("success", false)
                else null),
            "can_forget": (
                total_count > equipped_count
                and forget_resolution.get("success", false)),
            "status": str(definition.get("status", "")),
        })

    var equipped: Array = []
    var occurrences: Dictionary = {}
    for slot_index in range(_growth.equipped_inner_skill_ids.size()):
        var inner_skill_id := str(_growth.equipped_inner_skill_ids[slot_index])
        var occurrence_index := int(occurrences.get(inner_skill_id, 0)) + 1
        occurrences[inner_skill_id] = occurrence_index
        var definition: Dictionary = _repository.get_inner_skill(inner_skill_id)
        equipped.append({
            "slot_index": slot_index,
            "inner_skill_id": inner_skill_id,
            "name": str(definition.get("name", inner_skill_id)),
            "occurrence_index": occurrence_index,
            "combat_source_order": (
                slot_index
                if slot_index < _growth.technique_slot_index
                else slot_index + 1),
        })

    return InnerSkillLoadoutDTOScript.new().configure({
        "learned": learned,
        "equipped": equipped,
        "equipped_inner_skill_ids": _growth.equipped_inner_skill_ids,
        "technique_slot_index": _growth.technique_slot_index,
        "base_inner_skill_capacity": capacity["base_capacity"],
        "effective_inner_skill_capacity": capacity["effective_capacity"],
        "capacity_modifiers": capacity["modifiers"],
        "inner_skill_limit": capacity["effective_capacity"],
        "editable": editable,
        "blocked_reason": "" if editable else blocked_reason,
    })

## 完整替换永久配装。所有输入先验证，失败时不会修改任何成长字段。
func set_loadout(equipped_inner_skill_ids, technique_slot_index) -> Dictionary:
    if not equipped_inner_skill_ids is Array:
        return {"success": false, "reason": "equipped_inner_skill_ids 必须是数组"}
    # 固定顺序：ID → 已获得副本数 → proposed 容量 → 数量 → 功法位置。
    var learned_counts := _counts(_growth.learned_inner_skill_ids)
    var requested_counts: Dictionary = {}
    var normalized: Array[String] = []
    for inner_skill_id_value in equipped_inner_skill_ids:
        if not inner_skill_id_value is String \
                or str(inner_skill_id_value).strip_edges() == "":
            return {"success": false, "reason": "内功配装不能包含空 ID"}
        var inner_skill_id := str(inner_skill_id_value)
        if not _repository.has_inner_skill(inner_skill_id):
            return {
                "success": false,
                "reason": "未知内功：%s" % inner_skill_id,
            }
        requested_counts[inner_skill_id] = int(
            requested_counts.get(inner_skill_id, 0)) + 1
        if int(requested_counts[inner_skill_id]) \
                > int(learned_counts.get(inner_skill_id, 0)):
            return {
                "success": false,
                "reason": "装备数量超过已获得副本数：%s" % inner_skill_id,
            }
        normalized.append(inner_skill_id)

    var capacity := _resolve_capacity(normalized)
    if not capacity.get("errors", []).is_empty():
        return {
            "success": false,
            "reason": "内功容量查询失败：%s" % "；".join(capacity["errors"]),
        }
    if normalized.size() > int(capacity["effective_capacity"]):
        return {
            "success": false,
            "reason": "内功有效容量为 %d，不能装备 %d 门" % [
                int(capacity["effective_capacity"]), normalized.size()],
        }
    if not technique_slot_index is int:
        return {"success": false, "reason": "technique_slot_index 必须是整数"}
    if int(technique_slot_index) < 0 \
            or int(technique_slot_index) > normalized.size():
        return {
            "success": false,
            "reason": "technique_slot_index 必须位于 0～装备数量之间",
        }

    var before: Dictionary = get_loadout().to_dict()
    _growth.equipped_inner_skill_ids.assign(normalized)
    _growth.technique_slot_index = int(technique_slot_index)
    var after: Dictionary = get_loadout().to_dict()
    return {
        "success": true,
        "before": before,
        "after": after,
        "equipped_inner_skill_ids": normalized.duplicate(),
        "technique_slot_index": int(technique_slot_index),
    }

## 查询当前有效普通遗忘所得。缺失基础字段不会被解释为 0。
func query_forget_value(inner_skill_id: String) -> Dictionary:
    if not _repository.has_inner_skill(inner_skill_id):
        return {"success": false, "reason": "未知内功：%s" % inner_skill_id}
    var definition: Dictionary = _repository.get_inner_skill(inner_skill_id)
    if not definition.has("forget_value"):
        return {
            "success": false,
            "reason": "该内功尚未配置遗忘所得：%s" % inner_skill_id,
        }
    if not definition["forget_value"] is int \
            or int(definition["forget_value"]) < 0:
        return {
            "success": false,
            "reason": "该内功遗忘所得配置无效：%s" % inner_skill_id,
        }
    if _forget_value_policy == null \
            or not _forget_value_policy.has_method("resolve"):
        return {"success": false, "reason": "内功遗忘所得策略不可用"}
    var resolved = _forget_value_policy.resolve(definition, _growth)
    if not resolved is int or int(resolved) < 0:
        return {"success": false, "reason": "内功有效遗忘所得必须是非负整数"}
    return {
        "success": true,
        "inner_skill_id": inner_skill_id,
        "base_forget_value": int(definition["forget_value"]),
        "forget_value": int(resolved),
    }

## 普通遗忘一个当前未装备副本，并一次性结算历练与累计数量。
func forget_inner_skill(inner_skill_id: String) -> Dictionary:
    if inner_skill_id.strip_edges() == "":
        return {"success": false, "reason": "inner_skill_id 不能为空"}
    if not _repository.has_inner_skill(inner_skill_id):
        return {"success": false, "reason": "未知内功：%s" % inner_skill_id}
    var learned_count := _count(_growth.learned_inner_skill_ids, inner_skill_id)
    if learned_count <= 0:
        return {"success": false, "reason": "尚未获得该内功：%s" % inner_skill_id}
    var equipped_count := _count(_growth.equipped_inner_skill_ids, inner_skill_id)
    if equipped_count >= learned_count:
        return {
            "success": false,
            "reason": "该内功所有副本均已装备，请先卸下一份",
        }
    var forget_resolution := query_forget_value(inner_skill_id)
    if not forget_resolution.get("success", false):
        return forget_resolution

    var forget_value := int(forget_resolution["forget_value"])
    var experience_before := int(_growth.experience)
    var matching_index: int = _growth.learned_inner_skill_ids.find(inner_skill_id)
    _growth.learned_inner_skill_ids.remove_at(matching_index)
    _growth.experience = experience_before + forget_value
    _growth.forgotten_inner_skill_count += 1
    return {
        "success": true,
        "inner_skill_id": inner_skill_id,
        "forget_value": forget_value,
        "experience_before": experience_before,
        "experience_after": _growth.experience,
        "forgotten_inner_skill_count": _growth.forgotten_inner_skill_count,
        "remaining_count": learned_count - 1,
    }

func _counts(values: Array) -> Dictionary:
    var result: Dictionary = {}
    for value in values:
        var inner_skill_id := str(value)
        result[inner_skill_id] = int(result.get(inner_skill_id, 0)) + 1
    return result

func _count(values: Array, inner_skill_id: String) -> int:
    var result := 0
    for value in values:
        if str(value) == inner_skill_id:
            result += 1
    return result

func _resolve_capacity(proposed_ids: Array) -> Dictionary:
    if _passive_runtime != null:
        return _passive_runtime.resolve_inner_skill_capacity(
            _growth, proposed_ids)
    return {
        "base_capacity": InnerSkillCapacityPolicyScript.BASE_INNER_SKILL_CAPACITY,
        "modifiers": [],
        "effective_capacity": InnerSkillCapacityPolicyScript.BASE_INNER_SKILL_CAPACITY,
        "source_breakdown": [],
        "errors": [],
    }
