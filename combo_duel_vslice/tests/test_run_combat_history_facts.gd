extends "res://tests/support/expanded_technique_test_base.gd"

const BattleEffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const BattleFinalResultDTOScript = preload(
    "res://core/battle_final_result_dto.gd")
const BattleRuntimeMutationTransactionScript = preload(
    "res://core/battle_runtime_mutation_transaction.gd")
const EffectValueResolverScript = preload(
    "res://core/effects/effect_value_resolver.gd")
const GameCompositionRootScript = preload(
    "res://core/game_composition_root.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const RunCombatHistoryScript = preload("res://core/run_combat_history.gd")
const RunProgressSnapshotScript = preload(
    "res://core/run_progress_snapshot.gd")
const RunSaveDataScript = preload("res://core/run_save_data.gd")


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_value_object_contract()
    _test_canonical_execution_projection()
    _test_transactions_progress_and_save_roundtrip()
    _test_satellite_content_and_run_outcome()
    _test_read_only_queries()
    _finish("RUN COMBAT HISTORY FACTS TEST")


func _test_value_object_contract() -> void:
    var history = RunCombatHistoryScript.new()
    _assert_equal(history.snapshot(), _empty_history_snapshot(),
        "空历史快照始终完整包含八种精确牌型")
    _assert_equal(history.most_successful_hand_ids(),
        RunCombatHistoryScript.HAND_IDS,
        "无牌型历史时八种牌型按正式顺序并列")
    _assert_true(not history.has_any_successful_hand(),
        "空历史不报告成功牌型")
    _assert_true(history.record_technique_success("zeta_probe"),
        "首次稳定功法 ID 记录成功")
    _assert_true(history.record_technique_success("alpha_probe"),
        "第二个稳定功法 ID 记录成功")
    _assert_true(not history.record_technique_success("zeta_probe"),
        "重复功法 ID 不新增不同功法")
    _assert_true(not history.record_technique_success("Bad-ID"),
        "非稳定功法 ID 被拒绝")
    _assert_equal(history.successful_technique_ids(),
        ["alpha_probe", "zeta_probe"], "功法 ID 按稳定字典序快照")
    _assert_equal(history.distinct_technique_count(), 2,
        "同 ID 去重后的不同功法数正确")
    for hand_id in RunCombatHistoryScript.HAND_IDS:
        _assert_true(history.record_hand_success(hand_id),
            "%s 精确牌型可记录" % hand_id)
    history.record_hand_success("pair")
    history.record_hand_success("straight")
    _assert_equal(history.hand_success_count("pair"), 2,
        "对子成功次数独立累计")
    _assert_equal(history.most_successful_hand_ids(), ["pair", "straight"],
        "最高次数并列按正式牌型顺序返回")
    _assert_true(history.has_any_successful_hand(),
        "存在牌型成功后只读布尔查询为真")
    _assert_true(not history.record_hand_success("unknown_hand"),
        "未知牌型不会污染历史")

    var restored = RunCombatHistoryScript.new()
    _assert_true(restored.restore_snapshot(history.snapshot()).is_empty(),
        "历史快照完整往返")
    _assert_equal(restored.snapshot(), history.snapshot(),
        "历史往返不改变排序或完整键集合")
    var replacement = RunCombatHistoryScript.new()
    replacement.record_technique_success("replacement_probe")
    replacement.record_hand_success("five_kind")
    _assert_true(restored.replace_from(replacement).is_empty(),
        "replace_from 使用绝对历史替换")
    _assert_equal(restored.successful_technique_ids(), ["replacement_probe"],
        "replace_from 不保留旧功法 ID")
    var merged = RunCombatHistoryScript.new()
    merged.record_technique_success("merged_probe")
    merged.record_hand_success("five_kind")
    _assert_true(restored.merge_from(merged).is_empty(),
        "merge_from 合并另一个类型化历史")
    _assert_equal(restored.successful_technique_ids(),
        ["merged_probe", "replacement_probe"],
        "merge_from 对功法 ID 仍然去重排序")
    _assert_equal(restored.hand_success_count("five_kind"), 2,
        "merge_from 对牌型次数求和")
    var before_invalid := restored.snapshot()
    var invalid := restored.snapshot()
    invalid["successful_hand_counts"]["pair"] = -1
    _assert_true(not restored.restore_snapshot(invalid).is_empty(),
        "负数牌型次数被拒绝")
    _assert_equal(restored.snapshot(), before_invalid,
        "非法恢复保持原历史原子不变")


func _test_canonical_execution_projection() -> void:
    var engine = _engine(410001)
    var manual := _resolve_execution(
        engine, "history-manual", "manual_probe", "high_card", "manual")
    _assert_true(manual.get("success", false), "normal 功法执行成功")
    _assert_equal(engine.player.run_combat_history.successful_technique_ids(),
        ["manual_probe"], "normal 功法记录稳定 technique_id")
    _assert_equal(engine.player.run_combat_history.hand_success_count(
        "high_card"), 1, "normal 功法记录自身 hand_id")

    _assert_true(_resolve_execution(
        engine, "history-extra", "extra_probe", "pair", "manual") \
        .get("success", false), "额外行动执行通过同一 manual 汇总")
    _assert_equal(engine.player.run_combat_history.hand_success_count("pair"),
        1, "额外行动牌型成功次数被记录")
    _assert_true(_resolve_execution(
        engine, "history-cooperate", "cooperate_probe", "straight", "manual") \
        .get("success", false), "协同牌型组拥有独立 execution")
    _assert_equal(engine.player.run_combat_history.hand_success_count(
        "straight"), 1, "主组与协同组分别记录自身 hand_id")

    _resolve_execution(
        engine, "history-auto", "automatic_probe", "full_house", "automatic")
    _resolve_execution(
        engine, "history-invoked", "invoked_probe", "four_kind", "invoked")
    _assert_true("automatic_probe" in engine.player.run_combat_history \
        .successful_technique_ids(), "自动功法记录 technique_id")
    _assert_true("invoked_probe" in engine.player.run_combat_history \
        .successful_technique_ids(), "调用功法记录 technique_id")
    _assert_equal(engine.player.run_combat_history.hand_success_count(
        "full_house"), 0, "自动功法不增加牌型次数")
    _assert_equal(engine.player.run_combat_history.hand_success_count(
        "four_kind"), 0, "调用功法不增加牌型次数")

    var before_echo: Dictionary = engine.player.run_combat_history.snapshot()
    _resolve_execution(
        engine, "history-echo", "echo_only_probe", "five_kind", "echo")
    _assert_equal(engine.player.run_combat_history.snapshot(), before_echo,
        "功法回响不新增功法 ID 或牌型次数")

    _resolve_execution(
        engine, "history-same-slot-a", "same_id_probe", "two_pair", "manual",
        "slot-a")
    _resolve_execution(
        engine, "history-same-slot-b", "same_id_probe", "three_kind", "manual",
        "slot-b")
    _assert_equal(engine.player.run_combat_history \
        .successful_technique_ids().count("same_id_probe"), 1,
        "同 ID 不同槽位只算一门不同功法")
    _assert_equal(engine.player.run_combat_history.hand_success_count(
        "two_pair"), 1, "同 ID 第一个槽位仍记录实际牌型")
    _assert_equal(engine.player.run_combat_history.hand_success_count(
        "three_kind"), 1, "同 ID 第二个槽位仍记录实际牌型")

    var replay_context = _execution_context(
        engine, "history-replay", "replay_probe", "pair", "manual")
    var replay_first: Dictionary = engine.technique_resolution_service \
        .resolve_direct_execution({}, replay_context, [])
    var replay_again: Dictionary = engine.technique_resolution_service \
        .finish_execution(replay_context)
    _assert_true(replay_first.get("success", false) \
        and replay_again.get("reused", false),
        "continuation/receipt 重放复用同一完成汇总")
    _assert_equal(engine.player.run_combat_history.hand_success_count("pair"),
        2, "重放不重复增加牌型次数")

    var before_failure: Dictionary = engine.player.run_combat_history.snapshot()
    var failed: Dictionary = engine.technique_resolution_service \
        .resolve_direct_execution({}, _execution_context(
            engine, "history-failed", "failed_probe", "pair", "manual"), [{
                "op": "unknown_history_test_operation",
            }])
    _assert_true(not failed.get("success", false), "失败 execution 明确返回失败")
    _assert_equal(engine.player.run_combat_history.snapshot(), before_failure,
        "失败 execution 不记录任何成功历史")

    var transaction := BattleRuntimeMutationTransactionScript.begin(
        [engine.player, engine.enemy], engine.battle_passive_event_service,
        engine.trigger_queue, engine.rng)
    var rolled_fact := _commit_summary_fact(
        engine, "history-rolled-back", "rolled_back_probe", "five_kind",
        "manual")
    _assert_true(rolled_fact.get("success", false),
        "事务内汇总先进入待发布 publication")
    BattleRuntimeMutationTransactionScript.rollback(transaction)
    _assert_equal(engine.player.run_combat_history.snapshot(), before_failure,
        "事务失败恢复历史且不发布待提交事实")

    var receipt_fact := _commit_summary_fact(
        engine, "history-receipt", "receipt_probe", "five_kind", "manual")
    var after_receipt: Dictionary = engine.player.run_combat_history.snapshot()
    var reused_fact: Dictionary = engine.battle_passive_event_service.commit(
        "technique_execution_resolved", receipt_fact["values"])
    _assert_true(reused_fact.get("success", false) \
        and reused_fact.get("reused", false), "同 event_token 使用现有 receipt")
    _assert_equal(engine.player.run_combat_history.snapshot(), after_receipt,
        "receipt 重放不会再次改变历史")


func _test_transactions_progress_and_save_roundtrip() -> void:
    var engine = _engine(410002)
    engine.player.run_combat_history.record_technique_success("base_probe")
    var battle_state: Dictionary = engine.player.capture_passive_query_state()
    engine.player.run_combat_history.record_technique_success("temporary_probe")
    engine.player.run_combat_history.record_hand_success("pair")
    engine.player.replace_passive_query_state(battle_state)
    _assert_equal(engine.player.run_combat_history.successful_technique_ids(),
        ["base_probe"], "BattleSide 快照恢复历史")
    _assert_equal(engine.player.run_combat_history.hand_success_count("pair"),
        0, "BattleSide 事务回滚牌型次数")

    var growth = GrowthInventoryScript.new(engine.content_catalog, false)
    growth.run_combat_history.record_technique_success("run_base_probe")
    var working = growth.create_mutation_copy()
    working.run_combat_history.record_technique_success("working_probe")
    _assert_equal(growth.run_combat_history.successful_technique_ids(),
        ["run_base_probe"], "GrowthInventory 工作副本不提前写真实历史")
    _assert_true(growth.replace_mutation_state(
        working.capture_mutation_state()).is_empty(),
        "GrowthInventory 事务状态提交成功")
    _assert_equal(growth.run_combat_history.successful_technique_ids(),
        ["run_base_probe", "working_probe"],
        "GrowthInventory 绝对工作副本提交不重复相加")

    var progress := growth.to_progress_snapshot()
    _assert_true(progress.has_run_combat_history_state,
        "RunProgressSnapshot 使用正式 has_history 语义")
    var restored_growth = GrowthInventoryScript.new(
        engine.content_catalog, false)
    restored_growth.apply_progress_snapshot(progress)
    _assert_equal(restored_growth.run_combat_history.snapshot(),
        growth.run_combat_history.snapshot(),
        "RunProgressSnapshot 在 GrowthInventory 间往返")
    var old_partial := RunProgressSnapshotScript.from_dict({"experience": 3})
    restored_growth.apply_progress_snapshot(old_partial)
    _assert_equal(restored_growth.run_combat_history.snapshot(),
        growth.run_combat_history.snapshot(),
        "旧 Snapshot 缺历史字段不解释为主动清空")

    growth.apply_to_battle_side(engine.player)
    _assert_equal(engine.player.run_combat_history.snapshot(),
        growth.run_combat_history.snapshot(),
        "战斗建立复制已提交 Run 历史到 BattleSide")
    engine.player.run_combat_history.record_technique_success(
        "battle_one_probe")
    growth.sync_from_battle_side(engine.player)
    _assert_true("battle_one_probe" in growth.run_combat_history \
        .successful_technique_ids(), "胜利式绝对进度同步包含本场历史")
    growth.apply_to_battle_side(engine.player)
    engine.player.run_combat_history.record_technique_success(
        "battle_two_probe")
    growth.sync_from_battle_side(engine.player)
    _assert_equal(growth.run_combat_history.distinct_technique_count(), 4,
        "连续多场从累计历史建立并继续去重累计")

    var root = GameCompositionRootScript.new(RuntimeProfileScript.test())
    _assert_true(root.initialize(), "存档测试组合根加载正式内容")
    var session = root.create_run_session()
    _assert_true(session.execute({
        "type": "setup_run", "seed": 410003,
        "starter_build_id": "standard_52",
    }).success, "存档测试本局建立成功")
    session.growth.run_combat_history.record_technique_success("save_probe")
    session.growth.run_combat_history.record_hand_success("full_house")
    var save = RunSaveDataScript.new().capture(session)
    _assert_true(save.validate(root.content_catalog).is_empty(),
        "包含历史的 RunSaveData 通过校验")
    var restored_result: Dictionary = save.restore_session(
        root.content_catalog, Callable(root, "create_run_session"))
    _assert_true(restored_result.get("success", false),
        "RunSaveData 恢复包含历史的本局")
    if restored_result.get("success", false):
        _assert_equal(restored_result["run_session"].growth \
            .run_combat_history.snapshot(),
            session.growth.run_combat_history.snapshot(),
            "存档恢复只恢复历史状态且不重演战斗事件")

    var legacy_values: Dictionary = save.to_dict()
    legacy_values["growth"].erase("run_combat_history_state")
    var legacy_save = RunSaveDataScript.new(legacy_values)
    _assert_true(legacy_save.validate(root.content_catalog).is_empty(),
        "schema v1 旧存档缺历史字段仍兼容")
    var legacy_result: Dictionary = legacy_save.restore_session(
        root.content_catalog, Callable(root, "create_run_session"))
    _assert_true(legacy_result.get("success", false), "旧存档迁移恢复成功")
    if legacy_result.get("success", false):
        _assert_equal(legacy_result["run_session"].growth \
            .run_combat_history.snapshot(), _empty_history_snapshot(),
            "旧存档缺字段迁移为空历史且不从配装伪造")


func _test_satellite_content_and_run_outcome() -> void:
    var root = GameCompositionRootScript.new(RuntimeProfileScript.test())
    _assert_true(root.initialize(), "卫星组合根内容加载成功")
    var definition: Dictionary = root.content_catalog.get_by_id(
        "inner_skill", "satellite")
    _assert_equal(definition.get("name"), "卫星", "卫星稳定 ID 与名称正式入库")
    _assert_equal(definition.get("rarity"), "rare", "卫星档位按权威正文为罕见")
    _assert_equal(definition.get("status"), "formal", "卫星是正式内功")
    _assert_equal(definition.get("behaviors", [])[0].get("id"),
        "run_value_effect", "卫星复用来源中立 Run 值效果 Handler")

    var late_session = _configured_session(root, 410004)
    late_session.growth.run_combat_history.record_technique_success(
        "historical_alpha")
    late_session.growth.run_combat_history.record_technique_success(
        "historical_beta")
    _equip_satellites(late_session.growth, 1)
    var late_result: Dictionary = late_session._dispatch_battle_completed_event(
        _battle_result("player_victory", 410004))
    _assert_true(late_result.get("success", false),
        "晚获得卫星可执行 battle_completed")
    _assert_equal(late_session.growth.experience, 2,
        "晚获得卫星读取此前全部不同功法历史")

    var repeated_session = _configured_session(root, 410005)
    repeated_session.growth.run_combat_history.record_technique_success("a")
    repeated_session.growth.run_combat_history.record_technique_success("b")
    repeated_session.growth.run_combat_history.record_technique_success("c")
    _equip_satellites(repeated_session.growth, 2)
    var repeated_result: Dictionary = repeated_session \
        ._dispatch_battle_completed_event(
            _battle_result("player_victory", 410005))
    _assert_true(repeated_result.get("success", false),
        "多个卫星副本在同一冻结计划独立执行")
    _assert_equal(repeated_session.growth.experience, 6,
        "两个卫星分别按三门不同功法获得历练")

    var defeat_session = _configured_session(root, 410006)
    defeat_session.growth.run_combat_history.record_technique_success("a")
    _equip_satellites(defeat_session.growth, 1)
    _assert_true(defeat_session._dispatch_battle_completed_event(
        _battle_result("player_defeat", 410006)).get("success", false),
        "战败 battle_completed 计划仍可稳定完成")
    _assert_equal(defeat_session.growth.experience, 0,
        "卫星在战败时明确跳过")
    _assert_true(defeat_session._dispatch_battle_completed_event(
        _battle_result("scenario_error", 410016)).get("success", false),
        "技术终止结果即使进入通用事件边界也可稳定跳过")
    _assert_equal(defeat_session.growth.experience, 0,
        "卫星在技术终止时不触发")

    var outcome_session = _configured_session(root, 410007)
    _equip_satellites(outcome_session.growth, 1)
    outcome_session.growth.run_combat_history.record_technique_success(
        "before_battle")
    var begun = _begin_battle_node(outcome_session)
    _assert_true(begun.get("success", false), "卫星正式战果测试进入战斗节点")
    if begun.get("success", false):
        var battle_history = RunCombatHistoryScript.new()
        battle_history.replace_from(outcome_session.growth.run_combat_history)
        battle_history.record_technique_success("during_battle")
        var progress_values: Dictionary = (
            outcome_session.progress_snapshot().to_dict())
        progress_values["run_combat_history_state"] = battle_history.snapshot()
        var dispatch: Dictionary = begun["dispatch"]
        var resolved = outcome_session.execute({
            "type": "resolve_battle_result",
            "battle_result": _battle_result_for_dispatch(
                dispatch, "player_victory"),
            "progress_snapshot": RunProgressSnapshotScript.from_dict(
                progress_values),
        })
        _assert_true(resolved.success,
            "战斗胜利按正式 BattleOutcomeCommit 链提交")
        _assert_equal(outcome_session.growth.run_combat_history \
            .successful_technique_ids(),
            ["before_battle", "during_battle"],
            "卫星执行前已合入本场完整累计历史")
        _assert_equal(outcome_session.growth.experience, 2,
            "正式胜利战果中卫星读取合并后的两门功法")

    var lost_session = _configured_session(root, 410008)
    _equip_satellites(lost_session.growth, 1)
    lost_session.growth.run_combat_history.record_technique_success(
        "committed_before_loss")
    var lost_begun = _begin_battle_node(lost_session)
    _assert_true(lost_begun.get("success", false), "战败测试进入战斗节点")
    if lost_begun.get("success", false):
        var lost_history = RunCombatHistoryScript.new()
        lost_history.replace_from(lost_session.growth.run_combat_history)
        lost_history.record_technique_success("uncommitted_loss")
        var lost_progress: Dictionary = (
            lost_session.progress_snapshot().to_dict())
        lost_progress["run_combat_history_state"] = lost_history.snapshot()
        var lost_dispatch: Dictionary = lost_begun["dispatch"]
        var lost = lost_session.execute({
            "type": "resolve_battle_result",
            "battle_result": _battle_result_for_dispatch(
                lost_dispatch, "player_defeat"),
            "progress_snapshot": RunProgressSnapshotScript.from_dict(
                lost_progress),
        })
        _assert_true(lost.success, "战败终局仍按既有状态机完成")
        _assert_equal(lost_session.growth.run_combat_history \
            .successful_technique_ids(), ["committed_before_loss"],
            "战败不提交本场新增历史")
        _assert_equal(lost_session.growth.experience, 0,
            "正式战败战果不触发卫星")

    var exit_session = _configured_session(root, 410009)
    exit_session.growth.run_combat_history.record_technique_success(
        "before_retry")
    var exit_begun = _begin_battle_node(exit_session)
    _assert_true(exit_begun.get("success", false), "退出重开测试进入战斗节点")
    var exit_before: Dictionary = (
        exit_session.growth.run_combat_history.snapshot())
    if exit_begun.get("success", false):
        var battle_session = exit_session.create_battle_session()
        tracked_engines.append(battle_session.engine)
        _assert_true(battle_session.setup_battle(
            exit_begun["dispatch"], exit_session.progress_snapshot()),
            "退出重开测试建立独立BattleSide工作副本")
        battle_session.engine.player.run_combat_history \
            .record_technique_success("uncommitted_retry")
        exit_session._close_active_battle_session()
    _assert_equal(exit_session.growth.run_combat_history.snapshot(), exit_before,
        "未确认战果的退出/重新挑战不会提交战斗工作历史")
    _assert_equal(exit_session.growth.experience, 0,
        "退出战斗不触发卫星")


func _test_read_only_queries() -> void:
    var history = RunCombatHistoryScript.new()
    history.record_technique_success("query_a")
    history.record_technique_success("query_b")
    history.record_hand_success("pair")
    var owner = GrowthInventoryScript.new(null, false)
    owner.run_combat_history.replace_from(history)
    var before := owner.capture_mutation_state()
    var rng := RandomNumberGenerator.new()
    rng.seed = 410010
    var rng_before := int(rng.state)
    var resolver = EffectValueResolverScript.new()
    _assert_equal(resolver.resolve({
        "kind": "run_combat_history",
        "metric": "distinct_successful_technique_count",
    }, {"actor": owner, "owner": owner}), 2,
        "通用 ValueSpec 读取不同成功功法数")
    _assert_equal(resolver.resolve({
        "kind": "run_combat_history",
        "metric": "hand_success_count",
        "hand_id": "pair",
    }, {"actor": owner, "owner": owner}), 1,
        "通用 ValueSpec 读取指定精确牌型次数")
    _assert_equal(resolver.resolve({
        "kind": "run_combat_history",
        "metric": "has_any_successful_hand",
    }, {"actor": owner, "owner": owner}), 1,
        "通用 ValueSpec 读取是否存在成功牌型")
    _assert_equal(history.most_successful_hand_ids(), ["pair"],
        "PracticeService 下一批可直接读取并列候选而无需日志统计")
    _assert_equal(owner.capture_mutation_state(), before,
        "UI/AI/preview 历史查询不修改任何 Run 状态")
    _assert_equal(int(rng.state), rng_before,
        "历史查询不推进 RNG")


func _resolve_execution(
        engine,
        token: String,
        technique_id: String,
        hand_id: String,
        trigger_mode: String,
        slot_instance_id: String = "") -> Dictionary:
    return engine.technique_resolution_service.resolve_direct_execution(
        {}, _execution_context(
            engine, token, technique_id, hand_id, trigger_mode,
            slot_instance_id), [])


func _execution_context(
        engine,
        token: String,
        technique_id: String,
        hand_id: String,
        trigger_mode: String,
        slot_instance_id: String = ""):
    var slot_id := slot_instance_id if slot_instance_id != "" \
        else "history-slot:%s:%s" % [hand_id, technique_id]
    return BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "hand_result": {"id": hand_id, "contributing": []},
        "played_cards": [],
        "group_snapshot": {
            "played_cards": [], "contributing_cards": [],
            "extra_cards": [], "facts_by_id": {},
            "action_same_qi_gain": 0,
        },
        "values": {"initial_power": 1, "technique_value": 1},
        "initial_power": 1,
        "power": 1,
        "technique_id": technique_id,
        "technique_name": technique_id,
        "technique_pool": "high",
        "action_token": token,
        "technique_execution_token": token,
        "root_action_token": token,
        "slot_instance_id": slot_id,
        "source_kind": "technique",
        "source_id": technique_id,
        "source_name": technique_id,
        "source_instance_key": slot_id,
        "trigger_mode": trigger_mode,
        "captures": {},
        "sequence_book": engine.sequence_book,
        "card_identity_policy": engine.player.card_identity_policy,
    })


