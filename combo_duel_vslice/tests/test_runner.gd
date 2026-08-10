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
const DefenseRetentionPolicyScript = preload(
    "res://core/defense_retention_policy.gd")
const StatusSystemScript = preload("res://core/status_system.gd")
const StatusBehaviorRegistryScript = preload(
    "res://core/statuses/status_behavior_registry.gd")
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
const AiSettingsServiceScript = preload("res://core/ai/ai_settings_service.gd")
const AiDecisionGatewayScript = preload("res://core/ai/ai_decision_gateway.gd")
const AiPromptEncoderScript = preload("res://core/ai/ai_prompt_encoder.gd")
const AiResponseValidatorScript = preload("res://core/ai/ai_response_validator.gd")
const MockAiProviderScript = preload("res://core/ai/providers/mock_ai_provider.gd")
const AiProviderSettingsScript = preload("res://core/ai/providers/ai_provider_settings.gd")
const ChatCompletionsAiProviderScript = preload("res://core/ai/providers/chat_completions_ai_provider.gd")
const AiProviderFactoryScript = preload("res://core/ai/providers/ai_provider_factory.gd")
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
const RunSaveDataScript = preload("res://core/run_save_data.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const ContentValidatorScript = preload("res://core/content_validator.gd")
const TechniqueRepositoryScript = preload("res://core/technique_repository.gd")
const StarterBuildAssemblerScript = preload("res://core/starter_build_assembler.gd")
const GameCompositionRootScript = preload("res://core/game_composition_root.gd")
const EnemyRepositoryScript = preload("res://core/enemy_repository.gd")
const EnemyDeckEncodingScript = preload("res://core/enemy_deck_encoding.gd")
const NodeRewardServiceScript = preload("res://core/node_reward_service.gd")
const RunEffectHandlerRegistryScript = preload(
    "res://core/run_effects/run_effect_handler_registry.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")
const PracticeServiceScript = preload("res://core/practice_service.gd")
const EffectExecutorScript = preload("res://core/effect_executor.gd")
const EffectHandlerRegistryScript = preload(
    "res://core/effects/effect_handler_registry.gd")
const BattleScene = preload("res://ui/main.tscn")
const RunScene = preload("res://ui/run_main.tscn")
const FrontScene = preload("res://ui/front_main.tscn")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const CardReshapeBehaviorRegistryScript = preload(
    "res://core/card_reshapes/card_reshape_behavior_registry.gd")
const CardReshapeBehaviorContextScript = preload(
    "res://core/card_reshapes/card_reshape_behavior_context.gd")
const CardReshapeBehaviorHandlerScript = preload(
    "res://core/card_reshapes/card_reshape_behavior_handler.gd")
const ConsumableEffectHandlerRegistryScript = preload(
    "res://core/consumables/consumable_effect_handler_registry.gd")
const ConsumableUseServiceScript = preload(
    "res://core/consumables/consumable_use_service.gd")
const CardWorkshopServiceScript = preload("res://core/card_workshop_service.gd")
const CardOriginServiceScript = preload("res://core/card_origin_service.gd")

const ProbeEffectHandlerScript = preload("res://tests/support/probe_effect_handler.gd")
const ProbeStatusBehaviorHandlerScript = preload(
    "res://tests/support/probe_status_behavior_handler.gd")

class TimingProbe:
    extends RefCounted

    var calls: Array[String] = []

    func record(event, label: String) -> Dictionary:
        calls.append("%s:%s:%d" % [event.timing, label, event.serial])
        return {"success": true, "detail": label}

class DefenseRetentionProbe:
    extends RefCounted

    var target
    var additional_percent: int
    var prevents_decay: bool

    func _init(
            target_value,
            additional_percent_value: int = 0,
            prevents_decay_value: bool = false) -> void:
        target = target_value
        additional_percent = additional_percent_value
        prevents_decay = prevents_decay_value

    func defense_retention_modifier(side, _context: Dictionary) -> Dictionary:
        if side != target:
            return {}
        return {
            "additional_retention_percent": additional_percent,
            "prevent_decay": prevents_decay,
        }

class RunEffectProbeHandler:
    extends RefCounted

    var _operation_ids: Array
    var _fail_on_apply: bool

    func _init(operation_ids_value: Array, fail_on_apply: bool = false) -> void:
        _operation_ids = operation_ids_value.duplicate()
        _fail_on_apply = fail_on_apply

    func operation_ids() -> Array:
        return _operation_ids.duplicate()

    func validate_effect(effect: Dictionary, validator, scope: String) -> void:
        if not effect.get("amount") is int:
            validator.report_error(scope + ".amount", "探针 amount 必须是整数")

    func apply(effect: Dictionary, context) -> Dictionary:
        if _fail_on_apply:
            return {"success": false, "reason": "探针按约定失败"}
        var amount := int(effect["amount"])
        context.growth.experience += amount
        return {
            "success": true,
            "applied": {
                "op": str(effect["op"]),
                "kind": "test_probe",
                "amount": amount,
            },
        }

class CardReshapeProbeHandler:
    extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

    var id: String

    func _init(id_value: String = "probe_add_value") -> void:
        id = id_value

    func behavior_id() -> String:
        return id

    func triggers() -> Array[String]:
        return ["card_contribution"]

    func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
        if not behavior.get("amount") is int:
            validator.report_error(scope + ".amount", "探针 amount 必须是整数")

    func execute(behavior: Dictionary, context) -> Dictionary:
        context.value += int(behavior.get("amount", 0))
        return {"success": true, "value": context.value}

class ConsumableProbeHandler:
    extends RefCounted

    var _operation_ids: Array
    var _fail_on_apply: bool

    func _init(operation_ids_value: Array, fail_on_apply: bool = false) -> void:
        _operation_ids = operation_ids_value.duplicate()
        _fail_on_apply = fail_on_apply

    func operation_ids() -> Array:
        return _operation_ids.duplicate()

    func validate_effect(effect: Dictionary, context, scope: String) -> void:
        if not effect.get("amount") is int:
            context.report_error(scope + ".amount", "探针 amount 必须是整数")

    func apply(effect: Dictionary, context) -> Dictionary:
        if _fail_on_apply:
            return {"success": false, "reason": "探针按约定失败"}
        var amount := int(effect["amount"])
        context.growth.experience += amount
        return {
            "success": true,
            "applied": {
                "op": str(effect["op"]),
                "kind": "consumable_probe",
                "amount": amount,
                "details": ["探针消耗品效果 +%d" % amount],
            },
        }

var failures: Array[String] = []
var assertions: int = 0
var card_serial: int = 0

func _initialize() -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    _test_content_catalog_and_validator()
    _test_card_reshape_behavior_registry()
    _test_enemy_pool_content_and_repository()
    _test_production_formal_sequences_and_damage()
    _test_formal_enemy_pool_battle_setup()
    _test_production_enemy_pool_remote_ai_battle()
    _test_formal_production_technique_behaviors()
    _test_starter_build_assembly_and_composition_root()
    _test_node_reward_service_contract()
    _test_run_effect_platform_contract()
    _test_run_card_workshop_effects()
    _test_awakening_origin_persistence_contract()
    _test_qi_instance_state_contract()
    _test_run_deck_contract()
    _test_card_zone_service_contract()
    _test_battle_flow_coordinator_contract()
    _test_battle_timing_system_contract_and_integration()
    _test_defense_retention_policy_and_round_decay()
    _test_awakening_battle_runtime()
    _test_awakening_group_completion_paths()
    _test_f2d2_formal_enhancement_runtime()
    _test_f2d2_opportunity_freeze_and_progress_sync()
    _test_f2e1_formal_imprint_runtime_and_persistence()
    _test_status_behavior_registry_contract()
    _test_status_system_contract()
    _test_declared_card_status_runtime_semantics()
    _test_action_controller_boundaries_and_strategy()
    _test_remote_ai_module_contract()
    _test_chat_completions_provider_contract()
    _test_ai_settings_and_conversation_disk_contract()
    _test_remote_ai_action_window_session_gate()
    _test_effect_handler_registry_contract()
    _test_effect_extension_entry_contract()
    _test_standard_deck()
    _test_pool_structure_and_turn_draw_rules()
    _test_active_hand_types_and_same_attribute_rules()
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
    _test_battle_consumable_multi_effect_rollback()
    _test_insight_growth_and_technique_acquisition()
    _test_formal_practice_shop_and_hand_progression()
    _test_zengyuan_pill_enhancement_and_preview()
    _test_simple_reshape_behaviors()
    _test_battle_consumable_reshape_persists_via_run_deck()
    _test_consumable_effect_registry_contract()
    _test_consumable_effect_validation_scope()
    _test_run_consumable_high_card_insight()
    _test_run_consumable_insight_exhausted_pool()
    _test_run_consumable_zengyuan_pill()
    _test_run_consumable_origin_and_save()
    _test_run_consumable_invalid_targets()
    _test_run_consumable_transaction_rollback()
    _test_run_consumable_failed_use_keeps_randomness()
    _test_run_consumable_slot_release_order()
    _test_run_consumable_phase_gate()
    _test_run_consumable_save_round_trip()
    _test_consumable_no_central_op_branches()
    _test_run_save_life_round_trip_legacy_defaults_and_validation()
    _test_battle_session_commands_snapshots_and_events()
    _test_snapshot_boundaries_are_typed()
    _test_map_generation_is_deterministic_and_constrained()
    _test_map_routes_reach_boss_without_crossing()
    _test_node_dispatcher_is_data_driven_and_deterministic()
    _test_run_state_node_and_practice_gate()
    _test_run_service_boundaries_and_progress_snapshot()
    _test_run_session_commands_snapshots_events_and_logs()
    _test_experience_interest_node_settlement()
    _test_boss_chest_flow()
    _test_layered_life_progression_and_battle_persistence()
    _test_run_state_battle_growth_persistence()
    _test_map_practice_and_battle_scene_integration()
    _test_battle_scene_prefers_injected_session_and_keeps_standalone_fallback()
    _test_front_menu_and_starter_build_flow()
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

func _test_card_reshape_behavior_registry() -> void:
    var registry = CardReshapeBehaviorRegistryScript.new()
    var probe = CardReshapeProbeHandler.new()
    _assert_true(registry.register_handler(probe), "测试重塑行为可以注入注册表")
    var invalid_registry = CardReshapeBehaviorRegistryScript.new()
    invalid_registry.register_handler(CardReshapeProbeHandler.new())
    _assert_true(
        not invalid_registry.register_handler(CardReshapeProbeHandler.new()),
        "重复重塑行为 ID 注册失败")
    _assert_true(
        not invalid_registry.register_handler(CardReshapeProbeHandler.new("Bad-ID")),
        "非法重塑行为 ID 注册失败")
    _assert_true(
        not invalid_registry.register_handler(CardReshapeProbeHandler.new("")),
        "空重塑行为 ID 注册失败")

    var catalog = ContentCatalogScript.new(
        RuntimeProfileScript.test(), null, null, registry)
    var base_catalog = ContentCatalogScript.new()
    _assert_true(base_catalog.load_all(), "建立重塑行为测试基线内容目录")
    var values := _catalog_definitions(base_catalog)
    values["card_states"]["enhancements"][0]["behaviors"] = [{
        "trigger": "card_contribution",
        "priority": 100,
        "handler": "probe_add_value",
        "amount": 5,
    }]
    _assert_true(
        catalog.load_from_definitions(values, base_catalog.paths),
        "内容定义可以绑定测试重塑行为")
    var probe_card = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_7"), "probe:wind_7")
    catalog.card_reshape_rules.bind_card(probe_card)
    probe_card.set_enhancement("qi_boost")
    var preview_values := PowerCalculatorScript.calculate(
        HandEvaluatorScript.evaluate([probe_card]))
    _assert_equal(
        preview_values["card_total"], 12,
        "测试重塑 Handler 可以改变真实功法值而不改 PowerCalculator")

    var wild_card = DeckFactoryScript.create_card_instance(
        base_catalog.get_by_id("card", "wind_7"), "reshape:hunyuan")
    base_catalog.card_reshape_rules.bind_card(wild_card)
    wild_card.set_enhancement("hunyuan")
    _assert_true(
        wild_card.is_attribute("wind") and wild_card.is_attribute("fire"),
        "混元通过行为绑定同时识别所有属性")
    var boosted_card = DeckFactoryScript.create_card_instance(
        base_catalog.get_by_id("card", "wind_7"), "reshape:qi_boost")
    base_catalog.card_reshape_rules.bind_card(boosted_card)
    boosted_card.set_enhancement("qi_boost")
    _assert_equal(boosted_card.effective_qi_value(), 15, "增元通过行为绑定增加八点有效真气")
    var momentum_card = DeckFactoryScript.create_card_instance(
        base_catalog.get_by_id("card", "wind_7"), "reshape:momentum")
    base_catalog.card_reshape_rules.bind_card(momentum_card)
    momentum_card.set_enhancement("momentum")
    _assert_equal(momentum_card.reshape_multiplier_bonus(), 1, "乘势通过行为绑定增加一点功法倍率")

    var unknown_values := _catalog_definitions(base_catalog)
    unknown_values["card_states"]["enhancements"][0]["behaviors"] = [{
        "trigger": "card_contribution",
        "handler": "missing_reshape_handler",
        "amount": 1,
    }]
    var unknown_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_catalog.load_from_definitions(unknown_values, base_catalog.paths),
        "未知重塑行为处理器在内容加载阶段失败")
    _assert_true(
        _array_contains_text(unknown_catalog.errors, "card_states.enhancements[0].behaviors[0].handler"),
        "未知重塑行为错误报告内容路径")

    var bad_parameter_values := _catalog_definitions(base_catalog)
    bad_parameter_values["card_states"]["enhancements"][0]["behaviors"] = [{
        "trigger": "card_contribution",
        "handler": "add_card_contribution",
        "amount": "two",
    }]
    var bad_parameter_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_parameter_catalog.load_from_definitions(
            bad_parameter_values, base_catalog.paths),
        "重塑行为参数错误在内容加载阶段失败")
    _assert_true(
        _array_contains_text(
            bad_parameter_catalog.errors,
            "card_states.enhancements[0].behaviors[0].amount"),
        "重塑行为参数错误报告内容路径")

    var missing_priority_values := _catalog_definitions(base_catalog)
    missing_priority_values["card_states"]["enhancements"][0]["behaviors"] = [{
        "trigger": "effective_qi",
        "handler": "add_effective_qi",
        "amount": 2,
    }]
    var missing_priority_catalog = ContentCatalogScript.new()
    _assert_true(
        not missing_priority_catalog.load_from_definitions(
            missing_priority_values, base_catalog.paths),
        "数值重塑行为缺少 priority 时内容加载失败")
    _assert_true(
        _array_contains_text(
            missing_priority_catalog.errors,
            "card_states.enhancements[0].behaviors[0].priority"),
        "数值优先级错误稳定报告内容路径")

    var unknown_anomaly_values := _catalog_definitions(base_catalog)
    for behavior in unknown_anomaly_values["card_states"]["origins"][2]["behaviors"]:
        if behavior.get("handler", "") == "apply_anomaly":
            behavior["anomaly"] = "missing_anomaly"
    var unknown_anomaly_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_anomaly_catalog.load_from_definitions(
            unknown_anomaly_values, base_catalog.paths),
        "重塑行为引用未知异状时内容加载失败")
    _assert_true(
        _array_contains_text(
            unknown_anomaly_catalog.errors,
            "card_states.origins[2].behaviors[3].anomaly"),
        "重塑异状引用错误稳定报告内容路径")

func _test_content_catalog_and_validator() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "统一内容目录一次性载入并通过全部校验")
    _assert_equal(catalog.errors, [], "当前内容数据没有校验错误")
    _assert_equal(catalog.definition("base_deck")["version"], 1, "内容数据带顶层版本")
    _assert_equal(catalog.definition("card_states")["version"], 8, "真气重塑与异状数据带顶层版本")
    _assert_equal(catalog.definition("starter_builds")["version"], 1, "初始构筑数据带顶层版本")
    _assert_equal(catalog.definition("consumables")["version"], 3, "消耗品与修习商品数据带顶层版本")
    var act_progression: Dictionary = catalog.definition("act_progression")
    _assert_equal(act_progression["acts"].size(), 3, "生命成长内容完整声明三层数据")
    _assert_equal(act_progression["acts"][0]["player"]["max_life"], 100, "第一层玩家生命上限来自成长内容")
    _assert_equal(act_progression["acts"][1]["enemies"]["elite"]["max_life"], 225, "成长内容同时保留第二层精英生命")
    _assert_equal(act_progression["acts"][2]["enemies"]["boss"]["max_life"], 450, "成长内容同时保留第三层 Boss 生命")
    _assert_equal(catalog.all_of("starter_build").size(), 1, "当前只开放一套初始构筑")
    _assert_equal(catalog.get_by_id("starter_build", "standard_52")["card_count"], 52, "唯一初始构筑为标准52张牌组")
    _assert_equal(
        catalog.get_by_id("starter_build", "standard_52")["card_ids"].size(),
        52,
        "标准初始构筑显式声明 52 个真气 ID")
    _assert_equal(catalog.all_of("card").size(), 52, "内容目录建立 52 张唯一基础真气索引")
    _assert_equal(catalog.all_of("origin").size(), 3, "内容目录建立三种正式本源索引")
    _assert_equal(catalog.all_of("enhancement").size(), 8, "内容目录建立八种正式强化索引")
    _assert_equal(catalog.all_of("imprint").size(), 3, "内容目录建立三种正式印记索引")
    _assert_equal(catalog.all_of("anomaly").size(), 13, "内容目录建立十三种战斗异状索引")
    _assert_equal(catalog.all_of("actor_status").size(), 8, "内容目录建立八种角色战斗状态索引")
    _assert_equal(catalog.get_by_id("anomaly", "lethal_poison")["category"], "poison", "烈毒定义归入唯一毒槽")
    _assert_equal(
        catalog.get_by_id("anomaly", "purification")["on_apply"],
        "suppress_existing_effects",
        "净化通过内容策略声明获得时生命周期")
    _assert_equal(catalog.get_by_id("technique", "fire_sparks")["name"], "火星连点", "可按类型与 ID 查询功法")
    _assert_equal(catalog.get_by_id("technique", "stagnant_gu_conceal_breath")["name"], "郁蛊敛息", "郁蛊敛息进入统一功法目录")
    _assert_equal(catalog.get_by_id("technique", "borrow_fire_guard_heart")["name"], "借火护心", "借火护心进入统一功法目录")

    var legacy_finish_values := _catalog_definitions(catalog)
    legacy_finish_values["card_states"]["reshape_categories"][0] = {
        "id": "finish", "capacity": 1, "replaceable": true}
    legacy_finish_values["card_states"]["finishes"] = [{"id": "foil", "name": "旧品相"}]
    var legacy_finish_catalog = ContentCatalogScript.new()
    _assert_true(
        not legacy_finish_catalog.load_from_definitions(legacy_finish_values),
        "旧 finish/finishes/foil 内容被明确拒绝")
    _assert_true(
        _array_contains_text(legacy_finish_catalog.errors, "旧品相字段已废弃"),
        "旧品相拒绝报告明确迁移原因")
    var legacy_consumable_values := _catalog_definitions(catalog)
    legacy_consumable_values["consumables"]["consumables"][1]["effects"] = [{
        "op": "apply_random_finish", "finishes": ["foil"]}]
    var legacy_consumable_catalog = ContentCatalogScript.new()
    _assert_true(
        not legacy_consumable_catalog.load_from_definitions(legacy_consumable_values),
        "旧随机品相消耗品语法被拒绝")
    _assert_true(
        _array_contains_text(legacy_consumable_catalog.errors, "未注册的消耗品效果操作：apply_random_finish"),
        "旧消耗品操作报告具名错误")

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

    _assert_equal(
        ContentValidatorScript.POOL_IDS,
        ["high", "pair", "three", "straight", "bomb"],
        "运行内容只承认五个新基础功法池 ID")
    for old_pool_id in ["pair_two_pair", "three_full_house", "four_five"]:
        var legacy_pool_values := _catalog_definitions(catalog)
        legacy_pool_values["techniques"]["techniques"][0]["pool"] = old_pool_id
        var legacy_pool_catalog = ContentCatalogScript.new()
        _assert_true(
            not legacy_pool_catalog.load_from_definitions(legacy_pool_values),
            "旧功法池 ID %s 在正式内容加载时失败" % old_pool_id)
        _assert_true(
            _array_contains_text(legacy_pool_catalog.errors, "引用未知功法池 %s" % old_pool_id),
            "旧功法池 ID %s 报告明确错误" % old_pool_id)

    var missing_version_values := _catalog_definitions(catalog)
    missing_version_values["consumables"].erase("version")
    var missing_version_catalog = ContentCatalogScript.new()
    _assert_true(not missing_version_catalog.load_from_definitions(missing_version_values), "缺少内容版本被拒绝")
    _assert_true(_array_contains_text(missing_version_catalog.errors, "缺少版本字段 version"), "版本错误稳定定位")

    var unknown_target_zone_values := _catalog_definitions(catalog)
    unknown_target_zone_values["consumables"]["consumables"][0]["targeting"]["zone"] = "hand"
    var unknown_target_zone_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_target_zone_catalog.load_from_definitions(unknown_target_zone_values),
        "未知消耗品目标区域在加载阶段失败")
    _assert_true(
        _array_contains_text(unknown_target_zone_catalog.errors, "未知目标区域 hand"),
        "未知消耗品目标区域错误稳定定位")

    var unknown_target_selection_values := _catalog_definitions(catalog)
    unknown_target_selection_values["consumables"]["consumables"][0]["targeting"]["selection"] = "manual"
    var unknown_target_selection_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_target_selection_catalog.load_from_definitions(unknown_target_selection_values),
        "未知消耗品目标选择方式在加载阶段失败")
    _assert_true(
        _array_contains_text(unknown_target_selection_catalog.errors, "未知目标选择方式 manual"),
        "未知消耗品目标选择方式错误稳定定位")

    var none_minimum_values := _catalog_definitions(catalog)
    none_minimum_values["consumables"]["consumables"][0]["targeting"]["minimum"] = 1
    var none_minimum_catalog = ContentCatalogScript.new()
    _assert_true(
        not none_minimum_catalog.load_from_definitions(none_minimum_values),
        "none 区域 minimum 非零在加载阶段失败")
    _assert_true(
        _array_contains_text(none_minimum_catalog.errors, "none 区域 minimum 必须为 0"),
        "none 区域 minimum 错误稳定定位")

    var none_maximum_values := _catalog_definitions(catalog)
    none_maximum_values["consumables"]["consumables"][0]["targeting"]["maximum"] = 1
    var none_maximum_catalog = ContentCatalogScript.new()
    _assert_true(
        not none_maximum_catalog.load_from_definitions(none_maximum_values),
        "none 区域 maximum 非零在加载阶段失败")
    _assert_true(
        _array_contains_text(none_maximum_catalog.errors, "none 区域 maximum 必须为 0"),
        "none 区域 maximum 错误稳定定位")

    var run_deck_selection_values := _catalog_definitions(catalog)
    run_deck_selection_values["consumables"]["consumables"][1]["targeting"]["selection"] = "first"
    var run_deck_selection_catalog = ContentCatalogScript.new()
    _assert_true(
        not run_deck_selection_catalog.load_from_definitions(run_deck_selection_values),
        "run_deck 非法选择方式在加载阶段失败")
    _assert_true(
        _array_contains_text(run_deck_selection_catalog.errors, "未知目标选择方式 first"),
        "run_deck 非法选择方式错误稳定定位")

    var missing_life_values := _catalog_definitions(catalog)
    missing_life_values["act_progression"]["acts"][0]["player"].erase("max_life")
    var missing_life_catalog = ContentCatalogScript.new()
    _assert_true(
        not missing_life_catalog.load_from_definitions(missing_life_values),
        "生命成长缺少具名字段时内容加载失败")
    _assert_true(
        _array_contains_text(
            missing_life_catalog.errors,
            "act_progression.acts[0].player.max_life"),
        "生命成长缺字段错误稳定定位到玩家生命上限")

    var missing_act_values := _catalog_definitions(catalog)
    missing_act_values["act_progression"]["acts"].remove_at(2)
    var missing_act_catalog = ContentCatalogScript.new()
    _assert_true(
        not missing_act_catalog.load_from_definitions(missing_act_values),
        "生命成长层数不全时内容加载失败")
    _assert_true(
        _array_contains_text(missing_act_catalog.errors, "缺少第 3 层生命定义"),
        "生命成长缺层错误具名报告第三层")

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

    var production_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.production())
    _assert_true(
        production_catalog.load_all(),
        "production 正式功法序列通过内容校验：%s" % str(production_catalog.errors))
    var production_repository = TechniqueRepositoryScript.new()
    _assert_true(
        production_repository.configure(
            production_catalog.definition("techniques"), true),
        "功法仓库载入显式接入档位")
    var production_sequences: Dictionary = production_catalog.definition("sequences")
    for hand_id in ContentValidatorScript.HAND_IDS:
        if hand_id == "five_kind":
            _assert_equal(
                production_sequences[hand_id],
                [],
                "五条正式序列是受规则允许的显式空数组")
            continue
        _assert_true(
            not production_sequences[hand_id].is_empty(),
            "production %s 开局序列非空" % hand_id)
        for technique_id_value in production_sequences[hand_id]:
            var technique_id := str(technique_id_value)
            _assert_true(
                production_repository.is_formally_complete(technique_id),
                "production %s 只引用正式语义完整功法 %s" % [
                    hand_id, technique_id])

    var fixture_values := _catalog_definitions(production_catalog)
    fixture_values["sequences"]["high_card"] = ["fire_sparks"]
    var fixture_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.production())
    _assert_true(
        not fixture_catalog.load_from_definitions(
            fixture_values,
            production_catalog.paths),
        "production 序列拒绝回归夹具功法")
    _assert_true(
        _array_contains_text(fixture_catalog.errors, "fire_sparks")
        and _array_contains_text(fixture_catalog.errors, "regression_fixture"),
        "回归夹具错误同时报告功法 ID 与当前档位")

    for abolished_hand_id in ["flush", "straight_flush", "royal_flush"]:
        var abolished_hand_values := _catalog_definitions(catalog)
        abolished_hand_values["sequences"][abolished_hand_id] = []
        var abolished_hand_catalog = ContentCatalogScript.new()
        _assert_true(
            not abolished_hand_catalog.load_from_definitions(abolished_hand_values),
            "废弃牌型 %s 序列键被拒绝" % abolished_hand_id)
        _assert_true(
            _array_contains_text(
                abolished_hand_catalog.errors,
                "包含未知精确牌型 %s" % abolished_hand_id),
            "废弃牌型 %s 错误稳定定位" % abolished_hand_id)

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

    var bad_status_handler_values := _catalog_definitions(catalog)
    bad_status_handler_values["card_states"]["anomalies"][0]["behaviors"][0]["handler"] = "missing_status_handler"
    var bad_status_handler_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_status_handler_catalog.load_from_definitions(bad_status_handler_values),
        "异状拒绝未注册的状态处理器")
    _assert_true(
        _array_contains_text(bad_status_handler_catalog.errors, "未注册的状态处理器 missing_status_handler"),
        "状态处理器错误稳定定位")

    var bad_actor_status_handler_values := _catalog_definitions(catalog)
    bad_actor_status_handler_values["battle_statuses"]["actor_statuses"][0]["behaviors"][0]["handler"] = "missing_actor_status_handler"
    var bad_actor_status_handler_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_actor_status_handler_catalog.load_from_definitions(
            bad_actor_status_handler_values),
        "角色状态拒绝未注册的状态处理器")
    _assert_true(
        _array_contains_text(
            bad_actor_status_handler_catalog.errors,
            "未注册的状态处理器 missing_actor_status_handler"),
        "角色状态处理器错误稳定定位")

    var bad_status_reference_values := _catalog_definitions(catalog)
    for anomaly in bad_status_reference_values["card_states"]["anomalies"]:
        if anomaly.get("id", "") == "qi_severance":
            anomaly["behaviors"][0]["apply_anomaly"]["id"] = "missing_anomaly"
    var bad_status_reference_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_status_reference_catalog.load_from_definitions(bad_status_reference_values),
        "状态行为拒绝未知异状引用")
    _assert_true(
        _array_contains_text(bad_status_reference_catalog.errors, "引用未知真气异状 missing_anomaly"),
        "状态行为引用错误稳定定位")

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
    var run_session: RunSession = RunSessionScript.new(null, null, null, null, catalog)
    _assert_true(engine.content_catalog == catalog, "战斗核心使用注入的统一目录实例")
    _assert_true(run_session.execute({"type": "setup_run", "seed": 17}).success, "本局流程从同一目录装配地图与节点内容")
    var battle_session: BattleSession = run_session.create_battle_session()
    _assert_true(battle_session.engine.content_catalog == catalog, "本局创建的战斗会话继续共享同一目录实例")

func _test_enemy_pool_content_and_repository() -> void:
    var catalog := ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(catalog.load_all(), "敌人池内容随统一目录通过校验")
    var definition: Dictionary = catalog.definition("enemies")
    _assert_equal(definition["enemies"].size(), 9, "敌人池包含三名普通、两名精英、三名 Boss 与一个过渡占位条目")
    var repository := EnemyRepositoryScript.new(catalog)
    _assert_true(repository.configure(definition), "敌人仓库可消费已校验内容")
    var first: Dictionary = repository.select(1, "combat", 2)
    var second: Dictionary = repository.select(1, "combat", 2)
    _assert_true(first.get("success", false), "按层数和普通战斗可抽取敌人")
    _assert_equal(first["entry"]["id"], second["entry"]["id"], "相同种子抽取相同敌人")
    _assert_equal(first["entry"]["id"], "act1_gale_sleeve_adept", "第 1 层普通种子 2 抽到疾袖客")
    _assert_equal(first["cards"].size(), 20, "第一层普通敌人牌组按编码展开为 20 张")
    _assert_equal(first["cards"][0].id, second["cards"][0].id, "相同种子牌组实例 ID 稳定")
    _assert_true(
        first["cards"].all(func(card): return card.anomaly_snapshot()["poison"] == ""),
        "敌人牌组不预置战斗异状")
    var one_card_values := _catalog_definitions(catalog)
    one_card_values["enemies"]["enemies"][0]["deck"] = ["wind_2"]
    var one_card_catalog := ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(
        one_card_catalog.load_from_definitions(one_card_values),
        "一张牌的敌人牌组可以通过内容校验")
    var preset_origin := EnemyDeckEncodingScript.parse([{
        "definition_id": "wind_7",
        "reshapes": {
            "origin": {
                "id": "attribute_change",
                "payload": {"attribute": "mountain"},
            },
            "enhancement": "qi_boost",
        },
    }], catalog, "enemy-origin-test")
    _assert_true(preset_origin.get("success", false), "敌人可通过显式对象预置带参数本源")
    _assert_equal(preset_origin["cards"][0].definition_id, "mountain_7", "敌人预置转属更新基础定义")
    _assert_equal(preset_origin["cards"][0].reshape_origin["id"], "attribute_change", "敌人预置保存本源身份")
    _assert_equal(preset_origin["cards"][0].reshape_enhancement, "qi_boost", "敌人预置可同时声明强化")
    var ambiguous_origin_values := _catalog_definitions(catalog)
    ambiguous_origin_values["enemies"]["enemies"][0]["deck"] = [
        "wind_7+attribute_change"]
    var ambiguous_origin_catalog := ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(
        not ambiguous_origin_catalog.load_from_definitions(ambiguous_origin_values),
        "敌人不能用无 payload 的字符串预置本源")
    _assert_true(
        _array_contains_text(ambiguous_origin_catalog.errors, "必须显式提供 origin 与 payload 对象"),
        "敌人模糊本源编码报告明确错误")
    var no_match := repository.select(3, "event", 7301)
    _assert_true(not no_match.get("success", false), "敌人池无匹配节点组合时明确失败")
    _assert_true(
        _array_contains_text([str(no_match.get("reason", ""))], "第 3 层 / event"),
        "敌人池无匹配组合报告层数和节点类型")
    var seed_two := repository.select(1, "combat", 1)
    var seed_five := repository.select(1, "combat", 5)
    _assert_equal(seed_two["entry"]["id"], "act1_fourfold_roamer", "第 1 层普通种子 1 抽到四象散人")
    _assert_equal(seed_five["entry"]["id"], "act1_mountain_gu_warden", "第 1 层普通种子 5 抽到山蛊守")
    _assert_true(
        first["entry"]["id"] != seed_two["entry"]["id"]
        and seed_two["entry"]["id"] != seed_five["entry"]["id"],
        "第一层普通不同 content_seed 能抽到不同敌人")
    for selected in [first, seed_two, seed_five]:
        _assert_equal(int(selected["entry"]["acts"][0]), 1, "抽到的第一层敌人声明覆盖第 1 层")
        _assert_equal(str(selected["entry"]["node_types"][0]), "combat", "抽到的第一层敌人声明覆盖普通战斗")
    var elite_ids: Dictionary = {}
    for seed_value in range(256):
        var elite_result: Dictionary = repository.select(1, "elite", 41000 + seed_value)
        _assert_true(elite_result.get("success", false), "第 1 层精英候选可抽取")
        elite_ids[str(elite_result["entry"]["id"])] = true
    _assert_true(elite_ids.size() >= 2, "第 1 层精英候选至少有两个不同 ID")
    var boss_ids: Dictionary = {}
    var boss_variant_ids: Array[String] = []
    for variant in range(3):
        var boss_result: Dictionary = repository.select(1, "boss", 7301, variant)
        _assert_true(boss_result.get("success", false), "第 1 层 Boss 候选可抽取")
        boss_ids[str(boss_result["entry"]["id"])] = true
        boss_variant_ids.append(str(boss_result["entry"]["id"]))
        _assert_true(
            str(boss_result["entry"]["id"]) != "transitional_elite_boss_placeholder",
            "第 1 层 Boss 不抽到过渡占位条目")
    _assert_equal(boss_ids.size(), 3, "第 1 层 Boss 的 boss_variant 0/1/2 分别抽到三个不同 ID")
    print("S2-07 第一层 Boss 变体 seed=7301: variant0=%s, variant1=%s, variant2=%s" % boss_variant_ids)
    var stable_boss_a: Dictionary = repository.select(1, "boss", 7301, 1)
    var stable_boss_b: Dictionary = repository.select(1, "boss", 7301, 1)
    _assert_equal(
        stable_boss_a["entry"]["id"], stable_boss_b["entry"]["id"],
        "相同 content_seed 与 boss_variant 抽取结果稳定")
    var formal_ids := {
        "balance_sleeves_listen_wind": true,
        "double_gu_exchange_breath": true,
        "three_ring_ensemble": true,
        "three_ring_chaos_qi": true,
        "seize_qi_return_nest": true,
        "five_steps_echo": true,
        "stagnant_gu_conceal_breath": true,
        "borrow_fire_guard_heart": true,
    }
    for entry in definition["enemies"]:
        var proficiency: Dictionary = entry.get("hand_proficiency_fixed", {})
        _assert_equal(proficiency.size(), 8, "敌人完整声明八种牌型固定熟练度")
        for hand_id in entry.get("sequences", {}):
            for technique_id in entry["sequences"][hand_id]:
                _assert_true(
                    formal_ids.has(str(technique_id)),
                    "敌人功法只引用八门正式完整功法：%s" % technique_id)
    var placeholder: Dictionary = definition["enemies"][definition["enemies"].size() - 1]
    _assert_equal(placeholder["acts"].size(), 2, "过渡占位条目覆盖两层")
    _assert_equal(int(placeholder["acts"][0]), 2, "过渡占位条目覆盖第 2 层")
    _assert_equal(int(placeholder["acts"][1]), 3, "过渡占位条目覆盖第 3 层")
    _assert_equal(placeholder["name"], "第 2/3 层过渡占位精英首领", "占位条目名称明确层数范围")

