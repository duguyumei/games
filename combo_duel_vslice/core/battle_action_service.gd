class_name BattleActionService
extends RefCounted

## 牌型组行动事务。
##
## 该服务只负责“提案 → 锁定 → 结算 → 提交牌区”的事务顺序，
## 不负责生成内容、不负责 UI，也不直接决定战斗胜负。
## 待选择功法会把事务记录保存在这里，选择完成后从原位置继续。

const ActionPreviewServiceScript = preload("res://core/action_preview_service.gd")
const PendingActionTransactionScript = preload("res://core/battle_pending_action_transaction.gd")
const SequenceBookScript = preload("res://core/sequence_book.gd")
const SameQiRuleScript = preload("res://core/same_qi_rule.gd")

var player
var enemy
var battle_flow
var player_action_controller
var action_resolver
var trigger_queue
var sequence_book
var enemy_sequence_book

var scripted_mode: bool = false
var enemy_ai_enabled: bool = false
var external_enemy_action_mode: bool = false
var enemy_action_index_reader: Callable
var enemy_action_index_writer: Callable
var turn_number_reader: Callable
var locked_enemy_cards_reader: Callable
var battle_state_reader: Callable
var preview_player: Callable
var preview_for_side: Callable
var action_unavailable_reason: Callable
var update_battle_state: Callable
var lock_enemy_action: Callable
var clear_enemy_action_lock: Callable
var resolve_enemy_only_actions: Callable
var set_scenario_error: Callable
var emit_state_changed: Callable

var pending_action_resolution = PendingActionTransactionScript.new()
var last_preview: Dictionary = {}
var last_enemy_preview: Dictionary = {}
var last_played_hand: String = ""
var last_player_action_cards: Array = []
var last_enemy_action_cards: Array = []

func _init(
        player_side,
        enemy_side,
        flow,
        player_controller,
        resolver,
        history,
        player_book,
        opponent_book,
        player_preview_callback: Callable,
        preview_callback: Callable,
        unavailable_reason_callback: Callable,
        battle_state_callback: Callable,
        update_state_callback: Callable,
        lock_enemy_callback: Callable,
        clear_enemy_callback: Callable,
        resolve_enemy_only_callback: Callable,
        scenario_error_callback: Callable,
        state_changed_callback: Callable,
        read_enemy_action_index: Callable,
        write_enemy_action_index: Callable,
        read_turn_number: Callable,
        read_locked_enemy_cards: Callable) -> void:
    player = player_side
    enemy = enemy_side
    battle_flow = flow
    player_action_controller = player_controller
    action_resolver = resolver
    trigger_queue = history
    sequence_book = player_book
    enemy_sequence_book = opponent_book
    preview_player = player_preview_callback
    preview_for_side = preview_callback
    action_unavailable_reason = unavailable_reason_callback
    battle_state_reader = battle_state_callback
    update_battle_state = update_state_callback
    lock_enemy_action = lock_enemy_callback
    clear_enemy_action_lock = clear_enemy_callback
    resolve_enemy_only_actions = resolve_enemy_only_callback
    set_scenario_error = scenario_error_callback
    emit_state_changed = state_changed_callback
    enemy_action_index_reader = read_enemy_action_index
    enemy_action_index_writer = write_enemy_action_index
    turn_number_reader = read_turn_number
    locked_enemy_cards_reader = read_locked_enemy_cards

func reset() -> void:
    pending_action_resolution.clear()
    last_preview.clear()
    last_enemy_preview.clear()
    last_played_hand = ""
    last_player_action_cards.clear()
    last_enemy_action_cards.clear()

func set_modes(is_scripted: bool, uses_enemy_ai: bool, uses_external_enemy_actions: bool) -> void:
    scripted_mode = is_scripted
    enemy_ai_enabled = uses_enemy_ai
    external_enemy_action_mode = uses_external_enemy_actions

func confirm_play(card_ids: Array, cooperation_card_ids: Array = []) -> Dictionary:
    if battle_state_reader.call() != "active":
        return {"success": false, "reason": "战斗已经结束"}
    if action_resolver.has_pending_choice():
        return {"success": false, "reason": "正在等待功法选择，请先完成选择"}
    if not battle_flow.can_act(player):
        return {"success": false, "reason": action_unavailable_reason.call(player)}
    var proposal = player_action_controller.propose(
        card_ids,
        func(selected_ids: Array): return preview_player.call(selected_ids))
    if not proposal.accepted:
        return {"success": false, "reason": proposal.rejection_reason}
    var cooperation_result := _prepare_cooperation(proposal, cooperation_card_ids)
    if not cooperation_result.get("success", false):
        return cooperation_result
    if scripted_mode:
        return _confirm_synchronized_play(proposal)
    return _confirm_solo_player(proposal)

func has_pending_choice() -> bool:
    return action_resolver.has_pending_choice()

func pending_choice_snapshot() -> Dictionary:
    return action_resolver.pending_choice_snapshot()

func pending_action_transaction_snapshot() -> Dictionary:
    return pending_action_resolution.snapshot()

func resolve_effect_choice(request_id: String, selected_card_ids: Array) -> Dictionary:
    if pending_action_resolution.is_empty() or not action_resolver.has_pending_choice():
        return {"success": false, "reason": "当前没有等待中的功法选择"}
    var resolution: Dictionary = action_resolver.resume_choice(request_id, selected_card_ids)
    if resolution.get("pending_choice", false):
        var current_request: Dictionary = action_resolver.pending_choice_snapshot()
        var detail := str(resolution.get("detail", "等待选择"))
        var same_request := str(current_request.get("request_id", "")) == request_id
        return {
            "success": false if same_request else true,
            "pending_choice": true,
            "choice_request": current_request,
            "reason": detail if same_request else "",
            "detail": detail,
        }
    if not resolution.get("success", false):
        action_resolver.abort_action_resolution()
        return {"success": false, "reason": resolution.get("detail", "功法选择恢复失败")}

    var pending = pending_action_resolution
    pending_action_resolution = PendingActionTransactionScript.new()
    match pending.kind:
        "solo_player":
            return _finish_solo_player_resolution(pending.record, pending.action_preview)
        "solo_player_post_commit":
            return _finish_solo_player_post_commit(
                pending.record, pending.action_preview,
                pending.metadata.get("played_cards", []))
        "solo_cooperation":
            return _finish_solo_cooperation_resolution(
                pending.record, pending.action_preview, pending.metadata)
        "solo_cooperation_post_commit":
            return _finish_solo_cooperation_post_commit(
                pending.record, pending.action_preview, pending.metadata)
        "synchronized_cooperation":
            return _finish_synchronized_cooperation_resolution(
                pending.record, pending.action_preview, pending.metadata)
        "synchronized_cooperation_post_commit":
            return _finish_synchronized_cooperation_post_commit(
                pending.record, pending.action_preview, pending.metadata)
        "synchronized":
            return _finish_synchronized_resolution(
                pending.records,
                pending.player_preview,
                pending.enemy_preview,
                pending.enemy_will_act)
        "synchronized_post_commit":
            return _finish_synchronized_post_commit(pending)
        "enemy_only":
            return _finish_enemy_only_resolution(pending.record, pending.action_preview)
        "enemy_only_post_commit":
            return _finish_enemy_only_post_commit(
                pending.record, pending.action_preview,
                pending.metadata.get("enemy_cards", []))
    return {"success": false, "reason": "未知的待恢复行动类型"}

