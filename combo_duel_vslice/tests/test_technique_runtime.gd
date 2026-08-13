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
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const TechniqueLoadoutPolicyScript = preload(
    "res://core/technique_loadout_policy.gd")

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

class LoadoutQueryResult:
    extends RefCounted
    var values: Dictionary
    func _init(source: Dictionary) -> void:
        values = source
    func to_dict() -> Dictionary:
        return values.duplicate(true)

class LoadoutLimitTwoResolver:
    extends RefCounted
    var calls: Array[Dictionary] = []
    func resolve(request):
        calls.append(request.to_dict())
        return LoadoutQueryResult.new({
            "success": true,
            "hook": request.hook,
            "subject_kind": request.subject_kind,
            "subject_id": request.subject_id,
            "base_value": request.base_value,
            "effective_value": 2 if request.subject_id == "normal_probe" \
                else request.base_value,
            "modifier_breakdown": [],
            "source_fingerprint": "fake_limit_two",
        })

class LoadoutCatalog:
    extends RefCounted
    var techniques: Dictionary = {}
    var statuses: Dictionary = {}
    var sequences: Dictionary = {}
    func _init() -> void:
        var hands := [
            "high_card", "pair", "two_pair", "three_kind", "straight",
            "full_house", "four_kind", "five_kind"]
        techniques = {
            "basic_scatter": {
                "id": "basic_scatter", "name": "散招", "pool": "universal",
                "built_in": true, "base_loadout_limit": 99,
                "eligible_hand_ids": hands.duplicate(),
                "built_in_fallback_order": 0,
            },
            "basic_guard": {
                "id": "basic_guard", "name": "守招", "pool": "universal",
                "built_in": true, "base_loadout_limit": 99,
                "eligible_hand_ids": hands.duplicate(),
                "built_in_fallback_order": 1,
            },
            "normal_probe": {
                "id": "normal_probe", "name": "普通探针", "pool": "pair",
                "built_in": false, "base_loadout_limit": 1,
                "eligible_hand_ids": [],
            },
        }
        statuses = {
            "basic_scatter": "formal_complete",
            "basic_guard": "formal_complete",
            "normal_probe": "formal_complete",
        }
        for hand_id in hands:
            sequences[hand_id] = ["basic_scatter"]
    func get_by_id(kind: String, content_id: String) -> Dictionary:
        return techniques.get(content_id, {}).duplicate(true) \
            if kind == "technique" else {}
    func definition(key: String) -> Dictionary:
        if key == "sequences":
            return sequences.duplicate(true)
        if key == "techniques":
            return {
                "techniques": techniques.values(),
                "integration_statuses": statuses.duplicate(true),
                "pool_membership": {
                    "high_card": ["high"], "pair": ["pair"],
                    "two_pair": ["pair"], "three_kind": ["three"],
                    "straight": ["straight"], "full_house": ["pair", "three"],
                    "four_kind": ["bomb"], "five_kind": ["bomb"],
                },
            }
        return {}
    func all_of(kind: String) -> Array:
        return techniques.values() if kind == "technique" else []

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
    _test_defense_decay_return_records()
    _test_action_resolution_results_and_no_life_loss_disruption()
    _test_synchronized_reflection_matches_normal_damage()
    _test_all_insights_grow_empty_slots()
    _test_s2f6a_basic_techniques_and_loadout_limits()
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
    _assert_equal(repository.techniques.size(), 27, "正式功法仓库包含基础功法与25门高牌功法")
    _assert_equal(repository.resource_paths.size(), 27, "正式功法资源路径包含27项")
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.production())
    _assert_true(catalog.load_all(), "production 空功法内容完整通过校验")
    _assert_equal(
        catalog.definition("techniques")["integration_statuses"],
        repository.integration_statuses,
        "功法仓库与内容目录接入状态一致")
    for hand_id in HAND_IDS:
        _assert_equal(
            catalog.definition("sequences")[hand_id], ["basic_scatter"],
            "production %s 默认装备散招" % hand_id)
    for enemy in catalog.definition("enemies")["enemies"]:
        for hand_id in HAND_IDS:
            _assert_equal(enemy["sequences"][hand_id], [], "敌人功法序列为空")
    var technique_category: Dictionary = catalog.definition(
        "practice_shop")["normal"]["categories"][0]
    _assert_equal(technique_category["candidate_ids"].size(), 25, "商店包含25门高牌正式候选")
    var resource_count := 0
    for path in DirAccess.get_files_at("res://data/techniques"):
        if str(path).ends_with(".tres"):
            resource_count += 1
    _assert_equal(resource_count, 27, "正式目录存在基础功法与25门高牌功法资源")

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

    var expiry_context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "action_token": "player-3-100",
    })
    var expiry: Dictionary = engine.status_system.register_reflection_expiry(
        expiry_context, 50)
    engine.player.set_reflection_percent(25, "later-source")
    engine.status_system._on_turn_end({"actor": engine.player})
    _assert_equal(engine.player.current_reflection_percent, 25, "反震到期不清除后来覆盖的新来源")
    _assert_true(str(expiry.get("source_token", "")) != "", "反震延迟记录具有来源token")

