## 一场战斗中真气的访问入口；管双方四个牌区的查询与变更。
##
## 我方牌区是 RunState 里那些数组的**同一个对象引用**，因此战斗内的移动
## 直接反映到探索层，不需要写回。敌方牌区是本场新建的，战斗结束即丢弃。
##
## 本类只负责「真气在哪个牌区」与「按条件查找」：
##   不负责规则判断 —— 封脉、行气上限、毒发都在动作里；
##   不负责生命周期清理 —— 那是 QiData 自己的方法，由动作或流程调用。
extends SerializableData
class_name BattleQiState

## 真气进入目标牌区时的插入位置。
enum INSERT_POSITIONS {
	TOP,     ## 队首（下标 0）
	BOTTOM,  ## 队尾；默认，抽取与弃置都用这个
	RANDOM,  ## 随机位置；归根洗回凝气用这个
}

## 双方牌区。键为 QiEnums.SIDES，值为「牌区 → 真气数组」。
## 按 qi_side 分派，因此查询方法无需敌我分支。
var _zones: Dictionary[int, Dictionary] = {}

## 双方的移除区。我方指向 RunState.removed_qi，敌方本场新建。
var _removed_qi: Dictionary[int, Array] = {}

## 本场战斗内被移除的真气总数。
## 与 _removed_qi 不同 —— 后者是探索级累计，这个每场重置，
## 供「每 N 张真气被消耗」这类按场生效的效果使用。
var _removed_count_this_battle: int = 0

## 洗牌用的随机数发生器；由 RunState 传入，因此写入存档。
var _rng: RandomNumberGenerator = null


## ============================================================
## 构造
## ============================================================

## 从探索状态与敌方配置建立本场战斗的访问入口。
##
## 我方牌区与移除区直接引用探索层的数组，不做拷贝 —— 牌区跨战斗连续，
## 上一场的消耗会延续到下一场，只有探索中主动重整才重置。
static func create(run_zones: Dictionary, run_removed: Array, rng: RandomNumberGenerator) -> BattleQiState:
	var state := BattleQiState.new()
	state._rng = rng
	state._zones[QiEnums.SIDES.PLAYER] = run_zones
	state._removed_qi[QiEnums.SIDES.PLAYER] = run_removed
	state._zones[QiEnums.SIDES.ENEMY] = _create_empty_zones()
	state._removed_qi[QiEnums.SIDES.ENEMY] = []
	return state


## 建立一组空牌区。
static func _create_empty_zones() -> Dictionary:
	var zones: Dictionary[int, Array] = {}
	for zone: int in range(QiEnums.ZONE_IDS.size()):
		zones[zone] = [] as Array[QiData]
	return zones


## 装填敌方牌库：全部真气进凝气并洗牌。
func load_enemy_deck(deck: Array[QiData]) -> void:
	var draw: Array = _zones[QiEnums.SIDES.ENEMY][QiEnums.ZONES.DRAW]
	draw.clear()
	for qi: QiData in deck:
		qi.qi_side = QiEnums.SIDES.ENEMY
		qi.qi_zone = QiEnums.ZONES.DRAW
		draw.append(qi)
	_shuffle_array(draw)


## ============================================================
## 查询：返回副本，外部无法绕过动作修改牌区
## ============================================================

## 按 UID 查找真气；遍历双方全部牌区。
## 牌区最多几十张，线性查找足够。
func find_qi(qi_uid: String) -> QiData:
	for side: int in _zones:
		for zone: int in _zones[side]:
			for qi: QiData in _zones[side][zone]:
				if qi.object_uid == qi_uid:
					return qi
	return null

## 返回指定阵营指定牌区的真气副本。
func get_zone(side: int, zone: int) -> Array[QiData]:
	var result: Array[QiData] = []
	if not _zones.has(side) or not _zones[side].has(zone):
		return result
	result.assign(_zones[side][zone])
	return result

## 返回指定牌区的真气数量。
func get_zone_size(side: int, zone: int) -> int:
	if not _zones.has(side) or not _zones[side].has(zone):
		return 0
	return (_zones[side][zone] as Array).size()

## 返回牌区队首的真气；凝气顶端即下标 0，抽取从这头取。
func top_of(side: int, zone: int) -> QiData:
	var list: Array = _get_zone_ref(side, zone)
	return list[0] if not list.is_empty() else null

## 返回牌区队尾的真气。
func bottom_of(side: int, zone: int) -> QiData:
	var list: Array = _get_zone_ref(side, zone)
	return list[-1] if not list.is_empty() else null

