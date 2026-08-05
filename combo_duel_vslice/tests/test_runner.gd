extends SceneTree

const QiCardScript = preload("res://core/qi_card.gd")
const CardInstanceIdFactoryScript = preload("res://core/card_instance_id_factory.gd")
const QiCardInstanceDataScript = preload("res://core/qi_card_instance_data.gd")
const RunDeckScript = preload("res://core/run_deck.gd")
const CardStateLifecycleScript = preload("res://core/card_state_lifecycle.gd")
const DeckFactoryScript = preload("res://core/deck_factory.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")
const CombatEngineScript = preload("res://core/combat_engine.gd")
const BattleSideScript = preload("res://core/battle_side.gd")
const BattleFlowCoordinatorScript = preload("res://core/battle_flow_coordinator.gd")
const BattleTimingSystemScript = preload("res://core/battle_timing_system.gd")
const StatusSystemScript = preload("res://core/status_system.gd")
const TriggerQueueScript = preload("res://core/trigger_queue.gd")
const BattleObservationScript = preload("res://core/battle_observation.gd")
const PlayerActionControllerScript = preload("res://core/player_action_controller.gd")
const EnemyActionControllerScript = preload("res://core/enemy_action_controller.gd")
const BattleActionProposalScript = preload("res://core/battle_action_proposal.gd")
const AiBattleContextScript = preload("res://core/ai/ai_battle_context.gd")
const AiDecisionObservationScript = preload("res://core/ai/ai_decision_observation.gd")
const AiHistoryProjectorScript = preload("res://core/ai/ai_history_projector.gd")
const AiBattleConversationScript = preload("res://core/ai/ai_battle_conversation.gd")
const AiCandidateScript = preload("res://core/ai/ai_candidate.gd")
const AiConversationStoreScript = preload("res://core/ai/ai_conversation_store.gd")
const AiDecisionGatewayScript = preload("res://core/ai/ai_decision_gateway.gd")
const MockAiProviderScript = preload("res://core/ai/providers/mock_ai_provider.gd")
const DamageResolverScript = preload("res://core/damage_resolver.gd")
const GameLogScript = preload("res://core/game_log.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const MapGeneratorScript = preload("res://core/map_generator.gd")
const NodeDispatcherScript = preload("res://core/node_dispatcher.gd")
const RunStateScript = preload("res://core/run_state.gd")
const RunSessionScript = preload("res://core/run_session.gd")
const MapNavigationServiceScript = preload("res://core/map_navigation_service.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const RunProgressSnapshotScript = preload("res://core/run_progress_snapshot.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const ContentValidatorScript = preload("res://core/content_validator.gd")
const EffectExecutorScript = preload("res://core/effect_executor.gd")
const RunScene = preload("res://ui/run_main.tscn")

class ProbeEffectHandler:
    extends RefCounted

    func operation_ids() -> Array[String]:
        return ["probe_effect"]

    func group_name() -> String:
        return "test_probe"

    func execute(_effect: Dictionary, context: Dictionary) -> Dictionary:
        context["probe_count"] = int(context.get("probe_count", 0)) + 1
        return {"success": true, "detail": "探针已执行"}

    func summarize(_effect: Dictionary, _context: Dictionary, intent: Dictionary, _state: Dictionary) -> void:
        intent["defense"] = int(intent.get("defense", 0)) + 7

class TimingProbe:
    extends RefCounted

    var calls: Array[String] = []

    func record(event, label: String) -> Dictionary:
        calls.append("%s:%s:%d" % [event.timing, label, event.serial])
        return {"success": true, "detail": label}

var failures: Array[String] = []
var assertions: int = 0
var card_serial: int = 0

func _initialize() -> void:
    _test_content_catalog_and_validator()
    _test_qi_instance_state_contract()
    _test_run_deck_contract()
    _test_card_zone_service_contract()
    _test_battle_flow_coordinator_contract()
    _test_battle_timing_system_contract_and_integration()
    _test_status_system_contract()
    _test_action_controller_boundaries_and_strategy()
    _test_remote_ai_module_contract()
    _test_effect_handler_registry_contract()
    _test_standard_deck()
    _test_pool_structure_and_turn_draw_rules()
    _test_all_nine_hand_types_and_contributors()
    _test_power_calculation()
    _test_damage_resolver_rules_and_facade()
    _test_structured_game_log_channels()
    _test_action_preview_service_matches_engine_facade()
    _test_action_resolver_boundary_and_queue_rebind()
    _test_sequence_progression_and_condition_failure()
    _test_no_automatic_damage_or_draw()
    _test_representative_damage_draw_discard()
    _test_representative_defense_and_layers()
    _test_representative_multi_attack()
    _test_representative_special_technique()
    _test_delayed_power_snapshot()
    _test_visible_queue_left_to_right()
    _test_inner_skill_equipment_and_extra_qi_defense()
    _test_inner_skill_preview_and_enemy_plan()
    _test_inner_skill_and_technique_left_to_right()
    _test_consumable_shared_slots_and_generation_limit()
    _test_insight_growth_and_technique_acquisition()
    _test_hierophant_bonus_enhancement_and_preview()
    _test_aura_seeded_finish_and_preview()
    _test_battle_consumable_reshape_persists_via_run_deck()
    _test_battle_session_commands_snapshots_and_events()
    _test_map_generation_is_deterministic_and_constrained()
    _test_map_routes_reach_boss_without_crossing()
    _test_node_dispatcher_is_data_driven_and_deterministic()
    _test_run_state_node_and_practice_gate()
    _test_run_service_boundaries_and_progress_snapshot()
    _test_run_session_commands_snapshots_events_and_logs()
    _test_boss_chest_flow()
    _test_run_state_battle_growth_persistence()
    _test_map_practice_and_battle_scene_integration()
    _test_scripted_enemy_is_deterministic_and_locked()
    _test_enemy_ai_plan_is_deterministic_and_hidden()
    _test_enemy_ai_uses_natural_combo()
    _test_both_sides_use_synchronized_combo()
    _test_ai_battle_reaches_terminal_state()
    _test_synchronized_defense_before_damage()
    _test_synchronized_lethal_and_battle_results()
    _test_data_driven_lethal_gu_needle()
    _test_lethal_poison_and_gu_recycle_chain()
    _test_scripted_poison_demo_reaches_recycle()
    if failures.is_empty():
        print("TEST PASS: %d assertions" % assertions)
        quit(0)
    else:
        for failure in failures:
            push_error("TEST FAIL: %s" % failure)
        print("TEST FAILURES: %d / %d assertions" % [failures.size(), assertions])
        quit(1)

func _card(rank: String, attribute: String = "wind"):
    card_serial += 1
    var order: int
    match rank:
        "J": order = 11
        "Q": order = 12
        "K": order = 13
        "A": order = 14
        _: order = int(rank)
    var qi: int = 12 if rank == "A" else (11 if rank in ["J", "Q", "K"] else int(rank))
    var attribute_name: String = {"wind": "风", "forest": "林", "fire": "火", "mountain": "山"}[attribute]
    return QiCardScript.new("test_%d" % card_serial, rank, order, qi, attribute, attribute_name)

func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append("%s：期望为 true" % label)

func _test_content_catalog_and_validator() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "统一内容目录一次性载入并通过全部校验")
    _assert_equal(catalog.errors, [], "当前十份内容数据没有校验错误")
    _assert_equal(catalog.definition("base_deck")["version"], 1, "内容数据带顶层版本")
    _assert_equal(catalog.definition("card_states")["version"], 3, "真气重塑与异状数据带顶层版本")
    _assert_equal(catalog.all_of("card").size(), 52, "内容目录建立 52 张唯一基础真气索引")
    _assert_equal(catalog.all_of("enhancement").size(), 8, "内容目录建立八种强化索引")
    _assert_equal(catalog.all_of("finish").size(), 4, "内容目录建立四种品相索引")
    _assert_equal(catalog.all_of("imprint").size(), 4, "内容目录建立四种印记索引")
    _assert_equal(catalog.all_of("anomaly").size(), 11, "内容目录建立十一种战斗异状索引")
    _assert_equal(catalog.all_of("actor_status").size(), 2, "内容目录建立蛊印与连势角色状态索引")
    _assert_equal(catalog.get_by_id("anomaly", "lethal_poison")["category"], "poison", "烈毒定义归入唯一毒槽")
    _assert_equal(
        catalog.get_by_id("anomaly", "purification")["on_apply"],
        "suppress_existing_effects",
        "净化通过内容策略声明获得时生命周期")
    _assert_equal(catalog.get_by_id("technique", "fire_sparks")["name"], "火星连点", "可按类型与 ID 查询功法")

    var changed_query: Dictionary = catalog.get_by_id("technique", "fire_sparks")
    changed_query["name"] = "外部篡改"
    _assert_equal(catalog.get_by_id("technique", "fire_sparks")["name"], "火星连点", "目录查询返回深复制")
    var changed_definition: Dictionary = catalog.definition("scripted_battle")
    changed_definition["enemy"]["opening_hand"][0] = "bad_card"
    _assert_equal(
        catalog.definition("scripted_battle")["enemy"]["opening_hand"][0],
        "fire_2",
        "整份定义查询同样保持深复制边界")

    var duplicate_values := _catalog_definitions(catalog)
    duplicate_values["techniques"]["techniques"].append(
        duplicate_values["techniques"]["techniques"][0].duplicate(true))
    var duplicate_catalog = ContentCatalogScript.new()
    _assert_true(not duplicate_catalog.load_from_definitions(duplicate_values), "重复内容 ID 被拒绝")
    _assert_true(_array_contains_text(duplicate_catalog.errors, "ID 重复：fire_sparks"), "重复 ID 错误稳定定位")

    var missing_version_values := _catalog_definitions(catalog)
    missing_version_values["consumables"].erase("version")
    var missing_version_catalog = ContentCatalogScript.new()
    _assert_true(not missing_version_catalog.load_from_definitions(missing_version_values), "缺少内容版本被拒绝")
    _assert_true(_array_contains_text(missing_version_catalog.errors, "缺少版本字段 version"), "版本错误稳定定位")

    var unknown_values := _catalog_definitions(catalog)
    unknown_values["sequences"]["pair"] = ["missing_technique"]
    var unknown_catalog = ContentCatalogScript.new()
    _assert_true(not unknown_catalog.load_from_definitions(unknown_values), "序列中的未知功法被拒绝")
    _assert_true(_array_contains_text(unknown_catalog.errors, "引用未知功法 missing_technique"), "未知功法错误稳定定位")

    var wrong_pool_values := _catalog_definitions(catalog)
    wrong_pool_values["sequences"]["pair"] = ["fire_sparks"]
    var wrong_pool_catalog = ContentCatalogScript.new()
    _assert_true(not wrong_pool_catalog.load_from_definitions(wrong_pool_values), "错误功法池资格被拒绝")
    _assert_true(_array_contains_text(wrong_pool_catalog.errors, "不属于 pair 的合格共用池"), "错误功法池错误稳定定位")

    var bad_op_values := _catalog_definitions(catalog)
    bad_op_values["techniques"]["techniques"][0]["effects"][0]["op"] = "unknown_op"
    var bad_op_catalog = ContentCatalogScript.new()
    _assert_true(not bad_op_catalog.load_from_definitions(bad_op_values), "未知效果操作码被拒绝")
    _assert_true(_array_contains_text(bad_op_catalog.errors, "未知效果操作码 unknown_op"), "操作码错误稳定定位")

    var bad_kind_values := _catalog_definitions(catalog)
    bad_kind_values["techniques"]["techniques"][0]["effects"][0]["amount"]["kind"] = "unknown_kind"
    var bad_kind_catalog = ContentCatalogScript.new()
    _assert_true(not bad_kind_catalog.load_from_definitions(bad_kind_values), "未知数值规格被拒绝")
    _assert_true(_array_contains_text(bad_kind_catalog.errors, "未知数值规格 kind unknown_kind"), "数值规格错误稳定定位")

    var nested_kind_values := _catalog_definitions(catalog)
    for technique in nested_kind_values["techniques"]["techniques"]:
        if technique["id"] == "discard_fuel_open_furnace":
            technique["effects"][2]["count"]["values"][1]["kind"] = "unknown_nested_kind"
    var nested_kind_catalog = ContentCatalogScript.new()
    _assert_true(not nested_kind_catalog.load_from_definitions(nested_kind_values), "递归 max.values 中的未知数值规格被拒绝")
    _assert_true(_array_contains_text(nested_kind_catalog.errors, "unknown_nested_kind"), "递归数值规格错误稳定定位")

    var bad_card_values := _catalog_definitions(catalog)
    bad_card_values["scripted_battle"]["enemy"]["opening_hand"][0] = "void_A"
    var bad_card_catalog = ContentCatalogScript.new()
    _assert_true(not bad_card_catalog.load_from_definitions(bad_card_values), "脚本战斗中的无效真气引用被拒绝")
    _assert_true(_array_contains_text(bad_card_catalog.errors, "引用未知真气 void_A"), "无效真气引用错误稳定定位")

    var bad_ai_policy_values := _catalog_definitions(catalog)
    bad_ai_policy_values["scripted_battle"]["enemy"]["ai"]["combo_folow_weight"] = 1.0
    var bad_ai_policy_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_ai_policy_catalog.load_from_definitions(bad_ai_policy_values),
        "敌方数据驱动策略拒绝拼写错误字段")
    _assert_true(
        _array_contains_text(bad_ai_policy_catalog.errors, "未知 AI 策略字段 combo_folow_weight"),
        "敌方策略字段错误稳定定位")

    var bad_ai_bias_values := _catalog_definitions(catalog)
    bad_ai_bias_values["scripted_battle"]["enemy"]["ai"]["next_technique_bias"] = {
        "missing_technique": 3.0,
    }
    var bad_ai_bias_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_ai_bias_catalog.load_from_definitions(bad_ai_bias_values),
        "敌方策略拒绝未知功法偏好")
    _assert_true(
        _array_contains_text(bad_ai_bias_catalog.errors, "引用未知功法 missing_technique"),
        "敌方功法偏好引用错误稳定定位")

    var bad_anomaly_lifecycle_values := _catalog_definitions(catalog)
    bad_anomaly_lifecycle_values["card_states"]["anomalies"][0]["remove_on_enter_discard"] = false
    var bad_anomaly_lifecycle_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_anomaly_lifecycle_catalog.load_from_definitions(bad_anomaly_lifecycle_values),
        "毒不能关闭进入弃牌堆清理规则")
    _assert_true(
        _array_contains_text(bad_anomaly_lifecycle_catalog.errors, "毒和状态进入弃牌堆时必须默认移除"),
        "异状生命周期错误稳定定位")

    var bad_anomaly_policy_values := _catalog_definitions(catalog)
    bad_anomaly_policy_values["card_states"]["anomalies"][-1]["on_apply"] = "unknown_policy"
    var bad_anomaly_policy_catalog = ContentCatalogScript.new()
    _assert_true(not bad_anomaly_policy_catalog.load_from_definitions(bad_anomaly_policy_values), "未知异状获得策略被拒绝")
    _assert_true(
        _array_contains_text(bad_anomaly_policy_catalog.errors, "未知异状获得策略 unknown_policy"),
        "异状获得策略错误稳定定位")

    var bad_anomaly_reference_values := _catalog_definitions(catalog)
    bad_anomaly_reference_values["techniques"]["techniques"][1]["effects"][1]["anomaly"] = "missing_anomaly"
    var bad_anomaly_reference_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_anomaly_reference_catalog.load_from_definitions(bad_anomaly_reference_values),
        "功法引用未知异状被拒绝")
    _assert_true(
        _array_contains_text(bad_anomaly_reference_catalog.errors, "引用未知真气异状 missing_anomaly"),
        "未知异状引用错误稳定定位")

    var bad_actor_status_values := _catalog_definitions(catalog)
    for technique in bad_actor_status_values["techniques"]["techniques"]:
        for effect in technique.get("effects", []):
            if effect.get("op", "") in ["add_stack", "add_target_stack", "add_stack_per_captured_card"]:
                effect["stack"] = "missing_actor_status"
                break
        if not bad_actor_status_values["techniques"]["techniques"].is_empty() \
                and _array_contains_effect_stack(technique.get("effects", []), "missing_actor_status"):
            break
    var bad_actor_status_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_actor_status_catalog.load_from_definitions(bad_actor_status_values),
        "功法引用未知角色状态被拒绝")
    _assert_true(
        _array_contains_text(bad_actor_status_catalog.errors, "引用未知角色状态 missing_actor_status"),
        "未知角色状态引用错误稳定定位")

    var battle_start_reshape_values := _catalog_definitions(catalog)
    battle_start_reshape_values["card_states"]["other_reshapes"] = [{
        "id": "test_poison_seed",
        "name": "测试跨战斗毒种",
        "battle_start_anomalies": [{"category": "poison", "anomaly": "lethal_poison"}],
    }]
    var battle_start_reshape_catalog = ContentCatalogScript.new()
    _assert_true(
        battle_start_reshape_catalog.load_from_definitions(battle_start_reshape_values),
        "重塑其他可以数据声明战斗开始异状")
    var battle_start_card = _card("5", "forest")
    battle_start_card.set_other_reshape("test_poison_seed")
    var battle_start_results: Array[Dictionary] = CardStateLifecycleScript.new(
        battle_start_reshape_catalog).on_battle_start(battle_start_card)
    _assert_true(battle_start_results[0]["success"], "战斗开始生命周期执行重塑声明")
    _assert_true(
        battle_start_card.has_anomaly("poison", "lethal_poison"),
        "跨战斗重塑在新战斗生成毒而不是保存毒对象")

    var bad_battle_start_values := _catalog_definitions(catalog)
    bad_battle_start_values["card_states"]["other_reshapes"] = [{
        "id": "bad_poison_seed",
        "name": "错误毒种",
        "battle_start_anomalies": [{"category": "state", "anomaly": "lethal_poison"}],
    }]
    var bad_battle_start_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_battle_start_catalog.load_from_definitions(bad_battle_start_values),
        "重塑战斗开始异状拒绝错误类别")
    _assert_true(
        _array_contains_text(bad_battle_start_catalog.errors, "lethal_poison 不属于类别 state"),
        "重塑战斗开始异状错误稳定定位")

    var bad_enhancement_reference_values := _catalog_definitions(catalog)
    bad_enhancement_reference_values["consumables"]["consumables"][1]["effects"][0]["enhancement"] = "missing_enhancement"
    var bad_enhancement_reference_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_enhancement_reference_catalog.load_from_definitions(bad_enhancement_reference_values),
        "消耗品引用未知强化被拒绝")
    _assert_true(
        _array_contains_text(bad_enhancement_reference_catalog.errors, "引用未知强化 missing_enhancement"),
        "未知强化引用错误稳定定位")

    var engine = CombatEngineScript.new(null, catalog)
    var run_session = RunSessionScript.new(null, null, null, null, catalog)
    _assert_true(engine.content_catalog == catalog, "战斗核心使用注入的统一目录实例")
    _assert_true(run_session.execute({"type": "setup_run", "seed": 17})["success"], "本局流程从同一目录装配地图与节点内容")
    var battle_session = run_session.create_battle_session()
    _assert_true(battle_session.engine.content_catalog == catalog, "本局创建的战斗会话继续共享同一目录实例")

