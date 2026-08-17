extends "res://tests/support/expanded_technique_test_base.gd"

const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")
const ConditionSpecRegistryScript = preload(
    "res://core/specs/condition_spec_registry.gd")
func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_catalog_and_single_move_delivery()
    _test_generation_removal_and_placement()
    _test_staging_commits_logical_hand_facts()
    _test_synchronous_and_cross_holder_facts()
    _test_all_side_passives_keep_effect_owner()
    _test_failed_restore_and_cleanup_do_not_publish()
    _finish("CARD MOVED COMMITTED TEST")


func _test_catalog_and_single_move_delivery() -> void:
    _assert_true(BattleEventCatalogScript.is_committed("card_moved"),
        "card_moved 是正式 committed Hook")
    _assert_true(BattleEventCatalogScript.forwards_dynamic_response("card_moved"),
        "card_moved 仍支持动态响应")
    _assert_true("card_moved" not in BattleEventCatalogScript.RESPONSE_ONLY_EVENTS,
        "card_moved 不再只是 response-only 事件")
    var filter_errors: Array[String] = []
    var filter_valid := ConditionSpecRegistryScript.new().validate_event_filters({
        "from_zone": "generated",
        "to_zone": "temporarily_removed",
    }, func(_scope: String, message: String): filter_errors.append(message), "filters")
    _assert_true(filter_valid and filter_errors.is_empty(),
        "事件牌区校验接受虚拟牌区")

    var engine = _engine(6101)
    var card = _card("7", "forest")
    engine.player.hand = [card]
    var events: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, receipt: Dictionary):
            events.append({
                "kind": kind,
                "values": values.duplicate(true),
                "receipt": receipt.duplicate(true),
            }))
    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "owner": engine.player,
        "captures": {},
        "action_token": "card-moved-dynamic",
        "source_kind": "technique",
    })
    var registered: Dictionary = engine.status_system.register_response(
        "card_moved", "turn_end", [{"op": "defense", "amount": 1}],
        context, {"owner": "actor", "reason": "explicit_discard"})
    _assert_true(registered.get("success", false),
        "既有 card_moved 动态响应仍可注册")
    var moved: Dictionary = engine.effect_ports.move_card(
        engine.player, "hand", engine.player, "discard_pile", card,
        "explicit_discard", "top", {
            "source_kind": "item",
            "source_id": "move-probe",
            "source_name": "移动探针",
            "source_instance_key": "item:move-probe",
            "trigger_mode": "direct",
            "action_token": "move-action-1",
        })
    _assert_true(moved.get("success", false), "hand 到弃牌堆移动成功")
    _assert_equal(events.filter(func(entry):
        return entry["kind"] in [
            "card_moved", "card_entered_discard",
            "card_explicitly_discarded"]).map(func(entry): return entry["kind"]), [
        "card_moved", "card_entered_discard", "card_explicitly_discarded"],
        "通用事实先于既有弃牌专项事实且各一次")
    _assert_equal(engine.player.defense, 1,
        "StatusSystem 动态响应只执行一次")
    _assert_equal(events.map(func(entry): return entry["kind"]), [
        "card_moved", "card_entered_discard",
        "card_explicitly_discarded", "defense_gained"],
        "动态响应位于通用和既有专项事实之后")
    var fact: Dictionary = events.filter(func(entry):
        return entry["kind"] == "card_moved")[0]["values"]
    _assert_equal(fact["from_zone"], "hand", "事实保留移动前牌区")
    _assert_equal(fact["to_zone"], "discard_pile", "事实公开最终牌区")
    _assert_equal(fact["reason"], "explicit_discard", "事实保留移动原因")
    _assert_equal(fact["placement"], "top", "事实公开目标位置")
    _assert_equal(fact["action_token"], "move-action-1", "事实保留行动令牌")
    _assert_equal(fact["source_kind"], "item", "事实保留来源协议")
    _assert_equal(fact["from_zone_count_before"], 1, "来源区 before 准确")
    _assert_equal(fact["from_zone_count_after"], 0, "来源区 after 准确")
    _assert_equal(fact["to_zone_count_before"], 0, "目标区 before 准确")
    _assert_equal(fact["to_zone_count_after"], 1, "目标区 after 准确")
    _assert_equal(fact["hand_count_before"], 1, "逻辑手牌 before 准确")
    _assert_equal(fact["hand_count_after"], 0, "逻辑手牌 after 准确")
    _assert_equal(fact["from_holder_id"], str(engine.player.owner_id),
        "事实公开来源持有方")
    _assert_equal(fact["to_holder_id"], str(engine.player.owner_id),
        "事实公开目标持有方")
    var moved_receipt: Dictionary = events.filter(func(entry):
        return entry["kind"] == "card_moved")[0]["receipt"]
    _assert_equal(moved_receipt["owner_ids"], [
        str(engine.player.owner_id), str(engine.enemy.owner_id)],
        "双方被动来源观察同一移动事实")
    var emitted_before_reuse := events.size()
    var reused: Dictionary = engine.battle_passive_event_service.commit(
        "card_moved", fact)
    _assert_true(reused.get("reused", false), "重复 event_token 复用既有收据")
    _assert_equal(events.size(), emitted_before_reuse,
        "重复令牌不再次发布 committed 或动态响应")

    events.clear()
    var drawn_card = _card("8", "wind")
    engine.player.draw_pile = [drawn_card]
    var drawn: Array = engine.player.card_zone_service.draw(
        engine.player, 1, "committed-draw-probe")
    _assert_equal(drawn, [drawn_card], "抽牌入口完成真实移动")
    _assert_equal(events.map(func(entry): return entry["kind"]), [
        "card_moved", "card_drawn"],
        "抽牌通用事实与既有card_drawn各一次")
    _disconnect_event_probes(engine)


