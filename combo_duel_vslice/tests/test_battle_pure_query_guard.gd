extends "res://tests/support/expanded_technique_test_base.gd"

const PureQueryGuardScript = preload(
    "res://core/passives/battle_pure_query_guard.gd")


class TransactionProbe:
    extends RefCounted

    var value: int = 0
    var capture_calls: int = 0
    var restore_calls: int = 0

    func capture_transaction_state() -> Dictionary:
        capture_calls += 1
        return {"value": value}

    func restore_transaction_state(state: Dictionary) -> void:
        restore_calls += 1
        value = int(state.get("value", value))


class SharedStatusProbe:
    extends RefCounted

    var value: int = 0


class BattleTransactionProbe:
    extends RefCounted

    var status_system
    var value: int = 0
    var include_status_calls: Array[bool] = []

    func _init(shared_status) -> void:
        status_system = shared_status

    func all_cards_for_run_sync() -> Array:
        return []

    func capture_transaction_state(options: Dictionary = {}) -> Dictionary:
        var include_status := bool(options.get("include_status_system", true))
        include_status_calls.append(include_status)
        return {
            "value": value,
            "status": status_system.value if include_status else null,
        }

    func restore_transaction_state(state: Dictionary) -> void:
        value = int(state.get("value", value))
        if state.get("status") != null:
            status_system.value = int(state["status"])


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_reentrant_scope_captures_once()
    _test_nested_mutation_rolls_back_at_outer_boundary()
    _test_shared_status_is_captured_by_one_side_only()
    _test_combat_services_share_guard_and_restore_nested_mutation()
    _finish("BATTLE PURE QUERY GUARD TEST")


func _test_reentrant_scope_captures_once() -> void:
    var guard = PureQueryGuardScript.new()
    var probe = TransactionProbe.new()
    var outer: Dictionary = guard.evaluate(func():
        var inner: Dictionary = guard.evaluate(
            func(): return "inner-value", [probe])
        _assert_true(inner.get("is_pure", false),
            "嵌套查询复用外层纯查询边界")
        return inner.get("value"),
        [probe])
    _assert_true(outer.get("is_pure", false), "无写入嵌套查询保持纯净")
    _assert_equal(outer.get("value"), "inner-value", "Guard透传查询返回值")
    _assert_equal(probe.capture_calls, 2,
        "同一对象整条嵌套链只捕获一次初态和一次终态")
    _assert_equal(probe.restore_calls, 0, "纯查询无需恢复状态")


func _test_nested_mutation_rolls_back_at_outer_boundary() -> void:
    var guard = PureQueryGuardScript.new()
    var probe = TransactionProbe.new()
    probe.value = 7
    var outer: Dictionary = guard.evaluate(func():
        guard.evaluate(func():
            probe.value = 19
            return true,
            [probe])
        return "completed",
        [probe])
    _assert_true(not outer.get("is_pure", true), "嵌套写入令整个查询失败")
    _assert_true(outer.get("state_mutated", false), "Guard报告状态写入违规")
    _assert_equal(probe.value, 7, "外层边界恢复嵌套查询写入")
    _assert_equal(probe.restore_calls, 1, "违规状态只恢复一次")


func _test_shared_status_is_captured_by_one_side_only() -> void:
    var guard = PureQueryGuardScript.new()
    var shared_status = SharedStatusProbe.new()
    var first = BattleTransactionProbe.new(shared_status)
    var second = BattleTransactionProbe.new(shared_status)
    var guarded: Dictionary = guard.evaluate(
        func(): return true, [first, second])
    _assert_true(guarded.get("is_pure", false), "双方共享状态查询成功")
    _assert_equal(first.include_status_calls, [true, true],
        "首个参与方捕获共享StatusSystem初态和终态")
    _assert_equal(second.include_status_calls, [false, false],
        "第二个参与方不重复深拷贝共享StatusSystem")


func _test_combat_services_share_guard_and_restore_nested_mutation() -> void:
    var engine = _engine(91001)
    var card = _card("6", "wind")
    engine.player.hand.append(card)
    card.configure_identity_policy(engine.card_identity_policy)
    card.configure_battle_permission_service(engine.battle_permission_service)
    _assert_true(
        engine.battle_rule_query_service._pure_query_guard \
            == engine.battle_pure_query_guard
            and engine.battle_rule_query_service._resolver._pure_query_guard \
                == engine.battle_pure_query_guard
            and engine.hand_recognition_policy._pure_query_guard \
                == engine.battle_pure_query_guard
            and engine.card_identity_policy._pure_query_guard \
                == engine.battle_pure_query_guard
            and engine.battle_permission_service._pure_query_guard \
                == engine.battle_pure_query_guard,
        "五类战斗查询由组合根装配同一个Guard")

    var original_qi := int(card.qi_value)
    var defense_before := int(engine.player.defense)
    var rng_before := int(engine.rng.state)
    engine.card_identity_policy.register_provider(
        func(value, _context):
            value.qi_value += 5
            return {"rank_tags": ["nested_probe"]},
        "nested_identity_mutation", 10)
    engine.hand_recognition_policy.register_provider(
        func(owner, _context):
            engine.card_identity_policy.resolve(card, {
                "owner": owner,
            })
            owner.defense += 3
            engine.rng.randi()
            engine.battle_passive_event_service.commit("action_confirmed", {
                "event_token": "pure-query-committed-probe",
                "owner": owner,
                "actor": owner,
            })
            return {"straight_allowed_sizes": [5]},
        "outer_hand_mutation", 10)
    var result: Dictionary = engine.hand_recognition_policy.resolve_options(
        engine.player)
    _assert_true(not result.get("success", true),
        "嵌套身份查询与外层牌型查询的写入令整体失败")
    _assert_equal(card.qi_value, original_qi, "嵌套身份查询的真气写入被恢复")
    _assert_equal(engine.player.defense, defense_before, "外层防御写入被恢复")
    _assert_equal(int(engine.rng.state), rng_before, "共享Guard恢复战斗RNG")
    _assert_true("committed" in "；".join(result.get("errors", [])),
        "共享Guard拒绝纯查询发送committed事件")
    engine.hand_recognition_policy.unregister_provider("outer_hand_mutation")

    var identity_result: Dictionary = engine.card_identity_policy.resolve(
        card, {"owner": engine.player})
    _assert_true(not identity_result.get("success", true),
        "卡牌身份入口独立使用共享Guard")
    _assert_equal(card.qi_value, original_qi, "独立身份查询恢复卡牌写入")
    engine.card_identity_policy.unregister_provider("nested_identity_mutation")

    engine.battle_permission_service.register_provider(
        func(_hook, context):
            context["owner"].defense += 4
            return {"allowed": true},
        "permission_mutation", 10)
    var permission: Dictionary = engine.battle_permission_service.can_play_card(
        engine.player, card)
    _assert_true(not permission.get("allowed", true),
        "权限入口通过共享Guard拒绝状态写入")
    _assert_equal(engine.player.defense, defense_before, "权限查询写入被恢复")
    engine.battle_permission_service.unregister_provider("permission_mutation")
