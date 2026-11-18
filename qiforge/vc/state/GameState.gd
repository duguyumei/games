## 游戏状态基类（2026-11-18 GoF 类制改造）。
## 对位原版 Nosebleed.Pancake.GameLogic.GameStates.GameState（csall GameState.cs:7-9：
## `public abstract class GameState : State<GameModel>`——原类仅此声明＋protected 构造，
## 无任何自有成员）。GameModel 上下文 → 我方 QiVcBattle（〔差异登记 #35〕上下文映射）。
extends "res://qiforge/vc/state/State.gd"

var _machine = null   # 宿主机器引用（〔差异登记 #36〕原版状态＝MonoBehaviour 场景装配、
                      # 经单例/上下文寻机推态；我方＝构造注入）

## 构造注入机器（原版 Awake 场景装配的引擎映射，#36）。
func _init(machine) -> void:
	_machine = machine
