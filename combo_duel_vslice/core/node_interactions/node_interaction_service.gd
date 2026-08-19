class_name NodeInteractionService
extends RefCounted

const SCHEMA_VERSION := 2
const ContextScript = preload(
    "res://core/node_interactions/node_interaction_context.gd")
const DTOScript = preload(
    "res://core/node_interactions/node_interaction_dto.gd")
const RegistryScript = preload(
    "res://core/node_interactions/node_interaction_handler_registry.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")
const IntQueryRequestScript = preload(
    "res://core/passives/passive_int_query_request.gd")

var handler_registry
var mutation_service
var content_catalog
var _pending: Dictionary = {}
var _committed: bool = false
var _int_policy_resolver = null
var _session_serial: int = 0

func _init(
        registry_override = null,
        mutation_service_override = null,
        content_catalog_override = null) -> void:
    handler_registry = (
        registry_override if registry_override != null else RegistryScript.new())
    mutation_service = (
        mutation_service_override
        if mutation_service_override != null
        else RunMutationServiceScript.new())
    content_catalog = content_catalog_override

func use_passive_int_policy_resolver(resolver) -> void:
    _int_policy_resolver = resolver

func prepare(dispatch: Dictionary, growth, source_context: Dictionary = {}) -> Dictionary:
    if str(dispatch.get("route", "")) != "interaction":
        return _failure("节点调度结果不是 interaction 路由")
    var interaction = dispatch.get("interaction")
    if not interaction is Dictionary:
        return _failure("interaction 路由缺少 interaction 对象")
    if not interaction.get("configuration") is Dictionary:
        return _failure("interaction.configuration 必须是对象")
    var kind := str(interaction.get("kind", ""))
    var handler_result: Dictionary = handler_registry.require_handler(kind)
    if not handler_result.get("success", false):
        return handler_result
    var values := _context_values(dispatch, interaction, source_context)
    if str(values.get("source_kind", "")) not in ["map_node", "boss_chest"]:
        return _failure("节点交互 source_kind 必须是 map_node 或 boss_chest")
    if str(values.get("source_id", "")) == "":
        return _failure("节点交互 source_id 不能为空")
    var token := _stable_token(values)
    values["interaction_token"] = token
    if not _pending.is_empty():
        if _committed:
            return _failure("该节点交互已经成功提交，不能重新准备")
        if str(_pending.get("token", "")) != token:
            return _failure("已有另一个待完成的节点交互")
        return {"success": true, "interaction": query_active(), "reused": true}

    var context = ContextScript.new(values, growth, content_catalog)
    var prepared = handler_result["handler"].prepare(context)
    if not prepared is Dictionary:
        return _failure("节点交互 prepare 必须返回对象")
    if prepared.has("success") and not prepared.get("success", false):
        return _failure(str(prepared.get("reason", "节点交互准备失败")))
    var dto_values: Dictionary = prepared.duplicate(true)
    dto_values.erase("success")
    dto_values.merge({
        "interaction_token": token,
        "source_kind": values["source_kind"],
        "source_id": values["source_id"],
        "node_id": values["node_id"],
        "node_type": values["node_type"],
        "content_id": values["content_id"],
        "interaction_kind": kind,
        "act": values["act"],
        "content_seed": values["content_seed"],
    }, true)
    if str(dto_values.get("title", "")) == "":
        dto_values["title"] = str(dispatch.get("title", ""))
    if str(dto_values.get("description", "")) == "":
        dto_values["description"] = str(dispatch.get("description", ""))
    var dto = DTOScript.new(dto_values)
    var dto_snapshot: Dictionary = dto.to_dict()
    var validation_error := validate_frozen_dto(dto_snapshot)
    if validation_error != "":
        return _failure(validation_error)
    var initial_choice_ids := _enabled_choice_ids(dto_snapshot)
    var policy := _resolve_multi_select_policy(
        growth, values, initial_choice_ids.size())
    if not policy.get("success", false):
        return policy
    _session_serial += 1
    var effective_maximum := mini(
        initial_choice_ids.size(),
        maxi(1, int(policy.get("effective_value", 1))))
    var effective_minimum := mini(
        effective_maximum, maxi(0, int(dto_snapshot.get(
            "minimum_choices", 1))))
    dto_snapshot["minimum_choices"] = effective_minimum
    dto_snapshot["maximum_choices"] = effective_maximum
    dto_snapshot["selected_choice_ids"] = []
    dto_snapshot["allow_finish"] = effective_maximum > 1
    dto_snapshot["session_serial"] = _session_serial
    dto_snapshot["policy_fingerprint"] = str(policy.get(
        "source_fingerprint", "no_runtime"))
    _pending = {
        "schema_version": SCHEMA_VERSION,
        "token": token,
        "source_kind": values["source_kind"],
        "source_id": values["source_id"],
        "node_id": values["node_id"],
        "node_type": values["node_type"],
        "content_id": values["content_id"],
        "interaction_kind": kind,
        "act": values["act"],
        "run_seed": values["run_seed"],
        "content_seed": values["content_seed"],
        "configuration": values["configuration"].duplicate(true),
        "interaction": dto_snapshot,
        "initial_choice_ids": initial_choice_ids,
        "selected_choice_ids": [],
        "maximum_choices": effective_maximum,
        "minimum_choices": effective_minimum,
        "allow_finish": effective_maximum > 1,
        "policy_fingerprint": str(policy.get(
            "source_fingerprint", "no_runtime")),
        "policy_breakdown": policy.get(
            "modifier_breakdown", []).duplicate(true),
        "session_serial": _session_serial,
    }
    if not _is_json_value(_pending):
        _pending.clear()
        return _failure("冻结节点交互包含不可写入 JSON 的运行对象")
    _committed = false
    return {"success": true, "interaction": dto_snapshot.duplicate(true), "reused": false}

