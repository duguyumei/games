## 一个已经调度好的功法原子组；同级双方在组开始时冻结执行资格，组结束后统一处理死亡。
extends BaseAction
class_name ActionQiAtomicGroup

## 玩家队首原子生成的行为。
var player_actions: Array[BaseAction] = []

## 敌方队首原子生成的行为。
var enemy_actions: Array[BaseAction] = []

## 当前原子所属的冻结行动请求。
var qi_action_request: QiActionRequest = null

## 当前原子是否为对应阵营队首功法的最后一个原子。
var player_is_last_atom: bool = false
var enemy_is_last_atom: bool = false

## 当前原子成功执行后请求的临时自我复制数量。
var player_copy_self_count: int = 0
var enemy_copy_self_count: int = 0

## 初始化一个单方或双方同时原子组。
func init_atomic_group(
		_player_actions: Array[BaseAction],
		_enemy_actions: Array[BaseAction],
		_qi_action_request: QiActionRequest,
		_player_is_last_atom: bool,
		_enemy_is_last_atom: bool,
		_player_copy_self_count: int,
		_enemy_copy_self_count: int) -> void:
	player_actions.assign(_player_actions)
	enemy_actions.assign(_enemy_actions)
	qi_action_request = _qi_action_request
	player_is_last_atom = _player_is_last_atom
	enemy_is_last_atom = _enemy_is_last_atom
	player_copy_self_count = max(_player_copy_self_count, 0)
	enemy_copy_self_count = max(_enemy_copy_self_count, 0)

## 严格按各原子内部配置顺序执行，并在整组结束后统一显示死亡。
func perform_action() -> void:
	if Global.battle_qi_state == null:
		return
	var player: Player = Global.get_player()
	var enemies: Array[Enemy] = Global.get_alive_enemies()
	var enemy: Enemy = enemies[0] if not enemies.is_empty() else null
	var player_eligible: bool = not player_actions.is_empty() \
		and player != null and player.is_alive()
	var enemy_eligible: bool = not enemy_actions.is_empty() \
		and enemy != null and enemy.is_alive()
	Global.battle_qi_state.begin_deferred_death_resolution()
	ActionHandler.begin_inline_action_capture()
	var player_executed: bool = false
	var enemy_executed: bool = false
	if player_eligible:
		_perform_atom_actions(player_actions)
		player_executed = true
	if enemy_eligible:
		_perform_atom_actions(enemy_actions)
		enemy_executed = true
	ActionHandler.end_inline_action_capture()
	if qi_action_request != null and player_executed:
		qi_action_request.record_gongfa_atom_execution(
			BattleQiState.SIDE_PLAYER, player_copy_self_count, player_is_last_atom)
	if qi_action_request != null and enemy_executed:
		qi_action_request.record_gongfa_atom_execution(
			BattleQiState.SIDE_ENEMY, enemy_copy_self_count, enemy_is_last_atom)
	Global.battle_qi_state.end_deferred_death_resolution()
	Global.finalize_qi_atomic_group_deaths()

## 执行一个原子内部的全部同步 Action。
func _perform_atom_actions(actions: Array[BaseAction]) -> void:
	var pending_actions: Array[BaseAction] = []
	pending_actions.assign(actions)
	while not pending_actions.is_empty():
		var action: BaseAction = pending_actions.pop_front()
		if action == null:
			continue
		if action.is_async_action():
			DebugLogger.log_error("Async actions cannot execute inside a gongfa atom")
			continue
		action.perform_action()
		var generated_actions: Array[BaseAction] = \
			ActionHandler.take_inline_captured_actions()
		if not generated_actions.is_empty():
			pending_actions = generated_actions + pending_actions

## 原子组本身由内部 Action 决定表现，不额外等待。
func is_instant_action() -> bool:
	return true
