extends "res://tests/support/expanded_technique_test_base.gd"

const TechniqueDefinitionScript = preload("res://core/technique_definition.gd")
const ContentValidatorScript = preload("res://core/content_validator.gd")
const SourceMarkerStoreScript = preload("res://core/source_marker_store.gd")
const SourceMarkerAddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")
const BattleEffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const ConditionSpecRegistryScript = preload(
    "res://core/specs/condition_spec_registry.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const AiBattleStateProjectorScript = preload(
    "res://core/ai/ai_battle_state_projector.gd")

const POOL_MEMBERSHIP := {
    "high_card": ["high"], "pair": ["pair"], "two_pair": ["pair"],
    "three_kind": ["three"], "straight": ["straight"],
    "full_house": ["pair", "three"], "four_kind": ["bomb"],
    "five_kind": ["bomb"],
}


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_definition_contract_and_validation()
    _test_zero_lifecycle_and_typed_ports()
    _test_slot_and_temporary_instance_isolation()
    _test_condition_manual_branch_and_effect_capture()
    _test_delay_response_identity_and_snapshot()
    _test_batch_rollback_and_committed_failure()
    _test_public_projection_and_battle_cleanup()
    _finish("CHARGING PRIMARY VALUE PROTOCOL TEST")


func _test_definition_contract_and_validation() -> void:
    var raw := _definition("charging_contract", [], {
        "minimum": 2, "maximum": 12,
        "allowed_operations": ["add", "subtract", "set", "clear"],
    })
    var definition = TechniqueDefinitionScript.new().configure_from_dictionary(raw)
    _assert_equal(definition.charging, raw["charging"],
        "TechniqueDefinition 接收 charging 声明")
    _assert_equal(definition.to_definition()["charging"], raw["charging"],
        "to_definition 保留 charging 声明")
    _assert_equal(definition.snapshot()["charging"], raw["charging"],
        "snapshot 保留 charging 声明")
    var restored = TechniqueDefinitionScript.new().configure_from_dictionary(
        definition.to_definition())
    _assert_equal(restored.charging, raw["charging"],
        "功法资源字典往返保持 charging")

    var valid_markers: Array = raw["marker_definitions"]
    _assert_charging_validation({}, valid_markers, true, "空 charging 合法")
    _assert_charging_validation(raw["charging"], valid_markers, true,
        "完整 charging 声明合法")
    _assert_charging_validation(raw["charging"], [], false,
        "primary_marker_id 不存在时报错")
    _assert_charging_validation(raw["charging"], [{
        "id": "charge", "scope": "run", "public": true,
    }], false, "charging marker 非 battle scope 报错")
    _assert_charging_validation(raw["charging"], [{
        "id": "charge", "scope": "battle", "public": false,
    }], false, "charging marker 非公开报错")
    var invalid_operation: Dictionary = raw["charging"].duplicate(true)
    invalid_operation["allowed_operations"] = ["add", "multiply"]
    _assert_charging_validation(invalid_operation, valid_markers, false,
        "非法 allowed_operation 报错")
    var duplicate_operation: Dictionary = raw["charging"].duplicate(true)
    duplicate_operation["allowed_operations"] = ["add", "add"]
    _assert_charging_validation(duplicate_operation, valid_markers, false,
        "重复 allowed_operation 报错")
    var invalid_maximum: Dictionary = raw["charging"].duplicate(true)
    invalid_maximum["minimum"] = 5
    invalid_maximum["maximum"] = 4
    _assert_charging_validation(invalid_maximum, valid_markers, false,
        "maximum 小于 minimum 报错")
    var countdown_in_charging: Dictionary = raw["charging"].duplicate(true)
    countdown_in_charging["countdown"] = 3
    _assert_charging_validation(countdown_in_charging, valid_markers, false,
        "charging 不接受具体倒计时字段")


