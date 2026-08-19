extends "res://tests/support/expanded_technique_test_base.gd"

const ContentCatalogScript = preload("res://core/content_catalog.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const NodeInteractionServiceScript = preload(
    "res://core/node_interactions/node_interaction_service.gd")
const NodeInteractionRegistryScript = preload(
    "res://core/node_interactions/node_interaction_handler_registry.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")


class SyntheticNodeHandler:
    extends RefCounted

    var prepare_calls: int = 0
    var commit_calls: int = 0

    func interaction_kind() -> String:
        return "choice_continuation_probe"

    func validate_configuration(_configuration: Dictionary, _validation) -> void:
        pass

    func prepare(context) -> Dictionary:
        prepare_calls += 1
        var choices: Array = []
        for choice_id in ["first", "second", "failure"]:
            choices.append({
                "id": choice_id,
                "label": choice_id,
                "description": "合成节点选项",
                "enabled": true,
                "metadata": {
                    "experience_at_prepare": int(
                        context.growth_snapshot.get("experience", 0)),
                },
            })
        return {
            "success": true,
            "title": "选择续跑探针",
            "description": "只用于底层平台专项",
            "choices": choices,
            "minimum_choices": 1,
            "maximum_choices": 1,
            "metadata": {},
        }

    func commit(
            context,
            _prepared_interaction: Dictionary,
            choice_id: String,
            choice_payload: Dictionary) -> Dictionary:
        commit_calls += 1
        if not bool(choice_payload.get("confirmed", false)):
            return {"success": false, "reason": "合成选项未确认"}
        if choice_id == "failure":
            return {
                "success": true,
                "effects": [{"op": "choice_continuation_missing_effect"}],
                "result": {"choice_id": choice_id},
            }
        return {
            "success": true,
            "effects": [{
                "op": "gain_experience",
                "amount": 2 if choice_id == "first" else 3,
            }],
            "result": {
                "choice_id": choice_id,
                "experience_before": int(
                    context.growth_snapshot.get("experience", 0)),
            },
        }


class SyntheticPolicyResult:
    extends RefCounted

    var maximum: int

    func _init(value: int) -> void:
        maximum = value

    func to_dict() -> Dictionary:
        return {
            "success": true,
            "hook": "rest_multi_select_count_query",
            "subject_kind": "node_interaction",
            "subject_id": "synthetic",
            "base_value": 1,
            "effective_value": maximum,
            "modifier_breakdown": [{
                "source_kind": "item",
                "content_id": "synthetic_multi_select",
                "source_instance_key": "item:run:synthetic_multi_select",
                "before": 1,
                "after": maximum,
            }],
            "source_fingerprint": "synthetic-policy-%d" % maximum,
            "errors": [],
        }


class SyntheticPolicyResolver:
    extends RefCounted

    var maximum: int

    func _init(value: int) -> void:
        maximum = value

    func resolve(_request):
        return SyntheticPolicyResult.new(maximum)


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_before_draw_lifecycle_continuation()
    _test_action_window_and_invocation_routing()
    _test_lifecycle_failure_rolls_back_timing()
    _test_solo_and_synchronized_confirmation_payment()
    _test_cooperation_payment_and_failure_rollback()
    _test_node_single_and_multi_select_sessions()
    _test_node_failure_restore_and_save_migration()
    _finish("CHOICE CONTINUATION PLATFORM TEST")


