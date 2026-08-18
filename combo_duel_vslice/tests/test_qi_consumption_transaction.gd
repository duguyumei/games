extends "res://tests/support/expanded_technique_test_base.gd"

const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")
const BattleEffectContextScript = preload("res://core/effects/battle_effect_context.gd")

func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_single_and_batch_payment()
    _test_prepare_validation_and_idempotency()
    _test_void_and_other_departures_are_distinct()
    _test_transfer_and_effect_capture()
    _test_temporary_qi_and_runtime_snapshot_idempotency()
    _test_handler_failure_rolls_back_everything()
    _finish("QI CONSUMPTION TRANSACTION TEST")


func _test_single_and_batch_payment() -> void:
    _assert_true(BattleEventCatalogScript.is_committed("qi_consumed"),
        "qi_consumed 是正式 committed Hook")
    var engine = _engine(18001)
    var first = _card("5", "wind")
    engine.player.hand = [first]
    var published: Array[Dictionary] = []
    var batch_visibility_probe := {
        "cards": [],
        "token": "",
        "first_consumed_saw_full_batch_removed": false,
    }
    var engine_ref: WeakRef = weakref(engine)
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, receipt: Dictionary):
            published.append({
                "kind": kind,
                "values": values.duplicate(true),
                "receipt": receipt.duplicate(true),
            })
            if kind == "qi_consumed" and str(batch_visibility_probe["token"]) != "" \
                    and str(values.get("consumption_batch_token", "")) \
                        == str(batch_visibility_probe["token"]) \
                    and not bool(batch_visibility_probe[
                        "first_consumed_saw_full_batch_removed"]):
                var observed_engine = engine_ref.get_ref()
                batch_visibility_probe[
                    "first_consumed_saw_full_batch_removed"] = \
                    observed_engine != null \
                    and batch_visibility_probe["cards"].all(
                    func(card):
                        return observed_engine.player.card_zone_service \
                            .find_active_location(
                                observed_engine.player,
                                str(card.id)).is_empty() \
                            and observed_engine.player \
                                .temporarily_removed_cards.has(card)))
    var source := {
        "source_kind": "item",
        "source_id": "fake_qi_cost",
        "source_name": "假代价来源",
        "source_instance_key": "item:fake_qi_cost",
        "trigger_mode": "direct",
        "action_token": "qi-action-1",
        "root_action_token": "root-1",
        "execution_token": "execution-1",
        "operation_token": "operation-1",
    }
    var plan: Dictionary = engine.effect_ports.prepare_qi_consumption(
        engine.player, [first], source)
    _assert_true(plan.get("success", false), "单张手牌消耗准备成功")
    _assert_true(engine.player.hand.has(first), "prepare 不移动手牌")
    _assert_true(published.is_empty(), "prepare 不发布事件")
    var committed: Dictionary = engine.effect_ports.commit_qi_consumption(
        plan, source)
    _assert_true(committed.get("success", false), "单张手牌消耗提交成功")
    _assert_true(engine.player.temporarily_removed_cards.has(first),
        "消耗进入既有临时移出区")
    _assert_true(not engine.player.discard_pile.has(first),
        "消耗不进入弃牌堆")
    _assert_equal(published.map(func(entry): return entry["kind"]),
        ["card_moved", "qi_consumed"],
        "单张消耗只产生一份移动事实和一份消耗事实")
    var moved: Dictionary = published[0]["values"]
    var consumed: Dictionary = published[1]["values"]
    _assert_equal(moved["reason"], "cost", "card_moved 保留 cost 原因")
    _assert_equal(moved["consumption_batch_token"],
        consumed["consumption_batch_token"], "两类事实共享批次令牌")
    _assert_equal(moved["consumption_batch_index"], 0,
        "card_moved 公开稳定批次序号")
    _assert_equal(consumed["consumption_batch_size"], 1,
        "qi_consumed 公开批量大小")
    _assert_equal(consumed["cause"], "cost", "qi_consumed 固定 cause=cost")
    _assert_equal(consumed["temporary"], false, "普通真气消耗公开 temporary=false")
    _assert_equal(consumed["source_instance_key"], "item:fake_qi_cost",
        "qi_consumed 保留来源协议")
    _assert_equal(consumed["action_token"], "qi-action-1",
        "qi_consumed 保留 action token")
    _assert_equal(consumed["root_action_token"], "root-1",
        "qi_consumed 保留 root action token")
    _assert_equal(consumed["execution_token"], "execution-1",
        "qi_consumed 保留 execution token")

    var second = _card("6", "forest")
    var third = _card("7", "fire")
    var fourth = _card("8", "mountain")
    var fifth = _card("9", "wind")
    engine.player.hand = [second]
    engine.player.draw_pile = [third]
    engine.player.staging = [fourth]
    engine.player.discard_pile = [fifth]
    published.clear()
    var batch_source := source.duplicate(true)
    batch_source["operation_token"] = "operation-2"
    batch_source["action_token"] = "qi-action-2"
    var batch_plan: Dictionary = engine.effect_ports.prepare_qi_consumption(
        engine.player, [fourth, second, third, fifth], batch_source)
    _assert_true(batch_plan.get("success", false),
        "手牌、牌库、待出区、弃牌堆混合批量准备成功")
    batch_visibility_probe["cards"] = [fourth, second, third, fifth]
    batch_visibility_probe["token"] = str(batch_plan.get(
        "consumption_batch_token", ""))
    var batch: Dictionary = engine.effect_ports.commit_qi_consumption(
        batch_plan, batch_source)
    _assert_true(batch.get("success", false), "多牌区批量消耗提交成功")
    _assert_equal(engine.player.temporarily_removed_cards.slice(
        engine.player.temporarily_removed_cards.size() - 4),
        [fourth, second, third, fifth], "批量严格保持调用方冻结顺序")
    _assert_equal(published.filter(func(entry):
        return entry["kind"] == "card_moved").size(), 4,
        "批量每张真气各一份 card_moved")
    _assert_equal(published.filter(func(entry):
        return entry["kind"] == "qi_consumed").size(), 4,
        "批量每张真气各一份 qi_consumed")
    var batch_facts: Array = published.filter(func(entry):
        return entry["kind"] == "qi_consumed").map(func(entry): return entry["values"])
    var moved_facts: Array = published.filter(func(entry):
        return entry["kind"] == "card_moved").map(func(entry): return entry["values"])
    _assert_true(bool(batch_visibility_probe[
        "first_consumed_saw_full_batch_removed"]),
        "第一份 qi_consumed 对外发布时全批均已离开活动牌区")
    _assert_equal(batch_facts.map(func(value): return value["consumption_batch_index"]),
        [0, 1, 2, 3], "qi_consumed 批次索引稳定")
    _assert_equal(moved_facts.map(func(value): return value["consumption_batch_index"]),
        [0, 1, 2, 3], "card_moved 与消耗事实使用同一稳定索引")
    _assert_true(batch_facts.all(func(value):
        return value["consumption_batch_token"] == batch_facts[0]["consumption_batch_token"]),
        "批量 qi_consumed 共享 token")
    _assert_true(moved_facts.all(func(value):
        return value["consumption_batch_token"] \
            == batch_facts[int(value["consumption_batch_index"])][
                "consumption_batch_token"]),
        "每张 card_moved 与 qi_consumed 共享批次 token")


