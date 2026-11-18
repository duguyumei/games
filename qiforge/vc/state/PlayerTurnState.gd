## 玩家回合态（2026-11-18 GoF 类制改造）。
## 对位原版 Nosebleed.Pancake.GameLogic.GameStates.PlayerTurnState
## （csall :38 OnEnterState / :136 OnExitState / :31 Awake＝MonoBehaviour 生命周期）。
## OnEnterState 存活段（csall :38-50 实读）：
##   `UniTask task = context._player.OnStartTurn(WasSaveDataLoaded__BackingField); Forget`
## ＋ lldb 运行时栈（差异登记 #31）：GameStateMachine 首轮 tick → PlayerTurnState.
## OnEnterState → OnStartTurn（UniTask 协程）→ DrawCards(isInitialCardDraw)。
extends "res://qiforge/vc/state/GameState.gd"

var _was_save_data_loaded := false   # WasSaveDataLoaded__BackingField（我方无战中存档路径，
                                     # 恒 false——〔差异登记 #37〕读档开局分支未复刻）

func state_name() -> String:
	return "PlayerTurnState"

## :31 Awake —— MonoBehaviour 场景装配钩子（〔#36〕引擎映射：构造注入，无需 Awake）。

## :38 OnEnterState —— 起 OnStartTurn（context.on_start_turn＝我方回合开始体：
## uses 清零/护甲刷新/气重置/抽牌/意图——行为沿我方已验证 _round_start 链）。
func on_enter_state(_from_state, _to_state, context) -> void:
	context.on_start_turn()

## :136 OnExitState —— 体 nuked；我方无回合退出钩子需求（空实现）。
func on_exit_state(_from_state, _to_state, _context) -> void:
	pass
