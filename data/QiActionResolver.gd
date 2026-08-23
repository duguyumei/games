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
		_collect_enemy_gongfa_modifiers(side_result, hand_type_id, battle_state)
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
		side_result: QiActionSideResult,
		hand_type_id: String,
		battle_state: BattleQiState) -> void:
	var current_slot: Dictionary = battle_state.get_current_gongfa_slot(
		hand_type_id, BattleQiState.SIDE_ENEMY)
	var gongfa_data_list: Array[GongfaData] = _get_enemy_gongfa_data(
		hand_type_id, current_slot)
	for gongfa_data: GongfaData in gongfa_data_list:
		if current_slot.is_empty():
			side_result.gongfa_instance_uids.append(
				battle_state.get_active_enemy_instance_id())
			side_result.gongfa_slot_instance_ids.append("")
		else:
			side_result.gongfa_instance_uids.append(
				str(current_slot.get("gongfa_instance_uid", "")))
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

## 读取敌方当前队列功法；没有固定功法时保留内嵌效果配置作为空槽替代来源。
static func _get_enemy_gongfa_data(
		hand_type_id: String, current_slot: Dictionary) -> Array[GongfaData]:
	var result: Array[GongfaData] = []
	if not current_slot.is_empty():
		var definition_id: String = str(current_slot.get("gongfa_definition_id", ""))
		var configured_gongfa: GongfaData = Global.get_gongfa_data(definition_id)
		if configured_gongfa != null:
			result.append(configured_gongfa)
		return result
	var enemies: Array[Enemy] = Global.get_alive_enemies()
	if enemies.is_empty():
		return result
	var effect_groups: Variant = enemies[0].enemy_data.get(
		"enemy_gongfa_effects_by_hand_type")
	if not effect_groups is Dictionary:
		return result
	for effect_value: Variant in effect_groups.get(hand_type_id, []):
		if not effect_value is Dictionary:
			continue
		var fallback_gongfa: GongfaData = GongfaData.new()
		fallback_gongfa.gongfa_eligible_hand_ids = [hand_type_id]
		fallback_gongfa.gongfa_effects = [effect_value]
		result.append(fallback_gongfa)
	return result

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
	for gongfa_index: int in gongfa_data_list.size():
		var gongfa_data: GongfaData = gongfa_data_list[gongfa_index]
		var source_instance_id: String = ""
		if gongfa_index < side_result.gongfa_instance_uids.size():
			source_instance_id = side_result.gongfa_instance_uids[gongfa_index]
		if source_instance_id == "" and side == BattleQiState.SIDE_ENEMY:
			source_instance_id = battle_state.get_active_enemy_instance_id()
		for effect_index: int in gongfa_data.gongfa_effects.size():
			var effect_value: Variant = gongfa_data.gongfa_effects[effect_index]
			var action_data: Array[Dictionary] = _extract_action_data(effect_value)
			if action_data.is_empty():
				continue
			var resolved_action_data: Array[Dictionary] = _resolve_power_placeholders(
				action_data, side_result)
			var effect_id: String = str(
				effect_value.get("effect_id", "") if effect_value is Dictionary else "")
			if effect_id == "":
				effect_id = "gongfa:%s:%d" % [gongfa_data.object_id, effect_index]
			resolved_action_data = _inject_damage_source_context(
				resolved_action_data,
				side,
				"gongfa",
				source_instance_id,
				effect_id)
			actions.append_array(ActionGenerator.create_actions(
				parent_combatant, null, targets, resolved_action_data, null))
	return actions

## 为功法效果生成的所有伤害动作注入可追踪的来源上下文。
static func _inject_damage_source_context(
		actions_data: Array[Dictionary],
		source_side: String,
		source_kind: String,
		source_instance_id: String,
		source_effect_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action_data: Dictionary in actions_data:
		result.append(_inject_damage_context_variant(
			action_data, source_side, source_kind, source_instance_id, source_effect_id))
	return result

## 递归处理动作包装结构，不修改功法固定配置资源。
static func _inject_damage_context_variant(
		value: Variant,
		source_side: String,
		source_kind: String,
		source_instance_id: String,
		source_effect_id: String) -> Variant:
	if value is Array:
		var array_result: Array = []
		for item: Variant in value:
			array_result.append(_inject_damage_context_variant(
				item, source_side, source_kind, source_instance_id, source_effect_id))
		return array_result
	if not value is Dictionary:
		return value
	var dictionary_result: Dictionary = {}
	for key: Variant in value.keys():
		var key_string: String = str(key)
		var child_value: Variant = _inject_damage_context_variant(
			value[key], source_side, source_kind, source_instance_id, source_effect_id)
		if _is_source_tracked_action_path(key_string) and child_value is Dictionary:
			var damage_values: Dictionary = child_value.duplicate(true)
			damage_values["source_side"] = source_side
			damage_values["source_kind"] = source_kind
			damage_values["source_instance_id"] = source_instance_id
			damage_values["source_effect_id"] = source_effect_id
			child_value = damage_values
		dictionary_result[key] = child_value
	return dictionary_result

## 判断动作路径是否属于统一伤害入口或其多段生成器。
static func _is_damage_action_path(action_path: String) -> bool:
	return action_path == Scripts.ACTION_ATTACK \
		or action_path == Scripts.ACTION_ATTACK_GENERATOR \
		or action_path == Scripts.ACTION_DIRECT_DAMAGE

## 判断动作路径是否需要记录功法来源，例如护盾和格挡来源。
static func _is_source_tracked_action_path(action_path: String) -> bool:
	return _is_damage_action_path(action_path) \
		or action_path == Scripts.ACTION_BLOCK \
		or action_path == Scripts.ACTION_ADD_GUARD \
		or action_path == Scripts.ACTION_ADD_REFLECT \
		or action_path == Scripts.ACTION_ADD_RESOLUTION \
		or action_path == Scripts.ACTION_ADD_SHIELD_PENETRATION

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
	var current_slot: Dictionary = battle_state.get_current_gongfa_slot(
		hand_type_id, BattleQiState.SIDE_ENEMY)
	return _get_enemy_gongfa_data(hand_type_id, current_slot)

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
