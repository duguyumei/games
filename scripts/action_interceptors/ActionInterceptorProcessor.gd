## Utility object for processing a chain of interceptors, see: BaseAction.intercept_action().
## Iterates over all interceptors of a given action-parent-target pairing, in order of interceptor priority
## defined by ActionInterceptorData.action_interceptor_priority.
## After the chain is finished, shadowed_action_values will be populated with modified values
## and the processor ultimately accepted/rejected.
## A rejected processsor will be discarded in the final returned result.
extends Node
class_name ActionInterceptorProcessor

var parent_action: BaseAction = null	# the action tied to this processor
var target: BaseCombatant = null	# the sub target to use for interception processing. Can be null

## This will contain any modified values for the parent action after processing has taken place.
## NOTE: Use get_shadowed_action_values() and set_shadowed_action_values() in interceptors
## instead of modifying this directly.
var shadowed_action_values: Dictionary = {}

## 当前正在执行的拦截器来源上下文；拦截器只能通过 getter 读取副本。
var _current_source_context: Dictionary[String, Variant] = {}

## 当前拦截器是否运行在无副作用预览模式。
var _is_preview_mode: bool = false

func _init(_parent_action: BaseAction, _target: BaseCombatant):
	parent_action = _parent_action
	target = _target

## Called via BaseAction.intercept_action().
## iterates over all interceptors, returning if the chain was accepted or rejected for further processing the action
## preview_mode flag is used for things like displaying cards in hand after modifiers or hovering cards over enemies. This tells interceptors to not create actual side effects
func process_interceptor_chain(preview_mode: bool = false) -> bool:
	var action_interceptors: Array[Dictionary] = _get_action_interceptors_modifying_pair(parent_action, parent_action.parent_combatant, target)
	if preview_mode:
		ActionHandler.begin_action_interceptor_preview()
	var accepted: bool = true
	_is_preview_mode = preview_mode
	for interceptor_entry: Dictionary in action_interceptors:
		var action_interceptor: BaseActionInterceptor = interceptor_entry["interceptor"]
		_current_source_context = interceptor_entry["source_context"].duplicate(true)
		var result: int = action_interceptor.process_action_interception(self, preview_mode)
		if result == BaseActionInterceptor.ACTION_ACCEPTENCES.STOPPED:
			break
		if result == BaseActionInterceptor.ACTION_ACCEPTENCES.REJECTED:
			accepted = false
			break
	_current_source_context.clear()
	_is_preview_mode = false
	if preview_mode:
		ActionHandler.end_action_interceptor_preview()
	return accepted

## 返回当前拦截器的只读来源上下文副本。
func get_source_context() -> Dictionary[String, Variant]:
	return _current_source_context.duplicate(true)

## 返回当前是否处于禁止副作用的预览查询。
func is_preview_mode() -> bool:
	return _is_preview_mode

## 根据当前来源上下文解析对应的本局实例；未知或旧来源返回 null。
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

## 预览模式返回来源资源深副本，正式模式返回真实本局实例。
func _protect_preview_source(source_instance: Variant) -> Variant:
	if _is_preview_mode and source_instance is Resource:
		return source_instance.duplicate(true)
	return source_instance

## Used by both interceptors during processing, then by the action after processing has taken place.
## this will shadow the parent action's values, allowing for interceptors to "modify" an action's
## values without actually changing them by standing above them in the action value hierarchy.
## First getting the original value, then shadowing with a value that will be continually modified.
func get_shadowed_action_values(key: String, default_value: Variant) -> Variant:
	var custom_action_value_keys: Dictionary = parent_action.values.get("custom_key_names", {})	# allows for having cards/actions use custom key names that convert to regular action key names. Useful for having cards with 2 of the same action but different values
	var key_name: String = custom_action_value_keys.get(key, key)
	if shadowed_action_values.has(key_name):
		return shadowed_action_values[key_name]
	else:
		return parent_action.get_action_value(key, default_value)

## Sets a value for a shadowed action value. Importantly, it will also perform custom_key_names
## conversions.
func set_shadowed_action_values(key: String, value: Variant) -> void:
	var custom_action_value_keys: Dictionary = parent_action.values.get("custom_key_names", {})	# allows for having cards/actions use custom key names that convert to regular action key names. Useful for having cards with 2 of the same action but different values
	var key_name: String = custom_action_value_keys.get(key, key)
	shadowed_action_values[key_name] = value

