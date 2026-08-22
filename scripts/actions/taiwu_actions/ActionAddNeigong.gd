## 经过行为管线获得内功；重复获得时创建新的独立实例。
extends BaseAction
class_name ActionAddNeigong

## 以预览模式执行相同拦截器，纯查询当前是否允许获得这门内功。
func can_add() -> bool:
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([], true)
	if processors.is_empty():
		return false
	return _can_add_with_processor(processors[0])

## 使用一份拦截结果校验固定定义和重复获得权限。
func _can_add_with_processor(processor: ActionInterceptorProcessor) -> bool:
	var neigong_object_id: String = processor.get_shadowed_action_values(
		"neigong_object_id", "")
	var definition: NeigongData = Global.get_neigong_data(neigong_object_id)
	if definition == null or not definition.is_valid_neigong():
		return false
	return Global.player_data.get_owned_neigong_by_definition_id(
		neigong_object_id).is_empty() or processor.get_shadowed_action_values(
		"allow_duplicate", false)

## 默认禁止同定义重复获得，拦截器可将 allow_duplicate 改为 true。
func perform_action() -> void:
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		if not _can_add_with_processor(processor):
			return
		var neigong_object_id: String = processor.get_shadowed_action_values(
			"neigong_object_id", "")
		var allow_duplicate: bool = processor.get_shadowed_action_values(
			"allow_duplicate", false)
		if not allow_duplicate and not Global.player_data.get_owned_neigong_by_definition_id(
				neigong_object_id).is_empty():
			return
		var neigong_data: NeigongData = Global.get_neigong_data_from_prototype(
			neigong_object_id)
		if neigong_data != null:
			Global.player_data.add_neigong_instance(neigong_data)
		return

## 内功获得属于即时数据行为。
func is_instant_action() -> bool:
	return true
