extends "res://tests/support/expanded_technique_test_base.gd"

const PassiveRuleHandlerRegistryScript = preload(
    "res://core/passives/passive_rule_handler_registry.gd")
const PassiveRuleRuntimeScript = preload(
    "res://core/passives/passive_rule_runtime.gd")
const PassiveRuleSourceScript = preload(
    "res://core/passives/passive_rule_source.gd")
const BattleRuleQueryServiceScript = preload(
    "res://core/passives/battle_rule_query_service.gd")
const BattleEffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const EffectValueResolverScript = preload(
    "res://core/effects/effect_value_resolver.gd")


class PreLifeLossProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    var calls: Array[Dictionary] = []
    var battle_rng: RandomNumberGenerator
    var event_service = null

    func behavior_id() -> String:
        return "pre_life_loss_probe"

    func supported_hooks() -> Array[String]:
        return ["pre_life_loss_query"] as Array[String]

    func handle(_hook: String, context, configuration: Dictionary) -> Dictionary:
        var request = context.payload.get("int_query")
        var facts: Dictionary = request.to_dict()
        facts["source_kind"] = context.source.source_kind
        facts["source_instance_key"] = context.source.source_instance_key
        calls.append(facts)
        if bool(configuration.get("mutate_state", false)):
            context.owner.defense += 19
        if bool(configuration.get("advance_rng", false)) \
                and battle_rng != null:
            battle_rng.randi()
        if bool(configuration.get("emit_event", false)) \
                and event_service != null:
            event_service.commit("action_confirmed", {
                "event_token": "pre-life-loss-query-must-not-emit",
                "actor": context.owner,
                "owner": context.owner,
                "action_token": request.action_token,
            })
        if int(configuration.get("fail_on_call", -1)) == calls.size():
            return {"success": false, "reason": "Fake pre life loss failure"}
        if bool(configuration.get("increase", false)):
            return {"success": true, "value": int(request.current_value) + 1}
        if bool(configuration.get("cancel_non_reflection", false)) \
                and not request.reflection_damage:
            return {"success": true, "value": 0}
        var only_type := str(configuration.get("only_damage_type", ""))
        if only_type != "" and only_type != request.damage_type:
            return {"success": true, "value": int(request.current_value)}
        if bool(configuration.get("cancel", false)):
            return {"success": true, "value": 0}
        return {
            "success": true,
            "value": maxi(0, int(request.current_value) \
                - int(configuration.get("prevent", 0))),
        }


class StaticSourceResolver:
    extends RefCounted

    var _catalog = null
    var sources: Array = []

    func _init(values: Array) -> void:
        sources = values.duplicate()

    func collect_sources(context) -> Array:
        if context != null and context.has_source_snapshot:
            return context.source_snapshot.map(func(value):
                return PassiveRuleSourceScript.new().configure(value))
        return sources.duplicate()

    func capture_source_snapshot(context) -> Array:
        return collect_sources(context).map(func(source): return source.to_dict())

    func equipped_inner_skill_entries(_context) -> Array:
        return []


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_normal_true_poison_and_cost_paths()
    _test_reflection_block_and_full_absorption()
    _test_cancel_keeps_absorption_resolution_and_reflection()
    _test_failure_is_atomic_and_query_is_pure()
    _test_multi_segment_reads_latest_state()
    _test_synchronized_preview_and_flush_rollback()
    _test_protocol_order_fingerprints_and_actual_value_consumers()
    _finish("PRE LIFE LOSS INTERVENTION TEST")