func _test_before_draw_lifecycle_continuation() -> void:
    var engine = _engine(98101)
    _install_battle_item(engine, "before_draw_choice", [{
        "id": "battle_effects",
        "configuration": {
            "hook": "before_normal_draw",
            "order": 100,
            "effects": [_choice_from("draw_pile", "before_draw")],
        },
    }])
    engine.player.configure_items(["before_draw_choice"])
    engine.player.draw_pile = [
        _card("2", "wind"), _card("3", "forest"), _card("4", "fire")]
    engine.player.hand.clear()
    var turn_before = int(engine.turn_number)
    var drawn = engine.start_player_turn()
    _assert_true(drawn.is_empty(), "before_normal_draw 等待时尚未执行正常补牌")
    _assert_equal(engine.player.hand.size(), 0, "等待生命周期选择时手牌保持为空")
    _assert_equal(engine.turn_number, turn_before + 1, "生命周期暂停只建立一次回合序号")
    _assert_true(engine.has_pending_choice(), "统一战斗入口公开生命周期 pending_choice")
    var request = engine.pending_choice_snapshot()
    var request_id = str(request.get("request_id", ""))
    var side_before_invalid = engine.player.capture_passive_query_state()
    var rng_before_invalid = int(engine.rng.state)
    var invalid_id = engine.resolve_choice("wrong-request", [])
    _assert_true(not invalid_id.get("success", true), "错误生命周期 request_id 被拒绝")
    _assert_equal(engine.player.capture_passive_query_state(), side_before_invalid,
        "错误 request_id 不改变牌区或角色状态")
    _assert_equal(engine.rng.state, rng_before_invalid, "错误 request_id 不推进 RNG")
    var invalid_candidate = engine.resolve_choice(request_id, ["missing-card"])
    _assert_true(not invalid_candidate.get("success", true), "冻结候选外实例被拒绝")
    _assert_equal(engine.pending_choice_snapshot(), request,
        "非法候选不推进生命周期游标或更换请求")
    var selected_id = str(request.get("candidate_ids", [])[0])
    var resumed = engine.resolve_choice(request_id, [selected_id])
    _assert_true(resumed.get("success", false), "合法生命周期选择恢复回合启动")
    _assert_equal(engine.turn_number, turn_before + 1, "恢复不重复增加回合数")
    _assert_equal(engine.player.hand.size(), 3, "恢复后正常补牌只执行一次")
    _assert_equal(
        engine.timing_system.history.filter(
            func(entry): return entry.get("timing") == "before_normal_draw").size(),
        1, "before_normal_draw 历史只提交一次")
    var repeated = engine.resolve_choice(request_id, [selected_id])
    _assert_true(not repeated.get("success", true), "已消费生命周期请求不能重复提交")


func _test_action_window_and_invocation_routing() -> void:
    var engine = _engine(98102)
    _install_battle_item(engine, "window_choice_first", [{
        "id": "battle_effects",
        "configuration": {
            "hook": "action_window_start", "order": 100,
            "effects": [_choice_from("hand", "window_first")],
        },
    }])
    _install_battle_item(engine, "window_choice_second", [{
        "id": "battle_effects",
        "configuration": {
            "hook": "action_window_start", "order": 100,
            "effects": [_choice_from("hand", "window_second")],
        },
    }])
    engine.player.configure_items([
        "window_choice_first", "window_choice_second"])
    engine.player.draw_pile = [
        _card("5", "wind"), _card("6", "forest"), _card("7", "fire")]
    engine.player.hand.clear()
    engine.start_player_turn()
    _assert_true(engine.has_pending_choice(), "action_window_start 可暂停并进入统一路由")
    var first_request = engine.pending_choice_snapshot()
    var card_id = str(first_request.get("candidate_ids", [])[0])
    var blocked_play = engine.confirm_play([card_id])
    _assert_true(not blocked_play.get("success", true), "行动窗口未就绪时不能出牌")
    var actions_before_end = int(engine.actions_available)
    engine.end_player_turn()
    _assert_equal(engine.actions_available, actions_before_end,
        "action_window_start 等待时不能结束回合")
    var first_resumed = engine.resolve_choice(
        str(first_request.get("request_id", "")), [card_id])
    _assert_true(first_resumed.get("pending_choice", false),
        "完成首个 Invocation 后从稳定游标进入第二个 Invocation")
    var second_request = engine.pending_choice_snapshot()
    _assert_true(str(second_request.get("request_id", "")) != str(
        first_request.get("request_id", "")), "后续 Invocation 使用新的稳定请求")
    _assert_equal(engine.battle_passive_timing_bridge.execution_history.size(), 1,
        "首个 Invocation 完成后只提交自身 receipt")
    var second_resumed = engine.resolve_choice(
        str(second_request.get("request_id", "")),
        [str(second_request.get("candidate_ids", [])[0])])
    _assert_true(second_resumed.get("success", false), "第二个 Invocation 完成后开放行动窗口")
    _assert_true(engine.round_service.is_action_window_ready(), "全部生命周期选择结束后行动窗口就绪")
    _assert_equal(engine.battle_passive_timing_bridge.execution_history.size(), 2,
        "两个 Invocation 各完成一次且没有重放")