func _test_prepare_validation_and_idempotency() -> void:
    var engine = _engine(18002)
    var first = _card("2", "wind")
    var second = _card("3", "forest")
    engine.player.hand = [first, second]
    var duplicate: Dictionary = engine.effect_ports.prepare_qi_consumption(
        engine.player, [first, first], {"minimum_count": 2})
    _assert_true(not duplicate.get("success", true), "重复实例 ID 被拒绝")
    var insufficient: Dictionary = engine.effect_ports.prepare_qi_consumption(
        engine.player, [first], {"minimum_count": 2})
    _assert_true(not insufficient.get("success", true), "最低支付数量不足被拒绝")
    var exact: Dictionary = engine.effect_ports.prepare_qi_consumption(
        engine.player, [first, second], {"exact_count": 1})
    _assert_true(not exact.get("success", true), "精确支付数量不符被拒绝")
    var plan: Dictionary = engine.effect_ports.prepare_qi_consumption(
        engine.player, [first, second], {
            "operation_token": "operation-freeze",
            "exact_count": 2,
        })
    _assert_true(plan.get("success", false), "合法精确批量准备成功")
    var shortened_plan: Dictionary = plan.duplicate(true)
    shortened_plan["entries"].pop_back()
    var shortened: Dictionary = engine.effect_ports.commit_qi_consumption(
        shortened_plan, {"source_kind": "rule", "source_id": "count-failure"})
    _assert_true(not shortened.get("success", true), "commit 重新验证精确支付数量")
    _assert_equal(engine.player.hand, [first, second], "commit 数量失效不移动任何目标")
    engine.player.hand.erase(second)
    engine.player.discard_pile.append(second)
    var failed: Dictionary = engine.effect_ports.commit_qi_consumption(
        plan, {"source_kind": "rule", "source_id": "freeze-failure"})
    _assert_true(not failed.get("success", true), "prepare 后目标离开来源区导致整批失败")
    _assert_true(engine.player.hand.has(first) and engine.player.discard_pile.has(second),
        "提交前失效不移动任何目标")

    var replay = _engine(18003)
    var replay_card = _card("9", "mountain")
    var collision_card = _card("10", "fire")
    replay.player.hand = [replay_card, collision_card]
    var replay_source := {
        "source_kind": "rule", "source_id": "replay",
        "source_instance_key": "rule:replay", "operation_token": "replay-op",
    }
    var replay_plan: Dictionary = replay.effect_ports.prepare_qi_consumption(
        replay.player, [replay_card], replay_source)
    var precommitted_collision_plan: Dictionary = \
        replay.effect_ports.prepare_qi_consumption(
            replay.player, [collision_card], replay_source)
    _assert_true(precommitted_collision_plan.get("success", false),
        "同令牌的并发计划在首批提交前可各自完成只读冻结")
    var replay_first: Dictionary = replay.effect_ports.commit_qi_consumption(
        replay_plan, replay_source)
    var event_count := int(replay.battle_passive_event_service.execution_history.size())
    var replay_again: Dictionary = replay.effect_ports.commit_qi_consumption(
        replay_plan, replay_source)
    _assert_true(replay_again.get("reused", false), "重复 operation token 复用回执")
    _assert_equal(replay.battle_passive_event_service.execution_history.size(),
        event_count, "重复 operation token 不重复执行事件")
    _assert_equal(replay_again.get("card_instance_ids", []),
        replay_first.get("card_instance_ids", []), "重复回执保留原支付对象")
    var replay_via_facade: Dictionary = replay.effect_ports.consume_qi_batch(
        replay.player, [replay_card], replay_source)
    _assert_true(replay_via_facade.get("reused", false),
        "完整 Facade 重放同一 operation token 直接复用回执")
    _assert_equal(replay.battle_passive_event_service.execution_history.size(),
        event_count, "完整 Facade 重放不重复提交事件")
    var precommitted_collision: Dictionary = \
        replay.effect_ports.commit_qi_consumption(
            precommitted_collision_plan, replay_source)
    _assert_true(not precommitted_collision.get("success", true),
        "先冻结的同令牌异目标计划也不能在首批后提交")
    var collision: Dictionary = replay.effect_ports.consume_qi_batch(
        replay.player, [collision_card], replay_source)
    _assert_true(not collision.get("success", true),
        "同一 operation token 不得绑定另一批目标")
    _assert_true(replay.player.hand.has(collision_card), "令牌冲突不支付新目标")


