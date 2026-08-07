class_name GrowthInventory
extends RefCounted

const RunProgressSnapshotScript = preload("res://core/run_progress_snapshot.gd")
const RunDeckScript = preload("res://core/run_deck.gd")

const CONSUMABLE_LIMIT := 3

var experience: int = 0
var consumable_ids: Array[String] = []
var insight_multipliers: Dictionary = {}
var learned_technique_ids: Array[String] = []
var learned_inner_skill_ids: Array[String] = []
var equipped_inner_skill_ids: Array[String] = []
var technique_slot_index: int = 0
var run_deck
var practice_purchases: Dictionary = {}

func _init(content_catalog = null, initialize_standard_deck: bool = true) -> void:
    run_deck = RunDeckScript.new(content_catalog)
    if initialize_standard_deck:
        run_deck.reset_standard()

func reset(run_namespace: String = "run", run_deck_override = null) -> void:
    experience = 0
    consumable_ids.clear()
    insight_multipliers.clear()
    learned_technique_ids.clear()
    learned_inner_skill_ids.clear()
    equipped_inner_skill_ids.clear()
    technique_slot_index = 0
    if run_deck_override != null:
        run_deck = run_deck_override
    else:
        run_deck.reset_standard(run_namespace)
    practice_purchases.clear()

func clear_practice_purchases() -> void:
    practice_purchases.clear()

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

func to_progress_snapshot():
    return RunProgressSnapshotScript.new({
        "consumable_ids": consumable_ids.duplicate(),
        "insight_multipliers": insight_multipliers.duplicate(true),
        "learned_technique_ids": learned_technique_ids.duplicate(),
        "learned_inner_skill_ids": learned_inner_skill_ids.duplicate(),
        "equipped_inner_skill_ids": equipped_inner_skill_ids.duplicate(),
        "technique_slot_index": technique_slot_index,
        "run_deck": run_deck.to_snapshot(),
    })

func apply_progress_snapshot(progress_snapshot) -> void:
    var values: Dictionary = progress_snapshot.to_dict()
    consumable_ids.clear()
    for consumable_id in values.get("consumable_ids", []):
        consumable_ids.append(str(consumable_id))
    insight_multipliers = values.get("insight_multipliers", {}).duplicate(true)
    learned_technique_ids.clear()
    for technique_id in values.get("learned_technique_ids", []):
        learned_technique_ids.append(str(technique_id))
    learned_inner_skill_ids.clear()
    for inner_skill_id in values.get("learned_inner_skill_ids", []):
        learned_inner_skill_ids.append(str(inner_skill_id))
    equipped_inner_skill_ids.clear()
    for inner_skill_id in values.get("equipped_inner_skill_ids", []):
        equipped_inner_skill_ids.append(str(inner_skill_id))
    technique_slot_index = clampi(
        int(values.get("technique_slot_index", 0)),
        0,
        equipped_inner_skill_ids.size())
    var run_deck_values: Dictionary = values.get("run_deck", {})
    if not run_deck_values.is_empty():
        var errors: Array[String] = run_deck.restore_snapshot(run_deck_values)
        if not errors.is_empty():
            push_error("无法导入本局牌组：%s" % "；".join(errors))

func apply_to_battle_side(side) -> void:
    side.configure_consumables(consumable_ids)
    side.insight_multipliers = insight_multipliers.duplicate(true)
    for technique_id in learned_technique_ids:
        side.learn_technique(technique_id)
    side.configure_inner_skills(equipped_inner_skill_ids, technique_slot_index)
    var no_shuffle_rng := RandomNumberGenerator.new()
    side.replace_deck(run_deck.create_battle_cards(), no_shuffle_rng, false)

func sync_from_battle_side(side) -> void:
    consumable_ids.clear()
    for consumable_id in side.consumable_ids:
        consumable_ids.append(str(consumable_id))
    insight_multipliers = side.insight_multipliers.duplicate(true)
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
