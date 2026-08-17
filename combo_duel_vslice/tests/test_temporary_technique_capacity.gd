extends SceneTree

const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const CombatEngineScript = preload("res://core/combat_engine.gd")
const SequenceBookScript = preload("res://core/sequence_book.gd")
const EffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const SourceMarkerAddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")
const BattleObservationScript = preload("res://core/battle_observation.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const AiBattleStateProjectorScript = preload(
    "res://core/ai/ai_battle_state_projector.gd")

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]
const POOL_MEMBERSHIP := {
    "high_card": ["high"], "pair": ["pair"], "two_pair": ["pair"],
    "three_kind": ["three"], "straight": ["straight"],
    "full_house": ["pair", "three"], "four_kind": ["bomb"],
    "five_kind": ["bomb"],
}

var failures: Array[String] = []
var assertions := 0


class QueryResult:
    extends RefCounted
    var values: Dictionary
    func _init(source: Dictionary) -> void:
        values = source
    func to_dict() -> Dictionary:
        return values.duplicate(true)


class InsightGainTwoResolver:
    extends RefCounted
    func resolve(request):
        return QueryResult.new({
            "success": true,
            "hook": request.hook,
            "subject_kind": request.subject_kind,
            "subject_id": request.subject_id,
            "base_value": request.base_value,
            "effective_value": 2 \
                if request.hook == "insight_slot_gain_query" \
                else request.base_value,
            "modifier_breakdown": [],
            "source_fingerprint": "temporary_capacity_test",
        })


func _initialize() -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    _test_sequence_capacity_and_batch_modes()
    _test_service_target_order_and_atomic_events()
    _test_random_snapshot_order_and_marker_identity()
    _test_handler_capture_events_and_capacity_changes()
    _test_battle_insight_and_same_action_generation()
    _test_host_qualification_and_public_projection()
    _test_battle_end_cleanup_and_legacy_snapshot()
    if failures.is_empty():
        print("TEMPORARY TECHNIQUE CAPACITY TEST PASS: %d assertions" % assertions)
        quit(0)
        return
    for failure in failures:
        push_error("TEMPORARY TECHNIQUE CAPACITY TEST FAIL: %s" % failure)
    quit(1)


func _test_sequence_capacity_and_batch_modes() -> void:
    var book = SequenceBookScript.new()
    book.configure_with_capacities({"high_card": ["origin"]}, {"high_card": 3})
    _assert_equal(book.slot_usage("high_card"), {
        "capacity": 3, "occupied": 1, "permanent": 1,
        "temporary": 0, "remaining": 2,
    }, "实时容量投影区分容量、永久、临时和剩余")
    var rng := RandomNumberGenerator.new()
    rng.seed = 1101
    var partial: Dictionary = book.commit_temporary_generation(
        _requests("high_card", "copy", 3, "after_current"), "partial", rng)
    _assert_true(partial.get("success", false), "partial 容量不足仍是合法效果结果")
    _assert_equal(partial.get("generated_count"), 2, "容量3且永久1门只生成2门")
    _assert_equal(partial.get("failed_count"), 1, "第3门记录容量不足")
    _assert_equal(partial.get("attempts", [])[2].get("reason"),
        "capacity_full", "容量失败写入逐项回执")
    _assert_equal(book.slot_usage("high_card")["occupied"], 3,
        "成功临时实例占用现有容量")
    var full: Dictionary = book.commit_temporary_generation(
        _requests("high_card", "copy", 1, "after_current"), "partial", rng)
    _assert_true(full.get("success", false), "已满容量不令整门功法失败")
    _assert_equal(full.get("generated_count"), 0, "已满容量生成数为0")

    book.configure_with_capacities({
        "high_card": ["origin"], "pair": ["pair_origin"]}, {
        "high_card": 2, "pair": 1,
    })
    var reversed_requests := _requests("pair", "copy", 1, "after_current")
    reversed_requests.append_array(
        _requests("high_card", "copy", 1, "after_current"))
    ## 服务会按权威顺序组织；领域入口保持收到的稳定顺序。这里显式按权威顺序提交。
    var canonical_requests := [reversed_requests[1], reversed_requests[0]]
    var ordered_partial: Dictionary = book.commit_temporary_generation(
        canonical_requests, "partial", rng)
    _assert_equal(ordered_partial["attempts"][0]["hand_id"], "high_card",
        "多牌型批次首先处理权威顺序中的高牌")
    _assert_true(ordered_partial["attempts"][0]["success"],
        "多牌型partial先生成有容量目标")
    _assert_true(not ordered_partial["attempts"][1]["success"],
        "多牌型partial继续记录已满目标")

    book.configure_with_capacities({
        "high_card": ["origin"], "pair": ["pair_origin"]}, {
        "high_card": 2, "pair": 1,
    })
    var serial_before := int(book.snapshot()["insertion_serial"])
    var rng_before := rng.state
    var atomic: Dictionary = book.commit_temporary_generation(
        canonical_requests, "atomic", rng)
    _assert_true(atomic.get("success", false), "atomic容量未满足是合法无生成结果")
    _assert_true(atomic.get("atomic_rolled_back", false), "atomic明确报告整体未提交")
    _assert_equal(atomic.get("generated_count"), 0, "atomic任一目标不足时一门也不生成")
    _assert_equal(book.snapshot()["insertion_serial"], serial_before,
        "atomic预检失败不推进插入序号")
    _assert_equal(rng.state, rng_before, "atomic预检失败不消耗随机数")

    var capacity_before := book.snapshot()
    var lowered: Dictionary = book.set_slot_capacity("high_card", 0)
    _assert_true(not lowered.get("success", false), "容量不能降低至实际占用以下")
    _assert_equal(book.snapshot(), capacity_before, "非法容量降低保持全部状态不变")


