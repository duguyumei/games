class_name BattleSnapshot
extends RefCounted

## 战斗状态的只读快照，core 与表现层之间的唯一读取边界。
##
## 字段是显式声明的。此前这个类只包一个裸 Dictionary 并暴露
## `value(key, default)` 与 `section(key)`，任何键名拼写错误都会静默返回默认值，
## 在界面上表现为 0 或空白而不是可定位的失败。那两个方法已移除；新增字段
## 必须同时在这里声明，读取方才能拿到。
##
## 日志与时点历史保持 Array 形态：它们是天然的追加序列，元素契约由
## StructuredGameLog 与 BattleTimingSystem 负责。

const SCHEMA_VERSION := 1

const SideSnapshotScript = preload("res://core/battle_side_snapshot.gd")

var battle_state: String = ""
var battle_state_detail: String = ""
var turn_number: int = 0
var actions_available: int = 0
var enemy_actions_available: int = 0
var action_states: Dictionary = {}
var resolution_mode: String = ""
var round_ended: bool = false
var locked_enemy_card_count: int = 0
var enemy_plan: Dictionary = {}
var ai_decision: Dictionary = {}
var pending_choice: Dictionary = {}
var pending_action_transaction: Dictionary = {}
var delayed_count: int = 0
var timing_history: Array = []
var status_history: Array = []
var player: BattleSideSnapshot
var enemy: BattleSideSnapshot
var last_preview: Dictionary = {}
var last_enemy_preview: Dictionary = {}
var last_player_action_cards: Array = []
var last_enemy_action_cards: Array = []
var battle_log: Array = []
var system_log: Array = []

## 从战斗会话产出的字典构建。
##
## 参战者字段缺失是装配错误，直接报错而不是给一个空 side：空 side 会让
## 界面显示 0 生命，看起来像战斗结束而不像装配失败。
static func from_dict(values: Dictionary) -> BattleSnapshot:
    var result := BattleSnapshot.new()
    for required in ["player", "enemy", "battle_state"]:
        if not values.has(required):
            push_error("战斗快照缺少必需字段：%s" % str(required))

    result.battle_state = str(values.get("battle_state", ""))
    result.battle_state_detail = str(values.get("battle_state_detail", ""))
    result.turn_number = int(values.get("turn_number", 0))
    result.actions_available = int(values.get("actions_available", 0))
    result.enemy_actions_available = int(values.get("enemy_actions_available", 0))
    result.action_states = values.get("action_states", {}).duplicate(true)
    result.resolution_mode = str(values.get("resolution_mode", ""))
    result.round_ended = bool(values.get("round_ended", false))
    result.locked_enemy_card_count = int(values.get("locked_enemy_card_count", 0))
    result.enemy_plan = values.get("enemy_plan", {}).duplicate(true)
    result.ai_decision = values.get("ai_decision", {}).duplicate(true)
    result.pending_choice = values.get("pending_choice", {}).duplicate(true)
    result.pending_action_transaction = values.get(
        "pending_action_transaction", {}).duplicate(true)
    result.delayed_count = int(values.get("delayed_count", 0))
    result.timing_history = values.get("timing_history", []).duplicate(true)
    result.status_history = values.get("status_history", []).duplicate(true)
    result.player = SideSnapshotScript.from_dict(values.get("player", {}))
    result.enemy = SideSnapshotScript.from_dict(values.get("enemy", {}))
    result.last_preview = values.get("last_preview", {}).duplicate(true)
    result.last_enemy_preview = values.get("last_enemy_preview", {}).duplicate(true)
    result.last_player_action_cards = values.get(
        "last_player_action_cards", []).duplicate(true)
    result.last_enemy_action_cards = values.get(
        "last_enemy_action_cards", []).duplicate(true)
    result.battle_log = values.get("battle_log", []).duplicate(true)
    result.system_log = values.get("system_log", []).duplicate(true)
    return result

## 按通道名取日志。表现层的日志通道切换是运行期选择，因此保留一个显式入口，
## 而不是让调用方拼字段名。未知通道是编程错误，直接报错。
func log_channel(channel: String) -> Array:
    match channel:
        "battle": return battle_log
        "system": return system_log
    push_error("未知日志通道：%s" % channel)
    return []

## 某一方的行动状态。`side_key` 只接受 "player" 或 "enemy"。
func action_state(side_key: String) -> Dictionary:
    if not action_states.has(side_key):
        push_error("行动状态不含该方：%s" % side_key)
        return {}
    return action_states[side_key]

## 是否存在等待玩家处理的功法选择。
func has_pending_choice() -> bool:
    return not pending_choice.is_empty()

## 序列化边界。存档、AI 传输和既有测试断言使用。
func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "battle_state": battle_state,
        "battle_state_detail": battle_state_detail,
        "turn_number": turn_number,
        "actions_available": actions_available,
        "enemy_actions_available": enemy_actions_available,
        "action_states": action_states.duplicate(true),
        "resolution_mode": resolution_mode,
        "round_ended": round_ended,
        "locked_enemy_card_count": locked_enemy_card_count,
        "enemy_plan": enemy_plan.duplicate(true),
        "ai_decision": ai_decision.duplicate(true),
        "pending_choice": pending_choice.duplicate(true),
        "pending_action_transaction": pending_action_transaction.duplicate(true),
        "delayed_count": delayed_count,
        "timing_history": timing_history.duplicate(true),
        "status_history": status_history.duplicate(true),
        "player": player.to_dict() if player != null else {},
        "enemy": enemy.to_dict() if enemy != null else {},
        "last_preview": last_preview.duplicate(true),
        "last_enemy_preview": last_enemy_preview.duplicate(true),
        "last_player_action_cards": last_player_action_cards.duplicate(true),
        "last_enemy_action_cards": last_enemy_action_cards.duplicate(true),
        "battle_log": battle_log.duplicate(true),
        "system_log": system_log.duplicate(true),
    }