func _catalog_definitions(catalog) -> Dictionary:
    var result: Dictionary = {}
    for key in ContentCatalogScript.CONTENT_ORDER:
        result[key] = catalog.definition(key)
    return result

func _array_contains_text(values: Array, wanted: String) -> bool:
    for value in values:
        if str(value).contains(wanted):
            return true
    return false

func _array_contains_effect_stack(effects: Array, wanted: String) -> bool:
    for effect in effects:
        if effect is Dictionary and str(effect.get("stack", "")) == wanted:
            return true
    return false

func _test_qi_instance_state_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "真气实例契约测试载入统一目录")
    var id_factory = CardInstanceIdFactoryScript.new("run-815")
    var first_id: String = id_factory.next_id("wind_7")
    var second_id: String = id_factory.next_id("wind_7")
    _assert_equal(first_id, "run-815:000001:wind_7", "实例ID包含本局命名空间、序号和定义ID")
    _assert_equal(second_id, "run-815:000002:wind_7", "同一定义的复制真气获得不同实例ID")
    _assert_equal(id_factory.next_serial(), 3, "实例ID工厂稳定推进序号")

    var card = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_7"),
        first_id)
    _assert_equal(card.id, first_id, "真气运行时ID使用唯一实例ID")
    _assert_equal(card.definition_id, "wind_7", "真气实例保留基础定义ID")
    card.set_enhancement("bonus")
    card.set_finish("foil")
    card.set_imprint("red")
    _assert_true(card.set_anomaly("poison", "stagnant_poison"), "可以建立毒异状")
    _assert_true(card.set_anomaly("poison", "lethal_poison"), "新毒替换唯一毒槽中的旧毒")
    _assert_equal(card.anomaly_poison, "lethal_poison", "唯一毒槽只保留新毒")
    _assert_true(card.set_anomaly("state", "vulnerability"), "毒与状态可以共存")
    _assert_true(card.set_anomaly("state", "acupoint_block"), "新状态替换唯一状态槽中的旧状态")
    _assert_equal(card.anomaly_state, "acupoint_block", "唯一状态槽只保留新状态")
    _assert_true(card.set_anomaly("mark", "wind_lure"), "可以建立风引标记")
    _assert_true(card.set_anomaly("mark", "qi_severance"), "不同标记可以同时存在")
    _assert_true(card.set_anomaly("other", "temporary_a", {"amount": 1}), "可以建立异状其他")
    _assert_true(card.set_anomaly("other", "temporary_b", {"amount": 2}), "多个异状其他可以共存")
    card.remove_anomaly("other")

    var run_data: Dictionary = QiCardInstanceDataScript.capture(card)
    _assert_true(not run_data.has("anomalies"), "本局实例DTO默认不保存战斗异状")
    _assert_equal(run_data["reshapes"]["finish"], "foil", "本局实例DTO保存品相重塑")
    _assert_equal(
        QiCardInstanceDataScript.validate(run_data, catalog),
        [],
        "本局实例DTO通过内容引用校验")
    var battle_data: Dictionary = QiCardInstanceDataScript.capture(card, true)
    _assert_equal(
        QiCardInstanceDataScript.validate(battle_data, catalog, true),
        [],
        "包含战斗状态的实例DTO通过内容引用校验")
    var restored = QiCardInstanceDataScript.restore(battle_data)
    _assert_equal(restored.id, first_id, "版本化DTO恢复唯一实例ID")
    _assert_equal(restored.definition_id, "wind_7", "版本化DTO恢复基础定义ID")
    _assert_equal(restored.reshape_imprint, "red", "版本化DTO恢复印记")
    _assert_equal(restored.anomaly_poison, "lethal_poison", "版本化DTO恢复毒异状")
    _assert_true(restored.has_anomaly("mark", "wind_lure"), "版本化DTO恢复多个标记")
    restored.set_anomaly("other", "temporary_a", {"amount": 1})

    var lifecycle = CardStateLifecycleScript.new(catalog)
    var removed: Dictionary = lifecycle.on_enter_discard(restored)
    _assert_equal(removed["poison"], "lethal_poison", "实际进入弃牌堆默认移除毒")
    _assert_equal(removed["state"], "acupoint_block", "实际进入弃牌堆默认移除状态")
    _assert_true(not restored.has_anomaly("poison"), "弃牌清理后没有残留毒")
    _assert_true(not restored.has_anomaly("state"), "弃牌清理后没有残留状态")
    _assert_true(restored.has_anomaly("mark", "wind_lure"), "标记不由通用弃牌规则清除")
    _assert_true(restored.has_anomaly("mark", "qi_severance"), "绝气标记保留到自己的生命周期")
    _assert_true(restored.has_anomaly("other", "temporary_a"), "异状其他只按自身生命周期处理")
    lifecycle.on_battle_end(restored)
    _assert_true(restored.anomaly_snapshot()["marks"].is_empty(), "战斗结束清理全部标记")
    _assert_true(restored.anomaly_snapshot()["others"].is_empty(), "战斗结束清理异状其他")

    var discard_side = BattleSideScript.new("弃牌生命周期")
    discard_side.use_card_state_lifecycle(lifecycle)
    var explicitly_discarded = _card("6", "forest")
    explicitly_discarded.set_anomaly("poison", "lethal_poison")
    explicitly_discarded.set_anomaly("state", "vulnerability")
    explicitly_discarded.set_anomaly("mark", "wind_lure")
    discard_side.hand = [explicitly_discarded]
    discard_side.discard_all()
    _assert_true(not explicitly_discarded.has_anomaly("poison"), "真实明确弃牌入口移除毒")
    _assert_true(not explicitly_discarded.has_anomaly("state"), "真实明确弃牌入口移除状态")
    _assert_true(explicitly_discarded.has_anomaly("mark", "wind_lure"), "真实明确弃牌入口保留未触发标记")

    var purified = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "fire_9"),
        id_factory.next_id("fire_9"))
    purified.set_enhancement("bonus")
    purified.set_finish("foil")
    purified.set_imprint("gold")
    purified.set_other_reshape("battle_curse", {"poison": "lethal_poison"})
    purified.set_other_reshape("scar", {"stacks": 1})
    purified.set_anomaly("poison", "lethal_poison")
    purified.set_anomaly("state", "acupoint_block")
    purified.set_anomaly("mark", "wind_lure")
    purified.set_anomaly("mark", "qi_severance")
    purified.set_anomaly("other", "temporary_a", {"qi_delta": 4})
    var purification_result: Dictionary = lifecycle.apply_anomaly(
        purified, "mark", "purification")
    _assert_true(purification_result["success"], "可以通过统一生命周期施加净化")
    _assert_equal(purified.reshape_enhancement, "", "净化令已有强化失效")
    _assert_equal(purified.reshape_finish, "", "净化令已有品相失效")
    _assert_equal(purified.reshape_imprint, "", "净化令已有印记失效")
    _assert_true(purified.reshape_others.is_empty(), "净化令已有重塑其他失效")
    _assert_equal(purified.anomaly_poison, "", "净化清除已有毒")
    _assert_equal(purified.anomaly_state, "", "净化清除已有状态")
    _assert_equal(purified.anomaly_marks.keys(), ["purification"], "净化清除风标与绝气标记后建立自身")
    _assert_true(purified.anomaly_others.is_empty(), "净化清除已有异状其他")

    var purified_run_data: Dictionary = QiCardInstanceDataScript.capture(purified)
    _assert_equal(purified_run_data["reshapes"]["enhancement"], "bonus", "净化期间本局DTO仍保存暂存强化")
    _assert_equal(purified_run_data["reshapes"]["others"]["battle_curse"]["poison"], "lethal_poison", "净化期间本局DTO仍保存暂存重塑其他")
    var purified_battle_data: Dictionary = QiCardInstanceDataScript.capture(purified, true)
    _assert_equal(purified_battle_data["reshapes"]["enhancement"], "", "战斗DTO保留净化期间的实际失效状态")
    _assert_true(purified_battle_data["suppressed_reshapes"].has("enhancement"), "战斗DTO记录待恢复重塑")

    purified.set_enhancement("multiplier")
    purified.set_anomaly("poison", "stagnant_poison")
    purified.set_anomaly("state", "qi_dissipation")
    purified.set_anomaly("mark", "returning_wind")
    purified.set_anomaly("other", "temporary_b", {"qi_delta": 2})
    var refreshed: Dictionary = lifecycle.apply_anomaly(
        purified, "mark", "purification")
    _assert_true(refreshed["refreshed"], "重复获得净化只刷新而不清除后来内容")
    _assert_equal(purified.reshape_enhancement, "multiplier", "净化后新强化正常生效")
    _assert_true(purified.has_anomaly("poison", "stagnant_poison"), "净化后新毒正常生效")
    _assert_true(purified.has_anomaly("state", "qi_dissipation"), "净化后新状态正常生效")
    _assert_true(purified.has_anomaly("mark", "returning_wind"), "净化后新标记正常生效")
    _assert_true(purified.has_anomaly("other", "temporary_b"), "净化后新异状其他正常生效")

    var restored_after_purification: Dictionary = lifecycle.on_battle_end(purified)
    _assert_equal(purified.reshape_enhancement, "multiplier", "后来强化替换净化前强化")
    _assert_equal(purified.reshape_finish, "foil", "战斗结束恢复净化前品相")
    _assert_equal(purified.reshape_imprint, "gold", "战斗结束恢复净化前印记")
    _assert_true(purified.reshape_others.has("battle_curse"), "战斗结束恢复未被替换的重塑其他")
    _assert_true(purified.reshape_others.has("scar"), "多个重塑其他分别恢复")
    _assert_true(purified.anomaly_snapshot()["marks"].is_empty(), "战斗结束移除净化与后来标记")
    _assert_equal(purified.anomaly_poison, "", "净化后新毒不跨战斗")
    _assert_equal(purified.anomaly_state, "", "净化后新状态不跨战斗")
    _assert_true(purified.anomaly_others.is_empty(), "净化后新异状其他不跨战斗")
    _assert_equal(restored_after_purification["finish"], "foil", "生命周期返回实际恢复品相用于日志或回放")

    var handler_card = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "mountain_6"),
        id_factory.next_id("mountain_6"))
    handler_card.set_enhancement("glass")
    handler_card.set_anomaly("poison", "lethal_poison")
    var handler_target = BattleSideScript.new("净化目标")
    handler_target.hand = [handler_card]
    var handler_rng := RandomNumberGenerator.new()
    handler_rng.seed = 815
    var handler_executor = EffectExecutorScript.new(handler_rng, null, catalog)
    var handler_result: Dictionary = handler_executor.execute_all([{
        "op": "apply_random_card_anomaly",
        "zone": "hand",
        "category": "mark",
        "anomaly": "purification",
        "count": 1,
    }], {"target": handler_target, "captures": {}})
    _assert_true(handler_result["success"], "数据驱动效果处理器通过统一生命周期施加净化")
    _assert_equal(handler_card.reshape_enhancement, "", "效果处理器施加净化后强化立即失效")
    _assert_true(handler_card.has_anomaly("mark", "purification"), "效果处理器保留净化标记")

    var invalid_data: Dictionary = run_data.duplicate(true)
    invalid_data["reshapes"]["enhancement"] = "missing_enhancement"
    _assert_true(
        _array_contains_text(
            QiCardInstanceDataScript.validate(invalid_data, catalog),
            "missing_enhancement"),
        "实例DTO拒绝未知内容引用")

func _test_remote_ai_module_contract() -> void:
    var context = AiBattleContextScript.new().configure({
        "battle_id": "battle-ai-contract",
        "rules_version": "v0.28",
        "player_build": {
            "deck": ["wind_2", "forest_3"],
            "techniques": ["fire_sparks"],
        },
        "enemy_build": {"archetype": "mock_enemy"},
        "visibility": {"opponent_hand": false, "opponent_draw_order": false},
        "protocol": {
            "history_compression_rounds": 5,
            "credentials": {"api_key": "must-not-be-persisted"},
        },
    })
    _assert_true(context.is_valid(), "远程 AI 战斗上下文包含战斗 ID 与规则版本")

    var observation = AiDecisionObservationScript.new().configure({
        "decision_id": "decision-1",
        "window_id": "combo-window-1",
        "state_hash": "state-hash-1",
        "round_number": 1,
        "action_index": 2,
        "self_state": {"hand_cards": ["enemy:fire_2"], "life": 80},
        "opponent_public_state": {
            "life": 91,
            "defense": 7,
            "hand_count": 6,
            "draw_pile_count": 37,
            "hand_cards": ["player:wind_2"],
            "draw_order": ["player:forest_3"],
            "selected_card_ids": ["player:fire_4"],
            "rng_seed": 2308,
            "nested": {
                "public_status": "purification",
                "hand": ["player:hidden-nested"],
            },
        },
    })
    var observed_opponent: Dictionary = observation.snapshot()["opponent"]
    _assert_true(observation.is_valid(), "远程 AI 决策观察包含窗口状态凭据")
    _assert_equal(observed_opponent.get("life"), 91, "远程 AI 保留玩家公开生命")
    _assert_equal(observed_opponent.get("hand_count"), 6, "远程 AI 保留玩家公开手牌数量")
    _assert_true(not observed_opponent.has("hand_cards"), "远程 AI 观察移除玩家隐藏手牌身份")
    _assert_true(not observed_opponent.has("draw_order"), "远程 AI 观察移除玩家抽牌顺序")
    _assert_true(not observed_opponent.has("selected_card_ids"), "远程 AI 观察移除玩家选牌草稿")
    _assert_true(not observed_opponent.has("rng_seed"), "远程 AI 观察移除随机种子")
    _assert_equal(observed_opponent["nested"].get("public_status"), "purification", "递归脱敏保留嵌套公开状态")
    _assert_true(not observed_opponent["nested"].has("hand"), "递归脱敏移除嵌套隐藏手牌")

    var projector = AiHistoryProjectorScript.new()
    var projected_events: Array = projector.project_many([
        {
            "sequence": 10,
            "round_number": 1,
            "action_index": 1,
            "window_id": "player-only-combo",
            "event_type": "action_window_opened",
            "actor_id": "player",
            "visibility": "public",
            "payload": {"enemy_can_act": false},
        },
        {
            "sequence": 11,
            "round_number": 1,
            "action_index": 1,
            "window_id": "player-only-combo",
            "event_type": "cards_played",
            "actor_id": "player",
            "visibility": "hidden_random_target",
            "payload": {
                "hand_type": "high_card",
                "played_card_ids": ["player:wind_2"],
                "context": {
                    "target_card_ids": ["enemy:hidden-1", "enemy:hidden-2"],
                },
            },
        },
        {
            "sequence": 12,
            "round_number": 1,
            "event_type": "private_draw_order",
            "actor_id": "player",
            "visibility": "private",
            "payload": {"drawn_card_ids": ["player:forest_3"]},
        },
    ])
    _assert_equal(projected_events.size(), 2, "私有事件完全不进入远程 AI 历史")
    _assert_equal(projected_events[1]["payload"].get("hidden_target_count"), 2, "隐藏随机目标只公开命中数量")
    _assert_true(not projected_events[1]["payload"]["context"].has("target_card_ids"), "嵌套隐藏随机目标不公开真气身份")

    var conversation = AiBattleConversationScript.new().configure(context, {
        "compression_enabled": true,
        "compression_interval_rounds": 5,
        "max_retries": 1,
    })
    for event in projected_events:
        conversation.record_public_event(event)
    _assert_equal(conversation.exchanges.size(), 0, "敌方无行动机会时只积压历史且不建立接口请求")
    _assert_true(not conversation.complete_round(4), "默认第 4 个完整回合不压缩工作历史")

    var proposal = BattleActionProposalScript.new().configure_accept(
        "remote_ai",
        ["enemy:fire_2", "enemy:fire_3"],
        {"hand": {"id": "pair"}, "damage": 12})
    var candidate = AiCandidateScript.new().configure({
        "candidate_id": "candidate-pair-with-synergy",
        "groups": [
            {"group_index": 0, "kind": "main", "card_ids": ["enemy:fire_2", "enemy:fire_3"]},
            {"group_index": 1, "kind": "synergy", "card_ids": ["enemy:wind_4"]},
        ],
        "summary": {"damage_min": 10, "damage_max": 14, "defense": 0},
        "tags": ["pair", "synergy"],
    }, proposal)
    _assert_true(candidate.is_valid(), "远程 AI 合法候选有效")
    _assert_equal(candidate.public_snapshot()["groups"].size(), 2, "候选同时承载主组与协同组")

    var provider = MockAiProviderScript.new(true)
    provider.queue_result({
        "success": true,
        "body": {
            "schema_version": 1,
            "decision_id": "decision-1",
            "state_hash": "state-hash-1",
            "candidate_id": "not-a-local-candidate",
        },
    })
    provider.queue_result({
        "success": true,
        "body": {
            "schema_version": 1,
            "decision_id": "decision-1",
            "state_hash": "state-hash-1",
            "candidate_id": "candidate-pair-with-synergy",
            "reason_code": "preserve_future_options",
            "confidence": 0.75,
        },
    })
    var gateway = AiDecisionGatewayScript.new(provider)
    var retry_count := [0]
    var ready_proposals: Array = []
    var ready_metadata: Array = []
    gateway.decision_retry.connect(func(_decision_id, _retry_index, _error):
        retry_count[0] = int(retry_count[0]) + 1)
    gateway.decision_ready.connect(func(_decision_id, ready_proposal, metadata):
        ready_proposals.append(ready_proposal)
        ready_metadata.append(metadata))
    var begin_result: Dictionary = gateway.begin_decision(conversation, observation, [candidate])
    _assert_true(begin_result.get("success", false), "远程 AI Gateway 接受异步决策任务")
    _assert_equal(provider.submitted_requests.size(), 2, "非法候选触发一次结构化纠错重试")
    _assert_equal(retry_count[0], 1, "Gateway 发出一次纠错重试事件")
    _assert_equal(ready_proposals.size(), 1, "合法回答只产生一个最终行动提案")
    _assert_true(ready_proposals[0] == proposal, "远程回答绑定本地 BattleActionProposal 而非直接动作")
    _assert_equal(ready_metadata[0].get("candidate_id"), candidate.candidate_id, "最终提案记录已验证候选 ID")
    var first_request: Dictionary = provider.submitted_requests[0]["payload"]
    var retry_request: Dictionary = provider.submitted_requests[1]["payload"]
    _assert_equal(first_request["history_delta"].size(), 2, "下次敌方出手收到此前无行动窗口的全部公开历史")
    _assert_equal(first_request["history_delta"][0]["window_id"], "player-only-combo", "单方连击窗口按原窗口 ID 上报")
    _assert_true(retry_request.has("correction"), "重试请求携带机器可读纠错信息")
    _assert_equal(retry_request["correction"].get("error_code"), "INVALID_CANDIDATE", "纠错明确指出非法候选")

    _assert_true(conversation.complete_round(5), "默认第 5 个完整回合压缩工作历史")
    _assert_equal(conversation.provider_epoch, 1, "压缩后推进 Provider 会话分段")
    _assert_equal(conversation.public_events.size(), 2, "压缩不删除本地完整公开事件")
    _assert_equal(conversation.work_summary.get("event_count"), 2, "工作摘要覆盖已积压事件")

    var next_observation = AiDecisionObservationScript.new().configure({
        "decision_id": "decision-2",
        "window_id": "round-6-main",
        "state_hash": "state-hash-2",
        "round_number": 6,
        "action_index": 0,
        "self_state": {"life": 80},
        "opponent_public_state": {"life": 91},
    })
    provider.queue_result({
        "success": true,
        "body": {
            "schema_version": 1,
            "decision_id": "decision-2",
            "state_hash": "state-hash-2",
            "candidate_id": "candidate-pair-with-synergy",
        },
    })
    gateway.begin_decision(conversation, next_observation, [candidate])
    var next_request: Dictionary = provider.submitted_requests[2]["payload"]
    _assert_equal(next_request.get("provider_epoch"), 1, "压缩后的下一次请求使用新 Provider epoch")
    _assert_true(next_request.has("battle_context"), "新 Provider epoch 重新发送战斗上下文")
    _assert_equal(next_request["history_delta"], [], "已压缩且已发送事件不在增量中重复发送")

    var store = AiConversationStoreScript.new()
    var encoded: String = store.encode(conversation.snapshot())
    var decoded: Dictionary = store.decode(encoded)
    _assert_equal(
        decoded["context_snapshot"]["protocol"]["credentials"]["api_key"],
        "[REDACTED]",
        "AI 会话持久化递归脱敏 API Key")
    var restored = AiBattleConversationScript.new().restore(decoded)
    _assert_equal(restored.battle_id, conversation.battle_id, "AI 会话快照恢复战斗 ID")
    _assert_equal(restored.public_events.size(), conversation.public_events.size(), "AI 会话快照恢复完整公开事件数量")
    _assert_equal(restored.public_events[1]["window_id"], "player-only-combo", "AI 会话快照恢复事件窗口")
    _assert_equal(int(restored.public_events[1]["sequence"]), 11, "AI 会话快照恢复事件序号")
    _assert_equal(restored.exchanges.size(), conversation.exchanges.size(), "AI 会话快照恢复请求回答审计链")

