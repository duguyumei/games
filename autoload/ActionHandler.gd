## Singleton maintaining actions taken and registered interceptors for each combatant.
## See: BaseAction, BaseActionInterceptor, ActionInterceptorProcessor, and ActionGenerator
extends Node

@onready var action_timer: Timer = Timer.new()

# actions
var action_stack: Array[Array] = []	# stack of queues of BaseActions
var current_action_queue: Array[BaseAction] = []
var current_action: BaseAction = null # the current action being invoked
var actions_being_performed: bool = false	# flag to prevent multiple actions being performed simultaneously and check for blocking

## 功法原子内部同步执行时临时接管新生成的行为，避免它们越过当前原子组延后执行。
var _inline_action_capture_depth: int = 0

## 当前原子子行为生成的同步后续行为。
var _inline_captured_actions: Array[BaseAction] = []

# action interceptors
## 将战斗对象映射到其拦截器来源注册记录。
var _registered_action_interceptors: Dictionary = {}

## 下一个稳定注册序号。
var _next_action_interceptor_registration_order: int = 0

## 当前是否正在执行无副作用预览拦截器。
var _action_interceptor_preview_depth: int = 0

## 真气拦截器注册表；按动作类型索引，敌我记录混排后按优先级统一排序。
## 与上面的旧体系并存：旧的服务框架原有动作，这套服务真气、内功、功法。
var qi_interceptors: QiInterceptorRegistry = QiInterceptorRegistry.new()

# signals
signal actions_ended	# all actions completed, typically signalling the end of an enemy attack or card play

func _ready():
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.player_killed.connect(_on_player_killed)
	Signals.run_ended.connect(_on_run_ended)
	
	# create and configure a pausable timer
	add_child(action_timer)
	action_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	action_timer.one_shot = true
	action_timer.name = "ActionTimer"

### Actions

func add_action(action: BaseAction, enqueue: bool = false, front_of_queue: bool = false):
	add_actions([action], enqueue, front_of_queue)

## Adds actions to either the top of the stack, or the end of the current queue if enque = true.
## if front_of_queue = true it will place the actions in front of the current queue, effectively always making them
## the next action to take place.
func add_actions(actions: Array[BaseAction], enqueue: bool = false, front_of_queue: bool = false):
	# 预览查询期间禁止拦截器向正式行为队列写入新行为。
	if is_previewing_action_interceptors():
		return
	if _inline_action_capture_depth > 0:
		if front_of_queue:
			_inline_captured_actions = actions + _inline_captured_actions
		else:
			_inline_captured_actions += actions
		return
	if enqueue:
		# adding to queue
		if len(action_stack) == 0:
			if actions_being_performed:
				# actions already being performed
				# adds actions to the current queue
				if front_of_queue:
					current_action_queue = actions + current_action_queue
				else:
					current_action_queue += actions
			else:
				# actions not being performed
				# add the actions as a queue, the push onto stack so it can be popped off in _perform_actions()
				action_stack.append(actions)
		else:
			if front_of_queue:
				current_action_queue = actions + current_action_queue
			else:
				current_action_queue += actions
	else:
		# adding to stack
		# adds each action to top of stack as their own queue
		for action in actions:
			action_stack += [[action]]
	
	if len(actions) > 0:	# automatically perform the actions when they're added
		if not actions_being_performed:	# check to prevent multiple automatic calls of this method
			_perform_actions()

## 开始捕获原子内部同步行为生成的后续行为。
func begin_inline_action_capture() -> void:
	_inline_action_capture_depth += 1

## 取出当前已经捕获的行为，并保持它们的生成顺序。
func take_inline_captured_actions() -> Array[BaseAction]:
	var result: Array[BaseAction] = []
	result.assign(_inline_captured_actions)
	_inline_captured_actions.clear()
	return result

## 结束一层原子内部行为捕获。
func end_inline_action_capture() -> void:
	_inline_action_capture_depth = max(_inline_action_capture_depth - 1, 0)
	if _inline_action_capture_depth == 0:
		_inline_captured_actions.clear()

func _perform_actions() -> void:	
	# performs all actions on the action stack
	actions_being_performed = true
	while len(action_stack) > 0:
		# pop the next queue from the stack
		var action_queue = action_stack.pop_back()
		
		# assign popped queue as current queue
		current_action_queue = []
		current_action_queue.assign(action_queue) # godot typed array shennanigans; re-adding elements to typed array to preserve type integrity
		
		# perform all actions in the queue until empty
		while len(current_action_queue) > 0:
			current_action = current_action_queue.pop_front()
			# skip short circuited actions
			if current_action.is_action_short_circuited():
				if not Global.are_remaining_enemies():
					continue
			# perform action
			current_action.perform_action()
			# wait for async actions to finish
			if current_action.is_async_action():
				await current_action.action_async_finished
			# wait for action delay if one exists
			if current_action.time_delay > 0.0 and !current_action.is_instant_action():
				action_timer.start(current_action.time_delay)
				await action_timer.timeout
				# await get_tree().create_timer(current_action.time_delay).timeout
			else:
				await get_tree().process_frame
			
			current_action = null
	
	actions_being_performed = false
	actions_ended.emit()

