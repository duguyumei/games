class_name BattleSession
extends RefCounted

signal state_changed

const CombatEngineScript = preload("res://core/combat_engine.gd")
const BattleSnapshotScript = preload("res://core/battle_snapshot.gd")
const BattleEventScript = preload("res://core/battle_event.gd")
const BattleCommandScript = preload("res://core/battle_command_dto.gd")
const BattleCommandResultScript = preload("res://core/battle_command_result.gd")
const BattleSetupServiceScript = preload("res://core/battle_setup_service.gd")
const ActionWindowAiCoordinatorScript = preload("res://core/ai/action_window_ai_coordinator.gd")
const BattleAiAdapterScript = preload("res://core/ai/battle_ai_adapter.gd")
const AiProviderFactoryScript = preload("res://core/ai/providers/ai_provider_factory.gd")
const AiConversationStoreScript = preload("res://core/ai/ai_conversation_store.gd")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")

var engine
var _battle_setup_service
var _player_run_deck
var _event_queue: Array = []
var _history_cursor: int = 0
var _event_serial: int = 0
var ai_coordinator = null
var _ai_provider = null
var _owns_ai_provider: bool = false
var _remote_ai_enabled: bool = false
var _ai_settings: Dictionary = {}
var _ai_window_serial: int = 0
var _ai_battle_id: String = ""
var _resolving_external_enemy: bool = false
var _last_ai_completed_round: int = 0
var _ai_adapter = null
var _ai_runtime_profile: Dictionary = {}
var _ai_conversation_store = AiConversationStoreScript.new()
var _ai_conversation_path: String = ""
var runtime_profile

static var _ai_attempt_serial: int = 0

func _init(engine_override = null, runtime_profile_override = null) -> void:
    engine = engine_override if engine_override != null else CombatEngineScript.new()
    runtime_profile = (
        runtime_profile_override
        if runtime_profile_override != null
        else (
            engine.content_catalog.runtime_profile
            if engine.content_catalog != null
            and engine.content_catalog.get("runtime_profile") != null
            else RuntimeProfileScript.current()))
    _ai_runtime_profile = {
        "provider": {"kind": runtime_profile.ai_provider_kind()},
    }
    _battle_setup_service = BattleSetupServiceScript.new(engine.content_catalog)
    _player_run_deck = _battle_setup_service.run_deck_from_progress(null)
    engine.state_changed.connect(_on_engine_state_changed)

func use_game_log(shared_game_log) -> void:
    engine.use_game_log(shared_game_log)
    _event_queue.clear()
    _history_cursor = 0
    _event_serial = 0

func use_ai_provider(provider) -> void:
    if _owns_ai_provider and _ai_provider != null \
            and _ai_provider != provider \
            and is_instance_valid(_ai_provider):
        _ai_provider.queue_free()
    _ai_provider = provider
    _owns_ai_provider = false
    if ai_coordinator != null:
        ai_coordinator.use_provider(provider)

func configure_ai_provider(config: Dictionary = {}):
    var provider = AiProviderFactoryScript.create(config)
    use_ai_provider(provider)
    _owns_ai_provider = true
    return provider

func configure_ai_runtime(profile: Dictionary) -> void:
    var provider_defaults: Dictionary = _ai_runtime_profile.get(
        "provider", {}).duplicate(true)
    _ai_runtime_profile = profile.duplicate(true)
    var configured_provider: Dictionary = _ai_runtime_profile.get(
        "provider", {}).duplicate(true)
    provider_defaults.merge(configured_provider, true)
    _ai_runtime_profile["provider"] = provider_defaults

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE and _owns_ai_provider \
            and _ai_provider != null and is_instance_valid(_ai_provider):
        _ai_provider.queue_free()

