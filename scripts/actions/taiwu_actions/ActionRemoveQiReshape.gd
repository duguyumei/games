## 经过行为管线移除一张真气的重塑。
extends BaseAction

## scope=run 时移除本局槽位，scope=battle 时移除战斗临时槽位。
func perform_action() -> void:
	for processor: ActionInterceptorProcessor in _intercept_action([]):
		var qi_instance_uid: String = str(processor.get_shadowed_action_values("qi_instance_uid", ""))
		var reshape_slot: String = str(processor.get_shadowed_action_values("reshape_slot", ""))
		var reshape_state_uid: String = str(processor.get_shadowed_action_values(
			"reshape_state_uid", ""))
		var scope: String = str(processor.get_shadowed_action_values(
			"scope", QiReshapeData.SCOPE_RUN))
		var changed: bool = false
		if scope == QiReshapeData.SCOPE_BATTLE:
			if Global.battle_qi_state != null:
				changed = Global.battle_qi_state.remove_temporary_reshape(
					qi_instance_uid, reshape_slot)
		else:
			var qi_data: QiData = Global.player_data.get_owned_qi(qi_instance_uid)
			if qi_data != null:
				if reshape_slot == QiReshapeData.SLOT_ORIGIN:
					continue
				var old_state: QiReshapeState = _find_state(
					qi_data, reshape_slot, reshape_state_uid)
				var old_definition: QiReshapeData = null
				if old_state != null:
					old_definition = Global.get_qi_reshape_data(old_state.definition_id)
				changed = qi_data.remove_run_reshape(reshape_slot, reshape_state_uid)
				if changed:
					QiEffectRuntime.invoke_reshape_remove(
						old_definition, qi_instance_uid, old_state,
						{"scope": QiReshapeData.SCOPE_RUN})
		if changed:
			Signals.player_qi_changed.emit()
			Signals.qi_reshape_changed.emit(qi_instance_uid, scope)

## 按槽位或状态 UID 查询待移除的重塑状态。
func _find_state(
		qi_data: QiData,
		reshape_slot: String,
		reshape_state_uid: String) -> QiReshapeState:
	for state: QiReshapeState in qi_data.qi_reshape_states:
		if state.reshape_slot != reshape_slot:
			continue
		if reshape_state_uid == "" or state.state_uid == reshape_state_uid:
			return state
	return null

## 真气重塑移除是即时行为。
func is_instant_action() -> bool:
	return true
