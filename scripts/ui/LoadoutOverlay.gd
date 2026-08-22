## 地图待选阶段的功法和内功搭配界面。
## 界面只维护候选副本，确认后通过 Action/Interceptor 一次性提交。
extends Control
class_name LoadoutOverlay

@onready var map: Control = $%Map
@onready var gongfa_rows: VBoxContainer = $Panel/Margin/VBox/GongfaScroll/GongfaRows
@onready var neigong_slots: HBoxContainer = $Panel/Margin/VBox/NeigongScroll/NeigongSlots
@onready var choice_title: Label = $Panel/Margin/VBox/ChoiceTitle
@onready var choice_container: VBoxContainer = $Panel/Margin/VBox/ChoiceScroll/ChoiceContainer
@onready var apply_gongfa_button: Button = $Panel/Margin/VBox/ActionButtons/ApplyGongfaButton
@onready var apply_neigong_button: Button = $Panel/Margin/VBox/ActionButtons/ApplyNeigongButton
@onready var close_button: Button = $Panel/Margin/VBox/ActionButtons/CloseButton
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel

## 当前界面中的功法候选序列；未提交前不会修改 PlayerData。
var draft_gongfa_sequences: Dictionary = {}

## 当前界面中的内功候选顺序；未提交前不会修改 PlayerData。
var draft_neigong_uids: Array[String] = []

## 当前正在选择功法的牌型和槽位。
var selected_hand_type_id: String = ""
var selected_gongfa_slot_index: int = -1

## 防止两个提交按钮同时发送行为。
var is_submitting: bool = false

func _ready() -> void:
	Signals.loadout_opened.connect(_on_loadout_opened)
	Signals.player_gongfa_changed.connect(_on_player_collection_changed)
	Signals.player_neigong_changed.connect(_on_player_collection_changed)
	Signals.player_gongfa_loadout_changed.connect(_on_player_loadout_changed)
	Signals.player_neigong_loadout_changed.connect(_on_player_loadout_changed)
	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)
	apply_gongfa_button.button_up.connect(_on_apply_gongfa_button_up)
	apply_neigong_button.button_up.connect(_on_apply_neigong_button_up)
	close_button.button_up.connect(_on_close_button_up)
	visible = false

## 打开搭配界面，并从本局当前配装创建独立候选副本。
func _on_loadout_opened() -> void:
	if not _is_loadout_available():
		return
	map.hide_map()
	visible = true
	is_submitting = false
	_copy_current_loadout_to_draft()
	_clear_choice_panel()
	_refresh_all()

## 复制当前完整配装；打开界面不会产生行为或保存。
func _copy_current_loadout_to_draft() -> void:
	draft_gongfa_sequences.clear()
	for hand_type_id: String in GongfaData.HAND_TYPE_IDS:
		draft_gongfa_sequences[hand_type_id] = (
			Global.player_data.player_gongfa_hand_sequences.get(hand_type_id, []).duplicate())
	draft_neigong_uids = Global.player_data.player_equipped_neigong_uids.duplicate()

## 重绘功法、内功和当前状态。
func _refresh_all() -> void:
	_refresh_gongfa_rows()
	_refresh_neigong_slots()
	_update_status()

## 按八种牌型显示连续功法和末尾空槽。
func _refresh_gongfa_rows() -> void:
	for child: Node in gongfa_rows.get_children():
		child.queue_free()
	if Global.player_data == null:
		return
	for hand_type_id: String in GongfaData.HAND_TYPE_IDS:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 48)
		var title := Label.new()
		title.custom_minimum_size = Vector2(112, 40)
		title.text = _hand_type_name(hand_type_id)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(title)
		var sequence: Array = draft_gongfa_sequences.get(hand_type_id, [])
		var capacity: int = Global.player_data.get_effective_gongfa_slot_count(hand_type_id)
		for slot_index: int in capacity:
			var slot_button := Button.new()
			slot_button.custom_minimum_size = Vector2(124, 40)
			if slot_index < sequence.size():
				var gongfa_uid: String = str(sequence[slot_index])
				var gongfa_data: GongfaData = Global.player_data.get_owned_gongfa(gongfa_uid)
				slot_button.text = gongfa_data.gongfa_name if gongfa_data != null else "未知功法"
				slot_button.tooltip_text = gongfa_data.gongfa_description if gongfa_data != null else ""
				slot_button.button_up.connect(
					_on_gongfa_slot_pressed.bind(hand_type_id, slot_index))
			elif slot_index == sequence.size():
				slot_button.text = "空槽"
				slot_button.button_up.connect(
					_on_gongfa_slot_pressed.bind(hand_type_id, slot_index))
			else:
				slot_button.text = ""
				slot_button.disabled = true
			row.add_child(slot_button)
		gongfa_rows.add_child(row)

