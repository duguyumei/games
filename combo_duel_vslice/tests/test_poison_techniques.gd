extends "res://tests/support/expanded_technique_test_base.gd"

const POISON_TECHNIQUES := {
    "high_forest_contain_poison":"林·含毒", "high_forest_bury_poison":"林·埋蛊",
    "high_forest_shed_shell":"林·蜕壳", "high_forest_trigger_poison":"林·催蛊",
    "pair_forest_double_cache":"林·双藏", "pair_forest_transfer_poison":"林·移花接蛊",
    "pair_forest_hide_poison":"林·蛰蛊藏息", "pair_forest_raise_poison":"林·养蛊",
    "pair_forest_swarm_guard":"林·群蛊护脉", "pair_forest_embrace_poison":"林·抱毒守元",
    "pair_forest_poison_heart":"林·饮鸩攻心", "three_forest_recover_poison_root":"林·回蛊养根",
    "three_forest_hundred_poison":"林·百蛊侵脉",
    "three_forest_bone_poison":"林·刮骨渡毒", "straight_forest_hidden_root":"林·潜根",
    "straight_forest_poison_armor":"林·残蛊化甲", "straight_forest_poison_march":"林·毒行千里",
    "straight_forest_five_leaf_poison":"林·五叶归蛊", "bomb_forest_cleanse_poison":"林·洗脉藏蛊",
    "bomb_forest_all_poison":"林·万蛊同寂", "bomb_forest_defense_poison":"林·腐甲生蛊",
    "high_forest_shared_fate_poison":"林·同命淬蛊",
    "high_forest_poison_meridian_echo":"林·蛊脉自鸣",
    "pair_forest_borrow_momentum_poison":"林·借势催蛊",
}

func _initialize() -> void:
    if not _require_test_mode(): return
    var repository = _repository()
    _assert_resource_contract(repository, POISON_TECHNIQUES)
    _test_each_base_effect()
    _test_poison_damage_contract()
    _test_poison_totals_and_burnout()
    _test_immediate_and_simultaneous_trigger()
    _test_explicit_discard_snapshot()
    _test_five_leaf_after_discard_cleanup()
    _finish("POISON TECHNIQUE TEST")

func _test_each_base_effect() -> void:
    var defense_ids := POISON_TECHNIQUES.keys().filter(func(id):
        return id not in [
            "pair_forest_poison_heart", "straight_forest_poison_march",
            "high_forest_shared_fate_poison",
            "high_forest_poison_meridian_echo"])
    for technique_id in defense_ids:
        if technique_id == "bomb_forest_defense_poison":
            continue
        _assert_base_behavior(technique_id, 10, 0)
    _assert_base_behavior("pair_forest_poison_heart", 0, 10)
    _assert_base_behavior("straight_forest_poison_march", 0, 10)
    var defense_engine = _engine(2001)
    defense_engine.player.defense = 12
    var result := _execute(defense_engine, "bomb_forest_defense_poison", 20)
    _assert_true(result.get("success", false), "林·腐甲生蛊主效果链执行")
    _assert_equal(defense_engine.player.defense, 10, "林·腐甲生蛊先移除F再获得floor(P/2)")
    _assert_equal(defense_engine.enemy.life, 94, "林·腐甲生蛊按F/2造成毒伤")

func _test_poison_damage_contract() -> void:
    var engine = _engine(2002)
    engine.enemy.defense = 30
    engine.enemy.current_reflection_percent = 100
    var vulnerable = _card("5")
    engine.player.hand = [vulnerable]
    engine.status_system.apply_card_anomaly(vulnerable, "state", "vulnerability", {}, "测试")
    var result: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 9, "专项毒伤", false, "poison-test", "poison")
    _assert_equal(result.get("damage_type"), "poison", "毒伤结果公开独立伤害类型")
    _assert_equal(result.get("life_lost"), 9, "毒伤结果公开实际生命损失")
    _assert_equal(engine.enemy.defense, 30, "毒伤默认不消耗防御")
    _assert_equal(engine.enemy.life, 91, "毒伤直接损失生命")
    _assert_equal(engine.player.life, 100, "毒伤不触发反震")

