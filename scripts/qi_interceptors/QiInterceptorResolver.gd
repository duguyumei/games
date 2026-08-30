## 真气拦截链的查找与执行。
##
## 对应旧体系的 ActionInterceptorProcessor，但查找方式不同：
## 旧的查「发起者」和「承受者」两个位置的名单，靠 modifies_parent 匹配方向；
## 这里按动作路径一次查表，靠比较 owner 与动作发起者判断阵营。
##
## 结果是敌我拦截器进同一个待排序列表，优先级跨阵营有效 —— 例如敌方「运转无效」
## 优先级 1000、我方「运转时气力 +2」优先级 100 时，前者先执行并拒绝动作，加气力不发生。
## 旧体系把敌我拆成两条链时做不到这一点。
##
## 前后两个时机各跑一条独立的链，各自排序，由 phase 决定收集哪一批（见 _collect）。
##
## 改后的参数存在本对象的 _shadowed_values 上，不写回动作。动作执行时通过
## get_shadowed_value() 读取，因此拦截器的修改对动作透明。
extends RefCounted
class_name QiInterceptorResolver

## 本次拦截对应的动作。
var parent_action: BaseAction = null

## 本次拦截处于哪个阶段；决定收集哪一批拦截器。
var phase: int = QiInterceptorData.PHASES.BEFORE

## 被拦截器修改过的动作参数；未修改的键回落到动作自身的取值链。
var _shadowed_values: Dictionary = {}

## 当前正在执行的拦截器的来源上下文；拦截器只能通过 getter 读取副本。
var _current_source_context: Dictionary[String, Variant] = {}

## 当前是否运行在无副作用预览模式。
var _is_preview_mode: bool = false


func _init(
		_parent_action: BaseAction,
		_phase: int = QiInterceptorData.PHASES.BEFORE) -> void:
	parent_action = _parent_action
	phase = _phase


## 跑完整条拦截链。返回 false 表示动作被拒绝，调用方不应执行动作。
func run(preview_mode: bool = false) -> bool:
	if parent_action == null:
		return true

	var entries: Array[Dictionary] = _collect()
	if preview_mode:
		# 复用旧体系的预览深度计数：预览期间 ActionHandler.add_actions() 会丢弃入队请求。
		ActionHandler.begin_action_interceptor_preview()
	_is_preview_mode = preview_mode

	var accepted: bool = true
	for entry: Dictionary in entries:
		var interceptor_data: QiInterceptorData = entry["data"]
		var registration: QiInterceptorRegistration = entry["registration"]

		var interceptor_asset: Variant = load(interceptor_data.qi_interceptor_script_path)
		if interceptor_asset == null:
			continue
		var interceptor: BaseQiInterceptor = interceptor_asset.new()

		# 拦截器不能存状态，来源信息通过这里传递。
		_current_source_context = registration.get_source_context()
		var result: int = interceptor.process_qi_interception(self, preview_mode)
		if result == BaseQiInterceptor.ACCEPTANCES.STOPPED:
			break
		if result == BaseQiInterceptor.ACCEPTANCES.REJECTED:
			# AFTER 阶段动作已经执行完，拒绝无意义，按中断链处理而不改变结果。
			if phase == QiInterceptorData.PHASES.AFTER:
				break
			accepted = false
			break

	_current_source_context.clear()
	_is_preview_mode = false
	if preview_mode:
		ActionHandler.end_action_interceptor_preview()
	return accepted


