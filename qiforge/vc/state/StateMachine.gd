## 通用状态机（2026-11-18 GoF 类制改造）。
## 对位原版 Nosebleed.StateMachine.StateMachine<T>（csall StateMachine.cs:106-1066）＋
## MonoStateMachine<T>（MonoStateMachine.cs:118-645；Unity MonoBehaviour Update 驱动壳
## →〔差异登记 #36〕我方由宿主同步驱动，战斗环零谓词转移、tick 无泵）。
## 〔差异登记 #35〕泛型 T → 无类型 context；Func<bool> → Callable。
extends RefCounted

signal state_changed(from_state, to_state)   # StateMachine.cs:120 StateChangedDelegate

## StateMachine.cs:11 StateTransition（谓词转移项：Condition/To/Transitioned）。
class StateTransition:
	var condition: Callable
	var to_state

	func _init(p_condition: Callable, p_to_state) -> void:
		condition = p_condition
		to_state = p_to_state

var _current_state = null                                  # :106 _currentState
var _transitions := {}                                     # :120 Dictionary<Type, List>
var _current_transitions: Array = []                       # :122 当前态转移表
var _any_transitions: Array = []                           # :124 Any 态转移表

## MonoStateMachine.cs:130 CurrentState。
func current_state():
	return _current_state

## StateMachine.cs:249 Tick —— 活动态走时钟＋评估谓词转移表（我方战斗环零装配＝惰性，
## 与原版 GameStateMachine 同：GameLogic 全树零 AddTransition 调用，grep 实证）。
func tick(context, dt: float) -> void:
	if _current_state != null:
		_current_state.tick_state(context, dt)
	for t in (_current_transitions as Array).duplicate():
		if t.condition.call():
			_do_transition(t, context)
			return
	for t in (_any_transitions as Array).duplicate():
		if t.condition.call():
			_do_transition(t, context)
			return

## StateMachine.cs:426 DoTransition。
func _do_transition(transition: StateTransition, context) -> void:
	set_state(transition.to_state, context)

## StateMachine.cs:434 SetState —— 幂等（同态直返）＋退出旧态＋进入新态。
func set_state(to_state, context) -> void:
	if to_state == null or to_state == _current_state:
		return
	var from := _current_state
	if from != null:
		from.exit_state(to_state, context)
	_current_state = to_state
	_current_transitions = _transitions.get(to_state, [])
	state_changed.emit(from, to_state)
	to_state.enter_state(from, context)

## StateMachine.cs:635 SetStateIf —— 仅当前态匹配 from 才转。
func set_state_if(from_state, to_state, context) -> void:
	if _current_state == from_state:
		set_state(to_state, context)

## StateMachine.cs:645 AddTransition —— 单源谓词转移装配（框架件 1:1 保留；
## 原版 GameStateMachine 未用——结构性存在，战斗环同不用）。
func add_transition(from_state, to_state, predicate: Callable) -> StateTransition:
	var t := StateTransition.new(predicate, to_state)
	if not _transitions.has(from_state):
		_transitions[from_state] = []
	(_transitions[from_state] as Array).push_back(t)
	return t

## StateMachine.cs:1044 AddAnyTransition —— 任意源谓词转移装配（同上保留）。
func add_any_transition(to_state, predicate: Callable) -> StateTransition:
	var t := StateTransition.new(predicate, to_state)
	_any_transitions.push_back(t)
	return t