func _test_void_and_other_departures_are_distinct() -> void:
    var engine = _engine(18004)
    var void_card = _card("4", "fire")
    engine.player.hand = [void_card]
    engine.effect_ports.apply_card_anomaly(
        void_card, "mark", "void", {}, "消耗测试")
    var events: Array[String] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, _values: Dictionary, _receipt: Dictionary): events.append(kind))
    var consumed: Dictionary = engine.effect_ports.consume_qi_batch(
        engine.player, [void_card], {
            "source_kind": "technique", "source_id": "void-cost",
            "source_instance_key": "technique:void-cost",
            "operation_token": "void-cost-op",
        })
    _assert_true(consumed.get("success", false), "带虚无真气可作为代价消耗")
    _assert_true("qi_consumed" in events and "card_moved" in events,
        "虚无代价仍产生标准两类事实")
    _assert_true("card_explicitly_discarded" not in events
        and "card_entered_discard" not in events,
        "虚无代价不触发明确弃牌或入堆事实")

    events.clear()
    var played_void = _card("4", "mountain")
    var discarded_void = _card("5", "fire")
    engine.effect_ports.apply_card_anomaly(
        played_void, "mark", "void", {}, "虚无正常离场测试")
    engine.effect_ports.apply_card_anomaly(
        discarded_void, "mark", "void", {}, "虚无明确弃置测试")
    engine.player.staging = [played_void]
    engine.player.hand = [discarded_void]
    events.clear()
    engine.player.card_zone_service.move_card(
        engine.player, "staging", "discard_pile", played_void, "normal_play")
    engine.player.card_zone_service.move_card(
        engine.player, "hand", "discard_pile", discarded_void, "explicit_discard")
    _assert_true("qi_consumed" not in events,
        "虚无正常打出和明确弃置后的消散均不发送 qi_consumed")

    events.clear()
    var bypass = _card("6", "wind")
    engine.player.hand = [bypass]
    var bypassed: Dictionary = engine.player.card_zone_service.temporarily_remove(
        engine.player, str(bypass.id), "cost")
    _assert_true(not bypassed.get("success", true),
        "CardZoneService 拒绝 reason=cost 绕过正式事务")
    var legacy_cost: Dictionary = engine.effect_ports.temporarily_remove_card(
        engine.player, str(bypass.id), "cost", {
            "source_kind": "rule", "source_id": "legacy-cost",
            "operation_token": "legacy-cost-op",
        })
    _assert_true(legacy_cost.get("success", false),
        "旧公开单卡入口的 reason=cost 转入正式事务")
    _assert_true("qi_consumed" in events, "旧公开入口仍提交标准消耗事实")

    events.clear()
    var dissipated = _card("5", "wind")
    engine.player.hand = [dissipated]
    var dissipate_result: Dictionary = engine.effect_ports.temporarily_remove_card(
        engine.player, str(dissipated.id), "effect_dissipate", "rule")
    _assert_true(dissipate_result.get("success", false), "主动消散仍走原临时移出链")
    _assert_true("qi_consumed" not in events, "主动消散不发送 qi_consumed")

    events.clear()
    var permanent = _card("6", "forest")
    engine.player.hand = [permanent]
    engine.player.permanently_remove_card(
        str(permanent.id), "test_permanent_remove")
    _assert_true("qi_consumed" not in events, "永久移出不发送 qi_consumed")

    events.clear()
    var temporary = _card("7", "mountain")
    engine.player.add_generated_card(temporary, "hand", true)
    engine.timing_system.emit_timing("battle_end", {
        "actors": [engine.player, engine.enemy], "round_number": 1,
    })
    _assert_true("qi_consumed" not in events, "战斗结束清理不发送 qi_consumed")


