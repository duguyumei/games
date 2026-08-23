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

## 当前行动中敌方待结算区已经翻开的牌数；只属于战斗现场，不参与结算请求或存档。
var _enemy_revealed_pending_count: int = 0

## 当前唯一敌人的实例标识。
var _active_enemy_instance_id: String = ""

## 递增的行动序号，用于生成稳定且不可复用的冻结令牌。
var _next_action_order: int = 0

## 当前已经冻结、等待结算器处理的请求令牌。
var _frozen_action_token: String = ""

## 玩家当前连击槽值。
var _player_combo_value: int = 0

## 敌方当前连击槽值。
var _enemy_combo_value: int = 0

## 连击槽上限；后续可以由战斗规则查询覆盖。
var _combo_capacity: int = 5

## 当前回合序号；连击行动不会增加回合序号。
var _round_number: int = 0

## 下一次行动允许出牌的阵营。
var _next_action_sides: Array[String] = []

## 下一次行动是否需要先进行回合开始补牌。
var _needs_round_start_draw: bool = true

## 玩家八种牌型的战斗循环功法队列。
var _player_gongfa_queues: Dictionary[String, GongfaQueueState] = {}

## 敌方八种牌型的战斗循环功法队列；当前默认为空，保留后续敌人配置入口。
var _enemy_gongfa_queues: Dictionary[String, GongfaQueueState] = {}

## 玩家战斗内功槽的有序实例 UID快照。
var _player_neigong_slot_uids: Array[String] = []

## 敌方战斗内功槽的有序实例 UID快照；当前敌方默认全部为空。
var _enemy_neigong_slot_uids: Array[String] = []

## 玩家战斗内功槽容量快照。
var _player_neigong_slot_capacity: int = 6

## 敌方战斗内功槽容量快照。
var _enemy_neigong_slot_capacity: int = 6

## 敌方战斗内功槽使用的固定定义 ID；实例只属于本场战斗。
var _enemy_neigong_definition_ids: Array[String] = []

## 每张真气 UID 对应的临时重塑列表。
var _qi_uid_to_reshape_states: Dictionary = {}

## 每张真气 UID 对应的战斗异状列表。
var _qi_uid_to_anomaly_states: Dictionary = {}

## 玩家护盾来源队列；每条来源独立扣减和回合衰减。
var _player_shield_entries: Array[BattleDefenseEntry] = []

## 敌方护盾来源队列；每条来源独立扣减和回合衰减。
var _enemy_shield_entries: Array[BattleDefenseEntry] = []

## 玩家反震比例来源队列；实际结算取有效来源中的最大值。
var _player_reflect_entries: Array[BattleDefenseEntry] = []

## 敌方反震比例来源队列；实际结算取有效来源中的最大值。
var _enemy_reflect_entries: Array[BattleDefenseEntry] = []

## 玩家格挡来源队列；下一次直接伤害严格消耗队首。
var _player_guard_entries: Array[BattleDefenseEntry] = []

## 敌方格挡来源队列；下一次直接伤害严格消耗队首。
var _enemy_guard_entries: Array[BattleDefenseEntry] = []

## 玩家化解值来源队列；总值可叠加，消耗按来源顺序处理。
var _player_resolution_entries: Array[BattleDefenseEntry] = []

## 敌方化解值来源队列；总值可叠加，消耗按来源顺序处理。
var _enemy_resolution_entries: Array[BattleDefenseEntry] = []

## 玩家穿透比例来源队列；按伤害类型读取最高有效值。
var _player_penetration_entries: Array[BattleDefenseEntry] = []

## 敌方穿透比例来源队列；按伤害类型读取最高有效值。
var _enemy_penetration_entries: Array[BattleDefenseEntry] = []

## 递增序号保证同一来源状态的替换和处理顺序稳定。
var _next_state_order: int = 0

## 递增序号保证防御来源条目的注册顺序稳定。
var _next_defense_entry_order: int = 0

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

