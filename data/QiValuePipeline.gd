## 真气数值的统一纯查询管线；所有来源只提供配置，不在查询期间修改运行时状态。
extends RefCounted
class_name QiValuePipeline

## 三个单张真气数值阶段。
const STAGE_BASE_QI: String = "base_qi_value"
const STAGE_EFFECTIVE_QI: String = "effective_qi_value"
const STAGE_FINAL_QI: String = "final_qi_value"

## 倍率和功法值阶段。
const STAGE_MULTIPLIER: String = "multiplier"
const STAGE_EFFECTIVE_POWER: String = "effective_power"

## 数值效果允许使用的全部稳定阶段。
const VALUE_STAGES: Array[String] = [
	STAGE_BASE_QI,
	STAGE_EFFECTIVE_QI,
	STAGE_FINAL_QI,
	STAGE_MULTIPLIER,
	STAGE_EFFECTIVE_POWER,
]

## 数值效果允许使用的运算与目标。
const VALUE_OPERATIONS: Array[String] = ["add", "multiply", "set"]
const VALUE_TARGETS: Array[String] = [
	"all", "self", "first_pending", "participating", "non_participating", "scalar",
]

## 固定来源组；其他特殊来源必须显式选择其中一个组注册。
const SOURCE_GROUPS: Array[String] = [
	"pending_qi",
	"hand_qi",
	"gongfa",
	"neigong",
	"status",
	"artifact",
]

## 为一方计算全部单张数值、同气倍率和功法值。
static func calculate_side_values(
		side_result: QiActionSideResult,
		pending_cards: Array[QiData],
		battle_state: BattleQiState) -> void:
	if side_result == null or side_result.pattern == null or battle_state == null:
		return
	var sources: Array[Dictionary] = collect_ordered_sources(
		side_result.side,
		side_result.pattern.hand_type_id,
		pending_cards,
		battle_state.get_zone(side_result.side, BattleQiState.ZONE_HAND),
		battle_state)
	var participating_uids: Array[String] = \
		side_result.pattern.participating_qi_instance_uids
	_rebuild_all_pending_attributes(side_result, pending_cards, battle_state)
	for qi_data: QiData in pending_cards:
		var context: Dictionary = {
			"side": side_result.side,
			"hand_type_id": side_result.pattern.hand_type_id,
			"qi_instance_uid": qi_data.object_uid,
			"participates_in_value": participating_uids.has(qi_data.object_uid),
			"first_pending_qi_uid": pending_cards[0].object_uid if not pending_cards.is_empty() else "",
		}
		var native_base_value: int = qi_data.get_base_qi_value(battle_state)
		var base_value: int = _apply_stage(
			native_base_value, STAGE_BASE_QI, sources, context, side_result, battle_state)
		var native_effective_value: int = qi_data.get_qi_value(battle_state)
		var effective_value: int = _apply_stage(
			base_value + native_effective_value - native_base_value,
			STAGE_EFFECTIVE_QI,
			sources,
			context,
			side_result,
			battle_state)
		var contribution_value: int = QiStateResolver.apply_contribution_modifiers(
			qi_data, effective_value, battle_state, context)
		var final_value: int = _apply_stage(
			contribution_value, STAGE_FINAL_QI, sources, context, side_result, battle_state)
		side_result.qi_value_details[qi_data.object_uid] = {
			"base_qi_value": base_value,
			"effective_qi_value": effective_value,
			"final_qi_value": final_value,
			"participates_in_value": bool(context["participates_in_value"]),
		}
		if bool(context["participates_in_value"]):
			side_result.final_qi_value_sum += final_value
	side_result.qi_value_sum = side_result.final_qi_value_sum
	side_result.final_multiplier = _apply_stage(
		side_result.base_multiplier,
		STAGE_MULTIPLIER,
		sources,
		{
			"side": side_result.side,
			"hand_type_id": side_result.pattern.hand_type_id,
			"participates_in_value": false,
			"qi_instance_uid": "",
			"first_pending_qi_uid": pending_cards[0].object_uid if not pending_cards.is_empty() else "",
		},
		side_result,
		battle_state)
	side_result.multiplier_modifiers = \
		side_result.final_multiplier - side_result.base_multiplier
	side_result.base_power = max(int(floor(
		float(side_result.final_qi_value_sum) * float(side_result.final_multiplier))), 0)
	side_result.initial_power = side_result.base_power
	side_result.effective_power = _apply_stage(
		side_result.base_power,
		STAGE_EFFECTIVE_POWER,
		sources,
		{
			"side": side_result.side,
			"hand_type_id": side_result.pattern.hand_type_id,
			"participates_in_value": false,
			"qi_instance_uid": "",
			"first_pending_qi_uid": pending_cards[0].object_uid if not pending_cards.is_empty() else "",
		},
		side_result,
		battle_state)
	side_result.final_power = side_result.effective_power

