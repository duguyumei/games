extends "res://tests/support/expanded_technique_test_base.gd"

const HandGroupSnapshotScript = preload("res://core/hand_group_snapshot.gd")
const ValueResolverScript = preload("res://core/effects/effect_value_resolver.gd")

const FIRE_BY_POOL := {
    "high": [
        "high_fire_kindling", "high_fire_scatter", "high_fire_scorch",
        "high_fire_ignite", "high_fire_momentum", "high_fire_burn_void",
        "high_fire_burn_poison_momentum", "high_fire_turn_wheel",
        "high_fire_hidden_channel", "high_fire_tread_momentum",
        "high_fire_cast_kindling", "high_fire_return_kindling",
        "high_fire_afterglow",
    ],
    "pair": [
        "pair_fire_heat_to_momentum", "pair_fire_double_knock",
        "pair_fire_advance_together", "pair_fire_echo_mark",
        "pair_fire_turn_back", "pair_fire_knock_armor",
        "pair_fire_guard_momentum", "pair_fire_double_kindling",
        "pair_fire_remaining_form", "pair_fire_scorch_channel",
        "pair_fire_send_kindling", "pair_fire_melt_armor_momentum",
    ],
    "three": [
        "three_fire_poison_pursuit", "three_fire_rekindle",
        "three_fire_same_furnace", "three_fire_ring_iron",
        "three_fire_shift_flame", "three_fire_scorched_earth",
        "three_fire_furnace_return", "three_fire_ember_momentum",
    ],
    "straight": [
        "straight_fire_five_steps", "straight_fire_long_drive",
        "straight_fire_pursue_array", "straight_fire_return_kindling",
        "straight_fire_through_furnace", "straight_fire_burning_path",
        "straight_fire_hidden_kindling", "straight_fire_transfer_heat",
        "straight_fire_return_same_qi",
    ],
    "bomb": [
        "bomb_fire_thousand_hammers", "bomb_fire_pour_furnace",
        "bomb_fire_myriad_echoes", "bomb_fire_burst_momentum",
        "bomb_fire_ember_burst", "bomb_fire_burn_body_empower",
        "bomb_fire_cast_furnace", "bomb_fire_ember_calamity",
        "bomb_fire_return_furnace", "bomb_fire_break_city",
    ],
}

const NEW_FIRE_IDS := [
    "high_fire_turn_wheel", "high_fire_hidden_channel",
    "high_fire_tread_momentum", "high_fire_cast_kindling",
    "high_fire_return_kindling", "high_fire_afterglow",
    "pair_fire_double_knock", "pair_fire_advance_together",
    "pair_fire_echo_mark", "pair_fire_turn_back", "pair_fire_knock_armor",
    "pair_fire_guard_momentum", "pair_fire_double_kindling",
    "pair_fire_remaining_form", "pair_fire_scorch_channel",
    "pair_fire_send_kindling", "three_fire_rekindle",
    "three_fire_same_furnace", "three_fire_ring_iron",
    "three_fire_shift_flame", "three_fire_scorched_earth",
    "three_fire_furnace_return", "three_fire_ember_momentum",
    "straight_fire_five_steps", "straight_fire_long_drive",
    "straight_fire_pursue_array", "straight_fire_return_kindling",
    "straight_fire_through_furnace", "straight_fire_burning_path",
    "straight_fire_hidden_kindling", "straight_fire_transfer_heat",
    "bomb_fire_thousand_hammers", "bomb_fire_pour_furnace",
    "bomb_fire_myriad_echoes", "bomb_fire_burst_momentum",
    "bomb_fire_ember_burst", "bomb_fire_burn_body_empower",
    "bomb_fire_cast_furnace", "bomb_fire_ember_calamity",
    "bomb_fire_return_furnace",
]

func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_catalog_and_each_effect_chain()
    _test_momentum_settlement_and_preconsume()
    _test_same_qi_writes_and_extra_action_order()
    _test_burned_out_lifecycle_and_intrinsic_base_freeze()
    _test_pair_and_full_house_boundaries()
    _test_response_and_zone_techniques()
    _test_bomb_k_and_echoes()
    _finish("FIRE TECHNIQUE TEST")

