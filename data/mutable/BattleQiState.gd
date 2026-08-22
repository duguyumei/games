## 一场战斗中的真气现场状态；保存敌我临时牌区、重塑和异状，不参与本局存档。
extends RefCounted
class_name BattleQiState

## 战斗状态只能使用 battle 生命周期；run 状态由 QiData 持有。
const SCOPE_BATTLE: String = "battle"

## 玩家阵营的稳定标识。
const SIDE_PLAYER: String = "player"

## 敌方阵营的稳定标识。
const SIDE_ENEMY: String = "enemy"

## 牌库区域的稳定标识。
const ZONE_DRAW: String = "draw"

## 手牌区域的稳定标识。
const ZONE_HAND: String = "hand"

## 弃牌堆区域的稳定标识。
const ZONE_DISCARD: String = "discard"

## 消耗牌堆区域的稳定标识。
const ZONE_EXHAUST: String = "exhaust"

## 已经提交但尚未结算的真气区域。
const ZONE_PENDING: String = "pending"

## 当前基础八脉容量。
const HAND_LIMIT: int = 8

## 单次行动待结算区允许的最大真气数量。
const PENDING_LIMIT: int = 5

## 真气已经实际打出。
const EVENT_QI_PLAYED: String = "qi_played"

## 真气已经实际进入弃牌堆；手动和自然弃置都使用这个事件。
const EVENT_QI_DISCARDED: String = "qi_discarded"

## 真气已经实际耗尽。
const EVENT_QI_EXHAUSTED: String = "qi_exhausted"

## 真气已经从当前战斗移除。
const EVENT_QI_BANISHED: String = "qi_banished"

## 当前战斗结束。
const EVENT_BATTLE_ENDED: String = "battle_ended"

## 玩家当前剩余牌库。
var _player_draw: Array[QiData] = []

## 玩家当前手牌。
var _player_hand: Array[QiData] = []

## 玩家当前弃牌堆。
var _player_discard: Array[QiData] = []

## 玩家当前消耗牌堆。
var _player_exhaust: Array[QiData] = []

## 玩家当前不可撤回的待结算区。
var _player_pending: Array[QiData] = []

## 敌方当前剩余牌库。
var _enemy_draw: Array[QiData] = []

## 敌方当前手牌。
var _enemy_hand: Array[QiData] = []

## 敌方当前弃牌堆。
var _enemy_discard: Array[QiData] = []

## 敌方当前消耗牌堆。
var _enemy_exhaust: Array[QiData] = []

## 敌方当前待结算区。
var _enemy_pending: Array[QiData] = []

## 当前唯一敌人的实例标识。
var _active_enemy_instance_id: String = ""

## 递增的行动序号，用于生成稳定且不可复用的冻结令牌。
var _next_action_order: int = 0

## 当前已经冻结、等待结算器处理的请求令牌。
var _frozen_action_token: String = ""

## 每张真气 UID 对应的临时重塑列表。
var _qi_uid_to_reshape_states: Dictionary = {}

## 每张真气 UID 对应的战斗异状列表。
var _qi_uid_to_anomaly_states: Dictionary = {}

## 递增序号保证同一来源状态的替换和处理顺序稳定。
var _next_state_order: int = 0

## 已处理的事件令牌，避免同一结算事件重复移除状态。
var _processed_event_tokens: Dictionary[String, bool] = {}

## 使用敌我牌组初始化战斗牌区；输入对象会深复制，牌区不会修改本局牌组。
func initialize_zones(
		player_deck: Array[QiData],
		enemy_deck: Array[QiData],
		player_shuffle_rng: RandomNumberGenerator,
		enemy_shuffle_rng: RandomNumberGenerator,
		active_enemy_instance_id: String) -> bool:
	_clear_zones()
	if player_deck.is_empty() or enemy_deck.is_empty() \
		or active_enemy_instance_id == "":
		return false
	var seen_player_uids: Dictionary[String, bool] = {}
	for qi_data: QiData in player_deck:
		if qi_data == null or qi_data.object_uid == "" \
			or seen_player_uids.has(qi_data.object_uid):
			_clear_zones()
			return false
		seen_player_uids[qi_data.object_uid] = true
		_player_draw.append(qi_data.duplicate(true) as QiData)
	for enemy_index: int in enemy_deck.size():
		var enemy_qi: QiData = enemy_deck[enemy_index]
		if enemy_qi == null:
			_clear_zones()
			return false
		var copied_enemy_qi: QiData = enemy_qi.duplicate(true) as QiData
		copied_enemy_qi.object_uid = "enemy-%s-%d-%s" % [
			active_enemy_instance_id, enemy_index, copied_enemy_qi.object_id]
		copied_enemy_qi.initialize_instance_value()
		_enemy_draw.append(copied_enemy_qi)
	_active_enemy_instance_id = active_enemy_instance_id
	_shuffle_zone(_player_draw, player_shuffle_rng)
	_shuffle_zone(_enemy_draw, enemy_shuffle_rng)
	return true

