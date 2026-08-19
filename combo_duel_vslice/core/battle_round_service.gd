class_name BattleRoundService
extends RefCounted

## 战斗回合生命周期。
##
## 这里故意只编排回合时点、补牌和行动资格，不执行牌型或功法效果。
## 规则结算仍由 ActionResolver / DamageResolver 负责；对手行动由
## CombatEngine 通过回调接入，避免回合服务复制一份敌方 AI 规则。

const BattleTimingSystemScript = preload("res://core/battle_timing_system.gd")
const DefenseRetentionPolicyScript = preload(
    "res://core/defense_retention_policy.gd")

var player
var enemy
var battle_flow
var timing_system
var trigger_queue
var defense_retention_policy := DefenseRetentionPolicyScript.new()

var scripted_mode: bool = false
var external_enemy_action_mode: bool = false
var turn_number: int = 0
var enemy_action_index: int = 0
var round_ended: bool = false
var external_round_end_requested: bool = false
var battle_start_card_effects_applied: bool = false
var current_round_actors: Array = []
var last_defense_decay_results: Array[Dictionary] = []
var round_start_cursor: String = "idle"
var _round_start_state: Dictionary = {}

var _battle_state: Callable
var _lock_enemy_action: Callable
var _resolve_enemy_only_actions: Callable
var _update_battle_state: Callable
var _set_scenario_error: Callable
var _state_changed: Callable

func _init(
        player_side,
        enemy_side,
        flow,
        timing,
        history,
        battle_state_reader: Callable,
        lock_enemy_action: Callable,
        resolve_enemy_only_actions: Callable,
        update_battle_state: Callable,
        set_scenario_error: Callable,
        state_changed: Callable) -> void:
    player = player_side
    enemy = enemy_side
    battle_flow = flow
    timing_system = timing
    trigger_queue = history
    _battle_state = battle_state_reader
    _lock_enemy_action = lock_enemy_action
    _resolve_enemy_only_actions = resolve_enemy_only_actions
    _update_battle_state = update_battle_state
    _set_scenario_error = set_scenario_error
    _state_changed = state_changed

func reset() -> void:
    turn_number = 0
    enemy_action_index = 0
    round_ended = false
    external_round_end_requested = false
    battle_start_card_effects_applied = false
    current_round_actors.clear()
    last_defense_decay_results.clear()
    round_start_cursor = "idle"
    _round_start_state.clear()

func set_modes(is_scripted: bool, uses_external_enemy_actions: bool) -> void:
    scripted_mode = is_scripted
    external_enemy_action_mode = uses_external_enemy_actions

func start_player_turn() -> Array:
    if _battle_state.call() != "active":
        return []
    if round_start_cursor not in ["idle", "action_window_ready"]:
        return _round_start_state.get("player_drawn", []).duplicate()
    if round_start_cursor == "action_window_ready" and not round_ended:
        return _round_start_state.get("player_drawn", []).duplicate()
    round_start_cursor = "battle_start" \
        if not battle_start_card_effects_applied else "round_start_setup"
    _round_start_state = {
        "actor_index": 0,
        "player_drawn": [],
        "enemy_drawn": [],
        "side_drawn": [],
        "effective_hand_limit": 0,
    }
    return _continue_round_start()

func continue_round_start_after_choice() -> Dictionary:
    if round_start_cursor in ["idle", "action_window_ready"]:
        return {"success": false, "reason": "当前没有暂停的回合启动流程"}
    var drawn := _continue_round_start()
    return {
        "success": _battle_state.call() == "active",
        "pending_choice": timing_system.has_pending_choice(),
        "choice_request": timing_system.pending_choice_snapshot(),
        "drawn_cards": drawn,
        "action_window_ready": round_start_cursor == "action_window_ready",
    }

func is_action_window_ready() -> bool:
    return round_start_cursor == "action_window_ready" \
        and not timing_system.has_pending_choice()

func is_round_start_in_progress() -> bool:
    return round_start_cursor not in ["idle", "action_window_ready"]

