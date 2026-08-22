## 真气效果脚本运行桥；固定定义只提供脚本路径，实际状态仍由 QiData 或 BattleQiState 持有。
extends RefCounted
class_name QiEffectRuntime

## 调用重塑的应用钩子；空脚本路径表示纯数据重塑。
static func invoke_reshape_apply(
		definition: QiReshapeData,
		qi_instance_uid: String,
		state: QiReshapeState,
		context: Dictionary[String, Variant] = {}) -> void:
	var effect: BaseQiReshapeEffect = _create_reshape_effect(
		definition, qi_instance_uid, state)
	if effect == null:
		return
	effect.on_apply(_with_reshape_state_context(definition, state, context))

## 调用重塑的事件钩子。
static func invoke_reshape_event(
		definition: QiReshapeData,
		qi_instance_uid: String,
		state: QiReshapeState,
		event_id: String,
		context: Dictionary[String, Variant] = {}) -> void:
	var effect: BaseQiReshapeEffect = _create_reshape_effect(
		definition, qi_instance_uid, state)
	if effect == null:
		return
	effect.on_event(event_id, _with_reshape_state_context(definition, state, context))

## 调用异状的应用钩子。
static func invoke_anomaly_apply(
		definition: QiAnomalyData,
		qi_instance_uid: String,
		state: QiAnomalyState,
		context: Dictionary[String, Variant] = {}) -> void:
	var effect: BaseQiAnomalyEffect = _create_anomaly_effect(
		definition, qi_instance_uid, state)
	if effect == null:
		return
	effect.on_apply(_with_anomaly_state_context(definition, state, context))

## 调用异状的事件钩子。
static func invoke_anomaly_event(
		definition: QiAnomalyData,
		qi_instance_uid: String,
		state: QiAnomalyState,
		event_id: String,
		context: Dictionary[String, Variant] = {}) -> void:
	var effect: BaseQiAnomalyEffect = _create_anomaly_effect(
		definition, qi_instance_uid, state)
	if effect == null:
		return
	effect.on_event(event_id, _with_anomaly_state_context(definition, state, context))

## 通过纯查询钩子计算异状对真气值的修正，不创建行为或发射信号。
static func modify_anomaly_qi_value(
		definition: QiAnomalyData,
		qi_instance_uid: String,
		state: QiAnomalyState,
		value: int,
		context: Dictionary[String, Variant] = {}) -> int:
	var effect: BaseQiAnomalyEffect = _create_anomaly_effect(
		definition, qi_instance_uid, state)
	if effect == null or state == null:
		return value
	return effect.modify_qi_value(
		value, state.stacks, _with_anomaly_state_context(definition, state, context))

## 调用重塑移除钩子。
static func invoke_reshape_remove(
		definition: QiReshapeData,
		qi_instance_uid: String,
		state: QiReshapeState,
		context: Dictionary[String, Variant] = {}) -> void:
	var effect: BaseQiReshapeEffect = _create_reshape_effect(
		definition, qi_instance_uid, state)
	if effect == null:
		return
	effect.on_remove(_with_reshape_state_context(definition, state, context))

## 调用异状移除钩子。
static func invoke_anomaly_remove(
		definition: QiAnomalyData,
		qi_instance_uid: String,
		state: QiAnomalyState,
		context: Dictionary[String, Variant] = {}) -> void:
	var effect: BaseQiAnomalyEffect = _create_anomaly_effect(
		definition, qi_instance_uid, state)
	if effect == null:
		return
	effect.on_remove(_with_anomaly_state_context(definition, state, context))

## 创建重塑效果脚本；定义没有脚本时视为纯数据效果。
static func _create_reshape_effect(
		definition: QiReshapeData,
		qi_instance_uid: String,
		state: QiReshapeState) -> BaseQiReshapeEffect:
	if definition == null or definition.effect_script_path == "":
		return null
	var effect_script: Script = load(definition.effect_script_path) as Script
	if effect_script == null:
		return null
	var effect: Variant = effect_script.new()
	if not effect is BaseQiReshapeEffect:
		return null
	effect.init(definition, qi_instance_uid, state)
	return effect

## 创建异状效果脚本；定义没有脚本时视为纯数据效果。
static func _create_anomaly_effect(
		definition: QiAnomalyData,
		qi_instance_uid: String,
		state: QiAnomalyState) -> BaseQiAnomalyEffect:
	if definition == null or definition.effect_script_path == "":
		return null
	var effect_script: Script = load(definition.effect_script_path) as Script
	if effect_script == null:
		return null
	var effect: Variant = effect_script.new()
	if not effect is BaseQiAnomalyEffect:
		return null
	effect.init(definition, qi_instance_uid, state)
	return effect

## 给效果脚本提供只读的固定定义和上下文副本。
static func _with_definition_context(
		definition: SerializableData,
		context: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = context.duplicate(true)
	result["definition_id"] = definition.object_id
	result["definition_config"] = definition.get("effect_config").duplicate(true)
	return result

## 为重塑钩子附加当前结果值和来源实例。
static func _with_reshape_state_context(
		definition: QiReshapeData,
		state: QiReshapeState,
		context: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = _with_definition_context(definition, context)
	if state != null:
		result["reshape_slot"] = state.reshape_slot
		result["result_values"] = state.result_values.duplicate(true)
	return result

## 为异状钩子附加当前层数和来源实例。
static func _with_anomaly_state_context(
		definition: QiAnomalyData,
		state: QiAnomalyState,
		context: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = _with_definition_context(definition, context)
	if state != null:
		result["stacks"] = state.stacks
		result["secondary_stacks"] = state.secondary_stacks
		result["expire_events"] = state.expire_events.duplicate()
	return result
