class_name BattleSideSnapshot
extends RefCounted

## 一方参战者的只读快照。
##
## 字段是显式声明的，不通过 `get(key, default)` 读取：键名写错会在解析期暴露，
## 而不是在界面上表现为 0 或空列表。
##
## 牌面、消耗品、内功等列表保持 Array 形态，因为它们的元素契约由各自的内容
## 校验负责；这里只保证顶层字段存在且类型正确。

const SCHEMA_VERSION := 12

var name: String = ""
var experience: int = 0
var life: int = 0
var max_life: int = 0
var base_max_life: int = 0
var defense: int = 0
var direct_power_fixed: int = 0
var direct_power_percent: int = 0
var momentum_value: int = 0
var momentum_cap: int = 0
var same_qi_value: int = 0
var same_qi_capacity: int = 5
var last_successful_technique_hand_id: String = ""
var current_reflection_percent: int = 0
var reflection_sources: Array = []
var reflection_true_damage_sources: Array = []
var block_sources: Array = []
var deflection_sources: Array = []
var challenge_records: Array = []
var hand_limit: int = 0
var base_hand_limit: int = 0
var inner_skill_limit: int = 0
var draw_count: int = 0
var hand_count: int = 0
var occupied_meridian_count: int = 0
var staging_count: int = 0
var discard_count: int = 0
var deck_count: int = 0
var temporarily_removed_count: int = 0
var poison_hand_count: int = 0
var poison_hand_amount: int = 0
var poison_draw_pile_count: int = 0
var poison_draw_pile_amount: int = 0
var poison_total_count: int = 0
var poison_total_amount: int = 0
var draw_pile: Array = []
var hand: Array = []
var staging: Array = []
var discard_pile: Array = []
var temporarily_removed: Array = []
var learned_inner_skill_ids: Array = []
var equipped_inner_skill_ids: Array = []
var equipped_inner_skills: Array = []
var technique_slot_index: int = 0
var forgotten_inner_skill_count: int = 0
var item_ids: Array = []
var consumable_ids: Array = []
var consumables: Array = []
var consumable_limit: int = 0
var hand_proficiency_fixed: Dictionary = {}
var hand_technique_progression: Dictionary = {}
var owned_technique_ids: Array = []
var technique_sequences: Dictionary = {}
var technique_slot_usage: Dictionary = {}
var charging_techniques: Array = []
var public_source_markers: Array = []
var poison_damage_modifier_sources: Array = []

## 从战斗会话产出的字典构建。
##
## 缺字段视为装配错误并报错，而不是静默使用零值：参战者快照的字段集合由
## `BattleSession._side_snapshot()` 唯一决定，缺失只可能是两侧不同步。
static func from_dict(values: Dictionary) -> BattleSideSnapshot:
    var result := BattleSideSnapshot.new()
    var missing: Array[String] = []
    for required in [
            "name", "experience", "life", "max_life", "base_max_life",
            "defense", "hand_limit",
            "base_hand_limit",
            "direct_power_fixed", "direct_power_percent", "momentum_value",
            "momentum_cap",
            "same_qi_value", "same_qi_capacity",
            "last_successful_technique_hand_id", "current_reflection_percent",
            "reflection_sources", "reflection_true_damage_sources",
            "block_sources", "deflection_sources", "challenge_records",
            "inner_skill_limit",
            "draw_count", "hand_count", "occupied_meridian_count", "staging_count", "discard_count",
            "deck_count", "temporarily_removed_count",
            "poison_hand_count", "poison_hand_amount",
            "poison_draw_pile_count", "poison_draw_pile_amount",
            "poison_total_count", "poison_total_amount",
            "technique_slot_index", "forgotten_inner_skill_count",
            "consumable_limit",
            "technique_slot_usage", "charging_techniques"]:
        if not values.has(required):
            missing.append(str(required))
    if not missing.is_empty():
        push_error("参战者快照缺少字段：%s" % ", ".join(missing))

    result.name = str(values.get("name", ""))
    result.experience = int(values.get("experience", 0))
    result.life = int(values.get("life", 0))
    result.max_life = int(values.get("max_life", 0))
    result.base_max_life = int(values.get("base_max_life", 0))
    result.defense = int(values.get("defense", 0))
    result.direct_power_fixed = int(values.get("direct_power_fixed", 0))
    result.direct_power_percent = int(values.get("direct_power_percent", 0))
    result.momentum_value = int(values.get("momentum_value", 0))
    result.momentum_cap = int(values.get("momentum_cap", 0))
    result.same_qi_value = int(values.get("same_qi_value", 0))
    result.same_qi_capacity = int(values.get("same_qi_capacity", 5))
    result.last_successful_technique_hand_id = str(
        values.get("last_successful_technique_hand_id", ""))
    result.current_reflection_percent = int(
        values.get("current_reflection_percent", 0))
    result.reflection_sources = values.get(
        "reflection_sources", []).duplicate(true)
    result.reflection_true_damage_sources = values.get(
        "reflection_true_damage_sources", []).duplicate(true)
    result.block_sources = values.get("block_sources", []).duplicate(true)
    result.deflection_sources = values.get(
        "deflection_sources", []).duplicate(true)
    result.challenge_records = values.get(
        "challenge_records", []).duplicate(true)
    result.hand_limit = int(values.get("hand_limit", 0))
    result.base_hand_limit = int(values.get("base_hand_limit", 0))
    result.inner_skill_limit = int(values.get("inner_skill_limit", 0))
    result.draw_count = int(values.get("draw_count", 0))
    result.hand_count = int(values.get("hand_count", 0))
    result.occupied_meridian_count = int(values.get("occupied_meridian_count", 0))
    result.staging_count = int(values.get("staging_count", 0))
    result.discard_count = int(values.get("discard_count", 0))
    result.deck_count = int(values.get("deck_count", 0))
    result.temporarily_removed_count = int(values.get("temporarily_removed_count", 0))
    result.poison_hand_count = int(values.get("poison_hand_count", 0))
    result.poison_hand_amount = int(values.get("poison_hand_amount", 0))
    result.poison_draw_pile_count = int(values.get("poison_draw_pile_count", 0))
    result.poison_draw_pile_amount = int(values.get("poison_draw_pile_amount", 0))
    result.poison_total_count = int(values.get("poison_total_count", 0))
    result.poison_total_amount = int(values.get("poison_total_amount", 0))
    result.draw_pile = values.get("draw_pile", []).duplicate(true)
    result.hand = values.get("hand", []).duplicate(true)
    result.staging = values.get("staging", []).duplicate(true)
    result.discard_pile = values.get("discard_pile", []).duplicate(true)
    result.temporarily_removed = values.get("temporarily_removed", []).duplicate(true)
    result.learned_inner_skill_ids = values.get(
        "learned_inner_skill_ids", []).duplicate(true)
    result.equipped_inner_skill_ids = values.get("equipped_inner_skill_ids", []).duplicate(true)
    result.equipped_inner_skills = values.get("equipped_inner_skills", []).duplicate(true)
    result.technique_slot_index = int(values.get("technique_slot_index", 0))
    result.forgotten_inner_skill_count = int(values.get(
        "forgotten_inner_skill_count", 0))
    result.item_ids = values.get("item_ids", []).duplicate(true)
    result.consumable_ids = values.get("consumable_ids", []).duplicate(true)
    result.consumables = values.get("consumables", []).duplicate(true)
    result.consumable_limit = int(values.get("consumable_limit", 0))
    result.hand_proficiency_fixed = values.get("hand_proficiency_fixed", {}).duplicate(true)
    result.hand_technique_progression = values.get("hand_technique_progression", {}).duplicate(true)
    result.owned_technique_ids = values.get("owned_technique_ids", []).duplicate(true)
    result.technique_sequences = values.get("technique_sequences", {}).duplicate(true)
    result.technique_slot_usage = values.get(
        "technique_slot_usage", {}).duplicate(true)
    result.charging_techniques = values.get(
        "charging_techniques", []).duplicate(true)
    result.public_source_markers = values.get(
        "public_source_markers", []).duplicate(true)
    result.poison_damage_modifier_sources = values.get(
        "poison_damage_modifier_sources", []).duplicate(true)
    return result

