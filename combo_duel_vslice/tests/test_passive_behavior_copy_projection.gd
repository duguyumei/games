extends "res://tests/support/technique_test_group.gd"

class ProjectionCounterProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    func behavior_id() -> String:
        return "projection_counter_probe"

    func supported_hooks() -> Array[String]:
        return ["action_resolve", "battle_start"] as Array[String]

    func battle_timing_bindings(_configuration: Dictionary) -> Array:
        return [{"hook": "battle_start", "order": 120}]

    func validate_configuration(configuration: Dictionary) -> Array[String]:
        if not configuration.get("amount", 1) is int:
            return ["amount 必须是整数"] as Array[String]
        return []

    func counter_definitions(_configuration: Dictionary) -> Array:
        return [{
            "counter_id": "run_hits", "default_value": 0,
            "minimum": 0, "retention_policy": "while_owned",
        }]

    func battle_counter_definitions(_configuration: Dictionary) -> Array:
        return [{
            "counter_id": "battle_hits", "default_value": 0,
            "minimum": 0, "reset_scope": "battle",
        }]

    func handle(_hook: String, context, configuration: Dictionary) -> Dictionary:
        var amount := int(configuration.get("amount", 1))
        var run_written: Dictionary = context.counter_mutation_port.increment(
            "run_hits", amount)
        if not run_written.get("success", false):
            return run_written
        var battle_written: Dictionary = (
            context.battle_counter_mutation_port.increment(
                "battle_hits", amount))
        if not battle_written.get("success", false):
            return battle_written
        return {
            "success": true,
            "run_hits": int(run_written.get("value", 0)),
            "battle_hits": int(battle_written.get("value", 0)),
            "source_instance_key": str(context.source.source_instance_key),
            "projection": context.source.projection.duplicate(true),
        }

func _initialize() -> void:
    _run_group("passive-behavior-copy-projection", [
        "_test_live_left_projection_identity_and_counters",
        "_test_projection_suppression_and_copy_eligibility",
        "_test_multiple_copiers_keep_independent_counter_addresses",
        "_test_locked_random_projection_is_stable_and_restorable",
        "_test_locked_empty_random_does_not_retry",
        "_test_locked_leftmost_repeat_reuses_existing_plan",
        "_test_projected_battle_timing_uses_existing_bridge",
    ])

func _test_live_left_projection_identity_and_counters() -> void:
    var engine = _projection_engine()
    var actor = engine.player
    _assert_true(actor.configure_inner_skills([
        "projection_target_a", "projection_live_copy"], 2).get(
            "success", false), "实时复制测试配装成功")
    var plan = engine.passive_rule_runtime.build_execution_plan(
        "action_resolve", {"actor": actor})
    _assert_true(plan.is_valid(), "实时左邻投影计划有效")
    _assert_equal(plan.invocations.size(), 3,
        "目标两个行为正常执行，复制者只投影其中一个可复制行为")
    var projected = _projected_invocation(plan)
    _assert_true(projected != null, "计划包含投影 Invocation")
    _assert_equal(projected.source.content_id, "projection_live_copy",
        "投影效果公开来源属于复制者")
    _assert_equal(projected.source.behavior_id, "projection_counter_probe",
        "投影执行目标 Handler")
    _assert_equal(projected.source.projection.get("target_content_id", ""),
        "projection_target_a", "投影元数据保存目标正文身份")
    _assert_equal(projected.source.definition.get("name", ""), "实时复制探针",
        "投影来源名称仍读取复制者定义")
    _assert_equal(projected.source.source_marker_definitions[0].get("id", ""),
        "target_charge", "目标 marker 定义随正文投影")

    var dispatched: Dictionary = engine.passive_rule_runtime.dispatch_event(
        "action_resolve", {"actor": actor}, "mutation")
    _assert_true(dispatched.get("success", false), "原行为和投影行为执行成功")
    var persistent: Dictionary = actor.passive_counter_store.capture_state()
    var battle: Dictionary = actor.battle_passive_counter_store.capture_state()
    _assert_equal(persistent.get("entries", []).size(), 2,
        "原来源与复制者各自拥有持久计数器")
    _assert_equal(battle.get("entries", {}).size(), 2,
        "原来源与复制者各自拥有战斗计数器")
    var projected_entry := _counter_entry(
        persistent.get("entries", []), "projection_live_copy")
    _assert_true(not projected_entry.is_empty(),
        "持久计数状态归复制者内容所有")
    _assert_equal(projected_entry.get("definition_content_id", ""),
        "projection_target_a", "持久状态从目标行为恢复计数器定义")
    _assert_true(str(projected_entry.get(
        "counter_instance_key", "")).contains("projection_target_a"),
        "复制目标进入独立计数器实例地址")

    var saved: Dictionary = actor.passive_counter_store.capture_state()
    actor.passive_counter_store.clear()
    _assert_true(actor.passive_counter_store.replace_state(saved).is_empty(),
        "投影持久计数器可以从绝对状态恢复")
    _assert_equal(actor.passive_counter_store.capture_state(), saved,
        "恢复不会丢失投影定义身份")

    _assert_true(actor.configure_inner_skills([
        "projection_target_b", "projection_live_copy",
        "projection_target_a"], 3).get("success", false),
        "改变内功顺序成功")
    var switched = engine.passive_rule_runtime.build_execution_plan(
        "action_resolve", {"actor": actor})
    var switched_projection = _projected_invocation(switched)
    _assert_equal(switched_projection.source.projection.get(
        "target_content_id", ""), "projection_target_b",
        "实时左邻在下一计划中更换目标")
    _assert_true(switched_projection.source.counter_instance_key.contains(
        "projection_target_b"), "更换目标后使用不同计数器实例地址")

