extends "res://tests/support/expanded_technique_test_base.gd"

const ValueResolverScript = preload("res://core/effects/effect_value_resolver.gd")
const InstanceDataScript = preload("res://core/qi_card_instance_data.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")

const WIND_BY_POOL := {
    "high": [
        "high_wind_scout", "high_wind_scatter", "high_wind_startle",
        "high_wind_lure", "high_wind_exchange", "high_wind_mixed_flow",
        "high_wind_piercing_cloud", "high_wind_companion",
        "high_wind_take_initiative", "high_wind_empty_sleeve",
        "high_wind_break_page", "high_wind_turbulence",
        "high_wind_seize_advantage", "high_wind_sweep_tail",
        "high_wind_three_breath_return",
    ],
    "pair": [
        "pair_wind_discard_poison", "pair_wind_change_feather",
        "pair_wind_dyed_sleeve", "pair_wind_returning_swallow",
        "pair_wind_exchange_hands", "pair_wind_cut_supplies",
        "pair_wind_turn_sleeve", "pair_wind_break_peak",
        "pair_wind_returning_tide",
    ],
    "three": [
        "three_wind_spring_hand", "three_wind_full_sail",
        "three_wind_return_tide", "three_wind_exploit_gap",
        "three_wind_continue_form", "three_wind_chase_empty",
        "three_wind_scatter_four", "three_wind_fall_together",
        "three_wind_falling_sign",
    ],
    "straight": [
        "straight_wind_drain_poison_deck", "straight_wind_pierce_sun",
        "straight_wind_cross_forest", "straight_wind_return_cycle",
        "straight_wind_open_path", "straight_wind_cut_flow",
        "straight_wind_reverse_journey", "straight_wind_change_route",
        "straight_wind_strip_reshape", "straight_wind_rise_fall",
    ],
    "bomb": [
        "bomb_wind_whale_draw", "bomb_wind_soar", "bomb_wind_cosmic_sleeve",
        "bomb_wind_cover_sky", "bomb_wind_sky_curtain", "bomb_wind_drain_sea",
        "bomb_wind_scatter_formation", "bomb_wind_turbulent_sea",
        "bomb_wind_plunder_empty", "bomb_wind_purge_anomaly",
        "bomb_wind_isolate_group", "bomb_wind_empty_hand",
    ],
}

func _initialize() -> void:
    if not _require_test_mode(): return
    _test_catalog_and_counts()
    _test_meridian_draw_rules()
    _test_void_departures()
    _test_temporary_rank_lifecycle()
    _test_forest_generation_modes()
    _test_frozen_exclusions()
    _test_atomic_exchange_and_synchronous_discard()
    _test_live_block_and_echo_guard()
    _test_wind_timing_and_targeting_ports()
    _test_wind_resource_boundaries()
    _test_break_page_burned_out_bridge()
    _test_continue_form_integrated()
    _test_scatter_four_echoes()
    _test_returning_swallow_post_commit()
    _test_return_tide_post_commit()
    _test_bomb_k()
    _finish("WIND TECHNIQUE TEST")

func _test_catalog_and_counts() -> void:
    var repository = _repository()
    var wind_count := 0
    for pool in WIND_BY_POOL:
        for technique_id in WIND_BY_POOL[pool]:
            wind_count += 1
            var definition = repository.get_definition(technique_id)
            _assert_true(definition != null, "%s可识别" % technique_id)
            if definition != null:
                _assert_equal(definition.pool, pool, "%s池归属" % technique_id)
                _assert_true(not definition.effects.is_empty(), "%s效果链非空" % technique_id)
                _assert_true(not definition.semantic_tags.is_empty(), "%s AI语义非空" % technique_id)
    _assert_equal(wind_count, 55, "风系稳定ID共55门")
    var counts := {"high":0, "pair":0, "three":0, "straight":0, "bomb":0}
    var normal_count := 0
    for technique_id in repository.formal_technique_ids():
        var definition = repository.get_definition(technique_id)
        if definition == null or definition.built_in:
            continue
        normal_count += 1
        counts[definition.pool] = int(counts.get(definition.pool, 0)) + 1
    _assert_equal(normal_count, 226, "非内建正式功法226门")
    _assert_equal(counts, {"high":60,"pair":54,"three":35,"straight":37,"bomb":40}, "五池数量准确")

func _test_meridian_draw_rules() -> void:
    var engine = _engine(4101)
    var meridian_card = _card("2", "wind")
    engine.status_system.apply_card_anomaly(meridian_card, "mark", "meridian", {}, "测试")
    engine.player.hand = [meridian_card]
    for rank in ["3", "4", "5", "6", "7", "8", "9"]:
        engine.player.hand.append(_card(rank, "wind"))
    engine.player.draw_pile = [_card("10", "forest"), _card("J", "fire")]
    var drawn: Array = engine.player.draw_to_limit("normal_draw")
    _assert_equal(drawn.size(), 1, "正常补牌按占脉逐张重查")
    _assert_equal(engine.player.actual_hand_count(), 9, "寄脉仍计入实际手牌")
    _assert_equal(engine.player.occupied_meridian_count(), 8, "寄脉不占容量")
    var explicit: Array = engine.effect_ports.draw(engine.player, 1, "technique")
    _assert_equal(explicit.size(), 1, "明确抽牌不受八脉容量限制")
    var preview_card = meridian_card
    _assert_true(engine.player.card_zone_service.stage_cards(engine.player, [preview_card.id]), "寄脉牌可进入预览待出区")
    _assert_true(preview_card.has_anomaly("mark", "meridian"), "预览待出不移除寄脉")
    engine.player.card_zone_service.rollback_staging(engine.player)
    _assert_true(preview_card.has_anomaly("mark", "meridian"), "预览回滚保留寄脉")