func query_active() -> Dictionary:
    if _pending.is_empty() or _committed:
        return {}
    return _pending.get("interaction", {}).duplicate(true)

func commit(token: String, choice_id: String, choice_payload, growth) -> Dictionary:
    if _pending.is_empty():
        return _failure("当前没有待提交的节点交互")
    if _committed:
        return _failure("该节点交互已经成功提交，不能重复提交")
    if token != str(_pending.get("token", "")):
        return _failure("interaction_token 不匹配")
    if not choice_payload is Dictionary:
        return _failure("choice_payload 必须是对象")
    if _pending.get("selected_choice_ids", []).has(choice_id):
        return _failure("同一节点交互选项不能重复提交：%s" % choice_id)
    if not _pending.get("initial_choice_ids", []).has(choice_id):
        return _failure("选项不属于本次会话的初始合法候选：%s" % choice_id)
    var pending_before := _pending.duplicate(true)
    var growth_before: Dictionary = growth.capture_mutation_state() \
        if growth != null and growth.has_method("capture_mutation_state") else {}
    var refreshed := _refresh_interaction(growth)
    if not refreshed.get("success", false):
        return _restore_commit_failure(
            growth, pending_before, growth_before, refreshed)
    var selected: Dictionary = {}
    for choice_value in _pending.get("interaction", {}).get("choices", []):
        if choice_value is Dictionary and str(choice_value.get("id", "")) == choice_id:
            selected = choice_value
            break
    if selected.is_empty():
        return _restore_commit_failure(
            growth, pending_before, growth_before,
            _failure("未知节点交互选项：%s" % choice_id))
    if not bool(selected.get("enabled", true)):
        return _restore_commit_failure(
            growth, pending_before, growth_before,
            _failure(str(selected.get(
                "disabled_reason", "该节点交互选项不可用"))))
    var handler_result: Dictionary = handler_registry.require_handler(
        str(_pending.get("interaction_kind", "")))
    if not handler_result.get("success", false):
        return _restore_commit_failure(
            growth, pending_before, growth_before, handler_result)
    var context = ContextScript.new(_pending, growth, content_catalog)
    var committed = handler_result["handler"].commit(
        context,
        _pending.get("interaction", {}).duplicate(true),
        choice_id,
        choice_payload.duplicate(true))
    if not committed is Dictionary:
        return _restore_commit_failure(
            growth, pending_before, growth_before,
            _failure("节点交互 commit 必须返回对象"))
    if not committed.get("success", false):
        return _restore_commit_failure(
            growth, pending_before, growth_before,
            _failure(str(committed.get("reason", "节点交互提交失败"))))
    var effects = committed.get("effects", [])
    if not effects is Array:
        return _restore_commit_failure(
            growth, pending_before, growth_before,
            _failure("节点交互 commit.effects 必须是数组"))
    var interaction_result = committed.get("result", {})
    if not interaction_result is Dictionary:
        return _restore_commit_failure(
            growth, pending_before, growth_before,
            _failure("节点交互 commit.result 必须是对象"))
    if not _is_json_value(interaction_result):
        return _restore_commit_failure(
            growth, pending_before, growth_before,
            _failure("节点交互 commit.result 包含运行对象"))
    var mutation_result: Dictionary = mutation_service.apply_effects(
        effects, growth, {
            "source_kind": str(_pending.get("source_kind", "")),
            "source_id": str(_pending.get("source_id", "")),
            "node_id": str(_pending.get("node_id", "")),
            "interaction_token": token,
        })
    if not mutation_result.get("success", false):
        return _restore_commit_failure(
            growth, pending_before, growth_before, mutation_result)
    _pending["selected_choice_ids"].append(choice_id)
    var next := _refresh_interaction(growth)
    if not next.get("success", false):
        return _restore_commit_failure(
            growth, pending_before, growth_before, next)
    var completed := _should_auto_complete()
    _committed = completed
    return {
        "success": true,
        "interaction_result": interaction_result.duplicate(true),
        "applied": mutation_result.get("applied", []).duplicate(true),
        "changed": bool(mutation_result.get("changed", false)),
        "interaction_token": token,
        "completed": completed,
        "interaction": {} if completed else query_active(),
        "selected_choice_ids": _pending.get(
            "selected_choice_ids", []).duplicate(),
    }

