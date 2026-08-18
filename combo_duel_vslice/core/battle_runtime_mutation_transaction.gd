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
        rng: RandomNumberGenerator = null) -> Dictionary:
    var snapshot := capture(
        sides, committed_event_service, trigger_queue, rng)
    if committed_event_service != null:
        committed_event_service.begin_publication_transaction()
    return {
        "success": true,
        "snapshot": snapshot,
        "committed_event_service": committed_event_service,
        "trigger_queue": trigger_queue,
        "rng": rng,
    }


static func capture(
        sides: Array,
        committed_event_service,
        trigger_queue,
        rng: RandomNumberGenerator = null) -> Dictionary:
    var side_states: Array = []
    for side in sides:
        if side != null:
            side_states.append({
                "side": side,
                "state": side.capture_passive_query_state(),
            })
    return {
        "side_states": side_states,
        "event_state": committed_event_service.capture_transaction_state() \
            if committed_event_service != null else {},
        "trigger_state": trigger_queue.capture_runtime_state() \
            if trigger_queue != null and trigger_queue.has_method(
                "capture_runtime_state") else {},
        "rng_state": int(rng.state) if rng != null else -1,
    }


static func commit(transaction: Dictionary) -> Dictionary:
    var event_service = transaction.get("committed_event_service")
    if event_service != null:
        event_service.commit_publication_transaction()
    return {"success": true}


static func rollback(transaction: Dictionary) -> bool:
    var event_service = transaction.get("committed_event_service")
    if event_service != null:
        event_service.rollback_publication_transaction()
    return restore(
        transaction.get("snapshot", {}),
        event_service,
        transaction.get("trigger_queue"),
        transaction.get("rng"))


static func restore(
        snapshot: Dictionary,
        committed_event_service,
        trigger_queue,
        rng: RandomNumberGenerator = null) -> bool:
    for entry in snapshot.get("side_states", []):
        var side = entry.get("side")
        if side != null:
            side.replace_passive_query_state(entry.get("state", {}))
    if committed_event_service != null:
        committed_event_service.restore_transaction_state(
            snapshot.get("event_state", {}))
    if trigger_queue != null and trigger_queue.has_method("restore_runtime_state"):
        trigger_queue.restore_runtime_state(snapshot.get("trigger_state", {}))
    var rng_state := int(snapshot.get("rng_state", -1))
    if rng != null and rng_state >= 0:
        rng.state = rng_state
    return true
