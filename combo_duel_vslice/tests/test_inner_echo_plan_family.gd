extends "res://tests/support/expanded_technique_test_base.gd"

const ContentCatalogScript = preload("res://core/content_catalog.gd")
const BattleEffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const SourceMarkerStoreScript = preload("res://core/source_marker_store.gd")

const IDS := [
    "every_second_hand_technique_echo",
    "first_technique_echo_if_none",
    "every_six_technique_executions_echo",
    "same_technique_different_slot_echo",
    "random_other_technique_gains_echo",
    "first_burnout_technique_echo",
    "blocked_technique_echoes",
    "first_temporary_technique_echo",
    "burnout_technique_advances_extra",
]

const POOL_MEMBERSHIP := {
    "high_card": ["high"], "pair": ["pair"], "two_pair": ["pair"],
    "three_kind": ["three"], "straight": ["straight"],
    "full_house": ["pair", "three"], "four_kind": ["bomb"],
    "five_kind": ["bomb"],
}


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_formal_content_and_single_entry_points()
    _test_matching_record_consumption_contract()
    _test_second_first_and_sixth_execution_modes()
    _test_stable_slot_history_and_pending_echoes()
    _test_burnout_cancel_temporary_and_extra_advance_modes()
    _test_native_echo_stacking_and_failure_rollback()
    _test_suppression_preview_and_replay_boundaries()
    _finish("INNER ECHO PLAN FAMILY TEST")


func _test_formal_content_and_single_entry_points() -> void:
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.test())
    var loaded := catalog.load_all()
    _assert_true(loaded, "九门内功正式目录通过 ContentValidator")
    if not loaded:
        push_error("内功目录校验错误：%s" % "；".join(catalog.errors))
        return
    for content_id in IDS:
        var definition: Dictionary = catalog.get_by_id(
            "inner_skill", content_id)
        _assert_true(not definition.is_empty(), "%s 正式资源存在" % content_id)
        _assert_equal(definition.get("status"), "formal",
            "%s 使用正式状态" % content_id)
        _assert_true(int(definition.get("forget_value", -1)) >= 0,
            "%s 声明非负遗忘所得" % content_id)
        _assert_equal(definition.get("behaviors", []).size(), 1,
            "%s 只声明一个来源中立 behavior" % content_id)
        _assert_equal(definition.get("behaviors", [])[0].get("id"),
            "technique_execution_plan",
            "%s 共用 technique_execution_plan" % content_id)
    _assert_equal(catalog.get_by_id(
        "inner_skill", "same_technique_different_slot_echo").get("rarity"),
        "legendary", "双位同鸣为传奇")
    _assert_equal(catalog.get_by_id(
        "inner_skill", "random_other_technique_gains_echo").get("rarity"),
        "legendary", "应机复响为传奇")
    var collection_source := FileAccess.get_file_as_string(
        "res://core/effects/collection_effect_handler.gd")
    _assert_true(collection_source.contains(
        "runtime.ports.append_current_technique_echo"),
        "repeat_effects 委托正式回响入口")
    _assert_true(not collection_source.contains(
        "state[\"pending_echo_plans\"].append"),
        "CollectionEffectHandler 不再直接写回响计划")
    var resolver_source := FileAccess.get_file_as_string(
        "res://core/technique_resolution_service.gd")
    _assert_true(resolver_source.contains(
        "func append_current_technique_echo"),
        "TechniqueResolutionService 拥有唯一计划追加入口")
    _assert_true(resolver_source.contains(
        "func _consume_pending_slot_echoes"),
        "跨 execution 待用回响由统一完成边界消费")


