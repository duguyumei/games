class_name BattleActionService
extends RefCounted

## 牌型组行动事务。
##
## 该服务只负责“提案 → 锁定 → 结算 → 提交牌区”的事务顺序，
## 不负责生成内容、不负责 UI，也不直接决定战斗胜负。
## 待选择功法会把事务记录保存在这里，选择完成后从原位置继续。

const ActionPreviewServiceScript = preload("res://core/action_preview_service.gd")
const ActionTransactionScript = preload("res://core/battle_action_transaction.gd")
const SequenceBookScript = preload("res://core/sequence_book.gd")
const SameQiRuleScript = preload("res://core/same_qi_rule.gd")

const ACTION_CONTEXT_KEY := "action_context"
const CURRENT_GROUP_CONTEXT_KEY := "current_group_context"
const SOLO_ROLE_PLAYER := "player"
const SOLO_ROLE_ENEMY := "enemy"
const GROUP_COMMIT_SOLO_MAIN := "solo_main"
const GROUP_COMMIT_SYNCHRONIZED_MAIN := "synchronized_main"
const GROUP_COMMIT_COOPERATION := "cooperation"

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

var active_action_transaction = ActionTransactionScript.new()
var _transaction_serial: int = 0
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
    active_action_transaction.clear_transaction(true)
    _transaction_serial = 0
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
    if active_action_transaction.is_active():
        return {"success": false, "reason": "当前已有未完成的行动事务"}
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
    return _prepare_solo_player_action(proposal)

func has_pending_choice() -> bool:
    return action_resolver.has_pending_choice()

func pending_choice_snapshot() -> Dictionary:
    return action_resolver.pending_choice_snapshot()

func pending_action_transaction_snapshot() -> Dictionary:
    return active_action_transaction.snapshot()

func resolve_effect_choice(request_id: String, selected_card_ids: Array) -> Dictionary:
    if active_action_transaction.is_empty() or not action_resolver.has_pending_choice():
        return {"success": false, "reason": "当前没有等待中的功法选择"}
    var resume_check: Dictionary = active_action_transaction.validate_resume(request_id)
    if not resume_check.get("success", false):
        return resume_check
    var resume_cursor: String = active_action_transaction.resume_cursor
    var resolution: Dictionary = action_resolver.resume_choice(request_id, selected_card_ids)
    if resolution.get("pending_choice", false):
        var current_request: Dictionary = action_resolver.pending_choice_snapshot()
        var detail := str(resolution.get("detail", "等待选择"))
        var same_request := str(current_request.get("request_id", "")) == request_id
        if not same_request:
            var resuspended: Dictionary = active_action_transaction.resume_from_choice(
                request_id, str(current_request.get("request_id", "")), resume_cursor)
            if not resuspended.get("success", false):
                return _fail_active_transaction(
                    resuspended.get("reason", "行动事务无法更新选择请求"),
                    str(resuspended.get("code", "choice_resuspend_failed")))
        return {
            "success": false if same_request else true,
            "pending_choice": true,
            "choice_request": current_request,
            "reason": detail if same_request else "",
            "detail": detail,
        }
    if not resolution.get("success", false):
        return _fail_active_transaction(
            resolution.get("detail", "功法选择恢复失败"),
            "effect_choice_resume_failed")
    var resumed: Dictionary = active_action_transaction.resume_from_choice(request_id)
    if not resumed.get("success", false):
        return _fail_active_transaction(
            resumed.get("reason", "行动事务恢复失败"),
            str(resumed.get("code", "transaction_resume_failed")))
    return _continue_active_transaction(resume_cursor)

func resolve_locked_enemy_action_once() -> Dictionary:
    if active_action_transaction.is_active():
        return {"success": false, "reason": "当前已有未完成的行动事务"}
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
    var solo_context := _make_solo_action_context(
        enemy, player, action_preview, record, enemy_sequence_book,
        SOLO_ROLE_ENEMY, [])
    return _start_solo_action_transaction(solo_context)

func _prepare_solo_player_action(proposal) -> Dictionary:
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
    var solo_context := _make_solo_action_context(
        player, enemy, action_preview, record, sequence_book,
        SOLO_ROLE_PLAYER, record.cooperation_groups)
    return _start_solo_action_transaction(solo_context)

