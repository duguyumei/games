extends "res://tests/support/expanded_technique_test_base.gd"

const BattleIntQueryCatalogScript = preload(
    "res://core/passives/battle_int_query_catalog.gd")
const BattleRuleQueryServiceScript = preload(
    "res://core/passives/battle_rule_query_service.gd")
const PassiveRuleHandlerRegistryScript = preload(
    "res://core/passives/passive_rule_handler_registry.gd")
const BattleIntQueryModifierHandlerScript = preload(
    "res://core/passives/battle_int_query_modifier_passive_handler.gd")
const PassiveRuleContextScript = preload(
    "res://core/passives/passive_rule_context.gd")
const DefenseRetentionPolicyScript = preload(
    "res://core/defense_retention_policy.gd")
const BattleSideScript = preload("res://core/battle_side.gd")

const LOSS_CAP := "defense_decay_loss_cap"
const KEEP_LAST := "decay_cannot_remove_last_defense"


class FakeQueryResult:
    extends RefCounted

    var success: bool = true
    var hook: String = ""
    var effective_value: int = 0
    var errors: Array[String] = []
    var _values: Dictionary = {}

    func _init(values: Dictionary) -> void:
        _values = values.duplicate(true)
        success = bool(values.get("success", true))
        hook = str(values.get("hook", ""))
        effective_value = int(values.get(
            "effective_value", values.get("base_value", 0)))
        for value in values.get("errors", []):
            errors.append(str(value))

    func to_dict() -> Dictionary:
        var result := _values.duplicate(true)
        result["success"] = success
        result["hook"] = hook
        result["effective_value"] = effective_value
        result["errors"] = errors.duplicate()
        return result


class FailingQueryService:
    extends RefCounted

    var fail_hook: String = ""
    var reports: int = 0

    func resolve_values(values: Dictionary):
        var hook := str(values.get("hook", ""))
        if hook == fail_hook:
            return FakeQueryResult.new({
                "success": false,
                "hook": hook,
                "base_value": int(values.get("base_value", 0)),
                "effective_value": int(values.get("base_value", 0)),
                "errors": ["专项查询失败"],
            })
        return FakeQueryResult.new({
            "success": true,
            "hook": hook,
            "base_value": int(values.get("base_value", 0)),
            "effective_value": int(values.get("base_value", 0)),
            "modifier_breakdown": [],
            "source_breakdown": [],
            "source_fingerprint": "fake-source",
            "fingerprint": "fake-source",
            "request_fingerprint": "fake-request",
            "errors": [],
        })

    func report_failure(_result, _boundary: String) -> void:
        reports += 1


class FakeDefenseRemovePort:
    extends RefCounted

    var calls: int = 0

    func commit(side, amount: int, _context: Dictionary) -> Dictionary:
        calls += 1
        var before := int(side.defense)
        var removed := mini(before, maxi(0, amount))
        side.defense = before - removed
        return {
            "success": true,
            "removed": removed,
            "before": before,
            "after": int(side.defense),
        }


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_catalog_handler_and_content_contracts()
    _test_default_and_formal_content_results()
    _test_duplicate_isolation_equipment_and_suppression()
    _test_pure_plan_failure_and_non_decay_boundary()
    _test_canonical_event_and_round_timing()
    _finish("DEFENSE DECAY POLICY QUERY TEST")