func _test_effect_handler_registry_contract() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 814
    var executor = EffectExecutorScript.new(rng)
    var expected_ops: Array[String] = []
    for operation_id in ContentValidatorScript.BATTLE_EFFECT_OPS:
        expected_ops.append(str(operation_id))
    expected_ops.sort()
    _assert_equal(executor.registry.operation_ids(), expected_ops, "运行时注册表与内容校验器使用相同的 14 个战斗操作码")
    _assert_equal(executor.registry.handler_group("damage"), "damage", "伤害操作进入伤害处理器")
    _assert_equal(executor.registry.handler_group("defense"), "defense", "防御操作进入防御处理器")
    _assert_equal(executor.registry.handler_group("draw"), "card_zone", "抽牌操作进入牌区处理器")
    _assert_equal(executor.registry.handler_group("apply_random_card_anomaly"), "card_anomaly", "真气异状进入异状处理器")
    _assert_equal(executor.registry.handler_group("add_target_stack"), "stack", "层数操作进入层数处理器")
    _assert_equal(executor.registry.handler_group("register_attack_counter_delay"), "flow_delay", "延迟记录进入流程处理器")

    var unknown_result: Dictionary = executor.execute_all([{"op": "not_registered"}], {})
    _assert_true(not unknown_result["success"], "未注册操作码在执行边界被安全拒绝")
    _assert_true(str(unknown_result["detail"]).contains("未注册"), "未知操作码返回明确诊断")

    var probe_handler := ProbeEffectHandler.new()
    _assert_true(executor.registry.register_handler(probe_handler), "新处理器可通过注册接口扩展")
    _assert_true(not executor.registry.register_handler(ProbeEffectHandler.new()), "重复操作码默认不能覆盖现有处理器")
    var probe_context := {}
    var probe_result: Dictionary = executor.execute_all([{"op": "probe_effect"}], probe_context)
    _assert_true(probe_result["success"], "动态注册处理器可以参与统一执行链")
    _assert_equal(probe_context["probe_count"], 1, "动态处理器只执行一次")
    _assert_equal(
        executor.summarize_intent([{"op": "probe_effect"}], {})["defense"],
        7,
        "动态处理器同时接入预览汇总链")

func _test_card_zone_service_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "牌区服务契约测试载入统一内容目录")
    var lifecycle = CardStateLifecycleScript.new(catalog)
    var side = BattleSideScript.new("牌区测试方")
    side.use_card_state_lifecycle(lifecycle)
    var rng := RandomNumberGenerator.new()
    rng.seed = 816
    var cards := [
        DeckFactoryScript.create_card_instance(catalog.get_by_id("card", "wind_2"), "zone:wind_2"),
        DeckFactoryScript.create_card_instance(catalog.get_by_id("card", "forest_3"), "zone:forest_3"),
        DeckFactoryScript.create_card_instance(catalog.get_by_id("card", "fire_4"), "zone:fire_4"),
        DeckFactoryScript.create_card_instance(catalog.get_by_id("card", "mountain_5"), "zone:mountain_5"),
    ]
    side.reset(cards, rng, false)
    _assert_equal(side.draw(2).size(), 2, "统一牌区服务执行抽牌")
    var staged_id := str(side.hand[0].id)
    _assert_true(side.stage_cards([staged_id]), "统一牌区服务把手牌移入待出区")
    _assert_equal(side.rollback_staging().size(), 1, "待出失败通过统一牌区服务回滚")
    var discard_target = side.find_hand_card(staged_id)
    discard_target.set_anomaly("poison", "lethal_poison")
    discard_target.set_anomaly("state", "qi_dissipation")
    discard_target.set_anomaly("mark", "wind_lure")
    _assert_true(side.stage_cards([staged_id]), "回滚后的真气可以再次进入待出区")
    side.commit_staging()
    _assert_true(not discard_target.has_anomaly("poison"), "实际进入弃牌堆时统一移除毒")
    _assert_true(not discard_target.has_anomaly("state"), "实际进入弃牌堆时统一移除状态")
    _assert_true(discard_target.has_anomaly("mark", "wind_lure"), "进入弃牌堆不会擅自移除有自身生命周期的标记")
    _assert_equal(side.recover_from_discard(1, "hand")[0], discard_target, "回收通过统一牌区服务离开弃牌堆")
    _assert_true(not discard_target.has_anomaly("poison"), "离开弃牌堆不会恢复已经清除的毒")

    discard_target.set_anomaly("poison", "lethal_poison")
    _assert_true(side.stage_cards([staged_id]), "蛊印回库测试牌进入待出区")
    var recycle_result: Dictionary = side.commit_staging_with_recycles({
        staged_id: {"category": "poison", "anomaly": "lethal_poison"},
    }, rng)
    _assert_equal(recycle_result["recycled"], [discard_target], "蛊印续毒从待出区直接洗回牌库")
    _assert_true(discard_target.has_anomaly("poison", "lethal_poison"), "未实际进入弃牌堆的回库牌保持续毒")

    var temporary_target = side.draw_pile[0]
    temporary_target.set_finish("foil")
    var temp_remove: Dictionary = side.temporarily_remove_card(str(temporary_target.id), "burn")
    _assert_true(temp_remove["success"], "燃尽使用统一临时移出接口")
    _assert_equal(temp_remove["to"], "temporarily_removed", "临时移出进入独立牌区而不是弃牌堆")
    _assert_true(side.all_cards_for_run_sync().has(temporary_target), "临时移出的本局牌仍参与重塑同步")
    _assert_true(not side.permanently_removed_card_ids.has(str(temporary_target.id)), "燃尽不会误登记为永久删除")

    var permanent_target = side.draw_pile[0]
    var permanent_remove: Dictionary = side.permanently_remove_card(str(permanent_target.id), "glass_break")
    _assert_true(permanent_remove["success"], "永久损毁使用统一永久移出接口")
    _assert_true(side.permanently_removed_card_ids.has(str(permanent_target.id)), "永久移出登记到 RunDeck 同步边界")

    var generated = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "fire_6"),
        "generated:fire_6")
    _assert_true(side.add_generated_card(generated, "hand", true)["success"], "统一牌区服务可以生成战斗临时真气")
    _assert_true(generated.temporary_card, "战斗临时生成牌带明确生命周期标志")

    var receiver = BattleSideScript.new("夺取测试方", "zone-opponent")
    receiver.use_card_state_lifecycle(lifecycle)
    var transfer_target = side.draw_pile[0]
    var transfer_id := str(transfer_target.id)
    var transfer: Dictionary = side.temporarily_transfer_card_to(
        receiver, transfer_id, "hand")
    _assert_true(transfer["success"], "临时夺取通过统一跨阵营移动接口")
    _assert_equal(transfer_target.original_owner_id, side.owner_id, "临时夺取记录原持有者而不改写本局归属")
    _assert_equal(receiver.find_hand_card(transfer_id), transfer_target, "夺取真气进入目标方指定牌区")
    var returned: Dictionary = receiver.return_transferred_card_to(
        side, transfer_id, "draw_pile")
    _assert_true(returned["success"], "临时夺取真气可以通过统一接口归还")
    _assert_equal(transfer_target.original_owner_id, "", "归还后清除临时原持有者标记")
    _assert_true(side.draw_pile.has(transfer_target), "归还真气回到原持有者指定牌区")
    _assert_true(side.permanently_remove_card(str(generated.id))["success"], "战斗临时牌可以从当前战斗彻底移除")
    _assert_true(not side.permanently_removed_card_ids.has(str(generated.id)), "移除战斗临时牌不会登记为本局永久删除")

func _test_battle_flow_coordinator_contract() -> void:
    var left = BattleSideScript.new("左方", "left")
    var right = BattleSideScript.new("右方", "right")
    var flow = BattleFlowCoordinatorScript.new()
    flow.reset([left, right])
    flow.begin_round([
        {"actor": left, "actions": 1},
        {"actor": right, "actions": 1},
    ])
    _assert_true(flow.can_act(left) and flow.can_act(right), "通用行动状态不区分玩家与敌人")
    _assert_true(flow.lock_intent(left, {"cards": ["left-card"]}), "任意行动方都可以锁定行动意图")
    _assert_equal(flow.resolution_mode(), "single", "只有一方有意图时使用单方结算")
    _assert_true(flow.lock_intent(right, {"cards": ["right-card"]}), "第二个行动方可以独立锁定意图")
    _assert_equal(flow.resolution_mode(), "synchronized", "至少两方都有意图时才使用同步结算")
    flow.clear_intents()
    _assert_equal(flow.resolution_mode(), "none", "行动窗口结束后清除全部锁定意图")
    _assert_true(flow.claim_combo(left, "natural_attribute"), "通用行动状态首次占用连击成功")
    _assert_true(not flow.claim_combo(left, "natural_attribute"), "同一行动方同类连击不能重复占用")

    flow.disable_next_rounds(right, "封招", 1)
    flow.begin_round([
        {"actor": left, "actions": 1},
        {"actor": right, "actions": 1},
    ])
    _assert_true(flow.can_act(left), "一方被禁用不会阻止另一方行动")
    _assert_true(not flow.can_act(right), "下回合禁用在下一行动轮生效")
    _assert_equal(flow.available_action_count(right), 0, "被禁用方对外显示零次可用行动")
    _assert_equal(flow.snapshot_for(right)["disabled_reasons"], ["封招"], "行动状态快照公开禁用原因")
    flow.grant_actions(right, 1)
    _assert_equal(flow.available_action_count(right), 0, "禁用期间获得行动次数也不能绕过行动资格")
    flow.enable_current_round(right, "封招")
    _assert_equal(flow.available_action_count(right), 2, "移除禁用后恢复尚未消耗的行动次数")
    flow.forfeit_remaining(right, "手牌数为 0")
    _assert_true(not flow.can_act(right), "无合法手牌可以通用地放弃剩余行动")
    _assert_equal(flow.snapshot_for(right)["last_forfeit_reason"], "手牌数为 0", "放弃行动保留结构化原因")

    flow.begin_round([
        {"actor": left, "actions": 1},
        {"actor": right, "actions": 1},
    ])
    _assert_true(flow.can_act(right), "一次性下回合禁用不会污染后续行动轮")

    var enemy_disabled = CombatEngineScript.new()
    _assert_true(enemy_disabled.setup_scripted_battle(2308), "敌方禁用集成测试载入脚本战斗")
    enemy_disabled.disable_actor_next_rounds(enemy_disabled.enemy, "封招", 1)
    enemy_disabled.start_player_turn()
    _assert_equal(enemy_disabled.enemy_actions_available, 0, "敌方下回合无法操作时不建立同步行动")
    var enemy_hand_before: int = enemy_disabled.enemy.hand.size()
    var player_result: Dictionary = enemy_disabled.confirm_play([enemy_disabled.player.hand[0].id])
    _assert_true(player_result["success"], "敌方被禁用时玩家仍能单方出招")
    _assert_true(player_result["enemy_played_cards"].is_empty(), "单方出招不会强制敌方陪同出牌")
    _assert_equal(enemy_disabled.enemy.hand.size(), enemy_hand_before, "被禁用敌方的手牌没有被消耗")

    var player_disabled = CombatEngineScript.new()
    _assert_true(player_disabled.setup_scripted_battle(2308), "玩家禁用集成测试载入脚本战斗")
    player_disabled.disable_actor_next_rounds(player_disabled.player, "封招", 1)
    player_disabled.start_player_turn()
    _assert_equal(player_disabled.actions_available, 0, "玩家下回合无法操作时对外显示零次行动")
    _assert_true(not player_disabled.last_enemy_action_cards.is_empty(), "玩家被禁用时敌方能够完成单方行动")

    var empty_enemy = CombatEngineScript.new()
    _assert_true(empty_enemy.setup_scripted_battle(
        2308, "res://data/scripted_battle.json", true), "零手牌集成测试载入调试 AI")
    empty_enemy.enemy.draw_pile.clear()
    empty_enemy.enemy.hand.clear()
    empty_enemy.start_player_turn()
    _assert_equal(empty_enemy.enemy_actions_available, 0, "敌方补牌后仍为零手牌时放弃剩余行动")
    _assert_equal(
        empty_enemy.actor_action_state(empty_enemy.enemy)["last_forfeit_reason"],
        "没有合法出牌方案",
        "零手牌通过通用行动资格记录原因而不是进入同步分支")

func _test_battle_timing_system_contract_and_integration() -> void:
    var game_log = GameLogScript.new()
    var queue = TriggerQueueScript.new(game_log)
    var timing = BattleTimingSystemScript.new(queue)
    var probe = TimingProbe.new()
    _assert_true(
        timing.register_handler(
            BattleTimingSystemScript.TURN_START,
            "right",
            200,
            Callable(probe, "record").bind("右"),
            true,
            "右侧时点探针",
            "测试"),
        "战斗时点可以注册处理器")
    _assert_true(
        timing.register_handler(
            BattleTimingSystemScript.TURN_START,
            "left",
            100,
            Callable(probe, "record").bind("左")),
        "同一战斗时点可以注册第二个处理器")
    _assert_true(
        not timing.register_handler(
            BattleTimingSystemScript.TURN_START,
            "left",
            300,
            Callable(probe, "record").bind("重复")),
        "同一时点拒绝重复处理器 ID")
    _assert_true(
        not timing.register_handler(
            "unknown_timing",
            "unknown",
            1,
            Callable(probe, "record").bind("未知")),
        "战斗时点拒绝未知生命周期名称")
    var timing_result: Dictionary = timing.emit_timing(
        BattleTimingSystemScript.TURN_START,
        {"round_number": 3, "metadata": {"test": true}})
    _assert_true(timing_result["success"], "战斗时点按已注册处理器完成分发")
    _assert_equal(probe.calls, ["turn_start:左:0", "turn_start:右:0"], "同一时点按 order 再按注册顺序稳定执行")
    _assert_equal(timing.history[0]["round_number"], 3, "时点历史保留结构化回合号")
    _assert_equal(timing.history[0]["metadata"], {"test": true}, "时点历史只公开显式元数据")
    _assert_equal(timing.history[0]["handler_results"][0]["handler_id"], "left", "时点历史记录实际处理器顺序")
    _assert_equal(queue.history[-1]["label"], "右侧时点探针", "标记为可见的时点处理器进入统一战斗日志")
    _assert_true(timing.unregister_handler(BattleTimingSystemScript.TURN_START, "left"), "战斗时点处理器可以按 ID 注销")
    _assert_true(not timing.emit_timing("bad")["success"], "分发未知战斗时点返回明确失败")

    var engine = CombatEngineScript.new()
    engine.setup(815, false)
    engine.start_player_turn()
    var opening_timings: Array = engine.timing_system.history.map(
        func(entry): return entry["timing"])
    _assert_equal(opening_timings, [
        "battle_start",
        "round_start",
        "turn_start",
        "before_normal_draw",
        "after_normal_draw",
        "action_window_start",
    ], "单方战斗以统一顺序进入战斗、回合、补牌和行动窗口时点")
    engine.end_player_turn()
    _assert_equal(engine.timing_system.history[-2]["timing"], "action_window_end", "结束回合先关闭行动窗口")
    _assert_equal(engine.timing_system.history[-1]["timing"], "turn_end", "行动窗口关闭后进入行动方回合结束")
    engine.start_player_turn()
    var battle_start_count := 0
    for entry in engine.timing_system.history:
        if entry["timing"] == "battle_start":
            battle_start_count += 1
    _assert_equal(battle_start_count, 1, "同一场战斗的战斗开始时点只触发一次")

    var ending_card = _card("7", "forest")
    ending_card.set_anomaly("poison", "lethal_poison")
    engine.player.hand = [ending_card]
    engine.player.stacks["momentum"] = 5
    engine.enemy.stacks["gu_mark"] = 2
    engine.delayed_effects.append({"label": "未到期测试延迟"})
    engine.enemy.life = 0
    engine._update_battle_state()
    var battle_end_entry: Dictionary = engine.timing_system.history[-1]
    _assert_equal(battle_end_entry["timing"], "battle_end", "战斗终局统一进入战斗结束时点")
    _assert_equal(
        battle_end_entry["handler_results"].map(func(result): return result["handler_id"]),
        [
            "status_system.card_battle_end",
            "status_system.transient_battle_end",
            "combat_engine.flow_cleanup",
        ],
        "战斗结束按固定顺序先清真气异状再清临时战斗状态")
    _assert_equal(ending_card.anomaly_poison, "", "战斗结束时点清除真气异状")
    _assert_true(engine.player.stacks.is_empty() and engine.enemy.stacks.is_empty(), "战斗结束时点清除敌我临时层数")
    _assert_equal(engine.delayed_effects.size(), 0, "战斗结束时点清除未到期延迟记录")

    var scripted = CombatEngineScript.new()
    _assert_true(scripted.setup_scripted_battle(2308), "双方时点集成测试载入脚本战斗")
    scripted.start_player_turn()
    var turn_start_actor_ids: Array = []
    for entry in scripted.timing_system.history:
        if entry["timing"] == "turn_start":
            turn_start_actor_ids.append(entry["actor_id"])
    _assert_equal(turn_start_actor_ids, ["player", "enemy"], "敌我通过同一种行动方回合开始时点进入正常补牌")

