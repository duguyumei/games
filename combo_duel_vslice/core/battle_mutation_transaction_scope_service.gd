class_name BattleMutationTransactionScopeService
extends RefCounted

const RuntimeTransactionScript = preload(
    "res://core/battle_runtime_mutation_transaction.gd")

## 单场战斗内正式 mutation 事务的可重入作用域。
##
## BattleRuntimeMutationTransaction 继续只负责快照、发布事务和恢复算法；本服务
## 只持有当前根事务。最外层 begin 捕获一次，内层 begin 加入根事务，任一内层
## rollback 都会立即恢复根快照并把根事务标记为 rollback-only。

var _side_refs: Array[WeakRef] = []
var _committed_event_service = null
var _trigger_queue = null
var _rng: RandomNumberGenerator = null
var _state_participant_refs: Array[WeakRef] = []

var _active_root: Dictionary = {}
var _open_scope_ids: Array[int] = []
var _scope_serial: int = 0
var _root_begin_count: int = 0
var _joined_begin_count: int = 0
var _root_commit_count: int = 0
var _root_rollback_count: int = 0

func configure(
        sides: Array,
        committed_event_service,
        trigger_queue,
        rng: RandomNumberGenerator = null,
        state_participants: Array = []):
    assert(_active_root.is_empty(),
        "不能在战斗 mutation 事务进行中重新装配作用域服务")
    _side_refs.clear()
    for side in _unique_objects(sides):
        _side_refs.append(weakref(side))
    _committed_event_service = committed_event_service
    _trigger_queue = trigger_queue
    _rng = rng
    _state_participant_refs = _weak_refs(state_participants)
    return self

func use_state_participants(participants: Array) -> void:
    assert(_active_root.is_empty(),
        "不能在战斗 mutation 事务进行中替换事务参与者")
    _state_participant_refs = _weak_refs(participants)

func use_committed_event_service(service) -> void:
    assert(_active_root.is_empty(),
        "不能在战斗 mutation 事务进行中替换 committed 事件服务")
    _committed_event_service = service

func use_trigger_queue(queue) -> void:
    assert(_active_root.is_empty(),
        "不能在战斗 mutation 事务进行中替换触发队列")
    _trigger_queue = queue

func use_rng(rng: RandomNumberGenerator) -> void:
    assert(_active_root.is_empty(),
        "不能在战斗 mutation 事务进行中替换战斗 RNG")
    _rng = rng

func begin(extra_state_participants: Array = []) -> Dictionary:
    var requested_participants := _merge_unique_objects(
        _live_objects(_state_participant_refs), extra_state_participants)
    var scope_id := _scope_serial
    _scope_serial += 1
    if _active_root.is_empty():
        var transaction := RuntimeTransactionScript.begin(
            _battle_sides(), _committed_event_service, _trigger_queue, _rng,
            requested_participants)
        transaction.merge({
            "scope_service": weakref(self),
            "scope_service_instance_id": get_instance_id(),
            "scope_id": scope_id,
            "root_scope_id": scope_id,
            "scope_kind": "root",
            "scope_closed": false,
            "rollback_only": false,
            "underlying_rolled_back": false,
            "captured_participant_ids": _object_ids(requested_participants),
        }, true)
        _active_root = transaction
        _open_scope_ids = [scope_id]
        _root_begin_count += 1
        return transaction

    if bool(_active_root.get("rollback_only", false)):
        return {
            "success": false,
            "reason": "当前战斗 mutation 根事务已经回滚",
            "rolled_back": true,
            "scope_service_instance_id": get_instance_id(),
        }
    var participant_result := _capture_new_participants(
        requested_participants)
    if not participant_result.get("success", false):
        _rollback_underlying(str(participant_result.get(
            "reason", "无法扩展嵌套事务参与者")))
        return participant_result
    var scope := {
        "success": true,
        "scope_service": weakref(self),
        "scope_service_instance_id": get_instance_id(),
        "scope_id": scope_id,
        "root_scope_id": int(_active_root.get("root_scope_id", -1)),
        "scope_kind": "joined",
        "scope_closed": false,
    }
    _open_scope_ids.append(scope_id)
    _joined_begin_count += 1
    return scope

func commit(scope: Dictionary) -> Dictionary:
    var validation := _validate_scope(scope)
    if not validation.get("success", false):
        return validation
    var scope_id := int(scope.get("scope_id", -1))
    var is_root := str(scope.get("scope_kind", "")) == "root"
    if not _close_scope(scope_id):
        _rollback_underlying("战斗 mutation 事务未按后进先出顺序提交")
        if is_root:
            _clear_active_root()
        return {
            "success": false,
            "reason": "战斗 mutation 事务未按后进先出顺序提交",
            "rolled_back": true,
        }
    scope["scope_closed"] = true
    if not is_root:
        return {
            "success": not bool(_active_root.get("rollback_only", false)),
            "joined": true,
            "rollback_only": bool(_active_root.get("rollback_only", false)),
        }
    if bool(_active_root.get("rollback_only", false)):
        _rollback_underlying(str(_active_root.get(
            "rollback_reason", "嵌套事务已经失败")))
        var failure := {
            "success": false,
            "reason": str(_active_root.get(
                "rollback_reason", "嵌套事务已经失败")),
            "rolled_back": true,
            "rollback_only": true,
        }
        _clear_active_root()
        return failure
    var committed: Dictionary = RuntimeTransactionScript.commit_underlying(
        _active_root)
    _root_commit_count += 1
    _clear_active_root()
    return committed