## 按有效内功槽容量显示有序内功和空槽。
func _refresh_neigong_slots() -> void:
	for child: Node in neigong_slots.get_children():
		child.queue_free()
	if Global.player_data == null:
		return
	var capacity: int = Global.player_data.get_effective_neigong_slot_count()
	for slot_index: int in capacity:
		var slot_button := Button.new()
		slot_button.custom_minimum_size = Vector2(124, 40)
		if slot_index < draft_neigong_uids.size():
			var neigong_data: NeigongData = Global.player_data.get_owned_neigong(
				 draft_neigong_uids[slot_index])
			slot_button.text = neigong_data.neigong_name if neigong_data != null else "未知内功"
			slot_button.tooltip_text = neigong_data.neigong_description if neigong_data != null else ""
		elif slot_index == draft_neigong_uids.size():
			slot_button.text = "空槽"
			slot_button.modulate = Color(1.0, 1.0, 1.0, 0.55)
		else:
			slot_button.text = ""
			slot_button.disabled = true
		if not slot_button.disabled:
			slot_button.button_up.connect(_on_neigong_slot_pressed.bind(slot_index))
		neigong_slots.add_child(slot_button)

## 点击功法槽时打开符合该牌型和次数限制的功法列表。
func _on_gongfa_slot_pressed(hand_type_id: String, slot_index: int) -> void:
	if is_submitting:
		return
	selected_hand_type_id = hand_type_id
	selected_gongfa_slot_index = slot_index
	choice_title.text = "%s 功法" % _hand_type_name(hand_type_id)
	for child: Node in choice_container.get_children():
		child.queue_free()
	var current_sequence: Array = draft_gongfa_sequences.get(hand_type_id, [])
	if slot_index < current_sequence.size():
		var clear_button := Button.new()
		clear_button.text = "清空当前槽位"
		clear_button.button_up.connect(_on_clear_gongfa_slot)
		choice_container.add_child(clear_button)
	var candidate_uids: Array[String] = _get_available_gongfa_uids(hand_type_id, slot_index)
	for gongfa_uid: String in candidate_uids:
		var gongfa_data: GongfaData = Global.player_data.get_owned_gongfa(gongfa_uid)
		if gongfa_data == null:
			continue
		var choice_button := Button.new()
		choice_button.text = "%s（持有 %d）" % [
			gongfa_data.gongfa_name, gongfa_data.gongfa_owned_count]
		choice_button.tooltip_text = gongfa_data.gongfa_description
		choice_button.button_up.connect(_on_gongfa_choice_pressed.bind(gongfa_uid))
		choice_container.add_child(choice_button)
	if choice_container.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "暂无可配置功法"
		choice_container.add_child(empty_label)

