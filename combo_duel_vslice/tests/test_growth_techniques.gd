extends "res://tests/support/expanded_technique_test_base.gd"

const ValueResolverScript = preload("res://core/effects/effect_value_resolver.gd")

const GROWTH_TECHNIQUES := {
    "high_forest_transplant":"林·移栽", "high_forest_fallen_bloom_share":"林·落英分润",
    "high_forest_tall_tree":"林·木秀", "high_forest_break_branch":"林·折枝",
    "high_forest_deadwood_spring":"林·枯木逢春", "pair_forest_sprout":"林·催芽",
    "pair_forest_branch":"林·分枝", "pair_forest_co_growth":"林·并生",
    "pair_forest_deep_root":"林·根深", "pair_forest_harvest":"林·采实",
    "pair_forest_store_shade":"林·藏荫", "pair_forest_cutting":"林·扦插",
    "three_forest_spring_rain":"林·春雨", "three_forest_graft":"林·接木",
    "three_forest_dye_branch":"林·染枝", "straight_forest_many_tree_glory":"林·百木争荣",
    "straight_forest_dormant_root":"林·宿根", "bomb_forest_all_sprout":"林·万木萌发",
    "bomb_forest_all_wood_unite":"林·万木归一", "bomb_forest_four_seasons":"林·四时轮转",
    "high_forest_variant_plant":"林·异株", "straight_forest_change_form":"林·易形",
    "bomb_forest_myriad_forms":"林·万象化生",
}

func _initialize() -> void:
    if not _require_test_mode(): return
    var repository = _repository()
    _assert_resource_contract(repository, GROWTH_TECHNIQUES)
    _test_each_base_effect()
    _test_g_q_r_reads()
    _test_transfer_atomicity()
    _test_cutting_generation()
    _test_adjusted_forest_generation_resources()
    _test_discard_share_dependency()
    _test_dormant_root_after_growth_cleanup()
    _finish("GROWTH TECHNIQUE TEST")

func _test_each_base_effect() -> void:
    for technique_id in GROWTH_TECHNIQUES:
        if technique_id == "three_forest_dye_branch":
            _assert_base_behavior(technique_id, 20, 0)
        elif technique_id in [
                "high_forest_tall_tree", "high_forest_break_branch",
                "straight_forest_many_tree_glory"]:
            _assert_base_behavior(technique_id, 0, 10)
        elif technique_id == "pair_forest_store_shade":
            _assert_base_behavior(technique_id, 10, 0)
        else:
            _assert_base_behavior(technique_id, 10, 0)

func _test_g_q_r_reads() -> void:
    var engine = _engine(3001)
    var first = _card("6")
    var second = _card("9")
    engine.status_system.apply_card_anomaly(first, "buff", "growth", {}, "测试", 2)
    engine.status_system.apply_card_anomaly(first, "buff", "qi_heat", {}, "测试", 3)
    engine.status_system.apply_card_anomaly(second, "buff", "qi_heat", {}, "测试", 5)
    var context = EffectContextScript.new().configure({
        "ports":engine.effect_ports, "actor":engine.player, "target":engine.enemy,
        "captures":{"cards":[first, second]}, "group_snapshot":{},
    })
    var resolver = ValueResolverScript.new()
    _assert_equal(resolver.resolve({"kind":"capture_anomaly_layers_sum","capture":"cards","category":"buff","anomaly":"growth"}, context), 2, "G集合求和")
    _assert_equal(resolver.resolve({"kind":"capture_anomaly_layers_max","capture":"cards","category":"buff","anomaly":"qi_heat"}, context), 5, "Q集合求最大")
    _assert_equal(resolver.resolve({"kind":"capture_r_sum","capture":"cards","side":"actor"}, context), 8, "Rsum读取当前有效值减基础值")
    _assert_equal(resolver.resolve({"kind":"capture_r_max","capture":"cards","side":"actor"}, context), 5, "Rmax读取准确")

func _test_transfer_atomicity() -> void:
    var engine = _engine(3002)
    var source_a = _card("4")
    var source_b = _card("5")
    var target = _card("7")
    engine.status_system.apply_card_anomaly(source_a, "buff", "growth", {}, "测试", 2)
    engine.status_system.apply_card_anomaly(source_b, "buff", "growth", {}, "测试", 3)
    var success: Dictionary = engine.effect_executor.execute_all([{
        "op":"transfer_anomaly_layers", "source_capture":"sources", "target_capture":"target",
        "category":"buff", "anomaly":"growth", "all":true}],
        _context(engine, {"sources":[source_a, source_b], "target":[target]}))
    _assert_true(success.get("success", false), "接木通用原子转移执行")
    _assert_equal(source_a.anomaly_layers("buff", "growth") + source_b.anomaly_layers("buff", "growth"), 0, "接木移除打出牌全部成长")
    _assert_equal(target.anomaly_layers("buff", "growth"), 5, "接木目标获得成长总和")
    engine.status_system.apply_card_anomaly(source_a, "buff", "qi_heat", {}, "测试", 4)
    var failed: Dictionary = engine.effect_executor.execute_all([{
        "op":"transfer_anomaly_layers", "source_capture":"sources", "target_capture":"missing",
        "category":"buff", "anomaly":"qi_heat", "all":true}],
        _context(engine, {"sources":[source_a]}))
    _assert_true(failed.get("success", false), "归一缺少目标安全落空")
    _assert_equal(source_a.anomaly_layers("buff", "qi_heat"), 4, "归一目标失败不预扣来源炽气")

