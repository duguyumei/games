## 抽象的真气选择动作；不修改旧 CardData 选择流程。
extends BaseAsyncAction
class_name ActionBasePickQi

## 从本局真气牌组中选择候选；非战斗消耗品默认使用此来源。
const SOURCE_OWNED_DECK_DRAFT: String = "owned_deck_draft"
## 预留的战斗手牌来源；完整真气战斗手牌接入后由调用方传入数组。
const SOURCE_BATTLE_HAND: String = "battle_hand"

## 玩家最终确认的真气实例。
var picked_qis: Array[QiData] = []
## 玩家最终确认的真气实例 UID，供后续行为稳定引用。
var picked_qi_instance_uids: Array[String] = []
## 已生成并缓存的候选真气；界面重绘不会再次随机。
var candidate_qis: Array[QiData] = []
## 标记候选是否已经生成，防止重新打开界面改变结果。
var _candidates_generated: bool = false

## 选择完成后由子类执行实际行为。
func perform_async_action() -> void:
	picked_qi_instance_uids.clear()
	for qi_data: QiData in picked_qis:
		if qi_data != null and qi_data.object_uid != "" and not picked_qi_instance_uids.has(qi_data.object_uid):
			picked_qi_instance_uids.append(qi_data.object_uid)
	action_async_finished.emit()

## 执行选择流程；候选不足时按配置自动结束，不会修改真气。
func perform_action() -> void:
	var pickable_qis: Array[QiData] = get_pickable_qis()
	var min_select: int = get_qi_pick_min_amount()
	var max_select: int = get_qi_pick_max_amount()
	var min_required: bool = bool(get_action_value("min_qi_required", true))
	var random_selection: bool = bool(get_action_value("random_selection", false))

	if max_select < min_select:
		max_select = min_select
	if pickable_qis.size() < min_select:
		if min_required:
			await _finish_without_selection()
		else:
			picked_qis = pickable_qis
			await _finish_after_frame()
		return
	if pickable_qis.size() == min_select and min_select > 0:
		picked_qis = pickable_qis.duplicate()
		await _finish_after_frame()
		return
	if random_selection:
		var randomized: Array[QiData] = pickable_qis.duplicate()
		var rng: RandomNumberGenerator = Global.player_data.get_player_rng(
			str(get_action_value("rng_name", "rng_qi_picking")))
		Random.shuffle_array(rng, randomized)
		picked_qis = randomized.slice(0, min(min_select, randomized.size()))
		await _finish_after_frame()
		return

	async_awaiting = true
	Signals.qi_pick_requested.emit(self)
	await Signals.qi_pick_confirmed
	async_awaiting = false
	perform_async_action()

## 返回选择提示；支持 {0}=最大数量、{1}=已选数量、{2}=剩余数量、{3}=候选数量。
func get_qi_pick_text() -> String:
	var max_select: int = get_qi_pick_max_amount()
	var selected_count: int = picked_qis.size()
	var remaining_count: int = max(max_select - selected_count, 0)
	var default_text: String = "选择 {0} 张真气（已选 {1}，还可选 {2}）"
	var text_template: String = str(get_action_value("qi_pick_text", default_text))
	return text_template.format([max_select, selected_count, remaining_count, candidate_qis.size()])

## 获取并缓存可供选择的候选真气。
func get_pickable_qis() -> Array[QiData]:
	if _candidates_generated:
		return candidate_qis
	_candidates_generated = true
	var source_qis: Array[QiData] = _get_input_qis()
	var candidate_count: int = int(get_action_value("candidate_count", source_qis.size()))
	if candidate_count <= 0 or candidate_count >= source_qis.size():
		candidate_qis = source_qis.duplicate()
		return candidate_qis
	var rng: RandomNumberGenerator = Global.player_data.get_player_rng(
		str(get_action_value("rng_name", "rng_qi_picking")))
	var randomized: Array[QiData] = source_qis.duplicate()
	Random.shuffle_array(rng, randomized)
	candidate_qis = randomized.slice(0, candidate_count)
	return candidate_qis

## 返回动作声明的真气来源；战斗手牌允许由 action value 直接传入。
func _get_input_qis() -> Array[QiData]:
	var source: String = str(get_action_value(
		"qi_pick_source", get_action_value("source", SOURCE_OWNED_DECK_DRAFT)))
	var source_qis: Array[QiData] = []
	if source == SOURCE_BATTLE_HAND:
		var supplied_hand: Array = get_action_value("battle_hand", [])
		for value: Variant in supplied_hand:
			if value is QiData:
				source_qis.append(value)
		return source_qis
	for qi_data: QiData in Global.player_data.player_qi_deck:
		if qi_data != null and qi_data.object_uid != "":
			source_qis.append(qi_data)
	return source_qis

## 最小选择数量；默认选择一张。
func get_qi_pick_min_amount() -> int:
	return max(int(get_action_value("min_select", 1)), 0)

## 最大选择数量；默认与最小选择数量相同。
func get_qi_pick_max_amount() -> int:
	return max(int(get_action_value("max_select", get_qi_pick_min_amount())), get_qi_pick_min_amount())

## 当前选择数量是否满足确认条件。
func are_enough_qis_picked() -> bool:
	return picked_qis.size() >= get_qi_pick_min_amount() \
		and picked_qis.size() <= get_qi_pick_max_amount()

## 判断一张候选真气能否加入当前选择。
func is_qi_pickable(qi_data: QiData, check_max_pick_size: bool = true) -> bool:
	if qi_data == null or not candidate_qis.has(qi_data):
		return false
	if picked_qis.has(qi_data):
		return true
	if check_max_pick_size and picked_qis.size() >= get_qi_pick_max_amount():
		return false
	return true

## 达到最大数量时是否自动确认。
func is_quick_qi_pick() -> bool:
	return bool(get_action_value("quick_pick", true)) \
		and picked_qis.size() >= get_qi_pick_max_amount()

## 取消或强制结束选择时清空结果，避免误应用真气状态。
func force_action_end() -> void:
	if async_awaiting:
		picked_qis.clear()
		picked_qi_instance_uids.clear()
		Signals.qi_pick_confirmed.emit()
		async_awaiting = false

## 选择动作没有额外时间延迟，异步等待由 ActionHandler 管理。
func is_instant_action() -> bool:
	return true

## 在下一帧结束一个没有足够候选的选择动作。
func _finish_without_selection() -> void:
	picked_qis.clear()
	await Global.get_tree().process_frame
	perform_async_action()

## 在下一帧执行自动选择结果，给动作队列留出接收异步完成信号的时间。
func _finish_after_frame() -> void:
	await Global.get_tree().process_frame
	perform_async_action()
