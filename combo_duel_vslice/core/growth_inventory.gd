class_name GrowthInventory
extends RefCounted

const RunProgressSnapshotScript = preload("res://core/run_progress_snapshot.gd")
const RunDeckScript = preload("res://core/run_deck.gd")

const CONSUMABLE_LIMIT := 3
const EXPERIENCE_INTEREST_STEP := 5
const EXPERIENCE_INTEREST_CAP := 5

var experience: int = 0
var consumable_ids: Array[String] = []
var item_ids: Array[String] = []
var learned_technique_ids: Array[String] = []
var learned_inner_skill_ids: Array[String] = []
var equipped_inner_skill_ids: Array[String] = []
var technique_slot_index: int = 0
var forgotten_inner_skill_count: int = 0
var run_deck
var practice_purchases: Dictionary = {}
var life: int = 100
var max_life: int = 100
var hand_technique_progression: Dictionary = {}
var practice_shop_state: Dictionary = {}
var consumable_use_sequence: int = 0
var last_recallable_consumable_id: String = ""
var base_hand_limit_modifier: int = 0
var hand_technique_multiplier_modifiers: Dictionary = {}
var used_unique_consumable_ids: Array[String] = []
var _content_catalog

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]

func _init(content_catalog = null, initialize_standard_deck: bool = true) -> void:
    _content_catalog = content_catalog
    run_deck = RunDeckScript.new(content_catalog)
    _initialize_hand_technique_progression(
        content_catalog.definition("sequences") if content_catalog != null else {})
    if initialize_standard_deck:
        run_deck.reset_standard()

func reset(
        run_namespace: String = "run",
        run_deck_override = null,
        initial_max_life: int = 100) -> void:
    experience = 0
    max_life = initial_max_life
    life = max_life
    consumable_ids.clear()
    item_ids.clear()
    learned_technique_ids.clear()
    learned_inner_skill_ids.clear()
    equipped_inner_skill_ids.clear()
    technique_slot_index = 0
    forgotten_inner_skill_count = 0
    if run_deck_override != null:
        run_deck = run_deck_override
    else:
        run_deck.reset_standard(run_namespace)
    practice_purchases.clear()
    _initialize_hand_technique_progression(
        _content_catalog.definition("sequences") if _content_catalog != null else {})
    practice_shop_state.clear()
    consumable_use_sequence = 0
    last_recallable_consumable_id = ""
    base_hand_limit_modifier = 0
    hand_technique_multiplier_modifiers.clear()
    used_unique_consumable_ids.clear()

func clear_practice_purchases() -> void:
    practice_purchases.clear()

func migrate_legacy_practice_shop_state() -> void:
    practice_shop_state = normalized_practice_shop_state(practice_shop_state)

func practice_shop_snapshot() -> Dictionary:
    return normalized_practice_shop_state(practice_shop_state)

static func normalized_practice_shop_state(value: Dictionary) -> Dictionary:
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

## 捕获本局效果事务所需的完整可变状态。
##
## 这不同于 RunProgressSnapshot 的部分快照：事务副本必须覆盖所有本局库存，
## 才能保证未来的牌组或装备 Handler 失败时不会留下部分修改。
func capture_mutation_state() -> Dictionary:
    return {
        "experience": experience,
        "life": life,
        "max_life": max_life,
        "consumable_ids": consumable_ids.duplicate(),
        "item_ids": item_ids.duplicate(),
        "learned_technique_ids": learned_technique_ids.duplicate(),
        "learned_inner_skill_ids": learned_inner_skill_ids.duplicate(),
        "equipped_inner_skill_ids": equipped_inner_skill_ids.duplicate(),
        "technique_slot_index": technique_slot_index,
        "forgotten_inner_skill_count": forgotten_inner_skill_count,
        "run_deck": run_deck.to_snapshot(),
        "practice_purchases": practice_purchases.duplicate(true),
        "hand_technique_progression": hand_technique_progression.duplicate(true),
        "practice_shop_state": practice_shop_snapshot(),
        "consumable_use_sequence": consumable_use_sequence,
        "last_recallable_consumable_id": last_recallable_consumable_id,
        "base_hand_limit_modifier": base_hand_limit_modifier,
        "hand_technique_multiplier_modifiers": hand_technique_multiplier_modifiers.duplicate(true),
        "used_unique_consumable_ids": used_unique_consumable_ids.duplicate(),
    }