func _test_lifecycle_failure_rolls_back_timing() -> void:
    var engine = _engine(98103)
    _install_battle_item(engine, "failing_lifecycle_choice", [{
        "id": "battle_effects",
        "configuration": {
            "hook": "before_normal_draw", "order": 100,
            "effects": [
                {"op": "defense", "amount": 4},
                {"op": "draw", "count": 1},
                _choice_from("draw_pile", "failure_resume"),
                {"op": "choice_continuation_missing_battle_effect"},
            ],
        },
    }])
    engine.player.configure_items(["failing_lifecycle_choice"])
    engine.player.draw_pile = [
        _card("8", "wind"), _card("9", "forest"), _card("10", "fire")]
    engine.player.hand.clear()
    engine.start_player_turn()
    _assert_true(engine.has_pending_choice(), "失败夹具先稳定进入生命周期选择")
    _assert_equal(engine.player.defense, 4, "选择前效果暂存在生命周期事务内")
    _assert_equal(engine.player.hand.size(), 1, "选择前牌区变化暂存在生命周期事务内")
    var transaction_snapshot: Dictionary = engine.timing_system._pending_timing.get(
        "transaction", {}).get("snapshot", {})
    var request = engine.pending_choice_snapshot()
    var failed = engine.resolve_choice(
        str(request.get("request_id", "")),
        [str(request.get("candidate_ids", [])[0])])
    _assert_true(not failed.get("success", true), "选择后的效果失败使生命周期时点失败")
    _assert_equal(engine.player.capture_passive_query_state(),
        transaction_snapshot.get("side_states", [])[0].get("state", {}),
        "失败恢复时点开始前的牌区、生命、防御与计数状态")
    _assert_equal(engine.rng.state, int(transaction_snapshot.get("rng_state", -1)),
        "生命周期失败恢复战斗 RNG")
    _assert_equal(engine.trigger_queue.capture_runtime_state(),
        transaction_snapshot.get("trigger_state", {}),
        "生命周期失败恢复 committed 事件、可见历史与日志")
    _assert_true(
        engine.battle_passive_timing_bridge._pending_events.is_empty(),
        "生命周期失败清除 Bridge Invocation continuation")
    _assert_true(
        engine.battle_passive_timing_bridge.execution_history.is_empty(),
        "生命周期失败回滚已执行 Invocation receipt")
    _assert_true(not engine.has_pending_choice(), "失败后清除已失效的选择请求")