func _test_random_snapshot_order_and_marker_identity() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 2202
    var book = SequenceBookScript.new()
    book.configure_with_capacities({"high_card": ["origin"]}, {"high_card": 5})
    var origin: Dictionary = book.current_slot("high_card")
    var after: Dictionary = book.commit_temporary_generation(
        _requests("high_card", "after_copy", 2, "after_current", {
            "origin_slot_instance_id": origin["slot_instance_id"],
        }), "partial", rng)
    var after_serials: Array = book.ordered_slots("high_card").filter(
        func(slot): return bool(slot.get("temporary", false))).map(
        func(slot): return int(slot.get("insertion_serial", 0)))
    _assert_equal(after_serials, [1, 2], "多份after_current保持声明顺序不反转")
    _assert_equal(after["generated_slots"].map(
        func(slot): return str(slot["slot_instance_id"])).duplicate().size(), 2,
        "每份临时功法都有实例身份")
    _assert_true(str(after["generated_slots"][0]["slot_instance_id"]) \
        != str(after["generated_slots"][1]["slot_instance_id"]),
        "临时实例slot_instance_id在战斗内唯一")

    var random_result: Dictionary = book.commit_temporary_generation(
        _requests("high_card", "random_copy", 1, "random"), "partial", rng)
    var snapshot: Dictionary = book.snapshot()
    var restored = SequenceBookScript.new()
    restored.restore_snapshot(snapshot)
    _assert_equal(restored.snapshot(), snapshot,
        "快照恢复保持容量、实例、当前位置和插入序号")
    _assert_equal(restored.find_slots({"technique_id": "random_copy"})[0][
        "insertion_position"], random_result["generated_slots"][0][
        "insertion_position"], "随机插入位置保存后不改变")

    var resolver = SourceMarkerAddressResolverScript.new()
    var independent_a: Dictionary = resolver.resolve_for_slot({
        "source_kind": "technique", "content_id": "after_copy",
        "marker_id": "probe", "scope": "battle",
    }, after["generated_slots"][0])
    var independent_b: Dictionary = resolver.resolve_for_slot({
        "source_kind": "technique", "content_id": "after_copy",
        "marker_id": "probe", "scope": "battle",
    }, after["generated_slots"][1])
    _assert_true(independent_a["source_instance_key"] \
        != independent_b["source_instance_key"],
        "independent临时实例使用各自battle标识")

    var share_request := _requests("high_card", "shared_copy", 1,
        "before_current", {
            "marker_mode": "share_origin",
            "origin_slot_instance_id": origin["slot_instance_id"],
        })
    book.change_slot_capacity("high_card", 1)
    var shared: Dictionary = book.commit_temporary_generation(
        share_request, "partial", rng)
    var shared_address: Dictionary = resolver.resolve_for_slot({
        "source_kind": "technique", "content_id": "shared_copy",
        "marker_id": "probe", "scope": "battle",
    }, shared["generated_slots"][0])
    _assert_equal(shared_address["source_instance_key"],
        str(origin["slot_instance_id"]), "share_origin共享明确原实例battle标识")

    var before_book = SequenceBookScript.new()
    before_book.configure_with_capacities(
        {"high_card": ["origin"]}, {"high_card": 3})
    var before_result: Dictionary = before_book.commit_temporary_generation(
        _requests("high_card", "before_copy", 2, "before_current"),
        "partial", rng)
    var before_serials: Array = before_book.ordered_slots("high_card").filter(
        func(slot): return bool(slot.get("temporary", false))).map(
        func(slot): return int(slot.get("insertion_serial", 0)))
    _assert_equal(before_result["generated_count"], 2,
        "before_current多份生成完整提交")
    _assert_equal(before_serials, [1, 2],
        "多份before_current保持声明顺序不反转")