func _continue_round_start() -> Array:
    while _battle_state.call() == "active":
        match round_start_cursor:
            "battle_start":
                var result := _emit_timing_result(
                    BattleTimingSystemScript.BATTLE_START, {
                        "round_number": 0,
                        "actors": [player, enemy],
                        "metadata": {
                            "setup_mode": "scripted" if scripted_mode else "solo"},
                    })
                round_start_cursor = "battle_start_complete"
                if not _timing_can_continue(result):
                    return _player_drawn()
            "battle_start_complete":
                battle_start_card_effects_applied = true
                round_start_cursor = "round_start_setup"
            "round_start_setup":
                turn_number += 1
                enemy_action_index = 0
                round_ended = false
                external_round_end_requested = false
                current_round_actors = [player]
                if scripted_mode:
                    current_round_actors.append(enemy)
                _round_start_state["actor_index"] = 0
                round_start_cursor = "round_start"
            "round_start":
                var result := _emit_timing_result(
                    BattleTimingSystemScript.ROUND_START, {
                        "round_number": turn_number,
                        "actors": current_round_actors,
                    })
                round_start_cursor = "round_start_complete"
                if not _timing_can_continue(result):
                    return _player_drawn()
            "round_start_complete":
                battle_flow.begin_round([
                    {"actor": player, "actions": 1},
                    {"actor": enemy, "actions": 1 if scripted_mode else 0},
                ])
                round_start_cursor = "turn_start"
            "turn_start":
                var side = _current_round_actor()
                var result := _emit_timing_result(
                    BattleTimingSystemScript.TURN_START, {
                        "round_number": turn_number,
                        "actor": side,
                        "actors": current_round_actors,
                    })
                round_start_cursor = "hand_limit"
                if not _timing_can_continue(result):
                    return _player_drawn()
            "hand_limit":
                var side = _current_round_actor()
                var hand_limit_result: Dictionary = side.effective_hand_limit_result()
                if not hand_limit_result.get("success", false):
                    _set_scenario_error.call("正常补牌手牌上限查询失败")
                    _state_changed.call()
                    return _player_drawn()
                _round_start_state["effective_hand_limit"] = int(
                    hand_limit_result["effective_value"])
                round_start_cursor = "before_normal_draw"
            "before_normal_draw":
                var side = _current_round_actor()
                var result := _emit_timing_result(
                    BattleTimingSystemScript.BEFORE_NORMAL_DRAW, {
                        "round_number": turn_number,
                        "actor": side,
                        "actors": current_round_actors,
                        "metadata": _draw_metadata(side),
                    })
                round_start_cursor = "normal_draw"
                if not _timing_can_continue(result):
                    return _player_drawn()
            "normal_draw":
                var side = _current_round_actor()
                var side_drawn: Array = side.draw_to_limit("normal_draw")
                _round_start_state["side_drawn"] = side_drawn
                if side == player:
                    _round_start_state["player_drawn"] = side_drawn
                else:
                    _round_start_state["enemy_drawn"] = side_drawn
                round_start_cursor = "after_normal_draw"
            "after_normal_draw":
                var side = _current_round_actor()
                var side_drawn: Array = _round_start_state.get("side_drawn", [])
                var metadata := _draw_metadata(side)
                metadata["drawn_count"] = side_drawn.size()
                var result := _emit_timing_result(
                    BattleTimingSystemScript.AFTER_NORMAL_DRAW, {
                        "round_number": turn_number,
                        "actor": side,
                        "actors": current_round_actors,
                        "drawn_cards": side_drawn,
                        "metadata": metadata,
                    })
                round_start_cursor = "next_actor"
                if not _timing_can_continue(result):
                    return _player_drawn()
            "next_actor":
                _round_start_state["actor_index"] = int(
                    _round_start_state.get("actor_index", 0)) + 1
                round_start_cursor = "turn_start" \
                    if int(_round_start_state["actor_index"]) \
                        < current_round_actors.size() \
                    else "action_window_start"
            "action_window_start":
                var result := _emit_timing_result(
                    BattleTimingSystemScript.ACTION_WINDOW_START, {
                        "round_number": turn_number,
                        "actors": current_round_actors,
                        "metadata": {"scripted_mode": scripted_mode},
                    })
                round_start_cursor = "action_window_ready"
                if not _timing_can_continue(result):
                    return _player_drawn()
            "action_window_ready":
                _open_action_window()
                return _player_drawn()
            _:
                _set_scenario_error.call(
                    "未知回合启动游标：%s" % round_start_cursor)
                _state_changed.call()
                return _player_drawn()
    return _player_drawn()

func _open_action_window() -> void:
    var drawn := _player_drawn()
    var enemy_drawn: Array = _round_start_state.get("enemy_drawn", [])
    trigger_queue.add_history(
        "round_start" if scripted_mode else "player_turn_start",
        "双方正常补牌" if scripted_mode else "正常补牌", "规则", "成功",
        "我方抽 %d 张｜对手抽 %d 张" % [drawn.size(), enemy_drawn.size()]
            if scripted_mode else "补至上限：抽 %d 张" % drawn.size())
    if player.hand.is_empty():
        battle_flow.forfeit_remaining(player, "没有可用于出招的手牌")
    if scripted_mode and battle_flow.can_act(enemy) and not external_enemy_action_mode:
        _lock_enemy_action.call()
    _update_battle_state.call()
    if _battle_state.call() == "active" \
            and not battle_flow.can_act(player) \
            and battle_flow.can_act(enemy) \
            and not external_enemy_action_mode:
        _resolve_enemy_only_actions.call()
    _state_changed.call()

