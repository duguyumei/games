extends Control

signal battle_finished(outcome: String)

const CombatEngineScript = preload("res://core/combat_engine.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const BattleUiMapperScript = preload("res://ui/battle_ui_mapper.gd")
const BattleHudScript = preload("res://ui/components/battle_hud.gd")

var battle_session: BattleSession = null
var run_progress: RunProgressSnapshot
var battle_configuration: Dictionary = {}
var selected_ids: Array[String] = []
var active_consumable_slot := -1
var active_log_channel := "battle"
var battle_hud

var _battle_finish_emitted := false
var _action_preview: Dictionary = {}
var _notification := ""
var _display_action_index := 1
var _last_turn_number := -1

func _ready() -> void:
    _ensure_battle_session()
    _assemble_hud()
    battle_session.state_changed.connect(_refresh)
    _reset_battle(int(battle_configuration.get("content_seed", 2308)))

func _process(_delta: float) -> void:
    battle_session.poll_ai_timeout()

func configure_battle(configuration: Dictionary) -> void:
    battle_configuration = configuration.duplicate(true)

func configure_battle_session(session: BattleSession) -> void:
    if session != null:
        battle_session = session

func _ensure_battle_session() -> void:
    if battle_session == null:
        battle_session = BattleSessionScript.new(CombatEngineScript.new())

func configure_ai_provider(provider) -> void:
    battle_session.use_ai_provider(provider)

func configure_ai_provider_settings(config: Dictionary) -> void:
    battle_session.configure_ai_provider(config)

func configure_run_context(shared_game_log, progress_snapshot: RunProgressSnapshot) -> void:
    if shared_game_log == null:
        return
    battle_session.use_game_log(shared_game_log)
    run_progress = progress_snapshot

func player_progress_snapshot() -> RunProgressSnapshot:
    return battle_session.player_progress_snapshot()

func final_result():
    return battle_session.final_result()

func close_battle() -> bool:
    return battle_session.close_battle()

func _assemble_hud() -> void:
    battle_hud = BattleHudScript.new()
    battle_hud.configure_mode(RuntimeProfileScript.current().allows_debug_menu())
    battle_hud.card_pressed.connect(_on_card_pressed)
    battle_hud.confirm_requested.connect(_confirm_play)
    battle_hud.end_turn_requested.connect(_end_turn)
    battle_hud.start_turn_requested.connect(_start_turn)
    battle_hud.consumable_selected.connect(_select_consumable_slot)
    battle_hud.consumable_use_requested.connect(_use_active_consumable)
    battle_hud.reset_requested.connect(_reset_battle)
    battle_hud.debug_channel_toggle_requested.connect(_toggle_log_channel)
    add_child(battle_hud)

func _reset_battle(seed: int = 2308) -> void:
    selected_ids.clear()
    active_consumable_slot = -1
    _action_preview.clear()
    _notification = ""
    _battle_finish_emitted = false
    _display_action_index = 1
    _last_turn_number = -1
    var configuration := battle_configuration.duplicate(true)
    configuration["content_seed"] = seed
    battle_configuration["content_seed"] = seed
    battle_session.setup_battle(configuration, run_progress)
    battle_session.execute({"type": "start_turn"})
    _refresh()

func _start_turn() -> void:
    selected_ids.clear()
    _action_preview.clear()
    var current := battle_session.snapshot()
    if current.battle_state != "active":
        _refresh()
        return
    if current.actions_available > 0 or current.enemy_actions_available > 0:
        _notification = "当前行动尚未结束"
        _refresh()
        return
    if not current.round_ended:
        battle_session.execute({"type": "end_turn"})
    var result := battle_session.execute({"type": "start_turn"})
    if not result.success:
        _notification = str(result.reason_or("暂时不能补牌"))
    _refresh()

func _end_turn() -> void:
    selected_ids.clear()
    active_consumable_slot = -1
    _action_preview.clear()
    var result := battle_session.execute({"type": "end_turn"})
    _notification = "" if result.success else str(result.reason_or("暂时不能结束回合"))
    _refresh()

func _confirm_play() -> void:
    var result := battle_session.execute({
        "type": "play_cards",
        "card_ids": selected_ids.duplicate(),
    })
    if result.success:
        _display_action_index += 1
        _notification = ""
    else:
        _notification = str(result.reason_or("无法出招"))
    selected_ids.clear()
    _action_preview.clear()
    _refresh()

func _select_consumable_slot(slot_index: int) -> void:
    var player_state := battle_session.snapshot().player
    if slot_index < 0 or slot_index >= player_state.consumables.size():
        return
    active_consumable_slot = -1 if active_consumable_slot == slot_index else slot_index
    selected_ids.clear()
    _action_preview.clear()
    _refresh()

func _use_active_consumable() -> void:
    if active_consumable_slot < 0:
        return
    var result := battle_session.execute({
        "type": "use_consumable",
        "slot_index": active_consumable_slot,
        "card_ids": selected_ids.duplicate(),
    })
    if result.success:
        selected_ids = _retained_card_ids(selected_ids, battle_session.snapshot().player.hand)
        active_consumable_slot = -1
        run_progress = battle_session.player_progress_snapshot()
        _notification = ""
    else:
        _notification = str(result.reason_or("无法使用消耗品"))
    _action_preview.clear()
    _refresh()

func _on_card_pressed(card_id: String) -> void:
    if selected_ids.has(card_id):
        selected_ids.erase(card_id)
    elif active_consumable_slot >= 0:
        if not _can_append_consumable_target():
            return
        selected_ids.append(card_id)
    elif selected_ids.size() < 5:
        selected_ids.append(card_id)
    else:
        _notification = "一次最多选择 5 张真气"
        _refresh()
        return
    _update_action_preview()
    _refresh()

func _can_append_consumable_target() -> bool:
    var consumables: Array = battle_session.snapshot().player.consumables
    if active_consumable_slot >= consumables.size():
        return false
    var limits: Dictionary = consumables[active_consumable_slot].get("targeting_limits", {})
    if str(limits.get("zone", "none")) == "none":
        _notification = "该消耗品不需要选择真气"
        return false
    if selected_ids.size() >= int(limits.get("maximum", 0)):
        _notification = "该消耗品至多选择 %d 张真气" % int(limits.get("maximum", 0))
        return false
    return true

func _update_action_preview() -> void:
    if active_consumable_slot >= 0 or selected_ids.is_empty():
        _action_preview.clear()
        return
    _action_preview = battle_session.preview(selected_ids)
    _notification = "" if bool(_action_preview.get("valid", false)) else str(
        _action_preview.get("reason", "选择无效"))

func _refresh() -> void:
    if battle_hud == null or battle_session == null:
        return
    var current := battle_session.snapshot()
    if _last_turn_number != current.turn_number:
        _last_turn_number = current.turn_number
        _display_action_index = 1
    if active_consumable_slot >= current.player.consumables.size():
        active_consumable_slot = -1
    var ui_snapshot := BattleUiMapperScript.map(current, {
        "selected_ids": selected_ids,
        "active_consumable_slot": active_consumable_slot,
        "action_preview": _action_preview,
        "can_use_consumable": _active_consumable_targets_valid(current.player),
        "active_log_channel": active_log_channel,
        "seed": int(battle_configuration.get("content_seed", 2308)),
        "notification": _notification,
        "action_index": _display_action_index,
    })
    battle_hud.present(ui_snapshot)
    if current.battle_state != "active" and not _battle_finish_emitted:
        _battle_finish_emitted = true
        run_progress = battle_session.player_progress_snapshot()
        battle_finished.emit.call_deferred(current.battle_state)

func _active_consumable_targets_valid(player_state: BattleSideSnapshot) -> bool:
    if active_consumable_slot < 0 or active_consumable_slot >= player_state.consumables.size():
        return false
    return bool(battle_session.validate_consumable_targets(
        active_consumable_slot, selected_ids).get("ok", false))

func _toggle_log_channel() -> void:
    active_log_channel = "system" if active_log_channel == "battle" else "battle"
    _refresh()

func _retained_card_ids(card_ids: Array[String], hand: Array) -> Array[String]:
    var present_ids: Array[String] = []
    for card_value in hand:
        present_ids.append(str(card_value.get("id", "")))
    return card_ids.filter(func(card_id: String): return present_ids.has(card_id))