func _restore_commit_failure(
        growth,
        pending_snapshot: Dictionary,
        growth_snapshot: Dictionary,
        failure: Dictionary) -> Dictionary:
    _pending = pending_snapshot.duplicate(true)
    if growth != null and not growth_snapshot.is_empty() \
            and growth.has_method("replace_mutation_state"):
        var errors: Array[String] = growth.replace_mutation_state(
            growth_snapshot)
        if not errors.is_empty():
            var result := failure.duplicate(true)
            result["reason"] = "%s；回滚失败：%s" % [
                str(result.get("reason", "节点选项提交失败")),
                "；".join(errors)]
            return result
    return failure

func finish(token: String) -> Dictionary:
    if _pending.is_empty() or _committed:
        return _failure("当前没有可结束的节点多选会话")
    if token != str(_pending.get("token", "")):
        return _failure("interaction_token 不匹配")
    if not bool(_pending.get("allow_finish", false)):
        return _failure("当前节点交互不允许主动结束")
    if _pending.get("selected_choice_ids", []).size() < int(
            _pending.get("minimum_choices", 1)):
        return _failure("尚未达到节点交互最少提交数")
    _committed = true
    return {
        "success": true,
        "completed": true,
        "interaction_token": token,
        "selected_choice_ids": _pending.get(
            "selected_choice_ids", []).duplicate(),
    }

func cancel(token: String) -> Dictionary:
    if _pending.is_empty() or _committed:
        return _failure("当前没有可取消草稿的节点交互")
    if token != str(_pending.get("token", "")):
        return _failure("interaction_token 不匹配")
    return {
        "success": true,
        "interaction_token": token,
        "interaction": query_active(),
        "cancelled": true,
    }