func _make_solo_action_context(
        actor,
        target,
        action_preview: Dictionary,
        record,
        action_sequence_book,
        actor_role: String,
        cooperation_groups: Array) -> Dictionary:
    var result_fields := {
        "preview": "preview" if actor_role == SOLO_ROLE_PLAYER else "enemy_preview",
        "played_cards": "played_cards" if actor_role == SOLO_ROLE_PLAYER else "enemy_played_cards",
        "technique_triggered": "technique_triggered" if actor_role == SOLO_ROLE_PLAYER else "enemy_technique_triggered",
        "actions_available": "actions_available" if actor_role == SOLO_ROLE_PLAYER else "enemy_actions_available",
        "include_cooperation": actor_role == SOLO_ROLE_PLAYER,
        "include_battle_state": actor_role == SOLO_ROLE_ENEMY,
    }
    return {
        "resolution_mode": ActionTransactionScript.RESOLUTION_SOLO,
        "actor": actor,
        "target": target,
        "sequence_book": action_sequence_book,
        "actor_role": actor_role,
        "player_preview": action_preview if actor_role == SOLO_ROLE_PLAYER else {},
        "enemy_preview": action_preview if actor_role == SOLO_ROLE_ENEMY else {},
        "main_trigger_results": {},
        "enemy_will_act": false,
        "cooperation_groups": cooperation_groups.duplicate(true),
        "next_cooperation_index": 0,
        "main_committed_cards": {
            SOLO_ROLE_PLAYER: [],
            SOLO_ROLE_ENEMY: [],
        },
        "committed_cards": {
            SOLO_ROLE_PLAYER: [],
            SOLO_ROLE_ENEMY: [],
        },
        "cooperation_preview": {},
        "cooperation_triggered": false,
        "result_fields": result_fields,
        "main_records": [record],
    }

func _start_solo_action_transaction(action_context: Dictionary) -> Dictionary:
    var actor = action_context["actor"]
    var record = action_context["main_records"][0]
    var actor_role := str(action_context["actor_role"])
    var previews := {}
    previews[actor_role] = _solo_action_preview(action_context)
    var group_context := _make_group_context(
        ActionTransactionScript.GROUP_MAIN,
        [record], previews, actor, action_context["target"], false,
        GROUP_COMMIT_SOLO_MAIN, {}, _action_choice_previews(action_context))
    var runtime_context := _action_runtime_context(
        action_context, group_context)
    var transaction_started: Dictionary = _begin_action_transaction(
        [record], previews,
        ActionTransactionScript.RESOLUTION_SOLO, actor, false,
        action_context.get("cooperation_groups", []), runtime_context)
    if not transaction_started.get("success", false):
        action_resolver.abort_action_resolution()
        return transaction_started
    action_resolver.begin_action_resolution([player, enemy], {
        "resolution_mode": ActionTransactionScript.RESOLUTION_SOLO,
        "round_number": int(turn_number_reader.call()),
        "action_tokens": [str(record["token"])],
        "acting_owner_ids": [str(actor.owner_id)],
    })
    return _execute_current_group()

func _finish_solo_action_outcome(
        action_context: Dictionary) -> Dictionary:
    var actor = action_context["actor"]
    var action_preview: Dictionary = _solo_action_preview(action_context)
    var actor_role := str(action_context["actor_role"])
    var played_cards: Array = action_context.get(
        "committed_cards", {}).get(actor_role, [])
    var main_triggered := bool(action_context.get(
        "main_trigger_results", {}).get(actor_role, false))
    var cooperation_preview: Dictionary = action_context.get(
        "cooperation_preview", {})
    var cooperation_triggered := bool(action_context.get(
        "cooperation_triggered", false))
    if main_triggered and cooperation_triggered:
        _notify_cooperation_resolved(action_preview, cooperation_preview)
    var action_completed: Dictionary = action_resolver.finish_action_resolution()
    if not action_completed.get("success", false):
        return _fail_active_transaction(
            action_completed.get("reason", "行动完成时点结算失败"),
            "action_resolution_end_failed")
    if actor_role == SOLO_ROLE_PLAYER:
        last_player_action_cards = played_cards
        last_enemy_action_cards.clear()
        last_played_hand = action_preview["hand"]["id"]
    else:
        last_player_action_cards.clear()
        last_enemy_action_cards = played_cards
        enemy_action_index_writer.call(enemy_action_index_reader.call() + 1)
    var same_qi_change := _apply_same_qi_gain(
        actor, action_preview, played_cards)
    if not same_qi_change.get("success", false):
        var same_qi_detail := "敌方同气结算失败" \
            if actor_role == SOLO_ROLE_ENEMY else "同气结算失败"
        return _fail_active_transaction(
            same_qi_change.get("reason", same_qi_detail), "same_qi_failed")
    battle_flow.clear_intents()
    if actor_role == SOLO_ROLE_ENEMY:
        update_battle_state.call()
        clear_enemy_action_lock.call()
    var result: Dictionary = _solo_action_result(
        action_context, same_qi_change)
    var completed: Dictionary = _complete_active_transaction(result)
    if not completed.get("success", false):
        return completed
    if actor_role == SOLO_ROLE_PLAYER:
        emit_state_changed.call()
    return result

