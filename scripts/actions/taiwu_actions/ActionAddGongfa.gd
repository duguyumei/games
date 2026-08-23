## 经过行为管线获得功法；重复获得会增加唯一实例的持有次数。
extends BaseAction
class_name ActionAddGongfa

## 以预览模式执行相同拦截器，纯查询当前是否允许获得这门功法。
func can_add() -> bool:
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([], true)
	if processors.is_empty():
		return false
	return _can_add_with_processor(processors[0])

## 使用一份拦截结果校验固定定义和重复获得权限。
func _can_add_with_processor(processor: ActionInterceptorProcessor) -> bool:
	var gongfa_object_id: String = processor.get_shadowed_action_values(
		"gongfa_object_id", "")
	var definition: GongfaData = Global.get_gongfa_data(gongfa_object_id)
	if definition == null or not definition.is_valid_gongfa():
		return false
	var owned_gongfa: GongfaData = Global.player_data.get_owned_gongfa_by_definition_id(
		gongfa_object_id)
	return owned_gongfa == null or processor.get_shadowed_action_values(
		"allow_duplicate", false)

## 默认禁止重复获得，拦截器可将 allow_duplicate 改为 true。
func perform_action() -> void:
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		if not _can_add_with_processor(processor):
			return
		var gongfa_object_id: String = processor.get_shadowed_action_values(
			"gongfa_object_id", "")
		var allow_duplicate: bool = processor.get_shadowed_action_values(
			"allow_duplicate", false)
		var owned_gongfa: GongfaData = Global.player_data.get_owned_gongfa_by_definition_id(
			gongfa_object_id)
		if owned_gongfa != null:
			if allow_duplicate and owned_gongfa.increase_owned_count(1):
				Signals.player_gongfa_changed.emit()
			return
		var gongfa_data: GongfaData = Global.get_gongfa_data_from_prototype(gongfa_object_id)
		if gongfa_data != null:
			Global.player_data.add_gongfa_instance(gongfa_data)
		return

## 功法获得属于即时数据行为。
func is_instant_action() -> bool:
	return true
