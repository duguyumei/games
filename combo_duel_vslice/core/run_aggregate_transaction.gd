class_name RunAggregateTransaction
extends RefCounted

## 一次 RunSession 业务提交的内存原子边界。
##
## 这里只捕获和恢复状态，不理解胜负、奖励或被动规则。恢复不发送信号、
## 不写日志、不重新执行效果，也不推进任何随机源。事件级 source_snapshot
## 是 dispatch 的局部输入，不是可恢复状态，因此不进入本聚合快照。

var _session = null
var _snapshot: Dictionary = {}
var _active: bool = false

func begin(run_session) -> Dictionary:
    if _active:
        return {"success": false, "reason": "本局聚合事务已经开始"}
    if run_session == null:
        return {"success": false, "reason": "本局聚合事务缺少 RunSession"}
    _session = run_session
    _snapshot = {
        "growth": run_session.growth.capture_mutation_state(),
        "navigation": run_session.navigation.capture_transaction_state(),
        "run_state": run_session._run_state.capture_transaction_state(),
        "pending_reward": run_session._pending_reward,
        "pending_victory_battle_result": (
            run_session._pending_victory_battle_result.duplicate(true)),
        "node_interaction": (
            run_session._node_interaction_service.capture_transaction_state()
            if run_session._node_interaction_service != null else {}),
        "event_queue": run_session._event_queue.duplicate(),
        "event_serial": run_session._event_serial,
        "persistent_change_serial": run_session._persistent_change_serial,
        "game_log": run_session.game_log.capture_runtime_state(),
    }
    _active = true
    return {"success": true}

func growth_state_before() -> Dictionary:
    return _snapshot.get("growth", {}).duplicate(true)

func commit() -> Dictionary:
    if not _active:
        return {"success": false, "reason": "本局聚合事务尚未开始"}
    _active = false
    _snapshot.clear()
    _session = null
    return {"success": true}

func rollback() -> Dictionary:
    if not _active or _session == null:
        return {
            "success": false,
            "reason": "本局聚合事务尚未开始，无法回滚",
            "errors": ["本局聚合事务尚未开始，无法回滚"],
        }
    var errors: Array[String] = []
    var growth_errors: Array[String] = _session.growth.replace_mutation_state(
        _snapshot.get("growth", {}))
    errors.append_array(growth_errors)
    _session.navigation.restore_transaction_state(
        _snapshot.get("navigation", {}))
    _session._run_state.restore_transaction_state(
        _snapshot.get("run_state", {}))
    _session._pending_reward = _snapshot.get("pending_reward")
    _session._pending_victory_battle_result.clear()
    _session._pending_victory_battle_result.merge(
        _snapshot.get("pending_victory_battle_result", {}).duplicate(true), true)
    if _session._node_interaction_service != null:
        _session._node_interaction_service.restore_transaction_state(
            _snapshot.get("node_interaction", {}))
    _session._event_queue.assign(_snapshot.get("event_queue", []))
    _session._event_serial = int(_snapshot.get("event_serial", 0))
    _session._persistent_change_serial = int(
        _snapshot.get("persistent_change_serial", 0))
    _session.game_log.restore_runtime_state(_snapshot.get("game_log", {}))
    _active = false
    _snapshot.clear()
    _session = null
    return {
        "success": errors.is_empty(),
        "reason": "" if errors.is_empty() else "；".join(errors),
        "errors": errors,
    }