func _test_cutting_generation() -> void:
    var engine = _engine(3003)
    var source = _card("Q", "fire")
    engine.player.hand = [source]
    engine.status_system.apply_card_anomaly(source, "buff", "growth", {}, "测试", 2)
    var result: Dictionary = engine.effect_executor.execute_all([
        {"op":"generate_temporary_normal_card","source_capture":"source","capture":"generated"},
        {"op":"apply_card_anomaly_to_captured","capture":"generated","category":"buff","anomaly":"growth","layers":1,"result_capture":"grown"},
        {"op":"remove_anomaly_layers","capture":"source","category":"buff","anomaly":"growth","all":false,"amount":1,"when":{"capture_nonempty":"grown"}},
    ], _context(engine, {"source":[source]}))
    _assert_true(result.get("success", false), "扦插生成链成功")
    _assert_equal(engine.player.hand.size(), 2, "扦插临时牌成功入手")
    var generated = engine.player.hand[1]
    _assert_true(generated.temporary_card, "扦插生成临时普通真气")
    _assert_equal(generated.current_rank_name(), "Q", "扦插复制当前牌阶")
    _assert_equal(generated.attribute, "fire", "扦插复制基础属性")
    _assert_true(generated.has_anomaly("mark", "void"), "扦插生成牌默认获得虚无")
    _assert_equal(generated.anomaly_layers("buff", "growth"), 1, "扦插生成牌获得成长")
    _assert_equal(source.anomaly_layers("buff", "growth"), 1, "扦插入手成功后才扣来源1层")

func _test_adjusted_forest_generation_resources() -> void:
    var condense_engine = _engine(3006)
    var condense_source = _card("2", "forest")
    var condense_context = _context(condense_engine, {})
    condense_context.group_snapshot = {
        "played_cards":[condense_source],
        "contributing_cards":[condense_source],
        "extra_cards":[],
    }
    var condense: Dictionary = condense_engine.effect_executor.execute_all(
        condense_engine.repository.get_definition("high_forest_condense").effects,
        condense_context)
    _assert_true(condense.get("success", false), "林凝气资源链生成临时真气")
    _assert_equal(condense_engine.player.hand.size(), 1, "林凝气生成牌进入手牌")
    var condensed = condense_engine.player.hand[0]
    _assert_equal(condensed.current_rank_order(), 3, "林凝气来源2只能生成相邻3")
    _assert_equal(condensed.attribute, "forest", "林凝气保持计值牌基础属性")
    _assert_true(condensed.has_anomaly("mark", "void"), "林凝气生成牌默认获得虚无")

    var variant_engine = _engine(3007)
    var variant_source = _card("8", "fire")
    variant_source.set_temporary_rank("10", 10, 10)
    variant_engine.player.hand = [variant_source]
    var variant_definition = variant_engine.repository.get_definition(
        "high_forest_variant_plant")
    var variant_context = _context(variant_engine, {})
    var variant: Dictionary = variant_engine.effect_executor.execute_all(
        variant_definition.effects, variant_context)
    if variant.get("pending_choice", false):
        variant = variant_engine.effect_executor.resume(
            variant.get("_continuation"),
            str(variant.get("choice_request", {}).get("request_id", "")),
            [str(variant_source.id)])
    _assert_true(variant.get("success", false), "林异株选择后生成完成")
    var variant_generated = variant_engine.player.hand.filter(
        func(card): return card != variant_source)[0]
    _assert_equal(variant_generated.current_rank_order(), 10, "林异株复制来源当前牌阶")
    _assert_true(variant_generated.attribute != "fire", "林异株随机基础属性不同于来源基础属性")
    _assert_true(variant_generated.has_anomaly("mark", "void"), "林异株生成牌默认获得虚无")
    _assert_true(not variant_generated.has_any_reshape_storage(), "林异株生成牌不继承来源临时牌阶")

    var myriad_engine = _engine(3008)
    var low = _card("2", "wind")
    var high = _card("A", "mountain")
    myriad_engine.player.hand = [low, high]
    var myriad_definition = myriad_engine.repository.get_definition(
        "bomb_forest_myriad_forms")
    var myriad: Dictionary = myriad_engine.effect_executor.execute_all(
        myriad_definition.effects, _context(myriad_engine, {}))
    _assert_true(myriad.get("pending_choice", false), "万象化生资源链等待至多2张来源")
    myriad = myriad_engine.effect_executor.resume(
        myriad.get("_continuation"),
        str(myriad.get("choice_request", {}).get("request_id", "")),
        [str(low.id), str(high.id)])
    _assert_true(myriad.get("success", false), "万象化生两张来源分别生成")
    var generated_cards: Array = myriad_engine.player.hand.filter(
        func(card): return card != low and card != high)
    _assert_equal(generated_cards.size(), 2, "万象化生生成2张临时普通真气")
    _assert_true(generated_cards.any(func(card): return card.current_rank_order() == 3), "万象化生来源2只能升到3")
    _assert_true(generated_cards.any(func(card): return card.current_rank_order() == 13), "万象化生来源A只能降到K")
    _assert_true(generated_cards.all(func(card): return card.has_anomaly("mark", "void")), "万象化生生成牌均默认获得虚无")

    var change_engine = _engine(3009)
    var change_low = _card("2", "forest")
    var change_high = _card("A", "forest")
    change_engine.player.hand = [change_low, change_high]
    var change_definition = change_engine.repository.get_definition(
        "straight_forest_change_form")
    var changed: Dictionary = change_engine.effect_executor.execute_all(
        change_definition.effects, _context(change_engine, {}))
    _assert_true(changed.get("pending_choice", false), "林易形等待选择1至2张目标")
    changed = change_engine.effect_executor.resume(
        changed.get("_continuation"),
        str(changed.get("choice_request", {}).get("request_id", "")),
        [str(change_low.id), str(change_high.id)])
    _assert_true(changed.get("success", false), "林易形可同时处理2张手牌")
    _assert_equal(change_low.current_rank_order(), 3, "林易形令2只向上易形")
    _assert_equal(change_high.current_rank_order(), 13, "林易形令A只向下易形")
    _assert_equal(change_engine.player.defense, 10, "林易形强化不改变基础防御")