func _test_projection_suppression_and_copy_eligibility() -> void:
    var engine = _projection_engine()
    var actor = engine.player
    actor.configure_inner_skills([
        "projection_target_a", "projection_live_copy"], 2)
    var raw_sources: Array = engine.passive_rule_runtime.collect_sources(
        {"owner": actor})
    var target_key := ""
    var provider_key := ""
    for source in raw_sources:
        if source.content_id == "projection_target_a":
            target_key = source.source_instance_key
        elif source.content_id == "projection_live_copy":
            provider_key = source.source_instance_key
    engine.passive_rule_runtime.suppression_service.apply({
        "suppression_id": "suppress-target",
        "target_instance_key": target_key,
        "blocked_hooks": ["action_resolve"],
    })
    var target_suppressed = engine.passive_rule_runtime.build_execution_plan(
        "action_resolve", {"actor": actor})
    _assert_true(_projected_invocation(target_suppressed) != null,
        "压制目标自身不会压制复制者投影")
    _assert_equal(target_suppressed.invocations.size(), 1,
        "目标全部行为被压制，复制者的可复制行为仍执行")
    engine.passive_rule_runtime.suppression_service.clear()
    engine.passive_rule_runtime.suppression_service.apply({
        "suppression_id": "suppress-provider",
        "target_instance_key": provider_key,
        "blocked_hooks": ["action_resolve"],
    })
    var provider_suppressed = engine.passive_rule_runtime.build_execution_plan(
        "action_resolve", {"actor": actor})
    _assert_true(_projected_invocation(provider_suppressed) == null,
        "压制复制者会阻止投影 Invocation")
    _assert_equal(provider_suppressed.invocations.size(), 2,
        "复制者被压制不影响原目标的两个行为")
    engine.passive_rule_runtime.suppression_service.clear()

    actor.configure_inner_skills([
        "projection_live_copy", "projection_live_copy"], 2)
    var no_chain = engine.passive_rule_runtime.build_execution_plan(
        "action_resolve", {"actor": actor})
    _assert_equal(no_chain.invocations.size(), 0,
        "复制类内功不能成为复制目标或建立复制链")

func _test_multiple_copiers_keep_independent_counter_addresses() -> void:
    var engine = _projection_engine()
    var actor = engine.player
    actor.configure_inner_skills([
        "projection_target_a", "projection_live_copy",
        "projection_target_b", "projection_live_copy"], 4)
    var plan = engine.passive_rule_runtime.build_execution_plan(
        "action_resolve", {"actor": actor})
    _assert_equal(plan.invocations.filter(func(invocation):
        return invocation.source.is_projected()).size(), 2,
        "两个复制者分别建立自己的投影 Invocation")
    _assert_true(engine.passive_rule_runtime.dispatch_event(
        "action_resolve", {"actor": actor}, "mutation").get(
            "success", false), "多复制者执行成功")
    var copied_entries: Array = actor.passive_counter_store.capture_state() \
        .get("entries", []).filter(func(entry): return str(entry.get(
            "content_id", "")) == "projection_live_copy")
    _assert_equal(copied_entries.size(), 2,
        "两个同名复制者各有一份持久计数状态")
    _assert_true(str(copied_entries[0].get("counter_instance_key", "")) \
        != str(copied_entries[1].get("counter_instance_key", "")),
        "同名复制者使用不同副本序号隔离计数器")