func _solo_action_result(
        action_context: Dictionary,
        same_qi_change: Dictionary) -> Dictionary:
    var result_fields: Dictionary = action_context["result_fields"]
    var actor = action_context["actor"]
    var actor_role := str(action_context["actor_role"])
    var result := {
        "success": true,
        "same_qi_changes": [same_qi_change],
    }
    result[str(result_fields["preview"])] = _solo_action_preview(action_context)
    result[str(result_fields["played_cards"])] = action_context.get(
        "committed_cards", {}).get(actor_role, [])
    result[str(result_fields["technique_triggered"])] = bool(
        action_context.get("main_trigger_results", {}).get(actor_role, false))
    result[str(result_fields["actions_available"])] = battle_flow.available_action_count(
        actor)
    if bool(result_fields["include_cooperation"]):
        result["cooperation_preview"] = action_context.get(
            "cooperation_preview", {})
        result["cooperation_technique_triggered"] = bool(action_context.get(
            "cooperation_triggered", false))
    if bool(result_fields["include_battle_state"]):
        result["battle_state"] = battle_state_reader.call()
    return result

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
    var action_context := {
        "resolution_mode": ActionTransactionScript.RESOLUTION_SYNCHRONIZED,
        "actor": player,
        "target": enemy,
        "actor_role": SOLO_ROLE_PLAYER,
        "player_preview": player_preview,
        "enemy_preview": enemy_preview,
        "main_trigger_results": {},
        "enemy_will_act": enemy_will_act,
        "cooperation_groups": player_record.cooperation_groups.duplicate(true),
        "next_cooperation_index": 0,
        "main_committed_cards": {
            SOLO_ROLE_PLAYER: [],
            SOLO_ROLE_ENEMY: [],
        },
        "committed_cards": {
            SOLO_ROLE_PLAYER: [],
            SOLO_ROLE_ENEMY: [],
        },
        "cooperation_preview": {},
        "cooperation_triggered": false,
        "main_records": records,
    }
    var group_context := _make_group_context(
        ActionTransactionScript.GROUP_MAIN,
        records, {"player": player_preview, "enemy": enemy_preview},
        player, enemy, resolution_mode == "synchronized",
        GROUP_COMMIT_SYNCHRONIZED_MAIN, {},
        _action_choice_previews(action_context))
    var transaction_started: Dictionary = _begin_action_transaction(
        records,
        {"player": player_preview, "enemy": enemy_preview},
        ActionTransactionScript.RESOLUTION_SYNCHRONIZED,
        player,
        enemy_will_act,
        player_record.cooperation_groups,
        _action_runtime_context(action_context, group_context))
    if not transaction_started.get("success", false):
        action_resolver.abort_action_resolution()
        return transaction_started
    action_resolver.begin_action_resolution([player, enemy], {
        "resolution_mode": ActionTransactionScript.RESOLUTION_SYNCHRONIZED,
        "round_number": int(turn_number_reader.call()),
        "action_tokens": records.map(func(record): return str(record["token"])),
        "acting_owner_ids": records.map(
            func(record): return str(record["actor"].owner_id)),
    })
    return _execute_current_group()

func _make_group_context(
        group_kind: String,
        records: Array,
        previews: Dictionary,
        actor,
        target,
        use_synchronized_damage: bool,
        commit_strategy: String,
        cooperation_definition: Dictionary,
        choice_display_previews: Dictionary) -> Dictionary:
    return {
        "group_kind": group_kind,
        "records": records.duplicate(),
        "previews": previews.duplicate(),
        "actor": actor,
        "target": target,
        "use_synchronized_damage": use_synchronized_damage,
        "commit_strategy": commit_strategy,
        "committed_cards": {},
        "cooperation_definition": cooperation_definition.duplicate(true),
        "choice_display_previews": choice_display_previews.duplicate(),
    }

func _action_runtime_context(
        action_context: Dictionary,
        group_context: Dictionary) -> Dictionary:
    return {
        ACTION_CONTEXT_KEY: action_context,
        CURRENT_GROUP_CONTEXT_KEY: group_context,
    }

func _action_choice_previews(action_context: Dictionary) -> Dictionary:
    var result := {}
    var player_preview: Dictionary = action_context.get("player_preview", {})
    var enemy_preview: Dictionary = action_context.get("enemy_preview", {})
    if str(action_context.get("resolution_mode", "")) \
            == ActionTransactionScript.RESOLUTION_SYNCHRONIZED:
        result["preview"] = player_preview
        result["enemy_preview"] = enemy_preview
        return result
    if not player_preview.is_empty():
        result["preview"] = player_preview
    if not enemy_preview.is_empty():
        result["enemy_preview"] = enemy_preview
    return result