func _test_discard_share_dependency() -> void:
    var engine = _engine(3004)
    var source = _card("8")
    var first = _card("3")
    var second = _card("4")
    engine.player.hand = [source, first, second]
    engine.status_system.apply_card_anomaly(source, "buff", "qi_heat", {}, "测试", 5)
    var definition = engine.repository.get_definition("high_forest_fallen_bloom_share")
    var result: Dictionary = engine.effect_executor.execute_all(
        definition.effects, _context(engine, {}))
    _assert_true(result.get("pending_choice", false), "落英先等待选择明确弃牌来源")
    var continuation = result.get("_continuation")
    var request_id := str(result.get("choice_request", {}).get("request_id", ""))
    result = engine.effect_executor.resume(continuation, request_id, [str(source.id)])
    _assert_true(result.get("pending_choice", false), "落英余数由玩家选择分配目标")
    _assert_true(engine.player.discard_pile.has(source), "落英等待余数选择前已完成明确弃牌")
    _assert_equal(engine.player.defense, 10, "落英等待恢复不重放前置防御")
    continuation = result.get("_continuation")
    request_id = str(result.get("choice_request", {}).get("request_id", ""))
    result = engine.effect_executor.resume(continuation, request_id, [str(second.id)])
    _assert_true(result.get("success", false), "落英明确弃牌后分润成功")
    _assert_equal(first.anomaly_layers("buff", "qi_heat"), 2, "落英整除份额分给全部目标")
    _assert_equal(second.anomaly_layers("buff", "qi_heat"), 3, "落英余数分给玩家选择目标")
    _assert_equal(source.anomaly_layers("buff", "qi_heat"), 0, "落英弃牌成功后移除来源全部炽气")
    _assert_equal(engine.player.defense, 10, "落英二次恢复仍不重放前置防御")

func _test_dormant_root_after_growth_cleanup() -> void:
    var engine = _engine(3005)
    var rooted = _card("7")
    var plain = _card("8")
    engine.player.staging = [rooted, plain]
    engine.status_system.apply_card_anomaly(rooted, "buff", "growth", {}, "测试", 3)
    var definition = engine.repository.get_definition("straight_forest_dormant_root")
    var context = EffectContextScript.new().configure({
        "ports":engine.effect_ports, "actor":engine.player, "target":engine.enemy,
        "power":20, "initial_power":20, "played_cards":[rooted, plain],
        "group_snapshot":{"played_cards":[rooted, plain]}, "captures":{},
        "technique_name":definition.display_name, "action_token":"test-1-005"})
    var result: Dictionary = engine.effect_executor.execute_all(definition.effects, context)
    _assert_true(result.get("success", false), "宿根只锁定打出时具有成长的牌")
    engine.player.card_zone_service.commit_staging(engine.player)
    _assert_equal(rooted.anomaly_layers("buff", "growth"), 1, "宿根在原3层成长清理后只重建1层")
    _assert_true(engine.player.draw_pile.has(rooted), "宿根目标清理后洗回牌库")
    _assert_true(engine.player.discard_pile.has(plain), "宿根不处理打出时没有成长的牌")

func _context(engine, captures: Dictionary):
    return EffectContextScript.new().configure({
        "ports":engine.effect_ports, "actor":engine.player, "target":engine.enemy,
        "power":20, "initial_power":20, "captures":captures,
        "group_snapshot":{}, "technique_name":"成长专项", "action_token":"test-1-001"})
