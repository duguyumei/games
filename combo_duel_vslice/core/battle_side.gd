class_name BattleSide
extends RefCounted

var name: String
var max_life: int = 100
var life: int = 100
var defense: int = 0
var hand_limit: int = 8
var draw_pile: Array = []
var hand: Array = []
var staging: Array = []
var discard_pile: Array = []
var stacks: Dictionary = {}
var equipped_inner_skill_ids: Array[String] = []
var technique_slot_index: int = 0

func _init(side_name: String = "") -> void:
    name = side_name

func reset(cards: Array, rng: RandomNumberGenerator, shuffle_cards: bool = true) -> void:
    life = max_life
    defense = 0
    hand_limit = 8
    stacks.clear()
    equipped_inner_skill_ids.clear()
    technique_slot_index = 0
    hand.clear()
    staging.clear()
    discard_pile.clear()
    draw_pile = cards.duplicate()
    if shuffle_cards:
        _shuffle(draw_pile, rng)

func _shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
    for index in range(cards.size() - 1, 0, -1):
        var other := rng.randi_range(0, index)
        var temporary = cards[index]
        cards[index] = cards[other]
        cards[other] = temporary

func draw(count: int) -> Array:
    var drawn: Array = []
    for _index in range(maxi(0, count)):
        if draw_pile.is_empty():
            break
        var card = draw_pile.pop_back()
        hand.append(card)
        drawn.append(card)
    return drawn

func draw_to_limit() -> Array:
    if hand.size() >= hand_limit:
        return []
    return draw(hand_limit - hand.size())

func stage_cards(card_ids: Array) -> bool:
    var found: Array = []
    for card_id in card_ids:
        var card = find_hand_card(str(card_id))
        if card == null or found.has(card):
            return false
        found.append(card)
    for card in found:
        hand.erase(card)
        staging.append(card)
    return true

func find_hand_card(card_id: String):
    for card in hand:
        if card.id == card_id:
            return card
    return null

func commit_staging() -> Array:
    var committed := staging.duplicate()
    discard_pile.append_array(staging)
    staging.clear()
    return committed

func commit_staging_with_recycles(recycle_statuses: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    var committed := staging.duplicate()
    var recycled: Array = []
    for card in staging:
        if recycle_statuses.has(card.id):
            var status_data: Dictionary = recycle_statuses[card.id]
            card.set_combat_status(str(status_data["slot"]), str(status_data["status"]))
            draw_pile.append(card)
            recycled.append(card)
        else:
            discard_pile.append(card)
    staging.clear()
    if not recycled.is_empty():
        _shuffle(draw_pile, rng)
    return {"committed": committed, "recycled": recycled}

func count_status_in_zone(zone: String, slot: String, status_id: String) -> int:
    var cards: Array = []
    match zone:
        "hand": cards = hand
        "draw_pile": cards = draw_pile
        "staging": cards = staging
        "discard_pile": cards = discard_pile
    var count := 0
    for card in cards:
        if card.has_combat_status(slot, status_id):
            count += 1
    return count

func random_discard(count: int, rng: RandomNumberGenerator) -> Array:
    var discarded: Array = []
    for _index in range(maxi(0, count)):
        if hand.is_empty():
            break
        var chosen := rng.randi_range(0, hand.size() - 1)
        var card = hand.pop_at(chosen)
        discard_pile.append(card)
        discarded.append(card)
    return discarded

func discard_all() -> Array:
    var discarded := hand.duplicate()
    discard_pile.append_array(hand)
    hand.clear()
    return discarded

func add_defense(amount: int) -> int:
    var gained := maxi(0, amount)
    defense += gained
    return gained

func add_stack(stack_id: String, amount: int) -> int:
    var gained := maxi(0, amount)
    stacks[stack_id] = int(stacks.get(stack_id, 0)) + gained
    return gained

func configure_inner_skills(inner_skill_ids: Array, dynamic_technique_slot: int = 0) -> void:
    equipped_inner_skill_ids.clear()
    for inner_skill_id in inner_skill_ids.slice(0, 6):
        equipped_inner_skill_ids.append(str(inner_skill_id))
    technique_slot_index = clampi(dynamic_technique_slot, 0, equipped_inner_skill_ids.size())

func combat_source_order(inner_skill_index: int) -> int:
    return inner_skill_index if inner_skill_index < technique_slot_index else inner_skill_index + 1

func receive_damage(amount: int, true_damage: bool = false) -> Dictionary:
    var incoming := maxi(0, amount)
    var defense_lost := 0
    var life_lost := 0
    if true_damage:
        life_lost = mini(life, incoming)
        life -= life_lost
    else:
        defense_lost = mini(defense, incoming)
        defense -= defense_lost
        var remainder := incoming - defense_lost
        life_lost = mini(life, remainder)
        life -= life_lost
    return {
        "requested": incoming,
        "defense_lost": defense_lost,
        "life_lost": life_lost,
        "true_damage": true_damage,
    }
