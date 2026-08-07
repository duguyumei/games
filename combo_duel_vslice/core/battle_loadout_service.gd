class_name BattleLoadoutService
extends RefCounted

## 战斗内配装顺序。
##
## 这里只负责功法结算位在已装备内功之间的移动，不执行功法效果、不改牌区，
## 也不决定行动资格。移动被拒绝时返回明确原因，调用方不需要重新推断边界。

var _side: BattleSide
var _trigger_queue: VisibleTriggerQueue
var _has_pending_choice: Callable

func _init(
        side: BattleSide,
        trigger_queue: VisibleTriggerQueue,
        has_pending_choice: Callable) -> void:
    _side = side
    _trigger_queue = trigger_queue
    _has_pending_choice = has_pending_choice

## 移动功法结算位。
##
## `direction` 为正向后移动，为负向前移动，绝对值不影响步长（一次一位）。
## 返回 `success` 与被拒原因，或移动前后的位次。
func move_technique_slot(direction: int) -> Dictionary:
    if _has_pending_choice.call():
        return {"success": false, "reason": "正在等待功法选择，不能调整功法位"}
    if direction == 0:
        return {"success": false, "reason": "功法位移动方向无效"}
    var previous := _side.technique_slot_index
    var next := clampi(
        previous + signi(direction),
        0,
        _side.equipped_inner_skill_ids.size())
    if next == previous:
        return {"success": false, "reason": "功法位已经位于该方向边界"}
    _side.technique_slot_index = next
    _trigger_queue.add_history(
        "loadout_order",
        "调整功法结算位",
        "玩家命令",
        "成功",
        "%d → %d" % [previous, next])
    return {"success": true, "previous": previous, "current": next}
