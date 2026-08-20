extends "res://tests/support/technique_test_group.gd"

const BattleEffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")

func _initialize() -> void:
    _run_group("technique-lifecycle-adapters", [
        "_test_post_success_stage_inserts_before_advance",
        "_test_pre_technique_cost_modes_and_power",
        "_test_real_manual_and_invocation_cost_paths",
        "_test_invocation_cost_rolls_back_after_effect_failure",
        "_test_invocation_cost_survives_choice_until_success",
        "_test_pre_technique_cost_failure_rolls_back",
        "_test_extra_action_preflight_draws_before_selection",
        "_test_extra_action_failure_rolls_back",
        "_test_card_trigger_target_policy_orders_frozen_candidates",
        "_test_pre_effect_operation_runs_before_technique_draw",
        "_test_pre_effect_operation_failure_rolls_back",
    ])

func _test_post_success_stage_inserts_before_advance() -> void:
    var engine = _lifecycle_engine(["post_insert_probe"], ["probe", "other"])
    engine.sequence_book.set_slot_capacity("high_card", 3)
    var before: Array = engine.sequence_book.ordered_slots("high_card")
    var original_slot := str(before[0].get("slot_instance_id", ""))
    var result: Dictionary = engine.technique_resolution_service \
        .resolve_direct_execution({}, _context(
            engine, "post-success-root", "manual", original_slot), [{
                "op": "repeat_effects", "count": 1,
                "effects": [{"op": "defense", "amount": 1}],
            }])
    _assert_true(result.get("success", false),
        "原功法与回响完成后推进前阶段成功")
    _assert_equal(result.get("echo_results", []).size(), 1,
        "推进前阶段接收到已经完成的全部回响")
    var inserted: Array = engine.sequence_book.ordered_slots("high_card")
    _assert_equal(inserted.size(), 3, "推进前阶段生成一门临时功法")
    _assert_equal(str(inserted[0].get("slot_instance_id", "")), original_slot,
        "推进前阶段运行时原功法仍是当前槽位")
    _assert_true(bool(inserted[1].get("temporary", false)),
        "新增功法拥有独立临时实例")
    var advanced: Dictionary = engine.effect_ports.complete_and_advance_technique(
        engine.player, "high_card", original_slot, 0, [],
        "post-success-root", "post-success-root", "post-success-root")
    _assert_true(advanced.get("success", false), "原功法随后正常推进")
    _assert_equal(str(engine.sequence_book.current_slot(
        "high_card").get("slot_instance_id", "")),
        str(inserted[1].get("slot_instance_id", "")),
        "插入后正常推进落到新增临时实例")

func _test_pre_technique_cost_modes_and_power() -> void:
    for trigger_mode in ["manual", "automatic", "invoked"]:
        var engine = _lifecycle_engine(["cost_probe"], ["probe"])
        engine.player.experience = 2
        var definition = engine.repository.get_definition("probe")
        var cost: Dictionary = engine.technique_resolution_service \
            .begin_pre_technique_cost(
                engine.player, engine.enemy, definition,
                {"id": "high_card", "contributing": []}, [],
                "high_card", "cost-%s" % trigger_mode,
                trigger_mode, str(engine.sequence_book.current_slot(
                    "high_card").get("slot_instance_id", "")), 10)
        _assert_true(cost.get("success", false),
            "%s 功法建立前置成本事务" % trigger_mode)
        var power: Dictionary = engine.technique_resolution_service.resolve_power(
            engine.player, engine.enemy,
            {"id": "high_card", "contributing": []}, [], 10,
            "cost-%s" % trigger_mode, trigger_mode, false,
            int(engine.player.direct_power_fixed) + int(cost.get(
                "power_fixed", 0)),
            int(engine.player.direct_power_percent) + int(cost.get(
                "power_percent", 0)))
        _assert_true(power.get("success", false),
            "%s 成本修正进入正式功法值计算" % trigger_mode)
        engine.technique_resolution_service.commit_pre_technique_cost(cost)
        _assert_equal(engine.player.experience, 1,
            "%s 独立支付1点历练" % trigger_mode)
        _assert_equal(power.get("values", {}).get("technique_value", 0), 20,
            "%s 获得+100%%功法值增幅" % trigger_mode)
    var echo = _lifecycle_engine(["cost_probe"], ["probe"])
    echo.player.experience = 2
    var skipped: Dictionary = echo.technique_resolution_service \
        .begin_pre_technique_cost(
            echo.player, echo.enemy, echo.repository.get_definition("probe"),
            {"id": "high_card"}, [], "high_card", "cost-echo", "echo",
            str(echo.sequence_book.current_slot(
                "high_card").get("slot_instance_id", "")), 10)
    _assert_true(skipped.get("skipped", false), "回响跳过前置成本")
    _assert_equal(echo.player.experience, 2, "回响不会重复支付历练")