## 返回指定阵营和牌区的数组副本；调用方不能直接增删内部牌区。
func get_zone(side: String, zone: String) -> Array[QiData]:
	var source: Array[QiData] = _get_zone_reference(side, zone)
	return source.duplicate()

## 返回指定牌区的有序实例 UID，用于界面刷新和请求冻结。
func get_zone_uids(side: String, zone: String) -> Array[String]:
	var result: Array[String] = []
	for qi_data: QiData in _get_zone_reference(side, zone):
		result.append(qi_data.object_uid)
	return result

## 返回指定阵营所有活动牌区中的真气实例。
func get_qi(side: String, qi_instance_uid: String) -> QiData:
	for zone: String in [ZONE_DRAW, ZONE_HAND, ZONE_DISCARD, ZONE_EXHAUST, ZONE_PENDING]:
		for qi_data: QiData in _get_zone_reference(side, zone):
			if qi_data.object_uid == qi_instance_uid:
				return qi_data
	return null

## 将指定阵营正常补牌至目标容量；牌库为空时直接停止，不回收弃牌堆。
func draw_to_hand_limit(side: String, hand_limit: int = HAND_LIMIT) -> int:
	if is_action_frozen() or not _is_valid_side(side):
		return 0
	var draw_zone: Array[QiData] = _get_zone_reference(side, ZONE_DRAW)
	var hand_zone: Array[QiData] = _get_zone_reference(side, ZONE_HAND)
	var drawn_count: int = 0
	while hand_zone.size() < max(0, hand_limit) and not draw_zone.is_empty():
		hand_zone.append(draw_zone.pop_back())
		drawn_count += 1
	return drawn_count

## 原子提交玩家本批选中的真气；顺序使用调用方给出的点击顺序。
func commit_player_selection(qi_instance_uids: Array[String]) -> bool:
	if is_action_frozen() or qi_instance_uids.is_empty() \
		or _player_pending.size() + qi_instance_uids.size() > PENDING_LIMIT:
		return false
	if not _can_move_batch(SIDE_PLAYER, qi_instance_uids, ZONE_HAND):
		return false
	for qi_instance_uid: String in qi_instance_uids:
		_move_qi_unchecked(SIDE_PLAYER, qi_instance_uid, ZONE_HAND, ZONE_PENDING)
	return true

## 敌方按当前手牌顺序提交前若干张真气到待结算区。
func prepare_enemy_pending(play_count: int) -> int:
	if is_action_frozen() or not _enemy_pending.is_empty():
		return 0
	var actual_count: int = min(clamp(play_count, 1, PENDING_LIMIT), _enemy_hand.size())
	var selected_uids: Array[String] = []
	for qi_index: int in actual_count:
		selected_uids.append(_enemy_hand[qi_index].object_uid)
	for qi_instance_uid: String in selected_uids:
		_move_qi_unchecked(SIDE_ENEMY, qi_instance_uid, ZONE_HAND, ZONE_PENDING)
	return actual_count

## 冻结双方待结算区并返回整体行动请求；玩家没有提交真气时拒绝确认。
func freeze_action() -> QiActionRequest:
	if is_action_frozen() or _player_pending.is_empty() \
		or _player_pending.size() > PENDING_LIMIT \
		or _enemy_pending.size() > PENDING_LIMIT:
		return null
	_next_action_order += 1
	_frozen_action_token = "qi-action-%d" % _next_action_order
	var request: QiActionRequest = QiActionRequest.new()
	request.initialize(
		_frozen_action_token,
		_active_enemy_instance_id,
		get_zone_uids(SIDE_PLAYER, ZONE_PENDING),
		get_zone_uids(SIDE_ENEMY, ZONE_PENDING))
	for qi_instance_uid: String in request.player_qi_instance_uids:
		_notify_committed_event(EVENT_QI_PLAYED, qi_instance_uid, request.action_token)
	for qi_instance_uid: String in request.enemy_qi_instance_uids:
		_notify_committed_event(EVENT_QI_PLAYED, qi_instance_uid, request.action_token)
	return request