## 按固定来源顺序收集数值和战斗事件来源。
static func collect_ordered_sources(
		side: String,
		hand_type_id: String,
		pending_cards: Array[QiData],
		hand_cards: Array[QiData],
		battle_state: BattleQiState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source_index: int in pending_cards.size():
		_append_data_source(result, "pending_qi", "qi", pending_cards[source_index].object_uid,
			source_index, pending_cards[source_index])
	_append_registered_sources(result, battle_state, side, "pending_qi")
	for source_index: int in hand_cards.size():
		_append_data_source(result, "hand_qi", "qi", hand_cards[source_index].object_uid,
			source_index, hand_cards[source_index])
	_append_registered_sources(result, battle_state, side, "hand_qi")
	var hand_ring: Array[String] = _get_rotated_hand_ring(hand_type_id)
	var gongfa_order: int = 0
	for queue_hand_type_id: String in hand_ring:
		for entry: Dictionary in battle_state.get_gongfa_queue_entries(side, queue_hand_type_id):
			var gongfa_data: GongfaData = _get_gongfa_source_data(side, entry)
			if gongfa_data == null:
				continue
			_append_data_source(result, "gongfa", "gongfa",
				str(entry.get("slot_instance_id", "")), gongfa_order, gongfa_data)
			gongfa_order += 1
	_append_registered_sources(result, battle_state, side, "gongfa")
	var neigong_entries: Array[Dictionary] = battle_state.get_neigong_slot_entries(side)
	for source_index: int in neigong_entries.size():
		var neigong_entry: Dictionary = neigong_entries[source_index]
		var neigong_data: NeigongData = _get_neigong_source_data(side, neigong_entry)
		if neigong_data == null:
			continue
		_append_data_source(result, "neigong", "neigong",
			str(neigong_entry.get("instance_uid", "")), source_index, neigong_data)
	_append_registered_sources(result, battle_state, side, "neigong")
	_append_status_sources(result, side)
	_append_registered_sources(result, battle_state, side, "status")
	_append_artifact_sources(result, side)
	_append_registered_sources(result, battle_state, side, "artifact")
	return result

## 对一个阶段按来源顺序执行加算、乘算和设值，并在阶段结束统一向下取整。
static func _apply_stage(
		initial_value: Variant,
		stage: String,
		sources: Array[Dictionary],
		context: Dictionary,
		side_result: QiActionSideResult,
		battle_state: BattleQiState) -> int:
	var current_value: float = float(initial_value)
	for source: Dictionary in sources:
		var effects: Array = source.get("value_effects", [])
		for effect_index: int in effects.size():
			var effect_value: Variant = effects[effect_index]
			if not effect_value is Dictionary:
				continue
			var effect: Dictionary = effect_value
			if str(effect.get("stage", "")) != stage \
				or not _matches_condition(effect, source, context) \
				or not _can_apply_consumable_effect(
					effect, source, context, side_result, battle_state):
				continue
			var operand: float = float(effect.get("value", 0.0))
			var before_value: float = current_value
			match str(effect.get("operation", "add")):
				"add":
					current_value += operand
				"multiply":
					current_value *= operand
				"set":
					current_value = operand
				_:
					continue
			var source_record: Dictionary = {
				"source_side": context.get("side", ""),
				"stage": stage,
				"effect_id": str(effect.get("effect_id", "%s:%d" % [
					source.get("source_instance_id", ""), effect_index])),
				"source_group": source.get("source_group", ""),
				"source_kind": source.get("source_kind", ""),
				"source_instance_id": source.get("source_instance_id", ""),
				"target_qi_instance_uid": context.get("qi_instance_uid", ""),
				"operation": effect.get("operation", "add"),
				"operand": operand,
				"before": before_value,
				"after": current_value,
			}
			side_result.applied_effect_sources.append(source_record)
			if effect.get("consume", null) is Dictionary:
				var receipt: Dictionary = source_record.duplicate(true)
				receipt["consume"] = effect["consume"].duplicate(true)
				if not bool(receipt["consume"].get("once_per_action", true)) \
					or not _has_effect_receipt(side_result, receipt):
					side_result.effect_receipts.append(receipt)
	return max(int(floor(current_value)), 0)

## 校验一组固定数值效果，避免未知阶段、运算或消费格式进入内容库。
static func validate_value_effects(effects: Array) -> bool:
	for effect_value: Variant in effects:
		if not effect_value is Dictionary:
			return false
		var effect: Dictionary = effect_value
		if str(effect.get("effect_id", "")) == "" \
			or not VALUE_STAGES.has(str(effect.get("stage", ""))) \
			or not VALUE_OPERATIONS.has(str(effect.get("operation", ""))) \
			or not VALUE_TARGETS.has(str(effect.get("target", "all"))):
			return false
		var operand: Variant = effect.get("value", null)
		if not operand is int and not operand is float:
			return false
		var hand_type_values: Variant = effect.get("hand_type_ids", [])
		if not hand_type_values is Array:
			return false
		for hand_type_value: Variant in hand_type_values:
			if not hand_type_value is String \
				or not GongfaData.HAND_TYPE_IDS.has(str(hand_type_value)):
				return false
		var consume_value: Variant = effect.get("consume", null)
		if consume_value == null:
			continue
		if not consume_value is Dictionary:
			return false
		var consume: Dictionary = consume_value
		if int(consume.get("max_uses", 0)) <= 0 \
			or int(consume.get("amount", 1)) <= 0 \
			or consume.has("once_per_action") \
				and not consume["once_per_action"] is bool:
			return false
	return true

## 判断一个带次数消费的效果是否仍有足够次数；只读战斗运行时计数。
static func _can_apply_consumable_effect(
		effect: Dictionary,
		source: Dictionary,
		context: Dictionary,
		side_result: QiActionSideResult,
		battle_state: BattleQiState) -> bool:
	var consume_value: Variant = effect.get("consume", null)
	if not consume_value is Dictionary:
		return true
	var consume: Dictionary = consume_value
	var max_uses: int = int(consume.get("max_uses", 0))
	var amount: int = int(consume.get("amount", 1))
	if battle_state == null or max_uses <= 0 or amount <= 0:
		return false
	var source_side: String = str(context.get("side", ""))
	var source_kind: String = str(source.get("source_kind", ""))
	var source_instance_id: String = str(source.get("source_instance_id", ""))
	var effect_id: String = str(effect.get("effect_id", ""))
	var reserved_uses: int = 0
	if not bool(consume.get("once_per_action", true)):
		for receipt: Dictionary in side_result.effect_receipts:
			if _is_same_effect_receipt(
				receipt, source_side, source_kind, source_instance_id, effect_id):
				reserved_uses += int(receipt.get("consume", {}).get("amount", 1))
	return battle_state.can_use_qi_value_effect(
		source_side,
		source_kind,
		source_instance_id,
		effect_id,
		max_uses,
		amount + reserved_uses)

## 判断本次行动是否已经为同一个效果记录过一次性回执。
static func _has_effect_receipt(
		side_result: QiActionSideResult, candidate: Dictionary) -> bool:
	for receipt: Dictionary in side_result.effect_receipts:
		if _is_same_effect_receipt(
			receipt,
			str(candidate.get("source_side", "")),
			str(candidate.get("source_kind", "")),
			str(candidate.get("source_instance_id", "")),
			str(candidate.get("effect_id", ""))):
			return true
	return false

## 比较两个回执是否属于同一阵营、来源实例和固定效果。
static func _is_same_effect_receipt(
		receipt: Dictionary,
		source_side: String,
		source_kind: String,
		source_instance_id: String,
		effect_id: String) -> bool:
	return str(receipt.get("source_side", "")) == source_side \
		and str(receipt.get("source_kind", "")) == source_kind \
		and str(receipt.get("source_instance_id", "")) == source_instance_id \
		and str(receipt.get("effect_id", "")) == effect_id

## 判断效果的牌型、目标和参与牌条件是否匹配。
static func _matches_condition(
		effect: Dictionary,
		source: Dictionary,
		context: Dictionary) -> bool:
	var hand_type_values: Variant = effect.get("hand_type_ids", [])
	if hand_type_values is Array and not hand_type_values.is_empty() \
		and not hand_type_values.has(context.get("hand_type_id", "")):
		return false
	if effect.has("requires_participating") \
		and bool(effect.get("requires_participating", false)) \
		!= bool(context.get("participates_in_value", false)):
		return false
	var target: String = str(effect.get("target", "all"))
	var qi_instance_uid: String = str(context.get("qi_instance_uid", ""))
	match target:
		"all":
			return true
		"self":
			return qi_instance_uid != "" \
				and qi_instance_uid == str(source.get("source_instance_id", ""))
		"first_pending":
			return qi_instance_uid != "" \
				and qi_instance_uid == str(context.get("first_pending_qi_uid", ""))
		"participating":
			return bool(context.get("participates_in_value", false))
		"non_participating":
			return qi_instance_uid != "" \
				and not bool(context.get("participates_in_value", false))
		"scalar":
			return qi_instance_uid == ""
	return false

## 统计全部待结算牌的四属性同气；牌型参与牌与踢脚牌都计入倍率。
static func _rebuild_all_pending_attributes(
		side_result: QiActionSideResult,
		pending_cards: Array[QiData],
		battle_state: BattleQiState) -> void:
	side_result.base_multiplier = 0
	for qi_data: QiData in pending_cards:
		for attribute_id: String in qi_data.get_effective_attribute_ids(battle_state):
			if not QiData.ATTRIBUTE_IDS.has(attribute_id):
				continue
			side_result.attribute_counts[attribute_id] = \
				int(side_result.attribute_counts.get(attribute_id, 0)) + 1
			side_result.attribute_qi_instance_uids[attribute_id].append(qi_data.object_uid)
	for attribute_id: String in QiData.ATTRIBUTE_IDS:
		side_result.base_multiplier = max(
			side_result.base_multiplier,
			int(side_result.attribute_counts.get(attribute_id, 0)))

## 添加一个固定数据对象作为查询来源。
static func _append_data_source(
		result: Array[Dictionary],
		source_group: String,
		source_kind: String,
		source_instance_id: String,
		source_order: int,
		data_object: Object) -> void:
	if data_object == null:
		return
	var value_effects: Variant = data_object.get("qi_value_effects")
	var battle_event_effects: Variant = data_object.get("qi_battle_event_effects")
	var normalized_value_effects: Array = value_effects if value_effects is Array else []
	if data_object is QiData:
		var multiplier_modifier: int = \
			(data_object as QiData).get_gongfa_multiplier_modifier()
		if multiplier_modifier != 0:
			normalized_value_effects = normalized_value_effects.duplicate(true)
			normalized_value_effects.append({
				"effect_id": "reshape_multiplier",
				"stage": STAGE_MULTIPLIER,
				"operation": "add",
				"value": multiplier_modifier,
				"target": "scalar",
			})
	result.append({
		"source_group": source_group,
		"source_kind": source_kind,
		"source_instance_id": source_instance_id,
		"source_order": source_order,
		"value_effects": normalized_value_effects,
		"battle_event_effects": battle_event_effects if battle_event_effects is Array else [],
	})

## 插入显式注册到某个固定顺序组的特殊来源。
static func _append_registered_sources(
		result: Array[Dictionary],
		battle_state: BattleQiState,
		side: String,
		source_group: String) -> void:
	if battle_state == null:
		return
	for source: Dictionary in battle_state.get_registered_qi_effect_sources(side, source_group):
		result.append(source)

## 从当前牌型开始轮转固定牌型环。
static func _get_rotated_hand_ring(hand_type_id: String) -> Array[String]:
	var result: Array[String] = []
	var start_index: int = GongfaData.HAND_TYPE_IDS.find(hand_type_id)
	if start_index < 0:
		start_index = 0
	for offset: int in GongfaData.HAND_TYPE_IDS.size():
		result.append(GongfaData.HAND_TYPE_IDS[
			(start_index + offset) % GongfaData.HAND_TYPE_IDS.size()])
	return result

## 返回玩家本局功法实例或敌方固定功法定义。
static func _get_gongfa_source_data(side: String, entry: Dictionary) -> GongfaData:
	if side == BattleQiState.SIDE_PLAYER and Global.player_data != null:
		return Global.player_data.get_owned_gongfa(
			str(entry.get("gongfa_instance_uid", "")))
	return Global.get_gongfa_data(str(entry.get("gongfa_definition_id", "")))

## 返回玩家本局内功实例或敌方固定内功定义。
static func _get_neigong_source_data(side: String, entry: Dictionary) -> NeigongData:
	if side == BattleQiState.SIDE_PLAYER and Global.player_data != null:
		return Global.player_data.get_owned_neigong(str(entry.get("instance_uid", "")))
	return Global.get_neigong_data(str(entry.get("definition_id", "")))

## 按当前战斗对象中的应用和显示顺序添加角色状态来源。
static func _append_status_sources(result: Array[Dictionary], side: String) -> void:
	var combatant: BaseCombatant = _get_side_combatant(side)
	if combatant == null:
		return
	var source_order: int = 0
	for status_id_value: Variant in combatant.status_id_to_status_effects.keys():
		var status_id: String = str(status_id_value)
		var status_data: StatusEffectData = Global.get_status_effect_data(status_id)
		for status_effect: Variant in combatant.status_id_to_status_effects.get(status_id, []):
			_append_data_source(result, "status", "status",
				"status:%s:%d" % [status_id, source_order], source_order, status_data)
			source_order += 1

## 按玩家本局获得顺序添加奇物来源；敌方当前没有奇物配置。
static func _append_artifact_sources(result: Array[Dictionary], side: String) -> void:
	if side != BattleQiState.SIDE_PLAYER or Global.player_data == null:
		return
	var source_order: int = 0
	for artifact_uid: String in Global.player_data.player_artifact_uid_to_artifact_data:
		var artifact_data: ArtifactData = \
			Global.player_data.player_artifact_uid_to_artifact_data[artifact_uid]
		_append_data_source(result, "artifact", "artifact", artifact_uid,
			source_order, artifact_data)
		source_order += 1

## 返回指定阵营唯一战斗对象。
static func _get_side_combatant(side: String) -> BaseCombatant:
	if side == BattleQiState.SIDE_PLAYER:
		return Global.get_player()
	if side == BattleQiState.SIDE_ENEMY:
		var enemies: Array[Enemy] = Global.get_alive_enemies()
		return enemies[0] if not enemies.is_empty() else null
	return null
