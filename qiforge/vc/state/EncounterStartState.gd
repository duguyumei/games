## 进遭遇态（2026-11-18 GoF 类制改造）。
## 对位原版 Nosebleed.Pancake.GameLogic.GameStates.EncounterStartState
## （csall :932 OnEnterState / :941 DelayExecute(CancellationToken, GameModel)——两法本体）。
## 方法体 csall nuked；行为＝我方已验证开局链（开局首帧案 #31：原版开局＝瞬落直通）。
extends "res://qiforge/vc/state/GameState.gd"

func state_name() -> String:
	return "EncounterStartState"

## :932 OnEnterState —— 起 DelayExecute 协程（原版 UniTask 形制）。
func on_enter_state(_from_state, _to_state, context) -> void:
	delay_execute(context)

## :941 DelayExecute —— 回合计零＋直通 PrePlayerTurn→PlayerTurn（→OnStartTurn 首抽
## isInitialCardDraw——lldb 栈实证 #31）。原版 Delay 体 nuked；
## 〔差异登记 #37〕我方零延迟同步直通（开局瞬落已验证链，不加垫拍）。
func delay_execute(context) -> void:
	context.round_no = 0
	if _exit_state_token_source:
		return
	_machine.set_state(_machine._pre_player_turn_state, context)
