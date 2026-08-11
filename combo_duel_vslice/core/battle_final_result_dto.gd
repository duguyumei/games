class_name BattleFinalResultDTO
extends RefCounted

## 已结束战斗向本局层提交的稳定结果协议。

const SCHEMA_VERSION := 1
const TERMINAL_STATES := [
    "player_victory",
    "player_defeat",
    "unresolved_draw",
    "scenario_error",
]

var schema_version: int = SCHEMA_VERSION
var battle_state: String = ""
var detail: String = ""
var node_id: String = ""
var act: int = 0
var node_type: String = ""
var content_id: String = ""
var content_seed: int = 0
var turn_number: int = 0

static func from_dict(values: Dictionary):
    if int(values.get("schema_version", SCHEMA_VERSION)) != SCHEMA_VERSION:
        return null
    if str(values.get("battle_state", "")) not in TERMINAL_STATES:
        return null
    var result = load("res://core/battle_final_result_dto.gd").new()
    result.battle_state = str(values.get("battle_state", ""))
    result.detail = str(values.get("detail", ""))
    result.node_id = str(values.get("node_id", ""))
    result.act = int(values.get("act", 0))
    result.node_type = str(values.get("node_type", ""))
    result.content_id = str(values.get("content_id", ""))
    result.content_seed = int(values.get("content_seed", 0))
    result.turn_number = maxi(0, int(values.get("turn_number", 0)))
    return result

func is_terminal() -> bool:
    return battle_state in TERMINAL_STATES

func to_dict() -> Dictionary:
    return {
        "schema_version": schema_version,
        "battle_state": battle_state,
        "detail": detail,
        "node_id": node_id,
        "act": act,
        "node_type": node_type,
        "content_id": content_id,
        "content_seed": content_seed,
        "turn_number": turn_number,
    }
