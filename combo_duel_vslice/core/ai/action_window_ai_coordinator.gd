class_name ActionWindowAiCoordinator
extends RefCounted

signal state_changed(snapshot)
signal proposal_locked(window_id, proposal, metadata)
signal fallback_used(window_id, reason)
signal window_failed(window_id, error)

const BattleConversationScript = preload("res://core/ai/ai_battle_conversation.gd")
const DecisionGatewayScript = preload("res://core/ai/ai_decision_gateway.gd")
const DecisionObservationScript = preload("res://core/ai/ai_decision_observation.gd")
const HistoryProjectorScript = preload("res://core/ai/ai_history_projector.gd")
const ConversationStoreScript = preload("res://core/ai/ai_conversation_store.gd")

const IDLE := "idle"
const THINKING := "thinking"
const READY := "ready"
const FALLBACK_READY := "fallback_ready"
const NO_ENEMY_ACTION := "no_enemy_action"
const FAILED := "failed"

const DEFAULT_SETTINGS := {
    "timeout_msec": 30000,
    "compression_enabled": true,
    "compression_interval_rounds": 5,
    "max_retries": 1,
    "intent_visibility": "full",
}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var conversation
var gateway
var history_projector := HistoryProjectorScript.new()
var conversation_store = ConversationStoreScript.new()
var proposal_locker: Callable
var clock: Callable
var conversation_path: String = ""
var conversation_autosave_enabled: bool = false

var state: String = IDLE
var current_window_id: String = ""
var current_decision_id: String = ""
var current_state_hash: String = ""
var current_round_number: int = 0
var current_action_index: int = 0
var enemy_can_act: bool = false
var player_can_act: bool = false
var decision_source: String = ""
var public_intent: Dictionary = {}
var last_error: Dictionary = {}
var last_metadata: Dictionary = {}

var _fallback_proposal = null
var _started_at_msec: int = 0
var _history_sequence: int = 0

func configure(
        context,
        provider,
        setting_overrides: Dictionary = {},
        locker: Callable = Callable(),
        clock_override: Callable = Callable()):
    settings = DEFAULT_SETTINGS.duplicate(true)
    settings.merge(setting_overrides, true)
    settings["timeout_msec"] = maxi(1, int(settings.get("timeout_msec", 30000)))
    settings["compression_interval_rounds"] = maxi(
        1, int(settings.get("compression_interval_rounds", 5)))
    settings["max_retries"] = maxi(0, int(settings.get("max_retries", 1)))
    proposal_locker = locker
    clock = clock_override
    conversation = BattleConversationScript.new().configure(context, settings)
    conversation_path = str(settings.get("conversation_path", ""))
    conversation_autosave_enabled = bool(
        settings.get("autosave_conversation", false)) \
        and conversation_path != ""
    conversation.changed.connect(_persist_conversation)
    gateway = DecisionGatewayScript.new(provider)
    gateway.decision_ready.connect(_on_decision_ready)
    gateway.decision_failed.connect(_on_decision_failed)
    state = IDLE
    current_window_id = ""
    current_decision_id = ""
    _fallback_proposal = null
    _history_sequence = 0
    return self

func use_provider(provider) -> void:
    if gateway != null:
        gateway.use_provider(provider)

