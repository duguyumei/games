## 经过行为管线给一张真气应用重塑。
extends BaseAction

## 运行时只修改本局工作副本或战斗现场，不会修改固定重塑定义。
func perform_action() -> void:
	for processor: ActionInterceptorProcessor in _intercept_action([]):
		var qi_instance_uids: Array[String] = _get_qi_instance_uids(processor)
		var reshape_definition_id: String = str(
			processor.get_shadowed_action_values("reshape_definition_id", ""))
		var result_values: Dictionary = processor.get_shadowed_action_values("result_values", {})
		var scope: String = str(processor.get_shadowed_action_values(
			"scope", QiReshapeData.SCOPE_RUN))
		if not result_values is Dictionary or not JsonStateValidator.is_json_compatible(result_values):
			continue
		if scope == QiReshapeData.SCOPE_BATTLE:
			_apply_battle_batch(qi_instance_uids, reshape_definition_id, result_values)
		elif scope == QiReshapeData.SCOPE_RUN:
			_apply_run_batch(qi_instance_uids, reshape_definition_id, result_values)

## 兼容单 UID，并支持 ActionPickQi 注入的 UID 数组。
func _get_qi_instance_uids(processor: ActionInterceptorProcessor) -> Array[String]:
	var result: Array[String] = []
	var configured_uids: Variant = processor.get_shadowed_action_values("qi_instance_uids", [])
	if configured_uids is Array:
		for value: Variant in configured_uids:
			var uid: String = str(value)
			if uid != "" and not result.has(uid):
				result.append(uid)
	if result.is_empty():
		var single_uid: String = str(processor.get_shadowed_action_values("qi_instance_uid", ""))
		if single_uid != "":
			result.append(single_uid)
	return result

## 批量应用战斗临时重塑；全部目标预校验成功后才写入。
func _apply_battle_batch(
		qi_instance_uids: Array[String],
		reshape_definition_id: String,
		result_values: Dictionary) -> void:
	if Global.battle_qi_state == null or qi_instance_uids.is_empty():
		return
	for qi_instance_uid: String in qi_instance_uids:
		if not Global.battle_qi_state.can_apply_temporary_reshape(
			qi_instance_uid, reshape_definition_id, result_values):
			return
	for qi_instance_uid: String in qi_instance_uids:
		Global.battle_qi_state.apply_temporary_reshape(
			qi_instance_uid, reshape_definition_id, result_values)
		Signals.player_qi_changed.emit()
		Signals.qi_reshape_changed.emit(qi_instance_uid, QiReshapeData.SCOPE_BATTLE)

## 批量应用本局重塑；预校验或实际写入失败时回滚整个批次。
func _apply_run_batch(
		qi_instance_uids: Array[String],
		reshape_definition_id: String,
		result_values: Dictionary) -> void:
	if Global.player_data == null or qi_instance_uids.is_empty():
		return
	var reshape_data: QiReshapeData = Global.get_qi_reshape_data(reshape_definition_id)
	if reshape_data == null:
		return
	var qi_data_by_uid: Dictionary = {}
	var old_states_by_uid: Dictionary = {}
	var old_locks_by_uid: Dictionary = {}
	for qi_instance_uid: String in qi_instance_uids:
		var qi_data: QiData = Global.player_data.get_owned_qi(qi_instance_uid)
		if qi_data == null or not qi_data.can_apply_run_reshape(reshape_data, result_values):
			return
		qi_data_by_uid[qi_instance_uid] = qi_data
		old_locks_by_uid[qi_instance_uid] = qi_data.qi_origin_locked
		old_states_by_uid[qi_instance_uid] = qi_data.qi_reshape_states.duplicate(true)
	for qi_instance_uid: String in qi_instance_uids:
		var target_qi: QiData = qi_data_by_uid[qi_instance_uid]
		if not target_qi.apply_run_reshape(reshape_data, result_values):
			for rollback_uid: String in old_states_by_uid.keys():
				var rollback_qi: QiData = qi_data_by_uid[rollback_uid]
				rollback_qi.qi_reshape_states = old_states_by_uid[rollback_uid]
				rollback_qi.qi_origin_locked = old_locks_by_uid[rollback_uid]
			return
	for qi_instance_uid: String in qi_instance_uids:
		var target_qi: QiData = qi_data_by_uid[qi_instance_uid]
		var old_state: QiReshapeState = _find_replaced_state(
			old_states_by_uid[qi_instance_uid], reshape_data.reshape_slot)
		if old_state != null:
			QiEffectRuntime.invoke_reshape_remove(
				Global.get_qi_reshape_data(old_state.definition_id),
				qi_instance_uid, old_state,
				{"replacement": true, "scope": QiReshapeData.SCOPE_RUN})
		QiEffectRuntime.invoke_reshape_apply(
			reshape_data, qi_instance_uid,
			target_qi.get_reshape_state(reshape_data.reshape_slot),
			{"scope": QiReshapeData.SCOPE_RUN})
		Signals.player_qi_changed.emit()
		Signals.qi_reshape_changed.emit(qi_instance_uid, QiReshapeData.SCOPE_RUN)

## 找到会被同槽替换的旧状态；其他槽位允许并存。
func _find_replaced_state(states: Array, reshape_slot: String) -> QiReshapeState:
	if reshape_slot == QiReshapeData.SLOT_OTHER:
		return null
	var latest_state: QiReshapeState = null
	for state: QiReshapeState in states:
		if state.reshape_slot != reshape_slot:
			continue
		if latest_state == null or state.applied_order > latest_state.applied_order:
			latest_state = state
	return latest_state
## 真气重塑应用是即时行为。
func is_instant_action() -> bool:
	return true