func _test_normal_true_poison_and_cost_paths() -> void:
    var fixture := _fixture([_source("item", "fake_guard", 0, {"prevent": 2})])
    var engine = fixture["engine"]
    engine.enemy.life = 100
    engine.enemy.defense = 4
    var normal: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 7, "test", false,
        "pre-normal", "normal", {"direct_attack": true})
    _assert_equal(normal.get("defense_lost", 0), 4,
        "普通伤害先计算防御实际吸收")
    _assert_equal(normal.get("life_loss_before_intervention", 0), 3,
        "查询基值只包含击穿防御后的溢出生命损失")
    _assert_equal(normal.get("life_lost", 0), 1,
        "普通伤害只干预溢出的生命损失")
    _assert_equal(normal.get("life_loss_prevented", 0), 2,
        "结果公开实际阻止量")

    engine.enemy.life = 100
    engine.enemy.defense = 4
    var true_hit: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 6, "test", true,
        "pre-true", "true")
    _assert_equal(true_hit.get("defense_lost", -1), 0,
        "真伤接受生命干预但不减少防御")
    _assert_equal(true_hit.get("life_lost", 0), 4,
        "真伤与普通伤害复用同一生命查询")
    _assert_equal(engine.enemy.defense, 4, "真伤保留防御")

    engine.enemy.life = 100
    engine.enemy.defense = 4
    var poison: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 6, "test", false,
        "pre-poison", "poison")
    _assert_equal(poison.get("defense_lost", -1), 0,
        "毒伤默认仍不受普通防御抵挡")
    _assert_equal(poison.get("life_lost", 0), 4,
        "毒伤进入通用生命写入前查询")

    var calls_before: int = fixture["handler"].calls.size()
    engine.enemy.life = 100
    engine.enemy.defense = 0
    var cost: Dictionary = engine.effect_ports.deal_damage(
        engine.enemy, engine.enemy, 5, "test", true,
        "pre-cost", "true", {"cause": "cost"})
    _assert_equal(cost.get("life_lost", 0), 5,
        "cause=cost 的生命代价不接受保护")
    _assert_equal(fixture["handler"].calls.size(), calls_before,
        "cause=cost 明确跳过 pre_life_loss_query")
    _assert_equal(cost.get("life_loss_intervention_skip_reason"), "cost",
        "代价跳过原因稳定公开")


func _test_reflection_block_and_full_absorption() -> void:
    var fixture := _fixture([_source("inner_skill", "fake_guard", 0, {
        "prevent": 1,
    })])
    var engine = fixture["engine"]
    engine.player.life = 100
    engine.player.defense = 0
    engine.enemy.defense = 4
    engine.enemy.set_reflection_percent(100)
    var hit: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 4, "test", false,
        "pre-reflection", "normal", {"direct_attack": true})
    _assert_equal(hit.get("life_lost", -1), 0,
        "防御完全吸收时不产生生命损失")
    _assert_equal(engine.player.life, 97,
        "反震伤害也经过通用保护后写入生命")
    var reflection_calls: Array = fixture["handler"].calls.filter(
        func(call): return bool(call.get("reflection_damage", false)))
    _assert_equal(reflection_calls.size(), 1, "反震执行一次生命查询")
    _assert_true(not bool(reflection_calls[0].get("direct_attack", true)),
        "反震明确不是敌方直接攻击")

    fixture = _fixture([_source("item", "must_not_run", 0, {
        "increase": true,
    })])
    engine = fixture["engine"]
    engine.effect_ports.begin_action_resolution(
        [engine.player, engine.enemy], {
            "acting_owner_ids": [str(engine.player.owner_id)],
        })
    engine.effect_ports.grant_block_source(
        engine.enemy, engine.player, "unconditional", "测试格挡")
    var blocked: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 9, "test", false,
        "pre-block", "normal", {"direct_attack": true})
    _assert_true(blocked.get("blocked", false), "格挡先取消整个直接攻击段")
    _assert_true(fixture["handler"].calls.is_empty(),
        "格挡成功不执行生命写入前查询")
    engine.effect_ports.abort_action_resolution()

    engine.enemy.defense = 20
    engine.enemy.life = 100
    engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 3, "test", false,
        "pre-absorbed", "normal")
    _assert_true(fixture["handler"].calls.is_empty(),
        "防御完全吸收时不执行生命查询")


func _test_cancel_keeps_absorption_resolution_and_reflection() -> void:
    var fixture := _fixture([_source("technique", "fake_cancel", 0, {
        "cancel_non_reflection": true,
    })])
    var engine = fixture["engine"]
    engine.enemy.life = 100
    engine.enemy.defense = 3
    engine.enemy.set_reflection_percent(100)
    engine.player.life = 100
    engine.player.defense = 0
    var events: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind in ["damage_resolved", "damage_blocked", "reflection_resolved"]:
                events.append({"kind": kind, "values": values.duplicate(true)}))
    var result: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 5, "test", false,
        "pre-cancel", "normal", {"direct_attack": true})
    _assert_equal(result.get("defense_lost", 0), 3,
        "取消生命损失不恢复已经吸收的防御")
    _assert_equal(result.get("life_loss_before_intervention", 0), 2,
        "取消前生命损失保留在结果事实中")
    _assert_equal(result.get("life_lost", -1), 0,
        "生命保护可以取消全部预计生命损失")
    _assert_true(result.get("life_loss_canceled", false),
        "结果明确标记生命损失取消")
    _assert_equal(engine.player.life, 97,
        "生命取消后仍按实际防御减少触发反震")
    _assert_equal(events.filter(
        func(event): return event["kind"] == "damage_blocked").size(), 0,
        "生命取消不伪装成格挡事件")
    var resolved_events: Array = events.filter(
        func(event): return event["kind"] == "damage_resolved")
    _assert_equal(resolved_events.size(), 2,
        "原伤害与反震各提交 damage_resolved")
    _assert_equal(resolved_events[0]["values"].get("life_lost", -1), 0,
        "取消生命损失仍提交 life_lost=0 的 damage_resolved")
    _assert_true(str(result.get("damage_segment_token", "")) != "",
        "结果携带稳定伤害段令牌")


