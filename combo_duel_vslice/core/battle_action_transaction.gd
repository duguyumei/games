class_name BattleActionTransaction
extends RefCounted

## 一次完整行动的纯状态事务。
##
## 事务只记录已经冻结的事实、阶段和恢复位置；领域规则仍由
## BattleActionService / ActionResolver / BattleEffectPorts 执行。

const SCHEMA_VERSION := 1

const PHASE_FROZEN := "frozen"
const PHASE_RESOLVING := "resolving"
const PHASE_COMMITTING_ZONES := "committing_zones"
const PHASE_POST_COMMIT := "post_commit"
const PHASE_COOPERATION := "cooperation"
const PHASE_COMPLETED := "completed"
const PHASE_FAILED := "failed"

const GROUP_MAIN := "main"
const GROUP_COOPERATION := "cooperation"

const CURSOR_GROUP_EFFECTS := "group_effects"
const CURSOR_POST_COMMIT_EFFECTS := "post_commit_effects"

const RESOLUTION_SOLO := "solo"
const RESOLUTION_SYNCHRONIZED := "synchronized"

const _ALLOWED_TRANSITIONS := {
    PHASE_FROZEN: [PHASE_RESOLVING, PHASE_FAILED],
    PHASE_RESOLVING: [PHASE_COMMITTING_ZONES, PHASE_FAILED],
    PHASE_COMMITTING_ZONES: [PHASE_POST_COMMIT, PHASE_FAILED],
    PHASE_POST_COMMIT: [PHASE_COOPERATION, PHASE_COMPLETED, PHASE_FAILED],
    PHASE_COOPERATION: [PHASE_RESOLVING, PHASE_COMPLETED, PHASE_FAILED],
    PHASE_COMPLETED: [],
    PHASE_FAILED: [],
}

var transaction_id: String = ""
var root_action_token: String = ""
var _phase: String = ""
var suspended: bool = false
var choice_request_id: String = ""
var resume_cursor: String = ""
var resolution_mode: String = ""
var initiator_owner_id: String = ""
var participating_owner_ids: Array[String] = []
var acting_owner_ids: Array[String] = []

## 运行时引用；snapshot() 只公开稳定快照。
var records: Array = []
var previews: Dictionary = {}
var runtime_context: Dictionary = {}

var group_index: int = 0
var group_kind: String = GROUP_MAIN
var cooperation_groups: Array = []
var enemy_will_act: bool = false
var frozen_card_instance_ids: Dictionary = {}
var committed_card_instance_ids: Dictionary = {}
var group_resolution_completed: bool = false
var group_zones_committed: bool = false
var post_commit_completed: bool = false
var frozen_same_qi: Dictionary = {}
var public_results: Dictionary = {}
var failure_reason: Dictionary = {}
var completed_flags: Dictionary = {}
var resolved_choice_request_ids: Array[String] = []


func phase() -> String:
    return _phase


func is_empty() -> bool:
    return transaction_id == ""


func is_active() -> bool:
    return not is_empty() and _phase not in [PHASE_COMPLETED, PHASE_FAILED]


