extends SceneTree

const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const TechniqueRepositoryScript = preload("res://core/technique_repository.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const SnapshotScript = preload("res://core/hand_group_snapshot.gd")
const QiCardScript = preload("res://core/qi_card.gd")
const ValueResolverScript = preload("res://core/effects/effect_value_resolver.gd")
const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const CombatEngineScript = preload("res://core/combat_engine.gd")

var failures: Array[String] = []
var assertions := 0

func _initialize() -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    _test_formal_resources()
    _test_group_snapshot_and_values()
    _test_piercing_condition()
    _test_mixed_flow_boundaries()
    _test_high_risk_runtime_behaviors()
    if failures.is_empty():
        print("HIGH CARD TECHNIQUE TEST PASS: %d assertions" % assertions)
        quit(0)
        return
    for failure in failures:
        push_error("HIGH CARD TECHNIQUE TEST FAIL: %s" % failure)
    quit(1)

func _test_formal_resources() -> void:
    var repository = TechniqueRepositoryScript.new()
    _assert_true(repository.load_from_file(), "TechniqueRepository加载正式内容")
    var high_ids: Array[String] = repository.formal_technique_ids().filter(
        func(value): return str(value).begins_with("high_"))
    _assert_equal(high_ids.size(), 59, "完整高牌池59门功法均为formal_complete")
    for technique_id in high_ids:
        var definition = repository.get_definition(technique_id)
        _assert_equal(definition.pool, "high", "%s属于高牌池" % technique_id)
        _assert_equal(definition.eligible_hand_ids, ["high_card"], "%s只允许高牌" % technique_id)
        _assert_equal(definition.base_loadout_limit, 1, "%s普通装配上限为1" % technique_id)
        _assert_true(not definition.description.is_empty(), "%s包含完整描述" % technique_id)
        _assert_true(not definition.semantic_tags.is_empty(), "%s包含AI语义" % technique_id)
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.production())
    _assert_true(catalog.load_all(), "高牌正式内容通过校验")
    for hand_id in ["high_card", "pair", "two_pair", "three_kind", "straight", "full_house", "four_kind", "five_kind"]:
        var sequence = catalog.definition("sequences").get(hand_id, [])
        _assert_true(sequence is Array and not sequence.is_empty(), "初始序列没有空槽")
        _assert_equal(str(sequence[0]), "basic_scatter", "初始序列仍使用基础散招")

func _test_group_snapshot_and_values() -> void:
    var high = _card("high", "K", 13, 11, "wind")
    var extra_fire = _card("extra-fire", "2", 2, 2, "fire")
    var extra_wind = _card("extra-wind", "3", 3, 3, "wind")
    var hand := HandEvaluatorScript.evaluate([extra_fire, high, extra_wind])
    var snapshot := SnapshotScript.freeze([extra_fire, high, extra_wind], hand, null)
    _assert_equal(snapshot["contributing_cards"], [high], "高牌只冻结最高牌为计值牌")
    _assert_equal(snapshot["extra_cards"], [extra_fire, extra_wind], "额外真气保持稳定出牌顺序")
    _assert_equal(SnapshotScript.base_qi_sum(snapshot, snapshot["played_cards"]), 16, "基础值总和不读取有效值")
    var context = EffectContextScript.new().configure({
        "played_cards": [extra_fire, high, extra_wind], "hand_result": hand,
        "group_snapshot": snapshot, "initial_power": 20, "power": 20,
    })
    var resolver = ValueResolverScript.new()
    _assert_equal(resolver.resolve({"kind":"extra_count"}, context), 2, "额外真气数量准确")
    _assert_equal(resolver.resolve({"kind":"extra_attribute_count","attribute":"wind"}, context), 1, "额外属性计数准确")
    _assert_true(not resolver.condition_met({"same_qi":"wind"}, context), "普通火额外牌破坏风同气")
    extra_fire.set_temporary_attribute("wind")
    var aliased := SnapshotScript.freeze([extra_fire, high, extra_wind], hand, null)
    var aliased_context = EffectContextScript.new().configure({
        "played_cards": [extra_fire, high, extra_wind], "hand_result": hand,
        "group_snapshot": aliased, "initial_power": 20, "power": 20,
    })
    _assert_true(resolver.condition_met({"same_qi":"wind"}, aliased_context), "临时属性参与同气")
    _assert_true(SnapshotScript.has_non_attribute_identity(aliased, extra_fire, "wind"), "临时风火牌仍具有非风身份")
    _assert_equal(snapshot["extra_cards"].size(), 2, "另一组快照不受后续身份变化污染")

