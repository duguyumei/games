class_name BattleEvent
extends RefCounted

## 战斗会话向表现层发布的一次性事件。
##
## 这里只描述已发生的触发记录与命令拒绝，不驱动战斗规则，也不替代
## StructuredGameLog 的持久诊断记录。

const SCHEMA_VERSION := 1

var type: String = ""
var serial: int = -1
var log_serial: int = -1
var timing: String = ""
var label: String = ""
var source: String = ""
var status: String = ""
var detail: String = ""
var command: String = ""
var reason: String = ""

static func trigger_history(event_serial: int, entry: Dictionary) -> BattleEvent:
    return from_dict({
        "type": "trigger_resolved",
        "serial": event_serial,
        "timing": entry.get("timing", ""),
        "label": entry.get("label", ""),
        "source": entry.get("source", ""),
        "status": entry.get("status", ""),
        "detail": entry.get("detail", ""),
    })

static func command_rejected(
        event_serial: int,
        rejected_command: String,
        rejection_reason: String,
        related_log_serial: int) -> BattleEvent:
    return from_dict({
        "type": "command_rejected",
        "serial": event_serial,
        "log_serial": related_log_serial,
        "command": rejected_command,
        "reason": rejection_reason,
    })

static func from_dict(values: Dictionary) -> BattleEvent:
    var result := BattleEvent.new()
    result.type = str(values.get("type", ""))
    result.serial = int(values.get("serial", -1))
    result.log_serial = int(values.get("log_serial", -1))
    result.timing = str(values.get("timing", ""))
    result.label = str(values.get("label", ""))
    result.source = str(values.get("source", ""))
    result.status = str(values.get("status", ""))
    result.detail = str(values.get("detail", ""))
    result.command = str(values.get("command", ""))
    result.reason = str(values.get("reason", ""))
    return result

func to_dict() -> Dictionary:
    var result := {
        "schema_version": SCHEMA_VERSION,
        "type": type,
        "serial": serial,
    }
    if type == "trigger_resolved":
        result.merge({
            "timing": timing,
            "label": label,
            "source": source,
            "status": status,
            "detail": detail,
        })
    elif type == "command_rejected":
        result.merge({
            "log_serial": log_serial,
            "command": command,
            "reason": reason,
        })
    return result