func _solo_action_preview(action_context: Dictionary) -> Dictionary:
    if str(action_context.get("actor_role", "")) == SOLO_ROLE_ENEMY:
        return action_context.get("enemy_preview", {})
    return action_context.get("player_preview", {})

func _execute_current_group(resume_cursor: String = "") -> Dictionary:
    var runtime_context: Dictionary = active_action_transaction.runtime_context
    var action_context: Dictionary = runtime_context.get(ACTION_CONTEXT_KEY, {})
    var group_context: Dictionary = runtime_context.get(
        CURRENT_GROUP_CONTEXT_KEY, {})
    if action_context.is_empty() or group_context.is_empty():
        return _fail_active_transaction(
            "行动事务缺少行动级或牌型组运行上下文",
            "missing_action_group_context")
    if resume_cursor == "":
        var resolution: Dictionary = action_resolver.resolve_action_records(
            group_context.get("records", []),
            bool(group_context.get("use_synchronized_damage", false)))
        if resolution.get("pending_choice", false):
            return _suspend_current_group(
                ActionTransactionScript.CURSOR_GROUP_EFFECTS,
                resolution.get("detail", _group_wait_detail(
                    action_context, group_context, false)))
        if not resolution.get("success", false):
            return _fail_active_transaction(
                resolution.get("detail", _group_resolution_failure_detail(
                    group_context)),
                "cooperation_resolution_failed"
                if str(group_context.get("group_kind", "")) \
                    == ActionTransactionScript.GROUP_COOPERATION
                else "group_resolution_failed")
        return _execute_current_group(
            ActionTransactionScript.CURSOR_GROUP_EFFECTS)
    if resume_cursor == ActionTransactionScript.CURSOR_GROUP_EFFECTS:
        var commit_ready: Dictionary = _enter_zone_commit_phase()
        if not commit_ready.get("success", false):
            return commit_ready
        _notify_current_group_pre_commit(group_context)
        var commit_result: Dictionary = _commit_current_group_zones(
            action_context, group_context)
        if not commit_result.get("success", false):
            return commit_result
        var post_commit_ready: Dictionary = _enter_post_commit_phase(
            commit_result.get("committed_by_owner", {}))
        if not post_commit_ready.get("success", false):
            return post_commit_ready
        var post_commit: Dictionary = action_resolver.resolve_post_commit_phase()
        if post_commit.get("pending_choice", false):
            return _suspend_current_group(
                ActionTransactionScript.CURSOR_POST_COMMIT_EFFECTS,
                post_commit.get("detail", _group_wait_detail(
                    action_context, group_context, true)))
        if not post_commit.get("success", false):
            return _fail_active_transaction(
                post_commit.get("detail", _group_post_commit_failure_detail(
                    action_context, group_context)),
                "cooperation_post_commit_failed"
                if str(group_context.get("group_kind", "")) \
                    == ActionTransactionScript.GROUP_COOPERATION
                else "post_commit_failed")
        var marked: Dictionary = _mark_current_group_post_commit_completed()
        if not marked.get("success", false):
            return marked
        return _finish_current_group(action_context, group_context)
    if resume_cursor == ActionTransactionScript.CURSOR_POST_COMMIT_EFFECTS:
        var marked: Dictionary = _mark_current_group_post_commit_completed()
        if not marked.get("success", false):
            return marked
        return _finish_current_group(action_context, group_context)
    return _fail_active_transaction(
        "行动事务恢复位置无效", "invalid_resume_cursor")

func _notify_current_group_pre_commit(group_context: Dictionary) -> void:
    var records: Array = group_context.get("records", [])
    if str(group_context.get("group_kind", "")) \
            == ActionTransactionScript.GROUP_COOPERATION:
        if not records.is_empty():
            _notify_cooperation_pre_commit(records[0])
        return
    for record in records:
        _notify_action_pre_commit(record)