func resolve_locked_enemy_action_once() -> Dictionary:
    if not battle_flow.can_act(enemy):
        return {"success": false, "reason": action_unavailable_reason.call(enemy)}
    var locked_card_ids: Array = locked_enemy_cards_reader.call()
    if locked_card_ids.is_empty():
        return {"success": false, "reason": "敌方尚未锁定行动提案"}
    var action_preview: Dictionary = preview_for_side.call(
        enemy, locked_card_ids, enemy_sequence_book)
    if not action_preview.get("valid", false) or not enemy.stage_cards(locked_card_ids):
        var detail := "对手锁定出牌失效"
        set_scenario_error.call(detail)
        return {"success": false, "reason": detail}
    var finalize_result: Dictionary = action_resolver.finalize_action_preview(
        enemy, action_preview, player, turn_number_reader.call())
    if not finalize_result.get("success", false):
        enemy.rollback_staging()
        return finalize_result
    var confirmed_result: Dictionary = action_resolver.confirm_finalized_action(
        enemy, action_preview, player, turn_number_reader.call())
    if not confirmed_result.get("success", false):
        enemy.rollback_staging()
        return confirmed_result

    battle_flow.lock_intent(enemy, action_preview)
    battle_flow.consume_action(enemy)
    _freeze_consumed_action_source(enemy, action_preview)
    _notify_action_started(enemy, action_preview)
    last_preview.clear()
    last_enemy_preview = action_preview
    trigger_queue.add_history(
        "enemy_combo_reveal", "对手发动单方连击", "连击", "成功", "计划已转为实际出招")
    action_resolver.log_calculation(enemy, action_preview, enemy_ai_enabled)
    var record = action_resolver.make_action_record(
        enemy, player, action_preview, enemy_sequence_book, 200, turn_number_reader.call())
    action_resolver.begin_action_resolution([player, enemy], {
        "kind": "enemy_only",
        "round_number": int(turn_number_reader.call()),
        "action_tokens": [str(record["token"])],
        "acting_owner_ids": [str(enemy.owner_id)],
    })
    var resolution: Dictionary = action_resolver.resolve_action_records(
        [record], battle_flow.resolution_mode() == "synchronized")
    if resolution.get("pending_choice", false):
        pending_action_resolution.configure_single(
            "enemy_only", record, action_preview)
        emit_state_changed.call()
        return {
            "success": true,
            "pending_choice": true,
            "choice_request": action_resolver.pending_choice_snapshot(),
            "enemy_preview": action_preview,
            "detail": resolution.get("detail", "等待选择"),
        }
    if not resolution.get("success", false):
        action_resolver.abort_action_resolution()
        return {"success": false, "reason": resolution.get("detail", "功法结算失败")}
    return _finish_enemy_only_resolution(record, action_preview)

func _confirm_solo_player(proposal) -> Dictionary:
    if not battle_flow.can_act(player):
        return {"success": false, "reason": action_unavailable_reason.call(player)}
    var action_preview: Dictionary = proposal.preview
    var staged_ids: Array = proposal.card_ids.duplicate()
    for group in proposal.groups.slice(1):
        staged_ids.append_array(group.get("card_ids", []))
    if not player.stage_cards(staged_ids):
        return {"success": false, "reason": "真气无法进入待出区"}
    var finalize_result := _finalize_staged_proposal(player, proposal)
    if not finalize_result.get("success", false):
        player.rollback_staging()
        return finalize_result
    battle_flow.lock_intent(player, action_preview)
    battle_flow.consume_action(player)
    _freeze_consumed_action_source(player, action_preview)
    _notify_action_started(player, action_preview)
    action_resolver.log_calculation(player, action_preview)
    var record = action_resolver.make_action_record(
        player, enemy, action_preview, sequence_book, 100, turn_number_reader.call())
    record.cooperation_groups = proposal.groups.slice(1).duplicate(true)
    action_resolver.begin_action_resolution([player, enemy], {
        "kind": "solo_player",
        "round_number": int(turn_number_reader.call()),
        "action_tokens": [str(record["token"])],
        "acting_owner_ids": [str(player.owner_id)],
    })
    var resolution: Dictionary = action_resolver.resolve_action_records(
        [record], battle_flow.resolution_mode() == "synchronized")
    if resolution.get("pending_choice", false):
        pending_action_resolution.configure_single(
            "solo_player", record, action_preview)
        emit_state_changed.call()
        return {
            "success": true,
            "pending_choice": true,
            "choice_request": action_resolver.pending_choice_snapshot(),
            "preview": action_preview,
            "detail": resolution.get("detail", "等待选择"),
        }
    if not resolution.get("success", false):
        action_resolver.abort_action_resolution()
        return {"success": false, "reason": resolution.get("detail", "功法结算失败")}
    return _finish_solo_player_resolution(record, action_preview)

func _finish_solo_player_resolution(record, action_preview: Dictionary) -> Dictionary:
    var has_cooperation: bool = not record.cooperation_groups.is_empty()
    _notify_action_pre_commit(record)
    var player_commit: Dictionary = action_resolver.commit_staging_for(
        player, action_preview.get("cards", []) if has_cooperation else [])
    var played_cards: Array = player_commit["committed"]
    action_resolver.log_cards_leave(player, played_cards)
    var post_commit: Dictionary = action_resolver.resolve_post_commit_phase()
    if post_commit.get("pending_choice", false):
        pending_action_resolution.configure_single(
            "solo_player_post_commit", record, action_preview,
            {"played_cards": played_cards})
        emit_state_changed.call()
        return {
            "success": true,
            "pending_choice": true,
            "choice_request": action_resolver.pending_choice_snapshot(),
            "preview": action_preview,
            "detail": post_commit.get("detail", "等待提交后选择"),
        }
    if not post_commit.get("success", false):
        action_resolver.abort_action_resolution()
        return {"success": false, "reason": post_commit.get("detail", "提交后效果失败")}
    return _finish_solo_player_post_commit(record, action_preview, played_cards)

func _finish_solo_player_post_commit(
        record, action_preview: Dictionary, played_cards: Array) -> Dictionary:
    var has_cooperation: bool = not record.cooperation_groups.is_empty()
    action_resolver.finish_action_record(record)
    if has_cooperation:
        return _resolve_solo_cooperation(
            record.cooperation_groups[0], action_preview, played_cards)
    return _finish_solo_action_outcome(
        action_preview, played_cards, record["triggered"], false)