func _test_matching_record_consumption_contract() -> void:
    var store = SourceMarkerStoreScript.new()
    var records := [
        {"target_slot_instance_id": "slot-a", "granted_count": 1,
            "insertion_serial": 0},
        {"target_slot_instance_id": "slot-b", "granted_count": 2,
            "insertion_serial": 1},
        {"target_slot_instance_id": "slot-a", "granted_count": 3,
            "insertion_serial": 2},
    ]
    var appended: Dictionary = store.append_records(
        "inner_skill", "inner:player:0:probe", "probe",
        "pending_slot_echoes", "battle", records,
        {"public": true, "marker_role": "pending_technique_echo"})
    _assert_true(appended.get("success", false),
        "通用有序 record 追加成功")
    var consumed: Dictionary = store.consume_matching_records(
        "inner_skill", "inner:player:0:probe", "pending_slot_echoes",
        "battle", {"target_slot_instance_id": "slot-a"}, 1)
    _assert_equal(consumed.get("consumed_records", []).map(
        func(value): return int(value.get("insertion_serial", -1))), [0],
        "过滤消费只取首条匹配记录")
    _assert_equal(store.records(
        "inner_skill", "inner:player:0:probe", "pending_slot_echoes"),
        [records[1], records[2]], "未消费记录保持原有顺序")
    var snapshot: Dictionary = store.snapshot()
    var restored = SourceMarkerStoreScript.new()
    _assert_true(restored.restore_snapshot(snapshot).is_empty(),
        "待用回响 records 快照可以恢复")
    _assert_equal(restored.public_projection()[0].get("records"),
        [records[1], records[2]], "公开投影保存目标槽位与待用次数")


func _test_second_first_and_sixth_execution_modes() -> void:
    var second = _plan_engine(
        ["every_second_hand_technique_echo"], ["probe"])
    var second_first := _resolve(second, "second-high-1", "high_card")
    var second_pair_first := _resolve(second, "second-pair-1", "pair")
    var second_high := _resolve(second, "second-high-2", "high_card")
    var second_pair := _resolve(second, "second-pair-2", "pair")
    _assert_equal(second_first.get("echo_results", []).size(), 0,
        "二转余音同牌型第一次不回响")
    _assert_equal(second_pair_first.get("echo_results", []).size(), 0,
        "二转余音另一牌型拥有独立第一次")
    _assert_equal(second_high.get("echo_results", []).size(), 1,
        "二转余音高牌第二次回响")
    _assert_equal(second_pair.get("echo_results", []).size(), 1,
        "二转余音对子独立第二次回响")

    var first = _plan_engine([
        "first_technique_echo_if_none",
        "first_technique_echo_if_none",
    ], ["probe"])
    var opened := _resolve(first, "first-open", "high_card")
    var later := _resolve(first, "first-later", "high_card")
    _assert_equal(opened.get("echo_results", []).size(), 1,
        "初鸣复唱多副本稳定检查但只追加一次")
    _assert_equal(later.get("echo_results", []).size(), 0,
        "初鸣复唱所有副本的首门门禁均已消费")

    var sixth = _plan_engine(
        ["every_six_technique_executions_echo"], ["probe"])
    for index in range(5):
        _assert_equal(_resolve(sixth, "six-normal-%d" % index,
            "high_card").get("echo_results", []).size(), 0,
            "六转成章第%d次尚未奖励" % (index + 1))
    var sixth_result := _resolve(sixth, "six-normal-5", "high_card")
    _assert_equal(sixth_result.get("echo_results", []).size(), 1,
        "六转成章第6次非回响立即回响")
    var deferred = _plan_engine(
        ["every_six_technique_executions_echo"], ["probe"])
    for index in range(5):
        _resolve(deferred, "six-deferred-%d" % index, "high_card")
    var echo_sixth := _resolve(
        deferred, "six-deferred-echo", "high_card", "echo")
    _assert_equal(echo_sixth.get("echo_results", []).size(), 0,
        "第6次为回响时不可递归回响")
    _assert_equal(_pending_record_count(deferred), 1,
        "第6次为回响时建立下一门非回响待用奖励")
    var deferred_used := _resolve(
        deferred, "six-deferred-next", "high_card")
    _assert_equal(deferred_used.get("echo_results", []).size(), 1,
        "延后奖励由下一门非回响功法消费")
    _assert_equal(_pending_record_count(deferred), 0,
        "延后奖励消费后删除 marker record")


