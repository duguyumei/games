class_name EffectPipeline
extends RefCounted

# 动作管线地基（纯逻辑，与具体游戏规则解耦）：
# - 动作是对象（GameAction），管线只听动作；谁挂钩子它不管——
#   状态、内功、装备、功法、场地……都是平等的数据载体。
# - 三段：PRE 拦截（可改可挡）→ RESOLVE 默认结算（按动作类型注册）→ POST 触发（可塞新动作入队）。
# - 队列化 + 链长上限：触发的新动作入队而非递归，超过上限截断防死循环。
#
# 钩子是一条数据：{ carrier, on, phase, priority, is_alive?, handler }。
# on 为动作类型或 "*"；phase 为 "pre"/"post"；同优先级按注册先后。

const MAX_CHAIN := 64

var events: Array[String] = []
# 当前行动权持有方（§11.5：同一点位双方钩子，持有方先结算）。由行动权动作的
# 结算器与 TurnManager 维护；钩子可带 "side" 字段参与此排序，无 side 者排持有方之后。
var acting_side: String = ""

var _resolvers: Dictionary = {}        # type -> Callable(GameAction)
var _points: Dictionary = {}           # 抽象点位（无默认结算，属正常）
var _hooks: Array = []
var _hook_seq := 0
var _queue: Array = []
var _processing := false

# 注册某类动作的默认结算方式（RESOLVE 层，由宿主提供）。
func register_resolver(action_type: String, resolver: Callable) -> void:
	_resolvers[action_type] = resolver

# 声明一个抽象点位：无默认结算（战斗开始、回合开始等纯时点），不告警。
func register_point(action_type: String) -> void:
	_points[action_type] = true

# 注册一个钩子载体。handler 签名：func(action: GameAction) -> void；
# PRE 里可改 action.amount / tags / cancelled，POST 里可 submit 新动作。
func register_hook(hook: Dictionary) -> void:
	_hook_seq += 1
	hook["_seq"] = _hook_seq
	_hooks.append(hook)
	_hooks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.get("priority", 0))
		var pb := int(b.get("priority", 0))
		if pa != pb:
			return pa < pb
		return int(a.get("_seq", 0)) < int(b.get("_seq", 0))
	)

# 动作入队并排空队列；触发产生的新动作排队等待，链长超限即截断。
func submit(action: GameAction) -> void:
	_queue.append(action)
	if _processing:
		return
	_processing = true
	var chain := 0
	while not _queue.is_empty():
		chain += 1
		if chain > MAX_CHAIN:
			_queue.clear()
			events.append("效果链过长，已截断（防死循环）。")
			push_warning("EffectPipeline: 效果链超过上限，可能存在互触发循环")
			break
		var next: GameAction = _queue.pop_front()
		_process(next)
	_processing = false

func _process(action: GameAction) -> void:
	_run_hooks("pre", action)
	if not action.cancelled:
		var resolver: Callable = _resolvers.get(action.type, Callable())
		if resolver.is_valid():
			resolver.call(action)
		elif not _points.has(action.type):
			push_warning("EffectPipeline: 未注册的动作类型 " + action.type)
	_run_hooks("post", action)

func _run_hooks(phase: String, action: GameAction) -> void:
	for hook in _ordered_hooks():
		var on := str(hook.get("on", ""))
		if on != action.type and on != "*":
			continue
		if str(hook.get("phase", "post")) != phase:
			continue
		var alive_check: Callable = hook.get("is_alive", Callable())
		if alive_check.is_valid() and not alive_check.call():
			continue
		var handler: Callable = hook.get("handler", Callable())
		if handler.is_valid():
			handler.call(action)

# §11.5 排序：行动权持有方的钩子先（priority 升序、注册稳定序），其余按原序在后。
# 无 side 的钩子（状态、测试等）视作非持有方，排第二梯队。
func _ordered_hooks() -> Array:
	if acting_side.is_empty():
		return _hooks
	var holders: Array = []
	var others: Array = []
	for hook in _hooks:
		if str(hook.get("side", "")) == acting_side:
			holders.append(hook)
		else:
			others.append(hook)
	return holders + others

func drain_events() -> Array[String]:
	var out: Array[String] = events
	events = []
	return out