func _resolve_solo_cooperation(
        group: Dictionary,
        main_preview: Dictionary,
        main_cards: Array) -> Dictionary:
    action_resolver.effect_ports.close_current_source_binding_window()
    var cooperation_preview: Dictionary = group["preview"]
    var cooperation_record = action_resolver.make_action_record(
        player, enemy, cooperation_preview, sequence_book, 101, turn_number_reader.call())
    var resolution: Dictionary = action_resolver.resolve_action_records(
        [cooperation_record], false)
    if resolution.get("pending_choice", false):
        pending_action_resolution.configure_single(
            "solo_cooperation",
            cooperation_record,
            cooperation_preview,
            {
                "main_preview": main_preview,
                "main_cards": main_cards,
                "main_triggered": true,
                "cooperation": group.get("cooperation", {}),
            })
        emit_state_changed.call()
        return {
            "success": true,
            "pending_choice": true,
            "choice_request": action_resolver.pending_choice_snapshot(),
            "preview": main_preview,
            "cooperation_preview": cooperation_preview,
            "detail": resolution.get("detail", "等待协同功法选择"),
        }
    if not resolution.get("success", false):
        action_resolver.abort_action_resolution()
        return {"success": false, "reason": resolution.get("detail", "协同组结算失败")}
    return _finish_solo_cooperation_resolution(
        cooperation_record,
        cooperation_preview,
        {
            "main_preview": main_preview,
            "main_cards": main_cards,
            "main_triggered": true,
            "cooperation": group.get("cooperation", {}),
        })

func _finish_solo_cooperation_resolution(
        record,
        cooperation_preview: Dictionary,
        metadata: Dictionary) -> Dictionary:
    _notify_cooperation_pre_commit(record)
    var cooperation_commit: Dictionary = action_resolver.commit_cooperation_staging(
        record, metadata.get("cooperation", {}))
    var cooperation_cards: Array = cooperation_commit["committed"]
    action_resolver.log_cards_leave(player, cooperation_cards)
    var post_commit: Dictionary = action_resolver.resolve_post_commit_phase()
    if post_commit.get("pending_choice", false):
        metadata["cooperation_cards"] = cooperation_cards
        pending_action_resolution.configure_single(
            "solo_cooperation_post_commit", record, cooperation_preview, metadata)
        emit_state_changed.call()
        return {
            "success": true,
            "pending_choice": true,
            "choice_request": action_resolver.pending_choice_snapshot(),
            "preview": metadata.get("main_preview", {}),
            "cooperation_preview": cooperation_preview,
            "detail": post_commit.get("detail", "等待协同提交后选择"),
        }
    if not post_commit.get("success", false):
        action_resolver.abort_action_resolution()
        return {"success": false, "reason": post_commit.get("detail", "协同提交后效果失败")}
    metadata["cooperation_cards"] = cooperation_cards
    return _finish_solo_cooperation_post_commit(
        record, cooperation_preview, metadata)

func _finish_solo_cooperation_post_commit(
        record, cooperation_preview: Dictionary, metadata: Dictionary) -> Dictionary:
    action_resolver.finish_action_record(record)
    var all_cards: Array = metadata.get("main_cards", []).duplicate()
    all_cards.append_array(metadata.get("cooperation_cards", []))
    return _finish_solo_action_outcome(
        metadata.get("main_preview", {}),
        all_cards,
        bool(metadata.get("main_triggered", false)),
        record["triggered"],
        cooperation_preview)

func _finish_solo_action_outcome(
        action_preview: Dictionary,
        played_cards: Array,
        main_triggered: bool,
        cooperation_triggered: bool,
        cooperation_preview: Dictionary = {}) -> Dictionary:
    if main_triggered and cooperation_triggered:
        _notify_cooperation_resolved(action_preview, cooperation_preview)
    var action_completed: Dictionary = action_resolver.finish_action_resolution()
    if not action_completed.get("success", false):
        return {"success": false, "reason": action_completed.get(
            "reason", "行动完成时点结算失败")}
    last_player_action_cards = played_cards
    last_enemy_action_cards.clear()
    last_played_hand = action_preview["hand"]["id"]
    var same_qi_change := _apply_same_qi_gain(
        player, action_preview, played_cards)
    if not same_qi_change.get("success", false):
        return same_qi_change
    battle_flow.clear_intents()
    emit_state_changed.call()
    return {
        "success": true,
        "preview": action_preview,
        "cooperation_preview": cooperation_preview,
        "technique_triggered": main_triggered,
        "cooperation_technique_triggered": cooperation_triggered,
        "played_cards": played_cards,
        "same_qi_changes": [same_qi_change],
        "actions_available": battle_flow.available_action_count(player),
    }

func _prepare_cooperation(proposal, cooperation_card_ids: Array) -> Dictionary:
    if cooperation_card_ids.is_empty():
        return {"success": true}
    var cooperation: Dictionary = proposal.preview.get("cooperation", {})
    if cooperation.is_empty():
        return {"success": false, "reason": "当前功法不能建立协同"}
    if not proposal.preview.get("condition", {}).get("ok", false):
        return {"success": false, "reason": "当前功法条件不满足，不能建立协同"}
    if not proposal.preview.get("technique_activation", {}).get("allowed", false):
        return {"success": false, "reason": "当前功法启动被拒绝，不能建立协同"}
    if cooperation_card_ids.size() < 1 or cooperation_card_ids.size() > 5:
        return {"success": false, "reason": "协同组必须选择1～5张真气"}
    if cooperation.has("exact_card_count") \
            and cooperation_card_ids.size() != int(cooperation["exact_card_count"]):
        return {"success": false, "reason": "协同组必须精确选择%d张真气" % int(cooperation["exact_card_count"])}
    for card_id in cooperation_card_ids:
        if proposal.card_ids.has(str(card_id)):
            return {"success": false, "reason": "同一张真气不能被主组和协同组重复使用"}

    var preview_book = SequenceBookScript.new()
    preview_book.sequences = sequence_book.sequences.duplicate(true)
    preview_book.positions = sequence_book.positions.duplicate(true)
    preview_book.advance(str(proposal.preview["hand"]["id"]))
    var cooperation_preview: Dictionary = preview_for_side.call(
        player, cooperation_card_ids, preview_book)
    if not cooperation_preview.get("valid", false):
        return {"success": false, "reason": cooperation_preview.get("reason", "协同组无效")}
    if str(cooperation_preview["hand"]["id"]) != str(cooperation["hand_id"]):
        return {
            "success": false,
            "reason": "协同组必须组成%s" % str(cooperation["hand_id"]),
        }
    if not _cooperation_cards_match(
            cooperation_preview.get("cards", []), cooperation,
            proposal.preview.get("cards", [])):
        return {"success": false, "reason": "协同牌不满足功法声明的异状限制"}

    var permission_result := _query_cooperation_permission(
        proposal.preview, cooperation_preview, "preview")
    proposal.preview["cooperation_permission"] = permission_result.duplicate(true)
    if not permission_result.get("errors", []).is_empty():
        return {"success": false, "reason": permission_result.get(
            "reason", "协同权限查询失败")}
    if not permission_result.get("allowed", false):
        return {"success": false, "reason": permission_result.get(
            "reason", "当前不能建立协同")}

    var main_individual_power := int(
        proposal.preview["values"]["technique_value"])
    var cooperation_individual_power := int(
        cooperation_preview["values"]["technique_value"])
    var shared_power: int = int(floor(
        main_individual_power + cooperation_individual_power * 0.5))
    proposal.preview["values"]["technique_value"] = shared_power
    cooperation_preview["values"]["technique_value"] = shared_power
    proposal.groups.append({
        "group_index": 1,
        "kind": "cooperation",
        "card_ids": cooperation_card_ids.duplicate(),
        "preview": cooperation_preview,
        "cooperation": cooperation.duplicate(true),
        "cooperation_permission": permission_result.duplicate(true),
        "shared_power": shared_power,
        "main_individual_power": main_individual_power,
        "cooperation_individual_power": cooperation_individual_power,
    })
    var same_qi_gain_result := _refresh_same_qi_gain(proposal, false)
    if not same_qi_gain_result.get("success", false):
        proposal.groups.pop_back()
        proposal.preview["values"]["technique_value"] = main_individual_power
        return same_qi_gain_result
    return {"success": true, "shared_power": shared_power}