func _commit_current_group_zones(
        action_context: Dictionary,
        group_context: Dictionary) -> Dictionary:
    var committed_by_owner := {}
    match str(group_context.get("commit_strategy", "")):
        GROUP_COMMIT_SOLO_MAIN:
            var actor = group_context["actor"]
            var actor_role := str(action_context["actor_role"])
            var preview: Dictionary = group_context.get(
                "previews", {}).get(actor_role, {})
            var has_cooperation: bool = not action_context.get(
                "cooperation_groups", []).is_empty()
            var commit: Dictionary = action_resolver.commit_staging_for(
                actor, preview.get("cards", []) if has_cooperation else [])
            _record_group_commit(
                action_context, group_context, actor_role, actor,
                commit.get("committed", []), true, committed_by_owner)
        GROUP_COMMIT_SYNCHRONIZED_MAIN:
            var records: Array = group_context.get("records", [])
            var player_record = records[0]
            var has_cooperation: bool = (
                bool(player_record["triggered"])
                and not action_context.get("cooperation_groups", []).is_empty())
            var player_commit: Dictionary = action_resolver.commit_staging_for(
                player,
                action_context.get("player_preview", {}).get("cards", [])
                if has_cooperation else [])
            _record_group_commit(
                action_context, group_context, SOLO_ROLE_PLAYER, player,
                player_commit.get("committed", []), true, committed_by_owner)
            if bool(action_context.get("enemy_will_act", false)):
                var enemy_commit: Dictionary = action_resolver.commit_staging_for(
                    enemy)
                _record_group_commit(
                    action_context, group_context, SOLO_ROLE_ENEMY, enemy,
                    enemy_commit.get("committed", []), true,
                    committed_by_owner)
        GROUP_COMMIT_COOPERATION:
            var records: Array = group_context.get("records", [])
            if records.is_empty():
                return _fail_active_transaction(
                    "协同牌型组缺少行动记录", "missing_cooperation_record")
            var record = records[0]
            var cooperation_commit: Dictionary = \
                action_resolver.commit_cooperation_staging(
                    record, group_context.get("cooperation_definition", {}))
            _record_group_commit(
                action_context, group_context, SOLO_ROLE_PLAYER, player,
                cooperation_commit.get("committed", []), false,
                committed_by_owner)
        _:
            return _fail_active_transaction(
                "牌型组提交策略无效", "invalid_group_commit_strategy")
    return {"success": true, "committed_by_owner": committed_by_owner}

func _record_group_commit(
        action_context: Dictionary,
        group_context: Dictionary,
        role: String,
        side,
        cards: Array,
        is_main_group: bool,
        committed_by_owner: Dictionary) -> void:
    var group_cards: Dictionary = group_context.get("committed_cards", {})
    group_cards[role] = cards
    group_context["committed_cards"] = group_cards
    var all_cards: Dictionary = action_context.get("committed_cards", {})
    var accumulated: Array = all_cards.get(role, []).duplicate()
    accumulated.append_array(cards)
    all_cards[role] = accumulated
    action_context["committed_cards"] = all_cards
    if is_main_group:
        var main_cards: Dictionary = action_context.get(
            "main_committed_cards", {})
        main_cards[role] = cards
        action_context["main_committed_cards"] = main_cards
    action_resolver.log_cards_leave(side, cards)
    committed_by_owner[str(side.owner_id)] = _card_ids(cards)

func _mark_current_group_post_commit_completed() -> Dictionary:
    var completed: Dictionary = \
        active_action_transaction.mark_post_commit_completed()
    if completed.get("success", false):
        return completed
    return _fail_active_transaction(
        completed.get("reason", "无法完成 post_commit"),
        str(completed.get("code", "post_commit_state_failed")))

func _finish_current_group(
        action_context: Dictionary,
        group_context: Dictionary) -> Dictionary:
    var records: Array = group_context.get("records", [])
    var group_kind := str(group_context.get("group_kind", ""))
    if group_kind == ActionTransactionScript.GROUP_MAIN:
        var trigger_results: Dictionary = action_context.get(
            "main_trigger_results", {})
        if str(action_context.get("resolution_mode", "")) \
                == ActionTransactionScript.RESOLUTION_SOLO:
            var actor_role := str(action_context.get("actor_role", ""))
            trigger_results[actor_role] = (
                true if not action_context.get(
                    "cooperation_groups", []).is_empty()
                else bool(records[0]["triggered"]))
        else:
            trigger_results[SOLO_ROLE_PLAYER] = bool(records[0]["triggered"])
            trigger_results[SOLO_ROLE_ENEMY] = (
                bool(records[1]["triggered"]) if records.size() > 1 else false)
        action_context["main_trigger_results"] = trigger_results
    elif group_kind == ActionTransactionScript.GROUP_COOPERATION:
        action_context["cooperation_preview"] = group_context.get(
            "previews", {}).get("cooperation", {})
        action_context["cooperation_triggered"] = (
            bool(records[0]["triggered"]) if not records.is_empty() else false)
    else:
        return _fail_active_transaction(
            "牌型组类型无效", "invalid_group_kind")
    for record in records:
        action_resolver.finish_action_record(record)
    if _has_next_cooperation_group(action_context):
        return _start_next_cooperation_group(action_context)
    if str(action_context.get("resolution_mode", "")) \
            == ActionTransactionScript.RESOLUTION_SOLO:
        return _finish_solo_action_outcome(action_context)
    return _finish_synchronized_outcome(action_context)

