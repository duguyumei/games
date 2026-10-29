## 一张可持久化的真气扑克牌；固定定义和本局实例共用此格式。
extends PrototypeData
class_name QiData

## 真气支持的四种武侠属性，同时映射为扑克牌花色。
enum QI_ATTRIBUTES {WIND, FOREST, FIRE, MOUNTAIN}

## 属性枚举对应的稳定内容 ID。
const ATTRIBUTE_IDS: Array[String] = ["wind", "forest", "fire", "mountain"]

## 属性枚举对应的扑克牌花色名称。
const ATTRIBUTE_SUIT_NAMES: Array[String] = ["黑桃", "梅花", "红桃", "方块"]

## 属性枚举对应的扑克牌花色稳定 ID。
const ATTRIBUTE_SUIT_IDS: Array[String] = ["spades", "clubs", "hearts", "diamonds"]

## 标准扑克牌的 13 个牌阶稳定 ID；本阶段不包含大小王。
const STANDARD_RANK_IDS: Array[String] = [
	"a", "2", "3", "4", "5", "6", "7", "8", "9", "10", "j", "q", "k"
]

## 标准扑克牌的四种属性顺序；顺序必须与属性枚举和花色映射保持一致。
const STANDARD_ATTRIBUTES: Array[int] = [
	QI_ATTRIBUTES.WIND,
	QI_ATTRIBUTES.FOREST,
	QI_ATTRIBUTES.FIRE,
	QI_ATTRIBUTES.MOUNTAIN,
]

## 真气的显示名称。
@export var qi_name: String = ""

## 真气的说明文本。
@export_multiline var qi_description: String = ""

## 真气的显示图片路径。
@export var qi_texture_path: String = ""

## 真气属性；依次对应风、林、火、山。
@export var qi_attribute: int = QI_ATTRIBUTES.WIND

## 真气牌阶；1 表示 A，11 至 13 表示 J、Q、K。
@export_range(1, 13, 1) var qi_rank: int = 1

## 本局实例当前使用的真气值；固定定义使用 -1，实例化时初始化为牌阶对应值。
@export var qi_value: int = -1

## 本局永久增加或减少的真气值；固定定义中应保持为 0。
@export var qi_permanent_value_modifier: int = 0

## 本局本源是否已经完成；固定模板保持为 false。
@export var qi_origin_locked: bool = false

## 旧版本兼容的本局改造字典；新代码不再写入，读取时只作为迁移来源。
@export var qi_permanent_state: Dictionary[String, Variant] = {}

## 本局持久化的真气重塑；战斗临时重塑存放在 BattleQiState。
@export var qi_reshape_states: Array[QiReshapeState] = []

## 允许跨战斗存在的特殊异状；普通战斗异状存放在 BattleQiState。
@export var qi_persistent_anomaly_states: Array[QiAnomalyState] = []

## 真气作为效果来源参与统一数值查询的固定配置；查询期间不会消耗状态或生成行为。
@export var qi_value_effects: Array[Dictionary] = []

## 真气监听战斗事件时使用的固定效果配置；正式事件确认后才会生成行为。
@export var qi_battle_event_effects: Array[Dictionary] = []

## 返回标准扑克牌牌阶对应的稳定 ID。
static func get_standard_rank_id(rank: int) -> String:
	if rank < 1 or rank > STANDARD_RANK_IDS.size():
		return ""
	return STANDARD_RANK_IDS[rank - 1]

## 返回标准扑克牌真气的固定内容 ID。
static func get_standard_qi_object_id(attribute: int, rank: int) -> String:
	if attribute < 0 or attribute >= ATTRIBUTE_IDS.size():
		return ""
	var rank_id: String = get_standard_rank_id(rank)
	if rank_id == "":
		return ""
	return "qi_%s_%s" % [ATTRIBUTE_IDS[attribute], rank_id]

