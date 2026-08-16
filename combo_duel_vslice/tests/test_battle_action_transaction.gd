extends "res://tests/support/expanded_technique_test_base.gd"

const ActionTransactionScript = preload(
    "res://core/battle_action_transaction.gd")


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_state_transitions_and_snapshot_contract()
    _test_solo_choice_transaction()
    _test_post_commit_choice_transaction()
    _test_enemy_only_choice_transaction()
    _test_synchronized_repeated_choice_transaction()
    _test_cooperation_resolution_choice_transaction()
    _test_cooperation_post_commit_choice_transaction()
    _test_legacy_pending_kinds_removed()
    _finish("BATTLE ACTION TRANSACTION TEST")


func _test_state_transitions_and_snapshot_contract() -> void:
    var transaction = ActionTransactionScript.new()
    var runtime_card = _card("7", "wind")
    var started: Dictionary = transaction.begin_transaction({
        "transaction_id": "tx-unit-001",
        "root_action_token": "root-unit-001",
        "resolution_mode": ActionTransactionScript.RESOLUTION_SOLO,
        "initiator_owner_id": "player",
        "participating_owner_ids": ["player", "enemy"],
        "acting_owner_ids": ["player"],
        "records": [],
        "previews": {
            "player": {
                "cards": [runtime_card],
                "callback": Callable(self, "_runtime_probe"),
                "service": self,
            },
        },
        "cooperation_groups": [{
            "group_index": 1,
            "preview": {"cards": [runtime_card]},
        }],
        "frozen_card_instance_ids": {"player": [str(runtime_card.id)]},
        "frozen_same_qi": {"player": {"frozen": true, "gain": 1}},
    })
    _assert_true(started.get("success", false), "事务从 frozen 稳定建立")
    var duplicate_start: Dictionary = transaction.begin_transaction({
        "transaction_id": "tx-unit-002",
        "root_action_token": "root-unit-002",
        "resolution_mode": ActionTransactionScript.RESOLUTION_SOLO,
    })
    _assert_equal(duplicate_start.get("code"), "transaction_already_active",
        "未完成事务拒绝同时开始第二事务")
    var illegal_post_commit: Dictionary = transaction.advance_phase(
        ActionTransactionScript.PHASE_POST_COMMIT)
    _assert_equal(illegal_post_commit.get("code"), "illegal_phase_transition",
        "frozen 不能跳过结算和牌区提交")
    _assert_true(transaction.advance_phase(
        ActionTransactionScript.PHASE_RESOLVING).get("success", false),
        "frozen 合法进入 resolving")
    _assert_true(transaction.suspend_for_choice(
        "request-a", ActionTransactionScript.CURSOR_GROUP_EFFECTS).get(
            "success", false), "resolving 以独立暂停状态等待选择")
    var before_wrong: Dictionary = transaction.snapshot()
    var wrong_request: Dictionary = transaction.validate_resume("request-wrong")
    _assert_equal(wrong_request.get("code"), "choice_request_mismatch",
        "错误 request_id 被事务拒绝")
    _assert_equal(transaction.snapshot(), before_wrong,
        "错误 request_id 不改变事务")
    _assert_true(transaction.resume_from_choice(
        "request-a", "request-b",
        ActionTransactionScript.CURSOR_GROUP_EFFECTS).get("success", false),
        "一次恢复后可在同一事务发布新选择")
    _assert_equal(transaction.choice_request_id, "request-b",
        "连续选择更新 request_id 而不新建事务")
    var repeated_request: Dictionary = transaction.validate_resume("request-a")
    _assert_equal(repeated_request.get("code"), "choice_request_mismatch",
        "已经消费的旧 request_id 不能重复提交")
    _assert_true(transaction.resume_from_choice("request-b").get(
        "success", false), "第二次选择恢复当前效果链")
    _assert_true(transaction.mark_group_resolution_completed().get(
        "success", false), "结算完成标识只在 resolving 写入")
    _assert_true(transaction.advance_phase(
        ActionTransactionScript.PHASE_COMMITTING_ZONES).get("success", false),
        "完成结算后进入牌区提交")
    var early_post_commit: Dictionary = transaction.advance_phase(
        ActionTransactionScript.PHASE_POST_COMMIT)
    _assert_equal(early_post_commit.get("code"), "zones_not_committed",
        "牌区未提交时不能进入 post_commit")
    _assert_true(transaction.mark_zones_committed({
        "player": [str(runtime_card.id)],
    }).get("success", false), "牌区提交保存稳定实例 ID")
    _assert_true(transaction.advance_phase(
        ActionTransactionScript.PHASE_POST_COMMIT).get("success", false),
        "牌区提交后进入 post_commit")
    _assert_true(transaction.mark_post_commit_completed().get(
        "success", false), "post_commit 完成标识写入")
    var snapshot: Dictionary = transaction.snapshot()
    _assert_true(not _contains_runtime_reference(snapshot),
        "事务 snapshot 不包含 Object、Callable 或服务实例")
    _assert_equal(snapshot["previews"]["player"]["cards"][0]["id"],
        str(runtime_card.id), "事务 snapshot 将卡牌转换为稳定 DTO")
    _assert_true(transaction.complete_transaction({"success": true}).get(
        "success", false), "post_commit 完成后事务进入 completed")
    _assert_equal(transaction.phase(), ActionTransactionScript.PHASE_COMPLETED,
        "完成事务保持明确 completed 终态")
    _assert_equal(transaction.validate_resume("request-b").get("code"),
        "transaction_not_active", "completed 事务不能恢复")

    var failed_transaction = ActionTransactionScript.new()
    failed_transaction.begin_transaction({
        "transaction_id": "tx-failed-001",
        "root_action_token": "root-failed-001",
        "resolution_mode": ActionTransactionScript.RESOLUTION_SOLO,
    })
    failed_transaction.fail_transaction("测试失败", "test_failure")
    _assert_equal(failed_transaction.phase(), ActionTransactionScript.PHASE_FAILED,
        "失败事务进入 failed 终态并保存结构化原因")
    _assert_equal(failed_transaction.validate_resume("request-x").get("code"),
        "transaction_not_active", "failed 事务不能恢复")