func _test_solo_and_synchronized_confirmation_payment() -> void:
    var engine = _payment_engine(98104, ["payment_a", "payment_b"])
    var cards = [
        _card("7", "wind"), _card("7", "forest"), _card("2", "fire")]
    engine.player.hand = cards
    _add_blazing(engine, cards[0], 2, 3, "source-a")
    _add_blazing(engine, cards[1], 1, 0, "source-b")
    _add_blazing(engine, cards[2], 9, 0, "extra-card")
    var first_card_id := str(cards[0].id)
    var second_card_id := str(cards[1].id)
    var extra_card_id := str(cards[2].id)
    var extra_card = cards[2]
    engine.actions_available = 1
    var started = engine.confirm_play(_ids(cards))
    _assert_true(started.get("pending_choice", false),
        "单方行动在 staging 后进入支付选择：%s" % str(started))
    if not started.get("pending_choice", false):
        return
    var first = engine.pending_choice_snapshot()
    _assert_true(not first.get("candidate_ids", []).has(extra_card_id),
        "支付候选只包含本组实际计值真气")
    var staging_before_invalid = engine.player.staging.map(
        func(card): return str(card.id))
    var invalid = engine.resolve_choice(
        str(first.get("request_id", "")), [extra_card_id])
    _assert_true(not invalid.get("success", true), "不能选择同组额外真气支付")
    _assert_equal(engine.player.staging.map(func(card): return str(card.id)),
        staging_before_invalid, "非法支付选择不改变 staging")
    var finished = engine.resolve_choice(
        str(first.get("request_id", "")), [first_card_id])
    _assert_true(finished.get("success", false), "多来源支付按稳定顺序完成单方行动")
    var receipts: Array = finished.get("preview", {}).get(
        "action_confirmation_payment_receipts", [])
    _assert_equal(receipts.size(), 2, "两个支付来源各提交一份回执")
    _assert_equal(receipts[0].get("paid"), 5, "普通炽气与来源临时炽气按实际总层数支付")
    _assert_equal(receipts[0].get("power_fixed_delta"), 10,
        "实际支付量乘固定单位值进入直接功法值修正")
    _assert_equal(receipts[1].get("card_instance_id"), second_card_id,
        "后一个来源读取前一来源支付后的最新真气状态")
    _assert_equal(extra_card.total_blazing_layers(), 9, "额外真气资源不被支付计划修改")
    _assert_equal(finished.get("preview", {}).get("group_snapshot", {}).get(
        "action_confirmation_payment_receipts", []).size(), 2,
        "支付回执写入现有 HandGroupSnapshot")

    var synchronized = _payment_engine(98105, ["payment_a"])
    synchronized.scripted_mode = true
    synchronized.battle_flow.set_action_count(synchronized.player, 1)
    synchronized.battle_flow.set_action_count(synchronized.enemy, 0)
    var sync_cards = [_card("6", "wind"), _card("6", "forest")]
    synchronized.player.hand = sync_cards
    _add_blazing(synchronized, sync_cards[0], 1, 0, "sync-a")
    _add_blazing(synchronized, sync_cards[1], 1, 0, "sync-b")
    var sync_first_id := str(sync_cards[0].id)
    var sync_started = synchronized.confirm_play(_ids(sync_cards))
    _assert_true(sync_started.get("pending_choice", false),
        "同步行动复用同一确认支付事务：%s" % str(sync_started))
    if not sync_started.get("pending_choice", false):
        return
    var frozen_context = synchronized.action_service._pending_confirmation_context.duplicate(true)
    var sync_request = synchronized.pending_choice_snapshot()
    var sync_finished = synchronized.resolve_choice(
        str(sync_request.get("request_id", "")), [sync_first_id])
    _assert_true(sync_finished.get("success", false), "同步行动支付恢复后完成")
    _assert_equal(frozen_context.get("enemy_preview", {}), {},
        "同步等待冻结既有敌方提案且不会临时生成新随机结果")