func _test_stable_slot_history_and_pending_echoes() -> void:
    var same = _plan_engine(
        ["same_technique_different_slot_echo"], ["probe", "probe"])
    var slots: Array = same.sequence_book.ordered_slots("high_card")
    var same_first := _resolve(same, "same-slot-a", "high_card",
        "manual", {}, [], str(slots[0]["slot_instance_id"]), "probe")
    var same_repeat := _resolve(same, "same-slot-a-repeat", "high_card",
        "invoked", {}, [], str(slots[0]["slot_instance_id"]), "probe")
    var same_second := _resolve(same, "same-slot-b", "high_card",
        "manual", {}, [], str(slots[1]["slot_instance_id"]), "probe")
    _assert_equal(same_first.get("echo_results", []).size(), 0,
        "双位同鸣首个稳定槽位只记录历史")
    _assert_equal(same_repeat.get("echo_results", []).size(), 0,
        "调用同一稳定槽位不伪装为第二槽位")
    _assert_equal(same_second.get("echo_results", []).size(), 1,
        "同ID第二个稳定槽位首次成功时回响")
    _assert_equal(same.player.source_marker_store.public_projection().filter(
        func(entry): return str(entry.get("marker_id", "")) \
            == "technique_slot_history").size(), 0,
        "双位同鸣私有历史不进入公开投影")

    var pending = _plan_engine(
        ["random_other_technique_gains_echo"], ["probe", "other"])
    var pending_slots: Array = pending.sequence_book.ordered_slots("high_card")
    var target_id := str(pending_slots[1]["slot_instance_id"])
    _resolve(pending, "pending-grant-1", "high_card", "manual", {}, [],
        str(pending_slots[0]["slot_instance_id"]), "probe")
    _resolve(pending, "pending-grant-2", "high_card", "manual", {}, [],
        str(pending_slots[0]["slot_instance_id"]), "probe")
    var public_pending: Array = pending.player.source_marker_store \
        .public_projection().filter(func(entry):
            return str(entry.get("marker_id", "")) == "pending_slot_echoes")
    _assert_equal(public_pending.size(), 1,
        "应机复响待用奖励属于来源 marker 的公开投影")
    _assert_equal(public_pending[0].get("records", []).size(), 2,
        "同一目标的待用次数可以稳定累积")
    _assert_true(public_pending[0].get("records", []).all(func(record):
        return str(record.get("target_slot_instance_id", "")) == target_id),
        "随机目标冻结为稳定 slot_instance_id")
    var consumed := _resolve(pending, "pending-consume", "high_card",
        "manual", {}, [], target_id, "other")
    _assert_equal(consumed.get("echo_results", []).size(), 2,
        "目标下次非回响成功时消费全部匹配次数")
    _assert_equal(_pending_record_count(pending), 1,
        "目标功法成功后应机复响自身再为另一槽位建立一次奖励")

    var no_target = _plan_engine(
        ["random_other_technique_gains_echo"], ["probe"])
    var rng_before := int(no_target.rng.state)
    _resolve(no_target, "pending-no-target", "high_card")
    _assert_equal(int(no_target.rng.state), rng_before,
        "没有其他实际槽位时不推进 RNG")
    _assert_equal(_pending_record_count(no_target), 0,
        "没有其他实际槽位时不写 marker")

    var lifecycle = _plan_engine(
        ["random_other_technique_gains_echo"], ["probe"])
    var temporary_target := _append_temporary_slot(lifecycle, "probe")
    _resolve(lifecycle, "pending-temporary-target", "high_card")
    _assert_true(lifecycle.player.source_marker_store.entries({
        "marker_id": "pending_slot_echoes"})[0].get("records", []).any(
            func(record): return str(record.get(
                "target_slot_instance_id", "")) == temporary_target),
        "战斗临时功法可以成为稳定待用目标")
    var cleanup: Dictionary = lifecycle.effect_ports \
        .clear_temporary_techniques(
            lifecycle.player, "pending-target-removed")
    _assert_true(cleanup.get("success", false),
        "临时槽位移除与待用回响清理原子成功")
    _assert_equal(_pending_record_count(lifecycle), 0,
        "目标槽位移除后失效记录立即清理且不转移")
    _assert_true(lifecycle.sequence_book.find_slots({}).all(func(slot):
        return str(slot.get("slot_instance_id", "")) != temporary_target),
        "临时目标槽位已从唯一序列事实源移除")


