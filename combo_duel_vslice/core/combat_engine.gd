class_name ComboCombatEngine
extends RefCounted

signal state_changed

const TechniqueRepositoryScript = preload("res://core/technique_repository.gd")
const InnerSkillRepositoryScript = preload("res://core/inner_skill_repository.gd")
const ConsumableRepositoryScript = preload("res://core/consumable_repository.gd")
const SequenceBookScript = preload("res://core/sequence_book.gd")
const BattleSideScript = preload("res://core/battle_side.gd")
const TriggerQueueScript = preload("res://core/trigger_queue.gd")
const EffectExecutorScript = preload("res://core/effect_executor.gd")
const ScriptedScenarioScript = preload("res://core/scripted_battle_scenario.gd")
const PlayerActionControllerScript = preload("res://core/player_action_controller.gd")
const EnemyActionControllerScript = preload("res://core/enemy_action_controller.gd")
const ActionPreviewServiceScript = preload("res://core/action_preview_service.gd")
const ActionResolverScript = preload("res://core/action_resolver.gd")
const DamageResolverScript = preload("res://core/damage_resolver.gd")
const GameLogScript = preload("res://core/game_log.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const BattleFlowCoordinatorScript = preload("res://core/battle_flow_coordinator.gd")
const BattleTimingSystemScript = preload("res://core/battle_timing_system.gd")
const StatusSystemScript = preload("res://core/status_system.gd")
const BattleEffectPortsScript = preload("res://core/effects/battle_effect_ports.gd")
const BattleRoundServiceScript = preload("res://core/battle_round_service.gd")
const BattleActionServiceScript = preload("res://core/battle_action_service.gd")
const BattleConsumableServiceScript = preload("res://core/battle_consumable_service.gd")
const BattleOutcomeServiceScript = preload("res://core/battle_outcome_service.gd")
const EnemyActionPlanningServiceScript = preload("res://core/enemy_action_planning_service.gd")
const BattleSetupServiceScript = preload("res://core/battle_setup_service.gd")
const BattleLoadoutServiceScript = preload("res://core/battle_loadout_service.gd")
const CardReshapeBattleRuntimeScript = preload(
    "res://core/card_reshapes/card_reshape_battle_runtime.gd")
const PassiveRuleHandlerRegistryScript = preload(
    "res://core/passives/passive_rule_handler_registry.gd")
const PassiveRuleRuntimeScript = preload(
    "res://core/passives/passive_rule_runtime.gd")
const BattlePassiveTimingBridgeScript = preload(
    "res://core/passives/battle_passive_timing_bridge.gd")
const BattlePassiveCommittedEventServiceScript = preload(
    "res://core/passives/battle_passive_committed_event_service.gd")
const BattleRuleQueryServiceScript = preload(
    "res://core/passives/battle_rule_query_service.gd")
const HandRecognitionPolicyScript = preload(
    "res://core/passives/hand_recognition_policy.gd")
const CardIdentityPolicyScript = preload(
    "res://core/passives/card_identity_policy.gd")
const BattlePermissionServiceScript = preload(
    "res://core/passives/battle_permission_service.gd")
const SameQiGaugeServiceScript = preload("res://core/same_qi_gauge_service.gd")
const TechniqueInvocationServiceScript = preload("res://core/technique_invocation_service.gd")
const TechniqueAutoTriggerServiceScript = preload("res://core/technique_auto_trigger_service.gd")
const TechniqueResolutionServiceScript = preload("res://core/technique_resolution_service.gd")

var rng := RandomNumberGenerator.new()
var game_log := GameLogScript.new()
var repository := TechniqueRepositoryScript.new()
var inner_skill_repository := InnerSkillRepositoryScript.new()
var consumable_repository := ConsumableRepositoryScript.new()
var sequence_book := SequenceBookScript.new()
var enemy_sequence_book := SequenceBookScript.new()
var trigger_queue := TriggerQueueScript.new(game_log)
var timing_system := BattleTimingSystemScript.new(trigger_queue)
var effect_executor
var player_action_controller := PlayerActionControllerScript.new()
var enemy_action_controller
var action_preview_service
var action_resolver
var effect_ports
var damage_resolver := DamageResolverScript.new()
var status_system
var player := BattleSideScript.new("玩家", "player")
var enemy := BattleSideScript.new("敌人", "enemy")
var battle_flow := BattleFlowCoordinatorScript.new()
var scenario := ScriptedScenarioScript.new()
var content_catalog
var content_ready: bool = false
var round_service
var action_service
var consumable_service
var outcome_service
var enemy_planning_service
var battle_setup_service
var loadout_service: BattleLoadoutService
var card_reshape_runtime
var passive_rule_registry
var passive_rule_runtime
var battle_passive_timing_bridge
var battle_passive_event_service
var battle_rule_query_service
var hand_recognition_policy
var card_identity_policy
var battle_permission_service
var same_qi_gauge_service
var technique_invocation_service
var technique_auto_trigger_service
var technique_resolution_service
var _battle_instance_serial: int = 0

var turn_number: int:
    get: return round_service.turn_number
    set(value): round_service.turn_number = value
var actions_available: int:
    get: return battle_flow.available_action_count(player)
    set(value): battle_flow.set_action_count(player, value)
var enemy_actions_available: int:
    get: return battle_flow.available_action_count(enemy)
    set(value): battle_flow.set_action_count(enemy, value)
var enemy_action_index: int:
    get: return round_service.enemy_action_index
    set(value): round_service.enemy_action_index = value
var locked_enemy_card_ids: Array:
    get: return enemy_planning_service.locked_enemy_card_ids
    set(value): enemy_planning_service.locked_enemy_card_ids = value
var locked_enemy_action_proposal:
    get: return enemy_planning_service.locked_enemy_action_proposal
    set(value): enemy_planning_service.locked_enemy_action_proposal = value
var scripted_mode: bool = false
var enemy_ai_enabled: bool = false
var external_enemy_action_mode: bool = false
var external_round_end_requested: bool:
    get: return round_service.external_round_end_requested
    set(value): round_service.external_round_end_requested = value
var enemy_ai_policy: Dictionary:
    get: return enemy_planning_service.enemy_ai_policy
    set(value): enemy_planning_service.set_policy(value)
var enemy_plan: Dictionary:
    get: return enemy_planning_service.enemy_plan
    set(value): enemy_planning_service.enemy_plan = value
var round_ended: bool:
    get: return round_service.round_ended
    set(value): round_service.round_ended = value
var battle_state: String:
    get: return outcome_service.state
    set(value): outcome_service.state = value
var battle_state_detail: String:
    get: return outcome_service.detail
    set(value): outcome_service.detail = value

var delayed_effects: Array = []
var power_modifiers: Dictionary = {}
var last_preview: Dictionary:
    get: return action_service.last_preview
    set(value): action_service.last_preview = value
var last_enemy_preview: Dictionary:
    get: return action_service.last_enemy_preview
    set(value): action_service.last_enemy_preview = value
var last_played_hand: String:
    get: return action_service.last_played_hand
    set(value): action_service.last_played_hand = value
var last_player_action_cards: Array:
    get: return action_service.last_player_action_cards
    set(value): action_service.last_player_action_cards = value
var last_enemy_action_cards: Array:
    get: return action_service.last_enemy_action_cards
    set(value): action_service.last_enemy_action_cards = value
var battle_cleanup_completed: bool:
    get: return outcome_service.cleanup_completed
    set(value): outcome_service.cleanup_completed = value
var battle_start_card_effects_applied: bool:
    get: return round_service.battle_start_card_effects_applied
    set(value): round_service.battle_start_card_effects_applied = value
var current_round_actors: Array:
    get: return round_service.current_round_actors
    set(value): round_service.current_round_actors = value
var defense_retention_policy:
    get: return round_service.defense_retention_policy
var last_defense_decay_results: Array[Dictionary]:
    get: return round_service.last_defense_decay_results

func _init(
        game_log_override = null,
        content_catalog_override = null,
        passive_rule_registry_override = null) -> void:
    if game_log_override != null:
        use_game_log(game_log_override)
    content_catalog = (
        content_catalog_override
        if content_catalog_override != null
        else ContentCatalogScript.new())
    battle_setup_service = BattleSetupServiceScript.new(content_catalog)
    if content_catalog_override == null:
        content_catalog.load_all()
    content_ready = bool(content_catalog.loaded)
    passive_rule_registry = (
        passive_rule_registry_override
        if passive_rule_registry_override != null
        else content_catalog.passive_rule_registry)
    if passive_rule_registry == null:
        passive_rule_registry = PassiveRuleHandlerRegistryScript.new()
    passive_rule_runtime = PassiveRuleRuntimeScript.new(
        passive_rule_registry, content_catalog)
    player.use_passive_rule_runtime(passive_rule_runtime)
    enemy.use_passive_rule_runtime(passive_rule_runtime)
    battle_passive_timing_bridge = BattlePassiveTimingBridgeScript.new(
        passive_rule_runtime, timing_system)
    battle_passive_event_service = BattlePassiveCommittedEventServiceScript.new(
        passive_rule_runtime, Callable(self, "_set_scenario_error"))
    battle_passive_event_service.register_weak_listener(
        player, "on_committed_event_for_run_history")
    battle_rule_query_service = BattleRuleQueryServiceScript.new(
        passive_rule_runtime, Callable(self, "_set_scenario_error"))
    battle_rule_query_service.use_rng(rng)
    battle_rule_query_service.use_committed_event_service(
        battle_passive_event_service)
    hand_recognition_policy = HandRecognitionPolicyScript.new(passive_rule_runtime)
    card_identity_policy = CardIdentityPolicyScript.new(passive_rule_runtime)
    battle_permission_service = BattlePermissionServiceScript.new(passive_rule_runtime)
    player.use_battle_rule_query_service(battle_rule_query_service)
    enemy.use_battle_rule_query_service(battle_rule_query_service)
    player.use_committed_event_service(
        battle_passive_event_service, Callable(self, "_read_turn_number"))
    enemy.use_committed_event_service(
        battle_passive_event_service, Callable(self, "_read_turn_number"))
    if content_ready:
        battle_setup_service.configure_repositories(
            repository,
            inner_skill_repository,
            consumable_repository,
            sequence_book,
            enemy_sequence_book)
    else:
        game_log.record_system(
            "error",
            "content_catalog",
            "战斗内容目录校验失败",
            "\n".join(content_catalog.errors))
    status_system = StatusSystemScript.new(
        content_catalog,
        timing_system,
        game_log)
    battle_permission_service.register_provider(
        status_system,
        "status_system",
        100,
        ["card_play_permission_query", "explicit_discard_permission_query"])
    status_system.use_battle_permission_service(battle_permission_service)
    effect_ports = BattleEffectPortsScript.new(
        damage_resolver,
        status_system,
        battle_flow,
        trigger_queue)
    effect_ports.use_battle_permission_service(battle_permission_service)
    effect_ports.use_sides(player, enemy)
    effect_ports.use_battle_rng(rng)
    effect_ports.use_technique_repository(repository)
    same_qi_gauge_service = SameQiGaugeServiceScript.new(battle_flow)
    effect_ports.use_same_qi_gauge_service(same_qi_gauge_service)
    passive_rule_runtime.use_battle_effect_ports(
        effect_ports, Callable(self, "_set_scenario_error"))
    status_system.use_effect_ports(effect_ports)
    status_system.use_rng(rng)
    card_reshape_runtime = CardReshapeBattleRuntimeScript.new(
        content_catalog.card_reshape_rules,
        effect_ports,
        rng,
        timing_system)
    battle_permission_service.register_provider(
        card_reshape_runtime,
        "card_reshape_runtime",
        200,
        ["explicit_discard_permission_query"])
    status_system.use_card_trigger_replay_service(
        card_reshape_runtime.trigger_replay_service)
    effect_ports.use_card_reshape_runtime(card_reshape_runtime)
    effect_ports.use_consumable_repository(consumable_repository)
    effect_ports.use_passive_battle_services(
        battle_rule_query_service, battle_passive_event_service,
        Callable(self, "_read_turn_number"))
    status_system.use_committed_event_service(
        battle_passive_event_service, Callable(self, "_read_turn_number"))
    delayed_effects = status_system.delayed_records
    player.use_status_system(status_system)
    enemy.use_status_system(status_system)
    player.use_card_policies(hand_recognition_policy, card_identity_policy)
    enemy.use_card_policies(hand_recognition_policy, card_identity_policy)
    player.use_battle_permission_service(battle_permission_service)
    enemy.use_battle_permission_service(battle_permission_service)
    player.use_technique_sequence_book(sequence_book)
    enemy.use_technique_sequence_book(enemy_sequence_book)
    player.use_battle_effect_ports(effect_ports)
    enemy.use_battle_effect_ports(effect_ports)
    player.use_card_reshape_runtime(card_reshape_runtime)
    enemy.use_card_reshape_runtime(card_reshape_runtime)
    effect_executor = EffectExecutorScript.new(rng, null, content_catalog)
    effect_ports.use_effect_executor(effect_executor)
    passive_rule_runtime.use_effect_executor(effect_executor)
    technique_resolution_service = TechniqueResolutionServiceScript.new(
        repository, effect_executor, effect_ports,
        battle_passive_event_service)
    effect_ports.use_technique_resolution_service(technique_resolution_service)
    technique_invocation_service = TechniqueInvocationServiceScript.new(
        technique_resolution_service, effect_executor, effect_ports, rng)
    effect_ports.use_technique_invocation_service(technique_invocation_service)
    technique_auto_trigger_service = TechniqueAutoTriggerServiceScript.new(
        repository, technique_invocation_service, effect_ports,
        battle_passive_event_service, [player, enemy],
        [sequence_book, enemy_sequence_book])
    status_system.use_effect_executor(effect_executor)
    battle_passive_event_service.register_weak_listener(
        status_system, "on_committed_event_for_responses")
    enemy_action_controller = EnemyActionControllerScript.new(rng)
    timing_system.register_weak_handler(
        BattleTimingSystemScript.BATTLE_END,
        "combat_engine.flow_cleanup",
        2147483646,
        self,
        "_on_flow_battle_end_timing")
    timing_system.register_weak_handler(
        BattleTimingSystemScript.ROUND_START,
        "combat_engine.automatic_round_start_event",
        2147483645,
        self,
        "_on_automatic_round_start_timing")
    timing_system.register_weak_handler(
        BattleTimingSystemScript.TURN_END,
        "combat_engine.automatic_turn_end_event",
        2147483645,
        self,
        "_on_automatic_turn_end_timing")
    action_preview_service = ActionPreviewServiceScript.new(
        repository,
        passive_rule_runtime,
        effect_executor,
        battle_rule_query_service,
        Callable(self, "_read_turn_number"),
        battle_permission_service,
        same_qi_gauge_service,
        technique_resolution_service)
    action_resolver = ActionResolverScript.new(
        effect_ports,
        repository,
        passive_rule_runtime,
        trigger_queue,
        effect_executor,
        rng,
        timing_system,
        Callable(self, "_set_scenario_error"),
        action_preview_service,
        battle_passive_event_service,
        technique_resolution_service)
    effect_ports.use_hand_retrigger_callback(
        Callable(action_resolver, "retrigger_current_hand_technique"))
    loadout_service = BattleLoadoutServiceScript.new(
        player,
        trigger_queue,
        Callable(action_resolver, "has_pending_choice"))
    round_service = BattleRoundServiceScript.new(
        player,
        enemy,
        battle_flow,
        timing_system,
        trigger_queue,
        Callable(self, "_read_battle_state"),
        Callable(self, "_lock_enemy_action"),
        Callable(self, "_resolve_enemy_only_actions"),
        Callable(self, "_update_battle_state"),
        Callable(self, "_set_scenario_error"),
        Callable(self, "_emit_state_changed"))
    round_service.defense_retention_policy.use_battle_rule_query_service(
        battle_rule_query_service)
    round_service.set_modes(scripted_mode, external_enemy_action_mode)
    enemy_planning_service = EnemyActionPlanningServiceScript.new(
        enemy,
        player,
        battle_flow,
        enemy_action_controller,
        enemy_sequence_book,
        scenario,
        Callable(self, "_preview_for_side"),
        Callable(self, "_action_unavailable_reason"),
        Callable(self, "_set_scenario_error"),
        Callable(self, "_read_turn_number"),
        Callable(self, "_read_enemy_action_index"),
        trigger_queue,
        game_log,
        passive_rule_runtime)
    action_service = BattleActionServiceScript.new(
        player,
        enemy,
        battle_flow,
        player_action_controller,
        action_resolver,
        trigger_queue,
        sequence_book,
        enemy_sequence_book,
        Callable(self, "preview"),
        Callable(self, "_preview_for_side"),
        Callable(self, "_action_unavailable_reason"),
        Callable(self, "_read_battle_state"),
        Callable(self, "_update_battle_state"),
        Callable(self, "_lock_enemy_action"),
        Callable(self, "_clear_enemy_action_lock"),
        Callable(self, "_resolve_enemy_only_actions"),
        Callable(self, "_set_scenario_error"),
        Callable(self, "_emit_state_changed"),
        Callable(self, "_read_enemy_action_index"),
        Callable(self, "_write_enemy_action_index"),
        Callable(self, "_read_turn_number"),
        Callable(self, "_read_locked_enemy_cards"))
    action_service.set_modes(
        scripted_mode,
        enemy_ai_enabled,
        external_enemy_action_mode)
    outcome_service = BattleOutcomeServiceScript.new(
        player,
        enemy,
        battle_flow,
        timing_system,
        trigger_queue,
        round_service,
        power_modifiers,
        game_log,
        Callable(self, "_clear_enemy_action_lock"),
        Callable(self, "_emit_state_changed"),
        Callable(self, "_read_turn_number"))
    consumable_service = BattleConsumableServiceScript.new(
        player,
        consumable_repository,
        repository,
        action_resolver,
        trigger_queue,
        rng,
        Callable(self, "_read_battle_state"),
        Callable(self, "_emit_state_changed"),
        enemy,
        battle_passive_event_service,
        content_catalog)

func use_game_log(shared_game_log) -> void:
    if shared_game_log == null:
        return
    game_log = shared_game_log
    trigger_queue = TriggerQueueScript.new(game_log)
    timing_system.use_trigger_queue(trigger_queue)
    if round_service != null:
        round_service.trigger_queue = trigger_queue
    if action_service != null:
        action_service.trigger_queue = trigger_queue
    if enemy_planning_service != null:
        enemy_planning_service.use_game_log_queue(trigger_queue, game_log)
    if consumable_service != null:
        consumable_service.use_game_log_queue(trigger_queue)
    if outcome_service != null:
        outcome_service.use_game_log_queue(trigger_queue, game_log)
    if status_system != null:
        status_system.use_game_log(game_log)
    if action_resolver != null:
        action_resolver.use_trigger_queue(trigger_queue)
    if effect_ports != null:
        effect_ports.use_trigger_queue(trigger_queue)

func _read_battle_state() -> String:
    return battle_state

func _emit_state_changed() -> void:
    state_changed.emit()

func _read_turn_number() -> int:
    return turn_number

func _read_enemy_action_index() -> int:
    return enemy_action_index

func _write_enemy_action_index(value: int) -> void:
    enemy_action_index = value

func _read_locked_enemy_cards() -> Array:
    return locked_enemy_card_ids

## 兼容旧测试和调试脚本直接切换公开模式字段；正式流程仍由 setup 方法配置。
func _sync_action_service_modes() -> void:
    round_service.set_modes(scripted_mode, external_enemy_action_mode)
    enemy_planning_service.set_modes(enemy_ai_enabled, external_enemy_action_mode)
    enemy_planning_service.set_policy(enemy_ai_policy)
    action_service.set_modes(
        scripted_mode,
        enemy_ai_enabled,
        external_enemy_action_mode)
    outcome_service.set_mode(scripted_mode)

func _create_standard_deck(instance_namespace: String = "") -> Array:
    return battle_setup_service.create_standard_deck(instance_namespace)

func setup(
        seed_value: int = 2308,
        shuffle_cards: bool = true,
        player_deck_override = null) -> void:
    if not content_ready:
        battle_state = "content_error"
        battle_state_detail = "统一内容目录无效"
        state_changed.emit()
        return
    battle_passive_timing_bridge.close_battle()
    battle_passive_event_service.close_battle()
    passive_rule_runtime.close_battle_effect_commands()
    rng.seed = seed_value
    battle_cleanup_completed = false
    round_service.reset()
    round_service.set_modes(false, false)
    action_service.reset()
    same_qi_gauge_service.reset()
    technique_invocation_service.reset()
    technique_auto_trigger_service.reset()
    action_service.set_modes(false, false, false)
    enemy_planning_service.reset()
    enemy_planning_service.set_modes(false, false)
    outcome_service.reset()
    outcome_service.set_mode(false)
    var player_cards: Array = (
        _create_standard_deck()
        if player_deck_override == null
        else player_deck_override)
    player.reset(player_cards, rng, shuffle_cards)
    enemy.reset(_create_standard_deck("enemy"), rng, shuffle_cards)
    battle_flow.reset([player, enemy])
    sequence_book.reset()
    enemy_sequence_book.reset()
    battle_setup_service.seed_owned_techniques(player, sequence_book)
    battle_setup_service.seed_owned_techniques(enemy, enemy_sequence_book)
    trigger_queue.clear()
    timing_system.reset()
    status_system.reset()
    delayed_effects.clear()
    power_modifiers.clear()
    locked_enemy_card_ids.clear()
    locked_enemy_action_proposal = null
    scripted_mode = false
    enemy_ai_enabled = false
    external_enemy_action_mode = false
    enemy_ai_policy.clear()
    enemy_plan.clear()
    damage_resolver.reset()
    action_resolver.reset()
    _battle_instance_serial += 1
    var battle_instance_id := "battle-%06d" % _battle_instance_serial
    effect_ports.use_battle_instance_id(battle_instance_id)
    passive_rule_runtime.open_battle_effect_commands(battle_instance_id)
    battle_passive_event_service.open_battle(
        [player, enemy], battle_instance_id)
    passive_rule_runtime.suppression_service.clear()
    state_changed.emit()

func setup_scripted_battle(
        seed_value: int = 2308,
        scenario_path: String = "",
        use_enemy_ai: bool = false,
        player_deck_override = null,
        shuffle_cards: bool = true) -> bool:
    if scenario_path == "":
        scenario_path = content_catalog.path_for("scripted_battle")
    setup(seed_value, shuffle_cards, player_deck_override)
    if not content_ready:
        return false
    var scenario_loaded: bool = battle_setup_service.load_scenario(scenario, scenario_path)
    if not scenario_loaded:
        battle_state = "scenario_error"
        battle_state_detail = "脚本化战斗场景无法载入"
        game_log.record_system(
            "error",
            "scenario_load",
            battle_state_detail,
            scenario_path)
        state_changed.emit()
        return false
    scripted_mode = true
    enemy_ai_enabled = use_enemy_ai
    var scripted_setup: Dictionary = battle_setup_service.apply_scripted_scenario(
        scenario,
        player,
        enemy,
        rng,
        _create_standard_deck("enemy"))
    if not scripted_setup.get("success", false):
        battle_state = "scenario_error"
        battle_state_detail = str(scripted_setup.get("reason", "脚本战斗装配无效"))
        game_log.record_system(
            "error", "scenario_loadout", "脚本战斗装配失败",
            battle_state_detail)
        state_changed.emit()
        return false
    enemy.name = scripted_setup["name"]
    enemy_ai_policy = scripted_setup["enemy_ai_policy"]
    _sync_action_service_modes()
    var enemy_sequences: Dictionary = scripted_setup["enemy_sequences"]
    if not enemy_sequences.is_empty():
        enemy_sequence_book.configure(enemy_sequences)
        battle_setup_service.seed_owned_techniques(enemy, enemy_sequence_book)
    trigger_queue.add_history(
        "battle_setup", enemy.name, "纵切场景", "成功",
        "调试 AI 已载入；不代表正式敌方策略" if enemy_ai_enabled else "固定脚本场景已载入")
    state_changed.emit()
    return true

func replace_player_deck(cards: Array, shuffle_cards: bool = true) -> void:
    player.replace_deck(cards, rng, shuffle_cards)
    battle_start_card_effects_applied = false
    current_round_actors.clear()
    state_changed.emit()

func use_external_enemy_actions(enabled: bool) -> void:
    if not enabled and battle_passive_timing_bridge.is_assembled():
        battle_passive_timing_bridge.close_battle()
        battle_passive_event_service.close_battle()
        passive_rule_runtime.close_battle_effect_commands()
    external_enemy_action_mode = enabled
    round_service.set_modes(scripted_mode, external_enemy_action_mode)
    action_service.set_modes(scripted_mode, enemy_ai_enabled, external_enemy_action_mode)
    round_service.external_round_end_requested = false
    if enabled:
        _clear_enemy_action_lock()

func start_player_turn() -> Array:
    _sync_action_service_modes()
    last_preview.clear()
    last_enemy_preview.clear()
    last_player_action_cards.clear()
    last_enemy_action_cards.clear()
    enemy_plan.clear()
    if not battle_passive_timing_bridge.is_assembled():
        var assembled: Dictionary = battle_passive_timing_bridge.assemble(
            [player, enemy])
        if not assembled.get("success", false):
            _set_scenario_error(str(assembled.get(
                "reason", "战斗被动生命周期装配失败")))
            return []
    return round_service.start_player_turn()

func end_player_turn() -> void:
    round_service.end_player_turn()

func register_defense_retention_provider(provider_id: String, provider) -> bool:
    return defense_retention_policy.register_provider(provider_id, provider)

func unregister_defense_retention_provider(provider_id: String) -> bool:
    return defense_retention_policy.unregister_provider(provider_id)

func apply_passive_suppression(values: Dictionary) -> Dictionary:
    var result: Dictionary = passive_rule_runtime.suppression_service.apply(values)
    if result.get("success", false):
        player.recalculate_effective_max_life()
        enemy.recalculate_effective_max_life()
    return result

func remove_passive_suppression(suppression_id: String) -> bool:
    var removed: bool = passive_rule_runtime.suppression_service.remove(
        suppression_id)
    if removed:
        player.recalculate_effective_max_life()
        enemy.recalculate_effective_max_life()
    return removed

func _finish_round_end() -> void:
    round_service.finish_round_end()

func preview(card_ids: Array) -> Dictionary:
    return _preview_for_side(player, card_ids, sequence_book, power_modifiers)

func _preview_for_side(side, card_ids: Array, book, modifiers_by_hand: Dictionary = {}) -> Dictionary:
    return action_preview_service.preview(
        side,
        card_ids,
        book,
        modifiers_by_hand,
        enemy if side == player else player)

func grant_consumable(side, consumable_id: String, source: String = "效果") -> bool:
    return consumable_service.grant(side, consumable_id, source)

func use_player_consumable(slot_index: int, card_ids: Array = []) -> Dictionary:
    return consumable_service.use_player(slot_index, card_ids)

func confirm_play(card_ids: Array, cooperation_card_ids: Array = []) -> Dictionary:
    _sync_action_service_modes()
    return action_service.confirm_play(card_ids, cooperation_card_ids)

func has_pending_effect_choice() -> bool:
    return action_service.has_pending_choice()

func pending_effect_choice_snapshot() -> Dictionary:
    return action_service.pending_choice_snapshot()

func pending_action_transaction_snapshot() -> Dictionary:
    return action_service.pending_action_transaction_snapshot()

func resolve_effect_choice(request_id: String, selected_card_ids: Array) -> Dictionary:
    _sync_action_service_modes()
    return action_service.resolve_effect_choice(request_id, selected_card_ids)

func combat_order_labels(side, technique_name: String = "当前功法") -> Array[String]:
    return action_resolver.combat_order_labels(side, technique_name)

func move_player_technique_slot(direction: int) -> Dictionary:
    var result: Dictionary = loadout_service.move_technique_slot(direction)
    if result["success"]:
        state_changed.emit()
    return result

func enemy_decision_observation():
    return enemy_planning_service.decision_observation()

func enemy_remote_action_proposals() -> Array:
    _sync_action_service_modes()
    return enemy_planning_service.remote_action_proposals()

func enemy_candidate_set() -> Dictionary:
    return enemy_planning_service.prepare_candidate_set()

func enemy_utility_action_proposal():
    _sync_action_service_modes()
    return enemy_planning_service.utility_action_proposal()

func lock_external_enemy_action(proposal) -> Dictionary:
    _sync_action_service_modes()
    return enemy_planning_service.store_external_action(proposal)

func has_locked_enemy_action() -> bool:
    return enemy_planning_service.has_locked_action()

func _lock_enemy_action() -> void:
    _sync_action_service_modes()
    enemy_planning_service.lock_action()

func _store_enemy_action_proposal(proposal, source_label: String) -> Dictionary:
    return enemy_planning_service.store_action_proposal(proposal, source_label)

func _clear_enemy_action_lock() -> void:
    enemy_planning_service.clear_action_lock()

func _public_enemy_plan(intent: Dictionary) -> Dictionary:
    return enemy_planning_service.public_plan(intent)

func _resolve_enemy_only_actions() -> void:
    _sync_action_service_modes()
    while battle_state == "active" \
            and not battle_flow.can_act(player) \
            and battle_flow.can_act(enemy):
        if locked_enemy_card_ids.is_empty():
            _lock_enemy_action()
        if locked_enemy_card_ids.is_empty():
            break
        var result: Dictionary = action_service.resolve_locked_enemy_action_once()
        if not result.get("success", false):
            return
        if battle_state == "active" and battle_flow.can_act(enemy):
            _lock_enemy_action()

func resolve_external_enemy_action() -> Dictionary:
    if not external_enemy_action_mode:
        return {"success": false, "reason": "战斗未启用外部敌方行动端口"}
    if battle_flow.can_act(player):
        return {"success": false, "reason": "玩家仍有行动机会，不能单方结算敌方行动"}
    _sync_action_service_modes()
    var result: Dictionary = action_service.resolve_locked_enemy_action_once()
    if result.get("success", false) \
            and battle_state == "active" \
            and external_round_end_requested \
            and not battle_flow.can_act(enemy):
        _finish_round_end()
    state_changed.emit()
    return result

func gain_extra_actions(amount: int, source: String) -> void:
    gain_extra_actions_for(player, amount, source)

func gain_extra_actions_for(side, amount: int, source: String) -> void:
    effect_ports.gain_extra_actions(side, amount, source)

func disable_actor_current_round(side, reason: String) -> void:
    battle_flow.disable_current_round(side, reason)
    if side == enemy:
        locked_enemy_card_ids.clear()
        locked_enemy_action_proposal = null
        enemy_plan.clear()
    trigger_queue.add_history(
        "action_control",
        "%s本回合无法行动" % side.name,
        "行动调度",
        "成功",
        reason)
    state_changed.emit()

func disable_actor_next_rounds(side, reason: String, round_count: int = 1) -> void:
    battle_flow.disable_next_rounds(side, reason, round_count)
    trigger_queue.add_history(
        "action_control_schedule",
        "%s后续行动受限" % side.name,
        "行动调度",
        "成功",
        "%s｜%d 回合" % [reason, maxi(0, round_count)])

func forfeit_actor_actions(side, reason: String) -> void:
    battle_flow.forfeit_remaining(side, reason)
    if side == enemy:
        locked_enemy_card_ids.clear()
        locked_enemy_action_proposal = null
        enemy_plan.clear()
    state_changed.emit()

func actor_action_state(side) -> Dictionary:
    return battle_flow.snapshot_for(side)

func _action_unavailable_reason(side) -> String:
    var state: Dictionary = battle_flow.snapshot_for(side)
    var disabled_reasons: Array = state.get("disabled_reasons", [])
    if not disabled_reasons.is_empty():
        return "当前无法行动：%s" % "、".join(disabled_reasons)
    var forfeit_reason := str(state.get("last_forfeit_reason", ""))
    if forfeit_reason != "":
        return forfeit_reason
    return "当前没有可用出牌机会"

func deal_damage(actor, target, base_amount: int, source_kind: String, true_damage: bool = false) -> Dictionary:
    return effect_ports.deal_damage(
        actor,
        target,
        base_amount,
        source_kind,
        true_damage)

func begin_synchronized_damage(records: Array) -> void:
    effect_ports.begin_synchronized_damage(records)

func flush_synchronized_damage() -> Dictionary:
    return effect_ports.flush_synchronized_damage()

func damage_actor_can_continue(side) -> bool:
    return damage_resolver.actor_can_continue(side)

func damage_target_can_receive(side) -> bool:
    return damage_resolver.target_can_receive(side)

func _update_battle_state() -> void:
    outcome_service.set_mode(scripted_mode)
    outcome_service.update()

func _on_automatic_round_start_timing(event) -> Dictionary:
    var actors: Array = event.actors if event.actors is Array else []
    for actor in actors:
        var token := "timing:round_start:%d:%s" % [
            int(event.serial), str(actor.owner_id)]
        var committed: Dictionary = battle_passive_event_service.publish_resolved_timing_event(
            "round_start", {
                "event_token": battle_passive_event_service.make_token(
                    "round_start", actor, event.serial, token),
                "event_serial": int(event.serial),
                "actor": actor, "owner": actor,
                "round_number": int(event.round_number),
                "action_token": token,
            })
        if not committed.get("success", false):
            return {"success": false, "detail": committed.get("reason", "round_start 提交失败")}
    return {"success": true}

func _on_automatic_turn_end_timing(event) -> Dictionary:
    var actor = event.actor
    if actor == null:
        return {"success": false, "detail": "turn_end 缺少行动方"}
    var token := "timing:turn_end:%d:%s" % [
        int(event.serial), str(actor.owner_id)]
    var committed: Dictionary = battle_passive_event_service.publish_resolved_timing_event(
        "turn_end", {
            "event_token": battle_passive_event_service.make_token(
                "turn_end", actor, event.serial, token),
            "event_serial": int(event.serial),
            "actor": actor, "owner": actor,
            "round_number": int(event.round_number),
            "action_token": token,
        })
    if not committed.get("success", false):
        return {"success": false, "detail": committed.get("reason", "turn_end 提交失败")}
    var actors: Array = event.actors if event.actors is Array else []
    if actors.is_empty() or actor == actors.back():
        var resolved: Dictionary = effect_ports.resolve_technique_invocations_at_timing(
            "round_end")
        if not resolved.get("success", false):
            return {
                "success": false,
                "detail": resolved.get("reason", "round_end 功法调用失败"),
            }
    return {"success": true}

func _on_flow_battle_end_timing(event) -> Dictionary:
    technique_resolution_service.discard_all_pending_executions()
    var result: Dictionary = outcome_service.on_battle_end_timing(event)
    var cleanup_token := "timing:battle_end:%d" % int(event.serial)
    for side in [player, enemy]:
        var temporary_cleanup: Dictionary = \
            effect_ports.clear_temporary_techniques(side, cleanup_token)
        if not temporary_cleanup.get("success", false):
            return {
                "success": false,
                "detail": str(temporary_cleanup.get(
                    "reason", "战斗结束临时功法清理失败")),
            }
    player.same_qi_value = 0
    enemy.same_qi_value = 0
    passive_rule_runtime.suppression_service.clear()
    return result

func _set_scenario_error(detail: String) -> void:
    outcome_service.set_scenario_error(detail)
