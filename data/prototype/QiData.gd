## 一张真气。
##
## 真气分三层，从内到外：
##   基础层（基础属性、基础内力）—— 永不改变，是真气的身份来源
##   重塑层（QiReshape 列表）    —— 跨探索永久保留，局外用资源改造
##   状态层（QiStateEntry 列表） —— 按各自生命周期范围清理，净化会全部清除
##
## 本类只提供数据与纯查询方法。所有状态改变都由动作（Action）施加，
## 因此这里没有 purify、readValue 之类会产生副作用的方法。
##
## 两个内力数值的区别：
##   存有的内力 = 基础内力 + 全部内力重塑        —— 面板显示、毒发门槛
##   提供的内力 = 存有的内力 + 气力，或冻结时为 1 —— 功法实际读取的值
extends PrototypeData
class_name QiData

## ============================================================
## 身份
## ============================================================

## 真气的显示名称，例如「金 7」。
@export var qi_name: String = ""

## 真气的说明文本。
@export_multiline var qi_description: String = ""

## 真气的显示图片路径。
@export var qi_texture_path: String = ""

## 所属阵营；取值见 QiEnums.SIDES。可变，因为后续会有夺取真气的效果。
@export var qi_side: int = QiEnums.SIDES.PLAYER

## 是否为战斗中生成的临时真气；战斗结束时删除，不写入探索牌库。
## 临时真气没有重塑槽，也不参与局外改造。
@export var qi_is_temporary: bool = false


## ============================================================
## 基础层：永不改变
## ============================================================

## 基础属性；取值见 QiEnums.ELEMENTS。
@export var qi_base_element: int = QiEnums.ELEMENTS.METAL

## 基础内力；起始牌库的合法范围为 5～9。
@export_range(1, 99, 1) var qi_base_value: int = QiEnums.BASE_VALUE_MIN


## ============================================================
## 重塑层：跨探索永久保留
## ============================================================

## 本张真气已挂载的持久重塑。
@export var qi_reshapes: Array[QiReshape] = []

## 本张真气的重塑槽容量；起始为 1，可用局外资源单张扩容，硬上限见 QiEnums.RESHAPE_SLOT_MAX。
@export var qi_reshape_slot_capacity: int = 1


## ============================================================
## 状态层
## ============================================================

## 全部状态记录，写入存档。
##
## 只追加不修改：施加追加一条，减少也追加一条负数记录，因此每条的来源都保留。
## 战斗结束时气力与毒量会被压缩成一条历史记录，避免存档随战斗场数膨胀。
@export var qi_states: Array[QiStateEntry] = []

## 当前所在牌区；取值见 QiEnums.ZONES。
@export var qi_zone: int = QiEnums.ZONES.DRAW

## 归属功法的实例 UID；进入驭气时写入，进入散气时清空。
@export var qi_owning_gongfa_uid: String = ""


## ============================================================
## 效果钩子：特殊真气自带的效果配置
## ============================================================

## 真气作为效果来源参与统一数值查询的固定配置；查询期间不会消耗状态或生成行为。
@export var qi_value_effects: Array[Dictionary] = []

## 真气监听战斗事件时使用的固定效果配置。
@export var qi_battle_event_effects: Array[Dictionary] = []


## ============================================================
## 构造
## ============================================================

## 按属性与基础内力创建一张真气；名称自动生成。
static func create(element: int, base_value: int, side: int = QiEnums.SIDES.PLAYER) -> QiData:
	var qi := QiData.new()
	qi.qi_base_element = element
	qi.qi_base_value = base_value
	qi.qi_side = side
	qi.qi_name = "%s %d" % [QiEnums.get_element_name(element), base_value]
	qi.object_id = "qi_%s_%d" % [QiEnums.get_element_id(element), base_value]
	return qi


## ============================================================
## 查询：纯函数，无副作用，不触发毒发
## ============================================================

## 当前属性 = 属性覆盖 → 属性替换重塑 → 基础属性。
## 覆盖与重塑各自取应用顺序最大的一条。
func peek_element() -> int:
	var override := get_element_override()
	if override >= 0:
		return override

	var reshape := _find_last_element_replace()
	if reshape != null:
		return reshape.target_element

	return qi_base_element

## 存有的内力 = 基础内力 + 全部内力重塑，下限 0。
## 用于面板显示、毒发门槛判断，以及气力的取值边界。
func peek_stored_value() -> int:
	var value := qi_base_value
	for reshape: QiReshape in qi_reshapes:
		if reshape.reshape_kind == QiReshape.KINDS.VALUE_ADJUST:
			value += reshape.value_delta
	return max(value, 0)

## 提供的内力 = 存有的内力 + 气力；冻结生效时固定为 1。
## 用于先手内力比较、输入资格判断，以及功法实际读取的值。
##
## 气力在此处才做上下限约束，而不在施加时约束 —— 保留原始数值，
## 因此之后若存有的内力提高，先前超限的气力会自动生效更多。
func peek_provided_value() -> int:
	if has_state(QiStateEntry.KINDS.FROZEN):
		return 1

	var stored := peek_stored_value()
	var momentum := get_state_amount(QiStateEntry.KINDS.MOMENTUM)
	momentum = clampi(momentum, -stored, stored * 2)
	return max(stored + momentum, 0)

