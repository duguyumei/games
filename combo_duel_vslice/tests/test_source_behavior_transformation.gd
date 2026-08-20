extends "res://tests/support/technique_test_group.gd"

const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")
const RunPassiveEventServiceScript = preload(
    "res://core/passives/run_passive_event_service.gd")
const RunPassiveEventContextScript = preload(
    "res://core/passives/run_passive_event_context.gd")
const RunSaveDataScript = preload("res://core/run_save_data.gd")
const RunSessionScript = preload("res://core/run_session.gd")
const BattleSetupServiceScript = preload(
    "res://core/battle_setup_service.gd")

class TransformationProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    func behavior_id() -> String:
        return "transformation_probe"

    func supported_hooks() -> Array[String]:
        return ["battle_completed"] as Array[String]

    func counter_definitions(_configuration: Dictionary) -> Array:
        return [{
            "counter_id": "triggers",
            "default_value": 0,
            "minimum": 0,
            "retention_policy": "while_owned",
        }]

    func handle(
            _hook: String,
            context,
            configuration: Dictionary) -> Dictionary:
        var written: Dictionary = context.counter_mutation_port.increment(
            "triggers", int(configuration.get("amount", 1)))
        if not written.get("success", false):
            return written
        return {
            "success": true,
            "value": int(written.get("value", 0)),
            "source_content_id": str(context.source.content_id),
            "definition_content_id": str(
                context.source.counter_definition_content_id),
            "projection": context.source.projection.duplicate(true),
        }

class TransformationFailureHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    func behavior_id() -> String:
        return "transformation_failure_probe"

    func supported_hooks() -> Array[String]:
        return ["battle_completed"] as Array[String]

    func handle(
            _hook: String,
            _context,
            _configuration: Dictionary) -> Dictionary:
        return {"success": false, "reason": "intentional transformation rollback"}

func _initialize() -> void:
    _run_group("source-behavior-transformation", [
        "_test_progress_and_permanent_projection",
        "_test_no_target_retries_after_reaching_threshold",
        "_test_failure_rolls_back_counter_and_transformation",
        "_test_save_battle_sync_and_reorder_stability",
        "_test_invalid_state_is_rejected",
    ])

func _test_progress_and_permanent_projection() -> void:
    var setup := _setup()
    var growth = setup["growth"]
    growth.learned_inner_skill_ids.assign([
        "transformation_source", "transformation_target_a"])
    growth.equipped_inner_skill_ids.assign([
        "transformation_source", "transformation_target_a"])
    var first := _dispatch(setup, "transform-progress-1")
    _assert_true(first.get("success", false), "第一场完成事件成功")
    _assert_true(growth.source_behavior_transformation_store.capture_state()[
        "records"].is_empty(), "第一点进度不会提前化影")
    _assert_equal(_progress_value(growth), 1, "第一场后进度为1")

    var second := _dispatch(setup, "transform-progress-2")
    _assert_true(second.get("success", false), "第二场完成事件成功")
    var state: Dictionary = growth.source_behavior_transformation_store \
        .capture_state()
    _assert_equal(state["records"].size(), 1, "达到2点时写入一个永久替换")
    _assert_equal(state["records"][0]["target_content_id"],
        "transformation_target_a", "唯一合法目标被选中")
    _assert_equal(_progress_value(growth), 0,
        "化影成功后原进度计数恢复默认值")

    var plan = setup["runtime"].build_execution_plan(
        "battle_completed", {"owner": growth})
    _assert_true(plan.is_valid(), "化影后的执行计划有效")
    _assert_equal(plan.invocations.size(), 2,
        "目标本体与化影来源各执行一份目标正文")
    var transformed = _transformed_invocation(plan)
    _assert_true(transformed != null, "计划包含永久行为投影")
    _assert_equal(transformed.source.content_id, "transformation_source",
        "化影后公开来源仍属于无影藏功自身")
    _assert_equal(transformed.source.behavior_id, "transformation_probe",
        "化影后执行目标 Handler")
    _assert_true(not transformed.source.behavior_copyable,
        "永久化影来源不会再次成为复制目标")

    var third := _dispatch(setup, "transform-progress-3")
    _assert_true(third.get("success", false), "化影后的下一场事件成功")
    var transformed_result := _result_for_content(
        third.get("results", []), "transformation_source")
    _assert_equal(transformed_result.get("source_content_id", ""),
        "transformation_source", "目标效果以原来源身份结算")
    _assert_equal(transformed_result.get("definition_content_id", ""),
        "transformation_target_a", "计数器定义仍来自目标正文")

