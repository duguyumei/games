extends "res://tests/support/technique_test_group.gd"


func _initialize() -> void:
    _run_group("battle-source-resources", [
        "_test_source_markers_and_public_change_events",
        "_test_momentum_and_direct_power_writes",
        "_test_same_qi_projection_idempotency_and_receipts",
        "_test_battle_resource_changed_contract_and_idempotency",
        "_test_resource_callers_and_transaction_rollback",
        "_test_reflection_sources_restore_after_action_window",
        "_test_block_source_binding_and_survival_consumption",
        "_test_challenge_source_lifecycle_and_resolution_event",
    ])


func _test_source_markers_and_public_change_events() -> void:
    var engine = _engine_with_cards([])
    var committed_kinds: Array[String] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind, _values, _receipt): committed_kinds.append(str(kind)))
    var source := {
        "source_kind": "technique",
        "source_instance_key": "slot:source-a",
        "content_id": "source-a",
        "marker_id": "charge",
        "scope": "battle",
        "public": true,
        "display_name": "蓄力",
    }
    var target := source.duplicate(true)
    target["source_instance_key"] = "slot:source-b"
    target["content_id"] = "source-b"

    var written: Dictionary = engine.effect_ports.write_source_marker(
        engine.player, source, "add", 4, "source-marker-write")
    _assert_true(written.get("success", false), "来源标识通过 Facade 正式写入")
    _assert_equal(engine.player.source_marker_store.value(
        "technique", "slot:source-a", "charge", "battle"), 4,
        "来源标识保留来源实例与 battle scope 地址")
    var transferred: Dictionary = engine.effect_ports.transfer_source_marker(
        engine.player, source, target, 3, "source-marker-transfer")
    _assert_equal(transferred.get("transferred", 0), 3,
        "来源标识转移保留正式转移量")
    _assert_equal(engine.player.source_marker_store.value(
        "technique", "slot:source-a", "charge", "battle"), 1,
        "来源标识转出只减少指定来源实例")
    _assert_equal(engine.player.source_marker_store.value(
        "technique", "slot:source-b", "charge", "battle"), 3,
        "来源标识转入写入独立来源实例")

    var record_source := source.duplicate(true)
    record_source["marker_id"] = "ordered_records"
    var appended: Dictionary = engine.effect_ports.append_source_marker_records(
        engine.player, record_source, [{"amount": 2}, {"amount": 5}],
        "source-marker-append")
    _assert_equal(appended.get("after", 0), 2, "有序来源记录整体追加")
    var consumed: Dictionary = engine.effect_ports.consume_source_marker_records(
        engine.player, record_source, 1, "source-marker-consume")
    _assert_equal(consumed.get("consumed_records", []), [{"amount": 2}],
        "有序来源记录按既有顺序消费")
    _assert_equal(committed_kinds.count("source_marker_changed"), 5,
        "每次实际 marker 写入均发送统一 committed 变化事件")


func _test_momentum_and_direct_power_writes() -> void:
    var engine = _engine_with_cards([])
    # 此专项用空牌库隔离来源资源；显式给旧兼容入口一个测试基础上限。
    _set_test_momentum_cap(engine.player, 9)
    _assert_equal(engine.effect_ports.add_momentum(engine.player, 6), 6,
        "兼容 add_momentum 入口委托统一连势写入")
    _assert_equal(engine.effect_ports.set_momentum(engine.player, 9), 9,
        "兼容 set_momentum 入口委托统一连势写入")
    var consumed: Dictionary = engine.effect_ports.write_momentum(
        engine.player, "consume", 4, "effect", "momentum-action", "probe")
    _assert_true(consumed.get("success", false), "连势消费通过统一 write_momentum")
    _assert_equal(consumed.get("paid", 0), 4, "连势回执保留实际支付量")
    _assert_equal(engine.player.momentum_value, 5, "连势正式值按回执写入")
    _assert_equal(engine.player.momentum_receipts_for_action(
        "momentum-action").size(), 1, "行动连势统计仍读取原回执")
    _assert_equal(engine.effect_ports.add_direct_power_fixed(engine.player, 7), 7,
        "直接固定功法值修正通过来源资源 Facade")
    _assert_equal(engine.effect_ports.add_direct_power_percent(engine.player, 25), 25,
        "直接百分比功法值修正保持独立资源")


