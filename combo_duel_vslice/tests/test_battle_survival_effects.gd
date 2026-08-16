extends "res://tests/support/technique_test_group.gd"


func _initialize() -> void:
    _run_group("battle-survival-effects", [
        "_test_damage_type_defense_life_and_block_facade",
        "_test_source_markers_life_and_defense_ports",
        "_test_poison_damage_modifiers_apply_per_segment",
        "_test_action_resolution_results_and_no_life_loss_disruption",
        "_test_reflection_override_sources_and_recursion_guard",
        "_test_synchronized_reflection_matches_normal_damage",
        "_test_unblockable_damage_still_absorbs_and_reflects",
    ])


func _test_damage_type_defense_life_and_block_facade() -> void:
    var engine = _engine_with_cards([])
    engine.enemy.life = 100
    engine.enemy.defense = 4
    var normal: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 6, "survival-test")
    _assert_equal(normal.get("defense_lost", 0), 4,
        "普通伤害先由防御吸收")
    _assert_equal(normal.get("life_lost", 0), 2,
        "普通伤害余量写入生命")

    engine.enemy.life = 100
    engine.enemy.defense = 4
    var true_hit: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 6, "survival-test", true,
        "survival-true", "true")
    _assert_equal(true_hit.get("defense_lost", 0), 0,
        "真伤不消耗防御")
    _assert_equal(engine.enemy.defense, 4,
        "真伤写入后保留原防御")
    _assert_equal(true_hit.get("life_lost", 0), 6,
        "真伤直接写入生命")

    engine.enemy.life = 100
    engine.enemy.defense = 4
    engine.enemy.set_reflection_percent(100)
    var player_life_before: int = int(engine.player.life)
    var poison: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 6, "survival-test", false,
        "survival-poison", "poison")
    _assert_equal(poison.get("defense_lost", 0), 0,
        "毒伤默认绕过普通防御")
    _assert_equal(engine.enemy.defense, 4,
        "毒伤默认不改写普通防御")
    _assert_equal(poison.get("life_lost", 0), 6,
        "毒伤默认直接写入生命")
    _assert_equal(engine.player.life, player_life_before,
        "毒伤不会触发反震")

    var defense_before: int = int(engine.player.defense)
    var gained: Dictionary = engine.effect_ports.add_defense_result(
        engine.player, 5, "survival-test", "survival-defense")
    _assert_true(gained.get("success", false), "防御增加通过Facade成功")
    _assert_equal(gained.get("gained", 0), 5, "防御增加写入实际增加量")
    _assert_equal(engine.player.defense, defense_before + 5,
        "防御增加写入BattleSide")

    engine.player.life = 95
    engine.player.max_life = 100
    var recovered: Dictionary = engine.effect_ports.recover_life(
        engine.player, 10, "survival-test", "survival-recovery",
        engine.player)
    _assert_equal(recovered.get("recovered", 0), 5,
        "生命恢复受最大生命限制")
    _assert_equal(engine.player.life, 100, "生命恢复正式写入BattleSide")

    engine.effect_ports.begin_action_resolution(
        [engine.player, engine.enemy], {
            "acting_owner_ids": [str(engine.enemy.owner_id)],
        })
    engine.effect_ports.grant_block_source(
        engine.player, engine.enemy, "unconditional", "专项格挡")
    var life_before_block: int = int(engine.player.life)
    var defense_before_block: int = int(engine.player.defense)
    var blocked: Dictionary = engine.effect_ports.deal_damage(
        engine.enemy, engine.player, 7, "survival-test", false,
        "survival-block", "normal", {"direct_attack": true})
    _assert_true(blocked.get("blocked", false), "合格直接伤害被格挡")
    _assert_equal(engine.player.life, life_before_block,
        "格挡只免疫当前伤害的生命写入")
    _assert_equal(engine.player.defense, defense_before_block,
        "格挡只免疫当前伤害的防御写入")
    _assert_equal(engine.player.block_sources.size(), 0,
        "成功格挡消费一个来源")
    engine.effect_ports.abort_action_resolution()