## 完成指定冻结请求，将双方待结算真气依次移入各自弃牌堆。
func complete_qi_action(request: QiActionRequest) -> bool:
	if request == null or not request.is_valid_request() \
		or request.action_token != _frozen_action_token \
		or request.player_qi_instance_uids != get_zone_uids(SIDE_PLAYER, ZONE_PENDING) \
		or request.enemy_qi_instance_uids != get_zone_uids(SIDE_ENEMY, ZONE_PENDING):
		return false
	for qi_instance_uid: String in request.player_qi_instance_uids:
		_move_qi_unchecked(SIDE_PLAYER, qi_instance_uid, ZONE_PENDING, ZONE_DISCARD)
		_notify_committed_event(EVENT_QI_DISCARDED, qi_instance_uid, request.action_token)
	for qi_instance_uid: String in request.enemy_qi_instance_uids:
		_move_qi_unchecked(SIDE_ENEMY, qi_instance_uid, ZONE_PENDING, ZONE_DISCARD)
		_notify_committed_event(EVENT_QI_DISCARDED, qi_instance_uid, request.action_token)
	_frozen_action_token = ""
	return true

## 返回当前是否已经确认并等待正式结算。
func is_action_frozen() -> bool:
	return _frozen_action_token != ""

## 返回当前唯一敌人的实例标识。
func get_active_enemy_instance_id() -> String:
	return _active_enemy_instance_id

## 按明确来源和去向移动一张真气；待结算区不能返回手牌。
func move_qi(
		side: String,
		qi_instance_uid: String,
		origin_zone: String,
		destination_zone: String,
		reason: String) -> bool:
	if is_action_frozen() or not _is_valid_side(side) or reason == "" \
		or (origin_zone == ZONE_PENDING and destination_zone == ZONE_HAND) \
		or not _can_move_batch(side, [qi_instance_uid], origin_zone):
		return false
	_move_qi_unchecked(side, qi_instance_uid, origin_zone, destination_zone)
	if destination_zone == ZONE_DISCARD:
		_notify_committed_event(EVENT_QI_DISCARDED, qi_instance_uid, reason)
	elif destination_zone == ZONE_EXHAUST:
		_notify_committed_event(EVENT_QI_EXHAUSTED, qi_instance_uid, reason)
	return true

## 校验一批 UID 是否互不重复且全部位于指定来源牌区。
func _can_move_batch(side: String, qi_instance_uids: Array[String], origin_zone: String) -> bool:
	var origin_uids: Array[String] = get_zone_uids(side, origin_zone)
	var seen_uids: Dictionary[String, bool] = {}
	for qi_instance_uid: String in qi_instance_uids:
		if qi_instance_uid == "" or seen_uids.has(qi_instance_uid) \
			or not origin_uids.has(qi_instance_uid):
			return false
		seen_uids[qi_instance_uid] = true
	return true

## 在已经完成整批校验后移动一张真气，不产生中间失败状态。
func _move_qi_unchecked(side: String, qi_instance_uid: String, origin_zone: String, destination_zone: String) -> void:
	var origin: Array[QiData] = _get_zone_reference(side, origin_zone)
	var destination: Array[QiData] = _get_zone_reference(side, destination_zone)
	for qi_index: int in origin.size():
		if origin[qi_index].object_uid != qi_instance_uid:
			continue
		destination.append(origin[qi_index])
		origin.remove_at(qi_index)
		return

## 向现有生命周期系统发送已经正式提交的事件。
func _notify_committed_event(event_id: String, qi_instance_uid: String, action_token: String) -> void:
	var global_node: Node = _get_global_node()
	var event_token: String = "%s:%s:%s" % [action_token, event_id, qi_instance_uid]
	if global_node != null:
		global_node.notify_qi_event(event_id, qi_instance_uid, event_token)
	else:
		notify_qi_event(event_id, qi_instance_uid, event_token)

## 原地打乱指定牌库；玩家和敌方由调用方提供相互独立的随机流。
func _shuffle_zone(zone: Array[QiData], rng: RandomNumberGenerator) -> void:
	if rng == null:
		return
	for source_index: int in range(zone.size() - 1, 0, -1):
		var target_index: int = rng.randi_range(0, source_index)
		var temporary_qi: QiData = zone[source_index]
		zone[source_index] = zone[target_index]
		zone[target_index] = temporary_qi