func _test_status_system_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "状态系统契约测试载入统一内容目录")
    var shared_log = GameLogScript.new()
    var engine = CombatEngineScript.new(shared_log, catalog)
    engine.setup(815, false)
    var system = engine.status_system
    _assert_true(
        system != null and system.has_method("add_actor_status"),
        "战斗核心装配独立 StatusSystem")

    var player_gu: Dictionary = system.add_actor_status(engine.player, "gu_mark", 4, "状态契约")
    var enemy_momentum: Dictionary = system.add_actor_status(engine.enemy, "momentum", 3, "状态契约")
    _assert_equal(player_gu["changed"], 4, "玩家通过统一状态接口获得蛊印")
    _assert_equal(enemy_momentum["changed"], 3, "敌方通过同一状态接口获得连势")
    _assert_equal(system.actor_status_value(engine.player, "gu_mark"), 4, "统一接口查询玩家状态层数")
    _assert_equal(system.actor_status_value(engine.enemy, "momentum"), 3, "统一接口查询敌方状态层数")
    _assert_equal(system.consume_actor_status(engine.player, "gu_mark", 2, "状态契约")["changed"], 2, "统一接口消费角色状态")
    _assert_true(not system.add_actor_status(engine.player, "missing_status", 1)["success"], "状态系统拒绝未登记角色状态")

    var card = _card("9", "fire")
    card.set_finish("foil")
    engine.player.hand = [card]
    _assert_true(system.apply_card_anomaly(card, "poison", "lethal_poison", {}, "状态契约")["success"], "状态系统施加烈毒")
    _assert_true(system.apply_card_anomaly(card, "poison", "stagnant_poison", {}, "状态契约")["success"], "新毒通过状态系统替换唯一毒槽")
    _assert_true(card.has_anomaly("poison", "stagnant_poison"), "唯一毒槽保留后来毒")
    system.apply_card_anomaly(card, "state", "vulnerability", {}, "状态契约")
    system.apply_card_anomaly(card, "state", "acupoint_block", {}, "状态契约")
    _assert_true(card.has_anomaly("state", "acupoint_block"), "新状态通过状态系统替换唯一状态槽")
    system.apply_card_anomaly(card, "mark", "wind_lure", {}, "状态契约")
    system.apply_card_anomaly(card, "mark", "qi_severance", {}, "状态契约")
    _assert_equal(card.anomaly_marks.size(), 2, "不同标记可通过状态系统共存")
    system.apply_card_anomaly(card, "mark", "purification", {}, "状态契约")
    _assert_equal(card.reshape_finish, "", "净化通过状态系统屏蔽既有重塑")
    _assert_equal(card.anomaly_marks.keys(), ["purification"], "净化清除既有异状后保留自身")
    system.apply_card_anomaly(card, "state", "qi_dissipation", {}, "净化后施加")
    _assert_true(card.has_anomaly("state", "qi_dissipation"), "净化不阻止后来施加的异状")

    system.consume_actor_status(engine.player, "gu_mark", 99, "状态契约")
    var poison_card = _card("7", "forest")
    poison_card.set_enhancement("bonus")
    engine.player.staging = [poison_card]
    system.apply_card_anomaly(poison_card, "poison", "lethal_poison", {}, "状态契约")
    var poison_resolutions: Array = system.resolve_played_card_anomalies(
        engine.player,
        engine.player.staging)
    _assert_equal(poison_resolutions[0]["damage"], 9, "烈毒读取奖励牌的当前有效真气值")
    _assert_equal(engine.player.life, 91, "烈毒通过统一伤害入口作用于持有者")
    _assert_true(not poison_card.has_anomaly("poison"), "没有蛊印时烈毒触发后移除")

    system.register_attack_counter_delay("状态契约延迟", 1, 120, 6, engine.player, engine.enemy)
    engine.deal_damage(engine.player, engine.enemy, 5, "technique")
    _assert_equal(system.delayed_records[0]["attack_count"], 1, "延迟记录通过状态系统累计攻击段")
    engine.timing_system.emit_timing(BattleTimingSystemScript.TURN_END, {
        "actor": engine.player,
        "actors": [engine.player, engine.enemy],
    })
    _assert_equal(system.delayed_records.size(), 0, "回合结束时点由状态系统结算到期延迟")
    _assert_equal(engine.enemy.life, 89, "延迟结算读取建立时保存的每段伤害")
    _assert_true(
        _array_contains_change_type(system.history, "delay_register")
        and _array_contains_change_type(system.history, "delay_resolve"),
        "状态历史记录延迟建立与结算")
    var status_snapshot = BattleSessionScript.new(engine).snapshot()
    _assert_equal(
        status_snapshot.value("status_history", []).size(),
        system.history.size(),
        "战斗快照公开状态系统的深复制历史")

    engine.timing_system.emit_timing(BattleTimingSystemScript.BATTLE_END, {
        "actors": [engine.player, engine.enemy],
    })
    _assert_equal(card.reshape_finish, "foil", "战斗结束移除净化并恢复未替换的整局重塑")
    _assert_true(card.anomaly_snapshot()["marks"].is_empty(), "战斗结束清除全部战斗异状")
    _assert_true(engine.player.stacks.is_empty() and engine.enemy.stacks.is_empty(), "战斗结束统一清除敌我角色状态")
    _assert_true(not system.history.is_empty(), "状态系统公开结构化变化历史")
    _assert_true(not shared_log.entries("battle").is_empty(), "状态变化进入统一战斗日志")

func _array_contains_change_type(values: Array, wanted: String) -> bool:
    for value in values:
        if value is Dictionary and str(value.get("change_type", "")) == wanted:
            return true
    return false

func _test_action_controller_boundaries_and_strategy() -> void:
    var human = PlayerActionControllerScript.new()
    var selected_card = _card("7", "wind")
    var accepted = human.propose(
        [selected_card.id],
        func(_ids_value: Array): return {
            "valid": true,
            "hand": {"id": "high_card"},
            "intent": {"damage": 0, "defense": 0},
        })
    _assert_true(accepted.accepted, "玩家行动控制器把 UI 选牌转换为统一行动提案")
    _assert_equal(accepted.controller_id, "human", "玩家行动提案记录独立生成来源")
    var rejected = human.propose(
        [],
        func(_ids_value: Array): return {"valid": false, "reason": "必须选牌"})
    _assert_true(not rejected.accepted, "玩家行动控制器保留共享预览规则的拒绝结果")
    _assert_equal(rejected.rejection_reason, "必须选牌", "玩家行动拒绝原因来自共享规则核")

    var actor = BattleSideScript.new("观察者", "observer")
    var opponent = BattleSideScript.new("目标", "target")
    actor.hand = [_card("2", "fire")]
    actor.draw_pile = [_card("3", "fire")]
    opponent.hand = [_card("A", "mountain")]
    opponent.draw_pile = [_card("K", "mountain")]
    var sequence_book = preload("res://core/sequence_book.gd").new()
    sequence_book.configure({"high_card": ["fire_sparks"]})
    var flow = BattleFlowCoordinatorScript.new()
    flow.reset([actor, opponent])
    flow.begin_round([{"actor": actor, "actions": 1}])
    var observation = BattleObservationScript.new().capture(
        actor, opponent, sequence_book, flow)
    var public_observation: Dictionary = observation.public_snapshot()
    _assert_equal(observation.actor_hand[0].id, actor.hand[0].id, "决策器能读取自己真实手牌")
    _assert_equal(public_observation["opponent_hand_count"], 1, "决策观察只公开对方手牌数量")
    _assert_true(not public_observation.has("opponent_hand"), "决策观察不泄露对方手牌内容")
    _assert_true(not public_observation.has("actor_draw_pile"), "决策观察不泄露己方牌库顺序")
    _assert_true(not public_observation.has("opponent_draw_pile"), "决策观察不泄露对方牌库顺序")

    var rng := RandomNumberGenerator.new()
    rng.seed = 815
    var enemy_controller = EnemyActionControllerScript.new(rng)
    var lethal_card = _card("4", "fire")
    var defense_card = _card("5", "mountain")
    var lethal_observation = BattleObservationScript.new()
    lethal_observation.actor_hand = [lethal_card, defense_card]
    lethal_observation.actor_life = 100
    lethal_observation.actor_max_life = 100
    lethal_observation.opponent_life = 10
    lethal_observation.opponent_defense = 0
    var lethal_definitions := {
        _selection_key([lethal_card.id]): {
            "valid": true,
            "intent": {"damage": 10, "defense": 0, "combo": false},
            "values": {"technique_value": 10},
            "condition": {"ok": true},
            "technique_id": "lethal",
            "next_technique_id": "",
        },
        _selection_key([defense_card.id]): {
            "valid": true,
            "intent": {"damage": 0, "defense": 100, "combo": false},
            "values": {"technique_value": 100},
            "condition": {"ok": true},
            "technique_id": "guard",
            "next_technique_id": "",
        },
    }
    var lethal = enemy_controller.propose_utility(
        lethal_observation,
        Callable(self, "_fake_action_preview").bind(lethal_definitions),
        {"defense_weight": 100.0, "power_weight": 0.0})
    _assert_equal(lethal.card_ids, [str(lethal_card.id)], "敌方硬优先级不会因即时评分权重错过必杀")
    _assert_equal(lethal.diagnostics["priority"], 2, "必杀行动进入最高决策优先级")

    var survival_observation = BattleObservationScript.new()
    survival_observation.actor_hand = [lethal_card, defense_card]
    survival_observation.actor_life = 20
    survival_observation.actor_max_life = 100
    survival_observation.opponent_life = 100
    survival_observation.opponent_defense = 0
    survival_observation.expected_incoming_damage = 25
    var survival = enemy_controller.propose_utility(
        survival_observation,
        Callable(self, "_fake_action_preview").bind(lethal_definitions),
        {
            "damage_weight": 100.0,
            "defense_weight": 0.0,
            "power_weight": 0.0,
            "danger_life_ratio": 0.3,
        })
    _assert_equal(survival.card_ids, [str(defense_card.id)], "确认存在致命威胁时敌方优先选择能存活的防御")
    _assert_equal(survival.diagnostics["priority"], 1, "生存行动只在有公开威胁估计时进入硬优先级")

    var setup_card_a = _card("6", "wind")
    var setup_card_b = _card("7", "wind")
    var follow_card_a = _card("8", "fire")
    var follow_card_b = _card("9", "forest")
    var planning_observation = BattleObservationScript.new()
    planning_observation.actor_hand = [
        setup_card_a, setup_card_b, follow_card_a, follow_card_b]
    planning_observation.actor_life = 100
    planning_observation.actor_max_life = 100
    planning_observation.opponent_life = 100
    planning_observation.opponent_defense = 0
    var setup_ids := [setup_card_a.id, setup_card_b.id]
    var follow_ids := [follow_card_a.id, follow_card_b.id]
    var all_ids := setup_ids + follow_ids
    var planning_definitions := {
        _selection_key(setup_ids): {
            "valid": true,
            "intent": {"damage": 35, "defense": 0, "combo": true},
            "values": {"technique_value": 35},
            "condition": {"ok": true},
            "technique_id": "setup",
            "next_technique_id": "payoff",
        },
        _selection_key(follow_ids): {
            "valid": true,
            "intent": {"damage": 40, "defense": 0, "combo": false},
            "values": {"technique_value": 40},
            "condition": {"ok": true},
            "technique_id": "payoff",
            "next_technique_id": "",
        },
        _selection_key(all_ids): {
            "valid": true,
            "intent": {"damage": 50, "defense": 0, "combo": true},
            "values": {"technique_value": 50},
            "condition": {"ok": true},
            "technique_id": "burst",
            "next_technique_id": "",
        },
    }
    var planned = enemy_controller.propose_utility(
        planning_observation,
        Callable(self, "_fake_action_preview").bind(planning_definitions),
        {
            "card_cost": 0.0,
            "power_weight": 0.0,
            "combo_bonus": 0.0,
            "combo_follow_up_weight": 0.75,
            "combo_without_follow_up_penalty": 30.0,
        })
    _assert_equal(planned.card_ids, [str(setup_card_a.id), str(setup_card_b.id)], "敌方会为可立即连击的后续收益放弃当前最高伤害")
    _assert_true(float(planned.diagnostics["score_components"]["combo_follow_up"]) > 0.0, "敌方提案记录可审计的后续手牌价值")

func _selection_key(card_ids: Array) -> String:
    var values: Array[String] = []
    for card_id in card_ids:
        values.append(str(card_id))
    values.sort()
    return "|".join(values)

func _fake_action_preview(card_ids: Array, definitions: Dictionary) -> Dictionary:
    return definitions.get(
        _selection_key(card_ids),
        {"valid": false, "reason": "测试候选未定义"}).duplicate(true)

func _test_run_deck_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "RunDeck 契约测试载入统一内容目录")
    var run_deck = RunDeckScript.new(catalog)
    run_deck.reset_standard("run-815")
    _assert_equal(run_deck.card_count(), 52, "RunDeck 从内容数据建立 52 张本局真气")
    _assert_true(run_deck.has_card("wind_7"), "基础真气实例在 RunDeck 中可按实例 ID 定位")

    var battle_cards := run_deck.create_battle_cards()
    var source = null
    for card in battle_cards:
        if card.id == "wind_7":
            source = card
            break
    _assert_true(source != null, "RunDeck 可以创建独立战斗实例")
    source.set_enhancement("bonus")
    source.set_finish("foil")
    source.set_imprint("red")
    source.set_anomaly("poison", "lethal_poison")
    run_deck.sync_from_battle_cards(battle_cards)
    var persistent: Dictionary = run_deck.card_data("wind_7")
    _assert_equal(persistent["reshapes"]["enhancement"], "bonus", "战斗中的强化同步为本局重塑")
    _assert_equal(persistent["reshapes"]["finish"], "foil", "战斗中的品相同步为本局重塑")
    _assert_equal(persistent["reshapes"]["imprint"], "red", "战斗中的印记同步为本局重塑")
    _assert_true(persistent["reshapes"]["others"].is_empty(), "未配置的重塑其他不会被测试擅自补入内容库")
    _assert_true(not persistent.has("anomalies"), "RunDeck 永不保存战斗异状")

    var copied: Dictionary = run_deck.copy_card("wind_7", 2)
    _assert_true(copied["success"], "RunDeck 提供明确的永久复制接口")
    _assert_equal(copied["instance_ids"].size(), 2, "永久复制生成指定数量的实例")
    _assert_true(copied["instance_ids"][0] != copied["instance_ids"][1], "每张复制真气拥有独立实例 ID")
    _assert_equal(run_deck.card_count(), 54, "永久复制增加本局牌组数量")
    _assert_equal(
        run_deck.card_data(copied["instance_ids"][0])["reshapes"],
        persistent["reshapes"],
        "永久复制完整保留全部重塑")
    _assert_true(run_deck.remove_card(copied["instance_ids"][0])["success"], "RunDeck 提供明确的永久移出接口")
    _assert_equal(run_deck.card_count(), 53, "永久移出只删除目标实例")

    var temporary = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "fire_3"),
        "temporary:test")
    temporary.temporary_card = true
    _assert_equal(run_deck.add_card(temporary)["success"], false, "战斗临时真气不能误入本局牌组")
    var restored_deck = RunDeckScript.new(catalog)
    _assert_equal(restored_deck.restore_snapshot(run_deck.to_snapshot()), [], "RunDeck 版本化快照可以通过校验恢复")
    _assert_equal(restored_deck.to_snapshot(), run_deck.to_snapshot(), "RunDeck 快照恢复保持完整实例状态和 ID 序列")

    var progress = RunProgressSnapshotScript.new({
        "consumable_ids": ["aura"],
        "insight_multipliers": {"high_card": 1},
        "learned_technique_ids": ["clear_wind_gap"],
        "run_deck": run_deck.to_snapshot(),
    })
    var battle_session = BattleSessionScript.new(CombatEngineScript.new())
    _assert_true(
        battle_session.setup_battle({"content_seed": 815}, progress),
        "BattleSetupService 从 RunDeck 快照建立战斗牌组")
    var battle_source = null
    for card in battle_session.engine.player.all_zone_cards():
        if card.id == "wind_7":
            battle_source = card
            break
    _assert_true(battle_source != null, "战斗装配保留本局真气实例 ID")
    _assert_equal(battle_source.reshape_imprint, "red", "战斗装配恢复印记与其他完整重塑字段")
    _assert_equal(battle_source.anomaly_poison, "", "新战斗不会从 RunDeck 恢复上场异状")
    battle_source.set_finish("polychrome")
    battle_source.set_anomaly("state", "qi_dissipation")
    battle_session.engine.player.mark_permanently_removed("wind_2")
    var synced_progress = battle_session.player_progress_snapshot()
    var synced_deck: Dictionary = synced_progress.value("run_deck", {})
    _assert_equal(synced_deck["cards"].size(), 52, "明确登记的永久移出会同步回本局牌组")
    var synced_source: Dictionary = {}
    for values in synced_deck["cards"]:
        if values["instance_id"] == "wind_7":
            synced_source = values
            break
    _assert_equal(synced_source["reshapes"]["finish"], "polychrome", "战斗中的本局重塑替换同步回 RunDeck")
    _assert_true(not synced_source.has("anomalies"), "战斗同步不会把状态异状带到下一场")

func _test_standard_deck() -> void:
    var deck := DeckFactoryScript.create_standard_deck()
    _assert_equal(deck.size(), 52, "基础牌组共 52 张")
    var attribute_counts := {"wind": 0, "forest": 0, "fire": 0, "mountain": 0}
    var face_values := {}
    for card in deck:
        attribute_counts[card.attribute] += 1
        _assert_equal(card.definition_id, card.id, "基础牌兼容ID同时保留定义身份")
        if card.attribute == "wind":
            face_values[card.rank_name] = card.qi_value
    for attribute in attribute_counts:
        _assert_equal(attribute_counts[attribute], 13, "%s 属性 13 张" % attribute)
    _assert_equal(face_values["J"], 11, "J 真气值")
    _assert_equal(face_values["Q"], 11, "Q 真气值")
    _assert_equal(face_values["K"], 11, "K 真气值")
    _assert_equal(face_values["A"], 12, "A 真气值")