func _test_formal_enemy_pool_battle_setup() -> void:
    var root := GameCompositionRootScript.new(RuntimeProfileScript.production())
    _assert_true(root.initialize(), "正式模式可装配敌人池")
    var run_session: RunSession = root.create_run_session()
    var battle_session: BattleSession = run_session.create_battle_session()
    _assert_true(
        battle_session.setup_battle({
            "act": 1,
            "node_type": "elite",
            "boss_variant": 0,
            "content_seed": 8112,
            "battle": {"use_enemy_ai": false},
        }),
        "正式第 1 层精英按层数、节点类型和种子完成敌人装配")
    _assert_equal(battle_session.engine.enemy.max_life, 150, "第一层精英敌人生命来自权威生命表")
    _assert_equal(battle_session.engine.enemy.life, 150, "第一层精英生命以查表上限开始")
    _assert_true(battle_session.engine.enemy.draw_pile.size() > 0, "正式精英使用非空自由牌组")
    _assert_true(
        battle_session.engine.enemy.name != "第 2/3 层过渡占位精英首领",
        "第一层精英不使用过渡占位条目")
    _assert_true(
        battle_session.engine.enemy_sequence_book.current_id("high_card") in [
            "borrow_fire_guard_heart", "stagnant_gu_conceal_breath"],
        "正式精英功法序列引用正式白名单")
    var boss_session: BattleSession = run_session.create_battle_session()
    _assert_true(
        boss_session.setup_battle({
            "act": 1,
            "node_type": "boss",
            "boss_variant": 2,
            "content_seed": 8112,
            "battle": {"use_enemy_ai": false},
        }),
        "正式第 1 层 Boss 完成战斗装配")
    _assert_equal(boss_session.engine.enemy.max_life, 200, "第一层 Boss 敌人生命来自权威生命表")
    _assert_equal(boss_session.engine.enemy.life, 200, "第一层 Boss 生命以查表上限开始")
    _assert_true(boss_session.engine.enemy.draw_pile.size() > 0, "正式 Boss 使用非空自由牌组")

func _test_production_enemy_pool_remote_ai_battle() -> void:
    var root := GameCompositionRootScript.new(RuntimeProfileScript.production())
    _assert_true(root.initialize(), "production 敌人池远程 AI 战斗内容加载成功")
    var run_session: RunSession = root.create_run_session()
    var session: BattleSession = run_session.create_battle_session()
    var provider := MockAiProviderScript.new(false)
    session.use_ai_provider(provider)
    session.configure_ai_runtime({
        "enabled": false,
        "provider": {"kind": "mock"},
        "storage": {"autosave_conversation": false},
    })
    var configuration := {
        "act": 1,
        "node_type": "combat",
        "content_seed": 2,
        "content_id": "s203b-act1-combat-remote-ai",
        "battle": {
            "entry_kind": "formal",
            "scenario_path": "res://data/production_enemy_entry.json",
            "use_enemy_ai": true,
            "use_remote_ai": true,
        },
        "ai_settings": {
            "timeout_msec": 30000,
            "max_retries": 0,
        },
    }
    _assert_true(session.setup_battle(configuration), "production 第一层普通敌人池战斗装配成功")
    _assert_true(session._remote_ai_enabled, "敌人池战斗明确打开远程 AI 路径")
    var enemy_id := str(session.engine.enemy.name)
    _assert_true(
        enemy_id in ["疾袖客", "四象散人", "山蛊守"],
        "远程 AI 战斗敌人来自第一层正式普通敌人池")
    _assert_true(session.execute({"type": "start_turn"}).success, "远程 AI 战斗建立首个行动窗口")

    var request_cursor := 0
    var window_count := 0
    var action_count := 0
    var enemy_effect_observed := false
    var max_steps := 240
    while session.engine.battle_state == "active" and max_steps > 0:
        max_steps -= 1
        if provider.submitted_requests.size() > request_cursor:
            var request: Dictionary = provider.submitted_requests[request_cursor]
            var payload: Dictionary = request["payload"]
            var candidates: Array = payload.get("candidates", [])
            _assert_true(not candidates.is_empty(), "远程 AI 每个行动窗口都收到合法候选")
            provider.queue_result({
                "success": true,
                "body": {
                    "schema_version": 1,
                    "decision_id": payload["observation"]["decision_id"],
                    "state_hash": payload["observation"]["state_hash"],
                    "candidate_id": candidates[0]["candidate_id"],
                },
            })
            _assert_true(
                provider.complete(str(request["request_id"])),
                "MockAiProvider 完成敌方远程回答")
            request_cursor += 1
            window_count += 1
            continue
        if session.engine.round_ended:
            _assert_true(session.execute({"type": "start_turn"}).success, "远程 AI 战斗进入下一回合")
            continue
        var snapshot = session.snapshot()
        var ai_state := str(snapshot.ai_decision.get("state", ""))
        if ai_state == "thinking":
            continue
        if session.engine.battle_flow.can_act(session.engine.player):
            if session.engine.player.hand.is_empty():
                _assert_true(session.execute({"type": "end_turn"}).success, "玩家无牌时结束回合")
                continue
            var play_result = session.execute({
                "type": "play_cards",
                "card_ids": [session.engine.player.hand[0].id],
            })
            _assert_true(play_result.success, "玩家行动与远程敌方提案完成同步结算")
            var enemy_preview_value = play_result.payload_value("enemy_preview", {})
            var enemy_preview: Dictionary = enemy_preview_value if enemy_preview_value is Dictionary else {}
            var enemy_intent_value = enemy_preview.get("intent", {})
            var enemy_intent: Dictionary = enemy_intent_value if enemy_intent_value is Dictionary else {}
            enemy_effect_observed = enemy_effect_observed \
                or int(enemy_intent.get("damage", 0)) > 0 \
                or int(enemy_intent.get("defense", 0)) > 0
            action_count += 1
        else:
            _assert_true(session.execute({"type": "end_turn"}).success, "玩家无行动时结束回合")

    var final_snapshot = session.snapshot()
    _assert_true(window_count > 0, "远程 AI 战斗实际建立多个行动窗口")
    _assert_true(provider.submitted_requests.size() > 0, "MockAiProvider 收到远程 AI 请求")
    _assert_true(action_count > 0, "远程 AI 战斗至少完成一次玩家同步行动")
    _assert_true(enemy_effect_observed, "远程 AI 选择产生可观察的敌方伤害或防御")
    _assert_true(session.engine.battle_state != "active", "远程 AI 战斗在安全步数内到达终态")
    _assert_true(
        final_snapshot.player.life == 0 or final_snapshot.enemy.life == 0,
        "远程 AI 战斗终态至少有一方生命降至 0")
    print("S2-03b remote AI metrics: enemy=%s windows=%d requests=%d rounds=%d actions=%d state=%s player_life=%d enemy_life=%d" % [
        enemy_id,
        window_count,
        provider.submitted_requests.size(),
        session.engine.turn_number,
        action_count,
        session.engine.battle_state,
        final_snapshot.player.life,
        final_snapshot.enemy.life,
    ])
    if session.engine.battle_state == "unresolved_draw":
        print("S2-03b remote AI simultaneous defeat: unresolved_draw")
    provider.free()

func _test_production_formal_sequences_and_damage() -> void:
    var root = GameCompositionRootScript.new(RuntimeProfileScript.production())
    _assert_true(root.initialize(), "production 组合根载入正式内容")
    var run_session: RunSession = root.create_run_session()
    _assert_true(run_session != null, "production 正式内容可建立本局会话")
    if run_session == null:
        return
    var battle_session: BattleSession = run_session.create_battle_session()
    _assert_true(
        battle_session.setup_battle({
            "content_seed": 2308,
            "battle": {"use_enemy_ai": false},
        }),
        "production 正式敌人入口可建立战斗")
    var engine = battle_session.engine
    var played = _card("9", "mountain")
    engine.player.hand = [played]
    engine.player.draw_pile.clear()
    engine.player.staging.clear()
    engine.actions_available = 1
    _assert_equal(
        engine.sequence_book.current_id("high_card"),
        "borrow_fire_guard_heart",
        "production 高牌首门功法来自正式开局序列")
    _assert_true(
        engine.repository.is_formally_complete(
            engine.sequence_book.current_id("high_card")),
        "production 战斗仓库确认当前高牌功法在白名单内")
    var preview: Dictionary = battle_session.preview([played.id])
    var life_before: int = engine.enemy.life
    var result = battle_session.execute({
        "type": "play_cards",
        "card_ids": [played.id],
    })
    var actual_damage: int = life_before - int(engine.enemy.life)
    _assert_true(result.success, "production 模式可以实际打出一次高牌")
    _assert_equal(actual_damage, 4, "production 山9高牌由借火护心造成4点伤害")
    _assert_equal(
        actual_damage,
        int(preview.get("intent", {}).get("damage", 0)),
        "production 高牌预览与实际伤害一致")
    _assert_true(actual_damage > 0, "production 高牌实际对敌方造成大于0的伤害")

func _test_formal_production_technique_behaviors() -> void:
    _test_double_gu_exchange_breath_formal_behavior()
    _test_balance_sleeves_listen_wind_formal_behavior()
    _test_three_ring_ensemble_formal_behavior()
    _test_three_ring_chaos_qi_formal_behavior()
    _test_five_steps_echo_formal_behavior()
    _test_seize_qi_return_nest_formal_behavior()
    _test_full_house_pool_branch_protocol()

func _test_full_house_pool_branch_protocol() -> void:
    var pair_cards := [
        _card("6", "wind"), _card("6", "forest"), _card("6", "fire"),
        _card("3", "wind"), _card("3", "mountain"),
    ]
    var pair_engine = _engine_with_hand(pair_cards, [], 9211)
    pair_engine.repository.techniques["probe_full_house_pair_branch"] = {
        "id": "probe_full_house_pair_branch",
        "name": "葫芦对子分支探针",
        "pool": "pair",
        "special": false,
        "effects": [
            {"op": "damage", "amount": {"kind": "hand_map", "values": {"pair": 7}}},
            {"op": "damage", "amount": 3, "when": {"hand_id": "pair"}},
        ],
    }
    pair_engine.inner_skill_repository.inner_skills["probe_inner_actual_hand_only"] = {
        "id": "probe_inner_actual_hand_only",
        "name": "内功实际牌型探针",
        "timing": "on_play_resolve",
        "effects": [{
            "op": "defense",
            "amount": {"kind": "hand_map", "values": {"pair": 20}},
        }],
    }
    pair_engine.player.configure_inner_skills(["probe_inner_actual_hand_only"], 1)
    pair_engine.sequence_book.configure({"full_house": ["probe_full_house_pair_branch"]})
    var pair_preview: Dictionary = pair_engine.preview(_ids(pair_cards))
    var pair_life_before: int = pair_engine.enemy.life
    var pair_result: Dictionary = pair_engine.confirm_play(_ids(pair_cards))
    _assert_equal(pair_preview.intent.damage, 10, "葫芦预览读取对子池的 pair 数值与条件分支")
    _assert_equal(pair_life_before - pair_engine.enemy.life, 10, "葫芦真实结算读取同一 pair 默认分支")
    _assert_true(pair_result.technique_triggered, "葫芦对子池功法正常触发")
    _assert_equal(pair_preview.intent.inner_skill_defense, 0, "内功预览不继承对子池默认分支")
    _assert_equal(pair_engine.player.defense, 0, "内功真实结算只读取实际葫芦牌型")

    var three_cards := [
        _card("7", "wind"), _card("7", "forest"), _card("7", "fire"),
        _card("4", "wind"), _card("4", "mountain"),
    ]
    var three_engine = _engine_with_hand(three_cards, [], 9212)
    three_engine.repository.techniques["probe_full_house_three_branch"] = {
        "id": "probe_full_house_three_branch",
        "name": "葫芦三条分支探针",
        "pool": "three",
        "special": false,
        "effects": [
            {"op": "damage", "amount": {"kind": "hand_map", "values": {"three_kind": 9}}},
            {"op": "damage", "amount": 2, "when": {"hand_id": "three_kind"}},
        ],
    }
    three_engine.sequence_book.configure({"full_house": ["probe_full_house_three_branch"]})
    var three_preview: Dictionary = three_engine.preview(_ids(three_cards))
    var three_life_before: int = three_engine.enemy.life
    three_engine.confirm_play(_ids(three_cards))
    _assert_equal(three_preview.intent.damage, 11, "葫芦预览读取三条池的 three_kind 分支")
    _assert_equal(three_life_before - three_engine.enemy.life, 11, "葫芦真实结算读取同一 three_kind 默认分支")

    var exact_cards := [
        _card("8", "wind"), _card("8", "forest"), _card("8", "fire"),
        _card("5", "wind"), _card("5", "mountain"),
    ]
    var exact_engine = _engine_with_hand(exact_cards, [], 9213)
    exact_engine.repository.techniques["probe_full_house_exact_branch"] = {
        "id": "probe_full_house_exact_branch",
        "name": "葫芦精确分支探针",
        "pool": "pair",
        "special": false,
        "effects": [{
            "op": "damage",
            "amount": {"kind": "hand_map", "values": {"pair": 5, "full_house": 13}},
        }],
    }
    exact_engine.sequence_book.configure({"full_house": ["probe_full_house_exact_branch"]})
    var exact_preview: Dictionary = exact_engine.preview(_ids(exact_cards))
    var exact_life_before: int = exact_engine.enemy.life
    exact_engine.confirm_play(_ids(exact_cards))
    _assert_equal(exact_preview.intent.damage, 13, "显式 full_house 数值在预览中优先于 pair 默认分支")
    _assert_equal(exact_life_before - exact_engine.enemy.life, 13, "显式 full_house 数值在真实结算中优先")

    var delayed_cards := [
        _card("9", "wind"), _card("9", "forest"), _card("9", "fire"),
        _card("2", "wind"), _card("2", "mountain"),
    ]
    var delayed_engine = _engine_with_hand(delayed_cards, [], 9214)
    delayed_engine.repository.techniques["probe_full_house_delayed_branch"] = {
        "id": "probe_full_house_delayed_branch",
        "name": "葫芦延迟分支探针",
        "pool": "pair",
        "special": false,
        "effects": [{
            "op": "register_delayed_effects",
            "timing": "turn_end",
            "occurrences": 1,
            "effects": [{
                "op": "add_stack",
                "stack": "momentum",
                "amount": {"kind": "hand_map", "values": {"pair": 4}},
                "when": {"hand_id": "pair"},
            }],
        }],
    }
    delayed_engine.sequence_book.configure({"full_house": ["probe_full_house_delayed_branch"]})
    delayed_engine.confirm_play(_ids(delayed_cards))
    _assert_equal(delayed_engine.delayed_effects[0].actual_hand_id, "full_house", "延迟记录保存实际葫芦牌型")
    _assert_equal(delayed_engine.delayed_effects[0].branch_hand_id, "pair", "延迟记录保存对子池默认分支")
    _assert_equal(delayed_engine.delayed_effects[0].technique_pool, "pair", "延迟记录保存原功法池")
    delayed_engine.end_player_turn()
    _assert_equal(delayed_engine.player.stacks.get("momentum", 0), 4, "延迟结算保持 pair 数值与条件语义")

    var retrigger_cards := [
        _card("10", "wind"), _card("10", "forest"), _card("10", "fire"),
        _card("4", "wind"), _card("4", "mountain"),
    ]
    var retrigger_engine = _engine_with_hand(retrigger_cards, [], 9215)
    retrigger_engine.repository.techniques["probe_full_house_retrigger_branch"] = {
        "id": "probe_full_house_retrigger_branch",
        "name": "葫芦重触分支探针",
        "pool": "pair",
        "special": false,
        "effects": [{
            "op": "damage",
            "amount": {"kind": "hand_map", "values": {"pair": 6}},
        }],
    }
    retrigger_engine.sequence_book.configure({"full_house": ["probe_full_house_retrigger_branch"]})
    var retrigger_life_before: int = retrigger_engine.enemy.life
    var retrigger_result: Dictionary = retrigger_engine.action_resolver.retrigger_current_hand_technique(
        retrigger_engine.player,
        retrigger_engine.enemy,
        retrigger_engine.sequence_book,
        1,
        6,
        [])
    _assert_true(retrigger_result.triggered, "葫芦重触功法正常触发")
    _assert_equal(retrigger_life_before - retrigger_engine.enemy.life, 6, "葫芦重触保持 pair 默认分支")

func _assert_preview_damage_matches(
        engine,
        played_cards: Array,
        label: String,
        cooperation_cards: Array = []) -> Dictionary:
    var preview: Dictionary = engine.preview(_ids(played_cards))
    var life_before: int = engine.enemy.life
    var result: Dictionary = engine.confirm_play(
        _ids(played_cards),
        _ids(cooperation_cards))
    _assert_true(result.get("success", false), "%s主分支完成结算" % label)
    _assert_equal(
        life_before - engine.enemy.life,
        int(preview.get("intent", {}).get("damage", 0)),
        "%s预览伤害与实际结算一致" % label)
    return result

func _test_double_gu_exchange_breath_formal_behavior() -> void:
    var pair := [_card("6", "wind"), _card("6", "forest")]
    var poison_card = _card("3", "fire")
    poison_card.set_anomaly("poison", "lethal_poison")
    var main = _engine_with_hand(pair + [poison_card])
    main.enemy.hand = [_card("2", "mountain")]
    main.sequence_book.configure({"pair": ["double_gu_exchange_breath"]})
    var result := _assert_preview_damage_matches(
        main, pair, "双蛊换息一对")
    _assert_true(result.get("technique_triggered", false), "双蛊换息正式主分支触发")
    _assert_true(main.enemy.hand.has(poison_card), "双蛊换息将合格带毒手牌置入敌方手牌")

    var shortage_pair := [_card("5", "wind"), _card("5", "forest")]
    var shortage = _engine_with_hand(shortage_pair)
    shortage.enemy.hand.clear()
    shortage.sequence_book.configure({"pair": ["double_gu_exchange_breath"]})
    _assert_preview_damage_matches(shortage, shortage_pair, "双蛊换息目标不足")
    _assert_equal(shortage.enemy.hand.size(), 0, "双蛊换息没有可移动目标时不凭空生成真气")

func _test_balance_sleeves_listen_wind_formal_behavior() -> void:
    var two_pair := [
        _card("3", "wind"), _card("3", "forest"),
        _card("4", "fire"), _card("4", "mountain"),
    ]
    var main = _engine_with_hand(two_pair)
    main.enemy.hand = [
        _card("2", "wind"), _card("7", "forest"), _card("8", "fire"),
    ]
    main.sequence_book.configure({"two_pair": ["balance_sleeves_listen_wind"]})
    _assert_preview_damage_matches(main, two_pair, "衡袖听风两对")
    _assert_equal(main.enemy.hand.size(), 1, "衡袖听风两对主分支随机弃敌方两张")
    _assert_true(main.player.defense > 0, "衡袖听风两对主分支同时获得防御")

    var shortage_cards := [
        _card("5", "wind"), _card("5", "forest"),
        _card("6", "fire"), _card("6", "mountain"),
    ]
    var shortage = _engine_with_hand(shortage_cards)
    shortage.enemy.hand.clear()
    shortage.sequence_book.configure({"two_pair": ["balance_sleeves_listen_wind"]})
    _assert_preview_damage_matches(shortage, shortage_cards, "衡袖听风目标不足")
    _assert_equal(shortage.enemy.hand.size(), 0, "衡袖听风敌方无手牌时弃牌安全收敛为空")

func _test_three_ring_ensemble_formal_behavior() -> void:
    var three_kind := [
        _card("5", "wind"), _card("5", "forest"), _card("5", "fire"),
    ]
    var main = _engine_with_hand(three_kind)
    main.sequence_book.configure({"three_kind": ["three_ring_ensemble"]})
    var result := _assert_preview_damage_matches(main, three_kind, "三环并奏三条")
    _assert_true(result.get("technique_triggered", false), "三环并奏正式主分支触发")

    var shortage_cards := [
        _card("4", "wind"), _card("4", "forest"), _card("4", "fire"),
    ]
    var shortage = _engine_with_hand(shortage_cards)
    shortage.sequence_book.configure({"three_kind": ["three_ring_ensemble"]})
    _assert_preview_damage_matches(shortage, shortage_cards, "三环并奏无协同目标")
    _assert_equal(shortage.player.hand.size(), 0, "三环并奏没有可协同一对时只提交主牌型")

func _test_three_ring_chaos_qi_formal_behavior() -> void:
    var full_house := [
        _card("3", "wind"), _card("3", "forest"), _card("3", "fire"),
        _card("2", "wind"), _card("2", "mountain"),
    ]
    var main = _engine_with_hand(full_house)
    main.enemy.hand = [_card("7", "forest"), _card("8", "mountain")]
    main.enemy.draw_pile.clear()
    main.sequence_book.configure({"full_house": ["three_ring_chaos_qi"]})
    _assert_preview_damage_matches(main, full_house, "三环乱气葫芦")
    main.end_player_turn()
    for card in main.enemy.hand:
        _assert_true(
            card.has_anomaly("state") or card.has_anomaly("poison"),
            "三环乱气回合结束主分支为敌方普通手牌施加声明异状")

    var shortage_cards := [
        _card("4", "wind"), _card("4", "forest"), _card("4", "fire"),
        _card("2", "forest"), _card("2", "mountain"),
    ]
    var shortage = _engine_with_hand(shortage_cards)
    shortage.enemy.hand.clear()
    shortage.enemy.draw_pile.clear()
    shortage.sequence_book.configure({"full_house": ["three_ring_chaos_qi"]})
    _assert_preview_damage_matches(shortage, shortage_cards, "三环乱气目标不足")
    shortage.end_player_turn()
    _assert_equal(shortage.enemy.hand.size(), 0, "三环乱气无敌方手牌和牌库时延迟效果安全为空")

func _test_five_steps_echo_formal_behavior() -> void:
    var straight := [
        _card("2", "wind"), _card("3", "forest"), _card("4", "fire"),
        _card("5", "mountain"), _card("6", "wind"),
    ]
    var main = _engine_with_hand(straight)
    main.sequence_book.configure({"straight": ["five_steps_echo"]})
    var result := _assert_preview_damage_matches(main, straight, "五步余音顺子")
    _assert_true(result.get("technique_triggered", false), "五步余音正式主分支触发")

    var shortage_cards := [
        _card("3", "wind"), _card("4", "forest"), _card("5", "fire"),
        _card("6", "mountain"), _card("7", "wind"),
    ]
    var shortage = _engine_with_hand(shortage_cards)
    shortage.sequence_book.configure({"straight": ["five_steps_echo"]})
    _assert_preview_damage_matches(shortage, shortage_cards, "五步余音无协同目标")
    _assert_equal(shortage.player.hand.size(), 0, "五步余音没有高牌协同时只提交主顺子")

func _test_seize_qi_return_nest_formal_behavior() -> void:
    var four_kind := [
        _card("7", "wind"), _card("7", "forest"),
        _card("7", "fire"), _card("7", "mountain"),
    ]
    var main = _engine_with_hand(four_kind, [], 9201)
    main.sequence_book.configure({"four_kind": ["seize_qi_return_nest"]})
    _assert_preview_damage_matches(main, four_kind, "夺气归巢四条")
    _assert_equal(
        main.player.stacks.get("steal_wind", 0),
        10,
        "夺气归巢四条主分支获得10层夺风")

    var shortage_cards := [
        _card("8", "wind"), _card("8", "forest"),
        _card("8", "fire"), _card("8", "mountain"),
    ]
    var shortage = _engine_with_hand(shortage_cards, [], 9202)
    shortage.enemy.hand.clear()
    shortage.enemy.draw_pile.clear()
    shortage.enemy.max_life = 1000
    shortage.enemy.life = 1000
    shortage.sequence_book.configure({"four_kind": ["seize_qi_return_nest"]})
    _assert_preview_damage_matches(shortage, shortage_cards, "夺气归巢目标不足")
    _assert_equal(
        shortage.delayed_effects.size(),
        0,
        "夺气归巢四条在敌方无目标时不错误建立五条延迟效果")

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

func _test_starter_build_assembly_and_composition_root() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "构筑装配测试内容目录有效")
    var assembler = StarterBuildAssemblerScript.new(catalog)
    var assembled: Dictionary = assembler.assemble_into_run_deck({
        "id": "assembly_probe",
        "card_count": 2,
        "card_ids": ["wind_2", "fire_A"],
    }, "assembly-probe")
    _assert_true(assembled.get("success", false), "初始构筑装配器按显式 card_ids 建立 RunDeck")
    var assembled_deck: Object = assembled.get("run_deck")
    _assert_equal(assembled_deck.card_count(), 2, "装配器不会退回固定标准52张牌组")
    _assert_true(assembled_deck.has_card("wind_2"), "装配结果包含构筑声明的风2")
    _assert_true(assembled_deck.has_card("fire_A"), "装配结果包含构筑声明的火A")
    var rejected: Dictionary = assembler.assemble_card_ids({
        "card_count": 1,
        "card_ids": ["missing_card"],
    })
    _assert_true(not rejected.get("success", false), "构筑装配器拒绝未知真气引用")

    var composition_root: Object = GameCompositionRootScript.new()
    _assert_true(composition_root.initialize(), "游戏组合根一次性加载统一内容平台")
    var first_session: Object = composition_root.create_run_session()
    var second_session: Object = composition_root.create_run_session()
    _assert_true(first_session._content_catalog == composition_root.content_catalog, "本局会话复用组合根内容目录")
    _assert_true(second_session._content_catalog == composition_root.content_catalog, "多个本局会话不重复创建内容目录")
    _assert_true(first_session.game_log == composition_root.game_log, "本局与战斗流程复用组合根结构化日志")
    var setup_result = first_session.execute({
        "type": "setup_run",
        "seed": 2308,
        "starter_build_id": "standard_52",
    })
    _assert_true(setup_result.success, "组合根建立的本局可按初始构筑启动")
    _assert_equal(first_session.snapshot().growth["run_deck_count"], 52, "初始构筑装配结果进入本局权威牌组")

func _test_node_reward_service_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "奖励服务测试内容目录有效")
    var service = NodeRewardServiceScript.new(catalog.definition("node_rewards"))
    var combat = service.create_bundle(
        {"id": "0_1", "type": "combat"},
        {"seed": 2308, "act": 1})
    var combat_again = service.create_bundle(
        {"id": "0_1", "type": "combat"},
        {"seed": 2308, "act": 1})
    _assert_equal(combat.to_dict(), combat_again.to_dict(), "相同节点上下文生成确定性奖励包")
    _assert_equal(combat.total("experience"), 3, "普通战斗奖励包包含三点历练")
    _assert_equal(
        combat.entries()[0].get("op"),
        "gain_experience",
        "节点历练奖励通过明确的本局效果操作执行")
    var elite = service.create_bundle({"id": "5_2", "type": "elite"}, {"seed": 2308, "act": 1})
    var boss = service.create_bundle({"id": "boss", "type": "boss"}, {"seed": 2308, "act": 1})
    _assert_equal(elite.total("experience"), 4, "精英奖励包包含四点历练")
    _assert_equal(boss.total("experience"), 5, "Boss奖励包包含五点历练")
    var event = service.create_bundle({"id": "4_2", "type": "event"}, {"seed": 2308, "act": 1})
    _assert_true(event.entries().is_empty(), "未确认的事件奖励保持空包而不补设计")
    var growth = GrowthInventoryScript.new()
    var applied: Dictionary = service.apply_bundle(combat, growth)
    _assert_true(applied.get("success", false), "奖励服务可以应用已实现的历练奖励")
    _assert_equal(growth.experience, 3, "奖励服务通过成长库存发放历练")
    var elite_growth = GrowthInventoryScript.new()
    _assert_true(
        service.apply_bundle(elite, elite_growth).get("success", false),
        "精英奖励包通过同一本局事务执行")
    _assert_equal(elite_growth.experience, 4, "精英节点实际获得四点历练")
    var boss_growth = GrowthInventoryScript.new()
    _assert_true(
        service.apply_bundle(boss, boss_growth).get("success", false),
        "Boss奖励包通过同一本局事务执行")
    _assert_equal(boss_growth.experience, 5, "Boss节点实际获得五点历练")

func _test_run_effect_platform_contract() -> void:
    var registry = RunEffectHandlerRegistryScript.new()
    _assert_equal(
        registry.operation_ids(),
        [
            "add_run_cards",
            "apply_run_card_reshape",
            "copy_run_card",
            "copy_run_card_state",
            "gain_experience",
            "heal_life",
            "remove_run_cards",
            "transform_run_card",
        ],
        "本局效果默认注册表按稳定顺序公开八个正式操作")
    _assert_true(registry.has_handler("gain_experience"), "历练增加操作已注册")
    _assert_true(registry.has_handler("heal_life"), "生命回复操作已注册")

    var invalid_id_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        not invalid_id_registry.register_handler(
            RunEffectProbeHandler.new(["Bad-Operation"])),
        "非 snake_case 本局效果操作 ID 被拒绝")
    var empty_id_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        not empty_id_registry.register_handler(RunEffectProbeHandler.new([""])),
        "空本局效果操作 ID 被拒绝")
    var duplicate_declaration_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        not duplicate_declaration_registry.register_handler(
            RunEffectProbeHandler.new(["probe_duplicate", "probe_duplicate"])),
        "单个 Handler 重复声明同一操作 ID 被拒绝")
    var duplicate_registration_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        duplicate_registration_registry.register_handler(
            RunEffectProbeHandler.new(["probe_registered"])),
        "第一个测试 Handler 可以注册")
    _assert_true(
        not duplicate_registration_registry.register_handler(
            RunEffectProbeHandler.new(["probe_registered"])),
        "多个 Handler 重复注册同一操作 ID 被拒绝")
    var invalid_contract_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        not invalid_contract_registry.register_handler(RefCounted.new()),
        "不符合 RunEffectHandler 契约的对象被拒绝")

    var custom_registry = RunEffectHandlerRegistryScript.new(false)
    _assert_true(
        custom_registry.register_handler(
            RunEffectProbeHandler.new(["probe_experience"])),
        "测试专用 Handler 只通过注册接入")
    var custom_growth = GrowthInventoryScript.new()
    var custom_result: Dictionary = RunMutationServiceScript.new(
        custom_registry).apply_effects(
            [{"op": "probe_experience", "amount": 4}], custom_growth)
    _assert_true(custom_result.get("success", false), "注册后的测试操作可由事务服务执行")
    _assert_equal(custom_growth.experience, 4, "测试操作无需修改中央服务即可增加历练")

    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "本局效果平台测试内容目录有效")
    var unknown_values := _catalog_definitions(catalog)
    unknown_values["node_rewards"]["node_rewards"]["combat"][0]["op"] = "missing_run_effect"
    var unknown_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_catalog.load_from_definitions(unknown_values),
        "未注册本局效果操作在内容加载阶段失败")
    _assert_true(
        _array_contains_text(
            unknown_catalog.errors,
            "未注册的本局效果操作：missing_run_effect"),
        "未知本局效果错误包含具名操作 ID")
    var invalid_gain_values := _catalog_definitions(catalog)
    invalid_gain_values["node_rewards"]["node_rewards"]["combat"][0].erase("amount")
    var invalid_gain_catalog = ContentCatalogScript.new()
    _assert_true(
        not invalid_gain_catalog.load_from_definitions(invalid_gain_values),
        "gain_experience 缺少 amount 时内容加载失败")
    _assert_true(
        _array_contains_text(
            invalid_gain_catalog.errors,
            "gain_experience amount 必须是非负整数"),
        "历练操作参数错误由 Handler 具名报告")

    var mutation = RunMutationServiceScript.new(registry)
    var percent_growth = GrowthInventoryScript.new(catalog)
    percent_growth.life = 70
    var percent_result: Dictionary = mutation.apply_effects(
        [{"op": "heal_life", "max_life_percent": 30}], percent_growth)
    _assert_true(percent_result.get("success", false), "按最大生命百分比回复执行成功")
    _assert_equal(percent_growth.life, 100, "70/100 按最大生命30%回复到100/100")
    _assert_equal(
        percent_result.get("applied", [])[0].get("theoretical_amount"),
        30,
        "百分比回复记录理论回复量30")
    var amount_growth = GrowthInventoryScript.new(catalog)
    amount_growth.life = 90
    var amount_result: Dictionary = mutation.apply_effects(
        [{"op": "heal_life", "amount": 30}], amount_growth)
    _assert_true(amount_result.get("success", false), "固定生命回复执行成功")
    _assert_equal(amount_growth.life, 100, "90/100 回复30点不超过上限")
    _assert_equal(
        amount_result.get("applied", [])[0].get("actual_amount"),
        10,
        "固定回复记录实际回复量10")
    _assert_true(
        not mutation.apply_effects([{
            "op": "heal_life",
            "amount": 20,
            "max_life_percent": 30,
        }], amount_growth).get("success", false),
        "heal_life 同时提供两种参数被拒绝")
    _assert_true(
        not mutation.apply_effects(
            [{"op": "heal_life"}], amount_growth).get("success", false),
        "heal_life 未提供回复参数被拒绝")
    _assert_true(
        not mutation.apply_effects(
            [{"op": "gain_experience", "amount": -1}], amount_growth
        ).get("success", false),
        "gain_experience 拒绝负数消费历练")

    var rollback_registry = RunEffectHandlerRegistryScript.new()
    _assert_true(
        rollback_registry.register_handler(
            RunEffectProbeHandler.new(["fail_after_gain"], true)),
        "原子失败探针注册成功")
    var rollback_growth = GrowthInventoryScript.new(catalog)
    rollback_growth.experience = 11
    rollback_growth.life = 70
    rollback_growth.consumable_ids.append("transaction_probe_consumable")
    rollback_growth.practice_purchases["transaction_probe_purchase"] = true
    rollback_growth.practice_shop_state = {"shop_index": 9, "slots": [{"id": "probe"}]}
    rollback_growth.hand_technique_progression["pair"]["slot_count"] = 3
    var rollback_before: Dictionary = rollback_growth.capture_mutation_state()
    var rollback_result: Dictionary = RunMutationServiceScript.new(
        rollback_registry).apply_effects([
            {"op": "gain_experience", "amount": 5},
            {"op": "fail_after_gain", "amount": 1},
        ], rollback_growth)
    _assert_true(not rollback_result.get("success", false), "第二个效果失败会拒绝整组事务")
    _assert_equal(rollback_result.get("failed_effect_index"), 1, "失败结果定位第二个效果")
    _assert_equal(
        rollback_result.get("failed_operation_id"),
        "fail_after_gain",
        "失败结果报告具名操作 ID")
    _assert_equal(
        rollback_growth.capture_mutation_state(),
        rollback_before,
        "事务失败后历练、生命、牌组、库存与修习状态全部保持不变")

    var success_growth = GrowthInventoryScript.new(catalog)
    success_growth.experience = 1
    success_growth.life = 70
    var success_result: Dictionary = mutation.apply_effects([
        {"op": "gain_experience", "amount": 4, "source": "contract_probe"},
        {"op": "heal_life", "amount": 20},
    ], success_growth)
    _assert_true(success_result.get("success", false), "多效果全部成功后提交一次真实状态")
    _assert_true(success_result.get("changed", false), "成功事务报告状态发生变化")
    _assert_equal(success_result.get("applied", []).size(), 2, "成功事务按数据顺序返回两个结果")
    _assert_equal(success_growth.experience, 5, "成功事务一次提交历练结果")
    _assert_equal(success_growth.life, 90, "成功事务一次提交生命结果")

    var save_session: RunSession = RunSessionScript.new()
    _assert_true(
        save_session.execute({"type": "setup_run", "seed": 2401}).success,
        "本局效果存档探针建立正式本局")
    save_session.growth.life = 70
    var save_effect_result: Dictionary = mutation.apply_effects([
        {"op": "gain_experience", "amount": 9},
        {"op": "heal_life", "amount": 20},
    ], save_session.growth)
    _assert_true(save_effect_result.get("success", false), "存档前本局效果事务执行成功")
    var restored: Dictionary = RunSaveDataScript.new().capture(
        save_session).restore_session(save_session._content_catalog)
    _assert_true(restored.get("success", false), "新框架产生的状态可以存档并读回")
    _assert_equal(restored["run_session"].growth.experience, 9, "读档保留本局效果增加的历练")
    _assert_equal(restored["run_session"].growth.life, 90, "读档保留本局效果回复的生命")

    var composition_root = GameCompositionRootScript.new()
    _assert_true(composition_root.initialize(), "组合根为本局效果平台注册共享依赖")
    var composed_session: RunSession = composition_root.create_run_session()
    _assert_true(
        composed_session._node_reward_service.handler_registry \
            == composition_root.run_effect_registry,
        "内容校验与节点奖励执行复用组合根中的同一注册表")
    var node_reward_source := FileAccess.get_file_as_string(
        "res://core/node_reward_service.gd")
    _assert_true(
        not node_reward_source.contains("match ") \
            and not node_reward_source.contains("gain_experience") \
            and not node_reward_source.contains("heal_life"),
        "NodeRewardService 不按操作 ID 或内容 ID 分支")

