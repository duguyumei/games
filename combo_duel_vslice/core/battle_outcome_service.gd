class_name BattleOutcomeService
extends RefCounted

## 战斗结果与终局清理。
##
## 结果状态只在这里计算并触发终局时点；不负责回合推进、伤害计算或本局奖励。
## BattleSession 仍通过 CombatEngine 的门面属性读取最终状态。

const BattleTimingSystemScript = preload("res://core/battle_timing_system.gd")

var player
var enemy
var battle_flow
var timing_system
var trigger_queue
var round_service
var power_modifiers: Dictionary
var game_log
var clear_enemy_action_lock: Callable
var state_changed: Callable
var turn_number_reader: Callable

var scripted_mode: bool = false
var state: String = "active"
var detail: String = ""
var cleanup_completed: bool = false

func _init(
        player_side,
        enemy_side,
        flow,
        timing,
        history,
        rounds,
        modifiers: Dictionary,
        log,
        clear_enemy_callback: Callable,
        state_changed_callback: Callable,
        read_turn_number: Callable) -> void:
    player = player_side
    enemy = enemy_side
    battle_flow = flow
    timing_system = timing
    trigger_queue = history
    round_service = rounds
    power_modifiers = modifiers
    game_log = log
    clear_enemy_action_lock = clear_enemy_callback
    state_changed = state_changed_callback
    turn_number_reader = read_turn_number

func reset() -> void:
    state = "active"
    detail = ""
    cleanup_completed = false

func set_mode(is_scripted: bool) -> void:
    scripted_mode = is_scripted

func use_game_log_queue(history, log) -> void:
    trigger_queue = history
    game_log = log

func update() -> String:
    if player.life <= 0 and enemy.life <= 0:
        state = "unresolved_draw"
        detail = "双方同时倒下：胜负规则尚未确认"
    elif enemy.life <= 0:
        state = "player_victory"
        detail = "试炼胜利"
    elif player.life <= 0:
        state = "player_defeat"
        detail = "玩家生命归零"
    elif scripted_mode and player.hand.is_empty() \
            and player.draw_pile.is_empty() \
            and player.staging.is_empty():
        state = "player_defeat"
        detail = "玩家没有可用真气且敌人尚未倒下"

    if state != "active":
        _finish_once()
    return state

func set_scenario_error(error_detail: String) -> void:
    state = "scenario_error"
    detail = error_detail
    battle_flow.set_action_count(player, 0)
    battle_flow.set_action_count(enemy, 0)
    clear_enemy_action_lock.call()
    game_log.record_system("error", "scenario_runtime", "脚本场景错误", error_detail)
    trigger_queue.add_history("scenario_error", "脚本场景错误", "脚本场景", "失败", error_detail)
    state_changed.call()

func on_battle_end_timing(_event) -> Dictionary:
    var cleared_power_modifiers: int = power_modifiers.size()
    var cleared_round_actors: int = round_service.current_round_actors.size()
    var cleared_defense: int = player.defense + enemy.defense
    player.defense = 0
    enemy.defense = 0
    power_modifiers.clear()
    round_service.current_round_actors.clear()
    return {
        "success": true,
        "detail": "清理 %d 点防御、%d 项功法修正与 %d 个回合行动方引用" % [
            cleared_defense,
            cleared_power_modifiers,
            cleared_round_actors],
    }

func _finish_once() -> void:
    if cleanup_completed:
        return
    var winner = null
    if state == "player_victory":
        winner = player
    elif state == "player_defeat":
        winner = enemy
    var emitted: Dictionary = timing_system.emit_timing(
        BattleTimingSystemScript.BATTLE_END, {
        "round_number": turn_number_reader.call(),
        "actors": [player, enemy],
        "winner": winner,
        "battle_state": state,
        "metadata": {
            "battle_state": state,
            "battle_state_detail": detail,
        },
    })
    if not emitted.get("success", false):
        set_scenario_error(
            "战斗时点失败 hook=%s reason=%s" % [
                BattleTimingSystemScript.BATTLE_END,
                str(emitted.get("reason", "battle_end 处理器失败")),
            ])
        cleanup_completed = true
        return
    cleanup_completed = true
    battle_flow.set_action_count(player, 0)
    battle_flow.set_action_count(enemy, 0)
    clear_enemy_action_lock.call()
    trigger_queue.add_history("battle_end", detail, "战斗结果", "结算")