func _test_void_departures() -> void:
    var engine = _engine(4102)
    var receipt_count_before: int = int(
        engine.battle_passive_event_service.receipt_store.size())
    var played = _card("4", "wind")
    var discarded = _card("5", "wind")
    engine.status_system.apply_card_anomaly(played, "mark", "void", {}, "测试")
    engine.status_system.apply_card_anomaly(discarded, "mark", "void", {}, "测试")
    engine.player.staging = [played]
    engine.player.hand = [discarded]
    var play_result: Dictionary = engine.player.card_zone_service.move_card(
        engine.player, "staging", "discard_pile", played, "normal_play")
    var discard_result: Dictionary = engine.player.card_zone_service.move_card(
        engine.player, "hand", "discard_pile", discarded, "explicit_discard")
    _assert_true(play_result.get("dispersed", false), "虚无打出后消散")
    _assert_true(discard_result.get("dispersed", false), "虚无明确弃置响应后消散")
    _assert_true(engine.player.discard_pile.is_empty(), "两条虚无路径均不进入弃牌堆")
    _assert_equal(engine.player.temporarily_removed_cards.size(), 2, "虚无牌进入战斗临时移除区")
    _assert_equal(
        engine.battle_passive_event_service.receipt_store.size() - receipt_count_before,
        3,
        "虚无两条路径各发送一次card_moved，明确弃置另发一次专项事件且不发送入堆事件")

func _test_temporary_rank_lifecycle() -> void:
    var card = _card("4", "forest")
    _assert_true(card.set_temporary_rank("9", 9, 9), "临时牌阶可设置")
    _assert_equal(card.current_rank_name(), "9", "临时牌阶参与当前牌阶查询")
    _assert_equal(card.current_base_qi_value(), 9, "临时牌阶参与标准基础真气值")
    var paired = _card("9", "wind")
    _assert_equal(HandEvaluatorScript.evaluate([card, paired])["id"], "pair", "临时牌阶参与牌型识别")
    card.set_anomaly("mark", "return_to_origin")
    _assert_equal(card.current_rank_name(), "4", "归元压制临时牌阶")
    _assert_true(card.has_any_reshape_storage(), "归元压制时仍算存有重塑")
    card.remove_anomaly("mark", "return_to_origin")
    _assert_equal(card.current_rank_name(), "9", "归元消失后临时牌阶恢复")
    var snapshot := InstanceDataScript.capture(card, true)
    var restored = InstanceDataScript.restore(snapshot)
    _assert_equal(restored.current_rank_name(), "9", "战斗快照恢复临时牌阶")
    var purification_engine = _engine(4110)
    purification_engine.status_system.apply_card_anomaly(
        restored, "mark", "purification", {}, "测试")
    _assert_equal(restored.current_rank_name(), "4", "净化清除临时牌阶")
    restored.set_temporary_rank("9", 9, 9)
    restored.clear_combat_state()
    _assert_equal(restored.current_rank_name(), "4", "战斗结束清理临时牌阶")

func _test_forest_generation_modes() -> void:
    var engine = _engine(4103)
    var source = _card("2", "forest")
    engine.player.hand = [source]
    for options in [
            {"rank_mode":"same_current","attribute_mode":"random_other_base"},
            {"rank_mode":"random_adjacent","attribute_mode":"same_base"},
            {"rank_mode":"random_adjacent","attribute_mode":"random_other_base"}]:
        var generated = engine.effect_ports.generate_temporary_normal_card(
            engine.player, source, options)
        _assert_true(generated != null and generated.temporary_card, "林系生成战斗临时普通真气")
        _assert_true(generated.has_anomaly("mark", "void"), "功法生成牌默认获得虚无")
        if options["rank_mode"] == "random_adjacent":
            _assert_equal(generated.current_rank_order(), 3, "牌阶2的相邻随机只能升阶")
        if options["attribute_mode"] == "same_base":
            _assert_equal(generated.attribute, "forest", "同基础属性生成准确")
        else:
            _assert_true(generated.attribute != "forest", "随机异基础属性不取来源属性")
        _assert_true(not generated.has_any_reshape_storage(), "生成牌不继承或存入重塑")
    var ace = _card("A", "forest")
    var below_ace = engine.effect_ports.generate_temporary_normal_card(
        engine.player, ace, {"rank_mode":"random_adjacent","attribute_mode":"same_base"})
    _assert_equal(below_ace.current_rank_order(), 13, "牌阶A的相邻随机只能降阶")