func _test_run_card_workshop_effects() -> void:
    var base_catalog = ContentCatalogScript.new()
    _assert_true(base_catalog.load_all(), "真气工坊测试载入统一内容目录")
    var content_values := _catalog_definitions(base_catalog)
    content_values["card_states"]["other_reshapes"].append({
        "id": "echo_reshape", "name": "回响重塑"})
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_from_definitions(content_values), "测试目录扩展印记与其他定义")
    var growth = GrowthInventoryScript.new(catalog)
    growth.run_deck.reset_standard("craft")
    var workshop = CardWorkshopServiceScript.new()

    var wind_seven_before: Dictionary = growth.run_deck.card_data("wind_7")
    var attribute_change: Dictionary = workshop.apply_run_card_origin(
        growth.run_deck, ["wind_7"], "attribute_change", {"attribute": "mountain"})
    _assert_true(attribute_change.get("success", false), "风7可以转属为山")
    var mountain_seven: Dictionary = growth.run_deck.card_data("wind_7")
    _assert_equal(mountain_seven["attribute"], "mountain", "转属改变基础属性")
    _assert_equal(mountain_seven["rank_name"], "7", "转属保持牌阶")
    _assert_equal(mountain_seven["qi_value"], wind_seven_before["qi_value"], "转属保持基础真气值")
    _assert_equal(mountain_seven["definition_id"], "mountain_7", "转属更新正式定义 ID")
    _assert_equal(mountain_seven["instance_id"], "wind_7", "转属保持实例 ID")
    _assert_true(
        not workshop.apply_run_card_origin(
            growth.run_deck, ["wind_7"], "rank_change", {"direction": "up"}
        ).get("success", false),
        "已有本源的真气不能再次易阶")

    _assert_true(workshop.apply_run_card_origin(
        growth.run_deck, ["wind_K"], "rank_change", {"direction": "up"}
    ).get("success", false), "风K可以升为风A")
    var wind_ace: Dictionary = growth.run_deck.card_data("wind_K")
    var ace_definition: Dictionary = catalog.get_by_id("card", "wind_A")
    _assert_equal(wind_ace["definition_id"], "wind_A", "易阶更新定义 ID")
    _assert_equal(wind_ace["qi_value"], ace_definition["qi"], "易阶真气值读取 base_deck")
    _assert_true(not workshop.apply_run_card_origin(
        growth.run_deck, ["forest_A"], "rank_change", {"direction": "up"}
    ).get("success", false), "A 不能升阶")
    _assert_true(not workshop.apply_run_card_origin(
        growth.run_deck, ["forest_2"], "rank_change", {"direction": "down"}
    ).get("success", false), "2 不能降阶")
    _assert_true(workshop.apply_run_card_origin(
        growth.run_deck, ["fire_6"], "rank_change", {"direction": "down"}
    ).get("success", false), "火6可以降阶")
    _assert_true(not workshop.apply_run_card_origin(
        growth.run_deck, ["fire_6"], "attribute_change", {"attribute": "wind"}
    ).get("success", false), "易阶后不能再次转属")

    var atomic_before_k: Dictionary = growth.run_deck.card_data("mountain_K")
    var atomic_before_a: Dictionary = growth.run_deck.card_data("mountain_A")
    var atomic_failure: Dictionary = workshop.apply_run_card_origin(
        growth.run_deck, ["mountain_K", "mountain_A"],
        "rank_change", {"direction": "up"})
    _assert_true(not atomic_failure.get("success", false), "多目标含非法本源目标时失败")
    _assert_equal(growth.run_deck.card_data("mountain_K"), atomic_before_k, "原子失败不修改前置合法目标")
    _assert_equal(growth.run_deck.card_data("mountain_A"), atomic_before_a, "原子失败不修改非法目标")

    _assert_true(workshop.apply_run_card_reshape(
        growth.run_deck, ["wind_7"], "enhancement", "qi_boost").get("success", false),
        "本源改造后仍可获得强化")
    _assert_true(workshop.apply_run_card_reshape(
        growth.run_deck, ["wind_7"], "imprint", "enlightenment").get("success", false),
        "印记占用独立单值槽")
    _assert_true(workshop.apply_run_card_reshape(
        growth.run_deck, ["wind_7"], "other", "echo_reshape", {"amount": 2}
    ).get("success", false), "其他重塑保存 payload")
    var source: Dictionary = growth.run_deck.card_data("wind_7")
    var copied: Dictionary = workshop.copy_run_card(growth.run_deck, "wind_7", 1)
    _assert_true(copied.get("success", false), "完整复制成功")
    var copied_id := str(copied.get("instance_ids", [""])[0])
    var copied_data: Dictionary = growth.run_deck.card_data(copied_id)
    _assert_true(copied_id != "wind_7", "复制品使用新实例 ID")
    _assert_equal(copied_data["definition_id"], source["definition_id"], "复制继承当前基础身份")
    _assert_equal(copied_data["reshapes"], source["reshapes"], "复制继承本源锁与全部本局重塑")
    _assert_true(not workshop.apply_run_card_origin(
        growth.run_deck, [copied_id], "rank_change", {"direction": "up"}
    ).get("success", false), "复制品继承本源锁")

    var battle_cards: Array = growth.run_deck.create_battle_cards()
    var qi_boost_card = null
    for card in battle_cards:
        if card.id == "wind_7":
            qi_boost_card = card
            break
    _assert_equal(qi_boost_card.effective_qi_value(), 15, "增元由配置令有效真气值+8")
    var pair_cards := []
    for card in battle_cards:
        if card.id in ["forest_8", "fire_8"]:
            card.set_enhancement("momentum")
            pair_cards.append(card)
    var momentum_values := PowerCalculatorScript.calculate(HandEvaluatorScript.evaluate(pair_cards))
    _assert_equal(momentum_values["card_multiplier_bonus"], 2, "两张乘势分别令功法倍率合计+2")
    var mixed = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_9"), "hunyuan:test", catalog.card_reshape_rules)
    mixed.set_enhancement("hunyuan")
    _assert_true(
        mixed.is_attribute("wind") and mixed.is_attribute("forest")
        and mixed.is_attribute("fire") and mixed.is_attribute("mountain"),
        "混元同时满足四种属性识别")
    _assert_equal(mixed.attribute, "wind", "混元不改变基础属性")
    mixed.set_enhancement("momentum")
    _assert_equal(mixed.reshape_enhancement, "momentum", "新强化替换旧强化")

    var save_session = RunSessionScript.new(null, null, null, null, catalog)
    _assert_true(save_session.execute({"type": "setup_run", "seed": 7112}).success, "建立存档测试本局")
    _assert_true(workshop.apply_run_card_origin(
        save_session.growth.run_deck, ["wind_7"],
        "attribute_change", {"attribute": "mountain"}).get("success", false),
        "存档前施加本源")
    workshop.apply_run_card_reshape(
        save_session.growth.run_deck, ["wind_7"], "enhancement", "qi_boost")
    workshop.apply_run_card_reshape(
        save_session.growth.run_deck, ["wind_7"], "imprint", "enlightenment")
    var saved_deck: Dictionary = save_session.growth.run_deck.to_snapshot()
    var restored: Dictionary = RunSaveDataScript.new().capture(
        save_session).restore_session(catalog)
    _assert_true(restored.get("success", false), "新 DTO 本局存档可以读回")
    _assert_equal(restored["run_session"].growth.run_deck.to_snapshot(), saved_deck, "读档保留本源、锁、强化与印记")

func _test_qi_instance_state_contract() -> void:
    var base_catalog = ContentCatalogScript.new()
    _assert_true(base_catalog.load_all(), "真气实例契约测试载入统一目录")
    var values := _catalog_definitions(base_catalog)
    values["card_states"]["other_reshapes"].append({"id": "battle_curse", "name": "战斗诅咒"})
    values["card_states"]["other_reshapes"].append({"id": "scar", "name": "伤痕"})
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_from_definitions(values), "实例测试目录扩展印记和其他重塑")
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
    card.set_enhancement("qi_boost")
    card.set_imprint("enlightenment")
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
    _assert_equal(
        run_data["reshapes"],
        {"origin": {}, "enhancement": "qi_boost", "imprint": "enlightenment", "others": {}},
        "本局实例 DTO 使用新四字段且不含旧品相字段")
    _assert_equal(
        QiCardInstanceDataScript.validate(run_data, catalog),
        [],
        "本局实例DTO通过内容引用校验")
    var legacy_instance: Dictionary = run_data.duplicate(true)
    legacy_instance["version"] = QiCardInstanceDataScript.VERSION - 1
    legacy_instance["reshapes"]["finish"] = "foil"
    _assert_true(
        _array_contains_text(
            QiCardInstanceDataScript.validate(legacy_instance, catalog),
            "真气实例版本不受支持"),
        "旧真气实例版本被明确拒绝而不迁移品相")
    var battle_data: Dictionary = QiCardInstanceDataScript.capture(card, true)
    _assert_equal(
        QiCardInstanceDataScript.validate(battle_data, catalog, true),
        [],
        "包含战斗状态的实例DTO通过内容引用校验")
    var restored = QiCardInstanceDataScript.restore(battle_data)
    _assert_equal(restored.id, first_id, "版本化DTO恢复唯一实例ID")
    _assert_equal(restored.definition_id, "wind_7", "版本化DTO恢复基础定义ID")
    _assert_equal(restored.reshape_imprint, "enlightenment", "版本化DTO恢复印记")
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
    catalog.card_reshape_rules.bind_card(purified)
    _assert_true(CardOriginServiceScript.new(catalog).apply_to_card(
        purified, "attribute_change", {"attribute": "mountain"}).get("success", false),
        "净化测试牌先接受转属本源")
    purified.set_enhancement("qi_boost")
    purified.set_imprint("enlightenment")
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
    _assert_true(purified.reshape_origin.is_empty(), "净化令本源在当前战斗失效")
    _assert_equal(purified.reshape_enhancement, "", "净化令已有强化失效")
    _assert_equal(purified.reshape_imprint, "", "净化令已有印记失效")
    _assert_true(purified.reshape_others.is_empty(), "净化令已有重塑其他失效")
    _assert_equal(purified.anomaly_poison, "", "净化清除已有毒")
    _assert_equal(purified.anomaly_state, "", "净化清除已有状态")
    _assert_equal(purified.anomaly_marks.keys(), ["purification"], "净化清除风标与绝气标记后建立自身")
    _assert_true(purified.anomaly_others.is_empty(), "净化清除已有异状其他")

    var purified_run_data: Dictionary = QiCardInstanceDataScript.capture(purified)
    _assert_equal(purified_run_data["reshapes"]["origin"]["id"], "attribute_change", "净化期间本局DTO仍保存暂存本源")
    _assert_equal(purified_run_data["reshapes"]["enhancement"], "qi_boost", "净化期间本局DTO仍保存暂存强化")
    _assert_equal(purified_run_data["reshapes"]["others"]["battle_curse"]["poison"], "lethal_poison", "净化期间本局DTO仍保存暂存重塑其他")
    var purified_battle_data: Dictionary = QiCardInstanceDataScript.capture(purified, true)
    _assert_true(purified_battle_data["reshapes"]["origin"].is_empty(), "战斗 DTO 记录本源实际失效状态")
    _assert_equal(purified_battle_data["reshapes"]["enhancement"], "", "战斗DTO保留净化期间的实际失效状态")
    _assert_true(purified_battle_data["suppressed_reshapes"].has("enhancement"), "战斗DTO记录待恢复重塑")

    _assert_true(purified.origin_locked(), "本源被净化屏蔽期间锁仍存在")
    _assert_true(not CardOriginServiceScript.new(catalog).apply_to_card(
        purified, "rank_change", {"direction": "up"}).get("success", false),
        "净化屏蔽期间不能绕过本源锁")
    purified.set_enhancement("momentum")
    purified.set_anomaly("poison", "stagnant_poison")
    purified.set_anomaly("state", "qi_dissipation")
    purified.set_anomaly("mark", "returning_wind")
    purified.set_anomaly("other", "temporary_b", {"qi_delta": 2})
    var refreshed: Dictionary = lifecycle.apply_anomaly(
        purified, "mark", "purification")
    _assert_true(refreshed["refreshed"], "重复获得净化只刷新而不清除后来内容")
    _assert_equal(purified.reshape_enhancement, "momentum", "净化后新强化正常生效")
    _assert_true(purified.has_anomaly("poison", "stagnant_poison"), "净化后新毒正常生效")
    _assert_true(purified.has_anomaly("state", "qi_dissipation"), "净化后新状态正常生效")
    _assert_true(purified.has_anomaly("mark", "returning_wind"), "净化后新标记正常生效")
    _assert_true(purified.has_anomaly("other", "temporary_b"), "净化后新异状其他正常生效")

    var restored_after_purification: Dictionary = lifecycle.on_battle_end(purified)
    _assert_equal(purified.reshape_origin["id"], "attribute_change", "战斗结束恢复净化前本源")
    _assert_equal(purified.reshape_enhancement, "momentum", "后来强化替换净化前强化")
    _assert_equal(purified.reshape_imprint, "enlightenment", "战斗结束恢复净化前印记")
    _assert_true(purified.reshape_others.has("battle_curse"), "战斗结束恢复未被替换的重塑其他")
    _assert_true(purified.reshape_others.has("scar"), "多个重塑其他分别恢复")
    _assert_true(purified.anomaly_snapshot()["marks"].is_empty(), "战斗结束移除净化与后来标记")
    _assert_equal(purified.anomaly_poison, "", "净化后新毒不跨战斗")
    _assert_equal(purified.anomaly_state, "", "净化后新状态不跨战斗")
    _assert_true(purified.anomaly_others.is_empty(), "净化后新异状其他不跨战斗")
    _assert_equal(restored_after_purification["origin"]["id"], "attribute_change", "生命周期返回恢复的本源")

    var handler_card = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "mountain_6"),
        id_factory.next_id("mountain_6"))
    handler_card.set_enhancement("qi_boost")
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
        "rules_version": "v0.30",
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
    var conversation_snapshot: AiConversationSnapshot = conversation.snapshot()
    _assert_true(
        conversation_snapshot is AiConversationSnapshot
        and not conversation_snapshot.has_method("value"),
        "AI 对话快照按字段读取且不保留无类型旁路")
    var encoded: String = store.encode(conversation_snapshot)
    var decoded: Dictionary = store.decode(encoded)
    _assert_equal(
        decoded["context_snapshot"]["protocol"]["credentials"]["api_key"],
        "[REDACTED]",
        "AI 会话持久化递归脱敏 API Key")
    _assert_equal(decoded["battle_id"], conversation.battle_id, "AI 审计快照读取战斗 ID")
    _assert_equal(decoded["public_events"].size(), conversation.public_events.size(), "AI 审计快照读取完整公开事件数量")
    _assert_equal(decoded["public_events"][1]["window_id"], "player-only-combo", "AI 审计快照读取事件窗口")
    _assert_equal(int(decoded["public_events"][1]["sequence"]), 11, "AI 审计快照读取事件序号")
    _assert_equal(decoded["exchanges"].size(), conversation.exchanges.size(), "AI 审计快照读取请求回答链")
    provider.free()

func _test_remote_ai_action_window_session_gate() -> void:
    var provider = MockAiProviderScript.new(false)
    var session: BattleSession = BattleSessionScript.new()
    session.use_ai_provider(provider)
    var configuration := {
        "content_seed": 2308,
        "content_id": "remote-ai-window-contract",
        "battle": {
            "scenario_path": "res://data/scripted_battle.json",
            "use_enemy_ai": true,
            "use_remote_ai": true,
        },
        "ai_settings": {
            "timeout_msec": 30000,
            "max_retries": 1,
            "intent_visibility": "full",
        },
    }
    _assert_true(session.setup_battle(configuration), "远程 AI 行动窗口战斗建立成功")
    _assert_true(session.execute({"type": "start_turn"}).success, "远程 AI 战斗开始首个行动窗口")
    var thinking_snapshot = session.snapshot()
    _assert_equal(thinking_snapshot.ai_decision["state"], "thinking", "行动窗口开始时敌方立即进入异步思考")
    _assert_true(not thinking_snapshot.ai_decision["can_player_confirm"], "敌方思考期间玩家确认门禁关闭")
    _assert_equal(thinking_snapshot.locked_enemy_card_count, 0, "AI 回答前敌方不提前移动或锁定真气")
    _assert_equal(provider.submitted_requests.size(), 1, "首个敌方出手机会只发送一次接口请求")
    var first_request: Dictionary = provider.submitted_requests[0]["payload"]
    _assert_true(first_request.get("candidates", []).size() > 1, "远程 AI 只收到本地枚举的多个合法选择")
    _assert_equal(first_request["candidates"][0]["groups"][0]["kind"], "main", "普通候选使用第 0 主牌型组契约")

    var player_hand_before: Array = thinking_snapshot.player.hand
    var blocked_play := session.execute({
        "type": "play_cards",
        "card_ids": [player_hand_before[0]["id"]],
    })
    _assert_true(not blocked_play.success, "敌方思考期间玩家出牌命令被应用层拒绝")
    _assert_true(blocked_play.reason.contains("思考"), "出牌门禁返回明确思考状态")
    _assert_equal(session.snapshot().player.staging_count, 0, "门禁拒绝不会把玩家真气移入待出区")
    var blocked_end := session.execute({"type": "end_turn"})
    _assert_true(not blocked_end.success, "敌方思考期间结束回合同样受门禁保护")

    var consumable_result := session.execute({
        "type": "use_consumable",
        "slot_index": 0,
        "card_ids": [],
    })
    _assert_true(consumable_result.success, "敌方思考期间仍可使用只影响我方的消耗品")
    _assert_equal(provider.submitted_requests.size(), 1, "思考期间使用我方消耗品不取消或重发当前请求")

    provider.queue_result({
        "success": true,
        "body": {
            "schema_version": 1,
            "decision_id": first_request["observation"]["decision_id"],
            "state_hash": first_request["observation"]["state_hash"],
            "candidate_id": first_request["candidates"][0]["candidate_id"],
        },
    })
    _assert_true(provider.complete(str(provider.submitted_requests[0]["request_id"])), "Mock Provider 完成首个远程回答")
    var ready_snapshot = session.snapshot()
    _assert_equal(ready_snapshot.ai_decision["state"], "ready", "合法回答通过后行动窗口转为思考完毕")
    _assert_true(ready_snapshot.ai_decision["can_player_confirm"], "敌方行动锁定后开放玩家确认")
    _assert_true(ready_snapshot.locked_enemy_card_count > 0, "远程候选经本地复核后才锁定敌方真气")
    _assert_true(ready_snapshot.enemy_plan.has("damage"), "本地预览核为已锁定远程候选生成公开伤害意图")

    var mixed_ids: Array[String] = []
    var ready_hand: Array = ready_snapshot.player.hand
    for left_index in range(ready_hand.size()):
        for right_index in range(left_index + 1, ready_hand.size()):
            if ready_hand[left_index]["attribute"] != ready_hand[right_index]["attribute"]:
                mixed_ids = [
                    str(ready_hand[left_index]["id"]),
                    str(ready_hand[right_index]["id"]),
                ]
                break
        if not mixed_ids.is_empty():
            break
    _assert_equal(mixed_ids.size(), 2, "固定起手存在混属性选牌用于制造敌方单方连击窗口")
    var synchronized_result := session.execute({
        "type": "play_cards",
        "card_ids": mixed_ids,
    })
    _assert_true(synchronized_result.success, "双方提案都准备后才进入真实同步结算")
    _assert_equal(provider.submitted_requests.size(), 2, "敌方获得连击出手机会后立即发起第二次接口请求")
    var second_request: Dictionary = provider.submitted_requests[1]["payload"]
    var second_history_types: Array[String] = []
    for event in second_request.get("history_delta", []):
        second_history_types.append(str(event.get("event_type", "")))
    _assert_true(second_history_types.has("consumable_used"), "下一次请求补发思考期间的我方消耗品事件")
    _assert_true(second_history_types.has("cards_played"), "下一次请求包含双方上一击公开出牌历史")
    _assert_true(second_history_types.has("action_resolved"), "下一次请求包含上一击生命防御结算结果")
    _assert_equal(session.snapshot().ai_decision["state"], "thinking", "敌方单方连击使用新的独立思考窗口")

    provider.queue_result({
        "success": true,
        "body": {
            "schema_version": 1,
            "decision_id": second_request["observation"]["decision_id"],
            "state_hash": second_request["observation"]["state_hash"],
            "candidate_id": second_request["candidates"][0]["candidate_id"],
        },
    })
    _assert_true(provider.complete(str(provider.submitted_requests[1]["request_id"])), "Mock Provider 完成敌方单方连击回答")
    _assert_equal(session.snapshot().enemy.discard_count, 2, "玩家无行动机会时敌方合法回答自动完成单方连击")
    _assert_equal(provider.submitted_requests.size(), 2, "同一完整回合自然连击只触发一次，不额外请求")
    _assert_true(session.execute({"type": "end_turn"}).success, "双方行动耗尽后可以正常结束完整回合")

    var timeout_provider = MockAiProviderScript.new(false)
    var timeout_session: BattleSession = BattleSessionScript.new()
    timeout_session.use_ai_provider(timeout_provider)
    var timeout_configuration: Dictionary = configuration.duplicate(true)
    timeout_configuration["content_seed"] = 2309
    timeout_configuration["content_id"] = "remote-ai-timeout-contract"
    _assert_true(timeout_session.setup_battle(timeout_configuration), "远程 AI 超时保底战斗建立成功")
    timeout_session.execute({"type": "start_turn"})
    _assert_true(timeout_session.poll_ai_timeout(9223372036854775807), "到达截止时间后取消远程请求")
    var fallback_snapshot = timeout_session.snapshot()
    _assert_equal(fallback_snapshot.ai_decision["state"], "fallback_ready", "远程超时后由本地 Utility AI 接管")
    _assert_true(fallback_snapshot.ai_decision["can_player_confirm"], "本地接管成功后重新开放玩家确认")
    _assert_equal(timeout_provider.pending.size(), 0, "超时取消清理 Provider 待处理请求")
    var timeout_system_log: Array = fallback_snapshot.system_log
    var has_fallback_log := false
    for entry in timeout_system_log:
        if str(entry.get("category", "")) == "remote_ai_fallback":
            has_fallback_log = true
            break
    _assert_true(has_fallback_log, "远程超时降级进入统一系统日志")
    var timeout_exchange_kinds: Array[String] = []
    for exchange in timeout_session.ai_conversation_snapshot().exchanges:
        timeout_exchange_kinds.append(str(exchange.get("kind", "")))
    _assert_true(timeout_exchange_kinds.has("response"), "AI 会话持久记录超时取消响应")
    _assert_true(timeout_exchange_kinds.has("fallback_selected"), "AI 会话持久记录最终本地接管行动")
    provider.free()
    timeout_provider.free()

func _test_chat_completions_provider_contract() -> void:
    var defaults = AiProviderSettingsScript.new()
    _assert_equal(defaults.provider_id, "deepseek", "远程 AI 默认服务商为 DeepSeek")
    _assert_equal(defaults.base_url, "https://api.deepseek.com", "DeepSeek 默认 base_url 正确")
    _assert_equal(defaults.endpoint_url(), "https://api.deepseek.com/chat/completions", "OpenAI 兼容 Chat Completions 端点正确")
    _assert_equal(defaults.model, "deepseek-v4-flash", "频繁战斗窗口默认使用 Flash 模型")
    _assert_equal(defaults.reasoning_effort, "medium", "Flash 默认使用中等推理强度")
    _assert_true(defaults.thinking_enabled, "DeepSeek 默认开启 thinking")
    _assert_true(not defaults.public_snapshot().has("api_key"), "公开 Provider 设置不包含 API Key 字段")

    var pro = AiProviderSettingsScript.new({"model": "deepseek-v4-pro"})
    _assert_equal(pro.reasoning_effort, "high", "Pro 模型默认使用高推理强度")
    var custom = AiProviderSettingsScript.new({
        "provider_id": "custom_openai_compatible",
        "base_url": "https://example.invalid/v1/",
        "path": "/chat/completions",
        "model": "custom-strategist",
        "reasoning_effort": "low",
    })
    _assert_equal(custom.endpoint_url(), "https://example.invalid/v1/chat/completions", "通用 Provider 正确拼接自定义端点")
    _assert_equal(custom.model, "custom-strategist", "模型字符串允许玩家自由填写")
    _assert_true(custom.is_valid(), "自定义 OpenAI 兼容 Provider 设置通过基础校验")

    var prompt = AiPromptEncoderScript.new()
    var system_content := str(prompt.system_message()["content"])
    _assert_true(system_content.contains("最终胜率"), "通用提示词明确优化全局胜率而非即时最大伤害")
    _assert_true(system_content.contains("只能从 candidates"), "通用提示词限制 AI 只能选择本地候选")
    _assert_true(system_content.contains("隐藏手牌"), "通用提示词禁止猜测玩家隐藏信息")
    _assert_true(system_content.contains("candidate_id"), "通用提示词内置固定 JSON 返回字段")
    _assert_true(not system_content.contains("decision-provider-test"), "稳定系统提示不混入单次决策内容")

    var provider = ChatCompletionsAiProviderScript.new({
        "api_key": "unit-test-secret",
        "extra_body": {
            "temperature": 0.15,
            "model": "must-not-override",
            "messages": [{"role": "user", "content": "must-not-override"}],
            "stream": true,
            "api_key": "must-not-leak",
            "metadata": {"authorization": "nested-must-not-leak"},
        },
    })
    var decision_payload := {
        "schema_version": 1,
        "type": "battle_decision",
        "battle_id": "provider-contract-battle",
        "provider_epoch": 0,
        "observation": {
            "decision_id": "decision-provider-test",
            "state_hash": "provider-state-hash",
        },
        "history_summary": {},
        "history_delta": [],
        "candidates": [{"candidate_id": "candidate-000"}],
    }
    var request_body: Dictionary = provider.build_request_payload(decision_payload)
    _assert_equal(request_body["model"], "deepseek-v4-flash", "请求体使用配置模型")
    _assert_equal(request_body["thinking"], {"type": "enabled"}, "请求体使用 DeepSeek thinking 结构")
    _assert_equal(request_body["reasoning_effort"], "medium", "请求体携带通用推理强度")
    _assert_equal(request_body["stream"], false, "战斗决策默认使用非流式响应")
    _assert_equal(request_body["temperature"], 0.15, "通用附加请求字段进入请求体")
    _assert_true(not request_body.has("api_key"), "通用附加字段不能把凭据写入请求体")
    _assert_true(not JSON.stringify(request_body).contains("must-not-leak"), "嵌套附加字段中的凭据也不会进入请求或审计")
    _assert_equal(request_body["model"], "deepseek-v4-flash", "通用附加字段不能覆盖配置模型")
    _assert_equal(request_body["messages"].size(), 2, "首次请求只包含稳定系统提示和一个结构化用户消息")
    _assert_equal(request_body["messages"][0]["role"], "system", "Chat Completions 首条消息为系统提示")
    _assert_true(str(request_body["messages"][1]["content"]).contains("decision-provider-test"), "单次决策只进入结构化用户消息")
    _assert_true(not request_body.has("api_key"), "API Key 不进入 JSON 请求体")
    _assert_true(not provider.submitted_requests.any(func(entry): return JSON.stringify(entry).contains("unit-test-secret")), "Provider 审计请求不保存 API Key")

    var next_epoch_payload: Dictionary = decision_payload.duplicate(true)
    next_epoch_payload["provider_epoch"] = 1
    next_epoch_payload["observation"]["decision_id"] = "decision-provider-epoch-1"
    var next_epoch_body: Dictionary = provider.build_request_payload(next_epoch_payload)
    _assert_equal(next_epoch_body["messages"].size(), 2, "历史压缩推进 Provider epoch 后重建短会话前缀")

    provider._rollback_messages({
        "battle_id": "provider-contract-battle",
        "message_count_before": 1,
    })
    _assert_equal(provider._messages_by_battle["provider-contract-battle"].size(), 1, "取消或失败请求会回滚未获回答的用户消息")

    var decision_json := JSON.stringify({
        "schema_version": 1,
        "decision_id": "decision-provider-test",
        "state_hash": "provider-state-hash",
        "candidate_id": "candidate-000",
        "reason_code": "preserve_future_options",
        "confidence": 0.8,
    })
    var parsed_response: Dictionary = provider.parse_provider_response(
        HTTPRequest.RESULT_SUCCESS,
        200,
        JSON.stringify({
            "choices": [{"message": {"content": decision_json}}],
            "usage": {"prompt_tokens": 120, "completion_tokens": 24},
        }))
    _assert_true(parsed_response["success"], "通用 Provider 解析 OpenAI 兼容成功响应")
    _assert_equal(parsed_response["body"], decision_json, "Provider 把 assistant content 交给本地协议验证器")
    _assert_equal(parsed_response["usage"]["completion_tokens"], 24, "Provider 保留用量供本地审计")
    var http_error: Dictionary = provider.parse_provider_response(
        HTTPRequest.RESULT_SUCCESS,
        401,
        JSON.stringify({"error": {"message": "invalid api key"}}))
    _assert_equal(http_error["error_code"], "HTTP_STATUS_401", "HTTP 错误转换为稳定 Provider 错误码")
    _assert_equal(http_error["message"], "invalid api key", "Provider 保留兼容服务返回的错误信息")

    var validator = AiResponseValidatorScript.new()
    var unexpected_field: Dictionary = validator.validate({
        "schema_version": 1,
        "decision_id": "decision-provider-test",
        "state_hash": "provider-state-hash",
        "candidate_id": "candidate-000",
        "explanation": "不应返回的自然语言",
    }, decision_payload["observation"], ["candidate-000"])
    _assert_equal(unexpected_field["error_code"], "UNEXPECTED_FIELD", "本地协议拒绝提示词之外的额外返回字段")
    var factory_defaults: Dictionary = AiProviderFactoryScript.default_deepseek_config()
    _assert_equal(factory_defaults["provider_id"], "deepseek", "Provider 工厂公开 DeepSeek 默认配置")
    _assert_true(not factory_defaults.has("api_key"), "Provider 工厂默认配置不持久化密钥")
    provider.free()

