## 真气状态的纯查询服务；只读取真气状态，不执行行为或发射结算信号。
extends RefCounted
class_name QiStateResolver

## 永久强化的固定内容 ID。
const ENHANCEMENT_VALUE_ADD: String = "qi_enhancement_increase_value"
const ENHANCEMENT_MULTIPLIER: String = "qi_enhancement_multiplier"
const ENHANCEMENT_MIX_ATTRIBUTE: String = "qi_enhancement_mix_attribute"
const ENHANCEMENT_VALUE_DOUBLE: String = "qi_enhancement_double_value"

## 可能覆盖最终真气值的战斗异状 ID；没有定义时不会产生额外效果。
const ANOMALY_BURNOUT_IDS: Array[String] = ["burnout", "qi_anomaly_burnout"]

## 返回本源重塑后的基础属性；没有本源时返回固定属性。
static func get_base_attribute_id(qi_data: QiData) -> String:
	if qi_data == null:
		return ""
	var attribute_id: String = qi_data.get_attribute_id()
	var origin_state: QiReshapeState = _find_latest_origin_attribute_state(
		qi_data.qi_reshape_states)
	if origin_state != null:
		attribute_id = str(origin_state.result_values.get("attribute_id", attribute_id))
	return attribute_id if QiData.ATTRIBUTE_IDS.has(attribute_id) else qi_data.get_attribute_id()

## 返回本局重塑和战斗临时重塑共同决定的首要有效属性 ID。
static func get_effective_attribute_id(
		qi_data: QiData,
		battle_state: BattleQiState = null) -> String:
	var attributes: Array[String] = get_effective_attribute_ids(qi_data, battle_state)
	return attributes[0] if not attributes.is_empty() else ""

## 返回当前有效的全部属性身份；混元和临时属性可以增加额外身份。
static func get_effective_attribute_ids(
		qi_data: QiData,
		battle_state: BattleQiState = null) -> Array[String]:
	var result: Array[String] = []
	if qi_data == null:
		return result
	var base_attribute_id: String = get_base_attribute_id(qi_data)
	if base_attribute_id != "":
		result.append(base_attribute_id)
	if _has_reshape_definition(qi_data.qi_reshape_states, ENHANCEMENT_MIX_ATTRIBUTE):
		for attribute_id: String in QiData.ATTRIBUTE_IDS:
			if not result.has(attribute_id):
				result.append(attribute_id)
	if battle_state != null and qi_data.object_uid != "":
		for state: QiReshapeState in battle_state.get_reshape_states(qi_data.object_uid):
			if state.reshape_slot != QiReshapeData.SLOT_TEMPORARY_ATTRIBUTE:
				continue
			var temporary_attribute_id: String = str(
				state.result_values.get("attribute_id", ""))
			if QiData.ATTRIBUTE_IDS.has(temporary_attribute_id) \
				and not result.has(temporary_attribute_id):
				result.append(temporary_attribute_id)
	return result

## 返回本源重塑后的基础牌阶，不读取战斗临时牌阶。
static func get_base_rank(qi_data: QiData) -> int:
	if qi_data == null:
		return 0
	var rank: int = qi_data.qi_rank
	var origin_state: QiReshapeState = _find_latest_origin_rank_state(
		qi_data.qi_reshape_states)
	if origin_state != null:
		rank = int(origin_state.result_values.get("rank", rank))
	return clamp(rank, 1, 13)

## 返回本局重塑和战斗临时重塑共同决定的有效牌阶。
static func get_effective_rank(
		qi_data: QiData,
		battle_state: BattleQiState = null) -> int:
	if qi_data == null:
		return 0
	var rank: int = get_base_rank(qi_data)
	if battle_state != null and qi_data.object_uid != "":
		for state: QiReshapeState in battle_state.get_reshape_states(qi_data.object_uid):
			if state.reshape_slot != QiReshapeData.SLOT_TEMPORARY_RANK:
				continue
			if state.result_values.has("rank"):
				rank = int(state.result_values.get("rank", rank))
	return clamp(rank, 1, 13)

