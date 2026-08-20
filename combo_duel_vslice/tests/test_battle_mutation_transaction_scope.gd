extends "res://tests/support/expanded_technique_test_base.gd"

const ScopeServiceScript = preload(
    "res://core/battle_mutation_transaction_scope_service.gd")
const RuntimeTransactionScript = preload(
    "res://core/battle_runtime_mutation_transaction.gd")


class StateProbe:
    extends RefCounted

    var value: int = 0
    var capture_calls: int = 0
    var restore_calls: int = 0

    func capture_transaction_state(_options: Dictionary = {}) -> Dictionary:
        capture_calls += 1
        return {"value": value}

    func restore_transaction_state(state: Dictionary) -> void:
        restore_calls += 1
        value = int(state.get("value", value))


class TriggerProbe:
    extends RefCounted

    var value: int = 0
    var capture_calls: int = 0
    var restore_calls: int = 0

    func capture_runtime_state() -> Dictionary:
        capture_calls += 1
        return {"value": value}

    func restore_runtime_state(state: Dictionary) -> void:
        restore_calls += 1
        value = int(state.get("value", value))


class EventProbe:
    extends RefCounted

    var value: int = 0
    var capture_calls: int = 0
    var restore_calls: int = 0
    var begin_calls: int = 0
    var commit_calls: int = 0
    var rollback_calls: int = 0

    func capture_transaction_state() -> Dictionary:
        capture_calls += 1
        return {"value": value}

    func restore_transaction_state(state: Dictionary) -> void:
        restore_calls += 1
        value = int(state.get("value", value))

    func begin_publication_transaction() -> void:
        begin_calls += 1

    func commit_publication_transaction() -> void:
        commit_calls += 1

    func rollback_publication_transaction() -> void:
        rollback_calls += 1


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_nested_scopes_capture_and_publish_once()
    _test_nested_rollback_marks_root_and_restores_again_at_close()
    _test_effect_executor_joins_existing_root()
    _test_damage_segment_joins_existing_root()
    _test_choice_keeps_one_root_until_resume()
    _test_same_qi_participant_restores_with_root()
    _test_public_mutation_ports_propagate_rollback_only_commit()
    _finish("BATTLE MUTATION TRANSACTION SCOPE TEST")


func _test_nested_scopes_capture_and_publish_once() -> void:
    var side = StateProbe.new()
    var participant = StateProbe.new()
    var events = EventProbe.new()
    var trigger = TriggerProbe.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = 41001
    var scope_service = ScopeServiceScript.new().configure(
        [side], events, trigger, rng, [participant])

    var root: Dictionary = scope_service.begin()
    var joined: Dictionary = scope_service.begin([participant])
    _assert_equal(side.capture_calls, 1, "嵌套作用域只捕获一次战斗方")
    _assert_equal(participant.capture_calls, 1, "嵌套作用域只捕获一次额外参与者")
    _assert_equal(events.capture_calls, 1, "嵌套作用域只捕获一次 committed 状态")
    _assert_equal(trigger.capture_calls, 1, "嵌套作用域只捕获一次触发队列")
    _assert_equal(events.begin_calls, 1, "嵌套作用域只建立一次 publication")

    var joined_commit: Dictionary = RuntimeTransactionScript.commit(joined)
    _assert_true(joined_commit.get("success", false), "内层作用域可正常加入并退出")
    _assert_true(scope_service.has_active_transaction(), "内层提交不关闭根事务")
    _assert_equal(events.commit_calls, 0, "内层提交不发布 committed 事件")
    var root_commit: Dictionary = RuntimeTransactionScript.commit(root)
    _assert_true(root_commit.get("success", false), "根事务最终提交成功")
    _assert_equal(events.commit_calls, 1, "整条嵌套链只提交一次 publication")
    _assert_equal(scope_service.diagnostics(), {
        "active": false,
        "open_scope_count": 0,
        "root_begin_count": 1,
        "joined_begin_count": 1,
        "root_commit_count": 1,
        "root_rollback_count": 0,
    }, "事务诊断准确记录一次根事务和一次加入")