func _test_catalog_and_each_effect_chain() -> void:
    var repository = _repository()
    var count := 0
    for pool in FIRE_BY_POOL:
        for technique_id in FIRE_BY_POOL[pool]:
            count += 1
            var definition = repository.get_definition(technique_id)
            _assert_true(definition != null, "%s可识别" % technique_id)
            if definition != null:
                _assert_equal(definition.pool, pool, "%s池归属" % technique_id)
                _assert_true(not definition.semantic_tags.is_empty(), "%s AI语义非空" % technique_id)
    _assert_equal(count, 52, "火系稳定ID共52门")
    for technique_id in NEW_FIRE_IDS:
        var engine = _engine(6100 + assertions)
        var result := _execute_with(engine, technique_id, 20, _snapshot([], [], 8), _hand_for(technique_id))
        _assert_true(
            result.get("success", false) or result.get("pending_choice", false),
            "%s真实效果链至少有一条可执行路径" % technique_id)

func _test_momentum_settlement_and_preconsume() -> void:
    var engine = _engine(6201)
    var pairs := [
        _card("2", "fire"), _card("2", "fire"),
        _card("3", "fire"), _card("3", "fire"),
        _card("4", "fire"), _card("4", "fire"),
    ]
    engine.player.hand = pairs.duplicate()
    engine.sequence_book.configure({"pair":[
        "pair_fire_guard_momentum", "pair_fire_echo_mark", "pair_fire_echo_mark"]})
    engine.actions_available = 3
    engine.player.momentum_value = 7
    for index in range(3):
        var result: Dictionary = engine.confirm_play([
            str(pairs[index * 2].id), str(pairs[index * 2 + 1].id)])
        _assert_true(result.get("success", false), "护势链第%d门成功" % (index + 1))
        if index < 2:
            _assert_equal(engine.player.momentum_value, 7, "护势自身及下一门保留连势")
    _assert_equal(engine.player.momentum_value, 0, "保护消费后再遇未改变连势的成功功法清空")

    var consume_engine = _engine(6202)
    var bomb_cards := []
    for _index in range(4):
        bomb_cards.append(_card("2", "fire"))
    consume_engine.player.hand = bomb_cards
    consume_engine.sequence_book.configure({"four_kind":["bomb_fire_burst_momentum"]})
    consume_engine.actions_available = 1
    consume_engine.player.momentum_value = 15
    var preview: Dictionary = consume_engine.preview(
        bomb_cards.map(func(card): return str(card.id)))
    _assert_equal(preview["values"]["momentum_used"], 15, "纯预览展示连势但不支付")
    _assert_equal(consume_engine.player.momentum_value, 15, "预览不消耗连势")
    var result: Dictionary = consume_engine.confirm_play(
        bomb_cards.map(func(card): return str(card.id)))
    _assert_true(result.get("success", false), "爆势正式确认成功")
    _assert_equal(result["preview"]["values"]["momentum_used"], 5, "爆势先支付再冻结剩余连势")
    _assert_equal(consume_engine.player.momentum_value, 5, "前置消费算本门改变连势并保留余量")
    _assert_equal(
        result["preview"]["values"]["direct_power_fixed"], 16,
        "爆势按2C加入直接固定功法值")
    _assert_true(
        not result["preview"].get("momentum_consume_receipts", []).is_empty(),
        "行动记录保存前置连势消费回执")

    var tread_engine = _engine(6203)
    var high = _card("9", "fire")
    var reserve = _card("3", "wind")
    tread_engine.player.hand = [high, reserve]
    tread_engine.sequence_book.configure({"high_card":["high_fire_tread_momentum"]})
    tread_engine.actions_available = 1
    tread_engine.player.momentum_value = 10
    result = tread_engine.confirm_play([str(high.id)])
    _assert_true(result.get("success", false), "踏势伤害后完整支付")
    _assert_equal(tread_engine.player.momentum_value, 0, "踏势消费10点连势")
    _assert_equal(tread_engine.actions_available, 1, "踏势支付成功后获得额外行动")

