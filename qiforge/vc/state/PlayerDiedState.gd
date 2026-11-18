## 玩家败北态（2026-11-18 GoF 类制改造）。
## 对位原版 Nosebleed.Pancake.GameLogic.GameStates.PlayerDiedState
## （csall :299 OnEnterState / :305 ShowGameOver(GameModel)——两法本体，体均 nuked）。
## 〔差异登记 #37〕我方败北表现＝ended("lose") 信号驱动屏内既有处理（2026-11-01 既有链），
## ShowGameOver 体不复刻——状态层薄占位 1:1。
extends "res://qiforge/vc/state/GameState.gd"

func state_name() -> String:
	return "PlayerDiedState"

## :299 OnEnterState —— 起 ShowGameOver。
func on_enter_state(_from_state, _to_state, context) -> void:
	show_game_over(context)

## :305 ShowGameOver(context) —— 原体 nuked；我方败北 UI 由 battle.ended 信号在
## check_end 数据判定时已发（时点不变），本体空。
func show_game_over(_context) -> void:
	pass