func _test_generation_removal_and_placement() -> void:
    var engine = _engine(6102)
    var events: Array[Dictionary] = []
    var placement_probe := {"bottom_visible": false}
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind != "card_moved":
                return
            events.append(values.duplicate(true))
            if values.get("placement") == "bottom":
                placement_probe["bottom_visible"] = \
                    not engine.player.draw_pile.is_empty() \
                    and engine.player.draw_pile[0] == values.get("card"))
    var temporary = _card("4", "wind")
    var permanent = _card("5", "fire")
    _assert_true(engine.player.add_generated_card(
        temporary, "hand", true).get("success", false),
        "临时生成成功")
    _assert_true(engine.player.add_generated_card(
        permanent, "hand", false).get("success", false),
        "非临时生成成功")
    _assert_equal(events[0]["from_zone"], "generated", "生成使用虚拟来源区")
    _assert_equal(events[0]["reason"], "temporary_generate",
        "临时生成保留 temporary_generate")
    _assert_equal(events[1]["reason"], "permanent_generate",
        "非临时生成保留 permanent_generate")

    var removed: Dictionary = engine.player.permanently_remove_card(
        str(permanent.id), "battle_permanent_remove")
    _assert_true(removed.get("success", false), "战斗中永久移出成功")
    _assert_equal(events[-1]["to_zone"], "permanently_removed",
        "永久移出公开虚拟目标区")

    var existing = _card("8", "mountain")
    engine.player.draw_pile = [existing]
    var bottom_card = _card("9", "forest")
    engine.player.hand = [bottom_card]
    var bottom: Dictionary = engine.effect_ports.move_card(
        engine.player, "hand", engine.player, "draw_pile", bottom_card,
        "effect", "bottom", "rule")
    _assert_true(bottom.get("success", false), "放到牌库底移动成功")
    _assert_true(placement_probe["bottom_visible"],
        "bottom 事实发布前牌已位于牌库底")
    _assert_equal(events[-1]["placement"], "bottom",
        "bottom 由同一次移动事实公开")
    _assert_equal(engine.player.draw_pile[0], bottom_card,
        "不再依赖移动后的二次重排")
    _disconnect_event_probes(engine)


