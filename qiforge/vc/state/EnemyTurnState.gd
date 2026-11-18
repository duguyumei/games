## 敌方回合态（2026-11-18 GoF 类制改造）。
## 对位原版 Nosebleed.Pancake.GameLogic.GameStates.EnemyTurnState
## （csall :1195 OnEnterState / :1280 ExecuteStateTask(GameModel) /
## :1307 WaitForTurnEnd() / :1340 OnExitState——四法本体）。
## OnEnterState 存活段（csall :1195-1280 实读）：AsyncUniTaskVoidMethodBuilder.Start(
## ref <ExecuteStateTask>d__1)＋Forget——**入态即起 fire-and-forget 协程**。
## WaitForTurnEnd＝WaitWhile(IsProcessing ‖ IsAnyViewUpdating)——2026-11-13 补全实证
## （原版 EnemyTurnState 收口双条件；灼烧焚卡/经验珠等演出不被下回合插队）。
extends "res://qiforge/vc/state/GameState.gd"

func state_name() -> String:
	return "EnemyTurnState"

## :1195 OnEnterState —— 入态即起 ExecuteStateTask（fire-and-forget，原版 Forget 同构）。
func on_enter_state(_from_state, _to_state, context) -> void:
	execute_state_task(context)

## :1280 ExecuteStateTask(context) —— 敌方回合体（我方已验证链，PerformIntents 逐敌三明治）：
## 落账兜底→逐敌构建（无屏直执行／有屏 Wait(0.12) 呼吸位＋EnemyActCommand 入队）→
## 灼烧逐敌→WaitForTurnEnd 排空（无屏零在飞＝同栈即过）→回合收口。
func execute_state_task(context) -> void:
	context._enemy_round_body()
	await wait_for_turn_end(context)
	context._enemy_round_end_body()

## :1307 WaitForTurnEnd —— WaitWhile(IsProcessing ‖ IsAnyViewUpdating)：
## 命令队列排空＋全局动画在飞计数清零（双条件，2026-11-13 原版补全）。
func wait_for_turn_end(context) -> void:
	while context.cmds.IsProcessing() \
			or (context.is_any_view_updating.is_valid() and context.is_any_view_updating.call()):
		await (Engine.get_main_loop() as SceneTree).process_frame

## :1340 OnExitState —— 体 nuked；我方无退出钩子需求（空实现）。
func on_exit_state(_from_state, _to_state, _context) -> void:
	pass