func _test_frozen_exclusions() -> void:
    var engine = _engine(4104)
    var excluded = _card("6", "forest")
    engine.player.draw_pile = [_card("6", "wind"), _card("7", "forest"), _card("8", "fire")]
    var result: Dictionary = engine.effect_executor.execute_all([{
        "op":"draw_filtered", "query":{
            "side":"actor", "zone":"draw_pile", "order":"random", "limit":2,
            "filters":{"card_kind":"normal","exclude_rank_orders_from_capture":"excluded"}},
        "capture":"drawn"}], _context(engine, {"excluded":[excluded]}))
    _assert_true(result.get("success", false), "冻结牌阶定向检索执行")
    _assert_equal(engine.player.hand.size(), 2, "合法目标不足时少抽且不回退普通抽牌")
    for card in engine.player.hand:
        _assert_true(card.current_rank_order() != 6, "定向检索排除冻结牌阶")
    var attribute_engine = _engine(4109)
    var forest_source = _card("5", "forest")
    attribute_engine.player.draw_pile = [
        _card("6", "forest"), _card("7", "wind")]
    var attribute_context = _context(
        attribute_engine, {"selected":[forest_source]})
    var attribute_result: Dictionary = attribute_engine.effect_executor.execute_all([
        {"op":"capture_metadata","capture":"selected","result_capture":"frozen"},
        {"op":"draw_filtered","query":{
            "side":"actor","zone":"draw_pile","order":"random","limit":2,
            "filters":{"card_kind":"normal","exclude_base_attributes_from_capture":"frozen"}},
            "capture":"drawn"}], attribute_context)
    _assert_true(attribute_result.get("success", false), "冻结基础属性定向检索执行")
    _assert_equal(attribute_engine.player.hand.size(), 1, "冻结基础属性被真实排除且不足时少抽")
    _assert_equal(attribute_engine.player.hand[0].attribute, "wind", "新抽牌基础属性不在冻结集合")

func _test_atomic_exchange_and_synchronous_discard() -> void:
    var engine = _engine(4105)
    var actor_card = _card("3", "wind")
    var target_card = _card("K", "fire")
    engine.status_system.apply_card_anomaly(actor_card, "mark", "meridian", {}, "测试")
    engine.player.hand = [actor_card]
    engine.enemy.draw_pile = [target_card]
    var exchange: Dictionary = engine.effect_ports.atomic_exchange_cards(
        engine.player, "hand", actor_card, engine.enemy, "draw_pile", target_card)
    _assert_true(exchange.get("success", false), "单牌交换原子完成")
    _assert_equal(engine.player.hand, [target_card], "我方获得敌方冻结牌")
    _assert_equal(engine.enemy.hand, [actor_card], "敌方获得我方冻结牌")
    _assert_true(not actor_card.has_anomaly("mark", "meridian"), "寄脉真实离手立即清除")
    _assert_equal(target_card.original_owner_id, engine.enemy.owner_id, "交换记录原持有者")
    var returned: Dictionary = engine.enemy.return_transferred_card_to(engine.player, actor_card.id)
    _assert_true(returned.get("success", false), "交换牌可按原持有者归还")
    var actor_discard = _card("7", "wind")
    var target_discard = _card("8", "forest")
    engine.player.hand = [actor_discard]
    engine.enemy.hand = [target_discard]
    var moved: Array = engine.effect_ports.move_cards_synchronously([
        {"side":engine.player,"source_zone":"hand","destination_zone":"discard_pile","card":actor_discard,"reason":"explicit_discard"},
        {"side":engine.enemy,"source_zone":"hand","destination_zone":"discard_pile","card":target_discard,"reason":"explicit_discard"},
    ])
    _assert_equal(moved.size(), 2, "双方目标冻结后同步弃置")
    _assert_true(engine.player.hand.is_empty() and engine.enemy.hand.is_empty(), "同步弃置完成全部离手")

    var return_engine = _engine(4119)
    var own = _card("4", "wind")
    var theirs = _card("Q", "fire")
    return_engine.player.hand = [own]
    return_engine.enemy.draw_pile = [theirs]
    return_engine.effect_ports.atomic_exchange_cards(
        return_engine.player, "hand", own,
        return_engine.enemy, "draw_pile", theirs)
    var battle_end: Dictionary = return_engine.timing_system.emit_timing(
        "battle_end", {"actors":[return_engine.player, return_engine.enemy]})
    _assert_true(battle_end.get("success", false), "战斗结束公共时点完成交换牌归还")
    _assert_true(return_engine.player.draw_pile.has(own), "我方送出的交换牌战后回到我方牌库")
    _assert_true(return_engine.enemy.draw_pile.has(theirs), "敌方送出的交换牌战后回到敌方牌库")
    _assert_equal(own.original_owner_id, "", "归还后清除我方牌的原持有者记录")
    _assert_equal(theirs.original_owner_id, "", "归还后清除敌方牌的原持有者记录")

    var removed_engine = _engine(4120)
    var stolen = _card("10", "mountain")
    removed_engine.enemy.draw_pile = [stolen]
    var transfer: Dictionary = removed_engine.enemy.card_zone_service.temporarily_transfer(
        removed_engine.enemy, removed_engine.player, str(stolen.id), "hand")
    _assert_true(transfer.get("success", false), "夺取牌记录原持有者")
    removed_engine.player.card_zone_service.temporarily_remove(
        removed_engine.player, str(stolen.id), "void")
    removed_engine.timing_system.emit_timing(
        "battle_end", {"actors":[removed_engine.player, removed_engine.enemy]})
    _assert_true(removed_engine.enemy.draw_pile.has(stolen), "临时移除区中的被夺牌也在战后归还")
    _assert_true(not removed_engine.player.temporarily_removed_cards.has(stolen), "归还后不残留在临时移除区")

