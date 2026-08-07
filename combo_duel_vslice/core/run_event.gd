class_name RunEvent
extends RefCounted

## 本局会话向表现层发布的一次性事件信封。
##
## 信封固定事件类型和序号，领域数据集中在 `payload`。这里故意不复制
## 各节点与奖励服务的业务模型；事件只负责通知，不作为状态恢复来源。

const SCHEMA_VERSION := 1

var type: String = ""
var serial: int = -1
var log_serial: int = -1
var payload: Dictionary = {}

static func create(
        event_type: String,
        event_serial: int,
        related_log_serial: int,
        values: Dictionary = {}) -> RunEvent:
    var result := RunEvent.new()
    result.type = event_type
    result.serial = event_serial
    result.log_serial = related_log_serial
    result.payload = values.duplicate(true)
    return result

static func from_dict(values: Dictionary) -> RunEvent:
    var payload_values := values.duplicate(true)
    payload_values.erase("schema_version")
    payload_values.erase("type")
    payload_values.erase("serial")
    payload_values.erase("log_serial")
    return create(
        str(values.get("type", "")),
        int(values.get("serial", -1)),
        int(values.get("log_serial", -1)),
        payload_values)

func to_dict() -> Dictionary:
    var result := payload.duplicate(true)
    result["schema_version"] = SCHEMA_VERSION
    result["type"] = type
    result["serial"] = serial
    result["log_serial"] = log_serial
    return result