func _confirm_synchronized_play(player_proposal) -> Dictionary:
    if not battle_flow.can_act(player):
        return {"success": false, "reason": action_unavailable_reason.call(player)}
    var player_preview: Dictionary = player_proposal.preview
    var enemy_preview: Dictionary = {}
    var enemy_card_ids: Array = locked_enemy_cards_reader.call()
    var enemy_will_act: bool = battle_flow.can_act(enemy) and not enemy_card_ids.is_empty()
    if enemy_will_act:
        enemy_preview = preview_for_side.call(enemy, enemy_card_ids, enemy_sequence_book)
        if not enemy_preview.get("valid", false):
            var preview_error := "对手锁定出牌失效：%s" % enemy_preview.get("reason", "未知错误")
            set_scenario_error.call(preview_error)
            return {"success": false, "reason": preview_error}
    var player_staged_ids: Array = player_proposal.card_ids.duplicate()
    for group in player_proposal.groups.slice(1):
        player_staged_ids.append_array(group.get("card_ids", []))
    if not player.stage_cards(player_staged_ids):
        return {"success": false, "reason": "我方真气无法进入待出区"}
    if enemy_will_act and not enemy.stage_cards(enemy_card_ids):
        player.rollback_staging()
        battle_flow.clear_intents()
        var staging_error := "对手锁定真气无法进入待出区"
        set_scenario_error.call(staging_error)
        return {"success": false, "reason": staging_error}

    var player_finalize := _finalize_staged_proposal(
        player, player_proposal, false)
    if not player_finalize.get("success", false):
        _rollback_power_formation_transactions(player, player_proposal)
        player.rollback_staging()
        if enemy_will_act:
            enemy.rollback_staging()
        return player_finalize
    if enemy_will_act:
        var enemy_finalize: Dictionary = action_resolver.finalize_action_preview(
            enemy, enemy_preview, player, turn_number_reader.call())
        if not enemy_finalize.get("success", false):
            _rollback_power_formation_transactions(player, player_proposal)
            player.rollback_staging()
            enemy.rollback_staging()
            return enemy_finalize
    var player_confirmed := _confirm_finalized_proposal(player, player_proposal)
    if not player_confirmed.get("success", false):
        _rollback_power_formation_transactions(player, player_proposal)
        player.rollback_staging()
        if enemy_will_act:
            enemy.rollback_staging()
        return player_confirmed
    if enemy_will_act:
        var enemy_confirmed: Dictionary = action_resolver.confirm_finalized_action(
            enemy, enemy_preview, player, turn_number_reader.call())
        if not enemy_confirmed.get("success", false):
            _rollback_power_formation_transactions(player, player_proposal)
            player.rollback_staging()
            enemy.rollback_staging()
            return enemy_confirmed

    battle_flow.lock_intent(player, player_preview)
    if enemy_will_act:
        battle_flow.lock_intent(enemy, enemy_preview)
    var resolution_mode: String = battle_flow.resolution_mode()
    battle_flow.consume_action(player)
    _freeze_consumed_action_source(player, player_preview)
    _notify_action_started(player, player_preview)
    if enemy_will_act:
        battle_flow.consume_action(enemy)
        _freeze_consumed_action_source(enemy, enemy_preview)
        _notify_action_started(enemy, enemy_preview)
    last_preview = player_preview
    last_enemy_preview = enemy_preview
    trigger_queue.add_history(
        "reveal",
        "双方揭示出牌" if resolution_mode == "synchronized" else "%s单方出招" % player.name,
        "同步规则" if resolution_mode == "synchronized" else "行动调度",
        "成功",
        _reveal_detail(player_preview, enemy_preview))
    action_resolver.log_calculation(player, player_preview)
    var player_record = action_resolver.make_action_record(
        player, enemy, player_preview, sequence_book, 100, turn_number_reader.call())
    player_record.cooperation_groups = player_proposal.groups.slice(1).duplicate(true)
    var records: Array = [player_record]
    if enemy_will_act:
        action_resolver.log_calculation(enemy, enemy_preview, enemy_ai_enabled)
        records.append(action_resolver.make_action_record(
            enemy, player, enemy_preview, enemy_sequence_book, 200, turn_number_reader.call()))
    action_resolver.begin_action_resolution([player, enemy], {
        "kind": "synchronized" if enemy_will_act else "solo_player",
        "round_number": int(turn_number_reader.call()),
        "action_tokens": records.map(func(record): return str(record["token"])),
        "acting_owner_ids": records.map(
            func(record): return str(record["actor"].owner_id)),
    })
    var resolution: Dictionary = action_resolver.resolve_action_records(
        records, resolution_mode == "synchronized")
    if resolution.get("pending_choice", false):
        pending_action_resolution.configure_synchronized(
            records,
            player_preview,
            enemy_preview,
            enemy_will_act)
        emit_state_changed.call()
        return {
            "success": true,
            "pending_choice": true,
            "choice_request": action_resolver.pending_choice_snapshot(),
            "preview": player_preview,
            "enemy_preview": enemy_preview,
            "detail": resolution.get("detail", "等待选择"),
        }
    if not resolution.get("success", false):
        action_resolver.abort_action_resolution()
        return {"success": false, "reason": resolution.get("detail", "功法结算失败")}
    return _finish_synchronized_resolution(
        records, player_preview, enemy_preview, enemy_will_act)