func _test_defense_decay_return_records() -> void:
    var engine = _engine_with_cards([])
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "action_token": "player-4-100",
    })
    engine.status_system.register_defense_decay_return(context)
    engine.status_system.register_defense_decay_return(context)
    engine.status_system._on_defense_decay_resolved({
        "actor": engine.player,
        "round_number": 4,
        "context": {"decay": {"lost": 3}},
    })
    engine.player.defense = 0
    engine.status_system._on_round_start_records({"round_number": 5})
    _assert_equal(engine.player.defense, 6, "立山式同回合两份记录分别返还自然衰减")

    engine.status_system.register_defense_decay_return(context)
    engine.status_system._on_defense_decay_resolved({
        "actor": engine.player,
        "round_number": 4,
        "context": {"decay": {"lost": 0}},
    })
    engine.status_system._on_round_start_records({"round_number": 5})
    _assert_equal(engine.player.defense, 6, "防御提前打光时立山式返还相应减少为零")

func _test_action_resolution_results_and_no_life_loss_disruption() -> void:
    var engine = _engine_with_cards([])
    var target_card = _card("3", "wind")
    engine.enemy.hand = [target_card]
    engine.enemy.defense = 5
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
    })
    var disruption := {
        "op": "apply_anomaly_from_query",
        "query": {"side":"target", "zone":"hand", "order":"zone", "limit":1,
            "filters":{"card_kind":"normal"}},
        "capture":"suppressed", "category":"state", "anomaly":"vulnerability",
    }
    engine.status_system.register_no_life_loss_disruption(context, disruption)
    engine.action_resolver.begin_action_resolution([engine.player, engine.enemy])
    engine.deal_damage(engine.enemy, engine.player, 0, "technique")
    var completed: Dictionary = engine.action_resolver.finish_action_resolution()
    _assert_true(completed.get("success", false), "单次行动完成时点成功发出")
    _assert_true(target_card.has_anomaly("state", "vulnerability"), "本次未损失生命时镇山施加破绽")

    engine.status_system.remove_card_anomaly(target_card, "state", "vulnerability", "test")
    engine.status_system.register_no_life_loss_disruption(context, disruption)
    engine.action_resolver.begin_action_resolution([engine.player, engine.enemy])
    engine.player.defense = 0
    engine.deal_damage(engine.enemy, engine.player, 1, "technique")
    completed = engine.action_resolver.finish_action_resolution()
    var player_result: Dictionary = completed.get("results", []).filter(
        func(value): return value.get("side") == engine.player)[0]
    _assert_equal(player_result.get("actual_life_loss", 0), 1, "行动结果提供本次实际生命损失")
    _assert_true(not target_card.has_anomaly("state", "vulnerability"), "本次损失生命时镇山不施加破绽")

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