## 计算某牌型槽位当前可用的功法实例 UID。
func _get_available_gongfa_uids(hand_type_id: String, slot_index: int) -> Array[String]:
	var result: Array[String] = []
	var current_sequence: Array = draft_gongfa_sequences.get(hand_type_id, [])
	var replacing_uid: String = str(current_sequence[slot_index]) \
		if slot_index < current_sequence.size() else ""
	var used_counts: Dictionary = {}
	for sequence_value: Variant in draft_gongfa_sequences.values():
		if not sequence_value is Array:
			continue
		for gongfa_uid_value: Variant in sequence_value:
			var gongfa_uid: String = str(gongfa_uid_value)
			used_counts[gongfa_uid] = int(used_counts.get(gongfa_uid, 0)) + 1
	if replacing_uid != "":
		used_counts[replacing_uid] = max(int(used_counts.get(replacing_uid, 0)) - 1, 0)
	var owned_values: Array = Global.player_data.player_gongfa_uid_to_gongfa_data.values()
	for gongfa_value: Variant in owned_values:
		if not gongfa_value is GongfaData:
			continue
		var gongfa_data: GongfaData = gongfa_value
		if not gongfa_data.supports_hand_type(hand_type_id):
			continue
		var gongfa_uid: String = gongfa_data.object_uid
		if int(used_counts.get(gongfa_uid, 0)) >= Global.player_data.get_effective_gongfa_equip_count(gongfa_uid):
			continue
		result.append(gongfa_uid)
	result.sort()
	return result

## 将选中的功法放入当前牌型槽；候选仍只写入界面草稿。
func _on_gongfa_choice_pressed(gongfa_uid: String) -> void:
	var sequence: Array = draft_gongfa_sequences.get(selected_hand_type_id, []).duplicate()
	if selected_gongfa_slot_index < 0 or selected_gongfa_slot_index > sequence.size():
		return
	if selected_gongfa_slot_index == sequence.size():
		sequence.append(gongfa_uid)
	else:
		sequence[selected_gongfa_slot_index] = gongfa_uid
	draft_gongfa_sequences[selected_hand_type_id] = sequence
	_clear_choice_panel()
	_refresh_all()

## 清空当前功法槽并保持其余功法连续前移。
func _on_clear_gongfa_slot() -> void:
	var sequence: Array = draft_gongfa_sequences.get(selected_hand_type_id, []).duplicate()
	if selected_gongfa_slot_index >= 0 and selected_gongfa_slot_index < sequence.size():
		sequence.remove_at(selected_gongfa_slot_index)
		draft_gongfa_sequences[selected_hand_type_id] = sequence
	_clear_choice_panel()
	_refresh_all()

## 点击内功槽时打开全部已拥有且未重复选择的内功。
func _on_neigong_slot_pressed(slot_index: int) -> void:
	if is_submitting:
		return
	selected_hand_type_id = ""
	selected_gongfa_slot_index = slot_index
	choice_title.text = "内功"
	for child: Node in choice_container.get_children():
		child.queue_free()
	if slot_index < draft_neigong_uids.size():
		var clear_button := Button.new()
		clear_button.text = "清空当前槽位"
		clear_button.button_up.connect(_on_clear_neigong_slot)
		choice_container.add_child(clear_button)
	var current_uid: String = draft_neigong_uids[slot_index] \
		if slot_index < draft_neigong_uids.size() else ""
	var owned_values: Array = Global.player_data.player_neigong_uid_to_neigong_data.values()
	for neigong_value: Variant in owned_values:
		if not neigong_value is NeigongData:
			continue
		var neigong_data: NeigongData = neigong_value
		if draft_neigong_uids.has(neigong_data.object_uid) and neigong_data.object_uid != current_uid:
			continue
		var choice_button := Button.new()
		choice_button.text = neigong_data.neigong_name
		choice_button.tooltip_text = neigong_data.neigong_description
		choice_button.button_up.connect(_on_neigong_choice_pressed.bind(neigong_data.object_uid))
		choice_container.add_child(choice_button)
	if slot_index == draft_neigong_uids.size():
		var empty_choice := Button.new()
		empty_choice.text = "保持空槽"
		empty_choice.button_up.connect(_clear_choice_panel)
		choice_container.add_child(empty_choice)
	if choice_container.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "暂无可装备内功"
		choice_container.add_child(empty_label)

## 将选中的内功放入候选顺序；不允许同一实例重复装备。
func _on_neigong_choice_pressed(neigong_uid: String) -> void:
	if selected_hand_type_id != "" or selected_gongfa_slot_index < 0 \
		or selected_gongfa_slot_index > draft_neigong_uids.size():
		return
	if selected_gongfa_slot_index == draft_neigong_uids.size():
		draft_neigong_uids.append(neigong_uid)
	else:
		draft_neigong_uids[selected_gongfa_slot_index] = neigong_uid
	_clear_choice_panel()
	_refresh_all()