func _test_piercing_condition() -> void:
    var card = _card("pierce", "A", 14, 12, "wind")
    var hand := HandEvaluatorScript.evaluate([card])
    var snapshot := SnapshotScript.freeze([card], hand, null)
    var resolver = ValueResolverScript.new()
    var normal = EffectContextScript.new().configure({
        "played_cards":[card], "hand_result":hand, "group_snapshot":snapshot,
        "initial_power":12, "power":12})
    var true_hit = EffectContextScript.new().configure({
        "played_cards":[card], "hand_result":hand, "group_snapshot":snapshot,
        "initial_power":13, "power":13})
    _assert_true(not resolver.condition_met({"initial_power_greater_than_group_base_qi":true}, normal), "P0等于S走普通伤害")
    _assert_true(resolver.condition_met({"initial_power_greater_than_group_base_qi":true}, true_hit), "P0大于S走真伤")

func _test_mixed_flow_boundaries() -> void:
    var single = _high_engine([_card("single-wind", "K", 13, 11, "wind")], 9101)
    var single_preview: Dictionary = single.preview([single.player.hand[0].id])
    var single_rng_state = single.rng.state
    _assert_true(not single_preview.has("frozen_power_formation"), "混流预览不冻结随机目标")
    _assert_equal(single.rng.state, single_rng_state, "混流预览不推进正式随机源")
    single.action_resolver.finalize_action_preview(
        single.player, single_preview, single.enemy, 1)
    _assert_equal(single_preview["values"]["direct_power_fixed"], 0, "单张风没有额外真气不加值")

    var wind_fire_cards := [
        _card("wf-high", "K", 13, 11, "wind"),
        _card("wf-extra", "2", 2, 2, "fire")]
    var wind_fire = _high_engine(wind_fire_cards, 9102)
    var wind_fire_preview: Dictionary = wind_fire.preview(_ids(wind_fire_cards))
    wind_fire.action_resolver.finalize_action_preview(
        wind_fire.player, wind_fire_preview, wind_fire.enemy, 1)
    _assert_equal(wind_fire_preview["values"]["direct_power_fixed"], 2, "风加普通火按额外火有效值加值")
    _assert_true(not SnapshotScript.is_same_qi(
        wind_fire_preview["group_snapshot"], "wind"), "普通火破坏风同气")

    var pure_wind_cards := [
        _card("ww-high", "K", 13, 11, "wind"),
        _card("ww-extra", "2", 2, 2, "wind")]
    var pure_wind = _high_engine(pure_wind_cards, 9103)
    var pure_wind_preview: Dictionary = pure_wind.preview(_ids(pure_wind_cards))
    pure_wind.action_resolver.finalize_action_preview(
        pure_wind.player, pure_wind_preview, pure_wind.enemy, 1)
    _assert_equal(pure_wind_preview["values"]["direct_power_fixed"], 0, "纯风额外牌不是混流加值目标")

    var aliased_extra = _card("alias-extra", "2", 2, 2, "fire")
    aliased_extra.set_temporary_attribute("wind")
    var aliased_cards := [
        _card("alias-high", "K", 13, 11, "wind"), aliased_extra]
    var aliased_engine = _high_engine(aliased_cards, 9104)
    var aliased_preview: Dictionary = aliased_engine.preview(_ids(aliased_cards))
    aliased_engine.action_resolver.finalize_action_preview(
        aliased_engine.player, aliased_preview, aliased_engine.enemy, 1)
    var frozen_target := str(aliased_preview["frozen_power_formation"]["target_id"])
    var frozen_power := int(aliased_preview["values"]["technique_value"])
    var frozen_initial := int(aliased_preview["values"]["initial_power"])
    var rng_after_confirm = aliased_engine.rng.state
    aliased_engine.action_resolver.finalize_action_preview(
        aliased_engine.player, aliased_preview, aliased_engine.enemy, 1)
    _assert_equal(aliased_preview["values"]["direct_power_fixed"], 2, "风火双身份额外牌加值")
    _assert_true(SnapshotScript.is_same_qi(
        aliased_preview["group_snapshot"], "wind"), "风火双身份额外牌维持风同气")
    _assert_equal(str(aliased_preview["frozen_power_formation"]["target_id"]), frozen_target, "正式确认复用混流随机目标")
    _assert_equal(aliased_preview["values"]["technique_value"], frozen_power, "正式确认复用混流最终P")
    _assert_equal(aliased_preview["values"]["initial_power"], frozen_initial, "混流固定修正不改变P0")
    _assert_equal(aliased_engine.rng.state, rng_after_confirm, "重复正式确认不再次推进随机源")