func setup_battle(configuration: Dictionary = {}, progress_snapshot = null) -> bool:
    engine.game_log.clear("battle")
    _event_queue.clear()
    _history_cursor = 0
    _event_serial = 0
    var battle: Dictionary = configuration.get("battle", {})
    var scenario_path := str(battle.get(
        "scenario_path", engine.content_catalog.path_for("scripted_battle")))
    var entry_kind := str(battle.get(
        "entry_kind", runtime_profile.enemy_entry_kind()))
    if not runtime_profile.allows_resource_path(scenario_path):
        engine.game_log.record_system(
            "error",
            "runtime_profile",
            "运行模式拒绝战斗资源",
            "%s 禁止引用 %s" % [runtime_profile.mode_name(), scenario_path])
        return false
    if runtime_profile.is_production() and entry_kind != "formal":
        engine.game_log.record_system(
            "error",
            "runtime_profile",
            "production 模式拒绝调试敌人入口",
            entry_kind)
        return false
    var use_enemy_ai := bool(battle.get("use_enemy_ai", true))
    var runtime_enabled := bool(_ai_runtime_profile.get("enabled", false))
    _remote_ai_enabled = (
        bool(battle.get("use_remote_ai", false)) or runtime_enabled) \
        and use_enemy_ai
    _ai_settings = _ai_runtime_profile.get(
        "conversation", {}).duplicate(true)
    _ai_settings.merge(configuration.get("ai_settings", {}), true)
    var storage: Dictionary = _ai_runtime_profile.get("storage", {})
    _ai_settings["autosave_conversation"] = bool(
        storage.get("autosave_conversation", false))
    if _remote_ai_enabled and _ai_provider == null:
        var provider_config: Dictionary = _ai_runtime_profile.get(
            "provider", {}).duplicate(true)
        provider_config.merge(configuration.get("ai_provider", {}), true)
        configure_ai_provider(provider_config)
    _ai_window_serial = 0
    _last_ai_completed_round = 0
    _ai_battle_id = _create_ai_battle_id(configuration)
    _ai_conversation_path = _ai_conversation_store.path_for_battle(
        _ai_battle_id,
        str(storage.get(
            "conversation_directory",
            AiConversationStoreScript.DEFAULT_DIRECTORY)))
    _ai_settings["conversation_path"] = _ai_conversation_path
    _player_run_deck = _battle_setup_service.run_deck_from_progress(progress_snapshot)
    var player_cards = (
        _player_run_deck.create_battle_cards()
        if progress_snapshot != null
        else null)
    var loaded: bool = engine.setup_scripted_battle(
        int(configuration.get("content_seed", 2308)),
        scenario_path,
        use_enemy_ai,
        player_cards,
        true)
    if loaded:
        _battle_setup_service.apply_non_deck_progress(engine.player, progress_snapshot)
        engine.use_external_enemy_actions(_remote_ai_enabled)
        if _remote_ai_enabled:
            _configure_ai_coordinator()
        else:
            ai_coordinator = null
    _capture_trigger_history()
    engine.game_log.record_system(
        "info" if loaded else "error",
        "battle_session",
        "战斗会话建立" if loaded else "战斗会话建立失败",
        "content_seed=%d" % int(configuration.get("content_seed", 2308)),
        {"scenario_path": scenario_path, "use_enemy_ai": use_enemy_ai})
    return loaded

func execute(command: Dictionary) -> Dictionary:
    return execute_dto(BattleCommandScript.new().configure(command)).to_legacy_dict()

