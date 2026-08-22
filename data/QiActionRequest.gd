## 一次已经确认的敌我真气行动；只冻结待结算区顺序，不负责牌型或功法计算。
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

## 初始化冻结请求；传入数组始终复制，调用方不能继续污染请求内容。
func initialize(
		_action_token: String,
		_enemy_instance_id: String,
		_player_qi_instance_uids: Array[String],
		_enemy_qi_instance_uids: Array[String]) -> void:
	action_token = _action_token
	enemy_instance_id = _enemy_instance_id
	player_qi_instance_uids = _player_qi_instance_uids.duplicate()
	enemy_qi_instance_uids = _enemy_qi_instance_uids.duplicate()

## 返回请求是否包含可结算的玩家真气以及合法令牌。
func is_valid_request() -> bool:
	return action_token != "" \
		and not player_qi_instance_uids.is_empty() \
		and player_qi_instance_uids.size() <= BattleQiState.PENDING_LIMIT \
		and enemy_qi_instance_uids.size() <= BattleQiState.PENDING_LIMIT