func _test_no_target_retries_after_reaching_threshold() -> void:
    var setup := _setup()
    var growth = setup["growth"]
    growth.learned_inner_skill_ids.assign(["transformation_source"])
    growth.equipped_inner_skill_ids.assign(["transformation_source"])
    _dispatch(setup, "transform-empty-1")
    var second := _dispatch(setup, "transform-empty-2")
    _assert_true(second.get("success", false), "无合法目标不令事件失败")
    _assert_equal(_progress_value(growth), 2, "无目标时保留封顶2点进度")
    _assert_true(growth.source_behavior_transformation_store.capture_state()[
        "records"].is_empty(), "无目标时不写空替换记录")

    growth.learned_inner_skill_ids.append("transformation_target_a")
    growth.equipped_inner_skill_ids.append("transformation_target_a")
    var third := _dispatch(setup, "transform-empty-3")
    _assert_true(third.get("success", false), "后来出现目标时重新尝试成功")
    _assert_equal(growth.source_behavior_transformation_store.capture_state()[
        "records"].size(), 1, "封顶进度在后续战斗完成时完成化影")

func _test_failure_rolls_back_counter_and_transformation() -> void:
    var setup := _setup()
    var growth = setup["growth"]
    growth.learned_inner_skill_ids.assign([
        "transformation_source", "transformation_target_a",
        "transformation_failure"])
    growth.equipped_inner_skill_ids.assign([
        "transformation_source", "transformation_target_a"])
    _dispatch(setup, "transform-rollback-seed")
    growth.equipped_inner_skill_ids.append("transformation_failure")
    var before: Dictionary = growth.capture_mutation_state()
    var failed := _dispatch(setup, "transform-rollback-fail")
    _assert_true(not failed.get("success", false),
        "化影后的同事件失败向外传播")
    _assert_equal(growth.capture_mutation_state(), before,
        "事件失败同时回滚进度、替换记录与其他成长状态")
    _assert_true(not setup["event_state"][
        "committed_passive_event_tokens"].has("transform-rollback-fail"),
        "失败事件不留下去重令牌")

func _test_save_battle_sync_and_reorder_stability() -> void:
    var setup := _setup()
    var growth = setup["growth"]
    growth.learned_inner_skill_ids.assign([
        "transformation_source", "transformation_target_a"])
    growth.equipped_inner_skill_ids.assign([
        "transformation_source", "transformation_target_a"])
    _dispatch(setup, "transform-roundtrip-1")
    _dispatch(setup, "transform-roundtrip-2")
    var expected: Dictionary = growth.source_behavior_transformation_store \
        .capture_state()

    growth.equipped_inner_skill_ids.assign(["transformation_source"])
    var without_target = setup["runtime"].build_execution_plan(
        "battle_completed", {"owner": growth})
    _assert_true(_transformed_invocation(without_target) != null,
        "目标卸下后永久化影正文仍然存在")
    growth.learned_inner_skill_ids.assign(["transformation_source"])
    growth.source_behavior_transformation_store.clear_unowned(
        growth.learned_inner_skill_ids)
    _assert_equal(growth.source_behavior_transformation_store.capture_state(),
        expected, "只要仍持有来源，目标是否持有不影响化影")

    var session = RunSessionScript.new(
        null, null, null, null, setup["catalog"])
    _assert_true(session.execute({
        "type": "setup_run", "seed": 88173}).success,
        "建立存档往返测试本局")
    _assert_true(session.growth.replace_mutation_state(
        growth.capture_mutation_state()).is_empty(),
        "把化影成长状态装入本局")
    var saved: Dictionary = RunSaveDataScript.new().capture(session).to_dict()
    _assert_equal(saved["growth"]["source_behavior_transformation_state"],
        expected, "Run Save 输出稳定化影记录")
    var restored := RunSaveDataScript.new(saved).restore_session(
        setup["catalog"])
    _assert_true(restored.get("success", false), "含化影记录的存档恢复成功")
    _assert_equal(restored["run_session"].growth \
        .source_behavior_transformation_store.capture_state(), expected,
        "读档后永久化影记录完全一致")

    var side = BattleSideScript.new("化影战斗方", "transform-player")
    side.use_passive_rule_runtime(setup["runtime"])
    var applied := BattleSetupServiceScript.new(setup["catalog"]) \
        .apply_non_deck_progress(side, growth.to_progress_snapshot())
    _assert_true(applied.get("success", false), "化影状态装入战斗工作副本")
    _assert_equal(side.source_behavior_transformation_store.capture_state(),
        expected, "战斗工作副本保留化影记录")
    var returned = BattleSetupServiceScript.new(setup["catalog"]) \
        .capture_progress(side, growth.run_deck)
    _assert_true(returned.has_source_behavior_transformation_state,
        "战果绝对快照携带化影状态")
    _assert_equal(returned.source_behavior_transformation_state, expected,
        "战果快照不重算或丢失化影目标")

