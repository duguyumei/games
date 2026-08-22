## 经过行为管线给一张真气应用异状。
extends BaseAction

## 运行时只修改本局工作副本或战斗现场，不会修改固定异状定义。
func perform_action() -> void:
	for processor: ActionInterceptorProcessor in _intercept_action([]):
		var qi_instance_uids: Array[String] = _get_qi_instance_uids(processor)
		var anomaly_definition_id: String = str(
			processor.get_shadowed_action_values("anomaly_definition_id", ""))
		var stacks: int = int(processor.get_shadowed_action_values("stacks", 1))
		var secondary_stacks: int = int(
			processor.get_shadowed_action_values("secondary_stacks", 0))
		var scope: String = str(processor.get_shadowed_action_values(
			"scope", QiAnomalyData.SCOPE_BATTLE))
		for qi_instance_uid: String in qi_instance_uids:
			_apply_to_qi(qi_instance_uid, anomaly_definition_id, stacks, secondary_stacks, scope)

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

## 给单个真气实例应用异状；批量调用不会共享状态对象。
func _apply_to_qi(
		qi_instance_uid: String,
		anomaly_definition_id: String,
		stacks: int,
		secondary_stacks: int,
		scope: String) -> void:
	var changed: bool = false
	if scope == QiAnomalyData.SCOPE_BATTLE:
		if Global.battle_qi_state != null:
			changed = Global.battle_qi_state.apply_anomaly(
				qi_instance_uid, anomaly_definition_id, stacks, secondary_stacks)
	elif scope == QiAnomalyData.SCOPE_RUN:
		var qi_data: QiData = Global.player_data.get_owned_qi(qi_instance_uid)
		var anomaly_data: QiAnomalyData = Global.get_qi_anomaly_data(anomaly_definition_id)
		if qi_data != null:
			changed = qi_data.apply_run_anomaly(anomaly_data, stacks, secondary_stacks)
			if changed:
				QiEffectRuntime.invoke_anomaly_apply(
					anomaly_data, qi_instance_uid,
					qi_data.get_persistent_anomaly_state(anomaly_definition_id),
					{"scope": QiAnomalyData.SCOPE_RUN})
	if changed:
		Signals.player_qi_changed.emit()
		Signals.qi_anomaly_changed.emit(qi_instance_uid, scope)

## 真气异状应用是即时行为。
func is_instant_action() -> bool:
	return true