func _test_same_qi_projection_idempotency_and_receipts() -> void:
    var engine = _engine_with_cards([_card("4", "wind")])
    var committed_kinds: Array[String] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind, _values, _receipt): committed_kinds.append(str(kind)))
    var projection: Dictionary = engine.effect_ports.same_qi_projection(
        engine.player, 5, {"legal_card_available": true})
    _assert_equal(projection.get("same_qi_trigger_count", 0), 1,
        "同气预估继续由 SameQiGaugeService 计算容量转换")
    _assert_equal(engine.player.same_qi_value, 0, "同气预估只读且不推进资源")

    var first: Dictionary = engine.effect_ports.write_same_qi(
        engine.player, "add", 5, "专项同气", "source-same-qi:write",
        "effect", "source-same-qi")
    var repeated: Dictionary = engine.effect_ports.write_same_qi(
        engine.player, "add", 5, "专项同气", "source-same-qi:write",
        "effect", "source-same-qi")
    _assert_equal(first.get("conversion_count", 0), 1,
        "同气达到容量后仍产生一次转换")
    _assert_true(repeated.get("reused", false), "同一稳定 token 的同气写入保持幂等")
    _assert_equal(engine.player.same_qi_value, 0, "幂等重放不重复推进同气值")
    _assert_equal(engine.effect_ports.same_qi_receipts_for_action(
        engine.player, "source-same-qi").size(), 1,
        "同气消费回执仍可按 action_token 捕获")
    _assert_equal(committed_kinds.count("same_qi_gain_resolved"), 1,
        "同气仅在首次实际成功写入后发送 committed event")


