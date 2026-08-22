## 真气行动的纯识别、数值计算和功法动作构造服务。
## 识别和数值计算不修改战斗状态；正式移动和事件由 Global 统一提交。
extends RefCounted
class_name QiActionResolver

## 计算双方冻结请求的牌型、同气和功法值结果。
static func calculate_request_results(
		request: QiActionRequest,
		battle_state: BattleQiState) -> bool:
	if request == null or battle_state == null or not request.is_valid_request():
		return false
	if request.enemy_instance_id != battle_state.get_active_enemy_instance_id():
		return false
	var player_cards: Array[QiData] = _get_request_cards(
		battle_state, BattleQiState.SIDE_PLAYER, request.player_qi_instance_uids)
	var enemy_cards: Array[QiData] = _get_request_cards(
		battle_state, BattleQiState.SIDE_ENEMY, request.enemy_qi_instance_uids)
	var player_result: QiActionSideResult = calculate_side_result(
		BattleQiState.SIDE_PLAYER, player_cards, battle_state)
	var enemy_result: QiActionSideResult = calculate_side_result(
		BattleQiState.SIDE_ENEMY, enemy_cards, battle_state)
	if BattleQiState.SIDE_PLAYER in request.eligible_sides \
		and request.player_gongfa_slot_instance_id != _get_result_slot_instance_id(player_result):
		return false
	if BattleQiState.SIDE_ENEMY in request.eligible_sides \
		and request.enemy_gongfa_slot_instance_id != _get_result_slot_instance_id(enemy_result):
		return false
	if BattleQiState.SIDE_PLAYER in request.eligible_sides and not player_result.is_valid():
		return false
	if BattleQiState.SIDE_ENEMY in request.eligible_sides \
		and not request.enemy_qi_instance_uids.is_empty() \
		and not enemy_result.is_valid():
		return false
	request.set_resolution_results(
		player_result, enemy_result,
		battle_state.get_combo_value(BattleQiState.SIDE_PLAYER),
		battle_state.get_combo_value(BattleQiState.SIDE_ENEMY))
	return true

## 返回一方本次牌型读取的第一个战斗功法实例 ID。
static func _get_result_slot_instance_id(side_result: QiActionSideResult) -> String:
	if side_result == null or side_result.gongfa_slot_instance_ids.is_empty():
		return ""
	return side_result.gongfa_slot_instance_ids[0]

## 计算一方牌型结果、真气贡献总和、倍率和功法值。
static func calculate_side_result(
		side: String,
		qi_cards: Array[QiData],
		battle_state: BattleQiState) -> QiActionSideResult:
	var side_result: QiActionSideResult = QiActionSideResult.new()
	side_result.side = side
	side_result.pattern = QiHandRecognizer.recognize(qi_cards, battle_state)
	if not side_result.pattern.is_valid():
		return side_result
	for qi_data: QiData in qi_cards:
		if not side_result.pattern.participating_qi_instance_uids.has(qi_data.object_uid):
			continue
		side_result.qi_value_sum += qi_data.get_contribution_qi_value(
			battle_state, {"participates_in_value": true})
		side_result.multiplier_modifiers += qi_data.get_gongfa_multiplier_modifier()
	side_result.base_multiplier = side_result.pattern.max_same_qi
	_collect_gongfa_modifiers(
		side_result, side_result.pattern.hand_type_id, battle_state)
	var multiplier: int = max(side_result.base_multiplier + side_result.multiplier_modifiers, 0)
	side_result.initial_power = int(floor(float(side_result.qi_value_sum * multiplier)))
	side_result.final_power = max(
		int(floor(float(side_result.initial_power + side_result.direct_fixed_modifier) \
			* (1.0 + float(side_result.direct_percent_modifier) / 100.0))), 0)
	return side_result

