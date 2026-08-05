class_name BattleSetupService
extends RefCounted

const RunDeckScript = preload("res://core/run_deck.gd")
const RunProgressSnapshotScript = preload("res://core/run_progress_snapshot.gd")

var _content_catalog

func _init(content_catalog = null) -> void:
    _content_catalog = content_catalog

func run_deck_from_progress(progress_snapshot):
    var run_deck = RunDeckScript.new(_content_catalog)
    var values: Dictionary = (
        progress_snapshot.to_dict()
        if progress_snapshot != null
        else {})
    var run_deck_values: Dictionary = values.get("run_deck", {})
    if run_deck_values.is_empty():
        run_deck.reset_standard("battle")
        return run_deck
    var errors := run_deck.restore_snapshot(run_deck_values)
    if not errors.is_empty():
        push_error("本局牌组快照无效：%s" % "；".join(errors))
        run_deck.reset_standard("battle-fallback")
    return run_deck

func apply_non_deck_progress(side, progress_snapshot) -> void:
    if progress_snapshot == null:
        return
    var values: Dictionary = progress_snapshot.to_dict()
    side.configure_consumables(values.get("consumable_ids", []))
    side.insight_multipliers = values.get("insight_multipliers", {}).duplicate(true)
    for technique_id in values.get("learned_technique_ids", []):
        side.learn_technique(str(technique_id))

func capture_progress(side, run_deck):
    run_deck.sync_from_battle_cards(
        side.all_cards_for_run_sync(),
        side.permanently_removed_card_ids)
    return RunProgressSnapshotScript.new({
        "consumable_ids": side.consumable_ids.duplicate(),
        "insight_multipliers": side.insight_multipliers.duplicate(true),
        "learned_technique_ids": side.owned_technique_ids.duplicate(),
        "run_deck": run_deck.to_snapshot(),
    })
