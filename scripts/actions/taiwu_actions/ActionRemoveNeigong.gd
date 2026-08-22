## 经过行为管线移除一个指定实例的内功。
extends BaseAction

## 按实例 UID 移除内功；对应装备引用由 PlayerData 同步清理。
func perform_action() -> void:
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		var neigong_instance_uid: String = processor.get_shadowed_action_values(
			"neigong_instance_uid", "")
		Global.player_data.remove_neigong_instance(neigong_instance_uid)

## 内功移除属于即时数据行为。
func is_instant_action() -> bool:
	return true