func _test_catalog_handler_and_content_contracts() -> void:
    _assert_equal(
        BattleRuleQueryServiceScript.QUERY_HOOKS,
        BattleIntQueryCatalogScript.HOOKS,
        "BattleRuleQueryService 从唯一整数查询目录读取 Hook")
    _assert_equal(
        PassiveRuleHandlerRegistryScript.BATTLE_INT_QUERY_HOOKS,
        BattleIntQueryCatalogScript.HOOKS,
        "PassiveRuleHandlerRegistry 从同一目录读取 Hook")
    _assert_equal(BattleIntQueryCatalogScript.HOOKS.size(), 16,
        "唯一目录登记十六个正式战斗整数查询")
    _assert_true("defense_decay_max_loss_query" \
        in BattleIntQueryCatalogScript.HOOKS,
        "目录登记自然衰减最大损失查询")
    _assert_true("defense_decay_minimum_remaining_query" \
        in BattleIntQueryCatalogScript.HOOKS,
        "目录登记自然衰减最低剩余查询")
    var registry = PassiveRuleHandlerRegistryScript.new()
    _assert_true(registry.has_handler("battle_int_query_modifier"),
        "Registry 默认注册来源中立战斗整数修正 Handler")
    var handler = BattleIntQueryModifierHandlerScript.new()
    _assert_true(handler.validate_configuration({
        "rules": [{
            "hook": "defense_decay_max_loss_query",
            "operation": "minimum",
            "operand": 25,
        }],
    }).is_empty(), "通用 Handler 接受正式 minimum 配置")
    _assert_true(not handler.validate_configuration({
        "rules": [{
            "hook": "defense_decay_max_loss_query",
            "operation": "minimum",
            "operand": 25.5,
        }],
    }).is_empty(), "operand 严格要求整数")
    var context = PassiveRuleContextScript.new().configure({})
    context.payload = {
        "current_value": 5,
        "metadata": {"cause": "decay", "round_number": 2},
    }
    var operations: Dictionary = handler.handle(
        "defense_decay_max_loss_query", context, {"rules": [
            {"hook": "defense_decay_max_loss_query", "operation": "add", "operand": 3},
            {"hook": "defense_decay_max_loss_query", "operation": "multiply", "operand": 2},
            {"hook": "defense_decay_max_loss_query", "operation": "minimum", "operand": 20},
            {"hook": "defense_decay_max_loss_query", "operation": "maximum", "operand": 18},
            {"hook": "defense_decay_max_loss_query", "operation": "set", "operand": 7,
                "filters": {"cause": "decay"}},
            {"hook": "defense_decay_max_loss_query", "operation": "add", "operand": 99,
                "filters": {"round_number": 3}},
        ]})
    _assert_equal(operations.get("value"), 7,
        "add/multiply/minimum/maximum/set 按配置稳定顺序执行且过滤精确")

    var catalog = _engine(41001).content_catalog
    var cap: Dictionary = catalog.get_by_id("inner_skill", LOSS_CAP)
    var keep: Dictionary = catalog.get_by_id("inner_skill", KEEP_LAST)
    _assert_equal(cap.get("name"), "重岳不崩", "重岳不崩正式 ID 与名称准确")
    _assert_equal(cap.get("status"), "formal", "重岳不崩标记 formal")
    _assert_equal(cap.get("rarity"), "rare", "重岳不崩稀有度为 rare")
    _assert_equal(cap["behaviors"][0]["id"],
        "battle_int_query_modifier", "重岳不崩复用通用 Handler")
    var cap_rule: Dictionary = cap["behaviors"][0]["configuration"][
        "rules"][0]
    _assert_equal(cap_rule.get("hook"), "defense_decay_max_loss_query",
        "重岳不崩只接入最大损失查询")
    _assert_equal(cap_rule.get("operation"), "minimum",
        "重岳不崩使用幂等 minimum 运算")
    _assert_equal(int(cap_rule.get("operand", 0)), 25,
        "重岳不崩数据 operand 为25")
    _assert_equal(keep.get("name"), "孤垒不灭", "孤垒不灭正式 ID 与名称准确")
    _assert_equal(keep.get("status"), "formal", "孤垒不灭标记 formal")
    _assert_equal(keep.get("rarity"), "common", "孤垒不灭稀有度为 common")
    var keep_rule: Dictionary = keep["behaviors"][0]["configuration"][
        "rules"][0]
    _assert_equal(
        keep_rule.get("hook"), "defense_decay_minimum_remaining_query",
        "孤垒不灭只接入最低剩余查询")
    _assert_equal(keep_rule.get("operation"), "maximum",
        "孤垒不灭使用幂等 maximum 运算")
    _assert_equal(int(keep_rule.get("operand", 0)), 1,
        "孤垒不灭数据 operand 为1")


