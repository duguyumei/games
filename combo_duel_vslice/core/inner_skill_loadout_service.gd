class_name InnerSkillLoadoutService
extends RefCounted

const InnerSkillLoadoutDTOScript = preload(
    "res://core/inner_skill_loadout_dto.gd")
const InnerSkillCapacityPolicyScript = preload(
    "res://core/passives/inner_skill_capacity_policy.gd")
const PassiveRuleRuntimeScript = preload(
    "res://core/passives/passive_rule_runtime.gd")
const IntQueryRequestScript = preload(
    "res://core/passives/passive_int_query_request.gd")
const EventContextScript = preload(
    "res://core/passives/run_passive_event_context.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")

var _growth
var _repository
var _passive_runtime
var _int_policy_resolver
var _event_service
var _event_state
var _run_mutation_service

func _init(growth, repository, _legacy_forget_policy = null, passive_runtime = null) -> void:
    _growth = growth
    _repository = repository
    _passive_runtime = passive_runtime
    if _passive_runtime == null:
        var catalog = _growth.get("_content_catalog")
        if catalog != null and catalog.get("passive_rule_registry") != null:
            _passive_runtime = PassiveRuleRuntimeScript.new(
                catalog.passive_rule_registry, catalog)
    var content_catalog = _growth.get("_content_catalog")
    _run_mutation_service = RunMutationServiceScript.new(
        content_catalog.run_effect_registry
            if content_catalog != null else null,
        content_catalog)

func use_passive_runtime(runtime) -> void:
    _passive_runtime = runtime

func use_run_mutation_service(service) -> void:
    _run_mutation_service = service

func use_passive_services(
        runtime,
        int_policy_resolver = null,
        event_service = null,
        event_state = null) -> void:
    _passive_runtime = runtime
    _int_policy_resolver = int_policy_resolver
    _event_service = event_service
    _event_state = event_state

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
            "modifier_breakdown": forget_resolution.get(
                "modifier_breakdown", []).duplicate(true),
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
func query_forget_value(
        inner_skill_id: String,
        source_snapshot: Array = []) -> Dictionary:
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
    var base_value := int(definition["forget_value"])
    var resolved_value := base_value
    var breakdown: Array = []
    if _int_policy_resolver != null:
        var values := {
            "hook": "inner_skill_forget_value_query",
            "owner": _growth,
            "subject_kind": "inner_skill",
            "subject_id": inner_skill_id,
            "base_value": base_value,
            "metadata": {
                "learned_count": _count(
                    _growth.learned_inner_skill_ids, inner_skill_id),
                "equipped_count": _count(
                    _growth.equipped_inner_skill_ids, inner_skill_id),
            },
        }
        if not source_snapshot.is_empty():
            values["source_snapshot"] = source_snapshot
        var query_result = _int_policy_resolver.resolve(
            IntQueryRequestScript.new().configure(values))
        var query_values: Dictionary = query_result.to_dict()
        if not query_values.get("success", false):
            return {
                "success": false,
                "reason": "；".join(query_values.get("errors", [])),
                "query": query_values,
            }
        resolved_value = int(query_values["effective_value"])
        breakdown = query_values["modifier_breakdown"].duplicate(true)
    if resolved_value < 0:
        return {"success": false, "reason": "内功有效遗忘所得必须是非负整数"}
    return {
        "success": true,
        "inner_skill_id": inner_skill_id,
        "base_forget_value": base_value,
        "forget_value": resolved_value,
        "modifier_breakdown": breakdown,
    }

## 普通遗忘一个当前未装备副本，并一次性结算历练与累计数量。
func forget_inner_skill(
        inner_skill_id: String,
        event_values: Dictionary = {}) -> Dictionary:
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
    var source_snapshot: Array = (
        _event_service.capture_source_snapshot(_growth)
        if _event_service != null else [])
    var forget_resolution := query_forget_value(
        inner_skill_id, source_snapshot)
    if not forget_resolution.get("success", false):
        return forget_resolution

    var forget_value := int(forget_resolution["forget_value"])
    var experience_before := int(_growth.experience)
    var working = _growth.create_mutation_copy()
    if working == null:
        return {"success": false, "reason": "无法建立遗忘事务工作副本"}
    var matching_index: int = working.learned_inner_skill_ids.find(inner_skill_id)
    working.learned_inner_skill_ids.remove_at(matching_index)
    if learned_count - 1 <= 0:
        working.source_marker_store.remove_entries({
            "source_kind": "inner_skill",
            "content_id": inner_skill_id,
            "scope": "run",
        }, true)
    if _run_mutation_service == null:
        return {"success": false, "reason": "遗忘历练修改缺少 RunMutationService"}
    var experience_change: Dictionary = _run_mutation_service.change_experience_in_place(
        working, forget_value, {
            "transaction_token": "inner_skill_forgotten:%d:%s" % [
                int(working.forgotten_inner_skill_count) + 1, inner_skill_id],
            "operation": "inner_skill_forget",
            "reason": "inner_skill_forget",
            "source_kind": "inner_skill",
            "source_id": inner_skill_id,
            "source_snapshot": source_snapshot,
        })
    if not experience_change.get("success", false):
        return experience_change
    working.forgotten_inner_skill_count += 1
    var event_result := _dispatch_forgotten_event(
        working, inner_skill_id, forget_resolution,
        source_snapshot, event_values)
    if not event_result.get("success", false):
        return event_result
    var commit_errors: Array[String] = _growth.replace_mutation_state(
        working.capture_mutation_state())
    if not commit_errors.is_empty():
        if _event_state != null and not event_result.get("skipped", false):
            _event_state.committed_passive_event_tokens.erase(
                str(event_result.get("transaction_token", "")))
        return {"success": false, "reason": "；".join(commit_errors)}
    return {
        "success": true,
        "inner_skill_id": inner_skill_id,
        "forget_value": forget_value,
        "base_forget_value": int(forget_resolution["base_forget_value"]),
        "modifier_breakdown": forget_resolution["modifier_breakdown"],
        "experience_before": experience_before,
        "experience_after": _growth.experience,
        "forgotten_inner_skill_count": _growth.forgotten_inner_skill_count,
        "remaining_count": learned_count - 1,
        "passive_event": event_result,
        "experience_change": experience_change.duplicate(true),
    }

func _dispatch_forgotten_event(
        working,
        inner_skill_id: String,
        forget_resolution: Dictionary,
        source_snapshot: Array,
        event_values: Dictionary) -> Dictionary:
    var token := "inner_skill_forgotten:%d:%s" % [
        int(working.forgotten_inner_skill_count), inner_skill_id]
    if _event_service == null or _event_state == null:
        return {
            "success": true,
            "skipped": true,
            "hook": "inner_skill_forgotten",
            "transaction_token": token,
        }
    var values := event_values.duplicate(true)
    values.merge({
        "hook": "inner_skill_forgotten",
        "owner": working,
        "content_id": inner_skill_id,
        "content_kind": "inner_skill",
        "transaction_token": token,
        "source_snapshot": source_snapshot,
        "payload": {
            "base_forget_value": int(
                forget_resolution["base_forget_value"]),
            "forget_value": int(forget_resolution["forget_value"]),
            "forgotten_inner_skill_count": int(
                working.forgotten_inner_skill_count),
        },
    }, true)
    return _event_service.dispatch(
        EventContextScript.new().configure(values), working, _event_state)

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
