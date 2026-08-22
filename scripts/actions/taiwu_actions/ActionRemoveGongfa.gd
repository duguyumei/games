## 经过行为管线遗忘功法持有次数或移除其唯一实例。
extends BaseAction

## 次数归零时移除实例并清理全部功法槽引用。
func perform_action() -> void:
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		var gongfa_instance_uid: String = processor.get_shadowed_action_values(
			"gongfa_instance_uid", "")
		var remove_count: int = max(processor.get_shadowed_action_values(
			"gongfa_remove_count", 1), 1)
		var gongfa_data: GongfaData = Global.player_data.get_owned_gongfa(
			gongfa_instance_uid)
		if gongfa_data == null or remove_count > gongfa_data.gongfa_owned_count:
			return
		if remove_count == gongfa_data.gongfa_owned_count:
			Global.player_data.remove_gongfa_instance(gongfa_instance_uid)
		elif gongfa_data.decrease_owned_count(remove_count):
			Signals.player_gongfa_changed.emit()
		return

## 功法遗忘属于即时数据行为。
func is_instant_action() -> bool:
	return true
