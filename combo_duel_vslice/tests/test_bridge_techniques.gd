extends "res://tests/support/expanded_technique_test_base.gd"

const BRIDGE_TECHNIQUES := {
    "high_forest_drink_poison_growth":"林·饮蛊催生",
    "high_fire_burn_poison_momentum":"火·焚蛊催势",
    "pair_forest_poison_growth":"林·毒木共荣",
    "pair_wind_discard_poison":"风·弃蛊逐敌",
    "pair_fire_heat_to_momentum":"火·采薪成势",
    "pair_mountain_guard_root":"山·护根留青",
    "three_wind_spring_hand":"风·春风满袖",
    "three_fire_poison_pursuit":"火·蛊焰追身",
    "three_forest_high_card_cooperate":"林·连枝并式",
    "straight_wind_drain_poison_deck":"风·涸泽搜蛊",
}

func _initialize() -> void:
    if not _require_test_mode(): return
    var repository = _repository()
    _assert_resource_contract(repository, BRIDGE_TECHNIQUES)
    _test_each_base_effect()
    _test_burn_poison_and_heat_momentum()
    _test_discard_poison_response()
    _test_poison_pursuit_response()
    _test_synchronized_poison_completion()
    _test_cooperation_contract()
    _test_top_five_boundary()
    _test_spring_hand_next_round()
    _test_guard_root_after_defense_decay()
    _test_cooperation_resolution()
    _test_drain_poison_full_resolution()
    _finish("BRIDGE TECHNIQUE TEST")

func _test_each_base_effect() -> void:
    _assert_base_behavior("high_forest_drink_poison_growth", 10, 0)
    _assert_base_behavior("high_fire_burn_poison_momentum", 0, 20)
    _assert_base_behavior("pair_forest_poison_growth", 10, 0)
    _assert_base_behavior("pair_wind_discard_poison", 0, 10)
    _assert_base_behavior("pair_fire_heat_to_momentum", 0, 20)
    _assert_base_behavior("pair_mountain_guard_root", 20, 0)
    _assert_base_behavior("three_wind_spring_hand", 0, 10)
    _assert_base_behavior("three_fire_poison_pursuit", 0, 10)
    _assert_base_behavior("three_forest_high_card_cooperate", 10, 0)
    _assert_base_behavior("straight_wind_drain_poison_deck", 0, 10)

func _test_burn_poison_and_heat_momentum() -> void:
    var engine = _engine(4001)
    var poison = _card("8", "fire")
    engine.player.hand = [poison]
    engine.status_system.apply_card_anomaly(poison, "state", "poison", {}, "测试")
    var result: Dictionary = engine.effect_executor.execute_all([
        {"op":"capture_metadata","capture":"card","result_capture":"before"},
        {"op":"apply_card_anomaly_to_captured","capture":"card","category":"debuff","anomaly":"burned_out","result_capture":"burned"},
        {"op":"write_momentum","operation":"add","amount":{"kind":"divide_floor","value":{"kind":"capture_field_first","capture":"before","field":"effective_qi"},"divisor":2},"when":{"capture_nonempty":"burned"}},
    ], _context(engine, {"card":[poison]}))
    _assert_true(result.get("success", false), "焚蛊催势依赖链成功")
    _assert_true(poison.has_anomaly("state", "poison") and poison.has_anomaly("debuff", "burned_out"), "燃尽不触发或清除毒")
    _assert_equal(engine.player.momentum_value, 4, "焚蛊按燃尽前V/2获得连势")
    var heat = _card("5")
    engine.status_system.apply_card_anomaly(heat, "buff", "qi_heat", {}, "测试", 6)
    engine.effect_executor.execute_all([
        {"op":"remove_anomaly_layers","capture":"card","category":"buff","anomaly":"qi_heat","all":true,"result_capture":"q"},
        {"op":"write_momentum","operation":"add","amount":{"kind":"capture_field_first","capture":"q","field":"amount"}},
    ], _context(engine, {"card":[heat]}))
    _assert_equal(engine.player.momentum_value, 10, "采薪将全部Q转换为连势")
    _assert_equal(heat.anomaly_layers("buff", "qi_heat"), 0, "采薪移除全部炽气")

func _test_discard_poison_response() -> void:
    var engine = _engine(4002)
    var card = _card("7")
    engine.player.hand = [card]
    engine.status_system.apply_card_anomaly(card, "state", "poison", {}, "测试")
    engine.status_system.register_response("card_moved", "turn_end", [
        {"op":"damage","damage_type":"poison","amount":{"kind":"capture_field_first","capture":"event_snapshot","field":"effective_qi"}}
    ], _context(engine, {}), {"owner":"actor","reason":"explicit_discard","from_zone":"hand","had_poison":true})
    engine.effect_ports.move_card(engine.player, "hand", engine.player, "discard_pile", card, "explicit_discard", "top", "test")
    _assert_equal(engine.enemy.life, 93, "弃蛊逐敌按明确弃牌前V造成毒伤")
    var played = _card("6")
    engine.player.hand = [played]
    engine.status_system.apply_card_anomaly(played, "state", "poison", {}, "测试")
    engine.effect_ports.move_card(engine.player, "hand", engine.player, "discard_pile", played, "play_commit", "top", "test")
    _assert_equal(engine.enemy.life, 93, "普通打出入堆不误触明确弃牌响应")

