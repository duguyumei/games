class_name BattleSetupService
extends RefCounted

## 战斗初始内容与本局进度的装配边界。
##
## 这里配置仓库、场景和参战者初始数据，并在战后捕获它实际持有的进度；
## 故意不执行回合、效果或本局成长合并，部分快照的合并由 GrowthInventory 负责。

const RunDeckScript = preload("res://core/run_deck.gd")
const RunProgressSnapshotScript = preload("res://core/run_progress_snapshot.gd")
const DeckFactoryScript = preload("res://core/deck_factory.gd")
const EnemyRepositoryScript = preload("res://core/enemy_repository.gd")

var _content_catalog
var enemy_repository

func _init(content_catalog = null) -> void:
    _content_catalog = content_catalog
    if content_catalog != null and content_catalog.loaded:
        var shared_repository = null
        if content_catalog.enemy_repository_ref != null:
            shared_repository = content_catalog.enemy_repository_ref.get_ref()
        enemy_repository = shared_repository
        if enemy_repository == null:
            enemy_repository = EnemyRepositoryScript.new(content_catalog)
            enemy_repository.configure(content_catalog.definition("enemies"))

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
            _content_catalog.definition("base_deck"),
            _content_catalog.card_reshape_rules),
        instance_namespace)

func seed_owned_techniques(side, book) -> void:
    side.owned_technique_ids.clear()
    for hand_id in book.sequences:
        for technique_id_value in book.sequences[hand_id]:
            side.learn_technique(str(technique_id_value))

func apply_player_technique_progression(side, book, progress_snapshot) -> Dictionary:
    if progress_snapshot == null or not progress_snapshot.has_hand_technique_progression:
        return {"success": true}
    var values: Dictionary = progress_snapshot.hand_technique_progression
    var learned_ids: Array = progress_snapshot.learned_technique_ids \
        if progress_snapshot.has_learned_technique_ids else []
    var validation: Dictionary = side.technique_loadout_policy.validate_complete(
        side, values, learned_ids, "")
    if not validation.get("success", false):
        return validation
    book.configure_hand_progression(values)
    side.hand_technique_progression = values.duplicate(true)
    side.hand_technique_progression_active = true
    return {
        "success": true,
        "instance_count": book.find_slots({}).size(),
    }

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
    var player_items: Dictionary = player.configure_items(
        player_definition.get("item_ids", []))
    if not player_items.get("success", false):
        return player_items
    var player_inner: Dictionary = player.configure_inner_skills(
        player_definition.get("inner_skills", []),
        int(player_definition.get("technique_slot_index", 0)))
    if not player_inner.get("success", false):
        return player_inner
    player.learned_inner_skill_ids.assign(
        player_definition.get("inner_skills", []))
    player.configure_consumables(player_definition.get("consumables", []))
    var enemy_items: Dictionary = enemy.configure_items(
        enemy_definition.get("item_ids", []))
    if not enemy_items.get("success", false):
        return enemy_items
    var enemy_inner: Dictionary = enemy.configure_inner_skills(
        enemy_definition.get("inner_skills", []),
        int(enemy_definition.get("technique_slot_index", 0)))
    if not enemy_inner.get("success", false):
        return enemy_inner
    enemy.learned_inner_skill_ids.assign(
        enemy_definition.get("inner_skills", []))
    enemy.max_life = int(enemy_definition.get("life", 100))
    enemy.life = enemy.max_life
    enemy.replace_deck(scenario.arrange_enemy_deck(enemy_deck), rng, false)
    return {
        "success": true,
        "name": scenario.scenario_name(),
        "enemy_sequences": scenario.enemy_sequences(),
        "enemy_ai_policy": scenario.enemy_ai_policy(),
    }

func apply_formal_enemy(
        enemy,
        act: int,
        node_type: String,
        content_seed: int,
        boss_variant: int,
        rng) -> Dictionary:
    if enemy_repository == null:
        return {"success": false, "reason": "正式敌人仓库未装配"}
    var life_definition := _enemy_life_definition(act, node_type)
    if life_definition.is_empty():
        return {
            "success": false,
            "reason": "敌人生命表缺少组合：第 %d 层 / %s" % [act, node_type],
        }
    var selected: Dictionary = enemy_repository.select(
        act, node_type, content_seed, boss_variant)
    if not selected.get("success", false):
        return selected
    var entry: Dictionary = selected["entry"]
    enemy.max_life = int(life_definition["max_life"])
    enemy.life = enemy.max_life
    var item_result: Dictionary = enemy.configure_items(
        entry.get("item_ids", []))
    if not item_result.get("success", false):
        return item_result
    var inner_result: Dictionary = enemy.configure_inner_skills(
        entry.get("equipped_inner_skill_ids", []),
        int(entry.get("technique_slot_index", 0)))
    if not inner_result.get("success", false):
        return inner_result
    enemy.hand_proficiency_fixed = entry.get("hand_proficiency_fixed", {}).duplicate(true)
    enemy.replace_deck(selected["cards"], rng, true)
    return {
        "success": true,
        "entry": entry,
        "ai_policy": selected["ai_policy"],
        "sequences": entry.get("sequences", {}).duplicate(true),
    }

