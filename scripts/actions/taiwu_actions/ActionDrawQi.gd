## 从指定阵营真气牌库抽牌；牌库为空时停止且不会自动洗回。
extends BaseAction
class_name ActionDrawQi

## 执行一次正式真气抽牌。
func perform_action() -> void:
	if Global.battle_qi_state == null:
		return
	var side: String = str(get_action_value("qi_side", ""))
	var draw_count: int = max(int(get_action_value("draw_count", 1)), 0)
	if Global.battle_qi_state.draw_qi(side, draw_count) > 0:
		Signals.qi_zones_changed.emit()

## 真气抽牌是同步牌区行为。
func is_instant_action() -> bool:
	return true