## 返回内部牌区引用；仅限本类的移动和查询方法使用。
func _get_zone_reference(side: String, zone: String) -> Array[QiData]:
	if side == SIDE_PLAYER:
		match zone:
			ZONE_DRAW:
				return _player_draw
			ZONE_HAND:
				return _player_hand
			ZONE_DISCARD:
				return _player_discard
			ZONE_EXHAUST:
				return _player_exhaust
			ZONE_PENDING:
				return _player_pending
	elif side == SIDE_ENEMY:
		match zone:
			ZONE_DRAW:
				return _enemy_draw
			ZONE_HAND:
				return _enemy_hand
			ZONE_DISCARD:
				return _enemy_discard
			ZONE_EXHAUST:
				return _enemy_exhaust
			ZONE_PENDING:
				return _enemy_pending
	return []

## 返回是否为受支持的敌我阵营标识。
func _is_valid_side(side: String) -> bool:
	return side == SIDE_PLAYER or side == SIDE_ENEMY

## 清空双方全部牌区和行动冻结状态。
func _clear_zones() -> void:
	_player_draw.clear()
	_player_hand.clear()
	_player_discard.clear()
	_player_exhaust.clear()
	_player_pending.clear()
	_enemy_draw.clear()
	_enemy_hand.clear()
	_enemy_discard.clear()
	_enemy_exhaust.clear()
	_enemy_pending.clear()
	_active_enemy_instance_id = ""
	_frozen_action_token = ""
	_next_action_order = 0

## 查询事件令牌是否已经结算；供 Global 在同步本局异状时避免重复触发。
func has_processed_event(event_token: String) -> bool:
	return event_token != "" and _processed_event_tokens.has(event_token)

## 将一个临时重塑加入指定真气；同一槽位会替换旧临时重塑。
## 预校验战斗临时重塑；不会修改战斗状态。
func can_apply_temporary_reshape(
		qi_instance_uid: String,
		reshape_definition_id: String,
		result_values: Dictionary[String, Variant]) -> bool:
	if qi_instance_uid == "" or reshape_definition_id == "":
		return false
	var global_node: Node = _get_global_node()
	if global_node == null:
		return false
	var definition: QiReshapeData = global_node.get_qi_reshape_data(reshape_definition_id)
	if definition == null or not definition.is_valid_definition():
		return false
	if not definition.allows_scope(QiReshapeData.SCOPE_BATTLE) \
		or not definition.reshape_slot.begins_with("temporary_"):
		return false
	if not JsonStateValidator.is_json_compatible(result_values):
		return false
	if definition.reshape_slot == QiReshapeData.SLOT_TEMPORARY_ATTRIBUTE \
		and not QiData.ATTRIBUTE_IDS.has(str(result_values.get("attribute_id", ""))):
		return false
	if definition.reshape_slot == QiReshapeData.SLOT_TEMPORARY_RANK:
		var rank: int = int(result_values.get("rank", 0))
		if rank < 1 or rank > 13:
			return false
	return true

## 将一个临时重塑加入指定真气；同一槽位会替换旧临时重塑。
func apply_temporary_reshape(
		qi_instance_uid: String,
		reshape_definition_id: String,
		result_values: Dictionary[String, Variant]) -> bool:
	if not can_apply_temporary_reshape(
			qi_instance_uid, reshape_definition_id, result_values):
		return false
	var definition: QiReshapeData = _get_global_node().get_qi_reshape_data(reshape_definition_id)
	var state: QiReshapeState = QiReshapeState.new()
	state.definition_id = reshape_definition_id
	state.state_uid = "%s-battle-reshape-%d" % [qi_instance_uid, _next_state_order + 1]
	state.reshape_slot = definition.reshape_slot
	state.scope = QiReshapeData.SCOPE_BATTLE
	state.result_values = result_values.duplicate(true)
	_next_state_order += 1
	state.applied_order = _next_state_order
	var states: Array = _qi_uid_to_reshape_states.get(qi_instance_uid, [])
	var kept_states: Array = []
	for existing_state: QiReshapeState in states:
		if existing_state.reshape_slot == state.reshape_slot:
			var old_definition: QiReshapeData = _get_global_node().get_qi_reshape_data(existing_state.definition_id)
			QiEffectRuntime.invoke_reshape_remove(
				old_definition, qi_instance_uid, existing_state,
				{"replacement": true})
			continue
		kept_states.append(existing_state)
	kept_states.append(state)
	_qi_uid_to_reshape_states[qi_instance_uid] = kept_states
	QiEffectRuntime.invoke_reshape_apply(
		definition, qi_instance_uid, state, {"scope": QiReshapeData.SCOPE_BATTLE})
	return true