func _test_ai_settings_and_conversation_disk_contract() -> void:
    var example := ConfigFile.new()
    _assert_equal(
        example.load("res://config/ai_settings.example.cfg"),
        OK,
        "仓库 AI 配置样例保持为可解析的 Godot ConfigFile")
    _assert_true(not bool(example.get_value("remote_ai", "enabled", true)), "AI 配置样例默认禁止联网")
    _assert_equal(example.get_value("provider", "api_key", "missing"), "", "AI 配置样例不携带真实密钥")
    var settings_path := "/tmp/taiwu-ai-settings-contract.cfg"
    if FileAccess.file_exists(settings_path):
        DirAccess.remove_absolute(settings_path)
    var settings_service = AiSettingsServiceScript.new(settings_path)
    _assert_true(settings_service.load_or_create(), "AI 设置服务自动建立可编辑配置文件")
    _assert_true(FileAccess.file_exists(settings_path), "AI 设置配置文件写入指定磁盘路径")
    var defaults: Dictionary = settings_service.public_snapshot()
    _assert_true(not defaults["enabled"], "远程 AI 默认关闭，避免测试和离线游玩意外联网")
    _assert_equal(defaults["provider"]["model"], "deepseek-v4-flash", "配置文件沿用 DeepSeek Flash 默认模型")
    _assert_true(not defaults["provider"].has("api_key"), "公开 AI 设置快照不暴露 API Key 字段")

    var editable := ConfigFile.new()
    _assert_equal(editable.load(settings_path), OK, "生成的 AI 配置可由 Godot ConfigFile 重新读取")
    editable.set_value("remote_ai", "enabled", true)
    editable.set_value("provider", "api_key", "settings-contract-secret")
    editable.set_value("provider", "model", "custom-compatible-model")
    editable.set_value("conversation", "compression_interval_rounds", 7)
    editable.set_value("storage", "conversation_directory", "/tmp/taiwu-ai-conversation-contract")
    _assert_equal(editable.save(settings_path), OK, "玩家可以直接修改并保存 AI 配置文件")
    _assert_true(settings_service.reload(), "AI 设置服务重新载入玩家编辑后的配置")
    var runtime_profile: Dictionary = settings_service.runtime_profile(true)
    _assert_true(runtime_profile["enabled"], "配置文件可以启用远程 AI")
    _assert_equal(runtime_profile["provider"]["api_key"], "settings-contract-secret", "运行时 Provider 可以读取配置文件 API Key")
    _assert_equal(runtime_profile["provider"]["model"], "custom-compatible-model", "配置文件允许任意兼容模型名")
    _assert_equal(runtime_profile["conversation"]["compression_interval_rounds"], 7, "配置文件控制历史压缩间隔")
    _assert_true(not JSON.stringify(settings_service.public_snapshot()).contains("settings-contract-secret"), "公开设置与日志投影不会泄露配置文件 API Key")

    var store = AiConversationStoreScript.new()
    var unsafe_battle_id := "battle/contract:01"
    var conversation_path: String = store.path_for_battle(
        unsafe_battle_id,
        "/tmp/taiwu-ai-conversation-contract")
    _assert_true(not conversation_path.get_file().contains("/"), "会话文件名会清理路径分隔符")
    _assert_true(store.save(conversation_path, {
        "schema_version": 1,
        "battle_id": unsafe_battle_id,
        "api_key": "conversation-secret",
        "nested": {"authorization": "Bearer conversation-secret"},
        "public_events": [{"sequence": 3, "event_type": "cards_played"}],
    }), "会话存储器自动创建目录并保存快照")
    _assert_true(FileAccess.file_exists(conversation_path), "脱敏 AI 会话实际写入磁盘")
    var raw_conversation := FileAccess.get_file_as_string(conversation_path)
    _assert_true(not raw_conversation.contains("conversation-secret"), "磁盘 AI 会话递归移除 API Key 与认证头")
    _assert_true(raw_conversation.contains(AiConversationStoreScript.REDACTED), "磁盘会话保留明确脱敏占位符供审计")
    var loaded_conversation: Dictionary = store.load(conversation_path)
    _assert_equal(loaded_conversation["battle_id"], unsafe_battle_id, "磁盘 AI 会话可以无损恢复公开身份")
    _assert_equal(loaded_conversation["public_events"][0]["sequence"], 3, "磁盘 AI 会话可以恢复公开历史序号")

    var mock_provider = MockAiProviderScript.new(false)
    var first_session = BattleSessionScript.new()
    first_session.configure_ai_runtime(runtime_profile)
    first_session.use_ai_provider(mock_provider)
    var battle_config := {
        "content_seed": 8811,
        "content_id": "ai-disk-contract",
        "battle": {
            "scenario_path": "res://data/scripted_battle.json",
            "use_enemy_ai": true,
            "use_remote_ai": false,
        },
    }
    _assert_true(first_session.setup_battle(battle_config), "配置文件启用状态可以为普通敌人开启远程 AI")
    first_session.execute({"type": "start_turn"})
    var autosave_path := first_session.ai_conversation_path()
    _assert_true(FileAccess.file_exists(autosave_path), "行动窗口变化自动保存脱敏 AI 会话")
    var first_saved: Dictionary = store.load(autosave_path)
    _assert_true(first_saved.get("public_events", []).size() > 0, "自动会话文件包含公开行动历史")
    _assert_true(first_saved.get("exchanges", []).size() > 0, "自动会话文件包含请求审计链")

    var restarted_session = BattleSessionScript.new()
    restarted_session.configure_ai_runtime(runtime_profile)
    var restarted_provider = MockAiProviderScript.new(false)
    restarted_session.use_ai_provider(restarted_provider)
    _assert_true(restarted_session.setup_battle(battle_config), "重新进入相同节点时从头建立新战斗")
    restarted_session.execute({"type": "start_turn"})
    var restarted_path := restarted_session.ai_conversation_path()
    _assert_true(restarted_path != autosave_path, "重新开始战斗会建立独立 AI 审计会话")
    _assert_true(FileAccess.file_exists(autosave_path), "旧战斗 AI 审计文件不会被新尝试覆盖")
    _assert_true(FileAccess.file_exists(restarted_path), "新战斗尝试拥有自己的 AI 审计文件")
    _assert_true(not restarted_session.has_method("load_ai_conversation"), "战斗会话不提供中途 AI 续接入口")
    _assert_true(not restarted_session.ai_coordinator.has_method("restore_conversation"), "行动窗口不从旧对话恢复")
    _assert_true(not restarted_session.ai_coordinator.conversation.has_method("resume_provider_session"), "Provider 会话不跨战斗尝试续接")
    _assert_true(not restarted_session.ai_coordinator.conversation.has_method("restore"), "AI 会话对象不提供续战恢复入口")
    mock_provider.free()
    restarted_provider.free()

func _test_effect_handler_registry_contract() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 814
    var executor = EffectExecutorScript.new(rng)
    _assert_true(not executor.registry.operation_ids().is_empty(), "运行时注册表公开稳定战斗效果 ID")
    _assert_equal(executor.registry.handler_group("damage"), "damage", "伤害操作进入伤害处理器")
    _assert_equal(executor.registry.handler_group("defense"), "defense", "防御操作进入防御处理器")
    _assert_equal(executor.registry.handler_group("draw"), "card_zone", "抽牌操作进入牌区处理器")
    _assert_equal(executor.registry.handler_group("apply_random_card_anomaly"), "card_anomaly", "真气异状进入异状处理器")
    _assert_equal(executor.registry.handler_group("add_target_stack"), "stack", "层数操作进入层数处理器")
    _assert_equal(executor.registry.handler_group("register_attack_counter_delay"), "flow_delay", "延迟记录进入流程处理器")

    var unknown_result: Dictionary = executor.execute_all([{"op": "not_registered"}], {})
    _assert_true(not unknown_result["success"], "未注册操作码在执行边界被安全拒绝")
    _assert_true(str(unknown_result["detail"]).contains("未注册"), "未知操作码返回明确诊断")

    var probe_handler := ProbeEffectHandlerScript.new()
    _assert_true(executor.registry.register_handler(probe_handler), "新处理器可通过注册接口扩展")
    _assert_true(not executor.registry.register_handler(ProbeEffectHandlerScript.new()), "重复操作码默认不能覆盖现有处理器")
    _assert_true(
        not executor.registry.register_handler(ProbeEffectHandlerScript.new(["duplicate_probe", "duplicate_probe"])),
        "单个效果处理器不能重复声明同一效果 ID")
    _assert_true(
        not executor.registry.register_handler(ProbeEffectHandlerScript.new(["Bad Effect ID"])),
        "效果 ID 必须使用稳定 snake_case")
    var probe_context := {}
    var probe_result: Dictionary = executor.execute_all([{"op": "probe_effect", "amount": 7}], probe_context)
    _assert_true(probe_result["success"], "动态注册处理器可以参与统一执行链")
    _assert_equal(probe_context["probe_count"], 1, "动态处理器只执行一次")
    _assert_equal(
        executor.summarize_intent([{"op": "probe_effect", "amount": 7}], {})["defense"],
        7,
        "动态处理器同时接入预览汇总链")

func _test_effect_extension_entry_contract() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 815
    var registry = EffectHandlerRegistryScript.new(rng)
    _assert_true(registry.register_handler(ProbeEffectHandlerScript.new()), "测试效果只在统一注册入口登记")
    var duplicate_registry = EffectHandlerRegistryScript.new(rng)
    _assert_true(duplicate_registry.register_handler(ProbeEffectHandlerScript.new()), "重复注册探针先登记一次")
    _assert_true(not duplicate_registry.register_handler(ProbeEffectHandlerScript.new()), "重复效果 ID 被注册表拒绝")

    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "效果扩展测试载入基线内容")
    var definitions: Dictionary = {}
    for key in ContentCatalogScript.CONTENT_ORDER:
        definitions[key] = catalog.definition(key)
    definitions["techniques"]["techniques"][0]["effects"] = [
        {"op": "probe_effect", "amount": 9},
    ]
    var registered_catalog = ContentCatalogScript.new(null, registry)
    _assert_true(
        registered_catalog.load_from_definitions(definitions),
        "已注册效果在内容加载校验阶段可直接使用")
    var duplicate_catalog = ContentCatalogScript.new(null, duplicate_registry)
    _assert_true(not duplicate_catalog.load_from_definitions(definitions), "重复注册在内容校验阶段明确失败")
    _assert_true(
        _array_contains_text(duplicate_catalog.errors, "效果 ID 重复注册：probe_effect"),
        "重复注册错误包含稳定效果 ID")

    var invalid_definitions := definitions.duplicate(true)
    invalid_definitions["techniques"]["techniques"][0]["effects"][0]["amount"] = 0
    var invalid_result: Dictionary = ContentValidatorScript.new(registry).validate(invalid_definitions)
    _assert_true(not invalid_result["valid"], "已注册效果的非法参数在内容校验阶段失败")
    _assert_true(
        _array_contains_text(invalid_result["errors"], "amount 必须是正整数"),
        "非法参数返回处理器声明的明确诊断")

    var invalid_condition_definitions := _catalog_definitions(catalog)
    for technique in invalid_condition_definitions["techniques"]["techniques"]:
        if str(technique.get("id", "")) == "borrow_fire_guard_heart":
            technique["effects"][1]["when"]["actor_defense_equals"] = -1
            break
    var invalid_condition_result: Dictionary = ContentValidatorScript.new().validate(
        invalid_condition_definitions)
    _assert_true(
        not invalid_condition_result["valid"],
        "非法防御条件在内容加载阶段失败")
    _assert_true(
        _array_contains_text(
            invalid_condition_result["errors"],
            "actor_defense_equals: 必须是非负整数"),
        "非法防御条件返回明确诊断：%s" % str(invalid_condition_result["errors"]))

    var missing_registry_catalog = ContentCatalogScript.new()
    _assert_true(not missing_registry_catalog.load_from_definitions(definitions), "缺失效果注册在内容校验阶段失败")
    _assert_true(
        _array_contains_text(missing_registry_catalog.errors, "未知效果操作码 probe_effect"),
        "缺失注册返回稳定效果 ID")

    var actor = BattleSideScript.new("效果探针行动方")
    var executor = EffectExecutorScript.new(rng, registry)
    var effect := {"op": "probe_effect", "amount": 9}
    var preview: Dictionary = executor.summarize_intent([effect], {"actor": actor})
    var resolved: Dictionary = executor.execute_all([effect], {"actor": actor})
    _assert_true(resolved["success"], "测试效果通过统一执行入口结算")
    _assert_equal(preview["defense"], actor.defense, "测试效果预览与实际结算结果一致")

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
    temporary_target.set_enhancement("qi_boost")
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
    _assert_equal(engine.timing_system.history[-3]["timing"], "action_window_end", "结束回合先关闭行动窗口")
    _assert_equal(
        engine.timing_system.history.slice(-2).map(
            func(entry): return entry["actor_id"]),
        ["player", "enemy"],
        "行动窗口关闭后双方依次进入回合结束")
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
            "card_reshape_runtime.battle_victory",
            "status_system.card_battle_end",
            "status_system.transient_battle_end",
            "combat_engine.flow_cleanup",
        ],
        "战斗结束先结算胜利重塑，再清真气异状与临时战斗状态")
    _assert_equal(ending_card.anomaly_poison, "", "战斗结束时点清除真气异状")
    _assert_true(engine.player.stacks.is_empty() and engine.enemy.stacks.is_empty(), "战斗结束时点清除敌我临时层数")
    _assert_equal(engine.delayed_effects.size(), 0, "战斗结束时点清除未到期延迟记录")
    _assert_equal(engine.player.defense + engine.enemy.defense, 0, "战斗结束时点清除双方防御")

    var scripted = CombatEngineScript.new()
    _assert_true(scripted.setup_scripted_battle(2308), "双方时点集成测试载入脚本战斗")
    scripted.start_player_turn()
    var turn_start_actor_ids: Array = []
    for entry in scripted.timing_system.history:
        if entry["timing"] == "turn_start":
            turn_start_actor_ids.append(entry["actor_id"])
    _assert_equal(turn_start_actor_ids, ["player", "enemy"], "敌我通过同一种行动方回合开始时点进入正常补牌")

func _test_defense_retention_policy_and_round_decay() -> void:
    var side = BattleSideScript.new("保留规则测试", "retention_probe")
    var policy = DefenseRetentionPolicyScript.new()
    for test_case in [
        {"before": 1, "after": 0},
        {"before": 3, "after": 1},
        {"before": 20, "after": 10},
    ]:
        side.defense = int(test_case["before"])
        var result: Dictionary = policy.apply_decay(side)
        _assert_equal(result["before"], test_case["before"], "默认衰减记录衰减前防御")
        _assert_equal(result["after"], test_case["after"], "默认 50% 保留比例显式向下取整")
        _assert_equal(result["lost"], test_case["before"] - test_case["after"], "默认衰减记录失去防御")
        _assert_equal(result["retention_percent"], 50, "默认防御保留比例为 50%")
        _assert_true(not result["prevented"], "默认防御衰减未被阻止")
        _assert_true(result["side"] == side, "结构化衰减结果保留战斗方")

    var bonus_provider = DefenseRetentionProbe.new(side, 25)
    _assert_true(policy.register_provider("test.retention_bonus", bonus_provider), "保留比例提供者可以注册")
    _assert_true(
        not policy.register_provider("test.retention_bonus", bonus_provider),
        "保留比例提供者 ID 不可重复注册")
    side.defense = 20
    var bonus_result: Dictionary = policy.apply_decay(side)
    _assert_equal(bonus_result["retention_percent"], 75, "额外保留比例与默认比例相加")
    _assert_equal(bonus_result["after"], 15, "合并全部比例后只取整一次")

    var lower_provider = DefenseRetentionProbe.new(side, -200)
    _assert_true(policy.register_provider("test.retention_lower", lower_provider), "负向保留比例提供者可以注册")
    side.defense = 20
    var clamped_result: Dictionary = policy.apply_decay(side)
    _assert_equal(clamped_result["retention_percent"], 0, "最终保留比例下限为 0%")
    _assert_equal(clamped_result["after"], 0, "0% 保留不会产生负防御")
    _assert_true(policy.unregister_provider("test.retention_lower"), "负向保留比例提供者可以注销")

    var upper_provider = DefenseRetentionProbe.new(side, 200)
    _assert_true(policy.register_provider("test.retention_upper", upper_provider), "正向保留比例提供者可以注册")
    side.defense = 20
    var upper_result: Dictionary = policy.apply_decay(side)
    _assert_equal(upper_result["retention_percent"], 100, "最终保留比例上限为 100%")
    _assert_equal(upper_result["after"], 20, "比例上限保证防御不会增长")
    _assert_true(not upper_result["prevented"], "比例达到 100% 不伪装为不衰减覆盖")
    _assert_true(policy.unregister_provider("test.retention_upper"), "正向保留比例提供者可以注销")

    var prevent_provider = DefenseRetentionProbe.new(side, 0, true)
    _assert_true(policy.register_provider("test.retention_prevent", prevent_provider), "不衰减覆盖提供者可以注册")
    side.defense = 20
    var prevented_result: Dictionary = policy.apply_decay(side)
    _assert_equal(prevented_result["retention_percent"], 100, "不衰减覆盖最终比例为 100%")
    _assert_equal(prevented_result["after"], 20, "不衰减覆盖完整保留防御")
    _assert_true(prevented_result["prevented"], "结构化结果记录衰减被阻止")
    _assert_true(policy.unregister_provider("test.retention_prevent"), "保留比例提供者可以注销")
    _assert_true(not policy.unregister_provider("test.retention_prevent"), "重复注销提供者返回失败")

    var engine = CombatEngineScript.new()
    engine.setup(82301, false)
    engine.start_player_turn()
    _assert_equal(engine.current_round_actors, [engine.player], "非脚本模式敌方没有本回合行动资格")
    engine.player.defense = 20
    engine.enemy.defense = 5
    var lifecycle_observations: Array[String] = []
    engine.timing_system.register_handler(
        BattleTimingSystemScript.ACTION_WINDOW_END,
        "test.capture_defense_before_decay",
        1,
        func(_event):
            lifecycle_observations.append("action_window:%d:%d" % [
                engine.player.defense, engine.enemy.defense])
            return {"success": true})
    engine.timing_system.register_handler(
        BattleTimingSystemScript.TURN_END,
        "test.capture_defense_after_decay",
        1,
        func(event):
            lifecycle_observations.append("turn_end:%s:%d" % [
                event.actor.owner_id, event.actor.defense])
            if event.actor == engine.player:
                event.actor.add_defense(8)
            return {"success": true})
    engine.end_player_turn()
    _assert_equal(lifecycle_observations, [
        "action_window:20:5",
        "turn_end:player:10",
        "turn_end:enemy:2",
    ], "防御衰减位于行动窗口结束后、双方所有 TURN_END 效果前")
    _assert_equal(engine.player.defense, 18, "回合结束新获得防御不参与已完成的衰减")
    _assert_equal(engine.enemy.defense, 2, "无行动资格的一方同样完成一次衰减")
    _assert_equal(engine.last_defense_decay_results[0]["lost"], 10, "回合服务保留我方结构化衰减结果")
    _assert_equal(engine.last_defense_decay_results[1]["side_id"], "enemy", "回合服务保留敌方结构化衰减结果")
    var timing_count_after_round: int = engine.timing_system.history.size()
    engine.round_service.finish_round_end()
    _assert_equal(engine.player.defense, 18, "同一完整回合重复结束不会再次衰减")
    _assert_equal(engine.timing_system.history.size(), timing_count_after_round, "同一完整回合重复结束不重发 TURN_END")

    engine.timing_system.unregister_handler(
        BattleTimingSystemScript.TURN_END,
        "test.capture_defense_after_decay")
    engine.start_player_turn()
    engine.player.defense = 20
    engine.enemy.defense = 20
    var engine_provider = DefenseRetentionProbe.new(engine.player, 25)
    _assert_true(
        engine.register_defense_retention_provider(
            "test.engine_retention_bonus", engine_provider),
        "战斗引擎公开统一保留比例提供者入口")
    engine.end_player_turn()
    _assert_equal(engine.player.defense, 15, "引擎提供者入口只修改命中的持有方")
    _assert_equal(engine.enemy.defense, 10, "提供者默认不影响另一方")
    _assert_true(
        engine.unregister_defense_retention_provider(
            "test.engine_retention_bonus"),
        "战斗引擎公开统一保留比例提供者注销入口")
    _assert_true(
        engine.timing_system.unregister_handler(
            BattleTimingSystemScript.ACTION_WINDOW_END,
            "test.capture_defense_before_decay"),
        "时点测试完成后注销捕获处理器")

    engine.player.defense = 7
    engine.enemy.defense = 9
    engine.enemy.life = 0
    engine._update_battle_state()
    _assert_equal(engine.player.defense + engine.enemy.defense, 0, "战斗结束时双方防御清空")

func _test_status_behavior_registry_contract() -> void:
    var registry = StatusBehaviorRegistryScript.new()
    var probe = ProbeStatusBehaviorHandlerScript.new()
    _assert_true(registry.register_handler(probe), "状态行为注册表接收外部小型处理器")
    _assert_true(
        not registry.register_handler(ProbeStatusBehaviorHandlerScript.new()),
        "状态行为注册表拒绝重复处理器 ID")
    _assert_true(
        not registry.register_handler(ProbeStatusBehaviorHandlerScript.new(["dup", "dup"])),
        "单个处理器不能重复声明同一行为 ID")
    _assert_true(
        registry.register_handler(
            ProbeStatusBehaviorHandlerScript.new(["probe_status_behavior"]), true),
        "显式替换可以更新已登记状态处理器")
    var unknown: Dictionary = registry.execute({"handler": "missing_behavior"}, null)
    _assert_true(not unknown.get("success", true), "运行边界拒绝未知状态处理器")
    _assert_true(str(unknown.get("detail", "")).contains("未注册"), "未知处理器返回稳定诊断")

    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "状态注册覆盖测试载入内容目录")
    var system = StatusSystemScript.new(catalog)
    for content_type in ["anomaly", "actor_status"]:
        for definition in catalog.all_of(content_type):
            for behavior in definition.get("behaviors", []):
                _assert_true(
                    system.behavior_registry.has_handler(str(behavior.get("handler", ""))),
                    "%s.%s 的行为已登记：%s" % [
                        content_type,
                        definition.get("id", ""),
                        behavior.get("handler", "")])

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
    system.add_actor_status(engine.player, "qi_intake", 2, "状态契约")
    system.add_actor_status(engine.player, "full_sleeve", 2, "状态契约")
    system.add_actor_status(engine.player, "bound_sleeve", 1, "状态契约")
    _assert_equal(engine.player.current_hand_limit(), 10, "纳气、盈袖与束袖统一计算当前手牌上限")

    var card = _card("9", "fire")
    card.set_enhancement("qi_boost")
    engine.player.hand = [card]
    _assert_true(system.apply_card_anomaly(card, "poison", "lethal_poison", {}, "状态契约")["success"], "状态系统施加烈毒")
    _assert_true(system.apply_card_anomaly(card, "poison", "stagnant_poison", {}, "状态契约")["success"], "新毒通过状态系统替换唯一毒槽")
    _assert_true(card.has_anomaly("poison", "stagnant_poison"), "唯一毒槽保留后来毒")
    system.apply_card_anomaly(card, "state", "vulnerability", {}, "状态契约")
    system.apply_card_anomaly(card, "state", "acupoint_block", {}, "状态契约")
    _assert_true(card.has_anomaly("state", "acupoint_block"), "新状态通过状态系统替换唯一状态槽")
    system.apply_card_anomaly(card, "mark", "wind_lure", {}, "状态契约")
    system.apply_card_anomaly(card, "mark", "wind_mark", {}, "状态契约")
    _assert_true(card.is_attribute("wind"), "风标记令普通真气同时视为风")
    system.apply_card_anomaly(card, "mark", "qi_severance", {}, "状态契约")
    _assert_equal(card.anomaly_marks.size(), 3, "不同标记可通过状态系统共存")
    system.apply_card_anomaly(card, "mark", "purification", {}, "状态契约")
    _assert_equal(card.reshape_enhancement, "", "净化通过状态系统屏蔽既有强化")
    _assert_equal(card.anomaly_marks.keys(), ["purification"], "净化清除既有异状后保留自身")
    system.apply_card_anomaly(card, "state", "qi_dissipation", {}, "净化后施加")
    _assert_true(card.has_anomaly("state", "qi_dissipation"), "净化不阻止后来施加的异状")

    system.consume_actor_status(engine.player, "gu_mark", 99, "状态契约")
    var poison_card = _card("7", "forest")
    poison_card.set_enhancement("qi_boost")
    engine.player.staging = [poison_card]
    system.apply_card_anomaly(poison_card, "poison", "lethal_poison", {}, "状态契约")
    var poison_resolutions: Array = system.resolve_played_card_anomalies(
        engine.player,
        engine.player.staging)
    _assert_equal(poison_resolutions[0]["damage"], 15, "烈毒读取增元后的当前有效真气值")
    _assert_equal(engine.player.life, 85, "烈毒通过统一伤害入口作用于持有者")
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
        status_snapshot.status_history.size(),
        system.history.size(),
        "战斗快照公开状态系统的深复制历史")

    engine.timing_system.emit_timing(BattleTimingSystemScript.BATTLE_END, {
        "actors": [engine.player, engine.enemy],
    })
    _assert_equal(card.reshape_enhancement, "qi_boost", "战斗结束移除净化并恢复未替换的强化")
    _assert_true(card.anomaly_snapshot()["marks"].is_empty(), "战斗结束清除全部战斗异状")
    _assert_true(engine.player.stacks.is_empty() and engine.enemy.stacks.is_empty(), "战斗结束统一清除敌我角色状态")
    _assert_true(not system.history.is_empty(), "状态系统公开结构化变化历史")
    _assert_true(not shared_log.entries("battle").is_empty(), "状态变化进入统一战斗日志")

func _test_declared_card_status_runtime_semantics() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(816, false)
    engine.sequence_book.configure({"high_card": []})

    var dissipated = _card("9", "forest")
    engine.player.hand = [dissipated]
    engine.status_system.apply_card_anomaly(
        dissipated, "state", "qi_dissipation", {}, "状态语义测试")
    _assert_equal(
        engine.preview([dissipated.id])["values"]["card_total"],
        4,
        "散气令参与最高牌型的有效真气贡献减半并向下取整")

    var stagnant = _card("9", "forest")
    engine.player.hand = [stagnant]
    engine.status_system.apply_card_anomaly(
        stagnant, "poison", "stagnant_poison", {}, "状态语义测试")
    _assert_equal(
        engine.preview([stagnant.id])["values"]["card_total"],
        5,
        "郁毒按原本贡献计算并扣除向下取整的50%削减值")
    engine.status_system.apply_card_anomaly(
        stagnant, "state", "qi_dissipation", {}, "状态语义测试")
    _assert_equal(
        engine.preview([stagnant.id])["values"]["card_total"],
        2,
        "散气先确定有效贡献后郁毒独立扣除该贡献的50%")

    var acupoint_a = _card("2", "forest")
    var acupoint_b = _card("3", "forest")
    var vulnerable = _card("4", "mountain")
    engine.player.hand = [acupoint_a, acupoint_b]
    engine.enemy.hand = [vulnerable]
    engine.status_system.apply_card_anomaly(
        acupoint_a, "state", "acupoint_block", {}, "状态语义测试")
    engine.status_system.apply_card_anomaly(
        acupoint_b, "state", "acupoint_block", {}, "状态语义测试")
    engine.status_system.apply_card_anomaly(
        vulnerable, "state", "vulnerability", {}, "状态语义测试")
    engine.enemy.life = 1000
    engine.enemy.max_life = 1000
    engine.deal_damage(engine.player, engine.enemy, 100, "technique")
    _assert_equal(engine.enemy.life, 920, "两张封穴与一张破绽按每张20%合并修正普通伤害")
    engine.enemy.life = 1000
    engine.deal_damage(engine.player, engine.enemy, 100, "technique", true)
    _assert_equal(engine.enemy.life, 900, "破绽与封穴不修改权威规则未明确包含的真伤")

    var limited = CombatEngineScript.new()
    limited.setup(817, false)
    limited.status_system.add_actor_status(limited.player, "qi_intake", 3, "状态语义测试")
    _assert_equal(limited.player.current_hand_limit(), 9, "纳气按是否存在统一增加1点上限而非按层叠加")
    limited.status_system.add_actor_status(limited.player, "full_sleeve", 2, "状态语义测试")
    limited.status_system.add_actor_status(limited.player, "bound_sleeve", 20, "状态语义测试")
    _assert_equal(limited.player.current_hand_limit(), 1, "盈袖束袖叠加后手牌上限最低为1")
    limited.timing_system.emit_timing(BattleTimingSystemScript.AFTER_NORMAL_DRAW, {
        "actor": limited.player,
    })
    _assert_equal(
        limited.status_system.actor_status_value(limited.player, "qi_intake"),
        2,
        "纳气在正常补牌完成后只移除1层")

    var forbidden = _card("7", "fire")
    limited.player.hand = [forbidden]
    limited.sequence_book.configure({"high_card": []})
    limited.status_system.apply_card_anomaly(
        forbidden, "state", "forbidden", {}, "状态语义测试")
    var forbidden_preview: Dictionary = limited.preview([forbidden.id])
    _assert_true(not forbidden_preview.get("valid", false), "封禁牌在本回合不能进入合法出牌提案")
    _assert_true(
        str(forbidden_preview.get("reason", "")).contains("封禁"),
        "封禁拒绝原因可供UI与AI统一读取")
    limited.timing_system.emit_timing(BattleTimingSystemScript.TURN_END, {
        "actor": limited.player,
    })
    _assert_true(not forbidden.has_anomaly("state", "forbidden"), "封禁在持有者本回合结束后移除")
    _assert_true(limited.preview([forbidden.id]).get("valid", false), "封禁移除后真气恢复可打出")

    var severed = _card("8", "fire")
    limited.player.hand = [severed]
    limited.player.draw_pile.clear()
    limited.status_system.apply_card_anomaly(
        severed, "state", "vulnerability", {}, "状态语义测试")
    limited.status_system.apply_card_anomaly(
        severed, "mark", "qi_severance", {}, "状态语义测试")
    limited.player.random_discard(1, limited.rng)
    _assert_true(
        limited.player.draw_pile.back() == severed,
        "绝气标记在真气进入弃牌堆后将其改置牌库顶")
    _assert_true(severed.has_anomaly("state", "forbidden"), "绝气改置时以封禁替换此前状态")
    _assert_true(not severed.has_anomaly("mark", "qi_severance"), "绝气标记成功触发后移除自身")

    var returning = _card("6", "wind")
    limited.player.hand = [returning]
    limited.player.draw_pile.clear()
    limited.status_system.apply_card_anomaly(
        returning, "poison", "lethal_poison", {}, "状态语义测试")
    limited.status_system.apply_card_anomaly(
        returning, "mark", "returning_wind", {}, "状态语义测试")
    var history_before: int = limited.status_system.history.size()
    limited.player.random_discard(1, limited.rng)
    var discard_history: Array = limited.status_system.history.slice(history_before)
    _assert_equal(discard_history[0]["status_id"], "lethal_poison", "回风改置前先完成进入弃牌堆的毒清理响应")
    _assert_equal(discard_history[1]["status_id"], "returning_wind", "回风在其他明确弃牌响应后移除自身")
    _assert_true(limited.player.draw_pile.back() == returning, "回风最终把真气放回牌库顶")

    var stopped = CombatEngineScript.new()
    stopped.setup(818, false)
    var turbulence_card = _card("5", "mountain")
    var follow = _card("4", "forest")
    stopped.status_system.apply_card_anomaly(
        turbulence_card, "mark", "wind_lure", {}, "优先级测试")
    stopped.status_system.apply_card_anomaly(
        turbulence_card, "mark", "turbulence", {}, "优先级测试")
    stopped.enemy.draw_pile = [follow, turbulence_card]
    stopped.enemy.hand.clear()
    stopped.enemy.draw(1)
    _assert_true(stopped.enemy.discard_pile.has(turbulence_card), "低优先级数值的乱流先于风引触发")
    _assert_true(turbulence_card.has_anomaly("mark", "wind_lure"), "乱流改置后停止同张牌剩余抽牌行为")
    _assert_true(stopped.enemy.draw_pile.has(follow), "停止分发后风引没有额外抽取下一张牌")

    var stolen = _card("10", "wind")
    stopped.status_system.apply_card_anomaly(
        stolen, "mark", "wind_lure", {}, "优先级测试")
    stopped.status_system.apply_card_anomaly(
        stolen, "mark", "turbulence", {}, "优先级测试")
    stopped.status_system.add_actor_status(stopped.player, "steal_wind", 1, "优先级测试")
    stopped.enemy.draw_pile = [stolen]
    stopped.enemy.draw(1)
    _assert_true(stopped.player.hand.has(stolen), "夺风先于被抽入手牌的真气状态响应")
    _assert_true(
        stolen.has_anomaly("mark", "wind_lure") and stolen.has_anomaly("mark", "turbulence"),
        "夺风移走真气后停止原持有者的风引与乱流响应")
    _assert_true(
        _array_contains_change_type(limited.status_system.history, "card_anomaly_remove"),
        "处理器触发产生结构化状态历史")
    _assert_true(
        not limited.game_log.entries("battle").is_empty(),
        "处理器触发与数值状态变化进入统一战斗日志")

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
    _assert_true(CardOriginServiceScript.new(catalog).apply_to_card(
        source, "attribute_change", {"attribute": "mountain"}).get("success", false),
        "战斗实例可通过共享本源规划器转属")
    source.set_enhancement("qi_boost")
    source.set_anomaly("poison", "lethal_poison")
    run_deck.sync_from_battle_cards(battle_cards)
    var persistent: Dictionary = run_deck.card_data("wind_7")
    _assert_equal(persistent["reshapes"]["origin"]["id"], "attribute_change", "战斗中的本源同步为本局重塑")
    _assert_equal(persistent["reshapes"]["enhancement"], "qi_boost", "战斗中的强化同步为本局重塑")
    _assert_equal(persistent["reshapes"]["imprint"], "", "未实现印记槽保持为空")
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
    var legacy_deck_snapshot: Dictionary = run_deck.to_snapshot()
    legacy_deck_snapshot["version"] = RunDeckScript.VERSION - 1
    _assert_true(
        _array_contains_text(
            RunDeckScript.new(catalog).restore_snapshot(legacy_deck_snapshot),
            "本局牌组版本不受支持"),
        "旧 RunDeck 版本明确拒绝而不静默迁移")

    var progress = RunProgressSnapshotScript.from_dict({
        "consumable_ids": ["zengyuan_pill"],
        "learned_technique_ids": ["long_wind_full_sleeve"],
        "run_deck": run_deck.to_snapshot(),
    })
    var battle_session: BattleSession = BattleSessionScript.new(CombatEngineScript.new())
    _assert_true(
        battle_session.setup_battle({"content_seed": 815}, progress),
        "BattleSetupService 从 RunDeck 快照建立战斗牌组")
    var battle_source = null
    for card in battle_session.engine.player.all_zone_cards():
        if card.id == "wind_7":
            battle_source = card
            break
    _assert_true(battle_source != null, "战斗装配保留本局真气实例 ID")
    _assert_equal(battle_source.reshape_origin["id"], "attribute_change", "战斗装配恢复本源字段")
    _assert_equal(battle_source.anomaly_poison, "", "新战斗不会从 RunDeck 恢复上场异状")
    battle_source.set_enhancement("momentum")
    battle_source.set_anomaly("state", "qi_dissipation")
    battle_session.engine.player.mark_permanently_removed("wind_2")
    var synced_progress = battle_session.player_progress_snapshot()
    var synced_deck: Dictionary = synced_progress.run_deck
    _assert_equal(synced_deck["cards"].size(), 52, "明确登记的永久移出会同步回本局牌组")
    var synced_source: Dictionary = {}
    for values in synced_deck["cards"]:
        if values["instance_id"] == "wind_7":
            synced_source = values
            break
    _assert_equal(synced_source["reshapes"]["enhancement"], "momentum", "战斗中的强化替换同步回 RunDeck")
    _assert_true(not synced_source.has("anomalies"), "战斗同步不会把状态异状带到下一场")

