class_name RunProgressSnapshot
extends RefCounted

## 本局成长数据在成长库存、战斗会话与存档之间的传输边界。
##
## 快照允许只携带部分字段：战斗只回传它实际拥有的数据，成长库存只更新
## `has_*` 为真的字段。这里故意不把缺失字段解释为空值，避免局部同步清空
## 仅由本局系统持有的内功与功法位状态。

const SCHEMA_VERSION := 1

var consumable_ids: Array[String] = []
var learned_technique_ids: Array[String] = []
var learned_inner_skill_ids: Array[String] = []
var equipped_inner_skill_ids: Array[String] = []
var technique_slot_index: int = 0
var run_deck: Dictionary = {}
var life: int = 0
var max_life: int = 0
var experience: int = 0
var hand_technique_progression: Dictionary = {}
var practice_shop_state: Dictionary = {}
var consumable_use_sequence: int = 0
var last_recallable_consumable_id: String = ""

var has_consumable_ids: bool = false
var has_learned_technique_ids: bool = false
var has_learned_inner_skill_ids: bool = false
var has_equipped_inner_skill_ids: bool = false
var has_technique_slot_index: bool = false
var has_run_deck: bool = false
var has_life: bool = false
var has_max_life: bool = false
var has_experience: bool = false
var has_hand_technique_progression: bool = false
var has_practice_shop_state: bool = false
var has_consumable_use_sequence: bool = false
var has_last_recallable_consumable_id: bool = false

static func from_dict(values: Dictionary) -> RunProgressSnapshot:
    var result := RunProgressSnapshot.new()
    result.has_consumable_ids = values.has("consumable_ids")
    result.has_learned_technique_ids = values.has("learned_technique_ids")
    result.has_learned_inner_skill_ids = values.has("learned_inner_skill_ids")
    result.has_equipped_inner_skill_ids = values.has("equipped_inner_skill_ids")
    result.has_technique_slot_index = values.has("technique_slot_index")
    result.has_run_deck = values.has("run_deck")
    result.has_life = values.has("life")
    result.has_max_life = values.has("max_life")
    result.has_experience = values.has("experience")
    result.has_hand_technique_progression = values.has("hand_technique_progression")
    result.has_practice_shop_state = values.has("practice_shop_state")
    result.has_consumable_use_sequence = values.has("consumable_use_sequence")
    result.has_last_recallable_consumable_id = values.has(
        "last_recallable_consumable_id")

    for consumable_id in values.get("consumable_ids", []):
        result.consumable_ids.append(str(consumable_id))
    for technique_id in values.get("learned_technique_ids", []):
        result.learned_technique_ids.append(str(technique_id))
    for inner_skill_id in values.get("learned_inner_skill_ids", []):
        result.learned_inner_skill_ids.append(str(inner_skill_id))
    for inner_skill_id in values.get("equipped_inner_skill_ids", []):
        result.equipped_inner_skill_ids.append(str(inner_skill_id))
    result.technique_slot_index = int(values.get("technique_slot_index", 0))
    result.run_deck = values.get("run_deck", {}).duplicate(true)
    result.life = int(values.get("life", 0))
    result.max_life = int(values.get("max_life", 0))
    result.experience = int(values.get("experience", 0))
    result.hand_technique_progression = values.get(
        "hand_technique_progression", {}).duplicate(true)
    result.practice_shop_state = values.get(
        "practice_shop_state", {}).duplicate(true)
    result.consumable_use_sequence = int(values.get("consumable_use_sequence", 0))
    result.last_recallable_consumable_id = str(values.get(
        "last_recallable_consumable_id", ""))
    return result

func to_dict() -> Dictionary:
    var result := {"schema_version": SCHEMA_VERSION}
    if has_consumable_ids:
        result["consumable_ids"] = consumable_ids.duplicate()
    if has_learned_technique_ids:
        result["learned_technique_ids"] = learned_technique_ids.duplicate()
    if has_learned_inner_skill_ids:
        result["learned_inner_skill_ids"] = learned_inner_skill_ids.duplicate()
    if has_equipped_inner_skill_ids:
        result["equipped_inner_skill_ids"] = equipped_inner_skill_ids.duplicate()
    if has_technique_slot_index:
        result["technique_slot_index"] = technique_slot_index
    if has_run_deck:
        result["run_deck"] = run_deck.duplicate(true)
    if has_life:
        result["life"] = life
    if has_max_life:
        result["max_life"] = max_life
    if has_experience:
        result["experience"] = experience
    if has_hand_technique_progression:
        result["hand_technique_progression"] = hand_technique_progression.duplicate(true)
    if has_practice_shop_state:
        result["practice_shop_state"] = practice_shop_state.duplicate(true)
    if has_consumable_use_sequence:
        result["consumable_use_sequence"] = consumable_use_sequence
    if has_last_recallable_consumable_id:
        result["last_recallable_consumable_id"] = last_recallable_consumable_id
    return result