func _test_solo_choice_transaction() -> void:
    var engine = _engine(91001)
    var selected = _card("8", "wind")
    var reserve = _card("3", "forest")
    var reserve_second = _card("4", "fire")
    engine.player.hand = [selected, reserve, reserve_second]
    _install_wait_technique(engine, "tx_solo_wait", "high", false)
    engine.sequence_book.configure({"high_card": ["tx_solo_wait"]})
    engine.actions_available = 1
    var start: Dictionary = engine.confirm_play([str(selected.id)])
    _assert_true(start.get("pending_choice", false),
        "玩家单方功法效果进入等待选择：%s" % str(start))
    if not start.get("pending_choice", false):
        return
    var snapshot: Dictionary = engine.pending_action_transaction_snapshot()
    _assert_equal(snapshot.get("phase"), ActionTransactionScript.PHASE_RESOLVING,
        "单方效果等待保持 resolving 阶段")
    _assert_equal(snapshot.get("resume_cursor"),
        ActionTransactionScript.CURSOR_GROUP_EFFECTS,
        "单方效果等待只记录 group_effects 游标")
    _assert_true(snapshot.get("suspended", false),
        "等待玩家选择是 suspended 状态而非新 phase")
    var actions_before: int = engine.actions_available
    var staging_before: int = engine.player.staging.size()
    var wrong: Dictionary = engine.resolve_effect_choice(
        "wrong-request", [str(reserve.id)])
    _assert_true(not wrong.get("success", true), "错误 request_id 不恢复单方事务")
    _assert_equal(engine.actions_available, actions_before,
        "错误 request_id 不重复消费行动次数")
    _assert_equal(engine.player.staging.size(), staging_before,
        "错误 request_id 不移动待出区")
    var second_action: Dictionary = engine.confirm_play([str(reserve.id)])
    _assert_equal(second_action.get("code"), null,
        "第二行动通过公开失败原因拒绝而不建立嵌套事务")
    _assert_true(not second_action.get("success", true),
        "活动事务期间拒绝开始第二行动")
    var finish: Dictionary = engine.resolve_effect_choice(
        str(start["choice_request"]["request_id"]), [str(reserve.id)])
    _assert_true(finish.get("success", false), "玩家单方选择恢复后完成行动")
    _assert_true(engine.pending_action_transaction_snapshot().get(
        "transaction_id", "") == "", "完成后清除活动事务")
    var discard_after: int = engine.player.discard_pile.size()
    var repeated: Dictionary = engine.resolve_effect_choice(
        str(start["choice_request"]["request_id"]), [str(reserve.id)])
    _assert_true(not repeated.get("success", true), "相同 request_id 重复提交被拒绝")
    _assert_equal(engine.player.discard_pile.size(), discard_after,
        "重复提交不重复移动行动牌")