func _test_high_risk_runtime_behaviors() -> void:
    _test_forest_gather_recycles_extra_card()
    _test_fire_ignite_dependency()
    _test_fire_burn_void_retrigger()
    _test_mountain_rampart_actual_trigger()
    _test_piercing_cloud_damage_modes()

func _test_forest_gather_recycles_extra_card() -> void:
    var high = _card("gather-high", "K", 13, 11, "wind")
    var extra = _card("gather-extra", "2", 2, 2, "forest")
    var engine = _high_engine([high, extra], 9201, "high_forest_gather")
    var result: Dictionary = engine.confirm_play(_ids([high, extra]))
    _assert_true(result.get("success", false), "聚林端到端结算成功")
    _assert_true(engine.player.draw_pile.has(extra), "额外林牌入弃牌堆后按重聚规则回到牌库")

func _test_fire_ignite_dependency() -> void:
    var played = _card("ignite-played", "A", 14, 12, "fire")
    var invalid_self = _card("ignite-self", "3", 3, 3, "fire")
    var enemy_card = _card("ignite-enemy", "4", 4, 4, "wind")
    var engine = _high_engine([played], 9202, "high_fire_ignite")
    engine.player.discard_pile = [invalid_self]
    engine.enemy.draw_pile = [enemy_card]
    engine.status_system.apply_card_anomaly(
        invalid_self, "mark", "burned_out", {}, "test")
    var result: Dictionary = engine.confirm_play([played.id])
    _assert_true(result.get("success", false), "火附火自方无合法目标时基础伤害仍结算")
    _assert_true(not enemy_card.has_anomaly("mark", "burned_out"), "自方燃尽失败时敌方不燃尽")

func _test_fire_burn_void_retrigger() -> void:
    var first = _card("void-first", "A", 14, 12, "fire")
    var second = _card("void-second", "3", 3, 3, "forest")
    var engine = _high_engine([first, second], 9203, "high_fire_burn_void")
    engine.status_system.apply_card_anomaly(first, "mark", "void", {}, "test")
    engine.status_system.apply_card_anomaly(second, "mark", "void", {}, "test")
    var preview: Dictionary = engine.preview(_ids([first, second]))
    _assert_true(preview.get("valid", false), "火焚虚预览有效")
    if not preview.get("valid", false):
        return
    var snapshot: Dictionary = SnapshotScript.freeze(
        preview["cards"], preview["hand"], engine.player, engine.enemy)
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports, "actor": engine.player,
        "target": engine.enemy, "hand_result": preview["hand"],
        "played_cards": preview["cards"], "group_snapshot": snapshot,
        "values": preview["values"], "technique_name": "火·焚虚",
    })
    var definition = engine.repository.get_definition("high_fire_burn_void")
    var first_result: Dictionary = engine.effect_executor.execute_all(
        definition.effects, context)
    _assert_true(first_result.get("success", false), "火焚虚多张逐张依赖链成功")
    _assert_equal(engine.player.experience, 2, "火焚虚每张合格牌各获得1点历练")
    _assert_true(first.has_anomaly("mark", "burned_out") and second.has_anomaly(
        "mark", "burned_out"), "火焚虚成功移除虚无后逐张施加燃尽")
    var second_context = EffectContextScript.new().configure({
        "ports": engine.effect_ports, "actor": engine.player,
        "target": engine.enemy, "hand_result": preview["hand"],
        "played_cards": preview["cards"], "group_snapshot": snapshot,
        "values": preview["values"], "technique_name": "火·焚虚",
    })
    engine.effect_executor.execute_all(definition.effects, second_context)
    _assert_equal(engine.player.experience, 2, "火焚虚重触不重复处理已经燃尽的牌")

