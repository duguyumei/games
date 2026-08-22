## 经过行为管线获得一张真气实例。
extends BaseAction

## 校验固定定义并创建独立原型实例后加入本局真气牌组。
func perform_action() -> void:
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		var qi_object_id: String = processor.get_shadowed_action_values("qi_object_id", "")
		var qi_data: QiData = Global.get_qi_data_from_prototype(qi_object_id)
		if qi_data != null:
			Global.player_data.add_qi_instance(qi_data)

## 真气获得属于即时数据行为。
func is_instant_action() -> bool:
	return true