func begin_transaction(values: Dictionary) -> Dictionary:
    if is_active():
        return _failure(
            "transaction_already_active", "当前已有未完成的行动事务")
    if not is_empty():
        return _failure(
            "transaction_not_cleared", "上一行动事务尚未清理")
    var next_transaction_id := str(values.get("transaction_id", ""))
    var next_root_token := str(values.get("root_action_token", ""))
    var next_mode := str(values.get("resolution_mode", ""))
    if next_transaction_id == "" or next_root_token == "":
        return _failure(
            "invalid_transaction_identity", "行动事务缺少稳定标识")
    if next_mode not in [RESOLUTION_SOLO, RESOLUTION_SYNCHRONIZED]:
        return _failure(
            "invalid_resolution_mode", "行动事务结算模式无效")

    transaction_id = next_transaction_id
    root_action_token = next_root_token
    _phase = PHASE_FROZEN
    resolution_mode = next_mode
    initiator_owner_id = str(values.get("initiator_owner_id", ""))
    participating_owner_ids = _string_array(
        values.get("participating_owner_ids", []))
    acting_owner_ids = _string_array(values.get("acting_owner_ids", []))
    records = values.get("records", []).duplicate()
    previews = values.get("previews", {}).duplicate()
    runtime_context = values.get("runtime_context", {}).duplicate()
    cooperation_groups = values.get("cooperation_groups", []).duplicate(true)
    enemy_will_act = bool(values.get("enemy_will_act", false))
    frozen_card_instance_ids = values.get(
        "frozen_card_instance_ids", {}).duplicate(true)
    frozen_same_qi = values.get("frozen_same_qi", {}).duplicate(true)
    completed_flags = values.get("completed_flags", {}).duplicate(true)
    group_index = 0
    group_kind = GROUP_MAIN
    suspended = false
    choice_request_id = ""
    resume_cursor = ""
    group_resolution_completed = false
    group_zones_committed = false
    post_commit_completed = false
    committed_card_instance_ids.clear()
    public_results.clear()
    failure_reason.clear()
    resolved_choice_request_ids.clear()
    return {"success": true, "transaction_id": transaction_id, "phase": _phase}


func advance_phase(next_phase: String) -> Dictionary:
    if not is_active():
        return _failure("transaction_not_active", "当前没有可推进的行动事务")
    if suspended:
        return _failure("transaction_suspended", "等待选择时不能推进事务阶段")
    if next_phase not in _ALLOWED_TRANSITIONS.get(_phase, []):
        return _failure(
            "illegal_phase_transition",
            "非法行动事务转换：%s -> %s" % [_phase, next_phase])
    if next_phase == PHASE_COMMITTING_ZONES and not group_resolution_completed:
        return _failure("group_not_resolved", "当前牌型组尚未完成结算")
    if next_phase == PHASE_POST_COMMIT and not group_zones_committed:
        return _failure("zones_not_committed", "牌区尚未提交，不能进入 post_commit")
    if next_phase in [PHASE_COOPERATION, PHASE_COMPLETED] \
            and _phase == PHASE_POST_COMMIT and not post_commit_completed:
        return _failure("post_commit_not_completed", "post_commit 尚未完成")
    _phase = next_phase
    return {"success": true, "phase": _phase}


func suspend_for_choice(request_id: String, cursor: String) -> Dictionary:
    if not is_active():
        return _failure("transaction_not_active", "当前没有可暂停的行动事务")
    if suspended:
        return _failure("transaction_already_suspended", "行动事务已经暂停")
    if request_id == "":
        return _failure("missing_choice_request_id", "等待选择缺少 request_id")
    if cursor not in [CURSOR_GROUP_EFFECTS, CURSOR_POST_COMMIT_EFFECTS]:
        return _failure("invalid_resume_cursor", "行动事务恢复位置无效")
    if cursor == CURSOR_GROUP_EFFECTS and _phase != PHASE_RESOLVING:
        return _failure("cursor_phase_mismatch", "牌型组效果只能在 resolving 阶段暂停")
    if cursor == CURSOR_POST_COMMIT_EFFECTS and _phase != PHASE_POST_COMMIT:
        return _failure("cursor_phase_mismatch", "提交后效果只能在 post_commit 阶段暂停")
    if resolved_choice_request_ids.has(request_id):
        return _failure("choice_already_resolved", "选择请求已经提交过")
    suspended = true
    choice_request_id = request_id
    resume_cursor = cursor
    return {"success": true, "request_id": request_id, "resume_cursor": cursor}


func validate_resume(request_id: String) -> Dictionary:
    if not is_active():
        return _failure("transaction_not_active", "当前没有可恢复的行动事务")
    if not suspended:
        return _failure("transaction_not_suspended", "行动事务当前没有等待选择")
    if request_id == "" or request_id != choice_request_id:
        return _failure("choice_request_mismatch", "选择 request_id 与当前事务不匹配")
    if resolved_choice_request_ids.has(request_id):
        return _failure("choice_already_resolved", "选择请求已经提交过")
    return {"success": true}