func _test_live_block_and_echo_guard() -> void:
    var side = _engine(4106).player
    side.add_block_source("actual_hand_more_than_attacker", "test", "enemy", "window")
    var failed: Dictionary = side.try_consume_block(5, "normal", "enemy", "window", 1, 2)
    _assert_true(not failed.get("blocked", false), "实时手牌不多时格挡不消耗")
    var success: Dictionary = side.try_consume_block(5, "normal", "enemy", "window", 3, 2)
    _assert_true(success.get("blocked", false), "攻击到来时手牌更多则格挡")
    var engine = _engine(4107)
    var context = _context(engine)
    context.source_kind = "technique"
    context.trigger_mode = "echo"
    var repeat: Dictionary = engine.effect_executor.execute_all([{
        "op":"repeat_effects", "count":2,
        "effects":[{"op":"damage","amount":5}]}], context)
    _assert_true(repeat.get("success", false), "回响来源执行链安全结束")
    _assert_equal(engine.enemy.life, 100, "回响不能递归产生新回响")

    var draw_engine = _engine(4130)
    draw_engine.player.draw_pile = [
        _card("2", "wind"), _card("3", "forest")]
    var draw_context = _context(draw_engine)
    draw_context.source_id = "echo_draw_probe"
    draw_context.source_name = "回响抽牌探针"
    draw_context.source_instance_key = "technique:echo_draw_probe"
    var draw_events: Array = []
    draw_engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "card_drawn" \
                    and str(values.get("source_id", "")) == "echo_draw_probe":
                draw_events.append(values.duplicate(true)))
    var echo_draw: Dictionary = draw_engine.effect_executor.execute_all([{
        "op":"repeat_effects", "count":2,
        "effects":[{"op":"draw", "count":1}],
    }], draw_context)
    _assert_true(echo_draw.get("success", false), "回响子效果通过共享执行器抽牌")
    _assert_equal(draw_events.size(), 2, "两次回响各提交一次抽牌事件")
    _assert_true(draw_events.all(func(values):
        return str(values.get("source_kind", "")) == "technique" \
            and str(values.get("trigger_mode", "")) == "echo"),
        "回响抽牌保留功法来源并独立公开 echo trigger_mode")
    _assert_equal(
        draw_engine.effect_ports.technique_draw_count(draw_engine.player), 2,
        "回响功法抽牌计入功法效果抽牌")