## 序列化边界。存档、AI 传输和既有测试断言使用。
func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "name": name,
        "experience": experience,
        "life": life,
        "max_life": max_life,
        "base_max_life": base_max_life,
        "defense": defense,
        "direct_power_fixed": direct_power_fixed,
        "direct_power_percent": direct_power_percent,
        "momentum_value": momentum_value,
        "momentum_cap": momentum_cap,
        "same_qi_value": same_qi_value,
        "same_qi_capacity": same_qi_capacity,
        "last_successful_technique_hand_id": last_successful_technique_hand_id,
        "current_reflection_percent": current_reflection_percent,
        "reflection_sources": reflection_sources.duplicate(true),
        "reflection_true_damage_sources": reflection_true_damage_sources.duplicate(true),
        "block_sources": block_sources.duplicate(true),
        "deflection_sources": deflection_sources.duplicate(true),
        "challenge_records": challenge_records.duplicate(true),
        "hand_limit": hand_limit,
        "base_hand_limit": base_hand_limit,
        "inner_skill_limit": inner_skill_limit,
        "draw_count": draw_count,
        "hand_count": hand_count,
        "occupied_meridian_count": occupied_meridian_count,
        "staging_count": staging_count,
        "discard_count": discard_count,
        "deck_count": deck_count,
        "temporarily_removed_count": temporarily_removed_count,
        "poison_hand_count": poison_hand_count,
        "poison_hand_amount": poison_hand_amount,
        "poison_draw_pile_count": poison_draw_pile_count,
        "poison_draw_pile_amount": poison_draw_pile_amount,
        "poison_total_count": poison_total_count,
        "poison_total_amount": poison_total_amount,
        "draw_pile": draw_pile.duplicate(true),
        "hand": hand.duplicate(true),
        "staging": staging.duplicate(true),
        "discard_pile": discard_pile.duplicate(true),
        "temporarily_removed": temporarily_removed.duplicate(true),
        "learned_inner_skill_ids": learned_inner_skill_ids.duplicate(true),
        "equipped_inner_skill_ids": equipped_inner_skill_ids.duplicate(true),
        "equipped_inner_skills": equipped_inner_skills.duplicate(true),
        "technique_slot_index": technique_slot_index,
        "forgotten_inner_skill_count": forgotten_inner_skill_count,
        "item_ids": item_ids.duplicate(true),
        "consumable_ids": consumable_ids.duplicate(true),
        "consumables": consumables.duplicate(true),
        "consumable_limit": consumable_limit,
        "hand_proficiency_fixed": hand_proficiency_fixed.duplicate(true),
        "hand_technique_progression": hand_technique_progression.duplicate(true),
        "owned_technique_ids": owned_technique_ids.duplicate(true),
        "technique_sequences": technique_sequences.duplicate(true),
        "technique_slot_usage": technique_slot_usage.duplicate(true),
        "charging_techniques": charging_techniques.duplicate(true),
        "public_source_markers": public_source_markers.duplicate(true),
        "poison_damage_modifier_sources": poison_damage_modifier_sources.duplicate(true),
    }