func _test_cooperation_payment_and_failure_rollback() -> void:
    var success_engine = _payment_engine(98106, ["payment_a"])
    var main = [_card("8", "wind"), _card("8", "forest")]
    var cooperation = [_card("4", "fire"), _card("4", "mountain")]
    success_engine.player.hand = main + cooperation
    for card in main + cooperation:
        _add_blazing(success_engine, card, 1, 0, "cooperation-success")
    _install_cooperation_techniques(success_engine)
    success_engine.actions_available = 1
    var started = success_engine.confirm_play(_ids(main), _ids(cooperation))
    _assert_true(started.get("pending_choice", false),
        "协同主组建立独立支付请求：%s" % str(started))
    if not started.get("pending_choice", false):
        return
    var main_request = success_engine.pending_choice_snapshot()
    var after_main = success_engine.resolve_choice(
        str(main_request.get("request_id", "")), [str(main[0].id)])
    _assert_true(after_main.get("pending_choice", false), "主组支付后从游标进入协同组支付")
    var cooperation_request = success_engine.pending_choice_snapshot()
    _assert_true(cooperation_request.get("candidate_ids", []).has(
        str(cooperation[0].id)), "协同组请求只读取自身计值真气")
    var completed = success_engine.resolve_choice(
        str(cooperation_request.get("request_id", "")),
        [str(cooperation[0].id)])
    _assert_true(completed.get("success", false), "协同两组支付完成后正常结算")
    var receipts: Array = completed.get("preview", {}).get(
        "action_confirmation_payment_receipts", [])
    _assert_true(receipts.any(func(receipt): return int(
        receipt.get("group_index", -1)) == 0), "回执保留主组 identity")
    _assert_true(completed.get("cooperation_preview", {}).get(
        "group_snapshot", {}).get(
            "action_confirmation_payment_receipts", []).size() == 1,
        "协同组回执写入自己的 HandGroupSnapshot")

    var rollback_engine = _payment_engine(98107, ["payment_a"])
    var rollback_main = [_card("9", "wind"), _card("9", "forest")]
    var rollback_coop = [_card("3", "fire"), _card("3", "mountain")]
    rollback_engine.player.hand = rollback_main + rollback_coop
    for card in rollback_main + rollback_coop:
        _add_blazing(rollback_engine, card, 2, 1, "cooperation-rollback")
    _install_cooperation_techniques(rollback_engine)
    var permission_calls = [0]
    rollback_engine.battle_permission_service.register_provider(
        func(hook, _context):
            if hook == "cooperation_permission_query":
                permission_calls[0] += 1
                return {"allowed": permission_calls[0] == 1}
            return {"allowed": true},
        "choice-continuation-cooperation-deny", 10,
        ["technique_activation_permission_query", "cooperation_permission_query"])
    rollback_engine.actions_available = 1
    var state_before = rollback_engine.player.capture_passive_query_state()
    var events_before = rollback_engine.battle_passive_event_service.capture_transaction_state()
    var rollback_start = rollback_engine.confirm_play(
        _ids(rollback_main), _ids(rollback_coop))
    if not rollback_start.get("pending_choice", false):
        _assert_true(false, "协同回滚夹具进入支付选择：%s" % str(rollback_start))
        return
    var rollback_main_request = rollback_engine.pending_choice_snapshot()
    rollback_engine.resolve_choice(
        str(rollback_main_request.get("request_id", "")),
        [str(rollback_main[0].id)])
    var rollback_coop_request = rollback_engine.pending_choice_snapshot()
    var rollback_result = rollback_engine.resolve_choice(
        str(rollback_coop_request.get("request_id", "")),
        [str(rollback_coop[0].id)])
    _assert_true(rollback_start.get("pending_choice", false) \
        and not rollback_result.get("success", true),
        "协同正式确认失败使支付事务整体失败")
    _assert_equal(rollback_engine.player.capture_passive_query_state(), state_before,
        "协同失败恢复普通/临时炽气、牌区与功法值状态")
    _assert_equal(
        rollback_engine.battle_passive_event_service.capture_transaction_state(),
        events_before, "协同失败不遗留 committed 事件、receipt 或 token")