func _test_zero_lifecycle_and_typed_ports() -> void:
    var store = SourceMarkerStoreScript.new()
    var created: Dictionary = store.write(
        "technique", "slot:a", "probe", "charge", "battle", "set", 0)
    _assert_true(created.get("created", false) and created.get("changed", false),
        "SourceMarkerStore 创建零值条目属于实际变化")
    _assert_true(not created.get("existed_before", true) \
        and created.get("exists_after", false), "零值创建公开存在性生命周期")
    var repeated: Dictionary = store.write(
        "technique", "slot:a", "probe", "charge", "battle", "set", 0)
    _assert_true(not repeated.get("changed", true),
        "已有 marker 重复 set 同值不伪造变化")
    var removed: Dictionary = store.write(
        "technique", "slot:a", "probe", "charge", "battle", "clear", 0)
    _assert_true(removed.get("removed", false) and removed.get("changed", false),
        "删除零值条目属于实际变化")
    var absent_clear: Dictionary = store.write(
        "technique", "slot:a", "probe", "charge", "battle", "clear", 0)
    _assert_true(not absent_clear.get("changed", true),
        "清理不存在 marker 不伪造变化")

    var engine = _charging_engine(19001, ["charging_probe"])
    var slot: Dictionary = engine.sequence_book.current_slot("high_card")
    var events: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "source_marker_changed":
                events.append(values.duplicate(true)))
    var write_inactive: Dictionary = engine.effect_ports.write_charging_primary_value(
        engine.player, slot["slot_instance_id"], "add", 1, "inactive")
    _assert_true(not write_inactive.get("success", true),
        "write 不能意外启动未激活实例")
    var begun: Dictionary = engine.effect_ports.begin_technique_charging(
        engine.player, slot["slot_instance_id"], 0, "begin-zero")
    _assert_true(begun.get("success", false) and begun.get("created", false),
        "begin 0 创建 marker 并进入蓄力")
    _assert_true(engine.effect_ports.is_technique_charging(
        engine.player, slot["slot_instance_id"]), "零值 marker 判定为正在蓄力")
    _assert_equal(events.size(), 1, "创建零值 marker 发送一次 committed 事件")
    _assert_true(events[0].get("created", false) \
        and str(events[0].get("marker_role", "")) == "charging_primary",
        "source_marker_changed 公开 created 与 marker_role")
    _assert_equal(events[0].get("slot_instance_id"), slot["slot_instance_id"],
        "source_marker_changed 公开精确 slot_instance_id")
    var begin_again: Dictionary = engine.effect_ports.begin_technique_charging(
        engine.player, slot["slot_instance_id"], 8, "begin-again")
    _assert_true(begin_again.get("already_active", false),
        "重复 begin 返回 already_active")
    _assert_equal(engine.effect_ports.technique_charging_state(
        engine.player, slot["slot_instance_id"])["current_value"], 0,
        "重复 begin 默认保留累计值")
    _assert_equal(events.size(), 1, "重复 begin 不发送变化事件")

    var added: Dictionary = engine.effect_ports.write_charging_primary_value(
        engine.player, slot["slot_instance_id"], "add", 15, "clamp-max")
    _assert_equal(added.get("requested_amount"), 15, "write 返回 requested_amount")
    _assert_equal(added.get("after"), 10, "maximum 正确限制主要蓄力值")
    _assert_equal(added.get("actual_delta"), 10, "write 返回 actual_delta")
    var subtracted: Dictionary = engine.effect_ports.write_charging_primary_value(
        engine.player, slot["slot_instance_id"], "subtract", 30, "clamp-min")
    _assert_equal(subtracted.get("after"), 0, "minimum 正确限制主要蓄力值")
    _assert_true(engine.effect_ports.is_technique_charging(
        engine.player, slot["slot_instance_id"]), "subtract 到0仍在蓄力")
    var event_count := events.size()
    var set_zero: Dictionary = engine.effect_ports.write_charging_primary_value(
        engine.player, slot["slot_instance_id"], "set", 0, "set-zero")
    _assert_true(set_zero.get("success", false) \
        and not set_zero.get("changed", true), "重复 set 0 不产生实际变化")
    _assert_equal(events.size(), event_count, "无实际变化不发送事件")
    var ended: Dictionary = engine.effect_ports.end_technique_charging(
        engine.player, slot["slot_instance_id"], "end-zero")
    _assert_true(ended.get("removed", false), "end 删除零值 marker")
    _assert_equal(ended.get("final_value"), 0, "end 返回结束前最终累计值")
    _assert_true(not engine.effect_ports.is_technique_charging(
        engine.player, slot["slot_instance_id"]), "clear 后结束蓄力")
    _assert_true(events[-1].get("removed", false),
        "删除零值 marker 发送 removed 事件")
    var ended_again: Dictionary = engine.effect_ports.end_technique_charging(
        engine.player, slot["slot_instance_id"], "end-again")
    _assert_true(ended_again.get("success", false) \
        and not ended_again.get("changed", true), "重复 end 不伪造变化")

    var restricted = _charging_engine(19008, ["charging_probe"])
    restricted.repository.techniques["charging_probe"]["charging"][
        "allowed_operations"] = ["add"]
    restricted.repository.definitions.erase("charging_probe")
    var restricted_slot: Dictionary = restricted.sequence_book.current_slot(
        "high_card")
    restricted.effect_ports.begin_technique_charging(
        restricted.player, restricted_slot["slot_instance_id"], 0, "restricted")
    _assert_true(not restricted.effect_ports.write_charging_primary_value(
        restricted.player, restricted_slot["slot_instance_id"], "set", 3,
        "restricted-set").get("success", true),
        "运行时严格校验 allowed_operations")
    _assert_true(not restricted.effect_ports.write_charging_primary_value(
        restricted.player, restricted_slot["slot_instance_id"], "add", -1,
        "negative-add").get("success", true),
        "add/subtract 不能用负数绕过操作声明")