func execute_dto(command):
    var command_type: String = str(command.type)
    var result: Dictionary
    match command_type:
        "start_turn":
            if engine.battle_state != "active":
                result = {"success": false, "reason": "战斗已经结束"}
            else:
                var drawn: Array = engine.start_player_turn()
                result = {"success": true, "drawn_card_ids": _card_ids(drawn)}
                if _remote_ai_enabled:
                    _open_current_action_window()
        "end_turn":
            if engine.battle_state != "active":
                result = {"success": false, "reason": "战斗已经结束"}
            elif engine.has_pending_effect_choice():
                result = {"success": false, "reason": "正在等待功法选择，请先完成选择"}
            elif _remote_ai_enabled and _enemy_ai_gate_reason() != "":
                result = {"success": false, "reason": _enemy_ai_gate_reason()}
            else:
                engine.end_player_turn()
                result = {"success": true}
                if _remote_ai_enabled and engine.has_locked_enemy_action() \
                        and not engine.battle_flow.can_act(engine.player):
                    _resolve_external_enemy_action_and_continue()
                _complete_ai_round_if_needed()
        "play_cards":
            if _remote_ai_enabled and _enemy_ai_gate_reason() != "":
                result = {"success": false, "reason": _enemy_ai_gate_reason()}
            else:
                result = engine.confirm_play(
                    command.card_ids,
                    command.cooperation_card_ids)
                if _remote_ai_enabled and result.get("success", false) \
                        and not result.get("pending_choice", false):
                    _ai_adapter.record_action_result(ai_coordinator, result)
                    _open_current_action_window()
        "resolve_choice":
            result = engine.resolve_effect_choice(
                command.request_id,
                command.card_ids)
            if _remote_ai_enabled and result.get("success", false) \
                    and not result.get("pending_choice", false):
                _ai_adapter.record_action_result(ai_coordinator, result)
                _open_current_action_window()
        "use_consumable":
            result = engine.use_player_consumable(
                command.slot_index,
                command.card_ids)
            if _remote_ai_enabled and result.get("success", false):
                _ai_adapter.record_consumable_use(
                    ai_coordinator,
                    command.card_ids,
                    result)
        "move_technique_slot":
            result = engine.move_player_technique_slot(command.direction)
        _:
            result = {"success": false, "reason": "未知战斗命令：%s" % command_type}
    if not result.get("success", false):
        _record_command_rejected(command_type, str(result.get("reason", "命令执行失败")))
    _capture_trigger_history()
    return BattleCommandResultScript.new().configure(command_type, result)

func preview(card_ids: Array) -> Dictionary:
    return _safe_preview_snapshot(engine.preview(card_ids))

func validate_consumable_targets(slot_index: int, card_ids: Array) -> Dictionary:
    if slot_index < 0 or slot_index >= engine.player.consumable_ids.size():
        return {"ok": false, "reason": "消耗品槽位无效"}
    var cards: Array = []
    for card_id in card_ids:
        var card = engine.player.find_hand_card(str(card_id))
        if card != null:
            cards.append(card)
    var consumable_id: String = engine.player.consumable_ids[slot_index]
    return engine.consumable_repository.validate_targets(consumable_id, cards)

func apply_player_progress_from(progress_snapshot) -> void:
    if progress_snapshot == null:
        return
    _player_run_deck = _battle_setup_service.run_deck_from_progress(progress_snapshot)
    engine.replace_player_deck(_player_run_deck.create_battle_cards(), true)
    _battle_setup_service.apply_non_deck_progress(engine.player, progress_snapshot)

func player_progress_snapshot():
    return _battle_setup_service.capture_progress(engine.player, _player_run_deck)

func combat_order_labels(technique_name: String = "当前功法") -> Array[String]:
    return engine.combat_order_labels(engine.player, technique_name)

