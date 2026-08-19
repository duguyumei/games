class_name RunCommandRequest
extends RefCounted

const SCHEMA_VERSION := 1
const ALLOWED_COMMANDS := ["regenerate_current_act_map"]

var command: String = ""
var request_token: String = ""
var source_kind: String = ""
var source_id: String = ""
var source_instance_key: String = ""
var transaction_token: String = ""

static func from_dict(values: Dictionary) -> RunCommandRequest:
    var result := RunCommandRequest.new()
    result.command = str(values.get("command", ""))
    result.request_token = str(values.get("request_token", ""))
    result.source_kind = str(values.get("source_kind", ""))
    result.source_id = str(values.get("source_id", ""))
    result.source_instance_key = str(values.get("source_instance_key", ""))
    result.transaction_token = str(values.get("transaction_token", ""))
    return result

func validate() -> Array[String]:
    var errors: Array[String] = []
    if command not in ALLOWED_COMMANDS:
        errors.append("Run command 未登记：%s" % command)
    if request_token == "":
        errors.append("Run command request 缺少稳定 request_token")
    if source_kind not in ["item", "inner_skill", "rule"]:
        errors.append("Run command source_kind 无效：%s" % source_kind)
    if source_id == "" or source_instance_key == "":
        errors.append("Run command request 缺少来源身份")
    return errors

func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "command": command,
        "request_token": request_token,
        "source_kind": source_kind,
        "source_id": source_id,
        "source_instance_key": source_instance_key,
        "transaction_token": transaction_token,
    }