func _test_pool_structure_and_turn_draw_rules() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(7, false)
    var unique_pools: Dictionary = {}
    for hand_id in engine.repository.pool_membership:
        for pool_id in engine.repository.pool_membership[hand_id]:
            unique_pools[pool_id] = true
    _assert_equal(unique_pools.size(), 6, "六类共用功法池")
    _assert_equal(engine.repository.pool_membership.size(), 9, "九种精确牌型均配置合格池")
    engine.sequence_book.configure({"pair": ["a", "b"], "two_pair": ["a", "b"]})
    engine.sequence_book.advance("pair")
    _assert_equal(engine.sequence_book.position("pair"), 1, "一对序列独立推进")
    _assert_equal(engine.sequence_book.position("two_pair"), 0, "两对序列不受一对推进影响")
    var drawn := engine.start_player_turn()
    _assert_equal(drawn.size(), 8, "回合开始补至基础手牌上限 8")
    _assert_equal(engine.player.hand.size(), 8, "补牌后手牌为 8")
    engine.player.discard_pile = engine.player.hand.slice(0, 3)
    engine.player.hand.clear()
    engine.player.draw_pile.clear()
    var empty_draw := engine.start_player_turn()
    _assert_equal(empty_draw.size(), 0, "牌库为空不从弃牌堆自动洗回")
    _assert_equal(engine.player.discard_pile.size(), 3, "弃牌堆保持不变")
    _assert_equal(engine.preview([])["valid"], false, "不能选择 0 张")
    engine.player.hand = [_card("2"), _card("3"), _card("4"), _card("5"), _card("6"), _card("7")]
    _assert_equal(engine.preview(_ids(engine.player.hand))["valid"], false, "不能选择超过 5 张")

func _test_all_nine_hand_types_and_contributors() -> void:
    var cases := [
        {"id": "high_card", "cards": [_card("A"), _card("7", "forest"), _card("3", "fire")], "count": 1, "sum": 12},
        {"id": "pair", "cards": [_card("7"), _card("7", "forest"), _card("A", "fire"), _card("3")], "count": 2, "sum": 14},
        {"id": "two_pair", "cards": [_card("9"), _card("9", "forest"), _card("4"), _card("4", "fire"), _card("A")], "count": 4, "sum": 26},
        {"id": "three_kind", "cards": [_card("6"), _card("6", "forest"), _card("6", "fire"), _card("A")], "count": 3, "sum": 18},
        {"id": "straight", "cards": [_card("A"), _card("2", "forest"), _card("3", "fire"), _card("4", "mountain"), _card("5")], "count": 5, "sum": 26},
        {"id": "flush", "cards": [_card("2"), _card("5"), _card("8"), _card("J"), _card("K")], "count": 5, "sum": 37},
        {"id": "full_house", "cards": [_card("7"), _card("7", "forest"), _card("7", "fire"), _card("3"), _card("3", "forest")], "count": 5, "sum": 27},
        {"id": "four_kind", "cards": [_card("8"), _card("8", "forest"), _card("8", "fire"), _card("8", "mountain"), _card("A")], "count": 4, "sum": 32},
        {"id": "straight_flush", "cards": [_card("10", "fire"), _card("J", "fire"), _card("Q", "fire"), _card("K", "fire"), _card("A", "fire")], "count": 5, "sum": 55},
    ]
    for test_case in cases:
        var result := HandEvaluatorScript.evaluate(test_case["cards"])
        _assert_equal(result["id"], test_case["id"], "识别 %s" % test_case["id"])
        _assert_equal(result["contributing"].size(), test_case["count"], "%s 参与张数" % test_case["id"])
        var qi_sum := 0
        for card in result["contributing"]:
            qi_sum += card.qi_value
        _assert_equal(qi_sum, test_case["sum"], "%s 参与真气值" % test_case["id"])
    var jq := HandEvaluatorScript.evaluate([_card("J"), _card("Q")])
    _assert_equal(jq["id"], "high_card", "J/Q 真气值相同但不成对")

func _test_power_calculation() -> void:
    var result := HandEvaluatorScript.evaluate([_card("7"), _card("7", "forest"), _card("4"), _card("3"), _card("A")])
    var values := PowerCalculatorScript.calculate(result, {
        "base_fixed": 3,
        "insight_multiplier": 1,
        "multiplier_bonus": 2,
        "power_fixed": 5,
        "power_amp_percent": 40,
    })
    _assert_equal(values["base_value"], 17, "基础值含固定修正")
    _assert_equal(values["baseline_value"], 34, "牌型基准值只读固定倍率")
    _assert_equal(values["technique_multiplier"], 5, "功法倍率加法")
    _assert_equal(values["unamplified_technique_value"], 90, "未增幅功法值")
    _assert_equal(values["technique_value"], 125, "功法值统一增幅后向下取整")

func _test_damage_resolver_rules_and_facade() -> void:
    var resolver = DamageResolverScript.new()
    var actor = BattleSideScript.new("攻击方")
    var target = BattleSideScript.new("受击方")
    target.life = 100
    target.defense = 7
    var normal: Dictionary = resolver.resolve(actor, target, 10, "technique")
    _assert_equal(normal["defense_lost"], 7, "普通伤害优先扣除全部可用防御")
    _assert_equal(normal["life_lost"], 3, "普通伤害余量才扣除生命")
    _assert_equal(target.defense, 0, "普通伤害实际更新目标防御")
    _assert_equal(target.life, 97, "普通伤害实际更新目标生命")

    target.life = 100
    target.defense = 9
    var true_hit: Dictionary = resolver.resolve(actor, target, 4, "technique", true)
    _assert_equal(true_hit["defense_lost"], 0, "真伤不扣除防御")
    _assert_equal(target.defense, 9, "真伤绕过并保留目标防御")
    _assert_equal(target.life, 96, "真伤直接扣除目标生命")

    actor.stacks["momentum"] = 25
    target.life = 100
    target.defense = 0
    var momentum_hit: Dictionary = resolver.resolve(actor, target, 8, "technique")
    _assert_equal(momentum_hit["final_amount"], 10, "连势按攻击段实时提高普通伤害")
    _assert_equal(target.life, 90, "连势增伤后的数值实际结算")

    actor.stacks.clear()
    target.life = 5
    var completed_segments := 0
    for _index in range(3):
        if not resolver.target_can_receive(target):
            break
        resolver.resolve(actor, target, 3, "technique")
        completed_segments += 1
    _assert_equal(completed_segments, 2, "多段攻击在目标死亡后停止后续攻击段")
    _assert_equal(target.life, 0, "多段攻击不会将生命扣至负数")

    var first = BattleSideScript.new("甲")
    var second = BattleSideScript.new("乙")
    first.life = 4
    second.life = 5
    resolver.begin_synchronized([first, second])
    resolver.resolve(first, second, 5, "technique")
    _assert_equal(second.life, 5, "同步伤害在缓冲刷新前不提前修改真实生命")
    _assert_true(not resolver.target_can_receive(second), "同步伤害 shadow 能判定目标已被本击击倒")
    _assert_true(resolver.actor_can_continue(second), "同步行动方按本击开始时存活状态完成已锁定伤害")
    resolver.resolve(second, first, 4, "technique")
    var synchronized: Array = resolver.flush_synchronized()
    _assert_equal(synchronized.size(), 2, "同步伤害刷新全部已锁定意图")
    _assert_equal(first.life, 0, "同步双方致命时第一方正常倒下")
    _assert_equal(second.life, 0, "同步双方致命时第二方正常倒下")

    var engine = CombatEngineScript.new()
    engine.setup(144, false)
    engine.player.stacks["momentum"] = 25
    engine.enemy.life = 20
    engine.enemy.defense = 3
    var facade: Dictionary = engine.deal_damage(
        engine.player,
        engine.enemy,
        8,
        "technique")
    var direct_actor = BattleSideScript.new("直接攻击方")
    var direct_target = BattleSideScript.new("直接受击方")
    direct_actor.stacks["momentum"] = 25
    direct_target.life = 20
    direct_target.defense = 3
    var direct: Dictionary = DamageResolverScript.new().resolve(
        direct_actor,
        direct_target,
        8,
        "technique")
    _assert_equal(facade["requested"], direct["requested"], "战斗引擎兼容门面与伤害服务请求值一致")
    _assert_equal(facade["defense_lost"], direct["defense_lost"], "战斗引擎兼容门面与伤害服务防御结算一致")
    _assert_equal(facade["life_lost"], direct["life_lost"], "战斗引擎兼容门面与伤害服务生命结算一致")
    _assert_equal(engine.enemy.life, direct_target.life, "战斗引擎兼容门面与伤害服务最终生命一致")
    _assert_equal(engine.enemy.defense, direct_target.defense, "战斗引擎兼容门面与伤害服务最终防御一致")

func _test_structured_game_log_channels() -> void:
    var game_log = GameLogScript.new()
    var battle_entry: Dictionary = game_log.record_battle(
        "damage",
        "测试攻击段",
        "测试功法",
        "成功",
        "造成 3 点伤害")
    var system_entry: Dictionary = game_log.record_system(
        "warning",
        "battle_command",
        "测试命令被拒绝",
        "命令参数无效",
        {"command": "test"})
    var run_entry: Dictionary = game_log.record_run(
        "node_lifecycle",
        "测试节点完成",
        "历练 +3",
        {"node_id": "0_0"})
    _assert_equal(battle_entry["serial"], 0, "统一日志从稳定序号零开始")
    _assert_equal(system_entry["serial"], 1, "战斗与系统日志共享同一递增序号")
    _assert_equal(run_entry["serial"], 2, "本局日志与其他通道共享同一递增序号")
    _assert_equal(game_log.entries("battle").size(), 1, "统一日志可独立查询战斗通道")
    _assert_equal(game_log.entries("run").size(), 1, "统一日志可独立查询本局通道")
    _assert_equal(game_log.entries("system").size(), 1, "统一日志可独立查询系统通道")
    _assert_equal(
        game_log.entries("battle")[0]["context"]["status"],
        "成功",
        "战斗日志保留结构化结算状态")
    var copied: Array = game_log.entries("system")
    copied[0]["detail"] = "被外部修改"
    _assert_equal(
        game_log.latest("system")["detail"],
        "命令参数无效",
        "修改日志查询副本不会污染日志核心")
    game_log.clear("battle")
    _assert_equal(game_log.entries("battle").size(), 0, "可以单独清理战斗日志通道")
    _assert_equal(game_log.entries("system").size(), 1, "清理战斗日志不会删除系统诊断")
    _assert_equal(game_log.entries("run").size(), 1, "清理战斗日志不会删除本局流程记录")

func _test_action_preview_service_matches_engine_facade() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(2308, false)
    engine.start_player_turn()
    var card_ids: Array = [engine.player.hand[0].id, engine.player.hand[1].id]
    var hand_count_before: int = engine.player.hand.size()
    var sequence_position_before: int = engine.sequence_book.position("pair")
    var direct: Dictionary = engine.action_preview_service.preview(
        engine.player,
        card_ids,
        engine.sequence_book,
        engine.power_modifiers,
        engine.natural_combo_used)
    var through_facade: Dictionary = engine.preview(card_ids)
    _assert_equal(direct, through_facade, "独立行动预览服务与战斗门面返回完全一致")
    _assert_equal(engine.player.hand.size(), hand_count_before, "行动预览服务不移动手牌")
    _assert_equal(
        engine.sequence_book.position("pair"),
        sequence_position_before,
        "行动预览服务不推进功法序列")

func _test_action_resolver_boundary_and_queue_rebind() -> void:
    var pair := [_card("8", "wind"), _card("8", "forest")]
    var engine = _engine_with_hand(pair, [], 815)
    engine.sequence_book.configure({"pair": ["double_gu_bind", "test_next_pair"]})
    var action_preview: Dictionary = engine.preview(_ids(pair))
    _assert_true(engine.player.stage_cards(_ids(pair)), "行动解析器测试真气进入待出区")
    var record: Dictionary = engine.action_resolver.make_action_record(
        engine.player,
        engine.enemy,
        action_preview,
        engine.sequence_book,
        100,
        engine.turn_number)
    engine.action_resolver.resolve_action_records([record], false)
    var commit: Dictionary = engine.action_resolver.commit_staging_for(engine.player)
    engine.action_resolver.finish_action_record(record)
    _assert_true(record["triggered"], "独立行动解析器触发当前功法")
    _assert_equal(engine.player.defense, 16, "独立行动解析器结算功法防御")
    _assert_equal(engine.enemy.stacks.get("gu_mark", 0), 1, "独立行动解析器结算目标层数")
    _assert_equal(commit["committed"].size(), 2, "独立行动解析器提交待出真气")
    _assert_equal(engine.player.discard_pile.size(), 2, "独立行动解析器负责出牌进入弃牌堆")
    _assert_equal(engine.sequence_book.position("pair"), 1, "独立行动解析器在牌型组结束后推进序列")
    _assert_equal(engine.timing_system.history[-1]["timing"], "group_end", "行动解析器通过统一牌型组结束时点推进序列")
    _assert_equal(
        engine.timing_system.history[-1]["handler_results"][0]["handler_id"],
        "action_resolver.sequence_progression",
        "功法序列推进作为牌型组结束处理器注册")

    var previous_queue = engine.trigger_queue
    var shared_log = GameLogScript.new()
    engine.use_game_log(shared_log)
    _assert_true(engine.trigger_queue != previous_queue, "替换统一日志时重建可见触发队列")
    _assert_true(engine.action_resolver.trigger_queue == engine.trigger_queue, "行动解析器同步绑定新的触发队列")

func _engine_with_hand(cards: Array, draw_cards: Array = [], seed_value: int = 99):
    var engine = CombatEngineScript.new()
    engine.setup(seed_value, false)
    engine.player.hand = cards.duplicate()
    engine.player.draw_pile = draw_cards.duplicate()
    engine.player.discard_pile.clear()
    engine.player.staging.clear()
    engine.actions_available = 1
    return engine

func _ids(cards: Array) -> Array:
    var result: Array = []
    for card in cards:
        result.append(card.id)
    return result

func _test_sequence_progression_and_condition_failure() -> void:
    var mixed_pair := [_card("9", "wind"), _card("9", "forest")]
    var engine = _engine_with_hand(mixed_pair)
    engine.repository.techniques["pure_wind_gate"] = {
        "id": "pure_wind_gate",
        "name": "测试纯风门",
        "pool": "pair_two_pair",
        "condition": {"pure_attribute": "wind"},
        "effects": [{"op": "defense", "amount": {"kind": "power"}}],
    }
    engine.sequence_book.configure({"pair": ["pure_wind_gate", "double_gu_bind"]})
    var failed := engine.confirm_play(_ids(mixed_pair))
    _assert_true(failed["success"], "牌型组即使功法条件失败仍完成出牌")
    _assert_equal(failed["technique_triggered"], false, "条件失败不触发功法")
    _assert_equal(engine.sequence_book.position("pair"), 0, "条件失败序列不推进")

    var wind_pair := [_card("9", "wind"), _card("9", "wind")]
    engine.player.hand = wind_pair
    engine.actions_available = 1
    var succeeded := engine.confirm_play(_ids(wind_pair))
    _assert_equal(succeeded["technique_triggered"], true, "条件满足触发功法")
    _assert_equal(engine.sequence_book.position("pair"), 1, "成功后序列推进一格")

func _test_no_automatic_damage_or_draw() -> void:
    var pair := [_card("5"), _card("5", "forest")]
    var reserve := [_card("A", "fire")]
    var engine = _engine_with_hand(pair + reserve, [_card("2")])
    engine.sequence_book.configure({"pair": []})
    var before_draw_count: int = engine.player.draw_pile.size()
    var result := engine.confirm_play(_ids(pair))
    _assert_true(result["success"], "空序列允许出牌")
    _assert_equal(engine.enemy.life, 100, "出牌与牌型基准值不自动伤害")
    _assert_equal(engine.player.hand.size(), 1, "连击期间不自动补牌")
    _assert_equal(engine.player.draw_pile.size(), before_draw_count, "出牌后牌库未自动抽取")
    _assert_equal(engine.player.discard_pile.size(), 2, "打出牌进入弃牌堆")

func _test_representative_damage_draw_discard() -> void:
    var selected := [_card("9", "mountain")]
    var remaining := [_card("3", "forest"), _card("4", "fire")]
    var draw_cards := [_card("6", "forest"), _card("2", "wind")]
    var engine = _engine_with_hand(selected + remaining, draw_cards, 4242)
    engine.sequence_book.configure({"high_card": ["clear_wind_gap"]})
    var result := engine.confirm_play(_ids(selected))
    _assert_true(result["technique_triggered"], "清风过隙触发")
    _assert_equal(engine.enemy.life, 91, "清风过隙造成 P 点伤害")
    _assert_equal(engine.player.draw_pile.size(), 0, "首次抽到风后额外抽 1 张")
    _assert_equal(engine.player.hand.size(), 3, "抽 2、随机弃 1、打出 1 后手牌数量")

func _test_representative_defense_and_layers() -> void:
    var pair := [_card("7", "wind"), _card("7", "forest")]
    var engine = _engine_with_hand(pair)
    var result := engine.confirm_play(_ids(pair))
    _assert_true(result["technique_triggered"], "双蛊缠脉触发")
    _assert_equal(engine.player.defense, 14, "双蛊缠脉获得 floor(P/2) 防御")
    _assert_equal(engine.enemy.stacks.get("gu_mark", 0), 1, "一对施加 1 层蛊印")

func _test_representative_multi_attack() -> void:
    var straight := [_card("2", "wind"), _card("3", "forest"), _card("4", "fire"), _card("5", "mountain"), _card("6", "wind")]
    var engine = _engine_with_hand(straight)
    var result := engine.confirm_play(_ids(straight))
    _assert_true(result["technique_triggered"], "五阳逐影触发")
    _assert_equal(engine.enemy.life, 25, "五段伤害与四次连续追击逐段结算")
    _assert_equal(engine.player.stacks.get("momentum", 0), 9, "五段与四追击累计连势")

func _test_representative_special_technique() -> void:
    var four := [_card("8", "wind"), _card("8", "forest"), _card("8", "fire"), _card("8", "mountain")]
    var remaining := [_card("2", "fire"), _card("3", "fire"), _card("4", "wind")]
    var draw_cards := [_card("5"), _card("6"), _card("7"), _card("9")]
    var engine = _engine_with_hand(four + remaining, draw_cards)
    var result := engine.confirm_play(_ids(four))
    _assert_true(result["technique_triggered"], "弃薪开炉特殊功法触发")
    _assert_equal(engine.enemy.life, 100, "特殊功法不强制即时伤害")
    _assert_equal(engine.player.stacks.get("momentum", 0), 10, "弃牌按火牌 4 / 其他 2 获得连势")
    _assert_equal(engine.player.hand.size(), 3, "N=3 时抽 3 张")
    _assert_equal(engine.player.discard_pile.size(), 7, "剩余手牌弃掉且打出四条入弃牌堆")
    _assert_equal(engine.actions_available, 1, "获得一次额外出牌机会")

func _test_delayed_power_snapshot() -> void:
    var flush := [_card("2", "forest"), _card("4", "forest"), _card("6", "forest"), _card("8", "forest"), _card("10", "forest")]
    var engine = _engine_with_hand(flush)
    var result := engine.confirm_play(_ids(flush))
    _assert_true(result["technique_triggered"], "百击归烬建立延迟记录")
    _assert_equal(engine.delayed_effects[0]["snapshot_power"], 120, "延迟记录建立时 P")
    _assert_equal(engine.delayed_effects[0]["damage_per_segment"], 6, "延迟每段读取快照 P/20")
    engine.deal_damage(engine.player, engine.enemy, 20, "technique")
    engine.power_modifiers["flush"] = {"power_amp_percent": 500}
    engine.end_player_turn()
    _assert_equal(engine.enemy.life, 80, "第一个回合结束尚未结算延迟")
    engine.end_player_turn()
    _assert_equal(engine.enemy.life, 74, "第二个回合结束按旧快照造成一段 6 伤害")
    _assert_equal(engine.delayed_effects.size(), 0, "延迟结算后移除记录")