## ============================================================
## 状态查询：结果查询
## ============================================================

## 是否携带指定种类的状态。
## 毒量与气力按总量判断 —— 追加负数记录抵消后总量为 0 时视为不携带。
func has_state(kind: int) -> bool:
	if kind == QiStateEntry.KINDS.POISON or kind == QiStateEntry.KINDS.MOMENTUM:
		return get_state_amount(kind) != 0
	for entry: QiStateEntry in qi_states:
		if entry.state_kind == kind:
			return true
	return false

## 返回指定种类状态的总量；同种记录求和。
## 毒量截下限 0（毒发追加负数记录后可能为负）；气力可正可负。
func get_state_amount(kind: int) -> int:
	var total := 0
	for entry: QiStateEntry in qi_states:
		if entry.state_kind == kind:
			total += entry.amount
	if kind == QiStateEntry.KINDS.POISON:
		return max(total, 0)
	return total

## 返回属性覆盖的目标属性；取应用顺序最大的一条。无覆盖时返回 -1。
func get_element_override() -> int:
	var best: QiStateEntry = null
	for entry: QiStateEntry in qi_states:
		if entry.state_kind != QiStateEntry.KINDS.ELEMENT_OVERRIDE:
			continue
		if best == null or entry.applied_order >= best.applied_order:
			best = entry
	return best.element if best != null else -1

## 返回该真气携带的全部状态种类，同种只出现一次；供状态处理器遍历。
func get_state_kinds() -> Array[int]:
	var kinds: Array[int] = []
	for entry: QiStateEntry in qi_states:
		if not kinds.has(entry.state_kind):
			kinds.append(entry.state_kind)
	return kinds


## ============================================================
## 状态查询：明细查询
##
## 只在需要展示来源时使用，例如悬浮提示与战斗日志。
## 常规显示与功法读取都用上面的结果查询。
## ============================================================

## 返回指定种类状态的全部记录，按应用顺序升序。
func get_state_entries(kind: int) -> Array[QiStateEntry]:
	var result: Array[QiStateEntry] = []
	for entry: QiStateEntry in qi_states:
		if entry.state_kind == kind:
			result.append(entry)
	result.sort_custom(func(a: QiStateEntry, b: QiStateEntry) -> bool:
		return a.applied_order < b.applied_order)
	return result

## 当前毒量是否大于 0。
func is_poisoned() -> bool:
	return get_state_amount(QiStateEntry.KINDS.POISON) > 0

## 运转进入散气时是否应触发毒发；门槛使用存有的内力，不是提供的内力。
func should_burst_on_discard() -> bool:
	var poison := get_state_amount(QiStateEntry.KINDS.POISON)
	return poison > 0 and poison >= peek_stored_value()

## 是否携带指定标记。
func has_mark(mark_id: String) -> bool:
	for reshape: QiReshape in qi_reshapes:
		if reshape.reshape_kind == QiReshape.KINDS.MARK and reshape.mark_id == mark_id:
			return true
	return false


## ============================================================
## 离场去向
## ============================================================

## 本应进入散气时的实际去向；只计算，不移动真气。
##
## 保留、耗散、归根三种状态都改变去向，同时存在时按固定优先级取一个：
##   保留（留在行气）> 耗散（从牌库移除）> 归根（洗回凝气）
##
## 返回 -1 表示从牌库移除，此时由战斗容器记入本场被移除的真气列表。
func resolve_discard_target() -> int:
	if has_state(QiStateEntry.KINDS.RETAINED):
		return QiEnums.ZONES.HAND
	if has_state(QiStateEntry.KINDS.CONSUMING):
		return -1
	if has_state(QiStateEntry.KINDS.RETURNING):
		return QiEnums.ZONES.DRAW
	return QiEnums.ZONES.DISCARD

## 是否因封脉而无法运转。
func is_sealed() -> bool:
	return has_state(QiStateEntry.KINDS.SEALED)


## ============================================================
## 重塑操作：发生在局外，无需事件与拦截
## ============================================================

## 实际可用的重塑槽数量；受本张真气的容量与全局硬上限共同约束。
func get_effective_slot_capacity() -> int:
	return min(qi_reshape_slot_capacity, QiEnums.RESHAPE_SLOT_MAX)

## 是否还有空余重塑槽。
func can_add_reshape() -> bool:
	return qi_reshapes.size() < get_effective_slot_capacity()

## 追加一个重塑；槽位已满或重塑不合法时返回 false。
func add_reshape(reshape: QiReshape) -> bool:
	if reshape == null or not reshape.is_valid():
		return false
	if not can_add_reshape():
		return false
	reshape.applied_order = _next_reshape_order()
	qi_reshapes.append(reshape)
	return true

## 移除指定下标的重塑并腾出槽位；被移除的重塑不返还。
func remove_reshape(index: int) -> bool:
	if index < 0 or index >= qi_reshapes.size():
		return false
	qi_reshapes.remove_at(index)
	return true

