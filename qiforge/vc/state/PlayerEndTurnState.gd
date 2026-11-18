## 玩家结束回合态（2026-11-18 GoF 类制改造）。
## 对位原版 Nosebleed.Pancake.GameLogic.GameStates.PlayerEndTurnState
## （csall :606 OnEnterState / :615 DelayExecute(GameModel, CancellationToken)——两法本体，
## 体均 nuked）。语义＝结束回合按钮后的弃牌中转（我方旧 "discarding" 态对位）。
## 〔差异登记 #37〕弃牌等待：我方旧制＝真同步（屏弃牌动画播完回调 discard_anim_done 才推
## 敌方回合——2026-11-06 用户令）——引擎映射＝battle.discard_anim_done 门面直接推
## PostPlayerEndTurn（同栈零帧差）；本态轮询等待体保留 1:1 形制（自裁：门面已推则不重推）。
extends "res://qiforge/vc/state/GameState.gd"

func state_name() -> String:
	return "PlayerEndTurnState"

## :606 OnEnterState —— 复位弃牌完成旗＋起 DelayExecute。
func on_enter_state(_from_state, _to_state, context) -> void:
	context._discard_anim_done = false
	delay_execute(context)

## :615 DelayExecute(context, ct) —— 回合末模型结算（已打出区先扫→手牌后弃——
## 2026-11-13 原版录屏逐帧实证序）＋等弃牌动画播完→推 PostPlayerEndTurn。
func delay_execute(context) -> void:
	context._end_turn_body()
	while not context._discard_anim_done and not _exit_state_token_source:
		await (Engine.get_main_loop() as SceneTree).process_frame
	# 门面路径（屏回调直接推 Post）下本协程醒来时已非本态——不重推（幂等自裁）
	if _machine.current_state() == self and context._discard_anim_done:
		_machine.set_state(_machine._post_player_end_turn_state, context)