func _test_locked_random_projection_is_stable_and_restorable() -> void:
    var engine = _projection_engine()
    var actor = engine.player
    actor.configure_inner_skills([
        "projection_target_a", "projection_target_b",
        "projection_random_copy"], 3)
    var rng := RandomNumberGenerator.new()
    rng.seed = 8341
    var prepared: Dictionary = engine.passive_rule_runtime \
        .prepare_battle_projections([actor], rng)
    _assert_true(prepared.get("success", false), "随机投影准备成功")
    var state: Dictionary = actor.passive_behavior_projection_store \
        .capture_state()
    var rng_after := int(rng.state)
    var first = _projected_invocation(
        engine.passive_rule_runtime.build_execution_plan(
            "action_resolve", {"actor": actor}))
    _assert_true(first != null, "随机锁定目标产生投影")
    var locked_target := str(first.source.projection.get(
        "target_content_id", ""))
    _assert_true(locked_target in [
        "projection_target_a", "projection_target_b"],
        "随机目标来自合法稳定候选")

    for _index in range(3):
        engine.passive_rule_runtime.build_execution_plan(
            "action_resolve", {"actor": actor})
    _assert_equal(actor.passive_behavior_projection_store.capture_state(), state,
        "重复计划、预览式查询不写锁定投影状态")
    _assert_equal(int(rng.state), rng_after,
        "重复计划不会推进战斗 RNG")
    engine.passive_rule_runtime.prepare_battle_projections([actor], rng)
    _assert_equal(int(rng.state), rng_after,
        "重复准备复用锁定记录且不重新随机")

    actor.configure_inner_skills([
        "projection_target_b", "projection_target_a",
        "projection_random_copy"], 3)
    var reordered = _projected_invocation(
        engine.passive_rule_runtime.build_execution_plan(
            "action_resolve", {"actor": actor}))
    _assert_equal(reordered.source.projection.get("target_content_id", ""),
        locked_target, "战斗内换位不会更换随机锁定目标")

    actor.passive_behavior_projection_store.clear()
    _assert_true(actor.passive_behavior_projection_store.replace_state(
        state).is_empty(), "锁定随机目标状态可以恢复")
    var restored = _projected_invocation(
        engine.passive_rule_runtime.build_execution_plan(
            "action_resolve", {"actor": actor}))
    _assert_equal(restored.source.projection.get("target_content_id", ""),
        locked_target, "恢复后不会重掷随机目标")
    var fingerprint: String = engine.passive_rule_runtime.execution_plan_fingerprint(
        engine.passive_rule_runtime.build_execution_plan(
            "action_resolve", {"actor": actor}))
    actor.passive_behavior_projection_store.clear()
    actor.passive_behavior_projection_store.replace_state(state)
    _assert_equal(engine.passive_rule_runtime.execution_plan_fingerprint(
        engine.passive_rule_runtime.build_execution_plan(
            "action_resolve", {"actor": actor})), fingerprint,
        "相同锁定目标产生相同 ExecutionPlan 指纹")

func _test_locked_empty_random_does_not_retry() -> void:
    var engine = _projection_engine()
    var actor = engine.player
    actor.configure_inner_skills(["projection_random_copy"], 1)
    var rng := RandomNumberGenerator.new()
    rng.seed = 25
    _assert_true(engine.passive_rule_runtime.prepare_battle_projections(
        [actor], rng).get("success", false), "无候选随机投影仍完成准备")
    var empty_state: Dictionary = actor.passive_behavior_projection_store \
        .capture_state()
    var rng_after := int(rng.state)
    actor.configure_inner_skills([
        "projection_target_a", "projection_random_copy"], 2)
    engine.passive_rule_runtime.prepare_battle_projections([actor], rng)
    _assert_equal(actor.passive_behavior_projection_store.capture_state(),
        empty_state, "本场无目标记录不会因后来出现候选而重试")
    _assert_equal(int(rng.state), rng_after, "无目标复用不推进 RNG")
    _assert_true(_projected_invocation(
        engine.passive_rule_runtime.build_execution_plan(
            "action_resolve", {"actor": actor})) == null,
        "无目标锁定本场保持不生效")