func _test_burnout_cancel_temporary_and_extra_advance_modes() -> void:
    var burnout = _plan_engine(
        ["first_burnout_technique_echo"], ["probe"])
    var burned_snapshot := _burned_snapshot("burn-card")
    var burnout_first := _resolve(burnout, "burn-action:first", "high_card",
        "manual", burned_snapshot, [], "", "probe", "burn-action")
    var burnout_second := _resolve(burnout, "burn-action:second", "high_card",
        "manual", burned_snapshot, [], "", "probe", "burn-action")
    var burnout_next := _resolve(burnout, "burn-next:first", "high_card",
        "manual", burned_snapshot, [], "", "probe", "burn-next")
    _assert_equal(burnout_first.get("echo_results", []).size(), 1,
        "烬法重鸣读取冻结燃尽事实并触发")
    _assert_equal(burnout_second.get("echo_results", []).size(), 0,
        "烬法重鸣同 root action 每来源只触发一次")
    _assert_equal(burnout_next.get("echo_results", []).size(), 1,
        "新 root action 重置烬法门禁")

    var canceled = _plan_engine(["blocked_technique_echoes"], ["probe"])
    var block_result := _resolve_with_attack_cancel(
        canceled, "cancel-block", "block")
    var deflection_result := _resolve_with_attack_cancel(
        canceled, "cancel-deflection", "deflection")
    var plain_result := _resolve(canceled, "cancel-pierced", "high_card")
    _assert_equal(block_result.get("summary", {}).get(
        "block_canceled_segment_count", -1), 1,
        "格挡取消进入功法执行汇总")
    _assert_equal(deflection_result.get("summary", {}).get(
        "deflection_canceled_segment_count", -1), 1,
        "卸力取消进入功法执行汇总")
    _assert_equal(block_result.get("echo_results", []).size(), 1,
        "受阻愈烈读取正式格挡取消汇总")
    _assert_equal(deflection_result.get("echo_results", []).size(), 1,
        "受阻愈烈读取正式卸力取消汇总")
    _assert_equal(plain_result.get("echo_results", []).size(), 0,
        "没有 attack_canceled 的卸力击穿不满足")

    var temporary = _plan_engine(
        ["first_temporary_technique_echo"], ["probe"])
    var temp_slot := _append_temporary_slot(temporary, "probe")
    var temp_first := _resolve(temporary, "temporary-first", "high_card",
        "manual", {}, [], temp_slot, "probe")
    var temp_second := _resolve(temporary, "temporary-second", "high_card",
        "manual", {}, [], temp_slot, "probe")
    _assert_equal(temp_first.get("echo_results", []).size(), 1,
        "第一门实际成功的临时槽位功法回响")
    _assert_equal(temp_second.get("echo_results", []).size(), 0,
        "临时功法生成本身不重复消费成功门禁")

    var advance = _manual_burnout_advance_engine([
        "burnout_technique_advances_extra",
        "burnout_technique_advances_extra",
    ])
    var committed_sequences: Array[Dictionary] = []
    advance.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "technique_sequence_changed":
                committed_sequences.append(values.duplicate(true)))
    var before: Array = advance.sequence_book.ordered_slots("high_card")
    var action: Dictionary = advance.confirm_play(
        [str(advance.player.hand[0].id)])
    var after: Array = advance.sequence_book.ordered_slots("high_card")
    _assert_true(action.get("success", false),
        "烬步催轮通过完整手动行动成功结算")
    _assert_equal(str(after[0].get("slot_instance_id", "")),
        str(before[0].get("slot_instance_id", "")),
        "三槽序列先正常推进1格再由两副本额外推进2格")
    _assert_equal(committed_sequences.size(), 1,
        "正常及额外推进只提交一份 technique_sequence_changed")
    _assert_equal(committed_sequences[0].get("normal_advance_count"), 1,
        "统一序列事件记录一次正常推进")
    _assert_equal(committed_sequences[0].get("extra_advance_count"), 2,
        "统一序列事件记录两次来源有序额外推进")
    _assert_equal(committed_sequences[0].get("source_records", []).map(
        func(record): return str(record.get("source_instance_key", ""))), [
            "inner:player:0:burnout_technique_advances_extra",
            "inner:player:1:burnout_technique_advances_extra",
        ], "额外推进来源按稳定 Invocation 顺序保存")


