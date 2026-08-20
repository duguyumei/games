class_name RunProgressSnapshot
extends RefCounted

## 本局成长数据在成长库存、战斗会话与存档之间的传输边界。
##
## 快照允许只携带部分字段：战斗只回传它实际拥有的数据，成长库存只更新
## `has_*` 为真的字段。这里故意不把缺失字段解释为空值，避免局部同步清空
## 仅由本局系统持有的内功与功法位状态。

const SCHEMA_VERSION := 4

var consumable_ids: Array[String] = []
var item_ids: Array[String] = []
var learned_technique_ids: Array[String] = []
var learned_inner_skill_ids: Array[String] = []
var equipped_inner_skill_ids: Array[String] = []
var technique_slot_index: int = 0
var forgotten_inner_skill_count: int = 0
var run_deck: Dictionary = {}
var life: int = 0
var max_life: int = 0
var base_max_life: int = 0
var source_marker_state: Dictionary = {}
var experience: int = 0
var free_meditation_charge: int = 0
var experience_operation_receipts: Dictionary = {}
var consumable_capacity: int = 2
var consumable_overflow_count: int = 0
var hand_technique_progression: Dictionary = {}
var practice_shop_state: Dictionary = {}
var consumable_use_sequence: int = 0
var last_recallable_consumable_id: String = ""
var base_hand_limit_modifier: int = 0
var hand_technique_multiplier_modifiers: Dictionary = {}
var used_unique_consumable_ids: Array[String] = []
var passive_counter_state: Dictionary = {}
var source_behavior_transformation_state: Dictionary = {}
var run_combat_history_state: Dictionary = {}

var has_consumable_ids: bool = false
var has_item_ids: bool = false
var has_learned_technique_ids: bool = false
var has_learned_inner_skill_ids: bool = false
var has_equipped_inner_skill_ids: bool = false
var has_technique_slot_index: bool = false
var has_forgotten_inner_skill_count: bool = false
var has_run_deck: bool = false
var has_life: bool = false
var has_max_life: bool = false
var has_base_max_life: bool = false
var has_source_marker_state: bool = false
var has_experience: bool = false
var has_free_meditation_charge: bool = false
var has_experience_operation_receipts: bool = false
var has_consumable_capacity: bool = false
var has_consumable_overflow_count: bool = false
var has_hand_technique_progression: bool = false
var has_practice_shop_state: bool = false
var has_consumable_use_sequence: bool = false
var has_last_recallable_consumable_id: bool = false
var has_base_hand_limit_modifier: bool = false
var has_hand_technique_multiplier_modifiers: bool = false
var has_used_unique_consumable_ids: bool = false
var has_passive_counter_state: bool = false
var has_source_behavior_transformation_state: bool = false
var has_run_combat_history_state: bool = false

static func from_dict(values: Dictionary) -> RunProgressSnapshot:
    var result := RunProgressSnapshot.new()
    result.has_consumable_ids = values.has("consumable_ids")
    result.has_item_ids = values.has("item_ids")
    result.has_learned_technique_ids = values.has("learned_technique_ids")
    result.has_learned_inner_skill_ids = values.has("learned_inner_skill_ids")
    result.has_equipped_inner_skill_ids = values.has("equipped_inner_skill_ids")
    result.has_technique_slot_index = values.has("technique_slot_index")
    result.has_forgotten_inner_skill_count = values.has(
        "forgotten_inner_skill_count")
    result.has_run_deck = values.has("run_deck")
    result.has_life = values.has("life")
    result.has_max_life = values.has("max_life")
    result.has_base_max_life = values.has("base_max_life")
    result.has_source_marker_state = values.has("source_marker_state")
    result.has_experience = values.has("experience")
    result.has_free_meditation_charge = values.has("free_meditation_charge")
    result.has_experience_operation_receipts = values.has(
        "experience_operation_receipts")
    result.has_consumable_capacity = values.has("consumable_capacity")
    result.has_consumable_overflow_count = values.has(
        "consumable_overflow_count")
    result.has_hand_technique_progression = values.has("hand_technique_progression")
    result.has_practice_shop_state = values.has("practice_shop_state")
    result.has_consumable_use_sequence = values.has("consumable_use_sequence")
    result.has_last_recallable_consumable_id = values.has(
        "last_recallable_consumable_id")
    result.has_base_hand_limit_modifier = values.has(
        "base_hand_limit_modifier")
    result.has_hand_technique_multiplier_modifiers = values.has(
        "hand_technique_multiplier_modifiers")
    result.has_used_unique_consumable_ids = values.has(
        "used_unique_consumable_ids")
    result.has_passive_counter_state = values.has("passive_counter_state")
    result.has_source_behavior_transformation_state = values.has(
        "source_behavior_transformation_state")
    result.has_run_combat_history_state = values.has(
        "run_combat_history_state")

    for consumable_id in values.get("consumable_ids", []):
        result.consumable_ids.append(str(consumable_id))
    for item_id in values.get("item_ids", []):
        result.item_ids.append(str(item_id))
    for technique_id in values.get("learned_technique_ids", []):
        result.learned_technique_ids.append(str(technique_id))
    for inner_skill_id in values.get("learned_inner_skill_ids", []):
        result.learned_inner_skill_ids.append(str(inner_skill_id))
    for inner_skill_id in values.get("equipped_inner_skill_ids", []):
        result.equipped_inner_skill_ids.append(str(inner_skill_id))
    result.technique_slot_index = int(values.get("technique_slot_index", 0))
    result.forgotten_inner_skill_count = int(values.get(
        "forgotten_inner_skill_count", 0))
    result.run_deck = values.get("run_deck", {}).duplicate(true)
    result.life = int(values.get("life", 0))
    result.max_life = int(values.get("max_life", 0))
    result.base_max_life = int(values.get(
        "base_max_life", values.get("max_life", 0)))
    result.source_marker_state = values.get(
        "source_marker_state", {}).duplicate(true)
    result.experience = int(values.get("experience", 0))
    result.free_meditation_charge = clampi(int(values.get(
        "free_meditation_charge", 0)), 0, 1)
    result.experience_operation_receipts = values.get(
        "experience_operation_receipts", {}).duplicate(true)
    result.consumable_capacity = maxi(0, int(values.get(
        "consumable_capacity", 2)))
    result.consumable_overflow_count = maxi(0, int(values.get(
        "consumable_overflow_count", 0)))
    result.hand_technique_progression = values.get(
        "hand_technique_progression", {}).duplicate(true)
    result.practice_shop_state = _normalized_practice_shop_state(
        values.get("practice_shop_state", {}))
    result.consumable_use_sequence = int(values.get("consumable_use_sequence", 0))
    result.last_recallable_consumable_id = str(values.get(
        "last_recallable_consumable_id", ""))
    result.base_hand_limit_modifier = int(values.get(
        "base_hand_limit_modifier", 0))
    result.hand_technique_multiplier_modifiers = values.get(
        "hand_technique_multiplier_modifiers", {}).duplicate(true)
    for consumable_id in values.get("used_unique_consumable_ids", []):
        result.used_unique_consumable_ids.append(str(consumable_id))
    result.passive_counter_state = values.get(
        "passive_counter_state", {}).duplicate(true)
    result.source_behavior_transformation_state = values.get(
        "source_behavior_transformation_state", {}).duplicate(true)
    result.run_combat_history_state = values.get(
        "run_combat_history_state", {}).duplicate(true)
    return result

