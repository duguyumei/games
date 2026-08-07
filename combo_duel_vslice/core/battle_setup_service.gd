class_name BattleSetupService
extends RefCounted

const RunDeckScript = preload("res://core/run_deck.gd")
const RunProgressSnapshotScript = preload("res://core/run_progress_snapshot.gd")
const DeckFactoryScript = preload("res://core/deck_factory.gd")

var _content_catalog

func _init(content_catalog = null) -> void:
    _content_catalog = content_catalog

func configure_repositories(
        technique_repository,
        inner_skill_repository,
        consumable_repository,
        sequence_book,
        enemy_sequence_book) -> void:
    # 仓库只消费已通过 ContentCatalog 校验的定义；文件读取不进入战斗建立流程。
    technique_repository.configure(_content_catalog.definition("techniques"), true)
    inner_skill_repository.configure(_content_catalog.definition("inner_skills"))
    consumable_repository.configure(_content_catalog.definition("consumables"))
    sequence_book.configure(_content_catalog.definition("sequences"))
    enemy_sequence_book.configure(_content_catalog.definition("sequences"))

func create_standard_deck(instance_namespace: String = "") -> Array:
    return DeckFactoryScript.namespace_instance_ids(
        DeckFactoryScript.create_standard_deck_from_definition(
            _content_catalog.definition("base_deck")),
        instance_namespace)

func seed_owned_techniques(side, book) -> void:
    side.owned_technique_ids.clear()
    for hand_id in book.sequences:
        for technique_id_value in book.sequences[hand_id]:
            side.learn_technique(str(technique_id_value))

func load_scenario(scenario, path: String) -> bool:
    if _content_catalog != null \
            and _content_catalog.runtime_profile != null \
            and not _content_catalog.runtime_profile.allows_resource_path(path):
        push_error(
            "%s 模式禁止载入战斗资源：%s" % [
                _content_catalog.runtime_profile.mode_name(), path])
        return false
    if path == _content_catalog.path_for("scripted_battle"):
        return scenario.configure(_content_catalog.definition("scripted_battle"))
    return scenario.load_from_file(path)

func apply_scripted_scenario(scenario, player, enemy, rng, enemy_deck: Array) -> Dictionary:
    # 脚本场景只负责初始装配，行动生成仍由敌方控制器和规划服务完成。
    var player_definition: Dictionary = scenario.player_definition()
    var enemy_definition: Dictionary = scenario.enemy_definition()
    player.configure_inner_skills(
        player_definition.get("inner_skills", []),
        int(player_definition.get("technique_slot_index", 0)))
    player.configure_consumables(player_definition.get("consumables", []))
    enemy.configure_inner_skills(
        enemy_definition.get("inner_skills", []),
        int(enemy_definition.get("technique_slot_index", 0)))
    enemy.max_life = int(enemy_definition.get("life", 100))
    enemy.life = enemy.max_life
    enemy.replace_deck(scenario.arrange_enemy_deck(enemy_deck), rng, false)
    return {
        "name": scenario.scenario_name(),
        "enemy_sequences": scenario.enemy_sequences(),
        "enemy_ai_policy": scenario.enemy_ai_policy(),
    }

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