func _test_wind_timing_and_targeting_ports() -> void:
    var delayed_engine = _engine(4111)
    var delayed_result: Dictionary = delayed_engine.effect_executor.execute_all([{
        "op":"register_next_round_hand_limit", "side":"target", "amount":-2,
    }], _context(delayed_engine))
    _assert_true(delayed_result.get("success", false), "敌方下一回合八脉修正可注册负值")
    delayed_engine.status_system._on_round_start_records({
        "round_number":1, "actors":[delayed_engine.player, delayed_engine.enemy]})
    _assert_equal(delayed_engine.player.base_hand_limit_modifier, 0, "敌方八脉修正不误作用我方")
    _assert_equal(delayed_engine.enemy.base_hand_limit_modifier, -2, "敌方下一回合八脉容量-2")

    var continue_engine = _engine(4112)
    continue_engine.player.draw_pile = [_card("6", "wind"), _card("7", "forest")]
    var continue_definition = continue_engine.repository.get_definition(
        "three_wind_continue_form")
    var continue_context = _context(continue_engine)
    continue_context.technique_id = "three_wind_continue_form"
    continue_context.technique_name = continue_definition.display_name
    var continue_result: Dictionary = continue_engine.effect_executor.execute_all(
        continue_definition.effects, continue_context)
    _assert_true(continue_result.get("success", false), "续式先建立同气收益响应")
    _assert_true(continue_engine.player.hand.is_empty(), "续式在同气额外行动确认前不提前抽牌")
    continue_engine.status_system.handle_response_event("same_qi_gain_resolved", {
        "actor":continue_engine.player, "holder":continue_engine.player,
        "granted_actions":1})
    _assert_equal(continue_engine.player.hand.size(), 2, "续式在额外行动获得后抽2张")

    var cut_engine = _engine(4113)
    var wind_a = _card("2", "wind")
    var forest = _card("3", "forest")
    var wind_b = _card("4", "wind")
    var untouched = _card("5", "fire")
    cut_engine.enemy.draw_pile = [untouched, wind_b, forest, wind_a]
    var cut_result: Dictionary = cut_engine.effect_executor.execute_all([{
        "op":"discard_captured_by_selected_base_attribute", "side":"target",
        "capture":"shown", "selected_capture":"selected",
        "result_capture":"discarded"}], _context(cut_engine, {
            "shown":[wind_a, forest, wind_b], "selected":[wind_a]}))
    _assert_true(cut_result.get("success", false), "截流按展示选择的基础属性结算")
    _assert_equal(cut_engine.enemy.discard_pile, [wind_a, wind_b], "截流只弃展示集合中同基础属性牌")
    _assert_equal(cut_engine.enemy.draw_pile, [untouched, forest], "未移动展示牌保持原相对顺序")

    var block_engine = _engine(4114)
    block_engine.player.draw_pile = [_card("8", "wind"), _card("9", "forest")]
    var block_definition = block_engine.repository.get_definition("bomb_wind_cover_sky")
    var block_context = _context(block_engine)
    block_context.technique_id = "bomb_wind_cover_sky"
    block_context.technique_name = block_definition.display_name
    var block_chain: Dictionary = block_engine.effect_executor.execute_all(
        block_definition.effects, block_context)
    _assert_true(block_chain.get("success", false), "遮天建立格挡及成功后效果")
    var block_record: Dictionary = block_engine.player.block_sources[0]
    block_engine.status_system.handle_response_event("damage_blocked", {
        "actor":block_engine.enemy, "attacker":block_engine.enemy,
        "target":block_engine.player, "defender":block_engine.player,
        "holder":block_engine.player,
        "source_token":str(block_record.get("source_token", ""))})
    _assert_equal(block_engine.player.hand.size(), 2, "遮天格挡成功后的通用后续效果抽2张")

    var turn_sleeve_engine = _engine(4115)
    turn_sleeve_engine.enemy.hand = [_card("3", "fire"), _card("4", "forest")]
    turn_sleeve_engine.enemy.draw_pile = [_card("9", "mountain")]
    turn_sleeve_engine.player.draw_pile = [_card("A", "wind")]
    var turn_sleeve = turn_sleeve_engine.repository.get_definition(
        "pair_wind_turn_sleeve")
    var turn_result: Dictionary = turn_sleeve_engine.effect_executor.execute_all(
        turn_sleeve.effects, _context(turn_sleeve_engine))
    _assert_true(turn_result.get("success", false), "翻袖完整效果链执行")
    _assert_equal(turn_sleeve_engine.enemy.hand.size(), 1, "翻袖实际弃牌后由敌方抽1张")
    _assert_true(turn_sleeve_engine.player.hand.is_empty(), "翻袖不会误让我方抽牌")

    var turbulent_engine = _engine(4116)
    turbulent_engine.enemy.draw_pile = [
        _card("6", "fire"), _card("7", "forest")]
    turbulent_engine.player.draw_pile = [_card("K", "wind")]
    var turbulent = turbulent_engine.repository.get_definition(
        "bomb_wind_turbulent_sea")
    var turbulent_result: Dictionary = turbulent_engine.effect_executor.execute_all(
        turbulent.effects, _context(turbulent_engine))
    _assert_true(turbulent_result.get("success", false), "乱海完整效果链执行")
    _assert_equal(turbulent_engine.enemy.hand.size(), 1, "乱海由敌方抽1张")
    _assert_true(turbulent_engine.player.hand.is_empty(), "乱海不会误让我方抽牌")

func _test_continue_form_integrated() -> void:
    var engine = _engine(4123)
    var played := [_card("5", "wind"), _card("5", "wind"), _card("5", "wind")]
    var reserve = _card("8", "forest")
    var drawn := [_card("J", "fire"), _card("Q", "mountain")]
    engine.player.hand = played + [reserve]
    engine.player.draw_pile = drawn.duplicate()
    engine.player.same_qi_value = 4
    engine.sequence_book.configure({"three_kind":["three_wind_continue_form"]})
    engine.actions_available = 1
    var result: Dictionary = engine.confirm_play(
        played.map(func(card): return str(card.id)))
    _assert_true(result.get("success", false), "续式完整同气行动结算成功")
    _assert_equal(result.get("actions_available", -1), 1, "续式行动通过同气实际获得额外行动")
    _assert_equal(engine.player.hand.size(), 3, "续式在额外行动开始前抽2张并保留原手牌")
    _assert_true(engine.player.hand.has(reserve), "续式抽牌不影响剩余手牌")
    _assert_true(engine.player.hand.has(drawn[0]) and engine.player.hand.has(drawn[1]), "续式抽入冻结牌库中的两张牌")

func _test_break_page_burned_out_bridge() -> void:
    var plain_engine = _engine(4129)
    var plain = _card("7", "forest")
    plain_engine.enemy.draw_pile = [plain]
    var plain_definition = plain_engine.repository.get_definition(
        "high_wind_break_page")
    var plain_result: Dictionary = plain_engine.effect_executor.execute_all(
        plain_definition.effects, _context(plain_engine))
    _assert_true(plain_result.get("success", false), "断页非燃尽分支执行成功")
    _assert_true(plain_engine.enemy.discard_pile.has(plain), "断页明确弃掉非燃尽顶牌")
    _assert_true(plain_engine.enemy.hand.is_empty(), "断页非燃尽分支不令敌方抽牌")

    var burned_engine = _engine(4130)
    var burned = _card("10", "fire")
    burned_engine.status_system.apply_card_anomaly(
        burned, "mark", "burned_out", {}, "测试")
    burned_engine.enemy.draw_pile = [burned]
    var hidden_definition = burned_engine.repository.get_definition(
        "straight_fire_hidden_kindling")
    var hidden_context = _context(burned_engine)
    hidden_context.power = 0
    hidden_context.initial_power = 0
    hidden_context.technique_id = "straight_fire_hidden_kindling"
    hidden_context.technique_name = hidden_definition.display_name
    var hidden_result: Dictionary = burned_engine.effect_executor.execute_all(
        hidden_definition.effects, hidden_context)
    _assert_true(hidden_result.get("success", false), "暗薪响应先行建立")
    var break_context = _context(burned_engine)
    break_context.power = 20
    break_context.initial_power = 20
    break_context.technique_id = "high_wind_break_page"
    break_context.technique_name = plain_definition.display_name
    var burned_result: Dictionary = burned_engine.effect_executor.execute_all(
        plain_definition.effects, break_context)
    _assert_true(burned_result.get("success", false), "断页燃尽分支执行成功")
    _assert_true(burned_engine.enemy.hand.has(burned), "断页强制抽取燃尽顶牌")
    _assert_true(burned_engine.enemy.discard_pile.is_empty(), "燃尽顶牌不进入断页弃置分支")
    _assert_equal(100 - burned_engine.enemy.life, 25, "断页触发暗薪并结算P伤害与基础值一半真伤")