func _test_nested_rollback_marks_root_and_restores_again_at_close() -> void:
    var side = StateProbe.new()
    side.value = 7
    var participant = StateProbe.new()
    participant.value = 11
    var events = EventProbe.new()
    events.value = 13
    var trigger = TriggerProbe.new()
    trigger.value = 17
    var rng := RandomNumberGenerator.new()
    rng.seed = 41002
    var rng_before := int(rng.state)
    var scope_service = ScopeServiceScript.new().configure(
        [side], events, trigger, rng, [participant])

    var root: Dictionary = scope_service.begin()
    var joined: Dictionary = scope_service.begin()
    side.value = 70
    participant.value = 110
    events.value = 130
    trigger.value = 170
    rng.randi()
    _assert_true(RuntimeTransactionScript.rollback(joined), "内层可请求整链回滚")
    _assert_equal(side.value, 7, "内层回滚立即恢复根战斗方快照")
    _assert_equal(participant.value, 11, "内层回滚立即恢复根参与者快照")
    _assert_equal(events.value, 13, "内层回滚立即恢复 committed 状态")
    _assert_equal(trigger.value, 17, "内层回滚立即恢复触发队列")
    _assert_equal(int(rng.state), rng_before, "内层回滚立即恢复战斗 RNG")

    # 模拟尚未退出的外层调用栈在看到失败前又做了一次写入。根收口必须
    # 再次恢复同一快照，不能只依赖内层回滚时的第一次恢复。
    side.value = 99
    participant.value = 199
    var root_commit: Dictionary = RuntimeTransactionScript.commit(root)
    _assert_true(not root_commit.get("success", true), "rollback-only 根事务拒绝提交")
    _assert_true(root_commit.get("rollback_only", false), "失败结果公开 rollback-only")
    _assert_equal(side.value, 7, "根收口再次恢复内层失败后的残余写入")
    _assert_equal(participant.value, 11, "根收口再次恢复参与者残余写入")
    _assert_equal(events.commit_calls, 0, "rollback-only 链不会发布 committed 事件")
    _assert_equal(events.rollback_calls, 1,
        "根收口二次恢复不会重复回滚 publication 事务")
    _assert_equal(scope_service.diagnostics().get("root_rollback_count"), 1,
        "重复恢复仍只统计一次根回滚")


func _test_effect_executor_joins_existing_root() -> void:
    var engine = _engine(41003)
    var scope_service = engine.battle_mutation_scope_service
    scope_service.reset_diagnostics()
    var root: Dictionary = scope_service.begin()
    var result: Dictionary = engine.effect_executor.execute_all(
        [{"op": "defense", "amount": 6}],
        _effect_context(engine, "scope-effect"))
    _assert_true(result.get("success", false), "根事务内的 EffectExecutor 正常执行")
    _assert_equal(engine.player.defense, 6, "加入事务的效果正常写入")
    var during: Dictionary = scope_service.diagnostics()
    _assert_equal(during.get("root_begin_count"), 1,
        "EffectExecutor 不重复建立完整根事务")
    _assert_true(int(during.get("joined_begin_count", 0)) >= 1,
        "EffectExecutor 的效果边界加入现有根事务")
    _assert_equal(during.get("root_commit_count"), 0,
        "EffectExecutor 内层完成不提前提交根事务")
    _assert_true(RuntimeTransactionScript.commit(root).get("success", false),
        "外层根事务最终提交")
    _assert_equal(scope_service.diagnostics().get("root_commit_count"), 1,
        "完整效果链只提交一次根事务")


func _test_damage_segment_joins_existing_root() -> void:
    var engine = _engine(41006)
    var scope_service = engine.battle_mutation_scope_service
    scope_service.reset_diagnostics()
    var root: Dictionary = scope_service.begin()
    var damaged: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 5, "transaction_probe", false,
        "scope-damage", "normal", {"direct_attack": true})
    _assert_true(damaged.get("success", false), "伤害段在现有根事务内正常结算")
    _assert_equal(engine.enemy.life, 95, "加入事务的伤害写入正常生效")
    var during: Dictionary = scope_service.diagnostics()
    _assert_equal(during.get("root_begin_count"), 1,
        "伤害段不再手工建立第二份完整快照")
    _assert_true(int(during.get("joined_begin_count", 0)) >= 1,
        "伤害段以加入作用域保留自己的失败边界")
    _assert_true(RuntimeTransactionScript.commit(root).get("success", false),
        "包含伤害段的根事务最终提交")
    _assert_equal(scope_service.diagnostics().get("root_commit_count"), 1,
        "伤害段与外层只发布一次根事务")


func _test_choice_keeps_one_root_until_resume() -> void:
    var engine = _engine(41004)
    var card = _card("5", "wind")
    var reserve = _card("8", "fire")
    engine.player.hand.append(card)
    engine.player.hand.append(reserve)
    var scope_service = engine.battle_mutation_scope_service
    scope_service.reset_diagnostics()
    var context = _effect_context(engine, "scope-choice")
    var started: Dictionary = engine.effect_executor.execute_all([{
        "op": "select_cards",
        "choice_id": "scope_wait",
        "chooser": "actor",
        "minimum": 1,
        "maximum": 1,
        "insufficient_policy": "fail",
        "query": {
            "side": "actor", "zone": "hand", "order": "zone",
            "filters": {"card_kind": "normal"},
        },
        "capture": "selected",
    }], context)
    _assert_true(started.get("pending_choice", false), "效果事务可暂停等待选择")
    _assert_true(scope_service.has_active_transaction(), "等待选择期间保留根事务")
    _assert_equal(scope_service.diagnostics().get("root_begin_count"), 1,
        "等待前只建立一次根事务")
    _assert_equal(scope_service.diagnostics().get("root_commit_count"), 0,
        "等待选择时不提交根事务")

    var request: Dictionary = started.get("choice_request", {})
    var resumed: Dictionary = engine.effect_executor.resume(
        started.get("_continuation"), str(request.get("request_id", "")),
        [str(card.id)])
    _assert_true(resumed.get("success", false), "合法选择恢复同一效果事务")
    _assert_equal(context.captures.get("selected", []), [card],
        "恢复后选择结果只提交一次")
    _assert_true(not scope_service.has_active_transaction(), "恢复完成后关闭根事务")
    _assert_equal(scope_service.diagnostics().get("root_begin_count"), 1,
        "恢复不重新建立根事务")
    _assert_equal(scope_service.diagnostics().get("root_commit_count"), 1,
        "选择前后整条效果链只提交一次")


