extends "res://tests/support/expanded_technique_test_base.gd"

const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")
const ConditionSpecRegistryScript = preload(
    "res://core/specs/condition_spec_registry.gd")

func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_catalog_apply_layers_remove_and_replace()
    _test_purification_and_temporary_reshape_diff()
    _test_atomic_transfer_facts()
    _test_lifecycle_precedes_card_moved_and_aggregates()
    _test_all_side_observation_keeps_effect_owner()
    _test_legacy_projection_and_chain_recursion()
    _test_cleanup_restore_failure_and_transaction_rollback()
    _finish("CARD STATE CHANGED COMMITTED TEST")

func _test_catalog_apply_layers_remove_and_replace() -> void:
    _assert_true(BattleEventCatalogScript.is_committed("card_state_changed"),
        "card_state_changed 是正式 committed Hook")
    _assert_true(BattleEventCatalogScript.forwards_dynamic_response(
        "card_state_changed"), "canonical 事件支持动态响应")
    _assert_true("card_state_changed" not in \
        BattleEventCatalogScript.RESPONSE_ONLY_EVENTS,
        "canonical 事件不属于 response-only")
    var errors: Array[String] = []
    var valid := ConditionSpecRegistryScript.new().validate_event_filters({
        "change_domain": "mixed",
        "operation": "purify",
        "added_count": 1,
        "removed_count": 3,
        "anomaly_category": "state",
        "temporary_reshape_subslot": "rank",
    }, func(_scope: String, message: String): errors.append(message), "filters")
    _assert_true(valid and errors.is_empty(),
        "条件框架接受通用状态事实字段")

    var engine = _engine(7201)
    var card = _card("7", "forest")
    engine.player.hand = [card]
    var facts := _state_facts(engine)
    var metadata := _metadata(engine, "state-action-1")
    var applied: Dictionary = engine.status_system.apply_card_anomaly(
        card, "state", "poison", {}, "专项测试", 1, false, metadata)
    _assert_true(applied.get("success", false), "首次施加毒成功")
    _assert_equal(facts.size(), 1, "首次施加只提交一次 canonical")
    var poison: Dictionary = facts[0]
    _assert_equal(poison["change_domain"], "anomaly", "毒属于 anomaly domain")
    _assert_equal(poison["operation"], "apply", "首次施加记录 apply")
    _assert_equal(poison["added_count"], 1, "首次施加记录一个 added")
    _assert_equal(poison["changes"][0]["content_id"], "poison", "changes 公开毒 ID")
    _assert_equal(poison["changes"][0]["layer_delta"], 1, "首次施加层数差为1")
    _assert_equal(poison["holder_id"], str(engine.player.owner_id),
        "事实公开实际持有者")
    _assert_equal(poison["action_token"], "state-action-1", "事实保留行动令牌")
    _assert_equal(poison["source_kind"], "technique", "事实保留来源协议")

    engine.status_system.apply_card_anomaly(
        card, "state", "poison", {}, "专项测试", 1, false, metadata)
    _assert_equal(facts.size(), 1, "same_id keep 无实际变化不发送")

    var layered = _card("8", "fire")
    engine.player.hand.append(layered)
    engine.status_system.apply_card_anomaly(
        layered, "buff", "qi_heat", {}, "专项测试", 2, false, metadata)
    facts.clear()
    engine.status_system.apply_card_anomaly(
        layered, "buff", "qi_heat", {}, "专项测试", 3, false, metadata)
    _assert_equal(facts.size(), 1, "buff 叠层只提交一次")
    _assert_equal(facts[0]["changes"][0]["layer_before"], 2,
        "叠层记录实际 before")
    _assert_equal(facts[0]["changes"][0]["layer_after"], 5,
        "叠层记录实际 after")
    _assert_equal(facts[0]["changes"][0]["layer_delta"], 3,
        "叠层 delta 使用实际差值")
    facts.clear()
    engine.status_system.set_card_anomaly_layers(
        layered, "buff", "qi_heat", 5, "专项测试", metadata)
    _assert_true(facts.is_empty(), "set_layers 设置当前值不发送")
    engine.status_system.set_card_anomaly_layers(
        layered, "buff", "qi_heat", 1, "专项测试", metadata)
    _assert_equal(facts[0]["operation"], "set_layers", "层数设置公开操作")
    _assert_equal(facts[0]["changes"][0]["layer_delta"], -4,
        "层数减少记录准确 delta")
    facts.clear()
    engine.status_system.remove_card_anomaly(
        layered, "buff", "qi_heat", "专项测试", metadata)
    _assert_equal(facts[0]["removed_count"], 1, "移除异状记录 removed")
    facts.clear()
    engine.status_system.remove_card_anomaly(
        layered, "buff", "qi_heat", "专项测试", metadata)
    _assert_true(facts.is_empty(), "清除不存在异状不发送")

    engine.status_system.apply_card_anomaly(
        layered, "debuff", "qi_wither", {}, "专项测试", 1, false, metadata)
    facts.clear()
    engine.status_system.apply_card_anomaly(
        layered, "debuff", "qi_wither", {}, "专项测试", 2, false, metadata)
    _assert_equal(facts[0]["changes"][0]["layer_delta"], 2,
        "debuff 叠层同样记录实际 delta")

    facts.clear()
    engine.status_system.apply_card_anomaly(
        card, "state", "vulnerability", {}, "专项测试", 1, true, metadata)
    _assert_equal(facts.size(), 1, "状态替换只提交一个 canonical")
    _assert_equal(facts[0]["operation"], "replace", "状态替换公开 replace")
    _assert_equal(facts[0]["removed_count"], 1, "状态替换包含旧状态移除")
    _assert_equal(facts[0]["added_count"], 1, "状态替换包含新状态新增")
    _assert_equal(facts[0]["changes"].map(
        func(change): return change["content_id"]),
        ["poison", "vulnerability"], "状态替换稳定公开旧、新状态")
    _disconnect_event_probes(engine)

