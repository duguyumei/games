class_name BattleSide
extends RefCounted

const DamageResolverScript = preload("res://core/damage_resolver.gd")
const CardZoneServiceScript = preload("res://core/card_zone_service.gd")

var name: String
var owner_id: String
var max_life: int = 100
var life: int = 100
var defense: int = 0
var hand_limit: int = 8
var draw_pile: Array = []
var hand: Array = []
var staging: Array = []
var discard_pile: Array = []
var temporarily_removed_cards: Array = []
var stacks: Dictionary = {}
var equipped_inner_skill_ids: Array[String] = []
var technique_slot_index: int = 0
var consumable_ids: Array[String] = []
var consumable_limit: int = 3
var insight_multipliers: Dictionary = {}
var owned_technique_ids: Array[String] = []
var permanently_removed_card_ids: Array[String] = []
var card_state_lifecycle
var status_system
var card_zone_service := CardZoneServiceScript.new()

func _init(side_name: String = "", stable_owner_id: String = "") -> void:
    name = side_name
    owner_id = stable_owner_id if stable_owner_id != "" else side_name

func use_card_state_lifecycle(lifecycle) -> void:
    card_state_lifecycle = lifecycle
    card_zone_service.use_card_state_lifecycle(lifecycle)

func use_status_system(system) -> void:
    status_system = system
    card_zone_service.use_status_system(system)

func reset(cards: Array, rng: RandomNumberGenerator, shuffle_cards: bool = true) -> void:
    life = max_life
    defense = 0
    hand_limit = 8
    stacks.clear()
    equipped_inner_skill_ids.clear()
    technique_slot_index = 0
    consumable_ids.clear()
    consumable_limit = 3
    insight_multipliers.clear()
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
    var qi_intake_bonus := 1 if int(stacks.get("qi_intake", 0)) > 0 else 0
    return maxi(
        1,
        hand_limit
        + qi_intake_bonus
        + int(stacks.get("full_sleeve", 0))
        - int(stacks.get("bound_sleeve", 0)))

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
            if used.has(card.id) or card.definition_id != str(definition_id):
                continue
            used[card.id] = true
            resolved.append(str(card.id))
            break
    return resolved

func commit_staging() -> Array:
    return card_zone_service.commit_staging(self)

func commit_staging_with_recycles(recycle_anomalies: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    return card_zone_service.commit_staging_with_recycles(
        self, recycle_anomalies, rng)

func commit_selected_staging_with_recycles(
        cards: Array,
        recycle_anomalies: Dictionary,
        rng: RandomNumberGenerator) -> Dictionary:
    return card_zone_service.commit_selected_staging_with_recycles(
        self, cards, recycle_anomalies, rng)

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

func add_stack(stack_id: String, amount: int) -> int:
    if status_system != null:
        var result: Dictionary = status_system.add_actor_status(
            self, stack_id, amount, "战斗方接口")
        return int(result.get("changed", 0)) if result.get("success", false) else 0
    var gained := maxi(0, amount)
    stacks[stack_id] = int(stacks.get(stack_id, 0)) + gained
    return gained

func configure_inner_skills(inner_skill_ids: Array, dynamic_technique_slot: int = 0) -> void:
    equipped_inner_skill_ids.clear()
    for inner_skill_id in inner_skill_ids.slice(0, 6):
        equipped_inner_skill_ids.append(str(inner_skill_id))
    technique_slot_index = clampi(dynamic_technique_slot, 0, equipped_inner_skill_ids.size())

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

func add_insight(hand_id: String, amount: int) -> int:
    insight_multipliers[hand_id] = int(insight_multipliers.get(hand_id, 0)) + maxi(0, amount)
    return int(insight_multipliers[hand_id])

func learn_technique(technique_id: String) -> bool:
    if technique_id == "" or owned_technique_ids.has(technique_id):
        return false
    owned_technique_ids.append(technique_id)
    return true

func combat_source_order(inner_skill_index: int) -> int:
    return inner_skill_index if inner_skill_index < technique_slot_index else inner_skill_index + 1

func receive_damage(amount: int, true_damage: bool = false) -> Dictionary:
    return DamageResolverScript.apply_to_target(self, amount, true_damage)
