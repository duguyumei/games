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
const StarterBuildRepositoryScript = preload("res://core/starter_build_repository.gd")
const StarterBuildAssemblerScript = preload("res://core/starter_build_assembler.gd")
const BattleSessionFactoryScript = preload("res://core/battle_session_factory.gd")
const RunSessionScript = preload("res://core/run_session.gd")
const AiSettingsServiceScript = preload("res://core/ai/ai_settings_service.gd")
const NodeRewardServiceScript = preload("res://core/node_reward_service.gd")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")

var content_catalog
var game_log
var starter_build_repository
var starter_build_assembler
var ai_settings_service
var initialized: bool = false
var runtime_profile

func _init(runtime_profile_override = null) -> void:
    runtime_profile = (
        runtime_profile_override
        if runtime_profile_override != null
        else RuntimeProfileScript.current())

func initialize() -> bool:
    if initialized:
        return content_catalog.loaded
    content_catalog = ContentCatalogScript.new(runtime_profile)
    var loaded: bool = content_catalog.load_all()
    game_log = GameLogScript.new()
    starter_build_repository = StarterBuildRepositoryScript.new()
    starter_build_assembler = StarterBuildAssemblerScript.new(content_catalog)
    ai_settings_service = AiSettingsServiceScript.new()
    if loaded:
        starter_build_repository.configure(
            content_catalog.definition("starter_builds"))
    initialized = true
    return loaded

func create_run_session():
    if not initialized:
        initialize()
    var map_generator := MapGeneratorScript.new(
        content_catalog.definition("map_rules") if content_catalog.loaded else {})
    var navigation := MapNavigationServiceScript.new(map_generator)
    var growth := GrowthInventoryScript.new(content_catalog, false)
    var run_state := RunStateScript.new(navigation, growth)
    var node_dispatcher := NodeDispatcherScript.new(
        content_catalog.definition("node_content") if content_catalog.loaded else {})
    var consumables := ConsumableRepositoryScript.new()
    if content_catalog.loaded:
        consumables.configure(content_catalog.definition("consumables"))
    var battle_factory := BattleSessionFactoryScript.new(
        game_log, content_catalog, runtime_profile)
    var reward_service := NodeRewardServiceScript.new(
        content_catalog.definition("node_rewards")
        if content_catalog.loaded else {})
    var session = RunSessionScript.new(
        run_state,
        node_dispatcher,
        game_log,
        consumables,
        content_catalog,
        starter_build_repository,
        starter_build_assembler,
        battle_factory,
        reward_service,
        runtime_profile)
    session.configure_ai_settings_service(ai_settings_service)
    return session
