## 真气拦截器注册表。
##
## 与旧体系最大的差别在于查找维度：旧的以战斗者为 key，查到之后还要用动作路径过滤；
## 这里直接以**动作名称**为 key，一条注册在它关心的每个动作名称下各存一份。
## 于是执行动作时一次查表就拿到全部候选，敌我双方的记录混在同一个数组里，
## 排序后优先级跨阵营有效 —— 这正是旧体系做不到的事。
##
## 归属信息存在记录的 owner 上，不靠 key 表达，因此清理需要遍历（见 unregister_by_owner）。
## 注册量不大（每个来源几条），遍历成本可忽略。
extends RefCounted
class_name QiInterceptorRegistry

## 动作名称 -> Array[QiInterceptorRegistration]。
var _by_action_name: Dictionary = {}

## 下一个稳定注册序号；保证排序条件完全相同时顺序仍然确定。
var _next_registration_order: int = 0

## 配置查询函数，签名为 func(interceptor_id: String) -> QiInterceptorData。
## 默认走 Global，测试时可替换为桩函数以脱离 autoload。
var _data_lookup: Callable = func(interceptor_id: String) -> QiInterceptorData:
	return Global.get_qi_interceptor_data(interceptor_id)


## 替换配置查询来源；仅供测试使用。
func set_data_lookup(data_lookup: Callable) -> void:
	_data_lookup = data_lookup


## 注册一个拦截器。
##
## 读配置里声明的动作名称白名单，在每个名称下各存一条记录。
## 同 (interceptor_id, owner, source_instance_id) 视为同一条，重复注册只更新不新增，
## 因此「先整体注销再重建」这种幂等写法是安全的。
func register(
		owner: Object,
		interceptor_id: String,
		source_kind: String = "",
		source_instance_id: String = "",
		source_order: int = 0) -> void:
	if owner == null or interceptor_id.is_empty():
		return
	var interceptor_data: QiInterceptorData = _data_lookup.call(interceptor_id)
	if interceptor_data == null:
		# 配置未登记；可能是旧体系的拦截器 ID，交由旧体系处理。
		return

	# 一次注册共用一个序号：同一拦截器在多个动作名称下的记录序号相同。
	# 这不影响排序稳定性，因为每次查找只针对一个动作名称，同一拦截器的多条记录
	# 不会出现在同一个候选列表里。
	_next_registration_order += 1
	for action_name: String in interceptor_data.qi_intercepted_action_names:
		if action_name.is_empty():
			continue
		var registrations: Array[QiInterceptorRegistration] = []
		registrations.assign(_by_action_name.get(action_name, []))

		# 去重：同来源实例的同一拦截器只更新顺序信息。
		# source_instance_id 为空时（无实例来源，如状态效果），同归属者的同一拦截器
		# 只能有一条 —— 与旧体系 ActionHandler.register_action_interceptor() 的行为一致。
		var is_duplicate: bool = false
		for registration: QiInterceptorRegistration in registrations:
			if registration.interceptor_id != interceptor_id \
					or registration.owner != owner \
					or registration.source_instance_id != source_instance_id:
				continue
			registration.source_kind = source_kind
			registration.source_order = source_order
			is_duplicate = true
			break
		if is_duplicate:
			continue

		registrations.append(QiInterceptorRegistration.new(
			interceptor_id,
			owner,
			source_kind,
			source_instance_id,
			source_order,
			_next_registration_order))
		_by_action_name[action_name] = registrations


## 返回某个动作名称下的全部注册记录副本。
func get_registrations(action_name: String) -> Array[QiInterceptorRegistration]:
	var registrations: Array[QiInterceptorRegistration] = []
	registrations.assign(_by_action_name.get(action_name, []))
	return registrations


## 注销指定来源实例注册的全部拦截器；卸下单件内功或单个状态失效时使用。
func unregister_by_source(owner: Object, source_instance_id: String) -> void:
	_remove_matching(func(registration: QiInterceptorRegistration) -> bool:
		return registration.owner == owner \
			and registration.source_instance_id == source_instance_id)


## 注销某一来源类别的全部拦截器；内功配装整体重建时先调用这个。
func unregister_by_source_kind(owner: Object, source_kind: String) -> void:
	_remove_matching(func(registration: QiInterceptorRegistration) -> bool:
		return registration.owner == owner and registration.source_kind == source_kind)


## 注销某个战斗者名下的全部拦截器；战斗结束或战斗者离场时使用。
func unregister_by_owner(owner: Object) -> void:
	_remove_matching(func(registration: QiInterceptorRegistration) -> bool:
		return registration.owner == owner)


## 注销除指定归属者之外的全部拦截器。
##
## 战斗结束时用它清掉敌方留下的注册：敌方战斗者随战斗销毁，其注册若不清会一直留在表里；
## 而玩家的内功注册由一局开始时的 reset_player() 建立、跨战斗持续有效，不能一起清掉。
## kept_owner 为 null 时不做任何事 —— 否则会把要保留的那一方也清掉。
func unregister_except_owner(kept_owner: Object) -> void:
	if kept_owner == null:
		return
	_remove_matching(func(registration: QiInterceptorRegistration) -> bool:
		return registration.owner != kept_owner)


## 清空整张表；一局结束时使用。
func clear_all() -> void:
	_by_action_name.clear()
	_next_registration_order = 0


## 移除所有满足条件的记录，并清掉空掉的动作名称键。
## 归属者已被释放的记录一并清除 —— 战斗者随战斗 queue_free 后，其注册不该继续留在表里。
func _remove_matching(should_remove: Callable) -> void:
	for action_name: String in _by_action_name.keys():
		var registrations: Array[QiInterceptorRegistration] = []
		registrations.assign(_by_action_name[action_name])
		registrations = registrations.filter(
			func(registration: QiInterceptorRegistration) -> bool:
				if not is_instance_valid(registration.owner):
					return false
				return not should_remove.call(registration))
		if registrations.is_empty():
			_by_action_name.erase(action_name)
		else:
			_by_action_name[action_name] = registrations