## 清空当前内功槽并保持后续槽位连续前移。
func _on_clear_neigong_slot() -> void:
	if selected_gongfa_slot_index >= 0 and selected_gongfa_slot_index < draft_neigong_uids.size():
		draft_neigong_uids.remove_at(selected_gongfa_slot_index)
	_clear_choice_panel()
	_refresh_all()

## 通过正式行为提交完整功法候选序列。
func _on_apply_gongfa_button_up() -> void:
	if not _is_loadout_available() or is_submitting:
		return
	if not Global.player_data.validate_gongfa_loadout(draft_gongfa_sequences):
		status_label.text = "功法配装不合法，请检查槽位和持有次数"
		return
	is_submitting = true
	_update_apply_buttons()
	ActionGenerator.generate_set_gongfa_loadout(draft_gongfa_sequences)
	await _wait_for_actions_and_save()
	is_submitting = false
	_update_apply_buttons()
	status_label.text = "功法配装已应用"

## 通过正式行为提交完整内功候选顺序。
func _on_apply_neigong_button_up() -> void:
	if not _is_loadout_available() or is_submitting:
		return
	if not Global.player_data.validate_neigong_loadout(draft_neigong_uids):
		status_label.text = "内功配装不合法，请检查槽位和重复实例"
		return
	is_submitting = true
	_update_apply_buttons()
	ActionGenerator.generate_set_neigong_loadout(draft_neigong_uids)
	await _wait_for_actions_and_save()
	is_submitting = false
	_update_apply_buttons()
	status_label.text = "内功配装已应用"

## 行为结束后只保存一次本局配装结果。
func _wait_for_actions_and_save() -> void:
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	FileLoader.autosave()

## 关闭搭配界面并返回同一个地图待选阶段；未应用草稿直接丢弃。
func _on_close_button_up() -> void:
	if is_submitting:
		return
	visible = false
	_clear_choice_panel()
	if map != null:
		map.can_travel = true
		map.show_map()

## 进入节点、战斗或离开本局时关闭界面。
func _on_run_started() -> void:
	visible = false

## 本局结束时清除临时草稿。
func _on_run_ended() -> void:
	visible = false
	draft_gongfa_sequences.clear()
	draft_neigong_uids.clear()

## 拥有内容变化后重建候选，但不覆盖用户尚未提交的草稿。
func _on_player_collection_changed() -> void:
	if visible and not is_submitting:
		_refresh_all()

## 提交成功后同步草稿为本局正式配装。
func _on_player_loadout_changed() -> void:
	if visible and not is_submitting:
		_copy_current_loadout_to_draft()
		_refresh_all()

## 清除右侧功法选择列表。
func _clear_choice_panel() -> void:
	selected_hand_type_id = ""
	selected_gongfa_slot_index = -1
	choice_title.text = "请选择一个槽位"
	for child: Node in choice_container.get_children():
		child.queue_free()

## 根据提交状态更新按钮可用性。
func _update_apply_buttons() -> void:
	apply_gongfa_button.disabled = is_submitting or not _is_loadout_available()
	apply_neigong_button.disabled = is_submitting or not _is_loadout_available()

## 更新界面状态文本和按钮状态。
func _update_status() -> void:
	status_label.text = "节点完成后可调整搭配；修改后分别点击应用"
	_update_apply_buttons()

## 判断当前是否处于地图节点待选阶段。
func _is_loadout_available() -> bool:
	return Global.player_data != null \
		and Global.player_data.player_waiting_for_node_selection \
		and not ActionHandler.actions_being_performed

## 将内部牌型 ID转换为界面名称。
func _hand_type_name(hand_type_id: String) -> String:
	return {
		"high_card": "高牌",
		"pair": "对子",
		"two_pair": "双对",
		"three_kind": "三条",
		"straight": "顺子",
		"full_house": "葫芦",
		"four_kind": "四条",
		"five_kind": "五条",
	}.get(hand_type_id, hand_type_id)
