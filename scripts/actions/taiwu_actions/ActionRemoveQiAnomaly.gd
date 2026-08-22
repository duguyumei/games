## 经过行为管线移除一张真气的异状。
extends BaseAction

## scope=run 时移除本局异状，scope=battle 时移除战斗异状。
func perform_action() -> void:
	for processor: ActionInterceptorProcessor in _intercept_action([]):
		var qi_instance_uids: Array[String] = _get_qi_instance_uids(processor)
		var anomaly_definition_id: String = str(
			processor.get_shadowed_action_values("anomaly_definition_id", ""))
		var scope: String = str(processor.get_shadowed_action_values(
			"scope", QiAnomalyData.SCOPE_BATTLE))
		for qi_instance_uid: String in qi_instance_uids:
			_remove_from_qi(qi_instance_uid, anomaly_definition_id, scope)

## 兼容旧的单 UID 参数，并读取 ActionPickQi 注入的 UID 数组。
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

## 从单个真气实例移除指定异状，并按生命周期触发移除钩子。
func _remove_from_qi(
		qi_instance_uid: String,
		anomaly_definition_id: String,
		scope: String) -> void:
	var changed: bool = false
	if scope == QiAnomalyData.SCOPE_BATTLE:
		if Global.battle_qi_state != null:
			changed = Global.battle_qi_state.remove_anomaly(
				qi_instance_uid, anomaly_definition_id)
	else:
		var qi_data: QiData = Global.player_data.get_owned_qi(qi_instance_uid)
		if qi_data != null:
			var old_state: QiAnomalyState = qi_data.get_persistent_anomaly_state(
				anomaly_definition_id)
			var old_definition: QiAnomalyData = null
			if old_state != null:
				old_definition = Global.get_qi_anomaly_data(old_state.definition_id)
			changed = qi_data.remove_run_anomaly(anomaly_definition_id)
			if changed:
				QiEffectRuntime.invoke_anomaly_remove(
					old_definition, qi_instance_uid, old_state,
					{"scope": QiAnomalyData.SCOPE_RUN})
	if changed:
		Signals.player_qi_changed.emit()
		Signals.qi_anomaly_changed.emit(qi_instance_uid, scope)

## 真气异状移除是即时行为。
func is_instant_action() -> bool:
	return true