## Removes the current async action. Will only remove short circuited actions unless force_end = true.
func _clear_current_async_action(force_end: bool = false) -> void:
	if current_action != null:
		if current_action is BaseAsyncAction:
			if current_action.async_awaiting:
				if current_action.is_action_short_circuited() or force_end:
					current_action.force_action_end() # force the action to stop awaiting something
					current_action.action_async_finished.emit() # force the action to emit a finished signal just in case
					current_action = null

func clear_all_actions() -> void:
	_clear_current_async_action(true)
	
	action_stack.clear()
	current_action_queue.clear()
	_inline_captured_actions.clear()
	_inline_action_capture_depth = 0
	
	if actions_being_performed:
		actions_being_performed = false
		actions_ended.emit()

### Action Interception

func register_action_interceptor(
		base_combatant: BaseCombatant,
		action_interceptor_object_id: String,
		source_kind: String = "legacy",
		source_instance_id: String = "",
		source_order: int = 0) -> void:
	# 旧调用不传来源实例时继续按拦截器 ID 去重；实例来源按 ID 与来源 UID 组合去重。
	var registrations: Array[ActionInterceptorRegistration] = []
	registrations.assign(_registered_action_interceptors.get(base_combatant, []))
	for registration: ActionInterceptorRegistration in registrations:
		if registration.interceptor_id != action_interceptor_object_id:
			continue
		if source_instance_id == "" and registration.source_instance_id == "":
			return
		if source_instance_id != "" and registration.source_instance_id == source_instance_id:
			registration.source_kind = source_kind
			registration.source_order = source_order
			return
	_next_action_interceptor_registration_order += 1
	registrations.append(ActionInterceptorRegistration.new(
		action_interceptor_object_id,
		source_kind,
		source_instance_id,
		source_order,
		_next_action_interceptor_registration_order))
	_registered_action_interceptors[base_combatant] = registrations

## 注销旧式拦截器，或注销指定来源实例注册的拦截器。
func unregister_action_interceptor(
		base_combatant: BaseCombatant,
		action_interceptor_object_id: String,
		source_instance_id: String = "") -> void:
	var registrations: Array[ActionInterceptorRegistration] = []
	registrations.assign(_registered_action_interceptors.get(base_combatant, []))
	for registration_index: int in range(registrations.size() - 1, -1, -1):
		var registration: ActionInterceptorRegistration = registrations[registration_index]
		if registration.interceptor_id != action_interceptor_object_id:
			continue
		if source_instance_id == "" and registration.source_instance_id != "":
			continue
		if source_instance_id != "" and registration.source_instance_id != source_instance_id:
			continue
		registrations.remove_at(registration_index)
	_registered_action_interceptors[base_combatant] = registrations
	if registrations.is_empty():
		_registered_action_interceptors.erase(base_combatant)

## 注销一个来源实例注册的全部拦截器。
func unregister_action_interceptors_from_source(
		base_combatant: BaseCombatant,
		source_instance_id: String) -> void:
	var registrations: Array[ActionInterceptorRegistration] = []
	registrations.assign(_registered_action_interceptors.get(base_combatant, []))
	registrations = registrations.filter(func(registration: ActionInterceptorRegistration) -> bool:
		return registration.source_instance_id != source_instance_id)
	if registrations.is_empty():
		_registered_action_interceptors.erase(base_combatant)
	else:
		_registered_action_interceptors[base_combatant] = registrations

## 注销某一来源类别注册的全部拦截器。
func unregister_action_interceptors_by_source_kind(
		base_combatant: BaseCombatant,
		source_kind: String) -> void:
	var registrations: Array[ActionInterceptorRegistration] = []
	registrations.assign(_registered_action_interceptors.get(base_combatant, []))
	registrations = registrations.filter(func(registration: ActionInterceptorRegistration) -> bool:
		return registration.source_kind != source_kind)
	if registrations.is_empty():
		_registered_action_interceptors.erase(base_combatant)
	else:
		_registered_action_interceptors[base_combatant] = registrations

func clear_all_action_interceptors() -> void:
	_registered_action_interceptors.clear()
	_next_action_interceptor_registration_order = 0

## 返回当前是否处于拦截器预览查询中。
func is_previewing_action_interceptors() -> bool:
	return _action_interceptor_preview_depth > 0

## 标记开始一层无副作用预览查询。
func begin_action_interceptor_preview() -> void:
	_action_interceptor_preview_depth += 1

## 结束一层无副作用预览查询。
func end_action_interceptor_preview() -> void:
	_action_interceptor_preview_depth = max(_action_interceptor_preview_depth - 1, 0)


func _on_combat_ended():
	_clear_current_async_action()
	# 只清敌方留下的真气拦截器注册：敌方战斗者随战斗销毁，注册不清会一直留在表里。
	# 玩家的内功注册由一局开始时的 Player.reset_player() 建立，跨战斗持续有效，不能清。
	qi_interceptors.unregister_except_owner(Global.get_player())

func _on_player_killed(_player: Player):
	clear_all_actions()

func _on_run_ended():
	clear_all_action_interceptors()
	qi_interceptors.clear_all()
	clear_all_actions()