## 从玩家本局配装和敌方固定设定创建战斗内功槽及八条功法队列。
func initialize_loadouts(
		player_data: PlayerData,
		enemy_data: EnemyData = null) -> bool:
	_player_gongfa_queues.clear()
	_enemy_gongfa_queues.clear()
	_player_neigong_slot_uids.clear()
	_enemy_neigong_slot_uids.clear()
	_enemy_neigong_definition_ids.clear()
	_player_neigong_slot_capacity = 6
	_enemy_neigong_slot_capacity = 6
	if player_data == null or enemy_data == null:
		return false
	_player_neigong_slot_capacity = player_data.get_effective_neigong_slot_count()
	for neigong_uid: String in player_data.player_equipped_neigong_uids:
		if _player_neigong_slot_uids.size() >= _player_neigong_slot_capacity:
			break
		if player_data.get_owned_neigong(neigong_uid) != null:
			_player_neigong_slot_uids.append(neigong_uid)
	_enemy_neigong_slot_capacity = max(enemy_data.enemy_neigong_slot_count, 0)
	if enemy_data.enemy_neigong_definition_ids.size() > _enemy_neigong_slot_capacity:
		return false
	for definition_id: String in enemy_data.enemy_neigong_definition_ids:
		if definition_id == "" or Global.get_neigong_data(definition_id) == null:
			return false
		_enemy_neigong_definition_ids.append(definition_id)
		_enemy_neigong_slot_uids.append("enemy-neigong-%s-%d" % [
			_active_enemy_instance_id, _enemy_neigong_definition_ids.size() - 1])
	for hand_type_id: String in GongfaData.HAND_TYPE_IDS:
		var player_queue := GongfaQueueState.new()
		player_queue.initialize(
			hand_type_id,
			player_data.get_effective_gongfa_slot_count(hand_type_id),
			player_data.player_gongfa_hand_sequences.get(hand_type_id, []))
		_player_gongfa_queues[hand_type_id] = player_queue
		var enemy_queue := GongfaQueueState.new()
		var enemy_capacity: int = max(int(
			enemy_data.enemy_gongfa_slot_counts.get(hand_type_id, 1)), 1)
		var enemy_definition_values: Variant = enemy_data.enemy_gongfa_loadout.get(
			hand_type_id, [])
		if not enemy_definition_values is Array:
			return false
		if enemy_definition_values.size() > enemy_capacity:
			return false
		for enemy_definition_value: Variant in enemy_definition_values:
			if not enemy_definition_value is String \
					or str(enemy_definition_value) == "":
				return false
			var enemy_gongfa_data: GongfaData = Global.get_gongfa_data(
				str(enemy_definition_value))
			if enemy_gongfa_data == null \
					or not enemy_gongfa_data.supports_hand_type(hand_type_id):
				return false
		if not enemy_queue.initialize_from_definition_ids(
			hand_type_id,
			enemy_capacity,
			enemy_definition_values,
			"enemy-%s" % _active_enemy_instance_id):
			return false
		_enemy_gongfa_queues[hand_type_id] = enemy_queue
	return true

## 返回指定阵营和牌型的战斗功法队列内容副本。
func get_gongfa_queue_entries(side: String, hand_type_id: String) -> Array[Dictionary]:
	var queues: Dictionary = _player_gongfa_queues if side == SIDE_PLAYER else _enemy_gongfa_queues
	var queue: GongfaQueueState = queues.get(hand_type_id, null)
	return queue.get_entries() if queue != null else []

## 返回指定阵营和牌型的战斗功法队列容量。
func get_gongfa_queue_capacity(side: String, hand_type_id: String) -> int:
	var queues: Dictionary = _player_gongfa_queues if side == SIDE_PLAYER else _enemy_gongfa_queues
	var queue: GongfaQueueState = queues.get(hand_type_id, null)
	return queue.capacity if queue != null else 0

## 返回指定阵营当前装备内功槽的 UID副本。
func get_neigong_slot_uids(side: String) -> Array[String]:
	return (_player_neigong_slot_uids if side == SIDE_PLAYER else _enemy_neigong_slot_uids).duplicate()

