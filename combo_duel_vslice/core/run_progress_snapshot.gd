class_name RunProgressSnapshot
extends RefCounted

## 本局成长数据在成长库存、战斗会话与存档之间的传输边界。
##
## 快照允许只携带部分字段：战斗只回传它实际拥有的数据，成长库存只更新
## `has_*` 为真的字段。这里故意不把缺失字段解释为空值，避免局部同步清空
## 仅由本局系统持有的内功与功法位状态。

const SCHEMA_VERSION := 1

var consumable_ids: Array[String] = []
var insight_multipliers: Dictionary = {}
var learned_technique_ids: Array[String] = []
var learned_inner_skill_ids: Array[String] = []
var equipped_inner_skill_ids: Array[String] = []
var technique_slot_index: int = 0
var run_deck: Dictionary = {}

var has_consumable_ids: bool = false
var has_insight_multipliers: bool = false
var has_learned_technique_ids: bool = false
var has_learned_inner_skill_ids: bool = false
var has_equipped_inner_skill_ids: bool = false
var has_technique_slot_index: bool = false
var has_run_deck: bool = false

static func from_dict(values: Dictionary) -> RunProgressSnapshot:
    var result := RunProgressSnapshot.new()
    result.has_consumable_ids = values.has("consumable_ids")
    result.has_insight_multipliers = values.has("insight_multipliers")
    result.has_learned_technique_ids = values.has("learned_technique_ids")
    result.has_learned_inner_skill_ids = values.has("learned_inner_skill_ids")
    result.has_equipped_inner_skill_ids = values.has("equipped_inner_skill_ids")
    result.has_technique_slot_index = values.has("technique_slot_index")
    result.has_run_deck = values.has("run_deck")

    for consumable_id in values.get("consumable_ids", []):
        result.consumable_ids.append(str(consumable_id))
    result.insight_multipliers = values.get(
        "insight_multipliers", {}).duplicate(true)
    for technique_id in values.get("learned_technique_ids", []):
        result.learned_technique_ids.append(str(technique_id))
    for inner_skill_id in values.get("learned_inner_skill_ids", []):
        result.learned_inner_skill_ids.append(str(inner_skill_id))
    for inner_skill_id in values.get("equipped_inner_skill_ids", []):
        result.equipped_inner_skill_ids.append(str(inner_skill_id))
    result.technique_slot_index = int(values.get("technique_slot_index", 0))
    result.run_deck = values.get("run_deck", {}).duplicate(true)
    return result

func to_dict() -> Dictionary:
    var result := {"schema_version": SCHEMA_VERSION}
    if has_consumable_ids:
        result["consumable_ids"] = consumable_ids.duplicate()
    if has_insight_multipliers:
        result["insight_multipliers"] = insight_multipliers.duplicate(true)
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
    return result