func _test_wind_resource_boundaries() -> void:
    var scout_engine = _engine(4126)
    var played = _card("A", "wind")
    var outsider = _card("2", "mountain")
    var shown_third = _card("3", "fire")
    var shown_second = _card("4", "forest")
    var shown_top = _card("5", "wind")
    scout_engine.player.hand = [played]
    scout_engine.player.draw_pile = [outsider, shown_third, shown_second, shown_top]
    scout_engine.sequence_book.configure({"high_card":["high_wind_scout"]})
    scout_engine.actions_available = 1
    var scout: Dictionary = scout_engine.confirm_play([str(played.id)])
    _assert_true(scout.get("pending_choice", false), "探风式等待选择展示牌置顶")
    var top_candidates: Array = scout.get("choice_request", {}).get("candidates", [])
    _assert_equal(top_candidates.size(), 3, "探风式首次选择冻结牌库顶3张")
    if top_candidates.is_empty():
        return
    scout = scout_engine.resolve_effect_choice(
        str(scout["choice_request"]["request_id"]), [str(shown_top.id)])
    _assert_true(scout.get("pending_choice", false), "探风式继续等待牌库底顺序选择")
    var bottom_candidates: Array = scout.get("choice_request", {}).get("candidates", [])
    _assert_equal(bottom_candidates.size(), 2, "探风式第二次选择只含原展示集合的剩余2张")
    _assert_true(bottom_candidates.all(func(candidate):
        return str(candidate.get("id", "")) != str(outsider.id)), "探风式排序候选不会越过冻结顶3张")
    scout = scout_engine.resolve_effect_choice(
        str(scout["choice_request"]["request_id"]), [str(shown_second.id)])
    _assert_true(scout.get("success", false), "探风式两段选择恢复后完成行动")

    var drain_engine = _engine(4127)
    var deeper = _card("2", "forest")
    var top_four := [
        _card("6", "wind"), _card("7", "forest"),
        _card("8", "fire"), _card("9", "mountain")]
    top_four[0].set_enhancement("rock_solid")
    drain_engine.enemy.draw_pile = [
        deeper, top_four[3], top_four[2], top_four[1], top_four[0]]
    var drain_context = _context(drain_engine)
    drain_context.actual_hand_id = "four_kind"
    drain_context.hand_result = {"id":"four_kind", "contributing":[]}
    var drain: Dictionary = drain_engine.effect_executor.execute_all(
        drain_engine.repository.get_definition("bomb_wind_drain_sea").effects,
        drain_context)
    _assert_true(drain.get("success", false), "涸海冻结顶K后逐张尝试明确弃置")
    _assert_equal(drain_engine.enemy.discard_pile.size(), 3, "涸海顶4中磐石失败时只弃其余3张")
    _assert_true(drain_engine.enemy.draw_pile.has(top_four[0]), "涸海不可弃的顶K牌留在牌库")
    _assert_true(drain_engine.enemy.draw_pile.has(deeper), "涸海不会向顶K以下补足弃牌数量")

    var cosmic = drain_engine.repository.get_definition("bomb_wind_cosmic_sleeve")
    _assert_equal(cosmic.effects[1].get("maximum", {}).get("kind", ""), "hand_count", "乾坤袖任意张上限动态读取实际手牌")

func _test_scatter_four_echoes() -> void:
    var no_echo_engine = _engine(4124)
    var no_echo_card = _card("7", "wind")
    no_echo_engine.enemy.hand = [no_echo_card]
    var first_wind_seed := _seed_for_random_attributes(
        func(values): return int(values[0]) == 0)
    no_echo_engine.rng.seed = first_wind_seed
    var no_echo_result: Dictionary = no_echo_engine.effect_executor.execute_all(
        no_echo_engine.repository.get_definition("three_wind_scatter_four").effects,
        _context(no_echo_engine))
    _assert_true(no_echo_result.get("success", false), "四散初次有弃牌时效果链完成")
    _assert_equal(100 - no_echo_engine.enemy.life, 10, "四散初次有弃牌时不产生回响伤害")
    _assert_true(no_echo_engine.enemy.discard_pile.has(no_echo_card), "四散初次随机属性命中并弃牌")

    var echo_engine = _engine(4125)
    var echo_card = _card("7", "wind")
    echo_engine.enemy.hand = [echo_card]
    var reroll_seed := _seed_for_random_attributes(func(values):
        return int(values[0]) != 0 and (
            int(values[1]) == 0 or int(values[2]) == 0))
    echo_engine.rng.seed = reroll_seed
    var echo_result: Dictionary = echo_engine.effect_executor.execute_all(
        echo_engine.repository.get_definition("three_wind_scatter_four").effects,
        _context(echo_engine))
    _assert_true(echo_result.get("success", false), "四散初次空弃后两次回响完成")
    _assert_equal(100 - echo_engine.enemy.life, 30, "四散只执行初次与两次回响且回响不递归")
    _assert_true(echo_engine.enemy.discard_pile.has(echo_card), "四散回响重新随机属性并读取最新手牌")

