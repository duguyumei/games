## 真气行动的纯数值计算、功法原子构造和安全公式解析服务。
extends RefCounted
class_name QiActionResolver

## 安全公式允许读取的冻结数值字段。
const FORMULA_VARIABLES: Array[String] = [
	"base_qi_value_sum",
	"final_qi_value_sum",
	"qi_value_sum",
	"base_multiplier",
	"final_multiplier",
	"base_power",
	"initial_power",
	"effective_power",
	"final_power",
	"power",
]

## 计算双方冻结请求的牌型、统一数值管线和当前主动功法快照。
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
		and not request.enemy_qi_instance_uids.is_empty() and not enemy_result.is_valid():
		return false
	request.set_resolution_results(
		player_result,
		enemy_result,
		battle_state.get_combo_value(BattleQiState.SIDE_PLAYER),
		battle_state.get_combo_value(BattleQiState.SIDE_ENEMY))
	return true

## 计算一方牌型、每张真气三阶段数值、全待结算区同气倍率和有效功法值。
static func calculate_side_result(
		side: String,
		qi_cards: Array[QiData],
		battle_state: BattleQiState) -> QiActionSideResult:
	var side_result: QiActionSideResult = QiActionSideResult.new()
	side_result.side = side
	side_result.pattern = QiHandRecognizer.recognize(qi_cards, battle_state)
	if not side_result.pattern.is_valid():
		return side_result
	_collect_active_gongfa(side_result, battle_state)
	QiValuePipeline.calculate_side_values(side_result, qi_cards, battle_state)
	return side_result

## 返回一方本次牌型读取的第一个战斗功法实例 ID。
static func _get_result_slot_instance_id(side_result: QiActionSideResult) -> String:
	if side_result == null or side_result.gongfa_slot_instance_ids.is_empty():
		return ""
	return side_result.gongfa_slot_instance_ids[0]

## 冻结当前牌型队首功法；其他功法只作为条件数值钩子参与，不主动执行原子。
static func _collect_active_gongfa(
		side_result: QiActionSideResult,
		battle_state: BattleQiState) -> void:
	var current_slot: Dictionary = battle_state.get_current_gongfa_slot(
		side_result.pattern.hand_type_id, side_result.side)
	if current_slot.is_empty():
		return
	var gongfa_data: GongfaData = _get_slot_gongfa_data(side_result.side, current_slot)
	if gongfa_data == null \
		or not gongfa_data.supports_hand_type(side_result.pattern.hand_type_id) \
		or not gongfa_data.is_valid_gongfa():
		return
	side_result.gongfa_instance_uids.append(
		str(current_slot.get("gongfa_instance_uid", "")))
	side_result.gongfa_slot_instance_ids.append(
		str(current_slot.get("slot_instance_id", "")))

## 为双方主动功法构造已调度的原子组行为。
static func build_effect_actions(
		request: QiActionRequest,
		battle_state: BattleQiState) -> Array[BaseAction]:
	var result: Array[BaseAction] = []
	if request == null or battle_state == null:
		return result
	var player_atoms: Array[Dictionary] = _build_side_atoms(
		BattleQiState.SIDE_PLAYER, request.player_result, battle_state)
	var enemy_atoms: Array[Dictionary] = _build_side_atoms(
		BattleQiState.SIDE_ENEMY, request.enemy_result, battle_state)
	for group: Dictionary in GongfaAtomScheduler.schedule_atom_groups(
			player_atoms, enemy_atoms):
		var player_actions: Array[BaseAction] = []
		var enemy_actions: Array[BaseAction] = []
		var player_atom: Dictionary = group.get("player_atom", {})
		var enemy_atom: Dictionary = group.get("enemy_atom", {})
		if not player_atom.is_empty():
			player_actions.assign(player_atom.get("actions", []))
		if not enemy_atom.is_empty():
			enemy_actions.assign(enemy_atom.get("actions", []))
		var atomic_group: ActionQiAtomicGroup = ActionQiAtomicGroup.new()
		atomic_group.init_atomic_group(
			player_actions,
			enemy_actions,
			request,
			int(player_atom.get("atom_index", -1)) \
				== int(player_atom.get("atom_count", 0)) - 1,
			int(enemy_atom.get("atom_index", -1)) \
				== int(enemy_atom.get("atom_count", 0)) - 1,
			max(int(player_atom.get("copy_self_count", 0)), 0),
			max(int(enemy_atom.get("copy_self_count", 0)), 0))
		result.append(atomic_group)
	return result

