extends "res://tests/support/technique_test_group.gd"


func _initialize() -> void:
    _run_group("battle-effect-flow", [
        "_test_effect_context_stack_and_immediate_queue_facade",
        "_test_automatic_trigger_uses_special_p0_and_nested_order",
        "_test_invocation_facade_immediate_and_deferred_timing",
        "_test_invocation_choice_resume_freezes_randomness",
        "_test_delayed_and_dynamic_response_facade",
        "_test_retrigger_and_direct_card_listener_facade",
    ])


func _test_effect_context_stack_and_immediate_queue_facade() -> void:
    var engine = _engine_with_cards([])
    var parent = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "slot_instance_id": "flow-parent-slot",
    })
    var child = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "slot_instance_id": "flow-child-slot",
    })
    engine.effect_ports.push_effect_context(parent)
    engine.effect_ports.push_effect_context(child)
    _assert_equal(engine.effect_ports.current_effect_context(), child,
        "嵌套效果上下文通过 Facade 压栈并读取栈顶")
    engine.effect_ports.pop_effect_context(child)
    _assert_equal(engine.effect_ports.current_effect_context(), parent,
        "子上下文完成后恢复父上下文")

    var first := {"op": "damage", "amount": {"kind": "constant", "value": 1}}
    var second := {"op": "defense", "amount": {"kind": "constant", "value": 2}}
    _assert_true(engine.effect_ports.schedule_immediate_effect(parent, first),
        "同一上下文可以登记第一条即时效果")
    _assert_true(engine.effect_ports.schedule_immediate_effect(parent, second),
        "同一上下文可以登记第二条即时效果")
    first["op"] = "draw"
    var queued: Array = engine.effect_ports.take_immediate_effects(parent)
    _assert_equal(queued.map(func(effect): return str(effect.get("op", ""))),
        ["damage", "defense"], "即时效果冻结副本并保持插入顺序")
    _assert_true(engine.effect_ports.take_immediate_effects(parent).is_empty(),
        "即时效果只被当前 continuation 接管一次")
    engine.effect_ports.pop_effect_context(parent)
    _assert_equal(engine.effect_ports.current_effect_context(), null,
        "最外层上下文完成后不残留当前引用")