func snapshot():
    var ai_snapshot: Dictionary = (
        ai_coordinator.snapshot()
        if _remote_ai_enabled and ai_coordinator != null
        else {
            "state": "local_utility" if engine.enemy_ai_enabled else "disabled",
            "can_player_confirm": true,
            "public_intent": engine.enemy_plan.duplicate(true),
        })
    var visible_enemy_plan: Dictionary = engine.enemy_plan.duplicate(true)
    if _remote_ai_enabled:
        visible_enemy_plan = ai_snapshot.get("public_intent", {}).duplicate(true)
        visible_enemy_plan.erase("ready")
    return BattleSnapshotScript.new({
        "battle_state": engine.battle_state,
        "battle_state_detail": engine.battle_state_detail,
        "turn_number": engine.turn_number,
        "actions_available": engine.actions_available,
        "enemy_actions_available": engine.enemy_actions_available,
        "action_states": {
            "player": engine.actor_action_state(engine.player),
            "enemy": engine.actor_action_state(engine.enemy),
        },
        "resolution_mode": engine.battle_flow.resolution_mode(),
        "round_ended": engine.round_ended,
        "locked_enemy_card_count": engine.locked_enemy_card_ids.size(),
        "enemy_plan": visible_enemy_plan,
        "ai_decision": ai_snapshot,
        "pending_choice": engine.pending_effect_choice_snapshot(),
        "pending_action_transaction": engine.pending_action_transaction_snapshot(),
        "delayed_count": engine.delayed_effects.size(),
        "timing_history": engine.timing_system.history_snapshot(200),
        "status_history": engine.status_system.history_snapshot(200),
        "player": _side_snapshot(engine.player),
        "enemy": _side_snapshot(engine.enemy),
        "last_preview": _safe_preview_snapshot(engine.last_preview),
        "last_enemy_preview": _safe_preview_snapshot(engine.last_enemy_preview),
        "last_player_action_cards": _card_snapshots(engine.last_player_action_cards),
        "last_enemy_action_cards": _card_snapshots(engine.last_enemy_action_cards),
        "battle_log": engine.game_log.entries("battle", 200),
        "system_log": engine.game_log.entries("system", 200),
    })

func drain_events() -> Array:
    _capture_trigger_history()
    var drained := _event_queue.duplicate()
    _event_queue.clear()
    return drained

func poll_ai_timeout(now_msec: int = -1) -> bool:
    if not _remote_ai_enabled or ai_coordinator == null:
        return false
    return ai_coordinator.poll_timeout(now_msec)

func ai_conversation_snapshot():
    if ai_coordinator == null:
        return null
    return ai_coordinator.conversation_snapshot()

func ai_conversation_path() -> String:
    return _ai_conversation_path

func save_ai_conversation(path: String = "") -> bool:
    if ai_coordinator == null:
        return false
    return ai_coordinator.save_conversation(path)

func _configure_ai_coordinator() -> void:
    _ai_adapter = BattleAiAdapterScript.new(engine)
    var context = _ai_adapter.build_context(_ai_battle_id)
    ai_coordinator = ActionWindowAiCoordinatorScript.new().configure(
        context,
        _ai_provider,
        _ai_settings,
        Callable(engine, "lock_external_enemy_action"))
    ai_coordinator.state_changed.connect(_on_ai_coordinator_state_changed)
    ai_coordinator.proposal_locked.connect(_on_ai_proposal_locked)
    ai_coordinator.fallback_used.connect(_on_ai_fallback_used)
    ai_coordinator.window_failed.connect(_on_ai_window_failed)

func _create_ai_battle_id(configuration: Dictionary) -> String:
    _ai_attempt_serial += 1
    var started_at_msec := int(Time.get_unix_time_from_system() * 1000.0)
    return "battle-%d-%s-%d-%d" % [
        int(configuration.get("content_seed", 2308)),
        str(configuration.get("content_id", "representative")),
        started_at_msec,
        _ai_attempt_serial,
    ]

func _open_current_action_window() -> void:
    if not _remote_ai_enabled or ai_coordinator == null:
        return
    if engine.battle_state != "active" or engine.round_ended:
        ai_coordinator.close_window()
        return
    var player_can_act: bool = engine.battle_flow.can_act(engine.player)
    var enemy_can_act: bool = engine.battle_flow.can_act(engine.enemy)
    if not player_can_act and not enemy_can_act:
        ai_coordinator.close_window()
        return
    var window: Dictionary = _ai_adapter.build_window(
        _ai_battle_id, _ai_window_serial)
    _ai_window_serial += 1
    engine.game_log.record_system(
        "info",
        "remote_ai_window",
        "敌方 AI 行动窗口已建立",
        "回合 %d｜行动 %d｜敌方%s行动" % [
            engine.turn_number,
            engine.enemy_action_index,
            "可以" if enemy_can_act else "不能"],
        {
            "window_id": window["window_id"],
            "player_can_act": player_can_act,
            "enemy_can_act": enemy_can_act,
        })
    ai_coordinator.open_window(
        window,
        window["candidates"],
        window["fallback_proposal"])

