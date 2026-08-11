class_name RunTerminalResultDTO
extends RefCounted

## 本局终局的可序列化结果。kind 是表现层唯一用于选择文案的状态字段。

const SCHEMA_VERSION := 1
const KINDS := [
    "victory",
    "defeat",
    "abandoned",
    "unresolved_rule",
    "scenario_error",
]
const NON_VICTORY_KINDS := [
    "defeat",
    "abandoned",
    "unresolved_rule",
    "scenario_error",
]

var schema_version: int = SCHEMA_VERSION
var kind: String = ""
var source: String = ""
var detail: String = ""
var battle_state: String = ""
var act: int = 0
var node_id: String = ""
var node_type: String = ""
var turn_number: int = 0

static func from_dict(values: Dictionary):
    if int(values.get("schema_version", SCHEMA_VERSION)) != SCHEMA_VERSION:
        return null
    if str(values.get("kind", "")) not in KINDS:
        return null
    var result = load("res://core/run_terminal_result_dto.gd").new()
    result.kind = str(values.get("kind", ""))
    result.source = str(values.get("source", ""))
    result.detail = str(values.get("detail", ""))
    result.battle_state = str(values.get("battle_state", ""))
    result.act = int(values.get("act", 0))
    result.node_id = str(values.get("node_id", ""))
    result.node_type = str(values.get("node_type", ""))
    result.turn_number = maxi(0, int(values.get("turn_number", 0)))
    if not result.is_valid():
        return null
    return result

func is_valid() -> bool:
    if kind not in KINDS or source == "" or act < 1:
        return false
    match kind:
        "victory":
            return battle_state in ["", "player_victory"]
        "defeat":
            return battle_state == "player_defeat"
        "unresolved_rule":
            return battle_state == "unresolved_draw"
        "scenario_error":
            return battle_state == "scenario_error" and detail != ""
        "abandoned":
            return battle_state == ""
    return false

func is_victory() -> bool:
    return kind == "victory"

func to_dict() -> Dictionary:
    return {
        "schema_version": schema_version,
        "kind": kind,
        "source": source,
        "detail": detail,
        "battle_state": battle_state,
        "act": act,
        "node_id": node_id,
        "node_type": node_type,
        "turn_number": turn_number,
    }