func _test_slot_and_temporary_instance_isolation() -> void:
    var engine = _charging_engine(
        19002, ["charging_probe", "charging_probe"], 4)
    var permanent_slots: Array = engine.sequence_book.ordered_slots("high_card")
    engine.effect_ports.begin_technique_charging(
        engine.player, permanent_slots[0]["slot_instance_id"], 3, "permanent-a")
    engine.effect_ports.begin_technique_charging(
        engine.player, permanent_slots[1]["slot_instance_id"], 7, "permanent-b")
    var permanent_active: Array = engine.effect_ports.charging_technique_instances(
        engine.player)
    _assert_equal(permanent_active.map(func(entry): return entry["current_value"]),
        [3, 7], "同一功法两个永久槽位分别保存累计值")
    _assert_true(permanent_active[0]["source_instance_key"] \
        != permanent_active[1]["source_instance_key"],
        "同功法永久槽位使用不同 source_instance_key")
    var first_projection: Dictionary = permanent_active[0]
    first_projection["marker_entry"]["value"] = 99
    _assert_equal(engine.effect_ports.technique_charging_state(
        engine.player, permanent_slots[0]["slot_instance_id"])["current_value"], 3,
        "枚举返回值是副本")

    var origin_slot: Dictionary = permanent_slots[0]
    var generated: Dictionary = engine.sequence_book.commit_temporary_generation([
        _temporary_request("charging_probe", 0, origin_slot, "share_origin"),
        _temporary_request("charging_probe", 1, origin_slot, "share_origin"),
    ], "atomic", engine.rng)
    _assert_equal(generated.get("generated_count"), 2, "生成两个临时功法副本")
    var temporary_slots: Array = generated["generated_slots"]
    engine.effect_ports.begin_technique_charging(
        engine.player, temporary_slots[0]["slot_instance_id"], 4, "temporary-a")
    engine.effect_ports.begin_technique_charging(
        engine.player, temporary_slots[1]["slot_instance_id"], 9, "temporary-b")
    var temporary_active: Array = engine.effect_ports.charging_technique_instances(
        engine.player).filter(func(entry): return entry.get("temporary", false))
    _assert_equal(temporary_active.map(func(entry): return entry["current_value"]),
        [4, 9], "两个临时副本的主要蓄力值独立")
    _assert_equal(temporary_active.map(
        func(entry): return entry["source_instance_key"]),
        temporary_slots.map(func(slot): return slot["slot_instance_id"]),
        "share_origin 临时副本的 charging marker 仍按实际槽位隔离")

    var resolver = SourceMarkerAddressResolverScript.new()
    var ordinary_a: Dictionary = resolver.resolve_for_slot({
        "source_kind": "technique", "content_id": "charging_probe",
        "marker_id": "ordinary", "scope": "battle",
    }, temporary_slots[0])
    var ordinary_b: Dictionary = resolver.resolve_for_slot({
        "source_kind": "technique", "content_id": "charging_probe",
        "marker_id": "ordinary", "scope": "battle",
    }, temporary_slots[1])
    _assert_equal(ordinary_a["source_instance_key"],
        origin_slot["slot_instance_id"], "普通 marker 继续 share_origin")
    _assert_equal(ordinary_b["source_instance_key"],
        origin_slot["slot_instance_id"], "多个临时副本普通 marker 继续合并")

    var removed_id := str(temporary_slots[0]["slot_instance_id"])
    engine.sequence_book.release_all_temporary_slots()
    _assert_true(not engine.effect_ports.charging_technique_instances(
        engine.player).any(func(entry):
            return str(entry["slot_instance_id"]) == removed_id),
        "已移出序列的槽位不再枚举为有效蓄力实例")
    _assert_true(not engine.effect_ports.technique_charging_state(
        engine.player, removed_id).get("success", true),
        "已移出序列的槽位不能继续作为写目标")