func _test_mountain_rampart_actual_trigger() -> void:
    var triggered = _card("rampart-triggered", "3", 3, 3, "mountain")
    triggered.set_enhancement("flawless")
    var plain = _card("rampart-plain", "K", 13, 11, "mountain")
    var engine = _high_engine([triggered, plain], 9204, "high_mountain_rampart")
    var preview: Dictionary = engine.preview(_ids([triggered, plain]))
    engine.player.stage_cards(_ids([triggered, plain]))
    engine.action_resolver.finalize_action_preview(
        engine.player, preview, engine.enemy, 1)
    var record = engine.action_resolver.make_action_record(
        engine.player, engine.enemy, preview, engine.sequence_book, 100, 1)
    engine.action_resolver.begin_action_resolution([engine.player, engine.enemy], {
        "action_tokens": [str(record["token"])]})
    var resolved: Dictionary = engine.action_resolver.resolve_action_records(
        [record], false)
    _assert_true(resolved.get("success", false), "山坚壁效果链结算成功")
    _assert_true(triggered.has_anomaly("mark", "regroup"), "山坚壁只给实际成功触发打出时效果的牌重聚")
    _assert_true(not plain.has_anomaly("mark", "regroup"), "山坚壁不选择未实际触发打出时效果的牌")
    engine.action_resolver.abort_action_resolution()

func _test_piercing_cloud_damage_modes() -> void:
    var normal_card = _card("pierce-normal", "A", 14, 12, "wind")
    var normal = _high_engine([normal_card], 9205, "high_wind_piercing_cloud")
    normal.enemy.defense = 20
    var normal_life := int(normal.enemy.life)
    normal.confirm_play([normal_card.id])
    _assert_equal(normal.enemy.life, normal_life, "穿云P0不大于S时只造成普通伤害")
    _assert_equal(normal.enemy.defense, 14, "穿云普通分支只结算一次伤害")

    var true_card = _card("pierce-true", "A", 14, 12, "wind")
    true_card.set_enhancement("momentum")
    var true_engine = _high_engine([true_card], 9206, "high_wind_piercing_cloud")
    true_engine.enemy.defense = 20
    var true_life := int(true_engine.enemy.life)
    true_engine.confirm_play([true_card.id])
    _assert_equal(true_engine.enemy.life, true_life - 12, "穿云P0大于S时改为真伤")
    _assert_equal(true_engine.enemy.defense, 20, "穿云真伤分支不再额外造成普通伤害")

func _high_engine(
        cards: Array,
        seed_value: int,
        technique_id: String = "high_wind_mixed_flow"):
    var engine = CombatEngineScript.new()
    engine.setup(seed_value, false, cards)
    engine.player.hand = cards.duplicate()
    engine.player.draw_pile.clear()
    engine.player.staging.clear()
    engine.player.discard_pile.clear()
    engine.enemy.hand.clear()
    engine.enemy.draw_pile.clear()
    engine.enemy.staging.clear()
    engine.enemy.discard_pile.clear()
    engine.sequence_book.configure({"high_card": [technique_id]})
    engine.actions_available = 1
    engine.enemy.defense = 0
    return engine

func _ids(cards: Array) -> Array:
    return cards.map(func(card): return str(card.id))

func _card(id: String, rank: String, order: int, qi: int, attribute: String):
    return QiCardScript.new(id, rank, order, qi, attribute, attribute, id)

func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append(label)

func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])
