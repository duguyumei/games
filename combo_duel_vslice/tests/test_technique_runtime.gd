extends SceneTree

const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const QiCardScript = preload("res://core/qi_card.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")
const TechniqueRepositoryScript = preload("res://core/technique_repository.gd")
const CombatEngineScript = preload("res://core/combat_engine.gd")
const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectValueResolverScript = preload("res://core/effects/effect_value_resolver.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]
const POOL_MEMBERSHIP := {
    "high_card": ["high"],
    "pair": ["pair"],
    "two_pair": ["pair"],
    "three_kind": ["three"],
    "straight": ["straight"],
    "full_house": ["pair", "three"],
    "four_kind": ["bomb"],
    "five_kind": ["bomb"],
}

var failures: Array[String] = []
var assertions: int = 0
var card_serial: int = 0
var tracked_engines: Array = []

func _initialize() -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    _test_empty_repository_and_production_data()
    _test_power_snapshot_formula_and_initial_power_reader()
    _test_empty_and_failed_techniques_leave_momentum_untouched()
    _test_same_hand_momentum_is_used_and_retained()
    _test_changed_hand_uses_old_momentum_then_keeps_new_gain()
    _test_retrigger_reuses_frozen_snapshot()
    _test_delayed_effect_reuses_frozen_snapshot()
    _test_reflection_override_sources_and_recursion_guard()
    _test_synchronized_reflection_matches_normal_damage()
    _test_all_insights_grow_empty_slots()
    _dispose_tracked_engines()
    if failures.is_empty():
        print("TECHNIQUE TEST PASS: %d assertions" % assertions)
        quit(0)
        return
    for failure in failures:
        push_error("TECHNIQUE TEST FAIL: %s" % failure)
    quit(1)

func _test_empty_repository_and_production_data() -> void:
    var repository = TechniqueRepositoryScript.new()
    _assert_true(repository.load_from_file(), "合法空功法仓库加载成功")
    _assert_true(repository.loaded_successfully, "空仓库与加载失败状态可区分")
    _assert_equal(repository.techniques.size(), 0, "正式功法仓库为零门")
    _assert_equal(repository.resource_paths, [], "正式功法资源路径为空")
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.production())
    _assert_true(catalog.load_all(), "production 空功法内容完整通过校验")
    _assert_equal(
        catalog.definition("techniques")["integration_statuses"], {},
        "正式接入状态为空对象")
    for hand_id in HAND_IDS:
        _assert_equal(
            catalog.definition("sequences")[hand_id], [],
            "production %s 序列为空" % hand_id)
    for enemy in catalog.definition("enemies")["enemies"]:
        for hand_id in HAND_IDS:
            _assert_equal(enemy["sequences"][hand_id], [], "敌人功法序列为空")
    var technique_category: Dictionary = catalog.definition(
        "practice_shop")["normal"]["categories"][0]
    _assert_equal(technique_category["candidate_ids"], [], "商店功法候选为空")
    var resource_count := 0
    for path in DirAccess.get_files_at("res://data/techniques"):
        if str(path).ends_with(".tres"):
            resource_count += 1
    _assert_equal(resource_count, 0, "正式目录不存在旧功法资源")

