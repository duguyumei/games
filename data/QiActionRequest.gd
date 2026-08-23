## 一次已经确认的敌我真气行动；同时冻结牌型、同气和功法值结算输入。
extends RefCounted
class_name QiActionRequest

## 本次行动的稳定令牌；完成接口据此拒绝旧请求和重复请求。
var action_token: String = ""

## 当前唯一敌人的实例标识。
var enemy_instance_id: String = ""

## 玩家待结算区的有序真气实例 UID 快照。
var player_qi_instance_uids: Array[String] = []

## 敌方待结算区的有序真气实例 UID 快照。
var enemy_qi_instance_uids: Array[String] = []

## 确认时玩家当前牌型队列第一项的战斗实例 ID。
var player_gongfa_slot_instance_id: String = ""

## 确认时敌方当前牌型队列第一项的战斗实例 ID。
var enemy_gongfa_slot_instance_id: String = ""

## 本次行动允许出牌的阵营；连击时可以只有一方行动。
var eligible_sides: Array[String] = []

## 玩家方的牌型和数值结果快照。
var player_result: QiActionSideResult = null

## 敌方的牌型和数值结果快照。
var enemy_result: QiActionSideResult = null

## 玩家连击槽结算前的数值。
var player_combo_before: int = 0

## 敌方连击槽结算前的数值。
var enemy_combo_before: int = 0

## 玩家连击槽结算后的数值。
var player_combo_after: int = 0

## 敌方连击槽结算后的数值。
var enemy_combo_after: int = 0

## 玩家本次队首功法的全部原子是否已经实际执行完毕。
var player_gongfa_completed: bool = false

## 敌方本次队首功法的全部原子是否已经实际执行完毕。
var enemy_gongfa_completed: bool = false

## 初始化冻结请求；传入数组始终复制，调用方不能继续污染请求内容。
func initialize(
		_action_token: String,
		_enemy_instance_id: String,
		_player_qi_instance_uids: Array[String],
		_enemy_qi_instance_uids: Array[String],
		_action_eligible_sides: Array[String] = [],
		_player_gongfa_slot_instance_id: String = "",
		_enemy_gongfa_slot_instance_id: String = "") -> void:
	action_token = _action_token
	enemy_instance_id = _enemy_instance_id
	player_qi_instance_uids = _player_qi_instance_uids.duplicate()
	enemy_qi_instance_uids = _enemy_qi_instance_uids.duplicate()
	eligible_sides = _action_eligible_sides.duplicate()
	player_gongfa_slot_instance_id = _player_gongfa_slot_instance_id
	enemy_gongfa_slot_instance_id = _enemy_gongfa_slot_instance_id
	if eligible_sides.is_empty():
		if not player_qi_instance_uids.is_empty():
			eligible_sides.append(BattleQiState.SIDE_PLAYER)
		if not enemy_qi_instance_uids.is_empty():
			eligible_sides.append(BattleQiState.SIDE_ENEMY)

## 返回请求是否包含至少一方可结算真气以及合法令牌。
func is_valid_request() -> bool:
	var allows_empty_enemy_action: bool = eligible_sides.has(BattleQiState.SIDE_ENEMY) \
		and not eligible_sides.has(BattleQiState.SIDE_PLAYER)
	return action_token != "" \
		and (not player_qi_instance_uids.is_empty() \
		or not enemy_qi_instance_uids.is_empty() \
		or allows_empty_enemy_action) \
		and player_qi_instance_uids.size() <= BattleQiState.PENDING_LIMIT \
		and enemy_qi_instance_uids.size() <= BattleQiState.PENDING_LIMIT

## 将识别和功法值结果写入冻结请求；调用方传入的结果会被深复制。
func set_resolution_results(
		_player_result: QiActionSideResult,
		_enemy_result: QiActionSideResult,
		_player_combo_before_value: int,
		_enemy_combo_before_value: int) -> void:
	player_result = _player_result.copy_result() if _player_result != null else null
	enemy_result = _enemy_result.copy_result() if _enemy_result != null else null
	player_combo_before = _player_combo_before_value
	enemy_combo_before = _enemy_combo_before_value

## 返回指定阵营的冻结结果；不存在时返回空值。
func get_side_result(side: String) -> QiActionSideResult:
	if side == BattleQiState.SIDE_PLAYER:
		return player_result
	if side == BattleQiState.SIDE_ENEMY:
		return enemy_result
	return null

## 记录一方实际完成的原子；复制数量只来自已经执行的原子。
func record_gongfa_atom_execution(
		side: String,
		copy_self_count: int,
		is_last_atom: bool) -> void:
	var side_result: QiActionSideResult = get_side_result(side)
	if side_result == null:
		return
	side_result.gongfa_copy_count += max(copy_self_count, 0)
	if side == BattleQiState.SIDE_PLAYER and is_last_atom:
		player_gongfa_completed = true
	elif side == BattleQiState.SIDE_ENEMY and is_last_atom:
		enemy_gongfa_completed = true

## 返回指定阵营的队首功法是否已经完整执行。
func is_gongfa_completed(side: String) -> bool:
	if side == BattleQiState.SIDE_PLAYER:
		return player_gongfa_completed
	if side == BattleQiState.SIDE_ENEMY:
		return enemy_gongfa_completed
	return false