func create_mutation_copy():
    var working := GrowthInventory.new(_content_catalog, false)
    var errors: Array[String] = working.replace_mutation_state(
        capture_mutation_state())
    if not errors.is_empty():
        push_error("无法建立成长库存事务副本：%s" % "；".join(errors))
        return null
    return working

## 用一个已完整验证的事务状态替换真实库存。
##
## RunDeck 先在独立实例中恢复并校验；只有成功后才替换所有字段，避免提交阶段
## 因牌组错误把真实库存写到一半。
func replace_mutation_state(state: Dictionary) -> Array[String]:
    var replacement_deck = RunDeckScript.new(_content_catalog)
    var deck_errors: Array[String] = replacement_deck.restore_snapshot(
        state["run_deck"])
    if not deck_errors.is_empty():
        return deck_errors
    experience = int(state["experience"])
    life = int(state["life"])
    max_life = int(state["max_life"])
    consumable_ids.assign(state["consumable_ids"])
    item_ids.assign(state.get("item_ids", []))
    learned_technique_ids.assign(state["learned_technique_ids"])
    learned_inner_skill_ids.assign(state["learned_inner_skill_ids"])
    equipped_inner_skill_ids.assign(state["equipped_inner_skill_ids"])
    technique_slot_index = int(state["technique_slot_index"])
    forgotten_inner_skill_count = int(
        state.get("forgotten_inner_skill_count", 0))
    run_deck = replacement_deck
    practice_purchases = state["practice_purchases"].duplicate(true)
    hand_technique_progression = state["hand_technique_progression"].duplicate(true)
    practice_shop_state = normalized_practice_shop_state(
        state["practice_shop_state"])
    consumable_use_sequence = int(state.get("consumable_use_sequence", 0))
    last_recallable_consumable_id = str(
        state.get("last_recallable_consumable_id", ""))
    base_hand_limit_modifier = int(state.get("base_hand_limit_modifier", 0))
    hand_technique_multiplier_modifiers = state.get(
        "hand_technique_multiplier_modifiers", {}).duplicate(true)
    used_unique_consumable_ids.assign(
        state.get("used_unique_consumable_ids", []))
    return []

func _initialize_hand_technique_progression(sequence_definition: Dictionary) -> void:
    hand_technique_progression.clear()
    for hand_id in HAND_IDS:
        var sequence: Array = sequence_definition.get(hand_id, [])
        var initial: Array = []
        if not sequence.is_empty():
            var technique_id := str(sequence[0])
            initial.append(technique_id)
            if not learned_technique_ids.has(technique_id):
                learned_technique_ids.append(technique_id)
        hand_technique_progression[hand_id] = {
            "slot_count": 1,
            "sequence": initial,
        }

func hand_progression(hand_id: String) -> Dictionary:
    var value: Dictionary = hand_technique_progression.get(hand_id, {})
    return value.duplicate(true)

func get_hand_technique_loadout(hand_id: String) -> Dictionary:
    return hand_progression(hand_id)

func set_hand_technique_loadout(hand_id: String, technique_ids: Array) -> Dictionary:
    if not HAND_IDS.has(hand_id):
        return {"success": false, "reason": "未知牌型：%s" % hand_id}
    var progression: Dictionary = hand_technique_progression.get(hand_id, {})
    var slot_count := int(progression.get("slot_count", 1))
    var normalized: Array[String] = []
    for technique_id_value in technique_ids:
        var technique_id := str(technique_id_value)
        if technique_id == "" or normalized.has(technique_id):
            return {"success": false, "reason": "功法序列包含空值或重复功法"}
        if normalized.size() >= slot_count:
            return {"success": false, "reason": "功法序列超过当前槽位数"}
        if not learned_technique_ids.has(technique_id):
            return {"success": false, "reason": "功法尚未获得：%s" % technique_id}
        if not _technique_belongs_to_hand(technique_id, hand_id):
            return {"success": false, "reason": "功法不属于该牌型的共用池：%s" % technique_id}
        normalized.append(technique_id)
    progression["sequence"] = normalized
    hand_technique_progression[hand_id] = progression
    return {"success": true, "hand_id": hand_id, "sequence": normalized.duplicate()}