func _test_invocation_facade_immediate_and_deferred_timing() -> void:
    var engine = _engine_with_cards([_card("7", "fire")])
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": [
            {"id": "a", "name": "甲", "pool": "high", "special": false,
                "effects": []},
            {"id": "b", "name": "乙", "pool": "high", "special": false,
                "effects": [{"op": "damage", "amount": {
                    "kind": "constant", "value": 2}}]},
            {"id": "c", "name": "丙", "pool": "high", "special": false,
                "effects": [{"op": "damage", "amount": {
                    "kind": "constant", "value": 3}}]},
        ],
    })
    engine.sequence_book.configure({"high_card": ["a", "b", "c"]})
    var sequence_events: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_sequence_changed":
                sequence_events.append(values.duplicate(true)))
    var caller: Dictionary = engine.sequence_book.current_slot("high_card")
    var runtime = EffectContextScript.new().configure({
        "ports": engine.effect_ports, "actor": engine.player,
        "target": engine.enemy,
        "hand_result": {"id": "high_card", "contributing": engine.player.hand},
        "played_cards": engine.player.hand,
        "values": {"initial_power": 7, "technique_value": 7},
        "initial_power": 7, "power": 7,
        "technique_id": "a", "technique_name": "甲",
        "action_token": "flow-immediate", "root_action_token": "flow-immediate",
        "slot_instance_id": str(caller["slot_instance_id"]),
        "sequence_book": engine.sequence_book,
        "card_identity_policy": engine.player.card_identity_policy,
    })
    engine.effect_ports.push_effect_context(runtime)
    var life_before: int = engine.enemy.life
    var immediate: Dictionary = engine.effect_ports.invoke_sequence_technique({
        "selection": {"mode": "by_id", "hand_id": "high_card",
            "technique_id": "b"},
        "timing": "immediate", "gain_same_qi": false,
    }, runtime)
    engine.effect_ports.pop_effect_context(runtime)
    _assert_true(immediate.get("success", false),
        "即时功法调用通过 BattleEffectPorts Facade 完整结算")
    _assert_equal(engine.enemy.life, life_before - 2,
        "即时调用效果在返回调用者前完成")
    _assert_true(not sequence_events.is_empty(),
        "调用槽位实际移动后发送功法序列 committed event")

    engine.sequence_book.configure({"high_card": ["a", "b", "c"]})
    caller = engine.sequence_book.current_slot("high_card")
    runtime.slot_instance_id = str(caller["slot_instance_id"])
    runtime.action_token = "flow-after-caller"
    runtime.root_action_token = "flow-after-caller"
    var deferred: Dictionary = engine.effect_ports.invoke_sequence_technique({
        "selection": {"mode": "by_id", "hand_id": "high_card",
            "technique_id": "c"},
        "timing": "after_caller_advance", "gain_same_qi": false,
    }, runtime)
    _assert_true(deferred.get("deferred", false),
        "after_caller_advance 调用先冻结请求")
    _assert_equal(engine.sequence_book.current_id("high_card"), "a",
        "延后调用在调用者推进前不移动目标槽位")
    engine.sequence_book.complete_slot(
        "high_card", str(caller["slot_instance_id"]))
    life_before = engine.enemy.life
    var resolved: Dictionary = engine.effect_ports.resolve_after_caller_advance(
        "flow-after-caller")
    _assert_true(resolved.get("success", false),
        "调用者推进后通过 Facade 结算冻结调用")
    _assert_equal(engine.enemy.life, life_before - 3,
        "延后调用沿用冻结目标并执行一次")

    engine.sequence_book.configure({"high_card": ["a", "b", "c"]})
    caller = engine.sequence_book.current_slot("high_card")
    runtime.slot_instance_id = str(caller["slot_instance_id"])
    runtime.action_token = "flow-action-end"
    runtime.root_action_token = "flow-action-end"
    var action_end: Dictionary = engine.effect_ports.invoke_sequence_technique({
        "selection": {"mode": "by_id", "hand_id": "high_card",
            "technique_id": "b"},
        "timing": "action_end", "gain_same_qi": false,
    }, runtime)
    _assert_true(action_end.get("deferred", false),
        "action_end 调用进入 TechniqueInvocationService 的稳定时点队列")
    life_before = engine.enemy.life
    var action_end_resolved: Dictionary = (
        engine.effect_ports.resolve_technique_invocations_at_timing(
            "action_end", "flow-action-end"))
    _assert_true(action_end_resolved.get("success", false),
        "action_end 时点通过 Facade 排空匹配调用")
    _assert_equal(engine.enemy.life, life_before - 2,
        "action_end 调用只执行匹配 root_action_token 的冻结请求")