func _test_post_commit_choice_transaction() -> void:
    var engine = _engine(91002)
    var cards := [
        _card("7", "wind"), _card("7", "forest"), _card("7", "fire")]
    engine.player.hand = cards.duplicate()
    engine.sequence_book.configure({"three_kind": ["three_wind_return_tide"]})
    engine.actions_available = 1
    var start: Dictionary = engine.confirm_play(_ids(cards))
    _assert_true(start.get("pending_choice", false),
        "玩家单方 post_commit 进入等待选择")
    var snapshot: Dictionary = engine.pending_action_transaction_snapshot()
    _assert_equal(snapshot.get("phase"), ActionTransactionScript.PHASE_POST_COMMIT,
        "post_commit 等待保持独立阶段")
    _assert_equal(snapshot.get("resume_cursor"),
        ActionTransactionScript.CURSOR_POST_COMMIT_EFFECTS,
        "post_commit 等待使用统一游标")
    _assert_true(snapshot.get("group_zones_committed", false),
        "post_commit 等待前牌区已提交")
    _assert_equal(engine.player.discard_pile.size(), 3,
        "post_commit 等待前行动牌只提交一次")
    var finish: Dictionary = engine.resolve_effect_choice(
        str(start["choice_request"]["request_id"]), [])
    _assert_true(finish.get("success", false), "post_commit 选择恢复后完成行动")


func _test_enemy_only_choice_transaction() -> void:
    var engine = _engine(91003)
    var selected = _card("9", "fire")
    var reserve = _card("4", "mountain")
    var reserve_second = _card("5", "forest")
    engine.enemy.hand = [selected, reserve, reserve_second]
    _install_wait_technique(engine, "tx_enemy_wait", "high", false)
    engine.enemy_sequence_book.configure({"high_card": ["tx_enemy_wait"]})
    engine.battle_flow.set_action_count(engine.player, 0)
    engine.battle_flow.set_action_count(engine.enemy, 1)
    engine.locked_enemy_card_ids = [str(selected.id)]
    var start: Dictionary = engine.action_service.resolve_locked_enemy_action_once()
    _assert_true(start.get("pending_choice", false),
        "敌方单方行动进入等待选择：%s" % str(start))
    if not start.get("pending_choice", false):
        return
    var snapshot: Dictionary = engine.pending_action_transaction_snapshot()
    _assert_equal(snapshot.get("initiator_owner_id"), str(engine.enemy.owner_id),
        "敌方单方事务冻结敌方为发起者")
    _assert_equal(snapshot.get("resolution_mode"),
        ActionTransactionScript.RESOLUTION_SOLO, "敌方单方事务使用 solo 模式")
    var candidates: Array = start["choice_request"].get("candidate_ids", [])
    var finish: Dictionary = engine.resolve_effect_choice(
        str(start["choice_request"]["request_id"]),
        [str(candidates[0])] if not candidates.is_empty() else [])
    _assert_true(finish.get("success", false), "敌方单方选择恢复后完成行动")