func _test_power_snapshot_formula_and_initial_power_reader() -> void:
    var hand := HandEvaluatorScript.evaluate([
        _card("7", "wind"), _card("7", "fire")])
    var values := PowerCalculatorScript.calculate(hand, {
        "multiplier_bonus": 1,
        "power_fixed": -50,
        "power_amp_percent": -50,
        "insight_multiplier": 99,
    })
    _assert_equal(values["base_value"], 14, "C 为贡献层结算后的总和")
    _assert_equal(values["fixed_multiplier"], 2, "固定牌型倍率保持独立")
    _assert_equal(values["technique_multiplier"], 3, "乘势或机缘进入 M")
    _assert_equal(values["baseline_value"], 28, "牌型基准值只读取固定倍率")
    _assert_equal(values["initial_power"], 42, "P₀=floor(C×M)")
    _assert_equal(values["direct_power_fixed"], -50, "直接固定修正不进入 P₀")
    _assert_equal(values["direct_power_percent"], -50, "直接百分比不进入 P₀")
    _assert_equal(values["pre_momentum_power"], -4, "负的连势前功法值不提前截断")
    values = PowerCalculatorScript.apply_momentum(values, 10)
    _assert_equal(values["momentum_used"], 10, "成功功法记录连势快照")
    _assert_equal(values["technique_value"], 6, "最终 P 加入连势后统一截断")
    _assert_true(not values.has("unamplified_technique_value"), "旧混义功法值字段已删除")
    var context = EffectContextScript.new().configure({"values": values})
    var resolver = EffectValueResolverScript.new()
    _assert_equal(resolver.resolve({"kind": "initial_power"}, context), 42, "效果通用读取 P₀")
    _assert_equal(
        resolver.resolve({
            "kind": "initial_power_fraction", "numerator": 1, "denominator": 2}, context),
        21,
        "效果可以按比例读取 P₀")

    var effect_engine = _engine_with_cards([])
    var effect_context = EffectContextScript.new().configure({
        "ports": effect_engine.effect_ports,
        "actor": effect_engine.player,
        "target": effect_engine.enemy,
        "power": 0,
    })
    var direct_result: Dictionary = effect_engine.effect_executor.execute_all([
        {"op": "add_direct_power_fixed", "amount": {
            "kind": "constant", "value": 5}},
        {"op": "add_direct_power_percent", "amount": {
            "kind": "constant", "value": 25}},
    ], effect_context)
    _assert_true(direct_result["success"], "直接功法值修正操作继续通过通用效果链结算")
    _assert_equal(effect_engine.player.direct_power_fixed, 5, "固定直接功法值修正写入明确角色字段")
    _assert_equal(effect_engine.player.direct_power_percent, 25, "百分比直接功法值修正写入明确角色字段")

func _test_empty_and_failed_techniques_leave_momentum_untouched() -> void:
    var empty_engine = _engine_with_cards([_card("9", "wind")])
    empty_engine.player.momentum_value = 8
    empty_engine.player.last_successful_technique_hand_id = "pair"
    var empty_preview: Dictionary = empty_engine.preview([
        empty_engine.player.hand[0].id])
    _assert_equal(empty_preview["values"]["momentum_used"], 0, "空序列预览不使用连势")
    var empty_result: Dictionary = empty_engine.confirm_play([
        empty_engine.player.hand[0].id])
    _assert_true(empty_result["success"], "空序列仍可正常出牌")
    _assert_equal(empty_engine.player.momentum_value, 8, "空序列不清空连势")
    _assert_equal(
        empty_engine.player.last_successful_technique_hand_id,
        "pair",
        "空序列不更新上次成功牌型")

    var failed_engine = _probe_engine(
        [_card("8", "wind")],
        "high_card",
        [],
        {"pure_attribute": "fire"})
    failed_engine.player.momentum_value = 7
    failed_engine.player.last_successful_technique_hand_id = "pair"
    var failed_preview: Dictionary = failed_engine.preview([
        failed_engine.player.hand[0].id])
    _assert_equal(failed_preview["values"]["momentum_used"], 0, "条件失败预览不使用连势")
    var failed_result: Dictionary = failed_engine.confirm_play([
        failed_engine.player.hand[0].id])
    _assert_true(failed_result["success"], "条件失败只令功法失败，不阻止出牌")
    _assert_equal(failed_engine.player.momentum_value, 7, "条件失败不清空连势")
    _assert_equal(failed_engine.player.last_successful_technique_hand_id, "pair", "失败不更新牌型")

func _test_same_hand_momentum_is_used_and_retained() -> void:
    var engine = _probe_engine([_card("6", "wind")], "high_card", [])
    engine.player.momentum_value = 5
    engine.player.last_successful_technique_hand_id = "high_card"
    var preview: Dictionary = engine.preview([engine.player.hand[0].id])
    var result: Dictionary = engine.confirm_play([engine.player.hand[0].id])
    _assert_true(result["technique_triggered"], "同牌型探针功法成功")
    _assert_equal(preview["values"]["initial_power"], result["preview"]["values"]["initial_power"], "预览与结算 P₀ 一致")
    _assert_equal(preview["values"]["momentum_used"], 5, "同牌型预览使用当前连势")
    _assert_equal(result["preview"]["values"]["momentum_used"], 5, "实际结算使用同一连势")
    _assert_equal(preview["values"]["technique_value"], result["preview"]["values"]["technique_value"], "预览与实际 P 一致")
    _assert_equal(engine.player.momentum_value, 5, "同牌型成功后保留连势")
    _assert_equal(engine.player.last_successful_technique_hand_id, "high_card", "成功后更新精确牌型")