func _test_condition_manual_branch_and_effect_capture() -> void:
    var effects := [{
        "op": "defense", "amount": 4,
        "when": {"charging_active": true, "trigger_mode": "manual"},
    }, {
        "op": "begin_technique_charging", "initial_value": 0,
        "when": {"charging_active": false, "trigger_mode": "manual"},
    }]
    var engine = _charging_engine(19003, ["charging_probe"], 1, effects)
    var first = _card("5", "wind")
    engine.player.hand = [first]
    var slot: Dictionary = engine.sequence_book.current_slot("high_card")
    var preview: Dictionary = engine.preview([first.id])
    var first_result: Dictionary = engine.confirm_play([first.id])
    _assert_true(first_result.get("technique_triggered", false),
        "首次主动触发仍是正常成功功法：%s" % str(first_result))
    if not first_result.has("preview"):
        return
    _assert_equal(first_result["preview"]["values"]["technique_value"],
        preview["values"]["technique_value"], "首次主动触发 P 与预览一致")
    _assert_equal(engine.player.defense, 0,
        "首次主动触发执行 charging_active=false 分支")
    _assert_true(engine.effect_ports.is_technique_charging(
        engine.player, slot["slot_instance_id"]), "首次主动触发建立蓄力 marker")
    _assert_equal(engine.sequence_book.current_slot("high_card")[
        "slot_instance_id"], slot["slot_instance_id"],
        "单槽蓄力功法仍正常推进并回到同一序列槽")

    var second = _card("6", "wind")
    engine.player.hand = [second]
    engine.actions_available = 1
    engine.player.momentum_value = 3
    var same_qi_before: int = int(engine.player.same_qi_value)
    var second_preview: Dictionary = engine.preview([second.id])
    var second_result: Dictionary = engine.confirm_play([second.id])
    _assert_true(second_result.get("technique_triggered", false),
        "蓄力期间再次主动触发仍是正常成功功法")
    _assert_equal(second_result["preview"]["values"]["momentum_used"], 3,
        "再次主动触发正常读取连势")
    _assert_equal(second_result["preview"]["values"]["technique_value"],
        second_preview["values"]["technique_value"], "再次触发正常计算 P")
    _assert_true(engine.player.same_qi_value >= same_qi_before,
        "再次主动触发继续走既有同气结算")
    _assert_equal(engine.player.defense, 4,
        "再次主动触发执行 charging_active=true 分支")
    _assert_true(engine.effect_ports.is_technique_charging(
        engine.player, slot["slot_instance_id"]),
        "再次主动触发不默认引爆或清理 marker")

    var condition_registry = ConditionSpecRegistryScript.new()
    for trigger_mode in ["automatic", "invoked", "echo", "retrigger"]:
        var context = _context(engine, slot, trigger_mode)
        _assert_true(condition_registry.evaluate({
            "charging_active": true,
            "trigger_mode": trigger_mode,
        }, context), "%s 可与 charging_active 组合" % trigger_mode)
        _assert_true(not condition_registry.evaluate({
            "charging_active": true,
            "trigger_mode": "manual",
        }, context), "%s 不会误走 manual 分支" % trigger_mode)
    var explicit_context = _context(engine, slot, "automatic")
    explicit_context.slot_instance_id = ""
    _assert_true(condition_registry.evaluate({
        "charging_active": true,
        "charging_slot_instance_id": slot["slot_instance_id"],
    }, explicit_context), "ConditionSpec 可只读判断指定 slot")

    var capture_engine = _charging_engine(
        19004, ["charging_probe", "charging_probe"], 2)
    var slots: Array = capture_engine.sequence_book.ordered_slots("high_card")
    capture_engine.effect_ports.begin_technique_charging(
        capture_engine.player, slots[0]["slot_instance_id"], 0, "capture-first")
    var capture_context = _context(capture_engine, slots[0], "manual")
    var pending: Dictionary = capture_engine.effect_executor.execute_all([
        {"op": "capture_charging_techniques", "capture": "frozen_charging"},
        {"op": "select_option", "choice_id": "continue", "options": [
            {"id": "yes", "name": "继续"}], "minimum": 1, "maximum": 1},
        {"op": "write_all_charging_primary", "operation": "add", "amount": 5,
            "target_capture": "frozen_charging"},
    ], capture_context)
    _assert_true(pending.get("pending_choice", false), "效果链进入等待选择")
    _assert_true(condition_registry.evaluate({
        "charging_active": true,
        "charging_capture": "frozen_charging",
    }, capture_context), "ConditionSpec 可只读判断已捕获功法实例")
    capture_engine.effect_ports.begin_technique_charging(
        capture_engine.player, slots[1]["slot_instance_id"], 0, "capture-second")
    var resumed: Dictionary = capture_engine.effect_executor.resume(
        pending["_continuation"], pending["choice_request"]["request_id"], ["yes"])
    _assert_true(resumed.get("success", false), "等待选择后恢复效果链")
    _assert_equal(capture_engine.effect_ports.technique_charging_state(
        capture_engine.player, slots[0]["slot_instance_id"])["current_value"], 5,
        "capture 冻结的原目标只累计一次")
    _assert_equal(capture_engine.effect_ports.technique_charging_state(
        capture_engine.player, slots[1]["slot_instance_id"])["current_value"], 0,
        "等待期间新增蓄力实例不进入已冻结批次")


