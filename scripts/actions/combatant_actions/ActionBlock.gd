## 标准护盾行为；每次执行都会以独立来源条目加入 BattleQiState。
## 如果行为没有显式目标，请在配置中使用 PARENT 目标覆盖。
extends BaseAction

func perform_action():
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action()
	
	for action_interceptor_processor in action_interceptor_processors:
		var target: BaseCombatant = action_interceptor_processor.target
		if target == null:
			return

		var shield_amount: int = action_interceptor_processor.get_shadowed_action_values(
			"shield", action_interceptor_processor.get_shadowed_action_values("block", 0))
		var source_context: Dictionary = action_interceptor_processor.get_source_context()
		var source_kind: String = str(action_interceptor_processor.get_shadowed_action_values(
			"source_kind", source_context.get("source_kind", "action")))
		var source_instance_id: String = str(action_interceptor_processor.get_shadowed_action_values(
			"source_instance_id", source_context.get("source_instance_id", "")))
		var duration_scope: String = str(action_interceptor_processor.get_shadowed_action_values(
			"duration_scope", "battle"))
		var remaining_rounds: int = int(action_interceptor_processor.get_shadowed_action_values(
			"remaining_rounds", -1))
		var remaining_hits: int = int(action_interceptor_processor.get_shadowed_action_values(
			"remaining_hits", -1))
		var decay_policy: String = str(action_interceptor_processor.get_shadowed_action_values(
			"decay_policy", "halve"))
		target.add_shield(
			shield_amount,
			source_kind,
			source_instance_id,
			duration_scope,
			remaining_rounds,
			remaining_hits,
			decay_policy)

func _to_string():
	var shield: int = get_action_value("shield", get_action_value("block", 0))
	return "Shield Action: " + str(shield)