func _seed_for_random_attributes(predicate: Callable) -> int:
    var probe := RandomNumberGenerator.new()
    for seed_value in range(1, 10000):
        probe.seed = seed_value
        var values := [
            probe.randi_range(0, 3),
            probe.randi_range(0, 3),
            probe.randi_range(0, 3),
        ]
        if predicate.call(values):
            return seed_value
    return 1

func _test_return_tide_post_commit() -> void:
    var engine = _engine(4117)
    var cards := [_card("7", "wind"), _card("7", "forest"), _card("7", "fire")]
    engine.player.hand = cards.duplicate()
    engine.sequence_book.configure({"three_kind":["three_wind_return_tide"]})
    engine.actions_available = 1
    var result: Dictionary = engine.confirm_play(
        cards.map(func(card): return str(card.id)))
    _assert_true(result.get("pending_choice", false), "回潮在组成牌完成入堆后等待选择")
    _assert_equal(engine.player.discard_pile.size(), 3, "回潮选择出现时三条组成牌已进入弃牌堆")
    var candidates: Array = result.get("choice_request", {}).get("candidates", [])
    _assert_equal(candidates.size(), 3, "回潮只列出仍在弃牌堆的三条组成牌")
    if candidates.size() < 2:
        return
    result = engine.resolve_effect_choice(
        str(result["choice_request"]["request_id"]),
        [str(candidates[0]["id"]), str(candidates[1]["id"])])
    _assert_true(result.get("success", false), "回潮提交后选择可恢复并完成行动")
    _assert_equal(engine.player.draw_pile.size(), 2, "回潮所选两张组成牌洗回牌库")
    _assert_equal(engine.player.discard_pile.size(), 1, "回潮未选组成牌留在弃牌堆")

    var moved_engine = _engine(4118)
    var moved_cards := [_card("8", "wind"), _card("8", "forest"), _card("8", "fire")]
    moved_engine.player.hand = moved_cards.duplicate()
    moved_engine.sequence_book.configure({"three_kind":["three_wind_return_tide"]})
    moved_engine.actions_available = 1
    var response_context = _context(moved_engine, {"watched":[moved_cards[0]]})
    moved_engine.status_system.register_response(
        "card_moved", "turn_end", [{
            "op":"move_captured", "capture":"watched",
            "from_side":"actor", "from_zone":"discard_pile",
            "to_side":"actor", "to_zone":"hand", "reason":"effect",
        }], response_context, {
            "holder_is_actor":true,
            "card_instance_ids_from_capture":"watched",
            "to_zone":"discard_pile",
            "max_triggers":1,
        })
    var moved_result: Dictionary = moved_engine.confirm_play(
        moved_cards.map(func(card): return str(card.id)))
    _assert_true(moved_result.get("pending_choice", false), "回潮在入堆响应移牌后仍可等待选择")
    _assert_true(moved_engine.player.hand.has(moved_cards[0]), "入堆响应先于回潮候选冻结完成")
    var moved_candidates: Array = moved_result.get("choice_request", {}).get("candidates", [])
    _assert_equal(moved_candidates.size(), 2, "已被入堆响应移走的组成牌不再是回潮候选")
    _assert_true(
        moved_candidates.all(func(candidate): return str(candidate.get("id", "")) != str(moved_cards[0].id)),
        "回潮候选按当前弃牌区过滤")
    moved_result = moved_engine.resolve_effect_choice(
        str(moved_result["choice_request"]["request_id"]), [])
    _assert_true(moved_result.get("success", false), "回潮候选过滤场景完成空选择并结束行动")

    var full_engine = _engine(4128)
    var triple := [_card("10", "wind"), _card("10", "forest"), _card("10", "fire")]
    var pair := [_card("3", "wind"), _card("3", "mountain")]
    full_engine.player.hand = triple + pair
    full_engine.sequence_book.configure({"full_house":["three_wind_return_tide"]})
    full_engine.actions_available = 1
    var full_result: Dictionary = full_engine.confirm_play(
        (triple + pair).map(func(card): return str(card.id)))
    _assert_true(full_result.get("pending_choice", false), "葫芦执行三条池回潮等待提交后选择")
    var full_candidates: Array = full_result.get("choice_request", {}).get("candidates", [])
    _assert_equal(full_candidates.size(), 3, "葫芦回潮只读取冻结三条组成牌")
    _assert_true(full_candidates.all(func(candidate):
        return int(candidate.get("rank_order", 0)) == 10), "葫芦回潮候选不混入对子组成牌")
    full_result = full_engine.resolve_effect_choice(
        str(full_result["choice_request"]["request_id"]), [])
    _assert_true(full_result.get("success", false), "葫芦回潮空选择后完成行动")