func _test_poison_totals_and_burnout() -> void:
    var engine = _engine(2003)
    var hand_poison = _card("7")
    var burned = _card("A")
    var deck_poison = _card("4")
    for card in [hand_poison, burned, deck_poison]:
        engine.status_system.apply_card_anomaly(card, "state", "poison", {}, "测试")
    engine.status_system.apply_card_anomaly(burned, "debuff", "burned_out", {}, "测试")
    engine.player.hand = [hand_poison, burned]
    engine.player.draw_pile = [deck_poison]
    var totals: Dictionary = engine.player.poison_totals()
    _assert_equal(totals["hand_count"], 2, "H毒牌张数包含燃尽毒牌")
    _assert_equal(totals["hand_amount"], 7, "燃尽毒牌对H贡献0")
    _assert_equal(totals["draw_pile_amount"], 4, "D读取牌库毒量")
    _assert_equal(totals["total_amount"], 11, "T=H+D")

func _test_immediate_and_simultaneous_trigger() -> void:
    var engine = _engine(2004)
    var player_card = _card("6")
    var enemy_card = _card("8")
    engine.player.hand = [player_card]
    engine.enemy.hand = [enemy_card]
    engine.status_system.apply_card_anomaly(player_card, "state", "poison", {}, "测试")
    engine.status_system.apply_card_anomaly(enemy_card, "state", "poison", {}, "测试")
    var immediate: Dictionary = engine.effect_ports.trigger_poison_card(engine.player, player_card, "test")
    _assert_true(immediate.get("success", false), "功法立即触毒走公共入口")
    _assert_equal(immediate.get("actual_life_loss"), 6, "立即触毒返回实际生命损失")
    _assert_true(not player_card.has_anomaly("state", "poison"), "毒伤完成后清除毒")
    engine.status_system.apply_card_anomaly(player_card, "state", "poison", {}, "测试")
    engine.player.life = 5
    engine.enemy.life = 5
    var sync: Dictionary = _execute(engine, "bomb_forest_all_poison", 20)
    _assert_true(sync.get("success", false), "万蛊同寂同步毒爆执行")
    _assert_equal(engine.player.life, 0, "同步毒爆处理我方致死")
    _assert_equal(engine.enemy.life, 0, "同步毒爆不因我方先死漏掉敌方")
    _assert_true(engine.player.hand.has(player_card) and engine.enemy.hand.has(enemy_card), "同步毒爆不移动目标牌")

func _test_explicit_discard_snapshot() -> void:
    var engine = _engine(2005)
    var card = _card("9")
    engine.player.hand = [card]
    engine.status_system.apply_card_anomaly(card, "state", "poison", {}, "测试")
    engine.status_system.register_response("card_moved", "turn_end", [
        {"op":"capture_value","value":{"kind":"capture_field_first","capture":"event_snapshot","field":"effective_qi"},"capture":"seen"}
    ], _context(engine), {"owner":"actor","reason":"explicit_discard","had_poison":true})
    var moved: Dictionary = engine.effect_ports.move_card(
        engine.player, "hand", engine.player, "discard_pile", card,
        "explicit_discard", "top", "test")
    _assert_true(moved.get("success", false), "明确弃牌移动成功")
    _assert_true(not card.has_anomaly("state", "poison"), "明确弃牌入堆后毒已清理")
    _assert_true(not engine.status_system.history.is_empty(), "明确弃牌提交清理前快照供响应读取")

func _test_five_leaf_after_discard_cleanup() -> void:
    var engine = _engine(2006)
    var first = _card("2")
    var second = _card("3")
    engine.player.staging = [first, second]
    var definition = engine.repository.get_definition("straight_forest_five_leaf_poison")
    var context = EffectContextScript.new().configure({
        "ports":engine.effect_ports, "actor":engine.player, "target":engine.enemy,
        "power":20, "initial_power":20, "played_cards":[first, second],
        "group_snapshot":{"played_cards":[first, second]}, "captures":{},
        "technique_name":definition.display_name, "action_token":"test-1-006"})
    var result: Dictionary = engine.effect_executor.execute_all(definition.effects, context)
    _assert_true(result.get("success", false), "五叶归蛊建立入堆后响应")
    engine.player.card_zone_service.commit_staging(engine.player)
    _assert_true(first.has_anomaly("state", "poison") and second.has_anomaly("state", "poison"), "五叶在原状态清理后重新施毒")
    _assert_true(engine.player.draw_pile.has(first) and engine.player.draw_pile.has(second), "五叶将全部实际入堆牌洗回")
    _assert_true(engine.player.discard_pile.is_empty(), "五叶响应完成后弃牌堆不残留目标")

func _context(engine):
    return EffectContextScript.new().configure({
        "ports":engine.effect_ports, "actor":engine.player, "target":engine.enemy,
        "power":20, "initial_power":20, "captures":{}, "action_token":"test-1-001",
        "technique_name":"专项响应"})