## 收集当前牌型功法序列的固定和百分比修正，并记录可执行功法 UID。
static func _collect_gongfa_modifiers(
		side_result: QiActionSideResult,
		hand_type_id: String,
		battle_state: BattleQiState) -> void:
	if side_result.side == BattleQiState.SIDE_ENEMY:
		_collect_enemy_gongfa_modifiers(side_result, hand_type_id)
		return
	if Global.player_data == null:
		return
	var current_slot: Dictionary = battle_state.get_current_gongfa_slot(
		hand_type_id, side_result.side)
	var gongfa_instance_uid: String = str(current_slot.get("gongfa_instance_uid", ""))
	if gongfa_instance_uid == "":
		return
	var gongfa_data: GongfaData = Global.player_data.get_owned_gongfa(gongfa_instance_uid)
	if gongfa_data == null or not gongfa_data.supports_hand_type(hand_type_id):
		return
	side_result.gongfa_instance_uids.append(gongfa_instance_uid)
	side_result.gongfa_slot_instance_ids.append(
		str(current_slot.get("slot_instance_id", "")))
	side_result.gongfa_copy_count = _get_gongfa_copy_count(gongfa_data)
	for effect_value: Variant in gongfa_data.gongfa_effects:
		if not effect_value is Dictionary:
			continue
		var effect: Dictionary = effect_value
		side_result.multiplier_modifiers += int(effect.get("multiplier_modifier", 0))
		side_result.direct_fixed_modifier += int(effect.get("power_fixed", 0))
		side_result.direct_percent_modifier += int(effect.get("power_percent", 0))

## 读取功法效果配置中的临时复制请求；没有该字段时不生成复制品。
static func _get_gongfa_copy_count(gongfa_data: GongfaData) -> int:
	if gongfa_data == null:
		return 0
	var copy_count: int = 0
	for effect_value: Variant in gongfa_data.gongfa_effects:
		if not effect_value is Dictionary:
			continue
		var effect: Dictionary = effect_value
		if str(effect.get("queue_operation", "")) != "copy_self":
			continue
		copy_count += max(int(effect.get("copy_count", 1)), 0)
	return copy_count

## 读取敌方牌型功法配置中的数值修正。
static func _collect_enemy_gongfa_modifiers(
		side_result: QiActionSideResult, hand_type_id: String) -> void:
	var enemies: Array[Enemy] = Global.get_alive_enemies()
	if enemies.is_empty():
		return
	var effect_groups: Variant = enemies[0].enemy_data.get(
		"enemy_gongfa_effects_by_hand_type")
	if not effect_groups is Dictionary:
		return
	for effect_value: Variant in effect_groups.get(hand_type_id, []):
		if not effect_value is Dictionary:
			continue
		var effect: Dictionary = effect_value
		side_result.multiplier_modifiers += int(effect.get("multiplier_modifier", 0))
		side_result.direct_fixed_modifier += int(effect.get("power_fixed", 0))
		side_result.direct_percent_modifier += int(effect.get("power_percent", 0))

## 为双方当前牌型构造现有 Action/Interceptor 可执行的功法动作。
static func build_effect_actions(
		request: QiActionRequest,
		battle_state: BattleQiState) -> Array[BaseAction]:
	var actions: Array[BaseAction] = []
	if request == null or battle_state == null:
		return actions
	if request.player_result != null:
		actions.append_array(_build_side_effect_actions(
			BattleQiState.SIDE_PLAYER, request.player_result, battle_state))
	if request.enemy_result != null:
		actions.append_array(_build_side_effect_actions(
			BattleQiState.SIDE_ENEMY, request.enemy_result, battle_state))
	return actions

## 将一方装备功法的动作配置按当前功法值转换成动作实例。
static func _build_side_effect_actions(
		side: String,
		side_result: QiActionSideResult,
		battle_state: BattleQiState) -> Array[BaseAction]:
	var actions: Array[BaseAction] = []
	if side_result == null or not side_result.is_valid():
		return actions
	var parent_combatant: BaseCombatant = null
	var targets: Array[BaseCombatant] = []
	if side == BattleQiState.SIDE_PLAYER:
		parent_combatant = Global.get_player()
		for enemy: Enemy in Global.get_alive_enemies():
			targets.append(enemy)
	else:
		var alive_enemies: Array[Enemy] = Global.get_alive_enemies()
		if alive_enemies.is_empty():
			return actions
		parent_combatant = alive_enemies[0]
		var player: BaseCombatant = Global.get_player()
		if player != null:
			targets.append(player)
	var gongfa_data_list: Array[GongfaData] = _get_side_gongfa_data(
		side, side_result, battle_state)
	for gongfa_data: GongfaData in gongfa_data_list:
		for effect_value: Variant in gongfa_data.gongfa_effects:
			var action_data: Array[Dictionary] = _extract_action_data(effect_value)
			if action_data.is_empty():
				continue
			var resolved_action_data: Array[Dictionary] = _resolve_power_placeholders(
				action_data, side_result)
			actions.append_array(ActionGenerator.create_actions(
				parent_combatant, null, targets, resolved_action_data, null))
	return actions