func _technique_belongs_to_hand(technique_id: String, hand_id: String) -> bool:
    if _content_catalog == null:
        return true
    var techniques: Dictionary = _content_catalog.definition("techniques")
    var definition: Dictionary = {}
    for value in techniques.get("techniques", []):
        if str(value.get("id", "")) == technique_id:
            definition = value
            break
    if definition.is_empty():
        return false
    if str(techniques.get("integration_statuses", {}).get(technique_id, "")) != "formal_complete":
        return false
    return techniques.get("pool_membership", {}).get(hand_id, []).has(
        str(definition.get("pool", "")))

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
        if candidate != "" \
                and _technique_belongs_to_hand(candidate, hand_id) \
                and not sequence.has(candidate) \
                and not available.has(candidate):
            available.append(candidate)
    available.sort()
    var acquired := ""
    if not available.is_empty():
        var index := rng.randi_range(0, available.size() - 1) if rng != null else 0
        acquired = available[index]
        sequence.append(acquired)
        if not learned_technique_ids.has(acquired):
            learned_technique_ids.append(acquired)
    progression["sequence"] = sequence
    hand_technique_progression[hand_id] = progression
    return {
        "success": true,
        "hand_id": hand_id,
        "slot_count_before": before,
        "slot_count_after": before + 1,
        "acquired_technique_id": acquired,
        "technique_available": acquired != "",
        "no_technique_available": acquired == "",
    }

func apply_insight(
        hand_id: String,
        candidates: Array = [],
        rng: RandomNumberGenerator = null) -> Dictionary:
    return apply_insight_growth(hand_id, candidates, rng)

func experience_interest_parameters() -> Dictionary:
    return {
        "step": EXPERIENCE_INTEREST_STEP,
        "cap": EXPERIENCE_INTEREST_CAP,
    }

func apply_experience_interest() -> Dictionary:
    var experience_before := experience
    var parameters := experience_interest_parameters()
    var step := int(parameters["step"])
    var cap := int(parameters["cap"])
    var amount := mini(
        floori(experience_before / step),
        cap)
    experience += amount
    return {
        "amount": amount,
        "experience_before": experience_before,
        "experience_after": experience,
        "step": step,
        "cap": cap,
    }

func purchase_consumable(consumable_id: String, price: int, practice_available: bool) -> Dictionary:
    if not practice_available:
        return {"success": false, "reason": "节点进行中不能修习"}
    if practice_purchases.has(consumable_id):
        return {"success": false, "reason": "本次修习已购买"}
    if consumable_ids.size() >= CONSUMABLE_LIMIT:
        return {"success": false, "reason": "共享消耗品栏已满"}
    if experience < price:
        return {"success": false, "reason": "历练不足"}
    experience -= price
    consumable_ids.append(consumable_id)
    practice_purchases[consumable_id] = true
    return {"success": true, "remaining_experience": experience}

func to_progress_snapshot() -> RunProgressSnapshot:
    return RunProgressSnapshotScript.from_dict({
        "consumable_ids": consumable_ids.duplicate(),
        "item_ids": item_ids.duplicate(),
        "learned_technique_ids": learned_technique_ids.duplicate(),
        "learned_inner_skill_ids": learned_inner_skill_ids.duplicate(),
        "equipped_inner_skill_ids": equipped_inner_skill_ids.duplicate(),
        "technique_slot_index": technique_slot_index,
        "forgotten_inner_skill_count": forgotten_inner_skill_count,
        "run_deck": run_deck.to_snapshot(),
        "life": life,
        "max_life": max_life,
        "experience": experience,
        "hand_technique_progression": hand_technique_progression.duplicate(true),
        "practice_shop_state": practice_shop_snapshot(),
        "consumable_use_sequence": consumable_use_sequence,
        "last_recallable_consumable_id": last_recallable_consumable_id,
        "base_hand_limit_modifier": base_hand_limit_modifier,
        "hand_technique_multiplier_modifiers": hand_technique_multiplier_modifiers.duplicate(true),
        "used_unique_consumable_ids": used_unique_consumable_ids.duplicate(),
    })

