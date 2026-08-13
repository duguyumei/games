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
        "solo_cooperation":
            return _finish_solo_cooperation_resolution(
                pending.record, pending.action_preview, pending.metadata)
        "synchronized_cooperation":
            return _finish_synchronized_cooperation_resolution(
                pending.record, pending.action_preview, pending.metadata)
        "synchronized":
            return _finish_synchronized_resolution(
                pending.records,
                pending.player_preview,
                pending.enemy_preview,
                pending.enemy_will_act)
        "enemy_only":
            return _finish_enemy_only_resolution(pending.record, pending.action_preview)
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
    action_resolver.log_calculation(player, action_preview)
    var record = action_resolver.make_action_record(
        player, enemy, action_preview, sequence_book, 100, turn_number_reader.call())
    record.cooperation_groups = proposal.groups.slice(1).duplicate(true)
    action_resolver.begin_action_resolution([player, enemy], {
        "kind": "solo_player",
        "round_number": int(turn_number_reader.call()),
        "action_tokens": [str(record["token"])],
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
    var player_commit: Dictionary = action_resolver.commit_staging_for(
        player, action_preview.get("cards", []) if has_cooperation else [])
    var played_cards: Array = player_commit["committed"]
    action_resolver.log_cards_leave(player, played_cards)
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
    var cooperation_commit: Dictionary = action_resolver.commit_cooperation_staging(
        record, metadata.get("cooperation", {}))
    var cooperation_cards: Array = cooperation_commit["committed"]
    action_resolver.log_cards_leave(player, cooperation_cards)
    action_resolver.finish_action_record(record)
    var all_cards: Array = metadata.get("main_cards", []).duplicate()
    all_cards.append_array(cooperation_cards)
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
    var action_completed: Dictionary = action_resolver.finish_action_resolution()
    if not action_completed.get("success", false):
        return {"success": false, "reason": action_completed.get(
            "reason", "行动完成时点结算失败")}
    last_player_action_cards = played_cards
    last_enemy_action_cards.clear()
    last_played_hand = action_preview["hand"]["id"]
    _apply_same_qi_link(player, action_preview)
    battle_flow.clear_intents()
    emit_state_changed.call()
    return {
        "success": true,
        "preview": action_preview,
        "cooperation_preview": cooperation_preview,
        "technique_triggered": main_triggered,
        "cooperation_technique_triggered": cooperation_triggered,
        "played_cards": played_cards,
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
    var same_qi_action_result := _freeze_same_qi_action(proposal)
    if not same_qi_action_result.get("success", false):
        proposal.groups.pop_back()
        proposal.preview["values"]["technique_value"] = main_individual_power
        return same_qi_action_result
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
        player.rollback_staging()
        if enemy_will_act:
            enemy.rollback_staging()
        return player_finalize
    if enemy_will_act:
        var enemy_finalize: Dictionary = action_resolver.finalize_action_preview(
            enemy, enemy_preview, player, turn_number_reader.call())
        if not enemy_finalize.get("success", false):
            player.rollback_staging()
            enemy.rollback_staging()
            return enemy_finalize
    var player_confirmed := _confirm_finalized_proposal(player, player_proposal)
    if not player_confirmed.get("success", false):
        player.rollback_staging()
        if enemy_will_act:
            enemy.rollback_staging()
        return player_confirmed
    if enemy_will_act:
        var enemy_confirmed: Dictionary = action_resolver.confirm_finalized_action(
            enemy, enemy_preview, player, turn_number_reader.call())
        if not enemy_confirmed.get("success", false):
            player.rollback_staging()
            enemy.rollback_staging()
            return enemy_confirmed

    battle_flow.lock_intent(player, player_preview)
    if enemy_will_act:
        battle_flow.lock_intent(enemy, enemy_preview)
    var resolution_mode: String = battle_flow.resolution_mode()
    battle_flow.consume_action(player)
    if enemy_will_act:
        battle_flow.consume_action(enemy)
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
    var player_commit: Dictionary = action_resolver.commit_staging_for(
        player, player_preview.get("cards", []) if has_cooperation else [])
    var enemy_commit: Dictionary = action_resolver.commit_staging_for(enemy) \
        if enemy_will_act else {"committed": []}
    var player_cards: Array = player_commit["committed"]
    var enemy_cards: Array = enemy_commit["committed"]
    action_resolver.log_cards_leave(player, player_cards)
    if enemy_will_act:
        action_resolver.log_cards_leave(enemy, enemy_cards)
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
    var cooperation_commit: Dictionary = action_resolver.commit_cooperation_staging(
        record, metadata.get("cooperation", {}))
    var all_player_cards: Array = metadata.get("player_cards", []).duplicate()
    all_player_cards.append_array(cooperation_commit.get("committed", []))
    action_resolver.log_cards_leave(
        player, cooperation_commit.get("committed", []))
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
    var action_completed: Dictionary = action_resolver.finish_action_resolution()
    if not action_completed.get("success", false):
        return {"success": false, "reason": action_completed.get(
            "reason", "行动完成时点结算失败")}
    last_player_action_cards = player_cards
    last_enemy_action_cards = enemy_cards
    last_played_hand = player_preview["hand"]["id"]
    _apply_same_qi_link(player, player_preview)
    if enemy_will_act:
        enemy_action_index_writer.call(enemy_action_index_reader.call() + 1)
        _apply_same_qi_link(enemy, enemy_preview)
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
        "actions_available": battle_flow.available_action_count(player),
        "enemy_actions_available": battle_flow.available_action_count(enemy),
        "battle_state": battle_state_reader.call(),
    }

func _finish_enemy_only_resolution(record, action_preview: Dictionary) -> Dictionary:
    var enemy_commit: Dictionary = action_resolver.commit_staging_for(enemy)
    var enemy_cards: Array = enemy_commit["committed"]
    action_resolver.log_cards_leave(enemy, enemy_cards)
    action_resolver.finish_action_record(record)
    var action_completed: Dictionary = action_resolver.finish_action_resolution()
    if not action_completed.get("success", false):
        return {"success": false, "reason": action_completed.get(
            "reason", "行动完成时点结算失败")}
    last_player_action_cards.clear()
    last_enemy_action_cards = enemy_cards
    enemy_action_index_writer.call(enemy_action_index_reader.call() + 1)
    _apply_same_qi_link(enemy, action_preview)
    battle_flow.clear_intents()
    update_battle_state.call()
    clear_enemy_action_lock.call()
    return {
        "success": true,
        "enemy_preview": action_preview,
        "enemy_played_cards": enemy_cards,
        "enemy_technique_triggered": record["triggered"],
        "enemy_actions_available": battle_flow.available_action_count(enemy),
        "battle_state": battle_state_reader.call(),
    }

func _grant_extra_actions(side, amount: int, source: String) -> void:
    var gained: int = battle_flow.grant_actions(side, amount)
    trigger_queue.add_history(
        "action_end",
        "%s额外出牌机会" % side.name,
        source,
        "成功",
        "+%d（连击不自动补牌）" % gained)

func _apply_same_qi_link(side, action_preview: Dictionary) -> bool:
    var frozen_action: Dictionary = action_preview.get("same_qi_action", {})
    if not bool(frozen_action.get("qualified", false)):
        return false
    if not bool(action_preview.get("intent", {}).get("same_qi_link", false)):
        return false
    if not battle_flow.claim_combo(side, "same_qi_link"):
        return false
    _grant_extra_actions(side, 1, "同气连动")
    return true

func _freeze_same_qi_action(proposal) -> Dictionary:
    var group_results: Array = [proposal.preview.get("same_qi", {})]
    for group in proposal.groups.slice(1):
        group_results.append(group.get("preview", {}).get("same_qi", {}))
    var action_result: Dictionary = SameQiRuleScript.intersect_group_attributes(
        group_results)
    if not action_result.get("success", false):
        return {
            "success": false,
            "reason": str(action_result.get("reason", "同气行动冻结失败")),
        }
    var available: bool = (
        bool(action_result.get("qualified", false))
        and not battle_flow.has_claimed_combo(player, "same_qi_link"))
    var technique_combo := bool(
        proposal.preview.get("intent", {}).get("technique_combo", false))
    for group in proposal.groups.slice(1):
        technique_combo = (
            technique_combo
            or bool(group.get("preview", {}).get(
                "intent", {}).get("technique_combo", false)))
    proposal.preview["same_qi_action"] = action_result.duplicate(true)
    proposal.preview["intent"]["same_qi_link"] = available
    proposal.preview["intent"]["combo"] = available or technique_combo
    for group in proposal.groups.slice(1):
        group["preview"]["same_qi_action"] = action_result.duplicate(true)
        group["preview"]["intent"]["same_qi_link"] = available
        group["preview"]["intent"]["combo"] = available or technique_combo
    return {"success": true, "same_qi_action": action_result}

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
    _refresh_cooperation_shared_power(proposal)
    if emit_confirmed:
        return _confirm_finalized_proposal(side, proposal)
    return {"success": true}

func _confirm_finalized_proposal(side, proposal) -> Dictionary:
    var target = enemy if side == player else player
    var main_result: Dictionary = action_resolver.confirm_finalized_action(
        side, proposal.preview, target, turn_number_reader.call())
    if not main_result.get("success", false):
        return main_result
    for group in proposal.groups.slice(1):
        var group_result: Dictionary = action_resolver.confirm_finalized_action(
            side, group.get("preview", {}), target, turn_number_reader.call())
        if not group_result.get("success", false):
            return group_result
    return {"success": true}

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
