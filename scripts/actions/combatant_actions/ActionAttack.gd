## ActionAttackGenerator 创建的单段攻击行为。
## 所有生命伤害都通过 CombatDamageResolver 处理。
extends BaseAction

func perform_action():
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = _intercept_action()
	
	for action_interceptor_processor in action_interceptor_processors:
		var target: BaseCombatant = action_interceptor_processor.target
		if target == null:
			return
		if not target.is_alive():
			return
		
		# play audio instantly if one is provided
		var audio_path: String = action_interceptor_processor.get_shadowed_action_values("audio_path", "") # sound that plays for every attack
		if audio_path != "":
			ActionGenerator.generate_sound_action(audio_path)
		
		# 伤害类型必须由动作配置明确提供；普通攻击默认是普通直接伤害。
		var damage: int = action_interceptor_processor.get_shadowed_action_values("damage", 0)
		var damage_type: String = str(action_interceptor_processor.get_shadowed_action_values(
			"damage_type", CombatDamageRequest.DAMAGE_NORMAL))
		var source_side: String = str(action_interceptor_processor.get_shadowed_action_values(
			"source_side", _get_source_side()))
		var source_context: Dictionary = action_interceptor_processor.get_source_context()
		var source_kind: String = str(action_interceptor_processor.get_shadowed_action_values(
			"source_kind", source_context.get("source_kind", "action")))
		var source_instance_id: String = str(action_interceptor_processor.get_shadowed_action_values(
			"source_instance_id", source_context.get("source_instance_id", "")))
		var source_effect_id: String = str(action_interceptor_processor.get_shadowed_action_values(
			"source_effect_id", source_context.get("interceptor_id", "")))

		# 伤害结算统一由玩家和敌方的真气战斗状态处理。
		var damages: Array[int] = target.damage(
			damage, damage_type, source_side, source_instance_id, source_effect_id, source_kind)
		var unblocked_damage: int = damages[0]
		var unblocked_damage_capped: int = damages[1]
		var overkill_damage: int = damages[2]
		
		# store unblocked/overkill damage in the CardPlayRequest if it exists.
		# this will accumulate between *all* actions sharing the same CardPlayRequest, thus
		# allowing actions such as healing on damage dealt (unblocked_damage_capped), or
		# an action that provides block based on overkill_damage. These will require providing
		# custom_key_names into the subsequent actions.
		if card_play_request != null:
			var previous_unblocked_damage: int = get_action_value("unblocked_damage", 0)
			card_play_request.card_values["unblocked_damage"] = unblocked_damage + previous_unblocked_damage
			var previous_unblocked_damage_capped: int = get_action_value("unblocked_damage_capped", 0)
			card_play_request.card_values["unblocked_damage_capped"] = unblocked_damage_capped + previous_unblocked_damage_capped
			var previous_overkill_damage: int = get_action_value("overkill_damage", 0)
			card_play_request.card_values["overkill_damage"] = overkill_damage + previous_overkill_damage
		
		# target killed by attack, perform on-lethal actions if they exist
		if not target.is_alive():
			# apply actions on lethal
			var actions_on_lethal: Array[Dictionary] = []
			actions_on_lethal.assign(get_action_value("actions_on_lethal", []))
			if len(actions_on_lethal) > 0:
				var generated_on_lethal_actions: Array[BaseAction] = ActionGenerator.create_actions(parent_combatant, card_play_request, [target], actions_on_lethal, self)
				ActionHandler.add_actions(generated_on_lethal_actions)

func is_action_short_circuited():
	return get_action_value("action_short_circuits", true)

func _to_string():
	var damage: int = get_action_value("damage", 0)
	return "Attack Action: " + str(damage)

## 从动作拥有者推导伤害来源阵营。
func _get_source_side() -> String:
	if parent_combatant != null and parent_combatant.is_in_group("players"):
		return BattleQiState.SIDE_PLAYER
	if parent_combatant != null and parent_combatant.is_in_group("enemies_alive_or_dead"):
		return BattleQiState.SIDE_ENEMY
	return ""
