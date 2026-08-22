## 通过预览拦截器查询指定牌型的有效功法槽容量。
extends BaseAction
class_name ActionQueryGongfaSlotCount

## 返回拦截后的非负槽位容量；查询不会修改任何运行状态。
func query_effective_count() -> int:
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([], true)
	if processors.is_empty():
		return max(get_action_value("gongfa_slot_count", 0), 1)
	return max(processors[0].get_shadowed_action_values(
		"gongfa_slot_count", get_action_value("gongfa_slot_count", 0)), 1)

## 查询行为不会被加入执行队列。
func perform_action() -> void:
	pass
