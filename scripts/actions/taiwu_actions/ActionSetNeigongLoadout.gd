## 经过行为管线一次性替换完整内功装备顺序。
extends BaseAction

## 拦截后的候选只有全部校验通过才会提交。
func perform_action() -> void:
	if Global.player_data == null or not Global.player_data.player_waiting_for_node_selection:
		return
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		var candidate_value: Variant = processor.get_shadowed_action_values(
			"equipped_neigong_uids", [])
		if candidate_value is Array:
			var candidate_uids: Array[String] = []
			candidate_uids.assign(candidate_value)
			Global.player_data.set_neigong_loadout(candidate_uids)
		return

## 配装提交属于即时数据行为。
func is_instant_action() -> bool:
	return true
