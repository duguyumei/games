## 功法原子的校验与双队首调度器；不会重新排序任意一方自身的原子队列。
extends RefCounted
class_name GongfaAtomScheduler

## 未登记的行为优先级。
const PRIORITY_UNKNOWN: int = -1

## 首版明确支持的原子优先级。
const PRIORITY_SELF_DRAW: int = 0
const PRIORITY_OPPONENT_DRAW: int = 1
const PRIORITY_SELF_DISCARD: int = 2
const PRIORITY_OPPONENT_DISCARD: int = 3
const PRIORITY_HAND_EFFECT: int = 4
const PRIORITY_DECK_EFFECT: int = 5
const PRIORITY_STATUS: int = 6
const PRIORITY_DEFENSE: int = 7
const PRIORITY_DAMAGE: int = 8
const PRIORITY_POISON: int = 9

## 校验固定功法的全部原子和其中所有 Action 都已经登记优先级。
static func validate_atom_definitions(atom_definitions: Array[Dictionary]) -> bool:
	for atom: Dictionary in atom_definitions:
		var actions_value: Variant = atom.get("actions", null)
		if not actions_value is Array or actions_value.is_empty():
			return false
		for action_value: Variant in actions_value:
			if not action_value is Dictionary or action_value.is_empty():
				return false
			for action_path_value: Variant in action_value.keys():
				if get_action_priority(str(action_path_value), action_value[action_path_value]) \
					== PRIORITY_UNKNOWN:
					return false
	return true

## 根据原子的第一个 Action 返回优先级。
static func get_atom_priority(atom: Dictionary) -> int:
	var actions: Variant = atom.get("actions", null)
	if not actions is Array or actions.is_empty() or not actions[0] is Dictionary:
		return PRIORITY_UNKNOWN
	var first_action: Dictionary = actions[0]
	if first_action.is_empty():
		return PRIORITY_UNKNOWN
	var first_path: String = str(first_action.keys()[0])
	return get_action_priority(first_path, first_action[first_path])

## 返回一个已登记 Action 的功法原子优先级。
static func get_action_priority(action_path: String, action_values: Variant) -> int:
	var values: Dictionary = action_values if action_values is Dictionary else {}
	if action_path == Scripts.ACTION_DRAW_QI:
		return PRIORITY_OPPONENT_DRAW \
			if str(values.get("target_side", "self")) == "opponent" \
			else PRIORITY_SELF_DRAW
	if action_path == Scripts.ACTION_DISCARD_QI:
		return PRIORITY_OPPONENT_DISCARD \
			if str(values.get("target_side", "self")) == "opponent" \
			else PRIORITY_SELF_DISCARD
	if [Scripts.ACTION_APPLY_QI_RESHAPE, Scripts.ACTION_REMOVE_QI_RESHAPE,
		Scripts.ACTION_APPLY_QI_ANOMALY, Scripts.ACTION_REMOVE_QI_ANOMALY].has(action_path):
		return PRIORITY_HAND_EFFECT
	if [Scripts.ACTION_ADD_QI, Scripts.ACTION_REMOVE_QI,
		Scripts.ACTION_RESHUFFLE].has(action_path):
		return PRIORITY_DECK_EFFECT
	if [Scripts.ACTION_APPLY_STATUS, Scripts.ACTION_ADD_HEALTH,
		Scripts.ACTION_SET_HEALTH, Scripts.ACTION_HEAL_PERCENT].has(action_path):
		return PRIORITY_STATUS
	if [Scripts.ACTION_BLOCK, Scripts.ACTION_ADD_GUARD,
		Scripts.ACTION_ADD_RESOLUTION, Scripts.ACTION_ADD_REFLECT,
		Scripts.ACTION_ADD_SHIELD_PENETRATION].has(action_path):
		return PRIORITY_DEFENSE
	if [Scripts.ACTION_ATTACK, Scripts.ACTION_ATTACK_GENERATOR,
		Scripts.ACTION_DIRECT_DAMAGE].has(action_path):
		return PRIORITY_POISON \
			if str(values.get("damage_type", CombatDamageRequest.DAMAGE_NORMAL)) \
			== CombatDamageRequest.DAMAGE_POISON else PRIORITY_DAMAGE
	return PRIORITY_UNKNOWN

## 按双方队首优先级生成有序原子组；同级队首进入同一个组。
static func schedule_atom_groups(
		player_atoms: Array[Dictionary],
		enemy_atoms: Array[Dictionary]) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var player_index: int = 0
	var enemy_index: int = 0
	while player_index < player_atoms.size() or enemy_index < enemy_atoms.size():
		var player_priority: int = PRIORITY_UNKNOWN
		var enemy_priority: int = PRIORITY_UNKNOWN
		if player_index < player_atoms.size():
			player_priority = int(player_atoms[player_index].get("priority", PRIORITY_UNKNOWN))
		if enemy_index < enemy_atoms.size():
			enemy_priority = int(enemy_atoms[enemy_index].get("priority", PRIORITY_UNKNOWN))
		if player_priority == PRIORITY_UNKNOWN and enemy_priority == PRIORITY_UNKNOWN:
			break
		if enemy_priority == PRIORITY_UNKNOWN \
			or player_priority != PRIORITY_UNKNOWN and player_priority < enemy_priority:
			groups.append({"player_atom": player_atoms[player_index], "enemy_atom": {}})
			player_index += 1
		elif player_priority == PRIORITY_UNKNOWN or enemy_priority < player_priority:
			groups.append({"player_atom": {}, "enemy_atom": enemy_atoms[enemy_index]})
			enemy_index += 1
		else:
			groups.append({
				"player_atom": player_atoms[player_index],
				"enemy_atom": enemy_atoms[enemy_index],
			})
			player_index += 1
			enemy_index += 1
	return groups