## 按有效牌阶计算标准基础真气值。
static func get_base_qi_value(
		qi_data: QiData,
		battle_state: BattleQiState = null) -> int:
	if qi_data == null:
		return 0
	var origin_state: QiReshapeState = _find_latest_origin_rank_state(
		qi_data.qi_reshape_states)
	if origin_state != null and not _has_temporary_rank(qi_data, battle_state) \
		and origin_state.result_values.has("base_qi_value"):
		return max(int(origin_state.result_values.get("base_qi_value", 0)), 0)
	return _standard_qi_value(get_effective_rank(qi_data, battle_state))

## 返回当前兼容接口的有效真气值；不额外触发战斗行为。
static func get_effective_qi_value(
		qi_data: QiData,
		battle_state: BattleQiState = null) -> int:
	if qi_data == null:
		return 0
	var value: int = get_base_qi_value(qi_data, battle_state)
	var explicit_value_state: QiReshapeState = _find_latest_value_state(
		qi_data.qi_reshape_states, QiReshapeData.SCOPE_RUN)
	if battle_state != null and qi_data.object_uid != "":
		for state: QiReshapeState in battle_state.get_reshape_states(qi_data.object_uid):
			if state.result_values.has("value"):
				explicit_value_state = state
	if explicit_value_state != null:
		value = int(explicit_value_state.result_values.get("value", value))
	elif qi_data.qi_value >= 0 \
		and _find_latest_origin_rank_state(qi_data.qi_reshape_states) == null \
		and not _has_temporary_rank(qi_data, battle_state):
		value = qi_data.qi_value
	value = max(value + qi_data.qi_permanent_value_modifier, 0)
	return _apply_anomaly_value_modifiers(qi_data, value, battle_state)

## 返回参与功法数值计算时的真气贡献值；只做纯计算，不随机也不写状态。
static func get_contribution_qi_value(
		qi_data: QiData,
		battle_state: BattleQiState = null,
		context: Dictionary = {}) -> int:
	if qi_data == null:
		return 0
	var value: int = get_effective_qi_value(qi_data, battle_state)
	var value_add: int = 0
	var value_multiplier: int = 1
	for state: QiReshapeState in qi_data.qi_reshape_states:
		if state.reshape_slot != QiReshapeData.SLOT_ENHANCEMENT:
			continue
		match state.definition_id:
			ENHANCEMENT_VALUE_ADD:
				value_add += 8
			ENHANCEMENT_VALUE_DOUBLE:
				value_multiplier *= 2
	if battle_state != null and qi_data.object_uid != "":
		for state: QiReshapeState in battle_state.get_reshape_states(qi_data.object_uid):
			if state.reshape_slot != QiReshapeData.SLOT_TEMPORARY_ENHANCEMENT:
				continue
			value_add += int(state.result_values.get("value_add", 0))
			value_multiplier *= max(int(state.result_values.get("value_multiplier", 1)), 1)
	value = max(value + value_add, 0) * value_multiplier
	if bool(context.get("participates_in_value", false)) \
		and _has_fire_awakening(qi_data):
		value *= 2
	if _has_burnout(qi_data, battle_state):
		return 0
	return max(value, 0)

## 返回参与当前功法时的静态倍率修正；机缘随机判定由战斗结算阶段处理。
static func get_gongfa_multiplier_modifier(qi_data: QiData) -> int:
	if qi_data == null:
		return 0
	var modifier: int = 0
	for state: QiReshapeState in qi_data.qi_reshape_states:
		if state.reshape_slot == QiReshapeData.SLOT_ENHANCEMENT \
			and state.definition_id == ENHANCEMENT_MULTIPLIER:
			modifier += 1
	return modifier

## 返回指定牌阶的标准真气值，供重塑行为构造结果值使用。
static func get_standard_qi_value(rank: int) -> int:
	return _standard_qi_value(rank)

## 判断本源是否已经锁定。
static func is_origin_locked(qi_data: QiData) -> bool:
	return qi_data != null and qi_data.qi_origin_locked

