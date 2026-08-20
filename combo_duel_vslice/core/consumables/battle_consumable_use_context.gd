class_name BattleConsumableUseContext
extends "res://core/consumables/consumable_use_context.gd"

const BattleRuntimeMutationTransactionScript = preload(
	"res://core/battle_runtime_mutation_transaction.gd")

## 战斗内消耗品效果上下文。
##
## growth 是 BattleSide 玩家方；目标按当前手牌实例 ID 解析。功法候选沿用共享
## 功法仓库的正式白名单（与历史纵切行为一致，不按效果的功法池过滤）；随机数
## 沿用战斗引擎的 rng，保证已有纵切确定性测试继续成立。

const ENHANCEMENT_NAMES := {"qi_boost": "增元", "momentum": "乘势", "hunyuan": "混元"}
const QiCardInstanceDataScript = preload("res://core/qi_card_instance_data.gd")

## 这些操作依赖 RunDeck、战斗外配装编辑或本局构筑能力。公共服务在查询阶段
## 通过上下文能力拒绝，避免执行到一半才发现 BattleSide 不拥有对应端口。
const RUN_ONLY_OPERATIONS := {
	"remove_run_cards": true,
	"copy_run_card": true,
	"generate_random_base_cards": true,
	"apply_origin": true,
	"apply_prepared_group_origin": true,
	"apply_imprint": true,
	"apply_random_imprint": true,
	"apply_random_enhancement": true,
	"remove_run_cards_for_experience": true,
	"rewrite_technique_progression": true,
	"apply_origin_to_matching_rank": true,
	"modify_base_hand_limit": true,
	"grant_random_inner_skill": true,
	"duplicate_equipped_inner_skill": true,
	"gain_equipped_inner_skill_forget_value": true,
}

var _technique_repository
var _consumable_repository
var _event_service
var _trigger_queue
var _battle_sides: Array = []
var _mutation_scope_service = null

func _init(
		player_side,
		instance_ids_override: Array = [],
		rng_override: RandomNumberGenerator = null,
		technique_repository = null,
		consumable_repository = null,
		event_service = null,
		trigger_queue = null,
		battle_sides: Array = [],
		metadata_override: Dictionary = {},
		mutation_scope_service = null) -> void:
	super(player_side, instance_ids_override, rng_override, metadata_override)
	_technique_repository = technique_repository
	_consumable_repository = consumable_repository
	_event_service = event_service
	_trigger_queue = trigger_queue
	_battle_sides = battle_sides.duplicate()
	_mutation_scope_service = mutation_scope_service
	if _battle_sides.is_empty() and player_side != null:
		_battle_sides.append(player_side)

func create_effect_context(
		resolved_instance_ids: Array,
		random_source: RandomNumberGenerator,
		metadata_override: Dictionary):
	return BattleConsumableUseContext.new(
		growth, resolved_instance_ids, random_source, _technique_repository,
		_consumable_repository, _event_service, _trigger_queue,
		_battle_sides, metadata_override, _mutation_scope_service)

func supports_effect(effect: Dictionary) -> Dictionary:
	var operation_id := str(effect.get("op", ""))
	if RUN_ONLY_OPERATIONS.has(operation_id):
		return {
			"supported": false,
			"reason": "当前战斗上下文不支持该本局构筑能力：%s" % operation_id,
		}
	return {"supported": true, "reason": ""}

func eligible_targets(zone: String) -> Array:
	if zone != "run_deck" or growth == null:
		return []
	var result: Array = []
	for card in growth.hand:
		result.append(_target_summary(card))
	return result

func owns_target(zone: String, instance_id: String) -> bool:
	return zone == "run_deck" and _find_card(instance_id) != null

func current_target_limit(targeting: Dictionary) -> int:
	if str(targeting.get("maximum_source", "")) == "base_hand_limit":
		return int(growth.hand_limit) + int(growth.base_hand_limit_modifier)
	return int(targeting.get("maximum", 0))

func card_data(instance_id: String) -> Dictionary:
	var card = _find_card(instance_id)
	return QiCardInstanceDataScript.capture(card, true) if card != null else {}

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