func _test_failure_is_atomic_and_query_is_pure() -> void:
    var fixture := _fixture([_source("item", "fake_impure", 0, {
        "mutate_state": true,
        "advance_rng": true,
        "emit_event": true,
    })])
    fixture["handler"].battle_rng = fixture["engine"].rng
    fixture["handler"].event_service = fixture["engine"] \
        .battle_passive_event_service
    var engine = fixture["engine"]
    engine.enemy.life = 100
    engine.enemy.defense = 3
    var side_before: Dictionary = engine.enemy.capture_passive_query_state()
    var rng_before: int = engine.rng.state
    var events_before: Dictionary = engine.battle_passive_event_service \
        .capture_transaction_state()
    var trigger_before: Dictionary = engine.trigger_queue.capture_runtime_state()
    var failed: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 7, "test", false,
        "pre-failure", "normal")
    _assert_true(not failed.get("success", true),
        "纯查询违规令正式伤害边界失败")
    _assert_equal(engine.enemy.capture_passive_query_state(), side_before,
        "查询失败时生命、防御及被动状态均不改变")
    _assert_equal(engine.rng.state, rng_before, "查询失败不推进 RNG")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        events_before, "查询失败不留下事件或 committed receipt")
    _assert_equal(engine.trigger_queue.capture_runtime_state(), trigger_before,
        "查询失败不写触发历史或结构化日志")
    _assert_true(not fixture["errors"].is_empty() \
        and fixture["errors"][0].contains("boundary=pre_life_loss"),
        "正式边界通过 scenario error 协议报告查询失败")

    fixture = _fixture([_source("item", "fake_increase", 0, {
        "increase": true,
    })])
    engine = fixture["engine"]
    var life_before: int = engine.enemy.life
    failed = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 2, "test")
    _assert_true(not failed.get("success", true),
        "查询不能利用干预 Hook 增加生命损失")
    _assert_equal(engine.enemy.life, life_before,
        "越界结果在生命写入前失败")


func _test_multi_segment_reads_latest_state() -> void:
    var fixture := _fixture([_source("inner_skill", "fake_each_hit", 0, {
        "prevent": 1,
    })])
    var engine = fixture["engine"]
    engine.enemy.life = 20
    engine.enemy.defense = 3
    var first: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 5, "test", false, "multi-1")
    var second: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 5, "test", false, "multi-2")
    _assert_equal(first.get("life_lost", 0), 1,
        "首段按当时防御计算溢出并干预")
    _assert_equal(second.get("life_lost", 0), 4,
        "后段读取首段提交后的最新防御与生命")
    _assert_equal(fixture["handler"].calls.map(
        func(call): return int(call.get("defense_before", -1))), [3, 0],
        "逐段查询事实公开最新 defense_before")
    _assert_equal(fixture["handler"].calls.map(
        func(call): return int(call.get("life_before", -1))), [20, 19],
        "逐段查询事实公开最新 life_before")


func _test_synchronized_preview_and_flush_rollback() -> void:
    var fixture := _fixture([_source("item", "fake_late_failure", 0, {
        "prevent": 1,
        "fail_on_call": 2,
    })])
    var engine = fixture["engine"]
    engine.enemy.life = 30
    engine.enemy.defense = 2
    var side_before: Dictionary = engine.enemy.capture_passive_query_state()
    var event_before: Dictionary = engine.battle_passive_event_service \
        .capture_transaction_state()
    var trigger_before: Dictionary = engine.trigger_queue.capture_runtime_state()
    engine.effect_ports.begin_synchronized_damage([{"actor": engine.player}])
    var preview_one: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 4, "test", false, "sync-1")
    var preview_two: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 4, "test", false, "sync-2")
    _assert_true(preview_one.get("buffered", false) \
        and preview_two.get("buffered", false),
        "同步伤害只写入 shadow 预览")
    _assert_equal(engine.enemy.capture_passive_query_state(), side_before,
        "同步预览不写真实生命、防御或来源状态")
    _assert_true(fixture["handler"].calls.is_empty(),
        "同步预览不提前执行或消费生命保护来源")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        event_before, "同步预览不发送事件或 receipt")
    _assert_equal(engine.trigger_queue.capture_runtime_state(), trigger_before,
        "同步预览不写历史或日志")

    var flushed: Dictionary = engine.effect_ports.flush_synchronized_damage()
    _assert_true(not flushed.get("success", true) \
        and flushed.get("rolled_back", false),
        "同步后段查询失败返回结构化失败并标记回滚")
    _assert_equal(engine.enemy.capture_passive_query_state(), side_before,
        "同步后段失败恢复整次 flush 的生命、防御和被动状态")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        event_before, "同步失败恢复 serial、receipt 和 execution history")
    _assert_equal(engine.trigger_queue.capture_runtime_state(), trigger_before,
        "同步失败恢复触发历史和结构化日志")