## 将一个战斗异状加入指定真气，并按固定定义执行叠加策略。
func apply_anomaly(
		qi_instance_uid: String,
		anomaly_definition_id: String,
		stacks: int = 1,
		secondary_stacks: int = 0) -> bool:
	if qi_instance_uid == "" or anomaly_definition_id == "" or stacks <= 0:
		return false
	var definition: QiAnomalyData = _get_global_node().get_qi_anomaly_data(anomaly_definition_id)
	if definition == null or not definition.is_valid_definition():
		return false
	if not definition.allows_scope(QiAnomalyData.SCOPE_BATTLE):
		return false
	var states: Array = _qi_uid_to_anomaly_states.get(qi_instance_uid, [])
	for existing_state: QiAnomalyState in states:
		if existing_state.definition_id != anomaly_definition_id:
			continue
		match definition.stack_policy:
			QiAnomalyData.STACK_ADD:
				existing_state.stacks += stacks
				existing_state.secondary_stacks += secondary_stacks
			QiAnomalyData.STACK_REPLACE:
				existing_state.stacks = stacks
				existing_state.secondary_stacks = secondary_stacks
			QiAnomalyData.STACK_KEEP:
				pass
		if definition.max_stacks > 0:
			existing_state.stacks = min(existing_state.stacks, definition.max_stacks)
		QiEffectRuntime.invoke_anomaly_apply(
			definition, qi_instance_uid, existing_state,
			{"scope": QiAnomalyData.SCOPE_BATTLE})
		return true
	var state: QiAnomalyState = QiAnomalyState.new()
	state.definition_id = anomaly_definition_id
	state.scope = QiAnomalyData.SCOPE_BATTLE
	state.stacks = stacks
	state.secondary_stacks = secondary_stacks
	state.expire_events = definition.expire_events.duplicate()
	if definition.max_stacks > 0:
		state.stacks = min(state.stacks, definition.max_stacks)
	_next_state_order += 1
	state.applied_order = _next_state_order
	states.append(state)
	_qi_uid_to_anomaly_states[qi_instance_uid] = states
	QiEffectRuntime.invoke_anomaly_apply(
		definition, qi_instance_uid, state, {"scope": QiAnomalyData.SCOPE_BATTLE})
	return true

## 移除指定真气的临时重塑槽。
func remove_temporary_reshape(qi_instance_uid: String, reshape_slot: String) -> bool:
	var states: Array = _qi_uid_to_reshape_states.get(qi_instance_uid, [])
	for state_index: int in range(states.size() - 1, -1, -1):
		if states[state_index].reshape_slot != reshape_slot:
			continue
		var state: QiReshapeState = states[state_index]
		var definition: QiReshapeData = _get_global_node().get_qi_reshape_data(state.definition_id)
		QiEffectRuntime.invoke_reshape_remove(
			definition, qi_instance_uid, state, {"scope": SCOPE_BATTLE})
		states.remove_at(state_index)
		if states.is_empty():
			_qi_uid_to_reshape_states.erase(qi_instance_uid)
		else:
			_qi_uid_to_reshape_states[qi_instance_uid] = states
		return true
	return false

## 移除指定真气上的一个战斗异状。
func remove_anomaly(qi_instance_uid: String, anomaly_definition_id: String) -> bool:
	var states: Array = _qi_uid_to_anomaly_states.get(qi_instance_uid, [])
	for state_index: int in range(states.size() - 1, -1, -1):
		if states[state_index].definition_id != anomaly_definition_id:
			continue
		var state: QiAnomalyState = states[state_index]
		var definition: QiAnomalyData = _get_global_node().get_qi_anomaly_data(state.definition_id)
		QiEffectRuntime.invoke_anomaly_remove(
			definition, qi_instance_uid, state, {"scope": SCOPE_BATTLE})
		states.remove_at(state_index)
		if states.is_empty():
			_qi_uid_to_anomaly_states.erase(qi_instance_uid)
		else:
			_qi_uid_to_anomaly_states[qi_instance_uid] = states
		return true
	return false