func _test_returning_swallow_post_commit() -> void:
    var engine = _engine(4121)
    var cards := [_card("6", "wind"), _card("6", "forest")]
    engine.player.hand = cards.duplicate()
    engine.sequence_book.configure({"pair":["pair_wind_returning_swallow"]})
    engine.actions_available = 1
    var result: Dictionary = engine.confirm_play(
        cards.map(func(card): return str(card.id)))
    _assert_true(result.get("pending_choice", false), "回燕先选择对子组成牌")
    var candidates: Array = result.get("choice_request", {}).get("candidates", [])
    _assert_equal(candidates.size(), 2, "回燕候选只包含对子组成牌")
    if candidates.is_empty():
        return
    var selected_id := str(candidates[0]["id"])
    result = engine.resolve_effect_choice(
        str(result["choice_request"]["request_id"]), [selected_id])
    _assert_true(result.get("success", false), "回燕在提交后完成回手")
    _assert_true(engine.player.hand.any(
        func(card): return str(card.id) == selected_id), "回燕所选牌在入堆响应完成后回手")
    _assert_equal(engine.player.discard_pile.size(), 1, "回燕未选组成牌留在弃牌堆")

    var moved_engine = _engine(4122)
    var moved_cards := [_card("9", "wind"), _card("9", "fire")]
    moved_engine.player.hand = moved_cards.duplicate()
    moved_engine.sequence_book.configure({"pair":["pair_wind_returning_swallow"]})
    moved_engine.actions_available = 1
    var response_context = _context(moved_engine, {"watched":[moved_cards[0]]})
    moved_engine.status_system.register_response(
        "card_moved", "turn_end", [{
            "op":"move_captured", "capture":"watched",
            "from_side":"actor", "from_zone":"discard_pile",
            "to_side":"actor", "to_zone":"draw_pile", "reason":"effect",
        }], response_context, {
            "holder_is_actor":true,
            "card_instance_ids_from_capture":"watched",
            "to_zone":"discard_pile",
            "max_triggers":1,
        })
    var moved_result: Dictionary = moved_engine.confirm_play(
        moved_cards.map(func(card): return str(card.id)))
    _assert_true(moved_result.get("pending_choice", false), "回燕移动响应场景等待选牌")
    moved_result = moved_engine.resolve_effect_choice(
        str(moved_result["choice_request"]["request_id"]),
        [str(moved_cards[0].id)])
    _assert_true(moved_result.get("success", false), "回燕在外部入堆响应后完成行动")
    _assert_true(moved_engine.player.draw_pile.has(moved_cards[0]), "外部响应移走的牌不被回燕再次移动")
    _assert_true(not moved_engine.player.hand.has(moved_cards[0]), "回燕提交后按当前弃牌区过滤")

    var full_engine = _engine(4129)
    var triple := [_card("Q", "wind"), _card("Q", "forest"), _card("Q", "fire")]
    var pair := [_card("4", "wind"), _card("4", "mountain")]
    full_engine.player.hand = triple + pair
    full_engine.sequence_book.configure({"full_house":["pair_wind_returning_swallow"]})
    full_engine.actions_available = 1
    var full_result: Dictionary = full_engine.confirm_play(
        (triple + pair).map(func(card): return str(card.id)))
    _assert_true(full_result.get("pending_choice", false), "葫芦执行对子池回燕等待选择")
    var full_candidates: Array = full_result.get("choice_request", {}).get("candidates", [])
    _assert_equal(full_candidates.size(), 2, "葫芦回燕只读取冻结对子组成牌")
    _assert_true(full_candidates.all(func(candidate):
        return int(candidate.get("rank_order", 0)) == 4), "葫芦回燕候选不混入三条组成牌")
    if not full_candidates.is_empty():
        full_result = full_engine.resolve_effect_choice(
            str(full_result["choice_request"]["request_id"]),
            [str(full_candidates[0]["id"])])
        _assert_true(full_result.get("success", false), "葫芦回燕选择后完成行动")

func _test_bomb_k() -> void:
    var resolver = ValueResolverScript.new()
    var engine = _engine(4108)
    var context = _context(engine)
    context.actual_hand_id = "four_kind"
    _assert_equal(resolver.resolve({"kind":"bomb_constituent_count"}, context), 4, "四条K=4")
    context.actual_hand_id = "five_kind"
    _assert_equal(resolver.resolve({"kind":"bomb_constituent_count"}, context), 5, "五条K=5")

func _context(engine, captures: Dictionary = {}):
    return EffectContextScript.new().configure({
        "ports":engine.effect_ports, "actor":engine.player, "target":engine.enemy,
        "power":20, "initial_power":20, "actual_hand_id":"high_card",
        "hand_result":{"id":"high_card","contributing":[]},
        "played_cards":[], "group_snapshot":{"played_cards":[],"contributing_cards":[],"extra_cards":[]},
        "captures":captures, "action_token":"wind-test", "source_kind":"technique",
    })