## 返回双方战斗内功槽的展示数据，不暴露可修改的内部数组。
func get_neigong_slot_entries(side: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if side == SIDE_PLAYER and Global.player_data != null:
		for neigong_uid: String in _player_neigong_slot_uids:
			var player_neigong: NeigongData = Global.player_data.get_owned_neigong(neigong_uid)
			result.append({
				"instance_uid": neigong_uid,
				"definition_id": player_neigong.object_id if player_neigong != null else "",
				"name": player_neigong.neigong_name if player_neigong != null else "空槽",
			})
		return result
	if side == SIDE_ENEMY:
		for definition_index: int in _enemy_neigong_definition_ids.size():
			var definition_id: String = _enemy_neigong_definition_ids[definition_index]
			var enemy_neigong: NeigongData = Global.get_neigong_data(definition_id)
			result.append({
				"instance_uid": _enemy_neigong_slot_uids[definition_index],
				"definition_id": definition_id,
				"name": enemy_neigong.neigong_name if enemy_neigong != null else definition_id,
			})
	return result

## 返回指定阵营的战斗内功槽容量。
func get_neigong_slot_capacity(side: String) -> int:
	return _player_neigong_slot_capacity if side == SIDE_PLAYER else _enemy_neigong_slot_capacity

## 添加一条带来源和生命周期的战斗防御效果，并返回稳定运行时 UID。
func add_defense_entry(
		side: String,
		kind: String,
		value: float,
		source_kind: String,
		source_instance_id: String,
		affected_damage_types: Array[String] = [],
		duration_scope: String = "battle",
		remaining_rounds: int = -1,
		remaining_hits: int = -1,
		decay_policy: String = "halve") -> String:
	if not _is_valid_side(side) or value <= 0.0 \
		or not [BattleDefenseEntry.SCOPE_BATTLE, BattleDefenseEntry.SCOPE_ROUNDS,
		BattleDefenseEntry.SCOPE_HITS].has(duration_scope):
		return ""
	if not [
		BattleDefenseEntry.KIND_SHIELD,
		BattleDefenseEntry.KIND_REFLECT,
		BattleDefenseEntry.KIND_GUARD,
		BattleDefenseEntry.KIND_RESOLUTION,
		BattleDefenseEntry.KIND_PENETRATION,
	].has(kind):
		return ""
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(side, kind)
	_next_defense_entry_order += 1
	var entry_uid: String = "battle-defense-%d" % _next_defense_entry_order
	entries.append(BattleDefenseEntry.create(
		entry_uid,
		kind,
		value,
		source_kind,
		source_instance_id,
		_next_defense_entry_order,
		affected_damage_types,
		duration_scope,
		remaining_rounds,
		remaining_hits,
		decay_policy))
	_emit_defense_changed(side, kind)
	return entry_uid

## 添加护盾来源；护盾默认在回合结束时独立减半。
func add_shield(
		side: String,
		amount: int,
		source_kind: String,
		source_instance_id: String,
		duration_scope: String = "battle",
		remaining_rounds: int = -1,
		remaining_hits: int = -1,
		decay_policy: String = "halve") -> String:
	return add_defense_entry(
		side,
		BattleDefenseEntry.KIND_SHIELD,
		amount,
		source_kind,
		source_instance_id,
		[],
		duration_scope,
		remaining_rounds,
		remaining_hits,
		decay_policy)

## 添加反震比例来源；多个有效来源结算时取最高值。
func add_reflect_ratio(
		side: String,
		ratio: float,
		source_kind: String,
		source_instance_id: String,
		duration_scope: String = "battle",
		remaining_rounds: int = -1,
		remaining_hits: int = -1) -> String:
	return add_defense_entry(
		side,
		BattleDefenseEntry.KIND_REFLECT,
		ratio,
		source_kind,
		source_instance_id,
		[],
		duration_scope,
		remaining_rounds,
		remaining_hits)

## 添加指定次数的格挡来源；每一次格挡都是队列中的独立条目。
func add_guard(
		side: String,
		count: int,
		source_kind: String,
		source_instance_id: String,
		duration_scope: String = "battle",
		remaining_rounds: int = -1,
		remaining_hits: int = -1) -> int:
	var added_count: int = 0
	for _guard_index: int in max(count, 0):
		if add_defense_entry(
				side,
				BattleDefenseEntry.KIND_GUARD,
				1,
				source_kind,
				source_instance_id,
				[],
				duration_scope,
				remaining_rounds,
				remaining_hits) != "":
			added_count += 1
	return added_count

## 添加化解值来源；总化解值不设置上限。
func add_resolution(
		side: String,
		amount: int,
		source_kind: String,
		source_instance_id: String,
		duration_scope: String = "battle",
		remaining_rounds: int = -1,
		remaining_hits: int = -1) -> String:
	return add_defense_entry(
		side,
		BattleDefenseEntry.KIND_RESOLUTION,
		amount,
		source_kind,
		source_instance_id,
		[],
		duration_scope,
		remaining_rounds,
		remaining_hits)

## 添加指定伤害类型的护盾穿透比例来源；不对内容数值设置硬上限。
func add_shield_penetration(
		side: String,
		damage_types: Array[String],
		ratio: float,
		source_kind: String,
		source_instance_id: String,
		duration_scope: String = "battle",
		remaining_rounds: int = -1,
		remaining_hits: int = -1) -> String:
	return add_defense_entry(
		side,
		BattleDefenseEntry.KIND_PENETRATION,
		ratio,
		source_kind,
		source_instance_id,
		damage_types,
		duration_scope,
		remaining_rounds,
		remaining_hits)

## 返回指定阵营当前护盾总值；来源条目仍保持独立。
func get_shield(side: String) -> int:
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(
		side, BattleDefenseEntry.KIND_SHIELD)
	_cleanup_entries(entries)
	var total: int = 0
	for entry: BattleDefenseEntry in entries:
		total += max(int(entry.value), 0)
	return total

## 返回指定阵营当前有效的最高反震比例。
func get_reflect_ratio(side: String) -> float:
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(
		side, BattleDefenseEntry.KIND_REFLECT)
	_cleanup_entries(entries)
	var maximum: float = 0.0
	for entry: BattleDefenseEntry in entries:
		maximum = max(maximum, entry.value)
	return maximum

## 返回指定伤害类型当前有效的最高护盾穿透比例。
func get_shield_penetration_ratio(side: String, damage_type: String) -> float:
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(
		side, BattleDefenseEntry.KIND_PENETRATION)
	_cleanup_entries(entries)
	var maximum: float = 0.0
	for entry: BattleDefenseEntry in entries:
		if entry.affects_damage_type(damage_type):
			maximum = max(maximum, entry.value)
	return maximum

## 返回指定阵营当前化解总值；不设置上限。
func get_resolution_value(side: String) -> int:
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(
		side, BattleDefenseEntry.KIND_RESOLUTION)
	_cleanup_entries(entries)
	var total: int = 0
	for entry: BattleDefenseEntry in entries:
		total += max(int(entry.value), 0)
	return total

## 返回指定阵营当前格挡次数。
func get_guard_count(side: String) -> int:
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(
		side, BattleDefenseEntry.KIND_GUARD)
	_cleanup_entries(entries)
	return entries.size()

## 消耗指定阵营队首的一层格挡。
func consume_guard(side: String) -> bool:
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(
		side, BattleDefenseEntry.KIND_GUARD)
	_cleanup_entries(entries)
	if entries.is_empty():
		return false
	entries.remove_at(0)
	_emit_defense_changed(side, BattleDefenseEntry.KIND_GUARD)
	return true

## 尝试用化解值取消一次直接伤害；超过总值时清空化解但不改变伤害。
func consume_resolution(side: String, damage_amount: int) -> Dictionary:
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(
		side, BattleDefenseEntry.KIND_RESOLUTION)
	_cleanup_entries(entries)
	var total: int = get_resolution_value(side)
	if damage_amount <= 0 or total <= 0:
		return {"prevented": false, "consumed": 0}
	if damage_amount > total:
		var consumed_all: int = total
		for entry: BattleDefenseEntry in entries:
			if entry.value <= 0.0:
				continue
			entry.value = 0.0
			if entry.remaining_hits > 0:
				entry.remaining_hits -= 1
		_cleanup_entries(entries)
		_emit_defense_changed(side, BattleDefenseEntry.KIND_RESOLUTION)
		return {"prevented": false, "consumed": consumed_all}
	var remaining_to_consume: int = damage_amount
	var consumed: int = 0
	for entry: BattleDefenseEntry in entries:
		if remaining_to_consume <= 0:
			break
		var entry_value: int = max(int(entry.value), 0)
		var entry_consumed: int = min(entry_value, remaining_to_consume)
		entry.value -= entry_consumed
		remaining_to_consume -= entry_consumed
		consumed += entry_consumed
		if entry_consumed > 0 and entry.remaining_hits > 0:
			entry.remaining_hits -= 1
	_cleanup_entries(entries)
	_emit_defense_changed(side, BattleDefenseEntry.KIND_RESOLUTION)
	return {"prevented": true, "consumed": consumed}

## 按来源顺序吸收护盾，并返回实际吸收量。
func absorb_shield(side: String, damage_amount: int) -> int:
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(
		side, BattleDefenseEntry.KIND_SHIELD)
	_cleanup_entries(entries)
	var remaining_damage: int = max(damage_amount, 0)
	var absorbed: int = 0
	for entry: BattleDefenseEntry in entries:
		if remaining_damage <= 0:
			break
		var entry_value: int = max(int(entry.value), 0)
		var entry_absorbed: int = min(entry_value, remaining_damage)
		entry.value -= entry_absorbed
		remaining_damage -= entry_absorbed
		absorbed += entry_absorbed
		if entry_absorbed > 0 and entry.remaining_hits > 0:
			entry.remaining_hits -= 1
	_cleanup_entries(entries)
	if absorbed > 0:
		_emit_defense_changed(side, BattleDefenseEntry.KIND_SHIELD)
	return absorbed

## 消耗一个实际采用的最高值修正来源；较低值来源不会被误消耗。
func consume_highest_modifier_hit(
		side: String, kind: String, damage_type: String = "") -> bool:
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(side, kind)
	_cleanup_entries(entries)
	var maximum: float = -INF
	for entry: BattleDefenseEntry in entries:
		if damage_type != "" and not entry.affects_damage_type(damage_type):
			continue
		maximum = max(maximum, entry.value)
	if maximum == -INF:
		return false
	for entry: BattleDefenseEntry in entries:
		if entry.value != maximum:
			continue
		if damage_type != "" and not entry.affects_damage_type(damage_type):
			continue
		if entry.remaining_hits > 0:
			entry.remaining_hits -= 1
		_cleanup_entries(entries)
		_emit_defense_changed(side, kind)
		return true
	return false

## 在回合结束时逐来源衰减护盾，并递减所有回合生命周期。
func decay_shields_at_round_end() -> void:
	for side: String in [SIDE_PLAYER, SIDE_ENEMY]:
		var shield_entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(
			side, BattleDefenseEntry.KIND_SHIELD)
		for entry: BattleDefenseEntry in shield_entries:
			if entry.decay_policy == "halve":
				entry.value = floor(entry.value * 0.5)
		for kind: String in [
			BattleDefenseEntry.KIND_SHIELD,
			BattleDefenseEntry.KIND_REFLECT,
			BattleDefenseEntry.KIND_GUARD,
			BattleDefenseEntry.KIND_RESOLUTION,
			BattleDefenseEntry.KIND_PENETRATION,
		]:
			_decrement_rounds(_get_defense_entries_reference(side, kind))
		_cleanup_all_defense_entries(side)
		for kind: String in [
			BattleDefenseEntry.KIND_SHIELD,
			BattleDefenseEntry.KIND_REFLECT,
			BattleDefenseEntry.KIND_GUARD,
			BattleDefenseEntry.KIND_RESOLUTION,
			BattleDefenseEntry.KIND_PENETRATION,
		]:
			_emit_defense_changed(side, kind)

## 消耗参与本次伤害计算的次数型修正。
func consume_damage_modifier_hits(
		side: String, damage_type: String, only_kinds: Array[String]) -> void:
	for kind: String in only_kinds:
		var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(side, kind)
		for entry: BattleDefenseEntry in entries:
			if not entry.affects_damage_type(damage_type) or entry.remaining_hits < 0:
				continue
			entry.remaining_hits -= 1
		_cleanup_all_defense_entries(side)

## 移除一个精确来源条目。
func remove_defense_entry(entry_uid: String) -> bool:
	if entry_uid == "":
		return false
	for side: String in [SIDE_PLAYER, SIDE_ENEMY]:
		for kind: String in [
			BattleDefenseEntry.KIND_SHIELD,
			BattleDefenseEntry.KIND_REFLECT,
			BattleDefenseEntry.KIND_GUARD,
			BattleDefenseEntry.KIND_RESOLUTION,
			BattleDefenseEntry.KIND_PENETRATION,
		]:
			var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(side, kind)
			for index: int in entries.size():
				if entries[index].entry_uid != entry_uid:
					continue
				entries.remove_at(index)
				_emit_defense_changed(side, kind)
				return true
	return false

## 清空指定阵营指定类型的所有防御来源。
func clear_defense_kind(side: String, kind: String) -> void:
	if not _is_valid_side(side) or not [
		BattleDefenseEntry.KIND_SHIELD,
		BattleDefenseEntry.KIND_REFLECT,
		BattleDefenseEntry.KIND_GUARD,
		BattleDefenseEntry.KIND_RESOLUTION,
		BattleDefenseEntry.KIND_PENETRATION,
	].has(kind):
		return
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(side, kind)
	entries.clear()
	_emit_defense_changed(side, kind)

## 返回指定来源条目的只读副本，供界面和调试使用。
func get_defense_entries(side: String, kind: String) -> Array[BattleDefenseEntry]:
	var result: Array[BattleDefenseEntry] = []
	var entries: Array[BattleDefenseEntry] = _get_defense_entries_reference(side, kind)
	_cleanup_entries(entries)
	for entry: BattleDefenseEntry in entries:
		result.append(entry.copy_entry())
	return result

## 返回指定阵营按来源顺序排列的护盾条目副本。
func get_shield_entries(side: String) -> Array[BattleDefenseEntry]:
	return get_defense_entries(side, BattleDefenseEntry.KIND_SHIELD)

## 返回指定阵营按来源顺序排列的反震条目副本。
func get_reflect_entries(side: String) -> Array[BattleDefenseEntry]:
	return get_defense_entries(side, BattleDefenseEntry.KIND_REFLECT)

## 返回指定阵营严格 FIFO 的格挡条目副本。
func get_guard_entries(side: String) -> Array[BattleDefenseEntry]:
	return get_defense_entries(side, BattleDefenseEntry.KIND_GUARD)

## 返回指定阵营按来源顺序排列的化解条目副本。
func get_resolution_entries(side: String) -> Array[BattleDefenseEntry]:
	return get_defense_entries(side, BattleDefenseEntry.KIND_RESOLUTION)

## 返回指定阵营按伤害类型筛选的穿透条目副本。
func get_penetration_entries(side: String) -> Array[BattleDefenseEntry]:
	return get_defense_entries(side, BattleDefenseEntry.KIND_PENETRATION)

## 根据当前待结算区的纯牌型识别结果返回牌型 ID，供冻结请求记录功法槽。
func _get_pending_hand_type(side: String) -> String:
	var pattern: QiHandPatternResult = QiHandRecognizer.recognize(
		get_zone(side, ZONE_PENDING), self)
	return pattern.hand_type_id if pattern != null and pattern.is_valid() else ""

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

## 开始一个行动窗口；仅在新回合时补牌，连击行动保留双方当前手牌。
func begin_action_window() -> bool:
	if is_action_frozen() or _next_action_sides.is_empty() and not _needs_round_start_draw:
		return false
	if not _needs_round_start_draw:
		if is_side_eligible(SIDE_PLAYER) and _player_hand.is_empty():
			_next_action_sides.erase(SIDE_PLAYER)
		if is_side_eligible(SIDE_ENEMY) and _enemy_hand.is_empty():
			_next_action_sides.erase(SIDE_ENEMY)
		if _next_action_sides.is_empty():
			_needs_round_start_draw = true
	if _needs_round_start_draw:
		_round_number += 1
		draw_to_hand_limit(SIDE_PLAYER, HAND_LIMIT)
		draw_to_hand_limit(SIDE_ENEMY, HAND_LIMIT)
		_next_action_sides = [SIDE_PLAYER, SIDE_ENEMY]
		if _player_hand.is_empty():
			_next_action_sides.erase(SIDE_PLAYER)
		if _enemy_hand.is_empty():
			_next_action_sides.erase(SIDE_ENEMY)
		_needs_round_start_draw = false
	return not _next_action_sides.is_empty()

## 返回当前行动是否允许指定阵营出牌。
func is_side_eligible(side: String) -> bool:
	return _next_action_sides.has(side)

## 返回当前行动允许出牌的阵营副本。
func get_eligible_sides() -> Array[String]:
	return _next_action_sides.duplicate()

## 返回当前回合序号。
func get_round_number() -> int:
	return _round_number

## 返回指定阵营的连击槽值。
func get_combo_value(side: String) -> int:
	if side == SIDE_PLAYER:
		return _player_combo_value
	if side == SIDE_ENEMY:
		return _enemy_combo_value
	return 0

## 返回连击槽上限。
func get_combo_capacity() -> int:
	return _combo_capacity

## 设置连击槽上限；不会降低当前已积累值。
func set_combo_capacity(capacity: int) -> void:
	_combo_capacity = max(capacity, 1)

## 根据本次识别结果推进连击槽并准备下一次行动。
func advance_after_action(request: QiActionRequest) -> void:
	var player_gain: int = 0
	var enemy_gain: int = 0
	if request.player_result != null and request.player_result.pattern != null:
		player_gain = request.player_result.pattern.max_same_qi
	if request.enemy_result != null and request.enemy_result.pattern != null:
		enemy_gain = request.enemy_result.pattern.max_same_qi
	request.player_combo_before = _player_combo_value
	request.enemy_combo_before = _enemy_combo_value
	_player_combo_value += player_gain
	_enemy_combo_value += enemy_gain
	_next_action_sides.clear()
	if _player_combo_value >= _combo_capacity:
		_player_combo_value = 0
		_next_action_sides.append(SIDE_PLAYER)
	if _enemy_combo_value >= _combo_capacity:
		_enemy_combo_value = 0
		_next_action_sides.append(SIDE_ENEMY)
	request.player_combo_after = _player_combo_value
	request.enemy_combo_after = _enemy_combo_value
	if _next_action_sides.is_empty():
		decay_shields_at_round_end()
		_needs_round_start_draw = true
		request.eligible_sides = []
	else:
		_needs_round_start_draw = false
		request.eligible_sides = _next_action_sides.duplicate()

## 返回当前是否等待下一回合补牌。
func needs_round_start_draw() -> bool:
	return _needs_round_start_draw

## 返回指定阵营和牌型当前指向的功法实例 UID；没有配装时返回空字符串。
func get_current_gongfa_instance_uid(
		hand_type_id: String, side: String = SIDE_PLAYER) -> String:
	var front: Dictionary = get_current_gongfa_slot(hand_type_id, side)
	return str(front.get("gongfa_instance_uid", ""))

## 返回指定阵营牌型队列第一项的独立副本。
func get_current_gongfa_slot(hand_type_id: String, side: String = SIDE_PLAYER) -> Dictionary:
	var queues: Dictionary = _player_gongfa_queues if side == SIDE_PLAYER else _enemy_gongfa_queues
	var queue: GongfaQueueState = queues.get(hand_type_id, null)
	return queue.peek_front() if queue != null else {}

## 校验冻结请求中的战斗功法实例仍是当前队列第一项。
func is_current_gongfa_slot(
		hand_type_id: String, side: String, slot_instance_id: String) -> bool:
	return str(get_current_gongfa_slot(hand_type_id, side).get(
		"slot_instance_id", "")) == slot_instance_id

## 推进指定阵营牌型队列，并按请求数量尝试生成临时复制品。
func advance_gongfa_sequence(
		hand_type_id: String,
		side: String = SIDE_PLAYER,
		requested_copy_count: int = 0) -> Dictionary:
	var queues: Dictionary = _player_gongfa_queues if side == SIDE_PLAYER else _enemy_gongfa_queues
	var queue: GongfaQueueState = queues.get(hand_type_id, null)
	if queue == null:
		return {}
	return queue.trigger_front(requested_copy_count)

## 原子提交玩家本批选中的真气；顺序使用调用方给出的点击顺序。
func commit_player_selection(qi_instance_uids: Array[String]) -> bool:
	if is_action_frozen() or qi_instance_uids.is_empty() \
		or _player_pending.size() + qi_instance_uids.size() > PENDING_LIMIT:
		return false
	if not _can_move_batch(SIDE_PLAYER, qi_instance_uids, ZONE_HAND):
		return false
	for qi_instance_uid: String in qi_instance_uids:
		_move_qi_unchecked(SIDE_PLAYER, qi_instance_uid, ZONE_HAND, ZONE_PENDING)
	_reveal_enemy_pending(qi_instance_uids.size())
	return true

## 敌方按当前手牌顺序提交前若干张真气到待结算区。
func prepare_enemy_pending(play_count: int) -> int:
	if is_action_frozen() or not is_side_eligible(SIDE_ENEMY) \
		or not _enemy_pending.is_empty():
		return 0
	_enemy_revealed_pending_count = 0
	var actual_count: int = min(clamp(play_count, 1, PENDING_LIMIT), _enemy_hand.size())
	var selected_uids: Array[String] = []
	for qi_index: int in actual_count:
		selected_uids.append(_enemy_hand[qi_index].object_uid)
	for qi_instance_uid: String in selected_uids:
		_move_qi_unchecked(SIDE_ENEMY, qi_instance_uid, ZONE_HAND, ZONE_PENDING)
	return actual_count

## 冻结双方待结算区并返回整体行动请求；连击允许只有一方有牌。
func freeze_action() -> QiActionRequest:
	if is_action_frozen() or _next_action_sides.is_empty() \
		or is_side_eligible(SIDE_PLAYER) and _player_pending.is_empty() \
		or _player_pending.size() > PENDING_LIMIT \
		or _enemy_pending.size() > PENDING_LIMIT:
		return null
	_reveal_enemy_pending(_enemy_pending.size())
	_next_action_order += 1
	_frozen_action_token = "qi-action-%d" % _next_action_order
	var request: QiActionRequest = QiActionRequest.new()
	request.initialize(
		_frozen_action_token,
		_active_enemy_instance_id,
		get_zone_uids(SIDE_PLAYER, ZONE_PENDING),
		get_zone_uids(SIDE_ENEMY, ZONE_PENDING),
		_next_action_sides,
		get_current_gongfa_slot(
			_get_pending_hand_type(SIDE_PLAYER), SIDE_PLAYER).get("slot_instance_id", ""),
		get_current_gongfa_slot(
			_get_pending_hand_type(SIDE_ENEMY), SIDE_ENEMY).get("slot_instance_id", ""))
	return request

## 完成指定冻结请求，将双方待结算真气依次移入各自弃牌堆。
func complete_qi_action(request: QiActionRequest) -> bool:
	if request == null or not request.is_valid_request() \
		or request.action_token != _frozen_action_token \
		or request.enemy_instance_id != _active_enemy_instance_id \
		or request.player_qi_instance_uids != get_zone_uids(SIDE_PLAYER, ZONE_PENDING) \
		or request.enemy_qi_instance_uids != get_zone_uids(SIDE_ENEMY, ZONE_PENDING):
		return false
	if request.player_result != null and request.player_result.is_valid() \
		and not is_current_gongfa_slot(
			request.player_result.pattern.hand_type_id,
			SIDE_PLAYER,
			request.player_gongfa_slot_instance_id):
		return false
	if request.enemy_result != null and request.enemy_result.is_valid() \
		and not is_current_gongfa_slot(
			request.enemy_result.pattern.hand_type_id,
			SIDE_ENEMY,
			request.enemy_gongfa_slot_instance_id):
		return false
	for qi_instance_uid: String in request.player_qi_instance_uids:
		_move_qi_unchecked(SIDE_PLAYER, qi_instance_uid, ZONE_PENDING, ZONE_DISCARD)
		_notify_committed_event(EVENT_QI_DISCARDED, qi_instance_uid, request.action_token)
	for qi_instance_uid: String in request.enemy_qi_instance_uids:
		_move_qi_unchecked(SIDE_ENEMY, qi_instance_uid, ZONE_PENDING, ZONE_DISCARD)
		_notify_committed_event(EVENT_QI_DISCARDED, qi_instance_uid, request.action_token)
	if request.player_result != null and request.player_result.is_valid():
		advance_gongfa_sequence(
			request.player_result.pattern.hand_type_id,
			SIDE_PLAYER,
			request.player_result.gongfa_copy_count)
	if request.enemy_result != null and request.enemy_result.is_valid():
		advance_gongfa_sequence(
			request.enemy_result.pattern.hand_type_id,
			SIDE_ENEMY,
			request.enemy_result.gongfa_copy_count)
	advance_after_action(request)
	_frozen_action_token = ""
	_enemy_revealed_pending_count = 0
	return true

## 返回当前是否已经确认并等待正式结算。
func is_action_frozen() -> bool:
	return _frozen_action_token != ""

## 返回当前行动中敌方待结算区已经翻开的牌数。
func get_enemy_revealed_pending_count() -> int:
	return _enemy_revealed_pending_count

## 按玩家本次成功提交的牌数，从敌方待结算区左侧继续翻牌。
func _reveal_enemy_pending(reveal_count: int) -> void:
	_enemy_revealed_pending_count = clamp(
		_enemy_revealed_pending_count + max(0, reveal_count),
		0,
		_enemy_pending.size())

## 取消尚未执行效果的冻结请求；牌仍留在待结算区，允许重新确认。
func cancel_frozen_action(request: QiActionRequest) -> bool:
	if request == null or request.action_token != _frozen_action_token:
		return false
	_frozen_action_token = ""
	return true

## 返回当前唯一敌人的实例标识。
func get_active_enemy_instance_id() -> String:
	return _active_enemy_instance_id

## 根据战斗对象返回玩家或敌方阵营；未知对象返回空字符串。
func get_combatant_side(combatant: BaseCombatant) -> String:
	if combatant == null:
		return ""
	if combatant.is_in_group("players"):
		return SIDE_PLAYER
	if combatant.is_in_group("enemies_alive_or_dead") or combatant.is_in_group("enemies"):
		return SIDE_ENEMY
	return ""

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
	_enemy_revealed_pending_count = 0
	_active_enemy_instance_id = ""
	_frozen_action_token = ""
	_next_action_order = 0
	_player_combo_value = 0
	_enemy_combo_value = 0
	_combo_capacity = 5
	_round_number = 0
	_next_action_sides.clear()
	_needs_round_start_draw = true
	_processed_event_tokens.clear()
	_player_gongfa_queues.clear()
	_enemy_gongfa_queues.clear()
	_player_neigong_slot_uids.clear()
	_enemy_neigong_slot_uids.clear()
	_enemy_neigong_definition_ids.clear()
	_player_neigong_slot_capacity = 6
	_enemy_neigong_slot_capacity = 6
	_clear_defense_entries()
	_next_defense_entry_order = 0

## 返回指定阵营和类型的内部来源队列。
func _get_defense_entries_reference(
		side: String, kind: String) -> Array[BattleDefenseEntry]:
	if side == SIDE_PLAYER:
		match kind:
			BattleDefenseEntry.KIND_SHIELD:
				return _player_shield_entries
			BattleDefenseEntry.KIND_REFLECT:
				return _player_reflect_entries
			BattleDefenseEntry.KIND_GUARD:
				return _player_guard_entries
			BattleDefenseEntry.KIND_RESOLUTION:
				return _player_resolution_entries
			BattleDefenseEntry.KIND_PENETRATION:
				return _player_penetration_entries
	if side == SIDE_ENEMY:
		match kind:
			BattleDefenseEntry.KIND_SHIELD:
				return _enemy_shield_entries
			BattleDefenseEntry.KIND_REFLECT:
				return _enemy_reflect_entries
			BattleDefenseEntry.KIND_GUARD:
				return _enemy_guard_entries
			BattleDefenseEntry.KIND_RESOLUTION:
				return _enemy_resolution_entries
			BattleDefenseEntry.KIND_PENETRATION:
				return _enemy_penetration_entries
	var empty_entries: Array[BattleDefenseEntry] = []
	return empty_entries

## 删除已经过期或归零的来源条目。
func _cleanup_entries(entries: Array[BattleDefenseEntry]) -> void:
	for index: int in range(entries.size() - 1, -1, -1):
		if entries[index] == null or not entries[index].is_active():
			entries.remove_at(index)

## 递减一组按回合持续的来源条目。
func _decrement_rounds(entries: Array[BattleDefenseEntry]) -> void:
	for entry: BattleDefenseEntry in entries:
		if entry.remaining_rounds > 0:
			entry.remaining_rounds -= 1

## 清理一个阵营的所有防御来源队列。
func _cleanup_all_defense_entries(side: String) -> void:
	for kind: String in [
		BattleDefenseEntry.KIND_SHIELD,
		BattleDefenseEntry.KIND_REFLECT,
		BattleDefenseEntry.KIND_GUARD,
		BattleDefenseEntry.KIND_RESOLUTION,
		BattleDefenseEntry.KIND_PENETRATION,
	]:
		_cleanup_entries(_get_defense_entries_reference(side, kind))

## 清空双方全部防御来源队列。
func _clear_defense_entries() -> void:
	_player_shield_entries.clear()
	_enemy_shield_entries.clear()
	_player_reflect_entries.clear()
	_enemy_reflect_entries.clear()
	_player_guard_entries.clear()
	_enemy_guard_entries.clear()
	_player_resolution_entries.clear()
	_enemy_resolution_entries.clear()
	_player_penetration_entries.clear()
	_enemy_penetration_entries.clear()

## 向界面和外部行为发布防御来源变化。
func _emit_defense_changed(side: String, kind: String) -> void:
	Signals.battle_defense_changed.emit(side, kind)

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