func _finish_synchronized_resolution(
        records: Array,
        player_preview: Dictionary,
        enemy_preview: Dictionary,
        enemy_will_act: bool) -> Dictionary:
    var player_record = records[0]
    var has_cooperation: bool = (
        player_record["triggered"]
        and not player_record.cooperation_groups.is_empty())
    _notify_action_pre_commit(player_record)
    if enemy_will_act and records.size() > 1:
        _notify_action_pre_commit(records[1])
    var player_commit: Dictionary = action_resolver.commit_staging_for(
        player, player_preview.get("cards", []) if has_cooperation else [])
    var enemy_commit: Dictionary = action_resolver.commit_staging_for(enemy) \
        if enemy_will_act else {"committed": []}
    var player_cards: Array = player_commit["committed"]
    var enemy_cards: Array = enemy_commit["committed"]
    action_resolver.log_cards_leave(player, player_cards)
    if enemy_will_act:
        action_resolver.log_cards_leave(enemy, enemy_cards)
    var post_commit: Dictionary = action_resolver.resolve_post_commit_phase()
    if post_commit.get("pending_choice", false):
        pending_action_resolution.configure_synchronized(
            records, player_preview, enemy_preview, enemy_will_act)
        pending_action_resolution.kind = "synchronized_post_commit"
        pending_action_resolution.metadata = {
            "player_cards": player_cards,
            "enemy_cards": enemy_cards,
        }
        emit_state_changed.call()
        return {
            "success": true,
            "pending_choice": true,
            "choice_request": action_resolver.pending_choice_snapshot(),
            "preview": player_preview,
            "enemy_preview": enemy_preview,
            "detail": post_commit.get("detail", "等待同步提交后选择"),
        }
    if not post_commit.get("success", false):
        action_resolver.abort_action_resolution()
        return {"success": false, "reason": post_commit.get("detail", "同步提交后效果失败")}
    return _finish_synchronized_post_commit_values(
        records, player_preview, enemy_preview, enemy_will_act,
        player_cards, enemy_cards)

func _finish_synchronized_post_commit(pending) -> Dictionary:
    return _finish_synchronized_post_commit_values(
        pending.records, pending.player_preview, pending.enemy_preview,
        pending.enemy_will_act, pending.metadata.get("player_cards", []),
        pending.metadata.get("enemy_cards", []))

func _finish_synchronized_post_commit_values(
        records: Array,
        player_preview: Dictionary,
        enemy_preview: Dictionary,
        enemy_will_act: bool,
        player_cards: Array,
        enemy_cards: Array) -> Dictionary:
    var player_record = records[0]
    var has_cooperation: bool = (
        player_record["triggered"]
        and not player_record.cooperation_groups.is_empty())
    for record in records:
        action_resolver.finish_action_record(record)
    if has_cooperation:
        return _resolve_synchronized_player_cooperation(
            player_record.cooperation_groups[0],
            player_preview,
            enemy_preview,
            enemy_will_act,
            player_cards,
            enemy_cards,
            player_record["triggered"],
            records[1]["triggered"] if records.size() > 1 else false)
    return _finish_synchronized_outcome(
        player_preview,
        enemy_preview,
        enemy_will_act,
        player_cards,
        enemy_cards,
        player_record["triggered"],
        records[1]["triggered"] if records.size() > 1 else false)

func _resolve_synchronized_player_cooperation(
        group: Dictionary,
        player_preview: Dictionary,
        enemy_preview: Dictionary,
        enemy_will_act: bool,
        player_cards: Array,
        enemy_cards: Array,
        player_triggered: bool,
        enemy_triggered: bool) -> Dictionary:
    action_resolver.effect_ports.close_current_source_binding_window()
    var cooperation_preview: Dictionary = group["preview"]
    var cooperation_record = action_resolver.make_action_record(
        player, enemy, cooperation_preview, sequence_book, 101, turn_number_reader.call())
    var resolution: Dictionary = action_resolver.resolve_action_records(
        [cooperation_record], false)
    var metadata := {
        "player_preview": player_preview,
        "enemy_preview": enemy_preview,
        "enemy_will_act": enemy_will_act,
        "player_cards": player_cards,
        "enemy_cards": enemy_cards,
        "player_triggered": player_triggered,
        "enemy_triggered": enemy_triggered,
        "cooperation": group.get("cooperation", {}),
    }
    if resolution.get("pending_choice", false):
        pending_action_resolution.configure_single(
            "synchronized_cooperation",
            cooperation_record,
            cooperation_preview,
            metadata)
        emit_state_changed.call()
        return {
            "success": true,
            "pending_choice": true,
            "choice_request": action_resolver.pending_choice_snapshot(),
            "preview": player_preview,
            "enemy_preview": enemy_preview,
            "cooperation_preview": cooperation_preview,
            "detail": resolution.get("detail", "等待协同功法选择"),
        }
    if not resolution.get("success", false):
        action_resolver.abort_action_resolution()
        return {"success": false, "reason": resolution.get("detail", "协同组结算失败")}
    return _finish_synchronized_cooperation_resolution(
        cooperation_record, cooperation_preview, metadata)

func _finish_synchronized_cooperation_resolution(
        record,
        cooperation_preview: Dictionary,
        metadata: Dictionary) -> Dictionary:
    _notify_cooperation_pre_commit(record)
    var cooperation_commit: Dictionary = action_resolver.commit_cooperation_staging(
        record, metadata.get("cooperation", {}))
    var cooperation_cards: Array = cooperation_commit.get("committed", [])
    action_resolver.log_cards_leave(
        player, cooperation_cards)
    var post_commit: Dictionary = action_resolver.resolve_post_commit_phase()
    if post_commit.get("pending_choice", false):
        metadata["cooperation_cards"] = cooperation_cards
        pending_action_resolution.configure_single(
            "synchronized_cooperation_post_commit", record,
            cooperation_preview, metadata)
        emit_state_changed.call()
        return {
            "success": true,
            "pending_choice": true,
            "choice_request": action_resolver.pending_choice_snapshot(),
            "preview": metadata.get("player_preview", {}),
            "enemy_preview": metadata.get("enemy_preview", {}),
            "cooperation_preview": cooperation_preview,
            "detail": post_commit.get("detail", "等待协同提交后选择"),
        }
    if not post_commit.get("success", false):
        action_resolver.abort_action_resolution()
        return {"success": false, "reason": post_commit.get("detail", "协同提交后效果失败")}
    metadata["cooperation_cards"] = cooperation_cards
    return _finish_synchronized_cooperation_post_commit(
        record, cooperation_preview, metadata)

func _finish_synchronized_cooperation_post_commit(
        record, cooperation_preview: Dictionary, metadata: Dictionary) -> Dictionary:
    var all_player_cards: Array = metadata.get("player_cards", []).duplicate()
    all_player_cards.append_array(metadata.get("cooperation_cards", []))
    action_resolver.finish_action_record(record)
    return _finish_synchronized_outcome(
        metadata.get("player_preview", {}),
        metadata.get("enemy_preview", {}),
        bool(metadata.get("enemy_will_act", false)),
        all_player_cards,
        metadata.get("enemy_cards", []),
        bool(metadata.get("player_triggered", false)),
        bool(metadata.get("enemy_triggered", false)),
        record["triggered"],
        cooperation_preview)