func _test_s2f6a_basic_techniques_and_loadout_limits() -> void:
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.production())
    _assert_true(catalog.load_all(), "F6A 正式基础功法内容可加载")
    var scatter: Dictionary = catalog.get_by_id("technique", "basic_scatter")
    var guard: Dictionary = catalog.get_by_id("technique", "basic_guard")
    var effect_engine = _engine_with_cards([])
    for power in [3, 4]:
        effect_engine.enemy.life = 100
        effect_engine.enemy.defense = 0
        effect_engine.player.defense = 0
        var context = EffectContextScript.new().configure({
            "ports": effect_engine.effect_ports,
            "actor": effect_engine.player,
            "target": effect_engine.enemy,
            "power": power,
        })
        _assert_true(effect_engine.effect_executor.execute_all(
            scatter["effects"], context)["success"], "散招走通用效果链")
        _assert_equal(100 - effect_engine.enemy.life, int(floor(power / 4.0)),
            "散招 P=%d 造成 floor(P/4)" % power)
        _assert_true(effect_engine.effect_executor.execute_all(
            guard["effects"], context)["success"], "守招走通用效果链")
        _assert_equal(effect_engine.player.defense, int(floor(power / 4.0)),
            "守招 P=%d 获得 floor(P/4) 防御" % power)

    var action_engine = _engine_with_cards([_card("4", "wind")])
    action_engine.repository.configure(catalog.definition("techniques"), true)
    var action_sequences := _empty_sequences()
    action_sequences["high_card"] = ["basic_scatter", "basic_guard"]
    action_engine.sequence_book.configure(action_sequences)
    action_engine.player.momentum_value = 3
    action_engine.player.last_successful_technique_hand_id = "high_card"
    var played: Dictionary = action_engine.confirm_play([action_engine.player.hand[0].id])
    _assert_true(played.get("technique_triggered", false), "基础功法是真实功法并正常启动")
    _assert_equal(played["preview"]["values"]["momentum_used"], 3, "基础功法读取连势")
    _assert_equal(action_engine.sequence_book.current_id("high_card"), "basic_guard", "基础功法成功后推进真实序列")

    var fake_catalog := LoadoutCatalog.new()
    var growth = GrowthInventoryScript.new(fake_catalog, false)
    growth.learned_technique_ids.assign(["normal_probe"])
    var policy = growth.technique_loadout_policy
    var baseline: Dictionary = growth.hand_technique_progression.duplicate(true)
    var cross_hand: Dictionary = baseline.duplicate(true)
    cross_hand["pair"] = {"slot_count": 1, "sequence": ["normal_probe"]}
    cross_hand["two_pair"] = {"slot_count": 1, "sequence": ["normal_probe"]}
    _assert_true(not policy.validate_complete(
        growth, cross_hand, growth.learned_technique_ids, "two_pair")["success"],
        "普通功法跨八牌型合计第二次被拒绝")
    var same_hand: Dictionary = baseline.duplicate(true)
    same_hand["pair"] = {
        "slot_count": 2,
        "sequence": ["normal_probe", "normal_probe"],
    }
    _assert_true(not policy.validate_complete(
        growth, same_hand, growth.learned_technique_ids, "pair")["success"],
        "普通功法同一序列第二次被拒绝")

    var resolver := LoadoutLimitTwoResolver.new()
    policy.use_int_policy_resolver(resolver)
    var before_state := growth.capture_mutation_state()
    _assert_true(policy.validate_complete(
        growth, cross_hand, growth.learned_technique_ids, "two_pair")["success"],
        "Fake 查询将普通功法上限改为 2 后跨牌型合法")
    _assert_true(policy.validate_complete(
        growth, same_hand, growth.learned_technique_ids, "pair")["success"],
        "Fake 查询上限 2 后同序列重复合法")
    _assert_equal(growth.capture_mutation_state(), before_state, "装配次数查询不修改本局状态")
    _assert_true(resolver.calls.all(func(call):
        return call.get("hook") == "technique_loadout_copy_limit_query"),
        "所有 Fake 次数查询使用统一 hook")

    policy.use_int_policy_resolver(null)
    var ninety_nine: Dictionary = baseline.duplicate(true)
    var remaining := 99
    for hand_id in HAND_IDS:
        var count := mini(remaining, 13)
        ninety_nine[hand_id] = {
            "slot_count": count,
            "sequence": [],
        }
        for _index in range(count):
            ninety_nine[hand_id]["sequence"].append("basic_scatter")
        remaining -= count
    _assert_equal(remaining, 0, "测试夹具恰好生成 99 个散招")
    _assert_true(policy.validate_complete(
        growth, ninety_nine, growth.learned_technique_ids)["success"],
        "散招全局装配 99 次合法")
    var hundred: Dictionary = ninety_nine.duplicate(true)
    hundred["high_card"]["slot_count"] += 1
    hundred["high_card"]["sequence"].append("basic_scatter")
    _assert_true(not policy.validate_complete(
        growth, hundred, growth.learned_technique_ids)["success"],
        "第 100 个散招被拒绝")

    var original: Dictionary = growth.hand_technique_progression.duplicate(true)
    _assert_true(not growth.set_hand_technique_loadout("pair", [])["success"],
        "未填满序列不能保存")
    _assert_equal(growth.hand_technique_progression, original,
        "不完整提交失败时八牌型原状态不变")
    var insight := growth.apply_insight_growth("high_card", [])
    _assert_true(insight["success"], "心得无普通候选时仍成功")
    _assert_equal(insight["acquired_technique_id"], "basic_scatter",
        "心得无普通候选时自动填入散招")
    _assert_equal(growth.hand_progression("high_card")["sequence"].size(),
        growth.hand_progression("high_card")["slot_count"],
        "心得完成后序列仍填满")
    _assert_equal(growth.learned_technique_ids, ["normal_probe"],
        "基础功法不写入已习得功法集合")

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