func _enemy_ai_gate_reason() -> String:
    if not _remote_ai_enabled or ai_coordinator == null \
            or not engine.battle_flow.can_act(engine.enemy):
        return ""
    var ai_state := str(ai_coordinator.state)
    if ai_state == ActionWindowAiCoordinatorScript.THINKING:
        return "敌方仍在思考，暂时不能确认出牌或结束回合"
    if ai_state in [
            ActionWindowAiCoordinatorScript.READY,
            ActionWindowAiCoordinatorScript.FALLBACK_READY] \
            and engine.has_locked_enemy_action():
        return ""
    return "敌方行动尚未准备完成"

func _resolve_external_enemy_action_and_continue() -> void:
    if _resolving_external_enemy or not engine.has_locked_enemy_action():
        return
    _resolving_external_enemy = true
    var result: Dictionary = engine.resolve_external_enemy_action()
    if result.get("success", false):
        _ai_adapter.record_action_result(ai_coordinator, result)
    _resolving_external_enemy = false
    _complete_ai_round_if_needed()
    if result.get("success", false) and engine.battle_state == "active" \
            and (engine.battle_flow.can_act(engine.player) \
                or engine.battle_flow.can_act(engine.enemy)):
        _open_current_action_window()
    elif ai_coordinator != null and not engine.battle_flow.can_act(engine.player) \
            and not engine.battle_flow.can_act(engine.enemy):
        ai_coordinator.close_window()

func _complete_ai_round_if_needed() -> void:
    if ai_coordinator == null or not engine.round_ended \
            or engine.turn_number <= _last_ai_completed_round:
        return
    ai_coordinator.complete_round(engine.turn_number)
    _last_ai_completed_round = engine.turn_number

func _on_ai_coordinator_state_changed(_snapshot: Dictionary) -> void:
    state_changed.emit()

func _on_ai_proposal_locked(
        window_id: String,
        _proposal,
        metadata: Dictionary) -> void:
    engine.game_log.record_system(
        "info",
        "remote_ai_decision",
        "敌方 AI 行动提案已准备",
        "远程回答" if str(metadata.get("source", "")) == "remote" else "本地 Utility 接管",
        {
            "window_id": window_id,
            "source": str(metadata.get("source", "")),
        })
    if not engine.battle_flow.can_act(engine.player) \
            and engine.battle_flow.can_act(engine.enemy):
        _resolve_external_enemy_action_and_continue()
    state_changed.emit()

func _on_ai_fallback_used(window_id: String, reason: Dictionary) -> void:
    engine.game_log.record_system(
        "warning",
        "remote_ai_fallback",
        "远程 AI 已由本地 Utility 接管",
        str(reason.get("message", "远程 AI 不可用")),
        {
            "window_id": window_id,
            "error_code": str(reason.get("error_code", "")),
        })

func _on_ai_window_failed(window_id: String, error: Dictionary) -> void:
    if engine.battle_flow.can_act(engine.enemy):
        engine.forfeit_actor_actions(
            engine.enemy,
            str(error.get("message", "敌方没有合法行动")))
    if engine.external_round_end_requested and not engine.round_ended:
        engine.end_player_turn()
    engine.game_log.record_system(
        "error",
        "remote_ai_window",
        "敌方行动窗口失败",
        str(error.get("message", "未知错误")),
        {"window_id": window_id})
    _complete_ai_round_if_needed()
    state_changed.emit()

func _on_engine_state_changed() -> void:
    _capture_trigger_history()
    state_changed.emit()

func _capture_trigger_history() -> void:
    var history: Array = engine.trigger_queue.history
    if _history_cursor > history.size():
        _history_cursor = 0
    while _history_cursor < history.size():
        var entry: Dictionary = history[_history_cursor]
        _event_queue.append(BattleEventScript.new({
            "type": "trigger_resolved",
            "serial": _event_serial,
            "timing": str(entry.get("timing", "")),
            "label": str(entry.get("label", "")),
            "source": str(entry.get("source", "")),
            "status": str(entry.get("status", "")),
            "detail": str(entry.get("detail", "")),
        }))
        _event_serial += 1
        _history_cursor += 1