func _notify_cooperation_pre_commit(record) -> void:
    _notify_action_pre_commit(record)
    var cards: Array = record["preview"].get("cards", []).duplicate()
    action_resolver.effect_ports.notify_response_event("cooperation_pre_commit", {
        "actor": record["actor"],
        "holder": record["actor"],
        "action_token": str(record["token"]),
        "round_number": int(turn_number_reader.call()),
        "event_cards": cards,
        "source_card_instance_id": str(cards[0].id) if not cards.is_empty() else "",
        "source_card_instance_ids": cards.map(func(card): return str(card.id)),
    })

func _notify_action_pre_commit(record) -> void:
    var cards: Array = record["preview"].get("cards", []).duplicate()
    action_resolver.effect_ports.notify_response_event("action_pre_commit", {
        "actor": record["actor"], "holder": record["actor"],
        "target": record["target"], "action_token": str(record["token"]),
        "round_number": int(turn_number_reader.call()),
        "event_cards": cards,
        "source_card_instance_id": str(cards[0].id) if not cards.is_empty() else "",
        "source_card_instance_ids": cards.map(func(card): return str(card.id)),
    })

func _freeze_consumed_action_source(side, preview: Dictionary) -> void:
    var source: Dictionary = battle_flow.last_consumed_action_source(side)
    preview["action_source"] = source.duplicate(true)
    var snapshot: Dictionary = preview.get("group_snapshot", {}).duplicate(true)
    snapshot["action_source"] = source.duplicate(true)
    snapshot["action_is_extra"] = bool(source.get("is_extra_action", false))
    snapshot["action_from_same_qi"] = bool(source.get("from_same_qi", false))
    preview["group_snapshot"] = snapshot

func _notify_action_started(side, preview: Dictionary) -> void:
    var source: Dictionary = preview.get("action_source", {}).duplicate(true)
    action_resolver.effect_ports.notify_response_event("extra_action_started", {
        "actor": side, "holder": side,
        "action_token": str(preview.get("reshape_action_token", "")),
        "round_number": int(turn_number_reader.call()),
        "action_source": source,
        "is_extra_action": bool(source.get("is_extra_action", false)),
        "from_same_qi": bool(source.get("from_same_qi", false)),
        "source_category": str(source.get("category", "")),
    })

func _notify_cooperation_resolved(
        main_preview: Dictionary,
        cooperation_preview: Dictionary) -> void:
    action_resolver.effect_ports.notify_response_event("cooperation_resolved", {
        "actor": player, "holder": player, "target": enemy,
        "action_token": str(main_preview.get("reshape_action_token", "")),
        "round_number": int(turn_number_reader.call()),
        "main_technique_id": str(main_preview.get("technique_id", "")),
        "cooperation_technique_id": str(cooperation_preview.get(
            "technique_id", "")),
        "main_triggered": true,
        "cooperation_triggered": true,
    })

func _finish_synchronized_outcome(
        player_preview: Dictionary,
        enemy_preview: Dictionary,
        enemy_will_act: bool,
        player_cards: Array,
        enemy_cards: Array,
        player_triggered: bool,
        enemy_triggered: bool,
        cooperation_triggered: bool = false,
        cooperation_preview: Dictionary = {}) -> Dictionary:
    if player_triggered and cooperation_triggered:
        _notify_cooperation_resolved(player_preview, cooperation_preview)
    var action_completed: Dictionary = action_resolver.finish_action_resolution()
    if not action_completed.get("success", false):
        return {"success": false, "reason": action_completed.get(
            "reason", "行动完成时点结算失败")}
    last_player_action_cards = player_cards
    last_enemy_action_cards = enemy_cards
    last_played_hand = player_preview["hand"]["id"]
    var same_qi_changes: Array = []
    var player_same_qi := _apply_same_qi_gain(
        player, player_preview, player_cards)
    if not player_same_qi.get("success", false):
        return player_same_qi
    same_qi_changes.append(player_same_qi)
    if enemy_will_act:
        enemy_action_index_writer.call(enemy_action_index_reader.call() + 1)
        var enemy_same_qi := _apply_same_qi_gain(
            enemy, enemy_preview, enemy_cards)
        if not enemy_same_qi.get("success", false):
            return enemy_same_qi
        same_qi_changes.append(enemy_same_qi)
    battle_flow.clear_intents()
    update_battle_state.call()
    if battle_state_reader.call() == "active" and battle_flow.can_act(enemy):
        if external_enemy_action_mode:
            clear_enemy_action_lock.call()
        else:
            lock_enemy_action.call()
    else:
        clear_enemy_action_lock.call()
    if battle_state_reader.call() == "active" \
            and not battle_flow.can_act(player) \
            and battle_flow.can_act(enemy) \
            and not external_enemy_action_mode:
        resolve_enemy_only_actions.call()
    emit_state_changed.call()
    return {
        "success": true,
        "preview": player_preview,
        "enemy_preview": enemy_preview,
        "cooperation_preview": cooperation_preview,
        "technique_triggered": player_triggered,
        "cooperation_technique_triggered": cooperation_triggered,
        "enemy_technique_triggered": enemy_triggered,
        "played_cards": player_cards,
        "enemy_played_cards": enemy_cards,
        "same_qi_changes": same_qi_changes,
        "actions_available": battle_flow.available_action_count(player),
        "enemy_actions_available": battle_flow.available_action_count(enemy),
        "battle_state": battle_state_reader.call(),
    }

func _finish_enemy_only_resolution(record, action_preview: Dictionary) -> Dictionary:
    _notify_action_pre_commit(record)
    var enemy_commit: Dictionary = action_resolver.commit_staging_for(enemy)
    var enemy_cards: Array = enemy_commit["committed"]
    action_resolver.log_cards_leave(enemy, enemy_cards)
    var post_commit: Dictionary = action_resolver.resolve_post_commit_phase()
    if post_commit.get("pending_choice", false):
        pending_action_resolution.configure_single(
            "enemy_only_post_commit", record, action_preview,
            {"enemy_cards": enemy_cards})
        emit_state_changed.call()
        return {
            "success": true,
            "pending_choice": true,
            "choice_request": action_resolver.pending_choice_snapshot(),
            "enemy_preview": action_preview,
            "detail": post_commit.get("detail", "等待提交后选择"),
        }
    if not post_commit.get("success", false):
        action_resolver.abort_action_resolution()
        return {"success": false, "reason": post_commit.get("detail", "敌方提交后效果失败")}
    return _finish_enemy_only_post_commit(record, action_preview, enemy_cards)