func _test_default_and_formal_content_results() -> void:
    var engine = _decay_engine([], 41002)
    for values in [[100, 50], [3, 1], [1, 0]]:
        var result := _decay(engine, engine.player, int(values[0]))
        _assert_true(result.get("success", false), "默认自然衰减成功")
        _assert_equal(result.get("after"), values[1],
            "默认50%%保留 %d→%d" % [values[0], values[1]])
        _assert_equal(result.get("lost"), values[0] - values[1],
            "默认结果公开实际 lost")

    engine = _decay_engine([LOSS_CAP], 41003)
    var capped := _decay(engine, engine.player, 100)
    _assert_equal(capped.get("proportional_after"), 50,
        "重岳不崩仍先计算默认比例结果")
    _assert_equal(capped.get("proposed_loss"), 50,
        "重岳不崩查询基值为比例阶段预计损失")
    _assert_equal(capped.get("queried_max_loss"), 25,
        "最大损失查询返回25")
    _assert_equal(capped.get("after"), 75, "重岳不崩令100→75")
    _assert_equal(_decay(engine, engine.player, 40).get("after"), 20,
        "原损失不超过25时重岳不崩不改变40→20")

    engine = _decay_engine([KEEP_LAST], 41004)
    var last_one := _decay(engine, engine.player, 1)
    _assert_equal(last_one.get("queried_minimum_remaining"), 1,
        "孤垒不灭最低剩余查询返回1")
    _assert_equal(last_one.get("after"), 1, "孤垒不灭令1→1")
    _assert_equal(_decay(engine, engine.player, 3).get("after"), 1,
        "孤垒不灭保持默认3→1")

    engine = _decay_engine([LOSS_CAP, KEEP_LAST], 41005)
    _assert_equal(_decay(engine, engine.player, 100).get("after"), 75,
        "两门同时装备时100→75")
    _assert_equal(_decay(engine, engine.player, 1).get("after"), 1,
        "两门同时装备时1→1")
    engine.player.defense_retention_sources.append({
        "source_token": "test-retain-all",
        "prevent_decay": true,
    })
    var retained := _decay(engine, engine.player, 100)
    _assert_equal(retained.get("retention_percent"), 100,
        "既有完全保留来源仍决定比例阶段")
    _assert_equal(retained.get("lost"), 0, "100%保留时实际损失为0")


