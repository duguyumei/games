class_name BattleSide
extends RefCounted

const DamageResolverScript = preload("res://core/damage_resolver.gd")
const CardZoneServiceScript = preload("res://core/card_zone_service.gd")
const InnerSkillCapacityPolicyScript = preload(
    "res://core/passives/inner_skill_capacity_policy.gd")

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]

var name: String
var owner_id: String
var max_life: int = 100
var life: int = 100
var defense: int = 0
var experience: int = 0
var hand_limit: int = 8
var base_hand_limit_modifier: int = 0
var direct_power_fixed: int = 0
var direct_power_percent: int = 0
var momentum_value: int = 0
var last_successful_technique_hand_id: String = ""
var current_reflection_percent: int = 0
var draw_pile: Array = []
var hand: Array = []
var staging: Array = []
var discard_pile: Array = []
var temporarily_removed_cards: Array = []
var equipped_inner_skill_ids: Array[String] = []
var item_ids: Array[String] = []
var technique_slot_index: int = 0
var consumable_ids: Array[String] = []
var consumable_limit: int = 3
var hand_proficiency_fixed: Dictionary = {}
var hand_technique_progression: Dictionary = {}
var hand_technique_progression_active: bool = false
var hand_technique_multiplier_modifiers: Dictionary = {}
var owned_technique_ids: Array[String] = []
var permanently_removed_card_ids: Array[String] = []
var card_state_lifecycle
var status_system
var card_zone_service := CardZoneServiceScript.new()
var passive_rule_runtime = null

func _init(side_name: String = "", stable_owner_id: String = "") -> void:
    name = side_name
    owner_id = stable_owner_id if stable_owner_id != "" else side_name

func use_card_state_lifecycle(lifecycle) -> void:
    card_state_lifecycle = lifecycle
    card_zone_service.use_card_state_lifecycle(lifecycle)

func use_status_system(system) -> void:
    status_system = system
    card_zone_service.use_status_system(system)

func use_card_reshape_runtime(runtime) -> void:
    card_zone_service.use_card_reshape_runtime(runtime)

func use_passive_rule_runtime(runtime) -> void:
    passive_rule_runtime = runtime

func reset(
        cards: Array,
        rng: RandomNumberGenerator,
        shuffle_cards: bool = true,
        restore_life: bool = true) -> void:
    if restore_life:
        life = max_life
    defense = 0
    experience = 0
    hand_limit = 8
    base_hand_limit_modifier = 0
    direct_power_fixed = 0
    direct_power_percent = 0
    momentum_value = 0
    last_successful_technique_hand_id = ""
    current_reflection_percent = 0
    equipped_inner_skill_ids.clear()
    item_ids.clear()
    technique_slot_index = 0
    consumable_ids.clear()
    consumable_limit = 3
    hand_proficiency_fixed.clear()
    hand_technique_progression.clear()
    hand_technique_progression_active = false
    hand_technique_multiplier_modifiers.clear()
    owned_technique_ids.clear()
    permanently_removed_card_ids.clear()
    card_zone_service.reset_zones(self, cards, rng, shuffle_cards)

func replace_deck(cards: Array, rng: RandomNumberGenerator, shuffle_cards: bool = true) -> void:
    card_zone_service.reset_zones(self, cards, rng, shuffle_cards)

func all_zone_cards() -> Array:
    var cards: Array = []
    for zone in [draw_pile, hand, staging, discard_pile]:
        cards.append_array(zone)
    return cards

func all_cards_for_run_sync() -> Array:
    var cards := all_zone_cards()
    cards.append_array(temporarily_removed_cards)
    return cards

func mark_permanently_removed(instance_id: String) -> void:
    if instance_id != "" and not permanently_removed_card_ids.has(instance_id):
        permanently_removed_card_ids.append(instance_id)

func _shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
    card_zone_service.shuffle(cards, rng)

func draw(count: int) -> Array:
    return card_zone_service.draw(self, count)

func draw_to_limit() -> Array:
    var limit := current_hand_limit()
    if hand.size() >= limit:
        return []
    return draw(limit - hand.size())

