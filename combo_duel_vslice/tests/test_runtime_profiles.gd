extends SceneTree

const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const GameCompositionRootScript = preload("res://core/game_composition_root.gd")
const AiProviderFactoryScript = preload("res://core/ai/providers/ai_provider_factory.gd")
const MockAiProviderScript = preload("res://core/ai/providers/mock_ai_provider.gd")

var failures: Array[String] = []
var assertions: int = 0

func _initialize() -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    _test_mode_capability_matrix()
    _test_profile_content_dependencies()
    _test_production_rejects_debug_resources()
    _test_composition_root_injects_mode()
    if failures.is_empty():
        print("RUNTIME PROFILE TEST PASS: %d assertions" % assertions)
        quit(0)
        return
    for failure in failures:
        push_error("RUNTIME PROFILE TEST FAIL: %s" % failure)
    quit(1)

func _test_mode_capability_matrix() -> void:
    var production = RuntimeProfileScript.production()
    var development = RuntimeProfileScript.development()
    var test_profile = RuntimeProfileScript.test()
    _assert_equal(
        RuntimeProfileScript.from_user_arguments(PackedStringArray()).mode_name(),
        "production",
        "无启动参数默认进入 production")
    _assert_true(not production.allows_debug_content(), "production 禁止调试内容")
    _assert_true(not production.allows_debug_menu(), "production 不装配调试菜单")
    _assert_true(development.allows_debug_content(), "development 可显式装配调试内容")
    _assert_true(development.allows_fast_entry(), "development 可开放快速入口")
    _assert_true(test_profile.allows_debug_content(), "test 可显式装配测试夹具")
    _assert_true(test_profile.uses_fixed_seed(), "test 使用固定种子")
    _assert_true(test_profile.uses_fixed_card_order(), "test 使用固定牌序")
    _assert_equal(test_profile.ai_provider_kind(), "mock", "test 选择 Mock Provider")
    _assert_equal(production.ai_provider_kind(), "remote", "production 不装配 Mock Provider")
    _assert_true(
        not production.allows_resource_path("res://core/ai/providers/mock_ai_provider.gd"),
        "production 资源边界拒绝 Mock Provider")
    _assert_equal(production.enemy_entry_kind(), "formal", "production 使用正式敌人入口")

func _test_profile_content_dependencies() -> void:
    var production_catalog = ContentCatalogScript.new(
        RuntimeProfileScript.production())
    _assert_true(
        production_catalog.load_all(),
        "production 内容目录有效：%s" % str(production_catalog.errors))
    _assert_equal(
        production_catalog.path_for("sequences"),
        "res://data/production_sequences.json",
        "production 不引用纵切固定牌序")
    _assert_equal(
        production_catalog.path_for("scripted_battle"),
        "res://data/production_enemy_entry.json",
        "production 使用正式敌人内容入口")
    _assert_true(
        production_catalog.definition("sequences")["high_card"].is_empty(),
        "production 合法装配空正式功法序列")
    _assert_true(
        production_catalog.definition("inner_skills")["inner_skills"].is_empty(),
        "production 内容目录未装配调试内功")

    for profile in [RuntimeProfileScript.development(), RuntimeProfileScript.test()]:
        var catalog = ContentCatalogScript.new(profile)
        _assert_true(catalog.load_all(), "%s 内容目录有效" % profile.mode_name())
        _assert_equal(
            catalog.path_for("sequences"),
            "res://data/vertical_slice_sequences.json",
            "%s 显式引用纵切牌序" % profile.mode_name())
        _assert_equal(
            catalog.path_for("scripted_battle"),
            "res://data/scripted_battle.json",
            "%s 显式引用脚本敌人" % profile.mode_name())

    var provider = AiProviderFactoryScript.create({
        "kind": RuntimeProfileScript.test().ai_provider_kind(),
        "auto_complete": false,
    })
    _assert_true(provider.get_script() == MockAiProviderScript, "test 工厂装配 Mock Provider")
    provider.queue_free()

func _test_production_rejects_debug_resources() -> void:
    var production = RuntimeProfileScript.production()
    var bad_catalog = ContentCatalogScript.new(production)
    _assert_true(
        not bad_catalog.load_all({
            "sequences": "res://data/vertical_slice_sequences.json",
        }),
        "production 内容校验拒绝纵切牌序")
    _assert_true(
        "禁止引用调试资源" in "\n".join(bad_catalog.errors),
        "production 内容校验报告明确的模式边界错误")

    var root = GameCompositionRootScript.new(production)
    _assert_true(root.initialize(), "production 组合根可使用正式内容初始化")
    var battle_session: BattleSession = root.create_run_session().create_battle_session()
    _assert_true(
        not battle_session.setup_battle({
            "content_seed": 2308,
            "battle": {
                "entry_kind": "scripted",
                "scenario_path": "res://data/scripted_battle.json",
                "use_enemy_ai": true,
            },
        }),
        "production 战斗工厂拒绝脚本敌人资源")

func _test_composition_root_injects_mode() -> void:
    for profile in [
            RuntimeProfileScript.production(),
            RuntimeProfileScript.development(),
            RuntimeProfileScript.test()]:
        var root = GameCompositionRootScript.new(profile)
        _assert_true(root.initialize(), "%s 组合根初始化" % profile.mode_name())
        var session: RunSession = root.create_run_session()
        _assert_true(
            session.runtime_profile == profile,
            "%s 由组合根注入本局会话" % profile.mode_name())
        _assert_true(
            session._battle_session_factory.runtime_profile == profile,
            "%s 由组合根注入战斗会话工厂" % profile.mode_name())

    var test_profile = RuntimeProfileScript.test()
    var test_root = GameCompositionRootScript.new(test_profile)
    _assert_true(test_root.initialize(), "test 组合根初始化")
    var test_session = test_root.create_run_session()
    var setup := test_session.execute({
        "type": "setup_run",
        "starter_build_id": "standard_52",
    })
    _assert_true(setup.success, "test 模式建立本局")
    _assert_equal(
        setup.payload_value("seed"),
        RuntimeProfileScript.TEST_SEED,
        "test 强制固定种子")

func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append("%s：期望为 true" % label)