func _test_visible_queue_left_to_right() -> void:
    var engine = _engine_with_hand([])
    var hand_result := HandEvaluatorScript.evaluate([_card("2")])
    var context := {"engine": engine, "actor": engine.player, "target": engine.enemy, "hand_result": hand_result, "power": 1, "captures": {}}
    engine.trigger_queue.enqueue("same", "右侧", "测试", 200, [{"op": "defense", "amount": 1}], context.duplicate(true))
    engine.trigger_queue.enqueue("same", "左侧", "测试", 100, [{"op": "defense", "amount": 2}], context.duplicate(true))
    engine.trigger_queue.process_timing("same", engine.effect_executor)
    _assert_equal(engine.player.defense, 3, "同一时点效果逐项更新最新状态")
    var size: int = engine.trigger_queue.history.size()
    _assert_equal(engine.trigger_queue.history[size - 2]["label"], "左侧", "触发队列先结算左侧")
    _assert_equal(engine.trigger_queue.history[size - 1]["label"], "右侧", "触发队列后结算右侧")

func _test_inner_skill_equipment_and_extra_qi_defense() -> void:
    var cards := [_card("4", "wind"), _card("4", "forest"), _card("2", "fire"), _card("3", "mountain")]
    var unequipped = _engine_with_hand(cards)
    unequipped.sequence_book.configure({"pair": []})
    unequipped.confirm_play(_ids(cards))
    _assert_equal(unequipped.player.defense, 0, "未装备初始内功时额外真气不提供防御")

    var equipped_cards := [_card("4", "wind"), _card("4", "forest"), _card("2", "fire"), _card("3", "mountain")]
    var equipped = _engine_with_hand(equipped_cards)
    equipped.sequence_book.configure({"pair": []})
    equipped.player.configure_inner_skills(["extra_qi_to_defense"], 1)
    equipped.confirm_play(_ids(equipped_cards))
    _assert_equal(equipped.player.defense, 5, "未参与一对的 2 与 3 转化为 5 点防御")
    _assert_equal(equipped.player.equipped_inner_skill_ids.size(), 1, "玩家独立记录已装备内功")
    _assert_equal(equipped.enemy.equipped_inner_skill_ids.size(), 0, "敌方装备状态与玩家独立")
    equipped.player.configure_inner_skills([
        "extra_qi_to_defense", "extra_qi_to_defense", "extra_qi_to_defense",
        "extra_qi_to_defense", "extra_qi_to_defense", "extra_qi_to_defense",
        "extra_qi_to_defense"], 7)
    _assert_equal(equipped.player.equipped_inner_skill_ids.size(), 6, "基础内功装备栏上限为六")
    _assert_equal(equipped.player.technique_slot_index, 6, "动态功法位限制在当前装备顺序内")

func _test_inner_skill_preview_and_enemy_plan() -> void:
    var cards := [_card("7", "wind"), _card("7", "forest"), _card("2", "fire"), _card("3", "mountain")]
    var engine = _engine_with_hand(cards)
    engine.sequence_book.configure({"pair": []})
    engine.player.configure_inner_skills(["extra_qi_to_defense"], 1)
    var preview: Dictionary = engine.preview(_ids(cards))
    _assert_equal(preview["intent"]["inner_skill_defense"], 5, "玩家预览单独显示内功预计防御")
    _assert_equal(preview["intent"]["defense"], 5, "玩家总行动预览计入内功防御")

    engine.enemy.hand = cards.duplicate()
    engine.enemy_sequence_book.configure({"pair": [], "high_card": []})
    engine.enemy.configure_inner_skills(["extra_qi_to_defense"], 1)
    var enemy_preview: Dictionary = engine._preview_for_side(engine.enemy, _ids(cards), engine.enemy_sequence_book)
    var public_plan: Dictionary = engine._public_enemy_plan(enemy_preview["intent"])
    _assert_equal(public_plan["defense"], 5, "敌方行动计划计入已装备内功防御")
    _assert_true(not public_plan.has("inner_skills"), "敌方公开计划不泄露具体内功来源")

func _prepare_history_order(engine, cards: Array) -> Array[String]:
    engine.sequence_book.configure({"pair": ["double_gu_bind"]})
    engine.player.configure_inner_skills(["extra_qi_to_defense"], engine.player.technique_slot_index)
    engine.confirm_play(_ids(cards))
    var labels: Array[String] = []
    for entry in engine.trigger_queue.history:
        if entry["timing"] == "solo_prepare":
            labels.append(entry["label"])
    return labels

func _test_inner_skill_and_technique_left_to_right() -> void:
    var before_cards := [_card("6", "wind"), _card("6", "forest"), _card("2", "fire")]
    var technique_before = _engine_with_hand(before_cards)
    technique_before.player.technique_slot_index = 0
    var first_order := _prepare_history_order(technique_before, before_cards)
    _assert_equal(first_order, ["双蛊缠脉", "初始内功候选"], "功法位在左时先于内功结算")

    var after_cards := [_card("6", "wind"), _card("6", "forest"), _card("2", "fire")]
    var technique_after = _engine_with_hand(after_cards)
    technique_after.player.technique_slot_index = 1
    var second_order := _prepare_history_order(technique_after, after_cards)
    _assert_equal(second_order, ["初始内功候选", "双蛊缠脉"], "内功在左时先于功法结算")

func _test_consumable_shared_slots_and_generation_limit() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(77, false)
    engine.player.configure_consumables(["high_card_insight", "hierophant", "aura", "hierophant"])
    _assert_equal(engine.player.consumable_ids.size(), 3, "三类消耗品共用三格容量")
    _assert_equal(engine.player.consumable_ids, ["high_card_insight", "hierophant", "aura"], "共享槽保留三种代表消耗品")
    _assert_equal(engine.grant_consumable(engine.player, "hierophant", "测试"), false, "没有空位时不生成消耗品")
    var used := engine.use_player_consumable(0, [])
    _assert_true(used["success"], "无目标心得可以直接使用")
    _assert_equal(engine.player.consumable_ids.size(), 2, "使用后立即释放共享槽位")
    _assert_true(engine.grant_consumable(engine.player, "hierophant", "测试"), "释放槽位后可以生成消耗品")
    _assert_equal(engine.player.consumable_ids.size(), 3, "重新生成后占满三格")

func _test_insight_growth_and_technique_acquisition() -> void:
    var high = _card("9", "wind")
    var pair := [_card("7", "forest"), _card("7", "fire")]
    var engine = _engine_with_hand([high] + pair, [], 810)
    engine.player.configure_consumables(["high_card_insight"])
    _assert_true(not engine.player.owned_technique_ids.has("fire_sparks"), "初始玩家功法库不含敌方代表功法")
    var sequence_before: Array = engine.sequence_book.sequences["high_card"].duplicate()
    var result := engine.use_player_consumable(0, [])
    _assert_true(result["success"], "高牌心得使用成功")
    _assert_equal(engine.player.insight_multipliers.get("high_card", 0), 1, "心得只增加指定精确牌型累计倍率")
    _assert_equal(engine.player.insight_multipliers.get("pair", 0), 0, "高牌心得不提高一对")
    _assert_equal(result["acquired_technique_id"], "fire_sparks", "心得从合格池获得尚未拥有的功法")
    _assert_true(engine.player.owned_technique_ids.has("fire_sparks"), "所得功法进入本局功法库")
    _assert_equal(engine.sequence_book.sequences["high_card"], sequence_before, "心得所得功法不自动修改当前序列")
    var high_preview := engine.preview([high.id])
    _assert_equal(high_preview["values"]["technique_multiplier"], 2, "高牌固定倍率与累计心得倍率相加")
    _assert_equal(high_preview["values"]["technique_value"], 18, "心得立即影响高牌功法值预览")
    var pair_preview := engine.preview(_ids(pair))
    _assert_equal(pair_preview["values"]["technique_multiplier"], 2, "其他精确牌型倍率保持不变")

func _test_hierophant_bonus_enhancement_and_preview() -> void:
    var pair := [_card("7", "wind"), _card("7", "forest")]
    pair[0].set_enhancement("multiplier")
    var third = _card("3", "fire")
    var engine = _engine_with_hand(pair + [third])
    engine.player.configure_consumables(["hierophant"])
    var no_target := engine.use_player_consumable(0, [])
    _assert_equal(no_target["success"], false, "教皇至少需要一张目标真气")
    var too_many := engine.use_player_consumable(0, _ids(pair + [third]))
    _assert_equal(too_many["success"], false, "教皇不能选择超过两张真气")
    var result := engine.use_player_consumable(0, _ids(pair))
    _assert_true(result["success"], "教皇可以强化至多两张真气")
    _assert_equal(pair[0].reshape_enhancement, "bonus", "新强化替换同一张真气的旧强化")
    _assert_equal(pair[1].reshape_enhancement, "bonus", "第二张目标获得奖励牌强化")
    var preview := engine.preview(_ids(pair))
    _assert_equal(preview["values"]["base_value"], 18, "两张奖励七的有效真气值各加二")
    _assert_equal(preview["values"]["baseline_value"], 36, "奖励牌同时进入牌型基准值")
    _assert_equal(preview["values"]["technique_value"], 36, "奖励牌立即进入功法值预览")

func _test_aura_seeded_finish_and_preview() -> void:
    var first_card = _card("8", "mountain")
    var second_card = _card("8", "mountain")
    first_card.set_finish("foil")
    second_card.set_finish("foil")
    var first = _engine_with_hand([first_card], [], 4404)
    var second = _engine_with_hand([second_card], [], 4404)
    first.player.configure_consumables(["aura"])
    second.player.configure_consumables(["aura"])
    var first_result := first.use_player_consumable(0, [first_card.id])
    var second_result := second.use_player_consumable(0, [second_card.id])
    _assert_true(first_result["success"] and second_result["success"], "光环选择一张真气使用成功")
    _assert_true(first_card.reshape_finish in ["foil", "holographic", "polychrome"], "光环只产生三种合格品相")
    _assert_equal(first_card.reshape_finish, second_card.reshape_finish, "相同固定种子产生相同光环品相")
    _assert_true(first_card.reshape_finish != "", "新品相替换旧品相且不会清空")
    var preview := first.preview([first_card.id])
    match first_card.reshape_finish:
        "foil":
            _assert_equal(preview["values"]["base_value"], 11, "箔面使自身贡献加三")
            _assert_equal(preview["values"]["technique_value"], 11, "箔面贡献进入功法值")
        "holographic":
            _assert_equal(preview["values"]["technique_multiplier"], 2, "镭射使功法倍率加一")
            _assert_equal(preview["values"]["technique_value"], 16, "镭射立即影响功法值")
        "polychrome":
            _assert_equal(preview["values"]["power_amp_percent"], 20, "多彩加入功法值增幅加法池")
            _assert_equal(preview["values"]["technique_value"], 9, "多彩增幅后功法值向下取整")
    var foil = _card("8", "wind")
    foil.set_finish("foil")
    var foil_values := PowerCalculatorScript.calculate(HandEvaluatorScript.evaluate([foil]))
    _assert_equal(foil_values["base_value"], 11, "箔面品相固定增加三点自身贡献")
    var holographic = _card("8", "wind")
    holographic.set_finish("holographic")
    var holographic_values := PowerCalculatorScript.calculate(HandEvaluatorScript.evaluate([holographic]))
    _assert_equal(holographic_values["technique_multiplier"], 2, "镭射品相使功法倍率加一")
    _assert_equal(holographic_values["technique_value"], 16, "镭射品相进入功法值计算")
    var polychrome = _card("8", "wind")
    polychrome.set_finish("polychrome")
    var polychrome_values := PowerCalculatorScript.calculate(HandEvaluatorScript.evaluate([polychrome]))
    _assert_equal(polychrome_values["power_amp_percent"], 20, "多彩品相提供百分之二十功法值增幅")
    _assert_equal(polychrome_values["technique_value"], 9, "多彩品相统一乘算并向下取整")

func _test_battle_consumable_reshape_persists_via_run_deck() -> void:
    var run_deck = RunDeckScript.new()
    run_deck.reset_standard("consumable-reshape")
    var progress = RunProgressSnapshotScript.new({
        "consumable_ids": ["aura"],
        "insight_multipliers": {},
        "learned_technique_ids": [],
        "run_deck": run_deck.to_snapshot(),
    })
    var first_battle = BattleSessionScript.new(CombatEngineScript.new())
    _assert_true(first_battle.setup_battle({"content_seed": 4404}, progress), "带光环的本局牌组可以进入战斗")
    first_battle.execute({"type": "start_turn"})
    var target = first_battle.engine.player.hand[0]
    var target_id := str(target.id)
    var reshape_result: Dictionary = first_battle.execute({
        "type": "use_consumable",
        "slot_index": 0,
        "card_ids": [target_id],
    })
    _assert_true(reshape_result["success"], "战斗中可以使用消耗品重塑真气")
    var applied_finish := str(target.reshape_finish)
    _assert_true(applied_finish in ["foil", "holographic", "polychrome"], "战斗消耗品产生合格品相重塑")
    var after_progress = first_battle.player_progress_snapshot()
    _assert_true(after_progress.value("consumable_ids", []).is_empty(), "战斗中使用消耗品后释放本局槽位")
    var second_battle = BattleSessionScript.new(CombatEngineScript.new())
    _assert_true(second_battle.setup_battle({"content_seed": 4405}, after_progress), "重塑后的 RunDeck 可以建立下一场战斗")
    var restored = null
    for card in second_battle.engine.player.all_zone_cards():
        if card.id == target_id:
            restored = card
            break
    _assert_true(restored != null, "下一场战斗保留被消耗品重塑的真气实例")
    _assert_equal(restored.reshape_finish, applied_finish, "战斗中施加的品相通过 RunDeck 跨战斗保存")
    _assert_true(restored.anomaly_snapshot()["marks"].is_empty(), "跨战斗重塑同步不会附带战斗异状")

func _test_battle_session_commands_snapshots_and_events() -> void:
    var configuration := {
        "content_seed": 2308,
        "battle": {
            "scenario_path": "res://data/scripted_battle.json",
            "use_enemy_ai": true,
        },
    }
    var first = BattleSessionScript.new()
    var second = BattleSessionScript.new()
    _assert_true(first.setup_battle(configuration), "战斗会话可以按配置建立战斗")
    _assert_true(second.setup_battle(configuration), "第二个战斗会话可以按相同配置建立战斗")
    var setup_events: Array = first.drain_events()
    _assert_true(not setup_events.is_empty(), "战斗建立产生可消费事件")
    _assert_equal(first.drain_events().size(), 0, "战斗事件只消费一次")

    _assert_true(first.execute({"type": "start_turn"})["success"], "开始回合命令成功")
    _assert_true(second.execute({"type": "start_turn"})["success"], "第二会话开始回合命令成功")
    var first_snapshot = first.snapshot()
    var second_snapshot = second.snapshot()
    _assert_equal(first_snapshot.section("player")["hand_count"], 8, "战斗快照包含玩家手牌数量")
    _assert_equal(first_snapshot.section("enemy")["hand_count"], 8, "战斗快照包含敌方手牌数量")
    _assert_true(first_snapshot.section("action_states")["player"]["can_act"], "战斗快照公开通用玩家行动资格")
    _assert_true(first_snapshot.section("action_states")["enemy"]["can_act"], "战斗快照公开通用敌方行动资格")
    _assert_equal(first_snapshot.section("player")["equipped_inner_skills"][0]["id"], "extra_qi_to_defense", "快照提供内功展示定义")
    _assert_equal(first_snapshot.section("player")["consumables"][1]["targeting_limits"]["maximum"], 2, "快照提供消耗品展示与目标上限")
    _assert_true(not first_snapshot.value("battle_log", []).is_empty(), "战斗快照提供独立战斗日志通道")
    _assert_equal(first_snapshot.value("battle_log", [])[0]["channel"], "battle", "战斗日志具有统一通道字段")
    _assert_equal(first_snapshot.value("system_log", [])[0]["channel"], "system", "系统日志具有统一通道字段")
    _assert_equal(
        first_snapshot.section("player")["hand"],
        second_snapshot.section("player")["hand"],
        "相同配置与种子产生相同只读手牌快照")
    var changed_copy: Dictionary = first_snapshot.to_dict()
    changed_copy["player"]["life"] = 0
    _assert_equal(first.snapshot().section("player")["life"], 100, "修改快照副本不会修改战斗核心")
    var battle_log_copy: Array = first_snapshot.value("battle_log", [])
    battle_log_copy[0]["message"] = "外部篡改"
    _assert_true(first.snapshot().value("battle_log", [])[0]["message"] != "外部篡改", "日志快照同样保持只读副本边界")

    var preview_snapshot: Dictionary = first.preview([
        first_snapshot.section("player")["hand"][0]["id"]])
    _assert_true(preview_snapshot.get("cards", [])[0] is Dictionary, "会话预览只返回卡牌快照而非领域对象")
    _assert_true(preview_snapshot.get("hand", {}).has("contributing_card_ids"), "会话预览用卡牌 ID 表达参与牌")

    var move_result := first.execute({"type": "move_technique_slot", "direction": -1})
    _assert_true(move_result["success"], "调整功法位命令通过战斗会话执行")
    _assert_equal(first.snapshot().section("player")["technique_slot_index"], 0, "功法位变化进入新快照")
    var hand: Array = first.snapshot().section("player")["hand"]
    var play_result := first.execute({"type": "play_cards", "card_ids": [hand[0]["id"]]})
    _assert_true(play_result["success"], "出牌命令通过战斗会话执行")
    var action_events: Array = first.drain_events()
    _assert_true(not action_events.is_empty(), "出牌结算产生战斗事件流")
    _assert_true(action_events[0].value("serial", -1) >= 0, "战斗事件具有稳定递增序号")

    var rejected := first.execute({"type": "not_a_command"})
    _assert_equal(rejected["success"], false, "未知战斗命令被安全拒绝")
    var rejected_events: Array = first.drain_events()
    _assert_equal(rejected_events[-1].event_type(), "command_rejected", "命令失败产生结构化拒绝事件")
    var system_log: Array = first.snapshot().value("system_log", [])
    _assert_equal(system_log[-1]["severity"], "warning", "命令拒绝进入系统日志 warning 通道")
    _assert_equal(system_log[-1]["context"]["command"], "not_a_command", "系统日志保留被拒绝命令上下文")