## Returns a priority-sorted array of all interceptors involving an action, its parent, and its target.
## Both parent and target can be the same, and one or both can be null.
## Additional flags ignore_all_interceptors, ignored_interceptor_ids, and forced_interceptor_ids can
## be provided through the action's values to alter which interceptors are allowed to be populated.
func _get_action_interceptors_modifying_pair(action: BaseAction, parent_combatant: BaseCombatant, target_combatant: BaseCombatant) -> Array[Dictionary]:
	var returned_action_interceptors: Array[Dictionary] = []
	var interceptor_entries: Array[Dictionary] = []
	
	### Get interceptor flags from action data
	# Use ignore_all_interceptors = true for actions which should always be performed unmodified
	var ignore_all_interceptors: bool = get_shadowed_action_values("ignore_all_interceptors", false)
	if ignore_all_interceptors:
		return []
	
	# InterceptorData IDs for specific interceptors to not use for this action.
	var ignored_interceptor_ids: Array[String] = []
	ignored_interceptor_ids.assign(get_shadowed_action_values("ignored_interceptor_ids", []))
	
	# InterceptorData IDs for specific interceptors to always use for this action.
	var forced_interceptor_ids: Array[String] = []
	forced_interceptor_ids.assign(get_shadowed_action_values("forced_interceptor_ids", []))
	
	### Parent Interceptors
	# get ids of all interceptors the parent has
	var parent_registrations: Array[ActionInterceptorRegistration] = []
	parent_registrations.assign(ActionHandler._registered_action_interceptors.get(parent_combatant, []))
	
	# get data objects of all corresponding interceptors affecting the parent
	for registration: ActionInterceptorRegistration in parent_registrations:
		var action_interceptor_object_id: String = registration.interceptor_id
		var action_interceptor_data: ActionInterceptorData = Global.get_action_interceptor_data(action_interceptor_object_id)
		if action_interceptor_data == null:
			continue
		# filter ignored interceptors
		if ignored_interceptor_ids.has(action_interceptor_object_id):
			continue
		# must modifiy parent
		if action_interceptor_data.action_interceptor_modifies_parent:
			# must modifiy this action
			var action_script_path: String = action.get_script().resource_path
			if action_interceptor_data.action_intercepted_action_paths.has(action_script_path):
				interceptor_entries.append({"data": action_interceptor_data, "registration": registration})
				forced_interceptor_ids.erase(action_interceptor_object_id)
	
	### Target Interceptors
	# get ids of all interceptors the target has
	var target_registrations: Array[ActionInterceptorRegistration] = []
	target_registrations.assign(ActionHandler._registered_action_interceptors.get(target_combatant, []))
	
	# get data objects of all corresponding affecting the target
	for registration: ActionInterceptorRegistration in target_registrations:
		var action_interceptor_object_id: String = registration.interceptor_id
		var action_interceptor_data: ActionInterceptorData = Global.get_action_interceptor_data(action_interceptor_object_id)
		if action_interceptor_data == null:
			continue
		# filter ignored interceptors
		if ignored_interceptor_ids.has(action_interceptor_object_id):
			continue
		
		# must modifiy target
		if not action_interceptor_data.action_interceptor_modifies_parent:
			# must modifiy this action
			var action_script_path: String = action.get_script().resource_path
			if action_interceptor_data.action_intercepted_action_paths.has(action_script_path):
				interceptor_entries.append({"data": action_interceptor_data, "registration": registration})
				forced_interceptor_ids.erase(action_interceptor_object_id)
	
	### Forced Interceptors
	# apply forced parent interceptors from action data
	for forced_interceptor_id: String in forced_interceptor_ids:
		if parent_registrations.any(func(registration: ActionInterceptorRegistration) -> bool:
			return registration.interceptor_id == forced_interceptor_id):
			continue # ignore duplicates
		if target_registrations.any(func(registration: ActionInterceptorRegistration) -> bool:
			return registration.interceptor_id == forced_interceptor_id):
			continue # ignore duplicates
		var action_interceptor_data: ActionInterceptorData = Global.get_action_interceptor_data(forced_interceptor_id)
		if action_interceptor_data == null:
			continue
		var forced_registration := ActionInterceptorRegistration.new(
			forced_interceptor_id, "forced", "", 0, 0)
		interceptor_entries.append({"data": action_interceptor_data, "registration": forced_registration})
	
	### Return
	# sort interceptor data by their priority
	interceptor_entries.sort_custom(_sort_action_interceptor_entries)
	
	# create interceptors from data
	for interceptor_entry: Dictionary in interceptor_entries:
		var action_interceptor_data: ActionInterceptorData = interceptor_entry["data"]
		var registration: ActionInterceptorRegistration = interceptor_entry["registration"]
		# create interceptor
		var action_interceptor_asset = load(action_interceptor_data.action_interceptor_script_path)
		var action_interceptor: BaseActionInterceptor = action_interceptor_asset.new()
		returned_action_interceptors.append({
			"interceptor": action_interceptor,
			"source_context": registration.get_source_context(),
		})
	
	return returned_action_interceptors

func _sort_action_interceptor_entries(entry_1: Dictionary, entry_2: Dictionary) -> bool:
	# 优先级较高者先执行；同优先级按装备顺序和稳定注册顺序执行。
	var data_1: ActionInterceptorData = entry_1["data"]
	var data_2: ActionInterceptorData = entry_2["data"]
	if data_1.action_interceptor_priority != data_2.action_interceptor_priority:
		return data_1.action_interceptor_priority > data_2.action_interceptor_priority
	var registration_1: ActionInterceptorRegistration = entry_1["registration"]
	var registration_2: ActionInterceptorRegistration = entry_2["registration"]
	if registration_1.source_order != registration_2.source_order:
		return registration_1.source_order < registration_2.source_order
	return registration_1.registration_order < registration_2.registration_order