## 处理一个已经提交的真气事件；事件令牌不重复处理。
func notify_qi_event(
		event_id: String,
		qi_instance_uid: String = "",
		event_token: String = "") -> Array[String]:
	if event_id == "":
		return []
	if event_token != "":
		if _processed_event_tokens.has(event_token):
			return []
		_processed_event_tokens[event_token] = true
	if event_id == EVENT_BATTLE_ENDED:
		var cleared_uids: Array[String] = []
		for uid: String in _qi_uid_to_anomaly_states.keys():
			for state: QiAnomalyState in _qi_uid_to_anomaly_states[uid]:
				var anomaly_definition: QiAnomalyData = _get_global_node().get_qi_anomaly_data(state.definition_id)
				QiEffectRuntime.invoke_anomaly_event(
					anomaly_definition, uid, state, event_id, {"scope": SCOPE_BATTLE})
				QiEffectRuntime.invoke_anomaly_remove(
					anomaly_definition, uid, state, {"scope": SCOPE_BATTLE})
			cleared_uids.append(uid)
		for uid: String in _qi_uid_to_reshape_states.keys():
			for state: QiReshapeState in _qi_uid_to_reshape_states[uid]:
				var reshape_definition: QiReshapeData = _get_global_node().get_qi_reshape_data(state.definition_id)
				QiEffectRuntime.invoke_reshape_remove(
					reshape_definition, uid, state, {"scope": SCOPE_BATTLE})
			if not cleared_uids.has(uid):
				cleared_uids.append(uid)
		clear_battle()
		return cleared_uids
	var target_uids: Array[String] = []
	if qi_instance_uid != "":
		target_uids.append(qi_instance_uid)
	else:
		for uid: String in _qi_uid_to_anomaly_states.keys():
			target_uids.append(uid)
		for uid: String in _qi_uid_to_reshape_states.keys():
			if not target_uids.has(uid):
				target_uids.append(uid)
	var removed_definition_ids: Array[String] = []
	for uid: String in target_uids:
		for reshape_state: QiReshapeState in _qi_uid_to_reshape_states.get(uid, []):
			var reshape_definition: QiReshapeData = _get_global_node().get_qi_reshape_data(
				reshape_state.definition_id)
			QiEffectRuntime.invoke_reshape_event(
				reshape_definition, uid, reshape_state, event_id, {"scope": SCOPE_BATTLE})
		var states: Array = _qi_uid_to_anomaly_states.get(uid, [])
		for state_index: int in range(states.size() - 1, -1, -1):
			var state: QiAnomalyState = states[state_index]
			var definition: QiAnomalyData = _get_global_node().get_qi_anomaly_data(state.definition_id)
			QiEffectRuntime.invoke_anomaly_event(
				definition, uid, state, event_id, {"scope": SCOPE_BATTLE})
			if not state.expire_events.has(event_id):
				continue
			QiEffectRuntime.invoke_anomaly_remove(
				definition, uid, state, {"scope": SCOPE_BATTLE})
			removed_definition_ids.append(state.definition_id)
			states.remove_at(state_index)
		if states.is_empty():
			_qi_uid_to_anomaly_states.erase(uid)
		else:
			_qi_uid_to_anomaly_states[uid] = states
	return removed_definition_ids

## 清理战斗状态；不会修改任何 QiData 本局实例。
func clear_battle() -> void:
	_qi_uid_to_reshape_states.clear()
	_qi_uid_to_anomaly_states.clear()
	_processed_event_tokens.clear()
	_clear_zones()

## 返回指定真气的临时重塑副本，调用方不能借此修改容器内部状态。
func get_reshape_states(qi_instance_uid: String) -> Array[QiReshapeState]:
	var result: Array[QiReshapeState] = []
	for state: QiReshapeState in _qi_uid_to_reshape_states.get(qi_instance_uid, []):
		result.append(state.copy_state())
	return result

## 返回指定真气的战斗异状副本，调用方不能借此修改容器内部状态。
func get_anomaly_states(qi_instance_uid: String) -> Array[QiAnomalyState]:
	var result: Array[QiAnomalyState] = []
	for state: QiAnomalyState in _qi_uid_to_anomaly_states.get(qi_instance_uid, []):
		result.append(state.copy_state())
	return result

## 判断指定真气当前是否拥有某个战斗异状。
func has_anomaly(qi_instance_uid: String, anomaly_definition_id: String) -> bool:
	for state: QiAnomalyState in _qi_uid_to_anomaly_states.get(qi_instance_uid, []):
		if state.definition_id == anomaly_definition_id and state.stacks > 0:
			return true
	return false

## 通过场景树读取 Global，避免战斗现场容器与自动加载脚本形成编译循环。
func _get_global_node() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null or not main_loop is SceneTree:
		return null
	return (main_loop as SceneTree).root.get_node_or_null("Global")