func _test_same_qi_writes_and_extra_action_order() -> void:
    var engine = _engine(6301)
    engine.player.hand = [_card("7", "fire")]
    engine.actions_available = 1
    var receipt: Dictionary = engine.effect_ports.write_same_qi(
        engine.player, "add", 5, "测试同气", "same-qi-order", "effect")
    _assert_equal(receipt.get("conversion_count", 0), 1, "正向同气写入立即转换阈值")
    _assert_equal(receipt.get("extra_action_source", ""), "same_qi", "额外行动记录同气来源")
    _assert_equal(engine.battle_flow.next_action_source(engine.player).get("category", ""), "normal_first_attack", "第一击前同气行动排在正常第一击之后")
    engine.battle_flow.consume_action(engine.player)
    _assert_equal(engine.battle_flow.next_action_source(engine.player).get("category", ""), "same_qi", "正常第一击后才轮到同气额外行动")

    var turn_engine = _engine(6302)
    var played := [_card("2", "fire"), _card("5", "fire"), _card("9", "fire")]
    turn_engine.player.hand = played
    turn_engine.sequence_book.configure({"high_card":["high_fire_turn_wheel"]})
    turn_engine.actions_available = 1
    var result: Dictionary = turn_engine.confirm_play(
        played.map(func(card): return str(card.id)))
    _assert_true(result.get("success", false), "点轮行动完成")
    _assert_equal(turn_engine.player.same_qi_value, 3, "自然同气收益2后点轮额外写入1")

    var delayed_engine = _engine(6303)
    for token in ["hidden-a", "hidden-b"]:
        var context = _context(delayed_engine, "high_fire_hidden_channel", 10, _snapshot([], [], 0), "high_card", token)
        var delayed: Dictionary = delayed_engine.effect_executor.execute_all(
            delayed_engine.repository.get_definition("high_fire_hidden_channel").effects,
            context)
        _assert_true(delayed.get("success", false), "伏脉建立独立延迟记录")
    delayed_engine.timing_system.emit_timing("after_normal_draw", {
        "actor": delayed_engine.player, "cards": [], "reason": "normal_draw"})
    _assert_equal(delayed_engine.player.same_qi_value, 4, "两份伏脉延迟使用唯一令牌分别写入")
    var hidden_a_receipts: Array = delayed_engine.effect_ports.same_qi_receipts_for_action(
        delayed_engine.player, "hidden-a")
    var hidden_b_receipts: Array = delayed_engine.effect_ports.same_qi_receipts_for_action(
        delayed_engine.player, "hidden-b")
    _assert_equal(hidden_a_receipts.size(), 1, "伏脉A回执归属原行动令牌")
    _assert_equal(hidden_b_receipts.size(), 1, "伏脉B回执归属原行动令牌")
    if not hidden_a_receipts.is_empty():
        _assert_true(
            str(hidden_a_receipts[0].get("action_token", "")).begins_with("hidden-a:delay:"),
            "伏脉延迟回执保存唯一派生行动令牌")