func _commit_summary_fact(
        engine,
        event_token: String,
        technique_id: String,
        hand_id: String,
        trigger_mode: String) -> Dictionary:
    var values := {
        "event_token": event_token,
        "event_serial": engine.battle_passive_event_service.next_serial(),
        "actor": engine.player,
        "target": engine.enemy,
        "owner": engine.player,
        "action_token": event_token,
        "source_kind": "technique",
        "source_id": technique_id,
        "source_instance_key": "slot:%s" % technique_id,
        "technique_id": technique_id,
        "hand_id": hand_id,
        "trigger_mode": trigger_mode,
        "is_echo": trigger_mode == "echo",
    }
    var committed: Dictionary = engine.battle_passive_event_service.commit(
        "technique_execution_resolved", values)
    committed["values"] = values
    return committed


func _configured_session(root, seed_value: int):
    var session = root.create_run_session()
    _assert_true(session != null, "组合根建立 RunSession")
    if session == null:
        return null
    _assert_true(session.execute({
        "type": "setup_run",
        "seed": seed_value,
        "starter_build_id": "standard_52",
    }).success, "RunSession 初始化成功")
    return session


func _equip_satellites(growth, count: int) -> void:
    growth.learned_inner_skill_ids.clear()
    growth.equipped_inner_skill_ids.clear()
    for _index in range(count):
        growth.learned_inner_skill_ids.append("satellite")
        growth.equipped_inner_skill_ids.append("satellite")
    growth.technique_slot_index = count