func _test_awakening_origin_persistence_contract() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "觉醒本源契约载入统一内容目录")
    _assert_equal(catalog.all_of("origin").size(), 3, "正式内容包含转属、易阶、觉醒三种本源")
    _assert_equal(catalog.all_of("enhancement").size(), 8, "F2D2 包含八种正式强化")
    _assert_equal(catalog.all_of("imprint").size(), 3, "F2E1 录入三种正式印记")

    var card = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_7"), "awakening:wind_7",
        catalog.card_reshape_rules)
    var identity_before := {
        "id": card.id,
        "definition_id": card.definition_id,
        "rank_name": card.rank_name,
        "rank_order": card.rank_order,
        "qi_value": card.qi_value,
        "attribute": card.attribute,
        "attribute_name": card.attribute_name,
    }
    var awakened: Dictionary = CardOriginServiceScript.new(catalog).apply_to_card(
        card, "awakening", {})
    _assert_true(awakened.get("success", false), "空 payload 觉醒读取当前基础属性")
    _assert_equal(
        card.reshape_origin,
        {"id": "awakening", "payload": {"attribute": "wind"}},
        "风牌觉醒持久保存 payload.attribute=wind")
    _assert_equal({
        "id": card.id,
        "definition_id": card.definition_id,
        "rank_name": card.rank_name,
        "rank_order": card.rank_order,
        "qi_value": card.qi_value,
        "attribute": card.attribute,
        "attribute_name": card.attribute_name,
    }, identity_before, "觉醒不改变实例、牌阶、基础属性或基础真气值")
    _assert_true(
        not CardOriginServiceScript.new(catalog).apply_to_card(
            card, "attribute_change", {"attribute": "fire"}).get("success", false),
        "觉醒后本源槽锁定并拒绝再次改造")

    var mismatch = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_7"), "awakening:mismatch",
        catalog.card_reshape_rules)
    _assert_true(
        not CardOriginServiceScript.new(catalog).apply_to_card(
            mismatch, "awakening", {"attribute": "fire"}).get("success", false),
        "风牌不能通过 payload 强制写成火觉醒")

    var captured: Dictionary = QiCardInstanceDataScript.capture(card)
    _assert_equal(
        QiCardInstanceDataScript.validate(captured, catalog), [],
        "觉醒真气实例通过统一持久化校验")
    var restored = QiCardInstanceDataScript.restore(captured, catalog.card_reshape_rules)
    _assert_equal(restored.reshape_origin, card.reshape_origin, "真气 DTO 往返保留觉醒属性")

    var run_deck = RunDeckScript.new(catalog)
    run_deck.reset_standard("awakening-run")
    _assert_true(
        run_deck.apply_card_origin(["wind_7"], "awakening", {}).get("success", false),
        "RunDeck 通过本源边界施加觉醒")
    var copied: Dictionary = run_deck.copy_card("wind_7")
    _assert_true(copied.get("success", false), "完整复制觉醒真气成功")
    _assert_equal(
        run_deck.card_data(str(copied["instance_ids"][0]))["reshapes"]["origin"],
        run_deck.card_data("wind_7")["reshapes"]["origin"],
        "完整复制保留觉醒属性与本源锁")
    var battle_cards: Array = run_deck.create_battle_cards()
    run_deck.sync_from_battle_cards(battle_cards)
    _assert_equal(
        run_deck.card_data("wind_7")["reshapes"]["origin"]["payload"]["attribute"],
        "wind",
        "战斗装配与战后同步保留觉醒属性")

    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 82101}).success, "觉醒存档测试建立本局")
    _assert_true(
        session.growth.run_deck.apply_card_origin(
            ["forest_7"], "awakening", {}).get("success", false),
        "本局牌组施加林觉醒")
    var save = RunSaveDataScript.new().capture(session)
    var save_restored: Dictionary = save.restore_session(catalog)
    _assert_true(save_restored.get("success", false), "带觉醒的本局存档可以恢复")
    _assert_equal(
        save_restored["run_session"].growth.run_deck.card_data(
            "forest_7")["reshapes"]["origin"]["payload"]["attribute"],
        "forest",
        "存档—读档保留觉醒属性")

    var enemy_awakened: Dictionary = EnemyDeckEncodingScript.parse([{
        "definition_id": "mountain_7",
        "reshapes": {
            "origin": {"id": "awakening", "payload": {"attribute": "mountain"}},
        },
    }], catalog, "awakening-enemy")
    _assert_true(enemy_awakened.get("success", false), "敌人可预置与基础属性一致的觉醒")
    _assert_equal(
        enemy_awakened["cards"][0].reshape_origin["payload"]["attribute"],
        "mountain",
        "敌人预置保留觉醒属性")
    var bad_enemy: Dictionary = EnemyDeckEncodingScript.parse([{
        "definition_id": "wind_7",
        "reshapes": {
            "origin": {"id": "awakening", "payload": {"attribute": "fire"}},
        },
    }], catalog, "awakening-enemy-bad")
    _assert_true(not bad_enemy.get("success", false), "敌人预置同样拒绝伪造觉醒属性")
    var inferred_enemy: Dictionary = EnemyDeckEncodingScript.parse([{
        "definition_id": "fire_7",
        "reshapes": {
            "origin": {"id": "awakening", "payload": {}},
        },
    }], catalog, "awakening-enemy-inferred")
    _assert_true(inferred_enemy.get("success", false), "敌人预置可用空 payload 读取基础属性")
    _assert_equal(
        inferred_enemy["cards"][0].reshape_origin["payload"]["attribute"],
        "fire",
        "敌人空 payload 觉醒在装配时持久化实际属性")

func _test_awakening_battle_runtime() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "觉醒战斗运行时载入统一内容目录")
    var origin = CardOriginServiceScript.new(catalog)

    var wind_a = _card("7", "wind")
    var wind_b = _card("6", "wind")
    var wind_tail = _card("5", "forest")
    origin.apply_to_card(wind_a, "awakening", {})
    origin.apply_to_card(wind_b, "awakening", {})
    var wind_engine = _engine_with_hand([], [wind_tail, wind_b, wind_a], 82111)
    var wind_drawn: Array = wind_engine.player.draw(1)
    _assert_equal(wind_drawn.size(), 1, "最外层抽牌仍只报告请求抽到的一张")
    _assert_equal(wind_engine.player.hand.size(), 3, "连续风觉醒链式额外抽牌直到普通尾牌")
    _assert_equal(wind_engine.player.draw_pile.size(), 0, "风觉醒遇到空牌库自然停止")

    var forest_play = _card("7", "forest")
    var forest_discard = _card("6", "forest")
    var forest_effect = _card("5", "forest")
    var forest_direct = _card("4", "forest")
    for card in [forest_play, forest_discard, forest_effect, forest_direct]:
        origin.apply_to_card(card, "awakening", {})
    var forest_engine = _engine_with_hand([], [], 82112)
    forest_engine.player.staging = [forest_play]
    forest_engine.player.hand = [forest_discard, forest_effect]
    forest_engine.player.draw_pile = [forest_direct]
    forest_engine.player.card_zone_service.move_card(
        forest_engine.player, "staging", "discard_pile", forest_play, "normal_play")
    forest_engine.player.card_zone_service.move_card(
        forest_engine.player, "hand", "discard_pile", forest_discard, "explicit_discard")
    forest_engine.effect_ports.move_card(
        forest_engine.player, "hand", forest_engine.player, "discard_pile",
        forest_effect, "effect")
    _assert_true(
        forest_engine.player.draw_pile.has(forest_play)
        and forest_engine.player.draw_pile.has(forest_discard)
        and forest_engine.player.draw_pile.has(forest_effect),
        "林觉醒在正常打出、明确弃牌和效果入弃牌堆后回库并洗牌")
    forest_engine.player.card_zone_service.move_card(
        forest_engine.player, "draw_pile", "draw_pile", forest_direct, "gu_recycle")
    _assert_true(
        forest_engine.player.draw_pile.has(forest_direct),
        "未实际进入弃牌堆的直接回库不触发林觉醒改置")

    var fire_main = _card("7", "fire")
    var fire_extra = _card("2", "fire")
    origin.apply_to_card(fire_main, "awakening", {})
    origin.apply_to_card(fire_extra, "awakening", {})
    fire_main.set_enhancement("qi_boost")
    var fire_engine = _engine_with_hand([fire_main, fire_extra], [], 82113)
    fire_engine.sequence_book.configure({"high_card": ["stagnant_gu_conceal_breath"]})
    var fire_preview: Dictionary = fire_engine.preview(_ids([fire_main, fire_extra]))
    _assert_equal(fire_preview["values"]["card_total"], 30, "增元火觉醒按(7+8)×2参与数值计算")
    _assert_true(
        not fire_main.has_anomaly("mark", "burned_out"),
        "预览保持纯计算且不施加燃尽")
    var fire_result: Dictionary = fire_engine.confirm_play(_ids([fire_main, fire_extra]))
    _assert_true(fire_result.get("success", false), "火觉醒真实功法组完成结算")
    _assert_true(fire_main.has_anomaly("mark", "burned_out"), "参与最高牌型的火觉醒在组结束后燃尽")
    _assert_true(not fire_extra.has_anomaly("mark", "burned_out"), "额外打出但未贡献的火觉醒不翻倍且不燃尽")
    _assert_equal(
        PowerCalculatorScript.calculate(
            HandEvaluatorScript.evaluate([fire_main]),
            {},
            Callable(fire_engine.status_system, "modify_card_contribution").bind(
                fire_engine.player))["card_total"],
        0,
        "燃尽令当前真气贡献为零")
    _assert_equal(
        fire_engine.status_system.effective_qi_value(fire_main),
        0,
        "战斗异状与效果读取同样把燃尽视为零有效真气")
    _assert_equal(
        _count_status_changes(fire_engine.status_system.history, "burned_out"),
        1,
        "一个功法组只为参与真气施加一次燃尽")
    _assert_equal(
        fire_engine.timing_system.history[-1]["handler_results"][-1]["handler_id"],
        "card_reshape_runtime.group_resolved",
        "火觉醒在功法与内功完成、序列推进之后响应组结束")
    fire_engine.status_system.apply_card_anomaly(
        fire_main, "mark", "purification", {}, "觉醒测试净化")
    _assert_true(not fire_main.has_anomaly("mark", "burned_out"), "净化可清除燃尽")
    fire_engine.status_system.apply_card_anomaly(
        fire_extra, "mark", "burned_out", {}, "觉醒测试战斗结束")
    fire_engine.timing_system.emit_timing(BattleTimingSystemScript.BATTLE_END, {
        "actors": [fire_engine.player, fire_engine.enemy],
    })
    _assert_true(not fire_extra.has_anomaly("mark", "burned_out"), "战斗结束自动移除燃尽")

    var mountain_hand = _card("7", "mountain")
    var mountain_discard = _card("6", "mountain")
    var mountain_staging = _card("5", "mountain")
    var mountain_draw = _card("4", "mountain")
    for card in [mountain_hand, mountain_discard, mountain_staging, mountain_draw]:
        origin.apply_to_card(card, "awakening", {})
    mountain_hand.set_enhancement("qi_boost")
    var mountain_engine = _engine_with_hand([mountain_hand], [], 82114)
    mountain_engine.player.discard_pile = [mountain_discard]
    mountain_engine.player.staging = [mountain_staging]
    mountain_engine.player.draw_pile = [mountain_draw]
    var turn_end_result: Dictionary = mountain_engine.timing_system.emit_timing(
        BattleTimingSystemScript.TURN_END, {
            "actor": mountain_engine.player,
            "actors": [mountain_engine.player],
        })
    _assert_equal(mountain_engine.player.defense, 15, "山觉醒读取增元后的当前有效真气获得防御")
    _assert_equal(
        turn_end_result["results"][-2]["handler_id"],
        "card_reshape_runtime.turn_end",
        "山觉醒排在现有回合结束状态与延迟效果之后")
    mountain_engine.status_system.apply_card_anomaly(
        mountain_hand, "mark", "burned_out", {}, "觉醒测试燃尽")
    mountain_engine.timing_system.emit_timing(BattleTimingSystemScript.TURN_END, {
        "actor": mountain_engine.player,
        "actors": [mountain_engine.player],
    })
    _assert_equal(mountain_engine.player.defense, 15, "山觉醒读取燃尽后的零有效真气")

func _test_awakening_group_completion_paths() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "觉醒组结束路径测试载入内容")
    var origin = CardOriginServiceScript.new(catalog)

    var synchronized_card = _card("7", "fire")
    origin.apply_to_card(synchronized_card, "awakening", {})
    var synchronized_engine = CombatEngineScript.new(null, catalog)
    _assert_true(synchronized_engine.setup_scripted_battle(2308), "同步觉醒测试载入脚本战斗")
    synchronized_engine.start_player_turn()
    synchronized_engine.player.hand = [synchronized_card, _card("3", "forest")]
    synchronized_engine.player.draw_pile.clear()
    synchronized_engine.sequence_book.configure({
        "high_card": ["stagnant_gu_conceal_breath"],
    })
    var synchronized_result: Dictionary = synchronized_engine.confirm_play(
        [synchronized_card.id])
    _assert_true(synchronized_result.get("success", false), "同步行动完成火觉醒功法组")
    _assert_true(synchronized_card.has_anomaly("mark", "burned_out"), "同步行动组结束施加燃尽")
    _assert_equal(
        _count_status_changes(synchronized_engine.status_system.history, "burned_out"),
        1,
        "同步行动的火觉醒只结算一次")

    var main_cards := [
        _card("7", "fire"), _card("7", "fire"), _card("7", "fire")]
    var cooperation_cards := [_card("5", "fire"), _card("5", "fire")]
    for card in main_cards + cooperation_cards:
        origin.apply_to_card(card, "awakening", {})
    var cooperation_engine = _engine_with_hand(
        main_cards + cooperation_cards, [], 82115)
    cooperation_engine.sequence_book.configure({
        "three_kind": ["three_ring_ensemble"],
        "pair": ["double_gu_exchange_breath"],
    })
    var cooperation_result: Dictionary = cooperation_engine.confirm_play(
        _ids(main_cards), _ids(cooperation_cards))
    _assert_true(cooperation_result.get("success", false), "主组与协同组完成各自功法结算")
    for card in main_cards + cooperation_cards:
        _assert_true(card.has_anomaly("mark", "burned_out"), "协同路径每张参与真气在自己的组结束后燃尽")
    _assert_equal(
        _count_status_changes(cooperation_engine.status_system.history, "burned_out"),
        5,
        "主组三张与协同组两张各只结算一次燃尽")

    var pending_card = _card("8", "fire")
    var pending_target = _card("3", "forest")
    var pending_target_other = _card("4", "mountain")
    origin.apply_to_card(pending_card, "awakening", {})
    var pending_engine = _engine_with_hand(
        [pending_card, pending_target, pending_target_other], [], 82116)
    pending_engine.sequence_book.configure({"high_card": ["discard_gu_exchange_breath"]})
    var pending_result: Dictionary = pending_engine.confirm_play([pending_card.id])
    _assert_true(pending_result.get("pending_choice", false), "等待选择路径在组完成前暂停")
    _assert_true(
        not pending_card.has_anomaly("mark", "burned_out"),
        "等待选择期间不会提前施加燃尽")
    var request: Dictionary = pending_engine.action_resolver.pending_choice_snapshot()
    var resumed: Dictionary = pending_engine.resolve_effect_choice(
        str(request.get("request_id", "")), [pending_target.id])
    while resumed.get("pending_choice", false):
        request = pending_engine.action_resolver.pending_choice_snapshot()
        var candidates: Array = request.get("candidate_ids", [])
        resumed = pending_engine.resolve_effect_choice(
            str(request.get("request_id", "")),
            candidates.slice(0, 1))
    _assert_true(resumed.get("success", false), "等待选择恢复后完成功法组")
    _assert_true(
        pending_card.has_anomaly("mark", "burned_out"),
        "等待选择恢复后才为参与真气施加燃尽")
    _assert_equal(
        _count_status_changes(pending_engine.status_system.history, "burned_out"),
        1,
        "等待选择恢复不会重复触发组结束燃尽")

func _test_f2d2_formal_enhancement_runtime() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "F2D2 正式强化测试载入内容目录")
    var enhancement_ids: Array = catalog.all_of("enhancement").map(
        func(value): return str(value.get("id", "")))
    enhancement_ids.sort()
    _assert_equal(
        enhancement_ids,
        ["flawless", "hidden_gold", "hunyuan", "momentum", "opportunity",
            "qi_boost", "rock_solid", "void_burst"],
        "八种正式强化集合完整且无额外内容")

    var void_main = _card("7", "fire")
    var void_extra = _card("2", "forest")
    void_main.set_enhancement("void_burst")
    void_extra.set_enhancement("void_burst")
    var void_hand: Dictionary = HandEvaluatorScript.evaluate([void_main, void_extra])
    var void_values: Dictionary = PowerCalculatorScript.calculate(void_hand)
    _assert_equal(void_values["card_total"], 14, "虚暴只翻倍参与最高牌型的真气")
    _assert_equal(
        void_extra.effective_qi_value(false, {"participating": false}),
        2,
        "额外打出但未参与的虚暴真气保持原有效值")
    CardOriginServiceScript.new(catalog).apply_to_card(void_main, "awakening", {})
    _assert_equal(
        void_main.effective_qi_value(false, {"participating": true}),
        28,
        "虚暴 priority 200 先于火觉醒 priority 300 连续翻倍")

    var mountain_void = _card("7", "mountain")
    CardOriginServiceScript.new(catalog).apply_to_card(
        mountain_void, "awakening", {})
    mountain_void.set_enhancement("void_burst")
    var mountain_engine = _engine_with_hand([mountain_void], [], 82201)
    var end_result: Dictionary = mountain_engine.timing_system.emit_timing(
        BattleTimingSystemScript.TURN_END, {
            "actor": mountain_engine.player,
            "actors": [mountain_engine.player],
        })
    _assert_equal(mountain_engine.player.defense, 7, "山觉醒先按当前有效真气获得防御")
    _assert_true(
        mountain_engine.player.temporarily_removed_cards.has(mountain_void),
        "普通回合结束重塑完成后虚无牌消散")
    _assert_equal(
        end_result["results"][-2]["handler_id"],
        "card_reshape_runtime.turn_end",
        "山觉醒位于普通重塑 order 900")
    _assert_equal(
        end_result["results"][-1]["handler_id"],
        "card_reshape_runtime.turn_end_final",
        "虚无消散位于最终回合结束 order 1000")

    var flawless = _card("6", "wind")
    flawless.set_enhancement("flawless")
    var permission_engine = _engine_with_hand([flawless], [], 82202)
    for blocked in [
        ["poison", "lethal_poison"],
        ["poison", "stagnant_poison"],
        ["state", "vulnerability"],
        ["state", "acupoint_block"],
    ]:
        _assert_true(
            not permission_engine.status_system.apply_card_anomaly(
                flawless, blocked[0], blocked[1], {}, "无漏测试").get(
                    "success", false),
            "无漏拒绝 %s" % blocked[1])
    _assert_true(
        permission_engine.status_system.apply_card_anomaly(
            flawless, "state", "qi_dissipation", {}, "无漏测试").get(
                "success", false),
        "无漏允许散气")
    _assert_true(
        permission_engine.status_system.apply_card_anomaly(
            flawless, "mark", "wind_mark", {}, "无漏测试").get(
                "success", false),
        "无漏允许普通标记")

    var random_flawless = _card("5", "wind")
    var random_ordinary = _card("4", "forest")
    random_flawless.set_enhancement("flawless")
    var random_target = BattleSideScript.new("随机异状目标")
    random_target.hand = [random_flawless, random_ordinary]
    var random_executor = EffectExecutorScript.new(
        RandomNumberGenerator.new(), null, catalog)
    var random_result: Dictionary = random_executor.execute_all([{
        "op": "apply_random_card_anomaly",
        "zone": "hand",
        "category": "poison",
        "anomaly": "lethal_poison",
        "count": 2,
    }], {"target": random_target, "captures": {}})
    _assert_true(random_result.get("success", false), "随机异状先过滤无漏非法目标")
    _assert_equal(random_flawless.anomaly_poison, "", "无漏不进入随机毒目标集合")
    _assert_equal(random_ordinary.anomaly_poison, "lethal_poison", "随机毒只施加给合法目标")
    var random_option_result: Dictionary = permission_engine.effect_executor.execute_all([{
        "op": "apply_card_anomaly_to_captured",
        "capture": "flawless_target",
        "random_options": [
            {"category": "poison", "anomaly": "lethal_poison"},
            {"category": "state", "anomaly": "qi_dissipation"},
        ],
    }], {
        "ports": permission_engine.effect_ports,
        "actor": permission_engine.player,
        "target": permission_engine.enemy,
        "captures": {"flawless_target": [random_flawless]},
    })
    _assert_true(random_option_result.get("success", false), "随机异状选项过滤后正常结算")
    _assert_equal(
        random_flawless.anomaly_state,
        "qi_dissipation",
        "随机异状先排除无漏拒绝项再抽取")

    var flawless_extra = _card("2", "forest")
    flawless_extra.set_enhancement("flawless")
    var flawless_main = _card("A", "wind")
    var flawless_engine = _engine_with_hand(
        [flawless_main, flawless_extra], [], 82203)
    var direct_flawless: Array = flawless_engine.card_reshape_runtime.on_card_played(
        flawless_engine.player, [flawless_extra])
    _assert_equal(direct_flawless.size(), 1, "无漏行为由正式运行时注册")
    _assert_equal(flawless_engine.player.defense, 2, "无漏 Handler 通过窄端口增加防御")
    flawless_engine.player.defense = 0
    flawless_engine.sequence_book.configure({"high_card": []})
    var flawless_result: Dictionary = flawless_engine.confirm_play(
        _ids([flawless_main, flawless_extra]))
    _assert_true(flawless_result.get("success", false), "无漏额外牌正常打出")
    _assert_equal(
        flawless_engine.player.defense,
        2,
        "无漏打出效果覆盖未参与最高牌型的额外真气")

    var rock = _card("6", "mountain")
    var ordinary_a = _card("4", "wind")
    var ordinary_b = _card("3", "forest")
    rock.set_enhancement("rock_solid")
    var discard_engine = _engine_with_hand(
        [rock, ordinary_a, ordinary_b], [], 82204)
    var random_discarded: Array = discard_engine.player.random_discard(
        3, discard_engine.rng)
    _assert_equal(random_discarded.size(), 2, "随机弃牌只处理可明确弃掉的真气")
    _assert_true(discard_engine.player.hand.has(rock), "磐石不进入随机弃牌候选")
    discard_engine.player.hand.append(_card("5", "fire"))
    _assert_equal(discard_engine.player.discard_all().size(), 1, "全部弃牌跳过磐石")
    _assert_true(discard_engine.player.hand.has(rock), "全部弃牌后磐石仍留手")
    var direct_discard: Dictionary = discard_engine.player.card_zone_service.move_card(
        discard_engine.player,
        "hand",
        "discard_pile",
        rock,
        "explicit_discard")
    _assert_true(not direct_discard.get("success", false), "统一移动入口拒绝明确弃掉磐石")

    var choice_main = _card("A", "wind")
    var choice_rock = _card("6", "mountain")
    var choice_a = _card("4", "forest")
    var choice_b = _card("3", "fire")
    choice_rock.set_enhancement("rock_solid")
    var choice_engine = _engine_with_hand(
        [choice_main, choice_rock, choice_a, choice_b], [], 82205)
    choice_engine.enemy.hand = [_card("2", "wind"), _card("3", "wind")]
    choice_engine.sequence_book.configure({
        "high_card": ["discard_gu_exchange_breath"],
    })
    var choice_result: Dictionary = choice_engine.confirm_play([choice_main.id])
    _assert_true(choice_result.get("pending_choice", false), "明确弃牌功法建立选择请求")
    var candidate_ids: Array = choice_result.get("choice_request", {}).get(
        "candidate_ids", [])
    _assert_true(not candidate_ids.has(choice_rock.id), "手动明确弃牌候选自动排除磐石")
    _assert_true(
        _resolve_all_pending_choices(choice_engine).get("success", false),
        "明确弃牌候选测试完成并释放等待事务")

    var rock_extra = _card("2", "mountain")
    rock_extra.set_enhancement("rock_solid")
    var rock_main = _card("A", "wind")
    var rock_engine = _engine_with_hand([rock_main, rock_extra], [], 82206)
    rock_engine.sequence_book.configure({"high_card": []})
    var enemy_life_before: int = rock_engine.enemy.life
    var rock_play: Dictionary = rock_engine.confirm_play(
        _ids([rock_main, rock_extra]))
    _assert_true(rock_play.get("success", false), "磐石额外牌正常打出")
    _assert_equal(
        rock_engine.enemy.life,
        enemy_life_before - 2,
        "磐石打出效果覆盖未参与最高牌型的额外真气")
    _assert_true(rock_engine.player.discard_pile.has(rock_extra), "磐石正常打出后进入弃牌堆")

    var hidden_hand = _card("2", "wind")
    var hidden_draw = _card("3", "forest")
    var hidden_discard = _card("4", "fire")
    var hidden_staging = _card("5", "mountain")
    var hidden_removed = _card("6", "wind")
    for card in [hidden_hand, hidden_draw, hidden_discard, hidden_staging, hidden_removed]:
        card.set_enhancement("hidden_gold")
    var gold_engine = _engine_with_hand([hidden_hand], [hidden_draw], 82207)
    gold_engine.player.discard_pile = [hidden_discard]
    gold_engine.player.staging = [hidden_staging]
    gold_engine.player.temporarily_removed_cards = [hidden_removed]
    gold_engine.player.experience = 10
    gold_engine.enemy.life = 0
    gold_engine.outcome_service.update()
    _assert_equal(
        gold_engine.player.experience,
        16,
        "藏金胜利只统计手牌与抽牌堆各三点历练")

    var losing_gold = _card("7", "wind")
    losing_gold.set_enhancement("hidden_gold")
    var loss_engine = _engine_with_hand([losing_gold], [], 82208)
    loss_engine.player.experience = 10
    loss_engine.player.life = 0
    loss_engine.outcome_service.update()
    _assert_equal(loss_engine.player.experience, 10, "藏金在玩家战败时不奖励")

func _test_f2d2_opportunity_freeze_and_progress_sync() -> void:
    var first = _card("7", "wind")
    var second = _card("7", "forest")
    first.set_enhancement("opportunity")
    second.set_enhancement("opportunity")
    var engine = _engine_with_hand([first, second], [], 82301)
    engine.sequence_book.configure({"pair": []})
    engine.player.experience = 5
    var preview_state: int = engine.rng.state
    var pure_preview: Dictionary = engine.preview(_ids([first, second]))
    var repeated_preview: Dictionary = engine.preview(_ids([first, second]))
    _assert_equal(repeated_preview, pure_preview, "重复预览保持完全一致")
    _assert_equal(engine.rng.state, preview_state, "重复预览不推进随机源")
    _assert_equal(engine.player.experience, 5, "重复预览不增加历练")

    var pattern := [true, false, false, true]
    var seed := _find_opportunity_seed(pattern)
    _assert_true(seed > 0, "找到机缘两张牌独立判定的确定性种子")
    engine.rng.seed = seed
    var result: Dictionary = engine.confirm_play(_ids([first, second]))
    _assert_true(result.get("success", false), "机缘牌正式确认行动成功")
    var frozen: Dictionary = result["preview"].get("reshape_action_results", {})
    _assert_equal(frozen[first.id]["multiplier_success"], true, "第一张机缘倍率判定成功")
    _assert_equal(frozen[first.id]["experience_success"], false, "第一张机缘历练判定失败")
    _assert_equal(frozen[second.id]["multiplier_success"], false, "第二张机缘倍率判定失败")
    _assert_equal(frozen[second.id]["experience_success"], true, "第二张机缘历练判定成功")
    _assert_equal(engine.player.experience, 25, "多张机缘历练结果独立累加")
    var expected_values: Dictionary = PowerCalculatorScript.apply_frozen_card_multiplier_bonus(
        pure_preview["values"], 1)
    for field in [
        "card_multiplier_bonus", "technique_multiplier",
        "unamplified_technique_value", "technique_value"]:
        _assert_equal(
            result["preview"]["values"][field],
            expected_values[field],
            "机缘冻结后纯函数更新 %s" % field)
    _assert_equal(
        result["preview"]["values"]["baseline_value"],
        pure_preview["values"]["baseline_value"],
        "机缘不修改 baseline_value")

    var pending_card = _card("8", "fire")
    pending_card.set_enhancement("opportunity")
    var pending_a = _card("3", "forest")
    var pending_b = _card("4", "mountain")
    var pending_engine = _engine_with_hand(
        [pending_card, pending_a, pending_b], [], 82302)
    pending_engine.enemy.hand = [_card("2", "wind"), _card("3", "wind")]
    pending_engine.sequence_book.configure({
        "high_card": ["discard_gu_exchange_breath"],
    })
    pending_engine.rng.seed = _find_opportunity_seed([false, true])
    var pending_result: Dictionary = pending_engine.confirm_play([pending_card.id])
    _assert_true(pending_result.get("pending_choice", false), "机缘行动可以进入等待选择")
    var frozen_before: Dictionary = pending_result["preview"].get(
        "reshape_action_results", {}).duplicate(true)
    var experience_before_resume: int = pending_engine.player.experience
    var repeated_finalize: Dictionary = pending_engine.action_resolver \
        .finalize_action_preview(pending_engine.player, pending_result["preview"])
    _assert_true(repeated_finalize.get("reused", false), "同一行动重复 finalizer 复用冻结结果")
    _assert_equal(
        pending_engine.player.experience,
        experience_before_resume,
        "同一行动重复 finalizer 不重复发放机缘历练")
    var pending_snapshot: Dictionary = pending_engine.action_service \
        .pending_action_transaction_snapshot()
    _assert_equal(
        pending_snapshot["record"]["reshape_action_results"],
        frozen_before,
        "BattleActionRecord 快照保存机缘冻结结果")
    var resumed: Dictionary = _resolve_all_pending_choices(pending_engine)
    _assert_true(resumed.get("success", false), "等待选择恢复后行动完成")
    _assert_equal(
        pending_engine.player.experience,
        experience_before_resume,
        "等待选择恢复不重复增加机缘历练")
    _assert_equal(
        resumed["preview"].get("reshape_action_results", {}),
        frozen_before,
        "等待选择恢复复用原冻结结果")

    var main_cards := [
        _card("7", "wind"), _card("7", "forest"), _card("7", "fire")]
    var cooperation_cards := [_card("5", "wind"), _card("5", "mountain")]
    main_cards[0].set_enhancement("opportunity")
    cooperation_cards[0].set_enhancement("opportunity")
    var cooperation_engine = _engine_with_hand(
        main_cards + cooperation_cards, [], 82303)
    cooperation_engine.sequence_book.configure({
        "three_kind": ["three_ring_ensemble"],
        "pair": ["double_gu_exchange_breath"],
    })
    var main_pure: Dictionary = cooperation_engine.preview(_ids(main_cards))
    var cooperation_pure: Dictionary = cooperation_engine.preview(
        _ids(cooperation_cards))
    cooperation_engine.rng.seed = _find_opportunity_seed(pattern)
    var cooperation_result: Dictionary = cooperation_engine.confirm_play(
        _ids(main_cards), _ids(cooperation_cards))
    _assert_true(cooperation_result.get("success", false), "主组与协同组机缘行动成功")
    var expected_main: Dictionary = PowerCalculatorScript.apply_frozen_card_multiplier_bonus(
        main_pure["values"], 1)
    var expected_cooperation: Dictionary = PowerCalculatorScript.apply_frozen_card_multiplier_bonus(
        cooperation_pure["values"], 0)
    var expected_shared := int(floor(
        int(expected_main["technique_value"])
        + int(expected_cooperation["technique_value"]) * 0.5))
    _assert_equal(
        cooperation_result["preview"]["values"]["technique_value"],
        expected_shared,
        "主组先冻结机缘再计算共享功法值")
    _assert_equal(
        cooperation_result["cooperation_preview"]["values"]["technique_value"],
        expected_shared,
        "协同组先冻结机缘再取得同一共享功法值")
    _assert_true(
        cooperation_result["preview"]["reshape_action_results"].has(
            main_cards[0].id),
        "主组按实例 ID 保存机缘结果")
    _assert_true(
        cooperation_result["cooperation_preview"]["reshape_action_results"].has(
            cooperation_cards[0].id),
        "协同组按实例 ID 保存机缘结果")

    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "战斗历练同步测试载入内容目录")
    var growth = GrowthInventoryScript.new(catalog)
    growth.experience = 7
    var battle_session: BattleSession = BattleSessionScript.new(
        CombatEngineScript.new(null, catalog))
    _assert_true(
        battle_session.setup_battle(
            {"content_seed": 82304}, growth.to_progress_snapshot()),
        "带历练的本局进度建立正式战斗")
    _assert_equal(battle_session.engine.player.experience, 7, "战斗装配读取本局绝对历练")
    battle_session.engine.effect_ports.gain_battle_experience(
        battle_session.engine.player, 20)
    var captured: RunProgressSnapshot = battle_session.player_progress_snapshot()
    _assert_equal(captured.experience, 27, "战斗快照捕获奖励后的绝对历练")
    growth.apply_progress_snapshot(captured)
    growth.apply_progress_snapshot(captured)
    _assert_equal(growth.experience, 27, "同一战斗历练快照同步两次不重复增加")
    var old_snapshot: RunProgressSnapshot = RunProgressSnapshotScript.from_dict({
        "life": 100,
        "max_life": 100,
    })
    growth.experience = 11
    growth.apply_progress_snapshot(old_snapshot)
    _assert_equal(growth.experience, 11, "旧快照不带 experience 时保持现有历练")