func _test_same_qi_participant_restores_with_root() -> void:
    var engine = _engine(41005)
    engine.player.hand.append(_card("6", "forest"))
    var scope_service = engine.battle_mutation_scope_service
    scope_service.reset_diagnostics()
    var root: Dictionary = scope_service.begin()
    var joined: Dictionary = scope_service.begin(
        [engine.same_qi_gauge_service])
    var write: Dictionary = engine.same_qi_gauge_service.apply_write(
        engine.player, "add", 1, "事务探针", "scope-same-qi", {
            "action_token": "scope-same-qi",
            "source_category": "effect",
        })
    _assert_true(write.get("success", false), "同气参与者在事务内完成写入")
    _assert_equal(engine.player.same_qi_value, 1, "同气值已临时改变")
    _assert_equal(engine.same_qi_gauge_service._receipts.size(), 1,
        "同气幂等 receipt 已临时写入")
    RuntimeTransactionScript.rollback(joined)
    _assert_equal(engine.player.same_qi_value, 0, "回滚恢复同气槽数值")
    _assert_true(engine.same_qi_gauge_service._receipts.is_empty(),
        "回滚恢复同气参与者 receipt")
    _assert_true(not RuntimeTransactionScript.commit(root).get("success", true),
        "同气内层回滚令根事务无法提交")


func _test_public_mutation_ports_propagate_rollback_only_commit() -> void:
    var engine = _engine(41007)
    var scope_service = engine.battle_mutation_scope_service

    var resource_root: Dictionary = scope_service.begin()
    var resource_joined: Dictionary = scope_service.begin()
    RuntimeTransactionScript.rollback(resource_joined)
    var same_qi_result: Dictionary = engine.effect_ports.write_same_qi(
        engine.player, "add", 1, "事务探针", "rollback-only-same-qi",
        "effect", "rollback-only-same-qi")
    _assert_true(not same_qi_result.get("success", true),
        "资源写入口不会把 rollback-only 提交误报为成功")
    _assert_true(same_qi_result.get("rolled_back", false),
        "资源写入口公开事务已经回滚")
    _assert_true(not RuntimeTransactionScript.commit(resource_root).get(
        "success", true), "资源根事务按 rollback-only 收口")
    _assert_equal(engine.player.same_qi_value, 0,
        "资源根收口清除失败返回前的残余写入")

    var card = _card("7", "wind")
    engine.player.hand = [card]
    var card_root: Dictionary = scope_service.begin()
    var card_joined: Dictionary = scope_service.begin()
    RuntimeTransactionScript.rollback(card_joined)
    var discard_result: Dictionary = \
        engine.player.card_zone_service.random_discard_result(
            engine.player, 1, engine.rng, {
                "source_kind": "rule",
                "source_id": "rollback_only_probe",
                "source_name": "事务探针",
                "source_instance_key": "rule:rollback_only_probe",
                "trigger_mode": "direct",
            })
    _assert_true(not discard_result.get("success", true),
        "牌区写入口不会把 rollback-only 提交误报为成功")
    _assert_true(discard_result.get("rolled_back", false),
        "牌区写入口公开事务已经回滚")
    _assert_true(not RuntimeTransactionScript.commit(card_root).get(
        "success", true), "牌区根事务按 rollback-only 收口")
    _assert_equal(engine.player.hand, [card],
        "牌区根收口恢复失败返回前的残余移动")


func _effect_context(engine, token: String):
    return EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "power": 10,
        "initial_power": 10,
        "values": {"technique_value": 10, "initial_power": 10},
        "hand_result": {"id": "high_card", "contributing": []},
        "played_cards": [],
        "group_snapshot": {
            "played_cards": [], "contributing_cards": [], "extra_cards": [],
        },
        "captures": {},
        "technique_id": "scope_probe",
        "technique_name": "事务探针",
        "action_token": token,
        "source_kind": "technique",
        "source_id": "scope_probe",
        "source_name": "事务探针",
        "source_instance_key": "technique:%s" % token,
    })