func current_hand_limit() -> int:
    return maxi(
        1,
        hand_limit
        + base_hand_limit_modifier)

func stage_cards(card_ids: Array) -> bool:
    return card_zone_service.stage_cards(self, card_ids)

func rollback_staging() -> Array:
    return card_zone_service.rollback_staging(self)

func find_hand_card(card_id: String):
    for card in hand:
        if card.id == card_id:
            return card
    return null

func resolve_hand_definition_ids(definition_ids: Array) -> Array[String]:
    var resolved: Array[String] = []
    var used: Dictionary = {}
    for definition_id in definition_ids:
        for card in hand:
            var current_definition_id: String = card.current_definition_id() \
                if card.has_method("current_definition_id") else str(card.definition_id)
            if used.has(card.id) or current_definition_id != str(definition_id):
                continue
            used[card.id] = true
            resolved.append(str(card.id))
            break
    return resolved

func commit_staging() -> Array:
    return card_zone_service.commit_staging(self)

func commit_selected_staging(cards: Array) -> Array:
    return card_zone_service.commit_selected_staging(self, cards)

func count_anomaly_in_zone(zone: String, category: String, anomaly_id: String) -> int:
    var cards: Array = []
    match zone:
        "hand": cards = hand
        "draw_pile": cards = draw_pile
        "staging": cards = staging
        "discard_pile": cards = discard_pile
    var count := 0
    for card in cards:
        if card.has_anomaly(category, anomaly_id):
            count += 1
    return count

func random_discard(count: int, rng: RandomNumberGenerator) -> Array:
    return card_zone_service.random_discard(self, count, rng)

func discard_all() -> Array:
    return card_zone_service.discard_all(self)

func recover_from_discard(count: int, destination: String = "draw_pile") -> Array:
    return card_zone_service.recover_from_discard(self, count, destination)

func temporarily_remove_card(instance_id: String, reason: String = "burn") -> Dictionary:
    return card_zone_service.temporarily_remove(self, instance_id, reason)

func permanently_remove_card(instance_id: String, reason: String = "permanent_remove") -> Dictionary:
    return card_zone_service.permanently_remove(self, instance_id, reason)

func add_generated_card(card, destination: String, temporary: bool) -> Dictionary:
    return card_zone_service.add_generated(self, card, destination, temporary)

func temporarily_transfer_card_to(
        target_side,
        instance_id: String,
        destination: String = "draw_pile") -> Dictionary:
    return card_zone_service.temporarily_transfer(
        self, target_side, instance_id, destination)

func return_transferred_card_to(
        original_side,
        instance_id: String,
        destination: String = "draw_pile") -> Dictionary:
    return card_zone_service.return_transferred(
        self, original_side, instance_id, destination)

func add_defense(amount: int) -> int:
    var gained := maxi(0, amount)
    defense += gained
    return gained

func add_momentum(amount: int) -> int:
    var before := momentum_value
    momentum_value = maxi(0, momentum_value + amount)
    return momentum_value - before

func set_momentum(value: int) -> int:
    momentum_value = maxi(0, value)
    return momentum_value

func set_reflection_percent(value: int) -> int:
    current_reflection_percent = maxi(0, value)
    return current_reflection_percent