## 返回牌区顶端的若干张真气；不足时返回全部。
func top_of_count(side: int, zone: int, count: int) -> Array[QiData]:
	var result: Array[QiData] = []
	var list: Array = _get_zone_ref(side, zone)
	for index: int in range(min(count, list.size())):
		result.append(list[index])
	return result

## 返回某门功法的全部驭气；数组顺序即输入顺序。
func inputs_of(gongfa_uid: String) -> Array[QiData]:
	var result: Array[QiData] = []
	for side: int in _zones:
		for qi: QiData in _get_zone_ref(side, QiEnums.ZONES.PENDING):
			if qi.qi_owning_gongfa_uid == gongfa_uid:
				result.append(qi)
	return result

## 按条件筛选牌区中的真气。
## 功法的目标条件千变万化，因此用可调用对象而非为每种条件写一个方法。
func filter(side: int, zone: int, condition: Callable) -> Array[QiData]:
	var result: Array[QiData] = []
	for qi: QiData in _get_zone_ref(side, zone):
		if condition.call(qi):
			result.append(qi)
	return result

## 从牌区随机取若干张真气；一次性抽样，同一张不会重复选中。
##
## 这与「分多次各取 1 张」不同 —— 后者每次都重新面对已经变化的池子，
## 因此功法正文必须明确写的是哪一种。
func pick_random(side: int, zone: int, count: int, condition: Callable = Callable()) -> Array[QiData]:
	var pool: Array[QiData] = []
	for qi: QiData in _get_zone_ref(side, zone):
		if not condition.is_valid() or condition.call(qi):
			pool.append(qi)

	var result: Array[QiData] = []
	for index: int in range(min(count, pool.size())):
		var pick: int = _rng.randi() % pool.size() if _rng != null else 0
		result.append(pool[pick])
		pool.remove_at(pick)
	return result

## 返回牌区中提供的内力最高的真气；并列时取靠前的一张。
func highest_provided_value(side: int, zone: int) -> QiData:
	var best: QiData = null
	for qi: QiData in _get_zone_ref(side, zone):
		if best == null or qi.peek_provided_value() > best.peek_provided_value():
			best = qi
	return best

## 返回牌区中提供的内力最低的真气；并列时取靠前的一张。
func lowest_provided_value(side: int, zone: int) -> QiData:
	var best: QiData = null
	for qi: QiData in _get_zone_ref(side, zone):
		if best == null or qi.peek_provided_value() < best.peek_provided_value():
			best = qi
	return best

## 统计牌区中携带指定状态的真气数量。
func count_by_state(side: int, zone: int, state_kind: int) -> int:
	var total := 0
	for qi: QiData in _get_zone_ref(side, zone):
		if qi.has_state(state_kind):
			total += 1
	return total

## 返回本场战斗被移除的真气总数。
func get_removed_count_this_battle() -> int:
	return _removed_count_this_battle

## 返回指定阵营本次探索被移除的真气副本。
func get_removed_qi(side: int) -> Array[QiData]:
	var result: Array[QiData] = []
	if _removed_qi.has(side):
		result.assign(_removed_qi[side])
	return result


## ============================================================
## 变更：只被动作调用
## ============================================================

## 移动一张真气。
##
## 不做任何规则检查 —— 封脉、行气上限、毒发都在动作里判断，
## 这里只负责搬数组，保持单一职责。
## position 决定它进入目标牌区的位置。
func move_qi(qi: QiData, from_zone: int, to_zone: int, position: int = INSERT_POSITIONS.BOTTOM) -> bool:
	if qi == null:
		return false

	var source: Array = _get_zone_ref(qi.qi_side, from_zone)
	var index := source.find(qi)
	if index < 0:
		return false
	source.remove_at(index)

	qi.qi_zone = to_zone
	_insert_into(_get_zone_ref(qi.qi_side, to_zone), qi, position)
	return true

## 按数组顺序依次移动多张真气。
##
## 一次运转多张与分多次各运转一张的结果不同：前者一次性确定全部目标，
## 后者每次都重新面对已经变化的牌区。因此功法正文必须明确写的是哪一种。
func move_qi_batch(qi_list: Array[QiData], from_zone: int, to_zone: int, position: int = INSERT_POSITIONS.BOTTOM) -> int:
	var moved := 0
	for qi: QiData in qi_list:
		if move_qi(qi, from_zone, to_zone, position):
			moved += 1
	return moved