## 收集本次要执行的拦截器，已按优先级排好序。
##
## 一次查表拿到该动作上的全部注册，再用两个条件过滤：
## 阶段必须与本次拦截一致；watches_opponent 为真的只在对方发起时生效，为假的只在自己发起时生效。
func _collect() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []

	# 动作可以用这个开关完全跳过拦截，用于必须原样执行的内部动作。
	# 这里读的是动作自身的值：_collect() 在链开始前调用，此时还没有拦截器写过 shadow。
	if parent_action.get_action_value("ignore_all_interceptors", false):
		return entries

	var ignored_interceptor_ids: Array[String] = []
	ignored_interceptor_ids.assign(
		parent_action.get_action_value("ignored_interceptor_ids", []))

	var action_path: String = parent_action.get_script().resource_path
	# 发起者已被释放时无法做阵营判定，整条链跳过。
	if not is_instance_valid(parent_action.parent_combatant):
		return entries
	var actor: BaseCombatant = parent_action.parent_combatant

	for registration: QiInterceptorRegistration in \
			ActionHandler.qi_interceptors.get_registrations(action_path):
		var interceptor_data: QiInterceptorData = \
			Global.get_qi_interceptor_data(registration.interceptor_id)
		if interceptor_data == null:
			continue
		if ignored_interceptor_ids.has(registration.interceptor_id):
			continue
		# 归属者已随战斗销毁时跳过；悬空归属无法参与阵营判定。
		if not is_instance_valid(registration.owner):
			continue
		# 阶段不符的跳过；前后两批各自成链。
		if interceptor_data.qi_interceptor_phase != phase:
			continue

		# 阵营判定就是这一个比较：归属者是发起者本人即「自己发起」。
		var is_self: bool = (registration.owner == actor)
		if interceptor_data.qi_interceptor_watches_opponent and is_self:
			continue  # 关心对方发起，但这次是自己发起
		if not interceptor_data.qi_interceptor_watches_opponent and not is_self:
			continue  # 关心自己发起，但这次是对方发起

		entries.append({"data": interceptor_data, "registration": registration})

	entries.sort_custom(_sort_entries)
	return entries


## 优先级降序；同优先级按来源顺序，再按稳定注册序号。
func _sort_entries(entry_1: Dictionary, entry_2: Dictionary) -> bool:
	var data_1: QiInterceptorData = entry_1["data"]
	var data_2: QiInterceptorData = entry_2["data"]
	if data_1.qi_interceptor_priority != data_2.qi_interceptor_priority:
		return data_1.qi_interceptor_priority > data_2.qi_interceptor_priority
	var registration_1: QiInterceptorRegistration = entry_1["registration"]
	var registration_2: QiInterceptorRegistration = entry_2["registration"]
	if registration_1.source_order != registration_2.source_order:
		return registration_1.source_order < registration_2.source_order
	return registration_1.registration_order < registration_2.registration_order


## 读取动作参数；已被拦截器修改过的返回修改值，否则回落到动作自身的取值链。
## 动作执行时应当用这个方法读参数，而不是直接 get_action_value()，否则拿不到修改。
func get_shadowed_value(key: String, default_value: Variant) -> Variant:
	var key_name: String = _resolve_key_name(key)
	if _shadowed_values.has(key_name):
		return _shadowed_values[key_name]
	return parent_action.get_action_value(key, default_value)


## 修改动作参数。只写本对象，动作自身的 values 不变。
func set_shadowed_value(key: String, value: Variant) -> void:
	_shadowed_values[_resolve_key_name(key)] = value


## 应用动作声明的参数键别名。
##
## 与旧体系保持一致：一张卡上有两个同类动作但参数不同时，靠 custom_key_names
## 把通用键名映射到各自专属的键名，避免两个动作抢同一个参数。
func _resolve_key_name(key: String) -> String:
	var custom_action_value_keys: Dictionary = parent_action.values.get("custom_key_names", {})
	return custom_action_value_keys.get(key, key)


## 返回当前拦截器的只读来源上下文副本。
func get_source_context() -> Dictionary[String, Variant]:
	return _current_source_context.duplicate(true)


## 返回当前是否处于禁止副作用的预览查询。
func is_preview_mode() -> bool:
	return _is_preview_mode


## 解析当前来源对应的本局实例；拦截器靠它读取自己的配置数值。
## 例如「运转时气力 +N」的 N 存在内功数据里，而非拦截器脚本里。
func get_source_instance() -> Variant:
	var source_kind: String = _current_source_context.get("source_kind", "")
	var source_instance_id: String = _current_source_context.get("source_instance_id", "")
	match source_kind:
		"artifact":
			return _protect_preview_source(Global.player_data \
				.player_artifact_uid_to_artifact_data.get(source_instance_id, null))
		"neigong":
			return _protect_preview_source(
				Global.player_data.get_owned_neigong(source_instance_id))
		"gongfa":
			return _protect_preview_source(
				Global.player_data.get_owned_gongfa(source_instance_id))
	return null


## 预览模式返回深副本，避免拦截器误改本局数据；正式模式返回真实实例。
func _protect_preview_source(source_instance: Variant) -> Variant:
	if _is_preview_mode and source_instance is Resource:
		return source_instance.duplicate(true)
	return source_instance