func _has_next_cooperation_group(action_context: Dictionary) -> bool:
    var cooperation_groups: Array = action_context.get(
        "cooperation_groups", [])
    var next_index := int(action_context.get("next_cooperation_index", 0))
    if next_index >= cooperation_groups.size():
        return false
    if str(action_context.get("resolution_mode", "")) \
            == ActionTransactionScript.RESOLUTION_SYNCHRONIZED:
        return bool(action_context.get("main_trigger_results", {}).get(
            SOLO_ROLE_PLAYER, false))
    return str(action_context.get("actor_role", "")) == SOLO_ROLE_PLAYER

func _start_next_cooperation_group(action_context: Dictionary) -> Dictionary:
    action_resolver.effect_ports.close_current_source_binding_window()
    var next_index := int(action_context.get("next_cooperation_index", 0))
    var cooperation_groups: Array = action_context.get(
        "cooperation_groups", [])
    var group: Dictionary = cooperation_groups[next_index]
    action_context["next_cooperation_index"] = next_index + 1
    var cooperation_preview: Dictionary = group.get("preview", {})
    var cooperation_record = action_resolver.make_action_record(
        player, enemy, cooperation_preview, sequence_book, 101,
        turn_number_reader.call())
    var choice_previews := _action_choice_previews(action_context)
    choice_previews["cooperation_preview"] = cooperation_preview
    var group_context := _make_group_context(
        ActionTransactionScript.GROUP_COOPERATION,
        [cooperation_record], {"cooperation": cooperation_preview},
        player, enemy, false, GROUP_COMMIT_COOPERATION,
        group.get("cooperation", {}), choice_previews)
    var started: Dictionary = _begin_cooperation_transaction_group(
        cooperation_record, cooperation_preview,
        _action_runtime_context(action_context, group_context))
    if not started.get("success", false):
        return started
    return _execute_current_group()

func _suspend_current_group(
        resume_cursor: String,
        detail) -> Dictionary:
    var suspended: Dictionary = _suspend_active_transaction(resume_cursor)
    if not suspended.get("success", false):
        return suspended
    emit_state_changed.call()
    var group_context: Dictionary = active_action_transaction.runtime_context.get(
        CURRENT_GROUP_CONTEXT_KEY, {})
    var result := {
        "success": true,
        "pending_choice": true,
        "choice_request": action_resolver.pending_choice_snapshot(),
        "detail": str(detail),
    }
    for field_name in group_context.get("choice_display_previews", {}):
        result[str(field_name)] = group_context["choice_display_previews"][
            field_name]
    return result

func _group_wait_detail(
        action_context: Dictionary,
        group_context: Dictionary,
        post_commit: bool) -> String:
    if str(group_context.get("group_kind", "")) \
            == ActionTransactionScript.GROUP_COOPERATION:
        return "等待协同提交后选择" if post_commit else "等待协同功法选择"
    if str(action_context.get("resolution_mode", "")) \
            == ActionTransactionScript.RESOLUTION_SYNCHRONIZED:
        return "等待同步提交后选择" if post_commit else "等待选择"
    return "等待提交后选择" if post_commit else "等待选择"

func _group_resolution_failure_detail(group_context: Dictionary) -> String:
    if str(group_context.get("group_kind", "")) \
            == ActionTransactionScript.GROUP_COOPERATION:
        return "协同组结算失败"
    return "功法结算失败"