## 依次应用本局和战斗异状的纯数值钩子；不会修改异状层数或发送信号。
static func _apply_anomaly_value_modifiers(
		qi_data: QiData,
		value: int,
		battle_state: BattleQiState) -> int:
	var result: int = value
	var global_node: Node = _get_global_node()
	if global_node == null:
		return result
	for anomaly_state: QiAnomalyState in qi_data.qi_persistent_anomaly_states:
		var anomaly_data: QiAnomalyData = global_node.get_qi_anomaly_data(
			anomaly_state.definition_id)
		result = QiEffectRuntime.modify_anomaly_qi_value(
			anomaly_data, qi_data.object_uid, anomaly_state, result,
			{"scope": QiAnomalyData.SCOPE_RUN, "preview_mode": true})
	if battle_state != null and qi_data.object_uid != "":
		for anomaly_state: QiAnomalyState in battle_state.get_anomaly_states(qi_data.object_uid):
			var anomaly_data: QiAnomalyData = global_node.get_qi_anomaly_data(
				anomaly_state.definition_id)
			result = QiEffectRuntime.modify_anomaly_qi_value(
				anomaly_data, qi_data.object_uid, anomaly_state, result,
				{"scope": QiAnomalyData.SCOPE_BATTLE, "preview_mode": true})
	return max(result, 0)

## 判断真气是否拥有指定重塑定义。
static func _has_reshape_definition(states: Array, definition_id: String) -> bool:
	for state: QiReshapeState in states:
		if state.definition_id == definition_id:
			return true
	return false

## 判断当前真气是否拥有火觉醒本源。
static func _has_fire_awakening(qi_data: QiData) -> bool:
	for state: QiReshapeState in qi_data.qi_reshape_states:
		if state.reshape_slot == QiReshapeData.SLOT_ORIGIN \
			and state.origin_operation == QiReshapeData.ORIGIN_AWAKEN \
			and str(state.result_values.get("awakening_attribute_id", "")) == "fire":
			return true
	return false

## 判断当前真气是否被燃尽；具体异状仍由战斗状态负责创建和清理。
static func _has_burnout(qi_data: QiData, battle_state: BattleQiState) -> bool:
	for state: QiAnomalyState in qi_data.qi_persistent_anomaly_states:
		if ANOMALY_BURNOUT_IDS.has(state.definition_id) and state.stacks > 0:
			return true
	if battle_state == null or qi_data.object_uid == "":
		return false
	for state: QiAnomalyState in battle_state.get_anomaly_states(qi_data.object_uid):
		if ANOMALY_BURNOUT_IDS.has(state.definition_id) and state.stacks > 0:
			return true
	return false

## 判断战斗是否存在临时牌阶，供基础真气值查询选择正确来源。
static func _has_temporary_rank(qi_data: QiData, battle_state: BattleQiState) -> bool:
	if battle_state == null or qi_data == null or qi_data.object_uid == "":
		return false
	for state: QiReshapeState in battle_state.get_reshape_states(qi_data.object_uid):
		if state.reshape_slot == QiReshapeData.SLOT_TEMPORARY_RANK:
			return true
	return false

## 返回标准牌阶对应的基础真气值。
static func _standard_qi_value(rank: int) -> int:
	if rank == 1:
		return 12
	if rank >= 11 and rank <= 13:
		return 11
	return max(rank, 0)

## 在状态数组中找到最新的本源属性状态。
static func _find_latest_origin_attribute_state(states: Array) -> QiReshapeState:
	var latest: QiReshapeState = null
	for state: QiReshapeState in states:
		if state.scope != QiReshapeData.SCOPE_RUN \
			or state.reshape_slot != QiReshapeData.SLOT_ORIGIN \
			or not state.result_values.has("attribute_id"):
			continue
		if latest == null or state.applied_order > latest.applied_order:
			latest = state
	return latest

## 在状态数组中找到最新的本源牌阶状态。
static func _find_latest_origin_rank_state(states: Array) -> QiReshapeState:
	var latest: QiReshapeState = null
	for state: QiReshapeState in states:
		if state.scope != QiReshapeData.SCOPE_RUN \
			or state.reshape_slot != QiReshapeData.SLOT_ORIGIN \
			or not state.result_values.has("rank"):
			continue
		if latest == null or state.applied_order > latest.applied_order:
			latest = state
	return latest

## 在状态数组中找到最新的显式真气值状态。
static func _find_latest_value_state(states: Array, scope: String) -> QiReshapeState:
	var latest: QiReshapeState = null
	for state: QiReshapeState in states:
		if state.scope != scope or not state.result_values.has("value"):
			continue
		if latest == null or state.applied_order > latest.applied_order:
			latest = state
	return latest

## 通过场景树读取 Global，避免查询服务与自动加载脚本形成编译循环。
static func _get_global_node() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null or not main_loop is SceneTree:
		return null
	return (main_loop as SceneTree).root.get_node_or_null("Global")
