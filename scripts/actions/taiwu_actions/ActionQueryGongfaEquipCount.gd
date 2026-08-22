## 通过预览拦截器查询一门功法当前有效可配置次数，不产生任何副作用。
extends BaseAction
class_name ActionQueryGongfaEquipCount

## 返回拦截后的非负有效次数；预览拦截器不得修改任何运行状态。
func query_effective_count() -> int:
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([], true)
	if processors.is_empty():
		return max(get_action_value("gongfa_equip_count", 0), 0)
	return max(processors[0].get_shadowed_action_values(
		"gongfa_equip_count", get_action_value("gongfa_equip_count", 0)), 0)

## 查询行为不会被加入执行队列；保留空实现防止误调用产生状态修改。
func perform_action() -> void:
	pass
