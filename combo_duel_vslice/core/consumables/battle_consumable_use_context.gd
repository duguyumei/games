class_name BattleConsumableUseContext
extends "res://core/consumables/consumable_use_context.gd"

## 纵切战斗兼容入口的消耗品效果上下文。
##
## growth 是 BattleSide 玩家方；目标按当前手牌实例 ID 解析。功法候选沿用共享
## 功法仓库的正式白名单（与历史纵切行为一致，不按效果的功法池过滤）；随机数
## 沿用战斗引擎的 rng，保证已有纵切确定性测试继续成立。

const ENHANCEMENT_NAMES := {"bonus": "奖励牌", "multiplier": "倍率牌"}
const FINISH_NAMES := {
	"foil": "箔面",
	"holographic": "镭射",
	"polychrome": "多彩",
}

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

func apply_finish(instance_id: String, finish_id: String) -> Dictionary:
	var card = _find_card(instance_id)
	if card == null:
		return {
			"success": false,
			"reason": "目标不在当前手牌中：%s" % instance_id,
		}
	card.set_finish(finish_id)
	return {"success": true, "instance_id": instance_id, "finish": finish_id}

func technique_name(technique_id: String) -> String:
	if _technique_repository == null:
		return technique_id
	return str(_technique_repository.get_technique(technique_id).get("name", technique_id))

func enhancement_name(enhancement_id: String) -> String:
	return ENHANCEMENT_NAMES.get(enhancement_id, enhancement_id)

func finish_name(finish_id: String) -> String:
	return FINISH_NAMES.get(finish_id, finish_id)

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
			"enhancement": str(card.reshape_enhancement),
			"finish": str(card.reshape_finish),
			"imprint": str(card.reshape_imprint),
			"others": card.reshape_others.duplicate(true),
			"suppressed_reshapes": card.suppressed_reshapes.duplicate(true),
			"anomalies": card.anomaly_snapshot(),
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
		card.reshape_enhancement = str(values.get("enhancement", ""))
		card.reshape_finish = str(values.get("finish", ""))
		card.reshape_imprint = str(values.get("imprint", ""))
		card.reshape_others = values.get("others", {}).duplicate(true)
		card.suppressed_reshapes = values.get("suppressed_reshapes", {}).duplicate(true)
		var anomalies: Dictionary = values.get("anomalies", {})
		card.anomaly_poison = str(anomalies.get("poison", ""))
		card.anomaly_state = str(anomalies.get("state", ""))
		card.anomaly_marks = anomalies.get("marks", {}).duplicate(true)
		card.anomaly_others = anomalies.get("others", {}).duplicate(true)
	growth.hand_technique_progression = snapshot.get(
		"hand_technique_progression", {}).duplicate(true)
	growth.owned_technique_ids.assign(snapshot.get("owned_technique_ids", []))
	growth.consumable_ids.assign(snapshot.get("consumable_ids", []))
	return restored

func _find_card(instance_id: String):
	if growth == null or not growth.has_method("find_hand_card"):
		return null
	return growth.find_hand_card(instance_id)