## 返回完整 52 张标准扑克牌的固定内容 ID，不创建可修改实例。
static func get_standard_deck_object_ids() -> Array[String]:
	var object_ids: Array[String] = []
	for attribute: int in STANDARD_ATTRIBUTES:
		for rank: int in range(1, STANDARD_RANK_IDS.size() + 1):
			object_ids.append(get_standard_qi_object_id(attribute, rank))
	return object_ids

## 从固定真气定义创建本局实例，并初始化该实例的使用值。
func get_prototype(duplicate_sub_prototypes: bool = true) -> QiData:
	var prototype: QiData = super.get_prototype(duplicate_sub_prototypes) as QiData
	prototype.initialize_instance_value()
	return prototype

## 返回真气属性的稳定内容 ID。
func get_attribute_id() -> String:
	if qi_attribute < 0 or qi_attribute >= ATTRIBUTE_IDS.size():
		return ""
	return ATTRIBUTE_IDS[qi_attribute]

## 返回固定真气定义中的原始属性 ID；本局和战斗重塑不会改写此值。
func get_original_attribute_id() -> String:
	return get_attribute_id()

## 返回本局本源重塑后的基础属性；没有本源时返回固定属性。
func get_base_attribute_id() -> String:
	return QiStateResolver.get_base_attribute_id(self)

## 返回真气属性映射后的扑克牌花色名称。
func get_suit_name() -> String:
	var attribute_id: String = get_effective_attribute_id()
	var attribute_index: int = ATTRIBUTE_IDS.find(attribute_id)
	if attribute_index < 0 or attribute_index >= ATTRIBUTE_SUIT_NAMES.size():
		return ""
	return ATTRIBUTE_SUIT_NAMES[attribute_index]

## 返回当前有效属性对应的扑克牌花色稳定 ID。
func get_suit_id(battle_state: BattleQiState = null) -> String:
	var attribute_id: String = get_effective_attribute_id(battle_state)
	var attribute_index: int = ATTRIBUTE_IDS.find(attribute_id)
	if attribute_index < 0 or attribute_index >= ATTRIBUTE_SUIT_IDS.size():
		return ""
	return ATTRIBUTE_SUIT_IDS[attribute_index]

## 返回适合界面展示的牌阶文本。
func get_rank_name() -> String:
	return get_rank_name_for_rank(get_effective_rank())

## 按指定牌阶返回展示文本，供战斗临时牌阶查询使用。
static func get_rank_name_for_rank(rank: int) -> String:
	match rank:
		1:
			return "A"
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
	return str(rank)

## 返回本局重塑和战斗临时重塑共同决定的有效属性 ID。
func get_effective_attribute_id(battle_state: BattleQiState = null) -> String:
	return QiStateResolver.get_effective_attribute_id(self, battle_state)

## 返回当前有效的全部属性身份；混元和临时属性可能产生多个身份。
func get_effective_attribute_ids(battle_state: BattleQiState = null) -> Array[String]:
	return QiStateResolver.get_effective_attribute_ids(self, battle_state)

## 返回本局重塑和战斗临时重塑共同决定的有效牌阶。
func get_effective_rank(battle_state: BattleQiState = null) -> int:
	return QiStateResolver.get_effective_rank(self, battle_state)

## 返回本源重塑后的基础牌阶，不读取战斗临时牌阶。
func get_base_rank() -> int:
	return QiStateResolver.get_base_rank(self)

## 返回固定真气定义中的原始牌阶；本局重塑不会改写此值。
func get_original_rank() -> int:
	return qi_rank

## 返回当前有效牌阶对应的展示文本。
func get_effective_rank_name(battle_state: BattleQiState = null) -> String:
	return get_rank_name_for_rank(get_effective_rank(battle_state))

## 按有效牌阶返回基础真气值：A 为 12，J、Q、K 为 11，其余等于牌阶。
func get_base_qi_value(battle_state: BattleQiState = null) -> int:
	return QiStateResolver.get_base_qi_value(self, battle_state)