## 将一方当前牌型队首功法的固定原子转换为可执行 Action。
static func _build_side_atoms(
		side: String,
		side_result: QiActionSideResult,
		battle_state: BattleQiState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if side_result == null or not side_result.is_valid() \
		or side_result.gongfa_slot_instance_ids.is_empty():
		return result
	var current_slot: Dictionary = battle_state.get_current_gongfa_slot(
		side_result.pattern.hand_type_id, side)
	if str(current_slot.get("slot_instance_id", "")) \
		!= side_result.gongfa_slot_instance_ids[0]:
		return result
	var gongfa_data: GongfaData = _get_slot_gongfa_data(side, current_slot)
	if gongfa_data == null or not gongfa_data.is_valid_gongfa():
		return result
	var parent_combatant: BaseCombatant = _get_side_combatant(side)
	var target_combatant: BaseCombatant = _get_side_combatant(_get_opponent_side(side))
	if parent_combatant == null:
		return result
	var source_instance_id: String = str(current_slot.get("slot_instance_id", ""))
	for atom_index: int in gongfa_data.gongfa_atoms.size():
		var atom_definition: Dictionary = gongfa_data.gongfa_atoms[atom_index]
		var priority: int = GongfaAtomScheduler.get_atom_priority(atom_definition)
		if priority == GongfaAtomScheduler.PRIORITY_UNKNOWN:
			return []
		var action_data: Array[Dictionary] = []
		action_data.assign(atom_definition.get("actions", []))
		action_data = _resolve_action_values(action_data, side_result)
		action_data = _inject_action_context(
			action_data,
			side,
			"gongfa",
			source_instance_id,
			str(atom_definition.get("atom_id", "%s:%d" % [gongfa_data.object_id, atom_index])))
		var targets: Array[BaseCombatant] = []
		if target_combatant != null:
			targets.append(target_combatant)
		var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(
			parent_combatant, null, targets, action_data, null)
		result.append({
			"priority": priority,
			"actions": generated_actions,
			"atom_id": str(atom_definition.get("atom_id", "")),
			"side": side,
			"atom_index": atom_index,
			"atom_count": gongfa_data.gongfa_atoms.size(),
			"copy_self_count": max(int(atom_definition.get("copy_self_count", 0)), 0),
		})
	return result

## 对动作数据递归解析安全公式，并注入真气阵营和可追踪来源。
static func _resolve_action_values(
		actions_data: Array[Dictionary],
		side_result: QiActionSideResult) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action_data: Dictionary in actions_data:
		result.append(_resolve_variant(action_data, side_result))
	return result

## 递归复制固定配置并只解析白名单数值公式。
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
	if value is String and str(value).contains("$"):
		return _evaluate_safe_formula(str(value), side_result)
	return value

## 解析变量、单个四则运算和 floor/ceil 包装，不执行任意表达式。
static func _evaluate_safe_formula(expression: String, side_result: QiActionSideResult) -> Variant:
	var trimmed: String = expression.strip_edges()
	var rounding_mode: String = ""
	if trimmed.begins_with("floor(") and trimmed.ends_with(")"):
		rounding_mode = "floor"
		trimmed = trimmed.substr(6, trimmed.length() - 7).strip_edges()
	elif trimmed.begins_with("ceil(") and trimmed.ends_with(")"):
		rounding_mode = "ceil"
		trimmed = trimmed.substr(5, trimmed.length() - 6).strip_edges()
	var expression_regex: RegEx = RegEx.new()
	expression_regex.compile("^\\$([A-Za-z0-9_]+)(?:\\s*([+\\-*/])\\s*(-?[0-9]+(?:\\.[0-9]+)?))?$")
	var matched: RegExMatch = expression_regex.search(trimmed)
	if matched == null:
		return expression
	var current_value: float = float(_get_formula_variable(matched.get_string(1), side_result))
	var operation: String = matched.get_string(2)
	if operation != "":
		var operand: float = float(matched.get_string(3))
		match operation:
			"+":
				current_value += operand
			"-":
				current_value -= operand
			"*":
				current_value *= operand
			"/":
				if operand == 0.0:
					return expression
				current_value /= operand
	if rounding_mode == "floor":
		return int(floor(current_value))
	if rounding_mode == "ceil":
		return int(ceil(current_value))
	return current_value

## 校验功法原子中的所有公式只使用白名单变量和单个安全四则运算。
static func validate_atom_formulas(atom_definitions: Array) -> bool:
	for atom_value: Variant in atom_definitions:
		if not atom_value is Dictionary:
			return false
		var atom: Dictionary = atom_value
		if not _validate_formula_variant(atom.get("actions", [])):
			return false
	return true

## 递归校验固定配置中的公式字符串，不执行表达式。
static func _validate_formula_variant(value: Variant) -> bool:
	if value is Dictionary:
		for nested_value: Variant in value.values():
			if not _validate_formula_variant(nested_value):
				return false
		return true
	if value is Array:
		for nested_value: Variant in value:
			if not _validate_formula_variant(nested_value):
				return false
		return true
	if not value is String or not str(value).contains("$"):
		return true
	var trimmed: String = str(value).strip_edges()
	if (trimmed.begins_with("floor(") or trimmed.begins_with("ceil(")) \
		and trimmed.ends_with(")"):
		trimmed = trimmed.substr(
			6 if trimmed.begins_with("floor(") else 5,
			trimmed.length() - (7 if trimmed.begins_with("floor(") else 6)).strip_edges()
	var expression_regex: RegEx = RegEx.new()
	expression_regex.compile(
		"^\\$([A-Za-z0-9_]+)(?:\\s*([+\\-*/])\\s*(-?[0-9]+(?:\\.[0-9]+)?))?$")
	var matched: RegExMatch = expression_regex.search(trimmed)
	if matched == null or not FORMULA_VARIABLES.has(matched.get_string(1)):
		return false
	return matched.get_string(2) != "/" or float(matched.get_string(3)) != 0.0

## 返回安全公式允许访问的冻结数值。
static func _get_formula_variable(variable_name: String, side_result: QiActionSideResult) -> float:
	match variable_name:
		"base_qi_value_sum", "final_qi_value_sum", "qi_value_sum":
			return side_result.final_qi_value_sum
		"base_multiplier":
			return side_result.base_multiplier
		"final_multiplier":
			return side_result.final_multiplier
		"base_power", "initial_power":
			return side_result.base_power
		"effective_power", "final_power", "power":
			return side_result.effective_power
	return 0.0

## 为伤害、防御和真气牌区行为注入来源与精确阵营。
static func _inject_action_context(
		actions_data: Array[Dictionary],
		source_side: String,
		source_kind: String,
		source_instance_id: String,
		source_effect_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for action_data: Dictionary in actions_data:
		var copied_action: Dictionary = {}
		for action_path_value: Variant in action_data.keys():
			var action_path: String = str(action_path_value)
			var values: Dictionary = action_data[action_path].duplicate(true) \
				if action_data[action_path] is Dictionary else {}
			if action_path == Scripts.ACTION_DRAW_QI or action_path == Scripts.ACTION_DISCARD_QI:
				var target_side: String = str(values.get("target_side", "self"))
				values["qi_side"] = _get_opponent_side(source_side) \
					if target_side == "opponent" else source_side
			if _is_source_tracked_action_path(action_path):
				values["source_side"] = source_side
				values["source_kind"] = source_kind
				values["source_instance_id"] = source_instance_id
				values["source_effect_id"] = source_effect_id
			copied_action[action_path] = values
		result.append(copied_action)
	return result

## 返回指定槽位的玩家实例或敌方固定功法。
static func _get_slot_gongfa_data(side: String, current_slot: Dictionary) -> GongfaData:
	if side == BattleQiState.SIDE_PLAYER and Global.player_data != null:
		return Global.player_data.get_owned_gongfa(
			str(current_slot.get("gongfa_instance_uid", "")))
	return Global.get_gongfa_data(str(current_slot.get("gongfa_definition_id", "")))

## 返回指定阵营当前唯一战斗对象。
static func _get_side_combatant(side: String) -> BaseCombatant:
	if side == BattleQiState.SIDE_PLAYER:
		return Global.get_player()
	if side == BattleQiState.SIDE_ENEMY:
		var enemies: Array[Enemy] = Global.get_alive_enemies()
		return enemies[0] if not enemies.is_empty() else null
	return null

## 返回相对阵营。
static func _get_opponent_side(side: String) -> String:
	return BattleQiState.SIDE_ENEMY \
		if side == BattleQiState.SIDE_PLAYER else BattleQiState.SIDE_PLAYER

## 判断动作路径是否需要来源上下文。
static func _is_source_tracked_action_path(action_path: String) -> bool:
	return [
		Scripts.ACTION_ATTACK,
		Scripts.ACTION_ATTACK_GENERATOR,
		Scripts.ACTION_DIRECT_DAMAGE,
		Scripts.ACTION_BLOCK,
		Scripts.ACTION_ADD_GUARD,
		Scripts.ACTION_ADD_REFLECT,
		Scripts.ACTION_ADD_RESOLUTION,
		Scripts.ACTION_ADD_SHIELD_PENETRATION,
	].has(action_path)

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