func _test_delayed_and_dynamic_response_facade() -> void:
    var engine = _engine_with_cards([])
    # 本专项验证延迟／响应仍走统一执行器，不验证初始牌库容量策略。
    engine.player.base_momentum_cap = 100
    engine.player.momentum_cap_initialized = true
    engine.player.last_momentum_cap_query_result.clear()
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "values": {"initial_power": 23, "technique_value": 31},
        "initial_power": 23,
        "power": 31,
        "captures": {},
        "technique_id": "flow-delay",
        "technique_name": "流程延迟探针",
        "action_token": "flow-delay-root",
        "source_kind": "technique",
        "source_id": "flow-delay",
        "source_name": "流程延迟探针",
        "source_instance_key": "slot:flow-delay",
    })
    var delayed: Dictionary = engine.effect_ports.register_delayed_effects(
        "流程延迟探针", "turn_end", 1, [{
            "op": "write_momentum", "operation": "add",
            "amount": {"kind": "initial_power"},
        }], context)
    _assert_true(delayed.get("success", false),
        "延迟效果通过 BattleEffectPorts 注册到 StatusSystem")
    _assert_equal(delayed["record"].get("initial_power", 0), 23,
        "延迟记录冻结注册时 P0")
    context.initial_power = 99
    engine.player.set_momentum(0)
    var turn_end: Dictionary = engine.timing_system.emit_timing("turn_end", {
        "actor": engine.player,
        "actors": [engine.player, engine.enemy],
        "round_number": 1,
    })
    _assert_true(turn_end.get("success", false), "回合结束时点正常结算延迟记录")
    _assert_equal(engine.player.momentum_value, 23,
        "延迟执行继续读取注册时冻结 P0 而非后续上下文值")
    _assert_true(engine.status_system.delayed_records.find(
        delayed["record"]) < 0, "到期延迟记录只移除自身")

    var response: Dictionary = engine.effect_ports.register_response(
        "action_pre_commit", "battle_end", [{
            "op": "write_momentum", "operation": "add",
            "amount": {"kind": "constant", "value": 6},
        }], context)
    _assert_true(response.get("success", false),
        "动态响应通过 Facade 注册并保留来源上下文")
    engine.player.set_momentum(0)
    engine.effect_ports.notify_response_event("action_pre_commit", {
        "event_token": "flow-response-event",
        "actor": engine.player,
        "owner": engine.player,
        "action_token": "flow-response-root",
    })
    _assert_equal(engine.player.momentum_value, 6,
        "行动预提交响应由 StatusSystem 匹配后继续走统一 EffectExecutor")
    engine.effect_ports.notify_response_event("action_pre_commit", {
        "event_token": "flow-response-event",
        "actor": engine.player,
        "owner": engine.player,
        "action_token": "flow-response-root",
    })
    _assert_equal(engine.player.momentum_value, 6,
        "同一响应事件重放复用稳定 EffectSpec 身份且不重复写入")

    var committed_response: Dictionary = engine.effect_ports.register_response(
        "defense_gained", "battle_end", [{
            "op": "write_momentum", "operation": "add",
            "amount": {"kind": "event_field", "field": "effective_amount"},
        }], context, {"owner": "actor"})
    _assert_true(committed_response.get("success", false),
        "已提交事件动态响应通过同一 Facade 注册")
    engine.effect_ports.add_defense_result(
        engine.player, 4, "flow-response", "flow-response-defense")
    _assert_equal(engine.player.momentum_value, 10,
        "防御实际写入后的 committed event 才触发对应响应")


func _test_retrigger_and_direct_card_listener_facade() -> void:
    var engine = _probe_engine([
        _card("8", "wind"), _card("8", "fire")], "pair", [{
        "op": "damage", "amount": {"kind": "constant", "value": 1},
    }])
    var life_before: int = engine.enemy.life
    var retriggered: Dictionary = engine.effect_ports.retrigger_current_hand_technique(
        engine.player, engine.enemy, engine.sequence_book, {
            "initial_power": 8,
            "direct_power_fixed": 0,
            "direct_power_percent": 0,
            "pre_momentum_power": 8,
            "momentum_used": 0,
            "technique_value": 8,
        }, 3, [])
    _assert_true(retriggered.get("triggered", false),
        "功法重触通过 Facade 调用既有 ActionResolver 回调")
    _assert_equal(engine.enemy.life, life_before - 1,
        "重触只执行冻结功法效果且不改变伤害数值")
    engine.effect_ports.use_hand_retrigger_callback(Callable())
    var missing: Dictionary = engine.effect_ports.retrigger_current_hand_technique(
        engine.player, engine.enemy, engine.sequence_book, {}, 3, [])
    _assert_true(not missing.get("success", true),
        "重触回调未连接时保持明确失败")

    var listener: Callable = func(_values: Dictionary) -> Dictionary:
        return {"success": true, "applied": true}
    _assert_true(engine.effect_ports.register_direct_card_trigger_listener(
        "flow-listener", listener), "直接真气响应监听通过窄 runtime 端口注册")
    _assert_true(not engine.effect_ports.register_direct_card_trigger_listener(
        "flow-listener", listener), "相同监听 ID 不会重复注册")
    _assert_true(engine.effect_ports.unregister_direct_card_trigger_listener(
        "flow-listener"), "直接真气响应监听可通过同一 Facade 注销")