func _test_node_single_and_multi_select_sessions() -> void:
    var single = _node_fixture(1)
    var single_service = single["service"]
    var single_growth = single["growth"]
    var single_prepared = single_service.prepare(
        _node_dispatch(), single_growth, _node_source_context())
    var single_token = str(single_prepared.get(
        "interaction", {}).get("interaction_token", ""))
    var single_committed = single_service.commit(
        single_token, "first", {"confirmed": true}, single_growth)
    _assert_true(single_committed.get("success", false) \
        and single_committed.get("completed", false),
        "默认策略保持单选成功后自动完成")
    _assert_equal(single_service.query_active(), {}, "已完成单选不再公开 pending DTO")

    var multi = _node_fixture(3)
    var service = multi["service"]
    var growth = multi["growth"]
    var prepared = service.prepare(_node_dispatch(), growth, _node_source_context())
    var interaction: Dictionary = prepared.get("interaction", {})
    var token = str(interaction.get("interaction_token", ""))
    _assert_equal(interaction.get("maximum_choices"), 3,
        "来源中立 Run 整数查询把最大提交数提高至初始候选数")
    var first = service.commit(token, "first", {"confirmed": true}, growth)
    _assert_true(first.get("success", false) and not first.get("completed", true),
        "多选首项独立提交后会话继续")
    _assert_equal(growth.experience, 2, "首项效果通过现有 RunMutationService 提交")
    _assert_true(first.get("interaction", {}).get("allow_finish", false),
        "满足 minimum 后公开主动结束资格")
    var duplicate_state = growth.capture_mutation_state()
    var duplicate = service.commit(token, "first", {"confirmed": true}, growth)
    _assert_true(not duplicate.get("success", true), "同一选项不能成功提交两次")
    _assert_equal(growth.capture_mutation_state(), duplicate_state,
        "重复选项不改变已提交成长状态")
    var second = service.commit(token, "second", {"confirmed": true}, growth)
    _assert_equal(second.get("interaction_result", {}).get("experience_before"), 2,
        "后一个选项重新 prepare 并读取前一项提交后的 Growth")
    _assert_equal(second.get("selected_choice_ids"), ["first", "second"],
        "会话稳定保存已选顺序")
    var finished = service.finish(token)
    _assert_true(finished.get("success", false), "提交一项以上后可以主动结束多选会话")


func _test_node_failure_restore_and_save_migration() -> void:
    var fixture = _node_fixture(3)
    var service = fixture["service"]
    var growth = fixture["growth"]
    var handler = fixture["handler"]
    var prepared = service.prepare(_node_dispatch(), growth, _node_source_context())
    var token = str(prepared.get("interaction", {}).get("interaction_token", ""))
    service.commit(token, "first", {"confirmed": true}, growth)
    var pending_before_failure = service.capture_pending()
    var growth_before_failure = growth.capture_mutation_state()
    var failed = service.commit(token, "failure", {"confirmed": true}, growth)
    _assert_true(not failed.get("success", true), "后续选项效果失败返回明确失败")
    _assert_equal(service.capture_pending(), pending_before_failure,
        "单项失败只恢复本次命令的冻结 DTO，不抹掉此前成功选择")
    _assert_equal(growth.capture_mutation_state(), growth_before_failure,
        "单项失败恢复本次 Growth 修改")

    var saved = service.capture_pending()
    var restored_fixture = _node_fixture(3)
    var restored = restored_fixture["service"]
    var prepare_calls_before = restored_fixture["handler"].prepare_calls
    var restore_result = restored.restore_pending(saved)
    _assert_true(restore_result.get("success", false), "完整多选 pending 状态可以恢复")
    _assert_equal(restored_fixture["handler"].prepare_calls, prepare_calls_before,
        "恢复 pending 不重新执行已提交选项或 Handler.prepare")
    _assert_equal(restored.capture_pending().get("selected_choice_ids"), ["first"],
        "恢复保留已提交选项顺序")
    _assert_true(handler.prepare_calls >= 3, "每次实际选择都针对最新 Growth 重新准备")

    var legacy = saved.duplicate(true)
    legacy["schema_version"] = 1
    for field in [
            "initial_choice_ids", "selected_choice_ids", "maximum_choices",
            "minimum_choices", "allow_finish", "policy_fingerprint",
            "policy_breakdown", "session_serial"]:
        legacy.erase(field)
    legacy["interaction"]["selected_choice_ids"] = []
    legacy["interaction"]["minimum_choices"] = 1
    legacy["interaction"]["maximum_choices"] = 1
    legacy["interaction"]["allow_finish"] = false
    var legacy_fixture = _node_fixture(1)
    var legacy_result = legacy_fixture["service"].restore_pending(legacy)
    _assert_true(legacy_result.get("success", false),
        "旧 schema pending_node_interaction 明确迁移为单选会话")
    _assert_equal(
        legacy_fixture["service"].capture_pending().get("maximum_choices"),
        1, "旧存档迁移后最大提交数固定为1")


