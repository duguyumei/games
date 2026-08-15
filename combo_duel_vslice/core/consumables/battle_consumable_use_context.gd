class_name BattleConsumableUseContext
extends "res://core/consumables/consumable_use_context.gd"

## 纵切战斗兼容入口的消耗品效果上下文。
##
## growth 是 BattleSide 玩家方；目标按当前手牌实例 ID 解析。功法候选沿用共享
## 功法仓库的正式白名单（与历史纵切行为一致，不按效果的功法池过滤）；随机数
## 沿用战斗引擎的 rng，保证已有纵切确定性测试继续成立。

const ENHANCEMENT_NAMES := {"qi_boost": "增元", "momentum": "乘势", "hunyuan": "混元"}

var _technique_repository

func _init(
		player_side,
		instance_ids_override: Array = [],
		rng_override: RandomNumberGenerator = null,
		technique_repository = null,
		metadata_override: Dictionary = {}) -> void:
	super(player_side, instance_ids_override, rng_override, metadata_override)
	_technique_repository = technique_repository

func insight_candidates(hand_id: String, _pools: Array) -> Array[String]:
	if _technique_repository == null:
		return []
	return _technique_repository.formal_technique_ids_for_hand(hand_id)

func apply_enhancement(instance_id: String, enhancement_id: String) -> Dictionary:
	var card = _find_card(instance_id)
	if card == null:
		return {
			"success": false,
			"reason": "目标不在当前手牌中：%s" % instance_id,
		}
	card.set_enhancement(enhancement_id)
	return {"success": true, "instance_id": instance_id, "enhancement": enhancement_id}

func technique_name(technique_id: String) -> String:
	if _technique_repository == null:
		return technique_id
	return str(_technique_repository.get_technique(technique_id).get("name", technique_id))

func enhancement_name(enhancement_id: String) -> String:
	return ENHANCEMENT_NAMES.get(enhancement_id, enhancement_id)

func target_display_name(instance_id: String) -> String:
	var card = _find_card(instance_id)
	return card.display_name() if card != null else instance_id

## 战斗兼容入口的统一事务快照。只覆盖消耗品 Handler 可持久修改的状态，
## 不按 operation id 区分补偿逻辑。
func capture_transaction_state() -> Dictionary:
	var card_states: Dictionary = {}
	for instance_id in instance_ids:
		var card = _find_card(instance_id)
		if card == null:
			continue
		card_states[instance_id] = {
			"identity": {
				"definition_id": card.definition_id,
				"rank_name": card.rank_name,
				"rank_order": card.rank_order,
				"qi_value": card.qi_value,
				"attribute": card.attribute,
				"attribute_name": card.attribute_name,
			},
			"origin_base_identity": card.origin_base_identity.duplicate(true),
			"origin": card.reshape_origin.duplicate(true),
			"enhancement": str(card.reshape_enhancement),
			"imprint": str(card.reshape_imprint),
			"others": card.reshape_others.duplicate(true),
			"anomalies": card.anomaly_snapshot(),
			"temporary_reshapes": card.temporary_reshapes.duplicate(true),
		}
	return {
		"cards": card_states,
		"hand_technique_progression": growth.hand_technique_progression.duplicate(true),
		"owned_technique_ids": growth.owned_technique_ids.duplicate(),
		"consumable_ids": growth.consumable_ids.duplicate(),
	}

func restore_transaction_state(snapshot: Dictionary) -> bool:
	if growth == null:
		return false
	var restored := true
	for instance_id in snapshot.get("cards", {}):
		var card = _find_card(str(instance_id))
		if card == null:
			restored = false
			continue
		var values: Dictionary = snapshot["cards"][instance_id]
		var identity: Dictionary = values.get("identity", {})
		card.definition_id = str(identity.get("definition_id", card.definition_id))
		card.rank_name = str(identity.get("rank_name", card.rank_name))
		card.rank_order = int(identity.get("rank_order", card.rank_order))
		card.qi_value = int(identity.get("qi_value", card.qi_value))
		card.attribute = str(identity.get("attribute", card.attribute))
		card.attribute_name = str(identity.get("attribute_name", card.attribute_name))
		card.origin_base_identity = values.get("origin_base_identity", {}).duplicate(true)
		card.reshape_origin = values.get("origin", {}).duplicate(true)
		card.reshape_enhancement = str(values.get("enhancement", ""))
		card.reshape_imprint = str(values.get("imprint", ""))
		card.reshape_others = values.get("others", {}).duplicate(true)
		var anomalies: Dictionary = values.get("anomalies", {})
		if not card.restore_anomaly_snapshot(anomalies):
			restored = false
		card.temporary_reshapes = values.get("temporary_reshapes", {
			"enhancement": "", "attribute": "", "rank": {}}).duplicate(true)
		if not card.temporary_reshapes.has("rank"):
			card.temporary_reshapes["rank"] = {}
	growth.hand_technique_progression = snapshot.get(
		"hand_technique_progression", {}).duplicate(true)
	growth.owned_technique_ids.assign(snapshot.get("owned_technique_ids", []))
	growth.consumable_ids.assign(snapshot.get("consumable_ids", []))
	return restored

func _find_card(instance_id: String):
	if growth == null or not growth.has_method("find_hand_card"):
		return null
	return growth.find_hand_card(instance_id)