func _group_post_commit_failure_detail(
        action_context: Dictionary,
        group_context: Dictionary) -> String:
    if str(group_context.get("group_kind", "")) \
            == ActionTransactionScript.GROUP_COOPERATION:
        return "协同提交后效果失败"
    if str(action_context.get("resolution_mode", "")) \
            == ActionTransactionScript.RESOLUTION_SYNCHRONIZED:
        return "同步提交后效果失败"
    if str(action_context.get("actor_role", "")) == SOLO_ROLE_ENEMY:
        return "敌方提交后效果失败"
    return "提交后效果失败"

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
        action_context: Dictionary) -> Dictionary:
    var player_preview: Dictionary = action_context.get("player_preview", {})
    var enemy_preview: Dictionary = action_context.get("enemy_preview", {})
    var enemy_will_act := bool(action_context.get("enemy_will_act", false))
    var committed_cards: Dictionary = action_context.get("committed_cards", {})
    var player_cards: Array = committed_cards.get(SOLO_ROLE_PLAYER, [])
    var enemy_cards: Array = committed_cards.get(SOLO_ROLE_ENEMY, [])
    var trigger_results: Dictionary = action_context.get(
        "main_trigger_results", {})
    var player_triggered := bool(trigger_results.get(SOLO_ROLE_PLAYER, false))
    var enemy_triggered := bool(trigger_results.get(SOLO_ROLE_ENEMY, false))
    var cooperation_triggered := bool(action_context.get(
        "cooperation_triggered", false))
    var cooperation_preview: Dictionary = action_context.get(
        "cooperation_preview", {})
    if player_triggered and cooperation_triggered:
        _notify_cooperation_resolved(player_preview, cooperation_preview)
    var action_completed: Dictionary = action_resolver.finish_action_resolution()
    if not action_completed.get("success", false):
        return _fail_active_transaction(
            action_completed.get("reason", "行动完成时点结算失败"),
            "action_resolution_end_failed")
    last_player_action_cards = player_cards
    last_enemy_action_cards = enemy_cards
    last_played_hand = player_preview["hand"]["id"]
    var same_qi_changes: Array = []
    var player_same_qi := _apply_same_qi_gain(
        player, player_preview, player_cards)
    if not player_same_qi.get("success", false):
        return _fail_active_transaction(
            player_same_qi.get("reason", "我方同气结算失败"), "same_qi_failed")
    same_qi_changes.append(player_same_qi)
    if enemy_will_act:
        enemy_action_index_writer.call(enemy_action_index_reader.call() + 1)
        var enemy_same_qi := _apply_same_qi_gain(
            enemy, enemy_preview, enemy_cards)
        if not enemy_same_qi.get("success", false):
            return _fail_active_transaction(
                enemy_same_qi.get("reason", "敌方同气结算失败"), "same_qi_failed")
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
    var should_resolve_enemy: bool = battle_state_reader.call() == "active" \
        and not battle_flow.can_act(player) \
        and battle_flow.can_act(enemy) \
        and not external_enemy_action_mode
    var result := {
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
    var completed: Dictionary = _complete_active_transaction(result)
    if not completed.get("success", false):
        return completed
    if should_resolve_enemy:
        resolve_enemy_only_actions.call()
    emit_state_changed.call()
    return result

func _begin_action_transaction(
        records: Array,
        previews: Dictionary,
        resolution_mode: String,
        initiator,
        enemy_will_act: bool,
        cooperation_groups: Array,
        runtime_context: Dictionary = {}) -> Dictionary:
    if active_action_transaction.is_active():
        return {"success": false, "reason": "当前已有未完成的行动事务",
            "code": "transaction_already_active"}
    if records.is_empty():
        return {"success": false, "reason": "行动事务缺少结算记录",
            "code": "missing_action_records"}
    _transaction_serial += 1
    var root_action_token := str(records[0]["token"])
    var acting_owner_ids: Array = records.map(
        func(record): return str(record["actor"].owner_id))
    var frozen_ids := {
        str(player.owner_id): _card_ids(player.staging),
        str(enemy.owner_id): _card_ids(enemy.staging),
    }
    var frozen_same_qi: Dictionary = {}
    for preview_key in previews:
        var preview: Dictionary = previews[preview_key]
        if not preview.is_empty():
            frozen_same_qi[str(preview_key)] = preview.get(
                "same_qi", {}).duplicate(true)
    var started: Dictionary = active_action_transaction.begin_transaction({
        "transaction_id": "%s:tx:%06d" % [root_action_token, _transaction_serial],
        "root_action_token": root_action_token,
        "resolution_mode": resolution_mode,
        "initiator_owner_id": str(initiator.owner_id),
        "participating_owner_ids": [str(player.owner_id), str(enemy.owner_id)],
        "acting_owner_ids": acting_owner_ids,
        "records": records,
        "previews": previews,
        "runtime_context": runtime_context,
        "cooperation_groups": cooperation_groups,
        "enemy_will_act": enemy_will_act,
        "frozen_card_instance_ids": frozen_ids,
        "frozen_same_qi": frozen_same_qi,
        "completed_flags": {
            "cards_staged": true,
            "power_frozen": true,
            "momentum_consumed": true,
            "technique_slots_frozen": true,
            "actions_consumed": true,
            "action_confirmed_emitted": true,
            "enemy_action_locked": enemy_will_act,
        },
    })
    if not started.get("success", false):
        return started
    var resolving: Dictionary = active_action_transaction.advance_phase(
        ActionTransactionScript.PHASE_RESOLVING)
    if not resolving.get("success", false):
        return _fail_active_transaction(
            resolving.get("reason", "行动事务无法进入结算阶段"),
            str(resolving.get("code", "transaction_phase_failed")))
    return started

func _begin_cooperation_transaction_group(
        record,
        cooperation_preview: Dictionary,
        runtime_context: Dictionary) -> Dictionary:
    var cooperation_phase: Dictionary = active_action_transaction.advance_phase(
        ActionTransactionScript.PHASE_COOPERATION)
    if not cooperation_phase.get("success", false):
        return _fail_active_transaction(
            cooperation_phase.get("reason", "行动事务无法进入协同阶段"),
            str(cooperation_phase.get("code", "cooperation_phase_failed")))
    var next_group_index: int = active_action_transaction.group_index + 1
    var started: Dictionary = active_action_transaction.begin_cooperation_group(
        next_group_index,
        [record],
        {"cooperation": cooperation_preview},
        runtime_context)
    if not started.get("success", false):
        return _fail_active_transaction(
            started.get("reason", "行动事务无法进入协同牌型组"),
            str(started.get("code", "cooperation_group_failed")))
    return started

func _suspend_active_transaction(resume_cursor: String) -> Dictionary:
    var request: Dictionary = action_resolver.pending_choice_snapshot()
    active_action_transaction.record_public_results({
        "pending_choice": true,
        "choice_request": request,
        "phase": active_action_transaction.phase(),
        "group_index": active_action_transaction.group_index,
        "group_kind": active_action_transaction.group_kind,
    })
    var suspended: Dictionary = active_action_transaction.suspend_for_choice(
        str(request.get("request_id", "")), resume_cursor)
    if not suspended.get("success", false):
        return _fail_active_transaction(
            suspended.get("reason", "行动事务无法暂停"),
            str(suspended.get("code", "transaction_suspend_failed")))
    return suspended

func _enter_zone_commit_phase() -> Dictionary:
    var resolved: Dictionary = active_action_transaction.mark_group_resolution_completed()
    if not resolved.get("success", false):
        return _fail_active_transaction(
            resolved.get("reason", "无法标记牌型组结算完成"),
            str(resolved.get("code", "group_resolution_state_failed")))
    var advanced: Dictionary = active_action_transaction.advance_phase(
        ActionTransactionScript.PHASE_COMMITTING_ZONES)
    if not advanced.get("success", false):
        return _fail_active_transaction(
            advanced.get("reason", "行动事务无法进入牌区提交阶段"),
            str(advanced.get("code", "zone_commit_phase_failed")))
    return advanced

func _enter_post_commit_phase(
        committed_by_owner: Dictionary) -> Dictionary:
    var committed: Dictionary = active_action_transaction.mark_zones_committed(
        committed_by_owner)
    if not committed.get("success", false):
        return _fail_active_transaction(
            committed.get("reason", "无法标记牌区提交完成"),
            str(committed.get("code", "zone_commit_state_failed")))
    var advanced: Dictionary = active_action_transaction.advance_phase(
        ActionTransactionScript.PHASE_POST_COMMIT)
    if not advanced.get("success", false):
        return _fail_active_transaction(
            advanced.get("reason", "行动事务无法进入 post_commit"),
            str(advanced.get("code", "post_commit_phase_failed")))
    return advanced

func _continue_active_transaction(resume_cursor: String) -> Dictionary:
    var expected_phase := (
        ActionTransactionScript.PHASE_RESOLVING
        if resume_cursor == ActionTransactionScript.CURSOR_GROUP_EFFECTS
        else ActionTransactionScript.PHASE_POST_COMMIT
        if resume_cursor == ActionTransactionScript.CURSOR_POST_COMMIT_EFFECTS
        else "")
    if expected_phase == "":
        return _fail_active_transaction(
            "行动事务恢复位置无效", "invalid_resume_cursor")
    if active_action_transaction.phase() != expected_phase:
        return _fail_active_transaction(
            "行动事务阶段与恢复位置不匹配", "resume_phase_mismatch")
    return _execute_current_group(resume_cursor)

func _complete_active_transaction(result: Dictionary) -> Dictionary:
    var completed: Dictionary = active_action_transaction.complete_transaction(result)
    if not completed.get("success", false):
        return _fail_active_transaction(
            completed.get("reason", "行动事务无法完成"),
            str(completed.get("code", "transaction_completion_failed")))
    var cleared: Dictionary = active_action_transaction.clear_transaction()
    if not cleared.get("success", false):
        return cleared
    return {"success": true}

func _fail_active_transaction(reason, code: String) -> Dictionary:
    action_resolver.abort_action_resolution()
    var failure := {"success": false, "reason": str(reason), "code": code}
    if not active_action_transaction.is_empty():
        var failed: Dictionary = active_action_transaction.fail_transaction(reason, code)
        if not failed.get("success", false):
            failure["transaction_failure"] = failed
        active_action_transaction.clear_transaction(true)
    return failure

func _card_ids(cards: Array) -> Array[String]:
    var result: Array[String] = []
    for card in cards:
        result.append(str(card.id))
    return result

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
