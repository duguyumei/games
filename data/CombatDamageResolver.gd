## 真气战斗统一伤害结算器；所有状态修改都经过 BattleQiState。
extends RefCounted
class_name CombatDamageResolver

## 结算一次伤害，并在必要时立即生成反震伤害。
static func resolve(
		target: BaseCombatant,
		request: CombatDamageRequest,
		battle_state: BattleQiState) -> CombatDamageResult:
	var result: CombatDamageResult = CombatDamageResult.new()
	if target == null or request == null or battle_state == null \
		or not request.is_valid_damage_type():
		return result
	result.requested_damage = max(request.amount, 0)
	result.damage_type = request.damage_type
	result.source_side = request.source_side
	result.source_kind = request.source_kind
	result.source_instance_id = request.source_instance_id
	result.source_effect_id = request.source_effect_id
	if result.requested_damage <= 0 or not target.is_alive():
		return result
	var target_side: String = battle_state.get_combatant_side(target)
	if target_side == "":
		return result
	if request.target_side != "" and request.target_side != target_side:
		return result
	request.target_side = target_side
	result.target_side = target_side
	var remaining_damage: int = result.requested_damage

	# 格挡只处理直接伤害，且一段多段伤害只消耗一层。
	if request.is_direct_damage() and battle_state.consume_guard(target_side):
		result.guard_consumed = true
		result.was_prevented = true
		Signals.combatant_blocked.emit(target, result.requested_damage)
		Signals.combat_damage_resolved.emit(target, result.copy_result())
		return result

	# 化解只处理直接伤害；超过总化解值时伤害保持原值。
	if request.is_direct_damage():
		var resolution_result: Dictionary = battle_state.consume_resolution(
			target_side, remaining_damage)
		result.resolution_consumed = int(resolution_result.get("consumed", 0))
		if bool(resolution_result.get("prevented", false)):
			result.was_prevented = true
			Signals.combat_damage_resolved.emit(target, result.copy_result())
			return result

	# 真实伤害完全绕过护盾和穿透修正。
	var shieldable_damage: int = remaining_damage
	var penetrating_damage: int = 0
	if request.damage_type != CombatDamageRequest.DAMAGE_TRUE:
		# 护盾穿透是攻击来源方的进攻修正，不属于受击方防御。
		var penetration_side: String = request.source_side \
			if [BattleQiState.SIDE_PLAYER, BattleQiState.SIDE_ENEMY].has(request.source_side) \
			else ""
		result.penetration_ratio = battle_state.get_shield_penetration_ratio(
			penetration_side, request.damage_type)
		penetrating_damage = max(
			int(floor(float(remaining_damage) * result.penetration_ratio)), 0)
		shieldable_damage = max(remaining_damage - penetrating_damage, 0)
		if penetration_side != "":
			battle_state.consume_highest_modifier_hit(
				penetration_side,
				BattleDefenseEntry.KIND_PENETRATION,
				request.damage_type)
	else:
		shieldable_damage = 0

	var shield_before: int = battle_state.get_shield(target_side)
	result.shield_absorbed = battle_state.absorb_shield(
		target_side, shieldable_damage)
	if shield_before > 0 and result.shield_absorbed > 0 \
		and battle_state.get_shield(target_side) == 0:
		Signals.combatant_block_broken.emit(target)
	result.health_damage = penetrating_damage \
		+ max(shieldable_damage - result.shield_absorbed, 0)

	# 反震在护盾扣减后、原伤害扣血前触发；反震本身不会再次触发反震。
	if request.can_trigger_reflect \
		and request.is_direct_damage() \
		and result.shield_absorbed > 0 \
		and [BattleQiState.SIDE_PLAYER, BattleQiState.SIDE_ENEMY].has(request.source_side) \
		and request.source_side != target_side \
		and battle_state.get_reflect_ratio(target_side) != 0.0:
		result.reflect_amount = int(floor(
			float(result.shield_absorbed) * battle_state.get_reflect_ratio(target_side)))
		if result.reflect_amount > 0:
			battle_state.consume_highest_modifier_hit(
				target_side,
				BattleDefenseEntry.KIND_REFLECT,
				CombatDamageRequest.DAMAGE_NORMAL)
			var source_combatant: BaseCombatant = _get_source_combatant(
				request.source_side, request.source_instance_id)
			if source_combatant != null and source_combatant.is_alive():
				Signals.combat_reflect_triggered.emit(
					target, source_combatant, result.reflect_amount)
				var reflect_request: CombatDamageRequest = CombatDamageRequest.new()
				reflect_request.amount = result.reflect_amount
				reflect_request.damage_type = CombatDamageRequest.DAMAGE_REFLECT
				reflect_request.source_side = target_side
				reflect_request.source_kind = "reflect"
				reflect_request.source_instance_id = "reflect:%s" % request.source_instance_id
				reflect_request.target_side = request.source_side
				reflect_request.source_effect_id = "reflect:%s" % request.source_effect_id
				reflect_request.can_trigger_reflect = false
				resolve(source_combatant, reflect_request, battle_state)

	# 原伤害在反震请求生成后扣除目标生命。
	if result.health_damage > 0:
		var health_result: Array[int] = target.apply_health_damage(result.health_damage)
		# health_damage 表示实际扣除的生命；超过生命上限的部分单独记录。
		result.health_damage = health_result[1]
		result.overkill_damage = health_result[2]
	Signals.combat_damage_resolved.emit(target, result.copy_result())
	return result

## 返回一个阵营当前可作为伤害来源的战斗对象。
static func _get_source_combatant(
		source_side: String,
		source_instance_id: String) -> BaseCombatant:
	if source_side == BattleQiState.SIDE_PLAYER:
		return Global.get_player()
	if source_side != BattleQiState.SIDE_ENEMY:
		return null
	# 反震请求会给来源 UID 加上前缀，先还原原始敌人实例 UID。
	var resolved_source_instance_id: String = source_instance_id
	if resolved_source_instance_id.begins_with("reflect:"):
		resolved_source_instance_id = resolved_source_instance_id.trim_prefix("reflect:")
	for enemy: Enemy in Global.get_alive_enemies():
		if resolved_source_instance_id == "" \
			or enemy.enemy_data.object_uid == resolved_source_instance_id:
			return enemy
	return null