## 扩充本张真气的重塑槽容量；已达硬上限时返回 false。
func expand_reshape_slot() -> bool:
	if qi_reshape_slot_capacity >= QiEnums.RESHAPE_SLOT_MAX:
		return false
	qi_reshape_slot_capacity += 1
	return true


## ============================================================
## 状态变更
## ============================================================

## 追加一条状态记录。
##
## 标记类状态**不叠加** —— 已存在时忽略本次施加，
## 因为同一张真气获得两次保留只生效一次。
func add_state(incoming: QiStateEntry) -> bool:
	if incoming == null or not incoming.is_valid():
		return false
	if QiStateEntry.is_flag_kind(incoming.state_kind) and has_state(incoming.state_kind):
		return false

	incoming.applied_order = _next_state_order()
	qi_states.append(incoming)
	return true

## 移除指定种类状态的全部记录。
func remove_state(kind: int) -> int:
	var kept: Array[QiStateEntry] = []
	var removed := 0
	for entry: QiStateEntry in qi_states:
		if entry.state_kind == kind:
			removed += 1
		else:
			kept.append(entry)
	qi_states = kept
	return removed

## 移除指定种类状态中来源匹配的记录。
func remove_state_by_source(kind: int, source_uid: String) -> int:
	var kept: Array[QiStateEntry] = []
	var removed := 0
	for entry: QiStateEntry in qi_states:
		if entry.state_kind == kind and entry.source_uid == source_uid:
			removed += 1
		else:
			kept.append(entry)
	qi_states = kept
	return removed

## 净化：清除本场战斗产生的全部状态，不区分正负。
##
## 归档记录代表「进入本场战斗时的状态」，因此保留 ——
## 净化后真气恰好还原到本场开局的形态。
## 净化**不清除持久重塑**，那属于构筑而非战斗状态。
func purify() -> void:
	var kept: Array[QiStateEntry] = []
	for entry: QiStateEntry in qi_states:
		if entry.is_history():
			kept.append(entry)
	qi_states = kept

## 战斗结束的状态归档。
##
## 气力与毒量压缩成一条历史记录 —— 一场战斗可能产生十几条记录，
## 不压缩会让存档随战斗场数膨胀。
## 其余状态由各自的处理器在战斗结束时移除，此处不处理。
##
## 例：毒+1(功法A)、毒+3(功法B)、毒-4(毒发)、毒+5(功法C) → 毒+5(历史)
func archive_states() -> void:
	for kind: int in get_state_kinds():
		if not QiStateEntry.needs_archive(kind):
			continue
		var total := get_state_amount(kind)
		remove_state(kind)
		if total != 0:
			qi_states.append(QiStateEntry.history(kind, total))

	qi_zone = QiEnums.ZONES.DRAW
	qi_owning_gongfa_uid = ""


## ============================================================
## 校验与展示
## ============================================================

## 校验本张真气的字段是否合法。
func is_valid_qi() -> bool:
	if not QiEnums.is_valid_element(qi_base_element):
		return false
	if qi_base_value <= 0:
		return false
	if qi_reshape_slot_capacity < 0:
		return false
	if qi_reshapes.size() > get_effective_slot_capacity():
		return false
	return true

## 返回用于界面展示的当前形态，例如「火 9」。
func get_display_text() -> String:
	return "%s %d" % [QiEnums.get_element_name(peek_element()), peek_provided_value()]


## ============================================================
## 内部工具
## ============================================================

## 返回应用顺序最大的属性替换重塑；没有时返回 null。
func _find_last_element_replace() -> QiReshape:
	var result: QiReshape = null
	for reshape: QiReshape in qi_reshapes:
		if reshape.reshape_kind != QiReshape.KINDS.ELEMENT_REPLACE:
			continue
		if result == null or reshape.applied_order >= result.applied_order:
			result = reshape
	return result

## 返回下一个可用的重塑应用顺序值。
func _next_reshape_order() -> int:
	var maximum := -1
	for reshape: QiReshape in qi_reshapes:
		maximum = max(maximum, reshape.applied_order)
	return maximum + 1

## 返回下一个可用的状态应用顺序值；属性覆盖依赖它取最后一条。
func _next_state_order() -> int:
	var maximum := -1
	for entry: QiStateEntry in qi_states:
		maximum = max(maximum, entry.applied_order)
	return maximum + 1


## ============================================================
## 起始牌库
## ============================================================

## 生成起始牌库：五行 × 内力 5～9 各一张，共 25 张，全部为纯基础真气。
##
## 这是一个中性起点 —— 每属性 5 张、每内力值 5 张，既不偏向属性线也不偏向内力线，
## 因此第一次改造的方向完全由玩家决定。实际调用方是存档创建流程。
static func create_starting_deck(side: int = QiEnums.SIDES.PLAYER) -> Array[QiData]:
	var deck: Array[QiData] = []
	for element: int in range(QiEnums.ELEMENT_COUNT):
		for value: int in range(QiEnums.BASE_VALUE_MIN, QiEnums.BASE_VALUE_MAX + 1):
			var qi := QiData.create(element, value, side)
			qi.object_uid = PrototypeData.generate_unique_id(qi)
			deck.append(qi)
	return deck



