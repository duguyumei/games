class_name BattleRoundService
extends RefCounted

## 战斗回合生命周期。
##
## 这里故意只编排回合时点、补牌和行动资格，不执行牌型或功法效果。
## 规则结算仍由 ActionResolver / DamageResolver 负责；对手行动由
## CombatEngine 通过回调接入，避免回合服务复制一份敌方 AI 规则。

const BattleTimingSystemScript = preload("res://core/battle_timing_system.gd")

var player
var enemy
var battle_flow
var timing_system
var trigger_queue

var scripted_mode: bool = false
var external_enemy_action_mode: bool = false
var turn_number: int = 0
var enemy_action_index: int = 0
var round_ended: bool = false
var external_round_end_requested: bool = false
var battle_start_card_effects_applied: bool = false
var current_round_actors: Array = []

var _battle_state: Callable
var _lock_enemy_action: Callable
var _resolve_enemy_only_actions: Callable
var _update_battle_state: Callable
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
    _state_changed = state_changed

func reset() -> void:
    turn_number = 0
    enemy_action_index = 0
    round_ended = false
    external_round_end_requested = false
    battle_start_card_effects_applied = false
    current_round_actors.clear()

func set_modes(is_scripted: bool, uses_external_enemy_actions: bool) -> void:
    scripted_mode = is_scripted
    external_enemy_action_mode = uses_external_enemy_actions

func start_player_turn() -> Array:
    if _battle_state.call() != "active":
        return []

    if not battle_start_card_effects_applied:
        timing_system.emit_timing(BattleTimingSystemScript.BATTLE_START, {
            "round_number": 0,
            "actors": [player, enemy],
            "metadata": {"setup_mode": "scripted" if scripted_mode else "solo"},
        })
        battle_start_card_effects_applied = true

    turn_number += 1
    enemy_action_index = 0
    round_ended = false
    external_round_end_requested = false
    current_round_actors = [player]
    if scripted_mode:
        current_round_actors.append(enemy)

    timing_system.emit_timing(BattleTimingSystemScript.ROUND_START, {
        "round_number": turn_number,
        "actors": current_round_actors,
    })
    battle_flow.begin_round([
        {"actor": player, "actions": 1},
        {"actor": enemy, "actions": 1 if scripted_mode else 0},
    ])

    var drawn: Array = []
    var enemy_drawn: Array = []
    for side in current_round_actors:
        timing_system.emit_timing(BattleTimingSystemScript.TURN_START, {
            "round_number": turn_number,
            "actor": side,
            "actors": current_round_actors,
        })
        timing_system.emit_timing(BattleTimingSystemScript.BEFORE_NORMAL_DRAW, {
            "round_number": turn_number,
            "actor": side,
            "actors": current_round_actors,
            "metadata": {
                "hand_count": side.hand.size(),
                "hand_limit": side.current_hand_limit(),
            },
        })
        var side_drawn: Array = side.draw_to_limit()
        timing_system.emit_timing(BattleTimingSystemScript.AFTER_NORMAL_DRAW, {
            "round_number": turn_number,
            "actor": side,
            "actors": current_round_actors,
            "drawn_cards": side_drawn,
            "metadata": {
                "drawn_count": side_drawn.size(),
                "hand_count": side.hand.size(),
                "hand_limit": side.current_hand_limit(),
            },
        })
        if side == player:
            drawn = side_drawn
        else:
            enemy_drawn = side_drawn

    trigger_queue.add_history(
        "round_start" if scripted_mode else "player_turn_start",
        "双方正常补牌" if scripted_mode else "正常补牌",
        "规则",
        "成功",
        "我方抽 %d 张｜对手抽 %d 张" % [drawn.size(), enemy_drawn.size()]
            if scripted_mode
            else "补至上限：抽 %d 张" % drawn.size())
    timing_system.emit_timing(BattleTimingSystemScript.ACTION_WINDOW_START, {
        "round_number": turn_number,
        "actors": current_round_actors,
        "metadata": {"scripted_mode": scripted_mode},
    })

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
    return drawn

func end_player_turn() -> void:
    if round_ended and scripted_mode:
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
    finish_round_end()
    _state_changed.call()

func finish_round_end() -> void:
    if round_ended and scripted_mode:
        return
    round_ended = true
    var ending_actors: Array = current_round_actors if not current_round_actors.is_empty() else [player]
    timing_system.emit_timing(BattleTimingSystemScript.ACTION_WINDOW_END, {
        "round_number": turn_number,
        "actors": ending_actors,
    })
    for side in ending_actors:
        timing_system.emit_timing(BattleTimingSystemScript.TURN_END, {
            "round_number": turn_number,
            "actor": side,
            "actors": ending_actors,
        })
    trigger_queue.add_history("player_turn_end", "玩家回合结束", "规则", "成功")
    _update_battle_state.call()