func _test_service_target_order_and_atomic_events() -> void:
    var partial_engine = _engine(2250)
    _configure_repository(partial_engine)
    partial_engine.sequence_book.configure_with_capacities({
        "high_card": ["origin"], "pair": ["foreign"]}, {
        "high_card": 2, "pair": 1,
    })
    var partial_context = _context(
        partial_engine,
        partial_engine.sequence_book.current_slot("high_card"),
        "service-order")
    var partial: Dictionary = partial_engine.effect_ports.generate_temporary_techniques({
        "technique_source": {"mode": "by_id", "technique_id": "copy"},
        "target_hands": ["pair", "high_card"],
        "copies": 1, "position": "after_current", "batch_mode": "partial",
    }, partial_context)
    _assert_equal(partial["attempts"].map(
        func(attempt): return str(attempt["hand_id"])),
        ["high_card", "pair"], "服务按权威八牌型顺序处理显式目标数组")
    _assert_equal(partial["generated_count"], 1,
        "服务partial在后续目标已满时保留前一目标成功实例")

    var atomic_engine = _engine(2251)
    _configure_repository(atomic_engine)
    atomic_engine.sequence_book.configure_with_capacities({
        "high_card": ["origin"], "pair": ["foreign"]}, {
        "high_card": 2, "pair": 1,
    })
    var atomic_context = _context(
        atomic_engine,
        atomic_engine.sequence_book.current_slot("high_card"),
        "service-atomic")
    var rng_before: int = atomic_engine.rng.state
    var insertion_before := int(
        atomic_engine.sequence_book.snapshot()["insertion_serial"])
    var events_before: int = _event_count(
        atomic_engine, "temporary_technique_generated")
    var atomic: Dictionary = atomic_engine.effect_ports.generate_temporary_techniques({
        "technique_source": {"mode": "by_id", "technique_id": "copy"},
        "target_hands": ["pair", "high_card"],
        "copies": 1, "position": "random", "batch_mode": "atomic",
    }, atomic_context)
    _assert_true(atomic.get("atomic_rolled_back", false),
        "服务atomic任一目标不足时整体不提交")
    _assert_equal(atomic_engine.rng.state, rng_before,
        "服务atomic预检失败不消耗战斗RNG")
    _assert_equal(atomic_engine.sequence_book.snapshot()["insertion_serial"],
        insertion_before, "服务atomic预检失败不推进插入序号")
    _assert_equal(_event_count(
        atomic_engine, "temporary_technique_generated"), events_before,
        "服务atomic整体未提交不发送生成成功事件")

    var all_other_engine = _engine(2252)
    _configure_repository(all_other_engine)
    var sequences: Dictionary = {}
    var capacities: Dictionary = {}
    for hand_id in HAND_IDS:
        sequences[hand_id] = ["origin"]
        capacities[hand_id] = 2
    all_other_engine.sequence_book.configure_with_capacities(
        sequences, capacities)
    var all_other_context = _context(
        all_other_engine,
        all_other_engine.sequence_book.current_slot("high_card"),
        "service-all-other")
    var all_other: Dictionary = \
        all_other_engine.effect_ports.generate_temporary_techniques({
            "technique_source": {"mode": "by_id", "technique_id": "copy"},
            "target_hands": "all_other", "copies": 1,
            "position": "after_current", "batch_mode": "atomic",
        }, all_other_context)
    _assert_equal(all_other["attempts"].map(
        func(attempt): return str(attempt["hand_id"])), HAND_IDS.slice(1),
        "all_other严格使用权威七牌型顺序")
    _assert_equal(all_other["generated_count"], 7,
        "all_other在七种目标均有空槽时生成七门")