func _test_locked_leftmost_repeat_reuses_existing_plan() -> void:
    var engine = _projection_engine()
    var actor = engine.player
    actor.configure_inner_skills([
        "projection_repeat", "projection_target_a"], 2)
    var rng := RandomNumberGenerator.new()
    rng.seed = 9
    _assert_true(engine.passive_rule_runtime.prepare_battle_projections(
        [actor], rng).get("success", false), "左侧锁定额外执行准备成功")
    var plan = engine.passive_rule_runtime.build_execution_plan(
        "action_resolve", {"actor": actor})
    var copyable_count := 0
    var uncopyable_count := 0
    for invocation in plan.invocations:
        if invocation.source.content_id != "projection_target_a":
            continue
        if invocation.source.behavior_id == "projection_counter_probe":
            copyable_count += 1
            _assert_equal(invocation.execution_count, 5,
                "空四栏令可复制行为共执行五次")
        elif invocation.source.behavior_id == "battle_effects":
            uncopyable_count += 1
            _assert_equal(invocation.execution_count, 1,
                "不可复制行为不获得额外执行")
    _assert_equal(copyable_count, 5,
        "复用既有 additional_executions 建立固定 Invocation 数")
    _assert_equal(uncopyable_count, 1, "不可复制行为只建立一次 Invocation")
    _assert_true(plan.invocations.all(func(invocation):
        return invocation.execution_count <= 5),
        "额外 Invocation 不递归放大执行次数")

    actor.configure_inner_skills([
        "projection_target_b", "projection_target_a",
        "projection_repeat"], 3)
    var reordered = engine.passive_rule_runtime.build_execution_plan(
        "action_resolve", {"actor": actor})
    var reordered_target_count := 0
    for invocation in reordered.invocations:
        if invocation.source.content_id == "projection_target_a" \
                and invocation.source.behavior_id == "projection_counter_probe":
            reordered_target_count += 1
            _assert_equal(invocation.execution_count, 5,
                "锁定目标换位后仍使用当前实例键获得额外执行")
    _assert_equal(reordered_target_count, 5,
        "内功换位不会把虚位养神的锁定目标变成旧槽位")

func _test_projected_battle_timing_uses_existing_bridge() -> void:
    var engine = _projection_engine()
    var actor = engine.player
    actor.configure_inner_skills([
        "projection_target_a", "projection_live_copy"], 2)
    var assembled: Dictionary = engine.battle_passive_timing_bridge.assemble(
        [engine.player, engine.enemy])
    _assert_true(assembled.get("success", false),
        "现有 BattlePassiveTimingBridge 可以装配投影行为")
    var binding_found := false
    for binding in assembled.get("bindings", []):
        if str(binding.get("hook", "")) == "battle_start" \
                and int(binding.get("order", 0)) == 120:
            binding_found = true
    _assert_true(binding_found, "投影目标的生命周期 order 进入既有绑定表")
    var emitted: Dictionary = engine.timing_system.emit_timing(
        "battle_start", {
            "round_number": 0,
            "actors": [engine.player, engine.enemy],
        })
    _assert_true(emitted.get("success", false), "投影生命周期实际执行成功")
    var history: Array = engine.battle_passive_timing_bridge.execution_history
    _assert_equal(history.size(), 2,
        "原目标与复制者分别沿同一生命周期桥执行一次")
    _assert_true(history.any(func(entry): return str(entry.get(
        "source_instance_key", "")).contains("projection_live_copy")),
        "生命周期历史中的投影来源属于复制者")

func _projection_engine():
    var engine = _engine_with_cards([])
    _assert_true(engine.passive_rule_registry.register_handler(
        ProjectionCounterProbeHandler.new()), "注册投影计数探针 Handler")
    var index: Dictionary = engine.content_catalog._indexes["inner_skill"]
    index["projection_target_a"] = {
        "id": "projection_target_a", "name": "目标甲",
        "marker_definitions": [{
            "id": "target_charge", "name": "目标蓄力",
            "scope": "run", "public": true, "initial_value": 0,
            "forget_policy": "remove",
        }],
        "behaviors": [{
            "id": "projection_counter_probe", "state_key": "probe_state",
            "configuration": {"amount": 1},
        }, {
            "id": "battle_effects", "copyable": false,
            "configuration": {
                "hook": "action_resolve",
                "effects": [{"op": "defense", "amount": 1}],
            },
        }],
    }
    index["projection_target_b"] = {
        "id": "projection_target_b", "name": "目标乙",
        "behaviors": [{
            "id": "projection_counter_probe", "state_key": "probe_state",
            "configuration": {"amount": 2},
        }],
    }
    index["projection_live_copy"] = _projection_definition(
        "projection_live_copy", "实时复制探针", "live_left_adjacent")
    index["projection_random_copy"] = _projection_definition(
        "projection_random_copy", "随机复制探针",
        "battle_locked_random_other")
    index["projection_repeat"] = _projection_definition(
        "projection_repeat", "空位增幅探针",
        "battle_locked_leftmost_repeat")
    return engine

func _projection_definition(
        content_id: String, display_name: String, mode: String) -> Dictionary:
    return {
        "id": content_id,
        "name": display_name,
        "copyable": false,
        "behaviors": [{
            "id": "passive_behavior_projection",
            "copyable": false,
            "configuration": {"mode": mode},
        }],
    }

func _projected_invocation(plan):
    for invocation in plan.invocations:
        if invocation.source.is_projected():
            return invocation
    return null

func _counter_entry(entries: Array, content_id: String) -> Dictionary:
    for entry_value in entries:
        var entry: Dictionary = entry_value
        if str(entry.get("content_id", "")) == content_id:
            return entry
    return {}
