class_name GameCompositionRoot
extends RefCounted

const ContentCatalogScript = preload("res://core/content_catalog.gd")
const GameLogScript = preload("res://core/game_log.gd")
const MapGeneratorScript = preload("res://core/map_generator.gd")
const MapNavigationServiceScript = preload("res://core/map_navigation_service.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const RunStateScript = preload("res://core/run_state.gd")
const NodeDispatcherScript = preload("res://core/node_dispatcher.gd")
const ConsumableRepositoryScript = preload("res://core/consumable_repository.gd")
const EnemyRepositoryScript = preload("res://core/enemy_repository.gd")
const StarterBuildRepositoryScript = preload("res://core/starter_build_repository.gd")
const StarterBuildAssemblerScript = preload("res://core/starter_build_assembler.gd")
const BattleSessionFactoryScript = preload("res://core/battle_session_factory.gd")
const RunSessionScript = preload("res://core/run_session.gd")
const AiSettingsServiceScript = preload("res://core/ai/ai_settings_service.gd")
const NodeRewardServiceScript = preload("res://core/node_reward_service.gd")
const RunEffectHandlerRegistryScript = preload(
    "res://core/run_effects/run_effect_handler_registry.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")
const ConsumableEffectHandlerRegistryScript = preload(
    "res://core/consumables/consumable_effect_handler_registry.gd")
const ConsumableUseServiceScript = preload(
    "res://core/consumables/consumable_use_service.gd")
const ContentValidatorScript = preload("res://core/content_validator.gd")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const NodeInteractionHandlerRegistryScript = preload(
    "res://core/node_interactions/node_interaction_handler_registry.gd")
const NodeInteractionServiceScript = preload(
    "res://core/node_interactions/node_interaction_service.gd")

var content_catalog: ContentCatalog
var game_log: StructuredGameLog
var starter_build_repository: StarterBuildRepository
var starter_build_assembler: StarterBuildAssembler
var ai_settings_service: AiSettingsService
var initialized: bool = false
var runtime_profile: RuntimeProfile
var enemy_repository
var run_effect_registry
var run_mutation_service
var consumable_effect_registry
var consumable_use_service
var node_interaction_registry
var node_interaction_service

func _init(runtime_profile_override: RuntimeProfile = null) -> void:
    runtime_profile = (
        runtime_profile_override
        if runtime_profile_override != null
        else RuntimeProfileScript.current())

## 加载内容并装配共享服务。
##
## 返回内容是否全部通过校验。内容不完整时不静默降级：`create_run_session()`
## 会拒绝创建会话，调用方必须读取 `content_errors()` 并向上报告。
func initialize() -> bool:
    if initialized:
        return content_catalog.loaded
    run_effect_registry = RunEffectHandlerRegistryScript.new()
    run_mutation_service = RunMutationServiceScript.new(run_effect_registry)
    consumable_effect_registry = ConsumableEffectHandlerRegistryScript.new()
    node_interaction_registry = NodeInteractionHandlerRegistryScript.new()
    content_catalog = ContentCatalogScript.new(
        runtime_profile, null, run_effect_registry, null,
        consumable_effect_registry, node_interaction_registry)
    var loaded: bool = content_catalog.load_all()
    run_mutation_service.content_catalog = content_catalog
    node_interaction_service = NodeInteractionServiceScript.new(
        node_interaction_registry, run_mutation_service, content_catalog)
    consumable_use_service = ConsumableUseServiceScript.new(
        consumable_effect_registry,
        content_catalog,
        ContentValidatorScript.HAND_IDS,
        ContentValidatorScript.POOL_IDS)
    game_log = GameLogScript.new()
    enemy_repository = EnemyRepositoryScript.new(content_catalog)
    if loaded:
        enemy_repository.configure(content_catalog.definition("enemies"))
        content_catalog.enemy_repository_ref = weakref(enemy_repository)
    starter_build_repository = StarterBuildRepositoryScript.new()
    starter_build_assembler = StarterBuildAssemblerScript.new(content_catalog)
    ai_settings_service = AiSettingsServiceScript.new()
    if loaded:
        starter_build_repository.configure(
            content_catalog.definition("starter_builds"))
    else:
        push_error("组合根内容加载失败，拒绝进入本局：%s" % ", ".join(content_catalog.errors))
    initialized = true
    return loaded

## 内容校验错误列表。`initialize()` 返回 false 时由调用方读取并展示。
func content_errors() -> Array[String]:
    if content_catalog == null:
        return ["组合根尚未初始化"] as Array[String]
    return content_catalog.errors

## 装配一个本局会话。
##
## 内容未通过校验时返回 null 而不是带空定义的会话：带空定义运行会让缺失内容
## 表现为静默的默认值，而不是可定位的失败。
func create_run_session() -> RunSession:
    if not initialized:
        initialize()
    if not content_catalog.loaded:
        push_error("内容未通过校验，拒绝创建本局会话：%s" % ", ".join(content_catalog.errors))
        return null
    var map_generator := MapGeneratorScript.new(
        content_catalog.definition("map_rules"))
    var navigation := MapNavigationServiceScript.new(map_generator)
    var growth := GrowthInventoryScript.new(content_catalog, false)
    var run_state := RunStateScript.new(navigation, growth)
    var node_dispatcher := NodeDispatcherScript.new(
        content_catalog.definition("node_content"))
    var consumables := ConsumableRepositoryScript.new()
    consumables.configure(content_catalog.definition("consumables"))
    var battle_factory := BattleSessionFactoryScript.new(
        game_log, content_catalog, runtime_profile)
    var reward_service := NodeRewardServiceScript.new(
        content_catalog.definition("node_rewards"),
        run_mutation_service)
    var session := RunSessionScript.new(
        run_state,
        node_dispatcher,
        game_log,
        consumables,
        content_catalog,
        starter_build_repository,
        starter_build_assembler,
        battle_factory,
        reward_service,
        runtime_profile,
        consumable_use_service,
        node_interaction_service)
    session.configure_ai_settings_service(ai_settings_service)
    return session