func to_dict() -> Dictionary:
    var result := {"schema_version": SCHEMA_VERSION}
    if has_consumable_ids:
        result["consumable_ids"] = consumable_ids.duplicate()
    if has_item_ids:
        result["item_ids"] = item_ids.duplicate()
    if has_learned_technique_ids:
        result["learned_technique_ids"] = learned_technique_ids.duplicate()
    if has_learned_inner_skill_ids:
        result["learned_inner_skill_ids"] = learned_inner_skill_ids.duplicate()
    if has_equipped_inner_skill_ids:
        result["equipped_inner_skill_ids"] = equipped_inner_skill_ids.duplicate()
    if has_technique_slot_index:
        result["technique_slot_index"] = technique_slot_index
    if has_forgotten_inner_skill_count:
        result["forgotten_inner_skill_count"] = forgotten_inner_skill_count
    if has_run_deck:
        result["run_deck"] = run_deck.duplicate(true)
    if has_life:
        result["life"] = life
    if has_max_life:
        result["max_life"] = max_life
    if has_base_max_life:
        result["base_max_life"] = base_max_life
    if has_source_marker_state:
        result["source_marker_state"] = source_marker_state.duplicate(true)
    if has_experience:
        result["experience"] = experience
    if has_free_meditation_charge:
        result["free_meditation_charge"] = free_meditation_charge
    if has_experience_operation_receipts:
        result["experience_operation_receipts"] = (
            experience_operation_receipts.duplicate(true))
    if has_consumable_capacity:
        result["consumable_capacity"] = consumable_capacity
    if has_consumable_overflow_count:
        result["consumable_overflow_count"] = consumable_overflow_count
    if has_hand_technique_progression:
        result["hand_technique_progression"] = hand_technique_progression.duplicate(true)
    if has_practice_shop_state:
        result["practice_shop_state"] = _normalized_practice_shop_state(
            practice_shop_state)
    if has_consumable_use_sequence:
        result["consumable_use_sequence"] = consumable_use_sequence
    if has_last_recallable_consumable_id:
        result["last_recallable_consumable_id"] = last_recallable_consumable_id
    if has_base_hand_limit_modifier:
        result["base_hand_limit_modifier"] = base_hand_limit_modifier
    if has_hand_technique_multiplier_modifiers:
        result["hand_technique_multiplier_modifiers"] = (
            hand_technique_multiplier_modifiers.duplicate(true))
    if has_used_unique_consumable_ids:
        result["used_unique_consumable_ids"] = used_unique_consumable_ids.duplicate()
    if has_passive_counter_state:
        result["passive_counter_state"] = passive_counter_state.duplicate(true)
    if has_source_behavior_transformation_state:
        result["source_behavior_transformation_state"] = (
            source_behavior_transformation_state.duplicate(true))
    if has_run_combat_history_state:
        result["run_combat_history_state"] = (
            run_combat_history_state.duplicate(true))
    return result

static func _normalized_practice_shop_state(value: Dictionary) -> Dictionary:
    var result := value.duplicate(true)
    if not result.has("items") and result.has("coupons"):
        result["items"] = result["coupons"]
    if not result.has("item_candidates") and result.has("coupon_candidates"):
        result["item_candidates"] = result["coupon_candidates"]
    if not result.has("item_slots") and result.has("coupon_slots"):
        result["item_slots"] = result["coupon_slots"]
    result.erase("coupons")
    result.erase("coupon_candidates")
    result.erase("coupon_slots")
    return result
