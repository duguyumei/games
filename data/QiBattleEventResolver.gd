## 已确认战斗事件的统一效果调度器；数值查询不会调用此类。
extends RefCounted
class_name QiBattleEventResolver

## 自身获得一次行动窗口时发送的事件。
const EVENT_ACTION_STARTED: String = "action_started"

## 按阵营和统一来源顺序构造事件行为。
static func build_event_actions(
		event_id: String,
		eligible_sides: Array[String],
		battle_state: BattleQiState) -> Array[BaseAction]:
	var result: Array[BaseAction] = []
	if event_id == "" or battle_state == null:
		return result
	for side: String in eligible_sides:
		var sources: Array[Dictionary] = QiValuePipeline.collect_ordered_sources(
			side,
			"",
			battle_state.get_zone(side, BattleQiState.ZONE_PENDING),
			battle_state.get_zone(side, BattleQiState.ZONE_HAND),
			battle_state)
		for source: Dictionary in sources:
			for event_effect_value: Variant in source.get("battle_event_effects", []):
				if not event_effect_value is Dictionary:
					continue
				var event_effect: Dictionary = event_effect_value
				if str(event_effect.get("event_id", "")) != event_id:
					continue
				var action_values: Variant = event_effect.get("actions", null)
				if not action_values is Array:
					continue
				var action_data: Array[Dictionary] = []
				action_data.assign(action_values)
				action_data = QiActionResolver._inject_action_context(
					action_data,
					side,
					str(source.get("source_kind", "")),
					str(source.get("source_instance_id", "")),
					str(event_effect.get("effect_id", "%s:%s" % [
						source.get("source_instance_id", ""), event_id])))
				var parent: BaseCombatant = _get_side_combatant(side)
				var target: BaseCombatant = _get_side_combatant(
					BattleQiState.SIDE_ENEMY if side == BattleQiState.SIDE_PLAYER \
					else BattleQiState.SIDE_PLAYER)
				var targets: Array[BaseCombatant] = []
				if target != null:
					targets.append(target)
				result.append_array(ActionGenerator.create_actions(
					parent, null, targets, action_data, null))
	return result

## 返回指定阵营当前唯一战斗对象。
static func _get_side_combatant(side: String) -> BaseCombatant:
	if side == BattleQiState.SIDE_PLAYER:
		return Global.get_player()
	if side == BattleQiState.SIDE_ENEMY:
		var enemies: Array[Enemy] = Global.get_alive_enemies()
		return enemies[0] if not enemies.is_empty() else null
	return null