## 读取玩家功法序列或敌方牌型功法配置。
static func _get_side_gongfa_data(
		side: String,
		side_result: QiActionSideResult,
		battle_state: BattleQiState) -> Array[GongfaData]:
	var result: Array[GongfaData] = []
	var hand_type_id: String = side_result.pattern.hand_type_id
	if side == BattleQiState.SIDE_PLAYER and Global.player_data != null:
		for gongfa_instance_uid: String in side_result.gongfa_instance_uids:
			var gongfa_data: GongfaData = Global.player_data.get_owned_gongfa(gongfa_instance_uid)
			if gongfa_data != null and gongfa_data.supports_hand_type(hand_type_id):
				result.append(gongfa_data)
		return result
	var enemies: Array[Enemy] = Global.get_alive_enemies()
	if enemies.is_empty():
		return result
	var enemy_effects: Variant = enemies[0].enemy_data.get("enemy_gongfa_effects_by_hand_type")
	# 敌方效果没有独立 GongfaData 时用临时对象承载相同动作格式。
	if enemy_effects is Dictionary:
		for effect_value: Variant in enemy_effects.get(hand_type_id, []):
			var enemy_gongfa: GongfaData = GongfaData.new()
			enemy_gongfa.gongfa_eligible_hand_ids = [hand_type_id]
			if effect_value is Dictionary:
				var enemy_effects_list: Array[Dictionary] = []
				enemy_effects_list.append(effect_value)
				enemy_gongfa.gongfa_effects = enemy_effects_list
			result.append(enemy_gongfa)
	return result

## 从一个功法效果配置中读取动作列表；兼容直接动作和 actions 包装格式。
static func _extract_action_data(effect_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not effect_value is Dictionary:
		return result
	var effect: Dictionary = effect_value
	var nested: Variant = effect.get("actions", effect.get("action_data", null))
	if nested is Array:
		for action_value: Variant in nested:
			if action_value is Dictionary:
				result.append(action_value)
		return result
	# 没有元数据字段时，把当前字典视为一个标准动作字典。
	var direct_action: Dictionary = {}
	for action_path: Variant in effect.keys():
		if str(action_path).begins_with("res://"):
			direct_action[str(action_path)] = effect[action_path]
	if not direct_action.is_empty():
		result.append(direct_action)
	return result

## 递归替换效果动作中的功法值占位符。
static func _resolve_power_placeholders(
		actions_data: Array[Dictionary], side_result: QiActionSideResult) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action_data: Dictionary in actions_data:
		var resolved_action: Dictionary = _resolve_variant(action_data, side_result)
		result.append(resolved_action)
	return result

## 递归复制字典、数组并替换常用数值占位符。
static func _resolve_variant(value: Variant, side_result: QiActionSideResult) -> Variant:
	if value is Dictionary:
		var dictionary_result: Dictionary = {}
		for key: Variant in value.keys():
			dictionary_result[key] = _resolve_variant(value[key], side_result)
		return dictionary_result
	if value is Array:
		var array_result: Array = []
		for item: Variant in value:
			array_result.append(_resolve_variant(item, side_result))
		return array_result
	if value is String:
		match value:
			"$power":
				return side_result.final_power
			"$power0":
				return side_result.initial_power
			"$qi_value_sum":
				return side_result.qi_value_sum
			"$same_qi":
				return side_result.pattern.max_same_qi
	return value

## 根据行动请求读取指定 UID 的牌区真气；未知 UID 会返回空数组。
static func _get_request_cards(
		battle_state: BattleQiState,
		side: String,
		qi_instance_uids: Array[String]) -> Array[QiData]:
	var result: Array[QiData] = []
	for qi_instance_uid: String in qi_instance_uids:
		var qi_data: QiData = battle_state.get_qi(side, qi_instance_uid)
		if qi_data == null:
			return []
		result.append(qi_data)
	return result