func _test_delay_response_identity_and_snapshot() -> void:
    var engine = _charging_engine(19005, ["charging_probe"])
    var slot: Dictionary = engine.sequence_book.current_slot("high_card")
    engine.effect_ports.begin_technique_charging(
        engine.player, slot["slot_instance_id"], 1, "delay-begin")
    var context = _context(engine, slot, "manual")
    context.root_action_token = "root-delay"
    context.technique_execution_token = "execution-delay"
    context.invocation_token = "invocation-delay"
    var delayed: Dictionary = engine.status_system.status_delay_service \
        .register_effect_chain("蓄力延迟探针", "turn_end", 2, [{
            "op": "write_charging_primary", "operation": "add", "amount": 2,
        }], context)
    _assert_true(delayed.get("success", false), "使用现有 StatusDelayService 登记延迟")
    var delay_record: Dictionary = delayed["record"]
    _assert_equal(delay_record.get("slot_instance_id"), slot["slot_instance_id"],
        "延迟记录保存实际 slot_instance_id")
    _assert_equal(delay_record.get("root_action_token"), "root-delay",
        "延迟记录保存 root_action_token")
    _assert_equal(delay_record.get("technique_execution_token"), "execution-delay",
        "延迟记录保存 execution token")
    var remaining_before := int(delay_record["remaining_occurrences"])
    engine.effect_ports.write_charging_primary_value(
        engine.player, slot["slot_instance_id"], "add", 1, "no-countdown")
    _assert_equal(delay_record["remaining_occurrences"], remaining_before,
        "修改主要蓄力值不推进倒计时")
    _assert_equal(engine.status_system.status_response_service.records().size(), 0,
        "修改主要值不建立响应或自动触发功法")
    engine.status_system.status_delay_service.resolve_turn_end_effects(
        engine.player, 1)
    _assert_equal(engine.effect_ports.technique_charging_state(
        engine.player, slot["slot_instance_id"])["current_value"], 4,
        "延迟恢复后仍写入发起蓄力的同一实际槽位")

    var response: Dictionary = engine.status_system.register_response(
        "turn_end", "turn_end", [], context)
    _assert_true(response.get("success", false), "使用现有 StatusResponseService 登记观察")
    _assert_equal(response["record"].get("slot_instance_id"),
        slot["slot_instance_id"], "响应记录保存实际 slot_instance_id")
    _assert_equal(response["record"].get("technique_execution_token"),
        "execution-delay", "响应记录保存 execution token")

    var snapshot: Dictionary = engine.player.capture_passive_query_state()
    engine.effect_ports.write_charging_primary_value(
        engine.player, slot["slot_instance_id"], "add", 9, "snapshot-change")
    engine.status_system.status_delay_service.clear()
    engine.player.replace_passive_query_state(snapshot)
    _assert_equal(engine.effect_ports.technique_charging_state(
        engine.player, slot["slot_instance_id"])["current_value"], 4,
        "战斗状态快照往返保持主要蓄力 marker")
    _assert_equal(engine.status_system.status_delay_service.records().size(), 1,
        "战斗状态快照往返保持延迟记录")
    _assert_equal(engine.status_system.status_delay_service.records()[0].get(
        "slot_instance_id"), slot["slot_instance_id"],
        "快照恢复后的延迟仍指向原槽位")