func add_consumable(consumable_id: String) -> Dictionary:
	if growth == null or _consumable_repository == null:
		return {"success": false, "reason": "战斗消耗品仓库不存在"}
	var definition: Dictionary = _consumable_repository.get_consumable(consumable_id)
	if definition.is_empty():
		return {"success": false, "reason": "未知消耗品：%s" % consumable_id}
	if growth.consumable_ids.size() >= consumable_capacity():
		return {"success": false, "reason": "共享消耗品栏已满"}
	## 当前消耗品会在全部 Handler 成功后统一扣除；reserved slot 只存在于本次
	## 工作事务，提交后的库存仍必须回到正式容量以内。
	growth.consumable_ids.append(consumable_id)
	return {"success": true, "consumable_id": consumable_id}

func consumable_capacity() -> int:
	return (
		int(growth.consumable_limit) + int(metadata.get(
			"reserved_consumable_slots", 0))
		if growth != null else 0)

func consumable_candidates(kind: String) -> Array[String]:
	return (
		_consumable_repository.ids_by_kind(kind)
		if _consumable_repository != null else [])

func last_recallable_consumable_id() -> String:
	return str(growth.last_recallable_consumable_id) if growth != null else ""

func record_last_recallable_consumable(consumable_id: String) -> void:
	if growth != null:
		growth.last_recallable_consumable_id = consumable_id

func technique_name(technique_id: String) -> String:
	if _technique_repository == null:
		return technique_id
	return str(_technique_repository.get_technique(technique_id).get("name", technique_id))

func enhancement_name(enhancement_id: String) -> String:
	return ENHANCEMENT_NAMES.get(enhancement_id, enhancement_id)

func target_display_name(instance_id: String) -> String:
	var card = _find_card(instance_id)
	return card.display_name() if card != null else instance_id

## 战斗入口复用正式 Runtime 快照，不按 operation id 区分补偿逻辑。事件服务在
## 事务期间延迟对外发布；失败时恢复 serial、receipt 与 execution history，因而
## 监听器不会观察到已经回滚的半次消耗品使用。
func begin_transaction() -> Dictionary:
	var transaction: Dictionary = _mutation_scope_service.begin() \
		if _mutation_scope_service != null \
		else BattleRuntimeMutationTransactionScript.begin(
			_battle_sides, _event_service, _trigger_queue, rng)
	transaction["context"] = self
	return transaction

func capture_transaction_state() -> Dictionary:
	return BattleRuntimeMutationTransactionScript.capture(
		_battle_sides, _event_service, _trigger_queue, rng)

func commit_transaction(transaction: Dictionary) -> Dictionary:
	return BattleRuntimeMutationTransactionScript.commit(transaction)

func rollback_transaction(transaction: Dictionary) -> bool:
	return BattleRuntimeMutationTransactionScript.rollback(transaction)

func restore_transaction_state(snapshot: Dictionary) -> bool:
	return BattleRuntimeMutationTransactionScript.restore(
		snapshot, _event_service, _trigger_queue, rng)

func state_fingerprint() -> Dictionary:
	if growth == null:
		return {}
	return {
		"consumable_ids": growth.consumable_ids.duplicate(),
		"consumable_use_sequence": growth.consumable_use_sequence,
		"last_recallable_consumable_id": growth.last_recallable_consumable_id,
		"used_unique_consumable_ids": growth.used_unique_consumable_ids.duplicate(),
		"experience": growth.experience,
		"hand_technique_progression": (
			growth.hand_technique_progression.duplicate(true)),
		"owned_technique_ids": growth.owned_technique_ids.duplicate(),
		"targets": eligible_targets("run_deck"),
		"has_rng": rng != null,
		"rng_state": int(rng.state) if rng != null else 0,
	}

func _target_summary(card) -> Dictionary:
	var values: Dictionary = QiCardInstanceDataScript.capture(card, true)
	var reshapes: Dictionary = values.get("reshapes", {})
	return {
		"instance_id": str(card.id),
		"card_id": str(card.definition_id),
		"rank": str(card.rank_name),
		"suit": str(card.attribute),
		"attribute": str(card.attribute),
		"origin": reshapes.get("origin", {}).duplicate(true),
		"enhancement": str(reshapes.get("enhancement", "")),
		"imprint": str(reshapes.get("imprint", "")),
		"others": reshapes.get("others", {}).duplicate(true),
		"display_name": card.display_name(),
	}

func _find_card(instance_id: String):
	if growth == null or not growth.has_method("find_hand_card"):
		return null
	return growth.find_hand_card(instance_id)