func _test_pre_technique_cost_failure_rolls_back() -> void:
    var engine = _lifecycle_engine(
        ["cost_fail_probe", "cost_fail_probe"], ["probe"])
    engine.player.experience = 1
    var facts_before: Dictionary = engine.battle_passive_event_service \
        .capture_transaction_state()
    var rng_before := int(engine.rng.state)
    var result: Dictionary = engine.technique_resolution_service \
        .begin_pre_technique_cost(
            engine.player, engine.enemy, engine.repository.get_definition("probe"),
            {"id": "high_card"}, [], "high_card", "cost-failure", "manual",
            str(engine.sequence_book.current_slot(
                "high_card").get("slot_instance_id", "")), 10)
    _assert_true(not result.get("success", true), "第二份强制成本不足时整体失败")
    _assert_true(result.get("rolled_back", false), "失败成本报告已回滚")
    _assert_equal(engine.player.experience, 1, "首份已支付历练随事务恢复")
    _assert_equal(engine.player.experience_operation_receipts.size(), 0,
        "失败恢复不残留支付回执")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        facts_before, "失败恢复committed事件与序号")
    _assert_equal(int(engine.rng.state), rng_before, "失败恢复战斗RNG")

func _test_real_manual_and_invocation_cost_paths() -> void:
    var manual = _lifecycle_engine(["cost_probe"], ["probe"])
    var manual_card = _card("9", "fire")
    manual.player.hand = [manual_card]
    manual.actions_available = 1
    manual.player.experience = 2
    var manual_result: Dictionary = manual.confirm_play([manual_card.id])
    _assert_true(manual_result.get("success", false),
        "手动行动沿正式确认链支付功法成本")
    _assert_equal(manual.player.experience, 1,
        "手动功法正式确认只支付一次")
    _assert_equal(manual_result.get("preview", {}).get(
        "pre_technique_cost", {}).get("power_percent", 0), 100,
        "手动功法预览保存成本功法值回执")

    for trigger_mode in ["automatic", "invoked"]:
        var engine = _lifecycle_engine(["cost_probe"], ["probe"])
        engine.player.experience = 2
        var slot: Dictionary = engine.sequence_book.current_slot("high_card")
        var invoked: Dictionary = engine.technique_invocation_service.invoke({
            "selection": {"mode": "self", "hand_id": "high_card"},
            "p0": {"mode": "fixed", "value": 10},
            "_trigger_mode": trigger_mode,
            "advance_sequence": false,
            "gain_same_qi": false,
            "use_momentum": false,
        }, _context(engine, "caller-%s" % trigger_mode,
            "manual", str(slot.get("slot_instance_id", ""))))
        _assert_true(invoked.get("success", false) \
            and invoked.get("triggered", false),
            "%s 沿正式调用链完成" % trigger_mode)
        _assert_equal(engine.player.experience, 1,
            "%s 正式调用链只支付一次" % trigger_mode)
        _assert_equal(invoked.get("power_values", {}).get(
            "technique_value", 0), 20,
            "%s 正式调用链冻结成本修正后的P" % trigger_mode)