func _test_synchronized_repeated_choice_transaction() -> void:
    var engine = _engine(91004)
    var player_selected = _card("10", "wind")
    var player_reserve = _card("2", "forest")
    var player_reserve_second = _card("4", "mountain")
    var enemy_selected = _card("J", "fire")
    var enemy_reserve = _card("3", "mountain")
    var enemy_reserve_second = _card("5", "forest")
    engine.player.hand = [player_selected, player_reserve, player_reserve_second]
    engine.enemy.hand = [enemy_selected, enemy_reserve, enemy_reserve_second]
    _install_wait_technique(engine, "tx_sync_wait", "high", false)
    engine.sequence_book.configure({"high_card": ["tx_sync_wait"]})
    engine.enemy_sequence_book.configure({"high_card": ["tx_sync_wait"]})
    engine.scripted_mode = true
    engine.battle_flow.set_action_count(engine.player, 1)
    engine.battle_flow.set_action_count(engine.enemy, 1)
    engine.locked_enemy_card_ids = [str(enemy_selected.id)]
    var start: Dictionary = engine.confirm_play([str(player_selected.id)])
    _assert_true(start.get("pending_choice", false),
        "同步行动首个效果等待选择：%s" % str(start))
    if not start.get("pending_choice", false):
        return
    var first_snapshot: Dictionary = engine.pending_action_transaction_snapshot()
    _assert_equal(first_snapshot.get("resolution_mode"),
        ActionTransactionScript.RESOLUTION_SYNCHRONIZED,
        "同步行动事务冻结 synchronized 模式")
    _assert_equal(first_snapshot.get("acting_owner_ids", []).size(), 2,
        "同步行动事务冻结双方行动参与者")
    var first_request := str(start["choice_request"]["request_id"])
    var first_candidates: Array = start["choice_request"].get("candidate_ids", [])
    var second_wait: Dictionary = engine.resolve_effect_choice(
        first_request,
        [str(first_candidates[0])] if not first_candidates.is_empty() else [])
    _assert_true(second_wait.get("pending_choice", false),
        "一次恢复后同一同步事务可再次等待选择")
    var second_snapshot: Dictionary = engine.pending_action_transaction_snapshot()
    _assert_equal(second_snapshot.get("transaction_id"),
        first_snapshot.get("transaction_id"), "连续选择不创建新事务")
    _assert_true(second_snapshot.get("choice_request_id") != first_request,
        "连续选择更新为新 request_id")
    var second_candidates: Array = second_wait["choice_request"].get(
        "candidate_ids", [])
    var finish: Dictionary = engine.resolve_effect_choice(
        str(second_wait["choice_request"]["request_id"]),
        [str(second_candidates[0])] if not second_candidates.is_empty() else [])
    _assert_true(finish.get("success", false), "同步双方选择完成后事务只完成一次")


func _test_cooperation_resolution_choice_transaction() -> void:
    var engine = _engine(91005)
    var main := [
        _card("6", "wind"), _card("6", "forest"), _card("6", "fire")]
    var cooperation = _card("4", "mountain")
    var reserve = _card("9", "wind")
    var reserve_second = _card("10", "forest")
    engine.player.hand = main + [cooperation, reserve, reserve_second]
    _install_cooperation_main(engine, "tx_coop_resolve_main")
    _install_wait_technique(engine, "tx_coop_resolve_wait", "high", false)
    engine.sequence_book.configure({
        "three_kind": ["tx_coop_resolve_main"],
        "high_card": ["tx_coop_resolve_wait"],
    })
    engine.actions_available = 1
    var start: Dictionary = engine.confirm_play(_ids(main), [str(cooperation.id)])
    _assert_true(start.get("pending_choice", false),
        "协同组结算进入等待选择：%s" % str(start))
    if not start.get("pending_choice", false):
        return
    var snapshot: Dictionary = engine.pending_action_transaction_snapshot()
    _assert_equal(snapshot.get("group_kind"),
        ActionTransactionScript.GROUP_COOPERATION, "事务明确当前为协同组")
    _assert_equal(snapshot.get("group_index"), 1, "事务保存协同组序号")
    _assert_equal(snapshot.get("phase"), ActionTransactionScript.PHASE_RESOLVING,
        "协同组效果等待仍使用 resolving")
    var finish: Dictionary = engine.resolve_effect_choice(
        str(start["choice_request"]["request_id"]), [str(reserve.id)])
    _assert_true(finish.get("success", false), "协同组结算选择恢复后完成行动")