func _test_handler_capture_events_and_capacity_changes() -> void:
    var engine = _engine(3303)
    _configure_repository(engine)
    engine.sequence_book.configure_with_capacities({
        "high_card": ["origin"]}, {"high_card": 3})
    var origin: Dictionary = engine.sequence_book.current_slot("high_card")
    var context = _context(engine, origin, "handler-generate")
    var event_count_before := _event_count(
        engine, "temporary_technique_generated")
    var execution: Dictionary = engine.effect_executor.execute_all([{
        "op": "generate_temporary_techniques",
        "technique_source": "current_source",
        "target_hands": "current",
        "copies": 3,
        "position": "after_current",
        "marker_mode": "independent",
        "batch_mode": "partial",
        "capture": "generation",
    }, {
        "op": "defense",
        "amount": {
            "kind": "capture_field_first",
            "capture": "generation",
            "field": "generated_count",
        },
    }], context)
    _assert_true(execution.get("success", false), "正式Handler只通过端口完成临时生成")
    var captured: Dictionary = context.captures["generation"][0]
    _assert_equal(captured["generated_count"], 2,
        "统一capture公开实际generated_count")
    _assert_equal(engine.player.defense, 2,
        "后续ValueSpec可以读取capture中的实际generated_count")
    _assert_equal(_event_count(engine, "temporary_technique_generated") \
        - event_count_before, 2, "每个实际成功实例只发送一次生成事件")
    _assert_equal(_event_count(engine, "technique_sequence_changed"), 1,
        "整个生成批次完成后只发送一次序列变化事件")

    var full_events := _event_count(engine, "temporary_technique_generated")
    var full_result: Dictionary = engine.effect_ports.generate_temporary_techniques({
        "technique_source": {"mode": "by_id", "technique_id": "copy"},
        "target_hands": "current", "copies": 1,
        "position": "random", "batch_mode": "partial",
    }, context)
    _assert_true(full_result.get("success", false), "容量失败仍返回统一成功回执")
    _assert_equal(full_result["generated_count"], 0, "容量已满不生成实例")
    _assert_equal(_event_count(engine, "temporary_technique_generated"),
        full_events, "容量失败不发送生成成功事件")

    var missing_origin: Dictionary = engine.effect_ports.generate_temporary_techniques({
        "technique_source": {"mode": "by_id", "technique_id": "copy"},
        "target_hands": "current", "copies": 1,
        "marker_mode": "share_origin",
    }, context)
    _assert_true(not missing_origin.get("success", false),
        "share_origin缺少真实原实例时请求失败")

    var capacity_events_before := _event_count(
        engine, "technique_slot_capacity_changed")
    var capacity_changed: Dictionary = engine.effect_ports.change_technique_slot_capacity(
        engine.player, "high_card", 1, {
            "source_kind": "item", "source_id": "probe_item",
            "source_name": "测试物品", "source_instance_key": "item:probe_item",
            "action_token": "capacity-change",
        })
    _assert_true(capacity_changed.get("success", false), "统一端口实时增加战斗容量")
    _assert_equal(_event_count(engine, "technique_slot_capacity_changed") \
        - capacity_events_before, 1, "实际容量变化只发送一次统一事件")
    engine.effect_ports.change_technique_slot_capacity(
        engine.player, "high_card", 0, {"source_kind": "rule"})
    _assert_equal(_event_count(engine, "technique_slot_capacity_changed") \
        - capacity_events_before, 1, "容量无实际变化不发送事件")
    var explicit_slot: Dictionary = engine.effect_ports.generate_temporary_techniques({
        "technique_source": {
            "mode": "by_slot",
            "slot_instance_id": str(origin["slot_instance_id"]),
        },
        "target_hands": "current", "copies": 1,
        "position": "before_current", "marker_mode": "share_origin",
        "batch_mode": "atomic",
    }, context)
    _assert_equal(explicit_slot["generated_count"], 1,
        "统一请求可以复制明确声明的实际功法槽实例")
    _assert_equal(explicit_slot["generated_slots"][0]["origin_slot_instance_id"],
        origin["slot_instance_id"], "明确槽位来源保留原稳定实例身份")