func _test_f2e1_formal_imprint_runtime_and_persistence() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "F2E1 正式印记测试载入内容目录")
    var imprint_ids: Array = catalog.all_of("imprint").map(
        func(value): return str(value.get("id", "")))
    imprint_ids.sort()
    _assert_equal(
        imprint_ids,
        ["alchemy", "enlightenment", "innate"],
        "正式印记只包含悟道、化丹与先天")

    var invalid_missing := _catalog_definitions(catalog)
    invalid_missing["card_states"]["imprints"].remove_at(0)
    var missing_catalog = ContentCatalogScript.new()
    _assert_true(
        not missing_catalog.load_from_definitions(invalid_missing),
        "缺少正式印记时内容加载失败")
    _assert_true(
        _array_contains_text(missing_catalog.errors, "缺少定义 enlightenment"),
        "缺失印记错误准确报告 ID")

    var invalid_mapping := _catalog_definitions(catalog)
    invalid_mapping["card_states"]["imprints"][0]["behaviors"][0]["mapping"][
        "pair"] = "zengyuan_pill"
    var mapping_catalog = ContentCatalogScript.new()
    _assert_true(
        not mapping_catalog.load_from_definitions(invalid_mapping),
        "悟道映射到非心得时启动校验失败")
    _assert_true(
        _array_contains_text(mapping_catalog.errors, "pair")
        and _array_contains_text(mapping_catalog.errors, "不是心得"),
        "错误悟道映射报告准确内容路径和类型")

    var unknown_mapping := _catalog_definitions(catalog)
    unknown_mapping["card_states"]["imprints"][0]["behaviors"][0]["mapping"][
        "pair"] = "missing_insight"
    unknown_mapping["card_states"]["imprints"][0]["behaviors"][0]["mapping"][
        "flush"] = "pair_insight"
    var unknown_mapping_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_mapping_catalog.load_from_definitions(unknown_mapping),
        "悟道未知消耗品或牌型在启动期失败")
    _assert_true(
        _array_contains_text(unknown_mapping_catalog.errors, "missing_insight")
        and _array_contains_text(unknown_mapping_catalog.errors, "未知牌型 flush"),
        "悟道未知引用分别具名报告")

    var invalid_kind := _catalog_definitions(catalog)
    invalid_kind["card_states"]["imprints"][1]["behaviors"][0]["kind"] = "relic"
    var kind_catalog = ContentCatalogScript.new()
    _assert_true(
        not kind_catalog.load_from_definitions(invalid_kind),
        "化丹引用空内容类别时启动校验失败")
    _assert_true(
        _array_contains_text(kind_catalog.errors, "kind=relic"),
        "化丹错误 kind 具名报告")

    var invalid_opening := _catalog_definitions(catalog)
    invalid_opening["card_states"]["imprints"][2]["behaviors"][0]["count"] = 1
    var opening_catalog = ContentCatalogScript.new()
    _assert_true(
        not opening_catalog.load_from_definitions(invalid_opening),
        "先天行为携带无关参数时启动校验失败")
    _assert_true(
        _array_contains_text(opening_catalog.errors, "不接受额外参数"),
        "先天额外参数错误具名报告")

    var extra_imprint := _catalog_definitions(catalog)
    extra_imprint["card_states"]["imprints"].append({
        "id": "echo", "name": "未实现回响占位"})
    var extra_catalog = ContentCatalogScript.new()
    _assert_true(
        not extra_catalog.load_from_definitions(extra_imprint),
        "正式印记集合拒绝额外回响空壳")

    var normal_bottom = _card("2", "wind")
    var innate_second = _card("3", "forest")
    var normal_top = _card("4", "fire")
    var innate_first = _card("5", "mountain")
    innate_first.set_imprint("innate")
    innate_second.set_imprint("innate")
    var opening_engine = _engine_with_hand(
        [], [normal_bottom, innate_second, normal_top, innate_first], 82401)
    opening_engine.player.hand_limit = 4
    var opening_drawn: Array = opening_engine.start_player_turn()
    _assert_equal(opening_drawn.size(), 4, "先天不足手牌上限时由普通牌补足")
    _assert_equal(
        _ids(opening_drawn).slice(0, 2),
        [innate_first.id, innate_second.id],
        "多张先天按洗牌后原抽取顺序优先进入起始手牌")

    var many_innates: Array = []
    for rank in ["2", "3", "4", "5", "6"]:
        var innate_card = _card(rank, "wind")
        innate_card.set_imprint("innate")
        many_innates.append(innate_card)
    var overflow_normal = _card("A", "forest")
    var overflow_engine = _engine_with_hand(
        [], [overflow_normal] + many_innates.duplicate(), 82402)
    overflow_engine.player.hand_limit = 3
    var overflow_drawn: Array = overflow_engine.start_player_turn()
    _assert_equal(overflow_drawn.size(), 3, "先天超过上限时只抽到手牌上限")
    _assert_true(
        overflow_engine.player.draw_pile.back().reshape_imprint == "innate",
        "未抽到的先天继续留在牌库顶")
    var second_turn_innate = _card("7", "wind")
    second_turn_innate.set_imprint("innate")
    var second_turn_normal = _card("8", "forest")
    overflow_engine.player.hand.clear()
    overflow_engine.player.hand_limit = 1
    overflow_engine.player.draw_pile = [second_turn_innate, second_turn_normal]
    var second_turn_drawn: Array = overflow_engine.start_player_turn()
    _assert_equal(
        second_turn_drawn[0].id,
        second_turn_normal.id,
        "第二回合不重新执行先天置顶")

    var pair_cards := [_card("7", "wind"), _card("7", "forest")]
    var enlightenment_hand = _card("3", "fire")
    var enlightenment_draw = _card("4", "mountain")
    enlightenment_hand.set_imprint("enlightenment")
    enlightenment_draw.set_imprint("enlightenment")
    var enlightenment_engine = _engine_with_hand(
        pair_cards + [enlightenment_hand], [enlightenment_draw], 82403)
    enlightenment_engine.sequence_book.configure({
        "pair": ["double_gu_exchange_breath"],
    })
    var pair_result: Dictionary = enlightenment_engine.confirm_play(_ids(pair_cards))
    _assert_true(pair_result.get("success", false), "成功对子出招建立悟道记录")
    enlightenment_engine.repository.techniques["f2e1_failed_gate"] = {
        "id": "f2e1_failed_gate",
        "name": "悟道失败条件探针",
        "pool": "high",
        "condition": {"pure_attribute": "wind"},
        "effects": [{"op": "defense", "amount": 1}],
    }
    var failed_card = _card("9", "fire")
    enlightenment_engine.player.hand.append(failed_card)
    enlightenment_engine.actions_available = 1
    enlightenment_engine.sequence_book.configure({
        "high_card": ["f2e1_failed_gate"],
    })
    var failed_result: Dictionary = enlightenment_engine.confirm_play([failed_card.id])
    _assert_true(failed_result.get("success", false), "条件失败组仍完成行动")
    _assert_true(
        not failed_result.get("technique_triggered", true),
        "条件失败组不覆盖最后成功牌型")
    enlightenment_engine.timing_system.emit_timing(
        BattleTimingSystemScript.BATTLE_END, {
            "actors": [enlightenment_engine.player, enlightenment_engine.enemy],
            "winner": enlightenment_engine.player,
        })
    _assert_equal(
        enlightenment_engine.player.consumable_ids,
        ["pair_insight"],
        "最后成功对子为手牌中的悟道印生成 pair_insight")
    _assert_equal(
        enlightenment_engine.player.consumable_ids.size(),
        1,
        "抽牌堆中的悟道印不触发")

    var cooperation_main := [
        _card("6", "wind"), _card("6", "forest"), _card("6", "fire")]
    var cooperation_cards := [_card("4", "wind"), _card("4", "mountain")]
    var cooperation_mark = _card("A", "forest")
    cooperation_mark.set_imprint("enlightenment")
    var cooperation_engine = _engine_with_hand(
        cooperation_main + cooperation_cards + [cooperation_mark], [], 82404)
    cooperation_engine.sequence_book.configure({
        "three_kind": ["three_ring_ensemble"],
        "pair": ["double_gu_exchange_breath"],
    })
    var cooperation_result: Dictionary = cooperation_engine.confirm_play(
        _ids(cooperation_main), _ids(cooperation_cards))
    _assert_true(cooperation_result.get("success", false), "悟道记录覆盖协同组成功路径")
    _assert_equal(
        cooperation_engine.card_reshape_runtime.last_successful_hand_by_side[
            cooperation_engine.player.owner_id],
        "pair",
        "后完成的协同对子成为最后成功牌型")

    var no_success_mark = _card("2", "wind")
    no_success_mark.set_imprint("enlightenment")
    var no_success_engine = _engine_with_hand([no_success_mark], [], 82405)
    no_success_engine.timing_system.emit_timing(
        BattleTimingSystemScript.BATTLE_END, {
            "actors": [no_success_engine.player, no_success_engine.enemy],
            "winner": no_success_engine.player,
        })
    _assert_true(
        no_success_engine.player.consumable_ids.is_empty(),
        "没有成功出招记录时悟道印不生成心得")

    var full_mark = _card("2", "forest")
    full_mark.set_imprint("enlightenment")
    var full_engine = _engine_with_hand([full_mark], [], 82406)
    full_engine.player.configure_consumables(["a", "b", "c"])
    full_engine.card_reshape_runtime.last_successful_hand_by_side[
        full_engine.player.owner_id] = "pair"
    full_engine.timing_system.emit_timing(
        BattleTimingSystemScript.BATTLE_END, {
            "actors": [full_engine.player, full_engine.enemy],
            "winner": full_engine.player,
        })
    _assert_equal(
        full_engine.player.consumable_ids,
        ["a", "b", "c"],
        "悟道印满三格时不生成也不覆盖")

    var alchemy = _card("5", "fire")
    alchemy.set_imprint("alchemy")
    var alchemy_engine = _engine_with_hand([alchemy], [], 82407)
    var alchemy_discard: Dictionary = alchemy_engine.player.card_zone_service.move_card(
        alchemy_engine.player, "hand", "discard_pile", alchemy, "explicit_discard")
    _assert_true(alchemy_discard.get("success", false), "化丹牌成功明确弃掉")
    _assert_equal(
        alchemy_engine.player.consumable_ids,
        ["zengyuan_pill"],
        "化丹从正式 pill 池生成当前丹药")

    var normal_alchemy = _card("6", "fire")
    normal_alchemy.set_imprint("alchemy")
    var normal_engine = _engine_with_hand([normal_alchemy], [], 82408)
    normal_engine.player.card_zone_service.move_card(
        normal_engine.player, "hand", "discard_pile", normal_alchemy, "normal_play")
    _assert_true(normal_engine.player.consumable_ids.is_empty(), "正常打出不触发化丹")

    var void_alchemy = _card("7", "fire")
    void_alchemy.set_imprint("alchemy")
    void_alchemy.set_enhancement("void_burst")
    var void_engine = _engine_with_hand([void_alchemy], [], 82409)
    void_engine.timing_system.emit_timing(BattleTimingSystemScript.TURN_END, {
        "actor": void_engine.player,
        "actors": [void_engine.player],
    })
    _assert_true(void_engine.player.consumable_ids.is_empty(), "虚无消散不触发化丹")

    var rock_alchemy = _card("8", "mountain")
    rock_alchemy.set_imprint("alchemy")
    rock_alchemy.set_enhancement("rock_solid")
    var rock_engine = _engine_with_hand([rock_alchemy], [], 82410)
    var rejected: Dictionary = rock_engine.player.card_zone_service.move_card(
        rock_engine.player, "hand", "discard_pile", rock_alchemy, "explicit_discard")
    _assert_true(not rejected.get("success", false), "磐石拒绝明确弃牌")
    _assert_true(rock_engine.player.consumable_ids.is_empty(), "未成功弃牌不触发化丹")

    var returning_alchemy = _card("9", "wind")
    returning_alchemy.set_imprint("alchemy")
    var returning_engine = _engine_with_hand([returning_alchemy], [], 82411)
    returning_engine.status_system.apply_card_anomaly(
        returning_alchemy, "mark", "returning_wind", {}, "化丹回风测试")
    returning_engine.player.card_zone_service.move_card(
        returning_engine.player,
        "hand",
        "discard_pile",
        returning_alchemy,
        "explicit_discard")
    _assert_equal(
        returning_engine.player.consumable_ids,
        ["zengyuan_pill"],
        "回风已改置牌区后化丹仍生成丹药")
    _assert_true(
        returning_engine.player.draw_pile.back() == returning_alchemy,
        "化丹结算后仍保留回风置于牌库顶的结果")

    var full_alchemy = _card("10", "fire")
    full_alchemy.set_imprint("alchemy")
    var full_alchemy_engine = _engine_with_hand([full_alchemy], [], 82412)
    full_alchemy_engine.player.configure_consumables(["a", "b", "c"])
    var full_rng_state: int = full_alchemy_engine.rng.state
    full_alchemy_engine.player.card_zone_service.move_card(
        full_alchemy_engine.player,
        "hand",
        "discard_pile",
        full_alchemy,
        "explicit_discard")
    _assert_equal(full_alchemy_engine.rng.state, full_rng_state, "化丹满栏不推进 RNG")
    _assert_equal(
        full_alchemy_engine.player.consumable_ids,
        ["a", "b", "c"],
        "化丹满栏不覆盖已有消耗品")

    var empty_alchemy = _card("J", "fire")
    empty_alchemy.set_imprint("alchemy")
    var empty_engine = _engine_with_hand([empty_alchemy], [], 82413)
    empty_engine.consumable_repository.consumables.erase("zengyuan_pill")
    var empty_rng_state: int = empty_engine.rng.state
    empty_engine.player.card_zone_service.move_card(
        empty_engine.player,
        "hand",
        "discard_pile",
        empty_alchemy,
        "explicit_discard")
    _assert_equal(empty_engine.rng.state, empty_rng_state, "化丹空候选池不推进 RNG")
    _assert_true(empty_engine.player.consumable_ids.is_empty(), "化丹空候选池不生成")

    var workshop = CardWorkshopServiceScript.new()
    var growth = GrowthInventoryScript.new(catalog)
    growth.run_deck.reset_standard("f2e1-sync")
    workshop.apply_run_card_reshape(
        growth.run_deck, ["wind_2"], "imprint", "alchemy")
    workshop.apply_run_card_reshape(
        growth.run_deck, ["forest_3"], "imprint", "enlightenment")
    workshop.apply_run_card_reshape(
        growth.run_deck, ["fire_4"], "imprint", "innate")
    var battle_session: BattleSession = BattleSessionScript.new(
        CombatEngineScript.new(null, catalog))
    _assert_true(
        battle_session.setup_battle(
            {"content_seed": 82414}, growth.to_progress_snapshot()),
        "三种印记本局牌组装配进战斗")
    var alchemy_battle_card = null
    var enlightenment_battle_card = null
    for card in battle_session.engine.player.all_zone_cards():
        if card.id == "wind_2":
            alchemy_battle_card = card
        elif card.id == "forest_3":
            enlightenment_battle_card = card
    for card in [alchemy_battle_card, enlightenment_battle_card]:
        var location: Dictionary = battle_session.engine.player.card_zone_service \
            .find_active_location(battle_session.engine.player, str(card.id))
        if str(location.get("zone", "")) != "hand":
            battle_session.engine.player.card_zone_service.move_card(
                battle_session.engine.player,
                str(location["zone"]),
                "hand",
                card,
                "test_setup")
    battle_session.engine.player.card_zone_service.move_card(
        battle_session.engine.player,
        "hand",
        "discard_pile",
        alchemy_battle_card,
        "explicit_discard")
    battle_session.engine.card_reshape_runtime.last_successful_hand_by_side[
        battle_session.engine.player.owner_id] = "pair"
    battle_session.engine.timing_system.emit_timing(
        BattleTimingSystemScript.BATTLE_END, {
            "actors": [battle_session.engine.player, battle_session.engine.enemy],
            "winner": battle_session.engine.player,
        })
    var captured: RunProgressSnapshot = battle_session.player_progress_snapshot()
    _assert_equal(
        captured.consumable_ids,
        ["zengyuan_pill", "pair_insight"],
        "悟道与化丹奖励进入玩家战斗进度快照")
    growth.apply_progress_snapshot(captured)
    growth.apply_progress_snapshot(captured)
    _assert_equal(
        growth.consumable_ids,
        ["zengyuan_pill", "pair_insight"],
        "同一绝对消耗品快照同步两次不重复生成")
    for imprint_spec in [
        ["wind_2", "alchemy"],
        ["forest_3", "enlightenment"],
        ["fire_4", "innate"],
    ]:
        _assert_equal(
            growth.run_deck.card_data(imprint_spec[0])["reshapes"]["imprint"],
            imprint_spec[1],
            "战斗同步保留 %s" % imprint_spec[1])

    var save_session = RunSessionScript.new(null, null, null, null, catalog)
    _assert_true(
        save_session.execute({"type": "setup_run", "seed": 82415}).success,
        "三印记存档测试建立本局")
    for imprint_spec in [
        ["wind_2", "alchemy"],
        ["forest_3", "enlightenment"],
        ["fire_4", "innate"],
    ]:
        workshop.apply_run_card_reshape(
            save_session.growth.run_deck,
            [imprint_spec[0]],
            "imprint",
            imprint_spec[1])
    var restored: Dictionary = RunSaveDataScript.new().capture(
        save_session).restore_session(catalog)
    _assert_true(restored.get("success", false), "三种印记存档后可以读回")
    for imprint_spec in [
        ["wind_2", "alchemy"],
        ["forest_3", "enlightenment"],
        ["fire_4", "innate"],
    ]:
        _assert_equal(
            restored["run_session"].growth.run_deck.card_data(
                imprint_spec[0])["reshapes"]["imprint"],
            imprint_spec[1],
            "存档读档保留 %s" % imprint_spec[1])
    var no_imprint_deck = RunDeckScript.new(catalog)
    no_imprint_deck.reset_standard("f2e1-old")
    var no_imprint_snapshot: Dictionary = no_imprint_deck.to_snapshot()
    _assert_equal(
        RunDeckScript.new(catalog).restore_snapshot(no_imprint_snapshot),
        [],
        "不含印记的旧本局牌组快照继续兼容")

func _find_opportunity_seed(pattern: Array) -> int:
    var probe := RandomNumberGenerator.new()
    for seed in range(1, 100000):
        probe.seed = seed
        var actual: Array = []
        for index in range(pattern.size() / 2):
            actual.append(probe.randi_range(1, 5) == 1)
            actual.append(probe.randi_range(1, 10) == 1)
        if actual == pattern:
            return seed
    return -1

func _resolve_all_pending_choices(engine) -> Dictionary:
    var result: Dictionary = {}
    while engine.has_pending_effect_choice():
        var request: Dictionary = engine.pending_effect_choice_snapshot()
        var minimum := int(request.get("minimum", 0))
        var candidates: Array = request.get("candidate_ids", [])
        result = engine.resolve_effect_choice(
            str(request.get("request_id", "")),
            candidates.slice(0, minimum))
    return result

func _count_status_changes(history: Array, status_id: String) -> int:
    var count := 0
    for change in history:
        if str(change.get("status_id", "")) == status_id \
                and str(change.get("change_type", "")) == "card_anomaly_apply":
            count += 1
    return count

func _test_standard_deck() -> void:
    var deck := DeckFactoryScript.create_standard_deck()
    _assert_equal(deck.size(), 52, "基础牌组共 52 张")
    var attribute_counts := {"wind": 0, "forest": 0, "fire": 0, "mountain": 0}
    var face_values := {}
    var rank_groups: Dictionary = {}
    for card in deck:
        attribute_counts[card.attribute] += 1
        if not rank_groups.has(card.rank_order):
            rank_groups[card.rank_order] = []
        rank_groups[card.rank_order].append(card)
        _assert_equal(card.definition_id, card.id, "基础牌兼容ID同时保留定义身份")
        if card.attribute == "wind":
            face_values[card.rank_name] = card.qi_value
    for attribute in attribute_counts:
        _assert_equal(attribute_counts[attribute], 13, "%s 属性 13 张" % attribute)
    _assert_equal(face_values["J"], 11, "J 真气值")
    _assert_equal(face_values["Q"], 11, "Q 真气值")
    _assert_equal(face_values["K"], 11, "K 真气值")
    _assert_equal(face_values["A"], 12, "A 真气值")
    for rank_order in rank_groups:
        _assert_equal(rank_groups[rank_order].size(), 4, "标准牌组每个牌阶只有四张真气")
        _assert_equal(
            HandEvaluatorScript.evaluate(rank_groups[rank_order])["id"],
            "four_kind",
            "标准牌组任一同牌阶组最多形成四条")

func _test_pool_structure_and_turn_draw_rules() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(7, false)
    var unique_pools: Dictionary = {}
    for hand_id in engine.repository.pool_membership:
        for pool_id in engine.repository.pool_membership[hand_id]:
            unique_pools[pool_id] = true
    _assert_equal(unique_pools.size(), 5, "五类共用功法池")
    _assert_equal(
        engine.repository.pool_membership,
        {
            "high_card": ["high"],
            "pair": ["pair"],
            "two_pair": ["pair"],
            "three_kind": ["three"],
            "straight": ["straight"],
            "full_house": ["pair", "three"],
            "four_kind": ["bomb"],
            "five_kind": ["bomb"],
        },
        "八种精确牌型的功法池成员资格与权威表完全一致")
    _assert_equal(
        engine.sequence_book.sequences["straight"],
        ["five_yang_chase"],
        "五阳逐影只挂有效顺子序列")
    _assert_equal(engine.sequence_book.sequences["five_kind"], [], "五条使用独立空初始序列")
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

func _test_active_hand_types_and_same_attribute_rules() -> void:
    var five_kind_cards := [
        _card("8", "wind"), _card("8", "forest"), _card("8", "fire"),
        _card("8", "mountain"), _card("8", "wind"),
    ]
    var cases := [
        {"id": "high_card", "cards": [_card("A"), _card("7", "forest"), _card("3", "fire")], "count": 1, "sum": 12},
        {"id": "pair", "cards": [_card("7"), _card("7", "forest"), _card("A", "fire"), _card("3")], "count": 2, "sum": 14},
        {"id": "two_pair", "cards": [_card("9"), _card("9", "forest"), _card("4"), _card("4", "fire"), _card("A")], "count": 4, "sum": 26},
        {"id": "three_kind", "cards": [_card("6"), _card("6", "forest"), _card("6", "fire"), _card("A")], "count": 3, "sum": 18},
        {"id": "straight", "cards": [_card("A"), _card("2", "forest"), _card("3", "fire"), _card("4", "mountain"), _card("5")], "count": 5, "sum": 26},
        {"id": "full_house", "cards": [_card("7"), _card("7", "forest"), _card("7", "fire"), _card("3"), _card("3", "forest")], "count": 5, "sum": 27},
        {"id": "four_kind", "cards": [_card("8"), _card("8", "forest"), _card("8", "fire"), _card("8", "mountain"), _card("A")], "count": 4, "sum": 32},
        {"id": "five_kind", "cards": five_kind_cards, "count": 5, "sum": 40},
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
    var same_attribute_cards := [
        _card("2", "fire"), _card("3", "fire"), _card("4", "fire"),
        _card("5", "fire"), _card("6", "fire"),
    ]
    var same_attribute_straight := HandEvaluatorScript.evaluate(same_attribute_cards)
    _assert_equal(same_attribute_straight["id"], "straight", "同属性顺子仍只识别为顺子")
    _assert_equal(same_attribute_straight["multiplier"], 4, "同属性顺子只使用顺子固定倍率")
    _assert_true(not HandEvaluatorScript.HANDS.has("flush"), "正式牌型表不再包含同花")
    _assert_true(not HandEvaluatorScript.HANDS.has("straight_flush"), "正式牌型表不再包含同花顺")

    var four_kind_result := HandEvaluatorScript.evaluate(five_kind_cards.slice(0, 4))
    var five_kind_result := HandEvaluatorScript.evaluate(five_kind_cards)
    _assert_equal(five_kind_result["multiplier"], 12, "五条固定倍率为十二倍")
    _assert_true(
        five_kind_result["strength"] > four_kind_result["strength"],
        "五条强度高于四条")
    var four_kind_values := PowerCalculatorScript.calculate(four_kind_result)
    var five_kind_values := PowerCalculatorScript.calculate(five_kind_result)
    _assert_true(
        is_equal_approx(
            float(five_kind_values["baseline_value"]) / float(four_kind_values["baseline_value"]),
            15.0 / 7.0),
        "同牌阶五条基准值约为四条的 2.14 倍")

    var best_source := five_kind_cards + [_card("A", "forest")]
    var best_candidates := HandEvaluatorScript.evaluate_best_candidates(best_source)
    _assert_equal(best_candidates.size(), 1, "五条稳定排除同源四条候选")
    _assert_equal(HandEvaluatorScript.evaluate_best(best_source)["id"], "five_kind", "五条稳定成为最高牌型")

    var same_attribute_five := [
        _card("7", "wind"), _card("7", "wind"), _card("7", "wind"),
        _card("7", "wind"), _card("7", "wind"),
    ]
    var five_engine = _engine_with_hand(same_attribute_five)
    var same_attribute_five_preview: Dictionary = five_engine.preview(_ids(same_attribute_five))
    _assert_equal(same_attribute_five_preview["hand"]["id"], "five_kind", "同属性五张同牌阶仍识别为五条")
    _assert_equal(same_attribute_five_preview["values"]["fixed_multiplier"], 12, "同属性五条保持十二倍固定倍率")
    _assert_equal(same_attribute_five_preview["values"]["power_amp_percent"], 50, "同属性五条独立获得公共+50%增幅")

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
    var status_catalog = ContentCatalogScript.new()
    _assert_true(status_catalog.load_all(), "伤害服务测试载入状态定义")
    var standalone_status_system = StatusSystemScript.new(status_catalog)
    var actor = BattleSideScript.new("攻击方")
    actor.use_status_system(standalone_status_system)
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
    direct_actor.use_status_system(standalone_status_system)
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
    var record = engine.action_resolver.make_action_record(
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
        "pool": "pair",
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
    ## 覆盖 damage + draw + discard_random + draw_if_captured_attribute 效果链。
    ##
    ## 此前由清风过隙承载，该功法已随风池重写移出权威活跃名单（提交 d66b4a3）。
    ## draw_if_captured_attribute 仍是注册操作码但已无内容承载，因此改用合成夹具，
    ## 避免这条链变成零运行时覆盖。
    var selected := [_card("9", "mountain")]
    var remaining := [_card("3", "forest"), _card("4", "fire")]
    var draw_cards := [_card("6", "forest"), _card("2", "wind")]
    var engine = _engine_with_hand(selected + remaining, draw_cards, 4242)
    engine.repository.techniques["probe_draw_discard_chain"] = {
        "id": "probe_draw_discard_chain",
        "name": "测试抽弃条件链",
        "pool": "high",
        "effects": [
            {"op": "damage", "amount": {"kind": "power"}},
            {"op": "draw", "count": {"kind": "constant", "value": 1}, "capture": "first_draw"},
            {"op": "discard_random", "count": {"kind": "constant", "value": 1}},
            {
                "op": "draw_if_captured_attribute",
                "capture": "first_draw",
                "attribute": "wind",
                "count": 1,
            },
        ],
    }
    engine.sequence_book.configure({"high_card": ["probe_draw_discard_chain"]})
    var result := engine.confirm_play(_ids(selected))
    _assert_true(result["technique_triggered"], "抽弃条件链功法触发")
    _assert_equal(engine.enemy.life, 91, "效果链首项造成 P 点伤害")
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
    ## 覆盖 register_attack_counter_delay：建立时冻结 P 快照，跨回合按旧快照结算。
    ##
    ## 此前由百击归烬承载。该功法已被权威源废弃（同花池整体废弃），但操作码保留：
    ## 火池「待确认」明确记录需要新的替代设计来提供跨回合延迟追击。因此改用合成
    ## 夹具，保住机制的运行时覆盖，等替代设计落地后再换回真实功法。
    var same_attribute_straight := [
        _card("2", "forest"), _card("3", "forest"), _card("4", "forest"),
        _card("5", "forest"), _card("6", "forest"),
    ]
    var engine = _engine_with_hand(same_attribute_straight)
    engine.repository.techniques["probe_attack_counter_delay"] = {
        "id": "probe_attack_counter_delay",
        "name": "测试延迟追击",
        "pool": "straight",
        "special": true,
        "effects": [{
            "op": "register_attack_counter_delay",
            "turn_ends": 2,
            "damage": {
                "kind": "power_fraction",
                "numerator": 1,
                "denominator": 20,
                "minimum": 1,
            },
        }],
    }
    engine.sequence_book.configure({"straight": ["probe_attack_counter_delay"]})
    var result := engine.confirm_play(_ids(same_attribute_straight))
    _assert_true(result["technique_triggered"], "延迟追击功法建立延迟记录")
    _assert_equal(result["preview"]["hand"]["id"], "straight", "延迟夹具使用合法顺子入口")
    _assert_equal(result["preview"]["values"]["power_amp_percent"], 50, "同属性顺子只进入公共+50%加法池")
    _assert_equal(engine.delayed_effects[0]["snapshot_power"], 120, "延迟记录建立时 P（含五张同属性+50%）")
    _assert_equal(engine.delayed_effects[0]["damage_per_segment"], 6, "延迟每段读取快照 P/20")
    engine.deal_damage(engine.player, engine.enemy, 20, "technique")
    engine.power_modifiers["straight"] = {"power_amp_percent": 500}
    engine.end_player_turn()
    _assert_equal(engine.enemy.life, 80, "第一个回合结束尚未结算延迟")
    engine.start_player_turn()
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
    engine.player.configure_consumables([
        "high_card_insight", "zengyuan_pill", "pair_insight", "zengyuan_pill"])
    _assert_equal(engine.player.consumable_ids.size(), 3, "三类消耗品共用三格容量")
    _assert_equal(engine.player.consumable_ids, ["high_card_insight", "zengyuan_pill", "pair_insight"], "共享槽保留三种代表消耗品")
    _assert_equal(engine.grant_consumable(engine.player, "straight_insight", "测试"), false, "没有空位时不生成消耗品")
    var used := engine.use_player_consumable(0, [])
    _assert_true(used["success"], "无目标心得可以直接使用")
    _assert_equal(engine.player.consumable_ids.size(), 2, "使用后立即释放共享槽位")
    _assert_true(engine.grant_consumable(engine.player, "straight_insight", "测试"), "释放槽位后可以生成消耗品")
    _assert_equal(engine.player.consumable_ids.size(), 3, "重新生成后占满三格")

func _test_battle_consumable_multi_effect_rollback() -> void:
    var target = _card("9", "wind")
    target.set_enhancement("momentum")
    var engine = _engine_with_hand([target], [], 7901)
    var configured: bool = bool(engine.consumable_repository.configure({
        "practice_offer_ids": ["battle_transaction_probe"],
        "consumables": [{
            "id": "battle_transaction_probe",
            "name": "战斗事务探针",
            "targeting": {"zone": "hand", "minimum": 1, "maximum": 1},
            "effects": [
                {"op": "gain_insight", "hand": "high_card", "pools": ["high"]},
                {"op": "apply_enhancement", "enhancement": "qi_boost"},
                {"op": "battle_transaction_fail", "amount": 0},
            ],
        }],
    }))
    _assert_true(configured, "战斗事务探针消耗品仓库配置成功")
    _assert_true(
        engine.consumable_service._handler_registry.register_handler(
            ConsumableProbeHandler.new(["battle_transaction_fail"], true)),
        "战斗事务失败探针注册成功")
    engine.player.configure_consumables(["battle_transaction_probe"])
    var card_before: Dictionary = target.persistent_reshape_state()
    var progression_before: Dictionary = engine.player.hand_technique_progression.duplicate(true)
    var owned_before: Array[String] = engine.player.owned_technique_ids.duplicate()
    var consumables_before: Array[String] = engine.player.consumable_ids.duplicate()
    var rng_state_before: int = int(engine.rng.state)

    var result := engine.use_player_consumable(0, [target.id])

    _assert_true(not result.get("success", false), "战斗多效果第二阶段后失败时整体失败")
    _assert_true(result.get("rolled_back", false), "战斗多效果失败报告已完成事务回滚")
    _assert_equal(target.persistent_reshape_state(), card_before, "失败恢复目标真气持久重塑状态")
    _assert_equal(
        engine.player.hand_technique_progression,
        progression_before,
        "失败恢复牌型功法成长")
    _assert_equal(engine.player.owned_technique_ids, owned_before, "失败恢复已拥有功法")
    _assert_equal(engine.player.consumable_ids, consumables_before, "失败不消费指定消耗品槽")
    _assert_equal(engine.rng.state, rng_state_before, "失败恢复战斗消耗品随机状态")

func _test_insight_growth_and_technique_acquisition() -> void:
    var high = _card("9", "wind")
    var pair := [_card("7", "forest"), _card("7", "fire")]
    var engine = _engine_with_hand([high] + pair, [], 810)
    engine.player.configure_consumables(["high_card_insight"])
    _assert_true(not engine.player.owned_technique_ids.has("fire_sparks"), "初始玩家功法库不含敌方代表功法")
    var owned_before: Array[String] = engine.player.owned_technique_ids.duplicate()
    var sequence_before: Array = engine.sequence_book.sequences["high_card"].duplicate()
    var result := engine.use_player_consumable(0, [])
    _assert_true(result["success"], "高牌心得使用成功")
    var acquired_id := str(result["acquired_technique_id"])
    _assert_true(acquired_id != "" and not owned_before.has(acquired_id), "心得从合格池获得尚未拥有的功法")
    _assert_true(engine.player.owned_technique_ids.has(acquired_id), "所得功法进入本局功法库")
    _assert_equal(engine.sequence_book.sequences["high_card"], sequence_before, "心得所得功法不自动修改当前序列")
    var high_preview := engine.preview([high.id])
    _assert_equal(high_preview["values"]["technique_multiplier"], 1, "心得不改变高牌功法倍率")
    _assert_equal(high_preview["values"]["technique_value"], 9, "心得不直接改变高牌功法值")
    var pair_preview := engine.preview(_ids(pair))
    _assert_equal(pair_preview["values"]["technique_multiplier"], 2, "其他精确牌型功法倍率保持不变")

    var exhausted := GrowthInventoryScript.new(engine.content_catalog, false)
    exhausted.hand_technique_progression["four_kind"] = {
        "slot_count": 1,
        "sequence": ["seize_qi_return_nest"],
    }
    exhausted.learned_technique_ids = ["seize_qi_return_nest"]
    var exhausted_result := exhausted.apply_insight_growth(
        "four_kind", ["seize_qi_return_nest"])
    _assert_true(exhausted_result["success"], "心得候选耗尽时仍成功完成槽位成长")
    _assert_equal(exhausted_result["acquired_technique_id"], "", "候选耗尽时不跨池获得功法")
    _assert_equal(
        exhausted.hand_progression("four_kind")["slot_count"], 2,
        "候选耗尽时对应牌型槽位仍增加1")

    var consumable_definition: Dictionary = engine.content_catalog.definition("consumables")
    var five_kind_insight_ids: Array[String] = []
    for consumable in consumable_definition["consumables"]:
        for effect in consumable.get("effects", []):
            if effect.get("op", "") == "gain_insight" \
                    and effect.get("hand", "") == "five_kind":
                five_kind_insight_ids.append(str(consumable.get("id", "")))
    _assert_equal(five_kind_insight_ids, ["five_kind_insight"], "五条心得已作为正式心得定义")
    _assert_true(
        consumable_definition["practice_offer_ids"].has("five_kind_insight"),
        "普通修习随机池包含五条心得")

func _test_formal_practice_shop_and_hand_progression() -> void:
    var production_profile = RuntimeProfileScript.production()
    var catalog = ContentCatalogScript.new(production_profile)
    _assert_true(catalog.load_all(), "production 内容目录可以装载正式修习配置")
    var expected_insight_ids := [
        "high_card_insight", "pair_insight", "two_pair_insight", "three_kind_insight",
        "straight_insight", "full_house_insight", "four_kind_insight", "five_kind_insight",
    ]
    expected_insight_ids.sort()
    var consumable_definition: Dictionary = catalog.definition("consumables")
    var ordinary_insight_ids: Array = []
    for consumable_id in consumable_definition["practice_offer_ids"]:
        if expected_insight_ids.has(str(consumable_id)):
            ordinary_insight_ids.append(str(consumable_id))
    ordinary_insight_ids.sort()
    _assert_equal(ordinary_insight_ids, expected_insight_ids, "八种心得全部进入普通消耗品候选")
    var practice_definition: Dictionary = catalog.definition("practice_shop")
    var shop_insight_ids: Array = []
    for candidate in practice_definition["normal_candidates"]:
        var candidate_id := str(candidate.get("id", ""))
        if expected_insight_ids.has(candidate_id):
            shop_insight_ids.append(candidate_id)
    shop_insight_ids.sort()
    _assert_equal(shop_insight_ids, expected_insight_ids, "普通修习商店候选包含八种心得")
    _assert_equal(practice_definition["pack_candidates"].size(), 3, "普通、大型、豪华三种心得包仍全部存在")
    for pack in practice_definition["pack_candidates"]:
        var pack_ids: Array = pack["candidate_ids"].duplicate()
        pack_ids.sort()
        _assert_equal(pack_ids, expected_insight_ids, "%s包含完整八种心得" % str(pack["name"]))
    var first: RunSession = RunSessionScript.new(
        null, null, null, null, catalog, null, null, null, null, production_profile)
    var second: RunSession = RunSessionScript.new(
        null, null, null, null, catalog, null, null, null, null, production_profile)
    _assert_true(first.execute({"type": "setup_run", "seed": 21101}).success, "production 本局可以建立")
    _assert_true(second.execute({"type": "setup_run", "seed": 21101}).success, "相同种子本局可以重复建立")
    _assert_true(first.snapshot().can_open_practice, "production 模式待选地图可以打开修习")
    var practice := first.snapshot().practice
    var same_practice := second.snapshot().practice
    _assert_equal(practice.get("normal", []).size(), 2, "普通商品栏固定为两个槽位")
    _assert_equal(practice.get("packs", []).size(), 2, "补充包栏固定为两个槽位")
    _assert_equal(practice.get("coupons", []).size(), 1, "优惠券栏固定为一个槽位")
    _assert_equal(practice.get("normal"), same_practice.get("normal"), "相同种子普通商品稳定")
    _assert_equal(practice.get("packs"), same_practice.get("packs"), "相同种子补充包稳定")
    _assert_equal(practice.get("coupons"), same_practice.get("coupons"), "相同种子优惠券槽稳定")
    _assert_true(first.execute({"type": "open_practice"}).success, "production 修习入口命令成功")

    first.growth.experience = 100
    var purchase := first.execute({
        "type": "purchase_practice_offer", "group": "normal", "slot_index": 0})
    _assert_true(purchase.success, "正式普通商品可以购买")
    _assert_equal(first.snapshot().practice.get("normal", [])[0], {}, "购买后普通槽位保持为空")
    var packs_before: Array = first.snapshot().practice.get("packs", []).duplicate(true)
    var coupons_before: Array = first.snapshot().practice.get("coupons", []).duplicate(true)
    var meditation_costs: Array[int] = []
    for _index in range(3):
        var meditation := first.execute({"type": "meditate"})
        _assert_true(meditation.success, "历练足够时冥想成功")
        meditation_costs.append(int(meditation.payload_value("cost", 0)))
    _assert_equal(meditation_costs, [5, 6, 7], "同一商店冥想费用依次为5、6、7")
    _assert_equal(first.snapshot().practice.get("normal", [])[0], {}, "冥想不补回已购买普通槽位")
    _assert_equal(first.snapshot().practice.get("packs", []), packs_before, "冥想不刷新补充包")
    _assert_equal(first.snapshot().practice.get("coupons", []), coupons_before, "冥想不刷新优惠券")
    first.growth.experience = 0
    var practice_before_reject := first.snapshot().practice.duplicate(true)
    var rejected := first.execute({"type": "meditate"})
    _assert_true(not rejected.success, "历练不足时冥想被拒绝")
    _assert_equal(first.snapshot().practice, practice_before_reject, "拒绝冥想不改变商店状态或随机序列")

    var high_initial: Dictionary = first.growth.hand_progression("high_card")
    _assert_equal(high_initial.get("slot_count"), 1, "高牌初始功法槽位为1")
    _assert_equal(high_initial.get("sequence", []).size(), 1, "高牌初始 active sequence 只有一门")
    var five_initial: Dictionary = first.growth.hand_progression("five_kind")
    _assert_equal(five_initial.get("slot_count"), 1, "五条初始功法槽位为1")
    _assert_equal(five_initial.get("sequence", []), [], "五条初始序列允许为空")
    var membership: Dictionary = catalog.definition("techniques").get("pool_membership", {})
    _assert_equal(membership.get("four_kind"), ["bomb"], "四条读取炸弹池")
    _assert_equal(membership.get("five_kind"), ["bomb"], "五条读取炸弹池")
    var four_before: Dictionary = first.growth.hand_progression("four_kind")
    var four_result: Dictionary = first.growth.apply_insight_growth(
        "four_kind", ["seize_qi_return_nest"])
    _assert_true(four_result.success, "四条心得成长成功")
    _assert_equal(four_result.acquired_technique_id, "", "四条候选耗尽时不跨池改抽")
    _assert_equal(first.growth.hand_progression("four_kind").slot_count, int(four_before.slot_count) + 1, "四条心得只增加四条槽位")
    var five_result: Dictionary = first.growth.apply_insight_growth(
        "five_kind", ["seize_qi_return_nest"])
    _assert_true(five_result.success, "五条心得成长成功")
    _assert_equal(five_result.acquired_technique_id, "seize_qi_return_nest", "五条从炸弹池获得正式功法")
    _assert_equal(first.growth.hand_progression("five_kind").slot_count, 2, "五条心得增加五条槽位")
    _assert_equal(first.growth.hand_progression("four_kind").slot_count, 2, "五条成长不改变四条槽位")

    var direct_growth = GrowthInventoryScript.new(catalog, false)
    direct_growth.experience = 3
    var direct_service := PracticeServiceScript.new(catalog)
    direct_service.configure({
        "normal_slots": 1,
        "pack_slots": 0,
        "coupon_slots": 0,
        "normal_candidates": [{
            "id": "stagnant_gu_conceal_breath", "kind": "technique", "price": 3}],
        "pack_candidates": [],
        "coupon_candidates": [],
    })
    var direct_sequence: Array = direct_growth.hand_progression("high_card").sequence.duplicate()
    direct_service.start_new_shop(direct_growth, 21102, 1, 1)
    var direct_purchase := direct_service.purchase(direct_growth, "normal", 0, true)
    _assert_true(direct_purchase.success, "直接购买正式功法成功")
    _assert_true(direct_growth.learned_technique_ids.has("stagnant_gu_conceal_breath"), "直接购买只加入本局功法库")
    _assert_equal(direct_growth.hand_progression("high_card").sequence, direct_sequence, "直接购买不自动修改牌型序列")

    var save_data = RunSaveDataScript.new().capture(first)
    var restored: Dictionary = save_data.restore_session(catalog)
    _assert_true(restored.success, "修习商店和牌型成长可以存档读档")
    _assert_equal(
        restored.run_session.growth.practice_shop_state,
        first.growth.practice_shop_state,
        "读档保留当前商店槽位、空位和冥想费用")
    _assert_equal(
        restored.run_session.growth.hand_technique_progression,
        first.growth.hand_technique_progression,
        "读档保留八种牌型槽位与功法序列")

func _test_zengyuan_pill_enhancement_and_preview() -> void:
    var pair := [_card("7", "wind"), _card("7", "forest")]
    pair[0].set_enhancement("momentum")
    var third = _card("3", "fire")
    var engine = _engine_with_hand(pair + [third])
    engine.player.configure_consumables(["zengyuan_pill"])
    var no_target := engine.use_player_consumable(0, [])
    _assert_equal(no_target["success"], false, "增元丹至少需要一张目标真气")
    var too_many := engine.use_player_consumable(0, _ids(pair + [third]))
    _assert_equal(too_many["success"], false, "增元丹不能选择超过两张真气")
    var result := engine.use_player_consumable(0, _ids(pair))
    _assert_true(result["success"], "增元丹可以强化至多两张真气")
    _assert_equal(pair[0].reshape_enhancement, "qi_boost", "新强化替换同一张真气的旧强化")
    _assert_equal(pair[1].reshape_enhancement, "qi_boost", "第二张目标获得增元强化")
    var preview := engine.preview(_ids(pair))
    _assert_equal(preview["values"]["base_value"], 30, "两张增元七的有效真气值各加八")
    _assert_equal(preview["values"]["baseline_value"], 60, "增元同时进入牌型基准值")
    _assert_equal(preview["values"]["technique_value"], 60, "增元立即进入功法值预览")

func _test_simple_reshape_behaviors() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "简单强化测试载入正式目录")
    var card = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_8"), "simple:hunyuan", catalog.card_reshape_rules)
    card.set_enhancement("hunyuan")
    _assert_true(card.is_attribute("wind") and card.is_attribute("forest"), "混元可同时满足不同属性条件")
    _assert_true(card.is_attribute("fire") and card.is_attribute("mountain"), "混元覆盖火山属性条件")
    _assert_equal(card.attribute, "wind", "混元不改变基础属性身份")

func _test_battle_consumable_reshape_persists_via_run_deck() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "跨战斗强化测试载入内容目录")
    var run_deck = RunDeckScript.new(catalog)
    run_deck.reset_standard("consumable-reshape")
    var progress = RunProgressSnapshotScript.from_dict({
        "consumable_ids": ["zengyuan_pill"],
        "learned_technique_ids": [],
        "run_deck": run_deck.to_snapshot(),
    })
    var first_battle: BattleSession = BattleSessionScript.new(CombatEngineScript.new())
    _assert_true(first_battle.setup_battle({"content_seed": 4404}, progress), "带增元丹的本局牌组可以进入战斗")
    first_battle.execute({"type": "start_turn"})
    var target = first_battle.engine.player.hand[0]
    var target_id := str(target.id)
    var reshape_result := first_battle.execute({
        "type": "use_consumable",
        "slot_index": 0,
        "card_ids": [target_id],
    })
    _assert_true(reshape_result.success, "战斗中可以使用消耗品重塑真气")
    _assert_equal(target.reshape_enhancement, "qi_boost", "战斗消耗品施加增元强化")
    var after_progress = first_battle.player_progress_snapshot()
    _assert_true(after_progress.consumable_ids.is_empty(), "战斗中使用消耗品后释放本局槽位")
    var second_battle = BattleSessionScript.new(CombatEngineScript.new())
    _assert_true(second_battle.setup_battle({"content_seed": 4405}, after_progress), "重塑后的 RunDeck 可以建立下一场战斗")
    var restored = null
    for card in second_battle.engine.player.all_zone_cards():
        if card.id == target_id:
            restored = card
            break
    _assert_true(restored != null, "下一场战斗保留被消耗品重塑的真气实例")
    _assert_equal(restored.reshape_enhancement, "qi_boost", "战斗中施加的强化通过 RunDeck 跨战斗保存")
    _assert_true(restored.anomaly_snapshot()["marks"].is_empty(), "跨战斗重塑同步不会附带战斗异状")