func resume_from_choice(
        request_id: String,
        next_request_id: String = "",
        next_cursor: String = "") -> Dictionary:
    var validation := validate_resume(request_id)
    if not validation.get("success", false):
        return validation
    resolved_choice_request_ids.append(request_id)
    suspended = false
    choice_request_id = ""
    resume_cursor = ""
    if next_request_id != "":
        return suspend_for_choice(
            next_request_id,
            next_cursor if next_cursor != "" else CURSOR_GROUP_EFFECTS)
    return {"success": true, "resumed_request_id": request_id}


func mark_group_resolution_completed() -> Dictionary:
    if not is_active() or _phase != PHASE_RESOLVING or suspended:
        return _failure("invalid_resolution_completion", "当前不能标记牌型组结算完成")
    group_resolution_completed = true
    return {"success": true}


func mark_zones_committed(cards_by_owner: Dictionary) -> Dictionary:
    if not is_active() or _phase != PHASE_COMMITTING_ZONES or suspended:
        return _failure("invalid_zone_commit", "当前不能标记牌区提交完成")
    for owner_id_value in cards_by_owner:
        var owner_id := str(owner_id_value)
        var accumulated: Array = committed_card_instance_ids.get(
            owner_id, []).duplicate()
        for card_id_value in cards_by_owner[owner_id_value]:
            var card_id := str(card_id_value)
            if not accumulated.has(card_id):
                accumulated.append(card_id)
        committed_card_instance_ids[owner_id] = accumulated
    group_zones_committed = true
    return {"success": true}


func mark_post_commit_completed() -> Dictionary:
    if not is_active() or _phase != PHASE_POST_COMMIT or suspended:
        return _failure("invalid_post_commit_completion", "当前不能标记 post_commit 完成")
    post_commit_completed = true
    return {"success": true}


func record_public_results(results: Dictionary) -> Dictionary:
    if not is_active():
        return _failure("transaction_not_active", "当前没有可记录结果的行动事务")
    public_results = _serializable_copy(results)
    return {"success": true}


func begin_cooperation_group(
        next_group_index: int,
        next_records: Array,
        next_previews: Dictionary,
        next_runtime_context: Dictionary = {}) -> Dictionary:
    if not is_active() or _phase != PHASE_COOPERATION or suspended:
        return _failure("invalid_cooperation_start", "当前不能进入协同牌型组")
    if next_group_index <= group_index:
        return _failure("invalid_group_index", "协同牌型组序号必须递增")
    group_index = next_group_index
    group_kind = GROUP_COOPERATION
    records = next_records.duplicate()
    previews = next_previews.duplicate()
    runtime_context = next_runtime_context.duplicate()
    group_resolution_completed = false
    group_zones_committed = false
    post_commit_completed = false
    committed_card_instance_ids.clear()
    return advance_phase(PHASE_RESOLVING)


func complete_transaction(results: Dictionary = {}) -> Dictionary:
    if not is_active():
        return _failure("transaction_not_active", "当前没有可完成的行动事务")
    if suspended:
        return _failure("transaction_suspended", "等待选择时不能完成行动事务")
    if _phase == PHASE_POST_COMMIT:
        if not post_commit_completed:
            return _failure("post_commit_not_completed", "post_commit 尚未完成")
    elif _phase != PHASE_COOPERATION:
        return _failure("illegal_phase_transition", "当前阶段不能完成行动事务")
    public_results = _serializable_copy(results)
    _phase = PHASE_COMPLETED
    return {"success": true, "phase": _phase}


func fail_transaction(reason, code: String = "transaction_failed") -> Dictionary:
    if is_empty():
        return _failure("transaction_not_active", "当前没有可失败关闭的行动事务")
    if _phase in [PHASE_COMPLETED, PHASE_FAILED]:
        return _failure("terminal_transaction", "终态行动事务不能再次转换")
    failure_reason = {
        "code": code,
        "reason": str(reason),
        "phase": _phase,
        "group_index": group_index,
        "group_kind": group_kind,
    }
    suspended = false
    choice_request_id = ""
    resume_cursor = ""
    _phase = PHASE_FAILED
    return {"success": true, "phase": _phase, "failure": failure_reason.duplicate(true)}