func open_window(
        values: Dictionary,
        candidates: Array,
        fallback_proposal = null) -> Dictionary:
    if gateway == null or conversation == null:
        return {"success": false, "reason": "AI 行动窗口协调器尚未配置"}
    if state == THINKING and current_decision_id != "":
        state = IDLE
        gateway.cancel_decision(current_decision_id, "新的行动窗口已开始")
    current_window_id = str(values.get("window_id", ""))
    current_decision_id = str(values.get("decision_id", current_window_id))
    current_state_hash = str(values.get("state_hash", ""))
    current_round_number = int(values.get("round_number", 0))
    current_action_index = int(values.get("action_index", 0))
    enemy_can_act = bool(values.get("enemy_can_act", false))
    player_can_act = bool(values.get("player_can_act", false))
    decision_source = ""
    public_intent.clear()
    last_error.clear()
    last_metadata.clear()
    _fallback_proposal = fallback_proposal
    record_public_event({
        "round_number": current_round_number,
        "action_index": current_action_index,
        "window_id": current_window_id,
        "event_type": "action_window_opened",
        "actor_id": "system",
        "visibility": "public",
        "payload": {
            "player_can_act": player_can_act,
            "enemy_can_act": enemy_can_act,
        },
    })
    if not enemy_can_act:
        state = NO_ENEMY_ACTION
        _emit_state_changed()
        return {"success": true, "requested": false, "state": state}
    if current_window_id == "" or current_decision_id == "" or current_state_hash == "":
        return _fail_window({
            "error_code": "INVALID_WINDOW",
            "message": "AI 行动窗口缺少 ID 或状态哈希",
        })
    var observation = values.get("observation")
    if observation is Dictionary:
        observation = DecisionObservationScript.new().configure(observation)
    if observation == null or not observation.has_method("is_valid") \
            or not observation.is_valid():
        return _use_fallback({
            "error_code": "INVALID_OBSERVATION",
            "message": "AI 行动窗口观察无效",
        })
    if candidates.is_empty():
        return _use_fallback({
            "error_code": "NO_REMOTE_CANDIDATES",
            "message": "没有可发送给远程 AI 的合法候选",
        })
    state = THINKING
    _started_at_msec = _now_msec()
    _emit_state_changed()
    var begin_result: Dictionary = gateway.begin_decision(
        conversation, observation, candidates)
    if not begin_result.get("success", false) and state == THINKING:
        return _use_fallback({
            "error_code": "GATEWAY_START_FAILED",
            "message": str(begin_result.get("reason", "AI 请求无法开始")),
        })
    return {
        "success": true,
        "requested": true,
        "state": state,
        "decision_id": current_decision_id,
    }

func record_public_event(raw_event: Dictionary) -> Dictionary:
    var event_values := raw_event.duplicate(true)
    if not event_values.has("sequence"):
        event_values["sequence"] = _history_sequence
    _history_sequence = maxi(
        _history_sequence,
        int(event_values.get("sequence", -1)) + 1)
    var projected: Dictionary = history_projector.project(event_values)
    if not projected.is_empty() and conversation != null:
        conversation.record_public_event(projected)
    return projected

func complete_round(round_number: int) -> bool:
    return conversation != null and conversation.complete_round(round_number)

func poll_timeout(now_msec: int = -1) -> bool:
    if state != THINKING:
        return false
    var current_time := now_msec if now_msec >= 0 else _now_msec()
    if current_time - _started_at_msec < int(settings.get("timeout_msec", 30000)):
        return false
    return gateway.cancel_decision(current_decision_id, "AI 请求超时")

func force_timeout() -> bool:
    if state != THINKING:
        return false
    return gateway.cancel_decision(current_decision_id, "AI 请求超时")

func can_player_confirm() -> bool:
    if not player_can_act:
        return false
    return not enemy_can_act or state in [READY, FALLBACK_READY]

func close_window() -> void:
    if state == THINKING and current_decision_id != "":
        state = IDLE
        gateway.cancel_decision(current_decision_id, "行动窗口已关闭")
    state = IDLE
    current_window_id = ""
    current_decision_id = ""
    enemy_can_act = false
    player_can_act = false
    decision_source = ""
    public_intent.clear()
    _fallback_proposal = null
    _emit_state_changed()

func snapshot() -> Dictionary:
    return {
        "state": state,
        "window_id": current_window_id,
        "decision_id": current_decision_id,
        "state_hash": current_state_hash,
        "round_number": current_round_number,
        "action_index": current_action_index,
        "enemy_can_act": enemy_can_act,
        "player_can_act": player_can_act,
        "can_player_confirm": can_player_confirm(),
        "decision_source": decision_source,
        "public_intent": public_intent.duplicate(true),
        "last_error": last_error.duplicate(true),
        "last_metadata": last_metadata.duplicate(true),
    }