func _test_battle_resource_changed_contract_and_idempotency() -> void:
    var engine = _engine_with_cards([])
    _set_test_momentum_cap(engine.player, 9)
    var facts: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind, values, _receipt):
            if str(kind) == "battle_resource_changed":
                facts.append(values.duplicate(false)))
    var momentum_source := {
        "source_kind": "inner_skill",
        "source_id": "fixture_resource_source",
        "source_name": "合成资源来源",
        "source_instance_key": "inner_skill:fixture_resource_source",
        "trigger_mode": "response",
        "root_action_token": "resource-contract",
        "effect_execution_token": "resource-contract:momentum-add",
    }
    var first: Dictionary = engine.effect_ports.write_momentum(
        engine.player, "add", 4, "inner_skill", "resource-contract",
        "fixture_resource_source", momentum_source)
    _assert_true(first.get("success", false), "连势通过资源 Service 正式写入")
    _assert_equal(facts.size(), 1, "连势实际增加只发布一次资源变化事实")
    var momentum_fact: Dictionary = facts[0]
    for field in [
            "event_token", "event_serial", "action_token", "transaction_token",
            "change_token", "actor", "owner", "holder", "resource_type",
            "operation", "requested_value", "requested_delta", "before",
            "after", "actual_delta", "cap", "conversion_info", "source_kind",
            "source_id", "source_name", "source_instance_key", "trigger_mode",
            "round_number"]:
        _assert_true(momentum_fact.has(field),
            "battle_resource_changed公开字段：%s" % field)
    _assert_equal(momentum_fact.get("resource_type"), "momentum",
        "资源事实使用统一 resource_type 字段")
    _assert_equal(momentum_fact.get("before"), 0, "连势事实记录写入前值")
    _assert_equal(momentum_fact.get("after"), 4, "连势事实记录写入后值")
    _assert_equal(momentum_fact.get("actual_delta"), 4,
        "连势事实区分实际变化量")
    _assert_equal(momentum_fact.get("requested_delta"), 4,
        "连势事实区分请求变化量")
    _assert_equal(momentum_fact.get("cap"), 9, "连势事实公开有效上限")
    _assert_equal(momentum_fact.get("source_instance_key"),
        "inner_skill:fixture_resource_source", "资源事实保留来源实例")
    _assert_true(str(momentum_fact.get("change_token", "")).contains(
        "resource-contract:momentum-add"), "change_token 派生自稳定写入 token")
    var replayed: Dictionary = engine.effect_ports.write_momentum(
        engine.player, "add", 4, "inner_skill", "resource-contract",
        "fixture_resource_source", momentum_source)
    _assert_true(replayed.get("reused", false), "相同稳定 token 重放复用原回执")
    _assert_equal(facts.size(), 1, "稳定 token 重放不重复发布资源事实")
    _assert_equal(engine.player.momentum_value, 4, "稳定 token 重放不重复增加连势")

    var unchanged_source := momentum_source.duplicate(true)
    unchanged_source["effect_execution_token"] = "resource-contract:no-change"
    var unchanged: Dictionary = engine.effect_ports.write_momentum(
        engine.player, "add", 0, "inner_skill", "resource-contract",
        "fixture_resource_source", unchanged_source)
    _assert_true(unchanged.get("success", false), "无变化连势写入仍成功")
    _assert_equal(facts.size(), 1, "资源实际值未变化时不发布事实")

    var capped_source := momentum_source.duplicate(true)
    capped_source["effect_execution_token"] = "resource-contract:capped"
    var capped: Dictionary = engine.effect_ports.write_momentum(
        engine.player, "add", 30, "inner_skill", "resource-contract",
        "fixture_resource_source", capped_source)
    _assert_equal(capped.get("capped_amount"), 25,
        "跨越多个上限阈值的请求保留截断量")
    _assert_equal(facts[-1].get("before"), 4, "截断事实记录准确前值")
    _assert_equal(facts[-1].get("after"), 9, "截断事实记录准确后值")
    _assert_equal(facts[-1].get("actual_delta"), 5,
        "截断事实记录准确实际变化")

    var same_qi_source := {
        "source_kind": "item",
        "source_id": "fixture_same_qi_source",
        "source_name": "合成同气来源",
        "source_instance_key": "item:fixture_same_qi_source",
        "trigger_mode": "automatic",
        "root_action_token": "same-qi-contract",
        "legal_card_available": true,
    }
    var same_qi_before := facts.size()
    var same_qi: Dictionary = engine.effect_ports.write_same_qi(
        engine.player, "add", 2, "合成同气来源",
        "same-qi-contract:first", "item", "same-qi-contract",
        same_qi_source)
    _assert_true(same_qi.get("success", false), "同气通过资源 Service 正式写入")
    _assert_equal(facts.size(), same_qi_before + 1,
        "同气实际变化只发布一次资源变化事实")
    _assert_equal(facts[-1].get("resource_type"), "same_qi",
        "同气与连势共用同一事件并以 resource_type 区分")
    var converted: Dictionary = engine.effect_ports.write_same_qi(
        engine.player, "add", 3, "合成同气来源",
        "same-qi-contract:convert", "item", "same-qi-contract",
        same_qi_source)
    _assert_equal(converted.get("conversion_count"), 1, "同气写入完成容量转换")
    _assert_equal(facts[-1].get("before"), 2, "同气转换事实记录转换前值")
    _assert_equal(facts[-1].get("after"), 0, "同气转换事实记录转换后值")
    _assert_equal(facts[-1].get("actual_delta"), -2,
        "同气转换事实记录槽位实际变化")
    _assert_equal(facts[-1].get("conversion_info", {}).get(
        "conversion_count"), 1, "同气转换次数进入 conversion_info")
    _assert_equal(facts[-1].get("conversion_info", {}).get("spent"), 5,
        "同气转换消耗进入 conversion_info")


