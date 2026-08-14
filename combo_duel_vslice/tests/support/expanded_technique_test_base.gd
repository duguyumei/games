extends SceneTree

const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const TechniqueRepositoryScript = preload("res://core/technique_repository.gd")
const CombatEngineScript = preload("res://core/combat_engine.gd")
const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const QiCardScript = preload("res://core/qi_card.gd")

var failures: Array[String] = []
var assertions := 0
var serial := 0
var tracked_engines: Array = []

func _require_test_mode() -> bool:
    if RuntimeProfileScript.current().is_test():
        return true
    push_error("自动化测试必须显式指定 --launch-mode=test")
    quit(2)
    return false

func _finish(label: String) -> void:
    _dispose_engines()
    if failures.is_empty():
        print("%s PASS: %d assertions" % [label, assertions])
        quit(0)
        return
    for failure in failures:
        push_error("%s FAIL: %s" % [label, failure])
    quit(1)

func _repository():
    var repository = TechniqueRepositoryScript.new()
    _assert_true(repository.load_from_file(), "TechniqueRepository加载正式内容")
    return repository

func _engine(seed_value: int = 1):
    var engine = CombatEngineScript.new()
    tracked_engines.append(engine)
    engine.setup(seed_value, false, [])
    engine.player.hand.clear()
    engine.player.draw_pile.clear()
    engine.player.staging.clear()
    engine.player.discard_pile.clear()
    engine.enemy.hand.clear()
    engine.enemy.draw_pile.clear()
    engine.enemy.staging.clear()
    engine.enemy.discard_pile.clear()
    engine.player.defense = 0
    engine.enemy.defense = 0
    engine.player.life = 100
    engine.enemy.life = 100
    return engine

func _dispose_engines() -> void:
    for engine in tracked_engines:
        engine.battle_passive_timing_bridge.close_battle()
        engine.battle_passive_event_service.close_battle()
        engine.passive_rule_runtime.close_battle_effect_commands()
        engine.effect_ports.use_hand_retrigger_callback(Callable())
        engine.battle_passive_event_service._scenario_error = Callable()
        engine.battle_rule_query_service._scenario_error = Callable()
        engine.passive_rule_runtime._battle_effect_scenario_error = Callable()
        engine.player.use_committed_event_service(null)
        engine.enemy.use_committed_event_service(null)
        engine.player.use_battle_rule_query_service(null)
        engine.enemy.use_battle_rule_query_service(null)
        engine.player.use_status_system(null)
        engine.enemy.use_status_system(null)
        engine.player.use_card_state_lifecycle(null)
        engine.enemy.use_card_state_lifecycle(null)
        engine.player.use_card_reshape_runtime(null)
        engine.enemy.use_card_reshape_runtime(null)
        engine.player.use_card_policies(null, null)
        engine.enemy.use_card_policies(null, null)
        engine.player.use_battle_permission_service(null)
        engine.enemy.use_battle_permission_service(null)
        engine.player.clear_combat_sources()
        engine.enemy.clear_combat_sources()
        engine.status_system.reset()
        engine.status_system.use_effect_ports(null)
        engine.status_system.use_effect_executor(null)
        engine.status_system.use_card_trigger_replay_service(null)
        engine.status_system.use_battle_permission_service(null)
        engine.effect_ports._sides.clear()
        engine.effect_ports._battle_rule_query_service = null
        engine.effect_ports._committed_event_service = null
        engine.effect_ports._round_number_reader = Callable()
        engine.effect_ports._consumable_repository = null
        engine.delayed_effects.clear()
        engine.action_service = null
        engine.round_service = null
        engine.enemy_planning_service = null
        engine.outcome_service = null
        engine.consumable_service = null
        engine.loadout_service = null
        engine.action_resolver = null
        engine.battle_rule_query_service = null
        engine.battle_passive_event_service = null
        engine.battle_passive_timing_bridge = null
        engine.battle_permission_service = null
        engine.passive_rule_runtime = null
        engine.status_system = null
        engine.card_reshape_runtime = null
        engine.effect_executor = null
        engine.effect_ports = null
    tracked_engines.clear()

func _execute(engine, technique_id: String, power: int = 20, captures: Dictionary = {}) -> Dictionary:
    var definition = engine.repository.get_definition(technique_id)
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "power": power,
        "initial_power": power,
        "values": {"technique_value": power, "initial_power": power},
        "hand_result": {"id": "high_card", "contributing": []},
        "played_cards": [],
        "group_snapshot": {
            "played_cards": [], "contributing_cards": [], "extra_cards": [],
            "played_poison_amount": 0, "played_poison_count": 0,
        },
        "captures": captures,
        "technique_id": technique_id,
        "technique_name": definition.display_name,
        "action_token": "test-1-001",
        "source_kind": "technique",
    })
    return engine.effect_executor.execute_all(definition.effects, context)

func _assert_resource_contract(repository, expected: Dictionary) -> void:
    for technique_id in expected:
        var definition = repository.get_definition(technique_id)
        _assert_true(definition != null, "%s资源存在" % technique_id)
        if definition == null:
            continue
        _assert_equal(definition.display_name, expected[technique_id], "%s名称准确" % technique_id)
        _assert_true(not definition.effects.is_empty(), "%s包含可执行效果" % technique_id)
        _assert_true(not definition.semantic_tags.is_empty(), "%s包含AI语义" % technique_id)

func _assert_base_behavior(technique_id: String, expected_defense: int, expected_life_loss: int) -> void:
    var engine = _engine(1000 + assertions)
    var result := _execute(engine, technique_id, 20)
    _assert_true(result.get("success", false) or result.get("pending_choice", false), "%s即时主效果链可执行" % technique_id)
    _assert_equal(engine.player.defense, expected_defense, "%s即时防御主效果" % technique_id)
    _assert_equal(100 - engine.enemy.life, expected_life_loss, "%s即时伤害主效果" % technique_id)

func _card(rank: String, attribute: String = "forest"):
    serial += 1
    var order := 14 if rank == "A" else 13 if rank == "K" else 12 if rank == "Q" else 11 if rank == "J" else int(rank)
    var qi := 12 if rank == "A" else 11 if rank in ["J", "Q", "K"] else int(rank)
    return QiCardScript.new("expanded-%d" % serial, rank, order, qi, attribute, attribute, "expanded-%d" % serial)

func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append(label)

func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])