## 根据固定定义中的原始牌阶返回原始基础真气值。
func get_original_base_qi_value() -> int:
	if qi_rank == 1:
		return 12
	if qi_rank >= 11 and qi_rank <= 13:
		return 11
	return qi_rank

## 返回包含本局重塑和旧兼容修正的真气值；战斗异状动态修正由战斗计算器继续处理。
func get_qi_value(battle_state: BattleQiState = null) -> int:
	return QiStateResolver.get_effective_qi_value(self, battle_state)

## 返回参与功法数值计算时的真气贡献值；查询不会修改真气或触发行为。
func get_contribution_qi_value(
		battle_state: BattleQiState = null,
		context: Dictionary = {}) -> int:
	return QiStateResolver.get_contribution_qi_value(self, battle_state, context)

## 返回永久强化提供的功法倍率修正；机缘判定由战斗结算阶段处理。
func get_gongfa_multiplier_modifier() -> int:
	return QiStateResolver.get_gongfa_multiplier_modifier(self)

## 创建本局真气实例时初始化使用值；固定定义仍保持 -1，不会被写回。
func initialize_instance_value() -> void:
	if object_uid != "" and qi_value < 0:
		qi_value = get_original_base_qi_value()

## 返回本局某个重塑槽的状态；不返回战斗临时重塑。
func get_reshape_state(reshape_slot: String) -> QiReshapeState:
	var latest_state: QiReshapeState = null
	for state: QiReshapeState in qi_reshape_states:
		if state.reshape_slot != reshape_slot:
			continue
		if latest_state == null or state.applied_order > latest_state.applied_order:
			latest_state = state
	return latest_state

## 返回本局指定异状的状态；没有该异状时返回 null。
func get_persistent_anomaly_state(anomaly_definition_id: String) -> QiAnomalyState:
	for state: QiAnomalyState in qi_persistent_anomaly_states:
		if state.definition_id == anomaly_definition_id:
			return state
	return null

## 应用一项本局重塑；固定定义只读，实例只保存变化后的结果值。
func apply_run_reshape(
		reshape_definition: QiReshapeData,
		result_values: Dictionary[String, Variant]) -> bool:
	if object_uid == "" \
		or reshape_definition == null \
		or not reshape_definition.is_valid_definition() \
		or not reshape_definition.allows_scope(QiReshapeData.SCOPE_RUN) \
		or not JsonStateValidator.is_json_compatible(result_values):
		return false
	var normalized_result: Dictionary[String, Variant] = build_reshape_result(
		reshape_definition, result_values)
	if normalized_result.is_empty() \
		and reshape_definition.reshape_kind == QiReshapeData.KIND_ORIGIN:
		return false
	result_values = normalized_result
	if reshape_definition.reshape_kind == QiReshapeData.KIND_ORIGIN:
		if qi_origin_locked or not _validate_origin_result(reshape_definition, result_values):
			return false
	else:
		if reshape_definition.reshape_slot == QiReshapeData.SLOT_ORIGIN:
			return false
		if reshape_definition.reshape_slot.begins_with("temporary_"):
			return false
	var state: QiReshapeState = QiReshapeState.new()
	state.definition_id = reshape_definition.object_id
	state.state_uid = "%s-reshape-%d" % [object_uid, _get_next_reshape_order()]
	state.reshape_slot = reshape_definition.reshape_slot
	state.origin_operation = reshape_definition.origin_operation
	state.scope = QiReshapeData.SCOPE_RUN
	state.result_values = result_values.duplicate(true)
	state.applied_order = _get_next_reshape_order()
	var kept_states: Array[QiReshapeState] = []
	for existing_state: QiReshapeState in qi_reshape_states:
		if state.reshape_slot != QiReshapeData.SLOT_OTHER \
			and existing_state.reshape_slot == state.reshape_slot:
			continue
		kept_states.append(existing_state)
	kept_states.append(state)
	qi_reshape_states = kept_states
	if reshape_definition.reshape_kind == QiReshapeData.KIND_ORIGIN:
		qi_origin_locked = true
	return true

