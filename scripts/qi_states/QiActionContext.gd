## 真气动作与状态处理器共用的执行上下文。
##
## 它把「动作要用到的外部能力」收在一处：查找真气、入队后续动作、发出事件。
## 处理器与动作都不直接持有战斗控制器，因此易于单独测试。
extends RefCounted
class_name QiActionContext

## 本场战斗的真气容器。
var battle_state: BattleQiState = null


static func create(state: BattleQiState) -> QiActionContext:
	var ctx := QiActionContext.new()
	ctx.battle_state = state
	return ctx


## 按 UID 查找真气。
func find_qi(qi_uid: String) -> QiData:
	if battle_state == null:
		return null
	return battle_state.find_qi(qi_uid)


## 入队一笔间接伤害。
##
## 间接伤害跳过格挡、化劲与岩障，只被护体罡气抵挡。毒发与反震都走这里。
##
## TODO: 伤害系统尚未实现。接上之后此处应构造伤害动作并入队，
## 由队列统一处理防御结算、反震触发与死亡检查。
func enqueue_indirect_damage(target_side: int, amount: int, source: ActionSource) -> void:
	if amount <= 0:
		return
	push_warning("QiActionContext: 伤害系统未接入，间接伤害 %d 未结算（目标 %d，来源 %s）。" % [
		amount, target_side, source.get_debug_text() if source != null else "?",
	])
