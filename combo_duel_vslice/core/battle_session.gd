class_name BattleSession
extends RefCounted

## 战斗用例门面，统一命令、快照、事件与远程 AI 协调边界。
##
## 会话只编排应用流程并把领域结果转换为 CommandResult；具体牌型、效果、
## 伤害和回合规则仍由 CombatEngine 下属组件负责，不在门面复制规则。

signal state_changed

const CombatEngineScript = preload("res://core/combat_engine.gd")
const BattleSnapshotScript = preload("res://core/battle_snapshot.gd")
const BattleEventScript = preload("res://core/battle_event.gd")
const BattleCommandScript = preload("res://core/battle_command_dto.gd")
const CommandResultScript = preload("res://core/command_result.gd")
const BattleSetupServiceScript = preload("res://core/battle_setup_service.gd")
const ActionWindowAiCoordinatorScript = preload("res://core/ai/action_window_ai_coordinator.gd")
const BattleAiAdapterScript = preload("res://core/ai/battle_ai_adapter.gd")
const AiProviderFactoryScript = preload("res://core/ai/providers/ai_provider_factory.gd")
const AiConversationStoreScript = preload("res://core/ai/ai_conversation_store.gd")
const AiDecisionTraceStoreScript = preload(
    "res://core/ai/ai_decision_trace_store.gd")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const BattleFinalResultDTOScript = preload(
    "res://core/battle_final_result_dto.gd")

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
var _ai_trace_store = AiDecisionTraceStoreScript.new()
var _ai_trace_path: String = ""
var runtime_profile
var _battle_binding: Dictionary = {}

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

func setup_battle(
        configuration: Dictionary = {},
        progress_snapshot: RunProgressSnapshot = null) -> bool:
    close_battle()
    _battle_binding.clear()
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
    var act := int(configuration.get("act", 1))
    var node_type := str(configuration.get("node_type", "combat"))
    var boss_variant := int(configuration.get("boss_variant", -1))
    var runtime_enabled := bool(_ai_runtime_profile.get("enabled", false))
    _remote_ai_enabled = (
        bool(battle.get("use_remote_ai", false)) or runtime_enabled) \
        and use_enemy_ai
    _ai_settings = _ai_runtime_profile.get(
        "conversation", {}).duplicate(true)
    _ai_settings.merge(configuration.get("ai_settings", {}), true)
    var storage: Dictionary = _ai_runtime_profile.get("storage", {})
    _ai_settings["autosave_conversation"] = bool(
        _ai_settings.get("autosave_conversation",
            storage.get("autosave_conversation", false)))
    _ai_settings["autosave_decision_trace"] = bool(
        _ai_settings.get("autosave_decision_trace",
            storage.get("autosave_decision_trace", false)))
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
    _ai_trace_path = str(_ai_settings.get("decision_trace_path", ""))
    if _ai_trace_path == "":
        _ai_trace_path = _ai_trace_store.path_for_battle(
            _ai_battle_id,
            str(storage.get("decision_trace_directory",
                AiDecisionTraceStoreScript.DEFAULT_DIRECTORY)))
    _ai_settings["decision_trace_path"] = _ai_trace_path
    _battle_binding = {
        "node_id": str(configuration.get("node_id", "")),
        "act": act,
        "node_type": node_type,
        "content_id": str(configuration.get("content_id", "")),
        "content_seed": int(configuration.get("content_seed", 2308)),
    }
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
        if entry_kind == "formal":
            var formal_setup: Dictionary = _battle_setup_service.apply_formal_enemy(
                engine.enemy,
                act,
                node_type,
                int(configuration.get("content_seed", 2308)),
                boss_variant,
                engine.rng)
            if not formal_setup.get("success", false):
                engine.game_log.record_system(
                    "error", "enemy_repository", "正式敌人装配失败",
                    str(formal_setup.get("reason", "未知错误")))
                return false
            engine.enemy.name = str(formal_setup["entry"].get("name", engine.enemy.name))
            engine.initialize_base_momentum_caps(true)
            engine.enemy_sequence_book.configure(formal_setup["sequences"])
            _battle_setup_service.seed_owned_techniques(
                engine.enemy, engine.enemy_sequence_book)
            engine.enemy_ai_policy = formal_setup["ai_policy"]
            engine._sync_action_service_modes()
        var progress_setup: Dictionary = _battle_setup_service.apply_non_deck_progress(
            engine.player, progress_snapshot)
        if not progress_setup.get("success", false):
            engine.game_log.record_system(
                "error", "player_progress", "玩家战斗装配失败",
                str(progress_setup.get("reason", "未知错误")))
            return false
        var progression_setup: Dictionary = \
            _battle_setup_service.apply_player_technique_progression(
            engine.player, engine.sequence_book, progress_snapshot)
        if not progression_setup.get("success", false):
            engine.game_log.record_system(
                "error", "player_progress", "玩家功法配装失败",
                str(progression_setup.get("reason", "未知错误")))
            return false
        # 非牌组进度会装配最终被动来源，但基础上限仍只读取已经装配好的牌库。
        engine.initialize_base_momentum_caps(true)
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