func _test_invocation_cost_rolls_back_after_effect_failure() -> void:
    for trigger_mode in ["automatic", "invoked"]:
        var engine = _lifecycle_engine(["cost_probe"], ["probe"])
        engine.repository.techniques["probe"]["effects"] = [{
            "op": "discard_random", "phase": "zones", "count": 1,
        }, {
            "op": "defense", "phase": "zones", "amount": 1,
            "side": "missing_side",
        }]
        engine.player.hand = [
            _card("5", "fire"), _card("6", "mountain")]
        engine.player.experience = 2
        var slot: Dictionary = engine.sequence_book.current_slot("high_card")
        var events_before: Dictionary = engine.battle_passive_event_service \
            .capture_transaction_state()
        var rng_before := int(engine.rng.state)
        var result: Dictionary = engine.technique_invocation_service.invoke({
            "selection": {"mode": "self", "hand_id": "high_card"},
            "p0": {"mode": "fixed", "value": 10},
            "_trigger_mode": trigger_mode, "advance_sequence": false,
            "gain_same_qi": false, "use_momentum": false,
        }, _context(engine, "%s-cost-failure" % trigger_mode,
            "manual", str(slot.get("slot_instance_id", ""))))
        _assert_true(not result.get("success", true),
            "%s功法后续效果失败向上返回" % trigger_mode)
        _assert_equal(engine.player.experience, 2,
            "%s后续失败恢复功法启动历练" % trigger_mode)
        _assert_equal(engine.player.experience_operation_receipts.size(), 0,
            "%s后续失败不残留历练回执" % trigger_mode)
        _assert_equal(engine.player.hand.size(), 2,
            "%s后续失败恢复先前随机弃置的手牌" % trigger_mode)
        _assert_equal(engine.player.discard_pile.size(), 0,
            "%s后续失败恢复弃牌堆" % trigger_mode)
        _assert_equal(
            engine.battle_passive_event_service.capture_transaction_state(),
            events_before, "%s后续失败恢复事件与发布状态" % trigger_mode)
        _assert_equal(int(engine.rng.state), rng_before,
            "%s后续失败恢复战斗RNG" % trigger_mode)

func _test_invocation_cost_survives_choice_until_success() -> void:
    var engine = _lifecycle_engine(["cost_probe"], ["probe"])
    engine.repository.techniques["probe"]["effects"] = [{
        "op": "select_cards", "choice_id": "invocation_cost_choice",
        "prompt": "选择一张真气", "chooser": "actor",
        "minimum": 1, "maximum": 1, "insufficient_policy": "fail",
        "query": {"side": "actor", "zone": "hand", "order": "zone",
            "limit": -1, "filters": {"card_kind": "normal"}},
        "capture": "chosen",
    }]
    var card = _card("7", "wind")
    engine.player.hand = [card, _card("8", "forest")]
    engine.player.experience = 2
    var slot: Dictionary = engine.sequence_book.current_slot("high_card")
    var context = _context(engine, "invoke-cost-choice", "manual", str(
        slot.get("slot_instance_id", "")))
    var effect := {
        "selection": {"mode": "self", "hand_id": "high_card"},
        "p0": {"mode": "fixed", "value": 10},
        "_trigger_mode": "invoked", "advance_sequence": false,
        "gain_same_qi": false, "use_momentum": false,
    }
    var pending: Dictionary = engine.technique_invocation_service.invoke(
        effect, context)
    _assert_true(pending.get("pending_choice", false),
        "调用功法支付成本后可以暂停等待选择")
    _assert_equal(engine.player.experience, 1,
        "选择暂停期间成本已支付但尚未重复提交")
    var request_id := str(pending.get("choice_request", {}).get(
        "request_id", ""))
    context.choice_responses[request_id] = [card.id]
    var resumed: Dictionary = engine.technique_invocation_service.invoke(
        effect, context)
    _assert_true(resumed.get("success", false),
        "选择恢复后完成同一次功法调用")
    _assert_equal(engine.player.experience, 1,
        "选择恢复成功只支付一次功法启动成本")
    _assert_equal(engine.player.experience_operation_receipts.size(), 1,
        "选择恢复成功保留唯一支付回执")