func _test_map_generation_is_deterministic_and_constrained() -> void:
    var generator = MapGeneratorScript.new()
    var first: Dictionary = generator.generate(2308, 1)
    var second: Dictionary = generator.generate(2308, 1)
    _assert_equal(first, second, "相同种子生成完全相同的地图与连线")
    _assert_equal(first["width"], 7, "地图内部网格横向宽度为七列")
    _assert_equal(first["route_rows"], 15, "Boss 前有十五行路线节点")
    _assert_equal(first["start_id"], "map_start", "地图记录唯一旅程起点")
    _assert_true(first["boss_variant"] >= 0 and first["boss_variant"] < 3, "种子确定三选一 Boss 候选序号")
    var row_counts: Dictionary = {}
    for node in first["nodes"]:
        var row: int = int(node["row"])
        row_counts[row] = int(row_counts.get(row, 0)) + 1
        _assert_true(node["type"] != "shop", "地图不生成商店节点")
        if row == 0:
            _assert_equal(node["type"], "combat", "第一行固定普通战斗")
        elif row == 8:
            _assert_equal(node["type"], "treasure", "第九层固定宝箱特殊奖励")
        elif row == 14:
            _assert_equal(node["type"], "rest", "第十五行固定休息")
        elif row == 15:
            _assert_equal(node["type"], "boss", "第十六行固定单一 Boss")
        elif row < 5:
            _assert_true(node["type"] not in ["elite", "rest"], "前五行不随机生成精英或休息")
        if row == 13:
            _assert_true(node["type"] != "rest", "第十四层不随机生成休息")
    _assert_equal(row_counts.get(-1, 0), 1, "地图只有一个位于第1层下方的旅程起点")
    _assert_true(row_counts.get(0, 0) >= 1 and row_counts.get(0, 0) <= 6, "六次路径生成保留一至六个第1层房间")
    for row in range(15):
        _assert_true(row_counts.get(row, 0) <= 6, "每个普通楼层最多六个有效节点")
    _assert_equal(row_counts.get(15, 0), 1, "地图只有一个层末 Boss")
    _assert_equal(
        int(generator.rules["weights"]["event"]) + int(generator.rules["weights"]["event_shop"]),
        27,
        "原生事件与商店替代事件合计百分之二十七")
    var hundred_room_pool: Array = generator._build_room_pool(100)
    _assert_equal(hundred_room_pool.count("combat"), 53, "房间类型池普通战斗占百分之五十三")
    _assert_equal(hundred_room_pool.count("event"), 22, "房间类型池原生事件占百分之二十二")
    _assert_equal(hundred_room_pool.count("event_shop"), 5, "房间类型池商店替代事件占百分之五")
    _assert_equal(hundred_room_pool.count("elite"), 8, "房间类型池精英占百分之八")
    _assert_equal(hundred_room_pool.count("rest"), 12, "房间类型池休息占百分之十二")
    var constraint_grid: Array = generator._create_grid(15, 7)
    generator._connect_grid_nodes(constraint_grid, 5, 3, 2)
    generator._connect_grid_nodes(constraint_grid, 5, 3, 3)
    constraint_grid[6][2]["type"] = "event"
    _assert_true(
        not generator._can_assign_type(constraint_grid, 6, 3, "event"),
        "类型分配器拒绝同一分叉目的地使用相同内部类型")
    constraint_grid[5][3]["type"] = "event_shop"
    _assert_true(
        not generator._can_assign_type(constraint_grid, 6, 3, "event_shop"),
        "商店替代事件继承原商店不可沿路线连续的生成约束")
    var trim_grid: Array = generator._create_grid(15, 7)
    generator._connect_grid_nodes(trim_grid, 0, 1, 2)
    generator._connect_grid_nodes(trim_grid, 0, 3, 2)
    generator._trim_redundant_first_floor_edges(trim_grid)
    _assert_equal(trim_grid[0][3]["out_columns"].size(), 0, "首层重复目的地连线按顺序移除")
    _assert_equal(trim_grid[1][2]["parent_columns"].size(), 2, "移除首层冗余边时保留原作内部父引用")
    for edge in first["edges"]:
        var from_type: String = _map_node_type(first, edge["from"])
        var to_type: String = _map_node_type(first, edge["to"])
        if from_type in ["elite", "rest"]:
            _assert_true(from_type != to_type, "精英与休息不沿路径直接同类相连")

func _test_map_routes_reach_boss_without_crossing() -> void:
    var generator = MapGeneratorScript.new()
    for seed_value in range(512):
        var graph: Dictionary = generator.generate(98173 + seed_value * 7919, seed_value % 3 + 1)
        _assert_map_route_constraints(graph, "地图种子 %d" % seed_value)

func _test_node_dispatcher_is_data_driven_and_deterministic() -> void:
    var dispatcher = NodeDispatcherScript.new()
    var combat_node := {
        "id": "0_2",
        "row": 0,
        "column": 2,
        "type": "combat",
        "generation_type": "combat",
    }
    var context := {"seed": 2308, "act": 1, "boss_variant": 2}
    var first: Dictionary = dispatcher.dispatch(combat_node, context)
    var second: Dictionary = dispatcher.dispatch(combat_node, context)
    _assert_true(first["success"], "普通战斗节点可以被调度")
    _assert_equal(first, second, "同一节点与上下文产生确定性调度结果")
    _assert_equal(first["route"], "battle", "普通战斗路由到战斗呈现层")
    _assert_equal(first["content_id"], "representative_combat", "普通战斗读取数据内容标识")
    _assert_equal(first["battle"]["scenario_path"], "res://data/scripted_battle.json", "战斗场景配置来自节点内容数据")
    var another_act: Dictionary = dispatcher.dispatch(combat_node, {"seed": 2308, "act": 2})
    _assert_true(first["content_seed"] != another_act["content_seed"], "不同层的相同坐标使用不同内容种子")

    var event_result: Dictionary = dispatcher.dispatch(
        {"id": "4_3", "row": 4, "column": 3, "type": "event"}, context)
    _assert_equal(event_result["route"], "placeholder", "未确认事件路由到占位呈现层")
    _assert_equal(event_result["content_status"], "unconfirmed", "未确认事件显式标记设计状态")
    _assert_true(not event_result.has("battle"), "非战斗调度结果不泄漏战斗配置")

    var boss_result: Dictionary = dispatcher.dispatch(
        {"id": "15_3", "row": 15, "column": 3, "type": "boss"}, context)
    _assert_equal(boss_result["boss_variant"], 2, "Boss 调度保留地图生成的候选序号")
    _assert_equal(
        dispatcher.dispatch({"id": "bad", "type": "unknown"}, context)["success"],
        false,
        "未知节点类型安全拒绝而不猜测内容")

func _test_run_state_node_and_practice_gate() -> void:
    var state = RunStateScript.new()
    state.setup(2308)
    _assert_true(state.can_open_practice(), "初次进入地图等待选路时可以修习")
    _assert_true(
        state.available_node_ids().size() >= 1 and state.available_node_ids().size() <= 6,
        "单一旅程起点连接一至六个第1层可选房间")
    var first_node_id: String = state.available_node_ids()[0]
    var begin := state.begin_node(first_node_id)
    _assert_true(begin["success"], "可以进入当前可达节点")
    _assert_true(not state.can_open_practice(), "节点进行中锁定修习入口")
    _assert_equal(state.purchase_consumable("hierophant", 3)["success"], false, "节点未完成时不能购买修习内容")
    var completion := state.complete_current_node()
    _assert_true(completion["success"], "节点可以完成并返回地图")
    _assert_equal(completion["reward"], 3, "普通战斗节点奖励三点历练")
    _assert_equal(state.experience, 3, "节点奖励进入本局历练")
    _assert_true(state.can_open_practice(), "节点完成到选择下一节点前重新开放修习")
    _assert_true(not state.available_node_ids().is_empty(), "返回地图后只开放相连下一节点")
    var purchase := state.purchase_consumable("hierophant", 3)
    _assert_true(purchase["success"], "待选节点期间可以消耗历练修习")
    _assert_equal(state.experience, 0, "修习购买扣除对应历练")
    _assert_equal(state.consumable_ids, ["hierophant"], "修习所得进入共享消耗品栏")
    _assert_equal(state.purchase_consumable("hierophant", 3)["success"], false, "同一地图待选阶段固定选项不能重复购买")

func _test_run_service_boundaries_and_progress_snapshot() -> void:
    var navigation = MapNavigationServiceScript.new()
    navigation.setup(2308)
    _assert_equal(navigation.act, 1, "地图导航服务独立保存当前层数")
    _assert_equal(navigation.phase, "awaiting_node", "地图导航服务独立保存待选阶段")
    var available := navigation.available_node_ids()
    _assert_true(available.size() >= 1 and available.size() <= 6, "地图导航服务独立计算可达节点")
    _assert_true(navigation.begin_node(str(available[0]))["success"], "地图导航服务独立进入节点")
    var completed := navigation.complete_current_node()
    _assert_true(completed["success"], "地图导航服务独立完成节点")
    _assert_equal(navigation.phase, "awaiting_node", "地图导航服务完成普通节点后回到待选阶段")
    _assert_equal(completed["reward"], 3, "地图导航服务只返回节点基础奖励，不持有历练")

    var growth = GrowthInventoryScript.new()
    growth.experience = 3
    _assert_equal(
        growth.purchase_consumable("hierophant", 3, false)["success"],
        false,
        "成长库存不绕过地图导航的修习时机限制")
    _assert_true(
        growth.purchase_consumable("hierophant", 3, true)["success"],
        "成长库存独立处理历练和消耗品购买")
    _assert_equal(growth.experience, 0, "成长库存独立扣除历练")
    var progress = growth.to_progress_snapshot()
    var progress_copy: Dictionary = progress.to_dict()
    progress_copy["consumable_ids"].clear()
    _assert_equal(progress.value("consumable_ids"), ["hierophant"], "成长快照对外提供深复制")
    var manual_deck = RunDeckScript.new()
    manual_deck.reset_standard("manual")
    var manual_cards := manual_deck.create_battle_cards()
    for card in manual_cards:
        if card.id == "wind_8":
            card.set_finish("foil")
    manual_deck.sync_from_battle_cards(manual_cards)
    var manual_progress = RunProgressSnapshotScript.new({
        "consumable_ids": ["aura"],
        "insight_multipliers": {"high_card": 2},
        "learned_technique_ids": ["clear_wind_gap"],
        "run_deck": manual_deck.to_snapshot(),
    })
    growth.apply_progress_snapshot(manual_progress)
    _assert_equal(growth.consumable_ids, ["aura"], "成长库存可以从进度快照导入消耗品")
    _assert_equal(growth.insight_multipliers["high_card"], 2, "成长库存可以从进度快照导入心得")
    _assert_equal(growth.run_deck.card_data("wind_8")["reshapes"]["finish"], "foil", "成长库存可以从进度快照导入完整本局牌组")

func _test_run_session_commands_snapshots_events_and_logs() -> void:
    var session = RunSessionScript.new()
    var setup := session.execute({"type": "setup_run", "seed": 2308})
    _assert_true(setup["success"], "本局会话接受结构化建局命令")
    var initial = session.snapshot()
    _assert_equal(initial.value("act"), 1, "本局快照提供当前层数")
    _assert_equal(initial.value("phase"), "awaiting_node", "本局快照提供当前流程阶段")
    _assert_true(initial.value("can_open_practice"), "本局快照提供修习可用状态")
    _assert_equal(initial.section("practice").get("offers", []).size(), 3, "修习代表选项由本局快照提供")
    var copied_graph: Dictionary = initial.section("graph")
    copied_graph["act"] = 99
    _assert_equal(session.snapshot().section("graph").get("act"), 1, "修改地图快照不会污染本局核心")

    var first_node_id := str(initial.value("available_node_ids", [])[0])
    var begin := session.execute({"type": "begin_node", "node_id": first_node_id})
    _assert_true(begin["success"], "本局会话统一校验并进入可达节点")
    _assert_true(begin.get("dispatch", {}).get("success", false), "进入节点命令同时返回数据驱动调度结果")
    _assert_equal(session.snapshot().value("phase"), "node_in_progress", "节点开始后快照进入未完成状态")
    var rejected := session.execute({"type": "open_practice"})
    _assert_equal(rejected["success"], false, "节点未完成时本局会话拒绝打开修习")

    var completion := session.execute({"type": "complete_node"})
    _assert_true(completion["success"], "本局会话完成当前节点")
    _assert_equal(session.snapshot().value("experience"), 3, "节点奖励通过本局快照公开")
    _assert_true(session.execute({"type": "open_practice"})["success"], "返回待选状态后可以打开修习")
    var purchase := session.execute({
        "type": "purchase_consumable",
        "consumable_id": "hierophant",
        "price": 0,
    })
    _assert_true(purchase["success"], "修习购买通过本局命令完成")
    _assert_equal(purchase["price"], 3, "修习价格由核心内容定义决定而不信任 UI 参数")
    _assert_equal(session.snapshot().value("experience"), 0, "修习购买后的历练进入只读快照")
    _assert_equal(session.snapshot().section("growth").get("consumable_ids"), ["hierophant"], "本局成长快照包含共享消耗品")

    var run_log: Array = session.snapshot().value("run_log", [])
    var system_log: Array = session.snapshot().value("system_log", [])
    _assert_true(run_log.size() >= 5, "建局、节点、修习和购买写入统一本局日志通道")
    _assert_true(not system_log.is_empty(), "被拒绝的本局命令写入统一系统日志通道")
    var events: Array = session.drain_events()
    _assert_true(events.size() >= 6, "本局会话公开一次性结构化事件流")
    _assert_equal(events[0].event_type(), "run_setup", "本局事件保留稳定的建局事件类型")
    _assert_true(session.drain_events().is_empty(), "本局事件被消费后不会重复播放")

    var battle_session = BattleSessionScript.new(CombatEngineScript.new())
    battle_session.use_game_log(session.game_log)
    _assert_true(battle_session.setup_battle({"content_seed": 2308}), "战斗会话可以复用本局日志实例")
    _assert_true(not session.game_log.entries("run").is_empty(), "建立战斗不会清除既有本局日志")
    _assert_true(not session.game_log.entries("system").is_empty(), "本局与战斗系统诊断进入同一日志序列")

    var boss_state = RunStateScript.new()
    boss_state.setup(8128)
    boss_state.current_node_id = boss_state.graph["boss_id"]
    boss_state.phase = "node_in_progress"
    var boss_session = RunSessionScript.new(boss_state)
    _assert_true(boss_session.execute({"type": "complete_node"})["success"], "Boss 节点完成也经过本局会话")
    _assert_equal(boss_session.snapshot().value("phase"), "boss_chest", "本局快照公开 Boss 宝箱阶段")
    _assert_true(boss_session.execute({"type": "complete_boss_chest"})["success"], "Boss 宝箱流程通过本局命令完成")
    _assert_equal(boss_session.snapshot().value("act"), 2, "Boss 宝箱命令推进到下一层")
    _assert_equal(boss_session.snapshot().value("run_log", []).size(), 2, "Boss 节点与宝箱流程均写入本局日志")

func _test_boss_chest_flow() -> void:
    var state = RunStateScript.new()
    state.setup(8128)
    state.current_node_id = state.graph["boss_id"]
    state.phase = "node_in_progress"
    var boss_result := state.complete_current_node()
    _assert_true(boss_result["success"], "第一层 Boss 节点可以完成")
    _assert_equal(state.phase, "boss_chest", "第一层 Boss 后进入不可见的第十七层 Boss 宝箱")
    _assert_true(not state.can_open_practice(), "Boss 宝箱流程中修习入口锁定")
    var chest_result := state.complete_boss_chest()
    _assert_true(chest_result["success"], "Boss 宝箱可以完成")
    _assert_equal(state.act, 2, "完成第一层 Boss 宝箱后进入第二层")
    _assert_equal(state.phase, "awaiting_node", "新层地图进入待选节点状态")
    _assert_true(state.can_open_practice(), "进入新层地图后修习入口开放")

    state.act = 3
    state.graph = state.map_generator.generate(state.seed, state.act)
    state.current_node_id = state.graph["boss_id"]
    state.phase = "node_in_progress"
    state.complete_current_node()
    _assert_equal(state.phase, "run_complete", "第三层 Boss 后直接完成本局且没有 Boss 宝箱")

func _test_run_state_battle_growth_persistence() -> void:
    var state = RunStateScript.new()
    state.setup(420)
    state.consumable_ids.append("aura")
    state.insight_multipliers = {"high_card": 2}
    var run_cards: Array = state.run_deck.create_battle_cards()
    for card in run_cards:
        if card.id == "wind_8":
            card.set_enhancement("bonus")
            card.set_finish("foil")
    state.run_deck.sync_from_battle_cards(run_cards)
    var engine = CombatEngineScript.new()
    engine.setup(420, false)
    state.apply_to_battle_side(engine.player)
    var modified = null
    for card in engine.player.draw_pile:
        if card.id == "wind_8":
            modified = card
            break
    _assert_true(modified != null, "本局牌组改造能应用到下一场战斗")
    _assert_equal(modified.reshape_enhancement, "bonus", "跨战斗保留真气强化")
    _assert_equal(modified.reshape_finish, "foil", "跨战斗保留真气品相")
    _assert_equal(engine.player.insight_multipliers.get("high_card", 0), 2, "跨战斗保留精确牌型心得倍率")
    _assert_equal(engine.player.consumable_ids, ["aura"], "跨战斗保留共享消耗品")
    modified.set_finish("polychrome")
    engine.player.consume_at(0)
    state.sync_from_battle_side(engine.player)
    _assert_equal(state.run_deck.card_data("wind_8")["reshapes"]["finish"], "polychrome", "战斗中的品相替换同步回本局 RunDeck")
    _assert_equal(state.consumable_ids.size(), 0, "战斗中使用消耗品后同步释放本局槽位")

func _test_map_practice_and_battle_scene_integration() -> void:
    var run_ui = RunScene.instantiate()
    run_ui.initialize_interface()
    root.add_child(run_ui)
    _assert_true(run_ui.practice_button != null, "地图场景建立右下角修习按钮")
    _assert_true(run_ui.map_scroll != null, "地图使用纵向滚动容器")
    _assert_true(
        run_ui.map_view._node_position(-1, 3).y > run_ui.map_view._node_position(0, 3).y,
        "单一旅程起点显示在第1层房间下方")
    _assert_equal(
        run_ui.map_view._node_description({"type": "start", "row": -1}),
        "旅程起点 · 选择上方第 1 层房间开始路线",
        "旅程起点悬停说明不显示为第0行")
    run_ui.map_view.size = Vector2(1100, 1700)
    _assert_true(
        run_ui.map_view._node_position(0, 6).x <= run_ui.map_view.size.x - 180.0,
        "地图右侧为修习按钮保留节点安全区")
    _assert_true(not run_ui.practice_button.disabled, "初始待选节点状态修习按钮可用")
    run_ui._open_practice()
    _assert_true(run_ui.practice_overlay.visible, "点击修习按钮打开卡片式修习页面")
    run_ui._close_practice()
    var first_node_id: String = str(run_ui.run_session.snapshot().value("available_node_ids", [])[0])
    run_ui._on_node_selected(first_node_id)
    _assert_equal(run_ui.run_session.snapshot().value("phase"), "node_in_progress", "地图选择战斗节点后进入未完成状态")
    _assert_true(run_ui.battle_layer.visible and run_ui.current_battle != null, "战斗节点接入现有战斗场景")
    _assert_equal(
        run_ui.current_battle.battle_configuration["content_id"],
        "representative_combat",
        "地图 UI 使用调度结果创建战斗而不自行选择内容")
    _assert_true(
        int(run_ui.current_battle.battle_configuration["content_seed"]) > 0,
        "地图 UI 将节点稳定内容种子传入战斗场景")
    _assert_true(run_ui.practice_button.disabled, "战斗节点进行中修习按钮锁定")
    run_ui._on_battle_finished("player_victory")
    _assert_equal(run_ui.run_session.snapshot().value("phase"), "awaiting_node", "战斗胜利后直接返回地图待选状态")
    _assert_equal(run_ui.run_session.snapshot().value("experience"), 3, "战斗胜利奖励显示为当前历练")
    _assert_true(
        run_ui.run_session.snapshot().value("run_log", []).size() >= 3,
        "地图、战斗节点完成与本局流程共用结构化日志")
    _assert_true(not run_ui.battle_layer.visible, "战斗胜利后关闭战斗层而不自动打开修习")
    _assert_true(not run_ui.practice_overlay.visible, "战斗胜利不会强制弹出修习页面")
    run_ui.queue_free()