func clear() -> void:
    _pending.clear()
    _committed = false

func capture_pending() -> Dictionary:
    if _pending.is_empty() or _committed:
        return {}
    return _pending.duplicate(true)

func capture_transaction_state() -> Dictionary:
    return {
        "pending": _pending.duplicate(true),
        "committed": _committed,
    }

## 聚合事务已经捕获过受信任的运行状态；恢复不得重新执行 prepare/commit。
func restore_transaction_state(state: Dictionary) -> void:
    _pending.clear()
    _pending.merge(state.get("pending", {}).duplicate(true), true)
    _committed = bool(state.get("committed", false))

func restore_pending(snapshot: Dictionary) -> Dictionary:
    if snapshot.is_empty():
        clear()
        return {"success": true, "restored": false}
    var restored_snapshot := normalize_pending_snapshot(snapshot)
    if int(restored_snapshot.get("schema_version", 0)) != SCHEMA_VERSION:
        return _failure("pending interaction schema_version 不受支持")
    var dto = restored_snapshot.get("interaction")
    if not dto is Dictionary:
        return _failure("pending interaction 缺少冻结 interaction DTO")
    var error := validate_frozen_dto(dto)
    if error != "":
        return _failure(error)
    if str(restored_snapshot.get("token", "")) != str(dto.get("interaction_token", "")):
        return _failure("pending interaction token 与 DTO 不一致")
    if not handler_registry.has_handler(str(restored_snapshot.get("interaction_kind", ""))):
        return _failure(
            "未注册的节点交互 kind：%s" % str(restored_snapshot.get("interaction_kind", "")))
    if not restored_snapshot.get("configuration") is Dictionary:
        return _failure("pending interaction configuration 必须是对象")
    var session_error := validate_pending_session_state(restored_snapshot)
    if session_error != "":
        return _failure(session_error)
    if not _is_json_value(restored_snapshot):
        return _failure("pending interaction 包含不可写入 JSON 的运行对象")
    _pending = restored_snapshot.duplicate(true)
    _committed = false
    _session_serial = maxi(_session_serial, int(_pending.get(
        "session_serial", 0)))
    return {"success": true, "restored": true, "interaction": query_active()}

static func validate_frozen_dto(dto: Dictionary) -> String:
    if int(dto.get("schema_version", 0)) != DTOScript.SCHEMA_VERSION:
        return "节点交互 DTO schema_version 无效"
    for field in [
            "interaction_token", "source_kind", "source_id", "content_id",
            "interaction_kind", "title"]:
        if str(dto.get(field, "")) == "":
            return "节点交互 DTO 缺少 %s" % field
    if not dto.get("choices") is Array:
        return "节点交互 DTO choices 必须是数组"
    var minimum := int(dto.get("minimum_choices", -1))
    var maximum := int(dto.get("maximum_choices", -1))
    if minimum < 0 or maximum < minimum:
        return "节点交互 DTO 选择数量范围无效"
    var seen: Dictionary = {}
    for choice_value in dto.get("choices", []):
        if not choice_value is Dictionary:
            return "节点交互 choice 必须是对象"
        var choice_id := str(choice_value.get("id", ""))
        if choice_id == "":
            return "节点交互 choice.id 不能为空"
        if seen.has(choice_id):
            return "节点交互 choice.id 重复：%s" % choice_id
        if not choice_value.get("metadata", {}) is Dictionary:
            return "节点交互 choice.metadata 必须是对象"
        seen[choice_id] = true
    if not dto.get("metadata", {}) is Dictionary:
        return "节点交互 metadata 必须是对象"
    if not _is_json_value(dto):
        return "节点交互 DTO 包含不可写入 JSON 的运行对象"
    return ""