func _test_transfer_and_effect_capture() -> void:
    var engine = _engine(18005)
    var transferred = _card("8", "forest")
    engine.player.hand = [transferred]
    var transfer: Dictionary = engine.effect_ports.move_card(
        engine.player, "hand", engine.enemy, "draw_pile", transferred,
        "temporary_transfer", "top", "rule")
    _assert_true(transfer.get("success", false), "测试牌可先临时转移")
    var result: Dictionary = engine.effect_ports.consume_qi_batch(
        engine.enemy, [transferred], {
            "source_kind": "inner_skill", "source_id": "fake-transfer-cost",
            "source_instance_key": "inner_skill:fake-transfer-cost",
            "operation_token": "transfer-cost-op",
        })
    _assert_true(result.get("success", false), "临时转移牌可由当前持有方消耗")
    _assert_equal(str(transferred.original_owner_id), str(engine.player.owner_id),
        "消耗后仍保留原持有者信息")
    _assert_true(engine.enemy.temporarily_removed_cards.has(transferred),
        "转移牌消耗进入当前持有方临时移出区")

    var captured = _card("9", "wind")
    engine.player.hand = [captured]
    var context = BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "owner": engine.player,
        "captures": {"payment": [captured]},
        "action_token": "effect-payment-action",
        "root_action_token": "effect-payment-root",
        "source_kind": "technique",
        "source_id": "fake-payment",
        "source_instance_key": "technique:fake-payment",
        "technique_execution_token": "effect-payment-execution",
    })
    var executed: Dictionary = engine.effect_executor.execute_all([{
        "op": "consume_captured",
        "capture": "payment",
        "result_capture": "paid",
        "exact_count": 1,
    }], context)
    _assert_true(executed.get("success", false), "consume_captured 通用 Effect 成功")
    _assert_equal(context.captures.get("paid", []).size(), 1,
        "consume_captured 写入 result_capture")
    _assert_true(engine.player.temporarily_removed_cards.has(captured),
        "consume_captured 复用正式临时移出区")
    var history_size: int = int(
        engine.battle_passive_event_service.execution_history.size())
    var resumed: Dictionary = engine.effect_executor.execute_all([{
        "op": "consume_captured",
        "capture": "payment",
        "result_capture": "paid",
        "exact_count": 1,
    }], context)
    _assert_true(resumed.get("success", false),
        "等待/continuation 重放 consume_captured 复用支付回执")
    _assert_equal(engine.battle_passive_event_service.execution_history.size(),
        history_size, "consume_captured 重放不重复提交事件")


