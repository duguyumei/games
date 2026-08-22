## 真气扑克牌型和同气识别器；所有方法都是纯查询，不移动牌区、不触发行为。
extends RefCounted
class_name QiHandRecognizer

## 按用户规则识别一组真气的精确牌型和参与牌。
static func recognize(
		qi_cards: Array[QiData], battle_state: BattleQiState = null) -> QiHandPatternResult:
	var result: QiHandPatternResult = QiHandPatternResult.new()
	var valid_cards: Array[QiData] = []
	for qi_data: QiData in qi_cards:
		if qi_data != null and qi_data.object_uid != "":
			valid_cards.append(qi_data)
	if valid_cards.is_empty():
		return result
	var rank_groups: Dictionary[int, Array] = _group_cards_by_rank(valid_cards, battle_state)
	var sorted_cards: Array[QiData] = _sort_cards_by_rank(valid_cards, battle_state)

	# 五张结构优先，避免同一组牌被误判成低级牌型。
	var five_kind_cards: Array[QiData] = _find_group_of_size(rank_groups, 5)
	if five_kind_cards.size() == 5:
		return _build_result("five_kind", five_kind_cards, sorted_cards, battle_state)
	var full_house_cards: Array[QiData] = _find_full_house(rank_groups)
	if full_house_cards.size() == 5:
		return _build_result("full_house", full_house_cards, sorted_cards, battle_state)
	var straight_cards: Array[QiData] = _find_straight(sorted_cards, battle_state)
	if straight_cards.size() == 5:
		return _build_result("straight", straight_cards, sorted_cards, battle_state)

	# 四张结构中四条优先于双对。
	var four_kind_cards: Array[QiData] = _find_group_of_size(rank_groups, 4)
	if four_kind_cards.size() == 4:
		return _build_result("four_kind", four_kind_cards, sorted_cards, battle_state)
	var pair_groups: Array = _find_groups_at_least(rank_groups, 2)
	if pair_groups.size() >= 2:
		var two_pair_cards: Array[QiData] = []
		for pair_group: Array in pair_groups.slice(0, 2):
			two_pair_cards.append_array(pair_group)
		return _build_result("two_pair", two_pair_cards, sorted_cards, battle_state)

	var three_kind_cards: Array[QiData] = _find_group_of_size(rank_groups, 3)
	if three_kind_cards.size() == 3:
		return _build_result("three_kind", three_kind_cards, sorted_cards, battle_state)
	if pair_groups.size() == 1:
		return _build_result("pair", pair_groups[0], sorted_cards, battle_state)
	return _build_result("high_card", [sorted_cards[0]], sorted_cards, battle_state)

## 按牌阶分组，牌阶只用于牌型识别，不读取真气值。
static func _group_cards_by_rank(
		qi_cards: Array[QiData], battle_state: BattleQiState) -> Dictionary[int, Array]:
	var groups: Dictionary[int, Array] = {}
	for qi_data: QiData in qi_cards:
		var rank: int = qi_data.get_effective_rank(battle_state)
		if not groups.has(rank):
			groups[rank] = []
		groups[rank].append(qi_data)
	for rank_value: Variant in groups.keys():
		var rank: int = int(rank_value)
		groups[rank].sort_custom(func(left: QiData, right: QiData) -> bool:
			return left.object_uid < right.object_uid)
	return groups

## 按牌阶从大到小、UID 从小到大排序，保证识别结果确定性。
static func _sort_cards_by_rank(
		qi_cards: Array[QiData], battle_state: BattleQiState) -> Array[QiData]:
	var sorted_cards: Array[QiData] = qi_cards.duplicate()
	sorted_cards.sort_custom(func(left: QiData, right: QiData) -> bool:
		var left_rank: int = left.get_effective_rank(battle_state)
		var right_rank: int = right.get_effective_rank(battle_state)
		if left_rank != right_rank:
			return left_rank > right_rank
		return left.object_uid < right.object_uid)
	return sorted_cards

## 找到指定数量的同阶牌；同阶多于目标数量时只取稳定排序的前几张。
static func _find_group_of_size(groups: Dictionary, required_size: int) -> Array[QiData]:
	var candidate_ranks: Array[int] = []
	for rank_value: Variant in groups.keys():
		var rank: int = int(rank_value)
		if groups[rank].size() >= required_size:
			candidate_ranks.append(rank)
	candidate_ranks.sort()
	if candidate_ranks.is_empty():
		return []
	var group: Array = groups[candidate_ranks.back()]
	var result: Array[QiData] = []
	for qi_data: QiData in group.slice(0, required_size):
		result.append(qi_data)
	return result