func _test_staging_commits_logical_hand_facts() -> void:
    var engine = _engine(6103)
    var first = _card("2", "wind")
    var second = _card("3", "forest")
    engine.player.hand = [first, second]
    var moved_facts: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "card_moved":
                moved_facts.append(values.duplicate(true)))
    _assert_true(engine.player.stage_cards([str(first.id), str(second.id)]),
        "两张牌进入暂存提案")
    _assert_true(moved_facts.is_empty(), "stage 不发布 committed 事实")
    engine.player.rollback_staging()
    _assert_true(moved_facts.is_empty(), "stage_rollback 不发布 committed 事实")
    _assert_true(engine.player.stage_cards([str(first.id), str(second.id)]),
        "再次暂存成功")
    engine.player.commit_selected_staging([first, second], {
        "action_token": "stage-confirm-1",
    })
    _assert_equal(moved_facts.size(), 2, "正式确认后每张牌只发布一次")
    _assert_true(moved_facts.all(func(fact):
        return fact["from_zone"] == "hand" \
            and fact["to_zone"] == "discard_pile"),
        "确认事实还原逻辑 hand 到最终牌区")
    _assert_equal([
        moved_facts[0]["hand_count_before"], moved_facts[0]["hand_count_after"],
        moved_facts[1]["hand_count_before"], moved_facts[1]["hand_count_after"],
    ], [2, 1, 1, 0], "多张确认按稳定逻辑顺序冻结手牌数量")
    _assert_equal(moved_facts.filter(func(fact):
        return fact["hand_count_before"] > 0 \
            and fact["hand_count_after"] == 0).size(), 1,
        "清空手牌仅最后一张满足非零到零")

    var void_card = _card("6", "fire")
    engine.player.hand = [void_card]
    engine.status_system.apply_card_anomaly(
        void_card, "mark", "void", {}, "专项测试")
    engine.player.stage_cards([str(void_card.id)])
    engine.player.commit_selected_staging([void_card], {
        "action_token": "void-confirm-1",
    })
    var void_fact: Dictionary = moved_facts[-1]
    _assert_equal(void_fact["from_zone"], "hand", "虚无确认仍还原 hand 来源")
    _assert_equal(void_fact["to_zone"], "temporarily_removed",
        "虚无打出事实公开最终临时移出区")
    _assert_equal(void_fact["reason"], "void", "虚无消散保留准确原因")
    _disconnect_event_probes(engine)


func _test_synchronous_and_cross_holder_facts() -> void:
    var engine = _engine(6104)
    var first = _card("7", "wind")
    var second = _card("8", "forest")
    engine.player.hand = [first, second]
    var moved_entries: Array[Dictionary] = []
    var all_arrived_probe := {"visible": true}
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, receipt: Dictionary):
            if kind != "card_moved":
                return
            moved_entries.append({
                "values": values.duplicate(true),
                "receipt": receipt.duplicate(true),
            })
            if str(values.get("movement_batch_token", "")) != "":
                all_arrived_probe["visible"] = all_arrived_probe["visible"] \
                    and engine.player.discard_pile.has(first) \
                    and engine.player.discard_pile.has(second))
    var synchronized: Array = engine.effect_ports.move_cards_synchronously([
        {"side": engine.player, "source_zone": "hand",
            "destination_zone": "discard_pile", "card": first,
            "reason": "effect"},
        {"side": engine.player, "source_zone": "hand",
            "destination_zone": "discard_pile", "card": second,
            "reason": "effect"},
    ], "rule")
    _assert_equal(synchronized.size(), 2, "同步移动提交两张牌")
    _assert_equal(moved_entries.size(), 2, "同步移动每张一个通用事实")
    _assert_true(all_arrived_probe["visible"], "观察者不会看到半完成批次")
    var first_fact: Dictionary = moved_entries[0]["values"]
    var second_fact: Dictionary = moved_entries[1]["values"]
    _assert_true(first_fact["movement_batch_token"] != "" \
            and first_fact["movement_batch_token"] \
                == second_fact["movement_batch_token"],
        "同步事实共享稳定批次令牌")
    _assert_equal([
        first_fact["movement_batch_index"], second_fact["movement_batch_index"]],
        [0, 1], "同步事实批次内序号稳定")
    _assert_equal([
        first_fact["from_zone_count_before"],
        first_fact["from_zone_count_after"],
        second_fact["from_zone_count_before"],
        second_fact["from_zone_count_after"],
    ], [2, 1, 1, 0], "同步批次逐张冻结逻辑 before/after")

    moved_entries.clear()
    var transferred = _card("10", "mountain")
    engine.player.hand = [transferred]
    var transfer: Dictionary = engine.effect_ports.move_card(
        engine.player, "hand", engine.enemy, "draw_pile", transferred,
        "temporary_transfer", "top", "rule")
    _assert_true(transfer.get("success", false), "跨双方临时转移成功")
    var transfer_fact: Dictionary = moved_entries[0]["values"]
    _assert_equal(transfer_fact["from_holder"], engine.player,
        "跨侧事实保留来源持有方对象")
    _assert_equal(transfer_fact["to_holder"], engine.enemy,
        "跨侧事实保留目标持有方对象")
    _assert_equal(transfer_fact["original_owner_id"],
        str(engine.player.owner_id), "跨侧事实保留原始所有者")
    _assert_equal(moved_entries[0]["receipt"]["owner_ids"], [
        str(engine.player.owner_id), str(engine.enemy.owner_id)],
        "跨侧移动仍由双方来源观察")
    _disconnect_event_probes(engine)