## 根据固定定义和请求参数构造一项完整重塑结果；只读当前真气。
func build_reshape_result(
		reshape_definition: QiReshapeData,
		requested_values: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	if reshape_definition == null or not reshape_definition.is_valid_definition() \
		or not JsonStateValidator.is_json_compatible(requested_values):
		return {}
	var result: Dictionary[String, Variant] = requested_values.duplicate(true)
	if reshape_definition.reshape_kind != QiReshapeData.KIND_ORIGIN:
		return result
	match reshape_definition.origin_operation:
		QiReshapeData.ORIGIN_ATTRIBUTE:
			if not result.has("attribute_id"):
				return {}
		QiReshapeData.ORIGIN_RANK_SHIFT:
			var direction: String = str(result.get("direction", ""))
			var target_rank: int = _get_rank_shift_target(qi_rank, direction)
			if result.has("rank") and int(result.get("rank", 0)) != target_rank:
				return {}
			if target_rank < 1:
				return {}
			result["rank"] = target_rank
			result["base_qi_value"] = QiStateResolver.get_standard_qi_value(target_rank)
		QiReshapeData.ORIGIN_AWAKEN:
			result["awakening_attribute_id"] = get_attribute_id()
	return result

## 预校验本局重塑；不会创建状态或调用效果。
func can_apply_run_reshape(
		reshape_definition: QiReshapeData,
		result_values: Dictionary[String, Variant]) -> bool:
	if object_uid == "" or reshape_definition == null \
		or not reshape_definition.is_valid_definition() \
		or not reshape_definition.allows_scope(QiReshapeData.SCOPE_RUN) \
		or (reshape_definition.reshape_kind == QiReshapeData.KIND_ORIGIN and qi_origin_locked):
		return false
	var normalized_result: Dictionary[String, Variant] = build_reshape_result(
		reshape_definition, result_values)
	if normalized_result.is_empty() \
		and reshape_definition.reshape_kind == QiReshapeData.KIND_ORIGIN:
		return false
	if reshape_definition.reshape_kind == QiReshapeData.KIND_ORIGIN:
		return _validate_origin_result(reshape_definition, normalized_result)
	return reshape_definition.reshape_slot != QiReshapeData.SLOT_ORIGIN \
		and not reshape_definition.reshape_slot.begins_with("temporary_")

## 校验本源操作的参数和边界，不修改当前真气。
func _validate_origin_result(
		reshape_definition: QiReshapeData,
		result_values: Dictionary[String, Variant]) -> bool:
	match reshape_definition.origin_operation:
		QiReshapeData.ORIGIN_ATTRIBUTE:
			var attribute_id: String = str(result_values.get("attribute_id", ""))
			return ATTRIBUTE_IDS.has(attribute_id) \
				and _matches_required_attribute(reshape_definition)
		QiReshapeData.ORIGIN_RANK_SHIFT:
			var target_rank: int = int(result_values.get("rank", 0))
			var expected_value: int = QiStateResolver.get_standard_qi_value(target_rank)
			return target_rank >= 1 and target_rank <= 13 \
				and target_rank != qi_rank \
				and int(result_values.get("base_qi_value", expected_value)) == expected_value \
				and target_rank == _get_rank_shift_target(
					qi_rank, str(result_values.get("direction", "")))
		QiReshapeData.ORIGIN_AWAKEN:
			var awakening_attribute_id: String = str(
				result_values.get("awakening_attribute_id", get_attribute_id()))
			return ATTRIBUTE_IDS.has(awakening_attribute_id) \
				and awakening_attribute_id == get_attribute_id() \
				and _matches_required_attribute(reshape_definition)
	return false

## 检查固定觉醒定义要求的基础属性。
func _matches_required_attribute(reshape_definition: QiReshapeData) -> bool:
	var required_attribute_id: String = str(
		reshape_definition.effect_config.get("required_attribute_id", ""))
	return required_attribute_id == "" or required_attribute_id == get_attribute_id()

## 根据权威规则计算易阶目标；到达 A 或 2 时返回 -1。
func _get_rank_shift_target(current_rank: int, direction: String) -> int:
	var upward_order: Array[int] = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 1]
	var current_index: int = upward_order.find(current_rank)
	if current_index < 0:
		return -1
	if direction == "up" and current_index < upward_order.size() - 1:
		return upward_order[current_index + 1]
	if direction == "down" and current_index > 0:
		return upward_order[current_index - 1]
	return -1

