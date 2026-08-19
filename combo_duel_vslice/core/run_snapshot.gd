class_name RunSnapshot
extends RefCounted

## 单局进度的只读快照，core 与表现层之间的唯一读取边界。
##
## 与 BattleSnapshot 同理：字段显式声明，不提供 `value(key, default)` 与
## `section(key)`。地图图结构、奖励、修习与成长子结构保持 Dictionary 形态，
## 它们各自由对应服务的校验负责。

const SCHEMA_VERSION := 1

var seed: int = 0
var starter_build_id: String = ""
var act: int = 0
var generation_serial: int = 0
var act_count: int = 0
var phase: String = ""
var experience: int = 0
var current_node_id: String = ""
var completed_node_ids: Dictionary = {}
var completed_node_count: int = 0
var available_node_ids: Array = []
var available_node_count: int = 0
var can_open_practice: bool = false
var reward: Dictionary = {}
var graph: Dictionary = {}
var practice: Dictionary = {}
var growth: Dictionary = {}
var run_log: Array = []
var battle_log: Array = []
var system_log: Array = []
var runtime_mode: String = ""
var debug_menu_enabled: bool = false
var terminal_result: Dictionary = {}

## 从本局会话产出的字典构建。
static func from_dict(values: Dictionary) -> RunSnapshot:
    var result := RunSnapshot.new()
    for required in ["seed", "act", "phase", "graph"]:
        if not values.has(required):
            push_error("本局快照缺少必需字段：%s" % str(required))

    result.seed = int(values.get("seed", 0))
    result.starter_build_id = str(values.get("starter_build_id", ""))
    result.act = int(values.get("act", 0))
    result.generation_serial = int(values.get("generation_serial", 0))
    result.act_count = int(values.get("act_count", 0))
    result.phase = str(values.get("phase", ""))
    result.experience = int(values.get("experience", 0))
    result.current_node_id = str(values.get("current_node_id", ""))
    result.completed_node_ids = values.get("completed_node_ids", {}).duplicate(true)
    result.completed_node_count = int(values.get("completed_node_count", 0))
    result.available_node_ids = values.get("available_node_ids", []).duplicate(true)
    result.available_node_count = int(values.get("available_node_count", 0))
    result.can_open_practice = bool(values.get("can_open_practice", false))
    result.reward = values.get("reward", {}).duplicate(true)
    result.graph = values.get("graph", {}).duplicate(true)
    result.practice = values.get("practice", {}).duplicate(true)
    result.growth = values.get("growth", {}).duplicate(true)
    result.run_log = values.get("run_log", []).duplicate(true)
    result.battle_log = values.get("battle_log", []).duplicate(true)
    result.system_log = values.get("system_log", []).duplicate(true)
    result.runtime_mode = str(values.get("runtime_mode", ""))
    result.debug_menu_enabled = bool(values.get("debug_menu_enabled", false))
    result.terminal_result = values.get("terminal_result", {}).duplicate(true)
    return result

## 是否有待领取的奖励。
func has_reward() -> bool:
    return not reward.is_empty()

## 序列化边界。存档与既有测试断言使用。
func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "seed": seed,
        "starter_build_id": starter_build_id,
        "act": act,
        "generation_serial": generation_serial,
        "act_count": act_count,
        "phase": phase,
        "experience": experience,
        "current_node_id": current_node_id,
        "completed_node_ids": completed_node_ids.duplicate(true),
        "completed_node_count": completed_node_count,
        "available_node_ids": available_node_ids.duplicate(true),
        "available_node_count": available_node_count,
        "can_open_practice": can_open_practice,
        "reward": reward.duplicate(true),
        "graph": graph.duplicate(true),
        "practice": practice.duplicate(true),
        "growth": growth.duplicate(true),
        "run_log": run_log.duplicate(true),
        "battle_log": battle_log.duplicate(true),
        "system_log": system_log.duplicate(true),
        "runtime_mode": runtime_mode,
        "debug_menu_enabled": debug_menu_enabled,
        "terminal_result": terminal_result.duplicate(true),
    }
