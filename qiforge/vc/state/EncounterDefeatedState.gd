## 终局胜利态（2026-11-18 GoF 类制改造）。
## 对位原版 Nosebleed.Pancake.GameLogic.GameStates.EncounterDefeatedState
## （csall :544 OnEnterState / :583 ExecuteTask(GameModel, CancellationToken)——两法本体）。
## ExecuteTask 编排（ISIL d__280 全序已读＋2026-11-15 底层对齐）：
##   首拍即 await player.OnEncounterDefeated()（弃手/清已打出/洗回立即启动，不等攻击视图）
##   → OnEncounterDefeated d__280：DiscardHand → DiscardComboPile → anyDiscarded? Delay(1000ms)
##     → TryAddDiscardPileToDeck（无条件）→ 末段 WaitWhile 等视图清空后才转场。
## 〔差异登记 #37〕推态时点＝我方死亡拍（击拍收尸后 _check_finale——既有验证链口径，
## 胜利空窗案挂起中）；末段视图清空等待＝我方屏侧 _try_finish_win（等珠/等弹窗）承担。
extends "res://qiforge/vc/state/GameState.gd"

func state_name() -> String:
	return "EncounterDefeatedState"

## :544 OnEnterState —— 起 ExecuteTask（fire-and-forget 协程，原版形制）。
func on_enter_state(_from_state, _to_state, context) -> void:
	execute_task(context)

## :583 ExecuteTask(gameModel, ct) —— await OnEncounterDefeated（battle 侧 1:1 编排体）
## → 完成通知屏（finale_cleanup_done＝我方 _finale_cleanup_done 旗对位信号）。
## 〔差异登记 #37〕不做退出取消：多波次换波（场上清空但候补未尽→敌方回合续走推下一波）
## 会退出本态再入——结算链必达＝旧行为对位（旧屏协程无中断路径）；原版 ct＝转场打断，不复刻。
func execute_task(context) -> void:
	await context.on_encounter_defeated()
	context.finale_cleanup_done.emit()