func _test_consumable_effect_registry_contract() -> void:
    var registry = ConsumableEffectHandlerRegistryScript.new()
    _assert_equal(
        registry.operation_ids(),
        ["apply_enhancement", "apply_origin", "gain_insight"],
        "默认注册三个现有消耗品操作")

    var duplicate_registry = ConsumableEffectHandlerRegistryScript.new(false)
    _assert_true(
        duplicate_registry.register_handler(ConsumableProbeHandler.new(["gain_insight"])),
        "空注册表可以注册首个探针")
    _assert_equal(
        duplicate_registry.register_handler(ConsumableProbeHandler.new(["gain_insight"])),
        false,
        "重复 op 注册被拒绝")
    _assert_true(
        _array_contains_text(duplicate_registry.registration_errors(), "重复注册：gain_insight"),
        "重复注册错误报告实际操作 ID")

    var invalid_registry = ConsumableEffectHandlerRegistryScript.new(false)
    _assert_equal(
        invalid_registry.register_handler(ConsumableProbeHandler.new(["Bad-ID"])),
        false,
        "非法 snake_case 操作 ID 被拒绝")
    _assert_true(
        _array_contains_text(invalid_registry.registration_errors(), "稳定 snake_case"),
        "非法 ID 错误说明稳定命名要求")

    var empty_registry = ConsumableEffectHandlerRegistryScript.new(false)
    _assert_equal(
        empty_registry.register_handler(ConsumableProbeHandler.new([])),
        false,
        "空操作列表被拒绝")

func _test_consumable_effect_validation_scope() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "消耗品校验测试基准内容有效")

    var unknown_op_values := _catalog_definitions(catalog)
    unknown_op_values["consumables"]["consumables"][0]["effects"] = [{"op": "unknown_op"}]
    var unknown_op_catalog = ContentCatalogScript.new()
    _assert_true(
        not unknown_op_catalog.load_from_definitions(unknown_op_values),
        "未注册 op 使内容加载阶段明确失败")
    _assert_true(
        _array_contains_text(
            unknown_op_catalog.errors,
            "consumables.consumables[0].effects[0].op"),
        "未注册 op 错误报告完整 scope")
    _assert_true(
        _array_contains_text(unknown_op_catalog.errors, "unknown_op"),
        "未注册 op 错误包含操作名")

    var bad_hand_values := _catalog_definitions(catalog)
    bad_hand_values["consumables"]["consumables"][0]["effects"] = [
        {"op": "gain_insight", "hand": "not_a_hand", "pools": ["high"]}]
    var bad_hand_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_hand_catalog.load_from_definitions(bad_hand_values),
        "非法精确牌型引用在加载阶段失败")
    _assert_true(
        _array_contains_text(bad_hand_catalog.errors, "引用未知精确牌型 not_a_hand"),
        "非法牌型错误稳定定位")

    var bad_pool_values := _catalog_definitions(catalog)
    bad_pool_values["consumables"]["consumables"][0]["effects"] = [
        {"op": "gain_insight", "hand": "high_card", "pools": ["not_a_pool"]}]
    var bad_pool_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_pool_catalog.load_from_definitions(bad_pool_values),
        "非法功法池引用在加载阶段失败")
    _assert_true(
        _array_contains_text(bad_pool_catalog.errors, "引用未知功法池 not_a_pool"),
        "非法功法池错误稳定定位")

    var bad_enhancement_values := _catalog_definitions(catalog)
    bad_enhancement_values["consumables"]["consumables"][0]["effects"] = [
        {"op": "apply_enhancement", "enhancement": "not_real"}]
    var bad_enhancement_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_enhancement_catalog.load_from_definitions(bad_enhancement_values),
        "非法强化引用在加载阶段失败")
    _assert_true(
        _array_contains_text(bad_enhancement_catalog.errors, "引用未知强化 not_real"),
        "非法强化错误稳定定位")

    var bad_origin_values := _catalog_definitions(catalog)
    bad_origin_values["consumables"]["consumables"][0]["effects"] = [{
        "op": "apply_origin",
        "origin": "attribute_change",
        "payload": {"attribute": "not_real"},
    }]
    var bad_origin_catalog = ContentCatalogScript.new()
    _assert_true(
        not bad_origin_catalog.load_from_definitions(bad_origin_values),
        "转属引用非法基础属性时加载失败")
    _assert_true(
        _array_contains_text(bad_origin_catalog.errors, "引用未知基础属性 not_real"),
        "非法本源 payload 错误稳定定位")

func _test_run_consumable_high_card_insight() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(
        session.execute({"type": "setup_run", "seed": 77123}).success,
        "心得测试本局建立")
    session.growth.consumable_ids.append("high_card_insight")
    var query := session.execute({"type": "query_consumable_use", "slot_index": 0})
    _assert_true(query.success, "心得使用查询成功")
    _assert_equal(query.payload_value("consumable_id"), "high_card_insight", "查询返回槽位消耗品 ID")
    _assert_equal(query.payload_value("name"), "高牌心得", "查询返回消耗品名称")
    _assert_equal(
        query.payload_value("targeting"),
        {"zone": "none", "selection": "deterministic_random"},
        "心得目标协议为 none/deterministic_random")
    _assert_equal(query.payload_value("selection"), "deterministic_random", "心得查询返回 selection")
    _assert_equal(query.payload_value("minimum"), 0, "心得最少目标数为 0")
    _assert_equal(query.payload_value("maximum"), 0, "心得最多目标数为 0")
    _assert_equal(query.payload_value("eligible_targets"), [], "心得没有可选真气目标")
    _assert_true(query.payload_value("can_use"), "心得可以无目标使用")

    var before := int(session.growth.hand_progression("high_card")["slot_count"])
    var use := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(use.success, "高牌心得无目标使用成功")
    _assert_equal(
        int(session.growth.hand_progression("high_card")["slot_count"]),
        before + 1,
        "高牌功法槽位 +1")
    var applied: Array = use.payload_value("applied")
    var acquired_id := str(applied[0]["acquired_technique_id"])
    _assert_true(acquired_id != "", "高牌心得从合格池获得功法")
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "功法池校验内容目录有效")
    var technique: Dictionary = catalog.get_by_id("technique", acquired_id)
    _assert_equal(technique.get("pool"), "high", "只从高牌正式池获得功法")
    _assert_equal(session.growth.consumable_ids, [], "使用后消耗品槽释放")
    _assert_equal(int(session.growth.consumable_use_sequence), 1, "成功使用递增随机序号")

    var full_first: RunSession = RunSessionScript.new()
    var full_second: RunSession = RunSessionScript.new()
    _assert_true(full_first.execute({"type": "setup_run", "seed": 77125}).success, "首个葫芦心得本局建立")
    _assert_true(full_second.execute({"type": "setup_run", "seed": 77125}).success, "同种子葫芦心得本局建立")
    var full_sequence_before: Array = full_first.growth.hand_progression("full_house").sequence.duplicate()
    full_first.growth.consumable_ids.append("full_house_insight")
    full_second.growth.consumable_ids.append("full_house_insight")
    var full_use_first := full_first.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    var full_use_second := full_second.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(full_use_first.success and full_use_second.success, "葫芦心得在相同种子本局均使用成功")
    var full_applied_first: Dictionary = full_use_first.payload_value("applied")[0]
    var full_applied_second: Dictionary = full_use_second.payload_value("applied")[0]
    var full_candidates: Array = full_applied_first["candidates"].duplicate()
    var sorted_full_candidates: Array = full_candidates.duplicate()
    sorted_full_candidates.sort()
    _assert_equal(full_candidates, sorted_full_candidates, "葫芦心得候选按功法 ID 排序后进入随机抽取")
    var unique_full_candidates: Dictionary = {}
    var candidate_pools: Dictionary = {}
    for candidate_id in full_candidates:
        unique_full_candidates[str(candidate_id)] = true
        _assert_true(not full_sequence_before.has(str(candidate_id)), "葫芦当前序列功法不再进入心得候选")
        var candidate_definition: Dictionary = catalog.get_by_id("technique", str(candidate_id))
        candidate_pools[str(candidate_definition.get("pool", ""))] = true
        _assert_equal(
            catalog.definition("techniques")["integration_statuses"].get(str(candidate_id)),
            "formal_complete",
            "葫芦心得只汇总 formal_complete 功法")
    _assert_equal(unique_full_candidates.size(), full_candidates.size(), "葫芦跨池候选按功法 ID 去重")
    _assert_true(candidate_pools.has("pair") and candidate_pools.has("three"), "葫芦心得同时汇总对子池与三条池")
    _assert_equal(full_applied_first["candidates"], full_applied_second["candidates"], "相同种子使用同一有序葫芦候选")
    _assert_equal(
        full_applied_first["acquired_technique_id"],
        full_applied_second["acquired_technique_id"],
        "葫芦跨池候选使用现有确定性随机源")

func _test_run_consumable_insight_exhausted_pool() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77124}).success, "候选耗尽测试本局建立")
    session.growth.consumable_ids.append("high_card_insight")
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "候选池内容目录有效")
    var techniques: Dictionary = catalog.definition("techniques")
    var high_ids: Array[String] = []
    for value in techniques["techniques"]:
        var technique_id := str(value["id"])
        if str(value.get("pool", "")) == "high" \
                and str(techniques["integration_statuses"].get(technique_id, "")) == "formal_complete":
            high_ids.append(technique_id)
    _assert_equal(high_ids.size(), 2, "高牌正式池当前共两门")
    session.growth.hand_technique_progression["high_card"] = {
        "slot_count": 1,
        "sequence": high_ids,
    }
    var use := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(use.success, "功法池无候选时心得仍成功")
    var applied: Array = use.payload_value("applied")
    _assert_equal(str(applied[0]["acquired_technique_id"]), "", "候选耗尽时不跨池抽取")
    _assert_equal(
        int(session.growth.hand_progression("high_card")["slot_count"]),
        2,
        "候选耗尽时槽位仍 +1")
    _assert_equal(session.growth.consumable_ids, [], "候选耗尽时消耗品仍释放")

    var five_session: RunSession = RunSessionScript.new()
    _assert_true(five_session.execute({"type": "setup_run", "seed": 77126}).success, "五条候选耗尽本局建立")
    five_session.growth.hand_technique_progression["five_kind"] = {
        "slot_count": 1,
        "sequence": ["seize_qi_return_nest"],
    }
    if not five_session.growth.learned_technique_ids.has("seize_qi_return_nest"):
        five_session.growth.learned_technique_ids.append("seize_qi_return_nest")
    five_session.growth.consumable_ids.append("five_kind_insight")
    var four_slots_before: int = int(five_session.growth.hand_progression("four_kind").slot_count)
    var five_use := five_session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(five_use.success, "五条心得无合格功法时仍使用成功")
    _assert_equal(
        str(five_use.payload_value("applied")[0]["acquired_technique_id"]),
        "",
        "五条炸弹池耗尽时不重复获得当前序列功法")
    _assert_equal(five_session.growth.hand_progression("five_kind").slot_count, 2, "五条心得仍增加五条槽位")
    _assert_equal(
        five_session.growth.hand_progression("four_kind").slot_count,
        four_slots_before,
        "五条心得不改变四条槽位")

func _test_run_consumable_zengyuan_pill() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77201}).success, "增元丹测试本局建立")
    session.growth.consumable_ids.append("zengyuan_pill")
    var query := session.execute({"type": "query_consumable_use", "slot_index": 0})
    _assert_true(query.success, "增元丹使用查询成功")
    _assert_equal(
        query.payload_value("targeting"),
        {"zone": "run_deck", "selection": "player_selected"},
        "增元丹目标协议为 run_deck/player_selected")
    _assert_equal(query.payload_value("selection"), "player_selected", "增元丹查询返回 selection")
    _assert_equal(query.payload_value("minimum"), 1, "增元丹最少选择一张")
    _assert_equal(query.payload_value("maximum"), 2, "增元丹至多选择两张")
    var targets: Array = query.payload_value("eligible_targets")
    _assert_equal(targets.size(), 52, "增元丹可选目标为完整 RunDeck")
    var first_target: Dictionary = targets[0]
    for field in ["instance_id", "card_id", "rank", "suit", "origin", "enhancement", "imprint", "others", "display_name"]:
        _assert_true(first_target.has(field), "增元丹可选目标包含字段 %s" % field)
    _assert_true(str(first_target["instance_id"]) != "", "可选目标携带稳定实例 ID")
    _assert_true(str(first_target["card_id"]) != "", "可选目标携带牌型 ID")
    _assert_equal(str(first_target["rank"]), "2", "可选目标携带点数")
    _assert_true(str(first_target["suit"]) != "", "可选目标携带属性")
    _assert_true(str(first_target["display_name"]) != "", "可选目标携带显示名称")

    var ids: Array = [first_target["instance_id"], targets[1]["instance_id"]]
    var use := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": ids})
    _assert_true(use.success, "增元丹选择两张真气成功")
    _assert_equal(
        str(session.growth.run_deck.card_data(str(ids[0]))["reshapes"]["enhancement"]),
        "qi_boost",
        "增元写入 RunDeck 第一张")
    _assert_equal(
        str(session.growth.run_deck.card_data(str(ids[1]))["reshapes"]["enhancement"]),
        "qi_boost",
        "增元写入 RunDeck 第二张")
    _assert_equal(session.growth.consumable_ids, [], "增元丹使用后释放槽位")

    var progress = session.progress_snapshot()
    var battle: BattleSession = BattleSessionScript.new(CombatEngineScript.new())
    _assert_true(battle.setup_battle({"content_seed": 77201}, progress), "携带增元的本局牌组进入战斗")
    battle.execute({"type": "start_turn"})
    var seen := false
    for card in battle.engine.player.all_zone_cards():
        if card.id != str(ids[0]):
            continue
        seen = true
        _assert_equal(card.reshape_enhancement, "qi_boost", "后续战斗装配能看到强化")
    _assert_true(seen, "被强化真气实例在战斗中出现")

func _test_run_consumable_origin_and_save() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77301}).success, "通用本源消耗品测试本局建立")
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "通用本源消耗品测试载入目录")
    session.growth.consumable_ids.append("high_card_insight")
    var service = ConsumableUseServiceScript.new(
        null, catalog, ContentValidatorScript.HAND_IDS, ContentValidatorScript.POOL_IDS)
    var definition := {
        "id": "high_card_insight",
        "targeting": {
            "zone": "run_deck", "selection": "player_selected",
            "minimum": 1, "maximum": 1},
        "effects": [{
            "op": "apply_origin",
            "origin": "attribute_change",
            "payload": {"attribute": "mountain"},
        }],
    }
    var used: Dictionary = service.use(
        session.growth, 0, ["wind_7"], 77301, definition)
    _assert_true(used.get("success", false), "统一消耗品 Handler 可施加转属本源")
    var changed: Dictionary = session.growth.run_deck.card_data("wind_7")
    _assert_equal(changed["definition_id"], "mountain_7", "消耗品转属更新基础定义")
    _assert_equal(changed["reshapes"]["origin"]["payload"], {"attribute": "mountain"}, "消耗品保存本源参数")
    var save = RunSaveDataScript.new().capture(session)
    var restored_dict: Dictionary = save.restore_session(catalog)
    _assert_true(restored_dict.get("success", false), "本源消耗品结果可以存档恢复")
    var restored: RunSession = restored_dict["run_session"]
    _assert_equal(
        restored.growth.run_deck.card_data("wind_7")["reshapes"]["origin"],
        changed["reshapes"]["origin"],
        "读档保留本源身份和锁定状态")

func _test_run_consumable_invalid_targets() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77401}).success, "非法目标测试本局建立")
    session.growth.consumable_ids.append("zengyuan_pill")
    var deck_ids: Array = session.growth.run_deck.cards_snapshot()
    var first_id := str(deck_ids[0]["instance_id"])
    var second_id := str(deck_ids[1]["instance_id"])

    var not_in_deck := session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": ["ghost_card"]})
    _assert_true(not not_in_deck.success, "不属于 RunDeck 的目标明确失败")
    var duplicate := session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [first_id, first_id]})
    _assert_true(not duplicate.success, "重复实例 ID 明确失败")
    var too_few := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(not too_few.success, "少于 minimum 明确失败")
    var too_many := session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [first_id, second_id, str(deck_ids[2]["instance_id"])]})
    _assert_true(not too_many.success, "多于 maximum 明确失败")
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "随机目标拒绝手选测试内容目录有效")
    var service = ConsumableUseServiceScript.new(
        null, catalog, ContentValidatorScript.HAND_IDS, ContentValidatorScript.POOL_IDS)
    var random_definition: Dictionary = catalog.get_by_id("consumable", "zengyuan_pill")
    random_definition["targeting"]["selection"] = "deterministic_random"
    var manual_random := service.use(
        session.growth, 0, [first_id], 77401, random_definition)
    _assert_true(
        not manual_random.get("success", false),
        "deterministic_random 传入手动目标明确失败")
    _assert_true(
        str(manual_random.get("reason", "")).contains("不允许手动指定目标"),
        "deterministic_random 手动目标失败原因明确")
    _assert_equal(int(session.growth.consumable_use_sequence), 0, "非法目标失败不递增使用序号")
    _assert_equal(session.growth.consumable_ids, ["zengyuan_pill"], "非法目标失败不删除消耗品")
    for card in session.growth.run_deck.cards_snapshot():
        _assert_equal(str(card["reshapes"]["enhancement"]), "", "非法目标失败不改动牌组")

func _test_run_consumable_transaction_rollback() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77501}).success, "回滚测试本局建立")
    session.growth.experience = 50
    session.growth.consumable_ids.append("high_card_insight")
    session.growth.consumable_use_sequence = 3
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "回滚测试内容目录有效")

    var registry = ConsumableEffectHandlerRegistryScript.new()
    _assert_true(
        registry.register_handler(ConsumableProbeHandler.new(["test_gain"])),
        "成功探针注册")
    _assert_true(
        registry.register_handler(ConsumableProbeHandler.new(["test_fail"], true)),
        "失败探针注册")
    var service = ConsumableUseServiceScript.new(
        registry, catalog, ContentValidatorScript.HAND_IDS, ContentValidatorScript.POOL_IDS)

    var crafted_success := {
        "id": "high_card_insight",
        "targeting": {"zone": "none", "selection": "deterministic_random", "minimum": 0, "maximum": 0},
        "effects": [{"op": "test_gain", "amount": 5}],
    }
    var ok := service.use(session.growth, 0, [], 77501, crafted_success)
    _assert_true(ok.get("success", false), "探针效果成功路径通过事务")
    _assert_equal(session.growth.experience, 55, "探针效果按工作副本应用")
    _assert_equal(session.growth.consumable_ids, [], "成功后删除消耗品")
    _assert_equal(int(session.growth.consumable_use_sequence), 4, "成功后递增序号")

    session.growth.experience = 50
    session.growth.consumable_ids.append("high_card_insight")
    var state_before = session.growth.capture_mutation_state()
    var crafted_failing := {
        "id": "high_card_insight",
        "targeting": {"zone": "none", "selection": "deterministic_random", "minimum": 0, "maximum": 0},
        "effects": [
            {"op": "test_gain", "amount": 5},
            {"op": "test_fail", "amount": 7},
        ],
    }
    var failed := service.use(session.growth, 0, [], 77501, crafted_failing)
    _assert_true(not failed.get("success", false), "第一个效果成功、第二个效果失败时事务失败")
    _assert_equal(
        session.growth.capture_mutation_state(),
        state_before,
        "失败后历练、生命、库存、功法、牌组与随机序号全部不变")

func _test_run_consumable_failed_use_keeps_randomness() -> void:
    var session_a: RunSession = RunSessionScript.new()
    _assert_true(session_a.execute({"type": "setup_run", "seed": 77601}).success, "随机保持甲本局建立")
    session_a.growth.consumable_ids.append("zengyuan_pill")
    var target := str(session_a.growth.run_deck.cards_snapshot()[0]["instance_id"])
    var use_a := session_a.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [target]})
    _assert_true(use_a.success, "甲直接成功使用增元丹")
    var result_a := str(session_a.growth.run_deck.card_data(target)["reshapes"]["enhancement"])

    var session_b: RunSession = RunSessionScript.new()
    _assert_true(session_b.execute({"type": "setup_run", "seed": 77601}).success, "随机保持乙本局建立")
    session_b.growth.consumable_ids.append("zengyuan_pill")
    var failed := session_b.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": ["not_in_deck"]})
    _assert_true(not failed.success, "乙先发生一次失败操作")
    _assert_equal(int(session_b.growth.consumable_use_sequence), 0, "失败不递增序号")
    var use_b := session_b.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [target]})
    _assert_true(use_b.success, "乙随后合法使用成功")
    var result_b := str(session_b.growth.run_deck.card_data(target)["reshapes"]["enhancement"])
    _assert_equal(result_b, result_a, "失败后合法操作结果与没有发生失败操作时一致")

func _test_run_consumable_slot_release_order() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77701}).success, "槽位顺序测试本局建立")
    session.growth.consumable_ids.assign(["zengyuan_pill", "pair_insight", "high_card_insight"])
    var first_id := str(session.growth.run_deck.cards_snapshot()[0]["instance_id"])
    var use_zero := session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [first_id]})
    _assert_true(use_zero.success, "使用 0 号槽成功")
    _assert_equal(
        session.growth.consumable_ids,
        ["pair_insight", "high_card_insight"],
        "0 号槽释放后其余槽位顺序保持")
    var use_one := session.execute({
        "type": "use_consumable", "slot_index": 1, "selected_instance_ids": []})
    _assert_true(use_one.success, "使用释放后的新 1 号槽成功")
    _assert_equal(
        session.growth.consumable_ids,
        ["pair_insight"],
        "心得释放后剩余槽位顺序保持")

func _test_run_consumable_phase_gate() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77801}).success, "阶段门禁测试本局建立")
    session.growth.consumable_ids.append("high_card_insight")
    var available: Array = session.snapshot().available_node_ids
    _assert_true(
        session.execute({"type": "begin_node", "node_id": str(available[0])}).success,
        "进入节点")
    var in_progress := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(not in_progress.success, "节点执行中不能使用消耗品")
    _assert_true(session.execute({"type": "complete_node"}).success, "完成节点进入奖励")
    var reward_phase := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(not reward_phase.success, "奖励阶段不能使用消耗品")
    _assert_true(session.execute({"type": "claim_reward", "bundle_id": ""}).success, "领取奖励")
    var ready := session.execute({
        "type": "use_consumable", "slot_index": 0, "selected_instance_ids": []})
    _assert_true(ready.success, "地图待选阶段可以使用消耗品")

func _test_run_consumable_save_round_trip() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(session.execute({"type": "setup_run", "seed": 77901}).success, "存档往返测试本局建立")
    session.growth.consumable_ids.assign(["zengyuan_pill", "high_card_insight"])
    var deck_snapshot: Array = session.growth.run_deck.cards_snapshot()
    var reshaped_id := str(deck_snapshot[3]["instance_id"])
    var applied = session.growth.run_deck.apply_card_reshape(
        reshaped_id, "enhancement", "momentum")
    _assert_true(applied.get("success", false), "测试牌组先完成一次重塑")
    var boosted_id := str(deck_snapshot[0]["instance_id"])
    var use := session.execute({
        "type": "use_consumable", "slot_index": 0,
        "selected_instance_ids": [boosted_id]})
    _assert_true(use.success, "存档前完成一次增元丹使用")
    _assert_equal(int(session.growth.consumable_use_sequence), 1, "存档前使用序号为 1")

    var save = RunSaveDataScript.new().capture(session)
    var restored_dict: Dictionary = save.restore_session()
    _assert_true(restored_dict.get("success", false), "存档恢复成功")
    var restored: RunSession = restored_dict["run_session"]
    _assert_equal(restored.growth.consumable_ids, ["high_card_insight"], "读档保留消耗品库存")
    _assert_equal(int(restored.growth.consumable_use_sequence), 1, "读档保留 consumable_use_sequence")
    _assert_equal(
        str(restored.growth.run_deck.card_data(reshaped_id)["reshapes"]["enhancement"]),
        "momentum",
        "读档保留已修改的 RunDeck 强化")
    _assert_equal(
        str(restored.growth.run_deck.card_data(boosted_id)["reshapes"]["enhancement"]),
        "qi_boost",
        "读档保留增元丹强化")
    _assert_equal(
        restored.growth.run_deck.card_count(),
        session.growth.run_deck.card_count(),
        "读档保留 RunDeck 完整牌数")

func _test_consumable_no_central_op_branches() -> void:
    var battle_source: String = FileAccess.get_file_as_string(
        "res://core/battle_consumable_service.gd")
    var validator_source: String = FileAccess.get_file_as_string(
        "res://core/content_validator.gd")
    for op in ["gain_insight", "apply_enhancement", "apply_origin"]:
        _assert_true(
            not battle_source.contains(op),
            "战斗兼容适配器不再按 op 写中央分支：%s" % op)
        _assert_true(
            not validator_source.contains(op),
            "内容校验器不再按 op 写中央分支：%s" % op)