func _assert_map_route_constraints(graph: Dictionary, label: String) -> void:
    var nodes_by_id: Dictionary = {}
    var incoming: Dictionary = {}
    var outgoing: Dictionary = {}
    var row_counts: Dictionary = {}
    var floor_entries: Array = []
    for node in graph["nodes"]:
        var node_id: String = str(node["id"])
        nodes_by_id[node_id] = node
        incoming[node_id] = []
        outgoing[node_id] = []
        var row: int = int(node["row"])
        row_counts[row] = int(row_counts.get(row, 0)) + 1
        if row == 0:
            floor_entries.append(node_id)
    var start_id := str(graph.get("start_id", ""))
    _assert_true(nodes_by_id.has(start_id), "%s：图中存在单一旅程起点" % label)
    _assert_equal(int(nodes_by_id[start_id]["row"]), -1, "%s：旅程起点位于第1层下方" % label)
    _assert_true(floor_entries.size() >= 1 and floor_entries.size() <= 6, "%s：第1层房间数量为一至六个" % label)
    for row in range(15):
        _assert_true(row_counts.get(row, 0) <= 6, "%s：第%d层最多六个节点" % [label, row + 1])

    var first_floor_destinations: Dictionary = {}
    for edge in graph["edges"]:
        incoming[str(edge["to"])].append(str(edge["from"]))
        outgoing[str(edge["from"])].append(str(edge["to"]))
        if int(edge["from_row"]) == 0:
            _assert_true(
                not first_floor_destinations.has(str(edge["to"])),
                "%s：首层不同节点不共享同一个第二层目的地" % label)
            first_floor_destinations[str(edge["to"])] = true
        var from_type: String = str(nodes_by_id[str(edge["from"])].get("generation_type", nodes_by_id[str(edge["from"])]["type"]))
        var to_type: String = str(nodes_by_id[str(edge["to"])].get("generation_type", nodes_by_id[str(edge["to"])]["type"]))
        if from_type in ["event_shop", "elite", "rest"]:
            _assert_true(from_type != to_type, "%s：精英与休息不沿路线连续" % label)

    _assert_equal(outgoing[start_id].size(), floor_entries.size(), "%s：单一起点连接全部第1层房间" % label)
    _assert_true(_map_can_reach(graph, start_id, graph["boss_id"]), "%s：旅程起点可以到达 Boss" % label)
    for entry_id in floor_entries:
        _assert_true(_map_can_reach(graph, entry_id, graph["boss_id"]), "%s：每个第1层房间都可到达 Boss" % label)

    for node_id in nodes_by_id:
        var node: Dictionary = nodes_by_id[node_id]
        var row: int = int(node["row"])
        var in_count: int = incoming[node_id].size()
        var out_count: int = outgoing[node_id].size()
        if row == -1:
            _assert_true(in_count == 0 and out_count >= 1 and out_count <= 6, "%s：单一起点只连接第1层房间" % label)
        elif row == 0:
            _assert_true(in_count == 1 and out_count >= 1 and out_count <= 3, "%s：第1层房间由单一起点进入" % label)
        elif row < 14:
            _assert_true(in_count >= 1 and in_count <= 3 and out_count >= 1 and out_count <= 3, "%s：中间节点入边与出边均为一至三条" % label)
        elif row == 14:
            _assert_true(in_count >= 1 and in_count <= 3 and out_count == 1, "%s：第十五层节点连接单一 Boss" % label)
        else:
            _assert_equal(out_count, 0, "%s：Boss 没有地图出边" % label)

    for left_index in range(graph["edges"].size()):
        var left: Dictionary = graph["edges"][left_index]
        if int(left["to_row"]) > 14:
            continue
        for right_index in range(left_index + 1, graph["edges"].size()):
            var right: Dictionary = graph["edges"][right_index]
            if int(left["from_row"]) != int(right["from_row"]):
                continue
            var crossing := (
                int(left["from_column"]) < int(right["from_column"])
                and int(left["to_column"]) > int(right["to_column"])) or (
                int(left["from_column"]) > int(right["from_column"])
                and int(left["to_column"]) < int(right["to_column"]))
            _assert_true(not crossing, "%s：相邻楼层连线不交叉" % label)

func _map_node_type(graph: Dictionary, node_id: String) -> String:
    for node in graph["nodes"]:
        if node["id"] == node_id:
            return str(node["type"])
    return ""

func _map_can_reach(graph: Dictionary, start_id: String, target_id: String) -> bool:
    var pending: Array = [start_id]
    var visited: Dictionary = {}
    while not pending.is_empty():
        var current: String = pending.pop_front()
        if current == target_id:
            return true
        if visited.has(current):
            continue
        visited[current] = true
        for edge in graph["edges"]:
            if edge["from"] == current:
                pending.append(str(edge["to"]))
    return false

func _hand_ids(cards: Array) -> Array:
    var ids: Array = []
    for card in cards:
        ids.append(card.id)
    return ids

func _test_scripted_enemy_is_deterministic_and_locked() -> void:
    var first = CombatEngineScript.new()
    var second = CombatEngineScript.new()
    _assert_true(first.setup_scripted_battle(2308), "第一个脚本场景载入")
    _assert_true(second.setup_scripted_battle(2308), "第二个脚本场景载入")
    first.start_player_turn()
    second.start_player_turn()
    _assert_equal(_hand_ids(first.enemy.hand), _hand_ids(second.enemy.hand), "相同种子敌方起手一致")
    _assert_equal(first.locked_enemy_card_ids, ["enemy:fire_2", "enemy:forest_4"], "第一回合敌方按 JSON 定义 ID 锁定唯一战斗实例")
    _assert_equal(first.locked_enemy_card_ids, second.locked_enemy_card_ids, "敌方锁定不依赖玩家选牌")

func _test_enemy_ai_plan_is_deterministic_and_hidden() -> void:
    var first = CombatEngineScript.new()
    var second = CombatEngineScript.new()
    _assert_true(first.setup_scripted_battle(2308, "res://data/scripted_battle.json", true), "第一个调试 AI 场景载入")
    _assert_true(second.setup_scripted_battle(2308, "res://data/scripted_battle.json", true), "第二个调试 AI 场景载入")
    first.start_player_turn()
    second.start_player_turn()
    _assert_equal(first.locked_enemy_card_ids, second.locked_enemy_card_ids, "相同种子与局面产生相同 AI 选牌")
    _assert_equal(first.enemy_plan, second.enemy_plan, "相同种子与局面产生相同公开计划")
    _assert_true(first.enemy_plan.has("damage"), "公开计划包含预计伤害")
    _assert_true(first.enemy_plan.has("defense"), "公开计划包含预计防御")
    _assert_true(first.enemy_plan.has("combo"), "公开计划包含连击提示")
    _assert_equal(first.enemy_plan["damage"], 6, "首击公开计划正确汇总三段预计伤害")
    _assert_equal(first.enemy_plan["defense"], 0, "首击公开计划正确显示零防御")
    _assert_true(not first.enemy_plan.has("hand"), "公开计划不包含具体牌型")
    _assert_true(not first.enemy_plan.has("cards"), "公开计划不包含具体真气")
    _assert_true(not first.enemy_plan.has("technique"), "公开计划不包含具体功法")

func _test_enemy_ai_uses_natural_combo() -> void:
    var engine = CombatEngineScript.new()
    engine.setup_scripted_battle(2308, "res://data/scripted_battle.json", true)
    engine.start_player_turn()
    engine.player.hand = [_card("2", "wind"), _card("3", "forest"), _card("4", "mountain")]
    engine.player.draw_pile.clear()
    _assert_true(engine.enemy_plan.get("combo", false), "AI 首击计划提示自然连击")
    var result := engine.confirm_play(_ids(engine.player.hand.slice(0, 2)))
    _assert_true(result["success"], "玩家混属性出牌后同步行动成功")
    _assert_true(engine.enemy_natural_combo_used, "敌方实际触发自然连击")
    _assert_equal(engine.enemy.discard_pile.size(), 2, "玩家无连击时敌方自动使用单方连击")
    _assert_equal(engine.enemy_actions_available, 0, "敌方单方连击已经消耗")

func _test_both_sides_use_synchronized_combo() -> void:
    var engine = CombatEngineScript.new()
    engine.setup_scripted_battle(2308, "res://data/scripted_battle.json", true)
    engine.start_player_turn()
    engine.player.hand = [_card("2", "wind"), _card("3", "forest"), _card("4", "mountain")]
    engine.player.draw_pile.clear()
    engine.confirm_play([engine.player.hand[0].id])
    _assert_equal(engine.actions_available, 1, "玩家单属性首击获得一次连击")
    _assert_equal(engine.enemy_actions_available, 1, "敌方单属性首击获得一次连击")
    _assert_equal(engine.enemy.discard_pile.size(), 1, "双方连击时敌方等待下一次同步出牌")
    _assert_equal(engine.enemy_plan["damage"], 0, "敌方第二击计划随功法序列更新为零伤害")
    _assert_equal(engine.enemy_plan["defense"], 11, "敌方第二击计划公开预计获得防御")
    engine.confirm_play([engine.player.hand[0].id])
    _assert_equal(engine.enemy.discard_pile.size(), 2, "双方第二击完成同步连击")
    _assert_equal(engine.enemy_actions_available, 0, "敌方自然连击不会重复触发")

func _test_ai_battle_reaches_terminal_state() -> void:
    var engine = CombatEngineScript.new()
    engine.setup_scripted_battle(2308, "res://data/scripted_battle.json", true)
    engine.start_player_turn()
    var steps := 0
    var all_actions_succeeded := true
    while engine.battle_state == "active" and steps < 200:
        if engine.actions_available > 0 and not engine.player.hand.is_empty():
            var result: Dictionary = engine.confirm_play([engine.player.hand[0].id])
            all_actions_succeeded = all_actions_succeeded and result.get("success", false)
        else:
            engine.end_player_turn()
            if engine.battle_state == "active":
                engine.start_player_turn()
        steps += 1
    _assert_true(all_actions_succeeded, "完整调试 AI 战斗中玩家动作均能结算")
    _assert_true(engine.battle_state != "active", "完整调试 AI 战斗在安全步数内结束")
    _assert_true(engine.battle_state != "scenario_error", "完整调试 AI 战斗不发生场景错误")

func _install_sync_guard(engine) -> void:
    engine.repository.techniques["sync_guard"] = {
        "id": "sync_guard",
        "name": "同步护身测试",
        "pool": "high",
        "effects": [
            {"op": "defense", "amount": {"kind": "power"}},
            {"op": "damage", "amount": {"kind": "power"}},
        ],
    }
    engine.sequence_book.configure({"high_card": ["sync_guard"]})
    engine.enemy_sequence_book.configure({"high_card": ["sync_guard"]})

func _scripted_engine_with_player_high(rank: String = "5"):
    var engine = CombatEngineScript.new()
    engine.setup_scripted_battle(2308)
    engine.start_player_turn()
    engine.player.hand = [_card(rank, "mountain"), _card("3", "forest")]
    engine.player.draw_pile.clear()
    return engine

func _test_synchronized_defense_before_damage() -> void:
    var engine = _scripted_engine_with_player_high("5")
    _install_sync_guard(engine)
    var result := engine.confirm_play([engine.player.hand[0].id])
    _assert_true(result["success"], "同步出牌成功")
    _assert_equal(result["enemy_preview"]["hand"]["id"], "high_card", "敌方揭示后识别牌型")
    _assert_equal(engine.player.life, 100, "敌方伤害先被我方本击建立的防御吸收")
    _assert_equal(engine.player.defense, 1, "我方五点防御承受敌方四点伤害")
    _assert_equal(engine.enemy.life, 99, "敌方先建立四点防御后只损失一点生命")
    _assert_equal(engine.enemy.defense, 0, "敌方本击防御被我方伤害耗尽")
    _assert_equal(engine.sequence_book.position("high_card"), 0, "单门我方序列循环回第一门")
    _assert_equal(engine.enemy_sequence_book.position("high_card"), 0, "敌我序列分别推进")

func _install_lethal_strike(engine) -> void:
    engine.repository.techniques["sync_lethal"] = {
        "id": "sync_lethal",
        "name": "同步致命测试",
        "pool": "high",
        "effects": [{"op": "damage", "amount": {"kind": "power"}}],
    }
    engine.sequence_book.configure({"high_card": ["sync_lethal"]})
    engine.enemy_sequence_book.configure({"high_card": ["sync_lethal"]})

func _test_synchronized_lethal_and_battle_results() -> void:
    var unresolved = _scripted_engine_with_player_high("5")
    _install_lethal_strike(unresolved)
    unresolved.player.life = 4
    unresolved.enemy.life = 5
    var unresolved_result := unresolved.confirm_play([unresolved.player.hand[0].id])
    _assert_true(unresolved_result["success"], "双方致命同步行动成功")
    _assert_equal(unresolved.player.life, 0, "敌方即使同击被击倒仍完成已锁定伤害")
    _assert_equal(unresolved.enemy.life, 0, "我方同步伤害击倒敌方")
    _assert_equal(unresolved.battle_state, "unresolved_draw", "同归于尽不擅自判定胜负")

    var victory = _scripted_engine_with_player_high("9")
    _install_lethal_strike(victory)
    victory.enemy.life = 3
    victory.confirm_play([victory.player.hand[0].id])
    _assert_equal(victory.battle_state, "player_victory", "敌方生命归零判定胜利")

    var exhausted = _scripted_engine_with_player_high("2")
    _install_lethal_strike(exhausted)
    exhausted.player.hand = [exhausted.player.hand[0]]
    exhausted.player.draw_pile.clear()
    exhausted.confirm_play([exhausted.player.hand[0].id])
    _assert_equal(exhausted.battle_state, "player_defeat", "无手牌无牌库且敌人存活判负")

func _test_data_driven_lethal_gu_needle() -> void:
    var selected := [_card("9", "wind")]
    var engine = _engine_with_hand(selected + [_card("3", "forest")])
    var poison_target = _card("7", "fire")
    engine.enemy.hand = [poison_target]
    engine.sequence_book.configure({"high_card": ["lethal_gu_needle"]})
    var result := engine.confirm_play(_ids(selected))
    _assert_true(result["technique_triggered"], "烈蛊飞针由数据效果接口触发")
    _assert_equal(engine.enemy.life, 96, "烈蛊飞针造成 floor(P/2) 伤害")
    _assert_true(poison_target.has_anomaly("poison", "lethal_poison"), "烈蛊飞针为对手手牌附烈毒")
    _assert_equal(engine.enemy.stacks.get("gu_mark", 0), 1, "纯风且实际附毒后获得蛊印")

func _poison_chain_engine(with_gu: bool):
    var engine = CombatEngineScript.new()
    engine.setup(5150, false)
    engine.scripted_mode = true
    engine.actions_available = 1
    engine.enemy_actions_available = 1
    engine.sequence_book.configure({"high_card": []})
    engine.enemy_sequence_book.configure({"high_card": []})
    engine.player.hand = [_card("2", "mountain"), _card("3", "forest")]
    engine.player.draw_pile.clear()
    var poisoned = _card("7", "fire")
    poisoned.set_anomaly("poison", "lethal_poison")
    var companion = _card("4", "forest")
    engine.enemy.hand = [poisoned, companion]
    engine.enemy.draw_pile.clear()
    engine.locked_enemy_card_ids = [poisoned.id, companion.id]
    if with_gu:
        engine.enemy.stacks["gu_mark"] = 1
    return {"engine": engine, "poisoned": poisoned, "player_card": engine.player.hand[0]}

func _test_lethal_poison_and_gu_recycle_chain() -> void:
    var without_gu: Dictionary = _poison_chain_engine(false)
    var plain_engine = without_gu["engine"]
    plain_engine.confirm_play([without_gu["player_card"].id])
    _assert_equal(plain_engine.enemy.life, 93, "烈毒按真气值造成普通伤害")
    _assert_true(plain_engine.enemy.discard_pile.has(without_gu["poisoned"]), "没有蛊印时毒牌正常进入弃牌堆")
    _assert_true(not without_gu["poisoned"].has_anomaly("poison"), "烈毒触发后移除")

    var with_gu: Dictionary = _poison_chain_engine(true)
    var gu_engine = with_gu["engine"]
    gu_engine.confirm_play([with_gu["player_card"].id])
    _assert_equal(gu_engine.enemy.life, 93, "蛊印不取消本次烈毒伤害")
    _assert_equal(gu_engine.enemy.stacks.get("gu_mark", 0), 0, "烈毒结算后消耗一层蛊印")
    _assert_true(gu_engine.enemy.draw_pile.has(with_gu["poisoned"]), "蛊印使毒牌洗回对手牌库")
    _assert_true(not gu_engine.enemy.discard_pile.has(with_gu["poisoned"]), "洗回牌不留在弃牌堆")
    _assert_true(with_gu["poisoned"].has_anomaly("poison", "lethal_poison"), "洗回牌重新获得同种烈毒")

func _test_scripted_poison_demo_reaches_recycle() -> void:
    var engine = CombatEngineScript.new()
    engine.setup_scripted_battle(2308)
    engine.start_player_turn()
    var first_wind = null
    for card in engine.player.hand:
        if card.attribute == "wind":
            first_wind = card
            break
    _assert_true(first_wind != null, "固定种子起手存在风牌用于一线悬蛊")
    engine.confirm_play([first_wind.id])
    engine.end_player_turn()
    engine.start_player_turn()
    engine.confirm_play([engine.player.hand[0].id])
    var poisoned = engine.enemy.find_hand_card("enemy:mountain_3")
    _assert_true(poisoned != null and poisoned.has_anomaly("poison", "lethal_poison"), "固定场景第二回合将山3附烈毒")
    var gu_before := int(engine.enemy.stacks.get("gu_mark", 0))
    engine.end_player_turn()
    engine.start_player_turn()
    _assert_true(engine.locked_enemy_card_ids.has("enemy:mountain_3"), "第三回合脚本锁定带毒山3实例")
    engine.confirm_play([engine.player.hand[0].id])
    _assert_equal(engine.enemy.stacks.get("gu_mark", 0), gu_before - 1, "场景实战链消耗一层蛊印")
    _assert_true(engine.enemy.draw_pile.has(poisoned), "场景实战链将山3洗回牌库")
    _assert_true(poisoned.has_anomaly("poison", "lethal_poison"), "场景洗回山3继续携带烈毒")