func _test_batch_rollback_and_committed_failure() -> void:
    var engine = _charging_engine(
        19006, ["charging_probe", "charging_probe"], 2)
    var slots: Array = engine.sequence_book.ordered_slots("high_card")
    for index in range(slots.size()):
        engine.effect_ports.begin_technique_charging(
            engine.player, slots[index]["slot_instance_id"], index + 1,
            "batch-begin-%d" % index)
    var failure_id := "charging_write_failure_probe"
    engine.content_catalog._indexes["item"][failure_id] = {
        "id": failure_id, "name": "蓄力批次失败探针",
        "behaviors": [{
            "id": "battle_effects",
            "configuration": {
                "hook": "source_marker_changed",
                "filters": {"slot_instance_id": slots[1]["slot_instance_id"]},
                "effects": [{"op": "unsupported_charging_test_op"}],
            },
        }],
    }
    engine.player.item_ids.assign([failure_id])
    var state_before: Dictionary = engine.player.capture_passive_query_state()
    var event_before: Dictionary = engine.battle_passive_event_service \
        .capture_transaction_state()
    var queue_before: Dictionary = engine.trigger_queue.capture_runtime_state()
    var rng_before := int(engine.rng.state)
    var published: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, _values: Dictionary, _receipt: Dictionary):
            published.append(kind))
    var failed: Dictionary = engine.effect_ports.write_all_charging_primary_values(
        engine.player, "add", 5, "batch-failure")
    _assert_true(not failed.get("success", true) \
        and failed.get("rolled_back", false), "write_all 中途失败整批回滚")
    _assert_equal(engine.player.capture_passive_query_state(), state_before,
        "批量失败恢复 marker、延迟响应、被动状态与序列")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        event_before, "批量失败恢复 event serial、receipt 与 execution history")
    _assert_equal(engine.trigger_queue.capture_runtime_state(), queue_before,
        "批量失败恢复 TriggerQueue 与 GameLog")
    _assert_equal(int(engine.rng.state), rng_before, "批量失败恢复 RNG")
    _assert_true(published.is_empty(), "批量失败不发布已回滚 source_marker_changed")

    engine.player.item_ids.clear()
    var succeeded: Dictionary = engine.effect_ports.write_all_charging_primary_values(
        engine.player, "add", 2, "batch-success")
    _assert_true(succeeded.get("success", false), "合法 write_all 按冻结顺序成功")
    _assert_equal(succeeded.get("frozen_slot_instance_ids"), slots.map(
        func(slot): return slot["slot_instance_id"]), "write_all 使用稳定槽位顺序")
    _assert_equal(engine.effect_ports.charging_technique_instances(
        engine.player).map(func(entry): return entry["current_value"]),
        [3, 4], "write_all 修改全部冻结目标")