func _test_burned_out_lifecycle_and_intrinsic_base_freeze() -> void:
    var engine = _engine(6401)
    var source = _card("4", "fire")
    var target = _card("8", "forest")
    source.set_temporary_rank("9", 9, 9)
    engine.player.hand = [source, target]
    var applied: Dictionary = engine.status_system.apply_card_anomaly(
        source, "mark", "burned_out", {}, "测试")
    _assert_true(applied.get("success", false), "燃尽通过通用端口施加")
    _assert_equal(engine.effect_ports.current_effective_qi(engine.player, source), 0, "燃尽只覆盖最终有效真气值为0")
    _assert_equal(source.current_rank_name(), "9", "燃尽不删除临时牌阶")
    engine.player.card_zone_service.move_card(
        engine.player, "hand", "discard_pile", source, "explicit_discard")
    _assert_true(source.has_anomaly("mark", "burned_out"), "明确弃置不移除燃尽")
    engine.player.card_zone_service.move_card(
        engine.player, "discard_pile", "draw_pile", source, "recover")
    engine.player.card_zone_service.move_card(
        engine.player, "draw_pile", "hand", source, "draw")
    _assert_true(source.has_anomaly("mark", "burned_out"), "回收与抽取不移除燃尽")
    var transferred: Dictionary = engine.status_system.transfer_card_anomaly(
        source, target, "mark", "burned_out", "测试转移")
    _assert_true(transferred.get("success", false), "燃尽可以来源安全地转移")
    _assert_true(not source.has_anomaly("mark", "burned_out") and target.has_anomaly("mark", "burned_out"), "燃尽转移同时移除来源并施加目标")

    source.set_anomaly("mark", "burned_out")
    var snapshot := HandGroupSnapshotScript.freeze(
        [source], {"id":"high_card", "contributing":[source]}, engine.player, engine.enemy)
    var context = _context(engine, "straight_fire_through_furnace", 0, snapshot, "straight", "base-freeze")
    context.captures["burned"] = [source]
    var intrinsic := ValueResolverScript.new().resolve({
        "kind":"capture_card_base_qi_sum", "capture":"burned"}, context)
    _assert_equal(intrinsic, 4, "火系基础值读取牌本体基础值而非临时牌阶9")
    source.qi_value = 12
    _assert_equal(ValueResolverScript.new().resolve({
        "kind":"capture_card_base_qi_sum", "capture":"burned"}, context), 4, "组内基础值在移动或改写前冻结")

func _test_pair_and_full_house_boundaries() -> void:
    for hand_id in ["pair", "two_pair", "full_house"]:
        var engine = _engine(6500 + assertions)
        var result := _execute_with(
            engine, "pair_fire_double_knock", 20,
            _snapshot([], [], 8), hand_id)
        _assert_true(result.get("success", false), "双叩%s分支执行" % hand_id)
        _assert_equal(100 - engine.enemy.life, 20, "双叩%s总伤害为P" % hand_id)
        _assert_equal(engine.player.momentum_value, 4 if hand_id == "two_pair" else 2, "双叩按原始命中段获得连势")
    var absorbed = _engine(6504)
    absorbed.enemy.defense = 100
    _execute_with(absorbed, "pair_fire_double_knock", 20, _snapshot([], [], 8), "pair")
    _assert_equal(absorbed.player.momentum_value, 0, "双叩伤害完全被防御吸收时不获得连势")

    var full_engine = _engine(6505)
    var triple := [_card("5", "fire"), _card("5", "wind"), _card("5", "forest")]
    var pair := [_card("9", "fire"), _card("9", "mountain")]
    for card in pair:
        card.set_anomaly("mark", "burned_out")
    var all_cards: Array = triple + pair
    var full_snapshot := _snapshot(all_cards, all_cards, 33)
    var full_result := _execute_with(
        full_engine, "pair_fire_remaining_form", 20, full_snapshot, "full_house")
    _assert_true(full_result.get("success", false), "余形葫芦分支执行")
    _assert_equal(100 - full_engine.enemy.life, 28, "余形葫芦只读取对子部分两张9的基础值各一半")

    var target_engine = _engine(6506)
    var ace = _card("A", "fire")
    var boosted = _card("2", "forest")
    target_engine.status_system.apply_card_anomaly(
        boosted, "buff", "qi_heat", {}, "测试", 20)
    target_engine.enemy.hand = [ace, boosted]
    var scorch := _execute_with(
        target_engine, "pair_fire_scorch_channel", 10,
        _snapshot([], [], 4), "pair")
    _assert_true(scorch.get("success", false), "焦脉最高有效值查询执行")
    _assert_true(boosted.has_anomaly("mark", "burned_out"), "焦脉按最高有效真气值而非最高牌阶选择")
    _assert_true(not ace.has_anomaly("mark", "burned_out"), "焦脉不误选高牌阶低有效值目标")