func _test_invalid_state_is_rejected() -> void:
    var setup := _setup()
    var store = setup["growth"].source_behavior_transformation_store
    var invalid := {
        "schema_version": 1,
        "records": [{
            "provider_content_id": "transformation_source",
            "provider_content_instance_ordinal": 0,
            "target_content_id": "transformation_target_a",
            "target_behaviors": [{
                "behavior_id": "missing_behavior",
                "behavior_index": 0,
            }],
        }],
    }
    _assert_true(not store.validate_state(invalid).is_empty(),
        "与当前正文不一致的行为描述被拒绝")
    _assert_true(not store.replace_state(invalid).is_empty(),
        "非法恢复不会进入 Store")
    _assert_true(store.capture_state()["records"].is_empty(),
        "非法恢复保持原状态不变")

func _setup() -> Dictionary:
    var engine = _engine_with_cards([])
    var catalog = engine.content_catalog
    _assert_true(catalog.passive_rule_registry.register_handler(
        TransformationProbeHandler.new()), "注册化影目标探针 Handler")
    _assert_true(catalog.passive_rule_registry.register_handler(
        TransformationFailureHandler.new()), "注册化影回滚探针 Handler")
    var index: Dictionary = catalog._indexes["inner_skill"]
    index["transformation_source"] = {
        "id": "transformation_source",
        "name": "无影藏功探针",
        "copyable": false,
        "behaviors": [{
            "id": "source_behavior_transformation",
            "state_key": "transformation_progress",
            "copyable": false,
            "configuration": {"progress_required": 2},
        }],
    }
    index["transformation_target_a"] = {
        "id": "transformation_target_a",
        "name": "化影目标甲",
        "behaviors": [{
            "id": "transformation_probe",
            "state_key": "target_probe",
            "configuration": {"amount": 1},
        }],
    }
    index["transformation_failure"] = {
        "id": "transformation_failure",
        "name": "化影失败探针",
        "copyable": false,
        "behaviors": [{
            "id": "transformation_failure_probe",
            "copyable": false,
            "configuration": {},
        }],
    }
    var runtime = engine.passive_rule_runtime
    var mutation = RunMutationServiceScript.new(
        catalog.run_effect_registry, catalog)
    var events = RunPassiveEventServiceScript.new(runtime, mutation)
    var growth = GrowthInventoryScript.new(catalog, false)
    return {
        "engine": engine,
        "catalog": catalog,
        "runtime": runtime,
        "mutation": mutation,
        "events": events,
        "growth": growth,
        "event_state": {"committed_passive_event_tokens": []},
    }

func _dispatch(setup: Dictionary, token: String) -> Dictionary:
    return setup["events"].dispatch(
        RunPassiveEventContextScript.new().configure({
            "hook": "battle_completed",
            "owner": setup["growth"],
            "run_seed": 4281,
            "act": 1,
            "node_id": "battle_probe",
            "outcome": "player_victory",
            "transaction_token": token,
        }),
        setup["growth"],
        setup["event_state"])

func _progress_value(growth) -> int:
    for entry_value in growth.passive_counter_store.capture_state().get(
            "entries", []):
        var entry: Dictionary = entry_value
        if str(entry.get("content_id", "")) == "transformation_source" \
                and str(entry.get("counter_id", "")) == "progress":
            return int(entry.get("value", 0))
    return 0

func _transformed_invocation(plan):
    for invocation in plan.invocations:
        if str(invocation.source.projection.get(
                "projection_kind", "")) == "source_behavior_transformation":
            return invocation
    return null

func _result_for_content(values: Array, content_id: String) -> Dictionary:
    for entry_value in values:
        var entry: Dictionary = entry_value
        if str(entry.get("content_id", "")) == content_id:
            return entry.get("result", {}).duplicate(true)
    return {}