func _test_native_echo_stacking_and_failure_rollback() -> void:
    var stacking = _plan_engine(
        ["every_second_hand_technique_echo"], ["probe"])
    _resolve(stacking, "stacking-seed", "high_card")
    var stacked := _resolve(stacking, "stacking-second", "high_card",
        "manual", {}, [
            {"op": "defense", "amount": 1},
            {"op": "repeat_effects", "count": 1,
                "effects": [{"op": "defense", "amount": 1}]},
        ])
    _assert_true(stacked.get("success", false),
        "功法自身回响与内功回响可以稳定叠加")
    _assert_equal(stacked.get("echo_results", []).size(), 2,
        "功法自身1次与二转余音1次合并为两份稳定 echo_index")
    _assert_equal(stacking.player.defense, 3,
        "原功法及两种回响复用对应冻结效果且不递归")
    _assert_true(stacked.get("echo_results", []).all(func(result):
        return result.get("success", false)),
        "回响执行中的 repeat_effects 被安全跳过而不登记下一层")

    var failing = _plan_engine(
        ["first_technique_echo_if_none"], ["probe"])
    var counter_before: Dictionary = \
        failing.player.battle_passive_counter_store.capture_state()
    var marker_before: Dictionary = failing.player.source_marker_store.snapshot()
    var event_before: Dictionary = failing.battle_passive_event_service \
        .capture_transaction_state()
    var failed := _resolve(failing, "echo-failure", "high_card",
        "manual", {}, [{
            "op": "repeat_effects", "count": 1,
            "effects": [{"op": "missing_echo_operation"}],
        }])
    _assert_true(not failed.get("success", true),
        "后续回响执行失败令 execution 正式失败")
    _assert_equal(failing.player.battle_passive_counter_store.capture_state(),
        counter_before, "回响失败恢复被动 counter")
    _assert_equal(failing.player.source_marker_store.snapshot(), marker_before,
        "回响失败恢复来源 marker")
    _assert_equal(failing.battle_passive_event_service \
        .capture_transaction_state(), event_before,
        "回响失败不遗留 summary receipt、publication 或执行历史")
    failing.technique_resolution_service.discard_execution("echo-failure")


