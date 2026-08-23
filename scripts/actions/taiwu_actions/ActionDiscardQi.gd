## 从指定阵营当前手牌左侧开始弃置真气。
extends BaseAction
class_name ActionDiscardQi

## 执行一次正式真气弃牌。
func perform_action() -> void:
	if Global.battle_qi_state == null:
		return
	var side: String = str(get_action_value("qi_side", ""))
	var discard_count: int = max(int(get_action_value("discard_count", 1)), 0)
	var event_token: String = str(get_action_value("event_token", "qi-discard-action"))
	if Global.battle_qi_state.discard_qi_from_hand(side, discard_count, event_token) > 0:
		Signals.qi_zones_changed.emit()

## 真气弃牌是同步牌区行为。
func is_instant_action() -> bool:
	return true