func _test_protocol_order_fingerprints_and_actual_value_consumers() -> void:
    var fixture := _fixture([
        _source("inner_skill", "fake_first", 0, {"prevent": 1}),
        _source("item", "fake_second", 1, {"prevent": 2}),
    ])
    var engine = fixture["engine"]
    var context := {
        "actor": engine.player,
        "target": engine.enemy,
        "damage_segment_token": "stable-segment",
        "action_token": "stable-action",
        "action_window_id": "stable-window",
        "source_kind": "technique",
        "source_id": "fake-source",
        "source_instance_key": "technique:fake-source:0",
        "trigger_mode": "direct",
        "cause": "damage",
        "damage_type": "normal",
        "direct_attack": true,
        "reflection_damage": false,
        "synchronized": false,
        "requested_damage": 10,
        "final_damage": 10,
        "defense_before": 2,
        "defense_lost": 2,
        "defense_after": 0,
        "life_before": 100,
        "proposed_life_loss": 8,
        "lethal": false,
    }
    var first = fixture["service"].resolve_pre_life_loss(
        engine.enemy, context)
    var second = fixture["service"].resolve_pre_life_loss(
        engine.enemy, context)
    _assert_equal(first.effective_value, 5,
        "多个中立来源按既有 Invocation 顺序逐步减量")
    _assert_equal(first.modifier_breakdown.map(
        func(entry): return entry["source_kind"]),
        ["inner_skill", "item"], "breakdown 保持稳定来源顺序")
    _assert_equal(first.modifier_breakdown, second.modifier_breakdown,
        "相同事实的 source breakdown 稳定")
    _assert_equal(first.source_fingerprint, second.source_fingerprint,
        "source fingerprint 稳定")
    _assert_equal(first.request_fingerprint, second.request_fingerprint,
        "request fingerprint 不依赖 Object 地址")

    engine.enemy.life = 100
    engine.enemy.defense = 0
    var actual: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 6, "test", false, "actual-read")
    var effect_context = BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "captures": {"damage_results": [actual]},
    })
    var resolver := EffectValueResolverScript.new()
    _assert_equal(resolver.resolve({
        "kind": "capture_actual_life_loss",
        "capture": "damage_results",
    }, effect_context), 3, "ValueSpec 读取干预后的实际 life_lost")
    _assert_true(resolver.condition_met({
        "capture_result_life_lost": "damage_results",
    }, effect_context), "实际生命损失条件读取干预后结果")


func _fixture(sources: Array, seed: int = 120001) -> Dictionary:
    var engine = _engine(seed)
    var handler := PreLifeLossProbeHandler.new()
    var registry = PassiveRuleHandlerRegistryScript.new(false)
    registry.register_handler(handler)
    var runtime = PassiveRuleRuntimeScript.new(
        registry, null, null, null, StaticSourceResolver.new(sources))
    var errors: Array[String] = []
    var service = BattleRuleQueryServiceScript.new(
        runtime, func(message: String): errors.append(message))
    service.use_rng(engine.rng)
    service.use_committed_event_service(engine.battle_passive_event_service)
    engine.player.use_battle_rule_query_service(service)
    engine.enemy.use_battle_rule_query_service(service)
    engine.effect_ports.use_passive_battle_services(
        service, engine.battle_passive_event_service)
    return {
        "engine": engine,
        "handler": handler,
        "runtime": runtime,
        "service": service,
        "errors": errors,
    }


func _source(
        source_kind: String,
        content_id: String,
        order: int,
        configuration: Dictionary):
    return PassiveRuleSourceScript.new().configure({
        "source_kind": source_kind,
        "content_id": content_id,
        "source_instance_key": "%s:test:%s" % [source_kind, content_id],
        "definition": {
            "id": content_id,
            "name": content_id,
            "behaviors": [{
                "id": "pre_life_loss_probe",
                "configuration": configuration.duplicate(true),
            }],
        },
        "behavior_id": "pre_life_loss_probe",
        "behavior_index": 0,
        "configuration": configuration,
        "source_order": order,
    })