func _test_cooperation_post_commit_choice_transaction() -> void:
    var engine = _engine(91006)
    var main := [
        _card("5", "wind"), _card("5", "forest"), _card("5", "fire")]
    var cooperation = _card("8", "mountain")
    var reserve = _card("2", "wind")
    var reserve_second = _card("3", "forest")
    engine.player.hand = main + [cooperation, reserve, reserve_second]
    _install_cooperation_main(engine, "tx_coop_main")
    _install_wait_technique(engine, "tx_coop_post", "high", true)
    engine.sequence_book.configure({
        "three_kind": ["tx_coop_main"],
        "high_card": ["tx_coop_post"],
    })
    engine.actions_available = 1
    var start: Dictionary = engine.confirm_play(_ids(main), [str(cooperation.id)])
    _assert_true(start.get("pending_choice", false),
        "协同组 post_commit 进入等待选择：%s" % str(start))
    if not start.get("pending_choice", false):
        return
    var snapshot: Dictionary = engine.pending_action_transaction_snapshot()
    _assert_equal(snapshot.get("group_kind"),
        ActionTransactionScript.GROUP_COOPERATION,
        "协同 post_commit 保持独立 group_kind")
    _assert_equal(snapshot.get("phase"), ActionTransactionScript.PHASE_POST_COMMIT,
        "协同 post_commit 等待使用统一 post_commit phase")
    _assert_equal(snapshot.get("resume_cursor"),
        ActionTransactionScript.CURSOR_POST_COMMIT_EFFECTS,
        "协同 post_commit 使用统一恢复游标")
    _assert_true(snapshot.get("committed_card_instance_ids", {}).get(
        str(engine.player.owner_id), []).has(str(cooperation.id)),
        "事务累计保存协同组已提交真气 ID")
    var candidates: Array = start["choice_request"].get("candidate_ids", [])
    var finish: Dictionary = engine.resolve_effect_choice(
        str(start["choice_request"]["request_id"]),
        [str(candidates[0])] if not candidates.is_empty() else [])
    _assert_true(finish.get("success", false),
        "协同组 post_commit 选择恢复后完成行动")


func _test_legacy_pending_kinds_removed() -> void:
    var source := FileAccess.get_file_as_string(
        "res://core/battle_action_service.gd")
    _assert_true(not source.contains("pending_action_resolution"),
        "服务内部不再保留旧 pending_action_resolution")
    _assert_true(not FileAccess.file_exists(
        "res://core/battle_pending_action_transaction.gd"),
        "旧 BattlePendingActionTransaction 已删除")
    for legacy_kind in [
            "solo_player_post_commit", "solo_cooperation_post_commit",
            "synchronized_post_commit", "synchronized_cooperation_post_commit",
            "enemy_only_post_commit"]:
        _assert_true(not source.contains('"%s"' % legacy_kind),
            "旧组合 pending kind 不再作为字符串状态：%s" % legacy_kind)


func _install_wait_technique(
        engine, technique_id: String, pool: String, post_commit: bool) -> void:
    var effect := {
        "op": "select_cards",
        "choice_id": "%s_choice" % technique_id,
        "prompt": "事务测试选择",
        "chooser": "actor",
        "minimum": 1,
        "maximum": 1,
        "insufficient_policy": "fail",
        "query": {"side": "actor", "zone": "hand", "order": "zone"},
        "capture": "%s_capture" % technique_id,
    }
    if post_commit:
        effect["phase"] = "post_commit"
    engine.repository.techniques[technique_id] = {
        "id": technique_id,
        "name": technique_id,
        "pool": pool,
        "effects": [effect],
    }


func _install_cooperation_main(engine, technique_id: String) -> void:
    engine.repository.techniques[technique_id] = {
        "id": technique_id,
        "name": technique_id,
        "pool": "three",
        "effects": [],
        "cooperation": {
            "hand_id": "high_card",
            "max_groups": 1,
            "power_rule": "shared_half",
            "exact_card_count": 1,
            "post_commit": {"destination": "own_discard"},
        },
    }


func _ids(cards: Array) -> Array[String]:
    return cards.map(func(card): return str(card.id))


func _contains_runtime_reference(value) -> bool:
    if typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL]:
        return true
    if value is Array:
        return value.any(func(item): return _contains_runtime_reference(item))
    if value is Dictionary:
        return value.values().any(
            func(item): return _contains_runtime_reference(item))
    return false


func _runtime_probe() -> void:
    pass