func _test_public_projection_and_battle_cleanup() -> void:
    var engine = _charging_engine(
        19007, ["charging_probe", "plain_delay_probe"], 2)
    var slot: Dictionary = engine.sequence_book.current_slot("high_card")
    engine.effect_ports.begin_technique_charging(
        engine.player, slot["slot_instance_id"], 6, "projection")
    var plain_slot: Dictionary = engine.sequence_book.ordered_slots("high_card")[1]
    engine.player.source_marker_store.write(
        "technique", plain_slot["slot_instance_id"], "plain_delay_probe",
        "charge", "battle", "set", 8)
    engine.player.source_marker_store.write(
        "technique", "virtual-slot", "charging_probe",
        "charge", "battle", "set", 9)
    _assert_equal(engine.effect_ports.charging_technique_instances(
        engine.player).size(), 1,
        "无charging声明的倒计时槽与无真实slot对象不被枚举")
    var marker_before: Dictionary = engine.player.source_marker_store.snapshot()
    var status_before: Dictionary = engine.status_system.capture_runtime_state()
    var sequence_before: Dictionary = engine.sequence_book.snapshot()
    var rng_before := int(engine.rng.state)
    var session = BattleSessionScript.new(engine)
    var snapshot = session.snapshot()
    _assert_equal(snapshot.player.charging_techniques.size(), 1,
        "BattleSession 按槽位公开 charging_techniques")
    _assert_equal(snapshot.player.charging_techniques[0]["current_value"], 6,
        "UI 投影公开主要蓄力当前值")
    _assert_equal(snapshot.player.charging_techniques[0]["slot_instance_id"],
        slot["slot_instance_id"], "UI 投影绑定对应功法槽位")
    var ai_state: Dictionary = AiBattleStateProjectorScript.new().project_self(
        engine.player, engine.sequence_book, engine.battle_flow)
    _assert_equal(ai_state["charging_techniques"].size(), 1,
        "AI 公开状态包含按槽位组织的主要蓄力值")
    _assert_equal(ai_state["charging_techniques"][0]["current_value"], 6,
        "AI 投影与 BattleSession 同值")
    _assert_equal(engine.player.source_marker_store.snapshot(), marker_before,
        "UI/AI 查询不修改 marker")
    _assert_equal(engine.status_system.capture_runtime_state(), status_before,
        "UI/AI 查询不推进延迟或响应")
    _assert_equal(engine.sequence_book.snapshot(), sequence_before,
        "UI/AI 查询不移动功法序列")
    _assert_equal(int(engine.rng.state), rng_before, "UI/AI 查询不推进 RNG")
    _assert_true(not engine.player.get_property_list().any(func(property):
        return str(property.get("name", "")) == "charging"),
        "协议没有角色级 charging 资源")
    engine.timing_system.emit_timing("battle_end", {
        "actors": [engine.player, engine.enemy], "round_number": 1,
    })
    _assert_true(engine.player.source_marker_store.entries({
        "scope": "battle", "marker_id": "charge"}).is_empty(),
        "战斗结束通过既有生命周期清理 battle charging marker")


