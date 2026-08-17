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

## 战斗兼容入口复用 BattleSide 的统一事务快照，不按 operation id 区分补偿逻辑。
func capture_transaction_state() -> Dictionary:
	return growth.capture_passive_query_state() if growth != null else {}

func restore_transaction_state(snapshot: Dictionary) -> bool:
	if growth == null:
		return false
	growth.replace_passive_query_state(snapshot)
	return true

func _find_card(instance_id: String):
	if growth == null or not growth.has_method("find_hand_card"):
		return null
	return growth.find_hand_card(instance_id)
