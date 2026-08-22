## 经过行为管线给目标添加按伤害类型读取的护盾穿透比例来源。
extends BaseAction

func perform_action() -> void:
	for processor: ActionInterceptorProcessor in _intercept_action():
		var target: BaseCombatant = processor.target
		if target == null or Global.battle_qi_state == null:
			continue
		var side: String = Global.battle_qi_state.get_combatant_side(target)
		if side == "":
			continue
		var configured_types: Array[String] = []
		var types_value: Variant = processor.get_shadowed_action_values("damage_types", [])
		if types_value is Array:
			configured_types.assign(types_value)
		var source_context: Dictionary = processor.get_source_context()
		Global.battle_qi_state.add_shield_penetration(
			side,
			configured_types,
			float(processor.get_shadowed_action_values("penetration_ratio", 0.0)),
			str(processor.get_shadowed_action_values(
				"source_kind", source_context.get("source_kind", "action"))),
			str(processor.get_shadowed_action_values(
				"source_instance_id", source_context.get("source_instance_id", ""))),
			str(processor.get_shadowed_action_values("duration_scope", "battle")),
			int(processor.get_shadowed_action_values("remaining_rounds", -1)),
			int(processor.get_shadowed_action_values("remaining_hits", -1)))

func is_instant_action() -> bool:
	return true