func _test_battle_insight_and_same_action_generation() -> void:
    var engine = _engine(4404)
    _configure_repository(engine)
    var progression := _basic_progression()
    engine.player.hand_technique_progression = progression.duplicate(true)
    engine.player.hand_technique_progression_active = true
    engine.player.owned_technique_ids.assign(["origin"])
    engine.sequence_book.configure_hand_progression(progression)
    engine.player.technique_loadout_policy.use_int_policy_resolver(
        InsightGainTwoResolver.new())
    var slot_before: Dictionary = engine.sequence_book.current_slot("high_card")
    var position_before: int = engine.sequence_book.position("high_card")
    var insight: Dictionary = engine.player.apply_insight_growth(
        "high_card", [], null, {
            "source_kind": "rule", "source_id": "insight_probe",
            "source_instance_key": "rule:insight_probe",
            "action_token": "insight-and-generate",
        })
    _assert_true(insight.get("success", false), "战斗中心得永久成长提交成功")
    _assert_equal(insight["slot_gain"], 2, "心得查询+2得到实际永久增量2")
    _assert_equal(engine.player.hand_technique_progression[
        "high_card"]["slot_count"], 3, "永久容量立即增加2")
    _assert_equal(engine.sequence_book.slot_capacity("high_card"), 3,
        "当前战斗容量立即同步实际+2")
    _assert_equal(engine.sequence_book.occupied_slot_count("high_card"), 1,
        "心得不重建或自动装备当前序列")
    _assert_equal(engine.sequence_book.position("high_card"), position_before,
        "实时增容不改变当前位置")
    _assert_equal(engine.sequence_book.current_slot("high_card")[
        "slot_instance_id"], slot_before["slot_instance_id"],
        "实时增容不改变已有稳定实例ID")
    _assert_true(not insight["technique_equipped"], "心得所得功法明确不自动装备")
    var context = _context(
        engine, engine.sequence_book.current_slot("high_card"),
        "insight-and-generate")
    var generated: Dictionary = engine.effect_ports.generate_temporary_techniques({
        "technique_source": {"mode": "by_id", "technique_id": "copy"},
        "target_hands": "current", "copies": 2,
        "position": "after_current", "batch_mode": "atomic",
    }, context)
    _assert_equal(generated["generated_count"], 2,
        "心得同一行动后续效果立即使用新增的两个空槽")

    var progression_snapshot: Dictionary = \
        engine.player.hand_technique_progression.duplicate(true)
    engine.sequence_book.set_slot_capacity("pair", 2)
    var mismatched: Dictionary = engine.player.apply_insight_growth(
        "pair", [], null, {"source_kind": "rule"})
    _assert_true(not mismatched.get("success", false),
        "永久与战斗容量不一致时心得提交失败关闭")
    _assert_equal(engine.player.hand_technique_progression,
        progression_snapshot, "容量同步系统错误回滚永久成长")


