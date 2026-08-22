## 经过行为管线一次性替换八种牌型的完整功法配装。
extends BaseAction

## 拦截后的完整候选只有全部校验通过才会提交。
func perform_action() -> void:
	if Global.player_data == null or not Global.player_data.player_waiting_for_node_selection:
		return
	var processors: Array[ActionInterceptorProcessor] = _intercept_action([])
	for processor: ActionInterceptorProcessor in processors:
		var candidate_value: Variant = processor.get_shadowed_action_values(
			"gongfa_hand_sequences", {})
		if candidate_value is Dictionary:
			Global.player_data.set_gongfa_loadout(candidate_value)
		return

## 配装提交属于即时数据行为。
func is_instant_action() -> bool:
	return true
