class_name BattleOutcomeCommitService
extends RefCounted

## 把一次正式战斗结果编排为唯一的 RunAggregateTransaction。
##
## 具体成长、被动、地图、奖励与终局规则仍由 RunSession 已装配的领域服务执行；
## 本服务只规定跨服务顺序和统一失败出口。

const RunAggregateTransactionScript = preload(
    "res://core/run_aggregate_transaction.gd")

func commit(run_session, battle_result, progress_snapshot) -> Dictionary:
    var transaction = RunAggregateTransactionScript.new()
    var begun: Dictionary = transaction.begin(run_session)
    if not begun.get("success", false):
        return begun

    var growth_before: Dictionary = transaction.growth_state_before()
    var outcome: Dictionary = {"success": true}
    var state := str(battle_result.battle_state)

    if state in ["player_victory", "player_defeat"]:
        outcome = run_session._apply_battle_progress_snapshot(progress_snapshot)
        # 战败仍提交生命、消耗品等终局事实，但 BattleSide 上声明为 permanent
        # 的改牌只允许胜利同步；同时本场不成为成功 Run 历史。两项都从聚合
        # 事务的战前 Growth 恢复，随后 battle_completed 仍可按战败结果产生其
        # 自己的合法 Run 变化。
        if outcome.get("success", false) and state != "player_victory":
            outcome = _restore_defeat_excluded_progress(
                run_session, growth_before)
        if outcome.get("success", false):
            outcome = _checkpoint("progress_applied", run_session)
        if outcome.get("success", false):
            outcome = run_session._dispatch_battle_completed_event(
                battle_result)
        if outcome.get("success", false):
            outcome = _checkpoint("battle_completed", run_session)
        if outcome.get("success", false):
            run_session._record_battle_growth_sync_if_changed(growth_before)

    if outcome.get("success", false):
        match state:
            "player_victory":
                run_session._pending_victory_battle_result.clear()
                run_session._pending_victory_battle_result.merge(
                    battle_result.to_dict(), true)
                var act_before: int = run_session.navigation.act
                var completion: Dictionary = (
                    run_session._apply_node_completion_transition())
                outcome = completion
                if completion.get("success", false):
                    var node_checkpoint := _checkpoint(
                        "node_advanced", run_session)
                    if not node_checkpoint.get("success", false):
                        outcome = node_checkpoint
                if outcome.get("success", false):
                    var rewarded: Dictionary = (
                        run_session._create_pending_reward_for_completion(
                        completion, act_before)
                    )
                    outcome = rewarded
                    if rewarded.get("success", false):
                        var reward_checkpoint := _checkpoint(
                            "reward_created", run_session)
                        if not reward_checkpoint.get("success", false):
                            outcome = reward_checkpoint
            "player_defeat", "unresolved_draw", "scenario_error":
                var terminal = run_session._build_terminal_from_battle_result(
                    battle_result)
                if terminal == null:
                    outcome = {
                        "success": false,
                        "reason": "无法建立本局终局结果",
                    }
                else:
                    outcome = _checkpoint("terminal_created", run_session)
                    if outcome.get("success", false):
                        outcome = run_session._apply_terminal_state(
                            terminal, false)
                    if outcome.get("success", false):
                        var terminal_applied: Dictionary = outcome
                        var terminal_checkpoint := _checkpoint(
                            "terminal_applied", run_session)
                        outcome = (
                            terminal_applied
                            if terminal_checkpoint.get("success", false)
                            else terminal_checkpoint)
            _:
                outcome = {"success": false, "reason": "未知战斗终止状态"}

    if not outcome.get("success", false):
        return _rollback_failure(transaction, outcome)

    var committed: Dictionary = transaction.commit()
    if not committed.get("success", false):
        return _rollback_failure(transaction, committed)
    outcome["success"] = true
    outcome["aggregate_committed"] = true
    return outcome

## 契约测试可通过子类覆盖该窄检查点注入跨服务故障；正式实现永远成功。
func _checkpoint(_stage: String, _run_session) -> Dictionary:
    return {"success": true}

func _restore_defeat_excluded_progress(
        run_session, growth_before: Dictionary) -> Dictionary:
    var retained_state: Dictionary = run_session.growth.capture_mutation_state()
    retained_state["run_deck"] = growth_before.get(
        "run_deck", {}).duplicate(true)
    retained_state["run_combat_history_state"] = growth_before.get(
        "run_combat_history_state", {}).duplicate(true)
    var errors: Array[String] = run_session.growth.replace_mutation_state(
        retained_state)
    if not errors.is_empty():
        return {
            "success": false,
            "reason": "战败牌组/历史恢复失败：%s" % "；".join(errors),
        }
    return {"success": true}

func _rollback_failure(transaction, failure: Dictionary) -> Dictionary:
    var rollback: Dictionary = transaction.rollback()
    var reason := str(failure.get("reason", "战斗结果提交失败"))
    if not rollback.get("success", false):
        reason += "；聚合事务回滚失败：%s" % str(rollback.get(
            "reason", "未知恢复错误"))
    return {
        "success": false,
        "reason": reason,
        "rolled_back": rollback.get("success", false),
        "rollback_attempted": true,
        "rollback_errors": rollback.get("errors", []).duplicate(),
        "suppress_rejection_log": true,
    }