func _test_temporary_qi_and_runtime_snapshot_idempotency() -> void:
    var engine = _engine(18007)
    var temporary = _card("Q", "fire")
    temporary.configure_reshape_rule_service(engine.card_reshape_runtime._rules)
    engine.player.add_generated_card(temporary, "hand", true)
    engine.player.momentum_value = 9
    var published: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "qi_consumed":
                published.append(values.duplicate(true)))
    var before_prepare_state: Dictionary = engine.player.capture_passive_query_state()
    var before_prepare_rng := int(engine.rng.state)
    var source := {
        "source_kind": "rule",
        "source_id": "temporary-cost",
        "source_instance_key": "rule:temporary-cost",
        "action_token": "temporary-cost-action",
        "operation_token": "temporary-cost-operation",
        "exact_count": 1,
    }
    var plan: Dictionary = engine.effect_ports.prepare_qi_consumption(
        engine.player, [temporary], source)
    _assert_true(plan.get("success", false), "战斗临时真气可以准备为代价")
    _assert_equal(engine.player.capture_passive_query_state(), before_prepare_state,
        "prepare 是纯读，不改变牌区、状态、计数器或回执")
    _assert_equal(int(engine.rng.state), before_prepare_rng, "prepare 不推进 RNG")
    _assert_true(published.is_empty(), "prepare 不发送 qi_consumed")
    var paid: Dictionary = engine.effect_ports.commit_qi_consumption(plan, source)
    _assert_true(paid.get("success", false), "战斗临时真气可以正式消耗")
    _assert_equal(published.size(), 1, "临时真气每张只提交一份消耗事实")
    _assert_equal(published[0].get("temporary"), true,
        "qi_consumed 冻结并公开 temporary=true")
    _assert_equal(str(published[0].get("original_owner_id", "")),
        str(engine.player.owner_id), "临时真气事实保留原归属")
    _assert_equal(engine.player.momentum_value, 9,
        "消耗不会按当前牌数追溯修改既有连势状态")

    var runtime_snapshot: Dictionary = engine.player.capture_passive_query_state()
    var history_size: int = int(
        engine.battle_passive_event_service.execution_history.size())
    engine.player.qi_consumption_receipts.clear()
    engine.player.replace_passive_query_state(runtime_snapshot)
    var restored_replay: Dictionary = engine.effect_ports.consume_qi_batch(
        engine.player, [temporary], source)
    _assert_true(restored_replay.get("reused", false),
        "战斗运行时快照恢复后同一 operation token 复用回执")
    _assert_equal(engine.battle_passive_event_service.execution_history.size(),
        history_size, "快照恢复后的重放不重复消费或提交事件")
    _assert_equal(engine.player.temporarily_removed_cards.count(temporary), 1,
        "快照恢复后的重放只保留一张临时移出牌")

    engine.timing_system.emit_timing("battle_end", {
        "actors": [engine.player, engine.enemy], "round_number": 1,
    })
    _assert_true(not engine.player.all_cards_for_run_sync().has(temporary),
        "已消耗的战斗临时真气仍按临时牌规则在战后删除")