## 应用一个允许跨战斗存在的异状；普通战斗异状必须使用 BattleQiState。
func apply_run_anomaly(
		anomaly_definition: QiAnomalyData,
		stacks: int = 1,
		secondary_stacks: int = 0) -> bool:
	if object_uid == "" \
		or anomaly_definition == null \
		or not anomaly_definition.is_valid_definition() \
		or not anomaly_definition.allows_scope(QiAnomalyData.SCOPE_RUN) \
		or stacks <= 0:
		return false
	for state: QiAnomalyState in qi_persistent_anomaly_states:
		if state.definition_id != anomaly_definition.object_id:
			continue
		match anomaly_definition.stack_policy:
			QiAnomalyData.STACK_ADD:
				state.stacks += stacks
				state.secondary_stacks += secondary_stacks
			QiAnomalyData.STACK_REPLACE:
				state.stacks = stacks
				state.secondary_stacks = secondary_stacks
			QiAnomalyData.STACK_KEEP:
				pass
		if anomaly_definition.max_stacks > 0:
			state.stacks = min(state.stacks, anomaly_definition.max_stacks)
		return true
	var state: QiAnomalyState = QiAnomalyState.new()
	state.definition_id = anomaly_definition.object_id
	state.scope = QiAnomalyData.SCOPE_RUN
	state.stacks = stacks
	state.secondary_stacks = secondary_stacks
	state.expire_events = anomaly_definition.expire_events.duplicate()
	state.applied_order = _get_next_reshape_order()
	if anomaly_definition.max_stacks > 0:
		state.stacks = min(state.stacks, anomaly_definition.max_stacks)
	qi_persistent_anomaly_states.append(state)
	return true

## 移除本局重塑；战斗临时状态由 BattleQiState 管理。
func remove_run_reshape(reshape_slot: String, state_uid: String = "") -> bool:
	if reshape_slot == QiReshapeData.SLOT_ORIGIN:
		return false
	for state_index: int in range(qi_reshape_states.size() - 1, -1, -1):
		var state: QiReshapeState = qi_reshape_states[state_index]
		if state.reshape_slot != reshape_slot:
			continue
		if state_uid != "" and state.state_uid != state_uid:
			continue
		qi_reshape_states.remove_at(state_index)
		return true
	return false

## 移除一个本局异状。
func remove_run_anomaly(anomaly_definition_id: String) -> bool:
	for state_index: int in range(qi_persistent_anomaly_states.size() - 1, -1, -1):
		if qi_persistent_anomaly_states[state_index].definition_id == anomaly_definition_id:
			qi_persistent_anomaly_states.remove_at(state_index)
			return true
	return false

## 处理一个已提交的本局范围真气事件；普通战斗状态不经过此方法。
func notify_run_qi_event(event_id: String) -> Array[String]:
	if event_id == "":
		return []
	var removed_definition_ids: Array[String] = []
	var global_node: Node = _get_global_node()
	if global_node == null:
		return removed_definition_ids
	for state_index: int in range(qi_persistent_anomaly_states.size() - 1, -1, -1):
		var state: QiAnomalyState = qi_persistent_anomaly_states[state_index]
		var definition: QiAnomalyData = global_node.get_qi_anomaly_data(state.definition_id)
		QiEffectRuntime.invoke_anomaly_event(
			definition, object_uid, state, event_id, {"scope": QiAnomalyData.SCOPE_RUN})
		if not state.expire_events.has(event_id):
			continue
		QiEffectRuntime.invoke_anomaly_remove(
			definition, object_uid, state, {"scope": QiAnomalyData.SCOPE_RUN})
		removed_definition_ids.append(state.definition_id)
		qi_persistent_anomaly_states.remove_at(state_index)
	return removed_definition_ids