func _test_extra_action_preflight_draws_before_selection() -> void:
    var engine = _lifecycle_engine(["extra_draw_probe"], ["probe"])
    engine.player.hand.clear()
    engine.player.draw_pile = [
        _card("2", "wind"), _card("3", "forest"),
        _card("4", "fire"), _card("5", "mountain"),
        _card("6", "wind"),
    ]
    engine.battle_flow.set_action_count(engine.player, 0)
    var gained: int = engine.battle_flow.grant_actions(engine.player, 1, {
        "category": "effect", "source": "专项额外行动",
        "action_token": "extra-root",
    })
    _assert_equal(gained, 1, "无手牌时预投影允许建立额外行动机会")
    var queued: Dictionary = engine.battle_flow.next_action_source(engine.player)
    _assert_equal(queued.get("preflight_projection", {}).get(
        "projected_draw_count", 0), 5, "队首额外行动冻结抽牌预投影")
    _assert_equal(engine.player.hand.size(), 0, "只读预投影本身不抽牌")
    var started: Dictionary = engine.battle_flow.prepare_next_action(engine.player)
    _assert_true(started.get("success", false) \
        and started.get("established", false), "额外行动在选牌前正式开始")
    _assert_equal(engine.player.hand.size(), 5, "额外行动开始效果在选牌前抽5张")
    var replayed: Dictionary = engine.battle_flow.prepare_next_action(engine.player)
    _assert_true(replayed.get("reused", false), "重复进入窗口不重复执行开始效果")
    _assert_equal(engine.player.hand.size(), 5, "窗口重入不重复抽牌")

    var normal = _lifecycle_engine(["extra_draw_probe"], ["probe"])
    normal.player.hand.clear()
    normal.player.draw_pile = [_card("7", "wind")]
    normal.battle_flow.set_action_count(normal.player, 1)
    var skipped: Dictionary = normal.battle_flow.prepare_next_action(normal.player)
    _assert_true(skipped.get("skipped", false), "普通行动不触发额外行动预投影")
    _assert_equal(normal.player.hand.size(), 0, "普通行动不会误抽额外行动牌")

func _test_extra_action_failure_rolls_back() -> void:
    var engine = _lifecycle_engine(["extra_fail_probe"], ["probe"])
    engine.player.hand.clear()
    engine.player.draw_pile = [_card("8", "forest")]
    engine.battle_flow.set_action_count(engine.player, 0)
    engine.battle_flow.grant_actions(engine.player, 1, {
        "category": "effect", "source": "失败额外行动",
        "action_token": "extra-fail-root",
    })
    var event_before: Dictionary = engine.battle_passive_event_service \
        .capture_transaction_state()
    var rng_before := int(engine.rng.state)
    var failed: Dictionary = engine.battle_flow.prepare_next_action(engine.player)
    _assert_true(not failed.get("success", true), "额外行动开始效果失败被上抛")
    _assert_equal(engine.player.hand.size(), 0, "失败恢复开始效果抽取的手牌")
    _assert_equal(engine.player.draw_pile.size(), 1, "失败恢复牌库")
    _assert_true(not bool(engine.battle_flow.next_action_source(
        engine.player).get("preflight_started", false)),
        "失败后额外行动窗口仍未标记开始")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        event_before, "失败恢复事件与回执")
    _assert_equal(int(engine.rng.state), rng_before, "失败恢复RNG")