func _test_duplicate_isolation_equipment_and_suppression() -> void:
    var engine = _decay_engine([LOSS_CAP, LOSS_CAP], 41006)
    var duplicate_cap := _decay(engine, engine.player, 100)
    _assert_equal(duplicate_cap.get("after"), 75,
        "两个重岳不崩副本仍只限制为25")
    _assert_equal(duplicate_cap["loss_cap_query"]["source_breakdown"].size(), 2,
        "重复副本仍按两个稳定 Invocation 进入来源明细")
    var first_fingerprint := str(
        duplicate_cap["loss_cap_query"]["request_fingerprint"])
    engine.player.defense = 100
    var repeated_plan: Dictionary = engine.defense_retention_policy.plan_decay(
        engine.player, {"round_number": 3})
    engine.player.defense = 100
    var repeated_plan_2: Dictionary = engine.defense_retention_policy.plan_decay(
        engine.player, {"round_number": 3})
    _assert_equal(
        repeated_plan["loss_cap_query"]["request_fingerprint"],
        repeated_plan_2["loss_cap_query"]["request_fingerprint"],
        "同一状态的自然衰减请求指纹稳定")
    _assert_equal(
        repeated_plan["loss_cap_query"]["source_fingerprint"],
        repeated_plan_2["loss_cap_query"]["source_fingerprint"],
        "同一来源顺序的自然衰减来源指纹稳定")
    _assert_true(first_fingerprint != "", "正式查询公开非空请求指纹")

    engine = _decay_engine([KEEP_LAST, KEEP_LAST], 41007)
    var duplicate_keep := _decay(engine, engine.player, 1)
    _assert_equal(duplicate_keep.get("after"), 1,
        "两个孤垒不灭副本仍只保留最低1")
    _assert_equal(
        duplicate_keep["minimum_remaining_query"]["source_breakdown"].size(),
        2,
        "重复最低剩余来源按稳定 Invocation 公开 breakdown")

    engine = _decay_engine([LOSS_CAP], 41008)
    engine.enemy.equipped_inner_skill_ids.clear()
    _assert_equal(_decay(engine, engine.player, 100).get("after"), 75,
        "玩家装备来源只影响玩家")
    _assert_equal(_decay(engine, engine.enemy, 100).get("after"), 50,
        "敌人未装备时完全不受玩家来源影响")
    engine.player.equipped_inner_skill_ids.clear()
    _assert_equal(_decay(engine, engine.player, 100).get("after"), 50,
        "卸下来源后自然衰减恢复默认")

    engine = _decay_engine([LOSS_CAP], 41009)
    _assert_true(engine.apply_passive_suppression({
        "suppression_id": "decay-cap-suppressed",
        "target_source_kind": "inner_skill",
        "target_instance_key": "inner:player:0:%s" % LOSS_CAP,
        "blocked_hooks": ["defense_decay_max_loss_query"],
        "reason": "专项压制",
    }).get("success", false), "可按正式 Hook 压制自然衰减来源")
    _assert_equal(_decay(engine, engine.player, 100).get("after"), 50,
        "被动压制后重岳不崩不生效")
    _assert_true(engine.remove_passive_suppression("decay-cap-suppressed"),
        "解除自然衰减来源压制成功")
    _assert_equal(_decay(engine, engine.player, 100).get("after"), 75,
        "解除压制后重岳不崩恢复")


func _test_pure_plan_failure_and_non_decay_boundary() -> void:
    var engine = _decay_engine([LOSS_CAP, KEEP_LAST], 41010)
    engine.player.defense = 100
    var side_before: Dictionary = engine.player.capture_passive_query_state()
    var rng_before := int(engine.rng.state)
    var events_before: Dictionary = engine.battle_passive_event_service \
        .capture_transaction_state()
    var plan: Dictionary = engine.defense_retention_policy.plan_decay(
        engine.player, {"round_number": 6})
    _assert_true(plan.get("success", false), "自然衰减纯计划成功")
    _assert_equal(engine.player.capture_passive_query_state(), side_before,
        "纯计划不修改角色、内功或标识状态")
    _assert_equal(int(engine.rng.state), rng_before, "纯计划不推进RNG")
    _assert_equal(
        engine.battle_passive_event_service.capture_transaction_state(),
        events_before,
        "纯计划不发送事件、不追加回执或历史")

    var side = BattleSideScript.new("失败测试", "failure-side")
    side.defense = 17
    var query_service = FailingQueryService.new()
    query_service.fail_hook = "defense_decay_max_loss_query"
    var remove_port = FakeDefenseRemovePort.new()
    var policy = DefenseRetentionPolicyScript.new()
    policy.use_battle_rule_query_service(query_service)
    policy.use_remove_defense_port(Callable(remove_port, "commit"))
    var failed: Dictionary = policy.apply_decay(side, {"round_number": 1})
    _assert_true(not failed.get("success", true), "查询失败返回结构化失败")
    _assert_equal(side.defense, 17, "查询失败时防御保持原值")
    _assert_equal(remove_port.calls, 0, "查询失败不进入防御提交端口")
    _assert_equal(query_service.reports, 1, "查询失败沿用正式 failure 报告边界")

    engine = _decay_engine([LOSS_CAP, KEEP_LAST], 41011)
    engine.player.defense = 4
    var direct: Dictionary = engine.effect_ports.remove_defense(
        engine.player, 0, true, engine.enemy, "effect",
        "direct-zero", "direct_effect")
    _assert_equal(direct.get("removed"), 4,
        "非自然防御减少不读取衰减查询并仍可归零")
    _assert_equal(engine.player.defense, 0,
        "攻击、直接削防等路径不受自然衰减最低剩余保护")