func _test_purification_and_temporary_reshape_diff() -> void:
    var engine = _engine(7202)
    var card = _card("9", "wind")
    engine.player.hand = [card]
    var facts := _state_facts(engine)
    var metadata := _metadata(engine, "state-action-2")
    engine.status_system.apply_card_anomaly(
        card, "buff", "growth", {}, "准备", 2, false, metadata)
    engine.status_system.apply_card_anomaly(
        card, "state", "poison", {}, "准备", 1, false, metadata)
    engine.status_system.apply_card_anomaly(
        card, "mark", "burned_out", {}, "准备", 1, false, metadata)
    engine.status_system.apply_temporary_attribute(
        card, "fire", "准备", metadata)
    facts.clear()
    engine.status_system.apply_card_anomaly(
        card, "mark", "purification", {}, "净化", 1, false, metadata)
    _assert_equal(facts.size(), 1, "净化多项清除只提交一个 canonical")
    var purified: Dictionary = facts[0]
    _assert_equal(purified["operation"], "purify", "净化公开 purify 操作")
    _assert_equal(purified["change_domain"], "mixed", "净化跨异状与临时重塑")
    _assert_equal(purified["removed_count"], 4,
        "removed_count 只计算三个旧异状和一个临时重塑")
    _assert_equal(purified["added_count"], 1, "净化自身只计入 added")
    _assert_true(purified["removed_changes"].all(func(change):
        return str(change.get("content_id", "")) != "purification"),
        "净化自身不计入清除数量")
    _assert_true(card.has_anomaly("mark", "purification"), "净化自身实际施加")

    var reshaped = _card("10", "mountain")
    engine.player.hand.append(reshaped)
    facts.clear()
    engine.status_system.apply_temporary_enhancement(
        reshaped, "momentum", "临时重塑", metadata)
    engine.status_system.apply_temporary_attribute(
        reshaped, "forest", "临时重塑", metadata)
    engine.status_system.apply_temporary_rank(
        reshaped, "Q", 12, 12, "临时重塑", metadata)
    _assert_equal(facts.size(), 3, "三个临时子槽首次施加各一个事实")
    _assert_true(facts.all(func(fact):
        return fact["change_domain"] == "temporary_reshape" \
            and fact["added_count"] == 1),
        "临时重塑首次施加均为 added")
    facts.clear()
    engine.status_system.apply_temporary_rank(
        reshaped, "K", 13, 13, "临时重塑替换", metadata)
    _assert_equal(facts.size(), 1, "临时牌阶替换只提交一次")
    var rank_change: Dictionary = facts[0]["changes"][0]
    _assert_equal(rank_change["change_kind"], "updated", "同槽替换记录 updated")
    _assert_equal(rank_change["before"], {
        "rank_name": "Q", "rank_order": 12, "base_qi": 12},
        "临时牌阶 before 完整")
    _assert_equal(rank_change["after"], {
        "rank_name": "K", "rank_order": 13, "base_qi": 13},
        "临时牌阶 after 完整")
    facts.clear()
    engine.status_system.apply_temporary_rank(
        reshaped, "K", 13, 13, "临时重塑替换", metadata)
    _assert_true(facts.is_empty(), "相同临时牌阶不发送")
    engine.status_system.clear_temporary_reshape(
        reshaped, "attribute", "清除临时属性", metadata)
    _assert_equal(facts[0]["removed_count"], 1, "清除单槽记录 removed")
    facts.clear()
    engine.status_system.clear_all_temporary_reshapes(
        reshaped, "清除全部临时重塑", metadata)
    _assert_equal(facts.size(), 1, "清除全部临时重塑聚合为一次")
    _assert_equal(facts[0]["removed_count"], 2,
        "清除全部只计算仍存在的强化和牌阶")
    facts.clear()
    engine.status_system.clear_all_temporary_reshapes(
        reshaped, "清除空临时重塑", metadata)
    _assert_true(facts.is_empty(), "清除空临时重塑不发送")
    _disconnect_event_probes(engine)