func apply_progress_snapshot(progress_snapshot: RunProgressSnapshot) -> void:
    if progress_snapshot.has_consumable_ids:
        consumable_ids.assign(progress_snapshot.consumable_ids)
    if progress_snapshot.has_item_ids:
        item_ids.assign(progress_snapshot.item_ids)
    if progress_snapshot.has_hand_technique_progression:
        hand_technique_progression = progress_snapshot.hand_technique_progression.duplicate(true)
    if progress_snapshot.has_practice_shop_state:
        practice_shop_state = normalized_practice_shop_state(
            progress_snapshot.practice_shop_state)
    if progress_snapshot.has_consumable_use_sequence:
        consumable_use_sequence = progress_snapshot.consumable_use_sequence
    if progress_snapshot.has_last_recallable_consumable_id:
        last_recallable_consumable_id = (
            progress_snapshot.last_recallable_consumable_id)
    if progress_snapshot.has_base_hand_limit_modifier:
        base_hand_limit_modifier = progress_snapshot.base_hand_limit_modifier
    if progress_snapshot.has_hand_technique_multiplier_modifiers:
        hand_technique_multiplier_modifiers = (
            progress_snapshot.hand_technique_multiplier_modifiers.duplicate(true))
    if progress_snapshot.has_used_unique_consumable_ids:
        used_unique_consumable_ids.assign(
            progress_snapshot.used_unique_consumable_ids)
    if progress_snapshot.has_learned_technique_ids:
        learned_technique_ids.assign(progress_snapshot.learned_technique_ids)
    if progress_snapshot.has_learned_inner_skill_ids:
        learned_inner_skill_ids.assign(progress_snapshot.learned_inner_skill_ids)
    if progress_snapshot.has_equipped_inner_skill_ids:
        equipped_inner_skill_ids.assign(progress_snapshot.equipped_inner_skill_ids)
    if progress_snapshot.has_technique_slot_index:
        technique_slot_index = progress_snapshot.technique_slot_index
    if progress_snapshot.has_forgotten_inner_skill_count:
        forgotten_inner_skill_count = progress_snapshot.forgotten_inner_skill_count
    if progress_snapshot.has_equipped_inner_skill_ids \
            or progress_snapshot.has_technique_slot_index:
        technique_slot_index = clampi(
            technique_slot_index, 0, equipped_inner_skill_ids.size())
    if progress_snapshot.has_run_deck and not progress_snapshot.run_deck.is_empty():
        var errors: Array[String] = run_deck.restore_snapshot(progress_snapshot.run_deck)
        if not errors.is_empty():
            push_error("无法导入本局牌组：%s" % "；".join(errors))
    if progress_snapshot.has_max_life:
        max_life = progress_snapshot.max_life
    if progress_snapshot.has_life:
        life = progress_snapshot.life
    if progress_snapshot.has_experience:
        experience = progress_snapshot.experience

func grow_life_to(new_max_life: int) -> void:
    var increase := new_max_life - max_life
    max_life = new_max_life
    life = mini(life + increase, max_life)

func apply_to_battle_side(side) -> void:
    side.max_life = max_life
    side.life = life
    side.experience = experience
    side.configure_consumables(consumable_ids)
    side.hand_technique_progression = hand_technique_progression.duplicate(true)
    side.hand_technique_progression_active = true
    side.base_hand_limit_modifier = base_hand_limit_modifier
    side.hand_technique_multiplier_modifiers = (
        hand_technique_multiplier_modifiers.duplicate(true))
    for technique_id in learned_technique_ids:
        side.learn_technique(technique_id)
    side.configure_inner_skills(equipped_inner_skill_ids, technique_slot_index)
    var no_shuffle_rng := RandomNumberGenerator.new()
    side.replace_deck(run_deck.create_battle_cards(), no_shuffle_rng, false)

func sync_from_battle_side(side) -> void:
    max_life = int(side.max_life)
    life = int(side.life)
    consumable_ids.clear()
    for consumable_id in side.consumable_ids:
        consumable_ids.append(str(consumable_id))
    if side.get("hand_technique_progression") is Dictionary:
        hand_technique_progression = side.hand_technique_progression.duplicate(true)
    base_hand_limit_modifier = int(side.get("base_hand_limit_modifier"))
    if side.get("hand_technique_multiplier_modifiers") is Dictionary:
        hand_technique_multiplier_modifiers = (
            side.hand_technique_multiplier_modifiers.duplicate(true))
    learned_technique_ids.clear()
    for technique_id in side.owned_technique_ids:
        learned_technique_ids.append(str(technique_id))
    equipped_inner_skill_ids.clear()
    for inner_skill_id in side.equipped_inner_skill_ids:
        equipped_inner_skill_ids.append(str(inner_skill_id))
        if not learned_inner_skill_ids.has(str(inner_skill_id)):
            learned_inner_skill_ids.append(str(inner_skill_id))
    technique_slot_index = int(side.technique_slot_index)
    run_deck.sync_from_battle_cards(
        side.all_cards_for_run_sync(),
        side.permanently_removed_card_ids)

func current_base_hand_limit() -> int:
    return maxi(1, 8 + base_hand_limit_modifier)
