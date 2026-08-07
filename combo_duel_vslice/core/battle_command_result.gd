class_name BattleCommandResult
extends RefCounted

const SCHEMA_VERSION := 1

var command_type: String = ""
var success: bool = false
var reason: String = ""
var payload: Dictionary = {}

func configure(executed_command_type: String, values: Dictionary):
    command_type = executed_command_type
    success = bool(values.get("success", false))
    reason = str(values.get("reason", ""))
    payload = values.duplicate(true)
    payload.erase("success")
    payload.erase("reason")
    return self

func snapshot() -> Dictionary:
    var result: Dictionary = to_legacy_dict()
    result["schema_version"] = SCHEMA_VERSION
    result["command_type"] = command_type
    return result

func to_legacy_dict() -> Dictionary:
    var result: Dictionary = payload.duplicate(true)
    result["success"] = success
    if reason != "":
        result["reason"] = reason
    return result