func _test_changed_hand_uses_old_momentum_then_keeps_new_gain() -> void:
    var engine = _probe_engine([
        _card("5", "wind"), _card("5", "fire")],
        "pair",
        [{"op": "add_momentum", "amount": {
            "kind": "initial_power_fraction", "numerator": 1, "denominator": 2}}])
    engine.player.momentum_value = 9
    engine.player.last_successful_technique_hand_id = "high_card"
    var ids := [engine.player.hand[0].id, engine.player.hand[1].id]
    var preview: Dictionary = engine.preview(ids)
    var expected_new := int(floor(preview["values"]["initial_power"] / 2.0))
    var result: Dictionary = engine.confirm_play(ids)
    _assert_true(result["technique_triggered"], "换牌型探针功法成功")
    _assert_equal(result["preview"]["values"]["momentum_used"], 9, "换牌型仍完整使用旧连势")
    _assert_equal(engine.player.momentum_value, expected_new, "旧连势在效果前清空且新连势保留")
    _assert_equal(engine.player.last_successful_technique_hand_id, "pair", "换牌型成功后更新牌型")

func _test_retrigger_reuses_frozen_snapshot() -> void:
    var cards := [_card("4", "wind"), _card("4", "fire")]
    var engine = _probe_engine(cards, "pair", [{
        "op": "add_momentum", "amount": {"kind": "initial_power"}}])
    var snapshot := {
        "initial_power": 31,
        "direct_power_fixed": 4,
        "direct_power_percent": 20,
        "pre_momentum_power": 42,
        "momentum_used": 7,
        "technique_value": 49,
    }
    var result: Dictionary = engine.action_resolver.retrigger_current_hand_technique(
        engine.player, engine.enemy, engine.sequence_book, snapshot, 6, [])
    _assert_true(result["triggered"], "同组重触内存探针成功")
    _assert_equal(engine.player.momentum_value, 31, "重触按冻结 P₀ 产生连势")
    _assert_equal(engine.sequence_book.position("pair"), 0, "重触自身不重复推进序列")

func _test_delayed_effect_reuses_frozen_snapshot() -> void:
    var engine = _engine_with_cards([])
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "values": {
            "initial_power": 23,
            "direct_power_fixed": 7,
            "direct_power_percent": 50,
            "pre_momentum_power": 45,
            "momentum_used": 8,
            "technique_value": 53,
        },
        "technique_id": "probe_delayed_snapshot",
        "technique_name": "延迟快照探针",
    })
    var registered: Dictionary = engine.status_system.register_delayed_effects(
        "延迟快照探针",
        "turn_end",
        1,
        [{"op": "add_momentum", "amount": {"kind": "initial_power"}}],
        context)
    engine.player.momentum_value = 100
    engine.player.set_momentum(0)
    var resolved: Dictionary = engine.status_system._resolve_delayed_effect_chain(
        registered["record"])
    _assert_true(resolved["success"], "延迟效果恢复成功")
    _assert_equal(engine.player.momentum_value, 23, "延迟恢复保留冻结 P₀")
    _assert_equal(registered["record"]["power"], 53, "延迟记录保留最终 P")
    _assert_equal(registered["record"]["momentum_used"], 8, "延迟记录保留连势快照")

func _test_reflection_override_sources_and_recursion_guard() -> void:
    var engine = _engine_with_cards([])
    engine.player.defense = 10
    engine.player.set_reflection_percent(50)
    var enemy_life: int = engine.enemy.life
    engine.deal_damage(engine.enemy, engine.player, 10, "technique")
    _assert_equal(engine.enemy.life, enemy_life - 5, "50% 反震读取实际削防")
    engine.player.defense = 10
    engine.player.set_reflection_percent(40)
    enemy_life = engine.enemy.life
    engine.deal_damage(engine.enemy, engine.player, 10, "technique")
    _assert_equal(engine.enemy.life, enemy_life - 4, "新 40% 比例覆盖旧比例")

    engine.player.defense = 10
    enemy_life = engine.enemy.life
    engine.deal_damage(engine.enemy, engine.player, 7, "technique", true)
    _assert_equal(engine.enemy.life, enemy_life, "真伤不触发反震")
    engine.player.defense -= 3
    _assert_equal(engine.enemy.life, enemy_life, "直接防御衰减不触发反震")

    engine.player.defense = 10
    engine.enemy.defense = 10
    engine.enemy.set_reflection_percent(100)
    var player_life: int = engine.player.life
    engine.deal_damage(engine.enemy, engine.player, 10, "technique")
    _assert_equal(engine.player.life, player_life, "反震伤害被防御吸收时不会递归反震")
    _assert_equal(engine.enemy.defense, 6, "反震作为普通伤害扣除攻击方防御")

