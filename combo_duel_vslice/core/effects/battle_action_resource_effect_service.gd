class_name BattleActionResourceEffectService
extends RefCounted

## BattleEffectPorts 内部的行动机会与战斗临时收益写入服务。
##
## 本服务不推进 BattleActionService 事务，也不计算同气容量或内容随机候选；它只把
## 已确定的效果结果写入 BattleFlowCoordinator、BattleSide 和统一内容目录，并通过
## VisibleTriggerQueue 的窄入口保留既有历史。

var _battle_flow
var _trigger_queue
var _consumable_repository
var _query_service
var _committed_event_service
var _round_reader: Callable


func _init(battle_flow, trigger_queue) -> void:
    assert(battle_flow != null,
        "BattleActionResourceEffectService requires BattleFlowCoordinator")
    assert(trigger_queue != null,
        "BattleActionResourceEffectService requires VisibleTriggerQueue")
    _battle_flow = battle_flow
    _trigger_queue = trigger_queue


func use_trigger_queue(trigger_queue) -> void:
    assert(trigger_queue != null,
        "BattleActionResourceEffectService requires VisibleTriggerQueue")
    _trigger_queue = trigger_queue


func use_consumable_repository(repository) -> void:
    assert(repository != null,
        "BattleActionResourceEffectService requires ConsumableRepository")
    _consumable_repository = repository

func use_passive_battle_services(
        query_service,
        committed_event_service,
        round_reader: Callable = Callable()) -> void:
    _query_service = query_service
    _committed_event_service = committed_event_service
    _round_reader = round_reader


func gain_extra_actions(
        side,
        amount: int,
        source: String,
        source_category: String = "rule",
        action_token: String = "") -> int:
    var gained: int = _battle_flow.grant_actions(side, amount, {
        "category": source_category,
        "source": source,
        "action_token": action_token,
        "from_same_qi": source_category == "same_qi",
    })
    add_history(
        "action_end",
        "%s额外出牌机会" % side.name,
        source,
        "成功",
        "+%d（连击不自动补牌）" % gained)
    return gained


func gain_battle_experience(
        side,
        amount: int,
        source: Dictionary = {}) -> Dictionary:
    var requested := maxi(0, amount)
    if requested == 0:
        return {"success": true, "skipped": true, "actual_delta": 0}
    var action_token := str(source.get("action_token", ""))
    var operation_token := str(source.get("operation_token", ""))
    if operation_token == "":
        operation_token = "%s:%s:%s:%d" % [
            action_token,
            str(source.get("source_instance_key", source.get("source_id", "rule"))),
            str(source.get("effect_execution_token", "experience")),
            requested,
        ]
    if side.experience_operation_receipts.has(operation_token):
        var duplicate: Dictionary = side.experience_operation_receipts[
            operation_token].duplicate(true)
        duplicate["success"] = true
        duplicate["duplicate"] = true
        return duplicate
    var query_values := {
        "success": true,
        "base_value": requested,
        "effective_value": requested,
        "modifier_breakdown": [],
        "source_fingerprint": "unconfigured",
    }
    if _query_service != null:
        var query = _query_service.resolve_values({
            "hook": "experience_gain_query",
            "owner": side,
            "actor": side,
            "subject_kind": "battle_resource",
            "subject_id": "experience",
            "base_value": requested,
            "round_number": _round_number(),
            "action_token": action_token,
            "source_kind": str(source.get("source_kind", "battle_effect")),
            "metadata": {
                "requested_gain": requested,
                "operation_token": operation_token,
            },
        })
        query_values = query.to_dict()
        if not query.success:
            _query_service.report_failure(query, "battle_experience_gain")
            return {"success": false, "reason": "战斗历练获得查询失败",
                "query": query_values}
    var gained := int(query_values.get("effective_value", requested))
    if gained < 0 or gained > requested:
        return {"success": false, "reason": "战斗历练获得结果超出请求范围"}
    var before := int(side.experience)
    side.experience = before + gained
    var event_token := ""
    var committed: Dictionary = {"success": true, "skipped": true}
    if _committed_event_service != null:
        event_token = _committed_event_service.make_token(
            "experience_change_resolved", side,
            _committed_event_service.next_serial(), action_token)
        committed = _committed_event_service.commit(
            "experience_change_resolved", {
                "event_token": event_token,
                "actor": side,
                "target": side,
                "holder": side,
                "holder_id": str(side.owner_id),
                "scope": "battle",
                "requested_delta": requested,
                "actual_delta": gained,
                "experience_before": before,
                "experience_after": int(side.experience),
                "direction": "gain",
                "prevented_amount": requested - gained,
                "changed": gained != 0,
                "operation": "gain_battle_experience",
                "operation_token": operation_token,
                "root_execution_token": str(source.get(
                    "root_execution_token", action_token)),
                "action_token": action_token,
                "round_number": _round_number(),
                "source_kind": str(source.get("source_kind", "battle_effect")),
                "source_id": str(source.get("source_id", "")),
                "source_name": str(source.get("source_name", "")),
                "source_instance_key": str(source.get("source_instance_key", "")),
                "trigger_mode": str(source.get("trigger_mode", "direct")),
                "payload": {
                    "experience_response_ancestry": source.get(
                        "experience_response_ancestry", []).duplicate(),
                },
            })
        if not committed.get("success", false):
            side.experience = before
            return {"success": false, "reason": str(committed.get(
                "reason", "战斗历练事实提交失败")), "committed": committed}
    var receipt := {
        "success": true,
        "duplicate": false,
        "scope": "battle",
        "requested_delta": requested,
        "actual_delta": gained,
        "experience_before": before,
        "experience_after": int(side.experience),
        "prevented_amount": requested - gained,
        "operation_token": operation_token,
        "event_token": event_token,
        "query": query_values,
        "committed": committed,
    }
    side.experience_operation_receipts[operation_token] = receipt.duplicate(true)
    return receipt


func can_grant_battle_consumable(side) -> bool:
    var result: Dictionary = side.effective_consumable_capacity_result()
    return result.get("success", false) \
        and int(result.get("available_slots", 0)) > 0


func grant_battle_consumable(side, consumable_id: String) -> bool:
    return side.grant_consumable(consumable_id)


func consumable_ids_by_kind(kind: String) -> Array[String]:
    assert(_consumable_repository != null,
        "BattleActionResourceEffectService consumable repository is not assembled")
    return _consumable_repository.ids_by_kind(kind)


func add_history(
        timing: String,
        label: String,
        source: String,
        result: String,
        detail: String = "") -> void:
    _trigger_queue.add_history(timing, label, source, result, detail)

func _round_number() -> int:
    return int(_round_reader.call()) if _round_reader.is_valid() else 0