func execute(command: Dictionary) -> CommandResult:
    return _execute_command(BattleCommandScript.new().configure(command))

func _execute_command(command: BattleCommandDto) -> CommandResult:
    var command_type: String = str(command.type)
    var result: Dictionary
    match command_type:
        "start_turn":
            if engine.battle_state != "active":
                result = {"success": false, "reason": "战斗已经结束"}
            else:
                var drawn: Array = engine.start_player_turn()
                result = {
                    "success": true,
                    "drawn_card_ids": _card_ids(drawn),
                    "pending_choice": engine.has_pending_choice(),
                    "choice_request": engine.pending_choice_snapshot(),
                    "action_window_ready": engine.round_service.is_action_window_ready(),
                }
                if _remote_ai_enabled and not engine.has_pending_choice():
                    _open_current_action_window()
        "end_turn":
            if engine.battle_state != "active":
                result = {"success": false, "reason": "战斗已经结束"}
            elif engine.has_pending_choice():
                result = {"success": false, "reason": "正在等待选择，请先完成选择"}
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
            result = engine.resolve_choice(
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
    _complete_ai_trace_if_terminal()
    return CommandResultScript.from_dict(command_type, result)

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

func apply_player_progress_from(progress_snapshot: RunProgressSnapshot) -> void:
    if progress_snapshot == null:
        return
    _player_run_deck = _battle_setup_service.run_deck_from_progress(progress_snapshot)
    engine.replace_player_deck(_player_run_deck.create_battle_cards(), true)
    var result: Dictionary = _battle_setup_service.apply_non_deck_progress(
        engine.player, progress_snapshot)
    if not result.get("success", false):
        push_error("玩家战斗装配失败：%s" % str(result.get("reason", "未知错误")))
        return
    var progression_result: Dictionary = \
        _battle_setup_service.apply_player_technique_progression(
            engine.player, engine.sequence_book, progress_snapshot)
    if not progression_result.get("success", false):
        push_error("玩家功法配装失败：%s" % str(
            progression_result.get("reason", "未知错误")))
        return
    engine.initialize_base_momentum_caps(true)

func player_progress_snapshot() -> RunProgressSnapshot:
    return _battle_setup_service.capture_progress(engine.player, _player_run_deck)

## 只在战斗已经结束后建立正式结果；active 永远没有 BattleFinalResultDTO。
func final_result():
    if engine.battle_state not in BattleFinalResultDTOScript.TERMINAL_STATES:
        return null
    var values := _battle_binding.duplicate(true)
    values.merge({
        "schema_version": BattleFinalResultDTOScript.SCHEMA_VERSION,
        "battle_state": engine.battle_state,
        "detail": engine.battle_state_detail,
        "turn_number": engine.turn_number,
    }, true)
    return BattleFinalResultDTOScript.from_dict(values)

## 关闭当前远程 AI 行动窗口。调用方无需接触 provider 或 gateway。
func close_battle() -> bool:
    var had_pending_remote_request := false
    if ai_coordinator != null:
        had_pending_remote_request = (
            str(ai_coordinator.state)
            == ActionWindowAiCoordinatorScript.THINKING)
        if engine != null and engine.battle_state != "active":
            ai_coordinator.complete_battle_trace(_ai_battle_summary())
        ai_coordinator.close_window()
    if engine != null:
        engine.use_external_enemy_actions(false)
        if engine.enemy_planning_service != null:
            engine.enemy_planning_service.clear_action_lock()
    _remote_ai_enabled = false
    return had_pending_remote_request

func _ai_battle_summary() -> Dictionary:
    var trace: Dictionary = ai_coordinator.decision_trace_snapshot() \
        if ai_coordinator != null else {}
    var windows: Array = trace.get("windows", [])
    var remote_success := 0
    var fallback_count := 0
    var total_elapsed := 0
    var prompt_tokens := 0
    var completion_tokens := 0
    var missed_lethal := 0
    var missed_survival := 0
    for window in windows:
        var selected: Dictionary = window.get("selected", {})
        if str(selected.get("source", "")) == "remote":
            remote_success += 1
        elif not selected.is_empty():
            fallback_count += 1
        total_elapsed += int(selected.get("elapsed_msec", 0))
        prompt_tokens += int(selected.get("usage", {}).get("prompt_tokens", 0))
        completion_tokens += int(selected.get("usage", {}).get("completion_tokens", 0))
        var diagnostics: Dictionary = window.get("candidate_diagnostics", {})
        var chosen_diagnostic := str(selected.get("diagnostic_candidate_id", ""))
        var has_lethal := false
        var has_survival := false
        var chose_lethal := false
        var chose_survival := false
        for candidate in diagnostics.get("candidates", []):
            var reasons: Array = candidate.get("hard_protection", {}).get("reasons", [])
            has_lethal = has_lethal or reasons.has("lethal")
            has_survival = has_survival or reasons.has("survival")
            if str(candidate.get("diagnostic_candidate_id", "")) == chosen_diagnostic:
                chose_lethal = reasons.has("lethal")
                chose_survival = reasons.has("survival")
        missed_lethal += 1 if has_lethal and not chose_lethal else 0
        missed_survival += 1 if has_survival and not chose_survival else 0
    var validation_failures := 0
    var timeouts := 0
    for exchange in ai_coordinator.conversation.exchanges:
        validation_failures += 1 if str(exchange.get("kind", "")) == "validation_failed" else 0
        timeouts += 1 if str(exchange.get("error_code", "")) in [
            "REQUEST_TIMEOUT", "TIMEOUT"] else 0
    return {
        "battle_result": "enemy_won" if engine.battle_state == "player_defeat" \
            else "player_won" if engine.battle_state == "player_victory" \
            else engine.battle_state,
        "enemy_id": str(_battle_binding.get("content_id", "")),
        "total_rounds": int(engine.turn_number),
        "decision_count": windows.size(),
        "remote_success_count": remote_success,
        "fallback_count": fallback_count,
        "validation_failure_count": validation_failures,
        "timeout_count": timeouts,
        "missed_lethal_count": missed_lethal,
        "missed_survival_count": missed_survival,
        "total_prompt_tokens": prompt_tokens,
        "total_completion_tokens": completion_tokens,
        "average_elapsed_msec": float(total_elapsed) / float(windows.size()) \
            if not windows.is_empty() else 0.0,
    }

func _complete_ai_trace_if_terminal() -> void:
    if ai_coordinator == null or engine == null or engine.battle_state == "active":
        return
    ai_coordinator.complete_battle_trace(_ai_battle_summary())

func combat_order_labels(technique_name: String = "当前功法") -> Array[String]:
    return engine.combat_order_labels(engine.player, technique_name)

func snapshot() -> BattleSnapshot:
    var ai_snapshot: Dictionary = (
        ai_coordinator.snapshot()
        if _remote_ai_enabled and ai_coordinator != null
        else {
            "state": "local_utility" if engine.enemy_ai_enabled else "disabled",
            "can_player_confirm": true,
            "possible_enemy_intents": engine.enemy_planning_service.possible_enemy_intents.duplicate(true),
        })
    var action_revealed: bool = not engine.last_enemy_action_cards.is_empty()
    var visible_enemy_plan: Dictionary = (
        engine.enemy_planning_service.public_plan(
            engine.last_enemy_preview.get("intent", {}))
        if action_revealed else {})
    var visible_locked_count: int = (
        engine.last_enemy_action_cards.size() if action_revealed else 0)
    return BattleSnapshotScript.from_dict({
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
        "locked_enemy_card_count": visible_locked_count,
        "enemy_plan": visible_enemy_plan,
        "possible_enemy_intents": ai_snapshot.get(
            "possible_enemy_intents", []).duplicate(true),
        "ai_decision": ai_snapshot,
        "pending_choice": engine.pending_choice_snapshot(),
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

func ai_conversation_snapshot() -> AiConversationSnapshot:
    if ai_coordinator == null:
        return null
    return ai_coordinator.conversation_snapshot()

func ai_conversation_path() -> String:
    return _ai_conversation_path

func ai_decision_trace_path() -> String:
    return _ai_trace_path

func ai_decision_trace_snapshot() -> Dictionary:
    return ai_coordinator.decision_trace_snapshot() \
        if ai_coordinator != null else {}

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
        _event_queue.append(BattleEventScript.trigger_history(
            _event_serial, entry))
        _event_serial += 1
        _history_cursor += 1

func _record_command_rejected(command_type: String, reason: String) -> void:
    var log_entry: Dictionary = engine.game_log.record_system(
        "warning",
        "battle_command",
        "战斗命令被拒绝",
        reason,
        {"command": command_type})
    _event_queue.append(BattleEventScript.command_rejected(
        _event_serial,
        command_type,
        reason,
        int(log_entry["serial"])))
    _event_serial += 1

func _side_snapshot(side) -> Dictionary:
    var sequence_book = engine.sequence_book \
        if side == engine.player else engine.enemy_sequence_book
    var poison: Dictionary = side.poison_totals()
    var passive_context := {
        "owner": side,
        "round_number": engine.turn_number,
    }
    var capacity: Dictionary = engine.passive_rule_runtime.resolve_inner_skill_capacity(
        side, side.equipped_inner_skill_ids)
    var execution_counts: Dictionary = engine.passive_rule_runtime.execution_counts_for(
        "action_preview", passive_context)
    var equipped_inner_skills: Array = []
    for inner_entry in engine.passive_rule_runtime.equipped_inner_skill_entries(
            passive_context):
        var definition: Dictionary = inner_entry["definition"].duplicate(true)
        var active := true
        var inactive_reasons: Array[String] = []
        var matching_sources: Array = engine.passive_rule_runtime.collect_sources(
            passive_context).filter(func(source):
                return source.source_instance_key == inner_entry["source_instance_key"])
        for source in matching_sources:
            var handler = engine.passive_rule_registry.handler(source.behavior_id)
            if handler == null or not handler.supported_hooks().has("action_preview"):
                continue
            var activation = engine.passive_rule_runtime.is_source_active(
                source, "action_preview", passive_context)
            if not activation.active:
                active = false
                if activation.reason != "" and not inactive_reasons.has(activation.reason):
                    inactive_reasons.append(activation.reason)
        definition["active"] = active
        definition["inactive_reason"] = "；".join(inactive_reasons)
        definition["source_instance_key"] = inner_entry["source_instance_key"]
        definition["execution_count_preview"] = int(execution_counts.get(
            inner_entry["source_instance_key"], 0))
        equipped_inner_skills.append(definition)
    var consumables: Array = []
    for consumable_id in side.consumable_ids:
        var consumable: Dictionary = engine.consumable_repository.get_consumable(consumable_id).duplicate(true)
        consumable["targeting_limits"] = engine.consumable_repository.target_limits(consumable_id)
        consumables.append(consumable)
    var same_qi_capacity: Dictionary = side.peek_effective_same_qi_capacity_result({
        "round_number": int(engine.turn_number),
        "source_kind": "battle_snapshot",
    })
    var momentum_cap: Dictionary = side.peek_effective_momentum_cap_result({
        "round_number": int(engine.turn_number),
        "source_kind": "battle_snapshot",
    })
    return {
        "name": side.name,
        "experience": side.experience,
        "life": side.life,
        "max_life": side.max_life,
        "base_max_life": side.base_max_life,
        "defense": side.defense,
        "direct_power_fixed": side.direct_power_fixed,
        "direct_power_percent": side.direct_power_percent,
        "momentum_value": side.momentum_value,
        "momentum_cap": int(momentum_cap.get("effective_value", 0)),
        "same_qi_value": side.same_qi_value,
        "same_qi_capacity": int(same_qi_capacity.get("effective_value", 5)),
        "last_successful_technique_hand_id": side.last_successful_technique_hand_id,
        "current_reflection_percent": side.current_reflection_percent,
        "reflection_sources": side.public_reflection_sources(),
        "reflection_true_damage_sources": side.public_reflection_true_damage_sources(),
        "block_sources": side.public_block_sources(),
        "deflection_sources": side.public_deflection_sources(),
        "challenge_records": side.public_challenge_records(),
        "base_hand_limit": side.base_hand_limit(),
        "hand_limit": side.peek_current_hand_limit(),
        "inner_skill_limit": int(capacity["effective_capacity"]),
        "draw_count": side.draw_pile.size(),
        "hand_count": side.hand.size(),
        "occupied_meridian_count": side.occupied_meridian_count(),
        "staging_count": side.staging.size(),
        "discard_count": side.discard_pile.size(),
        "deck_count": side.all_zone_cards().size(),
        "temporarily_removed_count": side.temporarily_removed_cards.size(),
        "poison_hand_count": int(poison["hand_count"]),
        "poison_hand_amount": int(poison["hand_amount"]),
        "poison_draw_pile_count": int(poison["draw_pile_count"]),
        "poison_draw_pile_amount": int(poison["draw_pile_amount"]),
        "poison_total_count": int(poison["total_count"]),
        "poison_total_amount": int(poison["total_amount"]),
        "draw_pile": _card_snapshots(side.draw_pile),
        "hand": _card_snapshots(side.hand),
        "staging": _card_snapshots(side.staging),
        "discard_pile": _card_snapshots(side.discard_pile),
        "temporarily_removed": _card_snapshots(side.temporarily_removed_cards),
        "learned_inner_skill_ids": side.learned_inner_skill_ids.duplicate(),
        "equipped_inner_skill_ids": side.equipped_inner_skill_ids.duplicate(),
        "equipped_inner_skills": equipped_inner_skills,
        "technique_slot_index": side.technique_slot_index,
        "forgotten_inner_skill_count": side.forgotten_inner_skill_count,
        "item_ids": side.item_ids.duplicate(),
        "consumable_ids": side.consumable_ids.duplicate(),
        "consumables": consumables,
        "consumable_limit": side.consumable_limit,
        "hand_proficiency_fixed": side.hand_proficiency_fixed.duplicate(true),
        "hand_technique_progression": side.hand_technique_progression.duplicate(true),
        "owned_technique_ids": side.owned_technique_ids.duplicate(),
        "technique_sequences": sequence_book.public_snapshot(),
        "technique_slot_usage": sequence_book.public_slot_usage_snapshot(),
        "charging_techniques": side.charging_technique_instances(true),
        "public_source_markers": side.source_marker_store.public_projection(),
        "poison_damage_modifier_sources": side.public_poison_damage_modifier_sources(),
    }

func _safe_preview_snapshot(preview: Dictionary) -> Dictionary:
    if preview.is_empty():
        return {}
    return {
        "valid": bool(preview.get("valid", false)),
        "hand": _hand_result_snapshot(preview.get("hand", {})),
        "cards": _card_snapshots(preview.get("cards", [])),
        "values": preview.get("values", {}).duplicate(true),
        "momentum_cap": int(preview.get("momentum_cap", 0)),
        "same_qi": preview.get("same_qi", {}).duplicate(true),
        "same_qi_group": preview.get("same_qi_group", {}).duplicate(true),
        "same_qi_gain": int(preview.get("same_qi_gain", 0)),
        "same_qi_before": int(preview.get("same_qi_before", 0)),
        "same_qi_capacity": int(preview.get("same_qi_capacity", 5)),
        "same_qi_after": int(preview.get("same_qi_after", 0)),
        "same_qi_trigger_count": int(preview.get(
            "same_qi_trigger_count", 0)),
        "reshape_action_confirmed": bool(preview.get("reshape_action_confirmed", false)),
        "reshape_action_results": preview.get(
            "reshape_action_results", {}).duplicate(true),
        "condition": preview.get("condition", {}).duplicate(true),
        "intent": preview.get("intent", {}).duplicate(true),
        "technique_id": str(preview.get("technique_id", "")),
        "slot_instance_id": str(preview.get("slot_instance_id", "")),
        "next_technique_id": str(preview.get("next_technique_id", "")),
        "next_slot_instance_id": str(preview.get("next_slot_instance_id", "")),
        "technique": preview.get("technique", {}).duplicate(true),
        "next_technique": preview.get("next_technique", {}).duplicate(true),
    }

func _hand_result_snapshot(hand_result: Dictionary) -> Dictionary:
    if hand_result.is_empty():
        return {}
    return {
        "id": str(hand_result.get("id", "")),
        "name": str(hand_result.get("name", "")),
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