func rollback(scope: Dictionary, reason: String = "") -> bool:
    var validation := _validate_scope(scope)
    if not validation.get("success", false):
        return bool(scope.get("scope_closed", false)) \
            and bool(scope.get("rolled_back", false))
    var scope_id := int(scope.get("scope_id", -1))
    var is_root := str(scope.get("scope_kind", "")) == "root"
    _close_scope_and_children(scope_id)
    scope["scope_closed"] = true
    scope["rolled_back"] = true
    _rollback_underlying(reason if reason != "" else "嵌套事务请求回滚")
    if is_root:
        _clear_active_root()
    return true

func has_active_transaction() -> bool:
    return not _active_root.is_empty()

func current_root_transaction() -> Dictionary:
    return _active_root

func abort_active(reason: String = "战斗 mutation 事务被中止") -> bool:
    if _active_root.is_empty():
        return false
    _rollback_underlying(reason)
    _clear_active_root()
    return true

func diagnostics() -> Dictionary:
    return {
        "active": not _active_root.is_empty(),
        "open_scope_count": _open_scope_ids.size(),
        "root_begin_count": _root_begin_count,
        "joined_begin_count": _joined_begin_count,
        "root_commit_count": _root_commit_count,
        "root_rollback_count": _root_rollback_count,
    }

func reset_diagnostics() -> void:
    assert(_active_root.is_empty(),
        "不能在战斗 mutation 事务进行中重置诊断计数")
    _root_begin_count = 0
    _joined_begin_count = 0
    _root_commit_count = 0
    _root_rollback_count = 0

func _capture_new_participants(participants: Array) -> Dictionary:
    var captured_ids: Array = _active_root.get(
        "captured_participant_ids", [])
    var snapshot: Dictionary = _active_root.get("snapshot", {})
    var participant_states: Array = snapshot.get("participant_states", [])
    for participant in participants:
        if participant == null or not participant.has_method(
                "capture_transaction_state"):
            continue
        var participant_id := int(participant.get_instance_id())
        if captured_ids.has(participant_id):
            continue
        participant_states.append({
            "participant_ref": weakref(participant),
            "state": participant.capture_transaction_state(),
        })
        captured_ids.append(participant_id)
    snapshot["participant_states"] = participant_states
    _active_root["snapshot"] = snapshot
    _active_root["captured_participant_ids"] = captured_ids
    return {"success": true}

func _rollback_underlying(reason: String) -> void:
    if _active_root.is_empty():
        return
    _active_root["rollback_only"] = true
    if reason != "" and str(_active_root.get("rollback_reason", "")) == "":
        _active_root["rollback_reason"] = reason
    var first_rollback := not bool(_active_root.get(
        "underlying_rolled_back", false))
    # 首次回滚后，尚未退出的外层调用栈仍可能执行少量写入。根作用域收口时
    # 必须再次按同一根快照恢复，不能因为 publication 已回滚就跳过状态恢复。
    if first_rollback:
        RuntimeTransactionScript.rollback_underlying(_active_root)
    else:
        RuntimeTransactionScript.restore_underlying_state(_active_root)
    _active_root["underlying_rolled_back"] = true
    _active_root["rolled_back"] = true
    if first_rollback:
        _root_rollback_count += 1

func _validate_scope(scope: Dictionary) -> Dictionary:
    if scope.is_empty() or not bool(scope.get("success", false)):
        return {"success": false, "reason": str(scope.get(
            "reason", "战斗 mutation 事务作用域无效"))}
    if int(scope.get("scope_service_instance_id", -1)) != get_instance_id():
        return {"success": false, "reason": "事务作用域不属于当前战斗"}
    if bool(scope.get("scope_closed", false)):
        return {"success": false, "reason": "事务作用域已经关闭"}
    if _active_root.is_empty() or int(scope.get(
            "root_scope_id", -1)) != int(_active_root.get(
            "root_scope_id", -2)):
        return {"success": false, "reason": "事务根作用域已经失效"}
    return {"success": true}

func _close_scope(scope_id: int) -> bool:
    if _open_scope_ids.is_empty() or _open_scope_ids.back() != scope_id:
        return false
    _open_scope_ids.pop_back()
    return true

func _close_scope_and_children(scope_id: int) -> void:
    var index := _open_scope_ids.find(scope_id)
    if index < 0:
        return
    _open_scope_ids.resize(index)

func _clear_active_root() -> void:
    _active_root = {}
    _open_scope_ids.clear()

func _unique_objects(values: Array) -> Array:
    var result: Array = []
    var ids: Dictionary = {}
    for value in values:
        if value == null or not value is Object:
            continue
        var value_id := int(value.get_instance_id())
        if ids.has(value_id):
            continue
        ids[value_id] = true
        result.append(value)
    return result

func _merge_unique_objects(first: Array, second: Array) -> Array:
    var combined := first.duplicate()
    combined.append_array(second)
    return _unique_objects(combined)

func _object_ids(values: Array) -> Array:
    return values.map(func(value): return int(value.get_instance_id()))

func _weak_refs(values: Array) -> Array[WeakRef]:
    var result: Array[WeakRef] = []
    for value in _unique_objects(values):
        result.append(weakref(value))
    return result

func _live_objects(refs: Array[WeakRef]) -> Array:
    var result: Array = []
    for value_ref in refs:
        var value = value_ref.get_ref()
        if value != null:
            result.append(value)
    return result

func _battle_sides() -> Array:
    var result: Array = []
    for side_ref in _side_refs:
        var side = side_ref.get_ref()
        if side != null:
            result.append(side)
    return result
