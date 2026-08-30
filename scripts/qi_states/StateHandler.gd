## 一种真气状态在各时点的行为，包括它何时消失。
##
## GDScript 没有接口，因此本类作为基类提供全部时点的空实现，
## 各状态的处理器只覆写自己关心的时点。
##
## 与事件监听的区别：
##   处理器是状态**自身的属性** —— 作用对象固定是携带它的那张真气，
##   且能在动作执行过程中介入。例如毒发必须在移动前结算，
##   因为它造成的气力变化会影响此后读到的数值。
##   事件监听则是功法与内功对已发生变化的外部响应，只能在动作完成后。
##
## 时点用「移动前／移动后 + 传入方向」而非为每个牌区各写一个方法，
## 因此新增状态不需要改运转动作，方向判断交给各处理器自己。
extends RefCounted
class_name StateHandler


## 本处理器负责的状态种类；子类必须覆写。取值见 QiStateEntry.KINDS。
func get_handled_kind() -> int:
	return -1


## ============================================================
## 移动相关时点
## ============================================================

## 移动前。
##
## 毒发在此结算 —— 它造成的气力变化会影响此后读到的数值，
## 因此必须早于真气实际改变牌区。
func before_move(_qi: QiData, _from_zone: int, _to_zone: int, _ctx: QiActionContext, _source: ActionSource) -> void:
	pass

## 移动后。
##
## 到点消失的状态在此移除自己，例如冻结在进入散气后移除。
func after_move(_qi: QiData, _from_zone: int, _to_zone: int, _ctx: QiActionContext, _source: ActionSource) -> void:
	pass

## 从牌库移除前（被消耗）。
func before_remove(_qi: QiData, _from_zone: int, _ctx: QiActionContext, _source: ActionSource) -> void:
	pass


## ============================================================
## 其他时点
## ============================================================

## 被功法读取内力时。
func on_read_value(_qi: QiData, _ctx: QiActionContext, _source: ActionSource) -> void:
	pass

## 回合开始。
func on_round_start(_qi: QiData, _ctx: QiActionContext, _source: ActionSource) -> void:
	pass

## 回合结束。
func on_round_end(_qi: QiData, _ctx: QiActionContext, _source: ActionSource) -> void:
	pass

## 战斗结束。
func on_battle_end(_qi: QiData, _ctx: QiActionContext, _source: ActionSource) -> void:
	pass