func _test_suppression_preview_and_replay_boundaries() -> void:
    var engine = _plan_engine(
        ["every_second_hand_technique_echo"], ["probe"])
    _resolve(engine, "suppression-seed", "high_card")
    var source_key := "inner:player:0:every_second_hand_technique_echo"
    _assert_true(engine.apply_passive_suppression({
        "suppression_id": "echo-plan-suppressed",
        "target_source_kind": "inner_skill",
        "target_instance_key": source_key,
        "blocked_hooks": ["technique_execution_resolved"],
        "reason": "专项压制",
    }).get("success", false), "可按稳定来源实例压制回响计划")
    var suppressed := _resolve(engine, "suppression-blocked", "high_card")
    _assert_equal(suppressed.get("echo_results", []).size(), 0,
        "被压制来源不建立回响计划也不追溯计数")
    _assert_true(engine.remove_passive_suppression("echo-plan-suppressed"),
        "解除来源压制成功")
    var restored_first := _resolve(
        engine, "suppression-restored-1", "high_card")
    var restored_second := _resolve(
        engine, "suppression-restored-2", "high_card")
    _assert_equal(restored_first.get("echo_results", []).size(), 1,
        "解除压制后从压制前计数继续，不追溯被压制 execution")
    _assert_equal(restored_second.get("echo_results", []).size(), 0,
        "回响后的下一轮计数重新开始")

    var marker_before: Dictionary = \
        engine.player.source_marker_store.snapshot()
    var counter_before: Dictionary = \
        engine.player.battle_passive_counter_store.capture_state()
    var rng_before := int(engine.rng.state)
    var preview: Dictionary = engine.preview([str(engine.player.hand[0].id)])
    _assert_true(preview.get("valid", false), "UI功法预览仍可执行")
    _assert_equal(engine.player.source_marker_store.snapshot(), marker_before,
        "预览不建立待用回响 marker")
    _assert_equal(engine.player.battle_passive_counter_store.capture_state(),
        counter_before, "预览不推进内功 counter")
    _assert_equal(int(engine.rng.state), rng_before, "预览不推进回响随机源")

    var replay = _plan_engine(
        ["first_technique_echo_if_none"], ["probe"])
    var context = _context(replay, "replay-token", "high_card")
    var first: Dictionary = replay.technique_resolution_service \
        .resolve_direct_execution(
        {}, context, [])
    var repeated: Dictionary = replay.technique_resolution_service \
        .finish_execution(context)
    _assert_equal(first.get("echo_results", []).size(), 1,
        "首次 execution 正常建立并执行回响")
    _assert_true(repeated.get("success", false) \
        and repeated.get("reused", false),
        "同一 execution token 重放复用已确认汇总")
    _assert_equal(repeated.get("echo_results", []).size(), 0,
        "receipt 重放不重复执行回响")


func _plan_engine(inner_ids: Array, sequence: Array):
    var engine = _engine(310000 + assertions)
    engine.player.equipped_inner_skill_ids.assign(inner_ids)
    engine.player.hand = [_card("7", "fire")]
    engine.player.draw_pile.clear()
    engine.actions_available = 1
    var definitions: Array = []
    var seen: Dictionary = {}
    for technique_id_value in sequence:
        var technique_id := str(technique_id_value)
        if seen.has(technique_id):
            continue
        seen[technique_id] = true
        definitions.append({
            "id": technique_id, "name": technique_id,
            "pool": "high", "special": false, "effects": [],
        })
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {}, "resource_paths": [],
        "techniques": definitions,
    })
    var sequences := {"high_card": sequence.duplicate()}
    engine.sequence_book.configure(sequences)
    return engine


func _manual_burnout_advance_engine(inner_ids: Array):
    var engine = _plan_engine(inner_ids, ["probe", "other", "third"])
    engine.player.hand[0].set_anomaly("debuff", "burned_out")
    return engine


func _resolve(
        engine,
        token: String,
        hand_id: String,
        trigger_mode: String = "manual",
        group_snapshot: Dictionary = {},
        effects: Array = [],
        slot_instance_id: String = "",
        technique_id: String = "probe",
        root_action_token: String = "") -> Dictionary:
    var context = _context(
        engine, token, hand_id, trigger_mode, group_snapshot,
        slot_instance_id, technique_id, root_action_token)
    return engine.technique_resolution_service.resolve_direct_execution(
        {}, context, effects)