func conversation_snapshot() -> AiConversationSnapshot:
    return conversation.snapshot() if conversation != null else null

func save_conversation(path: String = "") -> bool:
    if conversation == null:
        return false
    var target_path := path if path != "" else conversation_path
    if target_path == "":
        return false
    return conversation_store.save(target_path, conversation.snapshot())

func _on_decision_ready(decision_id: String, proposal, metadata: Dictionary) -> void:
    if decision_id != current_decision_id or state != THINKING:
        return
    var enriched := metadata.duplicate(true)
    enriched["elapsed_msec"] = maxi(0, _now_msec() - _started_at_msec)
    _lock_proposal(proposal, "remote", enriched)

func _on_decision_failed(decision_id: String, error: Dictionary) -> void:
    if decision_id != current_decision_id or state != THINKING:
        return
    _use_fallback(error)

func _use_fallback(error: Dictionary) -> Dictionary:
    last_error = error.duplicate(true)
    if _fallback_proposal == null or not bool(_fallback_proposal.accepted):
        return _fail_window(error)
    fallback_used.emit(current_window_id, error.duplicate(true))
    return _lock_proposal(_fallback_proposal, "local_utility", {
        "fallback_reason": error.duplicate(true),
        "elapsed_msec": maxi(0, _now_msec() - _started_at_msec),
    })

func _lock_proposal(proposal, source: String, metadata: Dictionary) -> Dictionary:
    var locked := false
    if proposal_locker.is_valid():
        var lock_result = proposal_locker.call(proposal)
        locked = (
            bool(lock_result.get("success", false))
            if lock_result is Dictionary
            else bool(lock_result))
    if not locked:
        var error := {
            "error_code": "LOCAL_REVALIDATION_FAILED",
            "message": "AI 候选在本地复核时已经失效",
        }
        if source == "remote" and _fallback_proposal != proposal:
            return _use_fallback(error)
        return _fail_window(error)
    decision_source = source
    last_metadata = metadata.duplicate(true)
    public_intent = _public_intent_for(proposal)
    state = READY if source == "remote" else FALLBACK_READY
    if source != "remote" and conversation != null:
        conversation.record_local_outcome(
            current_decision_id,
            "fallback_selected",
            {
                "source": source,
                "proposal": proposal.snapshot(),
                "metadata": metadata.duplicate(true),
            })
    proposal_locked.emit(current_window_id, proposal, {
        "source": source,
        "public_intent": public_intent.duplicate(true),
        "provider": metadata.duplicate(true),
    })
    _emit_state_changed()
    return {"success": true, "state": state, "source": source}

func _fail_window(error: Dictionary) -> Dictionary:
    state = FAILED
    last_error = error.duplicate(true)
    if conversation != null:
        conversation.record_local_outcome(
            current_decision_id,
            "window_failed",
            error)
    window_failed.emit(current_window_id, error.duplicate(true))
    _emit_state_changed()
    return {
        "success": false,
        "state": state,
        "reason": str(error.get("message", "AI 行动窗口失败")),
    }

func _public_intent_for(proposal) -> Dictionary:
    if str(settings.get("intent_visibility", "full")) != "full":
        return {"ready": true}
    var intent: Dictionary = proposal.preview.get("intent", {})
    return {
        "ready": true,
        "damage": maxi(0, int(intent.get("damage", 0))),
        "defense": maxi(0, int(intent.get("defense", 0))),
        "segments": maxi(0, int(intent.get("segments", 0))),
        "combo": bool(intent.get("combo", false)),
    }

func _emit_state_changed() -> void:
    state_changed.emit(snapshot())

func _persist_conversation() -> void:
    if conversation_autosave_enabled and conversation != null:
        conversation_store.save(conversation_path, conversation.snapshot())

func _now_msec() -> int:
    return int(clock.call()) if clock.is_valid() else Time.get_ticks_msec()