func _test_resource_callers_and_transaction_rollback() -> void:
    var engine = _engine_with_cards([])
    _set_test_momentum_cap(engine.player, 20)
    var facts: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind, values, _receipt):
            if str(kind) == "battle_resource_changed":
                facts.append(values.duplicate(false)))
    var runtime = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "action_token": "flow-resource-caller",
        "effect_execution_token": "flow-resource-caller:effect-0",
        "source_kind": "item",
        "source_id": "fixture_flow_resource",
        "source_name": "流程资源探针",
        "source_instance_key": "item:fixture_flow_resource",
        "trigger_mode": "response",
    })
    var executed: Dictionary = engine.effect_executor.execute_all([{
        "op": "write_momentum", "operation": "add", "amount": 5,
    }], runtime)
    _assert_true(executed.get("success", false), "FlowEffectHandler通过统一资源入口写入")
    _assert_equal(facts.size(), 1, "流程效果发布统一资源变化事实")

    var same_qi_caller_before := facts.size()
    var same_qi_caller: Dictionary = engine.technique_resolution_service \
        .settle_same_qi(engine.player, 2, "功法结算同气",
            "technique-resolution-same-qi", true, {
                "source_kind": "technique",
                "source_id": "basic_scatter",
                "source_name": "散招",
                "source_instance_key": "slot:basic-scatter",
                "trigger_mode": "manual",
                "action_token": "technique-resolution-same-qi",
            })
    _assert_true(same_qi_caller.get("success", false),
        "TechniqueResolution同气结算改用write_same_qi入口")
    _assert_equal(facts.size(), same_qi_caller_before + 1,
        "TechniqueResolution同气结算发布统一资源变化事实")

    var preview := {
        "frozen_power_formation": {
            "kind": "pre_momentum_consume",
            "consume_requested": true,
            "momentum_cost": 2,
            "consume_receipt": {},
        },
        "reshape_action_token": "preview-resource-caller",
        "technique_id": "basic_scatter",
        "slot_instance_id": "fixture-preview-slot",
        "technique": {"name": "确认期探针"},
    }
    var before_preview := facts.size()
    var confirmed: Dictionary = engine.action_preview_service \
        .commit_power_formation(engine.player, preview)
    _assert_true(confirmed.get("success", false), "ActionPreview确认期通过注入Facade支付连势")
    _assert_equal(facts.size(), before_preview + 1,
        "ActionPreview确认期发布统一资源变化事实")

    var prepared: Dictionary = engine.effect_ports.write_momentum(
        engine.player, "set", 3, "rule", "settlement-prepare", "fixture", {
            "source_kind": "rule", "source_id": "fixture",
            "source_name": "结算准备", "source_instance_key": "rule:fixture",
            "operation_token": "settlement-prepare",
        })
    _assert_true(prepared.get("success", false), "功法结算调用方测试准备成功")
    var before_settlement := facts.size()
    var settled: Dictionary = engine.technique_resolution_service \
        ._settle_momentum(engine.player, "settlement-resource-caller",
            "basic_scatter", true)
    _assert_true(settled.get("success", false), "TechniqueResolution通过Facade结算连势")
    _assert_equal(facts.size(), before_settlement + 1,
        "TechniqueResolution发布统一资源变化事实")

    engine.effect_ports.write_momentum(
        engine.player, "set", 4, "rule", "cleanup-prepare", "fixture", {
            "source_kind": "rule", "source_id": "fixture",
            "source_name": "清理准备", "source_instance_key": "rule:fixture",
            "operation_token": "cleanup-prepare",
        })
    var before_cleanup := facts.size()
    var cleaned: Dictionary = engine.status_system.combat_source_lifecycle_service \
        .clear_battle_sources(engine.player)
    _assert_true(cleaned.get("success", false), "CombatSourceLifecycle通过Facade清理连势")
    _assert_equal(facts.size(), before_cleanup + 1,
        "CombatSourceLifecycle发布统一资源变化事实")

    _set_test_momentum_cap(engine.player, 20)
    var value_before := int(engine.player.momentum_value)
    var receipts_before: Array = \
        engine.player.momentum_write_receipts.duplicate(true)
    var event_state_before: Dictionary = engine.battle_passive_event_service \
        .capture_transaction_state()
    var facts_before := facts.size()
    var transaction: Dictionary = engine.effect_ports \
        .begin_effect_mutation_transaction()
    var transactional: Dictionary = engine.effect_ports.write_momentum(
        engine.player, "add", 6, "item", "resource-rollback", "fixture", {
            "source_kind": "item", "source_id": "fixture",
            "source_name": "事务回滚探针",
            "source_instance_key": "item:fixture",
            "operation_token": "resource-rollback:momentum",
        })
    _assert_true(transactional.get("success", false), "事务内资源写入先成功")
    _assert_equal(facts.size(), facts_before, "外层事务提交前不向观察者发布资源事实")
    _assert_true(engine.effect_ports.rollback_effect_mutation_transaction(
        transaction), "资源事务沿用BattleRuntimeMutationTransaction回滚")
    _assert_equal(engine.player.momentum_value, value_before, "事务回滚恢复连势值")
    _assert_equal(engine.player.momentum_write_receipts, receipts_before,
        "事务回滚恢复资源写入回执")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        event_state_before, "事务回滚恢复committed事件、token和历史")
    _assert_equal(facts.size(), facts_before, "事务回滚不遗留公开资源事实")

    var same_qi_before := int(engine.player.same_qi_value)
    var actions_before := int(engine.battle_flow.available_action_count(
        engine.player))
    event_state_before = engine.battle_passive_event_service \
        .capture_transaction_state()
    transaction = engine.effect_ports.begin_effect_mutation_transaction()
    var converted: Dictionary = engine.effect_ports.write_same_qi(
        engine.player, "add", 5, "事务同气探针",
        "resource-rollback:same-qi", "item", "resource-rollback", {
            "source_kind": "item", "source_id": "fixture",
            "source_name": "事务同气探针",
            "source_instance_key": "item:fixture",
            "legal_card_available": true,
        })
    _assert_equal(converted.get("conversion_count"), 1,
        "事务内同气转换先生成内部回执与额外行动")
    _assert_true(engine.effect_ports.rollback_effect_mutation_transaction(
        transaction), "同气转换复用同一BattleRuntime事务回滚")
    _assert_equal(engine.player.same_qi_value, same_qi_before,
        "同气事务回滚恢复槽位值")
    _assert_equal(engine.battle_flow.available_action_count(engine.player),
        actions_before, "同气事务回滚恢复额外行动")
    _assert_true(engine.effect_ports.same_qi_receipts_for_action(
        engine.player, "resource-rollback").is_empty(),
        "同气事务回滚恢复内部幂等回执")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        event_state_before, "同气事务回滚不遗留committed事件回执")