## 通过场景树读取 Global，避免固定数据类与 Global 自动加载脚本形成编译循环。
func _get_global_node() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop == null or not main_loop is SceneTree:
		return null
	return (main_loop as SceneTree).root.get_node_or_null("Global")

## 计算下一项重塑或持久异状的稳定顺序。
func _get_next_reshape_order() -> int:
	var max_order: int = 0
	for state: QiReshapeState in qi_reshape_states:
		max_order = max(max_order, state.applied_order)
	for state: QiAnomalyState in qi_persistent_anomaly_states:
		max_order = max(max_order, state.applied_order)
	return max_order + 1

## 归一化旧存档中的真气状态；不执行任何效果。
func normalize_after_load() -> void:
	if qi_reshape_states == null:
		qi_reshape_states = []
	if qi_persistent_anomaly_states == null:
		qi_persistent_anomaly_states = []
	initialize_instance_value()
	for state: QiReshapeState in qi_reshape_states:
		state.reshape_slot = QiReshapeData.normalize_legacy_slot(state.reshape_slot)
		if state.state_uid == "":
			state.state_uid = "%s-reshape-%d" % [object_uid, state.applied_order]
		if state.reshape_slot == QiReshapeData.SLOT_ORIGIN:
			qi_origin_locked = true
	for state_index: int in range(qi_reshape_states.size() - 1, -1, -1):
		if not qi_reshape_states[state_index].is_valid_state():
			qi_reshape_states.remove_at(state_index)
	for state_index: int in range(qi_persistent_anomaly_states.size() - 1, -1, -1):
		if not qi_persistent_anomaly_states[state_index].is_valid_state():
			qi_persistent_anomaly_states.remove_at(state_index)

## 校验固定牌面与本局永久状态是否合法。
func is_valid_qi() -> bool:
	if not (qi_attribute >= 0 \
		and qi_attribute < ATTRIBUTE_IDS.size() \
		and qi_rank >= 1 \
		and qi_rank <= 13 \
		and qi_value >= -1 \
		and JsonStateValidator.is_json_compatible(qi_permanent_state) \
		and QiValuePipeline.validate_value_effects(qi_value_effects)):
		return false
	var seen_state_uids: Dictionary[String, bool] = {}
	var slot_counts: Dictionary[String, int] = {}
	var origin_count: int = 0
	for state: QiReshapeState in qi_reshape_states:
		if state == null or not state.is_valid_state():
			return false
		if seen_state_uids.has(state.state_uid):
			return false
		seen_state_uids[state.state_uid] = true
		if state.scope != QiReshapeData.SCOPE_RUN:
			return false
		if state.reshape_slot == QiReshapeData.SLOT_ORIGIN:
			origin_count += 1
		else:
			slot_counts[state.reshape_slot] = int(slot_counts.get(state.reshape_slot, 0)) + 1
	for slot: String in slot_counts.keys():
		if slot != QiReshapeData.SLOT_OTHER and slot_counts[slot] > 1:
			return false
	if origin_count > 1 \
		or (origin_count == 1 and not qi_origin_locked) \
		or (origin_count == 0 and qi_origin_locked):
		return false
	for state: QiAnomalyState in qi_persistent_anomaly_states:
		if state == null or not state.is_valid_state():
			return false
	return true

## 安全替换本局永久改造状态，非法值不会写入实例。
func set_permanent_state(value: Dictionary[String, Variant]) -> bool:
	if object_uid == "" or not JsonStateValidator.is_json_compatible(value):
		return false
	qi_permanent_state = value.duplicate(true)
	return true
