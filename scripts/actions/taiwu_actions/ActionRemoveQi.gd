## 经过行为管线移除一张指定实例的真气。
extends BaseAction

## 按实例 UID 移除真气，未知实例不会修改本局。
func perform_action() -> void:
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		var qi_instance_uid: String = processor.get_shadowed_action_values(
			"qi_instance_uid", "")
		Global.player_data.remove_qi_instance(qi_instance_uid)

## 真气移除属于即时数据行为。
func is_instant_action() -> bool:
	return true