func clear_transaction(force: bool = false) -> Dictionary:
    if not is_empty() and not force and _phase not in [PHASE_COMPLETED, PHASE_FAILED]:
        return _failure("transaction_not_terminal", "未完成事务不能直接清理")
    transaction_id = ""
    root_action_token = ""
    _phase = ""
    suspended = false
    choice_request_id = ""
    resume_cursor = ""
    resolution_mode = ""
    initiator_owner_id = ""
    participating_owner_ids.clear()
    acting_owner_ids.clear()
    records.clear()
    previews.clear()
    runtime_context.clear()
    group_index = 0
    group_kind = GROUP_MAIN
    cooperation_groups.clear()
    enemy_will_act = false
    frozen_card_instance_ids.clear()
    committed_card_instance_ids.clear()
    group_resolution_completed = false
    group_zones_committed = false
    post_commit_completed = false
    frozen_same_qi.clear()
    public_results.clear()
    failure_reason.clear()
    completed_flags.clear()
    resolved_choice_request_ids.clear()
    return {"success": true}


func snapshot() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "transaction_id": transaction_id,
        "root_action_token": root_action_token,
        "phase": _phase,
        "suspended": suspended,
        "choice_request_id": choice_request_id,
        "resume_cursor": resume_cursor,
        "resolution_mode": resolution_mode,
        "initiator_owner_id": initiator_owner_id,
        "participating_owner_ids": participating_owner_ids.duplicate(),
        "acting_owner_ids": acting_owner_ids.duplicate(),
        "records": records.map(func(record): return _record_snapshot(record)),
        "previews": _serializable_copy(previews),
        "group_index": group_index,
        "group_kind": group_kind,
        "cooperation_groups": _serializable_copy(cooperation_groups),
        "enemy_will_act": enemy_will_act,
        "frozen_card_instance_ids": frozen_card_instance_ids.duplicate(true),
        "committed_card_instance_ids": committed_card_instance_ids.duplicate(true),
        "group_resolution_completed": group_resolution_completed,
        "group_zones_committed": group_zones_committed,
        "post_commit_completed": post_commit_completed,
        "frozen_same_qi": _serializable_copy(frozen_same_qi),
        "public_results": _serializable_copy(public_results),
        "failure_reason": failure_reason.duplicate(true),
        "completed_flags": _serializable_copy(completed_flags),
    }


func _record_snapshot(record) -> Dictionary:
    if record != null and record.has_method("snapshot"):
        return _serializable_copy(record.snapshot())
    if record is Dictionary:
        return _serializable_copy(record)
    return {}


func _serializable_copy(value):
    var value_type := typeof(value)
    if value_type in [
            TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING,
            TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3,
            TYPE_VECTOR3I, TYPE_COLOR]:
        return value
    match value_type:
        TYPE_ARRAY:
            var array_result: Array = []
            for item in value:
                var sanitized = _serializable_copy(item)
                if sanitized != null or item == null:
                    array_result.append(sanitized)
            return array_result
        TYPE_DICTIONARY:
            var dictionary_result: Dictionary = {}
            for key in value:
                var sanitized = _serializable_copy(value[key])
                if sanitized != null or value[key] == null:
                    dictionary_result[str(key)] = sanitized
            return dictionary_result
        TYPE_OBJECT:
            if value == null:
                return null
            if value.has_method("snapshot"):
                return _serializable_copy(value.snapshot())
            if value.has_method("to_dict"):
                return _serializable_copy(value.to_dict())
            var owner_id = _object_property(value, "owner_id")
            if owner_id != null and str(owner_id) != "":
                return {"owner_id": str(owner_id)}
            var instance_id = _object_property(value, "id")
            if instance_id != null and str(instance_id) != "":
                return {"id": str(instance_id)}
            return null
        TYPE_CALLABLE, TYPE_SIGNAL:
            return null
    return null


func _object_property(value: Object, property_name: String):
    for property in value.get_property_list():
        if str(property.get("name", "")) == property_name:
            return value.get(property_name)
    return null


func _string_array(values: Array) -> Array[String]:
    var result: Array[String] = []
    for value in values:
        result.append(str(value))
    return result


func _failure(code: String, reason: String) -> Dictionary:
    return {"success": false, "code": code, "reason": reason}
