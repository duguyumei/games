## 游戏状态机·战斗环（2026-11-18 GoF 类制改造）。
## 对位原版 Nosebleed.Pancake.GameLogic.GameStateMachine（csall GameStateMachine.cs:20
## `public class GameStateMachine : MonoStateMachine<GameModel>`）。
## 原机持 18 状态（:659-695 字段块）＝全游戏级（地牢移动/换层/事件/过场/开局全在内）；
## 〔差异登记 #37〕我方本批只落**战斗环 8 态**（EncounterStart→PrePlayerTurn→PlayerTurn
## →PlayerEndTurn→PostPlayerEndTurn→EnemyTurn，终局 EncounterDefeated/PlayerDied），
## 其余 10 态（RunStart/DungeonMovement/DungeonComplete/FloorTransition/Cutscene/
## PassiveEvent/EventEnd/EventLeft/GameOver/EncounterReset）由屏流转层承担或既有登记
## （#34 EncounterReset＝调试重置不复刻）。MonoBehaviour Update 驱动壳 →〔#36〕宿主同步驱动。
extends "res://qiforge/vc/state/StateMachine.gd"

const ENCOUNTER_START := preload("res://qiforge/vc/state/EncounterStartState.gd")
const PRE_PLAYER_TURN := preload("res://qiforge/vc/state/PrePlayerTurnState.gd")
const PLAYER_TURN := preload("res://qiforge/vc/state/PlayerTurnState.gd")
const PLAYER_END_TURN := preload("res://qiforge/vc/state/PlayerEndTurnState.gd")
const POST_PLAYER_END_TURN := preload("res://qiforge/vc/state/PostPlayerEndTurnState.gd")
const ENEMY_TURN := preload("res://qiforge/vc/state/EnemyTurnState.gd")
const ENCOUNTER_DEFEATED := preload("res://qiforge/vc/state/EncounterDefeatedState.gd")
const PLAYER_DIED := preload("res://qiforge/vc/state/PlayerDiedState.gd")

# GameStateMachine.cs:659-695 状态字段块（战斗环子集；snake_case 语言惯例转写）：
var _encounter_start_state = null          # :681 _encounterStartState
var _pre_player_turn_state = null          # :679 _prePlayerTurnState
var _player_turn_state = null              # :669 _playerTurnState
var _player_end_turn_state = null          # :693 _playerEndTurnState
var _post_player_end_turn_state = null     # :695 _playerEndTurnEffectsState
var _enemy_turn_state = null               # :675 _enemyTurnState
var _encounter_defeated_state = null       # :671 _encounterDefeatedState
var _player_died_state = null              # :691 _playerDiedState

## 构造全部战斗环状态实例（原版＝MonoBehaviour 场景装配 Awake；
## 〔#36〕引擎映射＝构造注入机器引用，状态间推态走机器）。
func _init() -> void:
	_encounter_start_state = ENCOUNTER_START.new(self)
	_pre_player_turn_state = PRE_PLAYER_TURN.new(self)
	_player_turn_state = PLAYER_TURN.new(self)
	_player_end_turn_state = PLAYER_END_TURN.new(self)
	_post_player_end_turn_state = POST_PLAYER_END_TURN.new(self)
	_enemy_turn_state = ENEMY_TURN.new(self)
	_encounter_defeated_state = ENCOUNTER_DEFEATED.new(self)
	_player_died_state = PLAYER_DIED.new(self)

## GameStateMachine.cs:876 SetStateEncounterStart —— 进遭遇（战斗开始入口；
## 方法体 csall "Method not found"，语义＝SetState(_encounterStartState, gameModel)）。
func set_state_encounter_start(context) -> void:
	set_state(_encounter_start_state, context)

## GameStateMachine.cs:882 SetStateEncounterDefeated —— 终局胜利推态
## （体同上 nuked；SetStateEventEnded :894 存活段实证此类助手＝守卫＋SetState 结构——
## 我方守卫＝已入 PlayerDied 则不覆盖〔差异登记 #37：守卫体 nuked，幂等防重入为我方语义〕）。
func set_state_encounter_defeated(context) -> void:
	if _current_state == _player_died_state:
		print("[胜利链] 机器.set_state_encounter_defeated：现态已是 PlayerDied，守卫拦下不推（异常路径）")   # 〔取证日志·胜利弹窗案〕
		return
	print("[胜利链] 机器.set_state_encounter_defeated：现态=%s → 推 EncounterDefeatedState" % ("?" if _current_state == null else _current_state.state_name()))   # 〔取证日志·胜利弹窗案〕
	set_state(_encounter_defeated_state, context)

## 败北推态（原版无独立助手——PlayerDied 推态走 GameModel 内部调用〔体 nuked〕；
## 我方由 battle.check_end 数据判定时同步推，登记于 #37）。
func set_state_player_died(context) -> void:
	if _current_state == _encounter_defeated_state:
		return
	set_state(_player_died_state, context)