func _context(
        engine,
        token: String,
        hand_id: String,
        trigger_mode: String = "manual",
        group_snapshot: Dictionary = {},
        slot_instance_id: String = "",
        technique_id: String = "probe",
        root_action_token: String = ""):
    var slot_id := slot_instance_id
    if slot_id == "":
        slot_id = str(engine.sequence_book.current_slot(
            hand_id).get("slot_instance_id", "slot:%s" % hand_id))
    var snapshot := group_snapshot.duplicate(true)
    if snapshot.is_empty():
        snapshot = {
            "played_cards": [], "contributing_cards": [],
            "extra_cards": [], "facts_by_id": {},
            "action_same_qi_gain": 0,
        }
    return BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "hand_result": {"id": hand_id, "contributing": []},
        "played_cards": [],
        "group_snapshot": snapshot,
        "values": {"initial_power": 1, "technique_value": 1},
        "initial_power": 1,
        "power": 1,
        "technique_id": technique_id,
        "technique_name": technique_id,
        "technique_pool": "high",
        "action_token": token,
        "technique_execution_token": token,
        "root_action_token": root_action_token \
            if root_action_token != "" else token,
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


func _resolve_with_attack_cancel(
        engine, token: String, cancel_kind: String) -> Dictionary:
    var context = _context(engine, token, "high_card")
    engine.technique_resolution_service._ensure_execution_state(context, [])
    var begun: Dictionary = engine.technique_resolution_service \
        ._begin_execution(engine.technique_resolution_service \
            ._execution_info_from_context(context))
    if not begun.get("success", false):
        return begun
    var serial_value := int(engine.battle_passive_event_service.next_serial())
    var event: Dictionary = engine.battle_passive_event_service.commit(
        "attack_canceled", {
            "event_token": engine.battle_passive_event_service.make_token(
                "attack_canceled", engine.player, serial_value, token),
            "event_serial": serial_value,
            "actor": engine.player,
            "target": engine.enemy,
            "owner": engine.player,
            "action_token": token,
            "source_kind": "technique",
            "source_id": "probe",
            "source_name": "probe",
            "source_instance_key": context.slot_instance_id,
            "cancel_kind": cancel_kind,
            "requested_damage": 5,
            "final_damage": 0,
            "damage_type": "normal",
            "direct_attack": true,
        })
    if not event.get("success", false):
        return event
    return engine.technique_resolution_service.finish_execution(context)


func _burned_snapshot(card_id: String) -> Dictionary:
    return {
        "played_cards": [{"instance_id": card_id}],
        "contributing_cards": [{"instance_id": card_id}],
        "extra_cards": [],
        "facts_by_id": {
            card_id: {"burned_out_at_freeze": true},
        },
        "action_same_qi_gain": 0,
    }


func _pending_record_count(engine) -> int:
    var total := 0
    for entry in engine.player.source_marker_store.entries({
            "marker_id": "pending_slot_echoes", "scope": "battle"}):
        total += entry.get("records", []).size()
    return total


func _append_temporary_slot(engine, technique_id: String) -> String:
    var snapshot: Dictionary = engine.sequence_book.snapshot()
    var slots: Array = snapshot["slots_by_hand"]["high_card"]
    var temp_id := "battle-slot:high_card:009999:%s" % technique_id
    slots.append({
        "slot_schema_version": 2,
        "slot_instance_id": temp_id,
        "technique_id": technique_id,
        "hand_id": "high_card",
        "temporary": true,
        "host_sequence_qualified": true,
        "origin_technique_id": technique_id,
        "origin_slot_instance_id": "",
        "insertion_serial": 9999,
        "insertion_position": slots.size(),
        "insertion_mode": "after_current",
        "marker_mode": "independent",
        "generation_batch_token": "fixture-temp",
        "generator_source_kind": "inner_skill",
        "generator_source_id": "fixture",
        "generator_source_instance_key": "inner:player:fixture",
    })
    snapshot["slots_by_hand"]["high_card"] = slots
    snapshot["slot_capacity_by_hand"]["high_card"] = slots.size()
    engine.sequence_book.restore_snapshot(snapshot)
    return temp_id