func _test_response_and_zone_techniques() -> void:
    var afterglow = _engine(6601)
    var counted = _card("4", "fire")
    var snapshot := _snapshot([counted], [counted], 4)
    var context = _context(afterglow, "high_fire_afterglow", 10, snapshot, "high_card", "afterglow-token")
    _assert_true(afterglow.effect_executor.execute_all(
        afterglow.repository.get_definition("high_fire_afterglow").effects,
        context).get("success", false), "余明建立燃尽变化响应")
    afterglow.status_system.apply_card_anomaly(
        counted, "mark", "burned_out", {}, "测试", 1, false, {
            "holder":afterglow.player, "actor":afterglow.player,
            "action_token":"afterglow-token"})
    _assert_equal(100 - afterglow.enemy.life, 14, "余明按牌本体基础值追加真伤且只响应未燃尽到燃尽")

    var send = _engine(6602)
    var hand_card = _card("6", "fire")
    var deck_card = _card("7", "fire")
    hand_card.set_anomaly("mark", "burned_out")
    deck_card.set_anomaly("mark", "burned_out")
    send.player.hand = [hand_card]
    send.player.draw_pile = [deck_card]
    var send_context = _context(send, "pair_fire_send_kindling", 0, _snapshot([], [], 0), "two_pair", "send-token")
    send_context.choice_candidates["send-token:send_kindling_hand"] = [hand_card]
    send_context.choice_responses["send-token:send_kindling_hand"] = [str(hand_card.id)]
    var sent: Dictionary = send.effect_executor.execute_all(
        send.repository.get_definition("pair_fire_send_kindling").effects,
        send_context)
    _assert_true(sent.get("success", false), "嫁薪冻结手牌与牌库目标后原子转移")
    _assert_true(send.enemy.draw_pile.has(hand_card) and send.enemy.draw_pile.has(deck_card), "嫁薪两类来源同时进入敌方牌库")
    _assert_equal(hand_card.original_owner_id, send.player.owner_id, "嫁薪记录原持有者")
    send.timing_system.emit_timing("battle_end", {"actors":[send.player, send.enemy]})
    _assert_true(send.player.draw_pile.has(hand_card) and send.player.draw_pile.has(deck_card), "嫁薪牌战斗结束统一归还")

    var hidden = _engine(6603)
    var burned = _card("9", "fire")
    burned.set_anomaly("mark", "burned_out")
    hidden.enemy.draw_pile = [burned]
    var hidden_context = _context(hidden, "straight_fire_hidden_kindling", 10, _snapshot([], [], 5), "straight", "hidden-token")
    hidden.effect_executor.execute_all(
        hidden.repository.get_definition("straight_fire_hidden_kindling").effects,
        hidden_context)
    hidden.effect_ports.draw(hidden.enemy, 1, "technique")
    _assert_equal(100 - hidden.enemy.life, 9, "暗薪结算P/2普通伤害与基础值一半真伤")
    _assert_equal(100 - hidden.player.life, 0, "暗薪不会误伤我方")
    _assert_equal(hidden.enemy.life, 91, "暗薪抽到燃尽牌后按基础值一半追加真伤")