func _payment_engine(seed_value: int, item_ids: Array):
    var engine = _engine(seed_value)
    for item_id in item_ids:
        _install_battle_item(engine, str(item_id), [{
            "id": "action_confirmation_payment",
            "configuration": {"plans": [{
                "query": {
                    "side": "actor", "zone": "staging", "order": "zone",
                    "filters": {},
                },
                "payment_kind": "blazing_layers",
                "payment_method": "remove_all_layers",
                "power_fixed_per_unit": 2,
                "optional": false,
                "prompt": "选择炽气支付真气",
                "insufficient_policy": "skip",
            }]},
        }])
    engine.player.configure_items(item_ids)
    return engine


func _install_battle_item(engine, item_id: String, behaviors: Array) -> void:
    engine.content_catalog._indexes["item"][item_id] = {
        "id": item_id,
        "name": item_id,
        "kind": "item",
        "status": "candidate",
        "unique": true,
        "description": "选择续跑平台合成来源",
        "price": 1,
        "behaviors": behaviors.duplicate(true),
    }


func _choice_from(zone: String, choice_id: String) -> Dictionary:
    return {
        "op": "select_cards",
        "choice_id": choice_id,
        "prompt": "合成生命周期选择",
        "chooser": "actor",
        "minimum": 1,
        "maximum": 1,
        "insufficient_policy": "fail",
        "query": {
            "side": "actor", "zone": zone, "order": "random",
            "filters": {},
        },
        "capture": "%s_capture" % choice_id,
    }


func _add_blazing(
        engine, card, normal: int, temporary: int, source_key: String) -> void:
    if normal > 0:
        engine.status_system.apply_card_anomaly(
            card, "buff", "qi_heat", {}, "专项测试", normal)
    if temporary > 0:
        engine.status_system.add_temporary_blazing_layers(
            card, source_key, temporary, "专项测试")


func _install_cooperation_techniques(engine) -> void:
    engine.repository.techniques["choice_payment_main"] = {
        "id": "choice_payment_main", "name": "合成协同主组",
        "pool": "pair", "effects": [],
        "cooperation": {
            "hand_id": "pair", "max_groups": 1,
            "power_rule": "shared_half", "exact_card_count": 2,
            "post_commit": {"destination": "own_discard"},
        },
    }
    engine.repository.techniques["choice_payment_cooperation"] = {
        "id": "choice_payment_cooperation", "name": "合成协同组",
        "pool": "pair", "effects": [],
    }
    engine.sequence_book.configure({
        "pair": ["choice_payment_main", "choice_payment_cooperation"],
    })


func _node_fixture(maximum: int) -> Dictionary:
    var handler = SyntheticNodeHandler.new()
    var registry = NodeInteractionRegistryScript.new()
    registry.register_handler(handler)
    var catalog = ContentCatalogScript.new()
    catalog.load_all()
    var service = NodeInteractionServiceScript.new(
        registry, RunMutationServiceScript.new(null, catalog), catalog)
    service.use_passive_int_policy_resolver(
        SyntheticPolicyResolver.new(maximum))
    var growth = GrowthInventoryScript.new(catalog, false)
    growth.experience = 0
    return {"handler": handler, "service": service, "growth": growth}


func _node_dispatch() -> Dictionary:
    return {
        "route": "interaction",
        "node_id": "rest-probe",
        "node_type": "rest",
        "content_id": "choice_continuation_content",
        "title": "选择续跑节点",
        "description": "合成节点",
        "act": 1,
        "content_seed": 98108,
        "interaction": {
            "kind": "choice_continuation_probe",
            "configuration": {},
        },
    }


func _node_source_context() -> Dictionary:
    return {
        "source_kind": "map_node",
        "source_id": "rest-probe",
        "run_seed": 98108,
    }


func _ids(cards: Array) -> Array[String]:
    var result: Array[String] = []
    for card in cards:
        result.append(str(card.id))
    return result