func _resolve_multi_select_policy(
        growth, values: Dictionary, candidate_count: int) -> Dictionary:
    if _int_policy_resolver == null:
        return {
            "success": true, "base_value": 1, "effective_value": 1,
            "source_fingerprint": "no_runtime", "modifier_breakdown": [],
        }
    var result = _int_policy_resolver.resolve(
        IntQueryRequestScript.new().configure({
            "hook": "rest_multi_select_count_query",
            "owner": growth,
            "subject_kind": "node_interaction",
            "subject_id": str(values.get("interaction_token", "")),
            "base_value": 1,
            "metadata": {
                "interaction_kind": str(values.get(
                    "interaction_kind", "")),
                "node_type": str(values.get("node_type", "")),
                "candidate_count": candidate_count,
            },
        }))
    var resolved: Dictionary = result.to_dict()
    if not resolved.get("success", false):
        return _failure("节点多选次数查询失败：%s" % "；".join(
            resolved.get("errors", [])))
    if int(resolved.get("effective_value", 0)) < 1:
        return _failure("节点多选次数必须至少为1")
    return resolved

func _refresh_interaction(growth) -> Dictionary:
    var handler_result: Dictionary = handler_registry.require_handler(
        str(_pending.get("interaction_kind", "")))
    if not handler_result.get("success", false):
        return handler_result
    var context = ContextScript.new(_pending, growth, content_catalog)
    var prepared = handler_result["handler"].prepare(context)
    if not prepared is Dictionary \
            or (prepared.has("success") and not prepared.get("success", false)):
        return _failure(str(prepared.get(
            "reason", "节点交互重新准备失败")) if prepared is Dictionary \
            else "节点交互重新准备结果无效")
    var choices = prepared.get("choices", [])
    if not choices is Array:
        return _failure("节点交互重新准备 choices 必须是数组")
    var by_id: Dictionary = {}
    for choice in choices:
        if choice is Dictionary:
            by_id[str(choice.get("id", ""))] = choice.duplicate(true)
    var remaining: Array = []
    for choice_id in _pending.get("initial_choice_ids", []):
        if _pending.get("selected_choice_ids", []).has(choice_id) \
                or not by_id.has(choice_id):
            continue
        var choice: Dictionary = by_id[choice_id]
        if bool(choice.get("enabled", true)):
            remaining.append(choice)
    var dto: Dictionary = _pending.get("interaction", {}).duplicate(true)
    dto["choices"] = remaining
    dto["selected_choice_ids"] = _pending.get(
        "selected_choice_ids", []).duplicate()
    dto["minimum_choices"] = int(_pending.get("minimum_choices", 1))
    dto["maximum_choices"] = int(_pending.get("maximum_choices", 1))
    dto["allow_finish"] = bool(_pending.get("allow_finish", false)) \
        and dto["selected_choice_ids"].size() >= dto["minimum_choices"]
    dto["session_serial"] = int(_pending.get("session_serial", 0))
    dto["policy_fingerprint"] = str(_pending.get(
        "policy_fingerprint", ""))
    var dto_error := validate_frozen_dto(dto)
    if dto_error != "":
        return _failure(dto_error)
    _pending["interaction"] = dto
    return {"success": true, "interaction": dto.duplicate(true)}

func _should_auto_complete() -> bool:
    return _pending.get("selected_choice_ids", []).size() >= int(
        _pending.get("maximum_choices", 1)) \
        or _pending.get("interaction", {}).get("choices", []).is_empty()