func _test_atomic_transfer_facts() -> void:
    var engine = _engine(7203)
    var source = _card("J", "forest")
    var target = _card("Q", "fire")
    engine.player.hand = [source]
    engine.enemy.hand = [target]
    var metadata := _metadata(engine, "state-transfer-1")
    engine.status_system.apply_card_anomaly(
        source, "state", "poison", {}, "准备", 1, false, metadata)
    var facts: Array[Dictionary] = []
    var fully_applied := {"value": true}
    var transfer_cards := {"source": source, "target": target}
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind != "card_state_changed":
                return
            facts.append(values.duplicate(true))
            fully_applied["value"] = fully_applied["value"] \
                and not transfer_cards["source"].has_anomaly("state", "poison") \
                and transfer_cards["target"].has_anomaly("state", "poison"))
    var transferred: Dictionary = engine.status_system.transfer_card_anomaly(
        source, target, "state", "poison", "转移测试", metadata)
    _assert_true(transferred.get("success", false), "异状转移成功")
    _assert_equal(facts.size(), 2, "异状转移两张牌各一个 canonical")
    _assert_equal(facts.map(func(fact): return fact["operation"]),
        ["transfer_out", "transfer_in"], "转移事实顺序稳定")
    _assert_true(facts[0]["transfer_batch_token"] != "" \
        and facts[0]["transfer_batch_token"] == facts[1]["transfer_batch_token"],
        "转移共享稳定 batch token")
    _assert_equal(facts[0]["operation_token"], facts[1]["operation_token"],
        "同一业务转移共享 operation token")
    _assert_equal(facts[0]["transfer_peer_card_id"], str(target.id),
        "来源事实记录目标 peer")
    _assert_equal(facts[1]["transfer_peer_card_id"], str(source.id),
        "目标事实记录来源 peer")
    _assert_true(fully_applied["value"], "观察者不会看到只转移一半的状态")

    var effect_source = _card("J", "mountain")
    var effect_target = _card("Q", "wind")
    engine.player.hand = [effect_source]
    engine.enemy.hand = [effect_target]
    engine.status_system.apply_card_anomaly(
        effect_source, "state", "poison", {}, "效果路径准备", 1, false,
        metadata)
    facts.clear()
    fully_applied["value"] = true
    transfer_cards["source"] = effect_source
    transfer_cards["target"] = effect_target
    var effect_context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "captures": {
            "transfer_sources": [effect_source],
            "transfer_targets": [effect_target],
        },
        "action_token": "state-transfer-effect-1",
        "source_kind": "technique",
        "source_id": "state_transfer_effect_probe",
        "source_name": "状态转移效果探针",
        "source_instance_key": "technique:state_transfer_effect_probe",
        "trigger_mode": "manual",
    })
    var executed: Dictionary = engine.effect_executor.execute_all([{
        "op": "transfer_state_captured",
        "source_capture": "transfer_sources",
        "target_capture": "transfer_targets",
        "category": "state",
        "anomaly": "poison",
        "result_capture": "transferred",
    }], effect_context)
    _assert_true(executed.get("success", false), "效果处理器状态转移成功")
    _assert_equal(facts.size(), 2, "效果处理器复用原子转移并提交两个事实")
    _assert_equal(facts.map(func(fact): return fact["operation"]),
        ["transfer_out", "transfer_in"], "效果处理器不再拆成 apply/remove")
    _assert_true(facts[0]["operation_token"] == facts[1]["operation_token"] \
        and fully_applied["value"], "效果处理器转移共享操作且不可观察半完成状态")
    _disconnect_event_probes(engine)

