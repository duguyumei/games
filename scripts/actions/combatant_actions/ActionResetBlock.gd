extends BaseAction

func perform_action():
	# 真气战斗的护盾由回合结算器按来源分别衰减；旧的整值清零动作不再介入。
	if Global.battle_qi_state != null:
		return
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action()
	
	for action_interceptor_processor in action_interceptor_processors:
		var target: BaseCombatant = action_interceptor_processor.target
		if target == null:
			return

		target.reset_block()

func _to_string():
	return "Reset Block Action"