func _test_canonical_event_and_round_timing() -> void:
    var engine = _decay_engine([LOSS_CAP], 41012)
    var events: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind in ["defense_reduced", "damage_resolved", "damage_blocked"]:
                events.append({
                    "kind": kind,
                    "cause": str(values.get("cause", "")),
                    "effective_amount": int(values.get("effective_amount", 0)),
                    "source_kind": str(values.get("source_kind", "")),
                    "source_id": str(values.get("source_id", "")),
                    "round_number": int(values.get("round_number", -1)),
                }))
    engine.enemy.life = 100
    engine.player.set_reflection_percent(100)
    var decayed := _decay(engine, engine.player, 100, 4)
    var decay_events: Array = events.filter(
        func(value): return value["kind"] == "defense_reduced" \
            and value["cause"] == "decay")
    _assert_equal(decay_events.size(), 1,
        "自然衰减实际减少时只发送一次 canonical defense_reduced")
    _assert_equal(decay_events[0]["effective_amount"], 25,
        "defense_reduced 记录干预后的实际衰减25")
    _assert_equal(decay_events[0]["source_kind"], "rule",
        "自然衰减提交使用 rule 来源")
    _assert_equal(decay_events[0]["source_id"], "round_end_defense_decay",
        "自然衰减提交使用稳定规则来源 ID")
    _assert_equal(decay_events[0]["round_number"], 0,
        "统一防御端口写入当前引擎回合号")
    _assert_equal(engine.enemy.life, 100, "自然衰减不触发反震")
    _assert_equal(events.filter(
        func(value): return value["kind"] in [
            "damage_resolved", "damage_blocked"]).size(), 0,
        "自然衰减不进入伤害或攻击取消协议")
    _assert_equal(decayed.get("defense_commit", {}).get("cause"), "decay",
        "衰减结果保留统一防御提交回执")

    events.clear()
    _decay(engine, engine.player, 0, 4)
    _assert_equal(events.filter(
        func(value): return value["kind"] == "defense_reduced").size(), 0,
        "衰减为0时不发送 defense_reduced")

    engine = _decay_engine([LOSS_CAP], 41013)
    engine.player.defense = 100
    engine.enemy.defense = 0
    var results: Array[Dictionary] = engine.round_service.finish_round_end()
    _assert_equal(results[0].get("lost"), 25,
        "回合编排读取策略最终实际 lost")
    var decay_history: Array = engine.timing_system.history.filter(
        func(value): return value["timing"] == "defense_decay_resolved")
    _assert_equal(decay_history.size(), 2,
        "双方衰减各发送一次 defense_decay_resolved")
    _assert_equal(decay_history[0]["metadata"].get("defense_lost"), 25,
        "defense_decay_resolved 公开最终实际 lost")
    var timings: Array = engine.timing_system.history.map(
        func(value): return value["timing"])
    var last_decay_index := timings.rfind("defense_decay_resolved")
    var first_turn_end_index := timings.find("turn_end")
    _assert_true(last_decay_index >= 0 \
        and first_turn_end_index > last_decay_index,
        "双方自然衰减及 resolved 完成后才进入 turn_end")


func _decay_engine(inner_ids: Array, seed_value: int):
    var engine = _engine(seed_value)
    engine.player.equipped_inner_skill_ids.assign(inner_ids)
    engine.enemy.equipped_inner_skill_ids.clear()
    return engine


func _decay(engine, side, before: int, round_number: int = 3) -> Dictionary:
    side.defense = before
    return engine.defense_retention_policy.apply_decay(side, {
        "timing": "round_end_defense_decay",
        "round_number": round_number,
        "actor": side,
        "actors": [engine.player, engine.enemy],
    })