func _test_poison_pursuit_response() -> void:
    var engine = _engine(4003)
    var card = _card("4")
    engine.enemy.hand = [card]
    engine.status_system.apply_card_anomaly(card, "state", "poison", {}, "测试")
    engine.status_system.register_response("poison_trigger_completed", "turn_end", [
        {"op":"damage","amount":4},
        {"op":"write_momentum","operation":"add","amount":1}
    ], _context(engine, {}), {"holder":"target"})
    engine.effect_ports.trigger_poison_card(engine.enemy, card, "test")
    _assert_equal(engine.enemy.life, 92, "一次毒触发完成产生一次普通追击")
    _assert_equal(engine.player.momentum_value, 1, "每次追击后获得1连势")

func _test_synchronized_poison_completion() -> void:
    var engine = _engine(4010)
    var card = _card("4")
    engine.player.hand = [card]
    engine.status_system.apply_card_anomaly(card, "state", "poison", {}, "测试")
    engine.status_system.register_response("poison_trigger_completed", "turn_end", [
        {"op":"damage","damage_type":"poison","amount":{"kind":"capture_field_first","capture":"event","field":"actual_life_loss"}}
    ], _context(engine, {"source":[card]}), {
        "owner":"actor", "source_card_instance_ids_from_capture":"source"})
    engine.effect_ports.begin_synchronized_damage([{"actor":engine.player}])
    engine.effect_ports.trigger_poison_card(engine.player, card, "sync-poison")
    _assert_true(engine.effect_ports.flush_synchronized_damage().get(
        "success", false), "同步毒触发结构化 flush 成功")
    _assert_equal(engine.player.life, 96, "同步毒触发在真实写入时扣除持有者生命")
    _assert_equal(engine.enemy.life, 96, "同步毒触发完成事件在flush后携带实际生命损失")

func _test_cooperation_contract() -> void:
    var repository = _repository()
    var definition = repository.get_definition("three_forest_high_card_cooperate")
    _assert_equal(definition.cooperation.get("hand_id"), "high_card", "连枝并式协同高牌")
    _assert_equal(definition.cooperation.get("exact_card_count"), 1, "连枝并式协同精确1张")
    _assert_equal(definition.cooperation.get("card_has_any_anomaly", []).size(), 2, "连枝并式只允许毒或成长牌")

func _test_top_five_boundary() -> void:
    var engine = _engine(4004)
    var cards := [_card("2"), _card("3"), _card("4"), _card("5"), _card("6"), _card("7")]
    engine.enemy.draw_pile = cards.duplicate()
    var context = _context(engine, {})
    var result: Dictionary = engine.effect_executor.execute_all([
        {"op":"capture_query","query":{"side":"target","zone":"draw_pile","order":"top","limit":5,"filters":{"card_kind":"normal"}},"capture":"shown"}
    ], context)
    _assert_true(result.get("success", false), "涸泽顶5展示查询成功")
    _assert_equal(context.captures["shown"].size(), 5, "涸泽最多展示5张")
    _assert_true(not context.captures["shown"].has(cards[0]), "涸泽不泄露第6张以后内容")

func _test_spring_hand_next_round() -> void:
    var engine = _engine(4005)
    var definition = engine.repository.get_definition("three_wind_spring_hand")
    var result: Dictionary = engine.effect_executor.execute_all(
        definition.effects, _context(engine, {}))
    _assert_true(result.get("success", false), "春风满袖建立下一回合记录")
    var deck: Array = []
    for rank in ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J"]:
        deck.append(_card(rank))
    var grown = deck.back()
    engine.status_system.apply_card_anomaly(grown, "buff", "growth", {}, "测试", 2)
    engine.player.draw_pile = deck
    engine.round_service.turn_number = 1
    engine.round_service.battle_start_card_effects_applied = true
    var drawn: Array = engine.start_player_turn()
    _assert_equal(drawn.size(), 10, "春风下一完整回合按上限+2正常补牌")
    _assert_equal(grown.anomaly_layers("buff", "qi_heat"), 2, "春风只给本次正常补入的成长牌生成炽气")
    engine._finish_round_end()
    _assert_equal(engine.player.base_hand_limit_modifier, 0, "春风手牌上限修正在该回合结束时到期")

