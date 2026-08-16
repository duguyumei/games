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


func gain_battle_experience(side, amount: int) -> int:
    var gained := maxi(0, amount)
    side.experience += gained
    return gained


func can_grant_battle_consumable(side) -> bool:
    return side.consumable_ids.size() < side.consumable_limit


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
