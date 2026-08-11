class_name NodeInteractionService
extends RefCounted

const SCHEMA_VERSION := 1
const ContextScript = preload(
    "res://core/node_interactions/node_interaction_context.gd")
const DTOScript = preload(
    "res://core/node_interactions/node_interaction_dto.gd")
const RegistryScript = preload(
    "res://core/node_interactions/node_interaction_handler_registry.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")

var handler_registry
var mutation_service
var content_catalog
var _pending: Dictionary = {}
var _committed: bool = false

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
    var selected: Dictionary = {}
    for choice_value in _pending.get("interaction", {}).get("choices", []):
        if choice_value is Dictionary and str(choice_value.get("id", "")) == choice_id:
            selected = choice_value
            break
    if selected.is_empty():
        return _failure("未知节点交互选项：%s" % choice_id)
    if not bool(selected.get("enabled", true)):
        return _failure(str(selected.get("disabled_reason", "该节点交互选项不可用")))
    var handler_result: Dictionary = handler_registry.require_handler(
        str(_pending.get("interaction_kind", "")))
    if not handler_result.get("success", false):
        return handler_result
    var context = ContextScript.new(_pending, growth, content_catalog)
    var committed = handler_result["handler"].commit(
        context,
        _pending.get("interaction", {}).duplicate(true),
        choice_id,
        choice_payload.duplicate(true))
    if not committed is Dictionary:
        return _failure("节点交互 commit 必须返回对象")
    if not committed.get("success", false):
        return _failure(str(committed.get("reason", "节点交互提交失败")))
    var effects = committed.get("effects", [])
    if not effects is Array:
        return _failure("节点交互 commit.effects 必须是数组")
    var interaction_result = committed.get("result", {})
    if not interaction_result is Dictionary:
        return _failure("节点交互 commit.result 必须是对象")
    if not _is_json_value(interaction_result):
        return _failure("节点交互 commit.result 包含运行对象")
    var mutation_result: Dictionary = mutation_service.apply_effects(
        effects, growth, {
            "source_kind": str(_pending.get("source_kind", "")),
            "source_id": str(_pending.get("source_id", "")),
            "node_id": str(_pending.get("node_id", "")),
            "interaction_token": token,
        })
    if not mutation_result.get("success", false):
        return mutation_result
    _committed = true
    return {
        "success": true,
        "interaction_result": interaction_result.duplicate(true),
        "applied": mutation_result.get("applied", []).duplicate(true),
        "changed": bool(mutation_result.get("changed", false)),
        "interaction_token": token,
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

func restore_pending(snapshot: Dictionary) -> Dictionary:
    if snapshot.is_empty():
        clear()
        return {"success": true, "restored": false}
    if int(snapshot.get("schema_version", 0)) != SCHEMA_VERSION:
        return _failure("pending interaction schema_version 不受支持")
    var dto = snapshot.get("interaction")
    if not dto is Dictionary:
        return _failure("pending interaction 缺少冻结 interaction DTO")
    var error := validate_frozen_dto(dto)
    if error != "":
        return _failure(error)
    if str(snapshot.get("token", "")) != str(dto.get("interaction_token", "")):
        return _failure("pending interaction token 与 DTO 不一致")
    if not handler_registry.has_handler(str(snapshot.get("interaction_kind", ""))):
        return _failure(
            "未注册的节点交互 kind：%s" % str(snapshot.get("interaction_kind", "")))
    if not snapshot.get("configuration") is Dictionary:
        return _failure("pending interaction configuration 必须是对象")
    if not _is_json_value(snapshot):
        return _failure("pending interaction 包含不可写入 JSON 的运行对象")
    _pending = snapshot.duplicate(true)
    _committed = false
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