func _set_test_momentum_cap(side, value: int) -> void:
    side.momentum_cap_initialized = false
    side.initialize_base_momentum_cap(value)


func _test_reflection_sources_restore_after_action_window() -> void:
    var engine = _engine_with_cards([])
    var committed_kinds: Array[String] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind, _values, _receipt): committed_kinds.append(str(kind)))
    engine.player.defense = 4
    engine.action_resolver.begin_action_resolution(
        [engine.player, engine.enemy], {
            "acting_owner_ids": [str(engine.enemy.owner_id)],
            "action_tokens": ["reflection-window"],
        })
    engine.effect_ports.grant_reflection_source(
        engine.player, 50, 2, "round_end", "持续反震", "reflection-long")
    var temporary: Dictionary = engine.effect_ports.grant_reflection_source(
        engine.player, 100, 1, "action_window_end", "行动窗反震",
        "reflection-window", engine.enemy)
    _assert_equal(engine.player.reflection_sources.size(), 2,
        "不同持续时间的反震来源保持独立记录")
    _assert_equal(engine.player.current_reflection_percent, 100,
        "后建立行动窗反震在当前时点生效")
    _assert_true(str(temporary["record"].get("expiry_window_id", "")) != "",
        "行动窗反震绑定当前合法敌方行动窗口")

    var enemy_life_before: int = int(engine.enemy.life)
    var damage: Dictionary = engine.effect_ports.deal_damage(
        engine.enemy, engine.player, 2, "source-resource-test", false,
        "reflection-window:hit", "normal", {"direct_attack": true})
    _assert_equal(damage.get("defense_lost", 0), 2,
        "生存服务继续独立结算伤害造成的防御减少")
    _assert_equal(engine.enemy.life, enemy_life_before - 2,
        "生存服务只读当前反震来源并按既有规则结算")
    var finished: Dictionary = engine.action_resolver.finish_action_resolution()
    _assert_true(finished.get("success", false), "反震来源所在行动窗口正常收口")
    _assert_equal(engine.player.current_reflection_percent, 50,
        "100%行动窗来源到期后恢复仍有效的50%来源")
    _assert_equal(engine.player.reflection_sources.size(), 1,
        "行动窗到期只移除匹配来源")
    _assert_true(committed_kinds.count("reflection_source_changed") >= 3,
        "反震建立与到期继续发送统一来源生命周期事件")