func _record_command_rejected(command_type: String, reason: String) -> void:
    var log_entry: Dictionary = engine.game_log.record_system(
        "warning",
        "battle_command",
        "战斗命令被拒绝",
        reason,
        {"command": command_type})
    _event_queue.append(BattleEventScript.new({
        "type": "command_rejected",
        "serial": _event_serial,
        "log_serial": log_entry["serial"],
        "command": command_type,
        "reason": reason,
    }))
    _event_serial += 1

func _side_snapshot(side) -> Dictionary:
    var equipped_inner_skills: Array = []
    for inner_skill_id in side.equipped_inner_skill_ids:
        equipped_inner_skills.append(
            engine.inner_skill_repository.get_inner_skill(inner_skill_id))
    var consumables: Array = []
    for consumable_id in side.consumable_ids:
        var consumable: Dictionary = engine.consumable_repository.get_consumable(consumable_id).duplicate(true)
        consumable["targeting_limits"] = engine.consumable_repository.target_limits(consumable_id)
        consumables.append(consumable)
    return {
        "name": side.name,
        "life": side.life,
        "max_life": side.max_life,
        "defense": side.defense,
        "hand_limit": side.current_hand_limit(),
        "draw_count": side.draw_pile.size(),
        "hand_count": side.hand.size(),
        "staging_count": side.staging.size(),
        "discard_count": side.discard_pile.size(),
        "deck_count": side.all_zone_cards().size(),
        "temporarily_removed_count": side.temporarily_removed_cards.size(),
        "draw_pile": _card_snapshots(side.draw_pile),
        "hand": _card_snapshots(side.hand),
        "staging": _card_snapshots(side.staging),
        "discard_pile": _card_snapshots(side.discard_pile),
        "temporarily_removed": _card_snapshots(side.temporarily_removed_cards),
        "stacks": side.stacks.duplicate(true),
        "equipped_inner_skill_ids": side.equipped_inner_skill_ids.duplicate(),
        "equipped_inner_skills": equipped_inner_skills,
        "technique_slot_index": side.technique_slot_index,
        "consumable_ids": side.consumable_ids.duplicate(),
        "consumables": consumables,
        "consumable_limit": side.consumable_limit,
        "insight_multipliers": side.insight_multipliers.duplicate(true),
        "owned_technique_ids": side.owned_technique_ids.duplicate(),
    }

func _safe_preview_snapshot(preview: Dictionary) -> Dictionary:
    if preview.is_empty():
        return {}
    return {
        "valid": bool(preview.get("valid", false)),
        "hand": _hand_result_snapshot(preview.get("hand", {})),
        "cards": _card_snapshots(preview.get("cards", [])),
        "values": preview.get("values", {}).duplicate(true),
        "condition": preview.get("condition", {}).duplicate(true),
        "intent": preview.get("intent", {}).duplicate(true),
        "technique_id": str(preview.get("technique_id", "")),
        "next_technique_id": str(preview.get("next_technique_id", "")),
        "technique": preview.get("technique", {}).duplicate(true),
        "next_technique": preview.get("next_technique", {}).duplicate(true),
    }

func _hand_result_snapshot(hand_result: Dictionary) -> Dictionary:
    if hand_result.is_empty():
        return {}
    return {
        "id": str(hand_result.get("id", "")),
        "name": str(hand_result.get("name", "")),
        "multiplier": int(hand_result.get("multiplier", 0)),
        "strength": int(hand_result.get("strength", 0)),
        "royal": bool(hand_result.get("royal", false)),
        "contributing_card_ids": _card_ids(hand_result.get("contributing", [])),
    }

func _card_snapshots(cards: Array) -> Array:
    var result: Array = []
    for card in cards:
        result.append(card.to_dict())
    return result

func _card_ids(cards: Array) -> Array[String]:
    var result: Array[String] = []
    for card in cards:
        result.append(str(card.id))
    return result