func configure_inner_skills(
        inner_skill_ids: Array,
        dynamic_technique_slot: int = 0) -> Dictionary:
    var normalized: Array[String] = []
    for value in inner_skill_ids:
        if not value is String or str(value).strip_edges() == "":
            return {"success": false, "reason": "内功装配不能包含空 ID"}
        var content_id := str(value)
        if passive_rule_runtime != null \
                and not passive_rule_runtime.has_content("inner_skill", content_id):
            return {"success": false, "reason": "未知内功：%s" % content_id}
        normalized.append(content_id)
    var capacity := {
        "base_capacity": InnerSkillCapacityPolicyScript.BASE_INNER_SKILL_CAPACITY,
        "effective_capacity": InnerSkillCapacityPolicyScript.BASE_INNER_SKILL_CAPACITY,
        "modifiers": [],
        "errors": [],
    }
    if passive_rule_runtime != null:
        capacity = passive_rule_runtime.resolve_inner_skill_capacity(self, normalized)
    if not capacity.get("errors", []).is_empty():
        return {
            "success": false,
            "reason": "内功容量查询失败：%s" % "；".join(capacity["errors"]),
        }
    if normalized.size() > int(capacity.get("effective_capacity", 0)):
        return {
            "success": false,
            "reason": "内功有效容量为 %d，不能装备 %d 门" % [
                int(capacity.get("effective_capacity", 0)), normalized.size()],
        }
    if dynamic_technique_slot < 0 or dynamic_technique_slot > normalized.size():
        return {
            "success": false,
            "reason": "technique_slot_index 必须位于 0～装备数量之间",
        }
    equipped_inner_skill_ids.assign(normalized)
    technique_slot_index = dynamic_technique_slot
    return {
        "success": true,
        "equipped_inner_skill_ids": normalized.duplicate(),
        "technique_slot_index": technique_slot_index,
        "capacity": capacity,
    }

func configure_items(ids: Array) -> Dictionary:
    var normalized: Array[String] = []
    var seen: Dictionary = {}
    for value in ids:
        if not value is String or str(value).strip_edges() == "":
            return {"success": false, "reason": "物品装配不能包含空 ID"}
        var content_id := str(value)
        if seen.has(content_id):
            return {"success": false, "reason": "物品 ID 重复：%s" % content_id}
        if passive_rule_runtime != null \
                and not passive_rule_runtime.has_content("item", content_id):
            return {"success": false, "reason": "未知物品：%s" % content_id}
        seen[content_id] = true
        normalized.append(content_id)
    item_ids.assign(normalized)
    return {"success": true, "item_ids": normalized.duplicate()}

func configure_consumables(ids: Array) -> void:
    consumable_ids.clear()
    for consumable_id in ids.slice(0, consumable_limit):
        consumable_ids.append(str(consumable_id))

func grant_consumable(consumable_id: String) -> bool:
    if consumable_ids.size() >= consumable_limit:
        return false
    consumable_ids.append(consumable_id)
    return true

func consume_at(slot_index: int) -> String:
    if slot_index < 0 or slot_index >= consumable_ids.size():
        return ""
    return consumable_ids.pop_at(slot_index)

func apply_insight_growth(
        hand_id: String,
        candidates: Array = [],
        rng: RandomNumberGenerator = null) -> Dictionary:
    if not HAND_IDS.has(hand_id):
        return {"success": false, "reason": "未知牌型：%s" % hand_id}
    var progression: Dictionary = hand_technique_progression.get(hand_id, {
        "slot_count": 1,
        "sequence": [],
    }).duplicate(true)
    var before := int(progression.get("slot_count", 1))
    progression["slot_count"] = before + 1
    var sequence: Array = progression.get("sequence", []).duplicate()
    var available: Array[String] = []
    for candidate_value in candidates:
        var candidate := str(candidate_value)
        if candidate != "" and not sequence.has(candidate) and not available.has(candidate):
            available.append(candidate)
    available.sort()
    var acquired := ""
    if not available.is_empty():
        var index := rng.randi_range(0, available.size() - 1) if rng != null else 0
        acquired = available[index]
        sequence.append(acquired)
        learn_technique(acquired)
    progression["sequence"] = sequence
    hand_technique_progression[hand_id] = progression
    return {
        "success": true,
        "slot_count_before": before,
        "slot_count_after": before + 1,
        "acquired_technique_id": acquired,
        "no_technique_available": acquired == "",
    }

func learn_technique(technique_id: String) -> bool:
    if technique_id == "" or owned_technique_ids.has(technique_id):
        return false
    owned_technique_ids.append(technique_id)
    return true

func combat_source_order(inner_skill_index: int) -> int:
    return inner_skill_index if inner_skill_index < technique_slot_index else inner_skill_index + 1

func receive_damage(amount: int, true_damage: bool = false) -> Dictionary:
    return DamageResolverScript.apply_to_target(self, amount, true_damage)