func _test_card_trigger_target_policy_orders_frozen_candidates() -> void:
    var engine = _lifecycle_engine(["target_policy_probe"], ["probe"])
    var turbulence = _card("9", "forest")
    var low = _card("4", "fire")
    var high = _card("13", "mountain")
    for card in [turbulence, low, high]:
        engine.content_catalog.card_reshape_rules.bind_card(card)
    engine.player.hand = [low, high]
    engine.player.draw_pile = [turbulence]
    engine.status_system.apply_card_anomaly(
        turbulence, "mark", "turbulence", {}, "测试")
    var rng_before_query := int(engine.rng.state)
    var policy: Dictionary = engine.status_system.card_status_behavior_service \
        .query_card_trigger_target_policy(
            engine.player, turbulence, "turbulence", "mark",
            "remove_self_and_discard_non_attribute", "draw", [low, high],
            "target-policy-query")
    _assert_equal(policy.get("target_policy", ""), "lowest_rank",
        "来源中立查询返回状态行为目标策略")
    _assert_equal(int(engine.rng.state), rng_before_query,
        "目标策略纯查询不推进战斗RNG")
    engine.player.draw(1)
    _assert_true(engine.player.discard_pile.has(low),
        "来源中立目标策略把乱流候选按最低当前牌阶排序")
    _assert_true(engine.player.hand.has(high),
        "目标策略只改变选择顺序，不误弃其他候选")

func _test_pre_effect_operation_runs_before_technique_draw() -> void:
    var engine = _lifecycle_engine(["pre_draw_probe"], ["probe"])
    var enemy_hand = _card("8", "fire")
    var enemy_draw = _card("2", "wind")
    engine.enemy.hand = [enemy_hand]
    engine.enemy.draw_pile = [enemy_draw]
    var context = BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.enemy,
        "target": engine.player,
        "hand_result": {"id": "high_card", "contributing": []},
        "played_cards": [],
        "group_snapshot": {"played_cards": [], "contributing_cards": [],
            "extra_cards": [], "facts_by_id": {}, "action_same_qi_gain": 0},
        "values": {"initial_power": 10, "technique_value": 10},
        "technique_id": "probe", "technique_name": "probe",
        "technique_pool": "high", "action_token": "pre-draw-root",
        "technique_execution_token": "pre-draw-root",
        "root_action_token": "pre-draw-root", "slot_instance_id": "probe",
        "source_kind": "technique", "source_id": "probe",
        "source_name": "probe", "source_instance_key": "probe",
        "trigger_mode": "manual", "captures": {},
        "sequence_book": engine.enemy.technique_sequence_book,
        "card_identity_policy": engine.enemy.card_identity_policy,
    })
    var result: Dictionary = engine.technique_resolution_service \
        .resolve_direct_execution({}, context, [{"op": "draw", "count": 1}])
    _assert_true(result.get("success", false),
        "抽牌前响应完成后原功法抽牌继续执行")
    _assert_true(engine.enemy.discard_pile.has(enemy_hand),
        "抽牌前响应在敌方功法正式抽牌前弃置敌方手牌")
    _assert_true(engine.enemy.hand.has(enemy_draw),
        "抽牌前响应完成后原抽牌操作照常执行")
    var event_state: Dictionary = engine.battle_passive_event_service \
        .capture_transaction_state()
    var batch_tokens: Array = []
    for receipt in event_state.get("receipts", {}).values():
        if str(receipt.get("event_kind", "")) == \
                "effect_card_batch_committed":
            batch_tokens.append(str(receipt.get("event_token", "")))
    _assert_equal(batch_tokens.size(), 1,
        "前置响应弃牌提交独立的效果牌批次")
    _assert_true(batch_tokens[0].contains("inner:player"),
        "嵌套被动使用自身稳定Invocation作为EffectSpec令牌")