static func _enabled_choice_ids(dto: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for choice in dto.get("choices", []):
        if choice is Dictionary and bool(choice.get("enabled", true)):
            result.append(str(choice.get("id", "")))
    return result

static func normalize_pending_snapshot(snapshot: Dictionary) -> Dictionary:
    var result := snapshot.duplicate(true)
    if int(result.get("schema_version", 0)) != 1:
        return result
    var dto: Dictionary = result.get("interaction", {}).duplicate(true)
    var initial_ids := _enabled_choice_ids(dto)
    dto["minimum_choices"] = mini(1, initial_ids.size())
    dto["maximum_choices"] = mini(1, initial_ids.size())
    dto["selected_choice_ids"] = []
    dto["allow_finish"] = false
    dto["session_serial"] = 1
    dto["policy_fingerprint"] = "legacy_single_choice"
    result.merge({
        "schema_version": SCHEMA_VERSION,
        "interaction": dto,
        "initial_choice_ids": initial_ids,
        "selected_choice_ids": [],
        "maximum_choices": mini(1, initial_ids.size()),
        "minimum_choices": mini(1, initial_ids.size()),
        "allow_finish": false,
        "policy_fingerprint": "legacy_single_choice",
        "policy_breakdown": [],
        "session_serial": 1,
    }, true)
    return result

static func validate_pending_session_state(snapshot: Dictionary) -> String:
    var initial = snapshot.get("initial_choice_ids", [])
    var selected = snapshot.get("selected_choice_ids", [])
    if not initial is Array or not selected is Array:
        return "pending interaction 初始／已选集合必须是数组"
    var seen: Dictionary = {}
    for choice_id in initial:
        var stable_id := str(choice_id)
        if stable_id == "" or seen.has(stable_id):
            return "pending interaction 初始候选包含空值或重复值"
        seen[stable_id] = true
    var selected_seen: Dictionary = {}
    for choice_id in selected:
        var stable_id := str(choice_id)
        if not seen.has(stable_id) or selected_seen.has(stable_id):
            return "pending interaction 已选顺序包含非法或重复选项"
        selected_seen[stable_id] = true
    var maximum := int(snapshot.get("maximum_choices", 0))
    var minimum := int(snapshot.get("minimum_choices", 0))
    if minimum < 0 or maximum < minimum or maximum > initial.size() \
            or selected.size() > maximum:
        return "pending interaction 多选数量范围无效"
    if str(snapshot.get("policy_fingerprint", "")) == "" \
            or int(snapshot.get("session_serial", 0)) <= 0:
        return "pending interaction 缺少策略指纹或会话序号"
    return ""

static func _is_json_value(value) -> bool:
    if value == null or value is bool or value is int \
            or value is float or value is String:
        return true
    if value is Array:
        for child in value:
            if not _is_json_value(child):
                return false
        return true
    if value is Dictionary:
        for key in value:
            if not key is String or not _is_json_value(value[key]):
                return false
        return true
    return false

func _context_values(
        dispatch: Dictionary,
        interaction: Dictionary,
        source_context: Dictionary) -> Dictionary:
    var source_kind := str(source_context.get("source_kind", "map_node"))
    var source_id := str(source_context.get(
        "source_id", dispatch.get("node_id", "")))
    return {
        "source_kind": source_kind,
        "source_id": source_id,
        "node_id": str(dispatch.get("node_id", "")),
        "node_type": str(dispatch.get("node_type", "")),
        "content_id": str(dispatch.get("content_id", "")),
        "interaction_kind": str(interaction.get("kind", "")),
        "act": int(dispatch.get("act", 1)),
        "run_seed": int(source_context.get(
            "run_seed", source_context.get("seed", 0))),
        "content_seed": int(dispatch.get("content_seed", 0)),
        "configuration": interaction.get("configuration", {}).duplicate(true),
    }

func _stable_token(values: Dictionary) -> String:
    var stable_fields := [
        int(values.get("run_seed", 0)),
        int(values.get("act", 1)),
        str(values.get("source_kind", "")),
        str(values.get("source_id", "")),
        str(values.get("content_id", "")),
        int(values.get("content_seed", 0)),
        str(values.get("interaction_kind", "")),
    ]
    return "interaction-%s" % JSON.stringify(stable_fields).sha256_text()

func _failure(reason: String) -> Dictionary:
    return {"success": false, "reason": reason}