func _test_bomb_k_and_echoes() -> void:
    for hand_id in ["four_kind", "five_kind"]:
        var k := 4 if hand_id == "four_kind" else 5
        var hammer = _engine(6700 + k)
        hammer.enemy.defense = 100
        var result := _execute_with(
            hammer, "bomb_fire_thousand_hammers", 40,
            _snapshot([], [], 20), hand_id)
        _assert_true(result.get("success", false), "千锤%s读取K" % hand_id)
        var expected_true := int(floor(k / 2.0)) * int(floor(40.0 / k))
        _assert_equal(100 - hammer.enemy.life, expected_true, "千锤按上一段生命损失切换真伤")

        var echoes = _engine(6720 + k)
        result = _execute_with(
            echoes, "bomb_fire_myriad_echoes", 20,
            _snapshot([], [], 20), hand_id)
        _assert_true(result.get("success", false), "万响%s执行" % hand_id)
        _assert_equal(100 - echoes.enemy.life, 10 * (k - 1), "万响总计初次加K-2次回响且不递归")

    var pour = _engine(6740)
    pour.player.same_qi_value = 3
    var pour_result := _execute_with(
        pour, "bomb_fire_pour_furnace", 20,
        _snapshot([], [], 8), "four_kind")
    _assert_true(pour_result.get("success", false), "倾炉清空同气并追击")
    _assert_equal(pour.player.same_qi_value, 0, "倾炉通过结构化写入清空同气")
    _assert_equal(100 - pour.enemy.life, 26, "倾炉按实际清空3点各追击C/K=2")

    var ember = _engine(6741)
    var card = _card("4", "fire")
    card.set_temporary_rank("9", 9, 9)
    card.set_anomaly("mark", "burned_out")
    ember.player.staging = [card]
    var ember_snapshot := _snapshot([card], [card], 0)
    ember_snapshot["pre_momentum_consume_selected"] = true
    var ember_context = _context(
        ember, "bomb_fire_ember_burst", 20,
        ember_snapshot, "four_kind", "ember-token")
    var ember_result: Dictionary = ember.effect_executor.execute_all(
        ember.repository.get_definition("bomb_fire_ember_burst").effects,
        ember_context)
    _assert_true(ember_result.get("success", false), "烬爆初始伤害与消散响应建立")
    ember.status_system.handle_response_event("action_pre_commit", {
        "actor":ember.player, "holder":ember.player,
        "target":ember.enemy, "action_token":"ember-token"})
    _assert_true(ember.player.temporarily_removed_cards.has(card), "烬爆在入弃牌堆前消散燃尽组成牌")
    _assert_equal(100 - ember.enemy.life, 18, "烬爆消耗分支按牌本体基础值4造成2B真伤")

func _execute_with(
        engine,
        technique_id: String,
        power: int,
        snapshot: Dictionary,
        hand_id: String = "high_card",
        token: String = "fire-test") -> Dictionary:
    var definition = engine.repository.get_definition(technique_id)
    return engine.effect_executor.execute_all(
        definition.effects,
        _context(engine, technique_id, power, snapshot, hand_id, token))

func _context(
        engine,
        technique_id: String,
        power: int,
        snapshot: Dictionary,
        hand_id: String,
        token: String):
    var definition = engine.repository.get_definition(technique_id)
    return EffectContextScript.new().configure({
        "ports":engine.effect_ports, "actor":engine.player,
        "target":engine.enemy, "power":power, "initial_power":power,
        "values":{
            "technique_value":power, "initial_power":power,
            "card_total":int(snapshot.get("card_contribution", 0))},
        "hand_result":{"id":hand_id, "contributing":snapshot.get("contributing_cards", [])},
        "played_cards":snapshot.get("played_cards", []),
        "group_snapshot":snapshot, "captures":{},
        "technique_id":technique_id, "technique_name":definition.display_name,
        "technique_pool":definition.pool, "actual_hand_id":hand_id,
        "action_token":token, "source_kind":"technique",
        "card_identity_policy":engine.player.card_identity_policy,
    })

func _snapshot(played: Array, contributing: Array, contribution: int) -> Dictionary:
    var facts: Dictionary = {}
    for card in played:
        facts[str(card.id)] = {
            "rank_name_at_freeze":card.current_rank_name(),
            "rank_order_at_freeze":card.current_rank_order(),
            "base_qi_at_freeze":card.current_base_qi_value(),
            "card_base_qi_at_freeze":card.qi_value,
            "effective_qi_at_freeze":card.effective_qi_value(),
            "attributes_at_freeze":[card.current_attribute()],
            "base_attribute_at_freeze":card.attribute,
        }
    return {
        "played_cards":played.duplicate(),
        "contributing_cards":contributing.duplicate(),
        "extra_cards":played.filter(func(card): return not contributing.has(card)),
        "facts_by_id":facts, "card_contribution":contribution,
        "common_attributes":[], "contributing_common_attributes":[],
        "action_same_qi_gain":0, "action_same_qi_trigger_count":0,
        "action_same_qi_common_attributes":[],
        "action_is_extra":false, "action_from_same_qi":false,
    }

func _hand_for(technique_id: String) -> String:
    if technique_id.begins_with("pair_"):
        return "pair"
    if technique_id.begins_with("three_"):
        return "three_kind"
    if technique_id.begins_with("straight_"):
        return "straight"
    if technique_id.begins_with("bomb_"):
        return "four_kind"
    return "high_card"