func _test_lifecycle_precedes_card_moved_and_aggregates() -> void:
    var engine = _engine(7204)
    var card = _card("K", "wind")
    engine.player.hand = [card]
    var metadata := _metadata(engine, "state-lifecycle-1")
    engine.status_system.apply_card_anomaly(
        card, "buff", "growth", {}, "准备", 2, false, metadata)
    engine.status_system.apply_card_anomaly(
        card, "state", "poison", {}, "准备", 1, false, metadata)
    engine.status_system.apply_card_anomaly(
        card, "mark", "meridian", {}, "准备", 1, false, metadata)
    var events: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind in ["card_state_changed", "card_moved"]:
                events.append({"kind": kind, "values": values.duplicate(true)}))
    var moved: Dictionary = engine.effect_ports.move_card(
        engine.player, "hand", engine.player, "discard_pile", card,
        "explicit_discard", "top", metadata)
    _assert_true(moved.get("success", false), "带生命周期状态的弃牌成功")
    _assert_equal(events.map(func(entry): return entry["kind"]),
        ["card_state_changed", "card_moved"],
        "生命周期状态事实先于 card_moved")
    var lifecycle: Dictionary = events[0]["values"]
    _assert_equal(lifecycle["operation"], "lifecycle_remove",
        "离手与入弃牌堆统一使用 lifecycle_remove")
    _assert_equal(lifecycle["removed_count"], 3,
        "经脉、成长和毒由同一生命周期事实聚合")
    _assert_true(not card.has_anomaly("mark", "meridian"),
        "经脉不再由 CardZoneService 裸删")
    _assert_equal(events[1]["values"]["pre_move_snapshot"]["growth_layers"], 2,
        "card_moved 仍保留生命周期清理前快照")
    _disconnect_event_probes(engine)

func _test_all_side_observation_keeps_effect_owner() -> void:
    var engine = _engine(7205)
    var probe_id := "card_state_owner_probe"
    engine.content_catalog._indexes["item"][probe_id] = {
        "id": probe_id,
        "name": "状态观察归属探针",
        "behaviors": [{
            "id": "battle_effects",
            "configuration": {
                "hook": "card_state_changed",
                "effects": [{"op": "defense", "amount": 1}],
            },
        }],
    }
    engine.player.item_ids.assign([probe_id])
    engine.enemy.item_ids.assign([probe_id])
    var card = _card("A", "mountain")
    engine.enemy.hand = [card]
    var receipts: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, _values: Dictionary, receipt: Dictionary):
            if kind == "card_state_changed":
                receipts.append(receipt.duplicate(true)))
    engine.status_system.apply_card_anomaly(
        card, "mark", "burned_out", {}, "跨侧状态", 1, false,
        _metadata(engine, "state-owner-1"))
    _assert_equal(receipts[0]["owner_ids"], [
        str(engine.player.owner_id), str(engine.enemy.owner_id)],
        "双方被动来源观察同一状态事实")
    _assert_equal(engine.player.defense, 1,
        "观察敌方状态时玩家来源效果仍归玩家")
    _assert_equal(engine.enemy.defense, 1,
        "敌方来源效果仍归敌方而不串到 holder")
    _disconnect_event_probes(engine)