## 把真气从牌库移除；记入该方移除区并累加本场计数。
##
## 移除区是探索级的 —— 被移除的真气整个探索内都不回来，
## 只有探索中重整时才随实例化恢复。
func remove_qi_from_deck(qi: QiData, from_zone: int) -> bool:
	if qi == null:
		return false

	var source: Array = _get_zone_ref(qi.qi_side, from_zone)
	var index := source.find(qi)
	if index < 0:
		return false
	source.remove_at(index)

	if _removed_qi.has(qi.qi_side):
		(_removed_qi[qi.qi_side] as Array).append(qi)
	_removed_count_this_battle += 1
	return true

## 把散气整体洗回凝气；洗牌后追加到凝气尾部。
## 抽取过程中凝气不足时由抽取流程调用。
func reshuffle_discard_into_draw(side: int) -> int:
	var discard: Array = _get_zone_ref(side, QiEnums.ZONES.DISCARD)
	if discard.is_empty():
		return 0

	var moved: Array[QiData] = []
	moved.assign(discard)
	discard.clear()
	_shuffle_array(moved)

	var draw: Array = _get_zone_ref(side, QiEnums.ZONES.DRAW)
	for qi: QiData in moved:
		qi.qi_zone = QiEnums.ZONES.DRAW
		draw.append(qi)
	return moved.size()


## ============================================================
## 战斗结束
## ============================================================

## 战斗结束的收尾。
##
## 行气与驭气全部进散气 —— 不走 QiData.resolve_discard_target()，
## 因为保留、归根、耗散是**回合结束**的规则，而战斗结束时已无下个回合。
##
## 随后清除各真气的战斗状态并保留探索状态（例如毒量跨战斗延续），
## 删除临时真气，丢弃敌方数据。
func on_battle_end() -> void:
	for side: int in _zones:
		for zone: int in [QiEnums.ZONES.HAND, QiEnums.ZONES.PENDING]:
			var list: Array[QiData] = []
			list.assign(_get_zone_ref(side, zone))
			for qi: QiData in list:
				move_qi(qi, zone, QiEnums.ZONES.DISCARD)

	for side: int in _zones:
		for zone: int in _zones[side]:
			for qi: QiData in _get_zone_ref(side, zone):
				qi.archive_states()

	_remove_temporary_qi()

	_zones.erase(QiEnums.SIDES.ENEMY)
	_removed_qi.erase(QiEnums.SIDES.ENEMY)
	_removed_count_this_battle = 0

## 返回双方全部真气；供状态处理器在回合与战斗时点遍历。
##
## 回合开始的封脉解除、战斗结束的属性覆盖移除都由各状态的处理器负责，
## 因此容器只提供遍历入口，不自己实现清理逻辑。
func get_all_qi() -> Array[QiData]:
	var result: Array[QiData] = []
	for side: int in _zones:
		for zone: int in _zones[side]:
			result.append_array(_get_zone_ref(side, zone))
	return result


## ============================================================
## 内部工具
## ============================================================

## 返回牌区数组的引用；不存在时返回空数组，避免调用方判空。
func _get_zone_ref(side: int, zone: int) -> Array:
	if not _zones.has(side) or not _zones[side].has(zone):
		return []
	return _zones[side][zone]

## 按指定位置把真气插入牌区数组。
func _insert_into(list: Array, qi: QiData, position: int) -> void:
	match position:
		INSERT_POSITIONS.TOP:
			list.insert(0, qi)
		INSERT_POSITIONS.RANDOM:
			var index: int = _rng.randi() % (list.size() + 1) if _rng != null else list.size()
			list.insert(index, qi)
		_:
			list.append(qi)

## 用可存档的随机数发生器洗牌；否则读档后抽牌序列会改变。
func _shuffle_array(list: Array) -> void:
	if _rng == null:
		return
	for index: int in range(list.size() - 1, 0, -1):
		var swap: int = _rng.randi() % (index + 1)
		var temp: Variant = list[index]
		list[index] = list[swap]
		list[swap] = temp

## 删除全部临时真气；战斗结束时调用。
func _remove_temporary_qi() -> void:
	for side: int in _zones:
		for zone: int in _zones[side]:
			var list: Array = _get_zone_ref(side, zone)
			var kept: Array[QiData] = []
			for qi: QiData in list:
				if not qi.qi_is_temporary:
					kept.append(qi)
			list.clear()
			list.assign(kept)