func _test_block_source_binding_and_survival_consumption() -> void:
    var engine = _engine_with_cards([])
    engine.action_resolver.begin_action_resolution(
        [engine.player, engine.enemy], {
            "acting_owner_ids": [str(engine.enemy.owner_id)],
            "action_tokens": ["block-window"],
        })
    var bound: Dictionary = engine.effect_ports.grant_block_source(
        engine.player, engine.enemy, "unconditional", "当前格挡", "block-bound")
    engine.effect_ports.close_current_source_binding_window()
    var waiting: Dictionary = engine.effect_ports.grant_block_source(
        engine.player, engine.enemy, "unconditional", "后续格挡", "block-waiting")
    _assert_true(str(bound["record"].get("window_id", "")) != "",
        "绑定窗口开放时格挡来源绑定当前敌方行动")
    _assert_true(waiting["record"].get("waiting_for_action", false),
        "关闭来源绑定窗口后建立的格挡等待下一合法行动")

    var blocked: Dictionary = engine.effect_ports.deal_damage(
        engine.enemy, engine.player, 5, "source-resource-test", false,
        "block-window:hit", "normal", {"direct_attack": true})
    _assert_true(blocked.get("blocked", false),
        "生存服务继续读取并消费当前合格格挡来源")
    _assert_equal(engine.player.block_sources.size(), 1,
        "当前格挡消费后保留等待下一行动的独立来源")
    _assert_equal(str(engine.player.block_sources[0].get("source_token", "")),
        "block-waiting", "不合当前窗口的格挡来源不被错误消费")
    _assert_true(engine.action_resolver.finish_action_resolution().get(
        "success", false), "格挡来源所在行动窗口正常收口")


func _test_challenge_source_lifecycle_and_resolution_event() -> void:
    var engine = _engine_with_cards([])
    var committed_kinds: Array[String] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind, _values, _receipt): committed_kinds.append(str(kind)))
    engine.action_resolver.begin_action_resolution(
        [engine.player, engine.enemy], {
            "acting_owner_ids": [str(engine.enemy.owner_id)],
            "action_tokens": ["challenge-window"],
        })
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "power": 12,
        "initial_power": 10,
        "hand_result": {"id": "high_card"},
        "group_snapshot": {},
        "captures": {},
        "technique_id": "challenge-probe",
        "technique_name": "邀战探针",
        "actual_hand_id": "high_card",
        "technique_pool": "high",
        "action_token": "challenge-window",
        "source_kind": "technique",
        "source_id": "challenge-probe",
        "source_name": "邀战探针",
        "source_instance_key": "slot:challenge-probe",
    })
    var registered: Dictionary = engine.effect_ports.register_challenge(
        context, 3, [], "专项邀战")
    _assert_true(registered.get("success", false), "邀战来源通过 Facade 建立")
    _assert_equal(registered["record"].get("threshold", 0), 3,
        "邀战阈值保持独立冻结")
    _assert_true(str(registered["record"].get("window_id", "")) != "",
        "邀战来源绑定当前敌方行动窗口")
    engine.effect_ports.deal_damage(
        engine.enemy, engine.player, 3, "source-resource-test", true,
        "challenge-window:hit", "true", {"direct_attack": true})
    _assert_equal(engine.player.challenge_records[0].get("current", 0), 3,
        "邀战继续在既有伤害时点累计实际生命损失")
    _assert_true(engine.action_resolver.finish_action_resolution().get(
        "success", false), "邀战行动窗口正常收口")
    _assert_equal(engine.player.challenge_records.size(), 0,
        "邀战达标后按既有生命周期移除来源")
    _assert_true(committed_kinds.has("challenge_established"),
        "邀战建立发送 committed 生命周期事件")
    _assert_true(committed_kinds.has("challenge_resolved"),
        "邀战结算事件结构入口保持不变")
