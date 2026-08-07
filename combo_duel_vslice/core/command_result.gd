class_name CommandResult
extends RefCounted

## 会话命令跨越 core 与调用方时的统一结果边界。
##
## 这里统一成功状态、拒绝原因和流程阶段；各命令特有的数据进入 `payload`。
## 引擎内部的领域结果仍保持原有字典，不让门面 DTO 渗入规则结算层。

const SCHEMA_VERSION := 1
const STATUS_SUCCEEDED := "succeeded"
const STATUS_REJECTED := "rejected"

var command_type: String = ""
var success: bool = false
var status: String = STATUS_REJECTED
var reason: String = ""
var phase: String = ""
var payload: Dictionary = {}

static func from_dict(executed_command_type: String, values: Dictionary) -> CommandResult:
    var result := CommandResult.new()
    result.command_type = executed_command_type
    result.success = bool(values.get("success", false))
    result.status = str(values.get(
        "status",
        STATUS_SUCCEEDED if result.success else STATUS_REJECTED))
    result.reason = str(values.get("reason", ""))
    result.phase = str(values.get("phase", ""))
    result.payload = values.duplicate(true)
    for field in ["success", "status", "reason", "phase"]:
        result.payload.erase(field)
    return result

func reason_or(default_reason: String) -> String:
    return reason if reason != "" else default_reason

func payload_value(key: String, default_value = null):
    var value = payload.get(key, default_value)
    return value.duplicate(true) if value is Dictionary or value is Array else value

func to_dict() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "command_type": command_type,
        "success": success,
        "status": status,
        "reason": reason,
        "phase": phase,
        "payload": payload.duplicate(true),
    }
