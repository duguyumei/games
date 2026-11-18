## 玩家结束回合后效果态（2026-11-18 GoF 类制改造）。
## 对位原版 Nosebleed.Pancake.GameLogic.GameStates.PostPlayerEndTurnState
## （csall :556 OnEnterState / :565 DelayExecute(GameModel, CancellationToken)——两法本体，
## 体均 nuked）。原版字段名实证：GameStateMachine.cs:695
## `private PostPlayerEndTurnState _playerEndTurnEffectsState;`——本态＝回合末**效果**层。
## 〔差异登记 #37〕我方现无回合末效果层（效果全在出牌/敌方回合内结算）——空态直通
## EnemyTurn（结构占位 1:1，行为差异已登记；将来加回合末效果落本态）。
extends "res://qiforge/vc/state/GameState.gd"

func state_name() -> String:
	return "PostPlayerEndTurnState"

## :556 OnEnterState —— 起 DelayExecute。
func on_enter_state(_from_state, _to_state, context) -> void:
	delay_execute(context)

## :565 DelayExecute(context, ct) —— 我方无回合末效果体：直通 EnemyTurn。
func delay_execute(context) -> void:
	if _exit_state_token_source:
		return
	_machine.set_state(_machine._enemy_turn_state, context)