func _test_pre_effect_operation_failure_rolls_back() -> void:
    var engine = _lifecycle_engine(["pre_draw_fail_probe"], ["probe"])
    var enemy_hand = _card("8", "fire")
    var enemy_draw = _card("2", "wind")
    engine.enemy.hand = [enemy_hand]
    engine.enemy.draw_pile = [enemy_draw]
    var context = BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.enemy,
        "target": engine.player,
        "hand_result": {"id": "high_card", "contributing": []},
        "played_cards": [],
        "group_snapshot": {"played_cards": [], "contributing_cards": [],
            "extra_cards": [], "facts_by_id": {}, "action_same_qi_gain": 0},
        "values": {"initial_power": 10, "technique_value": 10},
        "technique_id": "probe", "technique_name": "probe",
        "technique_pool": "high", "action_token": "pre-draw-fail-root",
        "technique_execution_token": "pre-draw-fail-root",
        "root_action_token": "pre-draw-fail-root",
        "slot_instance_id": "probe", "source_kind": "technique",
        "source_id": "probe", "source_name": "probe",
        "source_instance_key": "probe", "trigger_mode": "manual",
        "captures": {}, "sequence_book": engine.enemy.technique_sequence_book,
        "card_identity_policy": engine.enemy.card_identity_policy,
    })
    var events_before: Dictionary = engine.battle_passive_event_service \
        .capture_transaction_state()
    var rng_before := int(engine.rng.state)
    var result: Dictionary = engine.technique_resolution_service \
        .resolve_direct_execution({}, context, [{"op": "draw", "count": 1}])
    _assert_true(not result.get("success", true),
        "抽牌前响应失败向上抛出并阻止原功法效果")
    _assert_true(engine.enemy.hand.has(enemy_hand),
        "前置响应失败恢复已移动的敌方手牌")
    _assert_equal(engine.enemy.discard_pile.size(), 0,
        "前置响应失败不残留敌方弃牌")
    _assert_true(engine.enemy.draw_pile.has(enemy_draw),
        "前置响应失败恢复敌方牌库")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        events_before, "前置响应失败恢复committed事件、回执与序号")
    _assert_equal(int(engine.rng.state), rng_before,
        "前置响应失败恢复战斗RNG")

func _lifecycle_engine(inner_ids: Array, sequence: Array):
    var engine = _engine_with_cards([])
    _install_fixtures(engine)
    engine.player.equipped_inner_skill_ids.assign(inner_ids)
    var definitions: Array = []
    for technique_id_value in sequence:
        var technique_id := str(technique_id_value)
        if definitions.any(func(value): return str(value.get("id", "")) \
                == technique_id):
            continue
        definitions.append({
            "id": technique_id, "name": technique_id,
            "pool": "high", "special": false, "effects": [],
        })
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": definitions,
    })
    engine.sequence_book.configure({"high_card": sequence.duplicate()})
    engine.player.use_technique_sequence_book(engine.sequence_book)
    return engine

