class_name RunEffectContext
extends RefCounted

## 单次本局事务的运行上下文。
##
## growth 始终是独立工作副本；metadata 只携带来源、奖励包等编排信息。

var growth
var metadata: Dictionary
var content_catalog
var committed_events: Array = []

func _init(
        growth_override,
        metadata_override: Dictionary = {},
        content_catalog_override = null) -> void:
    growth = growth_override
    metadata = metadata_override.duplicate(true)
    content_catalog = content_catalog_override

func record_committed_events(values: Array) -> void:
    for value in values:
        if value is Dictionary:
            var event: Dictionary = value.duplicate(true)
            var serial := committed_events.size() + 1
            var transaction_token := str(metadata.get(
                "transaction_token", "run_mutation"))
            event["event_serial"] = serial
            # 逐牌 canonical 事实已经持有由 transaction/operation/card 构成的
            # 稳定 token；来源标识等既有事件则继续在这里取得事务内序号。
            if str(event.get("event_token", "")) == "":
                event["event_token"] = "%s:%s:%s:%s:%s:%d" % [
                    str(event.get("event_type", "source_marker_changed")),
                    transaction_token,
                    str(event.get("source_kind", "")),
                    str(event.get("source_instance_key", "")),
                    str(event.get("marker_id", "")),
                    serial,
                ]
            committed_events.append(event)
