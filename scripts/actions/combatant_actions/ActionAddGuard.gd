## 经过行为管线给目标添加若干次下一段直接伤害格挡。
extends BaseAction

func perform_action() -> void:
	for processor: ActionInterceptorProcessor in _intercept_action():
		var target: BaseCombatant = processor.target
		if target == null or Global.battle_qi_state == null:
			continue
		var side: String = Global.battle_qi_state.get_combatant_side(target)
		if side == "":
			continue
		var source_context: Dictionary = processor.get_source_context()
		Global.battle_qi_state.add_guard(
			side,
			int(processor.get_shadowed_action_values("guard_count", 1)),
			str(processor.get_shadowed_action_values(
				"source_kind", source_context.get("source_kind", "action"))),
			str(processor.get_shadowed_action_values(
				"source_instance_id", source_context.get("source_instance_id", ""))),
			str(processor.get_shadowed_action_values("duration_scope", "battle")),
			int(processor.get_shadowed_action_values("remaining_rounds", -1)),
			int(processor.get_shadowed_action_values("remaining_hits", -1)))

func is_instant_action() -> bool:
	return true