func _test_failed_restore_and_cleanup_do_not_publish() -> void:
    var engine = _engine(6105)
    var card = _card("Q", "forest")
    engine.player.hand = [card]
    var facts: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "card_moved":
                facts.append(values.duplicate(true)))
    var failed: Dictionary = engine.player.card_zone_service.move_card(
        engine.player, "draw_pile", "discard_pile", card, "effect")
    _assert_true(not failed.get("success", true), "失败移动请求被拒绝")
    _assert_true(facts.is_empty(), "失败移动不发布事实")
    var state: Dictionary = engine.player.capture_passive_query_state()
    engine.player.replace_passive_query_state(state)
    _assert_true(facts.is_empty(), "快照恢复不发布事实")

    var temporary = _card("K", "fire")
    engine.player.add_generated_card(temporary, "hand", true)
    facts.clear()
    engine.player.card_zone_service.permanently_remove(
        engine.player, str(temporary.id), "battle_end_temporary")
    _assert_true(facts.is_empty(), "战斗退出临时牌清理不发布事实")

    var transferred = _card("A", "wind")
    engine.player.hand = [transferred]
    engine.player.temporarily_transfer_card_to(
        engine.enemy, str(transferred.id), "draw_pile")
    facts.clear()
    engine.player.card_zone_service.return_all_transferred_cards([
        engine.player, engine.enemy])
    _assert_true(facts.is_empty(), "战后批量归还清理不发布事实")
    _disconnect_event_probes(engine)


func _test_all_side_passives_keep_effect_owner() -> void:
    var engine = _engine(6106)
    var probe_id := "card_moved_owner_probe"
    engine.content_catalog._indexes["item"][probe_id] = {
        "id": probe_id,
        "name": "牌区观察归属探针",
        "behaviors": [{
            "id": "battle_effects",
            "configuration": {
                "hook": "card_moved",
                "effects": [{"op": "defense", "amount": 1}],
            },
        }],
    }
    engine.player.item_ids.assign([probe_id])
    engine.enemy.item_ids.assign([probe_id])
    engine.player.defense = 0
    engine.enemy.defense = 0
    var card = _card("J", "mountain")
    engine.player.hand = [card]
    var moved: Dictionary = engine.player.card_zone_service.move_card(
        engine.player, "hand", "discard_pile", card, "effect")
    _assert_true(moved.get("success", false), "双方观察归属探针移动成功")
    _assert_equal(engine.player.defense, 1,
        "移动方来源的被动效果归属自身")
    _assert_equal(engine.enemy.defense, 1,
        "观察敌方移动的来源仍把效果施加给自身")


func _disconnect_event_probes(engine) -> void:
    for connection in engine.battle_passive_event_service \
            .event_committed.get_connections():
        engine.battle_passive_event_service.event_committed.disconnect(
            connection["callable"])