func _battle_result(state: String, seed_value: int):
    return BattleFinalResultDTOScript.from_dict({
        "schema_version": 1,
        "battle_state": state,
        "detail": "历史专项",
        "node_id": "history-node-%d" % seed_value,
        "act": 1,
        "node_type": "combat",
        "content_id": "history-content",
        "content_seed": seed_value,
        "turn_number": 1,
    })


func _begin_battle_node(session) -> Dictionary:
    for node_id_value in session.snapshot().available_node_ids:
        var node_id := str(node_id_value)
        var definition: Dictionary = session.navigation.node_definition(node_id)
        if str(definition.get("type", "")) not in ["combat", "elite", "boss"]:
            continue
        var begun = session.execute({"type": "begin_node", "node_id": node_id})
        if not begun.success:
            return {"success": false}
        return {
            "success": true,
            "dispatch": begun.payload_value("dispatch", {}),
        }
    return {"success": false}


func _battle_result_for_dispatch(dispatch: Dictionary, state: String):
    return BattleFinalResultDTOScript.from_dict({
        "schema_version": 1,
        "battle_state": state,
        "detail": "正式历史战果",
        "node_id": str(dispatch.get("node_id", "")),
        "act": int(dispatch.get("act", 1)),
        "node_type": str(dispatch.get("node_type", "")),
        "content_id": str(dispatch.get("content_id", "")),
        "content_seed": int(dispatch.get("content_seed", 0)),
        "turn_number": 1,
    })


func _empty_history_snapshot() -> Dictionary:
    var counts: Dictionary = {}
    for hand_id in RunCombatHistoryScript.HAND_IDS:
        counts[hand_id] = 0
    return {
        "schema_version": RunCombatHistoryScript.SCHEMA_VERSION,
        "successful_technique_ids": [],
        "successful_hand_counts": counts,
    }
