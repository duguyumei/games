class_name BattleSession
extends RefCounted

signal state_changed

const CombatEngineScript = preload("res://core/combat_engine.gd")
const BattleSnapshotScript = preload("res://core/battle_snapshot.gd")
const BattleEventScript = preload("res://core/battle_event.gd")
const BattleSetupServiceScript = preload("res://core/battle_setup_service.gd")

var engine
var _battle_setup_service
var _player_run_deck
var _event_queue: Array = []
var _history_cursor: int = 0
var _event_serial: int = 0

func _init(engine_override = null) -> void:
    engine = engine_override if engine_override != null else CombatEngineScript.new()
    _battle_setup_service = BattleSetupServiceScript.new(engine.content_catalog)
    _player_run_deck = _battle_setup_service.run_deck_from_progress(null)
    engine.state_changed.connect(_on_engine_state_changed)

func use_game_log(shared_game_log) -> void:
    engine.use_game_log(shared_game_log)
    _event_queue.clear()
    _history_cursor = 0
    _event_serial = 0

func setup_battle(configuration: Dictionary = {}, progress_snapshot = null) -> bool:
    engine.game_log.clear("battle")
    _event_queue.clear()
    _history_cursor = 0
    _event_serial = 0
    var battle: Dictionary = configuration.get("battle", {})
    var scenario_path := str(battle.get("scenario_path", "res://data/scripted_battle.json"))
    var use_enemy_ai := bool(battle.get("use_enemy_ai", true))
    _player_run_deck = _battle_setup_service.run_deck_from_progress(progress_snapshot)
    var player_cards = (
        _player_run_deck.create_battle_cards()
        if progress_snapshot != null
        else null)
    var loaded: bool = engine.setup_scripted_battle(
        int(configuration.get("content_seed", 2308)),
        scenario_path,
        use_enemy_ai,
        player_cards)
    if loaded:
        _battle_setup_service.apply_non_deck_progress(engine.player, progress_snapshot)
    _capture_trigger_history()
    engine.game_log.record_system(
        "info" if loaded else "error",
        "battle_session",
        "战斗会话建立" if loaded else "战斗会话建立失败",
        "content_seed=%d" % int(configuration.get("content_seed", 2308)),
        {"scenario_path": scenario_path, "use_enemy_ai": use_enemy_ai})
    return loaded

func execute(command: Dictionary) -> Dictionary:
    var command_type := str(command.get("type", ""))
    var result: Dictionary
    match command_type:
        "start_turn":
            if engine.battle_state != "active":
                result = {"success": false, "reason": "战斗已经结束"}
            else:
                var drawn: Array = engine.start_player_turn()
                result = {"success": true, "drawn_card_ids": _card_ids(drawn)}
        "end_turn":
            if engine.battle_state != "active":
                result = {"success": false, "reason": "战斗已经结束"}
            else:
                engine.end_player_turn()
                result = {"success": true}
        "play_cards":
            result = engine.confirm_play(command.get("card_ids", []))
        "use_consumable":
            result = engine.use_player_consumable(
                int(command.get("slot_index", -1)),
                command.get("card_ids", []))
        "move_technique_slot":
            result = engine.move_player_technique_slot(int(command.get("direction", 0)))
        _:
            result = {"success": false, "reason": "未知战斗命令：%s" % command_type}
    if not result.get("success", false):
        _record_command_rejected(command_type, str(result.get("reason", "命令执行失败")))
    _capture_trigger_history()
    return result

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
        "enemy_plan": engine.enemy_plan.duplicate(true),
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
        "hand_limit": side.hand_limit,
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