func _enemy_life_definition(act: int, node_type: String) -> Dictionary:
    if _content_catalog == null:
        return {}
    for value in _content_catalog.definition("act_progression").get("acts", []):
        if int(value.get("act", 0)) == act:
            var enemies: Dictionary = value.get("enemies", {})
            var result = enemies.get(node_type, {})
            return result.duplicate(true) if result is Dictionary else {}
    return {}

func run_deck_from_progress(progress_snapshot: RunProgressSnapshot):
    var run_deck = RunDeckScript.new(_content_catalog)
    if progress_snapshot == null \
            or not progress_snapshot.has_run_deck \
            or progress_snapshot.run_deck.is_empty():
        run_deck.reset_standard("battle")
        return run_deck
    var errors := run_deck.restore_snapshot(progress_snapshot.run_deck)
    if not errors.is_empty():
        push_error("本局牌组快照无效：%s" % "；".join(errors))
        run_deck.reset_standard("battle-fallback")
    return run_deck

func apply_non_deck_progress(side, progress_snapshot: RunProgressSnapshot) -> Dictionary:
    if progress_snapshot == null:
        return {"success": true}
    var state_before: Dictionary = side.capture_passive_query_state()
    var result: Dictionary = _apply_non_deck_progress(side, progress_snapshot)
    if not result.get("success", false):
        side.replace_passive_query_state(state_before)
        result["rolled_back"] = true
    return result

func _apply_non_deck_progress(side, progress_snapshot: RunProgressSnapshot) -> Dictionary:
    if progress_snapshot.has_item_ids:
        var item_result: Dictionary = side.configure_items(
            progress_snapshot.item_ids)
        if not item_result.get("success", false):
            return item_result
    if progress_snapshot.has_learned_inner_skill_ids:
        side.learned_inner_skill_ids.assign(
            progress_snapshot.learned_inner_skill_ids)
    if progress_snapshot.has_equipped_inner_skill_ids \
            or progress_snapshot.has_technique_slot_index:
        if progress_snapshot.has_learned_inner_skill_ids:
            var learned_counts := _counts(progress_snapshot.learned_inner_skill_ids)
            var equipped_counts := _counts(
                progress_snapshot.equipped_inner_skill_ids
                if progress_snapshot.has_equipped_inner_skill_ids
                else side.equipped_inner_skill_ids)
            for content_id in equipped_counts:
                if int(equipped_counts[content_id]) > int(learned_counts.get(content_id, 0)):
                    return {
                        "success": false,
                        "reason": "装备数量超过已获得副本数：%s" % str(content_id),
                    }
        var inner_result: Dictionary = side.configure_inner_skills(
            progress_snapshot.equipped_inner_skill_ids
                if progress_snapshot.has_equipped_inner_skill_ids
                else side.equipped_inner_skill_ids,
            progress_snapshot.technique_slot_index
                if progress_snapshot.has_technique_slot_index
                else side.technique_slot_index)
        if not inner_result.get("success", false):
            return inner_result
    if progress_snapshot.has_forgotten_inner_skill_count:
        side.forgotten_inner_skill_count = (
            progress_snapshot.forgotten_inner_skill_count)
    if progress_snapshot.has_consumable_ids:
        side.configure_consumables(progress_snapshot.consumable_ids)
    if progress_snapshot.has_consumable_use_sequence:
        side.consumable_use_sequence = progress_snapshot.consumable_use_sequence
    if progress_snapshot.has_last_recallable_consumable_id:
        side.last_recallable_consumable_id = (
            progress_snapshot.last_recallable_consumable_id)
    if progress_snapshot.has_used_unique_consumable_ids:
        side.used_unique_consumable_ids.assign(
            progress_snapshot.used_unique_consumable_ids)
    if progress_snapshot.has_base_hand_limit_modifier:
        side.base_hand_limit_modifier = progress_snapshot.base_hand_limit_modifier
    if progress_snapshot.has_hand_technique_multiplier_modifiers:
        side.hand_technique_multiplier_modifiers = (
            progress_snapshot.hand_technique_multiplier_modifiers.duplicate(true))
    if progress_snapshot.has_learned_technique_ids:
        _replace_obtainable_owned_technique_ids(
            side, progress_snapshot.learned_technique_ids)
    if progress_snapshot.has_max_life:
        side.max_life = progress_snapshot.max_life
    if progress_snapshot.has_base_max_life:
        side.base_max_life = progress_snapshot.base_max_life
    elif progress_snapshot.has_max_life:
        side.base_max_life = progress_snapshot.max_life
    if progress_snapshot.has_source_marker_state:
        var marker_errors: Array[String] = side.source_marker_store.restore_snapshot(
            progress_snapshot.source_marker_state)
        if not marker_errors.is_empty():
            return {"success": false, "reason": "来源标识装配失败：%s" % "；".join(marker_errors)}
    if progress_snapshot.has_life:
        side.life = progress_snapshot.life
    if progress_snapshot.has_experience:
        side.experience = progress_snapshot.experience
    if progress_snapshot.has_passive_counter_state \
            and side.passive_counter_store == null:
        return {"success": false, "reason": "玩家本局被动计数器尚未装配"}
    if progress_snapshot.has_passive_counter_state:
        var counter_errors: Array[String] = side.passive_counter_store.replace_state(
            progress_snapshot.passive_counter_state)
        if not counter_errors.is_empty():
            return {
                "success": false,
                "reason": "玩家本局被动计数器装配失败：%s" % \
                    "；".join(counter_errors),
            }
    return {"success": true}