func _finish_enemy_only_post_commit(
        record, action_preview: Dictionary, enemy_cards: Array) -> Dictionary:
    action_resolver.finish_action_record(record)
    var action_completed: Dictionary = action_resolver.finish_action_resolution()
    if not action_completed.get("success", false):
        return {"success": false, "reason": action_completed.get(
            "reason", "行动完成时点结算失败")}
    last_player_action_cards.clear()
    last_enemy_action_cards = enemy_cards
    enemy_action_index_writer.call(enemy_action_index_reader.call() + 1)
    var same_qi_change := _apply_same_qi_gain(
        enemy, action_preview, enemy_cards)
    if not same_qi_change.get("success", false):
        return same_qi_change
    battle_flow.clear_intents()
    update_battle_state.call()
    clear_enemy_action_lock.call()
    return {
        "success": true,
        "enemy_preview": action_preview,
        "enemy_played_cards": enemy_cards,
        "same_qi_changes": [same_qi_change],
        "enemy_technique_triggered": record["triggered"],
        "enemy_actions_available": battle_flow.available_action_count(enemy),
        "battle_state": battle_state_reader.call(),
    }

func _apply_same_qi_gain(
        side,
        action_preview: Dictionary,
        actually_played_cards: Array) -> Dictionary:
    var frozen_action: Dictionary = action_preview.get("same_qi", {})
    if not bool(frozen_action.get("frozen", false)):
        return {"success": false, "reason": "行动缺少冻结同气收益"}
    var actual_ids: Array[String] = []
    for card in actually_played_cards:
        actual_ids.append(str(card.id))
    for card_id in frozen_action.get("card_ids", []):
        if not actual_ids.has(str(card_id)):
            return {"success": false, "reason": "冻结同气牌未全部成功打出"}
    if frozen_action.get("card_ids", []).is_empty():
        return {"success": false, "reason": "行动没有成功打出的普通真气"}
    var token := "%s:same_qi" % str(
        action_preview.get("reshape_action_token", ""))
    return action_resolver.settle_same_qi_gain(
        side, int(frozen_action.get("gain", 0)), "同气槽", token)

func _refresh_same_qi_gain(proposal, frozen: bool) -> Dictionary:
    var cards: Array = proposal.preview.get("cards", []).duplicate()
    for group in proposal.groups.slice(1):
        for card in group.get("preview", {}).get("cards", []):
            if not cards.has(card):
                cards.append(card)
    var action_result: Dictionary = SameQiRuleScript.analyze(
        cards, player.card_identity_policy, {
            "owner": player, "actor": player, "target": enemy,
            "action_token": str(proposal.preview.get(
                "reshape_action_token", "")),
        })
    if not action_result.get("success", false):
        return {
            "success": false,
            "reason": str(action_result.get("reason", "同气行动分组失败")),
        }
    action_result["frozen"] = frozen
    action_result["action_token"] = str(
        proposal.preview.get("reshape_action_token", ""))
    var excluded_ids: Array[String] = []
    for card in cards:
        excluded_ids.append(str(card.id))
    var legal_after := false
    for card in player.hand:
        if excluded_ids.has(str(card.id)):
            continue
        if player.status_system == null or bool(
                player.status_system.can_play_card(player, card).get(
                    "allowed", false)):
            legal_after = true
            break
    var projection: Dictionary = action_resolver.effect_ports.same_qi_projection(
        player, int(action_result.get("gain", 0)), {
            "target": enemy,
            "round_number": int(turn_number_reader.call()),
            "action_token": action_result["action_token"],
            "source_kind": "action_confirmed" if frozen else "preview",
            "legal_card_available": legal_after,
        })
    if not projection.get("success", false):
        return projection
    var technique_combo := bool(
        proposal.preview.get("intent", {}).get("technique_combo", false))
    for group in proposal.groups.slice(1):
        technique_combo = (
            technique_combo
            or bool(group.get("preview", {}).get(
                "intent", {}).get("technique_combo", false)))
    proposal.preview["same_qi"] = action_result.duplicate(true)
    var main_snapshot: Dictionary = proposal.preview.get(
        "group_snapshot", {}).duplicate(true)
    main_snapshot["action_same_qi_gain"] = int(
        action_result.get("gain", 0))
    main_snapshot["action_same_qi_trigger_count"] = int(
        projection.get("same_qi_trigger_count", 0))
    main_snapshot["action_same_qi_common_attributes"] = action_result.get(
        "common_attributes", []).duplicate()
    proposal.preview["group_snapshot"] = main_snapshot
    for field in [
            "same_qi_gain", "same_qi_before", "same_qi_capacity",
            "same_qi_after", "same_qi_trigger_count"]:
        proposal.preview[field] = int(projection.get(field, 0))
    for group in proposal.groups.slice(1):
        var group_preview: Dictionary = group.get("preview", {})
        var group_snapshot: Dictionary = group_preview.get(
            "group_snapshot", {}).duplicate(true)
        group_snapshot["action_same_qi_gain"] = int(
            action_result.get("gain", 0))
        group_snapshot["action_same_qi_trigger_count"] = int(
            projection.get("same_qi_trigger_count", 0))
        group_snapshot["action_same_qi_common_attributes"] = action_result.get(
            "common_attributes", []).duplicate()
        group_preview["group_snapshot"] = group_snapshot
    proposal.preview["intent"]["combo"] = (
        int(projection.get("same_qi_trigger_count", 0)) > 0
        or technique_combo)
    proposal.preview["intent"]["same_qi_gain"] = int(
        projection.get("same_qi_gain", 0))
    proposal.preview["intent"]["same_qi_trigger_count"] = int(
        projection.get("same_qi_trigger_count", 0))
    return {"success": true, "same_qi": action_result}