func _test_battle_session_commands_snapshots_and_events() -> void:
    var configuration := {
        "content_seed": 2308,
        "battle": {
            "scenario_path": "res://data/scripted_battle.json",
            "use_enemy_ai": true,
        },
    }
    var first: BattleSession = BattleSessionScript.new()
    var second: BattleSession = BattleSessionScript.new()
    _assert_true(first.setup_battle(configuration), "战斗会话可以按配置建立战斗")
    _assert_true(second.setup_battle(configuration), "第二个战斗会话可以按相同配置建立战斗")
    var setup_events: Array = first.drain_events()
    _assert_true(not setup_events.is_empty(), "战斗建立产生可消费事件")
    _assert_equal(first.drain_events().size(), 0, "战斗事件只消费一次")

    _assert_true(first.execute({"type": "start_turn"}).success, "开始回合命令成功")
    _assert_true(second.execute({"type": "start_turn"}).success, "第二会话开始回合命令成功")
    var first_snapshot = first.snapshot()
    var second_snapshot = second.snapshot()
    _assert_equal(first_snapshot.player.hand_count, 8, "战斗快照包含玩家手牌数量")
    _assert_equal(first_snapshot.enemy.hand_count, 8, "战斗快照包含敌方手牌数量")
    _assert_true(first_snapshot.action_states["player"]["can_act"], "战斗快照公开通用玩家行动资格")
    _assert_true(first_snapshot.action_states["enemy"]["can_act"], "战斗快照公开通用敌方行动资格")
    _assert_equal(first_snapshot.player.equipped_inner_skills[0]["id"], "extra_qi_to_defense", "快照提供内功展示定义")
    _assert_equal(first_snapshot.player.consumables[1]["targeting_limits"]["maximum"], 2, "快照提供消耗品展示与目标上限")
    _assert_true(not first_snapshot.battle_log.is_empty(), "战斗快照提供独立战斗日志通道")
    _assert_equal(first_snapshot.battle_log[0]["channel"], "battle", "战斗日志具有统一通道字段")
    _assert_equal(first_snapshot.system_log[0]["channel"], "system", "系统日志具有统一通道字段")
    _assert_equal(
        first_snapshot.player.hand,
        second_snapshot.player.hand,
        "相同配置与种子产生相同只读手牌快照")
    var changed_copy: Dictionary = first_snapshot.to_dict()
    changed_copy["player"]["life"] = 0
    _assert_equal(first.snapshot().player.life, 100, "修改快照副本不会修改战斗核心")
    var battle_log_copy: Array = first_snapshot.battle_log
    battle_log_copy[0]["message"] = "外部篡改"
    _assert_true(first.snapshot().battle_log[0]["message"] != "外部篡改", "日志快照同样保持只读副本边界")

    var preview_snapshot: Dictionary = first.preview([
        first_snapshot.player.hand[0]["id"]])
    _assert_true(preview_snapshot.get("cards", [])[0] is Dictionary, "会话预览只返回卡牌快照而非领域对象")
    _assert_true(preview_snapshot.get("hand", {}).has("contributing_card_ids"), "会话预览用卡牌 ID 表达参与牌")

    var move_result := first.execute({"type": "move_technique_slot", "direction": -1})
    _assert_true(move_result.success, "调整功法位命令通过战斗会话执行")
    _assert_equal(first.snapshot().player.technique_slot_index, 0, "功法位变化进入新快照")
    var hand: Array = first.snapshot().player.hand
    var play_result := first.execute({"type": "play_cards", "card_ids": [hand[0]["id"]]})
    _assert_true(play_result.success, "出牌命令通过战斗会话执行")
    var action_events: Array = first.drain_events()
    _assert_true(not action_events.is_empty(), "出牌结算产生战斗事件流")
    _assert_true(action_events[0].serial >= 0, "战斗事件具有稳定递增序号")

    var rejected := first.execute({"type": "not_a_command"})
    _assert_equal(rejected.success, false, "未知战斗命令被安全拒绝")
    var rejected_events: Array = first.drain_events()
    _assert_equal(rejected_events[-1].type, "command_rejected", "命令失败产生结构化拒绝事件")
    var system_log: Array = first.snapshot().system_log
    _assert_equal(system_log[-1]["severity"], "warning", "命令拒绝进入系统日志 warning 通道")
    _assert_equal(system_log[-1]["context"]["command"], "not_a_command", "系统日志保留被拒绝命令上下文")

func _test_snapshot_boundaries_are_typed() -> void:
    ## 锁住 core → 表现层的类型化读取边界。
    ##
    ## 这些快照类曾经只包一个裸 Dictionary 并暴露 value(key, default)，
    ## 键名写错会静默返回默认值。这里断言字段访问可用、无类型旁路残留，
    ## 且 inner_skill_limit 由领域常量供给而不是表现层各自假设一个数字。
    var session: BattleSession = BattleSessionScript.new(CombatEngineScript.new())
    _assert_true(session.setup_battle({"seed": 8801}), "战斗会话建立用于快照边界检查")
    session.execute({"type": "start_turn"})
    var battle := session.snapshot()

    _assert_true(battle is BattleSnapshot, "战斗快照是类型化对象")
    _assert_true(battle.player is BattleSideSnapshot, "参战方快照是类型化对象")
    _assert_true(
        not battle.has_method("value") and not battle.has_method("section"),
        "战斗快照不再保留无类型读取旁路")
    _assert_true(
        not battle.player.has_method("value"),
        "参战方快照不再保留无类型读取旁路")
    var battle_events: Array = session.drain_events()
    _assert_true(not battle_events.is_empty(), "战斗会话产出类型化事件")
    _assert_true(
        battle_events[0] is BattleEvent
        and not battle_events[0].has_method("value"),
        "战斗事件按字段读取且不保留无类型旁路")
    _assert_equal(
        battle.player.inner_skill_limit,
        BattleSideScript.INNER_SKILL_LIMIT,
        "内功容量由领域常量供给，表现层不各自假设")
    _assert_equal(battle.SCHEMA_VERSION, 1, "战斗快照使用稳定版本号")
    _assert_equal(battle.to_dict()["schema_version"], 1, "战斗快照序列化保留版本号")
    _assert_equal(
        battle.log_channel("battle"),
        battle.battle_log,
        "日志通道入口与字段访问返回同一内容")
    _assert_true(
        battle.action_state("player").has("can_act"),
        "行动状态入口按方返回结构")

    var composition_root = GameCompositionRootScript.new()
    _assert_true(composition_root.initialize(), "组合根初始化用于本局快照检查")
    var run_session = composition_root.create_run_session()
    _assert_true(run_session != null, "内容通过校验时组合根产出本局会话")
    run_session.execute({"type": "setup_run", "seed": 8802})
    var run := run_session.snapshot()

    _assert_true(run is RunSnapshot, "本局快照是类型化对象")
    _assert_true(
        not run.has_method("value") and not run.has_method("section"),
        "本局快照不再保留无类型读取旁路")
    _assert_equal(run.seed, 8802, "本局快照按字段公开种子")
    _assert_equal(run.SCHEMA_VERSION, 1, "本局快照使用稳定版本号")
    _assert_true(not run.available_node_ids.is_empty(), "本局快照按字段公开可选节点")

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
    _assert_equal(state.purchase_consumable("zengyuan_pill", 3)["success"], false, "节点未完成时不能购买修习内容")
    var completion := state.complete_current_node()
    _assert_true(completion["success"], "节点可以完成并返回地图")
    _assert_equal(completion["reward"], 3, "普通战斗节点奖励三点历练")
    _assert_equal(state.experience, 3, "节点奖励进入本局历练")
    _assert_true(state.can_open_practice(), "节点完成到选择下一节点前重新开放修习")
    _assert_true(not state.available_node_ids().is_empty(), "返回地图后只开放相连下一节点")
    var purchase := state.purchase_consumable("zengyuan_pill", 3)
    _assert_true(purchase["success"], "待选节点期间可以消耗历练修习")
    _assert_equal(state.experience, 0, "修习购买扣除对应历练")
    _assert_equal(state.consumable_ids, ["zengyuan_pill"], "修习所得进入共享消耗品栏")
    _assert_equal(state.purchase_consumable("zengyuan_pill", 3)["success"], false, "同一地图待选阶段固定选项不能重复购买")

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
        growth.purchase_consumable("zengyuan_pill", 3, false)["success"],
        false,
        "成长库存不绕过地图导航的修习时机限制")
    _assert_true(
        growth.purchase_consumable("zengyuan_pill", 3, true)["success"],
        "成长库存独立处理历练和消耗品购买")
    _assert_equal(growth.experience, 0, "成长库存独立扣除历练")
    growth.learned_inner_skill_ids.assign(["extra_qi_to_defense"])
    growth.equipped_inner_skill_ids.assign(["extra_qi_to_defense"])
    growth.technique_slot_index = 1
    var progress = growth.to_progress_snapshot()
    var progress_copy: Dictionary = progress.to_dict()
    progress_copy["consumable_ids"].clear()
    _assert_equal(progress.consumable_ids, ["zengyuan_pill"], "成长快照对外提供深复制")
    var manual_deck = RunDeckScript.new()
    manual_deck.reset_standard("manual")
    var manual_cards := manual_deck.create_battle_cards()
    for card in manual_cards:
        if card.id == "wind_8":
            card.set_enhancement("qi_boost")
    manual_deck.sync_from_battle_cards(manual_cards)
    var manual_progress = RunProgressSnapshotScript.from_dict({
        "consumable_ids": ["zengyuan_pill"],
        "hand_technique_progression": {
            "high_card": {"slot_count": 2, "sequence": []},
        },
        "learned_technique_ids": ["long_wind_full_sleeve"],
        "run_deck": manual_deck.to_snapshot(),
    })
    growth.life = 41
    growth.apply_progress_snapshot(manual_progress)
    _assert_equal(growth.consumable_ids, ["zengyuan_pill"], "成长库存可以从进度快照导入消耗品")
    _assert_equal(
        growth.hand_progression("high_card")["slot_count"],
        2,
        "成长库存可以从进度快照导入牌型功法槽位")
    _assert_equal(growth.life, 41, "局部战斗进度不清空未携带的当前生命")
    _assert_equal(growth.run_deck.card_data("wind_8")["reshapes"]["enhancement"], "qi_boost", "成长库存可以从进度快照导入完整本局牌组")
    _assert_equal(
        growth.equipped_inner_skill_ids,
        ["extra_qi_to_defense"],
        "局部战斗进度不清空未携带的已装备内功")
    _assert_equal(
        growth.technique_slot_index,
        1,
        "局部战斗进度不重置未携带的功法结算位")
    _assert_true(
        not manual_progress.to_dict().has("equipped_inner_skill_ids"),
        "局部快照序列化保留字段缺失语义")

func _test_run_session_commands_snapshots_events_and_logs() -> void:
    var session: RunSession = RunSessionScript.new()
    var setup := session.execute({"type": "setup_run", "seed": 2308})
    _assert_true(setup.success, "本局会话接受结构化建局命令")
    var initial = session.snapshot()
    _assert_equal(initial.act, 1, "本局快照提供当前层数")
    _assert_equal(initial.phase, "awaiting_node", "本局快照提供当前流程阶段")
    _assert_true(initial.can_open_practice, "本局快照提供修习可用状态")
    _assert_equal(initial.practice.get("offers", []).size(), 9, "修习快照提供八心得与增元丹")
    var snapshot_insight_ids: Array = []
    for offer in initial.practice.get("offers", []):
        if str(offer.get("kind", "")) == "insight":
            snapshot_insight_ids.append(str(offer.get("id", "")))
    snapshot_insight_ids.sort()
    _assert_equal(
        snapshot_insight_ids,
        [
            "five_kind_insight", "four_kind_insight", "full_house_insight",
            "high_card_insight", "pair_insight", "straight_insight",
            "three_kind_insight", "two_pair_insight",
        ],
        "本局修习快照公开全部八种心得")
    var copied_graph: Dictionary = initial.graph
    copied_graph["act"] = 99
    _assert_equal(session.snapshot().graph.get("act"), 1, "修改地图快照不会污染本局核心")

    var first_node_id := str(initial.available_node_ids[0])
    var begin := session.execute({"type": "begin_node", "node_id": first_node_id})
    _assert_true(begin.success, "本局会话统一校验并进入可达节点")
    _assert_true(
        begin.payload_value("dispatch", {}).get("success", false),
        "进入节点命令同时返回数据驱动调度结果")
    _assert_equal(session.snapshot().phase, "node_in_progress", "节点开始后快照进入未完成状态")
    var rejected := session.execute({"type": "open_practice"})
    _assert_equal(rejected.success, false, "节点未完成时本局会话拒绝打开修习")

    var completion := session.execute({"type": "complete_node"})
    _assert_true(completion.success, "本局会话完成当前节点")
    _assert_equal(session.snapshot().phase, "awaiting_reward", "节点完成后进入待领取奖励阶段")
    _assert_equal(session.snapshot().experience, 0, "领取前奖励不会提前写入历练")
    var reward_snapshot: Dictionary = session.snapshot().reward
    _assert_true(reward_snapshot.get("available", false), "本局快照公开待领取奖励包")
    _assert_equal(reward_snapshot.get("experience_total"), 3, "奖励快照公开普通战斗三点历练")
    _assert_true(not session.execute({"type": "open_practice"}).success, "奖励领取前修习保持锁定")
    var bundle_id := str(reward_snapshot.get("bundle", {}).get("id", ""))
    var claim := session.execute({"type": "claim_reward", "bundle_id": bundle_id})
    _assert_true(claim.success, "匹配奖励包ID后可以领取节点奖励")
    _assert_equal(session.snapshot().experience, 3, "领取后节点奖励写入本局历练")
    _assert_equal(session.snapshot().phase, "awaiting_node", "领取后才返回地图待选状态")
    _assert_true(not session.execute({"type": "claim_reward", "bundle_id": bundle_id}).success, "同一奖励包不能重复领取")
    _assert_true(session.execute({"type": "open_practice"}).success, "领取奖励返回待选状态后可以打开修习")
    var purchase := session.execute({
        "type": "purchase_consumable",
        "consumable_id": "zengyuan_pill",
        "price": 0,
    })
    _assert_true(purchase.success, "修习购买通过本局命令完成")
    _assert_equal(purchase.payload_value("price"), 3, "修习价格由核心内容定义决定而不信任 UI 参数")
    _assert_equal(session.snapshot().experience, 0, "修习购买后的历练进入只读快照")
    _assert_equal(session.snapshot().growth.get("consumable_ids"), ["zengyuan_pill"], "本局成长快照包含共享消耗品")

    var run_log: Array = session.snapshot().run_log
    var system_log: Array = session.snapshot().system_log
    _assert_true(run_log.size() >= 5, "建局、节点、修习和购买写入统一本局日志通道")
    _assert_true(not system_log.is_empty(), "被拒绝的本局命令写入统一系统日志通道")
    var events: Array = session.drain_events()
    _assert_true(events.size() >= 6, "本局会话公开一次性结构化事件流")
    _assert_equal(events[0].type, "run_setup", "本局事件保留稳定的建局事件类型")
    _assert_true(
        events[0] is RunEvent and not events[0].has_method("value"),
        "本局事件使用稳定信封字段且不保留无类型旁路")
    _assert_true(session.drain_events().is_empty(), "本局事件被消费后不会重复播放")

    var battle_session: BattleSession = BattleSessionScript.new(CombatEngineScript.new())
    battle_session.use_game_log(session.game_log)
    _assert_true(battle_session.setup_battle({"content_seed": 2308}), "战斗会话可以复用本局日志实例")
    _assert_true(not session.game_log.entries("run").is_empty(), "建立战斗不会清除既有本局日志")
    _assert_true(not session.game_log.entries("system").is_empty(), "本局与战斗系统诊断进入同一日志序列")

    var boss_state = RunStateScript.new()
    boss_state.setup(8128)
    boss_state.current_node_id = boss_state.graph["boss_id"]
    boss_state.phase = "node_in_progress"
    var boss_session: RunSession = RunSessionScript.new(boss_state)
    _assert_true(boss_session.execute({"type": "complete_node"}).success, "Boss 节点完成也经过本局会话")
    _assert_equal(boss_session.snapshot().phase, "awaiting_reward", "Boss胜利先进入奖励阶段")
    _assert_equal(boss_session.snapshot().reward["experience_total"], 5, "Boss奖励包为五点历练")
    var boss_bundle_id := str(boss_session.snapshot().reward["bundle"]["id"])
    _assert_true(boss_session.execute({"type": "claim_reward", "bundle_id": boss_bundle_id}).success, "领取Boss奖励后推进流程")
    _assert_equal(boss_session.snapshot().phase, "boss_chest", "领取后本局快照公开 Boss 宝箱阶段")
    _assert_equal(boss_session.snapshot().experience, 6, "Boss基础历练后按当前历练计算功行1")
    _assert_true(boss_session.execute({"type": "complete_boss_chest"}).success, "Boss 宝箱流程通过本局命令完成")
    _assert_equal(boss_session.snapshot().act, 2, "Boss 宝箱命令推进到下一层")
    _assert_equal(boss_session.snapshot().run_log.size(), 3, "Boss奖励建立、领取与宝箱流程均写入本局日志")

func _test_experience_interest_node_settlement() -> void:
    var combat := _interest_test_session("combat", 0)
    var combat_bundle := _claim_interest_test_node(combat)
    _assert_equal(combat.growth.experience, 3, "当前历练0的普通战斗最终为3，功行生息为0")
    _assert_equal(combat_bundle.payload_value("experience_interest", {}).get("amount"), 0, "普通战斗功行生息0")

    var rest := _interest_test_session("rest", 7)
    var rest_bundle := _claim_interest_test_node(rest)
    _assert_equal(rest.growth.experience, 8, "当前历练7的休息节点功行生息1")
    _assert_equal(rest_bundle.payload_value("experience_interest", {}).get("amount"), 1, "休息节点功行生息1")

    var event := _interest_test_session("event", 10)
    var event_bundle := _claim_interest_test_node(event)
    _assert_equal(event.growth.experience, 12, "当前历练10的事件节点功行生息2")
    _assert_equal(event_bundle.payload_value("experience_interest", {}).get("amount"), 2, "事件节点功行生息2")

    var treasure := _interest_test_session("treasure", 7)
    var treasure_bundle := _claim_interest_test_node(treasure)
    _assert_equal(treasure.growth.experience, 8, "宝箱节点也触发一次功行生息")
    _assert_equal(treasure_bundle.payload_value("experience_interest", {}).get("amount"), 1, "宝箱节点功行生息1")

    var boss := _interest_test_session("boss", 25)
    var boss_bundle := _claim_interest_test_node(boss)
    _assert_equal(boss.growth.experience, 35, "Boss基础奖励后当前历练30，功行生息5")
    _assert_equal(boss_bundle.payload_value("experience_interest", {}).get("amount"), 5, "Boss功行生息达到单次上限5")

    var before_duplicate: int = combat.growth.experience
    _assert_true(
        not combat.execute({"type": "claim_reward", "bundle_id": ""}).success,
        "同一节点重复领取被拒绝")
    _assert_equal(combat.growth.experience, before_duplicate, "重复领取不重复增加历练或功行")

    var hidden_chest := RunSessionScript.new()
    _assert_true(
        hidden_chest.execute({"type": "setup_run", "seed": 20606}).success,
        "Boss隐藏宝箱功行测试可以建立本局")
    hidden_chest.growth.experience = 10
    hidden_chest.navigation.phase = "boss_chest"
    var chest_result := hidden_chest.execute({"type": "complete_boss_chest"})
    _assert_true(chest_result.success, "Boss隐藏宝箱完成并触发功行")
    _assert_equal(hidden_chest.growth.experience, 12, "Boss隐藏宝箱当前历练10时功行生息2")
    _assert_equal(chest_result.payload_value("experience_interest", {}).get("amount"), 2, "Boss隐藏宝箱功行生息2")
    _assert_true(
        not hidden_chest.execute({"type": "complete_boss_chest"}).success,
        "同一Boss隐藏宝箱重复提交被拒绝")
    _assert_equal(hidden_chest.growth.experience, 12, "重复提交Boss隐藏宝箱不重复触发功行")

    var state := RunStateScript.new()
    state.setup(20607)
    state.growth.experience = 7
    state.graph = {"nodes": [{"id": "compat-rest", "type": "rest"}], "edges": []}
    state.current_node_id = "compat-rest"
    state.phase = "node_in_progress"
    var compatibility_result := state.complete_current_node()
    _assert_true(compatibility_result.get("success", false), "RunState兼容门面复用节点功行规则")
    _assert_equal(state.experience, 8, "RunState兼容门面对休息节点计算功行1")

    var save_data = RunSaveDataScript.new().capture(rest)
    var restored: Dictionary = save_data.restore_session()
    _assert_true(restored.get("success", false), "包含功行生息后的节点状态可以存档读档")
    _assert_equal(restored["run_session"].growth.experience, 8, "存档读档保留功行生息后的历练")

func _interest_test_session(node_type: String, starting_experience: int) -> RunSession:
    var session: RunSession = RunSessionScript.new()
    session.execute({"type": "setup_run", "seed": 20600 + starting_experience})
    session.navigation.graph = {
        "nodes": [{"id": "interest-node", "type": node_type}],
        "edges": [],
        "boss_variant": 0,
    }
    session.navigation.current_node_id = "interest-node"
    session.navigation.phase = "node_in_progress"
    session.growth.experience = starting_experience
    return session

func _claim_interest_test_node(session: RunSession) -> CommandResult:
    _assert_true(
        session.execute({"type": "complete_node"}).success,
        "功行测试节点建立奖励包")
    var bundle_id := str(session.snapshot().reward.get("bundle", {}).get("id", ""))
    var result := session.execute({"type": "claim_reward", "bundle_id": bundle_id})
    _assert_true(result.success, "功行测试节点奖励领取成功")
    return result

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

func _test_layered_life_progression_and_battle_persistence() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(
        session.execute({"type": "setup_run", "seed": 70401}).success,
        "生命成长测试可以建立本局")
    _assert_equal(session.growth.life, 100, "本局开局玩家当前生命为100")
    _assert_equal(session.growth.max_life, 100, "本局开局玩家生命上限为100")
    _assert_equal(session.snapshot().growth.get("life"), 100, "本局快照公开当前生命")
    _assert_equal(session.snapshot().growth.get("max_life"), 100, "本局快照公开生命上限")

    var first_battle: BattleSession = session.create_battle_session()
    _assert_true(
        first_battle.setup_battle(
            {"content_seed": 70402, "battle": {"use_enemy_ai": false}},
            session.progress_snapshot()),
        "第一场战斗从本局成长快照建立")
    _assert_equal(first_battle.engine.player.life, 100, "第一场战斗以本局当前生命开始")
    first_battle.engine.deal_damage(
        first_battle.engine.enemy,
        first_battle.engine.player,
        60,
        "technique")
    _assert_equal(first_battle.engine.player.life, 40, "战斗中受到60点伤害后剩余40生命")
    session.sync_progress_snapshot(first_battle.player_progress_snapshot())
    _assert_equal(session.growth.life, 40, "战后当前生命回写本局且不自动回满")
    _assert_equal(session.growth.max_life, 100, "战后生命上限保持第一层100")

    var second_battle: BattleSession = session.create_battle_session()
    _assert_true(
        second_battle.setup_battle(
            {"content_seed": 70403, "battle": {"use_enemy_ai": false}},
            session.progress_snapshot()),
        "残血本局可以建立下一场战斗")
    _assert_equal(second_battle.engine.player.life, 40, "下一场战斗以本局40点当前生命开始")
    _assert_equal(second_battle.engine.player.max_life, 100, "下一场战斗保留第一层100点上限")

    session.navigation.phase = "boss_chest"
    var first_chest := session.execute({"type": "complete_boss_chest"})
    _assert_true(first_chest.success, "第一层 Boss 宝箱完成后推进第二层")
    _assert_equal(session.navigation.act, 2, "第一层 Boss 宝箱后进入第二层")
    _assert_equal(session.growth.life, 90, "权威例子40/100跨层后成为90/150")
    _assert_equal(session.growth.max_life, 150, "第一层跨层后生命上限增至150")

    session.growth.life = 80
    session.navigation.phase = "boss_chest"
    var second_chest := session.execute({"type": "complete_boss_chest"})
    _assert_true(second_chest.success, "第二层 Boss 宝箱完成后推进第三层")
    _assert_equal(session.navigation.act, 3, "第二层 Boss 宝箱后进入第三层")
    _assert_equal(session.growth.life, 155, "第二层80/150跨层后当前生命增加75至155")
    _assert_equal(session.growth.max_life, 225, "第二层跨层后生命上限增至225")

    var full_session: RunSession = RunSessionScript.new()
    _assert_true(
        full_session.execute({"type": "setup_run", "seed": 70404}).success,
        "满血跨层测试可以建立独立本局")
    full_session.navigation.phase = "boss_chest"
    _assert_true(
        full_session.execute({"type": "complete_boss_chest"}).success,
        "满血时可以完成第一层 Boss 宝箱")
    _assert_equal(full_session.growth.life, 150, "满血跨层当前生命不超过新上限")
    _assert_equal(full_session.growth.max_life, 150, "满血跨层上限正确增长到150")

    var final_session: RunSession = RunSessionScript.new()
    _assert_true(
        final_session.execute({"type": "setup_run", "seed": 70405}).success,
        "第三层通关测试可以建立独立本局")
    final_session.growth.max_life = 225
    final_session.growth.life = 77
    final_session.navigation.act = 3
    final_session.navigation.graph = final_session.navigation.map_generator.generate(
        final_session.navigation.seed, 3)
    final_session.navigation.current_node_id = final_session.navigation.graph["boss_id"]
    final_session.navigation.phase = "node_in_progress"
    _assert_true(
        final_session.execute({"type": "complete_node"}).success,
        "第三层 Boss 胜利建立最终奖励")
    var final_bundle_id := str(final_session.snapshot().reward["bundle"]["id"])
    _assert_true(
        final_session.execute({
            "type": "claim_reward",
            "bundle_id": final_bundle_id,
        }).success,
        "第三层 Boss 奖励领取成功")
    _assert_equal(final_session.navigation.phase, "run_complete", "第三层 Boss 后直接完成本局")
    _assert_equal(final_session.growth.life, 77, "第三层通关不改变当前生命")
    _assert_equal(final_session.growth.max_life, 225, "第三层通关不执行下一层生命成长")

    var reset_probe = BattleSideScript.new("重置探针")
    var reset_rng := RandomNumberGenerator.new()
    reset_probe.max_life = 150
    reset_probe.life = 40
    reset_probe.reset([], reset_rng, false, false)
    _assert_equal(reset_probe.life, 40, "显式关闭生命重置时 BattleSide 保留当前生命")
    reset_probe.reset([], reset_rng, false)
    _assert_equal(reset_probe.life, 150, "默认重置仍为敌人侧和既有调用恢复满生命")

func _test_run_state_battle_growth_persistence() -> void:
    var state = RunStateScript.new()
    state.setup(420)
    state.consumable_ids.append("zengyuan_pill")
    state.hand_technique_progression["high_card"] = {
        "slot_count": 2,
        "sequence": [],
    }
    var run_cards: Array = state.run_deck.create_battle_cards()
    for card in run_cards:
        if card.id == "wind_8":
            card.set_enhancement("qi_boost")
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
    _assert_equal(modified.reshape_enhancement, "qi_boost", "跨战斗保留真气强化")
    _assert_equal(
        engine.player.hand_technique_progression.get("high_card", {}).get("slot_count", 0),
        2,
        "跨战斗保留高牌功法槽位")
    _assert_equal(engine.player.consumable_ids, ["zengyuan_pill"], "跨战斗保留共享消耗品")
    modified.set_enhancement("momentum")
    engine.player.consume_at(0)
    state.sync_from_battle_side(engine.player)
    _assert_equal(state.run_deck.card_data("wind_8")["reshapes"]["enhancement"], "momentum", "战斗中的强化替换同步回本局 RunDeck")
    _assert_equal(state.consumable_ids.size(), 0, "战斗中使用消耗品后同步释放本局槽位")

func _test_run_save_life_round_trip_legacy_defaults_and_validation() -> void:
    var session: RunSession = RunSessionScript.new()
    _assert_true(
        session.execute({"type": "setup_run", "seed": 20501}).success,
        "生命存档测试可以建立本局")
    session.navigation.act = 2
    session.navigation.graph = session.navigation.map_generator.generate(
        session.navigation.seed, 2)
    session.growth.life = 90
    session.growth.max_life = 150
    var save_data = RunSaveDataScript.new().capture(session)
    var saved: Dictionary = save_data.to_dict()
    _assert_equal(saved["growth"]["life"], 90, "存档 growth 段保存当前生命")
    _assert_equal(saved["growth"]["max_life"], 150, "存档 growth 段保存生命上限")
    var restored: Dictionary = save_data.restore_session()
    _assert_true(restored.get("success", false), "第2层90/150生命存档可以恢复")
    _assert_equal(restored["run_session"].growth.life, 90, "读档不把当前生命回满")
    _assert_equal(restored["run_session"].growth.max_life, 150, "读档不把生命上限退回100")

    var legacy: Dictionary = saved.duplicate(true)
    legacy["growth"].erase("life")
    legacy["growth"].erase("max_life")
    var legacy_restored: Dictionary = RunSaveDataScript.new(legacy).restore_session()
    _assert_true(legacy_restored.get("success", false), "缺少生命字段的旧版v1存档仍可读取")
    _assert_equal(legacy_restored["run_session"].growth.life, 150, "第2层旧存档补齐为满血150")
    _assert_equal(legacy_restored["run_session"].growth.max_life, 150, "第2层旧存档按权威表补齐150上限")

    var over_max: Dictionary = saved.duplicate(true)
    over_max["growth"]["life"] = 151
    _assert_true(
        _array_contains_text(
            RunSaveDataScript.new(over_max).validate(),
            "growth.life 不能大于 growth.max_life"),
        "当前生命高于上限时校验报出具名错误")
    var invalid_life: Dictionary = saved.duplicate(true)
    invalid_life["growth"]["life"] = -1
    _assert_true(
        _array_contains_text(
            RunSaveDataScript.new(invalid_life).validate(),
            "growth.life 必须是正整数"),
        "负数当前生命被具名拒绝")
    var fractional: Dictionary = saved.duplicate(true)
    fractional["growth"]["life"] = 90.5
    _assert_true(
        _array_contains_text(
            RunSaveDataScript.new(fractional).validate(),
            "growth.life 必须是正整数"),
        "非整数当前生命被具名拒绝")

func _test_map_practice_and_battle_scene_integration() -> void:
    var run_ui = RunScene.instantiate()
    run_ui.initialize_interface()
    root.add_child(run_ui)
    _assert_true(run_ui.practice_button != null, "地图场景建立右下角修习按钮")
    _assert_equal(run_ui.life_label.text, "生命 100/100", "地图顶栏显示当前生命与上限")
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
    var first_node_id: String = str(run_ui.run_session.snapshot().available_node_ids[0])
    run_ui._on_node_selected(first_node_id)
    _assert_equal(run_ui.run_session.snapshot().phase, "node_in_progress", "地图选择战斗节点后进入未完成状态")
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
    _assert_equal(run_ui.run_session.snapshot().phase, "awaiting_reward", "战斗胜利后进入可见奖励阶段")
    _assert_equal(run_ui.run_session.snapshot().experience, 0, "领取前战斗奖励不会提前到账")
    _assert_true(run_ui.reward_overlay.visible, "战斗胜利后显示奖励结算页面")
    _assert_true(run_ui.practice_button.disabled, "奖励领取期间修习保持锁定")
    run_ui._claim_reward()
    _assert_equal(run_ui.run_session.snapshot().phase, "awaiting_node", "领取奖励后返回地图待选状态")
    _assert_equal(run_ui.run_session.snapshot().experience, 3, "领取后战斗奖励显示为当前历练")
    _assert_true(not run_ui.reward_overlay.visible, "领取后关闭奖励结算页面")
    _assert_true(
        run_ui.run_session.snapshot().run_log.size() >= 3,
        "地图、战斗节点完成与本局流程共用结构化日志")
    _assert_true(not run_ui.battle_layer.visible, "战斗胜利后关闭战斗层而不自动打开修习")
    _assert_true(not run_ui.practice_overlay.visible, "战斗胜利不会强制弹出修习页面")
    run_ui.queue_free()

func _test_battle_scene_prefers_injected_session_and_keeps_standalone_fallback() -> void:
    var injected_scene = BattleScene.instantiate()
    _assert_true(
        injected_scene.battle_session == null,
        "战斗场景实例化时不提前创建并加载默认会话")
    var shared_root = GameCompositionRootScript.new()
    _assert_true(shared_root.initialize(), "UI 注入测试建立共享组合根")
    var shared_run = shared_root.create_run_session()
    var injected_session = shared_run.create_battle_session()
    injected_scene.configure_battle_session(injected_session)
    root.add_child(injected_scene)
    _assert_true(
        injected_scene.battle_session == injected_session,
        "正式流程在 ready 前注入并保留共享战斗会话")
    _assert_true(
        injected_scene.battle_session.engine.content_catalog == shared_root.content_catalog,
        "正式流程复用组合根内容目录而不建立第二份目录")
    injected_scene.queue_free()

    var standalone_scene = BattleScene.instantiate()
    standalone_scene._ensure_battle_session()
    _assert_true(
        standalone_scene.battle_session != null,
        "独立启动战斗场景时建立默认会话")
    _assert_true(
        standalone_scene.battle_session.engine.content_ready,
        "独立战斗场景的默认会话完成内容加载：%s" % ", ".join(
            standalone_scene.battle_session.engine.content_catalog.errors))
    standalone_scene.queue_free()

func _test_front_menu_and_starter_build_flow() -> void:
    var front = FrontScene.instantiate()
    front.initialize_interface()
    root.add_child(front)
    _assert_true(front.menu_page.visible, "项目入口默认显示主菜单")
    _assert_true(front.continue_button.disabled, "没有存档时继续游戏入口明确不可用")
    _assert_true(front.starter_repository.available_builds().size() == 1, "主菜单读取唯一标准初始构筑")
    front._on_new_game()
    _assert_true(front.build_page.visible, "新游戏进入初始构筑页面")
    _assert_equal(front.selected_starter_build_id, "standard_52", "初始构筑页面默认选中标准52张牌组")
    _assert_true(not front.begin_run_button.disabled, "存在可用初始构筑时允许开始行旅")
    front._start_new_run()
    _assert_true(front.active_run != null, "确认初始构筑后创建本局地图场景")
    _assert_equal(
        front.active_run.run_session.snapshot().starter_build_id,
        "standard_52",
        "初始构筑ID进入本局快照：run=%s" % [
            str(front.active_run.starter_build_id),
            ])
    _assert_equal(
        front.active_run.run_session.snapshot().phase,
        "awaiting_node",
        "确认构筑后本局从地图待选状态开始")
    front.queue_free()

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