func _test_handler_failure_rolls_back_everything() -> void:
    var engine = _engine(18006)
    var failure_id := "fake_qi_consumed_failure"
    engine.content_catalog._indexes["item"][failure_id] = {
        "id": failure_id,
        "name": "消耗失败探针",
        "behaviors": [{
            "id": "battle_effects",
            "configuration": {
                "hook": "qi_consumed",
                "effects": [{"op": "unsupported_qi_consumption_test_op"}],
            },
        }],
    }
    engine.player.item_ids.assign([failure_id])
    var first = _card("10", "wind")
    var second = _card("J", "forest")
    engine.player.hand = [first, second]
    var before_state: Dictionary = engine.player.capture_passive_query_state()
    var before_event_state: Dictionary = engine.battle_passive_event_service.capture_transaction_state()
    var before_queue: Dictionary = engine.trigger_queue.capture_runtime_state()
    var before_rng := int(engine.rng.state)
    var events: Array[String] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, _values: Dictionary, _receipt: Dictionary): events.append(kind))
    var failed: Dictionary = engine.effect_ports.consume_qi_batch(
        engine.player, [first, second], {
            "source_kind": "item", "source_id": failure_id,
            "source_instance_key": "item:%s" % failure_id,
            "operation_token": "failing-cost-op",
        })
    _assert_true(not failed.get("success", true), "qi_consumed 后效失败使整批失败")
    _assert_true(failed.get("rolled_back", false), "失败回执明确标记已回滚")
    _assert_equal(engine.player.hand, [first, second],
        "后效失败恢复全部活动牌区")
    _assert_true(engine.player.temporarily_removed_cards.is_empty(),
        "后效失败恢复临时移出区")
    _assert_equal(engine.player.capture_passive_query_state().get("qi_consumption_receipts", {}),
        before_state.get("qi_consumption_receipts", {}), "失败不留下支付回执")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        before_event_state, "失败恢复事件 serial、receipt 和 history")
    _assert_equal(engine.trigger_queue.capture_runtime_state(), before_queue,
        "失败恢复 TriggerQueue 与 GameLog")
    _assert_equal(int(engine.rng.state), before_rng, "失败不消耗 RNG")
    _assert_true(events.is_empty(), "失败不向外发布已回滚 committed 事实")