func _counts(values: Array) -> Dictionary:
    var result: Dictionary = {}
    for value in values:
        var content_id := str(value)
        result[content_id] = int(result.get(content_id, 0)) + 1
    return result

func capture_progress(side, run_deck) -> RunProgressSnapshot:
    run_deck.sync_from_battle_cards(
        side.all_cards_for_run_sync(),
        side.permanently_removed_card_ids)
    var values := {
        "consumable_ids": side.consumable_ids.duplicate(),
        "item_ids": side.item_ids.duplicate(),
        "learned_inner_skill_ids": side.learned_inner_skill_ids.duplicate(),
        "equipped_inner_skill_ids": side.equipped_inner_skill_ids.duplicate(),
        "technique_slot_index": side.technique_slot_index,
        "forgotten_inner_skill_count": side.forgotten_inner_skill_count,
        "hand_technique_progression": side.hand_technique_progression.duplicate(true),
        "learned_technique_ids": _obtainable_owned_technique_ids(side),
        "life": side.life,
        "max_life": side.max_life,
        "base_max_life": side.base_max_life,
        "source_marker_state": side.source_marker_store.snapshot("run"),
        "experience": side.experience,
        "consumable_use_sequence": side.consumable_use_sequence,
        "last_recallable_consumable_id": side.last_recallable_consumable_id,
        "base_hand_limit_modifier": side.base_hand_limit_modifier,
        "hand_technique_multiplier_modifiers": side.hand_technique_multiplier_modifiers.duplicate(true),
        "used_unique_consumable_ids": side.used_unique_consumable_ids.duplicate(),
        "run_deck": run_deck.to_snapshot(),
    }
    if side.passive_counter_store != null:
        values["passive_counter_state"] = (
            side.passive_counter_store.capture_state())
    return RunProgressSnapshotScript.from_dict(values)

func _obtainable_owned_technique_ids(side) -> Array[String]:
    var result: Array[String] = []
    for technique_id_value in side.owned_technique_ids:
        var technique_id := str(technique_id_value)
        if not _is_built_in_technique(side, technique_id):
            result.append(technique_id)
    return result

func _replace_obtainable_owned_technique_ids(side, learned_ids: Array) -> void:
    var built_in_ids: Array[String] = []
    for technique_id_value in side.owned_technique_ids:
        var technique_id := str(technique_id_value)
        if _is_built_in_technique(side, technique_id):
            built_in_ids.append(technique_id)
    side.owned_technique_ids.assign(built_in_ids)
    for technique_id_value in learned_ids:
        side.learn_technique(str(technique_id_value))

func _is_built_in_technique(side, technique_id: String) -> bool:
    if _content_catalog != null:
        return bool(_content_catalog.get_by_id(
            "technique", technique_id).get("built_in", false))
    return side.technique_loadout_policy.is_built_in(technique_id)