func _charging_engine(
        seed_value: int,
        sequence: Array,
        capacity: int = -1,
        effects: Array = []):
    var engine = _engine(seed_value)
    var plain_definition := _definition("plain_delay_probe")
    plain_definition["charging"] = {}
    plain_definition["automatic_triggers"] = [{
        "id": "plain_delay", "event": "turn_end", "timing": "immediate",
    }]
    engine.repository.configure({
        "pool_membership": POOL_MEMBERSHIP,
        "integration_statuses": {},
        "resource_paths": [],
        "techniques": [
            _definition("charging_probe", effects), plain_definition,
        ],
    })
    engine.sequence_book.configure_with_capacities(
        {"high_card": sequence},
        {"high_card": sequence.size() if capacity < 0 else capacity})
    engine.actions_available = 1
    return engine


func _definition(
        technique_id: String,
        effects: Array = [],
        charging_overrides: Dictionary = {}) -> Dictionary:
    var charging := {
        "primary_marker_id": "charge",
        "display_name": "蓄力值",
        "scope": "battle",
        "public": true,
        "allowed_operations": ["add", "subtract", "set", "clear"],
        "minimum": 0,
        "maximum": 10,
    }
    charging.merge(charging_overrides, true)
    return {
        "id": technique_id,
        "name": "蓄力协议探针",
        "pool": "high",
        "special": false,
        "manual_effect_mode": "normal",
        "automatic_triggers": [],
        "marker_definitions": [{
            "id": "charge", "scope": "battle", "public": true,
            "display_name": "蓄力值", "forget_policy": "clear",
        }],
        "charging": charging,
        "condition": {},
        "effects": effects.duplicate(true),
    }


func _assert_charging_validation(
        charging: Dictionary,
        markers: Array,
        expected_valid: bool,
        label: String) -> void:
    var validator = ContentValidatorScript.new()
    validator.errors.clear()
    validator._validate_technique_charging(
        charging.duplicate(true), markers.duplicate(true), "probe.charging")
    _assert_equal(validator.errors.is_empty(), expected_valid, label)


func _temporary_request(
        technique_id: String,
        copy_index: int,
        origin_slot: Dictionary,
        marker_mode: String) -> Dictionary:
    return {
        "hand_id": "high_card",
        "copy_index": copy_index,
        "technique_id": technique_id,
        "position": "after_current",
        "marker_mode": marker_mode,
        "origin_technique_id": technique_id,
        "origin_slot_instance_id": str(origin_slot["slot_instance_id"]),
        "generation_batch_token": "charging-temporary",
        "generator_source_kind": "rule",
        "generator_source_id": "charging-test",
        "generator_source_instance_key": "rule:charging-test",
    }


func _context(engine, slot: Dictionary, trigger_mode: String):
    return BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "technique_id": str(slot.get("technique_id", "")),
        "technique_name": "蓄力协议探针",
        "actual_hand_id": str(slot.get("hand_id", "high_card")),
        "slot_instance_id": str(slot.get("slot_instance_id", "")),
        "sequence_book": engine.sequence_book,
        "action_token": "charging-context-action",
        "root_action_token": "charging-context-root",
        "technique_execution_token": "charging-context-execution",
        "source_kind": "technique",
        "source_id": str(slot.get("technique_id", "")),
        "source_name": "蓄力协议探针",
        "source_instance_key": str(slot.get("slot_instance_id", "")),
        "trigger_mode": trigger_mode,
        "captures": {},
    })
