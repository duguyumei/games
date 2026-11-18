## 状态基类（2026-11-18 GoF 类制改造·用户令「和原版一样」）。
## 对位原版 Nosebleed.StateMachine.State<T>（csall State.cs:10-417）＋
## IState<T> 契约（IState.cs:5-33：StateName/IsEnabled/IsActiveState/TimeSinceEntered/
## HasExecuted/StateExecuted/StateEntered/StateExited/TickState/EnterState/ExitState/OnDestroy）。
## 〔差异登记 #35〕C# interface＋abstract class 两层 → GDScript 单基类
## （GDScript 无接口；duck-typed context 泛参 T 落为无类型）。
extends RefCounted

signal state_executed                                    # State.cs:87 StateExecuted
signal state_entered(from_state, to_state, context)      # State.cs:137 StateEntered
signal state_exited(from_state, to_state, context)       # State.cs:247 StateExited

var _state_entered_time := 0.0        # State.cs:10 _stateEnteredTime（TimeSinceEntered 基准）
var _execute_count := 0               # State.cs:12 _executeCount（HasExecuted 基准）
var _exit_state_token_source := false # State.cs:14 _exitStateTokenSource（CancellationTokenSource
                                      #  → bool 取消位；退出状态置 true，长任务 await 后自查）
var _is_active_state := false         # State.cs:16 IsActiveState__BackingField

## State.cs:24 virtual StateName —— 子类覆写返回原版类名（证据锚点）。
func state_name() -> String:
	return "State"

## State.cs:49 IsEnabled => true（本机无禁用态）。
func is_enabled() -> bool:
	return true

## State.cs:51 IsActiveState。
func is_active_state() -> bool:
	return _is_active_state

## State.cs:63 TimeSinceEntered（本轮停留秒数——机器 tick 维护时钟）。
func time_since_entered() -> float:
	return _state_entered_time

## State.cs:72 HasExecuted。
func has_executed() -> bool:
	return _execute_count > 0

## State.cs:380 EnterState —— 模板方法：置激活＋发 StateEntered＋调 OnEnterState 钩子。
func enter_state(from_state, context) -> void:
	_is_active_state = true
	_state_entered_time = 0.0
	_exit_state_token_source = false
	state_entered.emit(from_state, self, context)
	on_enter_state(from_state, self, context)

## State.cs:393 ExitState —— 模板方法：清激活＋发 StateExited＋调 OnExitState 钩子。
func exit_state(to_state, context) -> void:
	_is_active_state = false
	_exit_state_token_source = true   # 取消位置位：退出后仍在跑的 await 自查让路
	state_exited.emit(self, to_state, context)
	on_exit_state(self, to_state, context)

## State.cs:405 virtual TickState —— 机器每帧调（我方战斗环零谓词转移，tick 仅走时钟）。
func tick_state(context, dt: float) -> void:
	_state_entered_time += dt

## State.cs:409 protected virtual OnEnterState —— 子类覆写（各状态入口逻辑住这里）。
func on_enter_state(_from_state, _to_state, _context) -> void:
	pass

## State.cs:413 protected virtual OnExitState —— 子类覆写。
func on_exit_state(_from_state, _to_state, _context) -> void:
	pass

## State.cs:369 OnDestroy。
func on_destroy() -> void:
	pass

## State.cs:369 前 OnExecuteState（protected，_executeCount++＋StateExecuted 发射）。
func _on_execute_state() -> void:
	_execute_count += 1
	state_executed.emit()