func _test_legacy_projection_and_chain_recursion() -> void:
    var engine = _engine(7206)
    var card = _card("6", "fire")
    engine.player.hand = [card]
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "owner": engine.player,
        "captures": {},
        "action_token": "legacy-response-1",
        "source_kind": "technique",
    })
    engine.status_system.register_response(
        "card_anomaly_changed", "turn_end",
        [{"op": "defense", "amount": 1}], context)
    engine.status_system.register_response(
        "card_burned_out_changed", "turn_end",
        [{"op": "defense", "amount": 10}], context)
    engine.status_system.apply_card_anomaly(
        card, "mark", "burned_out", {}, "兼容响应", 1, false,
        _metadata(engine, "legacy-state-1"))
    _assert_equal(engine.player.defense, 11,
        "异状与燃尽 legacy response 各准确执行一次")
    engine.status_system.apply_temporary_attribute(
        card, "wind", "临时重塑", _metadata(engine, "legacy-state-2"))
    _assert_equal(engine.player.defense, 11,
        "临时重塑不误触发 card_anomaly_changed")

    var chain_engine = _engine(7207)
    var chain_card = _card("5", "forest")
    chain_engine.player.hand = [chain_card]
    var chain_context = EffectContextScript.new().configure({
        "ports": chain_engine.effect_ports,
        "actor": chain_engine.player,
        "target": chain_engine.enemy,
        "owner": chain_engine.player,
        "captures": {},
        "action_token": "legacy-chain-1",
        "source_kind": "technique",
    })
    chain_engine.status_system.register_response(
        "card_anomaly_changed", "turn_end", [{
            "op": "apply_card_anomaly_to_captured",
            "capture": "event_card",
            "category": "mark",
            "anomaly": "wind_lure",
        }], chain_context)
    var facts := _state_facts(chain_engine)
    chain_engine.status_system.apply_card_anomaly(
        chain_card, "state", "poison", {}, "链式测试", 1, false,
        _metadata(chain_engine, "legacy-chain-apply"))
    _assert_true(chain_card.has_anomaly("state", "poison") \
        and chain_card.has_anomaly("mark", "wind_lure"),
        "legacy 响应可合法链式修改其他状态")
    _assert_equal(facts.size(), 2,
        "链式变化产生两个新 operation，不因兼容投影重复递归")
    _assert_true(facts[0]["operation_token"] != facts[1]["operation_token"],
        "链式操作取得不同 operation token")
    _disconnect_event_probes(engine)
    _disconnect_event_probes(chain_engine)

func _test_cleanup_restore_failure_and_transaction_rollback() -> void:
    var engine = _engine(7208)
    var card = _card("4", "mountain")
    engine.player.hand = [card]
    var facts := _state_facts(engine)
    var metadata := _metadata(engine, "rollback-state-1")
    var failed: Dictionary = engine.status_system.apply_card_anomaly(
        card, "mark", "missing_anomaly", {}, "失败操作", 1, false, metadata)
    _assert_true(not failed.get("success", true), "失败施加被拒绝")
    _assert_true(facts.is_empty(), "失败施加不发送事实")

    engine.status_system.apply_card_anomaly(
        card, "state", "poison", {}, "准备", 1, false, metadata)
    facts.clear()
    var snapshot: Dictionary = engine.player.capture_passive_query_state()
    engine.player.replace_passive_query_state(snapshot)
    _assert_true(facts.is_empty(), "快照恢复不发送事实")
    engine.status_system.card_anomaly_service.on_card_battle_end(card)
    _assert_true(facts.is_empty(), "battle_end 清理不发送事实")

    engine.player.replace_passive_query_state(snapshot)
    var side_before: Dictionary = engine.player.capture_passive_query_state()
    var event_before: Dictionary = \
        engine.battle_passive_event_service.capture_transaction_state()
    var operation_before := int(engine.status_system.card_anomaly_service \
        .capture_runtime_state()["operation_serial"])
    engine.battle_passive_event_service.begin_publication_transaction()
    engine.status_system.remove_card_anomaly(
        card, "state", "poison", "事务内移除", metadata)
    _assert_true(facts.is_empty(), "外层事务提交前不发布 committed 或 legacy")
    engine.player.replace_passive_query_state(side_before)
    engine.battle_passive_event_service.restore_transaction_state(event_before)
    _assert_true(card.has_anomaly("state", "poison"), "事务回滚恢复真气状态")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        event_before, "事务回滚恢复 event serial、receipt 与执行历史")
    engine.status_system.remove_card_anomaly(
        card, "state", "poison", "回滚后再次移除", metadata)
    _assert_equal(facts.size(), 1, "回滚后合法操作只发布一次")
    _assert_equal(facts[0]["operation_token"],
        "card-state:remove:%06d" % operation_before,
        "事务回滚恢复 operation token 序列")
    _disconnect_event_probes(engine)

func _state_facts(engine) -> Array[Dictionary]:
    var facts: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "card_state_changed":
                facts.append(values.duplicate(true)))
    return facts

func _metadata(engine, action_token: String) -> Dictionary:
    return {
        "holder": engine.player,
        "source_actor": engine.player,
        "target": engine.enemy,
        "action_token": action_token,
        "source_kind": "technique",
        "source_id": "card_state_probe",
        "source_name": "状态事实探针",
        "source_instance_key": "technique:card_state_probe",
        "trigger_mode": "manual",
    }

func _disconnect_event_probes(engine) -> void:
    for connection in engine.battle_passive_event_service \
            .event_committed.get_connections():
        engine.battle_passive_event_service.event_committed.disconnect(
            connection["callable"])