func _test_synchronized_reflection_matches_normal_damage() -> void:
    var engine = _engine_with_cards([])
    engine.player.defense = 12
    engine.player.set_reflection_percent(50)
    var enemy_life: int = engine.enemy.life
    engine.begin_synchronized_damage([{"actor": engine.enemy}])
    var buffered: Dictionary = engine.deal_damage(
        engine.enemy, engine.player, 12, "technique")
    _assert_true(buffered["buffered"], "同步伤害先进入缓冲")
    _assert_equal(engine.enemy.life, enemy_life, "缓冲刷新前不提前反震")
    engine.flush_synchronized_damage()
    _assert_equal(engine.enemy.life, enemy_life - 6, "同步刷新按同一反震规则结算")

func _test_all_insights_grow_empty_slots() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "心得空池测试内容加载成功")
    var normal_ids: Array = []
    for category in catalog.definition("practice_shop")["normal"]["categories"]:
        if str(category.get("content_kind", "")) == "insight":
            normal_ids = category["candidate_ids"]
    _assert_equal(normal_ids.size(), 8, "普通池继续包含八种心得")
    for pack_id in ["insight_pack_basic", "large_insight_pack", "deluxe_insight_pack"]:
        var found := []
        for pack in catalog.definition("practice_shop")["packs"]["candidates"]:
            if str(pack["id"]) == pack_id:
                found = pack["candidate_ids"]
        _assert_equal(found.size(), 8, "%s 继续包含八种心得" % pack_id)
    var side = CombatEngineScript.new().player
    for hand_id in HAND_IDS:
        var before := int(side.hand_technique_progression.get(
            hand_id, {"slot_count": 1})["slot_count"])
        var result: Dictionary = side.apply_insight_growth(hand_id, [])
        _assert_true(result["success"], "%s 心得在空池成功使用" % hand_id)
        _assert_equal(result["slot_count_after"], before + 1, "%s 槽位增加一" % hand_id)
        _assert_equal(result["acquired_technique_id"], "", "%s 不生成功法" % hand_id)
        _assert_true(result["no_technique_available"], "%s 明确报告池空" % hand_id)

func _probe_engine(
        cards: Array,
        hand_id: String,
        effects: Array,
        condition: Dictionary = {}):
    var engine = _engine_with_cards(cards)
    var probe := {
        "id": "probe_technique",
        "name": "内存探针功法",
        "pool": str(POOL_MEMBERSHIP[hand_id][0]),
        "special": false,
        "condition": condition,
        "effects": effects,
    }
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {},
        "resource_paths": [],
        "techniques": [probe],
    })
    var sequences := _empty_sequences()
    sequences[hand_id] = ["probe_technique"]
    engine.sequence_book.configure(sequences)
    engine.actions_available = 1
    return engine

func _engine_with_cards(cards: Array):
    var engine = CombatEngineScript.new()
    tracked_engines.append(engine)
    engine.setup(2308, false, cards)
    engine.player.hand = cards.duplicate()
    engine.player.draw_pile.clear()
    engine.player.staging.clear()
    engine.player.discard_pile.clear()
    engine.actions_available = 1
    engine.enemy.defense = 0
    return engine

func _dispose_tracked_engines() -> void:
    for engine in tracked_engines:
        engine.effect_ports.use_hand_retrigger_callback(Callable())
        engine.delayed_effects.clear()
        engine.action_service = null
        engine.round_service = null
        engine.enemy_planning_service = null
        engine.outcome_service = null
        engine.consumable_service = null
        engine.loadout_service = null
        engine.action_resolver = null
    tracked_engines.clear()

func _empty_sequences() -> Dictionary:
    var result := {"version": 1}
    for hand_id in HAND_IDS:
        result[hand_id] = []
    return result

func _card(rank: String, attribute: String):
    card_serial += 1
    var order := 14 if rank == "A" else int(rank)
    var qi := 12 if rank == "A" else int(rank)
    return QiCardScript.new(
        "probe_card_%d" % card_serial,
        rank,
        order,
        qi,
        attribute,
        attribute)

func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append("%s：期望为 true" % label)