## 找到三条和对子组成的葫芦。
static func _find_full_house(groups: Dictionary) -> Array[QiData]:
	var triple_ranks: Array[int] = []
	var pair_ranks: Array[int] = []
	for rank_value: Variant in groups.keys():
		var rank: int = int(rank_value)
		if groups[rank].size() >= 3:
			triple_ranks.append(rank)
		if groups[rank].size() >= 2:
			pair_ranks.append(rank)
	triple_ranks.sort()
	pair_ranks.sort()
	if triple_ranks.is_empty():
		return []
	for triple_rank: int in triple_ranks:
		for pair_rank: int in pair_ranks:
			if pair_rank == triple_rank:
				continue
			var result: Array[QiData] = []
			result.append_array(groups[triple_rank].slice(0, 3))
			result.append_array(groups[pair_rank].slice(0, 2))
			return result
	return []

## 返回至少达到指定数量的牌组，按牌阶从高到低排列。
static func _find_groups_at_least(groups: Dictionary, required_size: int) -> Array:
	var ranks: Array[int] = []
	for rank_value: Variant in groups.keys():
		var rank: int = int(rank_value)
		if groups[rank].size() >= required_size:
			ranks.append(rank)
	ranks.sort()
	ranks.reverse()
	var result: Array = []
	for rank: int in ranks:
		result.append(groups[rank].slice(0, required_size))
	return result

## 识别五张连续牌，支持 A2345 和 10JQKA 两种 A 用法。
static func _find_straight(
		sorted_cards: Array[QiData], battle_state: BattleQiState) -> Array[QiData]:
	if sorted_cards.size() < 5:
		return []
	var by_rank: Dictionary[int, QiData] = {}
	for qi_data: QiData in sorted_cards:
		var rank: int = qi_data.get_effective_rank(battle_state)
		if not by_rank.has(rank):
			by_rank[rank] = qi_data
	var rank_windows: Array[Array] = [
		[1, 2, 3, 4, 5],
		[2, 3, 4, 5, 6],
		[3, 4, 5, 6, 7],
		[4, 5, 6, 7, 8],
		[5, 6, 7, 8, 9],
		[6, 7, 8, 9, 10],
		[7, 8, 9, 10, 11],
		[8, 9, 10, 11, 12],
		[9, 10, 11, 12, 13],
	]
	for window_index: int in range(rank_windows.size() - 1, -1, -1):
		var window: Array = rank_windows[window_index]
		var can_form: bool = true
		for rank: int in window:
			if not by_rank.has(rank):
				can_form = false
				break
		if can_form:
			var result: Array[QiData] = []
			for rank: int in window:
				result.append(by_rank[rank])
			return result
	return []

## 构造牌型结果并计算踢脚牌、四属性同气和稳定比较值。
static func _build_result(
		hand_type_id: String,
		participating_cards: Array,
		all_cards: Array,
		battle_state: BattleQiState) -> QiHandPatternResult:
	var result: QiHandPatternResult = QiHandPatternResult.new()
	result.hand_type_id = hand_type_id
	result.required_participating_count = participating_cards.size()
	for qi_data: QiData in participating_cards:
		result.participating_qi_instance_uids.append(qi_data.object_uid)
	for qi_data: QiData in all_cards:
		if not result.participating_qi_instance_uids.has(qi_data.object_uid):
			result.kicker_qi_instance_uids.append(qi_data.object_uid)
	for qi_data: QiData in participating_cards:
		for attribute_id: String in qi_data.get_effective_attribute_ids(battle_state):
			if not QiData.ATTRIBUTE_IDS.has(attribute_id):
				continue
			result.attribute_counts[attribute_id] = \
				int(result.attribute_counts.get(attribute_id, 0)) + 1
			result.attribute_qi_instance_uids[attribute_id].append(qi_data.object_uid)
	result.rebuild_same_qi_summary()
	for qi_data: QiData in participating_cards:
		result.comparison_values.append(qi_data.get_effective_rank(battle_state))
	result.comparison_values.sort()
	result.comparison_values.reverse()
	return result