func _test_host_qualification_and_public_projection() -> void:
    var engine = _engine(5505)
    _configure_repository(engine)
    engine.sequence_book.configure_with_capacities({
        "high_card": ["origin"]}, {"high_card": 3})
    var context = _context(
        engine, engine.sequence_book.current_slot("high_card"), "host-copy")
    var generated: Dictionary = engine.effect_ports.generate_temporary_techniques({
        "technique_source": {"mode": "by_id", "technique_id": "foreign"},
        "target_hands": "current", "copies": 1,
        "position": "after_current", "batch_mode": "partial",
    }, context)
    var foreign_slot: Dictionary = generated["generated_slots"][0]
    _assert_true(foreign_slot["host_sequence_qualified"],
        "跨牌型临时实例声明宿主池资格")
    var foreign_definition = engine.repository.get_definition("foreign")
    var high_result := {"id": "high_card", "contributing": []}
    _assert_true(not engine.repository.conditions_met(
        foreign_definition, high_result, null, false)["ok"],
        "原功法不属于宿主牌型时普通资格检查失败")
    _assert_true(engine.repository.conditions_met(
        foreign_definition, high_result, null,
        bool(foreign_slot["host_sequence_qualified"]))["ok"],
        "跨牌型实例只跳过原池归属限制")
    var conditioned_definition = engine.repository.get_definition(
        "foreign_conditioned")
    _assert_true(not engine.repository.conditions_met(
        conditioned_definition, high_result, null, true)["ok"],
        "宿主池资格不能跳过其他功法条件")

    var sequence_shape: Dictionary = engine.sequence_book.public_snapshot()
    var usage_shape: Dictionary = engine.sequence_book.public_slot_usage_snapshot()
    _assert_true(sequence_shape["high_card"] is Array,
        "原technique_sequences仍保持牌型到实际实例数组的形状")
    _assert_equal(usage_shape["high_card"]["capacity"], 3,
        "公开slot usage独立公开实时容量")
    var observation = BattleObservationScript.new().capture(
        engine.player, engine.enemy, engine.sequence_book, engine.battle_flow)
    _assert_true(observation.public_snapshot().has("technique_slot_usage"),
        "BattleObservation公开独立容量投影")
    var session_snapshot = BattleSessionScript.new(engine).snapshot()
    _assert_true(session_snapshot.player.technique_slot_usage.has("high_card"),
        "BattleSideSnapshot公开独立容量投影")
    var ai_state: Dictionary = AiBattleStateProjectorScript.new().project_self(
        engine.player, engine.sequence_book, engine.battle_flow)
    _assert_true(ai_state.has("technique_slot_usage"),
        "AI战斗状态公开独立容量投影")


func _test_battle_end_cleanup_and_legacy_snapshot() -> void:
    var engine = _engine(6606)
    _configure_repository(engine)
    var progression := _basic_progression()
    progression["high_card"]["slot_count"] = 3
    engine.player.hand_technique_progression = progression.duplicate(true)
    engine.player.hand_technique_progression_active = true
    engine.sequence_book.configure_hand_progression(progression)
    var permanent_slot: Dictionary = engine.sequence_book.current_slot("high_card")
    var context = _context(engine, permanent_slot, "battle-end-cleanup")
    var generated: Dictionary = engine.effect_ports.generate_temporary_techniques({
        "technique_source": {"mode": "by_id", "technique_id": "copy"},
        "target_hands": "current", "copies": 2,
        "position": "after_current", "batch_mode": "atomic",
    }, context)
    engine.sequence_book.move_slot_to_current(
        "high_card", generated["generated_slots"][0]["slot_instance_id"])
    var ended: Dictionary = engine.timing_system.emit_timing("battle_end", {
        "actors": [engine.player, engine.enemy],
    })
    _assert_true(ended.get("success", false), "现有BATTLE_END最终编排完成")
    _assert_equal(engine.sequence_book.temporary_slot_count("high_card"), 0,
        "BATTLE_END删除全部临时功法并释放占用")
    _assert_equal(engine.sequence_book.slot_capacity("high_card"), 3,
        "BATTLE_END不回退当前实时容量")
    _assert_equal(engine.sequence_book.current_slot("high_card")[
        "slot_instance_id"], permanent_slot["slot_instance_id"],
        "当前指向临时实例时确定性落到仍存在永久实例")
    _assert_equal(engine.player.hand_technique_progression[
        "high_card"]["sequence"], ["basic_scatter"],
        "战斗结束不把临时功法写回永久配装")
    _assert_true(not engine.player.owned_technique_ids.has("copy"),
        "战斗结束不把临时功法加入本局功法库")

    var legacy = SequenceBookScript.new()
    legacy.restore_snapshot({
        "schema_version": 1,
        "slots_by_hand": engine.sequence_book.snapshot()[
            "slots_by_hand"].duplicate(true),
        "initial_slots_by_hand": engine.sequence_book.snapshot()[
            "initial_slots_by_hand"].duplicate(true),
        "current_slot_ids": engine.sequence_book.snapshot()[
            "current_slot_ids"].duplicate(true),
        "insertion_serial": 0,
    })
    _assert_equal(legacy.slot_capacity("high_card"),
        legacy.occupied_slot_count("high_card"),
        "旧快照无容量字段时按实际槽位数量兼容推导")
    var old_config = SequenceBookScript.new()
    old_config.configure({"high_card": ["a", "b"], "pair": []})
    _assert_equal(old_config.slot_capacity("high_card"), 2,
        "旧configure入口容量默认等于实际序列长度")
    _assert_equal(old_config.slot_capacity("pair"), 0,
        "旧configure显式空序列默认容量为0")