func _test_guard_root_after_defense_decay() -> void:
    var engine = _engine(4006)
    var target = _card("5")
    engine.player.hand = [target]
    var definition = engine.repository.get_definition("pair_mountain_guard_root")
    var result: Dictionary = engine.effect_executor.execute_all(
        definition.effects, _context(engine, {}))
    _assert_true(result.get("pending_choice", false), "护根留青等待锁定手牌")
    result = engine.effect_executor.resume(
        result["_continuation"], str(result["choice_request"]["request_id"]),
        [str(target.id)])
    _assert_true(result.get("success", false), "护根留青完成目标锁定")
    engine.round_service.turn_number = 1
    engine._finish_round_end()
    _assert_equal(engine.player.defense, 10, "护根在公共防御保留后读取剩余防御")
    _assert_equal(target.anomaly_layers("buff", "growth"), 1, "护根防御仍大于0时培养锁定手牌")

    var depleted = _engine(4007)
    var depleted_target = _card("6")
    depleted.player.hand = [depleted_target]
    definition = depleted.repository.get_definition("pair_mountain_guard_root")
    result = depleted.effect_executor.execute_all(definition.effects, _context(depleted, {}))
    result = depleted.effect_executor.resume(
        result["_continuation"], str(result["choice_request"]["request_id"]),
        [str(depleted_target.id)])
    depleted.player.defense = 0
    depleted.round_service.turn_number = 1
    depleted._finish_round_end()
    _assert_equal(depleted_target.anomaly_layers("buff", "growth"), 0, "护根防御提前耗尽时不培养")

func _test_cooperation_resolution() -> void:
    var engine = _engine(4008)
    var main := [_card("6"), _card("6", "fire"), _card("6", "mountain")]
    var cooperation = _card("4")
    var growth_target = _card("9")
    engine.player.hand = main + [cooperation, growth_target]
    engine.status_system.apply_card_anomaly(cooperation, "state", "poison", {}, "测试")
    engine.status_system.apply_card_anomaly(cooperation, "buff", "growth", {}, "测试", 3)
    engine.enemy.defense = 100
    engine.sequence_book.configure({
        "three_kind":["three_forest_high_card_cooperate"],
        "high_card":["basic_scatter"],
    })
    engine.actions_available = 1
    var result: Dictionary = engine.confirm_play(
        main.map(func(card): return str(card.id)), [str(cooperation.id)])
    _assert_true(result.get("pending_choice", false), "连枝并式正式行动等待成长转移目标")
    result = engine.resolve_effect_choice(
        str(result["choice_request"]["request_id"]), [str(growth_target.id)])
    _assert_true(result.get("success", false), "连枝并式主组与高牌协同完整结算")
    var poison_responses: Array = engine.status_system.response_records.filter(
        func(record): return str(record.get("event_kind", "")) == "poison_trigger_completed" \
            and not record.get("filters", {}).get("source_card_instance_ids", []).is_empty())
    _assert_equal(poison_responses.size(), 1, "连枝建立一份毒触发响应")
    if not poison_responses.is_empty():
        _assert_equal(
            poison_responses[0].get("filters", {}).get("source_card_instance_ids", []),
            [str(cooperation.id)], "连枝响应只冻结协同牌来源")
    _assert_equal(engine.player.life, 100, "连枝自身防御先吸收协同毒牌伤害")
    _assert_equal(engine.enemy.life, 100, "连枝追加毒伤被敌方高防御吸收")
    _assert_equal(engine.enemy.defense, 99, "连枝只按我方实际生命损失追加1点毒伤")
    _assert_equal(cooperation.anomaly_layers("buff", "growth"), 0, "连枝协同牌入堆前移除全部成长")
    _assert_equal(growth_target.anomaly_layers("buff", "growth"), 3, "连枝把协同牌全部成长原子转给所选手牌")

func _test_drain_poison_full_resolution() -> void:
    var engine = _engine(4009)
    var hidden = _card("2")
    var first = _card("3")
    var second = _card("4")
    var poison_a = _card("5")
    var third = _card("6")
    var poison_b = _card("7")
    engine.enemy.draw_pile = [hidden, first, second, poison_a, third, poison_b]
    engine.status_system.apply_card_anomaly(poison_a, "state", "poison", {}, "测试")
    engine.status_system.apply_card_anomaly(poison_b, "state", "poison", {}, "测试")
    var definition = engine.repository.get_definition("straight_wind_drain_poison_deck")
    var result: Dictionary = engine.effect_executor.execute_all(
        definition.effects, _context(engine, {}))
    _assert_true(result.get("pending_choice", false), "涸泽批量弃毒后等待重排其余展示牌")
    _assert_equal(engine.enemy.life, 78, "涸泽造成基础10伤害与冻结值12毒伤")
    _assert_true(engine.enemy.discard_pile.has(poison_a) and engine.enemy.discard_pile.has(poison_b), "涸泽批量明确弃掉全部展示毒牌")
    var candidates: Array = result["choice_request"]["candidate_ids"]
    candidates.reverse()
    result = engine.effect_executor.resume(
        result["_continuation"], str(result["choice_request"]["request_id"]),
        candidates)
    _assert_true(result.get("success", false), "涸泽按玩家选择恢复并重排牌库顶")
    _assert_equal(str(engine.enemy.draw_pile.back().id), str(candidates[0]), "涸泽选择顺序第一张位于牌库顶")
    _assert_true(engine.enemy.draw_pile.has(hidden), "涸泽不移动展示范围外第6张")

func _context(engine, captures: Dictionary):
    return EffectContextScript.new().configure({
        "ports":engine.effect_ports, "actor":engine.player, "target":engine.enemy,
        "power":20, "initial_power":20, "captures":captures,
        "group_snapshot":{}, "technique_name":"桥接专项", "action_token":"test-1-001"})