func _current_round_actor():
    return current_round_actors[int(_round_start_state.get("actor_index", 0))]

func _draw_metadata(side) -> Dictionary:
    return {
        "hand_count": side.hand.size(),
        "base_hand_limit": side.base_hand_limit(),
        "hand_limit": int(_round_start_state.get("effective_hand_limit", 0)),
    }

func _player_drawn() -> Array:
    return _round_start_state.get("player_drawn", []).duplicate()

func _timing_can_continue(result: Dictionary) -> bool:
    if not result.get("success", false):
        _state_changed.call()
        return false
    if result.get("pending_choice", false):
        _state_changed.call()
        return false
    return true

func end_player_turn() -> void:
    if round_ended or _battle_state.call() != "active" \
            or not is_action_window_ready():
        return
    battle_flow.forfeit_remaining(player, "玩家结束当前回合")
    if external_enemy_action_mode:
        external_round_end_requested = true
        if not battle_flow.can_act(enemy):
            finish_round_end()
        _state_changed.call()
        return
    if _battle_state.call() == "active" and battle_flow.can_act(enemy):
        _resolve_enemy_only_actions.call()
    if _battle_state.call() == "active":
        finish_round_end()
    _state_changed.call()

func finish_round_end() -> Array[Dictionary]:
    if round_ended or _battle_state.call() != "active":
        return last_defense_decay_results.duplicate(true)
    round_ended = true
    var ending_actors: Array = [player, enemy]
    if not _emit_timing(BattleTimingSystemScript.ACTION_WINDOW_END, {
        "round_number": turn_number,
        "actors": ending_actors,
    }):
        return last_defense_decay_results.duplicate(true)
    last_defense_decay_results.clear()
    for side in ending_actors:
        var decay: Dictionary = defense_retention_policy.apply_decay(side, {
                "timing": "round_end_defense_decay",
                "round_number": turn_number,
                "actor": side,
                "actors": ending_actors,
            })
        last_defense_decay_results.append(decay)
        if not decay.get("success", false):
            return last_defense_decay_results.duplicate(true)
        if not _emit_timing(BattleTimingSystemScript.DEFENSE_DECAY_RESOLVED, {
            "round_number": turn_number,
            "actor": side,
            "actors": ending_actors,
            "decay": decay,
            "metadata": {
                "defense_before": int(decay.get("before", 0)),
                "defense_after": int(decay.get("after", 0)),
                "defense_lost": int(decay.get("lost", 0)),
            },
        }):
            return last_defense_decay_results.duplicate(true)
    trigger_queue.add_history(
        "defense_decay",
        "双方防御衰减",
        "完整回合规则",
        "成功",
        _defense_decay_detail(last_defense_decay_results))
    for side in ending_actors:
        if not _emit_timing(BattleTimingSystemScript.TURN_END, {
            "round_number": turn_number,
            "actor": side,
            "actors": ending_actors,
        }):
            return last_defense_decay_results.duplicate(true)
    trigger_queue.add_history("player_turn_end", "玩家回合结束", "规则", "成功")
    _update_battle_state.call()
    round_start_cursor = "idle"
    _round_start_state.clear()
    return last_defense_decay_results.duplicate(true)

func _emit_timing(hook: String, context: Dictionary) -> bool:
    return _emit_timing_result(hook, context).get("success", false)

func _emit_timing_result(hook: String, context: Dictionary) -> Dictionary:
    var result: Dictionary = timing_system.emit_timing(hook, context)
    if result.get("success", false):
        return result
    var reason := str(result.get("reason", "战斗时点处理器失败"))
    _set_scenario_error.call("战斗时点失败 hook=%s reason=%s" % [hook, reason])
    return result

func _defense_decay_detail(results: Array[Dictionary]) -> String:
    var details: Array[String] = []
    for result in results:
        details.append("%s %d→%d（保留 %d%%%s）" % [
            result["side"].name,
            int(result["before"]),
            int(result["after"]),
            int(result["retention_percent"]),
            "，阻止衰减" if bool(result["prevented"]) else "",
        ])
    return "｜".join(details)
