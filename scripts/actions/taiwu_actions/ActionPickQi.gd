## 选择真气后生成配置的后续行为；选择过程本身不修改真气。
extends ActionBasePickQi
class_name ActionPickQi

## 将选中的真气 UID 注入每个子行为，避免子行为依赖 UI 或对象引用。
func perform_async_action() -> void:
	_super_prepare_picked_uids()
	_generate_child_actions()
	action_async_finished.emit()

## 创建后续行为；空 action_data 仍然是一个合法的纯选择动作。
func _generate_child_actions() -> void:
	if not are_enough_qis_picked() and bool(get_action_value("min_qi_required", true)):
		return
	var action_data: Array[Dictionary] = []
	action_data.assign(get_action_value("action_data", []))
	if action_data.is_empty():
		return
	var child_action_data: Array[Dictionary] = []
	for action_definition: Dictionary in action_data:
		for action_path: String in action_definition.keys():
			var child_values: Dictionary = {}
			child_values.assign(action_definition[action_path])
			child_values["qi_instance_uids"] = picked_qi_instance_uids.duplicate()
			child_action_data.append({action_path: child_values})
	var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(
		parent_combatant, card_play_request, targets, child_action_data, self)
	ActionHandler.add_actions(generated_actions)

## 将对象引用转换为稳定 UID；子行为只接收纯数据。
func _super_prepare_picked_uids() -> void:
	picked_qi_instance_uids.clear()
	for qi_data: QiData in picked_qis:
		if qi_data != null and qi_data.object_uid != "" and not picked_qi_instance_uids.has(qi_data.object_uid):
			picked_qi_instance_uids.append(qi_data.object_uid)