func _finalize_staged_proposal(
        side, proposal, emit_confirmed: bool = true) -> Dictionary:
    _restore_individual_cooperation_power(proposal)
    var main_result: Dictionary = action_resolver.finalize_action_preview(
        side, proposal.preview,
        enemy if side == player else player, turn_number_reader.call())
    if not main_result.get("success", false):
        return main_result
    for group in proposal.groups.slice(1):
        var group_preview: Dictionary = group.get("preview", {})
        var group_result: Dictionary = action_resolver.finalize_action_preview(
            side, group_preview,
            enemy if side == player else player, turn_number_reader.call())
        if not group_result.get("success", false):
            return group_result
    if proposal.groups.size() > 1:
        if not proposal.preview.get("technique_activation", {}).get(
                "allowed", false):
            return {
                "success": false,
                "reason": "正式确认时主功法启动被拒绝，协同行动整体失效",
            }
        var cooperation_preview: Dictionary = proposal.groups[1].get("preview", {})
        var cooperation_definition: Dictionary = proposal.groups[1].get("cooperation", {})
        if cooperation_definition.has("exact_card_count") \
                and cooperation_preview.get("cards", []).size() != int(cooperation_definition["exact_card_count"]):
            return {"success": false, "reason": "正式确认时协同牌数量不符"}
        if not _cooperation_cards_match(
                cooperation_preview.get("cards", []), cooperation_definition,
                proposal.preview.get("cards", [])):
            return {"success": false, "reason": "正式确认时协同牌异状限制不符"}
        var cooperation_permission := _query_cooperation_permission(
            proposal.preview, cooperation_preview, "action_confirmed")
        cooperation_permission["frozen"] = true
        cooperation_permission["main_action_token"] = str(
            proposal.preview.get("reshape_action_token", ""))
        proposal.preview["cooperation_permission"] = cooperation_permission.duplicate(true)
        proposal.groups[1]["cooperation_permission"] = cooperation_permission.duplicate(true)
        if not cooperation_permission.get("errors", []).is_empty():
            return {"success": false, "reason": cooperation_permission.get(
                "reason", "协同权限查询失败")}
        if not cooperation_permission.get("allowed", false):
            return {"success": false, "reason": cooperation_permission.get(
                "reason", "正式确认时协同被拒绝")}
    var same_qi_freeze := _refresh_same_qi_gain(proposal, true)
    if not same_qi_freeze.get("success", false):
        return same_qi_freeze
    var formation_commit := _commit_power_formation_transactions(side, proposal)
    if not formation_commit.get("success", false):
        _rollback_power_formation_transactions(side, proposal)
        return formation_commit
    _refresh_cooperation_shared_power(proposal)
    if emit_confirmed:
        return _confirm_finalized_proposal(side, proposal)
    return {"success": true}

func _confirm_finalized_proposal(side, proposal) -> Dictionary:
    var target = enemy if side == player else player
    var main_result: Dictionary = action_resolver.confirm_finalized_action(
        side, proposal.preview, target, turn_number_reader.call())
    if not main_result.get("success", false):
        _rollback_power_formation_transactions(side, proposal)
        return main_result
    for group in proposal.groups.slice(1):
        var group_result: Dictionary = action_resolver.confirm_finalized_action(
            side, group.get("preview", {}), target, turn_number_reader.call())
        if not group_result.get("success", false):
            _rollback_power_formation_transactions(side, proposal)
            return group_result
    return {"success": true}

func _commit_power_formation_transactions(side, proposal) -> Dictionary:
    var previews: Array = [proposal.preview]
    for group in proposal.groups.slice(1):
        previews.append(group.get("preview", {}))
    var receipts: Array = []
    for preview_value in previews:
        var committed: Dictionary = action_resolver.action_preview_service.commit_power_formation(
            side, preview_value)
        if not committed.get("success", false):
            return committed
        if committed.get("changed", false):
            receipts.append(committed.get("receipt", {}).duplicate(true))
    proposal.preview["momentum_consume_receipts"] = receipts
    return {"success": true, "receipts": receipts}

func _rollback_power_formation_transactions(side, proposal) -> void:
    for group in proposal.groups.slice(1).duplicate():
        action_resolver.action_preview_service.rollback_power_formation(
            side, group.get("preview", {}))
    action_resolver.action_preview_service.rollback_power_formation(
        side, proposal.preview)

func _query_cooperation_permission(
        main_preview: Dictionary,
        cooperation_preview: Dictionary,
        source_kind: String) -> Dictionary:
    var permission = player.battle_permission_service
    if permission == null:
        return {
            "checked": true, "allowed": true, "reason": "",
            "source_breakdown": [], "errors": [],
        }
    var main_cards: Array = main_preview.get("cards", [])
    var cooperation_cards: Array = cooperation_preview.get("cards", [])
    var result: Dictionary = permission.can_establish_cooperation(
        player,
        str(main_preview.get("technique_id", "")),
        str(main_preview.get("hand", {}).get("id", "")),
        str(cooperation_preview.get("technique_id", "")),
        str(cooperation_preview.get("hand", {}).get("id", "")), {
            "target": enemy,
            "round_number": int(turn_number_reader.call()),
            "main_action_token": str(main_preview.get("reshape_action_token", "")),
            "main_card_instance_ids": main_cards.map(func(card): return str(card.id)),
            "cooperation_card_instance_ids": cooperation_cards.map(
                func(card): return str(card.id)),
            "main_preview": main_preview,
            "cooperation_preview": cooperation_preview,
            "source_kind": source_kind,
        })
    result["checked"] = true
    return result

func _cooperation_cards_match(
        cards: Array,
        cooperation: Dictionary,
        main_cards: Array = []) -> bool:
    var any_anomalies: Array = cooperation.get("card_has_any_anomaly", [])
    if not any_anomalies.is_empty():
        for card in cards:
            var matched := false
            for anomaly_value in any_anomalies:
                var anomaly: Dictionary = anomaly_value
                if card.has_anomaly(str(anomaly.get("category", "")), str(anomaly.get("id", ""))):
                    matched = true
                    break
            if not matched:
                return false
    if bool(cooperation.get("shares_attribute_with_main", false)):
        var shared := false
        for card in cards:
            for main_card in main_cards:
                for attribute in ["wind", "forest", "fire", "mountain"]:
                    if card.is_attribute(attribute) and main_card.is_attribute(attribute):
                        shared = true
                        break
                if shared:
                    break
            if shared:
                break
        if not shared:
            return false
    return true

func _refresh_cooperation_shared_power(proposal) -> void:
    if proposal.groups.size() < 2:
        return
    var cooperation_group: Dictionary = proposal.groups[1]
    var cooperation_preview: Dictionary = cooperation_group.get("preview", {})
    var shared_power: int = int(floor(
        int(proposal.preview.get("values", {}).get("technique_value", 0))
        + int(cooperation_preview.get("values", {}).get("technique_value", 0)) * 0.5))
    proposal.preview["values"]["technique_value"] = shared_power
    cooperation_preview["values"]["technique_value"] = shared_power
    cooperation_group["shared_power"] = shared_power

func _restore_individual_cooperation_power(proposal) -> void:
    if proposal.groups.size() < 2:
        return
    var cooperation_group: Dictionary = proposal.groups[1]
    proposal.preview["values"]["technique_value"] = int(
        cooperation_group.get(
            "main_individual_power",
            proposal.preview["values"].get("technique_value", 0)))
    var cooperation_preview: Dictionary = cooperation_group.get("preview", {})
    cooperation_preview["values"]["technique_value"] = int(
        cooperation_group.get(
            "cooperation_individual_power",
            cooperation_preview.get("values", {}).get("technique_value", 0)))

func _reveal_detail(player_preview: Dictionary, enemy_preview: Dictionary) -> String:
    var player_name: String = player_preview["hand"]["name"]
    if enemy_preview.is_empty():
        return "我方 %s｜对手本击不出牌" % player_name
    if enemy_ai_enabled:
        return "我方 %s｜对手按公开计划出招" % player_name
    return "我方 %s｜对手 %s" % [player_name, enemy_preview["hand"]["name"]]
