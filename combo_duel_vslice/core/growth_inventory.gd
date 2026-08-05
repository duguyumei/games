class_name GrowthInventory
extends RefCounted

const RunProgressSnapshotScript = preload("res://core/run_progress_snapshot.gd")
const RunDeckScript = preload("res://core/run_deck.gd")

const CONSUMABLE_LIMIT := 3

var experience: int = 0
var consumable_ids: Array[String] = []
var insight_multipliers: Dictionary = {}
var learned_technique_ids: Array[String] = []
var run_deck
var practice_purchases: Dictionary = {}

func _init(content_catalog = null) -> void:
    run_deck = RunDeckScript.new(content_catalog)
    run_deck.reset_standard()

func reset(run_namespace: String = "run") -> void:
    experience = 0
    consumable_ids.clear()
    insight_multipliers.clear()
    learned_technique_ids.clear()
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
    run_deck.sync_from_battle_cards(
        side.all_cards_for_run_sync(),
        side.permanently_removed_card_ids)
