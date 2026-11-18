## 玩家回合前态（2026-11-18 GoF 类制改造）。
## 对位原版 Nosebleed.Pancake.GameLogic.GameStates.PrePlayerTurnState
## （csall :10 OnEnterState / :71 TickState override——两法本体，体均 nuked）。
## TickState override 说明原版本态 tick 驱动（等某前置）；〔差异登记 #37〕我方＝同步直通
## （EnemyTurn 收口→本态→PlayerTurn 全链一帧内同栈完成——我方已验证回合推进节奏，
## 不引入逐帧等待；tick_state 保留 1:1 声明为空直通）。
extends "res://qiforge/vc/state/GameState.gd"

func state_name() -> String:
	return "PrePlayerTurnState"

## :10 OnEnterState —— 直通 PlayerTurn。
func on_enter_state(_from_state, _to_state, context) -> void:
	if _exit_state_token_source:
		return
	_machine.set_state(_machine._player_turn_state, context)

## :71 TickState（override）—— 原体 nuked；我方空直通（进入即走，tick 永不落本态）。
func tick_state(_context, dt: float) -> void:
	super(_context, dt)