func _engine(seed_value: int):
    var engine = CombatEngineScript.new()
    engine.setup(seed_value, false, [])
    return engine


func _configure_repository(engine) -> void:
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {},
        "resource_paths": [],
        "techniques": [
            {"id": "origin", "name": "原功法", "pool": "high",
                "special": false, "effects": []},
            {"id": "copy", "name": "临时副本", "pool": "high",
                "special": false, "effects": []},
            {"id": "foreign", "name": "跨池功法", "pool": "pair",
                "special": false, "effects": []},
            {"id": "foreign_conditioned", "name": "有条件跨池功法",
                "pool": "pair", "special": false,
                "condition": {"pure_attribute": "fire"}, "effects": []},
        ],
    })


func _basic_progression() -> Dictionary:
    var result: Dictionary = {}
    for hand_id in HAND_IDS:
        result[hand_id] = {
            "slot_count": 1,
            "sequence": ["basic_scatter"],
        }
    return result


func _context(engine, slot: Dictionary, action_token: String):
    return EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "owner": engine.player,
        "actual_hand_id": "high_card",
        "hand_result": {"id": "high_card", "contributing": []},
        "played_cards": [],
        "technique_id": str(slot.get("technique_id", "")),
        "technique_name": str(slot.get("technique_id", "")),
        "slot_instance_id": str(slot.get("slot_instance_id", "")),
        "source_kind": "technique",
        "source_id": str(slot.get("technique_id", "")),
        "source_instance_key": str(slot.get("slot_instance_id", "")),
        "sequence_book": engine.sequence_book,
        "action_token": action_token,
        "root_action_token": action_token,
        "captures": {},
    })


func _requests(
        hand_id: String,
        technique_id: String,
        copies: int,
        position: String,
        options: Dictionary = {}) -> Array:
    var result: Array = []
    for copy_index in range(copies):
        var request := {
            "hand_id": hand_id,
            "copy_index": copy_index,
            "technique_id": technique_id,
            "position": position,
            "marker_mode": str(options.get("marker_mode", "independent")),
            "origin_technique_id": str(options.get(
                "origin_technique_id", technique_id)),
            "origin_slot_instance_id": str(options.get(
                "origin_slot_instance_id", "")),
            "generation_batch_token": "test-batch",
            "generator_source_kind": "rule",
            "generator_source_id": "test",
            "generator_source_instance_key": "rule:test",
        }
        result.append(request)
    return result


func _event_count(engine, event_kind: String) -> int:
    return engine.battle_passive_event_service.receipt_store._receipts.values().filter(
        func(receipt): return str(receipt.get("event_kind", "")) == event_kind).size()


func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [
            label, str(expected), str(actual)])


func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append("%s：期望为 true" % label)