func _install_fixtures(engine) -> void:
    var index: Dictionary = engine.content_catalog._indexes["inner_skill"]
    index["post_insert_probe"] = {
        "id": "post_insert_probe", "name": "推进前插入探针",
        "behaviors": [{
            "id": "battle_effects",
            "configuration": {
                "hook": "technique_post_success_pre_advance",
                "effects": [{
                    "op": "generate_temporary_techniques",
                    "technique_source": {"mode": "current_slot"},
                    "target_hands": "current", "copies": 1,
                    "position": "after_current", "batch_mode": "partial",
                }],
            },
        }],
    }
    index["cost_probe"] = {
        "id": "cost_probe", "name": "功法成本探针",
        "behaviors": [{
            "id": "pre_technique_cost",
            "configuration": {
                "resource": "experience", "amount": 1,
                "power_percent": 100, "insufficient_policy": "skip",
            },
        }],
    }
    index["cost_fail_probe"] = {
        "id": "cost_fail_probe", "name": "失败成本探针",
        "behaviors": [{
            "id": "pre_technique_cost",
            "configuration": {
                "resource": "experience", "amount": 1,
                "power_percent": 100, "insufficient_policy": "fail",
            },
        }],
    }
    index["extra_draw_probe"] = {
        "id": "extra_draw_probe", "name": "额外行动抽牌探针",
        "behaviors": [{
            "id": "extra_action_preflight_projection",
            "configuration": {"projected_draw_count": 5},
        }, {
            "id": "battle_effects",
            "configuration": {
                "hook": "extra_action_started",
                "effects": [{"op": "draw", "count": 5}],
            },
        }],
    }
    index["extra_fail_probe"] = {
        "id": "extra_fail_probe", "name": "额外行动失败探针",
        "behaviors": [{
            "id": "extra_action_preflight_projection",
            "configuration": {"projected_draw_count": 1},
        }, {
            "id": "battle_effects",
            "configuration": {
                "hook": "extra_action_started",
                "effects": [
                    {"op": "draw", "count": 1},
                    {"op": "fixture_missing_operation"},
                ],
            },
        }],
    }
    index["target_policy_probe"] = {
        "id": "target_policy_probe", "name": "目标策略探针",
        "behaviors": [{
            "id": "card_trigger_target_policy",
            "configuration": {
                "trigger": "draw", "status_id": "turbulence",
                "behavior": "remove_self_and_discard_non_attribute",
                "policy": "lowest_rank",
            },
        }],
    }
    index["pre_draw_probe"] = {
        "id": "pre_draw_probe", "name": "抽牌前响应探针",
        "behaviors": [{
            "id": "battle_effects",
            "configuration": {
                "rules": [{
                    "hook": "pre_effect_operation",
                    "filters": {
                        "event_actor_is_opponent": true,
                        "operation_in": ["draw"],
                        "source_kind_in": ["technique"],
                    },
                    "effects": [{
                        "op": "move_query",
                        "query": {"side": "actor", "zone": "hand",
                            "order": "left", "limit": 1,
                            "filters": {"card_kind": "normal",
                                "explicit_discard_allowed": true}},
                        "to_side": "actor", "to_zone": "discard_pile",
                        "reason": "explicit_discard",
                    }],
                }],
            },
        }],
    }
    index["pre_draw_fail_probe"] = {
        "id": "pre_draw_fail_probe", "name": "失败抽牌前响应探针",
        "behaviors": [{
            "id": "battle_effects",
            "configuration": {
                "rules": [{
                    "hook": "pre_effect_operation",
                    "filters": {
                        "event_actor_is_opponent": true,
                        "operation_in": ["draw"],
                        "source_kind_in": ["technique"],
                    },
                    "effects": [{
                        "op": "move_query",
                        "query": {"side": "actor", "zone": "hand",
                            "order": "left", "limit": 1,
                            "filters": {"card_kind": "normal",
                                "explicit_discard_allowed": true}},
                        "to_side": "actor", "to_zone": "discard_pile",
                        "reason": "explicit_discard",
                    }, {
                        "op": "defense", "amount": 1,
                        "side": "missing_side",
                    }],
                }],
            },
        }],
    }

func _context(
        engine,
        token: String,
        trigger_mode: String,
        slot_instance_id: String):
    return BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "hand_result": {"id": "high_card", "contributing": []},
        "played_cards": [],
        "group_snapshot": {
            "played_cards": [], "contributing_cards": [],
            "extra_cards": [], "facts_by_id": {},
            "action_same_qi_gain": 0,
        },
        "values": {"initial_power": 10, "technique_value": 10},
        "technique_id": "probe", "technique_name": "probe",
        "technique_pool": "high",
        "action_token": token, "technique_execution_token": token,
        "root_action_token": token,
        "slot_instance_id": slot_instance_id,
        "source_kind": "technique", "source_id": "probe",
        "source_name": "probe", "source_instance_key": slot_instance_id,
        "trigger_mode": trigger_mode,
        "captures": {}, "sequence_book": engine.sequence_book,
        "card_identity_policy": engine.player.card_identity_policy,
    })
