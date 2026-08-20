class_name BattleRuntimeMutationTransaction
extends RefCounted

## 战斗内窄粒度 mutation 的共享原子边界。
##
## 它只冻结双方 BattleSide 运行时状态、committed 事件状态、publication、
## TriggerQueue/GameLog 与战斗 RNG。调用方自己的局部序号或作用域仍由调用方保存，
## 本类不承担行动状态机或 EffectExecutor 职责。

static func begin(
        sides: Array,
        committed_event_service,
        trigger_queue,
        rng: RandomNumberGenerator = null,
        state_participants: Array = []) -> Dictionary:
    var snapshot := capture(
        sides, committed_event_service, trigger_queue, rng, state_participants)
    if committed_event_service != null and committed_event_service.has_method(
            "begin_publication_transaction"):
        committed_event_service.begin_publication_transaction()
    return {
        "success": true,
        "snapshot": snapshot,
        "committed_event_service": committed_event_service,
        "trigger_queue": trigger_queue,
        "rng": rng,
        # 事务快照保存状态副本即可；不能反向强持有战斗组合根中的参与者。
        "state_participants": _weak_references(state_participants),
    }


static func capture(
        sides: Array,
        committed_event_service,
        trigger_queue,
        rng: RandomNumberGenerator = null,
        state_participants: Array = []) -> Dictionary:
    var side_states: Array = []
    var captured_status_systems: Dictionary = {}
    for side in sides:
        if side != null:
            var options: Dictionary = {}
            if side.has_method("all_cards_for_run_sync"):
                var status = side.status_system
                var include_status := false
                if status != null:
                    var status_key := str(status.get_instance_id())
                    include_status = not captured_status_systems.has(status_key)
                    if include_status:
                        captured_status_systems[status_key] = true
                options["include_status_system"] = include_status
            side_states.append({
                "side_ref": weakref(side),
                "state": side.capture_transaction_state(options),
            })
    var participant_states: Array = []
    for participant in state_participants:
        if participant != null and participant.has_method(
                "capture_transaction_state"):
            participant_states.append({
                "participant_ref": weakref(participant),
                "state": participant.capture_transaction_state(),
            })
    return {
        "side_states": side_states,
        "event_state": committed_event_service.capture_transaction_state() \
            if committed_event_service != null and committed_event_service.has_method(
                "capture_transaction_state") else {},
        "trigger_state": trigger_queue.capture_runtime_state() \
            if trigger_queue != null and trigger_queue.has_method(
                "capture_runtime_state") else {},
        "has_rng": rng != null,
        "rng_state": int(rng.state) if rng != null else 0,
        "participant_states": participant_states,
    }


static func commit(transaction: Dictionary) -> Dictionary:
    if transaction.has("success") and not bool(transaction.get(
            "success", false)):
        return {
            "success": false,
            "reason": str(transaction.get(
                "reason", "战斗 mutation 事务无效")),
            "rolled_back": bool(transaction.get("rolled_back", false)),
        }
    var scope_service = _scope_service(transaction)
    if scope_service != null:
        return scope_service.commit(transaction)
    return commit_underlying(transaction)


static func commit_underlying(transaction: Dictionary) -> Dictionary:
    var event_service = transaction.get("committed_event_service")
    if event_service != null and event_service.has_method(
            "commit_publication_transaction"):
        event_service.commit_publication_transaction()
    return {"success": true}


static func rollback(transaction: Dictionary) -> bool:
    var scope_service = _scope_service(transaction)
    if scope_service != null:
        return scope_service.rollback(transaction)
    return rollback_underlying(transaction)


static func rollback_underlying(transaction: Dictionary) -> bool:
    var event_service = transaction.get("committed_event_service")
    if event_service != null and event_service.has_method(
            "rollback_publication_transaction"):
        event_service.rollback_publication_transaction()
    return restore_underlying_state(transaction)


static func restore_underlying_state(transaction: Dictionary) -> bool:
    var event_service = transaction.get("committed_event_service")
    return restore(
        transaction.get("snapshot", {}),
        event_service,
        transaction.get("trigger_queue"),
        transaction.get("rng"),
        transaction.get("state_participants", []))


static func _scope_service(transaction: Dictionary):
    var value = transaction.get("scope_service")
    if value is WeakRef:
        return value.get_ref()
    return null


static func restore(
        snapshot: Dictionary,
        committed_event_service,
        trigger_queue,
        rng: RandomNumberGenerator = null,
        _state_participants: Array = []) -> bool:
    for entry in snapshot.get("side_states", []):
        var side = _referenced_object(entry, "side_ref", "side")
        if side != null:
            side.restore_transaction_state(entry.get("state", {}))
    if committed_event_service != null and committed_event_service.has_method(
            "restore_transaction_state") and not snapshot.get(
                "event_state", {}).is_empty():
        committed_event_service.restore_transaction_state(
            snapshot.get("event_state", {}))
    if trigger_queue != null and trigger_queue.has_method("restore_runtime_state"):
        trigger_queue.restore_runtime_state(snapshot.get("trigger_state", {}))
    for entry in snapshot.get("participant_states", []):
        var participant = _referenced_object(
            entry, "participant_ref", "participant")
        if participant != null and participant.has_method(
                "restore_transaction_state"):
            participant.restore_transaction_state(entry.get("state", {}))
    if rng != null and bool(snapshot.get(
            "has_rng", snapshot.has("rng_state"))):
        rng.state = int(snapshot.get("rng_state", rng.state))
    return true


static func _referenced_object(
        entry: Dictionary, weak_key: String, legacy_key: String):
    var value = entry.get(weak_key, entry.get(legacy_key))
    if value is WeakRef:
        return value.get_ref()
    return value


static func _weak_references(values: Array) -> Array:
    var result: Array = []
    for value in values:
        result.append(weakref(value) if value is Object else null)
    return result
